"""
Stripe Payment Handlers
- Checkout session creation
- Payment intent capture
- Webhook processing
- Connect account management
"""

import contextlib
import logging
import secrets
import string as _string
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import stripe
from firebase_functions import https_fn

# Initializing Stripe key lazily in handlers
from config import (
    BASE_URL,
    CATEGORY_TAX_CODE_MAP,
    IS_EMULATOR,
    PLATFORM_FEE_RATIO,
    STRIPE_TAX_CODE_BASIC_GROCERIES,
    STRIPE_TAX_CODE_CHILDRENS_CLOTHING,
    STRIPE_TAX_ENABLED,
    get_stripe_secret_key,
    get_stripe_webhook_secret,
)
from models.order_event import OrderEvent
from handlers.coupons import _compute_discount as _coupon_compute_discount
from schema_constants import (
    ApiKeys,
    AppConfig,
    BusinessRules,
    CartVerificationReasonValues,
    Collections,
    DeliveryStatusValues,
    DeliveryTypeValues,
    DigitalTypeValues,
    ErrorCodes,
    Fields,
    HeaderKeys,
    LanguageValues,
    LicenseStatusValues,
    NotificationTypes,
    OrderEventTypes,
    OrderStatusValues,
    PaymentProviderValues,
    PaymentStatusValues,
    PayoutStatusValues,
    PlatformDebtStatusValues,
    ProductLifecycleStatusValues,
    RateLimitActions,
    SecurityAlertTypes,
    SeverityLevels,
    StripeConstants,
    StripeEventTypes,
    UserRoleValues,
    ValidationLimits,
    WebhookStatusValues,
)
from services.email_service import _t as _email_t
from services.email_service import get_order_confirmation_email, get_seller_notification_email, send_email
from services.email_task import enqueue_email_task
from services.pdf_invoice_service import generate_invoice_pdf
from services.rate_limiter import RateLimiter
from services.shipping_service import calculate_shipping_cost, get_tax_rate
from utils.db import get_db, get_firestore, get_server_timestamp
from utils.function_options import DEFAULT_OPTIONS, PAYMENT_OPTIONS, WEBHOOK_OPTIONS

logger = logging.getLogger(__name__)

# stripe.api_key = STRIPE_SECRET_KEY  # Removed global assignment


def _check_premium_from_sub(uid: str) -> bool:
    """Check premium status from authoritative subscriptions doc, not cached user field.
    Called at checkout to gate free-shipping for premium buyers (line ~1394).
    """
    from utils.premium_check import is_premium_authoritative
    return is_premium_authoritative(uid, db=get_db())


def get_tax_code_for_category(category_id):
    """Map product categories to Stripe tax codes"""
    return CATEGORY_TAX_CODE_MAP.get(category_id)


# Province tax breakdown — derived from BusinessRules.TAX_RATES (single source of truth)
# BusinessRules.TAX_RATES uses percentages (5.0), we convert to ratios (0.05) for math
_PROVINCE_TAX_BREAKDOWN = {
    province: {name: rate / 100.0 for name, rate in taxes.items()}
    for province, taxes in BusinessRules.TAX_RATES.items()
}

# CRITICAL: Set timeout to 30s to prevent Cloud Function timeout (default is 80s)
# Cloud Functions timeout at 60s, so we need Stripe to timeout before that
stripe.max_network_retries = BusinessRules.STRIPE_MAX_NETWORK_RETRIES
# Note: stripe.default_http_client requires stripe-python v3+
# For v2, timeout is set per-request via stripe.api_requestor.APIRequestor
_rate_limiter = None

def _get_webhook_secret() -> str:
    return get_stripe_webhook_secret()


# CORS is configured in DEFAULT_OPTIONS via function_options.py


def get_rate_limiter():
    """Get RateLimiter instance (lazy initialization)."""
    global _rate_limiter
    if _rate_limiter is None:
        _rate_limiter = RateLimiter(get_db())
    return _rate_limiter


def get_transactional():
    """Get Firestore transactional decorator (lazy initialization)."""
    return get_firestore().transactional


def _get_seller_stripe_snapshot(order_id: str, order_data: dict) -> dict:
    """
    SECURITY FIX (HIGH-01): Read seller Stripe account snapshot from the backend-only
    private subcollection (`orders/{orderId}/_private/stripe`) instead of the main order doc.
    Returns empty dict if not found (callers then do live lookup from seller_profiles).
    """
    try:
        snap_doc = (
            get_db()
            .collection(Collections.ORDERS)
            .document(order_id)
            .collection("_private")
            .document("stripe")
            .get()
        )
        if snap_doc.exists:
            private_data = snap_doc.to_dict() or {}
            accounts = private_data.get(Fields.SELLER_STRIPE_ACCOUNTS)
            if accounts:
                return accounts
    except Exception as _e:
        logger.warning(f"Failed to read private stripe snapshot for order {order_id}: {_e}")
    return {}


def _assert_seller_active(seller_id: str, require_approval: bool = True) -> dict[str, Any]:
    """
    Validates that a seller exists and is active (not suspended).

    Args:
        seller_id: The Firebase Auth UID of the seller
        require_approval: If True, also checks Stripe onboarding completion

    Returns:
        Dict containing seller data

    Raises:
        https_fn.HttpsError: If seller is suspended or not properly onboarded
    """
    seller_ref = get_db().collection(Collections.USERS).document(seller_id)
    seller_doc = seller_ref.get()

    if not seller_doc.exists:
        raise https_fn.HttpsError("not-found", "Seller not found")

    seller_data = seller_doc.to_dict()

    if seller_data.get(Fields.SUSPENDED, False):
        raise https_fn.HttpsError(
            "permission-denied",
            f"Seller is suspended and cannot process orders [{ErrorCodes.SELL_ACCOUNT_SUSPENDED}]",
        )

    if require_approval:
        # Stripe Connect approval fields live in seller_profiles/{uid}
        sp_ref = get_db().collection(Collections.SELLER_PROFILES).document(seller_id)
        sp_doc = sp_ref.get()
        sp_data = sp_doc.to_dict() if sp_doc.exists else {}

        if not sp_data.get(Fields.ONBOARDING_COMPLETED, False):
            raise https_fn.HttpsError(
                "failed-precondition",
                f"Seller has not completed onboarding [{ErrorCodes.SELL_ONBOARDING_INCOMPLETE}]",
            )

        if not sp_data.get(Fields.CHARGES_ENABLED, False):
            raise https_fn.HttpsError(
                "failed-precondition",
                f"Seller is not approved to receive payments [{ErrorCodes.SELL_ONBOARDING_INCOMPLETE}]",
            )

        if not sp_data.get(Fields.PAYOUTS_ENABLED, False):
            raise https_fn.HttpsError(
                "failed-precondition",
                f"Seller payouts are not yet enabled [{ErrorCodes.SELL_PAYOUTS_DISABLED}]",
            )

    return seller_data


def _rollback_checkout(validated_items: list, order_ref, coupon_code: str | None = None, user_id: str | None = None) -> None:
    """Rollback stock reservation, coupon pre-reservation, and mark order as failed on checkout failure."""
    try:

        @get_transactional()
        def rollback_stock(transaction):
            # Phase 1: Read ALL product snapshots first
            """Function rollback_stock."""
            refs_and_snapshots = []
            for item in validated_items:
                product_ref = get_db().collection(Collections.PRODUCTS).document(item[Fields.PRODUCT_ID])
                product_snapshot = product_ref.get(transaction=transaction)
                refs_and_snapshots.append((
                    product_ref,
                    product_snapshot,
                    item[Fields.QUANTITY],
                    item.get(Fields.FULFILLMENT_WAREHOUSE_ID),  # Stamped at line 1462
                ))

            # Phase 2: Write ALL updates after all reads
            for ref, snapshot, qty, fulfillment_wh in refs_and_snapshots:
                if snapshot.exists:
                    _firestore = get_firestore()
                    patch = {Fields.STOCK_QUANTITY: _firestore.Increment(qty)}
                    if fulfillment_wh:
                        patch[f"{Fields.WAREHOUSE_STOCK}.{fulfillment_wh}"] = _firestore.Increment(qty)
                    transaction.update(ref, patch)
                    if fulfillment_wh:
                        inv_ref = ref.collection(Collections.INVENTORY_LEVELS).document(fulfillment_wh)
                        transaction.set(inv_ref, {
                            Fields.AVAILABLE_QUANTITY: _firestore.Increment(qty),
                            Fields.LAST_SYNCED_AT: get_server_timestamp(),
                        }, merge=True)

        transaction = get_db().transaction()
        rollback_stock(transaction)
    except Exception as rollback_err:
        logger.critical(f"🚨 CRITICAL: Stock rollback failed during checkout rollback: {rollback_err}")

    # AUDIT FIX (CRITICAL-C3): Roll back coupon pre-reservation on Stripe failure
    if coupon_code and user_id:
        try:
            _db = get_db()
            _fs = get_firestore()
            _cr = _db.collection(Collections.COUPONS).document(coupon_code)
            _ur = _cr.collection(Collections.COUPON_USES).document(user_id)

            @_fs.transactional
            def _undo_coupon_txn(_txn):
                _snap = _cr.get(transaction=_txn)
                if not _snap.exists:
                    return
                _used = int((_snap.to_dict() or {}).get(Fields.USED_COUNT, 0))
                _txn.update(_cr, {Fields.USED_COUNT: max(0, _used - 1)})
                _us = _ur.get(transaction=_txn)
                if _us.exists:
                    _uc = int((_us.to_dict() or {}).get("useCount", 1))
                    if _uc <= 1:
                        _txn.delete(_ur)
                    else:
                        _txn.update(_ur, {"useCount": _uc - 1})  # MEDIUM-3: was Fields.COUNT ("count"), wrong field

            _undo_coupon_txn(_db.transaction())
            logger.info(f"Coupon {coupon_code} pre-reservation rolled back for user {user_id}")
        except Exception as _ce:
            logger.error(f"Failed to rollback coupon {coupon_code} for user {user_id}: {_ce}")

    # Mark order as failed (keep for audit trail instead of deleting)
    try:
        order_ref.update(
            {
                Fields.ORDER_STATUS: OrderStatusValues.FAILED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.PAYMENT_FAILED,
                Fields.CANCELLATION_REASON: "Checkout session creation failed",
                Fields.STOCK_RESTORED: True,
                Fields.UPDATED_AT: get_server_timestamp(),
            }
        )
    except Exception as order_err:
        logger.critical(f"\U0001f6a8 CRITICAL: Order status rollback failed: {order_err}")


@https_fn.on_call(**DEFAULT_OPTIONS)
def verify_cart_prices(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    AUDIT FIX: Pre-checkout cart price verification.

    Checks if any cart item prices/stock/availability have changed since the
    user added them. Frontend should call this BEFORE initiating checkout to
    detect stale prices and update the cart UI.

    This prevents the critical bug where a user proceeds to checkout with
    outdated prices, only to get a hard error at payment time.

    Request data:
        items: List of {productId, price, quantity}

    Returns:
        {
            success: True,
            hasChanges: bool,
            priceChanges: [{productId, name, oldPrice, newPrice}],
            stockChanges: [{productId, name, requested, available}],
            removedProducts: [{productId}]
        }
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    # Rate limit: 10/min (called before checkout)
    allowed, message = get_rate_limiter().check_rate_limit(
        identifier=req.auth.uid, action=RateLimitActions.VERIFY_CART, max_requests=10, window_minutes=1, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", message)

    items = req.data.get(Fields.ITEMS, [])
    if not items:
        raise https_fn.HttpsError("invalid-argument", "No items to verify")

    price_changes = []
    stock_changes = []
    removed_products = []

    # Batch read all product documents to avoid N+1 reads
    _batch_refs = [
        get_db().collection(Collections.PRODUCTS).document(item.get(Fields.PRODUCT_ID))
        for item in items
        if item.get(Fields.PRODUCT_ID)
    ]
    product_docs_map: dict = {}
    if _batch_refs:
        for _doc in get_db().get_all(_batch_refs):
            product_docs_map[_doc.id] = _doc

    for item in items:
        product_id = item.get(Fields.PRODUCT_ID)
        client_price = item.get(Fields.PRICE, 0)
        requested_qty = item.get(Fields.QUANTITY, 1)

        if not product_id:
            continue

        product_doc = product_docs_map.get(product_id)
        if not product_doc or not product_doc.exists:
            removed_products.append({Fields.PRODUCT_ID: product_id})
            continue

        product_data = product_doc.to_dict()

        # Check if product is still active
        if product_data.get(Fields.LIFECYCLE_STATUS) != ProductLifecycleStatusValues.ACTIVE:
            removed_products.append(
                {
                    Fields.PRODUCT_ID: product_id,
                    Fields.NAME: product_data.get(Fields.NAME, ""),
                    Fields.REASON: CartVerificationReasonValues.DEACTIVATED,
                }
            )
            continue

        # Check price change — cents-based comparison avoids float precision issues
        db_price = product_data.get(Fields.PRICE, 0)
        db_price_cents = round(db_price * 100)
        client_price_cents = round(client_price * 100)
        if abs(db_price_cents - client_price_cents) > 1:
            price_changes.append(
                {
                    Fields.PRODUCT_ID: product_id,
                    Fields.NAME: product_data.get(Fields.NAME, ""),
                    ApiKeys.OLD_PRICE: client_price,
                    ApiKeys.NEW_PRICE: db_price,
                }
            )

        # Check stock availability
        stock_qty = product_data.get(Fields.STOCK_QUANTITY, 0)
        if stock_qty < requested_qty:
            stock_changes.append(
                {
                    Fields.PRODUCT_ID: product_id,
                    Fields.NAME: product_data.get(Fields.NAME, ""),
                    ApiKeys.REQUESTED: requested_qty,
                    ApiKeys.AVAILABLE: stock_qty,
                }
            )

    has_changes = len(price_changes) > 0 or len(stock_changes) > 0 or len(removed_products) > 0

    from utils.helpers import create_success_response

    return create_success_response(
        {
            ApiKeys.HAS_CHANGES: has_changes,
            ApiKeys.PRICE_CHANGES: price_changes,
            ApiKeys.STOCK_CHANGES: stock_changes,
            ApiKeys.REMOVED_PRODUCTS: removed_products,
        }
    )


def get_item_tax_rate(item, province):
    """Get tax rate for an item based on category and province"""
    tax_code = item.get(Fields.TAX_CODE)

    # Children's clothing exempt in some provinces
    if tax_code == STRIPE_TAX_CODE_CHILDRENS_CLOTHING and province in BusinessRules.CHILDRENS_CLOTHING_EXEMPT_PROVINCES:
        return 0.0

    # Basic groceries exempt in all provinces
    if tax_code == STRIPE_TAX_CODE_BASIC_GROCERIES:
        return 0.0

    # Default province tax rate
    return get_tax_rate(province)


def calculate_tax_with_stripe(validated_items, shipping_address, shipping_cost_cents, gst_number=None):
    """
    Calculate tax using Stripe Tax API.

    Args:
        gst_number: Canadian GST/HST number for B2B exemption (e.g., '123456789RT0001')

    Returns (tax_amount_cents, tax_breakdown, line_items_with_tax, is_reverse_charge)
    """
    try:
        line_items = []
        for item in validated_items:
            # F-129: Small Suppliers (<$30k revenue) are exempt from collecting GST/HST
            if item.get(Fields.IS_SMALL_SUPPLIER, False):
                logger.info(f"F-129: Skipping tax for item {item[Fields.PRODUCT_ID]} (Small Supplier)")
                continue

            # Get tax code from category mapping
            category_id = item.get(Fields.CATEGORY_ID, 0)
            tax_code = CATEGORY_TAX_CODE_MAP.get(category_id, BusinessRules.TAX_CODE_GENERAL_GOODS)

            line_items.append(
                {
                    StripeConstants.TAX_CALC_AMOUNT: round(item[Fields.PRICE] * 100) * item[Fields.QUANTITY],
                    StripeConstants.TAX_CALC_REFERENCE: item[Fields.PRODUCT_ID],
                    StripeConstants.TAX_CALC_TAX_CODE: tax_code,
                }
            )

        # Add shipping as line item
        if shipping_cost_cents > 0:
            line_items.append(
                {
                    StripeConstants.TAX_CALC_AMOUNT: shipping_cost_cents,
                    StripeConstants.TAX_CALC_REFERENCE: StripeConstants.SHIPPING_REFERENCE,
                    StripeConstants.TAX_CALC_TAX_CODE: BusinessRules.TAX_CODE_SHIPPING,  # Shipping tax code
                }
            )

        # Build customer details
        customer_details = {
            Fields.ADDRESS: {
                Fields.STREET: shipping_address.get(Fields.STREET, ""),
                Fields.CITY: shipping_address.get(Fields.CITY, ""),
                Fields.STATE: shipping_address.get(Fields.STATE, ""),
                Fields.POSTAL_CODE: shipping_address.get(Fields.POSTAL_CODE, ""),
                Fields.COUNTRY: AppConfig.DEFAULT_COUNTRY_CODE,
            },
            StripeConstants.ADDRESS_SOURCE: StripeConstants.ADDRESS_SOURCE_SHIPPING,
        }

        # Add GST number for B2B validation (Stripe will validate and apply reverse charge if valid)
        if gst_number:
            customer_details[StripeConstants.CUSTOMER_TAX_ID] = {
                Fields.TYPE: BusinessRules.STRIPE_TAX_TYPE_CA_GST_HST,  # Canadian GST/HST
                StripeConstants.VALUE: gst_number,
            }
            customer_details[StripeConstants.CUSTOMER_TAX_EXEMPT] = StripeConstants.TAX_EXEMPT_NONE  # Let Stripe determine

        # Call Stripe Tax API
        ensure_stripe_key()
        calculation = stripe.tax.Calculation.create(
            currency=BusinessRules.DEFAULT_CURRENCY,
            customer_details=customer_details,
            line_items=line_items,
        )

        # Stripe Tax returns amounts in cents — convert to dollars for consistency with manual calc
        tax_breakdown = {
            StripeConstants.TAX_TYPE_MAP.get(detail.tax_type, detail.tax_type.upper()): detail.amount / 100.0
            for detail in calculation.tax_breakdown
        }
        # Also convert tax_amount_cents from the Stripe response (already in cents, rename for clarity)
        tax_amount_cents = calculation.tax_amount_exclusive

        # Build item_taxes from Stripe calculation for consistency
        item_taxes = []
        for line_item in calculation.line_items.data:
            if line_item.reference != StripeConstants.SHIPPING_REFERENCE:
                item_taxes.append(
                    {
                        Fields.PRODUCT_ID: line_item.reference,
                        Fields.TAX_CENTS: line_item.amount_tax,
                        Fields.TAX_RATE: (line_item.amount_tax / line_item.amount) if line_item.amount > 0 else 0,
                    }
                )

        # Check if Stripe applied reverse charge (B2B exemption)
        is_reverse_charge = False
        customer_details = getattr(calculation, "customer_details", None)
        if customer_details:
            is_reverse_charge = getattr(customer_details, StripeConstants.CUSTOMER_TAX_EXEMPT, None) == StripeConstants.REVERSE_CHARGE

        return tax_amount_cents, tax_breakdown, item_taxes, is_reverse_charge

    except Exception as e:
        logger.error(f"Stripe Tax API error: {e}")
        # Fall back to manual calculation
        return None, None, None, False


# Helper to ensure stripe key is set before operations
def ensure_stripe_key():
    """Lazily initialize the Stripe API key from Secret Manager if not already set."""
    if not stripe.api_key:
        stripe.api_key = get_stripe_secret_key()


# ---------------------------------------------------------------------------
# Coupon validation helpers (used inside create_checkout_session)
# ---------------------------------------------------------------------------

def _coupon_not_expired(coupon_data: dict) -> bool:
    """Check whether a coupon is still within its validity period.

    Args:
        coupon_data: Coupon document dict from Firestore.

    Returns:
        True if the coupon has no expiry or has not yet expired.
    """
    expires_at = coupon_data.get(Fields.EXPIRES_AT)
    if expires_at is None:
        return True
    now_utc = datetime.now(UTC)
    if hasattr(expires_at, "ToDatetime"):
        expires_dt = expires_at.ToDatetime().replace(tzinfo=UTC)
    elif hasattr(expires_at, "astimezone"):
        expires_dt = expires_at.astimezone(UTC)
    else:
        return True
    return now_utc <= expires_dt


def _coupon_within_limits(coupon_data: dict, user_id: str) -> bool:
    """Check whether a coupon has not exceeded its global or per-user usage cap.

    Args:
        coupon_data: Coupon document dict from Firestore.
        user_id: The UID of the buyer applying the coupon.

    Returns:
        True if both the global usage count and per-user count are within limits.
    """
    max_uses_total = coupon_data.get(Fields.MAX_USES_TOTAL)
    used_count = int(coupon_data.get(Fields.USED_COUNT, 0))
    if max_uses_total is not None and used_count >= int(max_uses_total):
        return False
    coupon_code = coupon_data.get(Fields.COUPON_CODE, "")
    max_uses_per_user = int(coupon_data.get(Fields.MAX_USES_PER_USER, 1))
    if coupon_code:
        use_snap = (
            get_db()
            .collection(Collections.COUPONS)
            .document(coupon_code)
            .collection(Collections.COUPON_USES)
            .document(user_id)
            .get()
        )
        user_count = int(use_snap.to_dict().get("useCount", 0)) if use_snap.exists else 0
        if user_count >= max_uses_per_user:
            return False
    return True


def _coupon_seller_allowed(coupon_data: dict, sellers: set) -> bool:
    """Check whether a coupon is valid for the sellers present in the cart.

    Args:
        coupon_data: Coupon document dict from Firestore.
        sellers: Set of seller IDs from the buyer's current cart.

    Returns:
        True if the coupon is platform-wide (no sellerId) or belongs to a seller in the cart.
    """
    coupon_seller_id = coupon_data.get(Fields.SELLER_ID)
    if coupon_seller_id is None:
        return True  # Platform-wide coupon
    return coupon_seller_id in sellers


def _coupon_min_order_met(coupon_data: dict, actual_subtotal_cents: int) -> bool:
    """Check whether the cart subtotal meets the coupon's minimum order requirement.

    Args:
        coupon_data: Coupon document dict from Firestore.
        actual_subtotal_cents: Buyer's cart subtotal in cents (already in cents).

    Returns:
        True if no minimum is configured or if the subtotal meets the threshold.
    """
    min_order_cents = coupon_data.get(Fields.MIN_ORDER_CENTS)
    if min_order_cents is None:
        return True
    return actual_subtotal_cents >= int(min_order_cents)


def _build_stock_reservation_plan(
    validated_items: list[dict[str, Any]],
    product_data_by_id: dict[str, dict[str, Any]],
    inventory_candidates: dict[str, list[tuple[str, int]]],
) -> dict[str, Any]:
    """
    Build a deterministic stock reservation plan for checkout.

    This avoids duplicate-line under-reservation by aggregating decrements per
    product and simulating warehouse consumption in-memory before write phase.
    """
    stock_deduct_by_product: dict[str, int] = {}
    warehouse_deduct_by_product: dict[str, dict[str, int]] = {}
    item_warehouse_by_index: dict[int, str] = {}
    variant_state_by_product: dict[str, list[dict[str, Any]]] = {}

    remaining_stock_by_product: dict[str, int] = {}
    allow_backorder_by_product: dict[str, bool] = {}
    remaining_inventory_by_product: dict[str, dict[str, int]] = {}

    for product_id, product_data in product_data_by_id.items():
        remaining_stock_by_product[product_id] = int(product_data.get(Fields.STOCK_QUANTITY, 0) or 0)
        allow_backorder_by_product[product_id] = bool(
            (product_data.get(Fields.INVENTORY, {}) or {}).get(Fields.ALLOW_BACKORDER, False)
        )
        variants = product_data.get(Fields.VARIANTS, [])
        if isinstance(variants, list):
            variant_state_by_product[product_id] = [dict(v) for v in variants if isinstance(v, dict)]
        else:
            variant_state_by_product[product_id] = []
        remaining_inventory_by_product[product_id] = {
            wh_id: int(avail or 0) for wh_id, avail in inventory_candidates.get(product_id, [])
        }

    for item_index, item in enumerate(validated_items):
        product_id = item[Fields.PRODUCT_ID]
        product_data = product_data_by_id.get(product_id)
        if not product_data:
            raise https_fn.HttpsError("not-found", f"Product {product_id} not found")

        qty = int(item.get(Fields.QUANTITY, 0) or 0)
        if qty <= 0:
            raise https_fn.HttpsError("invalid-argument", f"Invalid quantity for product {product_id}")

        variant_id = item.get(Fields.VARIANT_ID)
        if product_data.get(Fields.HAS_VARIANTS, False) and not variant_id:
            raise https_fn.HttpsError(
                "invalid-argument",
                f"Product {product_data.get(Fields.NAME, product_id)} has variants — selection required",
            )

        if item.get(Fields.IS_DIGITAL, False):
            continue

        allow_backorder = allow_backorder_by_product.get(product_id, False)

        item_wh_id = None
        wh_remaining = remaining_inventory_by_product.get(product_id, {})
        if wh_remaining:
            for wh_id, available in sorted(wh_remaining.items(), key=lambda kv: kv[1], reverse=True):
                if available >= qty:
                    item_wh_id = wh_id
                    wh_remaining[wh_id] = available - qty
                    break

        if item_wh_id is None and not allow_backorder:
            remaining_stock = remaining_stock_by_product.get(product_id, 0)
            if remaining_stock < qty:
                raise https_fn.HttpsError(
                    "resource-exhausted",
                    f"Insufficient stock for {product_data.get(Fields.NAME, product_id)}",
                )

        remaining_stock_by_product[product_id] = remaining_stock_by_product.get(product_id, 0) - qty
        stock_deduct_by_product[product_id] = stock_deduct_by_product.get(product_id, 0) + qty

        if item_wh_id:
            by_wh = warehouse_deduct_by_product.setdefault(product_id, {})
            by_wh[item_wh_id] = by_wh.get(item_wh_id, 0) + qty
            item_warehouse_by_index[item_index] = item_wh_id

        if variant_id:
            variants = variant_state_by_product.get(product_id, [])
            variant_idx = next((idx for idx, v in enumerate(variants) if v.get(Fields.VARIANT_ID) == variant_id), None)
            if variant_idx is not None:
                variant_stock = int(variants[variant_idx].get(Fields.STOCK_QUANTITY, 0) or 0)
                if not allow_backorder and variant_stock < qty:
                    raise https_fn.HttpsError(
                        "resource-exhausted",
                        f"Insufficient stock for {product_data.get(Fields.NAME, product_id)} variant",
                    )
                variants[variant_idx][Fields.STOCK_QUANTITY] = variant_stock - qty

    return {
        "stock_deduct_by_product": stock_deduct_by_product,
        "warehouse_deduct_by_product": warehouse_deduct_by_product,
        "item_warehouse_by_index": item_warehouse_by_index,
        "variant_state_by_product": variant_state_by_product,
    }




@https_fn.on_call(**PAYMENT_OPTIONS)
def create_checkout_session(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Creates a Stripe Checkout session with server-side validation.

    Security features:
    - Price validation (server-side fetch from Firestore)
    - Stock availability check (atomic transactions)
    - Rate limiting (5 requests per minute per user)
    - Subtotal verification (1% tolerance)
    - Shipping/tax recalculation

    Request data:
        items: List of {productId, quantity, price, name, imageUrl, sellerId}
        shippingAddress: {street, city, province, postalCode, country}
        userId: Firebase Auth UID

    Returns:
        {
            sessionId: Stripe Checkout Session ID
            orderId: Firestore order document ID
            success: True
        }

    Raises:
        https_fn.HttpsError: For validation errors, insufficient stock, etc.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    # Honor admin provider toggles before creating any order/session state.
    from handlers.payment_providers import PaymentProvider, require_provider_enabled

    require_provider_enabled(PaymentProvider.STRIPE)
    ensure_stripe_key()

    # Check email verification (skip in emulator mode - tokens may not carry email_verified)
    if not IS_EMULATOR and not req.auth.token.get("email_verified", False):
        raise https_fn.HttpsError("permission-denied", "Please verify your email address before making a purchase.")

    user_id = req.auth.uid
    data = req.data

    # Security: Check if user is suspended
    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_snapshot = user_ref.get()
    user_data = user_snapshot.to_dict() if user_snapshot.exists else {}
    if user_data.get(Fields.SUSPENDED, False):
        raise https_fn.HttpsError(
            "permission-denied",
            f"Account suspended. Cannot proceed with checkout. [{ErrorCodes.SELL_ACCOUNT_SUSPENDED}]",
        )

    # Get GST number for B2B validation (Stripe Tax will validate it)
    tax_exemption = user_data.get(Fields.TAX_EXEMPTION)
    gst_number = tax_exemption.get(Fields.GST_NUMBER) if tax_exemption else None

    # Rate limiting: 5 requests per minute per user
    allowed, message = get_rate_limiter().check_rate_limit(
        identifier=user_id, action=RateLimitActions.CREATE_CHECKOUT, max_requests=5, window_minutes=1, fail_closed=True
    )

    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", message)

    # === EARLY VALIDATION (BEFORE DB HITS) ===
    items = data.get(Fields.ITEMS, [])
    shipping_address = data.get(Fields.SHIPPING_ADDRESS, {})

    # COMPLIANCE (HIGH): EULA acceptance required for digital products before delivery
    eula_accepted = data.get(ApiKeys.EULA_ACCEPTED, False)
    has_digital_items = any(item.get(Fields.IS_DIGITAL, False) for item in items if isinstance(item, dict))
    if has_digital_items and not eula_accepted:
        raise https_fn.HttpsError(
            "failed-precondition",
            "You must accept the End User License Agreement (EULA) before purchasing digital products.",
        )

    # COMPLIANCE (HIGH): Age verification required for age-restricted products (Canadian provincial law)
    age_verification_accepted = data.get(ApiKeys.AGE_VERIFICATION_ACCEPTED, False)
    has_age_restricted_items = any(item.get(Fields.IS_AGE_RESTRICTED, False) for item in items if isinstance(item, dict))
    if has_age_restricted_items and not age_verification_accepted:
        raise https_fn.HttpsError(
            "failed-precondition",
            "You must confirm you are 18 or older before purchasing age-restricted products.",
        )

    if not items or not isinstance(items, list):
        raise https_fn.HttpsError("invalid-argument", "No items in cart or invalid items format")

    for item in items:
        if not isinstance(item, dict):
            raise https_fn.HttpsError("invalid-argument", "Invalid item format")
        if not item.get(Fields.PRODUCT_ID):
            raise https_fn.HttpsError("invalid-argument", "Each item must have a productId")

        qty = item.get(Fields.QUANTITY, 1)
        if not isinstance(qty, int) or qty <= 0:
            raise https_fn.HttpsError("invalid-argument", f"Invalid quantity for product {item.get(Fields.PRODUCT_ID)}")
        if qty > ValidationLimits.MAX_ITEM_QUANTITY:
            raise https_fn.HttpsError("invalid-argument", f"Quantity for {item.get(Fields.PRODUCT_ID)} exceeds limit (100)")

    # F-317: Client MUST send integer cents — no float conversion
    client_subtotal_cents_raw = data.get(ApiKeys.SUBTOTAL_CENTS)
    if not isinstance(client_subtotal_cents_raw, int):
        raise https_fn.HttpsError("invalid-argument", "subtotalCents must be an integer")
    client_subtotal_cents = client_subtotal_cents_raw

    if client_subtotal_cents < 0:
        raise https_fn.HttpsError("invalid-argument", "Subtotal cannot be negative")
    if client_subtotal_cents > ValidationLimits.MAX_CHECKOUT_SUBTOTAL_CENTS:
        raise https_fn.HttpsError("invalid-argument", "Subtotal exceeds maximum allowed ($100,000)")

    # Shipping address validation (required for non-digital items, but checked early for consistency)
    if not shipping_address or not isinstance(shipping_address, dict):
        raise https_fn.HttpsError("invalid-argument", "Shipping address is required")

    # Required address fields for physical delivery
    required_address_fields = [Fields.STREET, Fields.CITY, Fields.STATE, Fields.POSTAL_CODE, Fields.COUNTRY]
    if not all(shipping_address.get(f) for f in required_address_fields):
        raise https_fn.HttpsError("invalid-argument", "Shipping address is incomplete")

    # Country restriction: Canadian buyers only
    country = (shipping_address.get(Fields.COUNTRY) or "").strip().upper()
    if country not in ("CA", "CANADA"):
        raise https_fn.HttpsError("invalid-argument", "Shipping is only available within Canada")

    # Postal code format validation
    postal_code = shipping_address.get(Fields.POSTAL_CODE, "")
    try:
        from utils.helpers import validate_postal_code
        validate_postal_code(postal_code)
    except (ValueError, Exception) as e:
        raise https_fn.HttpsError("invalid-argument", "Invalid Canadian postal code format") from e

    # Province validation
    province_code = (shipping_address.get(Fields.STATE) or "").strip().upper()
    if province_code not in BusinessRules.VALID_PROVINCES:
        raise https_fn.HttpsError(
            "invalid-argument",
            f"Invalid province '{province_code}'. Must be one of: {', '.join(sorted(BusinessRules.VALID_PROVINCES))}",
        )

    # Address field length limits (anti-injection)
    for addr_field in [Fields.STREET, Fields.CITY, Fields.STATE, Fields.POSTAL_CODE]:
        val = shipping_address.get(addr_field, "")
        if isinstance(val, str) and len(val) > 200:
            raise https_fn.HttpsError("invalid-argument", f"Address field '{addr_field}' is too long")

    client_idempotency_key = data.get(ApiKeys.IDEMPOTENCY_KEY)
    # Derive a deterministic key to prevent retries from changing the idempotency token.
    # A randomly-generated order id as fallback is useless — it changes every call.
    if not client_idempotency_key:
        import hashlib
        _cart_fingerprint = "|".join(sorted(
            f"{item.get(Fields.PRODUCT_ID, '')}:{item.get(Fields.QUANTITY, 1)}"
            for item in items
        ))
        _raw = f"checkout:{user_id}:{_cart_fingerprint}"
        client_idempotency_key = "auto_" + hashlib.sha256(_raw.encode()).hexdigest()[:32]

    # --- SERVER-SIDE PRODUCT VALIDATION ---
    # F-01:Authoritative price check. Never trust client-supplied prices.
    # F-02:Atomic stock check (implemented in transaction below).
    validated_items = []
    actual_subtotal_cents = 0
    sellers = set()

    # Batch fetch all products for efficiency (Max 30 items per cart)
    product_ids = [item.get(Fields.PRODUCT_ID) for item in items if item.get(Fields.PRODUCT_ID)]
    if not product_ids:
        raise https_fn.HttpsError("invalid-argument", "No valid product IDs in cart")

    db = get_db()
    product_docs = {
        d.id: d.to_dict()
        for d in db.get_all([db.collection(Collections.PRODUCTS).document(pid) for pid in product_ids])
        if d.exists
    }

    # Batch fetch all seller documents
    seller_ids = list({p.get(Fields.SELLER_ID) for p in product_docs.values() if p.get(Fields.SELLER_ID)})
    seller_docs = {
        d.id: d.to_dict()
        for d in db.get_all([db.collection(Collections.USERS).document(sid) for sid in seller_ids])
        if d.exists
    }

    # Batch fetch seller_profiles (onboardingCompleted + chargesEnabled live here).
    # Pre-fetching outside the item loop prevents an N+1 Firestore read pattern.
    seller_profile_docs_pre = {
        d.id: (d.to_dict() if d.exists else {})
        for d in db.get_all([db.collection(Collections.SELLER_PROFILES).document(sid) for sid in seller_ids])
    }

    for item in items:
        pid = item.get(Fields.PRODUCT_ID)
        p_data = product_docs.get(pid)
        if not p_data:
            raise https_fn.HttpsError("not-found", f"Product {pid} not found [{ErrorCodes.ORD_NOT_FOUND}]")

        # Security: Check if product is active
        if p_data.get(Fields.LIFECYCLE_STATUS) != ProductLifecycleStatusValues.ACTIVE:
            raise https_fn.HttpsError(
                "failed-precondition",
                f"Product {p_data.get(Fields.NAME, pid)} is not currently available for purchase"
                f" [{ErrorCodes.PAY_PRODUCT_UNAVAILABLE}]",
            )

        # Security: check if seller is active
        sid = p_data.get(Fields.SELLER_ID)

        # Self-purchase prevention
        if sid == user_id:
            raise https_fn.HttpsError(
                "invalid-argument",
                f"You cannot purchase your own product ({p_data.get(Fields.NAME, pid)})"
                f" [{ErrorCodes.PERM_SELF_PURCHASE}]",
            )

        # AUDIT FIX: Validate client sellerId matches server-side sellerId
        # Prevents client from trying to redirect payments by sending wrong sellerId
        client_sid = item.get(Fields.SELLER_ID)
        if client_sid and client_sid != sid:
             raise https_fn.HttpsError(
                 "invalid-argument",
                 f"Seller ID mismatch for product {pid}"
             )

        s_data = seller_docs.get(sid) or {}
        if s_data.get(Fields.SUSPENDED, False):
            raise https_fn.HttpsError(
                "failed-precondition",
                f"Seller for {p_data.get(Fields.NAME)} is currently inactive [{ErrorCodes.PAY_SELLER_SUSPENDED}]",
            )

        # Seller onboarding check — ensure seller can receive payments
        # Uses pre-fetched batch (seller_profile_docs_pre) to avoid per-item Firestore reads.
        sp_data = seller_profile_docs_pre.get(sid, {})
        if not sp_data.get(Fields.ONBOARDING_COMPLETED, False):
            raise https_fn.HttpsError(
                "failed-precondition",
                f"Seller for {p_data.get(Fields.NAME, pid)} has not completed onboarding"
            )
        if not sp_data.get(Fields.CHARGES_ENABLED, False):
            raise https_fn.HttpsError(
                "failed-precondition",
                f"Seller for {p_data.get(Fields.NAME, pid)} is not approved to receive payments"
            )

        # Authoritative price lookup
        price_cents = round(p_data.get(Fields.PRICE, 0) * 100)
        qty = int(item.get(Fields.QUANTITY, 1))
        actual_subtotal_cents += price_cents * qty
        sellers.add(sid)

        # Explicit field construction — NEVER use **item (client data injection risk)
        validated_item = {
            Fields.PRODUCT_ID: pid,
            Fields.QUANTITY: qty,
            Fields.PRICE: p_data.get(Fields.PRICE),
            Fields.NAME: p_data.get(Fields.NAME),
            Fields.IMAGE_URLS: p_data.get(Fields.IMAGE_URLS, []),
            Fields.SELLER_ID: sid,
            Fields.IS_DIGITAL: p_data.get(Fields.IS_DIGITAL, False),
            Fields.IS_SMALL_SUPPLIER: s_data.get(Fields.IS_SMALL_SUPPLIER, False),
            Fields.TAX_CODE: p_data.get(Fields.TAX_CODE, ""),
            Fields.FREE_SHIPPING: p_data.get(Fields.FREE_SHIPPING, False),
            Fields.WEIGHT_KG: p_data.get(Fields.WEIGHT_KG, 0),
            Fields.IS_PERISHABLE: p_data.get(Fields.IS_PERISHABLE, False),
            Fields.IS_LOCAL_DELIVERY_ONLY: p_data.get(Fields.IS_LOCAL_DELIVERY_ONLY, False),
            Fields.IS_INTERNATIONAL: p_data.get(Fields.IS_INTERNATIONAL, False),
            Fields.SUPPLIER_TYPE: p_data.get(Fields.SUPPLIER_TYPE, ""),
            Fields.SELLER_ADDRESS: p_data.get(Fields.SELLER_ADDRESS, {}),
            Fields.SHIP_FROM_PROVINCE: p_data.get(Fields.SHIP_FROM_PROVINCE, ""),
            Fields.CATEGORY_ID: p_data.get(Fields.CATEGORY_ID, 0),
            Fields.STATUS: DeliveryStatusValues.PENDING,
            Fields.CART_ITEM_ID: item.get(Fields.CART_ITEM_ID) or str(uuid.uuid4()),
            Fields.TRACKING_NUMBER: "",
            Fields.CARRIER: "",
            Fields.SHIPPED_AT: None,
            Fields.DELIVERED_AT: None,
            Fields.CONFIRMED_BY_BUYER: False,
        }
        # Include variant info only from client (server doesn't store variant selection)
        if item.get(Fields.VARIANT_ID):
            validated_item[Fields.VARIANT_ID] = item[Fields.VARIANT_ID]
            validated_item[Fields.VARIANT_TITLE] = item.get(Fields.VARIANT_TITLE, "")
            validated_item[Fields.VARIANT_OPTIONS] = item.get(Fields.VARIANT_OPTIONS, {})
            validated_item[Fields.VARIANT_SKU] = item.get(Fields.VARIANT_SKU, "")
        validated_items.append(validated_item)

    # Tolerance check: max 1 cent per item for rounding variances
    max_drift_cents = len(items)
    if abs(actual_subtotal_cents - client_subtotal_cents) > max_drift_cents:
        raise https_fn.HttpsError(
            "invalid-argument",
            f"Cart total mismatch or Price changed. Expected ${actual_subtotal_cents/100:.2f}"
        )

    # Initialize discount variables early to avoid NameError in shipping calculation
    discount_amount_cents = 0
    discounted_subtotal_cents = actual_subtotal_cents
    coupon_code = None
    coupon_seller_id = None

    # Apply coupon discount server-side — re-validate and compute (never trust client amount)
    coupon_code_input = (data.get(Fields.COUPON_CODE) or "").strip().upper() or None  # LOW-5: normalize
    if coupon_code_input:
        coupon_doc = get_db().collection(Collections.COUPONS).document(coupon_code_input).get()
        if not coupon_doc.exists:
            raise https_fn.HttpsError("not-found", "Coupon not found or has been removed.")
        c_data = coupon_doc.to_dict() or {}
        if not _coupon_not_expired(c_data):
            raise https_fn.HttpsError("failed-precondition", "Coupon has expired.")
        if not _coupon_within_limits(c_data, user_id):
            raise https_fn.HttpsError("resource-exhausted", "Coupon usage limit reached.")
        if not _coupon_seller_allowed(c_data, sellers):
            raise https_fn.HttpsError("failed-precondition", "Coupon is not valid for items in your cart.")
        if not _coupon_min_order_met(c_data, actual_subtotal_cents):
            raise https_fn.HttpsError("failed-precondition", "Order does not meet the coupon minimum requirement.")
        # HIGH-3: use shared _compute_discount (enforces MIN_CHECKOUT_TOTAL + MAX_COUPON_RATIO caps)
        discount_amount_cents = _coupon_compute_discount(c_data, actual_subtotal_cents)
        discounted_subtotal_cents = actual_subtotal_cents - discount_amount_cents
        coupon_code = coupon_code_input
        coupon_seller_id = c_data.get(Fields.SELLER_ID)  # None = platform-wide

    # Detect all-digital cart early — bypasses physical shipping/address rules.
    # NOTE: isDigital is re-verified server-side per item during product validation below.
    # Recompute all_digital from server-verified validated_items — never trust client payload
    all_digital = all(item.get(Fields.IS_DIGITAL, False) for item in validated_items)

    if all_digital:
        # Digital-only orders: worldwide delivery, zero shipping, zero Canadian tax
        delivery_speed = DeliveryTypeValues.STANDARD
        delivery_instructions = ""
        shipping_cost_cents = 0
        tax_amount_cents = 0
        taxes_breakdown = {}
        item_taxes = []
        state_code = shipping_address.get(Fields.STATE, BusinessRules.DEFAULT_PROVINCE)
        is_reverse_charge = False
    else:
        # Calculate shipping (server-side) - returns dollars
        delivery_speed = data.get(Fields.DELIVERY_SPEED, DeliveryTypeValues.STANDARD)
        if delivery_speed not in DeliveryTypeValues.ALL:
            delivery_speed = DeliveryTypeValues.STANDARD

        delivery_instructions = data.get(Fields.DELIVERY_INSTRUCTIONS, "")
        if delivery_instructions and len(delivery_instructions) > BusinessRules.MAX_DELIVERY_INSTRUCTIONS_LENGTH:
            delivery_instructions = delivery_instructions[: BusinessRules.MAX_DELIVERY_INSTRUCTIONS_LENGTH]

        try:
            physical_items = [i for i in validated_items if not i.get(Fields.IS_DIGITAL, False)]
            shipping_cost_dollars, shipping_breakdown_dollars = calculate_shipping_cost(
                physical_items, shipping_address, speed=delivery_speed
            )
            shipping_cost_cents = round(shipping_cost_dollars * 100)

            # Map breakdown to validated_items (before zeroing for threshold to keep record)
            for v_item in validated_items:
                item_key = v_item.get(Fields.CART_ITEM_ID) or v_item.get(Fields.PRODUCT_ID)
                v_item[Fields.ITEM_SHIPPING_CENTS] = round(shipping_breakdown_dollars.get(item_key, 0) * 100)

            # CRITICAL-C12: Backend Free Shipping Threshold Enforcement
            if discounted_subtotal_cents >= BusinessRules.FREE_SHIPPING_THRESHOLD_CENTS:
                shipping_cost_cents = 0
                for v_item in validated_items:
                    v_item[Fields.ITEM_SHIPPING_CENTS] = 0
            elif _check_premium_from_sub(user_id):
                shipping_cost_cents = 0
                for v_item in validated_items:
                    v_item[Fields.ITEM_SHIPPING_CENTS] = 0
        except ValueError as e:
            raise https_fn.HttpsError("invalid-argument", str(e)) from e
        except Exception as e:
            logger.error(f"Shipping calculation error: {str(e)}")
            raise https_fn.HttpsError("internal", "Shipping calculation failed. Please try again.") from e

        # Calculate taxes per-item
        state_code = shipping_address.get(Fields.STATE, BusinessRules.DEFAULT_PROVINCE)

    if not all_digital:
        if STRIPE_TAX_ENABLED:
            tax_result = calculate_tax_with_stripe(validated_items, shipping_address, shipping_cost_cents, gst_number)
            if tax_result[0] is not None:
                tax_amount_cents, taxes_breakdown, item_taxes, is_reverse_charge = tax_result
            else:
                # Fallback to manual calculation
                discount_ratio = discounted_subtotal_cents / actual_subtotal_cents if actual_subtotal_cents > 0 else 1.0
                tax_amount_cents = 0
                item_taxes = []
                for item in validated_items:
                    item_subtotal_cents = round(int(item[Fields.PRICE] * 100) * item[Fields.QUANTITY] * discount_ratio)
                    item_tax_rate = get_item_tax_rate(item, state_code)
                    if item.get(Fields.IS_SMALL_SUPPLIER, False):
                        item_tax_rate = 0.0
                    item_tax_cents = round(item_subtotal_cents * item_tax_rate)
                    tax_amount_cents += item_tax_cents
                    item_taxes.append({Fields.PRODUCT_ID: item[Fields.PRODUCT_ID], Fields.TAX_CENTS: item_tax_cents, Fields.TAX_RATE: item_tax_rate})

                if shipping_cost_cents > 0:
                    shipping_tax_rate = get_tax_rate(state_code)
                    tax_amount_cents += round(shipping_cost_cents * shipping_tax_rate)

                taxable_total_cents = discounted_subtotal_cents + shipping_cost_cents
                province_rates = _PROVINCE_TAX_BREAKDOWN.get(state_code, _PROVINCE_TAX_BREAKDOWN.get(BusinessRules.DEFAULT_PROVINCE, {"GST": 0.05}))
                taxes_breakdown = {name: round(taxable_total_cents * rate) / 100 for name, rate in province_rates.items()}
                is_reverse_charge = False
        else:
            # Calculate per-item tax (manual calculation)
            discount_ratio = discounted_subtotal_cents / actual_subtotal_cents if actual_subtotal_cents > 0 else 1.0
            tax_amount_cents = 0
            item_taxes = []
            for item in validated_items:
                item_subtotal_cents = round(int(item[Fields.PRICE] * 100) * item[Fields.QUANTITY] * discount_ratio)
                item_tax_rate = get_item_tax_rate(item, state_code)
                if item.get(Fields.IS_SMALL_SUPPLIER, False):
                    item_tax_rate = 0.0
                item_tax_cents = round(item_subtotal_cents * item_tax_rate)
                tax_amount_cents += item_tax_cents
                item_taxes.append({Fields.PRODUCT_ID: item[Fields.PRODUCT_ID], Fields.TAX_CENTS: item_tax_cents, Fields.TAX_RATE: item_tax_rate})

            if shipping_cost_cents > 0:
                shipping_tax_rate = get_tax_rate(state_code)
                tax_amount_cents += round(shipping_cost_cents * shipping_tax_rate)

            taxable_total_cents = discounted_subtotal_cents + shipping_cost_cents
            province_rates = _PROVINCE_TAX_BREAKDOWN.get(state_code, _PROVINCE_TAX_BREAKDOWN.get(BusinessRules.DEFAULT_PROVINCE, {"GST": 0.05}))
            taxes_breakdown = {name: round(taxable_total_cents * rate) / 100 for name, rate in province_rates.items()}
            is_reverse_charge = False

    # Total in cents
    total_amount_cents = discounted_subtotal_cents + shipping_cost_cents + tax_amount_cents

    # IDEMPOTENCY: Check for duplicate order
    recent_orders = (
        get_db().collection(Collections.ORDERS)
        .where(Fields.USER_ID, "==", user_id)
        .where(Fields.ORDER_STATUS, "==", OrderStatusValues.PENDING)
        .where(Fields.PAYMENT_STATUS, "==", PaymentStatusValues.AWAITING_PAYMENT)
        .order_by(Fields.CREATED_AT, direction="DESCENDING")
        .limit(10).get()
    )

    for recent_doc in recent_orders:
        recent_data = recent_doc.to_dict()
        if client_idempotency_key and recent_data.get(ApiKeys.IDEMPOTENCY_KEY) != client_idempotency_key:
            continue
        recent_created = recent_data.get(Fields.CREATED_AT)
        if recent_created and hasattr(recent_created, "timestamp"):
            if hasattr(recent_created, "tzinfo") and recent_created.tzinfo is None:
                recent_created = recent_created.replace(tzinfo=UTC)
            age_seconds = (datetime.now(UTC) - recent_created).total_seconds()
            from utils.helpers import compare_addresses
            if (age_seconds < BusinessRules.ORDER_DEDUP_WINDOW_SECONDS
                and recent_data.get(Fields.SUBTOTAL_CENTS) == actual_subtotal_cents
                and compare_addresses(recent_data.get(Fields.SHIPPING_ADDRESS), shipping_address)):
                existing_session_id = recent_data.get(Fields.STRIPE_SESSION_ID)
                if existing_session_id:
                    try:
                        existing_session = stripe.checkout.Session.retrieve(existing_session_id)
                        checkout_url = existing_session.url
                    except Exception:
                        checkout_url = None
                    if checkout_url:
                        return {ApiKeys.SUCCESS: True, ApiKeys.SESSION_ID: existing_session_id, Fields.ORDER_ID: recent_doc.id, ApiKeys.CHECKOUT_URL: checkout_url, ApiKeys.DUPLICATE: True}

    # Pre-query inventory candidates for the transaction
    inventory_candidates = {}
    for item in validated_items:
        p_id = item[Fields.PRODUCT_ID]
        if p_id not in inventory_candidates:
            try:
                inv_docs = get_db().collection(Collections.PRODUCTS).document(p_id).collection(Collections.INVENTORY_LEVELS).order_by(Fields.AVAILABLE_QUANTITY, direction="DESCENDING").limit(50).get()
                inventory_candidates[p_id] = [(d.id, (d.to_dict() or {}).get(Fields.AVAILABLE_QUANTITY, 0)) for d in inv_docs if d.exists]
            except Exception:
                inventory_candidates[p_id] = []

    # Final order data construction
    order_ref = get_db().collection(Collections.ORDERS).document()
    order_id = order_ref.id
    buyer_email = user_snapshot.to_dict().get(Fields.EMAIL) if user_snapshot.exists else None
    from handlers.payment_providers import PaymentProvider

    order_data = {
        Fields.ORDER_ID: order_id,
        Fields.USER_ID: user_id,
        Fields.CUSTOMER_EMAIL: buyer_email,
        Fields.SELLER_IDS: sorted(list(sellers)),
        Fields.PRODUCT_IDS: sorted(list({item[Fields.PRODUCT_ID] for item in validated_items})),
        Fields.ITEMS: validated_items,
        Fields.SUBTOTAL_CENTS: actual_subtotal_cents,
        Fields.DISCOUNT_AMOUNT_CENTS: discount_amount_cents,
        Fields.COUPON_CODE: coupon_code,
        Fields.COUPON_SELLER_ID: coupon_seller_id,
        Fields.SHIPPING_COST_CENTS: shipping_cost_cents,
        Fields.TAX_AMOUNT_CENTS: tax_amount_cents,
        Fields.TOTAL_AMOUNT_CENTS: total_amount_cents,
        Fields.TAXES: taxes_breakdown,
        Fields.ORDER_STATUS: OrderStatusValues.PENDING,
        Fields.PAYMENT_STATUS: PaymentStatusValues.AWAITING_PAYMENT,
        Fields.SHIPPING_ADDRESS: shipping_address,
        Fields.DELIVERY_INSTRUCTIONS: delivery_instructions,
        Fields.CREATED_AT: get_server_timestamp(),
        Fields.UPDATED_AT: get_server_timestamp(),
        Fields.CAPTURE_ATTEMPTS: 0,
        Fields.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
        Fields.PAYMENT_PROVIDER: PaymentProvider.STRIPE,
        Fields.DELIVERY_SPEED: delivery_speed,
        Fields.PLATFORM_FEE_TOTAL_CENTS: 0 if _check_premium_from_sub(user_id) else round(discounted_subtotal_cents * PLATFORM_FEE_RATIO),
        Fields.ARCHIVED: False,
        Fields.STOCK_RESTORED: False,
        Fields.TAX_EXEMPTION: tax_exemption if gst_number else None,
        Fields.TAX_EXEMPT: is_reverse_charge,
        Fields.ITEM_TAXES: item_taxes,
        Fields.PREFERRED_LANGUAGE: user_data.get(Fields.PREFERRED_LANGUAGE, 'en'),
        Fields.PLATFORM_FEE_RATIO: PLATFORM_FEE_RATIO,
        **({ApiKeys.IDEMPOTENCY_KEY: client_idempotency_key} if client_idempotency_key else {}),
        **({Fields.COUPON_PRERESERVED: True} if coupon_code else {}),
    }

    _stripe_snapshot_ref: list[dict | None] = [None]  # mutable container for cross-scope state

    @get_transactional()
    def checkout_atomic_transaction(transaction):
        # 1. READ PHASE
        """Function checkout_atomic_transaction."""
        product_ids_tx = list({item[Fields.PRODUCT_ID] for item in validated_items})
        product_refs_tx = {
            p_id: get_db().collection(Collections.PRODUCTS).document(p_id)
            for p_id in product_ids_tx
        }
        product_snapshots_tx = {
            p_id: p_ref.get(transaction=transaction) for p_id, p_ref in product_refs_tx.items()
        }
        inv_ref_by_product_wh_tx: dict[str, dict[str, Any]] = {}
        for p_id in product_ids_tx:
            candidates = inventory_candidates.get(p_id, [])
            p_ref = product_refs_tx[p_id]
            inv_ref_by_product_wh_tx[p_id] = {
                wh_id: p_ref.collection(Collections.INVENTORY_LEVELS).document(wh_id)
                for wh_id, _ in candidates
            }
            for inv_ref in inv_ref_by_product_wh_tx[p_id].values():
                inv_ref.get(transaction=transaction)

        coupon_ref = None
        coupon_use_ref = None
        coupon_snap = None
        coupon_use_snap = None
        if coupon_code:
            coupon_ref = get_db().collection(Collections.COUPONS).document(coupon_code)
            coupon_use_ref = coupon_ref.collection(Collections.COUPON_USES).document(user_id)
            coupon_snap = coupon_ref.get(transaction=transaction)
            coupon_use_snap = coupon_use_ref.get(transaction=transaction)

        seller_profile_snaps = {sid: get_db().collection(Collections.SELLER_PROFILES).document(sid).get(transaction=transaction) for sid in sellers}

        # 2. VALIDATION PHASE
        product_data_by_id_tx = {}
        for p_id, snapshot in product_snapshots_tx.items():
            if not snapshot.exists:
                raise https_fn.HttpsError('not-found', f'Product {p_id} not found')
            product_data_by_id_tx[p_id] = snapshot.to_dict() or {}

        reservation_plan = _build_stock_reservation_plan(
            validated_items=validated_items,
            product_data_by_id=product_data_by_id_tx,
            inventory_candidates=inventory_candidates,
        )

        if coupon_snap:
            if not coupon_snap.exists:
                raise https_fn.HttpsError('not-found', 'Coupon invalid')
            c_data = coupon_snap.to_dict() or {}
            # MEDIUM-4: re-check expiry inside transaction (race: coupon expires between validation and txn)
            if not _coupon_not_expired(c_data):
                raise https_fn.HttpsError('failed-precondition', 'Coupon has expired')
            if c_data.get(Fields.USED_COUNT, 0) >= c_data.get(Fields.MAX_USES_TOTAL, 999999):
                raise https_fn.HttpsError('resource-exhausted', 'Coupon fully used')
            u_count = coupon_use_snap.to_dict().get(Fields.USE_COUNT, 0) if coupon_use_snap.exists else 0
            if u_count >= c_data.get(Fields.MAX_USES_PER_USER, 1):
                raise https_fn.HttpsError('resource-exhausted', 'Coupon limit per user reached')

        seller_account_snapshot = {sid: snap.to_dict().get(Fields.STRIPE_ACCOUNT_ID) for sid, snap in seller_profile_snaps.items() if snap.exists and snap.to_dict().get(Fields.STRIPE_ACCOUNT_ID)}
        # SECURITY FIX (HIGH-01): stripeAccountId values must NOT be stored on the main order doc
        # because orders are readable by the buyer (resource.data.userId == request.auth.uid).
        # Store the snapshot in a backend-only private subcollection instead.
        # _stripe_snapshot is written AFTER the transaction via Admin SDK (bypasses client rules).
        _stripe_snapshot_ref[0] = seller_account_snapshot if seller_account_snapshot else None

        # 3. WRITE PHASE
        stock_deduct_by_product = reservation_plan["stock_deduct_by_product"]
        warehouse_deduct_by_product = reservation_plan["warehouse_deduct_by_product"]
        item_warehouse_by_index = reservation_plan["item_warehouse_by_index"]
        variant_state_by_product = reservation_plan["variant_state_by_product"]

        for p_id, deduct_qty in stock_deduct_by_product.items():
            if deduct_qty <= 0:
                continue
            patch = {Fields.STOCK_QUANTITY: get_firestore().Increment(-deduct_qty)}
            for wh_id, wh_deduct in warehouse_deduct_by_product.get(p_id, {}).items():
                patch[f'{Fields.WAREHOUSE_STOCK}.{wh_id}'] = get_firestore().Increment(-wh_deduct)
            if product_data_by_id_tx.get(p_id, {}).get(Fields.HAS_VARIANTS, False):
                patch[Fields.VARIANTS] = variant_state_by_product.get(p_id, [])
            transaction.update(product_refs_tx[p_id], patch)

            for wh_id, wh_deduct in warehouse_deduct_by_product.get(p_id, {}).items():
                inv_ref = inv_ref_by_product_wh_tx.get(p_id, {}).get(wh_id)
                if inv_ref:
                    transaction.set(
                        inv_ref,
                        {
                            Fields.AVAILABLE_QUANTITY: get_firestore().Increment(-wh_deduct),
                            Fields.LAST_SYNCED_AT: get_server_timestamp(),
                        },
                        merge=True,
                    )

        for item_idx, wh_id in item_warehouse_by_index.items():
            order_data[Fields.ITEMS][item_idx][Fields.FULFILLMENT_WAREHOUSE_ID] = wh_id

        if coupon_ref:
            transaction.update(coupon_ref, {Fields.USED_COUNT: get_firestore().Increment(1)})
            if coupon_use_snap.exists:
                transaction.update(coupon_use_ref, {Fields.USE_COUNT: get_firestore().Increment(1), Fields.LAST_USED_AT: get_server_timestamp()})
            else:
                transaction.set(coupon_use_ref, {Fields.USE_COUNT: 1, Fields.USED_AT: get_server_timestamp(), Fields.LAST_USED_AT: get_server_timestamp()})

        transaction.set(order_ref, order_data)
        return True

    try:
        checkout_atomic_transaction(get_db().transaction())
    except https_fn.HttpsError:
        raise
    except Exception as e:
        logger.error(f'Checkout atomic transaction error: {str(e)}')
        raise https_fn.HttpsError('internal', 'Could not complete checkout. Please try again.') from e

    # SECURITY FIX (HIGH-01): Write stripe account snapshot to backend-only private subcollection.
    # This doc is protected by firestore.rules `allow read, write: if false` (client-inaccessible);
    # backend reads via Admin SDK which bypasses rules. This prevents exposing seller Stripe account
    # IDs to the buyer who can read their own order document.
    if _stripe_snapshot_ref[0]:
        try:
            get_db().collection(Collections.ORDERS).document(order_id) \
                .collection("_private").document("stripe") \
                .set({Fields.SELLER_STRIPE_ACCOUNTS: _stripe_snapshot_ref[0],
                      Fields.CREATED_AT: get_server_timestamp()})
        except Exception as _snap_err:
            # Non-fatal: capture code falls back to live seller_profiles lookup
            logger.error(f"Failed to write stripe snapshot for order {order_id}: {_snap_err}")

    # Create Stripe Checkout Session
    try:
        # CRITICAL FIX: Stripe Checkout does NOT support negative unit_amount values.
        # Apply the coupon discount proportionally to each item's unit_amount so the
        # line items sum to discounted_subtotal_cents without any negative line items.
        _stripe_discount_ratio = (
            discounted_subtotal_cents / actual_subtotal_cents if actual_subtotal_cents > 0 else 1.0
        )
        line_items = []
        stripe_product_sum = 0  # Track actual Stripe-side subtotal to correct rounding
        for item in validated_items:
            product_data = {
                StripeConstants.NAME: item[Fields.NAME],
                StripeConstants.IMAGES: [u for u in item.get(Fields.IMAGE_URLS, [])[:1] if u]
            }

            # Add tax code if available
            tax_code = CATEGORY_TAX_CODE_MAP.get(item.get(Fields.CATEGORY_ID, 0))
            if tax_code:
                product_data[StripeConstants.TAX_CODE] = tax_code

            unit_amount = max(1, round(item[Fields.PRICE] * 100 * _stripe_discount_ratio))
            stripe_product_sum += unit_amount * item[Fields.QUANTITY]
            line_items.append(
                {
                    StripeConstants.PRICE_DATA: {
                        StripeConstants.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
                        StripeConstants.PRODUCT_DATA: product_data,
                        StripeConstants.UNIT_AMOUNT: unit_amount,
                    },
                    StripeConstants.QUANTITY: item[Fields.QUANTITY],
                }
            )

        # Remainder correction: adjust last product item so Stripe product subtotal
        # matches discounted_subtotal_cents exactly (rounding per-item can drift by N cents).
        # When last_qty > 1, integer division leaves a leftover [0, last_qty-1] cents;
        # that leftover is emitted as a separate 1-qty "Price adjustment" line item.
        rounding_delta = discounted_subtotal_cents - stripe_product_sum
        if rounding_delta != 0 and line_items:
            last_item = line_items[-1]
            last_qty = last_item[StripeConstants.QUANTITY]
            per_item_adj = rounding_delta // last_qty
            leftover = rounding_delta - per_item_adj * last_qty  # always >= 0 (Python % semantics)
            adjusted = last_item[StripeConstants.PRICE_DATA][StripeConstants.UNIT_AMOUNT] + per_item_adj
            if adjusted >= 1:
                last_item[StripeConstants.PRICE_DATA][StripeConstants.UNIT_AMOUNT] = adjusted
                if leftover > 0:
                    line_items.append({
                        StripeConstants.PRICE_DATA: {
                            StripeConstants.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
                            StripeConstants.PRODUCT_DATA: {StripeConstants.NAME: "Price adjustment"},
                            StripeConstants.UNIT_AMOUNT: leftover,
                        },
                        StripeConstants.QUANTITY: 1,
                    })
            else:
                logger.warning(f"create_checkout: rounding correction would make unit_amount={adjusted} (delta={rounding_delta}, qty={last_qty}) — skipping correction entirely")

        # Add shipping as line item (already in cents)
        if shipping_cost_cents > 0:
            line_items.append(
                {
                    StripeConstants.PRICE_DATA: {
                        StripeConstants.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
                        StripeConstants.PRODUCT_DATA: {StripeConstants.NAME: "Shipping"},
                        StripeConstants.UNIT_AMOUNT: shipping_cost_cents,
                    },
                    StripeConstants.QUANTITY: 1,
                }
            )

        # Add tax as line item (already in cents)
        # NOTE: Tax is calculated manually server-side; Stripe automatic_tax remains
        # disabled here to avoid double taxation in this checkout path.
        if tax_amount_cents > 0:
            line_items.append(
                {
                    StripeConstants.PRICE_DATA: {
                        StripeConstants.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
                        StripeConstants.PRODUCT_DATA: {StripeConstants.NAME: f"Tax ({state_code})"},
                        StripeConstants.UNIT_AMOUNT: tax_amount_cents,
                    },
                    StripeConstants.QUANTITY: 1,
                }
            )

        # Bill 96/Law 25: Quebec users must receive French-language checkout by default.
        # Stripe accepts 'fr-CA' or 'auto' (browser-detected). We use the user's stored
        # preferredLanguage — 'fr' → 'fr-CA', anything else → 'auto' (let Stripe decide).
        preferred_lang = user_data.get(Fields.PREFERRED_LANGUAGE, LanguageValues.ENGLISH)
        stripe_locale = "fr-CA" if preferred_lang == LanguageValues.FRENCH else "auto"

        session = stripe.checkout.Session.create(
            line_items=line_items,
            mode=StripeConstants.MODE_PAYMENT,
            # Explicit payment_method_types disables Stripe Link while keeping card/wallets.
            # Apple Pay and Google Pay work transparently via 'card' type in CA.
            payment_method_types=[StripeConstants.PAYMENT_METHOD_CARD],
            locale=stripe_locale,
            success_url=f"{BASE_URL}{AppConfig.CHECKOUT_SUCCESS_PATH}?session_id={{CHECKOUT_SESSION_ID}}",
            cancel_url=f"{BASE_URL}{AppConfig.CHECKOUT_CANCEL_PATH}",
            client_reference_id=user_id,
            metadata={StripeConstants.METADATA_ORDER_ID: order_id, StripeConstants.METADATA_USER_ID: user_id},
            **{StripeConstants.PAYMENT_INTENT_DATA: {
                StripeConstants.METADATA: {StripeConstants.METADATA_ORDER_ID: order_id},
            }},
            **({StripeConstants.CUSTOMER_EMAIL: buyer_email} if buyer_email else {}),
            # AUDIT FIX (CRITICAL-001): Idempotency key prevents duplicate sessions on retry
            idempotency_key=client_idempotency_key or f"checkout_{order_id}",
        )

        # Update order with session ID
        order_ref.update(
            {
                Fields.STRIPE_SESSION_ID: session.id,
                Fields.STRIPE_PAYMENT_INTENT_ID: session.payment_intent if hasattr(session, StripeConstants.PAYMENT_INTENT) else None,
            }
        )

        # Return dict directly for on_call functions
        return {
            ApiKeys.SUCCESS: True,
            ApiKeys.SESSION_ID: session.id,
            Fields.ORDER_ID: order_id,
            ApiKeys.CHECKOUT_URL: session.url,
            Fields.TAX_AMOUNT_CENTS: tax_amount_cents,  # F-77: server-calculated tax so Flutter shows the real amount
        }

    except stripe.error.CardError as e:
        # Card declined — rollback and return user-friendly message
        _rollback_checkout(validated_items, order_ref, coupon_code=coupon_code, user_id=user_id)
        raise https_fn.HttpsError(
            "failed-precondition", e.user_message or "Your card was declined. Please try a different payment method."
        ) from e
    except stripe.error.RateLimitError:
        _rollback_checkout(validated_items, order_ref, coupon_code=coupon_code, user_id=user_id)
        raise https_fn.HttpsError("unavailable", "Payment service is busy. Please try again in a moment.") from None
    except stripe.error.APIConnectionError:
        _rollback_checkout(validated_items, order_ref, coupon_code=coupon_code, user_id=user_id)
        raise https_fn.HttpsError(
            "unavailable", "Could not connect to payment service. Please check your connection and try again."
        ) from None
    except stripe.error.StripeError as e:
        _rollback_checkout(validated_items, order_ref, coupon_code=coupon_code, user_id=user_id)
        logger.error(f"Stripe error in checkout: {str(e)}")
        raise https_fn.HttpsError("internal", "Payment processing failed. Please try again.") from e
    except https_fn.HttpsError:
        # Re-raise already-safe HttpsErrors (from validation, stock checks, etc.)
        raise
    except Exception as e:
        _rollback_checkout(validated_items, order_ref, coupon_code=coupon_code, user_id=user_id)
        logger.error(f"Unexpected checkout error: {str(e)}")
        raise https_fn.HttpsError("internal", "An unexpected error occurred. Please try again.") from e


@https_fn.on_request(**WEBHOOK_OPTIONS)
def stripe_webhook(req: https_fn.Request) -> https_fn.Response:
    """
    Handles Stripe webhook events with strict security:
    1. Rate limiting by IP (FIRST)
    2. Signature verification (BEFORE processing)
    3. Idempotency check
    4. Event processing
    5. Sanitized error logging

    Supported events:
    - checkout.session.completed: Payment authorized
    - checkout.session.async_payment_succeeded: Async payment completed
    - checkout.session.async_payment_failed: Async payment failed
    - checkout.session.expired: Session expired
    - payment_intent.succeeded: Payment succeeded
    - payment_intent.payment_failed: Payment failed
    - payment_intent.canceled: Payment intent canceled
    - charge.refunded: Refund issued
    - charge.dispute.created: Dispute opened
    - charge.dispute.updated: Dispute updated (evidence/status change)
    - charge.dispute.closed: Dispute resolved
    - charge.dispute.funds_reinstated: Dispute funds reinstated to seller
    - transfer.reversed: Payout reversed
    - payout.failed: Payout failed
    - refund.failed: Refund failed
    - account.updated: Connect account status changed (enables sellers after onboarding)

    Security:
    - Rate limiting by IP (DDoS protection)
    - Signature verification (HMAC with timing-safe comparison)
    - Idempotency (Firestore webhook_events collection)
    - Sanitized error logging

    Returns:
        200 OK: Event processed successfully
        400 Bad Request: Invalid signature/payload
        429 Too Many Requests: Rate limit exceeded
        500 Internal Error: Processing failed
    """
    # Reject non-POST requests immediately (browser health checks, emulator UI)
    if req.method != "POST":
        return https_fn.Response("Method not allowed", status=405)

    # SECURITY FIX #1: Rate limiting by IP FIRST (prevent DDoS)
    # Skip rate limiting in emulator mode to avoid Firestore transaction issues
    # SECURITY FIX (AUDIT): Use the LAST IP in X-Forwarded-For, not the first.
    # The first IP is client-provided and trivially spoofable. GCP Load Balancer
    # appends the true client IP as the last entry — that value is trustworthy.
    forwarded_for = req.headers.get(HeaderKeys.X_FORWARDED_FOR, "")
    if forwarded_for:
        client_ip = forwarded_for.split(",")[-1].strip()  # Last entry = GCP LB appended, trustworthy
    else:
        client_ip = req.headers.get(HeaderKeys.X_REAL_IP, "unknown")

    if not IS_EMULATOR:
        allowed, message = get_rate_limiter().check_rate_limit(
            identifier=f"ip_{client_ip}",
            action=RateLimitActions.STRIPE_WEBHOOK,
            max_requests=BusinessRules.WEBHOOK_RATE_LIMIT_PER_MINUTE,
            window_minutes=1,
            fail_closed=True,  # Block on error for security
        )

        if not allowed:
            logger.warning(f"⚠️ Stripe webhook rate limit exceeded for IP: {client_ip[:10]}...")  # Sanitized log
            return https_fn.Response("Rate limit exceeded", status=429)

    # SECURITY FIX #2: Get raw payload and signature
    payload = req.get_data()
    sig_header = req.headers.get(HeaderKeys.STRIPE_SIGNATURE)

    if not sig_header:
        logger.warning(f"⚠️ Stripe webhook missing signature from IP: {client_ip[:10]}...")
        return https_fn.Response("Missing signature", status=400)

    try:
        # SECURITY FIX #3: Verify webhook signature (HMAC with timing-safe comparison)
        event = stripe.Webhook.construct_event(payload, sig_header, _get_webhook_secret(), tolerance=300)
    except ValueError:
        logger.warning(f"⚠️ Stripe webhook invalid payload from IP: {client_ip[:10]}...")  # Sanitized
        return https_fn.Response("Invalid payload", status=400)
    except Exception as e:
        # Handle SignatureVerificationError and other exceptions
        if "SignatureVerificationError" in str(type(e).__name__):
            logger.warning(f"⚠️ Stripe webhook invalid signature from IP: {client_ip[:10]}...")  # Sanitized
            return https_fn.Response("Invalid signature", status=400)
        logger.warning(f"⚠️ Stripe webhook verification error: {type(e).__name__}")  # Sanitized (no details)
        return https_fn.Response("Signature verification error", status=500)

    event_id = event[StripeConstants.OBJECT_ID]
    event_type = event[Fields.TYPE]

    # SECURITY FIX #3b: Reject stale webhooks (replay attack prevention)
    # Only apply to payment/checkout events — Stripe retries subscription events for up to 72h
    # so subscription.* and invoice.* must never be rejected based on age.
    import time as _time

    _STALE_CHECK_EVENT_PREFIXES = ("payment_intent.", "checkout.session.")
    event_created = event.get(StripeConstants.CREATED, 0)
    current_time = int(_time.time())
    event_age_seconds = current_time - event_created
    _needs_stale_check = any(event_type.startswith(p) for p in _STALE_CHECK_EVENT_PREFIXES)
    if not IS_EMULATOR and _needs_stale_check and event_age_seconds > BusinessRules.WEBHOOK_MAX_AGE_SECONDS:
        logger.warning(f"⚠️ Rejecting stale webhook: {event_type} age={event_age_seconds}s (event: {event_id[:16]}...)")
        return https_fn.Response("Event too old", status=400)

    # SECURITY FIX #4: Atomic idempotency check using create() to prevent race conditions.
    # If two webhook deliveries arrive simultaneously, only one create() will succeed.
    webhook_ref = get_db().collection(Collections.WEBHOOK_EVENTS).document(event_id)
    order_id = event.get(StripeConstants.DATA, {}).get(StripeConstants.OBJECT, {}).get(StripeConstants.METADATA, {}).get(StripeConstants.METADATA_ORDER_ID, "N/A")

    try:
        webhook_ref.create(
            {
                Fields.PROVIDER: PaymentProviderValues.STRIPE,
                Fields.TYPE: event_type,
                Fields.STATUS: WebhookStatusValues.PROCESSING,
                Fields.TIMESTAMP: get_server_timestamp(),
                Fields.CLIENT_IP: client_ip,
                Fields.EVENT_ID: event_id,
                Fields.ORDER_ID: order_id,
            }
        )
    except Exception:
        # Document already exists — check if completed or failed
        try:
            webhook_doc = webhook_ref.get()
            if webhook_doc.exists:
                existing_status = webhook_doc.to_dict().get(Fields.STATUS, WebhookStatusValues.COMPLETED)
                if existing_status == WebhookStatusValues.COMPLETED:
                    logger.info(f"✓ Stripe webhook already processed: {event_type} (event: {event_id[:16]}...)")
                    return https_fn.Response("Event already processed", status=200)
                # Allow retry of failed events
                logger.error(f"♻️ Retrying failed webhook: {event_type} (event: {event_id[:16]}...)")
                webhook_ref.update(
                    {
                        Fields.STATUS: WebhookStatusValues.PROCESSING,
                        Fields.TIMESTAMP: get_server_timestamp(),
                    }
                )
        except Exception as e:
            logger.warning(f"⚠️ Idempotency check error: {type(e).__name__}")

    # Route event to appropriate handler
    try:
        ensure_stripe_key()
        if event_type == StripeEventTypes.CHECKOUT_COMPLETED:
            process_checkout_session_completed(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.ASYNC_PAYMENT_SUCCEEDED:
            process_async_payment_succeeded(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.ASYNC_PAYMENT_FAILED:
            process_async_payment_failed(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.SESSION_EXPIRED:
            process_session_expired(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.PAYMENT_INTENT_SUCCEEDED:
            process_payment_intent_succeeded(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.PAYMENT_INTENT_PAYMENT_FAILED:
            process_payment_intent_failed(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.CHARGE_REFUNDED:
            process_charge_refunded(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.DISPUTE_CREATED:
            process_dispute_created(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.DISPUTE_UPDATED:
            process_dispute_updated(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.DISPUTE_CLOSED:
            process_dispute_closed(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.DISPUTE_FUNDS_REINSTATED:
            process_dispute_funds_reinstated(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.TRANSFER_REVERSED:
            process_transfer_reversed(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.PAYOUT_FAILED:
            process_payout_failed(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.REFUND_FAILED:
            process_refund_failed(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.PAYMENT_INTENT_CANCELED:
            process_payment_intent_canceled(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.ACCOUNT_UPDATED:
            process_account_updated(event[StripeConstants.DATA][StripeConstants.OBJECT])
        elif event_type == StripeEventTypes.SUBSCRIPTION_CREATED:
            from handlers.subscriptions import handle_subscription_created

            handle_subscription_created(event)
        elif event_type == StripeEventTypes.SUBSCRIPTION_UPDATED:
            from handlers.subscriptions import handle_subscription_updated

            handle_subscription_updated(event)
        elif event_type == StripeEventTypes.SUBSCRIPTION_DELETED:
            from handlers.subscriptions import handle_subscription_deleted

            handle_subscription_deleted(event)
        elif event_type == StripeEventTypes.INVOICE_PAYMENT_FAILED:
            from handlers.subscriptions import handle_invoice_payment_failed

            handle_invoice_payment_failed(event)
        elif event_type == StripeEventTypes.INVOICE_PAID:
            # Handles successful recurring subscription renewals — keeps currentPeriodEnd fresh
            from handlers.subscriptions import handle_subscription_updated

            invoice_obj = event[StripeConstants.DATA][StripeConstants.OBJECT]
            sub_id = invoice_obj.get(StripeConstants.SUBSCRIPTION)
            if sub_id:
                sub = stripe.Subscription.retrieve(sub_id)
                sub_event = {StripeConstants.DATA: {StripeConstants.OBJECT: sub}}
                handle_subscription_updated(sub_event)
        else:
            logger.info(f"ℹ️ Unhandled Stripe event type: {event_type}")

        # Mark as completed
        with contextlib.suppress(Exception):
            webhook_ref.update({Fields.STATUS: WebhookStatusValues.COMPLETED})

        logger.info(f"✓ Stripe webhook processed successfully: {event_type}")
        return https_fn.Response("Success", status=200)

    except Exception as e:
        # Mark as failed so Stripe can retry
        with contextlib.suppress(Exception):
            webhook_ref.update({Fields.STATUS: WebhookStatusValues.FAILED, Fields.ERROR: type(e).__name__})

        # SECURITY FIX #6: Sanitized error logging (no sensitive data exposure)
        error_type = type(e).__name__
        logger.error(f"❌ Error processing Stripe webhook: {error_type} for event_type: {event_type}")
        # Don't expose internal error details to webhook caller
        return https_fn.Response("Internal processing error", status=500)


def _generate_license_key() -> str:
    """Generate a XXXX-XXXX-XXXX-XXXX format license key using crypto-random characters."""
    alphabet = _string.ascii_uppercase + _string.digits
    segments = ["".join(secrets.choice(alphabet) for _ in range(4)) for _ in range(4)]
    return "-".join(segments)


def _generate_digital_licenses(order_id: str, order_data: dict) -> None:
    """Generate license keys for all digital items in an order.
    Idempotent: skips items where digitalUnlocked=True.
    Called immediately after order is confirmed on payment capture.
    """
    from datetime import datetime

    db = get_db()
    items = order_data.get(Fields.ITEMS, [])
    buyer_id = order_data.get(Fields.USER_ID, "")
    updated_items = list(items)
    any_generated = False

    for idx, item in enumerate(items):
        if not item.get(Fields.IS_DIGITAL, False):
            continue
        if item.get(Fields.DIGITAL_UNLOCKED, False):
            logger.info(f"Digital item {item.get(Fields.PRODUCT_ID)} already unlocked, skipping")
            continue

        product_id = item.get(Fields.PRODUCT_ID)
        product_doc = db.collection(Collections.PRODUCTS).document(product_id).get()
        if not product_doc.exists:
            logger.warning(f"Product {product_id} not found for digital license generation")
            continue

        product_data = product_doc.to_dict()
        digital_type = product_data.get(Fields.DIGITAL_TYPE)
        if not digital_type:
            logger.warning(f"Product {product_id} has isDigital=True but no digitalType")
            continue

        # Generate unique license key — doc ID = key for O(1) lookup
        license_key = None
        for _ in range(5):
            candidate = _generate_license_key()
            existing = db.collection(Collections.LICENSES).document(candidate).get()
            if not existing.exists:
                license_key = candidate
                break
        if not license_key:
            logger.error(f"Could not generate unique license key for product {product_id}")
            continue

        now = datetime.now(UTC)

        if digital_type == DigitalTypeValues.SOFTWARE:
            builds = product_data.get(Fields.DIGITAL_BUILDS, {})
            supported_platforms = list(builds.keys())
            license_doc = {
                Fields.LICENSE_KEY: license_key,
                Fields.PRODUCT_ID: product_id,
                Fields.ORDER_ID: order_id,
                Fields.USER_ID: buyer_id,
                Fields.DIGITAL_TYPE: DigitalTypeValues.SOFTWARE,
                Fields.STATUS: LicenseStatusValues.ACTIVE,
                Fields.SUPPORTED_PLATFORMS: supported_platforms,
                Fields.DEVICE_LIMIT: product_data.get(Fields.DEVICE_LIMIT),
                Fields.ACTIVATIONS: [],
                Fields.DIGITAL_BUILDS: builds,
                Fields.PRODUCT_NAME: product_data.get(Fields.NAME, ""),
                Fields.CREATED_AT: now,
            }
            db.collection(Collections.LICENSES).document(license_key).set(license_doc)

        elif digital_type == DigitalTypeValues.BOOK:
            book_source_url = product_data.get(Fields.BOOK_SOURCE_URL, "")
            license_doc = {
                Fields.LICENSE_KEY: license_key,
                Fields.PRODUCT_ID: product_id,
                Fields.ORDER_ID: order_id,
                Fields.USER_ID: buyer_id,
                Fields.DIGITAL_TYPE: DigitalTypeValues.BOOK,
                Fields.STATUS: LicenseStatusValues.ACTIVE,
                Fields.BOOK_SOURCE_URL: book_source_url,
                Fields.PRODUCT_NAME: product_data.get(Fields.NAME, ""),
                Fields.CREATED_AT: now,
            }
            db.collection(Collections.LICENSES).document(license_key).set(license_doc)

        # Update item in order — write platform availability without real URLs
        updated_item = dict(updated_items[idx])
        updated_item[Fields.LICENSE_KEY] = license_key
        updated_item[Fields.DIGITAL_UNLOCKED] = True
        updated_item[Fields.STATUS] = DeliveryStatusValues.DELIVERED  # Digital: instant delivery
        if digital_type == DigitalTypeValues.SOFTWARE:
            # Store platform keys only (no URLs) so the client can show download buttons
            # without exposing the seller's actual download URL.
            updated_item[Fields.DIGITAL_BUILDS] = {p: "" for p in supported_platforms}
        updated_items[idx] = updated_item
        any_generated = True
        logger.info(f"License {license_key} generated for product {product_id} (type={digital_type})")

    if any_generated:
        order_ref = db.collection(Collections.ORDERS).document(order_id)
        order_ref.update({Fields.ITEMS: updated_items, Fields.UPDATED_AT: datetime.now(UTC)})


def _execute_seller_payouts(order_id: str, order_data: dict, charge_id: str) -> list:
    """Create payout records and Stripe Transfers for all sellers in an order.

    Args:
        order_id: Firestore order document ID
        order_data: Order data dict
        charge_id: Stripe Charge ID (ch_xxx) — required for source_transaction

    Returns:
        List of (seller_id, error) tuples for any transfer failures.
    """
    transfer_errors = []
    items = order_data.get(Fields.ITEMS, [])

    # Use fee rate frozen at checkout time (not the current global config)
    stored_fee_rate = order_data.get(Fields.PLATFORM_FEE_RATIO, PLATFORM_FEE_RATIO)

    # Compute discount ratio so seller payouts reflect only collected amount.
    # For seller-scoped coupons (couponSellerId != None), only that seller absorbs
    # the discount — other sellers are unaffected.
    actual_subtotal_cents = order_data.get(Fields.SUBTOTAL_CENTS, 0)
    discount_amount_cents = order_data.get(Fields.DISCOUNT_AMOUNT_CENTS, 0)
    coupon_seller_id = order_data.get(Fields.COUPON_SELLER_ID)  # None = platform-wide

    # For scoped coupons, compute the scoped seller's subtotal to derive the correct ratio
    if coupon_seller_id is not None and discount_amount_cents > 0:
        scoped_subtotal_cents = sum(
            round(item.get(Fields.PRICE, 0) * 100) * item.get(Fields.QUANTITY, 1)
            for item in items
            if item.get(Fields.SELLER_ID) == coupon_seller_id
        )
        # scoped_discount_ratio applies only to the coupon seller; others get 1.0.
        # Clamp to [0.0, 1.0]: a fixed-amount coupon larger than the seller subtotal
        # must not produce a negative ratio (which would over-refund or reverse payout).
        scoped_discount_ratio = (
            max(0.0, min(1.0, (scoped_subtotal_cents - discount_amount_cents) / scoped_subtotal_cents))
            if scoped_subtotal_cents > 0
            else 1.0
        )
        global_discount_ratio = None  # sentinel: use per-seller logic below
    else:
        # FINANCIAL FIX (AUDIT): Platform-wide coupons should be absorbed by the platform,
        # NOT deducted from seller payouts. Independent sellers should receive their full
        # negotiated price regardless of platform marketing discounts.
        # Set global_discount_ratio = 1.0 (no reduction) for platform-wide coupons.
        # The platform absorbs the cost via reduced platform fee revenue.
        global_discount_ratio = 1.0
        scoped_discount_ratio = None  # unused

    # Compute per-seller totals (price in dollars × 100 → cents, × quantity)
    sellers_total: dict[str, int] = {}
    for item in items:
        sid = item.get(Fields.SELLER_ID)
        if not sid:
            continue
        amt = round(item.get(Fields.PRICE, 0) * 100) * item.get(Fields.QUANTITY, 1)
        sellers_total[sid] = sellers_total.get(sid, 0) + amt

    for seller_id, amount_cents in sellers_total.items():
        # Apply coupon discount proportionally before computing platform fee.
        # adjusted_amount_cents = seller's share of what the buyer actually paid (in cents).
        # For seller-scoped coupons, only the coupon's seller absorbs the discount.
        if global_discount_ratio is not None:
            # Platform-wide coupon or no coupon — uniform ratio
            adjusted_amount_cents = round(amount_cents * global_discount_ratio)
        elif seller_id == coupon_seller_id:
            # This seller issued the coupon — apply their specific discount ratio
            adjusted_amount_cents = round(amount_cents * scoped_discount_ratio)
        else:
            # Other sellers are unaffected by a scoped coupon
            adjusted_amount_cents = amount_cents
        # Prevent config updates from retroactively changing fees.
        platform_fee_cents = round(adjusted_amount_cents * stored_fee_rate)  # already in cents
        net_amount_cents = adjusted_amount_cents - platform_fee_cents  # already in cents

        payout_ref = get_db().collection(Collections.PAYOUTS).document(f"{order_id}_{seller_id}")
        # Skip if payout already exists (any non-FAILED status) — prevents webhook retry from creating duplicates
        existing_payout = payout_ref.get()
        if existing_payout.exists:
            existing_status = (existing_payout.to_dict() or {}).get(Fields.STATUS)
            if existing_status != PayoutStatusValues.FAILED:
                logger.info(f"Payout {payout_ref.id} already exists (status={existing_status}) — skipping")
                continue
        payout_data = {
            Fields.ORDER_ID: order_id,
            Fields.SELLER_ID: seller_id,
            Fields.AMOUNT_CENTS: adjusted_amount_cents,
            Fields.PLATFORM_FEE_CENTS: platform_fee_cents,
            Fields.NET_AMOUNT_CENTS: net_amount_cents,
            Fields.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
            Fields.STATUS: PayoutStatusValues.PENDING,
            Fields.FEE_RATE: stored_fee_rate,
            Fields.CREATED_AT: get_server_timestamp(),
        }
        payout_ref.set(payout_data, merge=True)

        # Attempt Stripe Transfer
        if charge_id:
            try:
                # Use seller Stripe account snapshot from order (set at checkout) for security.
                # This prevents account-swap attacks if seller changes their Connect account after checkout.
                # SECURITY FIX (HIGH-01): Read from private subcollection, not buyer-readable order doc.
                seller_stripe_accounts = _get_seller_stripe_snapshot(order_id, order_data)
                acct_id = seller_stripe_accounts.get(seller_id)
                if not acct_id:
                    # Fallback: fetch from seller_profiles (for orders without snapshot)
                    sp_doc = get_db().collection(Collections.SELLER_PROFILES).document(seller_id).get()
                    acct_id = (sp_doc.to_dict() or {}).get(Fields.STRIPE_ACCOUNT_ID)
                if acct_id:
                    transfer = stripe.Transfer.create(
                        amount=net_amount_cents,
                        currency=BusinessRules.DEFAULT_CURRENCY,
                        destination=acct_id,
                        source_transaction=charge_id,
                        transfer_group=order_id,
                        metadata={Fields.ORDER_ID: order_id, Fields.SELLER_ID: seller_id},
                        idempotency_key=f"transfer_{order_id}_{seller_id}",
                    )
                    payout_ref.update({
                        Fields.STRIPE_TRANSFER_ID: transfer.id,
                        Fields.STATUS: PayoutStatusValues.COMPLETED,
                    })
                else:
                    logger.warning(f"⚠️ No Stripe account for seller {seller_id} — skipping transfer for order {order_id}")
            except Exception as transfer_err:
                logger.warning(f"⚠️ Transfer to seller {seller_id} failed for order {order_id}: {transfer_err}")
                payout_ref.update({
                    Fields.STATUS: PayoutStatusValues.FAILED,
                    Fields.FAILURE_REASON: str(transfer_err),
                })
                transfer_errors.append((seller_id, str(transfer_err)))

    return transfer_errors


def _run_post_payment_side_effects(order_id: str, order_data: dict) -> None:
    """Run confirmation emails, digital licenses, coupon redemption, and cart clearing after payment capture.
    Called by both process_checkout_session_completed (card/instant) and process_async_payment_succeeded (bank/Interac).
    """
    # Generate digital licenses FIRST so license keys are included in the confirmation email
    try:
        _generate_digital_licenses(order_id, order_data)
        # Re-fetch order_data so the email builder sees digitalUnlocked=True and licenseKey values
        refreshed = get_db().collection(Collections.ORDERS).document(order_id).get()
        if refreshed.exists:
            order_data = refreshed.to_dict()
    except Exception as e:
        logger.error(f"Digital license generation failed for order {order_id}: {str(e)}")

    # Send confirmation emails
    try:
        buyer_email = order_data.get(Fields.CUSTOMER_EMAIL)
        if not buyer_email:
            buyer_doc = get_db().collection(Collections.USERS).document(order_data[Fields.USER_ID]).get()
            if buyer_doc.exists:
                buyer_email = buyer_doc.to_dict().get(Fields.EMAIL)

        buyer_lang = order_data.get(Fields.PREFERRED_LANGUAGE, "en")
        if buyer_email:
            buyer_email_html = get_order_confirmation_email(order_data, order_id, lang=buyer_lang)

            pdf_attachments = None
            try:
                import base64
                pdf_bytes = generate_invoice_pdf(order_data, order_id)
                if pdf_bytes:
                    short_oid = order_id[:8] if len(order_id) > 8 else order_id
                    pdf_attachments = [
                        {
                            "ContentType": "application/pdf",
                            "Filename": f"Origna_Invoice_{short_oid}.pdf",
                            "Base64Content": base64.b64encode(pdf_bytes).decode("utf-8"),
                        }
                    ]
            except Exception as e:
                logger.warning(f"PDF invoice generation failed (non-critical): {str(e)}")

            # FIX F5-3: Use enqueue_email_task to avoid blocking Stripe webhook.
            # Note: PDF attachment is passed through as extra kwarg — email_task will
            # fall back to sync send if attachments are present (Cloud Tasks payload limit).
            if pdf_attachments:
                send_email(
                    to_email=buyer_email,
                    subject=_email_t("sub.confirmed", buyer_lang),
                    html_content=buyer_email_html,
                    attachments=pdf_attachments,
                )
            else:
                enqueue_email_task(
                    to_email=buyer_email,
                    subject=_email_t("sub.confirmed", buyer_lang),
                    html_content=buyer_email_html,
                    event_type=OrderEventTypes.ORDER_CONFIRMED_BUYER,
                    order_id=order_id,
                )

        sellers = set(item[Fields.SELLER_ID] for item in order_data[Fields.ITEMS])
        for seller_id in sellers:
            seller_doc = get_db().collection(Collections.USERS).document(seller_id).get()
            if seller_doc.exists:
                seller_data = seller_doc.to_dict()
                seller_email = seller_data.get(Fields.EMAIL)
                if seller_email:
                    seller_lang = seller_data.get(Fields.PREFERRED_LANGUAGE, "en")
                    seller_email_html = get_seller_notification_email(order_data, order_id, seller_id, lang=seller_lang, seller_email=seller_email)
                    enqueue_email_task(
                        to_email=seller_email,
                        subject=_email_t("sub.new_order_seller", seller_lang).replace("{oid}", order_id[:8]),
                        html_content=seller_email_html,
                        event_type=OrderEventTypes.ORDER_CONFIRMED_SELLER,
                        order_id=order_id,
                    )  # FIX F5-3: Non-blocking seller notification
                # Push notification so mobile sellers see new orders immediately
                item_count = sum(1 for item in order_data[Fields.ITEMS] if item.get(Fields.SELLER_ID) == seller_id)
                try:
                    from services.push_service import send_push_notification as _push_seller
                    _push_seller(
                        seller_id,
                        title="New Order!",
                        body=f"You have a new order — {item_count} item{'s' if item_count != 1 else ''} to fulfill",
                        data={"type": NotificationTypes.ORDER_STATUS, "orderId": order_id, "status": OrderStatusValues.CONFIRMED},
                    )
                except Exception as push_err:
                    logger.warning(f"Failed to send push to seller {seller_id}: {push_err}")

        # GAP-13: Perishable urgent notifications — CFIA compliance.
        # Any order with perishable items must trigger an immediate URGENT push + email
        # to the responsible seller(s) so items are shipped same-day.
        try:
            all_items: list[dict] = order_data.get(Fields.ITEMS, [])
            has_perishable = any(
                item.get(Fields.IS_PERISHABLE, False) for item in all_items
            )
            if has_perishable:
                perishable_by_seller: dict[str, list[dict]] = {}
                for item in all_items:
                    if item.get(Fields.IS_PERISHABLE, False):
                        sid = item.get(Fields.SELLER_ID, "")
                        if sid:
                            perishable_by_seller.setdefault(sid, []).append(item)

                for p_seller_id, p_items in perishable_by_seller.items():
                    item_names = ", ".join(
                        i.get(Fields.NAME, "item") for i in p_items[:3]
                    )
                    oid_short_p = order_id[:8].upper()
                    # Urgent push — fires immediately, before email task queue
                    try:
                        from services.push_service import send_push_notification as _push_perishable
                        _push_perishable(
                            p_seller_id,
                            title="URGENT: Perishable Order",
                            body=f"Perishable items ({item_names}) — ship TODAY. Order #{oid_short_p}",
                            data={
                                "type": NotificationTypes.PERISHABLE_ORDER_URGENT,
                                "orderId": order_id,
                                "priority": "high",
                            },
                        )
                    except Exception as p_push_err:
                        logger.warning(
                            f"GAP-13: Failed perishable push to seller {p_seller_id}: {p_push_err}"
                        )
                    # Urgent email via task queue (non-blocking)
                    try:
                        p_seller_doc = get_db().collection(Collections.USERS).document(p_seller_id).get()
                        if p_seller_doc.exists:
                            p_seller_data = p_seller_doc.to_dict() or {}
                            p_seller_email = p_seller_data.get(Fields.EMAIL)
                            if p_seller_email:
                                p_lang = p_seller_data.get(Fields.PREFERRED_LANGUAGE, "en")
                                p_subject = _email_t("sub.perishable_urgent", p_lang).replace(
                                    "{oid}", oid_short_p
                                )
                                p_html = get_seller_notification_email(
                                    order_data, order_id, p_seller_id, lang=p_lang, seller_email=p_seller_email, is_urgent_perishable=True
                                )
                                enqueue_email_task(
                                    to_email=p_seller_email,
                                    subject=p_subject,
                                    html_content=p_html,
                                    event_type=OrderEventTypes.ORDER_CONFIRMED_SELLER,
                                    order_id=order_id,
                                )
                    except Exception as p_email_err:
                        logger.warning(
                            f"GAP-13: Failed perishable email to seller {p_seller_id}: {p_email_err}"
                        )
        except Exception as p_err:
            logger.error(f"GAP-13: Perishable notification block failed for order {order_id}: {p_err}")

    except Exception as e:
        logger.error(f"Failed to send confirmation emails: {str(e)}")

    # Redeem coupon if one was applied.
    # AUDIT FIX (CRITICAL-C3): Skip if coupon was already pre-reserved at checkout
    # time (couponPrereserved=True on order doc). Pre-reservation already atomically
    # incremented usedCount; calling redeem_coupon() again would double-count.
    # For orders created before this fix (couponPrereserved missing), fall back to
    # the original redeem_coupon() path so old orders are not broken.
    try:
        applied_coupon_code = order_data.get(Fields.COUPON_CODE)
        coupon_already_prereserved = order_data.get(Fields.COUPON_PRERESERVED, False)
        if applied_coupon_code and not coupon_already_prereserved:
            from handlers.coupons import redeem_coupon as _redeem_coupon
            _redeem_coupon(applied_coupon_code, order_data[Fields.USER_ID], order_id=order_id)
        elif applied_coupon_code and coupon_already_prereserved:
            logger.info(f"Coupon {applied_coupon_code} already pre-reserved at checkout — skipping double-redeem")
    except Exception as e:
        logger.error(f"Failed to redeem coupon for order {order_id}: {str(e)}")

    # Clear user's cart and stamp lastCheckoutTimestamp so the abandoned-cart cron
    # won't email users about items they just purchased.
    try:
        user_id = order_data[Fields.USER_ID]
        _clear_user_cart(user_id)
        get_db().collection(Collections.USERS).document(user_id).update(
            {Fields.LAST_CHECKOUT_TIMESTAMP: datetime.now(UTC)}
        )
    except Exception as e:
        logger.error(f"Failed to clear cart: {str(e)}")


def process_checkout_session_completed(session: dict) -> str | None:
    """
    Processes checkout.session.completed event.
    Updates order status to confirmed and sends confirmation emails.
    """
    # SECURITY: For async payment methods (bank transfers, Interac), the session
    # completes before payment arrives. Defer to async_payment_succeeded webhook.
    if session.get(StripeConstants.PAYMENT_STATUS) != StripeConstants.STATUS_PAID:
        logger.info(
            f"Session {session.get(StripeConstants.OBJECT_ID)} payment_status={session.get(StripeConstants.PAYMENT_STATUS)}, deferring to async_payment webhook"
        )
        return None

    order_id = session.get(StripeConstants.METADATA, {}).get(StripeConstants.METADATA_ORDER_ID)

    if not order_id:
        logger.info("No orderId in session metadata")
        return None

    order_ref = get_db().collection(Collections.ORDERS).document(order_id)
    order_doc = order_ref.get()

    if not order_doc.exists:
        logger.info(f"Order {order_id} not found")
        return None

    order_data = order_doc.to_dict()

    # SECURITY: Verify current order state — don't overwrite cancelled/expired orders
    current_status = order_data.get(Fields.ORDER_STATUS)
    if current_status != OrderStatusValues.PENDING:
        logger.info(f"Order {order_id} status is {current_status}, not PENDING — skipping")
        return f"Order {order_id} skipped (status: {current_status})"

    # SECURITY: Verify payment amount matches order amount
    session_amount = session.get("amount_total", 0)
    expected_amount = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0)
    if session_amount != expected_amount:
        logger.info(f"AMOUNT MISMATCH: session={session_amount}, expected={expected_amount} for {order_id}")
        _restore_stock_and_cancel_order(
            order_id, order_data, f"Amount mismatch: paid {session_amount} expected {expected_amount}"
        )
        return f"Order {order_id} cancelled - amount mismatch"

    # Fix 4: Address Injection Protection
    # Verify that the address used in Stripe matches the one in Firestore.
    # Prevents users from getting cheap shipping quote for Address A, then swapping to Address B in Stripe.
    # NOTE: Only applies when Stripe collects shipping address (shipping_address_collection enabled).
    # If shipping_details is empty, we don't collect address in Stripe — skip check.
    session_shipping = session.get("shipping_details", {}) or {}
    stripe_address = session_shipping.get("address", {}) or {}

    # Only compare if Stripe actually collected a shipping address
    if stripe_address and any(stripe_address.get(k) for k in ("country", "state", "postal_code")):
        order_address = order_data.get(Fields.SHIPPING_ADDRESS, {})

        def normalize(val):
            """Lowercase-strip a value for case/whitespace-insensitive address comparison."""
            return str(val).strip().lower() if val else ""

        # Compare critical fields that affect shipping/tax: Country, State, Postal Code
        # precise street match is skipped to allow minor typo corrections by user
        mismatches = []
        if normalize(stripe_address.get("country")) != normalize(order_address.get(Fields.COUNTRY)):
            mismatches.append("country")
        if normalize(stripe_address.get("state")) != normalize(order_address.get(Fields.STATE)):
            mismatches.append("state")
        # Fuzzy match postal code (remove spaces)
        stripe_zip = normalize(stripe_address.get("postal_code")).replace(" ", "")
        order_zip = normalize(order_address.get(Fields.POSTAL_CODE)).replace(" ", "")
        if stripe_zip != order_zip:
            mismatches.append(f"postal_code ({stripe_zip} vs {order_zip})")

        if mismatches:
            logger.warning(f"⚠️ Address mismatch for order {order_id}: {mismatches}. Cancelling.")
            _restore_stock_and_cancel_order(order_id, order_data, f"Shipping address mismatch: {', '.join(mismatches)}")
            return f"Order {order_id} cancelled - address mismatch"

    # SECURITY FIX: Re-validate products before confirming order
    # Products could be deactivated or sellers suspended between checkout and payment
    items = order_data.get(Fields.ITEMS, [])

    # Read unique products and sellers (deduplicated)
    product_ids_in_items = list({item.get(Fields.PRODUCT_ID) for item in items if item.get(Fields.PRODUCT_ID)})
    seller_ids_in_items = list({item.get(Fields.SELLER_ID) for item in items if item.get(Fields.SELLER_ID)})
    db = get_db()
    product_docs_map = {pid: db.collection(Collections.PRODUCTS).document(pid).get() for pid in product_ids_in_items}
    seller_docs_map = {sid: db.collection(Collections.USERS).document(sid).get() for sid in seller_ids_in_items}

    # Collect bad sellers whose items must be cancelled
    bad_seller_ids: set[str] = set()
    for item in items:
        product_id = item.get(Fields.PRODUCT_ID)
        seller_id = item.get(Fields.SELLER_ID)

        product_doc = product_docs_map.get(product_id)
        if product_doc is None or not product_doc.exists:
            logger.warning(f"⚠️ Product {product_id} no longer exists for seller {seller_id}")
            bad_seller_ids.add(seller_id)
            continue

        product_data = product_doc.to_dict()
        if product_data.get(Fields.LIFECYCLE_STATUS) != ProductLifecycleStatusValues.ACTIVE:
            logger.warning(f"⚠️ Product {product_id} deactivated (seller {seller_id})")
            bad_seller_ids.add(seller_id)

        seller_doc = seller_docs_map.get(seller_id)
        if seller_doc and seller_doc.exists and seller_doc.to_dict().get(Fields.SUSPENDED, False):
            logger.warning(f"⚠️ Seller {seller_id} suspended")
            bad_seller_ids.add(seller_id)

    if bad_seller_ids:
        good_items = [i for i in items if i.get(Fields.SELLER_ID) not in bad_seller_ids]

        if not good_items:
            # All sellers are bad — cancel entire order
            _restore_stock_and_cancel_order(order_id, order_data, f"All sellers invalid: {bad_seller_ids}")
            return f"Order {order_id} cancelled - all sellers invalid"

        # Multi-seller order: partial cancel — refund bad sellers' items, keep good items
        bad_items = [i for i in items if i.get(Fields.SELLER_ID) in bad_seller_ids]
        # SECURITY FIX (AUDIT): Apply coupon discount ratio before calculating refund amount.
        # Refunding at full price when buyer paid a discounted price over-refunds and drains platform.
        order_subtotal_cents = order_data.get(Fields.SUBTOTAL_CENTS, 0)
        order_discount_cents = order_data.get(Fields.DISCOUNT_AMOUNT_CENTS, 0)
        _discount_ratio = (
            (order_subtotal_cents - order_discount_cents) / order_subtotal_cents
            if order_subtotal_cents > 0 and order_discount_cents > 0
            else 1.0
        )
        bad_amount_cents = sum(
            round(round(item.get(Fields.PRICE, 0) * 100) * item.get(Fields.QUANTITY, 1) * _discount_ratio)
            for item in bad_items
        )
        pi_id_for_partial = session.get(StripeConstants.PAYMENT_INTENT)
        if pi_id_for_partial and bad_amount_cents > 0:
            try:
                ensure_stripe_key()
                stripe.Refund.create(
                    payment_intent=pi_id_for_partial,
                    amount=bad_amount_cents,
                    reason="requested_by_customer",
                    metadata={Fields.ORDER_ID: order_id, "bad_sellers": ",".join(sorted(bad_seller_ids))},
                    idempotency_key=f"partial_refund_{order_id}_{'_'.join(sorted(bad_seller_ids))}",
                )
                logger.info(f"Partial refund {bad_amount_cents}c issued for {order_id}")
            except Exception as e:
                logger.error(f"Partial refund failed for {order_id}: {e}")

        # Restore stock only for bad items
        batch = db.batch()
        _add_stock_restore_to_batch(batch, {**order_data, Fields.ITEMS: bad_items})
        order_ref.update({
            Fields.ITEMS: good_items,
            Fields.SELLER_IDS: sorted({i.get(Fields.SELLER_ID) for i in good_items}),
            Fields.SUBTOTAL_CENTS: sum(round(i.get(Fields.PRICE, 0) * 100) * i.get(Fields.QUANTITY, 1) for i in good_items),
            Fields.UPDATED_AT: get_server_timestamp(),
        })
        batch.commit()
        logger.info(f"Order {order_id}: removed items from bad sellers {bad_seller_ids}, order continues with {len(good_items)} items")

    # Update order status — auto-capture: payment is captured immediately at checkout
    pi_id = session.get(StripeConstants.PAYMENT_INTENT)

    # Initialize update data with CAPTURED status (auto-capture mode)
    # AUDIT FIX: Do NOT set EXPIRES_AT for captured orders — expiry only applies to
    # AUTHORIZED (manual-capture) payments awaiting capture. Setting it here creates
    # ghost state that confuses the stale_orders_dispatcher and client UIs.
    update_data = {
        Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
        Fields.STRIPE_PAYMENT_INTENT_ID: pi_id,
        Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        Fields.CAPTURED_AT: get_server_timestamp(),
        Fields.UPDATED_AT: get_server_timestamp(),
    }

    order_ref.update(update_data)

    # Record payment event
    payment_event_type = OrderEventTypes.PAYMENT_CAPTURED if update_data.get(Fields.PAYMENT_STATUS) == PaymentStatusValues.CAPTURED else OrderEventTypes.PAYMENT_AUTHORIZED
    try:
        OrderEvent.write(
            get_db(), order_id, payment_event_type,
            actor="stripe_webhook", actor_type="system",
            to_status=update_data.get(Fields.PAYMENT_STATUS),
            metadata={"paymentIntentId": pi_id or ""},
        )
    except Exception as e:
        logger.warning(f"Failed to write order event for {order_id}: {e}")

    # Retrieve charge_id for seller payouts (auto-capture: charge is already on the PI)
    charge_id = None
    if pi_id:
        try:
            ensure_stripe_key()
            from utils.helpers import get_charge_id_from_pi
            pi = stripe.PaymentIntent.retrieve(pi_id)
            charge_id = get_charge_id_from_pi(pi)
        except Exception as pi_err:
            logger.error(f"⚠️ Failed to retrieve PaymentIntent {pi_id} for charge_id: {pi_err}")

    if charge_id:
        try:
            _execute_seller_payouts(order_id, order_data, charge_id)
        except Exception as payout_err:
            logger.error(f"⚠️ Seller payout creation failed for order {order_id}: {payout_err}")

    if update_data.get(Fields.PAYMENT_STATUS) == PaymentStatusValues.CAPTURED:
        _run_post_payment_side_effects(order_id, order_data)

    return f"Order {order_id} confirmed"


def _clear_user_cart(user_id: str) -> None:
    """Deletes all items from user's cart subcollection using paginated batched writes.

    Cost fix: paginated with limit(500) to avoid unbounded stream reads on large carts.
    Cart size is already bounded by BusinessRules.MAX_CART_ITEMS but defensive pagination
    prevents full-collection scans.
    """
    cart_ref = get_db().collection(Collections.USERS).document(user_id).collection(Collections.CART)
    while True:
        docs = list(cart_ref.limit(500).stream())
        if not docs:
            return
        batch = get_db().batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()
        if len(docs) < 500:
            return


def process_async_payment_succeeded(session: dict) -> str | None:
    """Handles async payment success (e.g., bank transfers, Interac).
    Mirrors process_checkout_session_completed side effects.
    """
    order_id = session.get(StripeConstants.METADATA, {}).get(StripeConstants.METADATA_ORDER_ID)

    if not order_id:
        return None

    order_ref = get_db().collection(Collections.ORDERS).document(order_id)
    order_doc = order_ref.get()

    if not order_doc.exists:
        logger.warning(f"process_async_payment_succeeded: order {order_id} not found")
        return None

    order_data = order_doc.to_dict()

    # Guard: skip if already captured (idempotency)
    if order_data.get(Fields.PAYMENT_STATUS) == PaymentStatusValues.CAPTURED:
        logger.info(f"Order {order_id} already captured — skipping async_payment_succeeded")
        return f"Order {order_id} already captured"

    # SECURITY: Verify payment amount matches order amount
    # H-5: Cancel order on mismatch in async payment
    session_amount = session.get("amount_total", 0)
    expected_amount = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0)
    if session_amount != expected_amount:
        logger.info(f"ASYNC AMOUNT MISMATCH: session={session_amount}, expected={expected_amount} for {order_id}")
        _restore_stock_and_cancel_order(
            order_id, order_data, f"Amount mismatch in async payment: paid {session_amount} expected {expected_amount}"
        )
        return f"Order {order_id} cancelled - amount mismatch"

    # H-5 FIX: Re-validate products and sellers before confirming async payment.
    # Products could be deactivated or sellers suspended between checkout and payment arrival.
    db = get_db()
    items_for_validation = order_data.get(Fields.ITEMS, [])
    async_product_ids = list({item.get(Fields.PRODUCT_ID) for item in items_for_validation if item.get(Fields.PRODUCT_ID)})
    async_seller_ids = list({item.get(Fields.SELLER_ID) for item in items_for_validation if item.get(Fields.SELLER_ID)})

    # Batch fetch products and sellers (avoids N+1 queries)
    async_product_docs = {
        d.id: d.to_dict()
        for d in db.get_all([db.collection(Collections.PRODUCTS).document(pid) for pid in async_product_ids])
        if d.exists
    }
    async_seller_docs = {
        d.id: d.to_dict()
        for d in db.get_all([db.collection(Collections.USERS).document(sid) for sid in async_seller_ids])
        if d.exists
    }

    async_bad_seller_ids: set[str] = set()
    for item in items_for_validation:
        pid = item.get(Fields.PRODUCT_ID)
        sid = item.get(Fields.SELLER_ID)
        p_data = async_product_docs.get(pid)
        if not p_data:
            logger.warning(f"⚠️ Async payment: product {pid} no longer exists for seller {sid}")
            if sid:
                async_bad_seller_ids.add(sid)
            continue
        if p_data.get(Fields.LIFECYCLE_STATUS) != ProductLifecycleStatusValues.ACTIVE:
            logger.warning(f"⚠️ Async payment: product {pid} deactivated (seller {sid})")
            if sid:
                async_bad_seller_ids.add(sid)
        s_data = async_seller_docs.get(sid, {})
        if s_data.get(Fields.SUSPENDED, False):
            logger.warning(f"⚠️ Async payment: seller {sid} is suspended")
            if sid:
                async_bad_seller_ids.add(sid)

    if async_bad_seller_ids:
        good_items = [i for i in items_for_validation if i.get(Fields.SELLER_ID) not in async_bad_seller_ids]
        if not good_items:
            _restore_stock_and_cancel_order(
                order_id, order_data, f"Async payment: all sellers invalid {async_bad_seller_ids}"
            )
            return f"Order {order_id} cancelled - all sellers invalid at async payment time"
        logger.warning(
            f"⚠️ Async payment: partial seller validation failure for order {order_id}, "
            f"bad_sellers={async_bad_seller_ids}. Manual review required."
        )
        order_ref.update({
            Fields.REQUIRES_MANUAL_REVIEW: True,
            Fields.MANUAL_REVIEW_REASON: f"Async payment: sellers invalid at payment time: {sorted(async_bad_seller_ids)}",
            Fields.UPDATED_AT: get_server_timestamp(),
        })
        # BUG-1 FIX: Filter order_data items to exclude bad sellers BEFORE payouts.
        # Without this, _execute_seller_payouts receives items from suspended/deactivated
        # sellers and issues them payouts they must not receive.
        order_data = dict(order_data)
        order_data[Fields.ITEMS] = good_items

    # C-3: Set ORDER_STATUS to CONFIRMED when async payment succeeds
    order_ref.update({
        Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
        Fields.UPDATED_AT: get_server_timestamp()
    })
    # Refresh order_data with new payment status for side effects
    order_data[Fields.PAYMENT_STATUS] = PaymentStatusValues.CAPTURED
    order_data[Fields.ORDER_STATUS] = OrderStatusValues.CONFIRMED

    try:
        OrderEvent.write(
            get_db(), order_id, OrderEventTypes.PAYMENT_CAPTURED,
            actor="stripe_webhook", actor_type="system",
            to_status=PaymentStatusValues.CAPTURED,
        )
    except Exception as e:
        logger.warning(f"Failed to write order event for {order_id}: {e}")

    # Retrieve charge_id for seller payouts
    pi_id = session.get(StripeConstants.PAYMENT_INTENT)
    charge_id = None
    if pi_id:
        try:
            ensure_stripe_key()
            from utils.helpers import get_charge_id_from_pi
            pi = stripe.PaymentIntent.retrieve(pi_id)
            charge_id = get_charge_id_from_pi(pi)
        except Exception as pi_err:
            logger.error(f"⚠️ Failed to retrieve PaymentIntent {pi_id} for charge_id: {pi_err}")

    if charge_id:
        try:
            _execute_seller_payouts(order_id, order_data, charge_id)
        except Exception as payout_err:
            logger.error(f"⚠️ Seller payout creation failed for order {order_id}: {payout_err}")

    _run_post_payment_side_effects(order_id, order_data)

    return f"Order {order_id} payment captured"


def process_async_payment_failed(session: dict) -> str | None:
    """Handles async payment failure"""
    order_id = session.get(StripeConstants.METADATA, {}).get(StripeConstants.METADATA_ORDER_ID)

    if not order_id:
        return None

    order_ref = get_db().collection(Collections.ORDERS).document(order_id)
    order_doc = order_ref.get()

    if order_doc.exists:
        order_data = order_doc.to_dict()

        # Atomic: restore stock + mark order cancelled in a single batch
        batch = get_db().batch()

        if not order_data.get(Fields.STOCK_RESTORED, False):
            _add_stock_restore_to_batch(batch, order_data)

        batch.update(
            order_ref,
            {
                Fields.ORDER_STATUS: OrderStatusValues.CANCELLED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.PAYMENT_FAILED,
                Fields.STOCK_RESTORED: True,
                Fields.UPDATED_AT: get_server_timestamp(),
            },
        )
        batch.commit()

        try:
            OrderEvent.write(
                get_db(), order_id, OrderEventTypes.PAYMENT_FAILED,
                actor="stripe_webhook", actor_type="system",
                to_status=PaymentStatusValues.PAYMENT_FAILED,
            )
        except Exception as e:
            logger.warning(f"Failed to write order event for {order_id}: {e}")

        # Notify buyer that payment capture failed so they can update payment method
        try:
            from services.email_service import send_payment_capture_failed_email
            buyer_email = order_data.get(Fields.CUSTOMER_EMAIL)
            if not buyer_email:
                buyer_doc = get_db().collection(Collections.USERS).document(order_data.get(Fields.USER_ID, "")).get()
                if buyer_doc.exists:
                    buyer_email = (buyer_doc.to_dict() or {}).get(Fields.EMAIL)
            if buyer_email:
                buyer_name = order_data.get(Fields.CUSTOMER_NAME, "")
                lang = order_data.get(Fields.PREFERRED_LANGUAGE, "en")
                amount = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100
                send_payment_capture_failed_email(
                    order_id=order_id,
                    customer_email=buyer_email,
                    customer_name=buyer_name,
                    amount=amount,
                    error_message="Payment could not be processed",
                    lang=lang,
                )
        except Exception as email_err:
            logger.warning(f"Failed to send payment capture failed email for order {order_id}: {email_err}")

    return f"Order {order_id} cancelled due to payment failure"


def _add_stock_restore_to_batch(batch, order_data: dict) -> None:
    """Adds stock increment operations to an existing batch."""
    _fs = get_firestore()
    for item in order_data.get(Fields.ITEMS, []):
        if item.get(Fields.IS_DIGITAL, False):
            continue  # digital products have no physical stock to restore
        product_ref = get_db().collection(Collections.PRODUCTS).document(item[Fields.PRODUCT_ID])
        qty = item[Fields.QUANTITY]
        patch = {Fields.STOCK_QUANTITY: _fs.Increment(qty)}

        fulfillment_wh = item.get(Fields.FULFILLMENT_WAREHOUSE_ID)
        if fulfillment_wh:
            patch[f"{Fields.WAREHOUSE_STOCK}.{fulfillment_wh}"] = _fs.Increment(qty)
            # Also restore inventoryLevels subcollection (safe if doc doesn't exist yet — merge=True)
            inv_ref = product_ref.collection(Collections.INVENTORY_LEVELS).document(fulfillment_wh)
            batch.set(inv_ref, {
                Fields.AVAILABLE_QUANTITY: _fs.Increment(qty),
                Fields.LAST_SYNCED_AT: get_server_timestamp(),
            }, merge=True)

        batch.update(product_ref, patch)


def _add_stock_restore_to_transaction(transaction, order_data: dict) -> None:
    """Adds stock increment operations to an existing transaction.

    Handles stockQuantity, warehouseStock map, and inventoryLevels subcollection
    so all three inventory signals stay in sync after payment failure/cancellation.
    """
    _fs = get_firestore()
    for item in order_data.get(Fields.ITEMS, []):
        if item.get(Fields.IS_DIGITAL, False):
            continue  # digital products have no physical stock to restore
        product_ref = get_db().collection(Collections.PRODUCTS).document(item[Fields.PRODUCT_ID])
        qty = item[Fields.QUANTITY]
        patch = {Fields.STOCK_QUANTITY: _fs.Increment(qty)}

        fulfillment_wh = item.get(Fields.FULFILLMENT_WAREHOUSE_ID)
        if fulfillment_wh:
            patch[f"{Fields.WAREHOUSE_STOCK}.{fulfillment_wh}"] = _fs.Increment(qty)

        transaction.update(product_ref, patch)

        # F-69: Restore inventoryLevels subcollection (transaction.set with merge=True is supported)
        if fulfillment_wh:
            inv_ref = product_ref.collection(Collections.INVENTORY_LEVELS).document(fulfillment_wh)
            transaction.set(inv_ref, {
                Fields.AVAILABLE_QUANTITY: _fs.Increment(qty),
                Fields.LAST_SYNCED_AT: get_server_timestamp(),
            }, merge=True)


def _restore_stock_for_order(order_data: dict) -> None:
    """Restores product stock after order cancellation using batch write for atomicity."""
    batch = get_db().batch()
    _add_stock_restore_to_batch(batch, order_data)
    batch.commit()


def _restore_stock_and_cancel_order(order_id: str, order_data: dict, reason: str) -> None:
    """
    Restores stock and cancels order when validation fails post-payment.
    Uses a transaction to ensure stock is only restored once (F-69).
    """
    @get_transactional()
    def _do_rollback(transaction):
        order_ref = get_db().collection(Collections.ORDERS).document(order_id)
        # Re-read within transaction for atomicity
        order_snap = order_ref.get(transaction=transaction)
        if not order_snap.exists:
            return

        fresh_data = order_snap.to_dict()
        if fresh_data.get(Fields.STOCK_RESTORED, False):
            logger.info(f"Stock already restored for order {order_id} - skipping")
            return

        # Restore stock using atomic increment
        _add_stock_restore_to_transaction(transaction, fresh_data)

        # Update order status
        transaction.update(
            order_ref,
            {
                Fields.ORDER_STATUS: OrderStatusValues.CANCELLED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CANCELLED,
                Fields.CANCELLATION_REASON: reason,
                Fields.STOCK_RESTORED: True,
                Fields.CANCELLED_AT: get_server_timestamp(),
                Fields.UPDATED_AT: get_server_timestamp(),
            },
        )

    _do_rollback(get_db().transaction())

    # Refund/cancel the PaymentIntent to release buyer funds
    # With auto-capture, PI is in 'succeeded' state — must use refund, not cancel
    payment_intent_id = order_data.get(Fields.STRIPE_PAYMENT_INTENT_ID)
    if payment_intent_id:
        refund_succeeded = False
        try:
            # Try to retrieve PI to check its current state
            ensure_stripe_key()
            pi = stripe.PaymentIntent.retrieve(payment_intent_id)
            if pi.status == StripeConstants.STATUS_SUCCEEDED:
                # Auto-captured: must refund (cannot cancel a succeeded PI)
                stripe.Refund.create(
                    payment_intent=payment_intent_id,
                    reason="requested_by_customer",
                    metadata={Fields.ORDER_ID: order_id, Fields.REASON: reason[:500]},
                    idempotency_key=f"refund_invalidated_{order_id}",
                )
                refund_succeeded = True
            elif pi.status == StripeConstants.STATUS_REQUIRES_CAPTURE:
                # Manual capture mode: cancel releases the authorization
                stripe.PaymentIntent.cancel(
                    payment_intent_id,
                    cancellation_reason="abandoned",
                )
                refund_succeeded = True
            elif pi.status in ("requires_payment_method", "requires_confirmation", "requires_action"):
                # Not yet charged: safe to cancel
                stripe.PaymentIntent.cancel(
                    payment_intent_id,
                    cancellation_reason="abandoned",
                )
                refund_succeeded = True
            else:
                logger.warning(f"⚠️ PI {payment_intent_id} in unexpected state: {pi.status}, skipping refund/cancel")
        except stripe.error.StripeError as e:
            logger.critical(f"🚨 CRITICAL: Failed to refund/cancel PI for invalidated order {order_id}: {str(e)}")
            # SECURITY FIX: If refund fails, flag for manual review — buyer must not lose money
            get_db().collection(Collections.SECURITY_ALERTS).add(
                {
                    Fields.TYPE: SecurityAlertTypes.REFUND_FAILED,
                    Fields.SEVERITY: SeverityLevels.CRITICAL,
                    Fields.ORDER_ID: order_id,
                    Fields.PAYMENT_INTENT_ID: payment_intent_id,
                    Fields.REASON: f"Refund/cancel failed during post-payment validation ({type(e).__name__}). Check logs.",
                    Fields.TIMESTAMP: get_server_timestamp(),
                    Fields.RESOLVED: False,
                }
            )

        # If refund failed, mark order for manual review instead of silently closing
        if not refund_succeeded:
            order_ref = get_db().collection(Collections.ORDERS).document(order_id)
            order_ref.update(
                {
                    Fields.REQUIRES_MANUAL_REVIEW: True,
                    Fields.MANUAL_REVIEW_REASON: f"Refund/cancel failed for invalidated order: {reason}",
                    Fields.UPDATED_AT: get_server_timestamp(),
                }
            )


def process_session_expired(session: dict) -> str | None:
    """Handles expired checkout sessions"""
    order_id = session.get(StripeConstants.METADATA, {}).get(StripeConstants.METADATA_ORDER_ID)

    if not order_id:
        return None

    order_ref = get_db().collection(Collections.ORDERS).document(order_id)

    @get_transactional()
    def _expire_in_transaction(transaction):
        order_doc = order_ref.get(transaction=transaction)
        if not order_doc.exists:
            return False

        order_data = order_doc.to_dict()

        # IDEMPOTENCY FIX: Only restore stock once per order (atomic via transaction)
        if not order_data.get(Fields.STOCK_RESTORED, False):
            _fs = get_firestore()
            for item in order_data.get(Fields.ITEMS, []):
                if item.get(Fields.IS_DIGITAL, False):
                    continue  # digital products have no physical stock to restore
                product_ref = get_db().collection(Collections.PRODUCTS).document(item[Fields.PRODUCT_ID])
                qty = item[Fields.QUANTITY]
                transaction.update(product_ref, {Fields.STOCK_QUANTITY: _fs.Increment(qty)})
                fulfillment_wh = item.get(Fields.FULFILLMENT_WAREHOUSE_ID)
                if fulfillment_wh:
                    transaction.update(
                        product_ref,
                        {f"{Fields.WAREHOUSE_STOCK}.{fulfillment_wh}": _fs.Increment(qty)},
                    )
                    # Also restore inventoryLevels subcollection
                    inv_ref = product_ref.collection(Collections.INVENTORY_LEVELS).document(fulfillment_wh)
                    transaction.set(
                        inv_ref,
                        {
                            Fields.AVAILABLE_QUANTITY: _fs.Increment(qty),
                            Fields.LAST_SYNCED_AT: get_server_timestamp(),
                        },
                        merge=True,
                    )

        transaction.update(
            order_ref,
            {
                Fields.ORDER_STATUS: OrderStatusValues.EXPIRED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.SESSION_EXPIRED,
                Fields.STOCK_RESTORED: True,
                Fields.UPDATED_AT: get_server_timestamp(),
            },
        )
        return True

    _expire_in_transaction(get_db().transaction())

    return f"Order {order_id} expired"


def process_payment_intent_succeeded(payment_intent: dict) -> str | None:
    """Handles successful payment intents.

    SECURITY FIX (CRITICAL-024): Only update if payment is in a state that
    should transition to CAPTURED. Prevents overwriting 'authorized' set by
    checkout.session.completed (which uses manual capture mode).
    For manual capture mode orders, the capture_payment function handles the
    AUTHORIZED → CAPTURING → CAPTURED transition. This webhook fires when
    capture succeeds, so we only update if still in 'capturing' state.
    """
    order_id = payment_intent.get(StripeConstants.METADATA, {}).get(StripeConstants.METADATA_ORDER_ID)

    if not order_id:
        return None

    order_ref = get_db().collection(Collections.ORDERS).document(order_id)
    order_doc = order_ref.get()

    if not order_doc.exists:
        return None

    order_data = order_doc.to_dict()
    current_status = order_data.get(Fields.PAYMENT_STATUS)

    # Only update to CAPTURED if order is in a transitional state.
    # If already CAPTURED, REFUNDED, etc., do not overwrite.
    capturable_states = {PaymentStatusValues.CAPTURING, PaymentStatusValues.AWAITING_PAYMENT}
    if current_status in capturable_states:
        order_ref.update(
            {Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED, Fields.UPDATED_AT: get_server_timestamp()}
        )
        return f"Payment captured for order {order_id}"

    if current_status == PaymentStatusValues.CAPTURED:
        return f"Payment already captured for order {order_id} (idempotent)"

    # For manual capture mode (authorized state), do NOT overwrite to captured.
    # The capture_payment function handles this transition properly.
    logger.info(f"ℹ️ payment_intent.succeeded for order {order_id} skipped: current status={current_status}")
    return f"Order {order_id} status unchanged (current: {current_status})"


def process_payment_intent_failed(payment_intent: dict) -> str | None:
    """Handles failed payment intents"""
    order_id = payment_intent.get(StripeConstants.METADATA, {}).get(StripeConstants.METADATA_ORDER_ID)

    if not order_id:
        return None

    order_ref = get_db().collection(Collections.ORDERS).document(order_id)

    @get_transactional()
    def _fail_in_transaction(transaction):
        order_doc = order_ref.get(transaction=transaction)
        if not order_doc.exists:
            return False

        order_data = order_doc.to_dict()

        # CRITICAL FIX: Restore all stock fields (stockQuantity + warehouseStock) atomically
        if not order_data.get(Fields.STOCK_RESTORED, False):
            _add_stock_restore_to_transaction(transaction, order_data)

        transaction.update(
            order_ref,
            {
                Fields.ORDER_STATUS: OrderStatusValues.CANCELLED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.PAYMENT_FAILED,
                Fields.STOCK_RESTORED: True,
                Fields.UPDATED_AT: get_server_timestamp(),
            },
        )
        return True

    _fail_in_transaction(get_db().transaction())

    return f"Payment failed for order {order_id}"


def process_payment_intent_canceled(payment_intent: dict) -> str | None:
    """
    Handles canceled payment intents.
    Restores stock and cancels the order when a PI is canceled
    (e.g., session expired, user abandon, or admin cancellation).
    """
    order_id = payment_intent.get(StripeConstants.METADATA, {}).get(StripeConstants.METADATA_ORDER_ID)

    if not order_id:
        return None

    order_ref = get_db().collection(Collections.ORDERS).document(order_id)

    @get_transactional()
    def _cancel_in_transaction(transaction):
        order_doc = order_ref.get(transaction=transaction)
        if not order_doc.exists:
            return None

        order_data = order_doc.to_dict()

        # Skip if already in terminal state
        current_status = order_data.get(Fields.ORDER_STATUS)
        terminal_states = {OrderStatusValues.CANCELLED, OrderStatusValues.EXPIRED}
        if current_status in terminal_states:
            return f"already_terminal:{current_status}"

        # Restore stock idempotently — all three stock fields (stockQuantity + warehouseStock)
        if not order_data.get(Fields.STOCK_RESTORED, False):
            _add_stock_restore_to_transaction(transaction, order_data)

        transaction.update(
            order_ref,
            {
                Fields.ORDER_STATUS: OrderStatusValues.CANCELLED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CANCELLED,
                Fields.STOCK_RESTORED: True,
                Fields.CANCELLED_AT: get_server_timestamp(),
                Fields.UPDATED_AT: get_server_timestamp(),
            },
        )
        return "cancelled"

    result = _cancel_in_transaction(get_db().transaction())
    if result and result.startswith("already_terminal:"):
        status = result.split(":")[1]
        return f"Order {order_id} already in terminal state: {status} (idempotent)"

    return f"Payment canceled for order {order_id}"


def process_charge_refunded(charge: dict) -> str | None:
    """
    Handles charge refunds — distinguishes full vs partial refunds.
    AUDIT FIX (CRITICAL-019): Automatically reverses transfers to sellers
    when a refund is processed, preventing platform financial loss.
    """
    payment_intent_id = charge.get(StripeConstants.PAYMENT_INTENT)

    if not payment_intent_id:
        return None

    # Determine if full or partial refund
    amount_refunded = charge.get("amount_refunded", 0)
    amount_total = charge.get(Fields.AMOUNT, 0)
    is_full_refund = (amount_refunded >= amount_total) if amount_total > 0 else True

    # Find order by payment intent
    orders = (
        get_db()
        .collection(Collections.ORDERS)
        .where(Fields.STRIPE_PAYMENT_INTENT_ID, "==", payment_intent_id)
        .limit(1)
        .stream()
    )

    for order_doc in orders:
        order_ref = order_doc.reference
        order_id = order_doc.id
        order_data = order_doc.to_dict()

        # AUDIT FIX (CRITICAL-018): Block refund processing if capture or cancel is in progress.
        # This prevents the race condition where refund + capture execute simultaneously.
        current_payment_status = order_data.get(Fields.PAYMENT_STATUS, "")
        if current_payment_status in (PaymentStatusValues.CAPTURING, PaymentStatusValues.CANCELLING):
            logger.warning(
                f"⚠️ Refund webhook for order {order_id} blocked — payment status is {current_payment_status}"
            )
            # Return 500-equivalent to trigger Stripe retry (status will resolve by then)
            raise Exception(f"Order {order_id} has transitional payment status: {current_payment_status}. Retry later.")

        # SECURITY FIX (CRITICAL-017): Idempotency — check if this refund amount
        # was already processed to prevent duplicate reversals on webhook retry.
        previously_refunded = order_data.get(Fields.CUMULATIVE_REFUNDED_CENTS, 0)
        if previously_refunded >= amount_refunded:
            logger.info(
                f"ℹ️ Refund for order {order_id} already processed (cumulative={previously_refunded}, current={amount_refunded})"
            )
            return f"Order {order_id} refund already processed (idempotent)"

        # AUDIT FIX (CRITICAL-019): Reverse transfers to sellers on refund.
        # Without this, the platform refunds the buyer but sellers keep their payout.
        reversed_count = 0
        reversal_errors = []

        payouts = (
            get_db()
            .collection(Collections.PAYOUTS)
            .where(Fields.ORDER_ID, "==", order_id)
            .where(Fields.STATUS, "in", [PayoutStatusValues.COMPLETED, PayoutStatusValues.PARTIALLY_REVERSED])
            .limit(50)  # Cost fix: orders have ≤50 sellers; unbounded stream was wasteful
            .stream()
        )

        for payout_doc in payouts:
            payout_data = payout_doc.to_dict()
            transfer_id = payout_data.get(Fields.STRIPE_TRANSFER_ID)

            if not transfer_id:
                continue

            # SECURITY FIX (HIGH-019): Calculate remaining reversible amount
            # to prevent over-reversal on multiple partial refunds.
            already_reversed_cents = payout_data.get(Fields.CUMULATIVE_REVERSED_CENTS, 0)
            payout_net = payout_data.get(Fields.NET_AMOUNT_CENTS, 0)
            max_reversible = payout_net - already_reversed_cents

            if max_reversible <= 0:
                logger.info(f"ℹ️ Payout {payout_doc.id} fully reversed already, skipping")
                continue

            try:
                # PAY-M3: No pre-check on seller account status — if the account
                # is deactivated or funds withdrawn, Stripe returns a StripeError
                # which is caught below and escalated via SECURITY_ALERTS.
                # This is monitored rather than pre-checked to avoid an extra API call per payout.
                reversal_kwargs = {
                    StripeConstants.METADATA: {
                        Fields.REASON: "refund",
                        Fields.ORDER_ID: order_id,
                        "refundType": "full" if is_full_refund else "partial",
                    }
                }
                # For partial refunds, only reverse proportional amount
                # but cap at max_reversible to prevent over-reversal
                # SECURITY FIX (AUDIT): Use amount_total (includes tax+shipping) as denominator.
                # order_subtotal excludes tax/shipping but amount_refunded can include them.
                # Using subtotal as denominator causes numerator > denominator → over-reversal
                # that penalizes sellers for money they never received.
                # amount_total comes from the charge object and includes tax+shipping — correct denominator
                order_total_for_ratio = amount_total if amount_total > 0 else order_data.get(Fields.SUBTOTAL_CENTS, 1)
                if not is_full_refund and order_total_for_ratio > 0:
                    # Compute cumulative target reversal for this payout based on total refunded,
                    # then subtract what was already reversed to get the DELTA for this call.
                    # Using the raw cumulative `amount_refunded` without subtracting `already_reversed`
                    # would over-reverse on subsequent partial refunds (e.g., $10 then $10 → second
                    # webhook would reverse $20 cumulative instead of the $10 delta).
                    cumulative_target = round(payout_net * amount_refunded / order_total_for_ratio)
                    reversal_delta = cumulative_target - already_reversed_cents
                    reversal_delta = min(max(reversal_delta, 0), max_reversible)
                    if reversal_delta > 0:
                        reversal_kwargs[Fields.AMOUNT] = reversal_delta
                else:
                    # Full refund: reverse remaining (not already reversed)
                    if already_reversed_cents > 0:
                        reversal_kwargs[Fields.AMOUNT] = max_reversible

                reversal = stripe.Transfer.create_reversal(transfer_id, **reversal_kwargs)

                # Calculate actual reversed amount for tracking
                actual_reversed = reversal_kwargs.get(Fields.AMOUNT, payout_net)
                new_cumulative = already_reversed_cents + actual_reversed
                new_status = (
                    PayoutStatusValues.REVERSED
                    if new_cumulative >= payout_net
                    else PayoutStatusValues.PARTIALLY_REVERSED
                )

                payout_doc.reference.update(
                    {
                        Fields.STATUS: new_status,
                        Fields.REVERSAL_ID: reversal.id,
                        Fields.REVERSED_AT: get_server_timestamp(),
                        Fields.REVERSAL_REASON: "refund",
                        Fields.CUMULATIVE_REVERSED_CENTS: new_cumulative,
                    }
                )
                reversed_count += 1
                logger.info(
                    f"✓ Reversed transfer {transfer_id} for refund on order {order_id} (amount={actual_reversed})"
                )

            except Exception as e:
                logger.warning(f"⚠️ Failed to reverse transfer {transfer_id} on refund: {str(e)}")
                reversal_errors.append({Fields.TRANSFER_ID: transfer_id, Fields.ERROR: type(e).__name__})

        # Log security alert and auto-suspend sellers if any reversals failed
        if reversal_errors:
            get_db().collection(Collections.SECURITY_ALERTS).add(
                {
                    Fields.TYPE: SecurityAlertTypes.REFUND_REVERSAL_FAILED,
                    Fields.SEVERITY: SeverityLevels.CRITICAL,
                    Fields.ORDER_ID: order_id,
                    Fields.REVERSAL_ERRORS: reversal_errors,
                    Fields.TIMESTAMP: get_server_timestamp(),
                    Fields.RESOLVED: False,
                }
            )

            # AUDIT FIX (CRITICAL-014): Auto-suspend sellers whose transfer reversals
            # failed (likely insufficient funds — seller withdrew). This prevents
            # further payouts until the platform recovers the funds.
            for err in reversal_errors:
                failed_transfer_id = err.get(Fields.TRANSFER_ID, "")
                if not failed_transfer_id:
                    continue
                # Find the seller for this failed transfer
                failed_payout = (
                    get_db()
                    .collection(Collections.PAYOUTS)
                    .where(Fields.STRIPE_TRANSFER_ID, "==", failed_transfer_id)
                    .limit(1)
                    .get()
                )
                for fp_doc in failed_payout:
                    fp_seller_id = fp_doc.to_dict().get(Fields.SELLER_ID)
                    if fp_seller_id:
                        try:
                            get_db().collection(Collections.USERS).document(fp_seller_id).update(
                                {
                                    Fields.SUSPENDED: True,
                                    Fields.SUSPENSION_REASON: f"Transfer reversal failed for order {order_id}. Manual review required.",
                                    Fields.SUSPENDED_AT: get_server_timestamp(),
                                }
                            )
                            logger.error(f"🚫 Auto-suspended seller {fp_seller_id} due to failed transfer reversal")

                            # A-05/F-139: Record platform debt for audit trail and manual recovery
                            # This fires when seller has zero Stripe balance and reversal fails.
                            debt_amount = fp_doc.to_dict().get(Fields.AMOUNT_CENTS, 0)
                            get_db().collection(Collections.PLATFORM_DEBT).add(
                                {
                                    Fields.ORDER_ID: order_id,
                                    Fields.SELLER_ID: fp_seller_id,
                                    Fields.TRANSFER_ID: failed_transfer_id,
                                    Fields.AMOUNT_CENTS: debt_amount,
                                    Fields.STATUS: PlatformDebtStatusValues.OPEN,
                                    Fields.REASON: "Transfer reversal failed — seller zero balance",
                                    Fields.CREATED_AT: get_server_timestamp(),
                                    Fields.RESOLVED: False,
                                }
                            )
                            logger.critical(
                                f"🚨 PLATFORM DEBT created for seller {fp_seller_id}: order={order_id} "
                                f"transfer={failed_transfer_id} amount={debt_amount} cents"
                            )
                        except Exception as suspend_err:
                            logger.critical(
                                f"🚨 CRITICAL: Failed to suspend seller {fp_seller_id} after transfer reversal failure: {type(suspend_err).__name__}"
                            )



        # Revoke digital licenses on any refund (lifetime license model — any refund invalidates)
        try:
            from handlers.digital import _revoke_digital_licenses_for_order

            revoked_count = _revoke_digital_licenses_for_order(order_id)
            if revoked_count:
                logger.info(f"Revoked {revoked_count} digital license(s) for refunded order {order_id}")
        except Exception as revoke_err:
            # Non-fatal: log but do not fail the refund webhook
            logger.error(f"License revocation failed for order {order_id}: {revoke_err}")

        # C-1: Restore stock when a charge is fully refunded
        if is_full_refund:
            if not order_data.get(Fields.STOCK_RESTORED, False):
                try:
                    _restore_stock_for_order(order_data)
                    # We will update STOCK_RESTORED in the big update below
                    order_data[Fields.STOCK_RESTORED] = True
                    logger.info(f"Restored stock for refunded order {order_id}")
                except Exception as e:
                    logger.error(f"Failed to restore stock for refunded order {order_id}: {e}")

            order_ref.update(
                {
                    Fields.PAYMENT_STATUS: PaymentStatusValues.REFUNDED,
                    Fields.TRANSFERS_REVERSED: reversed_count,
                    # SET (not Increment): amount_refunded is already the cumulative total from Stripe.
                    # Using Increment would double-count on webhook retries or sequential partial refunds.
                    Fields.CUMULATIVE_REFUNDED_CENTS: amount_refunded,
                    Fields.STOCK_RESTORED: order_data.get(Fields.STOCK_RESTORED, False),
                    Fields.REFUNDED_AT: get_server_timestamp(),
                    Fields.UPDATED_AT: get_server_timestamp(),
                }
            )
            return f"Order {order_id} fully refunded, reversed {reversed_count} transfers"
        else:
            order_ref.update(
                {
                    Fields.PAYMENT_STATUS: PaymentStatusValues.PARTIALLY_REFUNDED,
                    Fields.PARTIAL_REFUND_AMOUNT_CENTS: amount_refunded,
                    # SET (not Increment): amount_refunded is the cumulative total from Stripe.
                    Fields.CUMULATIVE_REFUNDED_CENTS: amount_refunded,
                    Fields.TRANSFERS_REVERSED: reversed_count,
                    Fields.REFUNDED_AT: get_server_timestamp(),
                    Fields.UPDATED_AT: get_server_timestamp(),
                }
            )
            return f"Order {order_id} partially refunded ({amount_refunded} cents), reversed {reversed_count} transfers"

    return None


def process_dispute_created(dispute: dict) -> str | None:
    """
    Handles dispute creation - CRITICAL PAYMENT INTEGRITY
    When a buyer disputes a charge, we must immediately reverse transfers to sellers
    to prevent double-loss (platform refunds buyer + already paid seller).
    """
    charge_id = dispute.get(StripeConstants.CHARGE)
    # CRITICAL FIX: Use payment_intent from dispute (not charge_id!)
    # charge_id is 'ch_xxx' but orders store 'pi_xxx' as stripePaymentIntentId
    payment_intent_id = dispute.get(StripeConstants.PAYMENT_INTENT)
    dispute_amount = dispute.get(Fields.AMOUNT, 0)

    # Log security alert (ORDER_ID added after lookup below)
    alert_ref = (
        get_db()
        .collection(Collections.SECURITY_ALERTS)
        .add(
            {
                Fields.TYPE: SecurityAlertTypes.DISPUTE_CREATED,
                Fields.SEVERITY: SeverityLevels.HIGH,
                Fields.CHARGE_ID: charge_id,
                Fields.PAYMENT_INTENT_ID: payment_intent_id,
                Fields.AMOUNT: dispute_amount,
                Fields.REASON: dispute.get(Fields.REASON),
                Fields.TIMESTAMP: get_server_timestamp(),
                Fields.RESOLVED: False,
            }
        )
    )

    if not payment_intent_id:
        logger.warning(f"⚠️ Dispute {dispute.get(StripeConstants.OBJECT_ID)} has no payment_intent, cannot find order")
        return f"Dispute logged for charge {charge_id}, no payment_intent to look up order"

    # CRITICAL: Auto-reverse all transfers linked to this payment intent
    orders = (
        get_db()
        .collection(Collections.ORDERS)
        .where(Fields.STRIPE_PAYMENT_INTENT_ID, "==", payment_intent_id)
        .limit(1)
        .stream()
    )

    reversed_count = 0
    order_doc = None  # initialized before loop to prevent UnboundLocalError if no order found
    order_id = None
    for order_doc in orders:
        order_id = order_doc.id

        # CRITICAL FIX: Add ORDER_ID to security alert for capture-block query
        alert_ref[1].update({Fields.ORDER_ID: order_id})

        # Find all completed payouts for this order
        payouts = (
            get_db()
            .collection(Collections.PAYOUTS)
            .where(Fields.ORDER_ID, "==", order_id)
            .where(Fields.STATUS, "==", PayoutStatusValues.COMPLETED)
            .stream()
        )

        order_data_for_dispute = order_doc.to_dict()
        order_total = order_data_for_dispute.get(Fields.TOTAL_AMOUNT_CENTS, 0)

        for payout_doc in payouts:
            payout_data = payout_doc.to_dict()
            transfer_id = payout_data.get(Fields.STRIPE_TRANSFER_ID)

            if not transfer_id:
                # AUDIT FIX (D1-1): Alert on missing transfer ID instead of silent skip
                logger.error(f"🚨 DISPUTE: Payout {payout_doc.id} has no stripeTransferId — cannot reverse")
                # NOTE: Use datetime.now() inside ArrayUnion — Firestore SDK
                # cannot serialize SERVER_TIMESTAMP sentinels inside arrays.
                alert_ref[1].update(
                    {
                        Fields.REVERSAL_ERRORS: get_firestore().ArrayUnion(
                            [
                                {
                                    Fields.PAYOUT_ID: payout_doc.id,
                                    Fields.ERROR: "Missing stripeTransferId — manual reversal required",
                                    Fields.TIMESTAMP: datetime.now(UTC),
                                }
                            ]
                        )
                    }
                )
                continue

            try:
                # AUDIT FIX (MEDIUM-025): For partial disputes, reverse proportional
                # amount instead of full transfer to avoid penalizing uninvolved sellers.
                reversal_kwargs = {
                    StripeConstants.METADATA: {
                        Fields.REASON: "dispute",
                        Fields.DISPUTE_ID: dispute.get(StripeConstants.OBJECT_ID),
                        Fields.ORDER_ID: order_id,
                    }
                }
                payout_net = payout_data.get(Fields.NET_AMOUNT_CENTS, 0)

                # AUDIT FIX (D1-5): Track cumulative reversed cents to prevent double-reversal
                already_reversed_cents = payout_data.get(Fields.CUMULATIVE_REVERSED_CENTS, 0)
                max_reversible = payout_net - already_reversed_cents
                if max_reversible <= 0:
                    logger.info(f"✓ Transfer {transfer_id} already fully reversed (idempotent skip)")
                    continue

                if dispute_amount and order_total and dispute_amount < order_total:
                    proportional_reversal = round(payout_net * dispute_amount / order_total)
                    proportional_reversal = min(proportional_reversal, max_reversible)
                    if proportional_reversal > 0:
                        reversal_kwargs[Fields.AMOUNT] = proportional_reversal
                else:
                    # Full reversal — cap at max reversible
                    if max_reversible < payout_net:
                        reversal_kwargs[Fields.AMOUNT] = max_reversible

                # Guard: skip zero-amount reversal to avoid Stripe API error
                if reversal_kwargs.get(Fields.AMOUNT, payout_net) <= 0:
                    logger.warning(f"Skipping zero-amount reversal for transfer {transfer_id}")
                    continue

                reversal = stripe.Transfer.create_reversal(
                    transfer_id,
                    **reversal_kwargs,
                    idempotency_key=f"dispute_reversal_{dispute.get(StripeConstants.OBJECT_ID)}_{transfer_id}",
                )

                # Mark payout as reversed with cumulative tracking
                reversal_amount = reversal_kwargs.get(Fields.AMOUNT, payout_net)
                new_cumulative = already_reversed_cents + reversal_amount
                new_status = (
                    PayoutStatusValues.REVERSED
                    if new_cumulative >= payout_net
                    else PayoutStatusValues.PARTIALLY_REVERSED
                )
                payout_doc.reference.update(
                    {
                        Fields.STATUS: new_status,
                        Fields.REVERSAL_ID: reversal.id,
                        Fields.REVERSED_AT: get_server_timestamp(),
                        Fields.REVERSAL_REASON: "dispute",
                        Fields.CUMULATIVE_REVERSED_CENTS: new_cumulative,
                    }
                )

                reversed_count += 1
                logger.info(f"✓ Reversed transfer {transfer_id} due to dispute ({reversal_amount}¢)")

            except stripe.error.InvalidRequestError as e:
                # AUDIT FIX (D1-2): Handle specific Stripe errors (already reversed, insufficient funds)
                error_code = getattr(e, "code", "unknown")
                logger.warning(f"⚠️ Stripe error reversing transfer {transfer_id}: {error_code} - {str(e)}")
                is_insufficient = "insufficient" in str(e).lower()
                alert_ref[1].update(
                    {
                        Fields.REVERSAL_ERRORS: get_firestore().ArrayUnion(
                            [
                                {
                                    Fields.TRANSFER_ID: transfer_id,
                                    Fields.ERROR: f"{type(e).__name__}: {error_code}",
                                    Fields.ERROR_CODE: error_code,
                                    Fields.SEVERITY: SeverityLevels.CRITICAL
                                    if is_insufficient
                                    else SeverityLevels.HIGH,
                                    Fields.TIMESTAMP: datetime.now(UTC),
                                }
                            ]
                        )
                    }
                )

                # AUDIT FIX (CRITICAL-016): Auto-suspend seller on insufficient funds
                # This means the seller withdrew funds — block further payouts
                if is_insufficient:
                    seller_id_from_payout = payout_data.get(Fields.SELLER_ID)
                    if seller_id_from_payout:
                        try:
                            get_db().collection(Collections.USERS).document(seller_id_from_payout).update(
                                {
                                    Fields.SUSPENDED: True,
                                    Fields.SUSPENSION_REASON: f"Dispute reversal failed (insufficient funds) for dispute {dispute.get(StripeConstants.OBJECT_ID)}. Manual review required.",
                                    Fields.SUSPENDED_AT: get_server_timestamp(),
                                }
                            )
                            logger.info(
                                f"🚫 Auto-suspended seller {seller_id_from_payout} due to insufficient funds during dispute reversal"
                            )
                        except Exception as suspend_err:
                            logger.critical(
                                f"🚨 CRITICAL: Failed to suspend seller {seller_id_from_payout} after dispute reversal failure: {type(suspend_err).__name__}"
                            )

            except (stripe.error.StripeError, ValueError, TypeError, RuntimeError) as e:
                # Log failure and continue processing other transfers
                logger.warning(f"⚠️ Failed to reverse transfer {transfer_id}: {str(e)}")
                alert_ref[1].update(
                    {
                        Fields.REVERSAL_ERRORS: get_firestore().ArrayUnion(
                            [
                                {
                                    Fields.TRANSFER_ID: transfer_id,
                                    Fields.ERROR: type(e).__name__,
                                    Fields.TIMESTAMP: datetime.now(UTC),
                                }
                            ]
                        )
                    }
                )

        # AUDIT FIX (D1-3): Update order status to reflect dispute
        # Store pre-dispute status for restoration if dispute is won
        current_status = order_doc.to_dict().get(Fields.ORDER_STATUS, OrderStatusValues.PENDING)
        order_doc.reference.update(
            {
                Fields.ORDER_STATUS: OrderStatusValues.DISPUTED,
                Fields.PRE_DISPUTE_STATUS: current_status,
                Fields.DISPUTE_ID: dispute.get(StripeConstants.OBJECT_ID),
                Fields.DISPUTED_AT: get_server_timestamp(),
                Fields.UPDATED_AT: get_server_timestamp(),
            }
        )

    # AUDIT FIX #32: Send dispute notification emails to affected sellers
    try:
        if order_doc and order_doc.exists:
            order_data = order_doc.to_dict()
            seller_ids = set(item.get(Fields.SELLER_ID) for item in order_data.get(Fields.ITEMS, []))
            for seller_id in seller_ids:
                if not seller_id:
                    continue
                seller_doc = get_db().collection(Collections.USERS).document(seller_id).get()
                if seller_doc.exists:
                    seller_email = seller_doc.to_dict().get(Fields.EMAIL)
                    if seller_email:
                        enqueue_email_task(
                            to_email=seller_email,
                            subject="⚠️ Payment Dispute Received - Origna",
                            html_content=f"""
                            <h2>A payment dispute has been filed</h2>
                            <p>A buyer has filed a dispute for an order containing your products.</p>
                            <p><strong>Order ID:</strong> {order_id}</p>
                            <p><strong>Dispute reason:</strong> {dispute.get(StripeConstants.REASON, "Not specified")}</p>
                            <p><strong>Amount:</strong> ${dispute.get(StripeConstants.AMOUNT, 0) / 100:.2f} {dispute.get(StripeConstants.CURRENCY, "CAD").upper()}</p>
                            <p>Your seller transfers for this order have been reversed pending dispute resolution.</p>
                            <p>Please review your order records and prepare any evidence (shipping confirmation, delivery proof, communication) that may help resolve this dispute.</p>
                            <p>— Origna Team</p>
                            """,
                            event_type=OrderEventTypes.DISPUTE_CREATED,
                            order_id=order_id,
                        )
    except Exception as e:
        logger.error(f"Failed to send dispute notification emails: {type(e).__name__}")

    return f"Dispute logged for charge {charge_id}, reversed {reversed_count} transfers"


def process_dispute_updated(dispute: dict) -> str | None:
    """
    Handles charge.dispute.updated — logs evidence updates and status changes.

    Stripe sends this when:
    - Evidence is submitted
    - Dispute status changes (e.g., needs_response → under_review)
    - Evidence due date changes
    """
    dispute_id = dispute.get(StripeConstants.OBJECT_ID)
    charge_id = dispute.get(StripeConstants.CHARGE)
    payment_intent_id = dispute.get(StripeConstants.PAYMENT_INTENT)
    status = dispute.get(Fields.STATUS)
    reason = dispute.get(Fields.REASON)

    logger.info(f"Dispute updated: {dispute_id} status={status} reason={reason}")

    # Update security alert with latest dispute status
    if charge_id:
        alerts = (
            get_db()
            .collection(Collections.SECURITY_ALERTS)
            .where(Fields.CHARGE_ID, "==", charge_id)
            .where(Fields.TYPE, "==", SecurityAlertTypes.DISPUTE_CREATED)
            .limit(1)
            .stream()
        )

        for alert_doc in alerts:
            alert_doc.reference.update(
                {
                    Fields.STATUS: status,
                    Fields.REASON: reason,
                    Fields.UPDATED_AT: get_server_timestamp(),
                }
            )

    # Update order dispute status
    if payment_intent_id:
        orders = (
            get_db()
            .collection(Collections.ORDERS)
            .where(Fields.STRIPE_PAYMENT_INTENT_ID, "==", payment_intent_id)
            .limit(1)
            .stream()
        )

        for order_doc in orders:
            order_doc.reference.update(
                {
                    Fields.DISPUTE_STATUS: status,
                    Fields.UPDATED_AT: get_server_timestamp(),
                }
            )

    return f"Dispute updated: {dispute_id} → {status}"


def process_dispute_funds_reinstated(dispute: dict) -> str | None:
    """
    Handles charge.dispute.funds_reinstated — funds returned after dispute won.

    This is sent when Stripe returns funds to the platform after a won dispute.
    We log it and ensure the order/payout state is correct.
    """
    dispute_id = dispute.get(StripeConstants.OBJECT_ID)
    charge_id = dispute.get(StripeConstants.CHARGE)
    payment_intent_id = dispute.get(StripeConstants.PAYMENT_INTENT)
    amount_reinstated = dispute.get(Fields.AMOUNT, 0)

    logger.info(f"Dispute funds reinstated: {dispute_id} amount={amount_reinstated}")

    # Log security alert for audit trail
    get_db().collection(Collections.SECURITY_ALERTS).add(
        {
            Fields.TYPE: SecurityAlertTypes.DISPUTE_FUNDS_REINSTATED,
            Fields.SEVERITY: SeverityLevels.LOW if amount_reinstated > 0 else SeverityLevels.HIGH,
            Fields.CHARGE_ID: charge_id,
            Fields.PAYMENT_INTENT_ID: payment_intent_id,
            Fields.AMOUNT: amount_reinstated,
            Fields.TIMESTAMP: get_server_timestamp(),
            Fields.RESOLVED: True,
        }
    )

    return f"Funds reinstated for dispute {dispute_id}: {amount_reinstated} cents"


def process_dispute_closed(dispute: dict) -> str | None:
    """Handles dispute resolution — updates security alert AND order status."""
    charge_id = dispute.get(StripeConstants.CHARGE)
    status = dispute.get(Fields.STATUS)

    # Update security alert
    alerts = (
        get_db()
        .collection(Collections.SECURITY_ALERTS)
        .where(Fields.CHARGE_ID, "==", charge_id)
        .where(Fields.TYPE, "==", SecurityAlertTypes.DISPUTE_CREATED)
        .limit(1)
        .stream()
    )

    for alert_doc in alerts:
        alert_doc.reference.update(
            {Fields.RESOLVED: True, Fields.RESOLUTION: status, Fields.RESOLVED_AT: get_server_timestamp()}
        )

    # Update order status based on dispute outcome
    payment_intent_id = dispute.get(StripeConstants.PAYMENT_INTENT)
    if payment_intent_id:
        orders = (
            get_db()
            .collection(Collections.ORDERS)
            .where(Fields.STRIPE_PAYMENT_INTENT_ID, "==", payment_intent_id)
            .limit(1)
            .stream()
        )

        for order_doc in orders:
            order_data = order_doc.to_dict()
            update_data = {
                Fields.DISPUTE_RESOLVED_AT: get_server_timestamp(),
                Fields.DISPUTE_RESOLUTION: status,
                Fields.UPDATED_AT: get_server_timestamp(),
            }
            if status == "lost":
                update_data[Fields.ORDER_STATUS] = OrderStatusValues.CANCELLED
                update_data[Fields.CANCELLATION_REASON] = "Dispute lost"
            elif status == "won":
                # CRITICAL FIX: Restore pre-dispute status (not current 'disputed' status)
                pre_dispute_status = order_data.get(Fields.PRE_DISPUTE_STATUS, OrderStatusValues.CONFIRMED)
                update_data[Fields.ORDER_STATUS] = pre_dispute_status

                # CRITICAL FIX: Re-create seller transfers on won dispute
                # The transfers were reversed in process_dispute_created
                order_id = order_doc.id
                payouts = (
                    get_db()
                    .collection(Collections.PAYOUTS)
                    .where(Fields.ORDER_ID, "==", order_id)
                    .where(Fields.STATUS, "in", [PayoutStatusValues.REVERSED, PayoutStatusValues.PARTIALLY_REVERSED])
                    .limit(50)  # Cost fix: bounded by seller count per order
                    .stream()
                )

                re_transferred = 0
                # Load the seller Stripe account snapshot stored at checkout time
                # SECURITY FIX (HIGH-01): Read from private subcollection, not buyer-readable order doc.
                seller_stripe_snapshot = _get_seller_stripe_snapshot(order_id, order_data)
                for payout_doc in payouts:
                    payout_data = payout_doc.to_dict()
                    seller_id = payout_data.get(Fields.SELLER_ID, "")
                    reversed_cents = payout_data.get(Fields.CUMULATIVE_REVERSED_CENTS, 0)

                    # FIX C-2: seller_stripe_snapshot maps seller_id directly to account string (or dict from older format)
                    seller_stripe_obj = seller_stripe_snapshot.get(seller_id)
                    seller_stripe_id = seller_stripe_obj.get(Fields.STRIPE_ACCOUNT_ID) if isinstance(seller_stripe_obj, dict) else seller_stripe_obj
                    if not seller_stripe_id:
                        # Fall back to current seller profile only if snapshot missing
                        sp = get_db().collection(Collections.SELLER_PROFILES).document(seller_id).get()
                        seller_stripe_id = (sp.to_dict() or {}).get(Fields.STRIPE_ACCOUNT_ID) if sp.exists else None

                    if not seller_stripe_id or reversed_cents <= 0:
                        logger.warning(f"Dispute won re-transfer skipped for seller {seller_id}: no Stripe account or zero reversed_cents")
                        continue

                    try:
                        new_transfer = stripe.Transfer.create(
                            amount=reversed_cents,
                            currency="cad",
                            destination=seller_stripe_id,
                            metadata={
                                Fields.ORDER_ID: order_id,
                                Fields.REASON: "dispute_won_re_transfer",
                                Fields.DISPUTE_ID: dispute.get("id", ""),
                            },
                            idempotency_key=f"dispute_won_retransfer_{order_id}_{payout_doc.id}",
                        )
                        payout_doc.reference.update(
                            {
                                Fields.STATUS: PayoutStatusValues.COMPLETED,
                                Fields.STRIPE_TRANSFER_ID: new_transfer.id,
                                Fields.CUMULATIVE_REVERSED_CENTS: 0,
                                Fields.UPDATED_AT: get_server_timestamp(),
                            }
                        )
                        re_transferred += 1
                        logger.info(f"\u2713 Re-transferred {reversed_cents}\u00a2 to seller after dispute won")
                    except Exception as e:
                        logger.error(f"\u26a0\ufe0f Failed to re-transfer to seller: {e}")
                        # AUDIT FIX: Sanitize exception before storing in Firestore
                        error_type = type(e).__name__
                        get_db().collection(Collections.SECURITY_ALERTS).add(
                            {
                                Fields.TYPE: SecurityAlertTypes.DISPUTE_CREATED,
                                Fields.SEVERITY: SeverityLevels.CRITICAL,
                                Fields.ORDER_ID: order_id,
                                Fields.ERROR_MESSAGE: f"Re-transfer failed after dispute won ({error_type}). Check logs.",
                                Fields.TIMESTAMP: get_server_timestamp(),
                                Fields.RESOLVED: False,
                            }
                        )

                if re_transferred > 0:
                    logger.info(f"Dispute won: re-transferred {re_transferred} payouts for order {order_id}")

            order_doc.reference.update(update_data)

            # AUDIT FIX #33: Send dispute resolution notification to sellers
            try:
                seller_ids = set(item.get(Fields.SELLER_ID) for item in order_data.get(Fields.ITEMS, []))
                outcome = "won (funds restored)" if status == "won" else "lost (order cancelled)"
                for seller_id in seller_ids:
                    if not seller_id:
                        continue
                    seller_doc = get_db().collection(Collections.USERS).document(seller_id).get()
                    if seller_doc.exists:
                        seller_email = seller_doc.to_dict().get(Fields.EMAIL)
                        if seller_email:
                            from services.email_task import enqueue_email_task
                            enqueue_email_task(
                                to_email=seller_email,
                                subject=f"Dispute Resolved ({status.title()}) - Origna",
                                html_content=f"""
                                <h2>Dispute Resolution Update</h2>
                                <p>The dispute for order <strong>{order_doc.id}</strong> has been <strong>{outcome}</strong>.</p>
                                {"<p>Your seller transfers have been restored.</p>" if status == "won" else "<p>The order has been cancelled and no further action is needed.</p>"}
                                <p>— Origna Team</p>
                                """,
                                event_type=OrderEventTypes.DISPUTE_RESOLVED
                            )
            except Exception as e:
                logger.error(f"Failed to send dispute resolution emails: {type(e).__name__}")

    return f"Dispute closed: {status}"


def process_transfer_reversed(transfer: dict) -> str | None:
    """Handles reversed payouts"""
    transfer_id = transfer.get(StripeConstants.OBJECT_ID)

    # Find payout by transfer ID
    payouts = (
        get_db().collection(Collections.PAYOUTS).where(Fields.STRIPE_TRANSFER_ID, "==", transfer_id).limit(1).stream()
    )

    for payout_doc in payouts:
        payout_doc.reference.update(
            {Fields.STATUS: PayoutStatusValues.REVERSED, Fields.UPDATED_AT: get_server_timestamp()}
        )

        return f"Payout {payout_doc.id} reversed"

    return None


def process_payout_failed(payout: dict) -> None:
    """Handles failed payouts — creates security alert AND updates payout records."""
    destination = payout.get(Fields.DESTINATION)
    _payout_id = payout.get(StripeConstants.OBJECT_ID)

    # Create security alert
    get_db().collection(Collections.SECURITY_ALERTS).add(
        {
            Fields.TYPE: SecurityAlertTypes.PAYOUT_FAILED,
            Fields.SEVERITY: SeverityLevels.HIGH,
            Fields.DESTINATION: destination,
            Fields.AMOUNT: payout.get(Fields.AMOUNT),
            Fields.FAILURE_MESSAGE: payout.get("failure_message"),
            Fields.TIMESTAMP: get_server_timestamp(),
            Fields.RESOLVED: False,
        }
    )

    # Update payout record if it exists
    if destination:
        payout_docs = (
            get_db()
            .collection(Collections.PAYOUTS)
            .where(Fields.STRIPE_ACCOUNT_ID, "==", destination)
            .where(Fields.STATUS, "==", PayoutStatusValues.PENDING)
            .limit(5)
            .stream()
        )

        for payout_doc in payout_docs:
            payout_doc.reference.update(
                {
                    Fields.STATUS: PayoutStatusValues.FAILED,
                    Fields.FAILURE_MESSAGE: payout.get("failure_message", "Unknown failure"),
                    Fields.UPDATED_AT: get_server_timestamp(),
                }
            )


def process_refund_failed(refund: dict) -> None:
    """Handles failed refunds"""
    charge_id = refund.get(StripeConstants.CHARGE)

    get_db().collection(Collections.SECURITY_ALERTS).add(
        {
            Fields.TYPE: SecurityAlertTypes.REFUND_FAILED,
            Fields.SEVERITY: SeverityLevels.CRITICAL,
            Fields.CHARGE_ID: charge_id,
            Fields.AMOUNT: refund.get(Fields.AMOUNT),
            Fields.FAILURE_REASON: refund.get("failure_reason"),
            Fields.TIMESTAMP: get_server_timestamp(),
            Fields.RESOLVED: False,
        }
    )

    # Flag the order as requiring manual review so admins can action it
    if charge_id:
        # Resolve payment_intent from charge (orders store PI id, not charge id)
        pi_id_for_refund = None
        try:
            ensure_stripe_key()
            charge_obj = stripe.Charge.retrieve(charge_id)
            pi_id_for_refund = charge_obj.payment_intent
        except Exception as e:
            logger.warning(f"⚠️ Could not retrieve charge {charge_id} to find payment_intent: {type(e).__name__}")
        if pi_id_for_refund:
            orders = (
                get_db()
                .collection(Collections.ORDERS)
                .where(Fields.STRIPE_PAYMENT_INTENT_ID, "==", pi_id_for_refund)
                .limit(1)
                .get()
            )
        else:
            logger.warning(f"⚠️ Could not resolve PaymentIntent for charge {charge_id} — skipping order flag")
            orders = []
        for order_doc in orders:
            order_doc.reference.update(
                {
                    Fields.REQUIRES_MANUAL_REVIEW: True,
                    Fields.UPDATED_AT: get_server_timestamp(),
                }
            )
            logger.warning(f"🚨 Refund failed for order {order_doc.id} — flagged for manual review")


def process_account_updated(account: dict) -> None:
    """
    Process account.updated event from Stripe Connect.
    Updates the user's Firestore document when their Stripe account status changes.
    This is critical for enabling sellers after they complete onboarding.
    """
    logger.info("\n🏪 Processing: account.updated")

    account_id = account.get(StripeConstants.OBJECT_ID)
    if not account_id:
        logger.warning("  ⚠️ No account ID in event")
        return

    logger.info(f"  Account ID: {account_id}")
    logger.info(f"  Charges Enabled: {account.get('charges_enabled')}")
    logger.info(f"  Payouts Enabled: {account.get('payouts_enabled')}")
    logger.info(f"  Details Submitted: {account.get('details_submitted')}")
    requirements = account.get("requirements", {})
    currently_due = requirements.get("currently_due", []) or []
    if currently_due:
        logger.info(f"  Requirements Due: {currently_due}")

    # Find user by querying seller_profiles where stripeAccountId == account_id
    seller_profiles = get_db().collection(Collections.SELLER_PROFILES).where(Fields.STRIPE_ACCOUNT_ID, "==", account_id).limit(1).get()

    if not seller_profiles:
        logger.warning(f"  ⚠️ No seller profile found with Stripe account {account_id}")
        return

    sp_ref = seller_profiles[0].reference
    user_id = sp_ref.id
    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_data = user_ref.get().to_dict() or {}

    logger.info(f"  User ID: {user_id}")

    # Pending requirements already extracted above for logging
    eventually_due = requirements.get("eventually_due", []) or []
    pending_requirements = list(set(currently_due + eventually_due))

    # Update seller_profiles with Stripe Connect status
    # FIX M-02: onboardingCompleted requires BOTH details_submitted AND charges_enabled.
    # Setting it on details_submitted alone would mark a seller as "onboarded" before
    # Stripe has approved charges, misleading any gate that checks only onboardingCompleted.
    _details_submitted = account.get("details_submitted", False)
    _charges_enabled = account.get("charges_enabled", False)
    sp_update = {
        Fields.CHARGES_ENABLED: _charges_enabled,
        Fields.PAYOUTS_ENABLED: account.get("payouts_enabled", False),
        Fields.ONBOARDING_COMPLETED: _details_submitted and _charges_enabled,
        Fields.PENDING_REQUIREMENTS: pending_requirements,
        Fields.UPDATED_AT: get_server_timestamp(),
    }
    sp_ref.update(sp_update)

    # Grant SELLER role on users doc only when FULLY approved: details submitted + charges enabled
    # This ensures KYC is complete before any seller privileges are granted
    if account.get("details_submitted", False) and account.get("charges_enabled", False):
        from firebase_admin import firestore as admin_firestore

        current_roles = user_data.get(Fields.ROLES, [])
        if UserRoleValues.SELLER not in current_roles:
            user_ref.update({Fields.ROLES: admin_firestore.ArrayUnion([UserRoleValues.SELLER])})
            logger.info(f"  ✅ Adding seller role to user {user_id} (KYC fully approved)")

    logger.info(f"  ✅ Updated seller profile {user_id} Stripe account status")


@https_fn.on_call(**DEFAULT_OPTIONS)
def create_connect_account(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Creates Stripe Connect account for seller onboarding"""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data or {}

    # AUDIT FIX: Rate limit account creation
    allowed, message = get_rate_limiter().check_rate_limit(
        identifier=user_id, action=RateLimitActions.CREATE_CONNECT_ACCOUNT, max_requests=3, window_minutes=60, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", message)

    # Import validation functions
    from utils.helpers import sanitize_email

    # Get user data from Firestore to get email if not provided
    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User profile not found")

    user_data = user_doc.to_dict()

    # Block suspended users from creating Stripe accounts
    if user_data.get(Fields.SUSPENDED, False):
        raise https_fn.HttpsError("permission-denied", "Your account is suspended. You cannot register as a seller.")

    # Check if user already has a Stripe account (read from seller_profiles)
    sp_ref = get_db().collection(Collections.SELLER_PROFILES).document(user_id)
    sp_doc = sp_ref.get()
    existing_account_id = (sp_doc.to_dict() or {}).get(Fields.STRIPE_ACCOUNT_ID) if sp_doc.exists else None
    if existing_account_id:
        # Return existing account instead of creating new one
        return {ApiKeys.SUCCESS: True, ApiKeys.ACCOUNT_ID: existing_account_id, ApiKeys.EXISTING: True}

    # Get email from request or user profile
    email_raw = data.get(Fields.EMAIL) or user_data.get(Fields.EMAIL)
    country = data.get(Fields.COUNTRY, AppConfig.DEFAULT_COUNTRY_CODE)

    if not email_raw:
        raise https_fn.HttpsError(
            "invalid-argument", "Email is required. Please update your profile with a valid email."
        )

    # Validate and sanitize email
    try:
        email = sanitize_email(email_raw)
    except ValueError:
        raise https_fn.HttpsError(
            "invalid-argument", "Invalid email format. Please provide a valid email address."
        ) from None

    # Validate country code against Stripe Connect-supported countries (ISO 3166-1 alpha-2)
    # https://stripe.com/docs/connect/account-capabilities#supported-countries
    _STRIPE_CONNECT_COUNTRIES = {
        "AU", "AT", "BE", "BR", "BG", "CA", "HR", "CY", "CZ", "DK", "EE", "FI",
        "FR", "DE", "GH", "GI", "GR", "HK", "HU", "IN", "ID", "IE", "IT", "JP",
        "KE", "LV", "LI", "LT", "LU", "MY", "MT", "MX", "NL", "NZ", "NG", "NO",
        "PL", "PT", "RO", "SG", "SK", "SI", "ZA", "ES", "SE", "CH", "TH", "TT",
        "GB", "US", "UY",
    }
    country_upper = (country or "").upper()
    if country_upper not in _STRIPE_CONNECT_COUNTRIES:
        raise https_fn.HttpsError(
            "invalid-argument",
            f"Country '{country}' is not supported for Stripe Connect. Please select a supported country.",
        )

    # Optional business type (default: individual)
    valid_business_types = {"individual", "company", "non_profit", "government_entity"}
    business_type = data.get("businessType", "individual")
    if business_type not in valid_business_types:
        raise https_fn.HttpsError(
            "invalid-argument", f"Invalid businessType. Must be one of: {', '.join(sorted(valid_business_types))}."
        )

    try:
        account = stripe.Account.create(
            type=StripeConstants.ACCOUNT_TYPE_EXPRESS,
            country=country_upper,
            email=email,
            capabilities={"card_payments": {"requested": True}, "transfers": {"requested": True}},
            business_type=business_type,
            metadata={Fields.USER_ID: user_id},
        )

        # Save Stripe Connect fields to seller_profiles/{uid} — SELLER role granted only after full KYC approval
        # (via process_account_updated webhook or get_connect_account_status)
        from models.seller_profile import SellerProfile
        now_ts = get_server_timestamp()
        sp_payload = SellerProfile(
            stripeAccountId=account.id,
            onboardingCompleted=False,
            chargesEnabled=False,
            payoutsEnabled=False,
        ).model_dump(exclude_none=True)
        sp_payload[Fields.UPDATED_AT] = now_ts
        sp_payload[Fields.CREATED_AT] = now_ts
        sp_ref.set(sp_payload, merge=True)

        return {ApiKeys.SUCCESS: True, ApiKeys.ACCOUNT_ID: account.id}

    except stripe.error.InvalidRequestError as e:
        logger.error(f"Stripe InvalidRequestError creating account: {e}")
        raise https_fn.HttpsError(
            "invalid-argument", "Invalid request. Please check your information and try again."
        ) from e
    except stripe.error.AuthenticationError:
        raise https_fn.HttpsError("internal", "Payment service configuration error. Please contact support.") from None
    except stripe.error.APIConnectionError:
        raise https_fn.HttpsError(
            "unavailable", "Could not connect to payment service. Please try again later."
        ) from None
    except stripe.error.StripeError as e:
        # Log the full error for debugging
        logger.error(f"Stripe error creating account: {str(e)}")
        raise https_fn.HttpsError("internal", "Could not create seller account. Please try again later.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def create_account_link(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Creates Stripe Connect onboarding link"""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # Rate limit: 5/min — each call creates a Stripe AccountLink (API cost)
    _limiter = get_rate_limiter()
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.CREATE_ACCOUNT_LINK, max_requests=5, window_minutes=1, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    # Build URLs from server-side config only — never trust client URLs
    # This prevents open redirect attacks via malicious refreshUrl/returnUrl
    refresh_url = f"{BASE_URL}{AppConfig.SELLER_REFRESH_PATH}"
    return_url = f"{BASE_URL}{AppConfig.SELLER_RETURN_PATH}"

    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    # CRITICAL FIX: Stripe account ID is stored in seller_profiles (not users doc)
    sp_doc = get_db().collection(Collections.SELLER_PROFILES).document(user_id).get()
    account_id = (sp_doc.to_dict() or {}).get(Fields.STRIPE_ACCOUNT_ID)

    if not account_id:
        raise https_fn.HttpsError(
            "failed-precondition",
            'You need to create an account first to become a seller. Please tap "Create Seller Account" to get started.',
        )

    try:
        # For Express accounts, always use account_onboarding
        # Stripe automatically shows any pending requirements
        account_link = stripe.AccountLink.create(
            account=account_id, refresh_url=refresh_url, return_url=return_url, type=StripeConstants.TYPE_ACCOUNT_ONBOARDING
        )

        return {ApiKeys.SUCCESS: True, ApiKeys.URL: account_link.url}

    except stripe.error.InvalidRequestError as e:
        raise https_fn.HttpsError("invalid-argument", "Invalid account configuration. Please contact support.") from e
    except stripe.error.APIConnectionError:
        raise https_fn.HttpsError(
            "unavailable", "Could not connect to payment service. Please try again later."
        ) from None
    except Exception as e:
        logger.error(f"Account link creation error: {e}")
        raise https_fn.HttpsError("internal", "Could not create onboarding link. Please try again later.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_connect_account_status(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Gets Stripe Connect account status"""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # Rate limit: 10/min — each call hits Stripe API + Firestore write
    _limiter = get_rate_limiter()
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.GET_CONNECT_STATUS, max_requests=10, window_minutes=1, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_data = user_doc.to_dict()

    # Read Stripe account ID from seller_profiles
    sp_ref = get_db().collection(Collections.SELLER_PROFILES).document(user_id)
    sp_doc = sp_ref.get()
    account_id = (sp_doc.to_dict() or {}).get(Fields.STRIPE_ACCOUNT_ID) if sp_doc.exists else None

    if not account_id:
        raise https_fn.HttpsError(
            "failed-precondition",
            "You need to create an account first to become a seller. Please complete your seller registration.",
        )

    try:
        account = stripe.Account.retrieve(account_id)

        # Update seller_profiles with latest Stripe status
        from firebase_admin import firestore as admin_firestore

        requirements = account.requirements
        currently_due = list(requirements.currently_due or [])
        eventually_due = list(requirements.eventually_due or [])
        pending_requirements = list(set(currently_due + eventually_due))

        # FIX M-02 (get_connect_account_status): onboardingCompleted requires BOTH
        # details_submitted AND charges_enabled — consistent with process_account_updated.
        # Setting it on details_submitted alone marks a seller as "onboarded" before
        # Stripe has approved charges, misleading any gate that checks only onboardingCompleted.
        sp_update = {
            Fields.CHARGES_ENABLED: account.charges_enabled,
            Fields.PAYOUTS_ENABLED: account.payouts_enabled,
            Fields.ONBOARDING_COMPLETED: account.details_submitted and account.charges_enabled,
            Fields.PENDING_REQUIREMENTS: pending_requirements,
            Fields.UPDATED_AT: get_server_timestamp(),
        }
        sp_ref.update(sp_update)

        # Only grant seller role if fully approved: onboarding + charges enabled + not suspended
        is_suspended = user_data.get(Fields.SUSPENDED, False)
        if account.details_submitted and account.charges_enabled and not is_suspended:
            user_ref.update({Fields.ROLES: admin_firestore.ArrayUnion([UserRoleValues.SELLER])})

        # Return dict directly for on_call functions
        return {
            ApiKeys.SUCCESS: True,
            Fields.CHARGES_ENABLED: account.charges_enabled,
            Fields.PAYOUTS_ENABLED: account.payouts_enabled,
            ApiKeys.DETAILS_SUBMITTED: account.details_submitted,
            ApiKeys.REQUIREMENTS_CURRENTLY_DUE: account.requirements.currently_due,
        }

    except stripe.error.InvalidRequestError as e:
        raise https_fn.HttpsError("invalid-argument", "Invalid account. Please contact support.") from e
    except stripe.error.APIConnectionError:
        raise https_fn.HttpsError(
            "unavailable", "Could not connect to payment service. Please try again later."
        ) from None
    except Exception as e:
        logger.error(f"Account status error: {str(e)}")
        raise https_fn.HttpsError("internal", "Could not retrieve account status. Please try again later.") from e


def _capture_payment_impl(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Internal implementation of capture_payment logic.
    Called by both the decorated capture_payment endpoint and confirm_order_receipt.
    """
    # Check if Stripe is enabled
    from handlers.payment_providers import PaymentProvider, require_provider_enabled

    require_provider_enabled(PaymentProvider.STRIPE)
    ensure_stripe_key()

    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    caller_uid = req.auth.uid
    order_id = req.data.get(Fields.ORDER_ID)

    if not order_id:
        raise https_fn.HttpsError("invalid-argument", "orderId required")

    order_ref = get_db().collection(Collections.ORDERS).document(order_id)
    order_doc = order_ref.get()

    if not order_doc.exists:
        raise https_fn.HttpsError("not-found", "Order not found")

    order_data = order_doc.to_dict()

    # CRITICAL SECURITY CHECK: Only order owner or admin can capture
    order_user_id = order_data.get(Fields.USER_ID)
    # FIX: Custom claims are set as {'admin': True/False}, not {Fields.ROLES: [...]}
    is_admin = req.auth.token.get(UserRoleValues.ADMIN, False)

    if caller_uid != order_user_id and not is_admin:
        raise https_fn.HttpsError("permission-denied", "Only the order owner or admin can capture this payment")

    # Verify order is in valid state for capture
    payment_status = order_data.get(Fields.PAYMENT_STATUS)
    order_status = order_data.get(Fields.ORDER_STATUS)

    # Idempotency: if already captured, return success
    if payment_status == PaymentStatusValues.CAPTURED:
        # Ensure buyer receipt confirmation is persisted (best-effort)
        if not order_data.get(Fields.CONFIRMED_BY_CLIENT):
            try:
                order_ref.update(
                    {
                        Fields.CONFIRMED_BY_CLIENT: True,
                        Fields.CONFIRMED_AT: get_server_timestamp(),
                        Fields.UPDATED_AT: get_server_timestamp(),
                    }
                )
            except Exception as confirm_err:
                logger.warning(f"⚠️ Failed to persist confirmed_by_client: {type(confirm_err).__name__}")

        # AUTO-CAPTURE MODE: Create seller payout records for sellers who don't yet have one.
        # With automatic capture, payment is captured at checkout (not at delivery).
        # Seller payouts must still be recorded when buyer confirms receipt.
        # BUG-2 FIX: Check per-seller instead of "any payout exists" to handle staggered
        # multi-seller delivery. The old check (len == 0) caused later sellers to be skipped
        # when an earlier seller's payout already existed.
        try:
            seller_ids_in_order = list({
                i.get(Fields.SELLER_ID)
                for i in order_data.get(Fields.ITEMS, [])
                if i.get(Fields.SELLER_ID)
            })
            sellers_with_payouts: set[str] = set()
            for _sid in seller_ids_in_order:
                _payout_docs = (
                    get_db()
                    .collection(Collections.PAYOUTS)
                    .document(f"{order_id}_{_sid}")
                    .get()
                )
                if _payout_docs.exists:
                    _payout_status = (_payout_docs.to_dict() or {}).get(Fields.STATUS)
                    if _payout_status != PayoutStatusValues.FAILED:
                        sellers_with_payouts.add(_sid)
            sellers_needing_payouts = [s for s in seller_ids_in_order if s not in sellers_with_payouts]
            if sellers_needing_payouts:
                items = order_data.get(Fields.ITEMS, [])
                fee_rate = order_data.get(Fields.PLATFORM_FEE_RATIO, PLATFORM_FEE_RATIO)
                _ac_subtotal = order_data.get(Fields.SUBTOTAL_CENTS, 0)
                _ac_discount = order_data.get(Fields.DISCOUNT_AMOUNT_CENTS, 0)
                _ac_coupon_seller_id = order_data.get(Fields.COUPON_SELLER_ID)

                if _ac_coupon_seller_id is not None and _ac_discount > 0:
                    _ac_scoped_items = [i for i in items if i.get(Fields.SELLER_ID) == _ac_coupon_seller_id]
                    _ac_scoped_sub = sum(round(i.get(Fields.PRICE, 0) * 100) * i.get(Fields.QUANTITY, 1) for i in _ac_scoped_items)
                    _ac_global_ratio: float | None = None
                    _ac_scoped_ratio = (_ac_scoped_sub - _ac_discount) / _ac_scoped_sub if _ac_scoped_sub > 0 else 1.0
                else:
                    _ac_global_ratio = (_ac_subtotal - _ac_discount) / _ac_subtotal if _ac_subtotal > 0 else 1.0
                    _ac_scoped_ratio = None

                sellers_total = {}
                for item in items:
                    item_status = item.get(Fields.STATUS, DeliveryStatusValues.PENDING)
                    if item_status in (DeliveryStatusValues.DELIVERED, DeliveryStatusValues.SHIPPED):
                        sid = item.get(Fields.SELLER_ID)
                        if sid:
                            amt = round(item.get(Fields.PRICE, 0) * 100) * item.get(Fields.QUANTITY, 1)
                            sellers_total[sid] = sellers_total.get(sid, 0) + amt

                # If no items are in DELIVERED/SHIPPED state (e.g. auto-confirm without explicit shipping),
                # fall back to all items — prevents zero-payout auto-capture.
                if not sellers_total:
                    logger.warning(f"Auto-capture {order_id}: no SHIPPED/DELIVERED items found — paying all items")
                    for item in items:
                        sid = item.get(Fields.SELLER_ID)
                        if sid:
                            amt = round(item.get(Fields.PRICE, 0) * 100) * item.get(Fields.QUANTITY, 1)
                            sellers_total[sid] = sellers_total.get(sid, 0) + amt

                # Retrieve charge_id for Stripe Transfers
                pi_id = order_data.get(Fields.STRIPE_PAYMENT_INTENT_ID)
                charge_id = None
                if pi_id:
                    try:
                        from utils.helpers import get_charge_id_from_pi
                        pi_obj = stripe.PaymentIntent.retrieve(pi_id)
                        charge_id = get_charge_id_from_pi(pi_obj)
                    except Exception as pi_err:
                        logger.error(f"\u26a0\ufe0f Failed to retrieve PaymentIntent for charge_id: {pi_err}")

                # BUG-2 FIX: Only create payouts for sellers who don't already have a
                # non-FAILED payout record (per-seller check set computed above).
                for seller_id, amount_cents in sellers_total.items():
                    if seller_id not in sellers_needing_payouts:
                        logger.info(f"Auto-capture {order_id}: skipping payout for seller {seller_id} — already exists")
                        continue
                    if _ac_global_ratio is not None:
                        adjusted_amount_cents = round(amount_cents * _ac_global_ratio)
                    elif seller_id == _ac_coupon_seller_id:
                        adjusted_amount_cents = round(amount_cents * _ac_scoped_ratio)
                    else:
                        adjusted_amount_cents = amount_cents
                    platform_fee_cents = round(adjusted_amount_cents * fee_rate)
                    net_amount_cents = adjusted_amount_cents - platform_fee_cents
                    payout_ref = get_db().collection(Collections.PAYOUTS).document(f"{order_id}_{seller_id}")
                    payout_data = {
                        Fields.ORDER_ID: order_id,
                        Fields.SELLER_ID: seller_id,
                        Fields.AMOUNT_CENTS: adjusted_amount_cents,
                        Fields.PLATFORM_FEE_CENTS: platform_fee_cents,
                        Fields.NET_AMOUNT_CENTS: net_amount_cents,
                        Fields.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
                        Fields.STATUS: PayoutStatusValues.PENDING,
                        Fields.CREATED_AT: get_server_timestamp(),
                    }
                    payout_ref.set(payout_data, merge=True)

                    # Attempt Stripe Transfer (may fail in emulator with fake accounts)
                    if charge_id:
                        # Prefer checkout-time snapshot to prevent account-swap attacks
                        # SECURITY FIX (HIGH-01): Read from private subcollection, not buyer-readable order doc.
                        seller_stripe_accounts = _get_seller_stripe_snapshot(order_id, order_data)
                        acct_id = seller_stripe_accounts.get(seller_id)
                        if not acct_id:
                            sp_doc = get_db().collection(Collections.SELLER_PROFILES).document(seller_id).get()
                            acct_id = (sp_doc.to_dict() or {}).get(Fields.STRIPE_ACCOUNT_ID)
                        if acct_id:
                            try:
                                transfer = stripe.Transfer.create(
                                    amount=net_amount_cents,
                                    currency=BusinessRules.DEFAULT_CURRENCY,
                                    destination=acct_id,
                                    source_transaction=charge_id,
                                    transfer_group=order_id,
                                    metadata={Fields.ORDER_ID: order_id, Fields.SELLER_ID: seller_id},
                                    idempotency_key=f"transfer_{order_id}_{seller_id}",
                                )
                                payout_ref.update(
                                    {
                                        Fields.STRIPE_TRANSFER_ID: transfer.id,
                                        Fields.STATUS: PayoutStatusValues.COMPLETED,
                                    }
                                )
                            except Exception as transfer_err:
                                logger.warning(f"⚠️ Transfer to seller {seller_id} failed: {transfer_err}")
                                payout_ref.update(
                                    {
                                        Fields.STATUS: PayoutStatusValues.FAILED,
                                        Fields.FAILURE_REASON: str(transfer_err),
                                    }
                                )
        except Exception as payout_err:
            logger.warning(f"⚠️ Failed to create payout records for already-captured order {order_id}: {payout_err}")

        return {
            ApiKeys.SUCCESS: True,
            ApiKeys.CAPTURED: True,
            ApiKeys.MESSAGE: "Payment already captured",
            ApiKeys.PAYMENT_INTENT_ID: order_data.get(Fields.STRIPE_PAYMENT_INTENT_ID),
        }

    # Verify order is in correct state (should be authorized/shipped)
    if payment_status != PaymentStatusValues.AUTHORIZED:
        raise https_fn.HttpsError("failed-precondition", f"Order payment not authorized (status: {payment_status})")

    if order_status not in [OrderStatusValues.SHIPPED, OrderStatusValues.IN_TRANSIT, OrderStatusValues.DELIVERED]:
        raise https_fn.HttpsError("failed-precondition", f"Order not shipped yet (status: {order_status})")

    # SECURITY: Check for active disputes before capturing
    dispute_alerts = (
        get_db()
        .collection(Collections.SECURITY_ALERTS)
        .where(Fields.TYPE, "==", SecurityAlertTypes.DISPUTE_CREATED)
        .where(Fields.RESOLVED, "==", False)
        .where(Fields.ORDER_ID, "==", order_id)
        .limit(1)
        .get()
    )

    if len(dispute_alerts) > 0:
        raise https_fn.HttpsError(
            "failed-precondition", "Cannot capture payment: active dispute on this order. Contact support."
        )

    payment_intent_id = order_data.get(Fields.STRIPE_PAYMENT_INTENT_ID)

    if not payment_intent_id:
        raise https_fn.HttpsError("failed-precondition", "No payment intent found")

    # Track capture attempts to prevent infinite retries
    capture_attempts = order_data.get(Fields.CAPTURE_ATTEMPTS, 0)
    if capture_attempts >= BusinessRules.MAX_CAPTURE_ATTEMPTS:
        raise https_fn.HttpsError("failed-precondition", "Maximum capture attempts exceeded")

    # RACE CONDITION FIX: Atomically transition paymentStatus from AUTHORIZED → CAPTURING
    # This prevents two concurrent capture_payment calls from both proceeding.
    @get_transactional()
    def lock_for_capture(transaction):
        """Function lock_for_capture."""
        fresh_doc = order_ref.get(transaction=transaction)
        if not fresh_doc.exists:
            raise https_fn.HttpsError("not-found", "Order not found")
        fresh_data = fresh_doc.to_dict()
        if fresh_data.get(Fields.PAYMENT_STATUS) == PaymentStatusValues.CAPTURED:
            return "already_captured"
        if fresh_data.get(Fields.PAYMENT_STATUS) != PaymentStatusValues.AUTHORIZED:
            raise https_fn.HttpsError(
                "failed-precondition",
                f"Order payment status changed concurrently (status: {fresh_data.get(Fields.PAYMENT_STATUS)})",
            )
        # Mark as "capturing" to block concurrent calls
        transaction.update(
            order_ref,
            {
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURING,
                Fields.CAPTURE_ATTEMPTS: fresh_data.get(Fields.CAPTURE_ATTEMPTS, 0) + 1,
                Fields.UPDATED_AT: get_server_timestamp(),
            },
        )
        return "locked"

    lock_result = lock_for_capture(get_db().transaction())
    if lock_result == "already_captured":
        return {
            ApiKeys.SUCCESS: True,
            ApiKeys.CAPTURED: True,
            ApiKeys.MESSAGE: "Payment already captured (concurrent request)",
            ApiKeys.PAYMENT_INTENT_ID: payment_intent_id,
        }

    # Emulator mode: skip real Stripe capture for fake payment intents
    if IS_EMULATOR and payment_intent_id and not payment_intent_id.startswith("pi_3"):
        items = order_data.get(Fields.ITEMS, [])
        all_items_delivered = all(item.get(Fields.STATUS) == DeliveryStatusValues.DELIVERED for item in items)
        order_ref.update(
            {
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED if all_items_delivered else order_status,
                Fields.CONFIRMED_BY_CLIENT: True,
                Fields.CONFIRMED_AT: get_server_timestamp(),
                Fields.CAPTURED_AT: get_server_timestamp(),
                Fields.CAPTURE_ATTEMPTS: capture_attempts + 1,
                Fields.UPDATED_AT: get_server_timestamp(),
            }
        )
        return {
            ApiKeys.SUCCESS: True,
            ApiKeys.CAPTURED: True,
            ApiKeys.NEW_STATUS: OrderStatusValues.DELIVERED if all_items_delivered else order_status,
            ApiKeys.EMULATOR_MODE: True,
            Fields.PAYOUT_ERRORS: False,
        }

    try:
        # Validate PI is in capturable state
        payment_intent = stripe.PaymentIntent.retrieve(payment_intent_id)

        if payment_intent.status != StripeConstants.STATUS_REQUIRES_CAPTURE:
            raise https_fn.HttpsError(
                "failed-precondition", f"Payment cannot be captured (status: {payment_intent.status})"
            )

        # Validate capture amount matches order total (both in cents)
        expected_amount_cents = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0)

        if payment_intent.amount != expected_amount_cents:
            raise https_fn.HttpsError(
                "failed-precondition",
                f"Payment amount mismatch: expected {expected_amount_cents} cents, got {payment_intent.amount} cents",
            )

        # SECURITY FIX: Calculate payouts first to detect issues BEFORE identifying as captured
        items = order_data.get(Fields.ITEMS, [])
        all_items_delivered = all(
            item.get(Fields.STATUS, DeliveryStatusValues.PENDING) == DeliveryStatusValues.DELIVERED for item in items
        )

        # Create payouts ONLY for sellers whose items are DELIVERED
        # SECURITY FIX: Removed PENDING fallback — only pay for confirmed deliveries
        sellers_total_cents = {}
        for item in items:
            item_status = item.get(Fields.STATUS, DeliveryStatusValues.PENDING)
            if item_status == DeliveryStatusValues.DELIVERED:
                seller_id = item[Fields.SELLER_ID]
                # Price is in dollars, convert to cents
                item_price_cents = round(item[Fields.PRICE] * 100)
                item_total_cents = item_price_cents * item[Fields.QUANTITY]
                sellers_total_cents[seller_id] = sellers_total_cents.get(seller_id, 0) + item_total_cents

        # Capture the payment (with idempotency key to prevent duplicate captures)
        # Note: we might only want to capture a partial amount if this was partial fulfillment,
        # but for now we capture the full amount (downstream refund logic handles the rest if needed).
        payment_intent = stripe.PaymentIntent.capture(
            payment_intent_id, idempotency_key=f"capture_{order_id}_{payment_intent_id}"
        )

        # CRITICAL FIX: Resolve Charge ID from captured PaymentIntent.
        # Stripe Transfer.create requires a Charge ID (ch_xxx), NOT a PaymentIntent ID (pi_xxx).
        from utils.helpers import get_charge_id_from_pi
        charge_id = get_charge_id_from_pi(payment_intent)
        if not charge_id:
            raise https_fn.HttpsError(
                "internal", f"No charge found after capturing PI {payment_intent_id}. Cannot create transfers."
            )

        # SECURITY FIX (CRITICAL-003): Capture-Dispute Race Window
        # Check if a dispute was filed exactly as we captured
        charge = stripe.Charge.retrieve(charge_id)
        if charge.dispute:
            logger.error(f"🚨 CRITICAL: Charge {charge_id} for order {order_id} is already disputed! Aborting payouts.")
            # Update order status to reflect dispute, skipping payouts
            get_db().collection(Collections.ORDERS).document(order_id).update(
                {Fields.PAYMENT_STATUS: PaymentStatusValues.DISPUTED, Fields.UPDATED_AT: get_server_timestamp()}
            )
            raise https_fn.HttpsError(
                "failed-precondition", "Payment is currently disputed and cannot be processed for payout."
            )

        # Execute Transfers / Payouts
        transfer_errors = []

        # AUDIT FIX (CRITICAL-001): Use fee rate stored at checkout, not current config.
        # Prevents config manipulation between checkout and capture.
        stored_fee_rate = order_data.get(Fields.PLATFORM_FEE_RATIO, PLATFORM_FEE_RATIO)
        _cap_subtotal = order_data.get(Fields.SUBTOTAL_CENTS, 0)
        _cap_discount = order_data.get(Fields.DISCOUNT_AMOUNT_CENTS, 0)
        _cap_coupon_seller_id = order_data.get(Fields.COUPON_SELLER_ID)

        if _cap_coupon_seller_id is not None and _cap_discount > 0:
            # Seller-scoped coupon: compute the scoped seller's subtotal for correct ratio
            _scoped_items = [i for i in items if i.get(Fields.SELLER_ID) == _cap_coupon_seller_id]
            _scoped_sub = sum(round(i.get(Fields.PRICE, 0) * 100) * i.get(Fields.QUANTITY, 1) for i in _scoped_items)
            _cap_global_ratio: float | None = None
            _cap_scoped_ratio = (_scoped_sub - _cap_discount) / _scoped_sub if _scoped_sub > 0 else 1.0
        else:
            _cap_global_ratio = (_cap_subtotal - _cap_discount) / _cap_subtotal if _cap_subtotal > 0 else 1.0
            _cap_scoped_ratio = None

        for seller_id, amount_cents in sellers_total_cents.items():
            # Apply coupon discount: scoped coupons only affect the coupon's seller
            if _cap_global_ratio is not None:
                adjusted_amount_cents = round(amount_cents * _cap_global_ratio)
            elif seller_id == _cap_coupon_seller_id:
                adjusted_amount_cents = round(amount_cents * _cap_scoped_ratio)
            else:
                adjusted_amount_cents = amount_cents
            # Platform fee in cents — use stored rate from checkout, fallback to config
            platform_fee_cents = round(adjusted_amount_cents * stored_fee_rate)
            net_amount_cents = adjusted_amount_cents - platform_fee_cents

            # SECURITY FIX (CRITICAL-014): Use snapshotted stripeAccountId from checkout.
            # Falls back to live lookup if snapshot not available (old orders).
            # SECURITY FIX (HIGH-01): Read from private subcollection, not buyer-readable order doc.
            seller_account_snapshot = _get_seller_stripe_snapshot(order_id, order_data)
            snapshot_account_id = seller_account_snapshot.get(seller_id)

            # Get seller's current data for suspension/charges checks
            # Stripe-specific fields (stripeAccountId, chargesEnabled) live in seller_profiles
            seller_ref = get_db().collection(Collections.USERS).document(seller_id)
            sp_live_ref = get_db().collection(Collections.SELLER_PROFILES).document(seller_id)
            seller_doc = seller_ref.get()
            sp_live_doc = sp_live_ref.get()

            if seller_doc.exists:
                seller_data = seller_doc.to_dict()
                sp_live_data = sp_live_doc.to_dict() if sp_live_doc.exists else {}
                # Prefer snapshot (immutable at checkout), fall back to live seller_profile
                stripe_account_id = snapshot_account_id or sp_live_data.get(Fields.STRIPE_ACCOUNT_ID)

                # SECURITY: Warn if account changed since checkout (potential fraud)
                live_account_id = sp_live_data.get(Fields.STRIPE_ACCOUNT_ID)
                if snapshot_account_id and live_account_id and snapshot_account_id != live_account_id:
                    logger.error(
                        f"🚨 SECURITY: Seller {seller_id} Stripe account changed since checkout! "
                        f"Using snapshot: {snapshot_account_id[:12]}..., live: {live_account_id[:12]}..."
                    )
                    get_db().collection(Collections.SECURITY_ALERTS).add(
                        {
                            Fields.TYPE: SecurityAlertTypes.SELLER_ACCOUNT_CHANGED,
                            Fields.SEVERITY: SeverityLevels.HIGH,
                            Fields.ORDER_ID: order_id,
                            Fields.SELLER_ID: seller_id,
                            Fields.SNAPSHOT_ACCOUNT_ID: snapshot_account_id,
                            Fields.LIVE_ACCOUNT_ID: live_account_id,
                            Fields.TIMESTAMP: get_server_timestamp(),
                            Fields.RESOLVED: False,
                        }
                    )

                # CRITICAL SECURITY: Re-verify seller is not suspended at capture time
                # Prevents race condition where seller suspended after checkout but before capture
                if seller_data.get(Fields.SUSPENDED, False):
                    logger.warning(f"⚠️ Skipping payout to suspended seller {seller_id} for order {order_id}")
                    # Mark for manual review
                    order_ref.update(
                        {
                            Fields.REQUIRES_MANUAL_REVIEW: True,
                            Fields.MANUAL_REVIEW_REASON: f"Seller {seller_id} suspended at capture time",
                        }
                    )
                    continue

                # Verify seller has valid Stripe account
                if not stripe_account_id:
                    logger.warning(f"⚠️ Seller {seller_id} has no Stripe account for order {order_id}")
                    continue

                # Verify seller account is enabled for charges
                if not sp_live_data.get(Fields.CHARGES_ENABLED, False):
                    logger.warning(f"⚠️ Seller {seller_id} account not enabled for charges for order {order_id}")
                    order_ref.update(
                        {
                            Fields.REQUIRES_MANUAL_REVIEW: True,
                            Fields.MANUAL_REVIEW_REASON: f"Seller {seller_id} account not charges_enabled",
                        }
                    )
                    continue

                if stripe_account_id:
                    # Check for existing transfer (idempotency)
                    existing_payout = (
                        get_db()
                        .collection(Collections.PAYOUTS)
                        .where(Fields.ORDER_ID, "==", order_id)
                        .where(Fields.SELLER_ID, "==", seller_id)
                        .where(Fields.STATUS, "==", PayoutStatusValues.COMPLETED)
                        .limit(1)
                        .get()
                    )

                    if len(existing_payout) > 0:
                        # Transfer already completed for this seller, skip
                        continue

                    try:
                        # AUDIT FIX (CRITICAL-011): Create PENDING payout record BEFORE Stripe transfer.
                        # This ensures we always have a record even if transfer succeeds but Firestore update fails.
                        payout_ref = (
                            get_db()
                            .collection(Collections.PAYOUTS)
                            .document(
                                f"{order_id}_{seller_id}"  # Deterministic ID for idempotency
                            )
                        )
                        payout_data = {
                            Fields.ORDER_ID: order_id,
                            Fields.SELLER_ID: seller_id,
                            Fields.AMOUNT_CENTS: adjusted_amount_cents,
                            Fields.PLATFORM_FEE_CENTS: platform_fee_cents,
                            Fields.NET_AMOUNT_CENTS: net_amount_cents,
                            Fields.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
                            Fields.STRIPE_ACCOUNT_ID: stripe_account_id,
                            Fields.STATUS: PayoutStatusValues.PENDING,
                            Fields.CREATED_AT: get_server_timestamp(),
                        }
                        payout_ref.set(payout_data, merge=True)

                        # Create transfer to seller (amount already in cents)
                        # SECURITY: idempotency_key prevents double-payouts at Stripe API level
                        # CRITICAL: source_transaction requires Charge ID (ch_xxx), not PI ID
                        transfer = stripe.Transfer.create(
                            amount=net_amount_cents,
                            currency=BusinessRules.DEFAULT_CURRENCY,
                            destination=stripe_account_id,
                            source_transaction=charge_id,
                            transfer_group=order_id,
                            metadata={
                                Fields.ORDER_ID: order_id,
                                Fields.SELLER_ID: seller_id,
                                Fields.METADATA_PLATFORM_FEE: platform_fee_cents,
                            },
                            idempotency_key=f"transfer_{order_id}_{seller_id}",
                        )

                        # Update payout record to COMPLETED with transfer ID (retry up to 3 times)
                        payout_recorded = False
                        for payout_attempt in range(3):
                            try:
                                payout_ref.update(
                                    {
                                        Fields.STRIPE_TRANSFER_ID: transfer.id,
                                        Fields.STATUS: PayoutStatusValues.COMPLETED,
                                    }
                                )
                                payout_recorded = True
                                break
                            except Exception as fs_err:
                                import time as _time

                                logger.warning(
                                    f"⚠️ Payout record update attempt {payout_attempt + 1}/3 failed for order {order_id}, seller {seller_id}: {str(fs_err)}"
                                )
                                if payout_attempt < 2:
                                    _time.sleep(2**payout_attempt)
                        if not payout_recorded:
                            # Transfer succeeded but COMPLETED status not recorded.
                            # PENDING record still exists with seller/order info for reconciliation.
                            logger.critical(
                                f"🚨 CRITICAL: Payout record stuck in PENDING for order {order_id}, seller {seller_id}, transfer {transfer.id}"
                            )
                            try:
                                get_db().collection(Collections.SECURITY_ALERTS).add(
                                    {
                                        Fields.TYPE: SecurityAlertTypes.PAYOUT_RECORD_INCOMPLETE,
                                        Fields.SEVERITY: SeverityLevels.CRITICAL,
                                        Fields.ORDER_ID: order_id,
                                        Fields.SELLER_ID: seller_id,
                                        Fields.STRIPE_TRANSFER_ID: transfer.id,
                                        Fields.AMOUNT_CENTS: net_amount_cents,
                                        "note": "PENDING payout record exists — update to COMPLETED manually",
                                        Fields.TIMESTAMP: get_server_timestamp(),
                                        Fields.RESOLVED: False,
                                    }
                                )
                            except Exception as alert_err:
                                logger.critical(
                                    f"🚨 Failed to create security alert for stuck payout: {type(alert_err).__name__}"
                                )
                    except Exception as e:
                        logger.error(f"Transfer error to seller {seller_id}: {str(e)}")
                        transfer_errors.append({Fields.SELLER_ID: seller_id, Fields.ERROR: type(e).__name__})

        # Update order status AFTER transfers to ensure consistency
        update_data = {
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.ORDER_STATUS: OrderStatusValues.DELIVERED if all_items_delivered else order_status,
            Fields.CAPTURED_AT: get_server_timestamp(),
            Fields.CONFIRMED_BY_CLIENT: True,
            Fields.CONFIRMED_AT: get_server_timestamp(),
            Fields.CAPTURE_ATTEMPTS: capture_attempts + 1,
            Fields.UPDATED_AT: get_server_timestamp(),
        }

        if transfer_errors:
            # Log errors but still mark captured (since money was taken), but add flag
            update_data[Fields.PAYOUT_ERRORS] = transfer_errors
            update_data[Fields.REQUIRES_MANUAL_REVIEW] = True
            logger.error(f"Payout errors for order {order_id}: {transfer_errors}")

        order_ref.update(update_data)

        return {
            ApiKeys.SUCCESS: True,
            ApiKeys.CAPTURED: True,
            ApiKeys.NEW_STATUS: update_data[Fields.ORDER_STATUS],
            Fields.PAYOUT_ERRORS: len(transfer_errors) > 0,
        }

    except https_fn.HttpsError:
        # Rollback 'capturing' state to 'authorized' so the order isn't stuck
        try:
            order_ref.update(
                {
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.UPDATED_AT: get_server_timestamp(),
                }
            )
        except Exception as rollback_err:
            logger.critical(f"🚨 CRITICAL: Failed to rollback capture state for order: {type(rollback_err).__name__}")
        raise
    except Exception as e:
        # Rollback 'capturing' state to 'authorized' so the order isn't stuck
        try:
            order_ref.update(
                {
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.UPDATED_AT: get_server_timestamp(),
                }
            )
        except Exception as rollback_err:
            logger.critical(f"🚨 CRITICAL: Failed to rollback capture state for order: {type(rollback_err).__name__}")
        error_msg = str(e).lower()
        logger.error(f"Capture payment error: {str(e)}")

        # Handle Stripe-specific errors by checking exception type name
        exc_type_name = type(e).__name__

        # Handle expired authorization (InvalidRequestError with 'expired' in message)
        if "expired" in error_msg:
            raise https_fn.HttpsError(
                "failed-precondition", "Payment authorization has expired. Please create a new order."
            ) from e

        # Handle card errors (3DS required, card declined, etc.)
        if exc_type_name == "CardError":
            # Handle 3DS required at capture time (rare edge case for manual captures)
            if getattr(e, "code", None) == "authentication_required":
                raise https_fn.HttpsError(
                    "failed-precondition",
                    "Payment requires additional verification. Please contact support to complete this payment.",
                ) from e
            user_message = (
                getattr(e, "user_message", None) or "Your card was declined. Please try a different payment method."
            )
            raise https_fn.HttpsError("failed-precondition", user_message) from e

        # Handle other Stripe API errors
        if exc_type_name in ("InvalidRequestError", "StripeError"):
            logger.error(f"Stripe error during capture: {e}")
            raise https_fn.HttpsError("failed-precondition", "Payment capture failed. Please contact support.") from e

        raise https_fn.HttpsError("internal", "Could not capture payment. Please try again.") from e


@https_fn.on_call(**PAYMENT_OPTIONS)
def capture_payment(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Manually captures authorized payment and initiates seller payouts.
    Called when buyer confirms order receipt.
    Thin wrapper around _capture_payment_impl for HTTP callable endpoint.
    """
    return _capture_payment_impl(req)


def sanitize_metadata(metadata: dict[str, Any]) -> dict[str, Any]:
    """
    Sanitize metadata fields before storing in Stripe or Firestore.
    Firestore handles NoSQL injection, but we validate inputs for safety.

    Args:
        metadata: Dictionary of metadata to sanitize

    Returns:
        Sanitized metadata dictionary
    """
    if not isinstance(metadata, dict):
        return {}

    # For Firestore NoSQL, metadata is stored as-is, no SQL injection risk
    # But we validate field types to ensure data integrity
    sanitized = {}
    for key, value in metadata.items():
        # Allow strings, numbers, booleans, None
        if isinstance(value, (str, int, float, bool, type(None))):
            sanitized[key] = value
        # Convert other types to strings
        else:
            sanitized[key] = str(value)

    return sanitized
