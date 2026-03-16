"""
Origna GTA Cloud Functions - Entry Point
Refactored architecture with modular handlers

All Firebase Cloud Functions are organized by domain:
- payment_stripe: Stripe payment processing
- products: Product CRUD + Algolia sync
- orders: Order lifecycle management
- admin: User roles + MFA + GDPR
- cron_jobs: Scheduled background tasks
"""

# Firebase Admin SDK initialization
# Stripe API key setup
import logging
import os

import firebase_admin

# ===============================================
# MONKEY-PATCH: firebase-functions 0.4.x crashes with KeyError: 'authtype'
# when Firestore on_document_updated triggers are invoked by service accounts.
# raw._get_attributes() returns a dict missing 'authtype' and 'authid'.
# See: https://github.com/firebase/firebase-functions-python/issues/187
# ===============================================
import stripe

logger = logging.getLogger(__name__)

_original_get_attributes = None


def _patch_cloud_event_get_attributes(self):
    """Inject missing 'authtype'/'authid' into Firestore trigger event attributes."""
    attrs = _original_get_attributes(self)
    if isinstance(attrs, dict):
        attrs.setdefault("authtype", "SERVICE")
        attrs.setdefault("authid", "")
    return attrs


try:
    from cloudevents.http.event import CloudEvent as _CE

    _original_get_attributes = _CE._get_attributes
    _CE._get_attributes = _patch_cloud_event_get_attributes
except (ImportError, AttributeError, TypeError) as patch_err:
    logger.warning(
        f"CloudEvent monkey patch skipped; trigger authtype workaround inactive: {type(patch_err).__name__}"
    )

# ===============================================
# MONKEY-PATCH: firebase-functions 0.4.x scheduler_fn uses strptime('%Y-%m-%dT%H:%M:%S%z')
# which crashes when Cloud Scheduler sends microseconds: '2026-02-24T14:05:03.713303-08:00'.
# Fix: subclass datetime to fall back to fromisoformat() on ValueError.
# ===============================================
try:
    import datetime as _datetime_module

    import firebase_functions.scheduler_fn as _sched_fn_module

    class _DatetimeWithIsoFallback(_datetime_module.datetime):
        """datetime subclass with ISO fallback for microsecond scheduler timestamps."""

        @classmethod
        def strptime(cls, date_string, fmt):
            """Function strptime."""
            try:
                return super().strptime(date_string, fmt)
            except ValueError:
                return _datetime_module.datetime.fromisoformat(date_string)

    _sched_fn_module._dt.datetime = _DatetimeWithIsoFallback
except (ImportError, AttributeError, TypeError, ValueError) as patch_err:
    logger.warning(
        f"Scheduler datetime monkey patch skipped; microsecond fallback inactive: {type(patch_err).__name__}"
    )

# ===============================================
# MONKEY-PATCH: firebase-functions 0.4.x scheduler_fn.on_schedule_wrapped crashes with
# AttributeError: 'ScheduledEvent' object has no attribute 'headers' when the scheduled
# function is invoked via the Cloud Run v2 event-driven path (ScheduledEvent) rather than
# via HTTP trigger (flask.Request). The SDK tries request.headers.get("X-CloudScheduler-...")
# but ScheduledEvent has no .headers attribute.
# Fix: add a headers stub to ScheduledEvent so .get() returns None (schedule_time=None).
# Sentry issue: FLUTTER-11 (compute_seller_metrics, Mar 2026)
# ===============================================
try:
    from firebase_functions.scheduler_fn import ScheduledEvent as _ScheduledEvent

    class _HeadersStub:
        """Stub headers object — returns None for any key to satisfy scheduler_fn SDK."""

        def get(self, key, default=None):
            """Function get."""
            return default

    if not hasattr(_ScheduledEvent, "headers"):
        _ScheduledEvent.headers = _HeadersStub()
except (ImportError, AttributeError, TypeError) as patch_err:
    logger.warning(
        f"ScheduledEvent headers monkey patch skipped: {type(patch_err).__name__}"
    )

# Initialize Firebase Admin SDK BEFORE any handler imports — handlers may call
# firestore.client() or firebase_admin.auth at import time.
if not firebase_admin._apps:
    firebase_admin.initialize_app()

# ===============================================
# PAYMENT HANDLERS - STRIPE
# ===============================================
# ===============================================
# DIGITAL PRODUCT HANDLERS
# ===============================================
# ===============================================
# ADDRESS HANDLERS
# ===============================================
# Initialize Sentry for production error monitoring
from config import init_sentry  # noqa: E402
from handlers.addresses import get_address_suggestions  # noqa: E402

# ===============================================
# ADMIN HANDLERS
# ===============================================
from handlers.admin import (  # noqa: E402
    admin_delete_review,
    admin_flag_review,
    admin_get_reviews,
    admin_mfa_disable,
    admin_mfa_enroll,
    admin_mfa_verify,
    admin_mfa_verify_backup,
    admin_refund_order,
    admin_update_product_stock,
    create_stripe_login_link,
    delete_account,
    e2e_get_mail_logs,
    e2e_seed_license,
    export_my_data,
    suspend_seller,
    unsubscribe_email,
    unsuspend_seller,
    update_user_roles,
)
from handlers.chat import (  # noqa: E402
    delete_message,
    get_or_create_chat,
    mark_messages_read,
    report_message,
    send_message,
)
from handlers.coupons import (  # noqa: E402
    admin_create_coupon,
    apply_coupon,
)

# ===============================================
# CRON JOB HANDLERS
# ===============================================
from handlers.cron_jobs import (  # noqa: E402
    auto_archive_old_orders,
    auto_capture_confirmed_receipts,
    stale_orders_dispatcher,
    check_low_stock_alerts,
    cleanup_orphaned_r2_images,
    cleanup_stale_rate_limits,
    cleanup_stale_security_alerts,
    cleanup_stale_webhook_events,
    compute_seller_metrics,
    compute_trending_products,
    escalate_stale_return_requests,
    monitor_algolia_sync,
    retry_failed_algolia_syncs,
    revalidate_digital_product_urls,
    send_abandoned_cart_emails,
    sync_expired_subscriptions,
)
from handlers.digital import (  # noqa: E402
    activate_license,
    deactivate_license,
    generate_book_download_session,
    generate_software_download_session,
    get_book_redirect,
    get_software_redirect,
    verify_license,
)

# ===============================================
# EMAIL TASK QUEUE HANDLER (Cloud Tasks)
# ===============================================
from handlers.email_tasks import sendEmailTask  # noqa: E402
from handlers.tasks import stale_orders_worker # noqa: E402

# ===============================================
# ORDER HANDLERS
# ===============================================
from handlers.orders import (  # noqa: E402
    approve_return_request,
    approve_shipping_cost,
    cancel_order,
    confirm_item_receipt,
    create_return_request,
    escalate_return_request,
    on_order_item_delivered,
    on_order_item_shipped,
    on_order_status_changed,
    on_return_request_status_changed,
    refund_order_item,
    reject_return_request,
    update_item_status,
    update_order_status,
    update_shipping_cost,
)

# ===============================================
# PAYMENT PROVIDER MANAGEMENT
# ===============================================
from handlers.payment_providers import get_payment_providers, get_provider_status, update_payment_provider  # noqa: E402
from handlers.payment_stripe import (  # noqa: E402
    capture_payment,
    create_account_link,
    create_checkout_session,
    create_connect_account,
    get_connect_account_status,
    stripe_webhook,
    verify_cart_prices,
)
from handlers.products import (  # noqa: E402
    admin_approve_product,
    admin_delete_product_question,
    admin_delete_product_rating,
    admin_reject_product,
    admin_update_warehouse_commission,
    answer_product_question,
    answer_review,
    ask_product_question,
    bulk_update_products,
    configure_algolia,
    create_product_atomic,
    create_warehouse,
    deactivate_supplier_platform,
    delete_product,
    delete_product_images,
    delete_warehouse,
    get_product_questions,
    get_product_ratings_paginated,
    get_products_paginated,
    get_seller_products_paginated,
    get_seller_warehouses,
    on_product_created,
    on_product_deleted,
    on_product_updated,
    submit_product_rating,
    submit_product_rating_atomic,
    subscribe_stock_notification,
    toggle_favorite,
    unsubscribe_stock_notification,
    update_product,
    update_warehouse,
    upload_product_images,
    upload_product_video,
    upload_review_images,
    vote_review_helpful,
)
from handlers.shipping import calculate_shipping_cost  # noqa: E402
from handlers.subscriptions import (  # noqa: E402
    cancel_subscription,
    create_subscription,
    get_subscription_status,
    reactivate_subscription,
)
from handlers.users import (  # noqa: E402
    add_buyer_address,
    cleanup_fcm_token,
    create_user_profile,
    delete_buyer_address,
    get_user_profile,
    set_default_buyer_address,
    update_buyer_address,
    update_email_consent,
    update_notification_preferences,
    update_user_profile,
)

# ===============================================
# PRODUCT HANDLERS
# ===============================================
# ===============================================
# SHIPPING CALCULATION — Canonical source is services/shipping_service.py
# This wrapper re-exports calculate_shipping_cost for external HTTP callers.
# The checkout flow (payment_stripe.py) imports directly from services.shipping_service.
# ===============================================

init_sentry()


# Lazy initialization of Stripe API key
def _init_stripe():
    """Initialize Stripe API key lazily"""
    if not stripe.api_key:
        from config import get_stripe_secret_key

        stripe.api_key = get_stripe_secret_key()


# Only initialize in production (not in test environment)
if os.environ.get("TESTING") != "true":
    import contextlib

    with contextlib.suppress(Exception):
        _init_stripe()


# Export all functions for Firebase deployment
__all__ = [
    # Address autocomplete proxy
    "get_address_suggestions",
    # Stripe payments
    "create_checkout_session",
    "verify_cart_prices",
    "stripe_webhook",
    "capture_payment",
    "create_connect_account",
    "get_connect_account_status",
    "create_account_link",
    # Premium subscriptions
    "create_subscription",
    "cancel_subscription",
    "get_subscription_status",
    "reactivate_subscription",
    # Chat (premium feature)
    "get_or_create_chat",
    "mark_messages_read",
    "send_message",
    "report_message",
    "delete_message",
    # Products
    "upload_product_images",
    "upload_product_video",
    "upload_review_images",
    "delete_product_images",
    "create_product_atomic",
    "delete_product",
    "submit_product_rating",
    "submit_product_rating_atomic",
    "toggle_favorite",
    "configure_algolia",
    "admin_approve_product",
    "admin_reject_product",
    "get_products_paginated",
    "get_seller_products_paginated",
    "get_product_ratings_paginated",
    "on_product_created",
    "on_product_updated",
    "on_product_deleted",
    "update_product",
    # Back-in-stock (TASK 07)
    "subscribe_stock_notification",
    "unsubscribe_stock_notification",
    # Product Q&A (TASK 09)
    "ask_product_question",
    "answer_product_question",
    "get_product_questions",
    # Seller review reply (N-03)
    "answer_review",
    # Review helpfulness voting (N-04)
    "vote_review_helpful",
    # Bulk seller operations (N-08)
    "bulk_update_products",
    # Admin supplier platform deactivation
    "deactivate_supplier_platform",
    # Coupon / promo codes (N-07)
    "apply_coupon",
    "admin_create_coupon",
    # Warehouses
    "create_warehouse",
    "update_warehouse",
    "delete_warehouse",
    "get_seller_warehouses",
    # Orders
    "confirm_item_receipt",
    "update_order_status",
    "update_item_status",
    "refund_order_item",
    "cancel_order",
    "approve_shipping_cost",
    "update_shipping_cost",
    "on_order_item_delivered",
    "on_order_item_shipped",
    "on_order_status_changed",
    "on_return_request_status_changed",
    "create_return_request",
    "approve_return_request",
    "reject_return_request",
    "escalate_return_request",
    # Admin
    "update_user_roles",
    "suspend_seller",
    "unsuspend_seller",
    "admin_update_product_stock",
    "admin_delete_review",
    "admin_delete_product_question",
    "admin_delete_product_rating",
    "admin_update_warehouse_commission",
    "admin_flag_review",
    "admin_get_reviews",
    "admin_refund_order",
    "admin_mfa_enroll",
    "admin_mfa_verify",
    "admin_mfa_verify_backup",
    "admin_mfa_disable",
    "create_stripe_login_link",
    "delete_account",
    "export_my_data",
    "unsubscribe_email",
    "e2e_get_mail_logs",
    "e2e_seed_license",
    # User Profile
    "add_buyer_address",
    "cleanup_fcm_token",
    "create_user_profile",
    "delete_buyer_address",
    "get_user_profile",
    "set_default_buyer_address",
    "update_buyer_address",
    "update_email_consent",
    "update_notification_preferences",
    "update_user_profile",
    # Payment Provider Management
    "get_payment_providers",
    "update_payment_provider",
    "get_provider_status",
    # Cron jobs
    "auto_capture_confirmed_receipts",
    "stale_orders_dispatcher",
    "auto_archive_old_orders",
    "monitor_algolia_sync",
    "revalidate_digital_product_urls",
    "cleanup_stale_rate_limits",
    "cleanup_orphaned_r2_images",
    "cleanup_stale_webhook_events",
    "cleanup_stale_security_alerts",
    "retry_failed_algolia_syncs",
    "check_low_stock_alerts",
    "send_abandoned_cart_emails",
    "compute_seller_metrics",
    # Trending products
    "compute_trending_products",
    "sync_expired_subscriptions",
    "escalate_stale_return_requests",
    # Cloud Tasks
    "sendEmailTask",
    "stale_orders_worker",
    # Shipping
    "calculate_shipping_cost",
    # Digital products
    "activate_license",
    "deactivate_license",
    "generate_book_download_session",
    "generate_software_download_session",
    "get_book_redirect",
    "get_software_redirect",
    "verify_license",
]

print(f"""
╔══════════════════════════════════════════════╗
║  Origna GTA Cloud Functions - Initialized   ║
║  Total Functions: {len(__all__)}                        ║
║  Architecture: Modular Handlers              ║
╚══════════════════════════════════════════════╝
""")
