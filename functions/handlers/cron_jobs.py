"""
Scheduled Cron Jobs
- Auto-capture confirmed receipts (daily)
- Check expired authorizations (daily)
- Monitor Algolia sync (every 15 min)
- Cleanup stale rate limits (every 30 min)
- Archive old orders (every 12 hours)
"""

import json
import logging
import os
from datetime import UTC, datetime, timedelta

import sentry_sdk
import stripe
from firebase_functions import scheduler_fn
from google.api_core import exceptions as google_exceptions
from google.cloud import tasks_v2

from config import (
    BACKUP_BUCKET,
    BASE_URL,
    IS_EMULATOR,
    PLATFORM_FEE_RATIO,
    PROJECT_ID,
    get_stripe_secret_key,
)

# GCP project + region: set automatically by Cloud Functions runtime
_GCP_PROJECT_ID: str = os.environ.get("GOOGLE_CLOUD_PROJECT", "")
_GCP_REGION: str = "northamerica-northeast1"
from schema_constants import (
    AlgoliaActionValues,
    BusinessRules,
    Collections,
    CronLockStatusValues,
    DeliveryStatusValues,
    EmailConfig,
    Fields,
    OrderEventTypes,
    OrderStatusValues,
    PaymentStatusValues,
    PayoutStatusValues,
    ProductLifecycleStatusValues,
    ReturnStatusValues,
    SecurityAlertTypes,
    SeverityLevels,
    SubscriptionStatusValues,
    UserRoleValues,
)
from utils.db import get_db, get_firestore, get_server_timestamp
from utils.function_options import CRON_OPTIONS

# M1: Use environment-aware BASE_URL from config instead of hardcoded prod URL
APP_BASE_URL = BASE_URL

logger = logging.getLogger(__name__)

# stripe.api_key = STRIPE_SECRET_KEY  # Removed global assignment to prevent deploy crash


def acquire_cron_lock(job_name: str, ttl_minutes: int = 30) -> bool:
    """
    Distributed lock using Firestore document.
    Prevents concurrent execution of cron jobs across Cloud Function instances.

    Returns True if lock acquired, False if another instance is running.
    """
    lock_ref = get_db().collection(Collections.CRON_LOCKS).document(job_name)
    now = datetime.now(UTC)
    cutoff = now - timedelta(minutes=ttl_minutes)

    @get_firestore().transactional
    def _try_acquire(transaction):
        doc = lock_ref.get(transaction=transaction)
        if doc.exists:
            lock_data = doc.to_dict()
            locked_at = lock_data.get(Fields.LOCKED_AT)
            if locked_at:
                if hasattr(locked_at, "tzinfo") and locked_at.tzinfo is None:
                    locked_at = locked_at.replace(tzinfo=UTC)
                if locked_at > cutoff:
                    return False  # Lock is still held by another instance
        transaction.set(
            lock_ref,
            {
                Fields.LOCKED_AT: now,
                Fields.LOCKED_BY: f"cron_{job_name}",
                Fields.STATUS: CronLockStatusValues.RUNNING,
            },
        )
        return True

    try:
        return _try_acquire(get_db().transaction())
    except Exception as e:
        logger.warning(f"⚠️ Failed to acquire cron lock for {job_name}: {type(e).__name__}")
        return False


def release_cron_lock(job_name: str) -> None:
    """Release a distributed cron lock."""
    try:
        get_db().collection(Collections.CRON_LOCKS).document(job_name).update(
            {
                Fields.STATUS: CronLockStatusValues.COMPLETED,
                Fields.COMPLETED_AT: datetime.now(UTC),
            }
        )
    except Exception as e:
        logger.warning(f"⚠️ Failed to release cron lock for {job_name}: {type(e).__name__}")


def _alert_cron_failure(job_name: str, exc: Exception) -> None:
    """M-14: Write an alert record to CRON_FAILURES and capture to Sentry on unhandled cron exception."""
    logger.error(f"CRON FAILURE [{job_name}]: {type(exc).__name__}: {exc}")
    sentry_sdk.capture_exception(exc)
    try:
        get_db().collection(Collections.CRON_FAILURES).add(
            {
                Fields.JOB_NAME: job_name,
                Fields.ERROR_TYPE: type(exc).__name__,
                Fields.ERROR_MESSAGE: str(exc)[:2000],
                Fields.CREATED_AT: datetime.now(UTC),
            }
        )
    except Exception as write_err:
        logger.warning(f"⚠️ Failed to write cron failure record for {job_name}: {type(write_err).__name__}")


# H3: Use cron expression for precise scheduling instead of 'every 24 hours'
@scheduler_fn.on_schedule(schedule="0 1 * * *", **CRON_OPTIONS)
def auto_capture_confirmed_receipts(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Auto-payout for delivered orders (payment already captured at checkout).

    Runs: Daily at 01:00 UTC

    Flow (post-automatic-capture migration):
    - Payment is captured immediately at Stripe Checkout — no manual capture needed.
    - This cron creates Transfers (payouts) to sellers for DELIVERED orders
      that have been delivered for AUTO_CONFIRM_DAYS without dispute.
    - Also auto-confirms SHIPPED orders after AUTO_CONFIRM_DAYS if buyer
      doesn't manually confirm receipt (marks as DELIVERED for payout).
    """
    logger.info("Running auto_capture_confirmed_receipts cron job (auto-payout mode)")

    # SECURITY FIX #16: Distributed lock prevents concurrent execution
    if not acquire_cron_lock("auto_capture_confirmed_receipts"):
        logger.info("auto_capture_confirmed_receipts: Lock held by another instance, skipping")
        return

    try:
        # Initialize Stripe key locally
        stripe.api_key = get_stripe_secret_key()
        _run_auto_capture()
    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("auto_capture_confirmed_receipts", exc)
    finally:
        release_cron_lock("auto_capture_confirmed_receipts")


def _run_auto_capture() -> None:
    """Inner implementation of auto-capture (extracted for lock management)."""

    # Check if Stripe is enabled before processing
    from handlers.payment_providers import PaymentProvider, is_provider_enabled

    if not is_provider_enabled(PaymentProvider.STRIPE):
        logger.info("Stripe payments are disabled, skipping auto-payout")
        return

    cutoff_date = datetime.now(UTC) - timedelta(days=BusinessRules.AUTO_CONFIRM_DAYS)

    # Query DELIVERED orders with captured payment that haven't been paid out yet
    # Also query SHIPPED orders past cutoff for auto-confirmation
    all_orders = []

    # DELIVERED orders ready for payout (payoutStatus not yet completed)
    # AUDIT FIX (CRITICAL-001): Include AUTHORIZED payments for auto-capture
    delivered_orders = (
        get_db()
        .collection(Collections.ORDERS)
        .where(Fields.ORDER_STATUS, "==", OrderStatusValues.DELIVERED)
        .where(Fields.PAYMENT_STATUS, "in", [PaymentStatusValues.CAPTURED, PaymentStatusValues.AUTHORIZED])
        # NOTE: Requires composite Firestore index on orderStatus + deliveredAt
        .where(Fields.DELIVERED_AT, "<=", cutoff_date)
        .limit(250)
        .stream()
    )
    all_orders.extend(delivered_orders)

    # SHIPPED orders past cutoff — auto-confirm as delivered for payout
    # AUDIT FIX (CRITICAL-001): Include AUTHORIZED payments for auto-capture
    shipped_orders = (
        get_db()
        .collection(Collections.ORDERS)
        .where(Fields.ORDER_STATUS, "==", OrderStatusValues.SHIPPED)
        .where(Fields.PAYMENT_STATUS, "in", [PaymentStatusValues.CAPTURED, PaymentStatusValues.AUTHORIZED])
        .where(Fields.SHIPPED_AT, "<=", cutoff_date)
        .limit(250)
        .stream()
    )
    all_orders.extend(shipped_orders)

    payout_count = 0
    failed_count = 0

    for order_doc in all_orders:
        try:
            order_data = order_doc.to_dict()
            order_id = order_doc.id
            payment_intent_id = order_data.get(Fields.STRIPE_PAYMENT_INTENT_ID)

            if not payment_intent_id:
                logger.info(f"Order {order_id} has no payment intent, skipping")
                continue

            # CRITICAL FIX (CRITICAL-001): Capture payment if it's only authorized
            if order_data.get(Fields.PAYMENT_STATUS) == PaymentStatusValues.AUTHORIZED:
                # Add transaction lock to prevent race with cancel (C-8 fix)
                @get_firestore().transactional
                def lock_for_auto_capture(transaction, order_ref=order_doc.reference):
                    """Function lock_for_auto_capture."""
                    fresh = order_ref.get(transaction=transaction)
                    if not fresh.exists or fresh.to_dict().get(Fields.PAYMENT_STATUS) != PaymentStatusValues.AUTHORIZED:
                        return False
                    transaction.update(order_ref, {
                        Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURING,
                        Fields.UPDATED_AT: get_server_timestamp()
                    })
                    return True

                try:
                    if not lock_for_auto_capture(get_db().transaction()):
                        logger.info(f"Order {order_id} cannot be auto-captured: payment status changed")
                        continue
                except Exception as e:
                    logger.warning(f"Failed to lock order {order_id} for auto-capture: {e}")
                    continue

                try:
                    # Emulator mode: skip real Stripe capture for fake payment intents
                    if IS_EMULATOR and not payment_intent_id.startswith("pi_3"):
                        order_doc.reference.update(
                            {
                                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                                # M2: Use server timestamps consistently, even in emulator
                                Fields.CAPTURED_AT: get_server_timestamp(),
                                Fields.UPDATED_AT: get_server_timestamp(),
                            }
                        )
                        order_data[Fields.PAYMENT_STATUS] = PaymentStatusValues.CAPTURED
                    else:
                        # 1. Fetch PI status
                        pi = stripe.PaymentIntent.retrieve(payment_intent_id)
                        if pi.status == "requires_capture":
                            # 2. Capture the funds
                            logger.info(f"Auto-capturing funds for order {order_id} (PI: {payment_intent_id})")
                            pi = stripe.PaymentIntent.capture(
                                payment_intent_id, idempotency_key=f"auto_capture_{order_id}_{payment_intent_id}"
                            )

                        # 3. Update Firestore status immediately
                        if pi.status in ["succeeded", "processing"]:
                            order_doc.reference.update(
                                {
                                    Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                                    Fields.CAPTURED_AT: get_server_timestamp(),
                                    Fields.UPDATED_AT: get_server_timestamp(),
                                }
                            )
                            # Refresh order_data for the rest of the loop
                            order_data[Fields.PAYMENT_STATUS] = PaymentStatusValues.CAPTURED
                            logger.info(f"Successfully auto-captured order {order_id}")
                        else:
                            logger.warning(
                                f"⚠️ Auto-capture for order {order_id} resulted in unexpected PI status: {pi.status}"
                            )
                            continue
                except (
                    stripe.error.StripeError,
                    google_exceptions.GoogleAPICallError,
                    google_exceptions.RetryError,
                    ValueError,
                    TypeError,
                    RuntimeError,
                ) as capture_err:
                    logger.error(f"Error during auto-capture for order {order_id}: {capture_err}")
                    sentry_sdk.capture_exception(capture_err)
                    # Revert lock on failure
                    order_doc.reference.update({
                        Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                        Fields.UPDATED_AT: get_server_timestamp()
                    })
                    continue

            # Skip orders that already have completed payouts
            payout_status = order_data.get(Fields.PAYOUT_STATUS)
            if payout_status == PayoutStatusValues.COMPLETED:
                continue

            # AUDIT FIX (HIGH-024): Check for active disputes before auto-payout.
            try:
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
                    logger.warning(f"⚠️ Order {order_id} has active dispute, skipping auto-payout")
                    continue
            except (
                google_exceptions.GoogleAPICallError,
                google_exceptions.RetryError,
                ValueError,
                TypeError,
                RuntimeError,
            ) as e:
                logger.warning(f"⚠️ Failed to check disputes for order {order_id}: {str(e)}, skipping for safety")
                continue

            # M-7 FIX: Check for active return requests before auto-payout/auto-confirm.
            try:
                active_returns = (
                    get_db()
                    .collection(Collections.RETURN_REQUESTS)
                    .where(Fields.ORDER_ID, "==", order_id)
                    .where(Fields.STATUS, "in", [
                        ReturnStatusValues.REQUESTED,
                        ReturnStatusValues.APPROVED,
                        ReturnStatusValues.LABEL_ISSUED,
                        ReturnStatusValues.RECEIVED,
                        ReturnStatusValues.ESCALATED
                    ])
                    .limit(1)
                    .get()
                )
                if len(active_returns) > 0:
                    logger.warning(f"⚠️ Order {order_id} has active return request, skipping auto-confirm/payout")
                    continue
            except (
                google_exceptions.GoogleAPICallError,
                google_exceptions.RetryError,
                ValueError,
                TypeError,
                RuntimeError,
            ) as e:
                logger.warning(f"⚠️ Failed to check return requests for order {order_id}: {str(e)}, skipping for safety")
                continue

            # FIX S23: Verify actual delivery/ship time before payout.
            items = order_data.get(Fields.ITEMS, [])
            latest_event_time = None
            for item in items:
                ts = item.get(Fields.DELIVERED_AT) or item.get(Fields.SHIPPED_AT)
                if ts:
                    if isinstance(ts, str):
                        try:
                            ts = datetime.fromisoformat(ts)
                        except ValueError:
                            continue
                    if latest_event_time is None or ts > latest_event_time:
                        latest_event_time = ts

            if latest_event_time and latest_event_time > cutoff_date:
                logger.info(f"Order {order_id} item-level timestamp too recent ({latest_event_time}), skipping")
                continue

            # Auto-confirm SHIPPED orders as DELIVERED after cutoff (transactional to prevent race conditions)
            if order_data.get(Fields.ORDER_STATUS) == OrderStatusValues.SHIPPED:
                _confirm_now = datetime.now(UTC)

                @get_firestore().transactional
                def _try_auto_confirm(transaction, _doc=order_doc, _now=_confirm_now):
                    fresh = _doc.reference.get(transaction=transaction)
                    if not fresh.exists:
                        return None
                    fresh_data = fresh.to_dict()
                    if fresh_data.get(Fields.ORDER_STATUS) != OrderStatusValues.SHIPPED:
                        return None  # already confirmed by a concurrent cron run
                    items = fresh_data.get(Fields.ITEMS, [])
                    for item in items:
                        if item.get(Fields.STATUS) == DeliveryStatusValues.SHIPPED:
                            item[Fields.STATUS] = DeliveryStatusValues.DELIVERED
                            item[Fields.DELIVERED_AT] = _now
                            item[Fields.CONFIRMED_AT] = _now  # Stamp confirmation time
                    transaction.update(
                        _doc.reference,
                        {
                            Fields.ITEMS: items,
                            Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                            Fields.AUTO_CONFIRMED: True,
                            # C2: Add DELIVERED_AT and CONFIRMED_AT for auto-confirmed orders
                            Fields.DELIVERED_AT: get_server_timestamp(),
                            Fields.CONFIRMED_AT: get_server_timestamp(),
                            Fields.UPDATED_AT: get_server_timestamp(),
                        },
                    )
                    return items

                try:
                    confirmed_items = _try_auto_confirm(get_db().transaction())
                except (
                    google_exceptions.GoogleAPICallError,
                    google_exceptions.RetryError,
                    ValueError,
                    TypeError,
                    RuntimeError,
                ) as e:
                    logger.error(f"Failed to auto-confirm order {order_id}: {e}")
                    continue

                if confirmed_items is None:
                    logger.info(f"Order {order_id} skipped auto-confirm (already processed)")
                    continue

                order_data[Fields.ORDER_STATUS] = OrderStatusValues.DELIVERED
                # C2: Sync local items with confirmed items from transaction
                # Without this, the payout loop reads stale SHIPPED status and produces zero payout
                order_data[Fields.ITEMS] = confirmed_items
                from models.order_event import OrderEvent
                OrderEvent.write(
                    get_db(), order_id, OrderEventTypes.AUTO_CONFIRMED,
                    actor="system", actor_type="system",
                    from_status=OrderStatusValues.SHIPPED, to_status=OrderStatusValues.DELIVERED,
                )
                logger.info(f"Auto-confirmed order {order_id} as delivered (was shipped, {BusinessRules.AUTO_CONFIRM_DAYS}+ days)")

            try:
                # Payment is already captured — just mark payout in progress
                order_doc.reference.update(
                    {
                        Fields.PAYOUT_STATUS: PayoutStatusValues.PROCESSING,
                        Fields.UPDATED_AT: get_server_timestamp(),
                    }
                )

                # Create payouts ONLY for sellers whose items are DELIVERED
                # SECURITY FIX: Removed PENDING fallback — only pay for confirmed deliveries
                items = order_data.get(Fields.ITEMS, [])
                sellers_total_cents = {}
                for item in items:
                    item_status = item.get(Fields.STATUS, DeliveryStatusValues.PENDING)
                    if item_status == DeliveryStatusValues.DELIVERED:
                        seller_id = item[Fields.SELLER_ID]
                        item_price_cents = round(item.get(Fields.PRICE, 0) * 100)  # price is dollar float → convert to cents
                        item_total_cents = item_price_cents * item[Fields.QUANTITY]
                        sellers_total_cents[seller_id] = sellers_total_cents.get(seller_id, 0) + item_total_cents

                # AUDIT FIX (CRITICAL-001): Use stored fee rate from checkout, not current config
                stored_fee_rate = order_data.get(Fields.PLATFORM_FEE_RATIO, PLATFORM_FEE_RATIO)

                expected_seller_count = len(sellers_total_cents)
                current_order_success_count = 0  # Track successful transfers for this order

                # F-80: Batch-read all sellers for this order in two round-trips instead of 2N
                seller_ids_for_order = list(sellers_total_cents.keys())
                user_refs = [get_db().collection(Collections.USERS).document(sid) for sid in seller_ids_for_order]
                sp_refs = [get_db().collection(Collections.SELLER_PROFILES).document(sid) for sid in seller_ids_for_order]
                user_docs_batch = {doc.id: doc for doc in get_db().get_all(user_refs)} if user_refs else {}
                sp_docs_batch = {doc.id: doc for doc in get_db().get_all(sp_refs)} if sp_refs else {}

                # M-12 FIX: Retrieve the PaymentIntent once per order (outside seller loop)
                # to avoid redundant Stripe API calls when an order has multiple sellers.
                from utils.helpers import get_charge_id_from_pi as _get_charge_id_from_pi
                _order_charge_id: str | None = None
                try:
                    _pi = stripe.PaymentIntent.retrieve(payment_intent_id)
                    _order_charge_id = _get_charge_id_from_pi(_pi)
                except stripe.error.StripeError as _pi_err:
                    logger.error(f"Failed to retrieve charge for PI {payment_intent_id}: {str(_pi_err)}")

                for seller_id, amount_cents in sellers_total_cents.items():
                    platform_fee_cents = round(amount_cents * stored_fee_rate)
                    net_amount_cents = amount_cents - platform_fee_cents

                    # Use snapshot of seller's Stripe account from time of checkout.
                    # Prevents "Account Swap" attack where seller changes account after order.
                    seller_stripe_accounts = order_data.get(Fields.SELLER_STRIPE_ACCOUNTS, {})
                    stripe_account_id = seller_stripe_accounts.get(seller_id)

                    # Use batch-read results for suspension and charges check
                    seller_doc = user_docs_batch.get(seller_id)

                    if seller_doc and seller_doc.exists:
                        seller_data = seller_doc.to_dict()

                        # Fallback to current seller_profiles if snapshot missing
                        if not stripe_account_id:
                            sp_fallback = sp_docs_batch.get(seller_id)
                            stripe_account_id = (sp_fallback.to_dict() or {}).get(Fields.STRIPE_ACCOUNT_ID) if sp_fallback and sp_fallback.exists else None
                            if stripe_account_id:
                                logger.warning(f"⚠️ Using current Stripe account for seller {seller_id} (snapshot missing)")

                        # SECURITY FIX: Check chargesEnabled (not payoutsEnabled) for consistency
                        # with capture_payment. Also check seller is not suspended.
                        seller_suspended = seller_data.get(Fields.SUSPENDED, False)
                        sp_doc = sp_docs_batch.get(seller_id)
                        seller_charges_ok = (sp_doc.to_dict() or {}).get(Fields.CHARGES_ENABLED, False) if sp_doc and sp_doc.exists else False

                        if seller_suspended:
                            logger.warning(f"⚠️ Skipping auto-payout to suspended seller {seller_id} for order {order_id}")
                            order_doc.reference.update(
                                {
                                    Fields.REQUIRES_MANUAL_REVIEW: True,
                                    Fields.MANUAL_REVIEW_REASON: f"Seller {seller_id} suspended at auto-capture",
                                }
                            )
                            continue

                        if stripe_account_id and seller_charges_ok:
                            try:
                                # M-12 FIX: Use pre-fetched charge_id (retrieved once above, outside this loop).
                                # Stripe Transfer requires a Charge ID (ch_xxx), not a PaymentIntent ID (pi_xxx).
                                charge_id = _order_charge_id

                                if not charge_id:
                                    logger.warning(
                                        f"⚠️ No charge found for PI {payment_intent_id}, skipping transfer for seller {seller_id}"
                                    )
                                    order_doc.reference.update(
                                        {
                                            Fields.REQUIRES_MANUAL_REVIEW: True,
                                            Fields.MANUAL_REVIEW_REASON: f"No charge ID found for auto-payout to seller {seller_id}",
                                        }
                                    )
                                    continue

                                # Create PENDING payout record BEFORE Stripe transfer (idempotent)
                                existing_payouts = list(
                                    get_db()
                                    .collection(Collections.PAYOUTS)
                                    .where(Fields.ORDER_ID, "==", order_id)
                                    .where(Fields.SELLER_ID, "==", seller_id)
                                    .limit(1)
                                    .get()
                                )
                                if existing_payouts:
                                    payout_ref = existing_payouts[0].reference
                                    existing_status = (existing_payouts[0].to_dict() or {}).get(Fields.STATUS)
                                    if existing_status == PayoutStatusValues.COMPLETED:
                                        logger.info(f"Payout already completed for {order_id}/{seller_id}, skipping")
                                        current_order_success_count += 1
                                        continue
                                else:
                                    doc_id = f"{order_id}_{seller_id}"
                                    payout_ref = get_db().collection(Collections.PAYOUTS).document(doc_id)
                                payout_ref.set(
                                    {
                                        Fields.ORDER_ID: order_id,
                                        Fields.SELLER_ID: seller_id,
                                        Fields.AMOUNT_CENTS: amount_cents,
                                        Fields.PLATFORM_FEE_CENTS: platform_fee_cents,
                                        Fields.NET_AMOUNT_CENTS: net_amount_cents,
                                        Fields.STATUS: PayoutStatusValues.PENDING,
                                        Fields.AUTO_CAPTURED: True,
                                        Fields.CREATED_AT: get_server_timestamp(),
                                    }
                                )

                                transfer = stripe.Transfer.create(
                                    amount=net_amount_cents,
                                    currency=BusinessRules.DEFAULT_CURRENCY,
                                    destination=stripe_account_id,
                                    source_transaction=charge_id,
                                    transfer_group=order_id,
                                    metadata={
                                        Fields.ORDER_ID: order_id,
                                        Fields.SELLER_ID: seller_id,
                                        Fields.AUTO_CAPTURED: True,
                                    },
                                    idempotency_key=f"transfer_{order_id}_{seller_id}",
                                )

                                # Update payout record with transfer details
                                payout_ref.update(
                                    {
                                        Fields.STATUS: PayoutStatusValues.COMPLETED,
                                        Fields.STRIPE_TRANSFER_ID: transfer.id,
                                        Fields.PAYOUT_DATE: get_server_timestamp(),
                                    }
                                )

                                current_order_success_count += 1

                            except stripe.error.StripeError as e:
                                logger.error(f"Payout failed for seller {seller_id}: {str(e)}")

                                # AUDIT FIX: Sanitize Stripe error before storing in Firestore
                                safe_error = f"{type(e).__name__}: {getattr(e, 'code', 'unknown')}"

                                # Update existing payout record to FAILED
                                try:
                                    payout_ref.update(
                                        {
                                            Fields.STATUS: PayoutStatusValues.FAILED,
                                            Fields.FAILURE_REASON: safe_error,
                                        }
                                    )
                                except Exception:
                                    # Fallback: create a new failure record if payout_ref wasn't set
                                    get_db().collection(Collections.PAYOUTS).add(
                                        {
                                            Fields.ORDER_ID: order_id,
                                            Fields.SELLER_ID: seller_id,
                                            Fields.AMOUNT_CENTS: amount_cents,
                                            Fields.PLATFORM_FEE_CENTS: platform_fee_cents,
                                            Fields.NET_AMOUNT_CENTS: net_amount_cents,
                                            Fields.STATUS: PayoutStatusValues.FAILED,
                                            Fields.FAILURE_REASON: safe_error,
                                            Fields.AUTO_CAPTURED: True,
                                            Fields.CREATED_AT: get_server_timestamp(),
                                        }
                                    )

                if current_order_success_count == expected_seller_count and current_order_success_count > 0:
                    payout_count += 1
                    logger.info(f"Auto-payout completed for order {order_id} ({current_order_success_count} transfers)")

                    # Mark order payout as completed so it's not reprocessed next cron run
                    order_doc.reference.update(
                        {
                            Fields.PAYOUT_STATUS: PayoutStatusValues.COMPLETED,
                            Fields.UPDATED_AT: get_server_timestamp(),
                        }
                    )
                elif current_order_success_count > 0:
                    payout_count += 1
                    logger.warning(
                        f"Partial payout for order {order_id} ({current_order_success_count}/{expected_seller_count} transfers)"
                    )
                    order_doc.reference.update(
                        {
                            Fields.PAYOUT_STATUS: PayoutStatusValues.PARTIAL,
                            Fields.REQUIRES_MANUAL_REVIEW: True,
                            Fields.MANUAL_REVIEW_REASON: f"Partial payout: {current_order_success_count}/{expected_seller_count} sellers paid",
                            Fields.UPDATED_AT: get_server_timestamp(),
                        }
                    )
                else:
                    logger.warning(f"No successful payouts for order {order_id}, marking as FAILED")
                    order_doc.reference.update(
                        {
                            Fields.PAYOUT_STATUS: PayoutStatusValues.FAILED,
                            Fields.UPDATED_AT: get_server_timestamp(),
                        }
                    )

            except stripe.error.StripeError as e:
                failed_count += 1
                logger.error(f"Failed to process payout for order {order_id}: {str(e)}")
                sentry_sdk.capture_exception(e)

                order_doc.reference.update(
                    {
                        Fields.PAYOUT_STATUS: PayoutStatusValues.FAILED,
                        Fields.LAST_CAPTURE_ERROR: f"{type(e).__name__}: {getattr(e, 'code', 'unknown')}",
                        Fields.UPDATED_AT: get_server_timestamp(),
                    }
                )

        except Exception as e:
            logger.error(f"Error processing item in batch: {e}")
            sentry_sdk.capture_exception(e)
    logger.info(f"Auto-payout completed: {payout_count} paid out, {failed_count} failed")


@scheduler_fn.on_schedule(schedule="every 1 hours", **CRON_OPTIONS)
def stale_orders_dispatcher(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Dispatches tasks to process stale/expired orders.

    Runs: Every 1 hour

    Logic:
    - Queries for stale PENDING or AUTHORIZED orders older than a cutoff.
    - Creates a Google Cloud Task for each order to be processed by the
      `stale_orders_worker` function.
    - This decouples finding orders from processing them, improving
      scalability and reliability.
    """
    logger.info("Running stale_orders_dispatcher cron job")

    if not acquire_cron_lock("stale_orders_dispatcher"):
        logger.info("stale_orders_dispatcher: Lock held by another instance, skipping")
        return

    try:
        _dispatch_stale_orders()
    except Exception as exc:
        _alert_cron_failure("stale_orders_dispatcher", exc)
    finally:
        release_cron_lock("stale_orders_dispatcher")


def _dispatch_stale_orders() -> None:
    """Queries for stale orders and creates a Cloud Task for each."""
    # Required environment variables (must be set in Firebase Functions deployment config):
    # - STALE_ORDER_WORKER_URL: HTTPS URL of the `stale_orders_worker` Cloud Function.
    # - TASK_HANDLER_SA_EMAIL: Service Account email authorized to invoke the worker.
    # - TASKS_QUEUE_ID: Cloud Tasks queue ID (defaults to 'stale-orders-queue').
    worker_url = os.environ.get("STALE_ORDER_WORKER_URL")
    task_handler_sa_email = os.environ.get("TASK_HANDLER_SA_EMAIL")
    queue_id = os.environ.get("TASKS_QUEUE_ID", "stale-orders-queue")
    
    if not all([worker_url, task_handler_sa_email]):
        logger.critical("Missing environment variables for Cloud Tasks dispatcher.")
        raise ValueError("STALE_ORDER_WORKER_URL and TASK_HANDLER_SA_EMAIL must be set.")


    cutoff_date = datetime.now(UTC) - timedelta(days=BusinessRules.AUTHORIZATION_EXPIRY_DAYS)

    orders = list(
        get_db()
        .collection(Collections.ORDERS)
        .where(
            Fields.PAYMENT_STATUS,
            "in",
            [
                PaymentStatusValues.AWAITING_PAYMENT,
                PaymentStatusValues.SESSION_EXPIRED,
                PaymentStatusValues.AUTHORIZED,
            ],
        )
        .where(Fields.ORDER_STATUS, "in", [OrderStatusValues.PENDING, OrderStatusValues.CONFIRMED])
        .where(Fields.CREATED_AT, "<=", cutoff_date)
        .limit(100)
        .stream()
    )

    if not orders:
        logger.info("No stale orders found to dispatch")
        return

    client = tasks_v2.CloudTasksClient()
    parent = client.queue_path(_GCP_PROJECT_ID, _GCP_REGION, queue_id)
    
    dispatched_count = 0
    for order_doc in orders:
        try:
            order_id = order_doc.id
            payload = {"order_id": order_id}

            task = {
                "http_request": {
                    "http_method": tasks_v2.HttpMethod.POST,
                    "url": worker_url,
                    "headers": {"Content-type": "application/json"},
                    "body": json.dumps(payload).encode(),
                    "oidc_token": {
                        "REDACTED_SECRET_email": task_handler_sa_email,
                        "audience": worker_url,
                    },
                }
            }
            # Use order ID for task name to prevent duplicates if dispatcher runs multiple times
            client.create_task(parent=parent, task=task, task_id=f"expire-{order_id}")
            dispatched_count += 1
        except google_exceptions.AlreadyExists:
             logger.info(f"Task for order {order_id} already exists. Skipping.")
        except Exception as e:
            logger.error(f"Failed to create task for order {order_doc.id}: {e}")
            sentry_sdk.capture_exception(e)

    logger.info(f"Stale order dispatch completed: {dispatched_count} tasks created")

@scheduler_fn.on_schedule(schedule="every 12 hours", **CRON_OPTIONS)
def auto_archive_old_orders(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Archives orders delivered/cancelled 30+ days ago.

    Runs: Every 12 hours

    Logic:
    - Find orders with status=delivered/cancelled
    - Updated 30+ days ago
    - Mark as archived
    """
    logger.info("Running auto_archive_old_orders cron job")

    if not acquire_cron_lock("auto_archive_old_orders"):
        logger.info("auto_archive_old_orders: lock held, skipping")
        return

    try:
        cutoff_date = datetime.now(UTC) - timedelta(days=BusinessRules.ARCHIVE_AFTER_DAYS)

        # Limit to 200 orders per run and use batch
        # NOTE: We cannot filter 'archived == False' because Firestore doesn't match
        # documents where the field doesn't exist. Instead, we query without the filter
        # and skip already-archived orders in the loop.
        orders = (
            get_db()
            .collection(Collections.ORDERS)
            .where(
                Fields.ORDER_STATUS,
                "in",
                [OrderStatusValues.DELIVERED, OrderStatusValues.CANCELLED, OrderStatusValues.EXPIRED, OrderStatusValues.FAILED, OrderStatusValues.DISPUTED]  # FIX (H2): also archive terminal states EXPIRED/FAILED/DISPUTED,
            )
            .where(Fields.UPDATED_AT, "<=", cutoff_date)
            .limit(200)
            .stream()
        )

        archived_count = 0
        batch = get_db().batch()

        for order_doc in orders:
            try:
                if order_doc.to_dict().get(Fields.ARCHIVED, False):
                    continue

                batch.update(
                    order_doc.reference,
                    {
                        Fields.ARCHIVED: True,
                        Fields.ARCHIVED_AT: get_server_timestamp(),
                        Fields.UPDATED_AT: get_server_timestamp(),
                    },
                )
                archived_count += 1

                # Commit every 500 operations
                if archived_count % 500 == 0:
                    batch.commit()
                    batch = get_db().batch()

            except Exception as e:
                logger.error(f"Error processing item in batch: {e}")
                sentry_sdk.capture_exception(e)
        # Commit remaining
        if archived_count % 500 != 0:
            batch.commit()

        logger.info(f"Archive completed: {archived_count} orders archived")
    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("auto_archive_old_orders", exc)
    finally:
        release_cron_lock("auto_archive_old_orders")


@scheduler_fn.on_schedule(schedule="every 15 minutes", **CRON_OPTIONS)
def monitor_algolia_sync(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Monitors Firestore-Algolia sync health.

    Runs: Every 15 minutes

    Logic:
    - Count active products in Firestore
    - Count products in Algolia
    - Alert if mismatch > 5%
    """
    logger.info("Running monitor_algolia_sync cron job")

    try:
        # Count active products in Firestore using count aggregation

        products_query = get_db().collection(Collections.PRODUCTS).where(Fields.LIFECYCLE_STATUS, "==", ProductLifecycleStatusValues.ACTIVE)

        # Use count aggregation (more efficient than streaming)
        count_query = products_query.count()
        firestore_count = count_query.get()[0][0].value

        # Count products in Algolia
        from services.algolia_service import get_index_stats

        algolia_count = get_index_stats()

        # Check for significant mismatch
        if firestore_count == 0:
            logger.info("No products in Firestore")
            return

        # algolia_count=0 means stats unavailable (event loop or credentials issue) — skip alert
        if algolia_count == 0:
            logger.warning("⚠️  Algolia stats unavailable, skipping sync check")
            return

        mismatch_percent = abs(firestore_count - algolia_count) / firestore_count

        if mismatch_percent > BusinessRules.ALGOLIA_SYNC_MISMATCH_THRESHOLD:  # > 5% mismatch
            # Dedup: check for existing unresolved alert of same type before inserting
            existing = (
                get_db()
                .collection(Collections.SECURITY_ALERTS)
                .where(Fields.TYPE, "==", SecurityAlertTypes.ALGOLIA_SYNC_ISSUE)
                .where(Fields.RESOLVED, "==", False)
                .limit(1)
                .get()
            )
            if not existing:
                get_db().collection(Collections.SECURITY_ALERTS).add(
                    {
                        Fields.TYPE: SecurityAlertTypes.ALGOLIA_SYNC_ISSUE,
                        Fields.SEVERITY: SeverityLevels.MEDIUM,
                        Fields.FIRESTORE_COUNT: firestore_count,
                        Fields.ALGOLIA_COUNT: algolia_count,
                        Fields.MISMATCH_PERCENT: mismatch_percent * 100,
                        Fields.TIMESTAMP: get_server_timestamp(),
                        Fields.RESOLVED: False,
                    }
                )

            logger.info(f"ALERT: Algolia sync mismatch: Firestore={firestore_count}, Algolia={algolia_count}")
        else:
            logger.info(f"Algolia sync healthy: Firestore={firestore_count}, Algolia={algolia_count}")

    except Exception as e:
        logger.error(f"Failed to monitor Algolia sync: {str(e)}")
        sentry_sdk.capture_exception(e)


@scheduler_fn.on_schedule(schedule="every 30 minutes", **CRON_OPTIONS)
def cleanup_stale_rate_limits(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Removes rate limit documents older than 1 hour.

    Runs: Every 30 minutes

    Logic:
    - Find rate_limits with last_request > 1 hour ago
    - Delete documents
    """
    logger.info("Running cleanup_stale_rate_limits cron job")

    if not acquire_cron_lock("cleanup_stale_rate_limits", ttl_minutes=35):
        logger.info("cleanup_stale_rate_limits: lock held, skipping")
        return

    try:
        # CRON-H2: 2hr cutoff (not 1hr) so entries at the edge of the 1hr window
        # are never deleted while still potentially active.
        cutoff_time = datetime.now(UTC) - timedelta(hours=2)

        query = get_db().collection(Collections.RATE_LIMITS).where(Fields.LAST_REQUEST, "<=", cutoff_time).limit(500)

        deleted_count = 0
        batch = get_db().batch()

        while True:
            docs = list(query.stream())
            if not docs:
                break

            for doc in docs:
                try:
                    batch.delete(doc.reference)
                    deleted_count += 1

                    # Commit every 500 deletes
                    if deleted_count % 500 == 0:
                        batch.commit()
                        batch = get_db().batch()

                except Exception as e:
                    logger.error(f"Error processing item in batch: {e}")
                    sentry_sdk.capture_exception(e)

            last_doc = docs[-1]
            query = get_db().collection(Collections.RATE_LIMITS).where(Fields.LAST_REQUEST, "<=", cutoff_time).limit(500).start_after(last_doc)
        # Commit remaining
        if deleted_count % 500 != 0:
            batch.commit()

        logger.info(f"Rate limit cleanup completed: {deleted_count} documents deleted")
    except Exception as exc:
        _alert_cron_failure("cleanup_stale_rate_limits", exc)
    finally:
        release_cron_lock("cleanup_stale_rate_limits")


@scheduler_fn.on_schedule(schedule="0 3 * * *", **CRON_OPTIONS)
def cleanup_orphaned_r2_images(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Removes orphaned images from Cloudflare R2 storage.

    Runs: Daily

    Logic:
    - Collect all imageUrls from active products
    - List R2 objects in products/ prefix
    - Delete objects not referenced by any product
    - Safety: Only deletes images older than 24 hours (avoids race with uploads)
    """
    import boto3
    from botocore.config import Config

    from config import R2Config, get_r2_credentials

    logger.info("Running cleanup_orphaned_r2_images cron job")

    if not acquire_cron_lock("cleanup_orphaned_r2_images"):
        logger.info("cleanup_orphaned_r2_images: lock held, skipping")
        return

    try:
        # Collect all image URLs currently referenced by products
        # select() fetches only imageUrls field — avoids reading full product docs
        referenced_keys = set()

        query = get_db().collection(Collections.PRODUCTS).select([Fields.IMAGE_URLS]).limit(500)
        while True:
            docs = list(query.stream())
            if not docs:
                break

            for product_doc in docs:
                try:
                    product_data = product_doc.to_dict()
                    image_urls = product_data.get(Fields.IMAGE_URLS, [])
                    for url in image_urls:
                        # Extract R2 key from CDN URL
                        # URL format: https://cdn.origna.ca/products/uuid.ext
                        if isinstance(url, str) and "/" in url:
                            # Get path after domain
                            path_parts = url.split("/")
                            # Reconstruct key: e.g. "products/uuid.ext" or "dev/products/uuid.ext"
                            for i, part in enumerate(path_parts):
                                if part in ("products", "dev"):
                                    key = "/".join(path_parts[i:])
                                    referenced_keys.add(key)
                                    break
                except Exception as e:
                    logger.error(f"Error processing item in batch: {e}")
                    sentry_sdk.capture_exception(e)

            last_doc = docs[-1]
            query = get_db().collection(Collections.PRODUCTS).select([Fields.IMAGE_URLS]).limit(500).start_after(last_doc)

        logger.info(f"  Found {len(referenced_keys)} referenced image keys")

        # List R2 objects
        r2_creds = get_r2_credentials()
        r2_access_key = r2_creds.get("access_key")
        r2_secret_key = r2_creds.get("secret_key")
        r2_account_id = r2_creds.get("account_id")

        if not all([r2_access_key, r2_secret_key, r2_account_id]):
            logger.warning("  ⚠️ R2 credentials not configured, skipping cleanup")
            return

        s3_client = boto3.client(
            "s3",
            endpoint_url=f"https://{r2_account_id}.r2.cloudflarestorage.com",
            aws_access_key_id=r2_access_key,
            aws_secret_access_key=r2_secret_key,
            config=Config(signature_version="s3v4"),
            region_name="auto",
        )

        bucket_name = R2Config.BUCKET_NAME
        prefix = R2Config.get_image_path("products", "").rsplit("/", 1)[0] + "/"

        # List objects in products/ prefix
        orphaned_keys = []
        continuation_token = None
        cutoff = datetime.now(UTC) - timedelta(hours=24)

        while True:
            list_kwargs = {
                "Bucket": bucket_name,
                "Prefix": prefix,
                "MaxKeys": 1000,
            }
            if continuation_token:
                list_kwargs["ContinuationToken"] = continuation_token

            try:
                response = s3_client.list_objects_v2(**list_kwargs)
            except Exception as e:
                logger.warning(f"  ⚠️ R2 list error: {e}")
                return

            for obj in response.get("Contents", []):
                key = obj["Key"]
                last_modified = obj.get("LastModified")

                # Safety: skip recently uploaded files (race condition with active uploads)
                if last_modified and last_modified > cutoff:
                    continue

                if key not in referenced_keys:
                    orphaned_keys.append(key)

            if not response.get("IsTruncated"):
                break
            continuation_token = response.get("NextContinuationToken")

        logger.info(f"  Found {len(orphaned_keys)} orphaned images to delete")

        # Delete orphaned objects in batches of 100
        deleted_count = 0
        for i in range(0, len(orphaned_keys), 100):
            batch_keys = orphaned_keys[i : i + 100]
            try:
                s3_client.delete_objects(Bucket=bucket_name, Delete={"Objects": [{"Key": k} for k in batch_keys]})
                deleted_count += len(batch_keys)
            except Exception as e:
                logger.warning(f"  ⚠️ R2 delete error for batch {i}: {e}")

        logger.info(f"  R2 orphan cleanup completed: {deleted_count} files deleted")
    except Exception as exc:
        _alert_cron_failure("cleanup_orphaned_r2_images", exc)
    finally:
        release_cron_lock("cleanup_orphaned_r2_images")


@scheduler_fn.on_schedule(schedule="0 4 * * *", **CRON_OPTIONS)
def cleanup_stale_webhook_events(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Removes processed webhook event records older than 7 days.

    Runs: Daily

    Logic:
    - The webhook_events collection stores event IDs for deduplication
    - Old records (>7 days) are no longer needed — Stripe won't replay them
    - Clean up to prevent unbounded collection growth
    """
    logger.info("Running cleanup_stale_webhook_events cron job")

    if not acquire_cron_lock("cleanup_stale_webhook_events"):
        logger.info("cleanup_stale_webhook_events: lock held, skipping")
        return

    try:
        cutoff_time = datetime.now(UTC) - timedelta(days=BusinessRules.WEBHOOK_EVENT_RETENTION_DAYS)

        webhook_docs = (
            get_db().collection(Collections.WEBHOOK_EVENTS).where(Fields.TIMESTAMP, "<=", cutoff_time).limit(500).stream()
        )

        deleted_count = 0
        batch = get_db().batch()

        for doc in webhook_docs:
            try:
                batch.delete(doc.reference)
                deleted_count += 1

                if deleted_count % 500 == 0:
                    batch.commit()
                    batch = get_db().batch()

            except Exception as e:
                logger.error(f"Error processing item in batch: {e}")
                sentry_sdk.capture_exception(e)
        if deleted_count % 500 != 0:
            batch.commit()

        logger.info(f"Webhook event cleanup completed: {deleted_count} documents deleted")
    except Exception as exc:
        _alert_cron_failure("cleanup_stale_webhook_events", exc)
    finally:
        release_cron_lock("cleanup_stale_webhook_events")


@scheduler_fn.on_schedule(schedule="0 5 * * *", **CRON_OPTIONS)
def cleanup_stale_security_alerts(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Archives resolved security alerts older than 90 days.

    Runs: Daily

    Logic:
    - Resolved alerts older than 90 days are deleted to prevent unbounded growth
    - Unresolved alerts are NEVER cleaned up (require manual resolution)
    """
    logger.info("Running cleanup_stale_security_alerts cron job")

    if not acquire_cron_lock("cleanup_stale_security_alerts"):
        logger.info("cleanup_stale_security_alerts: lock held, skipping")
        return

    try:
        cutoff_time = datetime.now(UTC) - timedelta(days=BusinessRules.SECURITY_ALERT_RETENTION_DAYS)

        alert_docs = (
            get_db()
            .collection(Collections.SECURITY_ALERTS)
            .where(Fields.RESOLVED, "==", True)
            .where(Fields.TIMESTAMP, "<=", cutoff_time)
            .limit(500)
            .stream()
        )

        deleted_count = 0
        batch = get_db().batch()

        for doc in alert_docs:
            try:
                batch.delete(doc.reference)
                deleted_count += 1

                if deleted_count % 500 == 0:
                    batch.commit()
                    batch = get_db().batch()

            except Exception as e:
                logger.error(f"Error processing item in batch: {e}")
                sentry_sdk.capture_exception(e)
        if deleted_count % 500 != 0:
            batch.commit()

        logger.info(f"Security alert cleanup completed: {deleted_count} resolved alerts deleted")
    except Exception as exc:
        _alert_cron_failure("cleanup_stale_security_alerts", exc)
    finally:
        release_cron_lock("cleanup_stale_security_alerts")


@scheduler_fn.on_schedule(schedule="every 1 hours", **CRON_OPTIONS)
def retry_failed_algolia_syncs(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Retries failed Algolia sync operations from the Dead Letter Queue.

    Runs: Every hour

    Logic:
    - Reads unresolved entries from algolia_sync_failures collection
    - Retries up to 3 times with exponential backoff tracking
    - Marks as resolved after successful retry or max attempts
    - Prevents unbounded DLQ growth
    """
    logger.info("Running retry_failed_algolia_syncs cron job")

    # FIX (H3): Add distributed lock — prevents concurrent instances from
    # double-retrying the same Algolia operations, causing duplicate index writes.
    if not acquire_cron_lock("retry_failed_algolia_syncs"):
        logger.info("retry_failed_algolia_syncs: already running, skipping")
        return


    try:
        from services.algolia_service import delete_product as algolia_delete_product
        from services.algolia_service import index_product as algolia_index_product

        # Fetch unresolved sync failures (max 50 per run)
        failures = (
            get_db().collection(Collections.ALGOLIA_SYNC_FAILURES).where(Fields.RESOLVED, "==", False).limit(50).stream()
        )

        retried = 0
        resolved = 0
        max_retries = BusinessRules.ALGOLIA_DLQ_MAX_RETRIES

        for failure_doc in failures:
            failure_data = failure_doc.to_dict()
            product_id = failure_data.get(Fields.PRODUCT_ID)
            action = failure_data.get(Fields.ACTION, AlgoliaActionValues.INDEX)
            retry_count = failure_data.get(Fields.RETRY_COUNT, 0)

            if not product_id:
                failure_doc.reference.update({Fields.RESOLVED: True})
                resolved += 1
                continue

            # Max retries exceeded — mark as resolved (needs manual intervention)
            if retry_count >= max_retries:
                failure_doc.reference.update(
                    {
                        Fields.RESOLVED: True,
                        Fields.MAX_RETRIES_EXCEEDED: True,
                        Fields.UPDATED_AT: get_server_timestamp(),
                    }
                )
                resolved += 1
                logger.warning(f"Algolia sync for {product_id} exceeded max retries — marking as resolved")
                continue

            try:
                if action == AlgoliaActionValues.DELETE:
                    algolia_delete_product(product_id)
                else:
                    # Re-fetch product data from Firestore
                    product_doc = get_db().collection(Collections.PRODUCTS).document(product_id).get()
                    if not product_doc.exists:
                        # Product was deleted — try to delete from Algolia instead
                        algolia_delete_product(product_id)
                    else:
                        product_data = product_doc.to_dict()
                        if product_data.get(Fields.LIFECYCLE_STATUS) == ProductLifecycleStatusValues.ACTIVE:
                            algolia_index_product(product_id, product_data)
                        else:
                            algolia_delete_product(product_id)

                # Success — resolve the failure
                failure_doc.reference.update(
                    {
                        Fields.RESOLVED: True,
                        Fields.UPDATED_AT: get_server_timestamp(),
                    }
                )
                resolved += 1
                retried += 1
            except Exception as e:
                # Increment retry count
                failure_doc.reference.update(
                    {
                        Fields.RETRY_COUNT: retry_count + 1,
                        Fields.LAST_RETRY_ERROR: type(e).__name__,
                        Fields.UPDATED_AT: get_server_timestamp(),
                    }
                )
                logger.warning(f"Algolia retry failed for {product_id}: {type(e).__name__}")

        logger.info(f"Algolia DLQ retry completed: {retried} retried, {resolved} resolved")
    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("retry_failed_algolia_syncs", exc)
    finally:
        release_cron_lock("retry_failed_algolia_syncs")  # FIX (H3): always release lock


@scheduler_fn.on_schedule(schedule="every 168 hours", **CRON_OPTIONS)  # weekly
def revalidate_digital_product_urls(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Weekly: HEAD-check all approved digital product download URLs.
    If a URL is unreachable, deactivate the product and notify the seller.
    This catches URLs that go dead after approval.
    """
    import requests

    from handlers.products import _get_seller_email, _send_product_rejection_email

    logger.info("Starting weekly digital product URL revalidation")

    if not acquire_cron_lock("revalidate_digital_product_urls"):
        logger.info("revalidate_digital_product_urls: lock held, skipping")
        return

    try:
        checked = 0
        deactivated = 0

        products = (
            get_db()
            .collection(Collections.PRODUCTS)
            .where(Fields.IS_DIGITAL, "==", True)
            .where(Fields.LIFECYCLE_STATUS, "==", ProductLifecycleStatusValues.ACTIVE)
            .limit(500)
            .stream()
        )

        for doc in products:
            product_data = doc.to_dict() or {}
            product_id = doc.id
            checked += 1

            urls_to_check: list[tuple[str, str]] = []
            book_url = product_data.get(Fields.BOOK_SOURCE_URL)
            if book_url:
                urls_to_check.append(("bookSourceUrl", book_url))
            builds = product_data.get(Fields.DIGITAL_BUILDS) or {}
            for platform, url in builds.items():
                if url:
                    urls_to_check.append((f"digitalBuilds.{platform}", url))

            dead = []
            for label, url in urls_to_check:
                try:
                    resp = requests.head(url, timeout=10, allow_redirects=True, headers={"User-Agent": "OrignaBot/1.0"})
                    if resp.status_code >= 400:
                        dead.append(label)
                except requests.exceptions.RequestException:
                    dead.append(label)

            if dead:
                reason = f"Download URL(s) became unreachable: {', '.join(dead)}"
                doc.reference.update(
                    {
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.UNDER_REVIEW,
                        Fields.APPROVAL_REJECTION_REASON: reason,
                    }
                )
                # Remove from Algolia
                try:
                    from services.algolia_service import delete_product as algolia_delete

                    algolia_delete(product_id)
                except (ImportError, RuntimeError, ValueError) as algolia_err:
                    logger.warning(f"Failed to remove product {product_id} from Algolia after URL revalidation: {algolia_err}")

                # Notify seller
                seller_email = _get_seller_email(product_data.get(Fields.SELLER_ID))
                if seller_email:
                    try:
                        _send_product_rejection_email(seller_email, product_data.get(Fields.NAME, ""), reason)
                    except Exception as e:
                        logger.error(f"Failed to email seller for dead URL on {product_id}: {e}")

                deactivated += 1
                logger.warning(f"Deactivated product {product_id} — dead URLs: {dead}")

        logger.info(f"Digital URL revalidation done: {checked} checked, {deactivated} deactivated")
    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("revalidate_digital_product_urls", exc)
    finally:
        release_cron_lock("revalidate_digital_product_urls")  # CRITICAL FIX (C2): always release lock


@scheduler_fn.on_schedule(schedule="0 6 * * *", **CRON_OPTIONS)
def check_low_stock_alerts(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Daily cron: email sellers when a product's stockQuantity falls at or below
    inventory.lowStockThreshold (only when the seller has opted into alerts).

    Runs: Every 24 hours

    Logic:
    - Only products where isActive=True AND approvalStatus=approved
    - inventory.lowStockThreshold > 0 (seller opted in)
    - inventory.trackQuantity = True (stock tracking is on)
    - stockQuantity <= inventory.lowStockThreshold
    - lastLowStockAlertAt is None OR > 23 hours ago (avoid daily spam)
    """
    from services.email_task import enqueue_email_task

    logger.info("Running check_low_stock_alerts cron job")

    # FIX (H3): Add distributed lock — prevents concurrent instances from
    # sending duplicate low-stock emails to sellers.
    if not acquire_cron_lock("check_low_stock_alerts"):
        logger.info("check_low_stock_alerts: already running, skipping")
        return

    try:
        alerted_count = 0
        checked_count = 0

        # Fetch active + approved products
        query = (
            get_db()
            .collection(Collections.PRODUCTS)
            .where(Fields.LIFECYCLE_STATUS, "==", ProductLifecycleStatusValues.ACTIVE)
            .limit(1000)
        )

        now_utc = datetime.now(UTC)
        alert_cooldown = timedelta(hours=23)

        # First pass: collect products needing alerts and unique seller IDs
        products_needing_alert = []
        unique_seller_ids: set = set()

        for doc in query.stream():
            checked_count += 1
            data = doc.to_dict() or {}

            inventory = data.get(Fields.INVENTORY) or {}
            threshold = inventory.get(Fields.LOW_STOCK_THRESHOLD, 0)
            track_quantity = inventory.get(Fields.TRACK_QUANTITY, True)

            # Skip if seller hasn't opted in (threshold=0) or tracking is disabled
            if not threshold or not track_quantity:
                continue

            stock = data.get(Fields.STOCK_QUANTITY, 0)
            if stock > threshold:
                continue

            # Check cooldown — don't re-alert within 23 hours
            last_alert = data.get(Fields.LAST_LOW_STOCK_ALERT_AT)
            if last_alert:
                if hasattr(last_alert, "tzinfo") and last_alert.tzinfo is None:
                    last_alert = last_alert.replace(tzinfo=UTC)
                elif not hasattr(last_alert, "tzinfo"):
                    last_alert = None
            if last_alert and (now_utc - last_alert) < alert_cooldown:
                continue

            seller_id = data.get(Fields.SELLER_ID)
            if not seller_id:
                continue

            products_needing_alert.append((doc, data, stock, threshold))
            unique_seller_ids.add(seller_id)

        # Batch-read all seller docs to avoid N+1
        seller_data_map: dict = {}
        if unique_seller_ids:
            seller_refs = [get_db().collection(Collections.USERS).document(sid) for sid in unique_seller_ids]
            for seller_snap in get_db().get_all(seller_refs):
                if seller_snap.exists:
                    seller_data_map[seller_snap.id] = seller_snap.to_dict() or {}

        # Second pass: send low stock alert emails
        for doc, data, stock, threshold in products_needing_alert:
            seller_id = data.get(Fields.SELLER_ID)
            seller_info = seller_data_map.get(seller_id)
            if not seller_info:
                continue

            seller_email = seller_info.get(Fields.EMAIL)
            if not seller_email:
                continue

            # CASL / Quebec Law 25: skip seller if they have not consented to emails
            if not seller_info.get(Fields.EMAIL_CONSENT):
                logger.info(f"Low stock alert skipped for seller {seller_id}: no emailConsent")
                continue

            product_name = data.get(Fields.NAME, "Your product")
            subject = f"[Origna] Low stock alert: {product_name}"
            from services.email_service import _get_signed_unsubscribe_url, UNSUBSCRIBE_URL
            unsub_url = _get_signed_unsubscribe_url(seller_email) if seller_email else UNSUBSCRIBE_URL
            html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #E53E3E;">⚠️ Low Stock Alert</h2>
      <p>Your product <strong>{product_name}</strong> is running low on stock.</p>
      <table style="width:100%; border-collapse:collapse; margin: 16px 0;">
        <tr><td style="padding:6px 0; color:#666; width:160px;">Current stock</td>
            <td style="font-weight:bold; color:#E53E3E;">{stock} unit{"s" if stock != 1 else ""} remaining</td></tr>
        <tr><td style="padding:6px 0; color:#666;">Alert threshold</td>
            <td>{threshold} units</td></tr>
        <tr><td style="padding:6px 0; color:#666;">Product ID</td>
            <td><code style="font-size:12px;">{doc.id}</code></td></tr>
      </table>
      <p>Please restock soon to avoid missing sales.</p>
      <p style="margin-top:20px;">
        <a href="https://orignagta.ca/seller/products" style="background:#5B30F6; color:#fff; padding:10px 22px; border-radius:6px; text-decoration:none; font-weight:bold;">
          Manage Inventory
        </a>
      </p>
      <p style="color:#999; font-size:12px; margin-top:20px;">
        You are receiving this because you enabled low stock alerts for this product.<br>
        To disable, edit the product and uncheck "Notify me when stock falls below threshold".<br>
        Origna Ventures Inc. — {EmailConfig.PHYSICAL_ADDRESS}<br>
        <a href="{unsub_url}" style="color:#667EEA;">Unsubscribe from seller notifications</a>
      </p>
    </div>"""

            try:
                enqueue_email_task(
                    to_email=seller_email,
                    subject=subject,
                    html_content=html,
                    event_type="low_stock_alert",
                    id_params={"product_id": doc.id}
                )
                get_db().collection(Collections.PRODUCTS).document(doc.id).update({Fields.LAST_LOW_STOCK_ALERT_AT: now_utc})
                alerted_count += 1
                logger.info(f"Low stock alert sent for product {doc.id} (stock={stock}, threshold={threshold})")
            except Exception as e:
                logger.error(f"Failed to send low stock alert for {doc.id}: {e}")

        logger.info(f"check_low_stock_alerts done: {checked_count} checked, {alerted_count} alerted")
    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("check_low_stock_alerts", exc)
    finally:
        release_cron_lock("check_low_stock_alerts")  # FIX (H3): always release lock


@scheduler_fn.on_schedule(schedule="0 7 * * *", **CRON_OPTIONS)
def send_abandoned_cart_emails(event: scheduler_fn.ScheduledEvent) -> None:
    """
    TASK 10 — Daily cron: email buyers who have items in cart but haven't checked out.

    Logic:
    - Only users with marketingOptIn=True (CASL compliance)
    - lastCheckoutTimestamp is None OR > 24h ago
    - User has at least one active product in their cart subcollection
    - lastCartAbandonEmailAt is None OR > 72h ago (3-day cooldown)
    - Skip users whose cart items are all deactivated/deleted
    """
    from services.email_task import enqueue_email_task

    logger.info("Running send_abandoned_cart_emails cron job")

    if not acquire_cron_lock("send_abandoned_cart_emails"):
        logger.info("send_abandoned_cart_emails: already running, skipping")
        return

    try:
        now_utc = datetime.now(UTC)
        cooldown_cutoff = now_utc - timedelta(hours=72)
        checkout_cutoff = now_utc - timedelta(hours=24)
        sent_count = 0
        skipped_count = 0

        # Fetch users who opted into marketing and haven't been emailed in 3 days
        users_query = get_db().collection(Collections.USERS).where(Fields.MARKETING_OPT_IN, "==", True).limit(500)

        for user_doc in users_query.stream():
            user_data = user_doc.to_dict() or {}
            user_id = user_doc.id
            user_email = user_data.get(Fields.EMAIL)

            if not user_email:
                continue

            # CASL / Quebec Law 25: skip users who have not consented to emails
            if not user_data.get(Fields.EMAIL_CONSENT):
                skipped_count += 1
                continue

            # 3-day cooldown check
            last_abandon_email = user_data.get(Fields.LAST_CART_ABANDON_EMAIL_AT)
            if last_abandon_email:
                if hasattr(last_abandon_email, "tzinfo") and last_abandon_email.tzinfo is None:
                    last_abandon_email = last_abandon_email.replace(tzinfo=UTC)
                if last_abandon_email > cooldown_cutoff:
                    skipped_count += 1
                    continue

            # Skip if checked out recently (< 24h ago)
            last_checkout = user_data.get(Fields.LAST_CHECKOUT_TIMESTAMP)
            if last_checkout:
                if hasattr(last_checkout, "tzinfo") and last_checkout.tzinfo is None:
                    last_checkout = last_checkout.replace(tzinfo=UTC)
                if last_checkout > checkout_cutoff:
                    skipped_count += 1
                    continue

            # Check cart subcollection
            cart_items = list(
                get_db().collection(Collections.USERS).document(user_id).collection(Collections.CART).limit(10).stream()
            )

            if not cart_items:
                continue

            # Verify at least one cart item is still active — batch fetch all product docs
            active_product_names: list[str] = []
            product_ids = [
                (cart_doc.to_dict() or {}).get(Fields.PRODUCT_ID) or cart_doc.id
                for cart_doc in cart_items
            ]
            product_refs = [get_db().collection(Collections.PRODUCTS).document(pid) for pid in product_ids]
            product_docs = get_db().get_all(product_refs)
            for product_doc in product_docs:
                if product_doc.exists:
                    pd = product_doc.to_dict() or {}
                    if pd.get(Fields.LIFECYCLE_STATUS) == ProductLifecycleStatusValues.ACTIVE and pd.get(Fields.STOCK_QUANTITY, 0) > 0:
                        active_product_names.append(pd.get(Fields.NAME, "an item"))
                if len(active_product_names) >= 3:
                    break

            if not active_product_names:
                skipped_count += 1
                continue

            # Build simple abandoned cart email
            product_list_html = "".join(f"<li>{name}</li>" for name in active_product_names)
            more_label = (
                f" (and {len(cart_items) - len(active_product_names)} more)"
                if len(cart_items) > len(active_product_names)
                else ""
            )
            from services.email_service import APP_BASE_URL, _email_wrapper

            display_name = user_data.get(Fields.NAME) or "there"
            lang = user_data.get(Fields.PREFERRED_LANGUAGE, "en")

            if lang == "fr":
                subject = "Votre panier vous attend — Origna"
                content_html = f"""
                <tr><td style="padding: 32px 40px 24px 40px;">
                  <h2 style="color: #1a1a2e; margin-top: 0; font-size: 20px;">Votre panier vous attend 🛒</h2>
                  <p style="color: #555; font-size: 15px;">Bonjour {display_name},</p>
                  <p style="color: #555; font-size: 15px;">Vous avez des articles dans votre panier qui sont encore disponibles :</p>
                  <ul style="margin:16px 0; padding-left:24px; color: #1a1a2e; font-weight: 500; line-height: 1.6;">
                    {product_list_html}
                  </ul>
                  {f'<p style="color:#888; font-size:13px; font-style: italic;">{more_label}</p>' if more_label else ""}
                  <div style="margin-top:32px; text-align: center;">
                    <a href="{APP_BASE_URL}/cart" style="background: linear-gradient(135deg, #667EEA, #764BA2); color:#fff; padding:12px 28px; border-radius:8px; text-decoration:none; font-weight:700; display: inline-block;">
                      Compléter mon achat
                    </a>
                  </div>
                </td></tr>
                """
                title = "Votre panier vous attend"
            else:
                subject = "You left something in your cart — Origna"
                content_html = f"""
                <tr><td style="padding: 32px 40px 24px 40px;">
                  <h2 style="color: #1a1a2e; margin-top: 0; font-size: 20px;">Your cart is waiting 🛒</h2>
                  <p style="color: #555; font-size: 15px;">Hi {display_name},</p>
                  <p style="color: #555; font-size: 15px;">You have items in your cart that are still available:</p>
                  <ul style="margin:16px 0; padding-left:24px; color: #1a1a2e; font-weight: 500; line-height: 1.6;">
                    {product_list_html}
                  </ul>
                  {f'<p style="color:#888; font-size:13px; font-style: italic;">{more_label}</p>' if more_label else ""}
                  <div style="margin-top:32px; text-align: center;">
                    <a href="{APP_BASE_URL}/cart" style="background: linear-gradient(135deg, #667EEA, #764BA2); color:#fff; padding:12px 28px; border-radius:8px; text-decoration:none; font-weight:700; display: inline-block;">
                      Complete your purchase
                    </a>
                  </div>
                </td></tr>
                """
                title = "Your cart is waiting"

            html = _email_wrapper(
                title=title,
                content=content_html,
                include_gst=False,
                lang=lang,
                recipient_email=user_email
            )

            try:
                enqueue_email_task(
                    to_email=user_email,
                    subject=subject,
                    html_content=html,
                    event_type="abandoned_cart",
                    user_id=user_id
                )
                get_db().collection(Collections.USERS).document(user_id).update(
                    {Fields.LAST_CART_ABANDON_EMAIL_AT: now_utc}
                )
                sent_count += 1
            except Exception as e:
                logger.error(f"Failed to send abandoned cart email to user {user_id}: {e}")

        logger.info(f"send_abandoned_cart_emails done: {sent_count} sent, {skipped_count} skipped")
    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("send_abandoned_cart_emails", exc)
    finally:
        release_cron_lock("send_abandoned_cart_emails")


def _compute_avg_response_time(seller_id: str, window_start: object) -> float:
    """
    Compute average first-reply time (hours) for a seller over the given window.

    Reads chat threads where the seller replied (firstSellerReplyAt >= window_start)
    and averages the pre-computed firstReplyHours field set by send_message.

    Returns 0.0 if the seller has no replied threads in the window.
    """
    try:
        chats = (
            get_db()
            .collection(Collections.CHATS)
            .where(Fields.SELLER_ID, "==", seller_id)
            .where(Fields.FIRST_SELLER_REPLY_AT, ">=", window_start)
            .limit(200)
            .stream()
        )
        hours_list = []
        for cd in chats:
            val = cd.to_dict().get(Fields.FIRST_REPLY_HOURS)
            if isinstance(val, (int, float)):
                hours_list.append(val)
        return round(sum(hours_list) / len(hours_list), 4) if hours_list else 0.0
    except Exception as e:
        logger.warning(f"_compute_avg_response_time failed for seller {seller_id}: {e}")
        return 0.0


@scheduler_fn.on_schedule(schedule="every 168 hours", **CRON_OPTIONS)  # weekly
def compute_seller_metrics(event: scheduler_fn.ScheduledEvent) -> None:
    """
    TASK 11 — Weekly cron: compute seller health metrics and raise security alerts for threshold breaches.

    H-9 FIX: Bulk fetch orders and chats to eliminate N+1 query vulnerability.
    """
    logger.info("Running compute_seller_metrics cron job")

    if not acquire_cron_lock("compute_seller_metrics"):
        logger.info("compute_seller_metrics: already running, skipping")
        return

    try:
        _compute_seller_metrics_logic()
    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("compute_seller_metrics", exc)
    finally:
        release_cron_lock("compute_seller_metrics")


def _compute_seller_metrics_logic() -> None:
    """Internal logic for compute_seller_metrics to facilitate testing."""
    from schema_constants import SecurityAlertTypes, SeverityLevels

    now_utc = datetime.now(UTC)
    try:
        window_start = now_utc - timedelta(days=BusinessRules.SELLER_METRICS_WINDOW_DAYS)
        DISPUTE_THRESHOLD = BusinessRules.SELLER_DISPUTE_RATE_THRESHOLD
        REFUND_THRESHOLD = BusinessRules.SELLER_REFUND_RATE_THRESHOLD
        CANCEL_THRESHOLD = BusinessRules.SELLER_CANCEL_RATE_THRESHOLD

        db = get_db()
        # 1. Fetch all orders from the window (Bulk, paginated)
        # AUDIT FIX (CRITICAL-performance): Add limit to prevent unbounded reads at scale.
        # 2000 orders/run is sufficient for daily metrics (cron runs daily).
        orders_ref = db.collection(Collections.ORDERS).where(Fields.CREATED_AT, ">=", window_start).limit(2000)
        orders_stream = orders_ref.stream()

        # Aggregate data by seller
        # seller_data[seller_id] = { ...metrics... }
        seller_stats = {}

        def _get_seller_entry(sid):
            if sid not in seller_stats:
                seller_stats[sid] = {
                    "total_orders": 0,
                    "disputed_orders": 0,
                    "total_seller_items": 0,
                    "refunded_items": 0,
                    "cancelled_items": 0,
                    "late_shipped_items": 0,
                    "total_revenue_cents": 0,
                }
            return seller_stats[sid]

        for order_doc in orders_stream:
            od = order_doc.to_dict() or {}
            order_seller_ids = od.get(Fields.SELLER_IDS, [])
            has_dispute = od.get(Fields.HAS_DISPUTE, False)
            order_status = od.get(Fields.ORDER_STATUS)
            items = od.get(Fields.ITEMS, [])
            created_at = od.get(Fields.CREATED_AT)
            if created_at and hasattr(created_at, "tzinfo") and created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=UTC)

            # Update per-seller order counts and disputes
            for sid in order_seller_ids:
                stats = _get_seller_entry(sid)
                stats["total_orders"] += 1
                if has_dispute:
                    stats["disputed_orders"] += 1

            # Update per-item metrics
            for item in items:
                sid = item.get(Fields.SELLER_ID)
                if not sid:
                    continue
                stats = _get_seller_entry(sid)
                stats["total_seller_items"] += 1

                item_status = item.get(Fields.STATUS)
                if item_status == DeliveryStatusValues.REFUNDED:
                    stats["refunded_items"] += 1
                if order_status == OrderStatusValues.CANCELLED:
                    stats["cancelled_items"] += 1

                # Late shipment
                shipped_at = item.get(Fields.SHIPPED_AT)
                est_days = item.get(Fields.ESTIMATED_SHIP_DAYS, 3)
                if shipped_at and created_at:
                    if hasattr(shipped_at, "tzinfo") and shipped_at.tzinfo is None:
                        shipped_at = shipped_at.replace(tzinfo=UTC)
                    if (shipped_at - created_at).days > est_days:
                        stats["late_shipped_items"] += 1

            # Revenue
            payouts = od.get(Fields.SELLER_PAYOUTS) or []
            for payout in payouts:
                sid = payout.get(Fields.SELLER_ID)
                if sid:
                    stats = _get_seller_entry(sid)
                    stats["total_revenue_cents"] += payout.get(Fields.SELLER_AMOUNT_CENTS, 0)

        # 2. Fetch all relevant chats in the window (Bulk)
        # We need FIRST_REPLY_HOURS for chats where FIRST_SELLER_REPLY_AT >= window_start
        chats_ref = db.collection(Collections.CHATS).where(Fields.FIRST_SELLER_REPLY_AT, ">=", window_start).limit(5000)
        chats_stream = chats_ref.stream()

        # seller_chats[seller_id] = [hours1, hours2, ...]
        seller_chats = {}
        for chat_doc in chats_stream:
            cd = chat_doc.to_dict() or {}
            sid = cd.get(Fields.SELLER_ID)
            hours = cd.get(Fields.FIRST_REPLY_HOURS)
            if sid and isinstance(hours, (int, float)):
                if sid not in seller_chats:
                    seller_chats[sid] = []
                seller_chats[sid].append(hours)

        # 3. Process all sellers — paginated to avoid unbounded full-collection stream.
        # Cost fix: was sellers_ref.stream() with no limit, scanning ALL seller users at once.
        sellers_query = (
            db.collection(Collections.USERS)
            .where(Fields.ROLES, "array_contains", UserRoleValues.SELLER)
            .order_by(Fields.CREATED_AT)
            .limit(500)
        )
        processed_count = 0
        alerted_count = 0
        last_seller_doc = None

        while True:
            page_query = sellers_query if last_seller_doc is None else sellers_query.start_after(last_seller_doc)
            seller_page = list(page_query.stream())
            if not seller_page:
                break

            for seller_doc in seller_page:
                seller_id = seller_doc.id
                stats = seller_stats.get(seller_id, {
                    "total_orders": 0,
                    "disputed_orders": 0,
                    "total_seller_items": 0,
                    "refunded_items": 0,
                    "cancelled_items": 0,
                    "late_shipped_items": 0,
                    "total_revenue_cents": 0,
                })

                total_orders = stats["total_orders"]
                total_items = stats["total_seller_items"]

                dispute_rate = stats["disputed_orders"] / total_orders if total_orders > 0 else 0.0
                refund_rate = stats["refunded_items"] / total_items if total_items > 0 else 0.0
                cancel_rate = stats["cancelled_items"] / total_items if total_items > 0 else 0.0
                late_rate = stats["late_shipped_items"] / total_items if total_items > 0 else 0.0

                # Response time from pre-fetched chats
                hours_list = seller_chats.get(seller_id, [])
                avg_response = round(sum(hours_list) / len(hours_list), 4) if hours_list else 0.0

                # Write metrics doc
                db.collection(Collections.SELLER_METRICS).document(seller_id).set({
                    Fields.SELLER_ID: seller_id,
                    Fields.DISPUTE_RATE: round(dispute_rate, 4),
                    Fields.REFUND_RATE: round(refund_rate, 4),
                    Fields.CANCELLATION_RATE: round(cancel_rate, 4),
                    Fields.LATE_SHIPMENT_RATE: round(late_rate, 4),
                    Fields.AVG_RESPONSE_TIME_HOURS: avg_response,
                    Fields.TOTAL_ORDERS_30D: total_orders,
                    Fields.TOTAL_REVENUE_CENTS_30D: stats["total_revenue_cents"],
                    Fields.COMPUTED_AT: now_utc,
                })
                processed_count += 1

                # Check breaches
                breaches = []
                if dispute_rate > DISPUTE_THRESHOLD:
                    breaches.append(f"disputeRate={dispute_rate:.1%}")
                if refund_rate > REFUND_THRESHOLD:
                    breaches.append(f"refundRate={refund_rate:.1%}")
                if cancel_rate > CANCEL_THRESHOLD:
                    breaches.append(f"cancellationRate={cancel_rate:.1%}")

                if breaches:
                    # Deduplicate security alerts
                    existing = db.collection(Collections.SECURITY_ALERTS)\
                        .where(Fields.TYPE, "==", SecurityAlertTypes.SELLER_METRICS_BREACH)\
                        .where(Fields.SELLER_ID, "==", seller_id)\
                        .where(Fields.RESOLVED, "==", False)\
                        .limit(1).get()

                    if not existing:
                        db.collection(Collections.SECURITY_ALERTS).add({
                            Fields.TYPE: SecurityAlertTypes.SELLER_METRICS_BREACH,
                            Fields.SELLER_ID: seller_id,
                            Fields.BREACHES: breaches,
                            Fields.TOTAL_ORDERS: total_orders,
                            Fields.SEVERITY: SeverityLevels.HIGH,
                            Fields.CREATED_AT: now_utc,
                            Fields.RESOLVED: False,
                        })
                        alerted_count += 1
                        logger.warning(f"Seller {seller_id} metrics breach: {', '.join(breaches)}")

            last_seller_doc = seller_page[-1]
            if len(seller_page) < 500:
                break

        logger.info(f"compute_seller_metrics done: {processed_count} sellers processed, {alerted_count} alerts raised")
    except Exception as e:
        # Re-raise so the outer wrapper (_compute_seller_metrics_logic caller) can alert via M-14
        logger.error(f"compute_seller_metrics failed: {e}")
        raise

# ============================================================================
# TRENDING PRODUCTS CRON
# ============================================================================

# FIX (M3): Use BusinessRules constants as single source of truth.
# Previously TRENDING_WINDOW_HOURS=48 here vs BusinessRules.TRENDING_WINDOW_HOURS=24
# caused the window variable to be computed but NEVER USED (noqa: F841 suppressed the warning).
# Now using BusinessRules values throughout.
TRENDING_TOP_N = BusinessRules.TRENDING_TOP_N              # 20 products
TRENDING_WINDOW_HOURS = BusinessRules.TRENDING_WINDOW_HOURS  # 24h rolling window
TRENDING_PURCHASE_WEIGHT = BusinessRules.TRENDING_PURCHASE_WEIGHT  # 3x
TRENDING_FAVORITE_WEIGHT = BusinessRules.TRENDING_FAVORITE_WEIGHT  # 2x


@scheduler_fn.on_schedule(schedule="every 6 hours", **CRON_OPTIONS)
def compute_trending_products(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Compute trending products every 6 hours.
    Score = viewCount + purchaseCount×3 + favoriteCount×2 within last 48h.
    Tags top-20 as isTrending=True, clears old trending flags.
    Sends FCM to premium users with notifyTrending=True.
    """
    db = get_db()
    logger.info("compute_trending_products started")

    if not acquire_cron_lock("compute_trending_products"):
        logger.info("compute_trending_products: already running, skipping")
        return

    try:
        now = datetime.now(UTC)
        window_start = now - timedelta(hours=TRENDING_WINDOW_HOURS)  # FIX (M3): now actually used

        # Fetch all active products
        # FIX (M3): Filter to products updated within the trending window so scoring
        # is based on recent activity, not all-time cumulative counters.
        # This requires a composite Firestore index on (lifecycleStatus, updatedAt).
        products_query = (
            db.collection(Collections.PRODUCTS)
            .where(Fields.LIFECYCLE_STATUS, "==", ProductLifecycleStatusValues.ACTIVE)
            .where(Fields.UPDATED_AT, ">=", window_start)
            .stream()
        )

        scored: list[tuple[int, str, str, str]] = []  # (score, productId, name, imageUrl)
        old_trending_ids: set[str] = set()  # IDs of products currently marked trending (avoids second scan)

        for prod_snap in products_query:
            data = prod_snap.to_dict() or {}
            if data.get(Fields.IS_TRENDING):
                old_trending_ids.add(prod_snap.id)
            view_count = data.get(Fields.VIEW_COUNT, 0) or 0
            purchase_count = data.get(Fields.PURCHASE_COUNT, 0) or 0
            # SRCH-M2: favoriteCount now tracked via toggle_favorite Cloud Function
            favorite_count = data.get(Fields.FAVORITE_COUNT, 0) or 0
            score = (
                view_count
                + (purchase_count * TRENDING_PURCHASE_WEIGHT)
                + (favorite_count * TRENDING_FAVORITE_WEIGHT)
            )
            if score > 0:
                images = data.get(Fields.IMAGE_URLS) or []
                image_url = images[0] if images else None
                scored.append((score, prod_snap.id, data.get(Fields.NAME, ""), image_url))

        # Sort descending and take top N
        scored.sort(key=lambda x: x[0], reverse=True)
        top_ids = {item[1] for item in scored[:TRENDING_TOP_N]}
        top_products = scored[:TRENDING_TOP_N]

        batch = db.batch()
        op_count = 0

        # Mark top-N as trending
        for _score, prod_id, _name, _img in top_products:
            ref = db.collection(Collections.PRODUCTS).document(prod_id)
            batch.update(
                ref,
                {
                    Fields.IS_TRENDING: True,
                    Fields.TRENDING_AT: now,
                    Fields.TRENDING_SCORE: _score,
                },
            )
            op_count += 1
            if op_count % 400 == 0:
                batch.commit()
                batch = db.batch()

        # Clear trending from products that dropped out of top-N
        # Uses IDs collected during the first scan — avoids a second Firestore query
        cleared = 0
        for prod_id in old_trending_ids:
            if prod_id not in top_ids:
                ref = db.collection(Collections.PRODUCTS).document(prod_id)
                batch.update(ref, {Fields.IS_TRENDING: False})
                cleared += 1
                op_count += 1
                if op_count % 400 == 0:
                    batch.commit()
                    batch = db.batch()

        batch.commit()
        logger.info(f"Trending: {len(top_products)} products marked trending, {cleared} cleared")

        # Notify premium users who opted in
        if top_products:
            _notify_trending_products(db, top_products[:5])  # notify about top 5
    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("compute_trending_products", exc)
    finally:
        release_cron_lock("compute_trending_products")


def _notify_trending_products(db, top_products: list[tuple]) -> None:
    """Send FCM push to premium users with notifyTrending=True (max 500)."""
    try:
        from firebase_admin import messaging

        users_query = (
            db.collection(Collections.USERS)
            .where(Fields.IS_PREMIUM, "==", True)
            .where(Fields.NOTIFY_TRENDING, "==", True)
            .limit(500)
            .stream()
        )

        tokens = []
        for user in users_query:
            # Cost fix: limit FCM tokens per user to avoid unbounded subcollection reads
            token_docs = user.reference.collection(Collections.FCM_TOKENS).limit(10).stream()
            for td in token_docs:
                t = (td.to_dict() or {}).get("token")
                if t:
                    tokens.append(t)

        if not tokens:
            return

        names = ", ".join(item[2] for item in top_products[:3])
        msg = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(
                title="🔥 Trending Now on Origna",
                body=f"{names} and more are trending right now!",
            ),
            data={"type": "trending", "screen": "/trending"},
        )
        response = messaging.send_each_for_multicast(msg)
        logger.info(f"Trending FCM sent: {response.success_count} ok, {response.failure_count} failed")
    except Exception as e:
        logger.error(f"Failed to send trending FCM: {e}")



@scheduler_fn.on_schedule(schedule="0 8 * * *", **CRON_OPTIONS)
def send_premium_renewal_reminders(event: scheduler_fn.ScheduledEvent) -> None:
    """
    FIX F7-6 — Daily cron: email premium subscribers whose subscription renews in
    exactly 7 days or 1 day, reminding them of the upcoming charge.
    Deduplication: stores a sent-flag in the subscription doc per reminder type.
    """
    if not acquire_cron_lock("send_premium_renewal_reminders"):
        logger.info("send_premium_renewal_reminders: already running, skipping")
        return

    try:
        from datetime import UTC, datetime, timedelta

        from services.email_service import get_premium_renewal_reminder_email
        from services.email_task import enqueue_email_task

        db = get_db()
        now = datetime.now(UTC)

        for days_ahead in (7, 1):
            window_start = now + timedelta(days=days_ahead) - timedelta(hours=12)
            window_end   = now + timedelta(days=days_ahead) + timedelta(hours=12)
            dedup_field  = f"renewalReminderSentDays{days_ahead}"

            query = (
                db.collection(Collections.SUBSCRIPTIONS)
                .where(Fields.CURRENT_PERIOD_END, ">=", window_start)
                .where(Fields.CURRENT_PERIOD_END, "<=", window_end)
                .where(Fields.STATUS, "in", list(SubscriptionStatusValues.PREMIUM_ACTIVE))
                .limit(200)
                .stream()
            )

            sent_count = 0
            for sub_doc in query:
                uid = sub_doc.id
                sub_data = sub_doc.to_dict() or {}

                # Skip if already cancelled at period end
                if sub_data.get(Fields.CANCEL_AT_PERIOD_END):
                    continue

                # Skip users with a cancelled subscription status (defence-in-depth guard)
                if sub_data.get(Fields.STATUS) == SubscriptionStatusValues.CANCELED:
                    continue

                # Dedup: skip if reminder already sent for this renewal cycle
                if sub_data.get(dedup_field):
                    continue

                try:
                    user_doc = db.collection(Collections.USERS).document(uid).get()
                    if not user_doc.exists:
                        continue
                    user_data = user_doc.to_dict() or {}
                    recipient_email = user_data.get(Fields.EMAIL)
                    lang = user_data.get(Fields.PREFERRED_LANGUAGE, "en")
                    period_end = sub_data.get(Fields.CURRENT_PERIOD_END)

                    if not recipient_email:
                        continue

                    html_body = get_premium_renewal_reminder_email(
                        user_data, period_end=period_end, days_remaining=days_ahead, lang=lang
                    )
                    subj_en = f"Your Origna Premium Renews in {days_ahead} Day{'s' if days_ahead > 1 else ''}"
                    subj_fr = f"Votre Origna Premium se renouvelle dans {days_ahead} jour{'s' if days_ahead > 1 else ''}"
                    subject = subj_fr if lang == "fr" else subj_en

                    enqueue_email_task(
                        to_email=recipient_email,
                        subject=subject,
                        html_content=html_body,
                        event_type="premium_renewal_reminder",
                        user_id=uid
                    )

                    # Mark reminder as sent to prevent re-sending in next run
                    db.collection(Collections.SUBSCRIPTIONS).document(uid).update(
                        {dedup_field: True, Fields.UPDATED_AT: now}
                    )
                    sent_count += 1
                except Exception as e:
                    logger.error(f"send_premium_renewal_reminders: failed for uid={uid}: {e}")

            logger.info(f"send_premium_renewal_reminders: {days_ahead}d window — {sent_count} emails sent")

    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("send_premium_renewal_reminders", exc)
    finally:
        release_cron_lock("send_premium_renewal_reminders")


@scheduler_fn.on_schedule(schedule="0 */6 * * *", **CRON_OPTIONS)
def sync_expired_subscriptions(event: scheduler_fn.ScheduledEvent) -> None:
    """Every 6 hours: detect and fix subscription-user cache mismatches. Catches missed webhooks."""
    if not acquire_cron_lock("sync_expired_subscriptions"):
        logger.info("sync_expired_subscriptions: already running, skipping")
        return

    try:
        import stripe as stripe_lib

        from handlers.subscriptions import _sync_subscription

        stripe_lib.api_key = get_stripe_secret_key()
        db = get_db()
        now = datetime.now(UTC)
        synced_count = 0
        error_count = 0

        # Fix subscriptions that should be expired but user.isPremium is still True
        expired_query = (
            db.collection(Collections.SUBSCRIPTIONS)
            .where(Fields.CURRENT_PERIOD_END, "<", now)
            .where(Fields.STATUS, "in", list(SubscriptionStatusValues.PREMIUM_ACTIVE))
            .limit(50)
            .stream()
        )
        for sub_doc in expired_query:
            uid = sub_doc.id
            sub_data = sub_doc.to_dict() or {}
            stripe_sub_id = sub_data.get(Fields.STRIPE_SUBSCRIPTION_ID)
            if not stripe_sub_id:
                continue
            try:
                stripe_sub = stripe_lib.Subscription.retrieve(stripe_sub_id)
                _sync_subscription(stripe_sub)
                synced_count += 1
            except Exception as e:
                logger.error(f"sync_expired_subscriptions: failed for {uid}: {e}")
                sentry_sdk.capture_exception(e)
                error_count += 1

        # Fix orphaned isPremium=True with no subscription doc — paginate through all premium users
        cursor = None
        while True:
            q = db.collection(Collections.USERS).where(Fields.IS_PREMIUM, "==", True).limit(500)
            if cursor is not None:
                q = q.start_after(cursor)
            page = list(q.stream())
            if not page:
                break

            uid_list = [u.id for u in page]
            sub_refs = [db.collection(Collections.SUBSCRIPTIONS).document(uid) for uid in uid_list]
            sub_docs = db.get_all(sub_refs)
            sub_exists = {doc.id: doc.exists for doc in sub_docs}

            chunk_batch = db.batch()
            chunk_orphan_count = 0

            for uid in uid_list:
                if not sub_exists.get(uid, False):
                    logger.warning(f"Clearing orphaned isPremium for user {uid}")
                    chunk_batch.update(
                        db.collection(Collections.USERS).document(uid),
                        {
                            Fields.IS_PREMIUM: False,
                            Fields.PREMIUM_EXPIRES_AT: None,
                            Fields.STRIPE_SUBSCRIPTION_ID: None,
                            Fields.PREMIUM_SINCE: None,
                            Fields.UPDATED_AT: now,
                        },
                    )
                    chunk_orphan_count += 1
                    synced_count += 1

            if chunk_orphan_count > 0:
                chunk_batch.commit()

            cursor = page[-1]
            if len(page) < 500:
                break

        logger.info(f"sync_expired_subscriptions: {synced_count} fixed, {error_count} errors")
    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("sync_expired_subscriptions", exc)
    finally:
        release_cron_lock("sync_expired_subscriptions")


@scheduler_fn.on_schedule(schedule="0 9 * * *", **CRON_OPTIONS)
def escalate_stale_return_requests(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Cron: Escalates return requests that have been in 'requested' status for
    more than _RETURN_ESCALATION_DAYS days without seller action.
    Sets status to 'escalated' and sends push to admins and buyer.
    """
    if not acquire_cron_lock("escalate_stale_return_requests"):
        logger.info("escalate_stale_return_requests: Lock held, skipping")
        return

    try:
        _run_return_escalation()
    except Exception as exc:
        # M-14: Alert on unhandled cron failure
        _alert_cron_failure("escalate_stale_return_requests", exc)
    finally:
        release_cron_lock("escalate_stale_return_requests")


def _run_return_escalation() -> None:
    from datetime import timedelta

    db = get_db()
    now = datetime.now(UTC)
    cutoff = now - timedelta(days=BusinessRules.RETURN_ESCALATION_DAYS)

    escalated = 0
    errors = 0

    try:
        # Query return requests stuck in 'requested' status past cutoff
        # BUGFIX: return_requests use Fields.REQUESTED_AT ('requestedAt'), not Fields.CREATED_AT ('createdAt')
        stale_returns = (
            db.collection(Collections.RETURN_REQUESTS)
            .where(Fields.RETURN_STATUS, "==", ReturnStatusValues.REQUESTED)
            .where(Fields.REQUESTED_AT, "<", cutoff)
            .limit(200)
            .stream()
        )

        # Pre-fetch admin users once — reused for every escalated return (no N+1 per return)
        try:
            from services.push_service import send_push_notification
            admin_doc_list = list(
                db.collection(Collections.USERS)
                .where(Fields.ROLES, "array_contains", UserRoleValues.ADMIN)
                .limit(10)
                .stream()
            )
        except Exception as prefetch_err:
            logger.warning(f"Failed to pre-fetch admin docs: {prefetch_err}")
            admin_doc_list = []

        for doc in stale_returns:
            return_id = doc.id
            return_data = doc.to_dict() or {}
            order_id = return_data.get(Fields.ORDER_ID, "")
            buyer_id = return_data.get(Fields.BUYER_ID, "")  # return_requests use buyerId not userId

            try:
                doc.reference.update({
                    Fields.RETURN_STATUS: ReturnStatusValues.ESCALATED,
                    Fields.UPDATED_AT: now,
                    Fields.ESCALATED_AT: now,
                    Fields.ESCALATION_REASON: f"No seller response after {BusinessRules.RETURN_ESCALATION_DAYS} days",
                })

                # Notify buyer
                if buyer_id:
                    try:
                        from services.push_service import send_push_notification
                        send_push_notification(
                            buyer_id,
                            "Return Request Escalated",
                            f"Your return for order #{order_id[:8]} has been escalated to our support team",
                            data={"type": "return_request", "orderId": order_id, "returnId": return_id, "status": ReturnStatusValues.ESCALATED},
                        )
                    except Exception as push_err:
                        logger.warning(f"Push to buyer failed for return {return_id}: {push_err}")

                # Notify admins using pre-fetched list (avoids N+1 query per return)
                try:
                    for admin_doc in admin_doc_list:
                        send_push_notification(
                            admin_doc.id,
                            "Return Escalated",
                            f"Return #{return_id[:8]} on order #{order_id[:8]} needs admin review",
                            data={"type": "return_request", "orderId": order_id, "returnId": return_id, "status": ReturnStatusValues.ESCALATED},
                        )
                except Exception as admin_err:
                    logger.warning(f"Admin push failed for return {return_id}: {admin_err}")

                escalated += 1
            except Exception as e:
                logger.error(f"Failed to escalate return {return_id}: {e}")
                sentry_sdk.capture_exception(e)
                errors += 1

    except Exception as e:
        logger.error(f"escalate_stale_return_requests query failed: {e}")
        sentry_sdk.capture_exception(e)
        return

    logger.info(f"escalate_stale_return_requests: escalated={escalated}, errors={errors}")


# ==============================================================================
# FIRESTORE BACKUP — PROD BLOCKER
# Daily export of all Firestore collections to GCS via the Admin API.
# IAM prerequisites (apply once per project via gcloud):
#   gcloud projects add-iam-policy-binding <PROJECT_ID> \
#     --member="serviceAccount:<PROJECT_ID>@appspot.gserviceaccount.com" \
#     --role="roles/datastore.importExportAdmin"
#   gsutil mb -l northamerica-northeast1 -p <PROJECT_ID> gs://<PROJECT_ID>-backups
#   gsutil iam ch \
#     serviceAccount:<PROJECT_ID>@appspot.gserviceaccount.com:objectAdmin \
#     gs://<PROJECT_ID>-backups
# ==============================================================================


@scheduler_fn.on_schedule(schedule="0 2 * * *", **CRON_OPTIONS)  # 2:00 AM UTC daily
def backup_firestore(event: scheduler_fn.ScheduledEvent) -> None:
    """Export all Firestore collections to GCS daily for disaster recovery (PROD BLOCKER)."""
    if IS_EMULATOR:
        logger.info("backup_firestore: skipped in emulator mode")
        return

    if not acquire_cron_lock("backup_firestore", ttl_minutes=60):
        logger.warning("backup_firestore: lock held, skipping")
        return

    try:
        _run_backup_firestore()
    except Exception as e:
        _alert_cron_failure("backup_firestore", e)
        sentry_sdk.capture_exception(e)
    finally:
        release_cron_lock("backup_firestore")


def _run_backup_firestore() -> None:
    """Call the Firestore Admin exportDocuments API to back up all collections to GCS."""
    from google.cloud import firestore_admin_v1

    db_name = f"projects/{PROJECT_ID}/databases/(default)"
    output_uri_prefix = f"{BACKUP_BUCKET}/{datetime.now(UTC).strftime('%Y-%m-%d')}"

    client = firestore_admin_v1.FirestoreAdminClient()
    req = firestore_admin_v1.ExportDocumentsRequest(
        name=db_name,
        output_uri_prefix=output_uri_prefix,
        # Empty collection_ids → exports ALL collections
        collection_ids=[],
    )
    operation = client.export_documents(request=req)
    logger.info(f"backup_firestore: export started → {output_uri_prefix} (operation={operation.operation.name})")
