"""
Premium Subscription Handlers
- Create Stripe subscription ($7.86 CAD/month)
- Cancel subscription (at period end)
- Get subscription status
- Webhook event processing (called from payment_stripe.py)
"""

import logging
from datetime import UTC, datetime
from typing import Any

import stripe
from firebase_admin import firestore as _fs
from firebase_functions import https_fn

from config import (
    get_stripe_premium_price_id,
    get_stripe_secret_key,
)
from schema_constants import (
    Collections,
    Fields,
    SubscriptionStatusValues,
    UserRoleValues,
)
from utils.db import get_db as _get_db
from utils.db import get_firestore as _get_firestore
from utils.db import get_server_timestamp as _get_server_timestamp
from utils.function_options import DEFAULT_OPTIONS


def _fetch_user_for_email(uid: str) -> dict:
    """Fetch user doc fields needed for email sending (email, name, language)."""
    try:
        doc = _get_db().collection(Collections.USERS).document(uid).get()
        if doc.exists:
            return doc.to_dict() or {}
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"_fetch_user_for_email: failed for {uid}: {e}")
    return {}

logger = logging.getLogger(__name__)

# Cache Stripe key at module level to avoid Secret Manager reads on every handler call
_STRIPE_KEY_CACHE: str | None = None


def _stripe_init() -> None:
    global _STRIPE_KEY_CACHE
    if not _STRIPE_KEY_CACHE:
        _STRIPE_KEY_CACHE = get_stripe_secret_key()
    stripe.api_key = _STRIPE_KEY_CACHE


def _get_or_create_stripe_customer(uid: str, user_snap) -> str:
    """Get existing Stripe customer ID or create a new one for the user."""
    _stripe_init()
    if not user_snap.exists:
        raise https_fn.HttpsError("not-found", "User profile not found.")
    user_data = user_snap.to_dict() or {}
    customer_id = user_data.get(Fields.CUSTOMER_ID)
    if customer_id:
        return customer_id

    customer = stripe.Customer.create(
        email=user_data.get(Fields.EMAIL, ""),
        name=user_data.get(Fields.NAME, ""),
        metadata={"uid": uid},
    )
    _get_db().collection(Collections.USERS).document(uid).update({Fields.CUSTOMER_ID: customer.id})
    return customer.id


@https_fn.on_call(**DEFAULT_OPTIONS)
def create_subscription(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Create a premium subscription for the authenticated buyer.
    - Creates or reuses a Stripe Customer
    - Returns a Stripe Checkout Session URL (subscription mode)
    - On successful payment, webhook syncs subscription status to Firestore
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    # MEDIUM-021 FIX: Use a more dynamic idempotency key to allow retries after session expiry
    # or cancellation, but still protect against double-clicks within a short window.
    # We use a 15-minute window for idempotency.
    uid = req.auth.uid
    idempotency_window = int(datetime.now(UTC).timestamp() // 900)
    idempotency_key = f"premium_sub_{uid}_{idempotency_window}"

    user_ref = _get_db().collection(Collections.USERS).document(uid)
    user_snap = user_ref.get()

    if not user_snap.exists:
        raise https_fn.HttpsError("not-found", "User profile not found.")

    user_data = user_snap.to_dict() or {}
    roles = user_data.get(Fields.ROLES, [])

    # MEDIUM FIX: Block sellers from subscribing — premium is for buyers only.
    # Sellers already have distinct business features and shouldn't pay buyer fees.
    if UserRoleValues.SELLER in roles:
        raise https_fn.HttpsError("failed-precondition", "Seller accounts cannot currently subscribe to Premium. This feature is for buyers only.")

    # Check already subscribed — block all non-terminal statuses to prevent double-subscriptions
    _NON_SUBSCRIBABLE = frozenset({
        SubscriptionStatusValues.ACTIVE,
        SubscriptionStatusValues.TRIALING,
        SubscriptionStatusValues.PAST_DUE,
        SubscriptionStatusValues.INCOMPLETE,
    })
    sub_snap = _get_db().collection(Collections.SUBSCRIPTIONS).document(uid).get()
    if sub_snap.exists:
        sub_data = sub_snap.to_dict() or {}
        status = sub_data.get(Fields.STATUS, "")
        if status in _NON_SUBSCRIBABLE:
            raise https_fn.HttpsError("already-exists", "You already have a subscription. Manage it from the subscription page.")

    price_id = get_stripe_premium_price_id()
    if not price_id:
        raise https_fn.HttpsError("internal", "Premium subscription is not configured yet. Please try again later.")

    _stripe_init()

    from config import BASE_URL

    customer_id = _get_or_create_stripe_customer(uid, user_snap)

    try:
        session = stripe.checkout.Session.create(
            customer=customer_id,
            line_items=[{"price": price_id, "quantity": 1}],
            mode="subscription",
            success_url=f"{BASE_URL}/subscription/success?session_id={{CHECKOUT_SESSION_ID}}",
            cancel_url=f"{BASE_URL}/subscription/cancel",
            client_reference_id=uid,
            metadata={"uid": uid},
            subscription_data={"metadata": {"uid": uid}},
            # Explicit payment_method_types disables Stripe Link (type: 'link').
            # Apple Pay and Google Pay work transparently via 'card' type.
            payment_method_types=["card"],
            idempotency_key=idempotency_key,
        )
        # Cache session URL so we can recover it on IdempotencyError
        user_ref.update({
            Fields.LAST_CHECKOUT_SESSION: session.url,
            Fields.LAST_CHECKOUT_TIMESTAMP: datetime.now(UTC),
        })
        return {"success": True, "checkoutUrl": session.url, "sessionId": session.id}
    except stripe.error.IdempotencyError as e:
        # Double-tap or retry — return cached session URL to surface existing checkout
        logger.info(f"Idempotency hit for premium subscription {uid}: {e}")
        cached_url = (user_ref.get().to_dict() or {}).get(Fields.LAST_CHECKOUT_SESSION)
        if cached_url:
            return {"success": True, "checkoutUrl": cached_url}
        raise https_fn.HttpsError("already-exists", "A checkout session is already in progress. Please try again in a moment.") from e
    except stripe.StripeError as e:
        logger.error(f"Stripe error creating subscription for {uid}: {e}")
        raise https_fn.HttpsError("internal", "Failed to create subscription. Please try again.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def cancel_subscription(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Cancel the premium subscription at end of current billing period.
    The user retains premium benefits until premiumExpiresAt.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    uid = req.auth.uid
    sub_snap = _get_db().collection(Collections.SUBSCRIPTIONS).document(uid).get()
    if not sub_snap.exists:
        raise https_fn.HttpsError("not-found", "No active subscription found.")

    sub_data = sub_snap.to_dict() or {}
    stripe_sub_id = sub_data.get(Fields.STRIPE_SUBSCRIPTION_ID)
    if not stripe_sub_id:
        raise https_fn.HttpsError("not-found", "Subscription ID not found.")

    status = sub_data.get(Fields.STATUS, "")
    # past_due users must also be allowed to cancel — they are stuck in a failed payment
    # loop and have the right to stop their subscription immediately.
    cancellable_statuses = SubscriptionStatusValues.PREMIUM_ACTIVE | {SubscriptionStatusValues.PAST_DUE}
    if status not in cancellable_statuses:
        raise https_fn.HttpsError("failed-precondition", "Subscription is not active.")

    if sub_data.get(Fields.CANCEL_AT_PERIOD_END):
        raise https_fn.HttpsError("failed-precondition", "Subscription is already scheduled to cancel.")

    _stripe_init()
    try:
        stripe.Subscription.modify(stripe_sub_id, cancel_at_period_end=True)
        _get_db().collection(Collections.SUBSCRIPTIONS).document(uid).update(
            {
                Fields.CANCEL_AT_PERIOD_END: True,
                Fields.CANCEL_SCHEDULED_AT: _get_server_timestamp(),
                Fields.UPDATED_AT: _get_server_timestamp(),
            }
        )
        # FIX F7-4: Send cancellation confirmation email
        try:
            user_data = _fetch_user_for_email(uid)
            lang = user_data.get("preferredLanguage", "en")
            recipient_email = user_data.get("email")
            if recipient_email:
                sub_snap2 = _get_db().collection("subscriptions").document(uid).get()
                period_end = (sub_snap2.to_dict() or {}).get("currentPeriodEnd") if sub_snap2.exists else None
                from services.email_service import get_premium_cancellation_email
                from services.email_task import enqueue_email_task

                html_body = get_premium_cancellation_email(user_data, period_end=period_end, lang=lang)
                subj = "Subscription Cancellation Confirmed" if lang == "en" else "Annulation d'abonnement confirmée"
                enqueue_email_task(
                    to_email=recipient_email,
                    subject=subj,
                    html_content=html_body,
                    event_type="premium_cancellation",
                    user_id=uid
                )
                logger.info(f"Premium cancellation email sent to {recipient_email} (uid={uid})")
        except Exception as _e:
            logger.error(f"cancel_subscription: failed to send cancellation email: {_e}")
        return {"success": True, "message": "Subscription will cancel at end of billing period."}
    except stripe.StripeError as e:
        logger.error(f"Stripe error canceling subscription for {uid}: {e}")
        raise https_fn.HttpsError("internal", "Failed to cancel subscription. Please try again.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def reactivate_subscription(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Reactivate a subscription that was scheduled to cancel at period end.
    Calls stripe.Subscription.modify to set cancel_at_period_end=False.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    uid = req.auth.uid
    sub_snap = _get_db().collection(Collections.SUBSCRIPTIONS).document(uid).get()
    if not sub_snap.exists:
        raise https_fn.HttpsError("not-found", "No subscription found.")

    sub_data = sub_snap.to_dict() or {}
    if not sub_data.get(Fields.CANCEL_AT_PERIOD_END):
        raise https_fn.HttpsError("failed-precondition", "Subscription is not scheduled to cancel.")

    stripe_sub_id = sub_data.get(Fields.STRIPE_SUBSCRIPTION_ID)
    if not stripe_sub_id:
        raise https_fn.HttpsError("not-found", "Subscription ID not found.")

    _stripe_init()
    try:
        updated_stripe_sub = stripe.Subscription.modify(stripe_sub_id, cancel_at_period_end=False)
        _sync_subscription(updated_stripe_sub)
        return {"success": True, "message": "Subscription reactivated."}
    except stripe.StripeError as e:
        logger.error(f"Stripe error reactivating subscription for {uid}: {e}")
        raise https_fn.HttpsError("internal", "Failed to reactivate subscription. Please try again.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_subscription_status(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Return the current premium subscription status for the authenticated user."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    uid = req.auth.uid
    sub_snap = _get_db().collection(Collections.SUBSCRIPTIONS).document(uid).get()
    if not sub_snap.exists:
        return {"isPremium": False, "status": None, "premiumExpiresAt": None}

    sub_data = sub_snap.to_dict() or {}
    stripe_sub_id = sub_data.get(Fields.STRIPE_SUBSCRIPTION_ID)
    period_end = sub_data.get(Fields.CURRENT_PERIOD_END)

    # Self-heal: if period_end is missing but we have a Stripe sub ID, re-sync from Stripe
    if not period_end and stripe_sub_id:
        try:
            _stripe_init()
            live_sub = stripe.Subscription.retrieve(stripe_sub_id)
            _sync_subscription(live_sub)
            sub_snap = _get_db().collection(Collections.SUBSCRIPTIONS).document(uid).get()
            sub_data = sub_snap.to_dict() or {}
            period_end = sub_data.get(Fields.CURRENT_PERIOD_END)
        except Exception as e:
            logger.warning(f"get_subscription_status: failed to re-sync sub {stripe_sub_id}: {e}")

    status = sub_data.get(Fields.STATUS)
    is_premium = status in SubscriptionStatusValues.PREMIUM_ACTIVE

    return {
        "isPremium": is_premium,
        "status": status,
        "premiumExpiresAt": period_end.isoformat() if period_end else None,
        "cancelAtPeriodEnd": sub_data.get(Fields.CANCEL_AT_PERIOD_END, False),
    }


# ============================================================================
# WEBHOOK HANDLERS — called by payment_stripe.py webhook dispatcher
# ============================================================================


def handle_subscription_created(event: stripe.Event | dict) -> None:
    """Sync subscription.created → Firestore + send welcome email."""
    # SECURITY FIX (CRITICAL-021): Use dict access to prevent AttributeError when
    # called with manual dict objects (e.g. from invoice.paid path).
    obj = event["data"]["object"] if isinstance(event, dict) else event.data.object
    _sync_subscription(obj)

    # FIX F7-2: Send premium welcome email on new subscription
    try:
        uid = obj.get("metadata", {}).get("uid") if isinstance(obj, dict) else (obj.metadata or {}).get("uid")
        if uid:
            period_end_ts = obj.get("current_period_end") if isinstance(obj, dict) else getattr(obj, "current_period_end", None)
            period_end = _ts_to_datetime(period_end_ts)
            user_data = _fetch_user_for_email(uid)
            lang = user_data.get("preferredLanguage", "en")
            recipient_email = user_data.get("email")
            if recipient_email:
                from services.email_service import get_premium_welcome_email
                from services.email_task import enqueue_email_task

                html_body = get_premium_welcome_email(user_data, period_end=period_end, lang=lang)
                subj = "Welcome to Origna Premium! 🌟" if lang == "en" else "Bienvenue dans Origna Premium ! 🌟"
                enqueue_email_task(
                    to_email=recipient_email,
                    subject=subj,
                    html_content=html_body,
                    event_type="premium_welcome",
                    user_id=uid
                )
                logger.info(f"Premium welcome email sent to {recipient_email} (uid={uid})")
    except Exception as _e:
        logger.error(f"handle_subscription_created: failed to send welcome email: {_e}")


def handle_subscription_updated(event: stripe.Event | dict) -> None:
    """Sync subscription.updated → Firestore + user.isPremium cache."""
    # SECURITY FIX (CRITICAL-021): Use dict access to prevent AttributeError when
    # called with manual dict objects (e.g. from invoice.paid path).
    obj = event["data"]["object"] if isinstance(event, dict) else event.data.object
    _sync_subscription(obj)


def handle_subscription_deleted(event: stripe.Event | dict) -> None:
    """Subscription ended → clear premium status."""
    # SECURITY FIX (CRITICAL-021): Use dict access to prevent AttributeError
    sub = event["data"]["object"] if isinstance(event, dict) else event.data.object
    uid = sub.get("metadata", {}).get("uid") if isinstance(sub, dict) else (sub.metadata or {}).get("uid")
    if not uid:
        logger.warning("subscription.deleted: no uid in metadata")
        return

    db = _get_db()
    now = datetime.now(UTC)

    sub_id = sub["id"] if isinstance(sub, dict) else sub.id
    current_period_end = sub.get("current_period_end") if isinstance(sub, dict) else sub.current_period_end

    sub_ref = db.collection(Collections.SUBSCRIPTIONS).document(uid)
    user_ref = db.collection(Collections.USERS).document(uid)

    @_get_firestore().transactional
    def _clear_premium(transaction: _fs.Transaction) -> None:
        user_doc = user_ref.get(transaction=transaction)
        transaction.set(
            sub_ref,
            {
                Fields.STRIPE_SUBSCRIPTION_ID: sub_id,
                Fields.STATUS: SubscriptionStatusValues.CANCELED,
                Fields.CANCEL_AT_PERIOD_END: False,
                Fields.CURRENT_PERIOD_END: _ts_to_datetime(current_period_end),
                Fields.UPDATED_AT: now,
            },
            merge=True,
        )
        if user_doc.exists:
            transaction.update(
                user_ref,
                {
                    Fields.IS_PREMIUM: False,
                    Fields.PREMIUM_EXPIRES_AT: None,
                    Fields.STRIPE_SUBSCRIPTION_ID: None,
                    Fields.PREMIUM_SINCE: None,
                    Fields.UPDATED_AT: now,
                },
            )
        else:
            logger.warning(f"handle_subscription_deleted: user {uid} not found — clearing sub doc only")

    _clear_premium(_get_db().transaction())
    logger.info(f"Premium cleared for user {uid} (subscription deleted)")

    # FIX F7-5: Send subscription expired/ended email
    try:
        user_data = _fetch_user_for_email(uid)
        lang = user_data.get("preferredLanguage", "en")
        recipient_email = user_data.get("email")
        if recipient_email:
            from services.email_service import get_premium_expired_email
            from services.email_task import enqueue_email_task

            html_body = get_premium_expired_email(user_data, lang=lang)
            subj = "Your Origna Premium Has Ended" if lang == "en" else "Votre Origna Premium a pris fin"
            enqueue_email_task(
                to_email=recipient_email,
                subject=subj,
                html_content=html_body,
                event_type="premium_expired",
                user_id=uid
            )
            logger.info(f"Premium expired email sent to {recipient_email} (uid={uid})")
    except Exception as _e:
        logger.error(f"handle_subscription_deleted: failed to send expired email: {_e}")


def handle_invoice_payment_failed(event: stripe.Event | dict) -> None:
    """Invoice payment failed → mark past_due + send alert email (FIX F7-3)."""
    invoice = event["data"]["object"] if isinstance(event, dict) else event.data.object
    sub_id = invoice.get("subscription")
    if not sub_id:
        return

    _stripe_init()
    sub = None
    try:
        sub = stripe.Subscription.retrieve(sub_id)
        _sync_subscription(sub)
    except stripe.StripeError as e:
        logger.error(f"Failed to retrieve subscription {sub_id} after payment failure: {e}")

    # FIX F7-3: Notify user that their subscription renewal payment failed
    try:
        uid = None
        if sub is not None:
            uid = (sub.get("metadata", {}).get("uid") if isinstance(sub, dict)
                   else (sub.metadata or {}).get("uid"))
        if not uid:
            # Try to get uid from invoice customer metadata via subscription metadata
            uid = (invoice.get("metadata", {}) or {}).get("uid")
        if uid:
            user_data = _fetch_user_for_email(uid)
            lang = user_data.get("preferredLanguage", "en")
            recipient_email = user_data.get("email")
            if recipient_email:
                from services.email_service import get_premium_payment_failed_email
                from services.email_task import enqueue_email_task

                html_body = get_premium_payment_failed_email(user_data, lang=lang)
                subj = "⚠️ Premium Payment Failed — Action Required" if lang == "en" else "⚠️ Paiement premium échoué — Action requise"
                enqueue_email_task(
                    to_email=recipient_email,
                    subject=subj,
                    html_content=html_body,
                    event_type="premium_payment_failed",
                    user_id=uid
                )
                logger.info(f"Premium payment-failed email sent to {recipient_email} (uid={uid})")
    except Exception as _e:
        logger.error(f"handle_invoice_payment_failed: failed to send payment-failed email: {_e}")


def _sync_subscription(sub: dict | stripe.Subscription) -> None:
    """Sync a Stripe Subscription object to Firestore and update user.isPremium cache."""
    uid = sub.get("metadata", {}).get("uid") if isinstance(sub, dict) else (sub.metadata or {}).get("uid")
    if not uid:
        logger.warning(
            f"_sync_subscription: no uid in metadata for sub {sub.get('id') if isinstance(sub, dict) else sub.id}"
        )
        return

    status = sub["status"] if isinstance(sub, dict) else sub.status
    sub_id = sub["id"] if isinstance(sub, dict) else sub.id
    period_end_ts = sub.get("current_period_end") if isinstance(sub, dict) else sub.current_period_end
    period_start_ts = sub.get("current_period_start") if isinstance(sub, dict) else sub.current_period_start
    cancel_at_end = sub.get("cancel_at_period_end", False) if isinstance(sub, dict) else sub.cancel_at_period_end

    # Newer Stripe API versions move current_period_* to subscription items
    if period_end_ts is None:
        try:
            items = (sub.get("items", {}).get("data", []) if isinstance(sub, dict)
                     else list(sub.items.data or []))
            if items:
                first_item = items[0]
                if isinstance(first_item, dict):
                    period_end_ts = first_item.get("current_period_end")
                    period_start_ts = period_start_ts or first_item.get("current_period_start")
                else:
                    period_end_ts = getattr(first_item, "current_period_end", None)
                    period_start_ts = period_start_ts or getattr(first_item, "current_period_start", None)
        except (AttributeError, TypeError, KeyError, IndexError) as parse_err:
            logger.debug(f"_sync_subscription: failed to parse subscription item period fields: {type(parse_err).__name__}")

    period_end = _ts_to_datetime(period_end_ts)
    period_start = _ts_to_datetime(period_start_ts)
    is_premium = status in SubscriptionStatusValues.PREMIUM_ACTIVE
    now = datetime.now(UTC)

    db = _get_db()

    sub_ref = db.collection(Collections.SUBSCRIPTIONS).document(uid)
    user_ref = db.collection(Collections.USERS).document(uid)

    @_fs.transactional
    def _sync_txn(transaction):
        # Read premiumSince atomically inside the transaction
        user_snap = user_ref.get(transaction=transaction)
        existing_premium_since = (user_snap.to_dict() or {}).get(Fields.PREMIUM_SINCE) if user_snap.exists else None

        transaction.set(
            sub_ref,
            {
                Fields.UID: uid,
                Fields.STRIPE_SUBSCRIPTION_ID: sub_id,
                Fields.STATUS: status,
                Fields.CURRENT_PERIOD_START: period_start,
                Fields.CURRENT_PERIOD_END: period_end,
                Fields.CANCEL_AT_PERIOD_END: cancel_at_end,
                Fields.UPDATED_AT: now,
            },
            merge=True,
        )

        user_update: dict[str, Any] = {
            Fields.IS_PREMIUM: is_premium,
            Fields.STRIPE_SUBSCRIPTION_ID: sub_id,
            Fields.UPDATED_AT: now,
        }
        if is_premium and period_end:
            user_update[Fields.PREMIUM_EXPIRES_AT] = period_end
            if not existing_premium_since:
                user_update[Fields.PREMIUM_SINCE] = period_start or now
        elif not is_premium:
            user_update[Fields.PREMIUM_EXPIRES_AT] = period_end

        transaction.update(user_ref, user_update)

    transaction = db.transaction()
    _sync_txn(transaction)
    logger.info(f"Subscription synced for user {uid}: status={status}, isPremium={is_premium}")


def _ts_to_datetime(ts: int | None) -> datetime | None:
    """Convert Unix timestamp to UTC datetime."""
    if ts is None:
        return None
    return datetime.fromtimestamp(ts, tz=UTC)
