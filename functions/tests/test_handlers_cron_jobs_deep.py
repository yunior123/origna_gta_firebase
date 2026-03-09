from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import Mock, patch

import pytest
from google.api_core import exceptions as google_exceptions
from schema_constants import (
    AlgoliaActionValues,
    BusinessRules,
    Collections,
    CronLockStatusValues,
    DeliveryStatusValues,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
    PayoutStatusValues,
    ProductLifecycleStatusValues,
    SubscriptionStatusValues,
)


def _query(*, stream_return=None, stream_side_effect=None, get_return=None):
    query = Mock()
    query.where.return_value = query
    query.order_by.return_value = query
    query.limit.return_value = query
    query.start_after.return_value = query
    if stream_side_effect is not None:
        query.stream.side_effect = stream_side_effect
    else:
        query.stream.return_value = stream_return if stream_return is not None else []
    query.get.return_value = [] if get_return is None else get_return
    return query


def _snapshot(doc_id: str, data=None, *, exists=True):
    snap = Mock()
    snap.id = doc_id
    snap.exists = exists
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


class TestCronLockHelpers:
    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_acquire_cron_lock_returns_false_when_recent_lock_exists(self, mock_get_db, mock_get_fs):
        from handlers.cron_jobs import acquire_cron_lock

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        lock_doc = Mock()
        lock_doc.exists = True
        lock_doc.to_dict.return_value = {
            # Naive datetime exercises tz-normalization branch.
            Fields.LOCKED_AT: datetime.now(UTC).replace(tzinfo=None, microsecond=0),
        }

        lock_ref = Mock()
        lock_ref.get.return_value = lock_doc
        db.collection.return_value.document.return_value = lock_ref
        mock_get_fs.return_value.transactional = lambda fn: fn

        assert acquire_cron_lock("job_recent") is False
        tx.set.assert_not_called()

    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_acquire_cron_lock_sets_running_status_when_lock_is_stale(self, mock_get_db, mock_get_fs):
        from handlers.cron_jobs import acquire_cron_lock

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        lock_doc = Mock()
        lock_doc.exists = True
        lock_doc.to_dict.return_value = {Fields.LOCKED_AT: datetime.now(UTC) - timedelta(hours=3)}

        lock_ref = Mock()
        lock_ref.get.return_value = lock_doc
        db.collection.return_value.document.return_value = lock_ref
        mock_get_fs.return_value.transactional = lambda fn: fn

        assert acquire_cron_lock("job_stale") is True
        tx.set.assert_called_once()
        written = tx.set.call_args.args[1]
        assert written[Fields.STATUS] == CronLockStatusValues.RUNNING
        assert written[Fields.LOCKED_BY] == "cron_job_stale"

    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_acquire_cron_lock_returns_false_on_internal_error(self, mock_get_db, mock_get_fs):
        from handlers.cron_jobs import acquire_cron_lock

        db = Mock()
        db.transaction.side_effect = RuntimeError("tx failed")
        mock_get_db.return_value = db
        mock_get_fs.return_value.transactional = lambda fn: fn

        assert acquire_cron_lock("job_error") is False

    @patch("handlers.cron_jobs.get_db")
    def test_release_cron_lock_swallows_update_error(self, mock_get_db):
        from handlers.cron_jobs import release_cron_lock

        lock_ref = Mock()
        lock_ref.update.side_effect = RuntimeError("update failed")
        mock_get_db.return_value.collection.return_value.document.return_value = lock_ref

        release_cron_lock("job_release")

    @patch("handlers.cron_jobs.sentry_sdk")
    @patch("handlers.cron_jobs.get_db")
    def test_alert_cron_failure_writes_record(self, mock_get_db, mock_sentry):
        from handlers.cron_jobs import _alert_cron_failure

        failures_col = Mock()
        mock_get_db.return_value.collection.return_value = failures_col

        _alert_cron_failure("job_alert", ValueError("boom"))

        mock_sentry.capture_exception.assert_called_once()
        failures_col.add.assert_called_once()

    @patch("handlers.cron_jobs.sentry_sdk")
    @patch("handlers.cron_jobs.get_db")
    def test_alert_cron_failure_handles_write_error(self, mock_get_db, mock_sentry):
        from handlers.cron_jobs import _alert_cron_failure

        failures_col = Mock()
        failures_col.add.side_effect = RuntimeError("write failed")
        mock_get_db.return_value.collection.return_value = failures_col

        _alert_cron_failure("job_alert_error", RuntimeError("boom"))
        mock_sentry.capture_exception.assert_called_once()


class TestAutoCaptureWrappers:
    @patch("handlers.cron_jobs._run_auto_capture")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_auto_capture_confirmed_receipts_skips_when_lock_is_held(self, _mock_lock, mock_run):
        from handlers.cron_jobs import auto_capture_confirmed_receipts

        auto_capture_confirmed_receipts(Mock())
        mock_run.assert_not_called()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs._run_auto_capture", side_effect=RuntimeError("capture failed"))
    @patch("handlers.cron_jobs.get_stripe_secret_key", return_value="sk_test_cron")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    def test_auto_capture_confirmed_receipts_alerts_and_releases_on_error(
        self, _mock_lock, _mock_secret, _mock_run, mock_alert, mock_release
    ):
        from handlers.cron_jobs import auto_capture_confirmed_receipts

        auto_capture_confirmed_receipts(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("auto_capture_confirmed_receipts")

    @patch("handlers.payment_providers.is_provider_enabled", return_value=False)
    def test_run_auto_capture_returns_early_when_stripe_disabled(self, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        with patch("handlers.cron_jobs.get_db") as mock_get_db:
            _run_auto_capture()
        mock_get_db.assert_not_called()


class TestSellerMetricsAndTrending:
    @patch("handlers.cron_jobs.get_db")
    def test_compute_avg_response_time_returns_average_of_numeric_values(self, mock_get_db):
        from handlers.cron_jobs import _compute_avg_response_time

        chats = [
            _snapshot("c1", {Fields.FIRST_REPLY_HOURS: 1.2}),
            _snapshot("c2", {Fields.FIRST_REPLY_HOURS: 2.8}),
            _snapshot("c3", {Fields.FIRST_REPLY_HOURS: "n/a"}),
        ]
        chats_query = _query(stream_return=chats)
        mock_get_db.return_value.collection.return_value = chats_query

        assert _compute_avg_response_time("seller_1", datetime.now(UTC) - timedelta(days=7)) == 2.0

    @patch("handlers.cron_jobs.get_db")
    def test_compute_avg_response_time_returns_zero_on_error(self, mock_get_db):
        from handlers.cron_jobs import _compute_avg_response_time

        mock_get_db.return_value.collection.side_effect = RuntimeError("db down")
        assert _compute_avg_response_time("seller_1", datetime.now(UTC)) == 0.0

    @patch("handlers.cron_jobs.get_db")
    def test_compute_seller_metrics_logic_writes_metrics_and_alerts(self, mock_get_db):
        from handlers.cron_jobs import _compute_seller_metrics_logic

        created_at = datetime.now().replace(microsecond=0)
        shipped_at = created_at + timedelta(days=5)
        orders = [
            _snapshot(
                "order_1",
                {
                    Fields.SELLER_IDS: ["seller_1"],
                    Fields.HAS_DISPUTE: True,
                    Fields.ORDER_STATUS: OrderStatusValues.CANCELLED,
                    Fields.CREATED_AT: created_at,
                    Fields.ITEMS: [
                        {
                            Fields.SELLER_ID: "seller_1",
                            Fields.STATUS: DeliveryStatusValues.REFUNDED,
                            Fields.SHIPPED_AT: shipped_at,
                            Fields.ESTIMATED_SHIP_DAYS: 1,
                        }
                    ],
                    Fields.SELLER_PAYOUTS: [{Fields.SELLER_ID: "seller_1", Fields.SELLER_AMOUNT_CENTS: 2599}],
                },
            )
        ]
        chats = [_snapshot("chat_1", {Fields.SELLER_ID: "seller_1", Fields.FIRST_REPLY_HOURS: 3.5})]
        sellers = [_snapshot("seller_1", {})]

        orders_query = _query(stream_return=orders)
        chats_query = _query(stream_return=chats)
        sellers_query = _query(stream_return=sellers)
        alerts_query = _query(get_return=[])

        metrics_ref = Mock()
        metrics_col = Mock()
        metrics_col.document.return_value = metrics_ref

        alerts_col = Mock()
        alerts_col.where.return_value = alerts_query

        def collection_side_effect(name):
            mapping = {
                Collections.ORDERS: orders_query,
                Collections.CHATS: chats_query,
                Collections.USERS: sellers_query,
                Collections.SELLER_METRICS: metrics_col,
                Collections.SECURITY_ALERTS: alerts_col,
            }
            return mapping[name]

        db = Mock()
        db.collection.side_effect = collection_side_effect
        mock_get_db.return_value = db

        _compute_seller_metrics_logic()

        metrics_ref.set.assert_called_once()
        payload = metrics_ref.set.call_args.args[0]
        assert payload[Fields.SELLER_ID] == "seller_1"
        assert payload[Fields.TOTAL_ORDERS_30D] == 1
        assert payload[Fields.TOTAL_REVENUE_CENTS_30D] == 2599
        alerts_col.add.assert_called_once()

    @patch("handlers.cron_jobs._compute_seller_metrics_logic")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_compute_seller_metrics_skips_when_lock_is_held(self, _mock_lock, mock_logic):
        from handlers.cron_jobs import compute_seller_metrics

        compute_seller_metrics(Mock())
        mock_logic.assert_not_called()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs._compute_seller_metrics_logic", side_effect=RuntimeError("metrics failed"))
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    def test_compute_seller_metrics_alerts_and_releases_on_error(
        self, _mock_lock, _mock_logic, mock_alert, mock_release
    ):
        from handlers.cron_jobs import compute_seller_metrics

        compute_seller_metrics(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("compute_seller_metrics")

    @patch("handlers.cron_jobs.get_db")
    @patch("handlers.cron_jobs._notify_trending_products")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    def test_compute_trending_products_marks_top_and_clears_old(
        self, _mock_lock, mock_release, mock_notify, mock_get_db
    ):
        from handlers.cron_jobs import compute_trending_products

        products = [
            _snapshot(
                "p_top",
                {
                    Fields.NAME: "Top Product",
                    Fields.IMAGE_URLS: ["https://cdn.example.com/top.png"],
                    Fields.VIEW_COUNT: 10,
                    Fields.PURCHASE_COUNT: 2,
                    Fields.FAVORITE_COUNT: 1,
                    Fields.IS_TRENDING: False,
                },
            ),
            _snapshot(
                "p_old",
                {
                    Fields.NAME: "Old Product",
                    Fields.IMAGE_URLS: [],
                    Fields.VIEW_COUNT: 0,
                    Fields.PURCHASE_COUNT: 0,
                    Fields.FAVORITE_COUNT: 0,
                    Fields.IS_TRENDING: True,
                },
            ),
            _snapshot(
                "p_second",
                {
                    Fields.NAME: "Second Product",
                    Fields.IMAGE_URLS: ["https://cdn.example.com/second.png"],
                    Fields.VIEW_COUNT: 4,
                    Fields.PURCHASE_COUNT: 1,
                    Fields.FAVORITE_COUNT: 0,
                    Fields.IS_TRENDING: False,
                },
            ),
        ]

        products_query = _query(stream_return=products)
        products_col = Mock()
        products_col.where.return_value = products_query
        products_col.document.side_effect = lambda pid: Mock(name=f"product_ref_{pid}")

        batch = Mock()
        db = Mock()
        db.batch.return_value = batch
        db.collection.side_effect = lambda name: products_col if name == Collections.PRODUCTS else Mock()
        mock_get_db.return_value = db

        compute_trending_products(Mock())

        assert batch.update.call_count >= 3
        batch.commit.assert_called()
        mock_notify.assert_called_once()
        notified_products = mock_notify.call_args.args[1]
        assert notified_products
        assert notified_products[0][1] == "p_top"
        mock_release.assert_called_once_with("compute_trending_products")

    @patch("handlers.cron_jobs.get_db")
    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    def test_compute_trending_products_alerts_on_exception(self, _mock_lock, mock_release, mock_alert, mock_get_db):
        from handlers.cron_jobs import compute_trending_products

        db = Mock()
        db.collection.side_effect = RuntimeError("query failure")
        mock_get_db.return_value = db

        compute_trending_products(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("compute_trending_products")

    def test_notify_trending_products_no_tokens_does_not_send(self):
        from handlers.cron_jobs import _notify_trending_products

        users_query = _query(stream_return=[])
        db = Mock()
        db.collection.return_value = users_query

        messaging = Mock()
        messaging.send_each_for_multicast.return_value = SimpleNamespace(success_count=0, failure_count=0)

        with patch("firebase_admin.messaging", messaging, create=True):
            _notify_trending_products(db, [(9, "p1", "Top Product", "img")])

        messaging.send_each_for_multicast.assert_not_called()

    def test_notify_trending_products_sends_multicast_for_collected_tokens(self):
        from handlers.cron_jobs import _notify_trending_products

        token_docs = [_snapshot("t1", {"token": "tok_1"}), _snapshot("t2", {"token": "tok_2"})]
        token_query = _query(stream_return=token_docs)

        user_ref = Mock()
        user_ref.collection.return_value = token_query
        user_doc = _snapshot("user_1", {})
        user_doc.reference = user_ref

        users_query = _query(stream_return=[user_doc])
        db = Mock()
        db.collection.return_value = users_query

        messaging = Mock()
        messaging.Notification.return_value = Mock()
        messaging.MulticastMessage.return_value = Mock()
        messaging.send_each_for_multicast.return_value = SimpleNamespace(success_count=2, failure_count=0)

        with patch("firebase_admin.messaging", messaging, create=True):
            _notify_trending_products(db, [(12, "p1", "Top Product", "img"), (8, "p2", "Next Product", "img2")])

        messaging.send_each_for_multicast.assert_called_once()


class TestPremiumRenewalAndSubscriptionSync:
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_send_premium_renewal_reminders_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import send_premium_renewal_reminders

        send_premium_renewal_reminders(Mock())
        mock_release.assert_not_called()

    @patch("services.email_task.enqueue_email_task")
    @patch("services.email_service.get_premium_renewal_reminder_email", return_value="<p>renewal</p>")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_send_premium_renewal_reminders_enqueues_email_and_sets_dedup(
        self, mock_get_db, _mock_lock, mock_release, _mock_template, mock_enqueue
    ):
        from handlers.cron_jobs import send_premium_renewal_reminders

        active_status = next(iter(SubscriptionStatusValues.PREMIUM_ACTIVE))
        sub_doc = _snapshot(
            "user_1",
            {
                Fields.STATUS: active_status,
                Fields.CANCEL_AT_PERIOD_END: False,
                Fields.CURRENT_PERIOD_END: datetime.now(UTC) + timedelta(days=7),
            },
        )
        subs_query = _query(stream_side_effect=[[sub_doc], []])

        subs_col = Mock()
        subs_col.where.return_value = subs_query
        sub_ref = Mock()
        subs_col.document.return_value = sub_ref

        user_doc = _snapshot("user_1", {Fields.EMAIL: "user@example.com", Fields.PREFERRED_LANGUAGE: "en"}, exists=True)
        user_ref = Mock()
        user_ref.get.return_value = user_doc
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: subs_col if name == Collections.SUBSCRIPTIONS else users_col
        mock_get_db.return_value = db

        send_premium_renewal_reminders(Mock())

        mock_enqueue.assert_called_once()
        sub_ref.update.assert_called_once()
        update_payload = sub_ref.update.call_args.args[0]
        assert any(key.startswith("renewalReminderSentDays") for key in update_payload)
        mock_release.assert_called_once_with("send_premium_renewal_reminders")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("db failed"))
    def test_send_premium_renewal_reminders_alerts_on_outer_failure(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import send_premium_renewal_reminders

        send_premium_renewal_reminders(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("send_premium_renewal_reminders")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_sync_expired_subscriptions_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import sync_expired_subscriptions

        sync_expired_subscriptions(Mock())
        mock_release.assert_not_called()

    @patch("handlers.subscriptions._sync_subscription")
    @patch("stripe.Subscription.retrieve", return_value=Mock(id="sub_123"))
    @patch("handlers.cron_jobs.get_stripe_secret_key", return_value="sk_test_sync")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_sync_expired_subscriptions_syncs_and_clears_orphaned_users(
        self, mock_get_db, _mock_lock, mock_release, _mock_key, _mock_retrieve, mock_sync
    ):
        from handlers.cron_jobs import sync_expired_subscriptions

        expired_sub = _snapshot("user_1", {Fields.STRIPE_SUBSCRIPTION_ID: "sub_123"})
        expired_query = _query(stream_return=[expired_sub])

        subs_col = Mock()
        subs_col.where.return_value = expired_query
        subs_col.document.side_effect = lambda uid: Mock(name=f"sub_ref_{uid}")

        premium_user = _snapshot("user_1", {})
        users_query = _query(stream_return=[premium_user])
        users_col = Mock()
        users_col.where.return_value = users_query
        users_col.document.side_effect = lambda uid: Mock(name=f"user_ref_{uid}")

        db = Mock()
        db.collection.side_effect = lambda name: subs_col if name == Collections.SUBSCRIPTIONS else users_col
        db.get_all.return_value = [_snapshot("user_1", exists=False)]
        batch = Mock()
        db.batch.return_value = batch
        mock_get_db.return_value = db

        sync_expired_subscriptions(Mock())

        mock_sync.assert_called_once()
        batch.update.assert_called_once()
        batch.commit.assert_called_once()
        mock_release.assert_called_once_with("sync_expired_subscriptions")

    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("stripe.Subscription.retrieve", side_effect=RuntimeError("stripe failed"))
    @patch("handlers.cron_jobs.get_stripe_secret_key", return_value="sk_test_sync")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_sync_expired_subscriptions_captures_per_subscription_error(
        self, mock_get_db, _mock_lock, mock_release, _mock_key, _mock_retrieve, mock_capture
    ):
        from handlers.cron_jobs import sync_expired_subscriptions

        expired_sub = _snapshot("user_1", {Fields.STRIPE_SUBSCRIPTION_ID: "sub_123"})
        expired_query = _query(stream_return=[expired_sub])
        empty_users_query = _query(stream_return=[])

        subs_col = Mock()
        subs_col.where.return_value = expired_query
        users_col = Mock()
        users_col.where.return_value = empty_users_query

        db = Mock()
        db.collection.side_effect = lambda name: subs_col if name == Collections.SUBSCRIPTIONS else users_col
        mock_get_db.return_value = db

        sync_expired_subscriptions(Mock())
        mock_capture.assert_called_once()
        mock_release.assert_called_once_with("sync_expired_subscriptions")

    @patch("services.email_task.enqueue_email_task")
    @patch("services.email_service.get_premium_renewal_reminder_email", return_value="<p>renewal</p>")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_send_premium_renewal_reminders_skip_and_inner_error_branches(
        self, mock_get_db, _mock_lock, mock_release, _mock_template, mock_enqueue
    ):
        from handlers.cron_jobs import send_premium_renewal_reminders

        active_status = next(iter(SubscriptionStatusValues.PREMIUM_ACTIVE))
        docs = [
            _snapshot(
                "u_cancel_at_period_end",
                {
                    Fields.STATUS: active_status,
                    Fields.CANCEL_AT_PERIOD_END: True,
                    Fields.CURRENT_PERIOD_END: datetime.now(UTC) + timedelta(days=7),
                },
            ),
            _snapshot(
                "u_status_cancelled",
                {
                    Fields.STATUS: SubscriptionStatusValues.CANCELED,
                    Fields.CANCEL_AT_PERIOD_END: False,
                    Fields.CURRENT_PERIOD_END: datetime.now(UTC) + timedelta(days=7),
                },
            ),
            _snapshot(
                "u_dedup",
                {
                    Fields.STATUS: active_status,
                    Fields.CANCEL_AT_PERIOD_END: False,
                    "renewalReminderSentDays7": True,
                    Fields.CURRENT_PERIOD_END: datetime.now(UTC) + timedelta(days=7),
                },
            ),
            _snapshot(
                "u_user_missing",
                {
                    Fields.STATUS: active_status,
                    Fields.CANCEL_AT_PERIOD_END: False,
                    Fields.CURRENT_PERIOD_END: datetime.now(UTC) + timedelta(days=7),
                },
            ),
            _snapshot(
                "u_no_email",
                {
                    Fields.STATUS: active_status,
                    Fields.CANCEL_AT_PERIOD_END: False,
                    Fields.CURRENT_PERIOD_END: datetime.now(UTC) + timedelta(days=7),
                },
            ),
            _snapshot(
                "u_inner_error",
                {
                    Fields.STATUS: active_status,
                    Fields.CANCEL_AT_PERIOD_END: False,
                    Fields.CURRENT_PERIOD_END: datetime.now(UTC) + timedelta(days=7),
                },
            ),
        ]
        subs_q = _query(stream_side_effect=[docs, []])
        subs_col = Mock()
        subs_col.where.return_value = subs_q
        subs_col.document.side_effect = lambda _uid: Mock()

        user_missing = _snapshot("u_user_missing", exists=False)
        user_no_email = _snapshot("u_no_email", {Fields.PREFERRED_LANGUAGE: "en"}, exists=True)

        user_refs = {
            "u_user_missing": Mock(get=Mock(return_value=user_missing)),
            "u_no_email": Mock(get=Mock(return_value=user_no_email)),
            "u_inner_error": Mock(get=Mock(side_effect=RuntimeError("user read failed"))),
        }
        users_col = Mock()
        users_col.document.side_effect = lambda uid: user_refs.get(uid, Mock(get=Mock(return_value=_snapshot(uid, {}, exists=True))))

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SUBSCRIPTIONS: subs_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        send_premium_renewal_reminders(Mock())

        mock_enqueue.assert_not_called()
        mock_release.assert_called_once_with("send_premium_renewal_reminders")

    @patch("stripe.Subscription.retrieve")
    @patch("handlers.cron_jobs.get_stripe_secret_key", return_value="sk_test_sync")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_sync_expired_subscriptions_missing_stripe_id_and_start_after_branch(
        self, mock_get_db, _mock_lock, mock_release, _mock_key, mock_retrieve
    ):
        from handlers.cron_jobs import sync_expired_subscriptions

        expired_sub = _snapshot(
            "u_missing_stripe_sub",
            {
                Fields.CURRENT_PERIOD_END: datetime.now(UTC) - timedelta(days=1),
                Fields.STATUS: next(iter(SubscriptionStatusValues.PREMIUM_ACTIVE)),
                # No stripeSubscriptionId -> line 2265 continue branch.
            },
        )
        expired_q = _query(stream_return=[expired_sub])
        subs_col = Mock()
        subs_col.where.return_value = expired_q
        subs_col.document.side_effect = lambda uid: Mock(name=f"sub_ref_{uid}")

        premium_page = [_snapshot(f"u_{i}", {}) for i in range(500)]
        users_q = _query(stream_side_effect=[premium_page, []])
        users_col = Mock()
        users_col.where.return_value = users_q
        users_col.document.side_effect = lambda uid: Mock(name=f"user_ref_{uid}")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SUBSCRIPTIONS: subs_col,
            Collections.USERS: users_col,
        }[name]
        db.get_all.return_value = [_snapshot(doc.id, exists=True) for doc in premium_page]
        db.batch.return_value = Mock()
        mock_get_db.return_value = db

        sync_expired_subscriptions(Mock())

        mock_retrieve.assert_not_called()
        assert users_q.start_after.called
        mock_release.assert_called_once_with("sync_expired_subscriptions")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("sync outer fail"))
    def test_sync_expired_subscriptions_outer_failure_alerts(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import sync_expired_subscriptions

        sync_expired_subscriptions(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("sync_expired_subscriptions")


class TestAdditionalCronCoverage:
    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.IS_EMULATOR", True)
    @patch("handlers.cron_jobs.get_server_timestamp", return_value="ts")
    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_emulator_authorized_order_happy_path(
        self, mock_get_db, mock_get_firestore, _mock_ts, _mock_enabled
    ):
        from handlers.cron_jobs import _run_auto_capture

        order_data = {
            Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_test_1",
            Fields.ITEMS: [
                {
                    Fields.SELLER_ID: "seller_1",
                    Fields.STATUS: DeliveryStatusValues.DELIVERED,
                    Fields.PRICE: 10.0,
                    Fields.QUANTITY: 2,
                    Fields.DELIVERED_AT: datetime.now(UTC) - timedelta(days=60),
                }
            ],
            Fields.SELLER_STRIPE_ACCOUNTS: {"seller_1": "acct_1"},
            Fields.PLATFORM_FEE_RATIO: 0.1,
        }
        order_doc = _snapshot("ord_1", order_data)
        order_doc.reference.get.return_value = _snapshot("ord_1", {Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED})

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_query = _query(get_return=[])
        alerts_col = Mock()
        alerts_col.where.return_value = alerts_query

        returns_query = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = returns_query

        payout_lookup_query = _query(get_return=[])
        payout_ref = Mock()
        payouts_col = Mock()
        payouts_col.where.return_value = payout_lookup_query
        payouts_col.document.return_value = payout_ref

        users_col = Mock()
        users_col.document.side_effect = lambda sid: SimpleNamespace(id=sid, _kind="user")
        sp_col = Mock()
        sp_col.document.side_effect = lambda sid: SimpleNamespace(id=sid, _kind="sp")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: sp_col,
        }[name]

        def _get_all(refs):
            snaps = []
            for ref in refs:
                if ref._kind == "user":
                    snaps.append(_snapshot(ref.id, {Fields.SUSPENDED: False}, exists=True))
                else:
                    snaps.append(
                        _snapshot(
                            ref.id,
                            {Fields.CHARGES_ENABLED: True, Fields.STRIPE_ACCOUNT_ID: "acct_1"},
                            exists=True,
                        )
                    )
            return snaps

        db.get_all.side_effect = _get_all
        tx = Mock()
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        mock_get_firestore.return_value = SimpleNamespace(transactional=lambda fn: fn)

        with (
            patch("handlers.cron_jobs.stripe.PaymentIntent.retrieve", return_value=SimpleNamespace(latest_charge="ch_1")),
            patch("handlers.cron_jobs.stripe.Transfer.create", return_value=SimpleNamespace(id="tr_1")),
        ):
            _run_auto_capture()

        payout_ref.set.assert_called_once()
        payout_ref.update.assert_called_once()
        # Order should end with completed payout status
        assert any(
            call.args and isinstance(call.args[0], dict) and call.args[0].get(Fields.PAYOUT_STATUS) == PayoutStatusValues.COMPLETED
            for call in order_doc.reference.update.call_args_list
        )
        assert tx.update.called

    @patch.dict(
        "os.environ",
        {"STALE_ORDER_WORKER_URL": "https://worker.example.com", "TASK_HANDLER_SA_EMAIL": "tasks@example.iam.gserviceaccount.com"},
        clear=True,
    )
    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.tasks_v2.CloudTasksClient")
    @patch("handlers.cron_jobs.get_db")
    def test_dispatch_stale_orders_creates_tasks_and_handles_duplicate_and_error(
        self, mock_get_db, mock_tasks_client_cls, mock_capture
    ):
        from handlers.cron_jobs import _dispatch_stale_orders

        orders = [_snapshot("o1", {}), _snapshot("o2", {}), _snapshot("o3", {})]
        orders_query = _query(stream_return=orders)
        db = Mock()
        db.collection.return_value = orders_query
        mock_get_db.return_value = db

        client = Mock()
        client.queue_path.return_value = "projects/p/locations/l/queues/q"
        client.create_task.side_effect = [None, google_exceptions.AlreadyExists("duplicate"), RuntimeError("task failure")]
        mock_tasks_client_cls.return_value = client

        _dispatch_stale_orders()

        assert client.create_task.call_count == 3
        mock_capture.assert_called_once()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_server_timestamp", return_value="ts")
    @patch("handlers.cron_jobs.get_db")
    def test_auto_archive_old_orders_archives_only_non_archived(
        self, mock_get_db, _mock_ts, _mock_lock, mock_release
    ):
        from handlers.cron_jobs import auto_archive_old_orders

        already_archived = _snapshot("a1", {Fields.ARCHIVED: True})
        to_archive = _snapshot("a2", {Fields.ARCHIVED: False})
        orders_query = _query(stream_return=[already_archived, to_archive])

        batch = Mock()
        db = Mock()
        db.batch.return_value = batch
        db.collection.return_value = orders_query
        mock_get_db.return_value = db

        auto_archive_old_orders(Mock())

        batch.update.assert_called_once()
        batch.commit.assert_called_once()
        mock_release.assert_called_once_with("auto_archive_old_orders")

    @patch("services.algolia_service.get_index_stats", return_value=50)
    @patch("handlers.cron_jobs.get_db")
    def test_monitor_algolia_sync_creates_alert_on_mismatch(self, mock_get_db, _mock_stats):
        from handlers.cron_jobs import monitor_algolia_sync

        count_query = Mock()
        count_query.get.return_value = [[SimpleNamespace(value=100)]]
        products_query = Mock()
        products_query.count.return_value = count_query

        products_col = Mock()
        products_col.where.return_value = products_query

        alerts_query = _query(get_return=[])
        alerts_col = Mock()
        alerts_col.where.return_value = alerts_query

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.SECURITY_ALERTS: alerts_col,
        }[name]
        mock_get_db.return_value = db

        monitor_algolia_sync(Mock())
        alerts_col.add.assert_called_once()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_stale_rate_limits_deletes_with_pagination(self, mock_get_db, _mock_lock, mock_release):
        from handlers.cron_jobs import cleanup_stale_rate_limits

        stale_doc = _snapshot("rl1", {Fields.LAST_REQUEST: datetime.now(UTC) - timedelta(days=1)})
        q = _query(stream_side_effect=[[stale_doc], []])
        rate_limits_col = Mock()
        rate_limits_col.where.return_value = q

        batch = Mock()
        db = Mock()
        db.collection.return_value = rate_limits_col
        db.batch.return_value = batch
        mock_get_db.return_value = db

        cleanup_stale_rate_limits(Mock())

        batch.delete.assert_called_once_with(stale_doc.reference)
        batch.commit.assert_called_once()
        mock_release.assert_called_once_with("cleanup_stale_rate_limits")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("config.get_r2_credentials", return_value={"access_key": "ak", "secret_key": "sk", "account_id": "acc"})
    @patch("boto3.client")
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_orphaned_r2_images_deletes_unreferenced_keys(
        self, mock_get_db, mock_boto_client, _mock_creds, _mock_lock, mock_release
    ):
        from handlers.cron_jobs import cleanup_orphaned_r2_images

        product_doc = _snapshot("p1", {Fields.IMAGE_URLS: ["https://cdn.origna.ca/products/keep.jpg"]})
        product_query = _query(stream_side_effect=[[product_doc], []])
        products_col = Mock()
        products_col.select.return_value = product_query

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        mock_get_db.return_value = db

        s3 = Mock()
        s3.list_objects_v2.return_value = {
            "Contents": [
                {"Key": "products/keep.jpg", "LastModified": datetime.now(UTC) - timedelta(days=2)},
                {"Key": "products/orphan.jpg", "LastModified": datetime.now(UTC) - timedelta(days=2)},
            ],
            "IsTruncated": False,
        }
        mock_boto_client.return_value = s3

        cleanup_orphaned_r2_images(Mock())

        s3.delete_objects.assert_called_once()
        deleted_keys = [obj["Key"] for obj in s3.delete_objects.call_args.kwargs["Delete"]["Objects"]]
        assert deleted_keys == ["products/orphan.jpg"]
        mock_release.assert_called_once_with("cleanup_orphaned_r2_images")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_stale_webhook_events_deletes_docs(self, mock_get_db, _mock_lock, mock_release):
        from handlers.cron_jobs import cleanup_stale_webhook_events

        webhook_doc = _snapshot("we1", {Fields.TIMESTAMP: datetime.now(UTC) - timedelta(days=30)})
        webhook_query = _query(stream_return=[webhook_doc])
        webhook_col = Mock()
        webhook_col.where.return_value = webhook_query

        batch = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.WEBHOOK_EVENTS: webhook_col}[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        cleanup_stale_webhook_events(Mock())

        batch.delete.assert_called_once_with(webhook_doc.reference)
        batch.commit.assert_called_once()
        mock_release.assert_called_once_with("cleanup_stale_webhook_events")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_stale_security_alerts_deletes_resolved_docs(self, mock_get_db, _mock_lock, mock_release):
        from handlers.cron_jobs import cleanup_stale_security_alerts

        alert_doc = _snapshot("sa1", {Fields.RESOLVED: True, Fields.TIMESTAMP: datetime.now(UTC) - timedelta(days=120)})
        alerts_query = _query(stream_return=[alert_doc])
        alerts_col = Mock()
        alerts_col.where.return_value = alerts_query

        batch = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.SECURITY_ALERTS: alerts_col}[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        cleanup_stale_security_alerts(Mock())

        batch.delete.assert_called_once_with(alert_doc.reference)
        batch.commit.assert_called_once()
        mock_release.assert_called_once_with("cleanup_stale_security_alerts")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("services.algolia_service.index_product")
    @patch("services.algolia_service.delete_product")
    @patch("handlers.cron_jobs.get_server_timestamp", return_value="ts")
    @patch("handlers.cron_jobs.get_db")
    def test_retry_failed_algolia_syncs_handles_core_retry_paths(
        self,
        mock_get_db,
        _mock_ts,
        mock_algolia_delete,
        mock_algolia_index,
        _mock_lock,
        mock_release,
    ):
        from handlers.cron_jobs import retry_failed_algolia_syncs

        max_retries = BusinessRules.ALGOLIA_DLQ_MAX_RETRIES
        missing_pid = _snapshot("f1", {Fields.PRODUCT_ID: None})
        exceeded = _snapshot("f2", {Fields.PRODUCT_ID: "p2", Fields.RETRY_COUNT: max_retries})
        delete_ok = _snapshot("f3", {Fields.PRODUCT_ID: "p3", Fields.ACTION: AlgoliaActionValues.DELETE, Fields.RETRY_COUNT: 0})
        index_ok = _snapshot("f4", {Fields.PRODUCT_ID: "p4", Fields.ACTION: AlgoliaActionValues.INDEX, Fields.RETRY_COUNT: 0})
        index_fail = _snapshot("f5", {Fields.PRODUCT_ID: "p5", Fields.ACTION: AlgoliaActionValues.INDEX, Fields.RETRY_COUNT: 0})

        failures_query = _query(stream_return=[missing_pid, exceeded, delete_ok, index_ok, index_fail])
        failures_col = Mock()
        failures_col.where.return_value = failures_query

        def _product_doc(pid: str):
            if pid in ("p4", "p5"):
                return _snapshot(pid, {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}, exists=True)
            return _snapshot(pid, {}, exists=False)

        products_col = Mock()
        products_col.document.side_effect = lambda pid: SimpleNamespace(get=lambda: _product_doc(pid))

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ALGOLIA_SYNC_FAILURES: failures_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        def _index_side_effect(pid, _data):
            if pid == "p5":
                raise RuntimeError("index down")
            return None

        mock_algolia_index.side_effect = _index_side_effect

        retry_failed_algolia_syncs(Mock())

        mock_algolia_delete.assert_called_with("p3")
        mock_algolia_index.assert_any_call("p4", _product_doc("p4").to_dict())
        # Failed retry should increment counter
        assert index_fail.reference.update.called
        mock_release.assert_called_once_with("retry_failed_algolia_syncs")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("services.algolia_service.delete_product")
    @patch("handlers.products._send_product_rejection_email")
    @patch("handlers.products._get_seller_email", return_value="seller@example.com")
    @patch("requests.head")
    @patch("handlers.cron_jobs.get_db")
    def test_revalidate_digital_product_urls_deactivates_dead_links(
        self,
        mock_get_db,
        mock_head,
        _mock_get_email,
        mock_send_rejection,
        mock_algolia_delete,
        _mock_lock,
        mock_release,
    ):
        from handlers.cron_jobs import revalidate_digital_product_urls

        mock_head.return_value = SimpleNamespace(status_code=404)

        product_doc = _snapshot(
            "pd1",
            {
                Fields.IS_DIGITAL: True,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.BOOK_SOURCE_URL: "https://files.example.com/book.pdf",
                Fields.DIGITAL_BUILDS: {"windows": "https://files.example.com/win.exe"},
                Fields.SELLER_ID: "seller_1",
                Fields.NAME: "Digital Pack",
            },
        )
        products_query = _query(stream_return=[product_doc])
        products_col = Mock()
        products_col.where.return_value = products_query

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        mock_get_db.return_value = db

        revalidate_digital_product_urls(Mock())

        product_doc.reference.update.assert_called_once()
        mock_algolia_delete.assert_called_once_with("pd1")
        mock_send_rejection.assert_called_once()
        mock_release.assert_called_once_with("revalidate_digital_product_urls")

    @patch("services.email_task.enqueue_email_task")
    @patch("services.email_service._email_wrapper", return_value="<html>abandoned</html>")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_send_abandoned_cart_emails_sends_for_en_and_fr_users(
        self, mock_get_db, _mock_lock, mock_release, _mock_wrapper, mock_enqueue
    ):
        from handlers.cron_jobs import send_abandoned_cart_emails

        user_en = _snapshot(
            "u_en",
            {
                Fields.EMAIL: "en@example.com",
                Fields.EMAIL_CONSENT: True,
                Fields.MARKETING_OPT_IN: True,
                Fields.NAME: "Alice",
                Fields.PREFERRED_LANGUAGE: "en",
            },
        )
        user_fr = _snapshot(
            "u_fr",
            {
                Fields.EMAIL: "fr@example.com",
                Fields.EMAIL_CONSENT: True,
                Fields.MARKETING_OPT_IN: True,
                Fields.NAME: "Jean",
                Fields.PREFERRED_LANGUAGE: "fr",
            },
        )
        users_query = _query(stream_return=[user_en, user_fr])
        users_col = Mock()
        users_col.where.return_value = users_query

        cart_doc = _snapshot("cart_1", {Fields.PRODUCT_ID: "p1"})
        cart_query = _query(stream_return=[cart_doc])
        user_ref_en = Mock()
        user_ref_en.collection.return_value = cart_query
        user_ref_fr = Mock()
        user_ref_fr.collection.return_value = cart_query
        users_col.document.side_effect = lambda uid: {"u_en": user_ref_en, "u_fr": user_ref_fr}[uid]

        products_col = Mock()
        products_col.document.side_effect = lambda pid: SimpleNamespace(id=pid)
        active_product_doc = _snapshot(
            "p1",
            {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.STOCK_QUANTITY: 3,
                Fields.NAME: "Widget",
            },
            exists=True,
        )

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        db.get_all.return_value = [active_product_doc]
        mock_get_db.return_value = db

        send_abandoned_cart_emails(Mock())

        assert mock_enqueue.call_count == 2
        subjects = [c.kwargs["subject"] for c in mock_enqueue.call_args_list]
        assert any("You left something in your cart" in s for s in subjects)
        assert any("Votre panier vous attend" in s for s in subjects)
        user_ref_en.update.assert_called_once()
        user_ref_fr.update.assert_called_once()
        mock_release.assert_called_once_with("send_abandoned_cart_emails")

    @patch("services.email_task.enqueue_email_task")
    @patch("services.email_service._email_wrapper", return_value="<html>abandoned</html>")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_send_abandoned_cart_emails_skips_recent_naive_timestamps(
        self, mock_get_db, _mock_lock, mock_release, _mock_wrapper, mock_enqueue
    ):
        from handlers.cron_jobs import send_abandoned_cart_emails

        now_naive = datetime.now(UTC).replace(tzinfo=None)
        user_recent_abandon = _snapshot(
            "u_recent_abandon",
            {
                Fields.EMAIL: "a@example.com",
                Fields.EMAIL_CONSENT: True,
                Fields.MARKETING_OPT_IN: True,
                Fields.LAST_CART_ABANDON_EMAIL_AT: now_naive,
            },
        )
        user_recent_checkout = _snapshot(
            "u_recent_checkout",
            {
                Fields.EMAIL: "b@example.com",
                Fields.EMAIL_CONSENT: True,
                Fields.MARKETING_OPT_IN: True,
                Fields.LAST_CHECKOUT_TIMESTAMP: now_naive,
            },
        )
        users_query = _query(stream_return=[user_recent_abandon, user_recent_checkout])
        users_col = Mock()
        users_col.where.return_value = users_query
        users_col.document.side_effect = lambda uid: Mock()

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: Mock(),
        }[name]
        mock_get_db.return_value = db

        send_abandoned_cart_emails(Mock())

        mock_enqueue.assert_not_called()
        mock_release.assert_called_once_with("send_abandoned_cart_emails")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("db failed"))
    def test_send_abandoned_cart_emails_alerts_on_outer_failure(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import send_abandoned_cart_emails

        send_abandoned_cart_emails(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("send_abandoned_cart_emails")


class TestRunAutoCaptureEdgeBranches:
    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_skips_orders_without_payment_intent(self, mock_get_db, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_no_pi",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.ITEMS: [],
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_authorized_lock_conflict_skips_order(self, mock_get_db, mock_get_fs, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_lock_conflict",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_lock_conflict",
                Fields.ITEMS: [],
            },
        )
        # Transactional re-read shows status changed; lock returns False branch.
        order_doc.reference.get.return_value = _snapshot(
            "ord_lock_conflict",
            {Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db
        mock_get_fs.return_value = SimpleNamespace(transactional=lambda fn: fn)

        _run_auto_capture()

        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_auto_confirm_transaction_exception_is_handled(
        self, mock_get_db, mock_get_fs, _mock_enabled
    ):
        from handlers.cron_jobs import _run_auto_capture

        old_ts = datetime.now(UTC) - timedelta(days=BusinessRules.AUTO_CONFIRM_DAYS + 2)
        order_doc = _snapshot(
            "ord_auto_confirm_err",
            {
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_auto_confirm_err",
                Fields.ITEMS: [{Fields.STATUS: DeliveryStatusValues.SHIPPED, Fields.SHIPPED_AT: old_ts}],
            },
        )
        order_doc.reference.get.side_effect = RuntimeError("tx read failed")

        delivered_q = _query(stream_return=[])
        shipped_q = _query(stream_return=[order_doc])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_col = Mock()
        alerts_col.where.return_value = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = _query(get_return=[])

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
        }[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db
        mock_get_fs.return_value = SimpleNamespace(transactional=lambda fn: fn)

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_auto_confirm_none_claim_skips_order(
        self, mock_get_db, mock_get_fs, _mock_enabled
    ):
        from handlers.cron_jobs import _run_auto_capture

        old_ts = datetime.now(UTC) - timedelta(days=BusinessRules.AUTO_CONFIRM_DAYS + 2)
        order_doc = _snapshot(
            "ord_auto_confirm_skip",
            {
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_auto_confirm_skip",
                Fields.ITEMS: [{Fields.STATUS: DeliveryStatusValues.SHIPPED, Fields.SHIPPED_AT: old_ts}],
            },
        )
        order_doc.reference.get.return_value = _snapshot(
            "ord_auto_confirm_skip",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.ITEMS: [],
            },
        )

        delivered_q = _query(stream_return=[])
        shipped_q = _query(stream_return=[order_doc])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_col = Mock()
        alerts_col.where.return_value = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = _query(get_return=[])

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
        }[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db
        mock_get_fs.return_value = SimpleNamespace(transactional=lambda fn: fn)

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.IS_EMULATOR", False)
    @patch("handlers.cron_jobs.get_server_timestamp", return_value="ts")
    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_capture_error_reverts_status_to_authorized(
        self,
        mock_get_db,
        mock_get_fs,
        _mock_ts,
        mock_capture,
        _mock_enabled,
    ):
        import handlers.cron_jobs as cron

        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_capture_err",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_capture_err",
                Fields.ITEMS: [],
            },
        )
        # Lock succeeds (still authorized in fresh read)
        order_doc.reference.get.return_value = _snapshot(
            "ord_capture_err",
            {Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED},
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db
        mock_get_fs.return_value = SimpleNamespace(transactional=lambda fn: fn)

        with patch(
            "handlers.cron_jobs.stripe.PaymentIntent.retrieve",
            side_effect=cron.stripe.error.StripeError("retrieve failed"),
        ):
            _run_auto_capture()

        # First update: lock to CAPTURING; second: revert to AUTHORIZED on capture failure.
        assert order_doc.reference.update.call_count >= 1
        assert any(
            c.args
            and isinstance(c.args[0], dict)
            and c.args[0].get(Fields.PAYMENT_STATUS) == PaymentStatusValues.AUTHORIZED
            for c in order_doc.reference.update.call_args_list
        )
        mock_capture.assert_called_once()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_skips_order_with_active_dispute(self, mock_get_db, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_dispute",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_dispute",
                Fields.ITEMS: [],
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_q = _query(get_return=[_snapshot("alert_1", {})])
        alerts_col = Mock()
        alerts_col.where.return_value = alerts_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
        }[name]
        mock_get_db.return_value = db

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_authorized_lock_exception_skips_order(self, mock_get_db, mock_get_fs, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_lock_err",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_lock_err",
                Fields.ITEMS: [],
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        db.transaction.side_effect = RuntimeError("tx failed")
        mock_get_db.return_value = db
        mock_get_fs.return_value = SimpleNamespace(transactional=lambda fn: fn)

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.IS_EMULATOR", False)
    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_authorized_unexpected_pi_status_skips(self, mock_get_db, mock_get_fs, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_pi_weird",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_weird",
                Fields.ITEMS: [],
            },
        )
        order_doc.reference.get.return_value = _snapshot("ord_pi_weird", {Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED})

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db
        mock_get_fs.return_value = SimpleNamespace(transactional=lambda fn: fn)

        with patch("handlers.cron_jobs.stripe.PaymentIntent.retrieve", return_value=SimpleNamespace(status="requires_action")):
            _run_auto_capture()

        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_skips_when_dispute_lookup_fails(self, mock_get_db, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_dispute_err",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_dispute_err",
                Fields.ITEMS: [],
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_q = _query()
        alerts_q.get.side_effect = RuntimeError("alerts query failed")
        alerts_col = Mock()
        alerts_col.where.return_value = alerts_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
        }[name]
        mock_get_db.return_value = db

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.IS_EMULATOR", False)
    @patch("handlers.cron_jobs.get_server_timestamp", return_value="ts")
    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_authorized_requires_capture_success_and_no_sellers_marks_failed_payout(
        self, mock_get_db, mock_get_fs, _mock_ts, _mock_enabled
    ):
        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_cap_ok",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_cap_ok",
                Fields.ITEMS: [],
            },
        )
        order_doc.reference.get.return_value = _snapshot("ord_cap_ok", {Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED})

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_col = Mock()
        alerts_col.where.return_value = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = _query(get_return=[])

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
        }[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db
        mock_get_fs.return_value = SimpleNamespace(transactional=lambda fn: fn)

        with (
            patch("handlers.cron_jobs.stripe.PaymentIntent.retrieve", return_value=SimpleNamespace(status="requires_capture")),
            patch("handlers.cron_jobs.stripe.PaymentIntent.capture", return_value=SimpleNamespace(status="succeeded")),
        ):
            _run_auto_capture()

        assert any(
            c.args and isinstance(c.args[0], dict) and c.args[0].get(Fields.PAYMENT_STATUS) == PaymentStatusValues.CAPTURED
            for c in order_doc.reference.update.call_args_list
        )
        assert any(
            c.args and isinstance(c.args[0], dict) and c.args[0].get(Fields.PAYOUT_STATUS) == PayoutStatusValues.FAILED
            for c in order_doc.reference.update.call_args_list
        )

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_skips_when_active_return_exists(self, mock_get_db, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_return_block",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_return_block",
                Fields.ITEMS: [],
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_col = Mock()
        alerts_col.where.return_value = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = _query(get_return=[_snapshot("ret_1", {})])

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
        }[name]
        mock_get_db.return_value = db

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()


class TestCronCleanupExtraBranches:
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_cleanup_stale_rate_limits_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import cleanup_stale_rate_limits

        cleanup_stale_rate_limits(Mock())
        mock_release.assert_not_called()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_stale_rate_limits_commits_every_500(self, mock_get_db, _mock_lock, mock_release):
        from handlers.cron_jobs import cleanup_stale_rate_limits

        docs = [_snapshot(f"rl_{i}", {Fields.LAST_REQUEST: datetime.now(UTC) - timedelta(days=2)}) for i in range(500)]
        q = _query(stream_side_effect=[docs, []])
        rate_limits_col = Mock()
        rate_limits_col.where.return_value = q

        batch = Mock()
        db = Mock()
        db.collection.return_value = rate_limits_col
        db.batch.return_value = batch
        mock_get_db.return_value = db

        cleanup_stale_rate_limits(Mock())

        batch.commit.assert_called_once()
        mock_release.assert_called_once_with("cleanup_stale_rate_limits")

    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_stale_rate_limits_handles_item_delete_error(
        self, mock_get_db, _mock_lock, mock_release, mock_capture
    ):
        from handlers.cron_jobs import cleanup_stale_rate_limits

        stale_doc = _snapshot("rl_err", {Fields.LAST_REQUEST: datetime.now(UTC) - timedelta(days=1)})
        q = _query(stream_side_effect=[[stale_doc], []])
        rate_limits_col = Mock()
        rate_limits_col.where.return_value = q

        batch = Mock()
        batch.delete.side_effect = RuntimeError("delete failed")

        db = Mock()
        db.collection.return_value = rate_limits_col
        db.batch.return_value = batch
        mock_get_db.return_value = db

        cleanup_stale_rate_limits(Mock())

        mock_capture.assert_called_once()
        mock_release.assert_called_once_with("cleanup_stale_rate_limits")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("db failed"))
    def test_cleanup_stale_rate_limits_alerts_on_outer_failure(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import cleanup_stale_rate_limits

        cleanup_stale_rate_limits(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("cleanup_stale_rate_limits")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_cleanup_orphaned_r2_images_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import cleanup_orphaned_r2_images

        cleanup_orphaned_r2_images(Mock())
        mock_release.assert_not_called()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("config.get_r2_credentials", return_value={"access_key": "", "secret_key": "", "account_id": ""})
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_orphaned_r2_images_missing_creds_returns_early(
        self, mock_get_db, _mock_creds, _mock_lock, mock_release
    ):
        from handlers.cron_jobs import cleanup_orphaned_r2_images

        product_doc = _snapshot("p1", {Fields.IMAGE_URLS: ["https://cdn.origna.ca/products/a.jpg"]})
        product_query = _query(stream_side_effect=[[product_doc], []])
        products_col = Mock()
        products_col.select.return_value = product_query

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        mock_get_db.return_value = db

        cleanup_orphaned_r2_images(Mock())
        mock_release.assert_called_once_with("cleanup_orphaned_r2_images")

    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("config.get_r2_credentials", return_value={"access_key": "", "secret_key": "", "account_id": ""})
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_orphaned_r2_images_handles_product_parse_error(
        self, mock_get_db, _mock_creds, _mock_lock, mock_release, mock_capture
    ):
        from handlers.cron_jobs import cleanup_orphaned_r2_images

        bad_doc = _snapshot("p_bad", {})
        bad_doc.to_dict.side_effect = RuntimeError("bad product doc")
        product_query = _query(stream_side_effect=[[bad_doc], []])
        products_col = Mock()
        products_col.select.return_value = product_query

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        mock_get_db.return_value = db

        cleanup_orphaned_r2_images(Mock())
        mock_capture.assert_called_once()
        mock_release.assert_called_once_with("cleanup_orphaned_r2_images")

    @patch("services.algolia_service.get_index_stats", return_value=95)
    @patch("handlers.cron_jobs.get_db")
    def test_monitor_algolia_sync_healthy_and_exception_paths(self, mock_get_db, _mock_stats):
        from handlers.cron_jobs import monitor_algolia_sync

        # Healthy path (mismatch below threshold)
        count_query = Mock()
        count_query.get.return_value = [[SimpleNamespace(value=100)]]
        products_query = Mock()
        products_query.count.return_value = count_query
        products_col = Mock()
        products_col.where.return_value = products_query

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.SECURITY_ALERTS: Mock(),
        }[name]
        mock_get_db.return_value = db
        monitor_algolia_sync(Mock())

        # Exception path
        count_query.get.side_effect = RuntimeError("count failed")
        monitor_algolia_sync(Mock())

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_cleanup_stale_webhook_events_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import cleanup_stale_webhook_events

        cleanup_stale_webhook_events(Mock())
        mock_release.assert_not_called()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_cleanup_stale_security_alerts_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import cleanup_stale_security_alerts

        cleanup_stale_security_alerts(Mock())
        mock_release.assert_not_called()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_retry_failed_algolia_syncs_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import retry_failed_algolia_syncs

        retry_failed_algolia_syncs(Mock())
        mock_release.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_skips_when_return_lookup_fails(self, mock_get_db, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_return_err",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_return_err",
                Fields.ITEMS: [],
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_col = Mock()
        alerts_col.where.return_value = _query(get_return=[])

        returns_q = _query()
        returns_q.get.side_effect = RuntimeError("returns down")
        returns_col = Mock()
        returns_col.where.return_value = returns_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
        }[name]
        mock_get_db.return_value = db

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_skips_when_latest_item_timestamp_is_too_recent(self, mock_get_db, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        recent_ts = datetime.now(UTC)
        order_doc = _snapshot(
            "ord_recent_item",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_recent_item",
                Fields.ITEMS: [
                    {Fields.STATUS: DeliveryStatusValues.DELIVERED, Fields.DELIVERED_AT: "invalid-iso"},
                    {Fields.STATUS: DeliveryStatusValues.DELIVERED, Fields.DELIVERED_AT: recent_ts},
                ],
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_col = Mock()
        alerts_col.where.return_value = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = _query(get_return=[])

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
        }[name]
        mock_get_db.return_value = db

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_server_timestamp", return_value="ts")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_existing_completed_payout_skips_transfer(self, mock_get_db, _mock_ts, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        old_ts = datetime.now(UTC) - timedelta(days=BusinessRules.AUTO_CONFIRM_DAYS + 5)
        order_doc = _snapshot(
            "ord_existing_payout",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_existing",
                Fields.ITEMS: [
                    {
                        Fields.SELLER_ID: "seller_1",
                        Fields.STATUS: DeliveryStatusValues.DELIVERED,
                        Fields.PRICE: 10.0,
                        Fields.QUANTITY: 1,
                        Fields.DELIVERED_AT: old_ts,
                    }
                ],
                Fields.SELLER_STRIPE_ACCOUNTS: {"seller_1": "acct_1"},
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_col = Mock()
        alerts_col.where.return_value = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = _query(get_return=[])

        existing_payout_doc = _snapshot("ord_existing_payout_seller_1", {Fields.STATUS: PayoutStatusValues.COMPLETED})
        existing_payout_doc.reference = Mock()
        payouts_q = _query(get_return=[existing_payout_doc])
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        users_col = Mock()
        users_col.document.side_effect = lambda sid: SimpleNamespace(id=sid)
        sp_col = Mock()
        sp_col.document.side_effect = lambda sid: SimpleNamespace(id=sid)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: sp_col,
        }[name]
        db.get_all.side_effect = [
            [_snapshot("seller_1", {Fields.SUSPENDED: False})],
            [_snapshot("seller_1", {Fields.CHARGES_ENABLED: True})],
        ]
        mock_get_db.return_value = db

        with (
            patch("handlers.cron_jobs.stripe.PaymentIntent.retrieve", return_value=SimpleNamespace(latest_charge="ch_1")),
            patch("handlers.cron_jobs.stripe.Transfer.create") as mock_transfer,
        ):
            _run_auto_capture()

        mock_transfer.assert_not_called()
        assert any(
            c.args and isinstance(c.args[0], dict) and c.args[0].get(Fields.PAYOUT_STATUS) == PayoutStatusValues.COMPLETED
            for c in order_doc.reference.update.call_args_list
        )

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_firestore")
    @patch("models.order_event.OrderEvent.write")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_shipped_auto_confirm_then_no_charge_marks_manual_review_and_failed(
        self, mock_get_db, _mock_event_write, mock_get_fs, _mock_enabled
    ):
        from handlers.cron_jobs import _run_auto_capture

        old_ts = datetime.now(UTC) - timedelta(days=BusinessRules.AUTO_CONFIRM_DAYS + 3)
        order_doc = _snapshot(
            "ord_ship_auto",
            {
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_ship_auto",
                Fields.ITEMS: [
                    {
                        Fields.SELLER_ID: "seller_auto",
                        Fields.STATUS: DeliveryStatusValues.SHIPPED,
                        Fields.PRICE: 20.0,
                        Fields.QUANTITY: 1,
                        Fields.SHIPPED_AT: old_ts,
                    }
                ],
                Fields.SELLER_STRIPE_ACCOUNTS: {},
            },
        )
        order_doc.reference.get.return_value = _snapshot(
            "ord_ship_auto",
            {
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.ITEMS: [
                    {
                        Fields.SELLER_ID: "seller_auto",
                        Fields.STATUS: DeliveryStatusValues.SHIPPED,
                        Fields.PRICE: 20.0,
                        Fields.QUANTITY: 1,
                    }
                ],
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_ship_auto",
            },
        )

        delivered_q = _query(stream_return=[])
        shipped_q = _query(stream_return=[order_doc])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_q = _query(get_return=[])
        alerts_col = Mock()
        alerts_col.where.return_value = alerts_q

        returns_q = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = returns_q

        payouts_lookup_q = _query(get_return=[])
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_lookup_q
        payouts_col.document.return_value = Mock()

        users_col = Mock()
        users_col.document.side_effect = lambda sid: SimpleNamespace(id=sid, _kind="user")
        sp_col = Mock()
        sp_col.document.side_effect = lambda sid: SimpleNamespace(id=sid, _kind="sp")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: sp_col,
        }[name]
        db.transaction.return_value = Mock()

        def _get_all(refs):
            out = []
            for ref in refs:
                if ref._kind == "user":
                    out.append(_snapshot(ref.id, {Fields.SUSPENDED: False}, exists=True))
                else:
                    out.append(
                        _snapshot(
                            ref.id,
                            {Fields.CHARGES_ENABLED: True, Fields.STRIPE_ACCOUNT_ID: "acct_auto"},
                            exists=True,
                        )
                    )
            return out

        db.get_all.side_effect = _get_all
        mock_get_db.return_value = db
        mock_get_fs.return_value = SimpleNamespace(transactional=lambda fn: fn)

        with (
            patch("handlers.cron_jobs.stripe.PaymentIntent.retrieve", return_value=SimpleNamespace(latest_charge=None)),
            patch("utils.helpers.get_charge_id_from_pi", return_value=None),
        ):
            _run_auto_capture()

        assert any(
            c.args
            and isinstance(c.args[0], dict)
            and c.args[0].get(Fields.MANUAL_REVIEW_REASON, "").startswith("No charge ID found")
            for c in order_doc.reference.update.call_args_list
        )
        assert any(
            c.args
            and isinstance(c.args[0], dict)
            and c.args[0].get(Fields.PAYOUT_STATUS) == PayoutStatusValues.FAILED
            for c in order_doc.reference.update.call_args_list
        )

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_outer_stripe_error_sets_failed_status(
        self, mock_get_db, mock_capture, _mock_enabled
    ):
        import handlers.cron_jobs as cron

        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_outer_stripe",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_outer",
                Fields.ITEMS: [],
            },
        )
        order_doc.reference.update.side_effect = [
            cron.stripe.error.StripeError("set processing failed"),
            None,
        ]

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_q = _query(get_return=[])
        alerts_col = Mock()
        alerts_col.where.return_value = alerts_q

        returns_q = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = returns_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
        }[name]
        mock_get_db.return_value = db

        _run_auto_capture()

        assert any(
            c.args
            and isinstance(c.args[0], dict)
            and c.args[0].get(Fields.PAYOUT_STATUS) == PayoutStatusValues.FAILED
            for c in order_doc.reference.update.call_args_list
        )
        mock_capture.assert_called_once()


class TestReturnEscalationCron:
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_escalate_stale_return_requests_skips_when_lock_is_held(self, _mock_lock, mock_release):
        from handlers.cron_jobs import escalate_stale_return_requests

        escalate_stale_return_requests(Mock())
        mock_release.assert_not_called()

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs._run_return_escalation", side_effect=RuntimeError("boom"))
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    def test_escalate_stale_return_requests_alerts_and_releases_on_error(
        self, _mock_lock, _mock_run, mock_release, mock_alert
    ):
        from handlers.cron_jobs import escalate_stale_return_requests

        escalate_stale_return_requests(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("escalate_stale_return_requests")

    @patch("services.push_service.send_push_notification")
    @patch("handlers.cron_jobs.get_db")
    def test_run_return_escalation_escalates_and_notifies_buyer_and_admins(self, mock_get_db, mock_push):
        from handlers.cron_jobs import _run_return_escalation

        return_doc = _snapshot(
            "ret_1",
            {
                Fields.ORDER_ID: "ord_12345",
                Fields.BUYER_ID: "buyer_1",
            },
        )
        stale_query = _query(stream_return=[return_doc])
        returns_col = Mock()
        returns_col.where.return_value = stale_query

        admin_doc = _snapshot("admin_1", {})
        admin_query = _query(stream_return=[admin_doc])
        users_col = Mock()
        users_col.where.return_value = admin_query

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.RETURN_REQUESTS: returns_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        _run_return_escalation()

        return_doc.reference.update.assert_called_once()
        assert mock_push.call_count == 2
        recipient_ids = [c.args[0] for c in mock_push.call_args_list]
        assert "buyer_1" in recipient_ids
        assert "admin_1" in recipient_ids

    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("services.push_service.send_push_notification")
    @patch("handlers.cron_jobs.get_db")
    def test_run_return_escalation_prefetch_and_update_failures_are_handled(
        self, mock_get_db, mock_push, mock_capture
    ):
        from handlers.cron_jobs import _run_return_escalation

        broken_return = _snapshot("ret_2", {Fields.ORDER_ID: "ord_2", Fields.BUYER_ID: "buyer_2"})
        broken_return.reference.update.side_effect = RuntimeError("update failed")
        stale_query = _query(stream_return=[broken_return])
        returns_col = Mock()
        returns_col.where.return_value = stale_query

        users_col = Mock()
        users_col.where.side_effect = RuntimeError("admin prefetch failed")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.RETURN_REQUESTS: returns_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        _run_return_escalation()

        mock_capture.assert_called_once()
        mock_push.assert_not_called()

    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.get_db")
    def test_run_return_escalation_handles_query_failure(self, mock_get_db, mock_capture):
        from handlers.cron_jobs import _run_return_escalation

        stale_query = _query(stream_side_effect=RuntimeError("query failed"))
        returns_col = Mock()
        returns_col.where.return_value = stale_query

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.RETURN_REQUESTS: returns_col}[name]
        mock_get_db.return_value = db

        _run_return_escalation()
        mock_capture.assert_called_once()

    @patch("services.push_service.send_push_notification", side_effect=RuntimeError("push failed"))
    @patch("handlers.cron_jobs.get_db")
    def test_run_return_escalation_buyer_and_admin_push_failures_are_swallowed(self, mock_get_db, _mock_push):
        from handlers.cron_jobs import _run_return_escalation

        return_doc = _snapshot(
            "ret_push_fail",
            {
                Fields.ORDER_ID: "ord_push_fail",
                Fields.BUYER_ID: "buyer_1",
            },
        )
        stale_query = _query(stream_return=[return_doc])
        returns_col = Mock()
        returns_col.where.return_value = stale_query

        admin_doc = _snapshot("admin_1", {})
        admin_query = _query(stream_return=[admin_doc])
        users_col = Mock()
        users_col.where.return_value = admin_query

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.RETURN_REQUESTS: returns_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        _run_return_escalation()
        return_doc.reference.update.assert_called_once()


class TestStaleOrdersDispatcherEdges:
    @patch.dict("os.environ", {}, clear=True)
    def test_dispatch_stale_orders_raises_when_required_env_missing(self):
        from handlers.cron_jobs import _dispatch_stale_orders

        with patch("handlers.cron_jobs.get_db"):
            try:
                _dispatch_stale_orders()
                assert False, "Expected ValueError for missing env"
            except ValueError:
                pass

    @patch.dict(
        "os.environ",
        {"STALE_ORDER_WORKER_URL": "https://worker.example.com", "TASK_HANDLER_SA_EMAIL": "tasks@example.iam.gserviceaccount.com"},
        clear=True,
    )
    @patch("handlers.cron_jobs.tasks_v2.CloudTasksClient")
    @patch("handlers.cron_jobs.get_db")
    def test_dispatch_stale_orders_returns_when_no_orders(self, mock_get_db, mock_tasks_client_cls):
        from handlers.cron_jobs import _dispatch_stale_orders

        orders_query = _query(stream_return=[])
        mock_get_db.return_value.collection.return_value = orders_query

        _dispatch_stale_orders()
        mock_tasks_client_cls.assert_not_called()


class TestCronResidualCoverage:
    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_skips_when_order_payout_already_completed(self, mock_get_db, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        order_doc = _snapshot(
            "ord_done_payout",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.PAYOUT_STATUS: PayoutStatusValues.COMPLETED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_done",
                Fields.ITEMS: [],
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_firestore")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_shipped_transaction_missing_doc_path(self, mock_get_db, mock_get_fs, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        old_ts = datetime.now(UTC) - timedelta(days=BusinessRules.AUTO_CONFIRM_DAYS + 2)
        order_doc = _snapshot(
            "ord_missing_after_lock",
            {
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_missing_after_lock",
                Fields.ITEMS: [{Fields.STATUS: DeliveryStatusValues.SHIPPED, Fields.SHIPPED_AT: old_ts}],
            },
        )
        order_doc.reference.get.return_value = _snapshot("ord_missing_after_lock", exists=False)

        delivered_q = _query(stream_return=[])
        shipped_q = _query(stream_return=[order_doc])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_col = Mock()
        alerts_col.where.return_value = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = _query(get_return=[])

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
        }[name]
        mock_get_db.return_value = db
        mock_get_fs.return_value = SimpleNamespace(transactional=lambda fn: fn)

        _run_auto_capture()
        order_doc.reference.update.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.get_server_timestamp", return_value="ts")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_suspended_seller_and_pi_retrieve_error_paths(
        self, mock_get_db, _mock_ts, mock_capture, _mock_enabled
    ):
        import handlers.cron_jobs as cron

        from handlers.cron_jobs import _run_auto_capture

        old_ts = datetime.now(UTC) - timedelta(days=BusinessRules.AUTO_CONFIRM_DAYS + 3)
        order_doc = _snapshot(
            "ord_suspended",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_suspended",
                Fields.ITEMS: [
                    {
                        Fields.SELLER_ID: "seller_suspended",
                        Fields.STATUS: DeliveryStatusValues.DELIVERED,
                        Fields.PRICE: 10.0,
                        Fields.QUANTITY: 1,
                        Fields.DELIVERED_AT: old_ts,
                    }
                ],
                Fields.SELLER_STRIPE_ACCOUNTS: {"seller_suspended": "acct_suspended"},
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_col = Mock()
        alerts_col.where.return_value = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = _query(get_return=[])

        users_col = Mock()
        users_col.document.side_effect = lambda sid: SimpleNamespace(id=sid, _kind="user")
        sp_col = Mock()
        sp_col.document.side_effect = lambda sid: SimpleNamespace(id=sid, _kind="sp")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: sp_col,
            Collections.PAYOUTS: Mock(),
        }[name]
        db.get_all.side_effect = [
            [_snapshot("seller_suspended", {Fields.SUSPENDED: True}, exists=True)],
            [_snapshot("seller_suspended", {Fields.CHARGES_ENABLED: True}, exists=True)],
        ]
        mock_get_db.return_value = db

        with patch(
            "handlers.cron_jobs.stripe.PaymentIntent.retrieve",
            side_effect=cron.stripe.error.StripeError("pi down"),
        ):
            _run_auto_capture()

        assert any(
            c.args
            and isinstance(c.args[0], dict)
            and c.args[0].get(Fields.MANUAL_REVIEW_REASON, "").endswith("suspended at auto-capture")
            for c in order_doc.reference.update.call_args_list
        )
        mock_capture.assert_not_called()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.get_server_timestamp", return_value="ts")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_partial_payout_with_fallback_failed_record(
        self, mock_get_db, _mock_ts, _mock_enabled
    ):
        import handlers.cron_jobs as cron

        from handlers.cron_jobs import _run_auto_capture

        old_ts = datetime.now(UTC) - timedelta(days=BusinessRules.AUTO_CONFIRM_DAYS + 4)
        order_doc = _snapshot(
            "ord_partial_payout",
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_partial_payout",
                Fields.ITEMS: [
                    {
                        Fields.SELLER_ID: "seller_ok",
                        Fields.STATUS: DeliveryStatusValues.DELIVERED,
                        Fields.PRICE: 12.0,
                        Fields.QUANTITY: 1,
                        Fields.DELIVERED_AT: old_ts,
                    },
                    {
                        Fields.SELLER_ID: "seller_fail",
                        Fields.STATUS: DeliveryStatusValues.DELIVERED,
                        Fields.PRICE: 8.0,
                        Fields.QUANTITY: 1,
                        Fields.DELIVERED_AT: old_ts,
                    },
                ],
                Fields.SELLER_STRIPE_ACCOUNTS: {"seller_ok": "acct_ok", "seller_fail": "acct_fail"},
            },
        )

        delivered_q = _query(stream_return=[order_doc])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        alerts_col = Mock()
        alerts_col.where.return_value = _query(get_return=[])
        returns_col = Mock()
        returns_col.where.return_value = _query(get_return=[])

        users_col = Mock()
        users_col.document.side_effect = lambda sid: SimpleNamespace(id=sid, _kind="user")
        sp_col = Mock()
        sp_col.document.side_effect = lambda sid: SimpleNamespace(id=sid, _kind="sp")

        payout_ref_ok = Mock()
        payout_ref_fail = Mock()
        payout_ref_fail.update.side_effect = RuntimeError("failed status write")

        payouts_lookup_q = _query(get_return=[])
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_lookup_q
        payouts_col.document.side_effect = lambda doc_id: (
            payout_ref_fail if doc_id.endswith("_seller_fail") else payout_ref_ok
        )
        payouts_col.add = Mock()

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: alerts_col,
            Collections.RETURN_REQUESTS: returns_col,
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: sp_col,
            Collections.PAYOUTS: payouts_col,
        }[name]
        db.get_all.side_effect = [
            [
                _snapshot("seller_ok", {Fields.SUSPENDED: False}, exists=True),
                _snapshot("seller_fail", {Fields.SUSPENDED: False}, exists=True),
            ],
            [
                _snapshot("seller_ok", {Fields.CHARGES_ENABLED: True}, exists=True),
                _snapshot("seller_fail", {Fields.CHARGES_ENABLED: True}, exists=True),
            ],
        ]
        mock_get_db.return_value = db

        def _transfer_side_effect(**kwargs):
            if kwargs.get("destination") == "acct_fail":
                raise cron.stripe.error.StripeError("transfer failed")
            return SimpleNamespace(id="tr_ok")

        with (
            patch("handlers.cron_jobs.stripe.PaymentIntent.retrieve", return_value=SimpleNamespace(latest_charge="ch_1")),
            patch("handlers.cron_jobs.stripe.Transfer.create", side_effect=_transfer_side_effect),
        ):
            _run_auto_capture()

        payouts_col.add.assert_called_once()
        assert any(
            c.args and isinstance(c.args[0], dict) and c.args[0].get(Fields.PAYOUT_STATUS) == PayoutStatusValues.PARTIAL
            for c in order_doc.reference.update.call_args_list
        )

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.get_db")
    def test_run_auto_capture_outer_loop_exception_is_captured(self, mock_get_db, mock_capture, _mock_enabled):
        from handlers.cron_jobs import _run_auto_capture

        bad_order = _snapshot("ord_bad_loop", {})
        bad_order.to_dict.side_effect = RuntimeError("broken order doc")

        delivered_q = _query(stream_return=[bad_order])
        shipped_q = _query(stream_return=[])
        orders_col = Mock()
        orders_col.where.side_effect = [delivered_q, shipped_q]

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        _run_auto_capture()
        mock_capture.assert_called_once()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_auto_archive_old_orders_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import auto_archive_old_orders

        auto_archive_old_orders(Mock())
        mock_release.assert_not_called()

    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_auto_archive_old_orders_batch_commit_and_item_error_paths(
        self, mock_get_db, _mock_lock, mock_release, mock_capture
    ):
        from handlers.cron_jobs import auto_archive_old_orders

        docs = [_snapshot(f"ord_{i}", {Fields.ARCHIVED: False}) for i in range(500)]
        bad_doc = _snapshot("ord_bad_archive", {})
        bad_doc.to_dict.side_effect = RuntimeError("bad order payload")
        orders_q = _query(stream_return=docs + [bad_doc])

        orders_col = Mock()
        orders_col.where.return_value = orders_q

        batch = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        auto_archive_old_orders(Mock())

        assert batch.commit.call_count >= 1
        mock_capture.assert_called_once()
        mock_release.assert_called_once_with("auto_archive_old_orders")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("archive db failed"))
    def test_auto_archive_old_orders_alerts_on_outer_failure(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import auto_archive_old_orders

        auto_archive_old_orders(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("auto_archive_old_orders")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("config.get_r2_credentials", return_value={"access_key": "ak", "secret_key": "sk", "account_id": "acct"})
    @patch("boto3.client")
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_orphaned_r2_images_pagination_recent_skip_and_delete_error(
        self, mock_get_db, mock_boto_client, _mock_creds, _mock_lock, mock_release
    ):
        from handlers.cron_jobs import cleanup_orphaned_r2_images

        product_doc = _snapshot("p_ref", {Fields.IMAGE_URLS: ["https://cdn.origna.ca/products/keep.jpg"]})
        product_query = _query(stream_side_effect=[[product_doc], []])
        products_col = Mock()
        products_col.select.return_value = product_query

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        mock_get_db.return_value = db

        client = Mock()
        now = datetime.now(UTC)
        client.list_objects_v2.side_effect = [
            {
                "Contents": [
                    {"Key": "products/keep.jpg", "LastModified": now - timedelta(days=3)},
                    {"Key": "products/recent.jpg", "LastModified": now},
                ],
                "IsTruncated": True,
                "NextContinuationToken": "next_token",
            },
            {
                "Contents": [{"Key": "products/orphan.jpg", "LastModified": now - timedelta(days=3)}],
                "IsTruncated": False,
            },
        ]
        client.delete_objects.side_effect = RuntimeError("delete failed")
        mock_boto_client.return_value = client

        cleanup_orphaned_r2_images(Mock())

        second_call_kwargs = client.list_objects_v2.call_args_list[1].kwargs
        assert second_call_kwargs["ContinuationToken"] == "next_token"
        client.delete_objects.assert_called_once()
        mock_release.assert_called_once_with("cleanup_orphaned_r2_images")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("config.get_r2_credentials", return_value={"access_key": "ak", "secret_key": "sk", "account_id": "acct"})
    @patch("boto3.client")
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_orphaned_r2_images_handles_list_error(
        self, mock_get_db, mock_boto_client, _mock_creds, _mock_lock, mock_release
    ):
        from handlers.cron_jobs import cleanup_orphaned_r2_images

        product_doc = _snapshot("p_ref", {Fields.IMAGE_URLS: []})
        product_query = _query(stream_side_effect=[[product_doc], []])
        products_col = Mock()
        products_col.select.return_value = product_query

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        mock_get_db.return_value = db

        client = Mock()
        client.list_objects_v2.side_effect = RuntimeError("list failed")
        mock_boto_client.return_value = client

        cleanup_orphaned_r2_images(Mock())
        mock_release.assert_called_once_with("cleanup_orphaned_r2_images")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("r2 outer fail"))
    def test_cleanup_orphaned_r2_images_alerts_on_outer_failure(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import cleanup_orphaned_r2_images

        cleanup_orphaned_r2_images(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("cleanup_orphaned_r2_images")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_stale_webhook_events_commit_and_item_error_paths(
        self, mock_get_db, mock_capture, _mock_lock, mock_release
    ):
        from handlers.cron_jobs import cleanup_stale_webhook_events

        docs = [_snapshot(f"wh_{i}", {}) for i in range(500)]
        bad_doc = _snapshot("wh_bad", {})
        webhook_docs = docs + [bad_doc]
        webhooks_q = _query(stream_return=webhook_docs)
        webhooks_col = Mock()
        webhooks_col.where.return_value = webhooks_q

        batch = Mock()
        batch.delete.side_effect = [None] * 500 + [RuntimeError("delete failed")]

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.WEBHOOK_EVENTS: webhooks_col}[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        cleanup_stale_webhook_events(Mock())
        assert batch.commit.call_count >= 1
        mock_capture.assert_called_once()
        mock_release.assert_called_once_with("cleanup_stale_webhook_events")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("webhook cleanup fail"))
    def test_cleanup_stale_webhook_events_outer_failure_alerts(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import cleanup_stale_webhook_events

        cleanup_stale_webhook_events(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("cleanup_stale_webhook_events")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.sentry_sdk.capture_exception")
    @patch("handlers.cron_jobs.get_db")
    def test_cleanup_stale_security_alerts_commit_and_item_error_paths(
        self, mock_get_db, mock_capture, _mock_lock, mock_release
    ):
        from handlers.cron_jobs import cleanup_stale_security_alerts

        docs = [_snapshot(f"sa_{i}", {}) for i in range(500)]
        bad_doc = _snapshot("sa_bad", {})
        alerts_q = _query(stream_return=docs + [bad_doc])
        alerts_col = Mock()
        alerts_col.where.return_value = alerts_q

        batch = Mock()
        batch.delete.side_effect = [None] * 500 + [RuntimeError("delete failed")]

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.SECURITY_ALERTS: alerts_col}[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        cleanup_stale_security_alerts(Mock())
        assert batch.commit.call_count >= 1
        mock_capture.assert_called_once()
        mock_release.assert_called_once_with("cleanup_stale_security_alerts")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("security cleanup fail"))
    def test_cleanup_stale_security_alerts_outer_failure_alerts(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import cleanup_stale_security_alerts

        cleanup_stale_security_alerts(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("cleanup_stale_security_alerts")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("services.algolia_service.delete_product")
    @patch("services.algolia_service.index_product")
    @patch("handlers.cron_jobs.get_server_timestamp", return_value="ts")
    @patch("handlers.cron_jobs.get_db")
    def test_retry_failed_algolia_syncs_missing_and_inactive_products_delete(
        self, mock_get_db, _mock_ts, _mock_index, mock_delete, _mock_lock, mock_release
    ):
        from handlers.cron_jobs import retry_failed_algolia_syncs

        failure_missing = _snapshot(
            "f_missing",
            {Fields.PRODUCT_ID: "p_missing", Fields.ACTION: AlgoliaActionValues.INDEX, Fields.RETRY_COUNT: 0},
        )
        failure_inactive = _snapshot(
            "f_inactive",
            {Fields.PRODUCT_ID: "p_inactive", Fields.ACTION: AlgoliaActionValues.INDEX, Fields.RETRY_COUNT: 0},
        )
        failures_q = _query(stream_return=[failure_missing, failure_inactive])
        failures_col = Mock()
        failures_col.where.return_value = failures_q

        product_refs = {
            "p_missing": Mock(get=Mock(return_value=_snapshot("p_missing", exists=False))),
            "p_inactive": Mock(
                get=Mock(
                    return_value=_snapshot("p_inactive", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED})
                )
            ),
        }
        products_col = Mock()
        products_col.document.side_effect = lambda pid: product_refs[pid]

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ALGOLIA_SYNC_FAILURES: failures_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        retry_failed_algolia_syncs(Mock())
        assert mock_delete.call_count == 2
        mock_release.assert_called_once_with("retry_failed_algolia_syncs")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("algolia retry outer fail"))
    def test_retry_failed_algolia_syncs_outer_failure_alerts(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import retry_failed_algolia_syncs

        retry_failed_algolia_syncs(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("retry_failed_algolia_syncs")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_revalidate_digital_product_urls_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import revalidate_digital_product_urls

        revalidate_digital_product_urls(Mock())
        mock_release.assert_not_called()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.products._send_product_rejection_email", side_effect=RuntimeError("email failed"))
    @patch("handlers.products._get_seller_email", return_value="seller@example.com")
    @patch("services.algolia_service.delete_product", side_effect=RuntimeError("algolia failed"))
    @patch("requests.head")
    @patch("handlers.cron_jobs.get_db")
    def test_revalidate_digital_product_urls_dead_url_error_branches(
        self,
        mock_get_db,
        mock_head,
        _mock_algolia_delete,
        _mock_get_seller_email,
        _mock_send_rejection,
        _mock_lock,
        mock_release,
    ):
        from requests import exceptions as requests_exceptions

        from handlers.cron_jobs import revalidate_digital_product_urls

        mock_head.side_effect = requests_exceptions.RequestException("timeout")

        product_doc = _snapshot(
            "prod_dead",
            {
                Fields.IS_DIGITAL: True,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.BOOK_SOURCE_URL: "https://dead.example.com/book.pdf",
                Fields.SELLER_ID: "seller_1",
                Fields.NAME: "Dead Book",
            },
        )
        products_q = _query(stream_return=[product_doc])
        products_col = Mock()
        products_col.where.return_value = products_q

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        mock_get_db.return_value = db

        revalidate_digital_product_urls(Mock())

        product_doc.reference.update.assert_called_once()
        mock_release.assert_called_once_with("revalidate_digital_product_urls")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("revalidate outer fail"))
    def test_revalidate_digital_product_urls_outer_failure_alerts(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import revalidate_digital_product_urls

        revalidate_digital_product_urls(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("revalidate_digital_product_urls")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_check_low_stock_alerts_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import check_low_stock_alerts

        check_low_stock_alerts(Mock())
        mock_release.assert_not_called()

    @patch("services.email_task.enqueue_email_task", side_effect=RuntimeError("mail down"))
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_check_low_stock_alerts_guard_and_failure_branches(
        self, mock_get_db, _mock_lock, mock_release, _mock_enqueue
    ):
        from handlers.cron_jobs import check_low_stock_alerts

        now_naive = datetime.now(UTC).replace(tzinfo=None)
        docs = [
            _snapshot(
                "prod_recent",
                {
                    Fields.SELLER_ID: "seller_recent",
                    Fields.NAME: "Recent",
                    Fields.STOCK_QUANTITY: 1,
                    Fields.INVENTORY: {Fields.LOW_STOCK_THRESHOLD: 5, Fields.TRACK_QUANTITY: True},
                    Fields.LAST_LOW_STOCK_ALERT_AT: now_naive,
                },
            ),
            _snapshot(
                "prod_missing_seller",
                {
                    Fields.SELLER_ID: "seller_missing",
                    Fields.NAME: "Missing Seller",
                    Fields.STOCK_QUANTITY: 1,
                    Fields.INVENTORY: {Fields.LOW_STOCK_THRESHOLD: 5, Fields.TRACK_QUANTITY: True},
                    Fields.LAST_LOW_STOCK_ALERT_AT: "invalid-ts",
                },
            ),
            _snapshot(
                "prod_no_consent",
                {
                    Fields.SELLER_ID: "seller_no_consent",
                    Fields.NAME: "No Consent",
                    Fields.STOCK_QUANTITY: 1,
                    Fields.INVENTORY: {Fields.LOW_STOCK_THRESHOLD: 5, Fields.TRACK_QUANTITY: True},
                },
            ),
            _snapshot(
                "prod_fail_email",
                {
                    Fields.SELLER_ID: "seller_fail",
                    Fields.NAME: "Fail Email",
                    Fields.STOCK_QUANTITY: 1,
                    Fields.INVENTORY: {Fields.LOW_STOCK_THRESHOLD: 5, Fields.TRACK_QUANTITY: True},
                },
            ),
        ]
        products_q = _query(stream_return=docs)
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = Mock()

        users_col = Mock()
        users_col.document.side_effect = lambda sid: SimpleNamespace(id=sid)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
        }[name]
        db.get_all.return_value = [
            _snapshot("seller_no_consent", {Fields.EMAIL: "nc@example.com", Fields.EMAIL_CONSENT: False}, exists=True),
            _snapshot("seller_fail", {Fields.EMAIL: "fail@example.com", Fields.EMAIL_CONSENT: True}, exists=True),
        ]
        mock_get_db.return_value = db

        check_low_stock_alerts(Mock())
        mock_release.assert_called_once_with("check_low_stock_alerts")

    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db", side_effect=RuntimeError("low stock outer fail"))
    def test_check_low_stock_alerts_outer_failure_alerts(
        self, _mock_db, _mock_lock, mock_release, mock_alert
    ):
        from handlers.cron_jobs import check_low_stock_alerts

        check_low_stock_alerts(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("check_low_stock_alerts")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_send_abandoned_cart_emails_skips_when_locked(self, _mock_lock, mock_release):
        from handlers.cron_jobs import send_abandoned_cart_emails

        send_abandoned_cart_emails(Mock())
        mock_release.assert_not_called()

    @patch("services.email_task.enqueue_email_task")
    @patch("services.email_service._email_wrapper", return_value="<html>abandoned</html>")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_send_abandoned_cart_emails_skip_and_break_paths(
        self, mock_get_db, _mock_lock, mock_release, _mock_wrapper, mock_enqueue
    ):
        from handlers.cron_jobs import send_abandoned_cart_emails

        users = [
            _snapshot("u_no_email", {Fields.MARKETING_OPT_IN: True, Fields.EMAIL_CONSENT: True}),
            _snapshot("u_no_consent", {Fields.MARKETING_OPT_IN: True, Fields.EMAIL: "noconsent@example.com", Fields.EMAIL_CONSENT: False}),
            _snapshot("u_empty_cart", {Fields.MARKETING_OPT_IN: True, Fields.EMAIL: "empty@example.com", Fields.EMAIL_CONSENT: True}),
            _snapshot("u_no_active", {Fields.MARKETING_OPT_IN: True, Fields.EMAIL: "inactive@example.com", Fields.EMAIL_CONSENT: True}),
            _snapshot("u_many_active", {Fields.MARKETING_OPT_IN: True, Fields.EMAIL: "active@example.com", Fields.EMAIL_CONSENT: True}),
        ]
        users_q = _query(stream_return=users)
        users_col = Mock()
        users_col.where.return_value = users_q

        cart_docs = {
            "u_empty_cart": [],
            "u_no_active": [_snapshot("p_inactive_1", {Fields.PRODUCT_ID: "p_inactive_1"}), _snapshot("p_inactive_2", {Fields.PRODUCT_ID: "p_inactive_2"})],
            "u_many_active": [
                _snapshot("p_active_1", {Fields.PRODUCT_ID: "p_active_1"}),
                _snapshot("p_active_2", {Fields.PRODUCT_ID: "p_active_2"}),
                _snapshot("p_active_3", {Fields.PRODUCT_ID: "p_active_3"}),
                _snapshot("p_active_4", {Fields.PRODUCT_ID: "p_active_4"}),
            ],
        }

        user_refs = {}
        for uid in [u.id for u in users]:
            ref = Mock()
            cart_q = Mock()
            cart_q.limit.return_value = cart_q
            cart_q.stream.return_value = cart_docs.get(uid, [])
            ref.collection.return_value = cart_q
            user_refs[uid] = ref
        users_col.document.side_effect = lambda uid: user_refs[uid]

        products_col = Mock()
        products_col.document.side_effect = lambda pid: SimpleNamespace(id=pid)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        db.get_all.side_effect = [
            [
                _snapshot("p_inactive_1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED, Fields.STOCK_QUANTITY: 1}),
                _snapshot("p_inactive_2", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE, Fields.STOCK_QUANTITY: 0}),
            ],
            [
                _snapshot("p_active_1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE, Fields.STOCK_QUANTITY: 3, Fields.NAME: "A1"}),
                _snapshot("p_active_2", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE, Fields.STOCK_QUANTITY: 2, Fields.NAME: "A2"}),
                _snapshot("p_active_3", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE, Fields.STOCK_QUANTITY: 1, Fields.NAME: "A3"}),
                _snapshot("p_active_4", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE, Fields.STOCK_QUANTITY: 1, Fields.NAME: "A4"}),
            ],
        ]
        mock_get_db.return_value = db

        send_abandoned_cart_emails(Mock())

        mock_enqueue.assert_called_once()
        user_refs["u_many_active"].update.assert_called_once()
        mock_release.assert_called_once_with("send_abandoned_cart_emails")

    @patch("services.email_task.enqueue_email_task", side_effect=RuntimeError("enqueue failed"))
    @patch("services.email_service._email_wrapper", return_value="<html>abandoned</html>")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_send_abandoned_cart_emails_enqueue_failure_branch(
        self, mock_get_db, _mock_lock, mock_release, _mock_wrapper, _mock_enqueue
    ):
        from handlers.cron_jobs import send_abandoned_cart_emails

        user = _snapshot(
            "u_fail",
            {
                Fields.MARKETING_OPT_IN: True,
                Fields.EMAIL: "fail@example.com",
                Fields.EMAIL_CONSENT: True,
            },
        )
        users_q = _query(stream_return=[user])
        users_col = Mock()
        users_col.where.return_value = users_q

        user_ref = Mock()
        cart_q = Mock()
        cart_q.limit.return_value = cart_q
        cart_q.stream.return_value = [_snapshot("p1", {Fields.PRODUCT_ID: "p1"})]
        user_ref.collection.return_value = cart_q
        users_col.document.return_value = user_ref

        products_col = Mock()
        products_col.document.return_value = SimpleNamespace(id="p1")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        db.get_all.return_value = [
            _snapshot("p1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE, Fields.STOCK_QUANTITY: 1, Fields.NAME: "P1"})
        ]
        mock_get_db.return_value = db

        send_abandoned_cart_emails(Mock())
        mock_release.assert_called_once_with("send_abandoned_cart_emails")

    @patch("handlers.cron_jobs.get_db")
    def test_compute_seller_metrics_logic_item_without_seller_and_second_page_empty(self, mock_get_db):
        from handlers.cron_jobs import _compute_seller_metrics_logic

        order_doc = _snapshot(
            "ord_metrics",
            {
                Fields.SELLER_IDS: ["seller_0"],
                Fields.HAS_DISPUTE: False,
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.CREATED_AT: datetime.now(UTC) - timedelta(days=2),
                Fields.ITEMS: [{Fields.STATUS: DeliveryStatusValues.DELIVERED}],  # missing sellerId hits continue branch
            },
        )

        orders_ref = Mock()
        orders_ref.where.return_value = orders_ref
        orders_ref.limit.return_value = orders_ref
        orders_ref.stream.return_value = [order_doc]

        chats_ref = Mock()
        chats_ref.where.return_value = chats_ref
        chats_ref.limit.return_value = chats_ref
        chats_ref.stream.return_value = []

        sellers_page = [_snapshot(f"seller_{i}", {}) for i in range(500)]
        sellers_query = Mock()
        sellers_query.where.return_value = sellers_query
        sellers_query.order_by.return_value = sellers_query
        sellers_query.limit.return_value = sellers_query
        sellers_query.start_after.return_value = sellers_query
        sellers_query.stream.side_effect = [sellers_page, []]

        metrics_col = Mock()
        metrics_col.document.return_value = Mock()

        alerts_q = Mock()
        alerts_q.where.return_value = alerts_q
        alerts_q.limit.return_value = alerts_q
        alerts_q.get.return_value = []
        alerts_col = Mock()
        alerts_col.where.return_value = alerts_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_ref,
            Collections.CHATS: chats_ref,
            Collections.USERS: sellers_query,
            Collections.SELLER_METRICS: metrics_col,
            Collections.SECURITY_ALERTS: alerts_col,
        }[name]
        mock_get_db.return_value = db

        _compute_seller_metrics_logic()
        assert sellers_query.start_after.called

    @patch("handlers.cron_jobs.get_db")
    def test_compute_seller_metrics_logic_reraises_on_failure(self, mock_get_db):
        from handlers.cron_jobs import _compute_seller_metrics_logic

        orders_ref = Mock()
        orders_ref.where.return_value = orders_ref
        orders_ref.limit.return_value = orders_ref
        orders_ref.stream.return_value = [_snapshot("ord", {Fields.SELLER_IDS: ["s1"], Fields.ITEMS: []})]

        chats_ref = Mock()
        chats_ref.where.return_value = chats_ref
        chats_ref.limit.return_value = chats_ref
        chats_ref.stream.return_value = []

        sellers_query = Mock()
        sellers_query.where.return_value = sellers_query
        sellers_query.order_by.return_value = sellers_query
        sellers_query.limit.return_value = sellers_query
        sellers_query.start_after.return_value = sellers_query
        sellers_query.stream.side_effect = [[_snapshot("s1", {})]]

        metrics_doc = Mock()
        metrics_doc.set.side_effect = RuntimeError("metrics write failed")
        metrics_col = Mock()
        metrics_col.document.return_value = metrics_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_ref,
            Collections.CHATS: chats_ref,
            Collections.USERS: sellers_query,
            Collections.SELLER_METRICS: metrics_col,
            Collections.SECURITY_ALERTS: Mock(),
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(RuntimeError):
            _compute_seller_metrics_logic()

    @patch("handlers.cron_jobs.get_db")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_compute_trending_products_skips_when_locked(self, _mock_lock, mock_release, _mock_get_db):
        from handlers.cron_jobs import compute_trending_products

        compute_trending_products(Mock())
        mock_release.assert_not_called()

    @patch("handlers.cron_jobs._notify_trending_products")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_compute_trending_products_commits_at_top_batch_boundary(
        self, mock_get_db, _mock_lock, mock_release, _mock_notify
    ):
        from handlers.cron_jobs import compute_trending_products

        docs = [
            _snapshot(
                f"tp_{i}",
                {
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                    Fields.VIEW_COUNT: 1,
                    Fields.PURCHASE_COUNT: 0,
                    Fields.FAVORITE_COUNT: 0,
                    # Keep all docs trending so clears + top updates hit the 400-op commit boundary.
                    Fields.IS_TRENDING: True,
                },
            )
            for i in range(400)
        ]
        products_q = _query(stream_return=docs)
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = Mock()

        batch = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        compute_trending_products(Mock())
        assert batch.commit.call_count >= 2
        mock_release.assert_called_once_with("compute_trending_products")

    @patch("handlers.cron_jobs.TRENDING_TOP_N", 400)
    @patch("handlers.cron_jobs._notify_trending_products")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_compute_trending_products_top_batch_commit_branch(
        self, mock_get_db, _mock_lock, mock_release, _mock_notify
    ):
        from handlers.cron_jobs import compute_trending_products

        docs = [
            _snapshot(
                f"tp_top_batch_{i}",
                {
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                    Fields.VIEW_COUNT: 1,
                    Fields.PURCHASE_COUNT: 0,
                    Fields.FAVORITE_COUNT: 0,
                    Fields.IS_TRENDING: False,
                },
            )
            for i in range(400)
        ]
        products_q = _query(stream_return=docs)
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = Mock()

        batch = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        compute_trending_products(Mock())
        assert batch.commit.call_count >= 2
        mock_release.assert_called_once_with("compute_trending_products")

    @patch("handlers.cron_jobs._notify_trending_products")
    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs.get_db")
    def test_compute_trending_products_commits_when_clearing_old_items(
        self, mock_get_db, _mock_lock, mock_release, _mock_notify
    ):
        from handlers.cron_jobs import compute_trending_products

        docs = [
            _snapshot(
                f"tp_top_{i}",
                {
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                    Fields.VIEW_COUNT: 10,
                    Fields.PURCHASE_COUNT: 0,
                    Fields.FAVORITE_COUNT: 0,
                    Fields.IS_TRENDING: False,
                },
            )
            for i in range(20)
        ]
        docs.extend(
            _snapshot(
                f"tp_old_trending_{i}",
                {
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                    Fields.VIEW_COUNT: 0,
                    Fields.PURCHASE_COUNT: 0,
                    Fields.FAVORITE_COUNT: 0,
                    Fields.IS_TRENDING: True,
                },
            )
            for i in range(381)
        )

        products_q = _query(stream_return=docs)
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = Mock()

        batch = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        compute_trending_products(Mock())
        assert batch.commit.call_count >= 2
        mock_release.assert_called_once_with("compute_trending_products")

    @patch("firebase_admin.messaging.send_each_for_multicast", side_effect=RuntimeError("fcm fail"))
    @patch("handlers.cron_jobs.get_db")
    def test_notify_trending_products_send_failure_branch(self, mock_get_db, _mock_send):
        from handlers.cron_jobs import _notify_trending_products

        user_doc = _snapshot("u1", {})
        token_doc = _snapshot("t1", {"token": "fcm_token"})
        token_q = Mock()
        token_q.limit.return_value = token_q
        token_q.stream.return_value = [token_doc]
        user_doc.reference.collection.return_value = token_q

        users_q = _query(stream_return=[user_doc])
        users_col = Mock()
        users_col.where.return_value = users_q

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.USERS: users_col}[name]
        mock_get_db.return_value = db

        _notify_trending_products(mock_get_db.return_value, [(10, "p1", "Product", None)])
