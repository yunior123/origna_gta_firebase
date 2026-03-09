"""
Cloud Tasks Worker Functions
"""
import logging

import sentry_sdk
import stripe
from firebase_functions import https_fn
from google.api_core import exceptions as google_exceptions

from config import get_stripe_secret_key
from schema_constants import (
    Collections,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
)
from utils.db import get_db, get_firestore, get_server_timestamp
from utils.function_options import V2_OPTIONS

logger = logging.getLogger(__name__)


@https_fn.on_request(**V2_OPTIONS)
def stale_orders_worker(req: https_fn.Request) -> https_fn.Response:
    """
    Processes a single stale order triggered by a Cloud Task.

    This function is the target for tasks dispatched by stale_orders_dispatcher.
    It performs the actual work of expiring an order, cancelling the Stripe
    authorization, restoring stock, and sending an email.

    Request Body:
        {
            "order_id": "the-order-id"
        }
    """
    body: dict | None = None
    try:
        # Cloud Tasks authenticates via OIDC token. The Cloud Run service
        # automatically verifies the token when the function requires authentication
        # (i.e., the service account has `roles/run.invoker` on this function).
        # No manual token verification needed for Cloud Functions v2 private endpoints.

        # Parse the order ID from the request body
        body = req.get_json(silent=True)
        if not body or "order_id" not in body:
            logger.error("Request body is missing 'order_id'")
            # Return a 400 Bad Request status. Cloud Tasks will not retry.
            return https_fn.Response("Invalid request: missing order_id", status=400)

        order_id = body["order_id"]
        logger.info(f"Worker processing stale order: {order_id}")
        stripe.api_key = get_stripe_secret_key()

        # 3. Execute the order processing logic (moved from the old cron job)
        success = _process_one_stale_order(order_id)

        if success:
            # Acknowledge the task was processed successfully.
            logger.info(f"Successfully processed stale order: {order_id}")
            return https_fn.Response("Order processed successfully", status=200)
        else:
            # A non-2xx response will cause Cloud Tasks to retry the task.
            logger.error(f"Failed to process stale order {order_id}, will be retried.")
            return https_fn.Response("Failed to process order", status=500)

    except Exception as e:
        order_id_hint = (body or {}).get("order_id", "unknown")
        logger.critical(f"Unhandled exception in stale_orders_worker for order {order_id_hint}: {e}")
        sentry_sdk.capture_exception(e)
        # Return 500 to signal a failure that should be retried by Cloud Tasks.
        return https_fn.Response("Internal Server Error", status=500)


def _process_one_stale_order(order_id: str) -> bool:
    """
    The core logic to expire a single order.
    Returns True on success, False on failure.
    """
    order_ref = get_db().collection(Collections.ORDERS).document(order_id)

    # We need the original order_data for Stripe PI and email
    order_doc = order_ref.get()
    if not order_doc.exists:
        logger.warning(f"Order {order_id} not found, cannot expire.")
        return True # Return True to not retry a non-existent order.

    order_data = order_doc.to_dict()

    # Transactionally update the order to EXPIRED
    @get_firestore().transactional
    def try_expire_order(transaction):
        """Function try_expire_order."""
        fresh_doc = order_ref.get(transaction=transaction)
        if not fresh_doc.exists:
            return "not_found", False, [], None
        fresh_data = fresh_doc.to_dict()
        current_status = fresh_data.get(Fields.ORDER_STATUS)
        fresh_payment_status = fresh_data.get(Fields.PAYMENT_STATUS)

        if fresh_payment_status in [PaymentStatusValues.CAPTURING, PaymentStatusValues.CAPTURED]:
            return f"locked_by_capture:{fresh_payment_status}", False, [], None

        if current_status not in [OrderStatusValues.PENDING, OrderStatusValues.CONFIRMED]:
            # Allow retry of stock restoration for already-expired orders whose batch failed.
            # On a failed stock-restore run, the order is EXPIRED but STOCK_RESTORED=False.
            if current_status == OrderStatusValues.EXPIRED and not fresh_data.get(Fields.STOCK_RESTORED, False):
                return "expired_needs_stock", False, fresh_data.get(Fields.ITEMS, []), fresh_data.get(Fields.PAYMENT_STATUS)
            return f"invalid_status:{current_status}", False, [], None

        stock_already_restored = fresh_data.get(Fields.STOCK_RESTORED, False)
        new_payment_status = (
            PaymentStatusValues.AUTHORIZATION_EXPIRED
            if fresh_payment_status == PaymentStatusValues.AUTHORIZED
            else PaymentStatusValues.SESSION_EXPIRED
        )
        transaction.update(
            order_ref,
            {
                Fields.ORDER_STATUS: OrderStatusValues.EXPIRED,
                Fields.PAYMENT_STATUS: new_payment_status,
                Fields.UPDATED_AT: get_server_timestamp(),
            },
        )
        return "locked", stock_already_restored, fresh_data.get(Fields.ITEMS, []), fresh_payment_status

    try:
        expire_result, stock_already_restored, fresh_items, prev_payment_status = try_expire_order(get_db().transaction())
        if expire_result not in ("locked", "expired_needs_stock"):
            logger.info(f"Order {order_id} cannot be expired: {expire_result}")
            return True # Not an error, just skipping. Acknowledge task.
    except (google_exceptions.GoogleAPICallError, google_exceptions.RetryError) as e:
        logger.warning(f"Failed to lock order {order_id} for expiry: {e}")
        return False # This is a transient error, return False to retry.

    # If the logic above passed, we have a lock and can proceed.

    # Cancel Stripe authorization if it existed (skip if this is a stock-restore retry)
    if expire_result != "expired_needs_stock" and prev_payment_status == PaymentStatusValues.AUTHORIZED:
        pi_id = order_data.get(Fields.STRIPE_PAYMENT_INTENT_ID)
        if pi_id:
            try:
                logger.info(f"Cancelling stale authorization for order {order_id} (PI: {pi_id})")
                stripe.PaymentIntent.cancel(pi_id, idempotency_key=f"cancel_auth_{order_id}")
            except stripe.error.StripeError as cancel_err:
                logger.warning(f"Failed to cancel Stripe PI {pi_id} for expired order {order_id}: {cancel_err}")
                # This is not a critical failure, we can continue. The auth will expire on its own.

    # Restore stock if it hasn't been restored already
    stock_restored_ok = stock_already_restored
    if not stock_already_restored:
        stock_batch = get_db().batch()
        for item in fresh_items:
            product_id = item.get(Fields.PRODUCT_ID)
            if not product_id:
                continue
            product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
            qty = item[Fields.QUANTITY]
            stock_patch = {Fields.STOCK_QUANTITY: get_firestore().Increment(qty)}
            fulfillment_wh = item.get(Fields.FULFILLMENT_WAREHOUSE_ID, "")
            if fulfillment_wh:
                stock_patch[f"{Fields.WAREHOUSE_STOCK}.{fulfillment_wh}"] = get_firestore().Increment(qty)
            stock_batch.update(product_ref, stock_patch)
            if fulfillment_wh:
                inv_ref = product_ref.collection(Collections.INVENTORY_LEVELS).document(fulfillment_wh)
                stock_batch.set(inv_ref, {
                    Fields.AVAILABLE_QUANTITY: get_firestore().Increment(qty),
                    Fields.LAST_SYNCED_AT: get_server_timestamp(),
                }, merge=True)
        try:
            stock_batch.commit()
            stock_restored_ok = True
        except Exception as e:
            logger.error(f"Failed to restore stock batch for order {order_id}: {e}")
            sentry_sdk.capture_exception(e)
            stock_restored_ok = False # Will cause the final update to not set STOCK_RESTORED

    # Final update to the order document
    update_fields = {
        Fields.EXPIRES_AT: get_server_timestamp(),
        Fields.UPDATED_AT: get_server_timestamp(),
    }
    if stock_restored_ok:
        update_fields[Fields.STOCK_RESTORED] = True
    order_ref.update(update_fields)

    # Send notification email
    if prev_payment_status == PaymentStatusValues.AUTHORIZED:
        try:
            from services.email_service import send_authorization_expired_email
            lang = order_data.get(Fields.PREFERRED_LANGUAGE, "en")
            send_authorization_expired_email(order_id, order_data, lang=lang)
        except Exception as email_err:
            logger.warning(f"Failed to send authorization expired email for order {order_id}: {email_err}")

    # Return False if stock restoration failed — Cloud Tasks will retry.
    # All other outcomes (success, already-restored, email errors) return True.
    return stock_restored_ok
