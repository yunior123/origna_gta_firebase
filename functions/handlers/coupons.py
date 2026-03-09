"""
Coupon / Promo Code Handlers (N-07)
- apply_coupon: validate a coupon code and compute discount
- redeem_coupon: internal function called after successful checkout
- admin_create_coupon: admin-only coupon creation
"""

import logging
import re
from datetime import UTC, datetime
from typing import Any

from firebase_functions import https_fn

from schema_constants import (
    ApiKeys,
    BusinessRules,
    Collections,
    CouponDiscountTypeValues,
    Fields,
    RateLimitActions,
    UserRoleValues,
)
from services.rate_limiter import RateLimiter
from utils.db import get_db, get_firestore
from utils.function_options import DEFAULT_OPTIONS
from utils.helpers import create_success_response

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# VALIDATION HELPERS
# ---------------------------------------------------------------------------

_COUPON_CODE_RE = re.compile(r'^[A-Z0-9]{4,20}$')


def _validate_coupon_code(code: str) -> bool:
    """Return True if code matches uppercase alphanumeric 4-20 chars."""
    return bool(_COUPON_CODE_RE.match(code))


def _compute_discount(coupon_data: dict, cart_subtotal_cents: int) -> int:
    """
    Compute discount amount in cents.
    - percent: integer arithmetic to avoid float drift (rounds down)
    - fixed_cents: min(discountValue, cart_subtotal_cents - MIN_REMAINING)
    
    F-103: Enforce a minimum checkout total ($1.00) to cover Stripe's $0.30 fixed fee.
    """
    discount_type = coupon_data.get(Fields.DISCOUNT_TYPE)
    discount_value = coupon_data.get(Fields.DISCOUNT_VALUE, 0)

    # F-103: Minimum amount that must remain after discount
    min_remaining = BusinessRules.MIN_CHECKOUT_TOTAL_CENTS
    max_percent = BusinessRules.MAX_COUPON_DISCOUNT_RATIO

    if cart_subtotal_cents <= min_remaining:
        return 0

    if discount_type == CouponDiscountTypeValues.PERCENT:
        # F-103: Cap percent discount
        effective_value = min(float(discount_value), max_percent * 100)
        discount_value_millipercent = int(round(effective_value * 1000))
        discount = cart_subtotal_cents * discount_value_millipercent // 100000

        # Final safety check: ensure at least $1 remains
        if cart_subtotal_cents - discount < min_remaining:
            return cart_subtotal_cents - min_remaining
        return discount

    elif discount_type == CouponDiscountTypeValues.FIXED_CENTS:
        # F-103: Fixed discount cannot reduce total below $1
        return min(int(discount_value), cart_subtotal_cents - min_remaining)

    return 0


# ---------------------------------------------------------------------------
# N-07: apply_coupon — validate and compute discount (does NOT redeem)
# ---------------------------------------------------------------------------

@https_fn.on_call(**DEFAULT_OPTIONS)
def apply_coupon(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    N-07: Validate a coupon code and return the computed discount preview.
    Does NOT apply/redeem the coupon — that happens in redeem_coupon after checkout succeeds.
    The actual discount is re-computed server-side in payment_stripe.py against the verified subtotal.

    Request data:
        code: str — coupon code (will be uppercased)
        cartSubtotalCents: int — cart subtotal in cents (preview only; not trusted at payment time)
        sellerIds: list[str]? — seller IDs in cart (for seller-scoped coupon validation)

    Returns:
        {valid: true, discountAmountCents: N, discountType: X, discountValue: Y}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data

    # S-04 FIX: Rate limit coupon code attempts
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id,
        action=RateLimitActions.APPLY_COUPON,
        max_requests=20,
        window_minutes=60,
        fail_closed=False,
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", "Too many coupon attempts. Please try again later.")

    code_raw = data.get(Fields.COUPON_CODE, "")
    cart_subtotal_cents = data.get(ApiKeys.CART_SUBTOTAL_CENTS)
    seller_ids = data.get(Fields.SELLER_IDS) or []
    if not isinstance(seller_ids, list):
        seller_ids = []

    # --- Input validation ---
    if not code_raw or not isinstance(code_raw, str):
        raise https_fn.HttpsError("invalid-argument", "couponCode is required")
    code = code_raw.strip().upper()
    if not _validate_coupon_code(code):
        raise https_fn.HttpsError("invalid-argument", "Coupon invalid or unavailable")

    if not isinstance(cart_subtotal_cents, int) or cart_subtotal_cents < 0:
        raise https_fn.HttpsError("invalid-argument", "cartSubtotalCents must be a non-negative integer")

    # --- Fetch coupon ---
    coupon_ref = get_db().collection(Collections.COUPONS).document(code)
    coupon_snap = coupon_ref.get()
    if not coupon_snap.exists:
        raise https_fn.HttpsError("not-found", "Coupon invalid or unavailable")

    coupon = coupon_snap.to_dict() or {}

    # --- Active check ---
    if not coupon.get("isActive", False):
        raise https_fn.HttpsError("failed-precondition", "Coupon invalid or unavailable")

    # --- Expiry check ---
    expires_at = coupon.get(Fields.EXPIRES_AT)
    if expires_at is not None:
        now_utc = datetime.now(UTC)
        if hasattr(expires_at, "ToDatetime"):
            expires_dt = expires_at.ToDatetime().replace(tzinfo=UTC)
        elif hasattr(expires_at, "astimezone"):
            expires_dt = expires_at.astimezone(UTC)
        else:
            expires_dt = None
        if expires_dt is not None and now_utc > expires_dt:
            raise https_fn.HttpsError("failed-precondition", "Coupon invalid or unavailable")

    # --- Global max uses check ---
    max_uses_total = coupon.get(Fields.MAX_USES_TOTAL)
    used_count = int(coupon.get(Fields.USED_COUNT, 0))
    if max_uses_total is not None and used_count >= int(max_uses_total):
        raise https_fn.HttpsError("resource-exhausted", "Coupon invalid or unavailable")

    # --- Per-user max uses check (reuse coupon_ref from above — no extra Firestore read) ---
    max_uses_per_user = int(coupon.get(Fields.MAX_USES_PER_USER, 1))
    user_uses = coupon_ref.collection(Collections.COUPON_USES).document(user_id).get()
    user_usage_count = int(user_uses.to_dict().get("useCount", 0)) if user_uses.exists else 0
    if user_usage_count >= max_uses_per_user:
        raise https_fn.HttpsError("resource-exhausted", "Coupon invalid or unavailable")

    # --- Seller scope check ---
    coupon_seller_id = coupon.get(Fields.SELLER_ID)
    if coupon_seller_id is not None and coupon_seller_id not in seller_ids:
        raise https_fn.HttpsError("failed-precondition", "Coupon invalid or unavailable")

    # --- Minimum order check ---
    min_order_cents = coupon.get(Fields.MIN_ORDER_CENTS)
    if min_order_cents is not None and cart_subtotal_cents < int(min_order_cents):
        raise https_fn.HttpsError(
            "failed-precondition",
            "Cart subtotal does not meet the minimum order requirement for this coupon"
        )

    # --- Compute discount preview (cartSubtotalCents is client-supplied — for display only) ---
    discount_amount_cents = _compute_discount(coupon, cart_subtotal_cents)

    return create_success_response({
        "valid": True,
        Fields.DISCOUNT_AMOUNT_CENTS: discount_amount_cents,
        Fields.DISCOUNT_TYPE: coupon.get(Fields.DISCOUNT_TYPE),
        Fields.DISCOUNT_VALUE: coupon.get(Fields.DISCOUNT_VALUE),
        Fields.COUPON_CODE: code,
    })


# ---------------------------------------------------------------------------
# N-07: redeem_coupon — internal function, called after successful checkout
# ---------------------------------------------------------------------------

def redeem_coupon(code: str, user_id: str, order_id: str = "") -> None:
    """
    N-07: Internal — atomically increment usedCount and record usage in coupon_uses subcollection.
    Called from payment_stripe.py after payment succeeds.

    Silently no-ops if coupon no longer exists (defensive).
    On transaction failure, writes a pending_redemptions/{orderId} doc for retry.
    """
    if not code or not user_id:
        return

    code = code.strip().upper()
    db = get_db()
    fs = get_firestore()
    coupon_ref = db.collection(Collections.COUPONS).document(code)
    use_ref = coupon_ref.collection(Collections.COUPON_USES).document(user_id)

    @fs.transactional
    def _redeem_txn(transaction):
        snap = coupon_ref.get(transaction=transaction)
        if not snap.exists:
            logger.warning(f"redeem_coupon: coupon {code} not found — skipping")
            return

        data = snap.to_dict() or {}
        used_count = int(data.get(Fields.USED_COUNT, 0))

        # AUDIT FIX (MEDIUM-C5): Re-check expiry inside transaction.
        # A coupon checked at 23:59:59 could expire before this transaction runs.
        expires_at = data.get(Fields.EXPIRES_AT)
        if expires_at is not None:
            now_utc = datetime.now(UTC)
            if hasattr(expires_at, "ToDatetime"):
                expires_dt = expires_at.ToDatetime().replace(tzinfo=UTC)
            elif hasattr(expires_at, "astimezone"):
                expires_dt = expires_at.astimezone(UTC)
            else:
                expires_dt = None
            if expires_dt is not None and now_utc > expires_dt:
                logger.warning(f"redeem_coupon: coupon {code} expired at {expires_dt} — aborting")
                return

        # Re-check global limit inside transaction to prevent race condition
        max_uses_total = data.get(Fields.MAX_USES_TOTAL)
        if max_uses_total is not None and used_count >= int(max_uses_total):
            logger.warning(f"redeem_coupon: coupon {code} already at max uses ({max_uses_total}) — aborting")
            return

        # Re-check per-user limit inside transaction
        use_snap = use_ref.get(transaction=transaction)
        max_uses_per_user = int(data.get(Fields.MAX_USES_PER_USER, 1))
        user_count = int(use_snap.to_dict().get("useCount", 0)) if use_snap.exists else 0
        if user_count >= max_uses_per_user:
            logger.warning(f"redeem_coupon: user {user_id} already at per-user limit for coupon {code} — aborting")
            return

        # Increment coupon usage (global counter + per-user record) inside the same transaction
        transaction.update(coupon_ref, {
            Fields.USED_COUNT: used_count + 1,
        })

        # Record per-user usage in subcollection
        if use_snap.exists:
            transaction.update(use_ref, {"useCount": user_count + 1, "lastUsedAt": fs.SERVER_TIMESTAMP})
        else:
            transaction.set(use_ref, {"useCount": 1, "usedAt": fs.SERVER_TIMESTAMP, "lastUsedAt": fs.SERVER_TIMESTAMP})

    try:
        txn = db.transaction()
        _redeem_txn(txn)
        logger.info(f"Coupon {code} redeemed by user {user_id}")
    except Exception as e:
        logger.error(f"redeem_coupon failed for code={code} user={user_id}: {e}")
        # Non-fatal — do not block order completion.
        # Write a pending_redemptions doc so a retry job can pick it up.
        if order_id:
            try:
                db.collection("pending_redemptions").document(order_id).set({
                    Fields.COUPON_CODE: code,
                    Fields.USER_ID: user_id,
                    "retriesRemaining": 5,
                    "createdAt": get_firestore().SERVER_TIMESTAMP,
                }, merge=True)
            except Exception as write_err:
                logger.error(f"Failed to write pending_redemption for order {order_id}: {write_err}")


# ---------------------------------------------------------------------------
# N-07: admin_create_coupon — admin-only coupon creation
# ---------------------------------------------------------------------------

@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_create_coupon(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    N-07: Admin creates a new coupon.

    Request data:
        couponCode: str — coupon code (4-20 uppercase alphanumeric) [field name: 'couponCode', not 'code']
        discountType: str — "percent" | "fixed_cents"
        discountValue: number — percent: 1-100, fixed_cents: min 100 (i.e., $1.00 CAD)
        minOrderCents: int? — minimum cart subtotal in cents
        maxUsesTotal: int? — null = unlimited
        maxUsesPerUser: int? — default 1
        expiresAt: str? — ISO 8601 datetime string
        isActive: bool — default true
        sellerId: str? — null = platform-wide coupon
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    token = req.auth.token or {}
    is_admin = token.get("admin") is True
    if not is_admin:
        # Also check Firestore roles for safety
        caller_doc = get_db().collection(Collections.USERS).document(req.auth.uid).get()
        if not caller_doc.exists:
            raise https_fn.HttpsError("permission-denied", "Admin access required")
        caller_roles = (caller_doc.to_dict() or {}).get(Fields.ROLES, [])
        if UserRoleValues.ADMIN not in caller_roles:
            raise https_fn.HttpsError("permission-denied", "Admin access required")

    data = req.data
    code_raw = data.get(Fields.COUPON_CODE, "")
    if not code_raw or not isinstance(code_raw, str):
        raise https_fn.HttpsError("invalid-argument", "code is required")

    code = code_raw.strip().upper()
    if not _validate_coupon_code(code):
        raise https_fn.HttpsError("invalid-argument", "code must be 4-20 uppercase alphanumeric characters")

    discount_type = data.get(Fields.DISCOUNT_TYPE, "")
    if discount_type not in CouponDiscountTypeValues.ALL:
        raise https_fn.HttpsError(
            "invalid-argument",
            f"discountType must be one of: {sorted(CouponDiscountTypeValues.ALL)}"
        )

    discount_value = data.get(Fields.DISCOUNT_VALUE)
    if not isinstance(discount_value, (int, float)) or discount_value <= 0:
        raise https_fn.HttpsError("invalid-argument", "discountValue must be a positive number")

    if discount_type == CouponDiscountTypeValues.PERCENT:
        if not (1 <= discount_value <= BusinessRules.MAX_ADMIN_COUPON_DISCOUNT_PERCENT):
            raise https_fn.HttpsError("invalid-argument", f"Percent discount must be between 1 and {BusinessRules.MAX_ADMIN_COUPON_DISCOUNT_PERCENT} to cover platform fees.")
    elif discount_type == CouponDiscountTypeValues.FIXED_CENTS:
        if discount_value < 100:
            raise https_fn.HttpsError("invalid-argument", "Fixed discount must be at least 100 cents ($1.00)")

        # F-103: Fixed discounts require a minimum order to ensure margin
        min_order_cents = data.get(Fields.MIN_ORDER_CENTS)
        required_min = int(discount_value) + (BusinessRules.MIN_CHECKOUT_TOTAL_CENTS * 5) # Require at least $5 margin for admin fixed coupons
        if min_order_cents is None or int(min_order_cents) < required_min:
            raise https_fn.HttpsError(
                "invalid-argument",
                f"Fixed discount of ${discount_value/100:.2f} requires a minOrderCents of at least ${required_min/100:.2f}"
            )

    min_order_cents = data.get(Fields.MIN_ORDER_CENTS)
    if min_order_cents is not None and (not isinstance(min_order_cents, int) or min_order_cents < 0):
        raise https_fn.HttpsError("invalid-argument", "minOrderCents must be a non-negative integer")

    max_uses_total = data.get(Fields.MAX_USES_TOTAL)
    if max_uses_total is not None and (not isinstance(max_uses_total, int) or max_uses_total < 1):
        raise https_fn.HttpsError("invalid-argument", "maxUsesTotal must be a positive integer")

    max_uses_per_user = data.get(Fields.MAX_USES_PER_USER, 1)
    if not isinstance(max_uses_per_user, int) or max_uses_per_user < 1:
        raise https_fn.HttpsError("invalid-argument", "maxUsesPerUser must be a positive integer")

    is_active = data.get("isActive", True)
    if not isinstance(is_active, bool):
        raise https_fn.HttpsError("invalid-argument", "isActive must be a boolean")

    seller_id = data.get(Fields.SELLER_ID)  # None = platform-wide

    expires_at = None
    expires_at_raw = data.get(Fields.EXPIRES_AT)
    if expires_at_raw is not None:
        try:
            expires_at = datetime.fromisoformat(expires_at_raw.replace("Z", "+00:00"))
        except (ValueError, AttributeError):
            raise https_fn.HttpsError("invalid-argument", "expiresAt must be a valid ISO 8601 datetime string") from None

    # Check for duplicate
    coupon_ref = get_db().collection(Collections.COUPONS).document(code)
    if coupon_ref.get().exists:
        raise https_fn.HttpsError("already-exists", f"Coupon code '{code}' already exists")

    now = datetime.now(UTC)
    coupon_doc = {
        Fields.COUPON_CODE: code,
        Fields.DISCOUNT_TYPE: discount_type,
        Fields.DISCOUNT_VALUE: discount_value,
        Fields.MIN_ORDER_CENTS: min_order_cents,
        Fields.MAX_USES_TOTAL: max_uses_total,
        Fields.MAX_USES_PER_USER: max_uses_per_user,
        Fields.USED_COUNT: 0,
        Fields.EXPIRES_AT: expires_at,
        "isActive": is_active,
        Fields.SELLER_ID: seller_id,
        Fields.CREATED_AT: now,
        "createdByAdminId": req.auth.uid,
    }

    coupon_ref.set(coupon_doc)
    logger.info(f"Coupon {code} created by admin {req.auth.uid}")

    return create_success_response({Fields.COUPON_CODE: code, "created": True})
