"""
Admin & User Management Handlers
- User role management (admin only)
- Seller suspension
- MFA enrollment/verification
- Account deletion
"""

import hashlib
import hmac
import logging
import secrets
import string
import time
from datetime import UTC, datetime, timedelta
from typing import Any

import pyotp
import stripe
from firebase_admin import auth
from firebase_functions import https_fn

from schema_constants import (
    APP_NAME,
    AdminActionValues,
    ApiKeys,
    BusinessRules,
    Collections,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
    PayoutStatusValues,
    ProductLifecycleStatusValues,
    RateLimitActions,
    SecurityAlertTypes,
    SeverityLevels,
    UserRoleValues,
)
from services.rate_limiter import RateLimiter
from utils.db import get_db, get_delete_field, get_firestore, get_server_timestamp
from utils.function_options import DEFAULT_OPTIONS
from utils.helpers import create_success_response

logger = logging.getLogger(__name__)


def _require_recent_admin_mfa(admin_data: dict[str, Any]) -> None:
    """
    Requires admin to have verified MFA within the last 5 minutes.

    Args:
        admin_data: Admin user document data

    Raises:
        https_fn.HttpsError: If MFA not verified or expired
    """
    if not admin_data.get(Fields.MFA_ENABLED, False):
        raise https_fn.HttpsError(
            "failed-precondition", "Admin MFA is not enabled. Please enable MFA before performing sensitive operations."
        )

    last_mfa_verify = admin_data.get(Fields.LAST_MFA_VERIFY)

    if not last_mfa_verify:
        raise https_fn.HttpsError("permission-denied", "MFA verification required. Please verify your MFA code first.")

    # Check if MFA was verified within allowed window
    now = datetime.now(UTC)
    # Firestore timestamps may be timezone-aware; use astimezone for correct conversion
    last_mfa_utc = last_mfa_verify.astimezone(UTC) if last_mfa_verify.tzinfo is not None else last_mfa_verify.replace(tzinfo=UTC)
    time_diff = now - last_mfa_utc

    if time_diff > timedelta(minutes=BusinessRules.MFA_VERIFICATION_VALIDITY_MINUTES):
        raise https_fn.HttpsError("permission-denied", "MFA verification expired. Please verify again.")


@https_fn.on_call(**DEFAULT_OPTIONS)
def update_user_roles(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Updates user roles (admin only with MFA).

    Security:
    - Admin only
    - Requires recent MFA verification (< 5 min)
    - Cannot modify own roles
    - Logs all role changes in security_alerts

    Request data:
        targetUserId (or userId): User ID to modify
        add: Array of roles to add (optional)
        remove: Array of roles to remove (optional)
        reason: Reason for change (optional)

    Returns:
        {success: True, newRoles: [...]}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    admin_id = req.auth.uid

    # AUDIT FIX #39: Rate limit role changes to prevent abuse
    from services.rate_limiter import RateLimiter

    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=admin_id, action=RateLimitActions.UPDATE_USER_ROLES, max_requests=10, window_minutes=5, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    data = req.data

    # Accept both 'targetUserId' and 'userId' as parameter names
    target_user_id_raw = data.get(Fields.TARGET_USER_ID) or data.get(Fields.USER_ID)
    # Support both patterns: full 'roles' list OR incremental 'add'/'remove'
    roles_to_add = data.get(ApiKeys.ADD, [])
    roles_to_remove = data.get(ApiKeys.REMOVE, [])
    reason = data.get(ApiKeys.REASON, "No reason provided")

    # Import validation functions
    from utils.helpers import sanitized_text

    # Sanitize targetUserId (should be alphanumeric)
    target_user_id = sanitized_text(target_user_id_raw) if target_user_id_raw else None

    if not target_user_id:
        raise https_fn.HttpsError("invalid-argument", "targetUserId required")

    if not isinstance(roles_to_add, list) or not isinstance(roles_to_remove, list):
        raise https_fn.HttpsError("invalid-argument", "add and remove must be arrays")

    # Validate roles
    for role in roles_to_add + roles_to_remove:
        if role not in UserRoleValues.ALL:
            raise https_fn.HttpsError("invalid-argument", f"Invalid role: {role}")

    # Check admin permissions
    admin_ref = get_db().collection(Collections.USERS).document(admin_id)
    admin_doc = admin_ref.get()

    if not admin_doc.exists:
        raise https_fn.HttpsError("not-found", "Admin user not found")

    admin_data = admin_doc.to_dict()

    if UserRoleValues.ADMIN not in admin_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    # Require recent MFA verification for sensitive operation
    _require_recent_admin_mfa(admin_data)

    # Cannot modify own roles
    if admin_id == target_user_id:
        raise https_fn.HttpsError("permission-denied", "Cannot modify your own roles")

    # Get target user
    target_user_ref = get_db().collection(Collections.USERS).document(target_user_id)
    target_user_doc = target_user_ref.get()

    if not target_user_doc.exists:
        raise https_fn.HttpsError("not-found", "Target user not found")

    target_user_data = target_user_doc.to_dict()
    old_roles = target_user_data.get(Fields.ROLES, [])

    # Guard: cannot demote another admin's admin role (requires super-admin or second admin)
    if UserRoleValues.ADMIN in roles_to_remove and UserRoleValues.ADMIN in old_roles:
        raise https_fn.HttpsError(
            "permission-denied",
            "Demoting an admin requires contacting the platform owner directly.",
        )

    # Compute new roles via add/remove delta
    new_roles = list((set(old_roles) | set(roles_to_add)) - set(roles_to_remove))
    # Ensure at least 'buyer' role is always present
    if UserRoleValues.BUYER not in new_roles:
        new_roles.append(UserRoleValues.BUYER)

    # Update roles in Firestore first
    target_user_ref.update(
        {
            Fields.ROLES: new_roles,
            Fields.UPDATED_AT: get_server_timestamp(),
            Fields.LAST_ROLE_UPDATE: get_server_timestamp(),
            Fields.LAST_ROLE_UPDATE_BY: admin_id,
        }
    )

    # Sync Firebase Auth custom claims — if this fails, revert the Firestore write
    try:
        custom_claims = {role: role in new_roles for role in UserRoleValues.ALL}
        auth.set_custom_user_claims(target_user_id, custom_claims)
    except Exception as e:
        # Revert to keep Firestore and Auth claims in sync
        try:
            target_user_ref.update(
                {
                    Fields.ROLES: old_roles,
                    Fields.UPDATED_AT: get_server_timestamp(),
                    Fields.LAST_ROLE_UPDATE_BY: admin_id,
                }
            )
        except Exception as revert_err:
            logger.critical(f"CRITICAL: Failed to revert roles after claims failure for {target_user_id}: {revert_err}")
            get_db().collection(Collections.SECURITY_ALERTS).add({
                Fields.TYPE: "role_sync_failure",
                Fields.SEVERITY: "critical",
                Fields.USER_ID: target_user_id,
                Fields.TIMESTAMP: get_server_timestamp(),
                Fields.RESOLVED: False,
            })
        raise https_fn.HttpsError("internal", f"Role update failed during Auth sync: {e}") from e

    # Log security alert
    get_db().collection(Collections.SECURITY_ALERTS).add(
        {
            Fields.TYPE: SecurityAlertTypes.ROLE_CHANGE,
            Fields.SEVERITY: SeverityLevels.MEDIUM,
            Fields.ADMIN_ID: admin_id,
            Fields.TARGET_USER_ID: target_user_id,
            Fields.OLD_ROLES: old_roles,
            Fields.NEW_ROLES: new_roles,
            Fields.REASON: reason,
            Fields.TIMESTAMP: get_server_timestamp(),
            Fields.RESOLVED: True,
        }
    )

    return create_success_response({Fields.NEW_ROLES: new_roles})


@https_fn.on_call(**DEFAULT_OPTIONS)
def suspend_seller(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Suspends a seller account (admin only with MFA).

    Actions:
    - Marks user as suspended
    - Deactivates all seller's products
    - Cancels all pending/confirmed orders
    - Creates security alert

    Request data:
        sellerId: User ID to suspend
        reason: Suspension reason

    Returns:
        {success: True, message: "Seller suspended"}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    admin_id = req.auth.uid
    data = req.data

    # AUDIT FIX: Rate limit seller suspension
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=admin_id, action=RateLimitActions.SUSPEND_SELLER, max_requests=10, window_minutes=1, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    # Import validation functions
    from utils.helpers import sanitized_text

    seller_id_raw = data.get(Fields.SELLER_ID)
    reason_raw = data.get(ApiKeys.REASON, "Policy violation")

    # Sanitize inputs
    seller_id = sanitized_text(seller_id_raw) if seller_id_raw else None
    reason = sanitized_text(reason_raw)[:500]  # Max 500 chars

    if not seller_id:
        raise https_fn.HttpsError("invalid-argument", "sellerId required")

    # Check admin permissions
    admin_ref = get_db().collection(Collections.USERS).document(admin_id)
    admin_doc = admin_ref.get()

    if not admin_doc.exists:
        raise https_fn.HttpsError("not-found", "Admin user not found")

    admin_data = admin_doc.to_dict()

    if UserRoleValues.ADMIN not in admin_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    # Require recent MFA verification
    _require_recent_admin_mfa(admin_data)

    # Cannot suspend admin
    if admin_id == seller_id:
        raise https_fn.HttpsError("permission-denied", "Cannot suspend yourself")

    # Get seller
    seller_ref = get_db().collection(Collections.USERS).document(seller_id)
    seller_doc = seller_ref.get()

    if not seller_doc.exists:
        raise https_fn.HttpsError("not-found", "Seller not found")

    seller_data = seller_doc.to_dict()

    # H-1: Cannot suspend an admin account via this endpoint
    if UserRoleValues.ADMIN in seller_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Cannot suspend an admin account via this endpoint.")

    # Deactivate products and cancel orders only if user has seller role
    is_seller = UserRoleValues.SELLER in seller_data.get(Fields.ROLES, [])

    # Suspend seller
    seller_ref.update(
        {
            Fields.SUSPENDED: True,
            Fields.SUSPENDED_AT: get_server_timestamp(),
            Fields.SUSPENDED_BY: admin_id,
            Fields.SUSPENSION_REASON: reason,
            Fields.UPDATED_AT: get_server_timestamp(),
        }
    )

    # Revoke all active Firebase Auth tokens immediately — suspended seller should not
    # retain JWT access for the remaining token lifetime (up to 1 hour).
    try:
        from firebase_admin import auth as firebase_auth
        firebase_auth.revoke_refresh_tokens(seller_id)
    except Exception as revoke_err:
        logger.error(f"CRITICAL: Failed to revoke tokens for suspended seller {seller_id}: {revoke_err}")
        get_db().collection(Collections.SECURITY_ALERTS).add({
            Fields.TYPE: SecurityAlertTypes.TOKEN_REVOCATION_FAILED,
            Fields.SEVERITY: SeverityLevels.CRITICAL,
            Fields.ADMIN_ID: admin_id,
            Fields.SELLER_ID: seller_id,
            Fields.REASON: f"Token revocation failed during suspension: {revoke_err}",
            Fields.TIMESTAMP: get_server_timestamp(),
            Fields.RESOLVED: False,
        })

    # Deactivate all seller's products and cancel orders only if user has seller role
    product_count = 0
    order_count = 0
    product_updates: dict[str, int] = {}

    if is_seller:
        # Deactivate all seller's products (with safety limit)
        products = (
            get_db()
            .collection(Collections.PRODUCTS)
            .where(Fields.SELLER_ID, "==", seller_id)
            .where(Fields.LIFECYCLE_STATUS, "in", [ProductLifecycleStatusValues.ACTIVE, ProductLifecycleStatusValues.APPROVED])
            .limit(500)
            .stream()
        )

        batch = get_db().batch()
        batch_count = 0
        product_ids = []

        for product_doc in products:
            batch.update(product_doc.reference, {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                Fields.SUSPENDED_AT: get_server_timestamp(),
            })
            product_ids.append(product_doc.id)
            product_count += 1
            batch_count += 1

            if batch_count >= 500:
                batch.commit()
                batch = get_db().batch()
                batch_count = 0

        if batch_count > 0:
            batch.commit()

        if product_ids:
            try:
                from services.algolia_service import batch_partial_update_products
                batch_partial_update_products(product_ids, {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED})
            except Exception as algolia_err:
                logger.error(f"WARNING: Algolia status sync failed during suspend: {algolia_err}")

        # Cancel all pending/confirmed orders (with safety limit).
        # Query uses the denormalized sellerIds array field — Firestore does not support
        # filtering on nested fields inside arrays like items[].sellerId.
        orders = (
            get_db()
            .collection(Collections.ORDERS)
            .where(Fields.SELLER_IDS, "array_contains", seller_id)
            .where(
                Fields.ORDER_STATUS,
                "in",
                [OrderStatusValues.PENDING, OrderStatusValues.CONFIRMED, OrderStatusValues.PROCESSING],
            )
            .limit(200)
            .stream()
        )

        order_batch = get_db().batch()
        order_batch_count = 0

        for order_doc in orders:
            order_data = order_doc.to_dict()

            # Accumulate stock restorations
            for item in order_data[Fields.ITEMS]:
                if item[Fields.SELLER_ID] == seller_id:
                    product_id = item[Fields.PRODUCT_ID]
                    quantity = item[Fields.QUANTITY]
                    product_updates[product_id] = product_updates.get(product_id, 0) + quantity

            # B-3: If multi-seller order, skip full cancellation to avoid impacting other sellers
            seller_ids_in_order = order_data.get(Fields.SELLER_IDS, [seller_id])
            if len([s for s in seller_ids_in_order if s]) > 1:
                continue

            order_batch.update(
                order_doc.reference,
                {
                    Fields.ORDER_STATUS: OrderStatusValues.CANCELLED,
                    Fields.CANCELLATION_REASON: f"Seller suspended: {reason}",
                    Fields.CANCELLED_BY: admin_id,
                    Fields.CANCELLED_AT: get_server_timestamp(),
                    Fields.UPDATED_AT: get_server_timestamp(),
                },
            )
            order_count += 1
            order_batch_count += 1

            if order_batch_count >= 500:
                order_batch.commit()
                order_batch = get_db().batch()
                order_batch_count = 0

        if order_batch_count > 0:
            order_batch.commit()

        # Void AUTHORIZED PaymentIntents and refund CAPTURED orders for suspended seller
        for order_doc in (
            get_db()
            .collection(Collections.ORDERS)
            .where(Fields.SELLER_IDS, "array_contains", seller_id)
            .where(Fields.ORDER_STATUS, "in", [OrderStatusValues.CANCELLED])
            .where(Fields.PAYMENT_STATUS, "in", [
                PaymentStatusValues.AUTHORIZED,
                PaymentStatusValues.CAPTURED,
            ])
            .limit(200)
            .stream()
        ):
            od = order_doc.to_dict()
            pi_id = od.get(Fields.STRIPE_PAYMENT_INTENT_ID)
            if not pi_id:
                continue
            payment_status = od.get(Fields.PAYMENT_STATUS)
            oid = order_doc.id
            try:
                if payment_status == PaymentStatusValues.AUTHORIZED:
                    stripe.PaymentIntent.cancel(
                        pi_id,
                        idempotency_key=f"suspend_void_{oid}",
                    )
                    order_doc.reference.update({Fields.PAYMENT_STATUS: PaymentStatusValues.VOIDED, Fields.UPDATED_AT: get_server_timestamp()})
                elif payment_status == PaymentStatusValues.CAPTURED:
                    stripe.Refund.create(
                        payment_intent=pi_id,
                        reason="fraudulent",
                        idempotency_key=f"suspend_refund_{oid}",
                        metadata={"admin_id": admin_id, "order_id": oid, "reason": "seller suspended"},
                    )
                    order_doc.reference.update({Fields.PAYMENT_STATUS: PaymentStatusValues.REFUNDED, Fields.UPDATED_AT: get_server_timestamp()})
            except Exception as stripe_err:
                logger.error(f"Stripe void/refund failed for order {oid} during suspension: {stripe_err}")
                get_db().collection(Collections.SECURITY_ALERTS).add({
                    Fields.TYPE: SecurityAlertTypes.REFUND_REVERSAL_FAILED,
                    Fields.ORDER_ID: oid,
                    Fields.ERROR_MESSAGE: str(stripe_err)[:500],
                    Fields.TIMESTAMP: get_server_timestamp(),
                    Fields.RESOLVED: False,
                })

        # Restore stock in batch — all reads/writes happen atomically inside the transaction
        if product_updates:
            @get_firestore().transactional
            def restore_stock_batch(transaction):
                """Function restore_stock_batch."""
                product_refs = [get_db().collection(Collections.PRODUCTS).document(pid) for pid in product_updates]
                snapshots = list(transaction.get_all(product_refs))
                for snapshot in snapshots:
                    if snapshot.exists:
                        current_stock = snapshot.to_dict().get(Fields.STOCK_QUANTITY, 0)
                        qty = product_updates[snapshot.id]
                        transaction.update(snapshot.reference, {Fields.STOCK_QUANTITY: current_stock + qty})

            restore_stock_batch(get_db().transaction())

    # Log security alert
    get_db().collection(Collections.SECURITY_ALERTS).add(
        {
            Fields.TYPE: SecurityAlertTypes.SELLER_SUSPENDED,
            Fields.SEVERITY: SeverityLevels.CRITICAL,
            Fields.ADMIN_ID: admin_id,
            Fields.SELLER_ID: seller_id,
            Fields.REASON: reason,
            Fields.PRODUCTS_DEACTIVATED: product_count,
            Fields.ORDERS_CANCELLED: order_count,
            Fields.TIMESTAMP: get_server_timestamp(),
            Fields.RESOLVED: True,
        }
    )

    return create_success_response(
        {
            ApiKeys.MESSAGE: "Seller suspended",
            Fields.PRODUCTS_DEACTIVATED: product_count,
            Fields.ORDERS_CANCELLED: order_count,
        }
    )


@https_fn.on_call(**DEFAULT_OPTIONS)
def unsuspend_seller(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Unsuspends a seller account (admin only with MFA).

    Actions:
    - Marks user as not suspended
    - Reactivates all seller's products that were suspended
    - Creates security alert

    Request data:
        sellerId: User ID to unsuspend
        reason: Unsuspension reason

    Returns:
        {success: True, message: "Seller unsuspended"}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    admin_id = req.auth.uid
    data = req.data

    # Rate limit — fail_closed=True: unsuspend is an account-state change, must not bypass on limiter error
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=admin_id, action=RateLimitActions.UNSUSPEND_SELLER, max_requests=10, window_minutes=1, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    from utils.helpers import sanitized_text

    seller_id_raw = data.get(Fields.SELLER_ID)
    reason_raw = data.get(ApiKeys.REASON, "Admin decision")

    seller_id = sanitized_text(seller_id_raw) if seller_id_raw else None
    reason = sanitized_text(reason_raw)[:500]

    if not seller_id:
        raise https_fn.HttpsError("invalid-argument", "sellerId required")

    # Check admin permissions
    admin_ref = get_db().collection(Collections.USERS).document(admin_id)
    admin_doc = admin_ref.get()

    if not admin_doc.exists:
        raise https_fn.HttpsError("not-found", "Admin user not found")

    admin_data = admin_doc.to_dict()

    if UserRoleValues.ADMIN not in admin_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    # Require recent MFA verification
    _require_recent_admin_mfa(admin_data)

    # Get seller
    seller_ref = get_db().collection(Collections.USERS).document(seller_id)
    seller_doc = seller_ref.get()

    if not seller_doc.exists:
        raise https_fn.HttpsError("not-found", "Seller not found")

    seller_data = seller_doc.to_dict()

    if not seller_data.get(Fields.SUSPENDED, False):
        raise https_fn.HttpsError("failed-precondition", "Seller is not currently suspended")

    # Unsuspend seller
    seller_ref.update(
        {
            Fields.SUSPENDED: False,
            Fields.UNSUSPENDED_AT: get_server_timestamp(),
            Fields.UNSUSPENDED_BY: admin_id,
            Fields.UPDATED_AT: get_server_timestamp(),
        }
    )

    # Reactivate seller's products that were suspended (not manually deleted)
    # Paginate in batches of 500 (Firestore batch write limit)
    product_count = 0
    skipped_count = 0
    max_iterations = 20  # Safety limit to prevent infinite loops (max 10k products)
    iteration_count = 0
    restored_product_ids = []

    while True:
        iteration_count += 1
        if iteration_count > max_iterations:
            logger.warning(
                f"⚠️ unsuspend_seller hit max iterations ({max_iterations}) for seller {seller_id}, "
                "stopping to prevent infinite loop."
            )
            break

        products = list(
            get_db()
            .collection(Collections.PRODUCTS)
            .where(Fields.SELLER_ID, "==", seller_id)
            .where(Fields.LIFECYCLE_STATUS, "==", ProductLifecycleStatusValues.PAUSED)
            .where(Fields.SUSPENDED_AT, "!=", None)
            .limit(500)
            .stream()
        )

        if not products:
            break

        batch = get_db().batch()
        batch_count = 0

        for product_doc in products:
            product_data = product_doc.to_dict()
            # Only reactivate products that were suspended (not explicitly deleted)
            if not product_data.get(Fields.DELETED_AT):
                stock = product_data.get(Fields.STOCK_QUANTITY, 0)
                price = product_data.get(Fields.PRICE, 0)
                if stock <= 0 or price <= 0:
                    skipped_count += 1
                    logger.info(
                        f"Skipping product {product_doc.id} during unsuspend "
                        f"(stock={stock}, price={price})"
                    )
                    continue
                batch.update(
                    product_doc.reference,
                    {
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                        Fields.SUSPENDED_AT: get_delete_field(),
                        "restoredAt": get_server_timestamp(),
                        Fields.UPDATED_AT: get_server_timestamp(),
                    },
                )
                restored_product_ids.append(product_doc.id)
                product_count += 1
                batch_count += 1

        if batch_count > 0:
            batch.commit()
        # Query now filters SUSPENDED_AT != None at DB level, so all fetched docs are reactivatable.
        # The while loop converges naturally as reactivated products no longer match PAUSED status.

    if restored_product_ids:
        try:
            from services.algolia_service import batch_partial_update_products
            batch_partial_update_products(restored_product_ids, {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE})
        except Exception as algolia_err:
            logger.error(f"WARNING: Algolia status sync failed during unsuspend: {algolia_err}")

    # Log security alert
    get_db().collection(Collections.SECURITY_ALERTS).add(
        {
            Fields.TYPE: SecurityAlertTypes.SELLER_UNSUSPENDED,
            Fields.SEVERITY: SeverityLevels.CRITICAL,
            Fields.ADMIN_ID: admin_id,
            Fields.SELLER_ID: seller_id,
            Fields.REASON: reason,
            Fields.PRODUCTS_DEACTIVATED: product_count,
            Fields.TIMESTAMP: get_server_timestamp(),
            Fields.RESOLVED: True,
        }
    )

    return create_success_response({ApiKeys.MESSAGE: "Seller unsuspended", "productsReactivated": product_count, "productsSkipped": skipped_count})


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_update_product_stock(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Updates product stock quantity (admin only with MFA).

    Security:
    - Requires admin role + recent MFA
    - Validates quantity is non-negative
    - Logs stock change for audit trail

    Request data:
        productId: Product document ID
        quantity: New stock quantity (0+)
        reason: Reason for stock update

    Returns:
        {success: True, message: "Stock updated"}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    admin_id = req.auth.uid
    data = req.data

    # Rate limit
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=admin_id, action=RateLimitActions.ADMIN_UPDATE_STOCK, max_requests=30, window_minutes=1, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    product_id = data.get(Fields.PRODUCT_ID)
    quantity = data.get(Fields.STOCK_QUANTITY)
    reason = data.get(ApiKeys.REASON, "Admin stock adjustment")

    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId required")

    if quantity is None or not isinstance(quantity, int) or quantity < 0:
        raise https_fn.HttpsError("invalid-argument", "quantity must be a non-negative integer")

    # Check admin permissions
    admin_ref = get_db().collection(Collections.USERS).document(admin_id)
    admin_doc = admin_ref.get()

    if not admin_doc.exists:
        raise https_fn.HttpsError("not-found", "Admin user not found")

    admin_data = admin_doc.to_dict()

    if UserRoleValues.ADMIN not in admin_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    # Require recent MFA verification
    _require_recent_admin_mfa(admin_data)

    # Get product
    product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
    product_doc = product_ref.get()

    if not product_doc.exists:
        raise https_fn.HttpsError("not-found", "Product not found")

    product_data = product_doc.to_dict()
    old_quantity = product_data.get(Fields.STOCK_QUANTITY, 0)

    # Use Increment for absolute set inside a transaction to avoid race conditions with concurrent purchases.
    # Admin sets an absolute value, but we must read-then-write atomically to correctly report old_quantity.
    @get_firestore().transactional
    def _update_stock_txn(txn, ref):
        snap = ref.get(transaction=txn)
        if not snap.exists:
            raise https_fn.HttpsError("not-found", "Product not found")
        txn.update(ref, {Fields.STOCK_QUANTITY: quantity, Fields.UPDATED_AT: get_server_timestamp()})
        return (snap.to_dict() or {}).get(Fields.STOCK_QUANTITY, 0)

    old_quantity = _update_stock_txn(get_db().transaction(), product_ref)

    logger.info(
        f"Admin {admin_id} updated stock for product {product_id}: {old_quantity} -> {quantity}. Reason: {reason}"
    )

    # Audit log (queryable, matches pattern in update_payment_provider)
    get_db().collection(Collections.ADMIN_LOGS).add(
        {
            Fields.ACTION: AdminActionValues.STOCK_UPDATE,
            Fields.ADMIN_ID: admin_id,
            Fields.PRODUCT_ID: product_id,
            "oldQuantity": old_quantity,
            "newQuantity": quantity,
            Fields.REASON: reason[:500],
            Fields.TIMESTAMP: get_server_timestamp(),
        }
    )

    return create_success_response(
        {ApiKeys.MESSAGE: "Stock updated", "oldQuantity": old_quantity, "newQuantity": quantity}
    )


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_mfa_enroll(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Enrolls admin in MFA (TOTP).

    Returns:
        {
            success: True,
            secret: "BASE32_SECRET",
            qrCodeUrl: "otpauth://..."
        }
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # AUDIT FIX: Rate limit MFA enrollment
    from services.rate_limiter import RateLimiter

    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.MFA_ENROLL, max_requests=3, window_minutes=1, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    # Check admin role
    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_data = user_doc.to_dict()

    if UserRoleValues.ADMIN not in user_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    # Generate TOTP secret
    secret = pyotp.random_base32()

    # Generate one-time backup codes (8 codes, 8 chars each)
    alphabet = string.ascii_uppercase + string.digits
    backup_codes = ["".join(secrets.choice(alphabet) for _ in range(8)) for _ in range(8)]

    # SECURITY: Hash backup codes with salt before storing (show plaintext only once)
    # Generate unique salt for this user's backup codes
    backup_codes_salt = secrets.token_hex(32)
    hashed_backup_codes = [hashlib.sha256((code + backup_codes_salt).encode()).hexdigest() for code in backup_codes]

    # AUDIT FIX: Encrypt MFA secret before storing in Firestore
    from utils.crypto_utils import encrypt_mfa_secret

    encrypted_secret = encrypt_mfa_secret(secret, associated_data=user_id)

    # AUDIT FIX: Race condition — check if enrollment already in progress or MFA already enabled
    existing_mfa = user_data.get(Fields.MFA_ENABLED, False)
    if existing_mfa:
        raise https_fn.HttpsError("failed-precondition", "MFA is already enabled. Disable it first to re-enroll.")

    # AUDIT FIX: Race condition — use Firestore transaction to prevent concurrent enrollments
    security_ref = get_db().collection(Collections.USER_SECURITY).document(user_id)

    @get_firestore().transactional
    def _enroll_mfa_txn(txn, sec_ref):
        doc = sec_ref.get(transaction=txn)
        data = doc.to_dict() or {}
        if data.get(Fields.MFA_SECRET_TEMP):
            raise https_fn.HttpsError("failed-precondition", "MFA already enabled or enrollment already in progress.")
        txn.set(
            sec_ref,
            {
                Fields.MFA_SECRET_TEMP: encrypted_secret,
                Fields.MFA_BACKUP_CODES_TEMP: hashed_backup_codes,
                Fields.MFA_BACKUP_CODES_SALT: backup_codes_salt,
                "mfaEnrollStartedAt": get_server_timestamp(),
                Fields.UPDATED_AT: get_server_timestamp(),
            },
            merge=True,
        )

    _enroll_mfa_txn(get_db().transaction(), security_ref)

    # Generate QR code URL
    totp = pyotp.TOTP(secret)
    email = user_data.get(Fields.EMAIL, user_id)
    qr_code_url = totp.provisioning_uri(name=email, issuer_name=APP_NAME)

    return create_success_response(
        {
            ApiKeys.QR_CODE_URL: qr_code_url,
            ApiKeys.PROVISIONING_URI: qr_code_url,
            ApiKeys.BACKUP_CODES: backup_codes,
        }
    )


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_mfa_verify(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Verifies MFA code and enables MFA.

    Request data:
        code: 6-digit TOTP code

    Returns:
        {success: True, mfaEnabled: True}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    code = req.data.get(ApiKeys.CODE)

    if not code:
        raise https_fn.HttpsError("invalid-argument", "code required")

    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    # Read MFA secrets from user_security/{uid} (backend-only collection)
    security_ref = get_db().collection(Collections.USER_SECURITY).document(user_id)
    security_doc = security_ref.get()
    security_data = security_doc.to_dict() if security_doc.exists else {}

    raw_secret = security_data.get(Fields.MFA_SECRET_TEMP) or security_data.get(Fields.MFA_SECRET)

    if not raw_secret:
        raise https_fn.HttpsError("failed-precondition", "MFA not enrolled. Call admin_mfa_enroll first.")

    # Decrypt MFA secret (rejects unencrypted plaintext)
    from utils.crypto_utils import decrypt_mfa_secret, encrypt_mfa_secret

    secret = decrypt_mfa_secret(raw_secret, associated_data=user_id)

    # SECURITY: Check MFA attempt limiting (max 5 attempts per 15 min)
    mfa_attempts = security_data.get(Fields.MFA_FAILED_ATTEMPTS, 0)
    mfa_lockout_until = security_data.get(Fields.MFA_LOCKOUT_UNTIL)
    if mfa_lockout_until:
        # Ensure timezone-aware comparison (Firestore timestamps are UTC)
        if hasattr(mfa_lockout_until, "tzinfo") and mfa_lockout_until.tzinfo is None:
            mfa_lockout_until = mfa_lockout_until.replace(tzinfo=UTC)
        if datetime.now(UTC) < mfa_lockout_until:
            raise https_fn.HttpsError("permission-denied", "Too many failed MFA attempts. Try again later.")

    # Verify code with constant-time comparison protection
    totp = pyotp.TOTP(secret)
    start_time = time.monotonic()

    code_valid = totp.verify(code, valid_window=1)

    # SECURITY: Constant-time response to prevent timing attacks
    elapsed = time.monotonic() - start_time
    min_response_time = 0.1  # 100ms minimum
    if elapsed < min_response_time:
        time.sleep(min_response_time - elapsed)

    if not code_valid:
        # AUDIT FIX (TOCTOU): Use atomic Increment to avoid race condition where
        # concurrent bad attempts both read the same counter value and both write
        # mfa_attempts+1, effectively halving the lockout enforcement.
        security_ref.update({Fields.MFA_FAILED_ATTEMPTS: get_firestore().Increment(1)})
        # Re-read to get the post-increment value for lockout decision
        fresh_security = security_ref.get().to_dict() or {}
        new_attempt_count = fresh_security.get(Fields.MFA_FAILED_ATTEMPTS, 1)
        if new_attempt_count >= BusinessRules.MFA_MAX_ATTEMPTS:
            security_ref.update({
                Fields.MFA_LOCKOUT_UNTIL: datetime.now(UTC) + timedelta(minutes=BusinessRules.MFA_LOCKOUT_MINUTES),
                Fields.MFA_FAILED_ATTEMPTS: 0,
            })
            logger.info(f"SECURITY: MFA lockout triggered for user {user_id}")
        raise https_fn.HttpsError("unauthenticated", "Invalid MFA code")

    # Reset failed attempts on success
    if mfa_attempts > 0:
        security_ref.update({Fields.MFA_FAILED_ATTEMPTS: 0})

    # Enable MFA — AUDIT FIX: re-encrypt secret for permanent storage with user AAD
    # Write MFA flag to users doc (OK for client to see)
    user_ref.update({
        Fields.MFA_ENABLED: True,
        Fields.LAST_MFA_VERIFY: get_server_timestamp(),
        Fields.UPDATED_AT: get_server_timestamp(),
    })

    # Write MFA secrets to user_security (backend-only)
    security_update = {
        Fields.MFA_SECRET: encrypt_mfa_secret(secret, associated_data=user_id),
        Fields.LAST_MFA_VERIFY: get_server_timestamp(),
        Fields.UPDATED_AT: get_server_timestamp(),
    }

    # Persist backup codes from temp storage
    temp_backup_codes = security_data.get(Fields.MFA_BACKUP_CODES_TEMP)
    backup_codes_salt = security_data.get(Fields.MFA_BACKUP_CODES_SALT)
    if temp_backup_codes:
        security_update[Fields.MFA_BACKUP_CODES] = temp_backup_codes
        security_update[Fields.MFA_BACKUP_CODES_TEMP] = get_delete_field()
        if backup_codes_salt:
            security_update[Fields.MFA_BACKUP_CODES_SALT] = backup_codes_salt

    # Remove temporary secret
    if Fields.MFA_SECRET_TEMP in security_data:
        security_update[Fields.MFA_SECRET_TEMP] = get_delete_field()

    security_ref.set(security_update, merge=True)

    return create_success_response({Fields.MFA_ENABLED: True})


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_mfa_disable(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Disables MFA (requires current MFA verification).

    Request data:
        code: 6-digit TOTP code

    Returns:
        {success: True, mfaEnabled: False}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    code = req.data.get(ApiKeys.CODE)

    if not code:
        raise https_fn.HttpsError("invalid-argument", "code required")

    # Rate limit MFA disable attempts (same protection as admin_mfa_verify)
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.MFA_DISABLE, max_requests=3, window_minutes=15, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_data = user_doc.to_dict()

    # Verify caller has admin role
    if UserRoleValues.ADMIN not in user_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    # Read MFA secret from user_security
    security_ref = get_db().collection(Collections.USER_SECURITY).document(user_id)
    security_doc = security_ref.get()
    security_data = security_doc.to_dict() if security_doc.exists else {}

    raw_secret = security_data.get(Fields.MFA_SECRET)

    if not raw_secret:
        raise https_fn.HttpsError("failed-precondition", "MFA not enabled")

    # Decrypt MFA secret (rejects unencrypted plaintext)
    from utils.crypto_utils import decrypt_mfa_secret

    secret = decrypt_mfa_secret(raw_secret, associated_data=user_id)

    # Verify code before disabling with timing protection
    totp = pyotp.TOTP(secret)

    start_time = time.monotonic()
    code_valid = totp.verify(code, valid_window=1)

    # SECURITY: Constant-time response to prevent timing attacks
    elapsed = time.monotonic() - start_time
    min_response_time = 0.1  # 100ms minimum
    if elapsed < min_response_time:
        time.sleep(min_response_time - elapsed)

    if not code_valid:
        raise https_fn.HttpsError("unauthenticated", "Invalid MFA code")

    # Disable MFA — update users doc (flag) and delete security secrets
    user_ref.update(
        {
            Fields.MFA_ENABLED: False,
            Fields.LAST_MFA_VERIFY: get_delete_field(),
            Fields.UPDATED_AT: get_server_timestamp(),
        }
    )
    # Delete all MFA secrets from user_security
    if security_doc.exists:
        security_ref.delete()

    get_db().collection(Collections.ADMIN_LOGS).add({
        Fields.ACTION: "mfa_disabled",
        Fields.ADMIN_ID: user_id,
        Fields.TARGET_USER_ID: user_id,
        Fields.TIMESTAMP: get_server_timestamp(),
    })

    return create_success_response({Fields.MFA_ENABLED: False})


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_mfa_verify_backup(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Verifies MFA backup code (one-time use).
    Used when admin loses access to TOTP device.

    Request data:
        code: 8-character backup code

    Returns:
        {success: True, mfaVerified: True, remainingCodes: 7}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    code = req.data.get(ApiKeys.CODE)

    if not code:
        raise https_fn.HttpsError("invalid-argument", "code required")

    # AUDIT FIX: Rate limit backup code verification attempts
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.MFA_BACKUP_VERIFY, max_requests=3, window_minutes=60, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_data = user_doc.to_dict()

    # Check if MFA is enabled
    if not user_data.get(Fields.MFA_ENABLED, False):
        raise https_fn.HttpsError("failed-precondition", "MFA not enabled")

    # Get stored backup codes and salt from user_security
    security_ref = get_db().collection(Collections.USER_SECURITY).document(user_id)
    security_doc = security_ref.get()
    security_data = security_doc.to_dict() if security_doc.exists else {}

    stored_hashed_codes = security_data.get(Fields.MFA_BACKUP_CODES, [])
    backup_codes_salt = security_data.get(Fields.MFA_BACKUP_CODES_SALT, "")

    if not stored_hashed_codes:
        raise https_fn.HttpsError("failed-precondition", "No backup codes available")

    # Hash the provided code with salt
    hashed_input = hashlib.sha256((code + backup_codes_salt).encode()).hexdigest()

    # Check if code matches using constant-time comparison
    code_found = False
    matched_hash: str | None = None
    for stored_hash in stored_hashed_codes:
        if hmac.compare_digest(hashed_input, stored_hash):
            code_found = True
            matched_hash = stored_hash

    if not code_found:
        # Log failed attempt
        logger.info(f"SECURITY: Invalid backup code attempt for user {user_id}")
        raise https_fn.HttpsError("invalid-argument", "Invalid backup code")

    # Remove used code by its exact hash — no second full scan
    remaining_codes = [c for c in stored_hashed_codes if c != matched_hash]

    # Update last MFA verify time on users doc
    user_ref.update(
        {
            Fields.LAST_MFA_VERIFY: get_server_timestamp(),
            Fields.UPDATED_AT: get_server_timestamp(),
        }
    )
    # Update remaining backup codes in user_security
    security_ref.update(
        {
            Fields.MFA_BACKUP_CODES: remaining_codes,
            Fields.UPDATED_AT: get_server_timestamp(),
        }
    )

    # Log security alert if low on codes
    if len(remaining_codes) <= 2:
        get_db().collection(Collections.SECURITY_ALERTS).add(
            {
                Fields.TYPE: SecurityAlertTypes.MFA_LOW_BACKUP_CODES,
                Fields.SEVERITY: SeverityLevels.MEDIUM,
                Fields.USER_ID: user_id,
                ApiKeys.REMAINING_CODES: len(remaining_codes),
                Fields.TIMESTAMP: get_server_timestamp(),
                Fields.RESOLVED: False,
            }
        )

    return create_success_response({ApiKeys.MFA_VERIFIED: True, ApiKeys.REMAINING_CODES: len(remaining_codes)})


@https_fn.on_call(**DEFAULT_OPTIONS)
def delete_account(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Deletes user account (GDPR compliance).

    Actions:
    - Deletes Firebase Auth user
    - Anonymizes Firestore data
    - Keeps orders/payouts for accounting (anonymized)

    Returns:
        {success: True, message: "Account deleted"}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # AUDIT FIX: Rate limit account deletion
    from services.rate_limiter import RateLimiter

    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.DELETE_ACCOUNT, max_requests=1, window_minutes=1, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    # Check if user has pending orders or payouts (with limit)
    pending_orders = (
        get_db()
        .collection(Collections.ORDERS)
        .where(Fields.USER_ID, "==", user_id)
        .where(
            Fields.ORDER_STATUS,
            "in",
            [
                OrderStatusValues.PENDING,
                OrderStatusValues.CONFIRMED,
                OrderStatusValues.PROCESSING,
                OrderStatusValues.SHIPPED,
            ],
        )
        .limit(1)
        .stream()
    )

    # Convert to list with safety check
    pending_orders_list = list(pending_orders)
    if pending_orders_list:
        raise https_fn.HttpsError(
            "failed-precondition", "Cannot delete account with pending orders. Please wait for orders to complete."
        )

    # Check if user is a seller with active orders to fulfill
    active_sales = (
        get_db()
        .collection(Collections.ORDERS)
        .where(Fields.SELLER_IDS, "array_contains", user_id)
        .where(
            Fields.ORDER_STATUS,
            "in",
            [
                OrderStatusValues.PENDING,
                OrderStatusValues.CONFIRMED,
                OrderStatusValues.PROCESSING,
                OrderStatusValues.SHIPPED,
            ],
        )
        .limit(1)
        .stream()
    )

    if any(active_sales):
        raise https_fn.HttpsError(
            "failed-precondition",
            "Cannot delete account with active sales to fulfill. Please complete your orders first.",
        )

    pending_payouts = (
        get_db()
        .collection(Collections.PAYOUTS)
        .where(Fields.SELLER_ID, "==", user_id)
        .where(Fields.STATUS, "==", PayoutStatusValues.PENDING)
        .limit(1)
        .stream()
    )

    if any(pending_payouts):
        raise https_fn.HttpsError(
            "failed-precondition", "Cannot delete account with pending payouts. Please contact support."
        )

    # Anonymize user data
    user_ref = get_db().collection(Collections.USERS).document(user_id)

    # GDPR: stripeAccountId lives in seller_profiles, not users
    sp_doc = get_db().collection(Collections.SELLER_PROFILES).document(user_id).get()
    stripe_account_id = (sp_doc.to_dict() or {}).get(Fields.STRIPE_ACCOUNT_ID) if sp_doc.exists else None

    # GDPR: Delete Stripe Connect account before anonymizing Firestore
    if stripe_account_id:
        try:
            stripe.Account.delete(stripe_account_id)
            logger.info(f"GDPR: Deleted Stripe Connect account {stripe_account_id} for user {user_id}")
        except Exception as stripe_err:
            # Log but don't block — Stripe cleanup is best-effort, flag for manual review
            get_db().collection(Collections.SECURITY_ALERTS).add(
                {
                    Fields.TYPE: SecurityAlertTypes.AUTH_DELETION_FAILED,
                    Fields.SEVERITY: SeverityLevels.HIGH,
                    Fields.USER_ID: user_id,
                    Fields.ERROR_MESSAGE: f"Stripe account deletion failed: {stripe_err}",
                    Fields.TIMESTAMP: get_server_timestamp(),
                    Fields.RESOLVED: False,
                }
            )
            logger.error(f"WARNING: Failed to delete Stripe account {stripe_account_id}: {stripe_err}")

    # GDPR: Delete user files from Firebase Storage
    try:
        from firebase_admin import storage as fb_storage

        bucket = fb_storage.bucket()
        for prefix in [f"products/{user_id}/", f"users/{user_id}/", f"verification/{user_id}/"]:
            blobs = list(bucket.list_blobs(prefix=prefix, max_results=500))
            for blob in blobs:
                blob.delete()
            if blobs:
                logger.info(f"GDPR: Deleted {len(blobs)} files from {prefix}")
    except Exception as storage_err:
        logger.error(f"WARNING: Storage cleanup failed for user {user_id}: {storage_err}")

    user_ref.update(
        {
            Fields.EMAIL: f"deleted_{user_id}@anonymized.local",
            Fields.NAME: "[Deleted User]",
            Fields.ADDRESS: get_delete_field(),
            Fields.STRIPE_ACCOUNT_ID: get_delete_field(),
            Fields.SELLER_PROFILE: get_delete_field(),
            Fields.BUSINESS_ADDRESS: get_delete_field(),
            Fields.BUSINESS_NAME: get_delete_field(),
            Fields.FULL_NAME: get_delete_field(),
            Fields.CUSTOMER_ID: get_delete_field(),
            Fields.BANK_DETAILS: get_delete_field(),
            Fields.PHONE_NUMBER: get_delete_field(),
            Fields.DELETED: True,
            Fields.DELETED_AT: get_server_timestamp(),
        }
    )

    # Delete user_security doc (MFA secrets)
    security_ref = get_db().collection(Collections.USER_SECURITY).document(user_id)
    if security_ref.get().exists:
        security_ref.delete()

    # GDPR: Delete seller profile if exists
    sp_ref = get_db().collection(Collections.SELLER_PROFILES).document(user_id)
    if sp_ref.get().exists:
        sp_ref.delete()
        logger.info(f"GDPR: Deleted seller_profiles/{user_id}")

    # GDPR FIX: Anonymize orders collection (unlink from user but keep for accounting)
    # Create anonymized identifier that can't be reversed
    anonymized_id = f"deleted_{hashlib.sha256(user_id.encode()).hexdigest()[:16]}"

    # Anonymize all orders (paginated — Firestore batch limit is 500)
    # Each iteration changes userId, so query converges naturally
    orders_count = 0
    while True:
        user_orders = list(
            get_db().collection(Collections.ORDERS).where(Fields.USER_ID, "==", user_id).limit(500).stream()
        )

        if not user_orders:
            break

        orders_batch = get_db().batch()
        for order_doc in user_orders:
            orders_batch.update(
                order_doc.reference,
                {
                    Fields.USER_ID: anonymized_id,
                    Fields.CUSTOMER_EMAIL: get_delete_field(),
                    Fields.SHIPPING_ADDRESS: get_delete_field(),
                    Fields.ANONYMIZED_AT: get_server_timestamp(),
                    Fields.ORIGINAL_USER_DELETED: True,
                },
            )
            orders_count += 1

        orders_batch.commit()

    if orders_count > 0:
        logger.info(f"GDPR: Anonymized {orders_count} orders for deleted user {user_id}")

    # Deactivate and anonymize products (GDPR: remove seller PII)
    product_ids_to_remove = []
    while True:
        products = list(
            get_db().collection(Collections.PRODUCTS).where(Fields.SELLER_ID, "==", user_id).limit(500).stream()
        )

        if not products:
            break

        product_batch = get_db().batch()
        for product_doc in products:
            product_batch.update(
                product_doc.reference,
                {
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ARCHIVED,
                    "archivedReason": "account_deleted",
                    Fields.ARCHIVED_AT: get_server_timestamp(),
                    Fields.SELLER_ID: anonymized_id,
                    Fields.SELLER_NAME: "[Deleted Seller]",
                    Fields.SELLER_ADDRESS: get_delete_field(),
                    Fields.DELETED_AT: get_server_timestamp(),
                },
            )
            product_ids_to_remove.append(product_doc.id)

        product_batch.commit()

    # GDPR: Remove products from Algolia search index
    if product_ids_to_remove:
        try:
            from services.algolia_service import delete_products_from_algolia

            delete_products_from_algolia(product_ids_to_remove)
            logger.info(f"GDPR: Removed {len(product_ids_to_remove)} products from Algolia")
        except Exception as algolia_err:
            logger.error(f"WARNING: Algolia cleanup failed: {algolia_err}")

    # GDPR: Anonymize payout records (keep for accounting, remove PII)
    payout_count = 0
    while True:
        user_payouts = list(
            get_db().collection(Collections.PAYOUTS).where(Fields.SELLER_ID, "==", user_id).limit(500).stream()
        )

        if not user_payouts:
            break

        payout_batch = get_db().batch()
        for payout_doc in user_payouts:
            payout_batch.update(
                payout_doc.reference,
                {
                    Fields.SELLER_ID: anonymized_id,
                    Fields.ANONYMIZED_AT: get_server_timestamp(),
                },
            )
            payout_count += 1

        payout_batch.commit()
    if payout_count > 0:
        logger.info(f"GDPR: Anonymized {payout_count} payout records for deleted user {user_id}")

    # GDPR: Anonymize or delete product questions (where user is asker or seller)
    # 1. User as Asker (anonymize askerId)
    while True:
        asker_questions = list(
            get_db().collection(Collections.PRODUCT_QUESTIONS).where(Fields.ASKER_ID, "==", user_id).limit(500).stream()
        )
        if not asker_questions:
            break
        q_batch = get_db().batch()
        for q_doc in asker_questions:
            q_batch.update(q_doc.reference, {Fields.ASKER_ID: anonymized_id})
        q_batch.commit()

    # 2. User as Seller (anonymize sellerId)
    while True:
        seller_questions = list(
            get_db().collection(Collections.PRODUCT_QUESTIONS).where(Fields.SELLER_ID, "==", user_id).limit(500).stream()
        )
        if not seller_questions:
            break
        q_batch = get_db().batch()
        for q_doc in seller_questions:
            q_batch.update(q_doc.reference, {Fields.SELLER_ID: anonymized_id})
        q_batch.commit()

    # GDPR: Anonymize product ratings (keep the rating but unlink identity)
    while True:
        user_ratings = list(
            get_db().collection(Collections.PRODUCT_RATINGS).where(Fields.USER_ID, "==", user_id).limit(500).stream()
        )
        if not user_ratings:
            break
        r_batch = get_db().batch()
        for r_doc in user_ratings:
            r_batch.update(r_doc.reference, {Fields.USER_ID: anonymized_id})
        r_batch.commit()

    # GDPR: Delete stock notifications (contains email)
    while True:
        stock_notifs = list(
            get_db().collection(Collections.STOCK_NOTIFICATIONS).where(Fields.USER_ID, "==", user_id).limit(500).stream()
        )
        if not stock_notifs:
            break
        s_batch = get_db().batch()
        for s_doc in stock_notifs:
            s_batch.delete(s_doc.reference)
        s_batch.commit()

    # GDPR: Anonymize or delete chat threads — run BOTH buyer and seller queries
    # unconditionally to handle users with both roles (fixes GDPR PII leak)
    for chat_field in [Fields.BUYER_ID, Fields.SELLER_ID]:
        while True:
            user_chats = list(
                get_db()
                .collection(Collections.CHATS)
                .where(chat_field, "==", user_id)
                .limit(100)
                .stream()
            )
            if not user_chats:
                break

            for chat_doc in user_chats:
                # GDPR: Delete all messages in the thread first
                while True:
                    messages = list(chat_doc.reference.collection(Collections.CHAT_MESSAGES).limit(500).stream())
                    if not messages:
                        break
                    m_batch = get_db().batch()
                    for m_doc in messages:
                        m_batch.delete(m_doc.reference)
                    m_batch.commit()

                chat_data = chat_doc.to_dict()
                chat_doc.reference.update(
                    {
                        Fields.BUYER_ID: anonymized_id if chat_data.get(Fields.BUYER_ID) == user_id else chat_data.get(Fields.BUYER_ID),
                        Fields.SELLER_ID: anonymized_id if chat_data.get(Fields.SELLER_ID) == user_id else chat_data.get(Fields.SELLER_ID),
                        Fields.LAST_MESSAGE: "[Chat history deleted]",
                    }
                )

    # Delete cart, favorites, address book, notifications, warehouses, metrics, and FCM tokens (subcollections, paginated)
    # FCM tokens are device identifiers = PII under PIPEDA — must be deleted for right to erasure.
    for sub_coll in [
        Collections.CART,
        Collections.FAVORITES,
        Collections.ADDRESSES,
        Collections.NOTIFICATIONS,
        Collections.WAREHOUSES,
        Collections.SELLER_METRICS,
        Collections.FCM_TOKENS,
    ]:
        while True:
            docs = list(get_db().collection(Collections.USERS).document(user_id).collection(sub_coll).limit(500).stream())
            if not docs:
                break
            batch = get_db().batch()
            for doc in docs:
                batch.delete(doc.reference)
            batch.commit()

    # Delete the top-level subscription doc (not a subcollection — lives at subscriptions/{uid})
    # Required for PIPEDA right to erasure and CASL records.
    get_db().collection(Collections.SUBSCRIPTIONS).document(user_id).delete()

    # Delete Firebase Auth user
    try:
        auth.delete_user(user_id)
    except Exception as e:
        # CRITICAL: If Auth deletion fails, user can still sign in
        # Mark for manual review but still return success for Firestore anonymization
        get_db().collection(Collections.SECURITY_ALERTS).add(
            {
                Fields.TYPE: SecurityAlertTypes.AUTH_DELETION_FAILED,
                Fields.SEVERITY: SeverityLevels.HIGH,
                Fields.USER_ID: user_id,
                Fields.ERROR_MESSAGE: f"{type(e).__name__}: Auth deletion failed. Check logs.",
                Fields.TIMESTAMP: get_server_timestamp(),
                Fields.RESOLVED: False,
            }
        )
        logger.critical(f"CRITICAL: Failed to delete Auth user {user_id}: {str(e)}")
        raise https_fn.HttpsError(
            "internal", "Account data anonymized but auth deletion failed. Contact support."
        ) from e

    return create_success_response({ApiKeys.MESSAGE: "Account deleted successfully"})


@https_fn.on_call(**DEFAULT_OPTIONS)
def export_my_data(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    PIPEDA compliance: Export all user data.

    Returns all personal data stored about the requesting user,
    including profile, orders, favorites, and consent history.
    Required by PIPEDA for data subject access requests (DSAR).
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required")

    user_id = req.auth.uid

    # Rate limit to prevent abuse
    from services.rate_limiter import RateLimiter

    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.EXPORT_DATA, max_requests=3, window_minutes=60, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    # Collect all user data
    user_doc = get_db().collection(Collections.USERS).document(user_id).get()
    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_data = user_doc.to_dict()
    # PIPEDA allowlist: only export fields the user explicitly provided or that are legally required.
    # Internal operational fields (suspendedBy, lastMfaVerify, etc.) are excluded.
    exportable_fields = {
        Fields.UID, Fields.EMAIL, Fields.NAME, Fields.ADDRESS,
        Fields.ROLES, Fields.CREATED_AT, Fields.UPDATED_AT,
        Fields.PREFERRED_LANGUAGE,
        Fields.EMAIL_CONSENT, Fields.MARKETING_OPT_IN,
        Fields.CONSENT_TIMESTAMP, Fields.CONSENT_METHOD,
        Fields.PRIVACY_ACCEPTED_AT, Fields.TERMS_ACCEPTED_AT,
        Fields.PRIVACY_POLICY_VERSION, Fields.TERMS_VERSION,
        Fields.DATA_PROCESSING_CONSENT, Fields.UNSUBSCRIBED_AT,
        Fields.MFA_ENABLED, Fields.MFA_ENROLLED_AT,
        Fields.TAX_EXEMPTION,
        Fields.NOTIFY_NEW_PRODUCTS, Fields.NOTIFY_TRENDING,
    }
    user_export = {k: v for k, v in user_data.items() if k in exportable_fields}

    # Collect orders (paginated — PIPEDA requires complete export)
    orders = []
    last_order_doc = None
    while True:
        query = (
            get_db()
            .collection(Collections.ORDERS)
            .where(Fields.USER_ID, "==", user_id)
            .order_by(Fields.CREATED_AT)
            .limit(500)
        )
        if last_order_doc:
            query = query.start_after(last_order_doc)
        batch_docs = list(query.stream())
        for order_doc in batch_docs:
            order_data = order_doc.to_dict()
            order_data[Fields.ORDER_ID] = order_doc.id
            for key, val in order_data.items():
                if hasattr(val, "isoformat"):
                    order_data[key] = val.isoformat()
            orders.append(order_data)
        if len(batch_docs) < 500:
            break
        last_order_doc = batch_docs[-1]

    # Collect favorites
    favorites = []
    fav_docs = get_db().collection(Collections.USERS).document(user_id).collection(Collections.FAVORITES).stream()
    for fav_doc in fav_docs:
        favorites.append(fav_doc.id)

    # Serialize user_export datetime fields
    for key, val in user_export.items():
        if hasattr(val, "isoformat"):
            user_export[key] = val.isoformat()

    return create_success_response(
        {
            ApiKeys.PROFILE: user_export,
            ApiKeys.ORDERS: orders,
            ApiKeys.FAVORITES: favorites,
            ApiKeys.EXPORTED_AT: datetime.now(UTC).isoformat(),
        }
    )


@https_fn.on_call(**DEFAULT_OPTIONS)
def unsubscribe_email(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    CASL compliance: Unsubscribe from all marketing emails.

    Updates user document to set marketingOptIn=false and emailConsent=false.
    Records the unsubscription timestamp for CASL audit trail.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required")

    user_id = req.auth.uid

    # Rate limit unsubscribe to prevent abuse
    from services.rate_limiter import RateLimiter

    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.UNSUBSCRIBE, max_requests=5, window_minutes=10, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_ref.update(
        {
            Fields.MARKETING_OPT_IN: False,
            Fields.EMAIL_CONSENT: False,
            Fields.UNSUBSCRIBED_AT: get_server_timestamp(),
            Fields.UPDATED_AT: get_server_timestamp(),
        }
    )

    logger.info(f"User {user_id} unsubscribed from marketing emails (CASL)")

    return create_success_response({ApiKeys.MESSAGE: "Successfully unsubscribed from marketing emails"})


@https_fn.on_call(**DEFAULT_OPTIONS)
def e2e_get_mail_logs(req: https_fn.CallableRequest) -> dict[str, Any]:
    """DEV ONLY: Get mail logs for E2E tests by email."""
    from config import CURRENT_ENV, Environment

    if CURRENT_ENV == Environment.PRODUCTION:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED, message="Not allowed in production environment"
        )

    # Verify caller is authenticated
    if not req.auth:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message="Not authenticated")
    user_id = req.auth.uid

    db = get_db()
    user_doc = db.collection(Collections.USERS).document(user_id).get()

    if not user_doc.exists or UserRoleValues.ADMIN not in user_doc.to_dict().get(Fields.ROLES, []):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.PERMISSION_DENIED, message="Admin role required")

    to_email = req.data.get("to")
    if not to_email:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="Missing 'to' parameter")

    # Get recent emails sent to this address
    from google.cloud.firestore_v1.base_query import FieldFilter

    logs = (
        db.collection(Collections.MAIL_LOGS)
        .where(filter=FieldFilter("to", "==", to_email))
        .order_by("sentAt", direction=get_firestore().Query.DESCENDING)
        .limit(10)
        .stream()
    )

    results = []
    for log in logs:
        data = log.to_dict()
        data["id"] = log.id
        # Convert timestamp to ISO string for JSON serialization
        if "sentAt" in data and data["sentAt"]:
            data["sentAt"] = data["sentAt"].isoformat()
        results.append(data)

    return create_success_response({"logs": results})


@https_fn.on_call(**DEFAULT_OPTIONS)
def e2e_seed_license(req: https_fn.CallableRequest) -> dict[str, Any]:
    """DEV/STAGING ONLY: Seed or delete a test license document for E2E tests.

    Uses Admin SDK to bypass Firestore security rules (licenses collection
    has allow write: if false — only Admin SDK can write).

    Requires admin role. Actions:
      create — writes license doc with provided data (server timestamp for createdAt)
      delete — deletes license doc by licenseKey
    """
    from config import CURRENT_ENV, Environment

    if CURRENT_ENV == Environment.PRODUCTION:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="Not allowed in production environment",
        )

    if not req.auth:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message="Not authenticated")
    user_id = req.auth.uid

    db = get_db()
    user_doc = db.collection(Collections.USERS).document(user_id).get()
    if not user_doc.exists or UserRoleValues.ADMIN not in user_doc.to_dict().get(Fields.ROLES, []):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.PERMISSION_DENIED, message="Admin role required")

    action = req.data.get("action", "create")
    license_key = req.data.get("licenseKey")
    if not license_key:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="licenseKey required")

    license_ref = db.collection(Collections.LICENSES).document(license_key)

    if action == "delete":
        license_ref.delete()
        return create_success_response({"deleted": license_key})

    # action == "create"
    data = req.data.get("data")
    if not data or not isinstance(data, dict):
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="data dict required for create")

    # Enforce licenseKey matches doc ID; set server timestamp
    data[Fields.LICENSE_KEY] = license_key
    data[Fields.CREATED_AT] = get_server_timestamp()

    license_ref.set(data)
    return create_success_response({"created": license_key})


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_get_reviews(req: https_fn.CallableRequest) -> dict[str, Any]:
    """List product reviews (admin only). Supports pagination and flagged filter."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    admin_id = req.auth.uid
    admin_doc = get_db().collection(Collections.USERS).document(admin_id).get()
    if not admin_doc.exists or UserRoleValues.ADMIN not in admin_doc.to_dict().get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    limit = min(int(req.data.get("limit", 20)), 100)
    start_after_id = req.data.get("startAfter")
    flagged_only = bool(req.data.get("flaggedOnly", False))

    query = get_db().collection(Collections.PRODUCT_RATINGS).order_by(Fields.CREATED_AT, direction="DESCENDING")

    if flagged_only:
        query = query.where(Fields.IS_FLAGGED, "==", True)

    if start_after_id:
        snap = get_db().collection(Collections.PRODUCT_RATINGS).document(start_after_id).get()
        if snap.exists:
            query = query.start_after(snap)

    docs = list(query.limit(limit).stream())
    reviews = []
    for doc in docs:
        data = doc.to_dict() or {}
        reviews.append({
            Fields.REVIEW_ID: doc.id,
            Fields.PRODUCT_ID: data.get(Fields.PRODUCT_ID),
            Fields.USER_ID: data.get(Fields.USER_ID),
            Fields.RATING: data.get(Fields.RATING),
            Fields.COMMENT: data.get(Fields.COMMENT),
            Fields.IS_FLAGGED: data.get(Fields.IS_FLAGGED, False),
            Fields.CREATED_AT: data.get(Fields.CREATED_AT),
        })

    return create_success_response({"reviews": reviews, "count": len(reviews)})


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_delete_review(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Delete a product review (admin only with MFA). Logs to admin_logs."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    admin_id = req.auth.uid
    review_id = req.data.get(Fields.REVIEW_ID)
    reason = (req.data.get(ApiKeys.REASON) or "Admin decision")[:500]

    if not review_id:
        raise https_fn.HttpsError("invalid-argument", "reviewId required")

    admin_doc = get_db().collection(Collections.USERS).document(admin_id).get()
    if not admin_doc.exists or UserRoleValues.ADMIN not in admin_doc.to_dict().get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    _require_recent_admin_mfa(admin_doc.to_dict())

    review_ref = get_db().collection(Collections.PRODUCT_RATINGS).document(review_id)
    review_snap = review_ref.get()
    if not review_snap.exists:
        raise https_fn.HttpsError("not-found", "Review not found")

    review_data = review_snap.to_dict() or {}
    deleted_product_id = review_data.get(Fields.PRODUCT_ID)
    deleted_rating_value = review_data.get(Fields.RATING, 0)

    review_ref.delete()

    # FIX H-1: Recalculate product average rating after deletion to keep it consistent.
    if deleted_product_id:
        try:
            product_ref = get_db().collection(Collections.PRODUCTS).document(deleted_product_id)

            def _recalc_txn(txn):
                p_snap = product_ref.get(transaction=txn)
                if not p_snap.exists:
                    return
                p_data = p_snap.to_dict() or {}
                old_avg = p_data.get(Fields.RATING, 0)
                old_count = p_data.get(Fields.RATING_COUNT, 0)
                if old_count <= 1:
                    # Last rating removed → reset to zero
                    txn.update(product_ref, {Fields.RATING: 0, Fields.RATING_COUNT: 0})
                    return
                new_count = old_count - 1
                new_avg = max(0.0, (old_avg * old_count - deleted_rating_value) / new_count)
                txn.update(product_ref, {Fields.RATING: new_avg, Fields.RATING_COUNT: new_count})

            from firebase_admin import firestore as _fs_admin
            _fs_admin.transactional(_recalc_txn)(get_db().transaction())

            # Sync Algolia after recalculation
            from services.algolia_service import algolia_partial_update
            p_after = product_ref.get().to_dict() or {}
            algolia_partial_update(
                deleted_product_id,
                {Fields.RATING: p_after.get(Fields.RATING, 0), Fields.RATING_COUNT: p_after.get(Fields.RATING_COUNT, 0)},
            )
        except Exception as recalc_err:
            logger.error(f"admin_delete_review: failed to recalculate rating for {deleted_product_id}: {recalc_err}")

    get_db().collection(Collections.ADMIN_LOGS).add(
        {
            Fields.ACTION: AdminActionValues.REVIEW_DELETE,
            Fields.ADMIN_ID: admin_id,
            Fields.REVIEW_ID: review_id,
            Fields.REASON: reason,
            Fields.TIMESTAMP: get_server_timestamp(),
        }
    )
    return create_success_response({"deleted": True})


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_flag_review(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Flag or unflag a product review (admin only with MFA). Logs to admin_logs."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    admin_id = req.auth.uid
    review_id = req.data.get(Fields.REVIEW_ID)
    flagged = req.data.get("flagged")
    reason = (req.data.get(ApiKeys.REASON) or "Admin decision")[:500]

    if not review_id or not isinstance(flagged, bool):
        raise https_fn.HttpsError("invalid-argument", "reviewId and flagged (bool) required")

    admin_doc = get_db().collection(Collections.USERS).document(admin_id).get()
    if not admin_doc.exists or UserRoleValues.ADMIN not in admin_doc.to_dict().get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    _require_recent_admin_mfa(admin_doc.to_dict())

    review_ref = get_db().collection(Collections.PRODUCT_RATINGS).document(review_id)
    if not review_ref.get().exists:
        raise https_fn.HttpsError("not-found", "Review not found")

    review_ref.update({Fields.IS_FLAGGED: flagged, Fields.UPDATED_AT: get_server_timestamp()})

    get_db().collection(Collections.ADMIN_LOGS).add(
        {
            Fields.ACTION: AdminActionValues.REVIEW_FLAG,
            Fields.ADMIN_ID: admin_id,
            Fields.REVIEW_ID: review_id,
            "flagged": flagged,
            Fields.REASON: reason,
            Fields.TIMESTAMP: get_server_timestamp(),
        }
    )
    return create_success_response({"flagged": flagged})


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_refund_order(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Full-order refund (admin only with MFA). Issues Stripe refund and updates order."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    admin_id = req.auth.uid
    order_id = (req.data.get(Fields.ORDER_ID) or "").strip()
    reason = (req.data.get(ApiKeys.REASON) or "Admin refund")[:500]

    if not order_id:
        raise https_fn.HttpsError("invalid-argument", "orderId required")

    admin_doc = get_db().collection(Collections.USERS).document(admin_id).get()
    if not admin_doc.exists or UserRoleValues.ADMIN not in admin_doc.to_dict().get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    _require_recent_admin_mfa(admin_doc.to_dict())

    order_ref = get_db().collection(Collections.ORDERS).document(order_id)
    order_doc = order_ref.get()
    if not order_doc.exists:
        raise https_fn.HttpsError("not-found", "Order not found")

    order_data = order_doc.to_dict()

    # Guard: only refundable statuses
    _REFUNDABLE_STATUSES = {OrderStatusValues.DELIVERED, OrderStatusValues.CONFIRMED, OrderStatusValues.PROCESSING, OrderStatusValues.SHIPPED}
    current_status = order_data.get(Fields.ORDER_STATUS)
    if current_status not in _REFUNDABLE_STATUSES:
        raise https_fn.HttpsError(
            "failed-precondition",
            f"Order status '{current_status}' is not refundable. Must be one of: {', '.join(_REFUNDABLE_STATUSES)}",
        )

    payment_intent_id = order_data.get(Fields.STRIPE_PAYMENT_INTENT_ID)
    if not payment_intent_id:
        raise https_fn.HttpsError("failed-precondition", "Order has no payment intent — cannot refund")

    # C-2: Reverse seller Stripe transfers BEFORE issuing buyer refund.
    # Prevents double-loss: buyer refunded AND seller keeps money.
    payout_docs = list(
        get_db()
        .collection(Collections.PAYOUTS)
        .where(Fields.ORDER_ID, "==", order_id)
        .where(Fields.STATUS, "==", PayoutStatusValues.COMPLETED)
        .limit(50)  # Cost fix: bounded by seller count per order
        .stream()
    )
    for payout_doc in payout_docs:
        payout_data = payout_doc.to_dict()
        transfer_id = payout_data.get(Fields.STRIPE_TRANSFER_ID)
        if not transfer_id:
            continue
        try:
            stripe.Transfer.create_reversal(
                transfer_id,
                idempotency_key=f"reversal_{order_id}_{payout_data.get(Fields.SELLER_ID, '')}",
            )
            payout_doc.reference.update({
                Fields.STATUS: PayoutStatusValues.REVERSED,
                Fields.UPDATED_AT: get_server_timestamp(),
            })
        except stripe.error.InvalidRequestError as e:
            err_msg = str(e)
            # "already_reversed" is acceptable — treat as success
            if "already" in err_msg.lower():
                continue
            # Any other reversal failure: abort — do NOT refund buyer
            get_db().collection(Collections.SECURITY_ALERTS).add({
                Fields.TYPE: SecurityAlertTypes.REFUND_REVERSAL_FAILED,
                Fields.STRIPE_TRANSFER_ID: transfer_id,
                Fields.ORDER_ID: order_id,
                Fields.ERROR_MESSAGE: f"{type(e).__name__}: {err_msg[:500]}",
                Fields.TIMESTAMP: get_server_timestamp(),
                Fields.RESOLVED: False,
            })
            raise https_fn.HttpsError(
                "internal",
                f"Transfer reversal failed for seller {payout_data.get(Fields.SELLER_ID)} — refund aborted to prevent double-loss."
            ) from e

    try:
        refund = stripe.Refund.create(
            payment_intent=payment_intent_id,
            reason="requested_by_customer",
            idempotency_key=f"admin_refund_{order_id}",
            metadata={"admin_id": admin_id, "order_id": order_id, "reason": reason},
        )
    except stripe.StripeError as e:
        raise https_fn.HttpsError("internal", f"Stripe refund failed: {e}") from e

    # Restore stock atomically in Firestore transaction
    items = order_data.get(Fields.ITEMS, [])
    if items:
        from firebase_admin import firestore as _fs

        @_fs.transactional
        def _restore_stock(transaction):
            refs_snaps = []
            for item in items:
                product_ref = get_db().collection(Collections.PRODUCTS).document(item[Fields.PRODUCT_ID])
                snap = product_ref.get(transaction=transaction)
                refs_snaps.append((product_ref, snap, item.get(Fields.QUANTITY, 0)))
            for ref, snap, qty in refs_snaps:
                if snap.exists and qty > 0:
                    current = (snap.to_dict() or {}).get(Fields.STOCK_QUANTITY, 0)
                    transaction.update(ref, {Fields.STOCK_QUANTITY: current + qty})

        _restore_stock(get_db().transaction())

    # DIGITAL-C1: Revoke licenses if this order contained digital products
    revoked_count = 0
    try:
        from handlers.digital import _revoke_digital_licenses_for_order
        revoked_count = _revoke_digital_licenses_for_order(order_id)
        if revoked_count > 0:
            logger.info(f"Revoked {revoked_count} digital licenses for refunded order {order_id}")
    except Exception as e:
        logger.error(f"Failed to revoke digital licenses for order {order_id}: {e}")
        # We don't abort the refund here, but we log the failure.

    order_ref.update(
        {
            Fields.ORDER_STATUS: OrderStatusValues.CANCELLED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.REFUNDED,
            Fields.REFUNDED_AT: get_server_timestamp(),
            Fields.REFUND_REASON: reason,
            Fields.CANCELLED_BY: admin_id,
            Fields.UPDATED_AT: get_server_timestamp(),
            Fields.REVOKED_LICENSE_COUNT: revoked_count,
        }
    )

    get_db().collection(Collections.ADMIN_LOGS).add(
        {
            Fields.ACTION: AdminActionValues.ORDER_REFUND,
            Fields.ADMIN_ID: admin_id,
            Fields.ORDER_ID: order_id,
            "stripeRefundId": refund.id,
            Fields.REASON: reason,
            Fields.TIMESTAMP: get_server_timestamp(),
        }
    )
    return create_success_response({"refundId": refund.id, "status": refund.status})


@https_fn.on_call(**DEFAULT_OPTIONS)
def create_stripe_login_link(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Generate a Stripe Express Dashboard login link for the authenticated seller.
    Static dashboard URLs don't work for Express accounts — requires server-side call.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    uid = req.auth.uid
    sp_doc = get_db().collection(Collections.SELLER_PROFILES).document(uid).get()
    if not sp_doc.exists:
        raise https_fn.HttpsError("not-found", "Seller profile not found.")

    stripe_account_id = (sp_doc.to_dict() or {}).get(Fields.STRIPE_ACCOUNT_ID)
    if not stripe_account_id:
        raise https_fn.HttpsError("failed-precondition", "No Stripe account found. Please complete onboarding first.")

    if not stripe.api_key:
        from config import get_stripe_secret_key
        stripe.api_key = get_stripe_secret_key()

    try:
        login_link = stripe.Account.create_login_link(stripe_account_id)
        return create_success_response({"url": login_link.url})
    except stripe.StripeError as e:
        logger.error(f"Failed to create Stripe login link for {uid}: {e}")
        raise https_fn.HttpsError("internal", "Failed to generate dashboard link. Please try again.") from e
