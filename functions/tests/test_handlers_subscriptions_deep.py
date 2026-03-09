from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import MagicMock, Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import Collections, Fields, SubscriptionStatusValues


def _auth_req(uid: str = "user_123"):
    req = Mock()
    req.auth = Mock()
    req.auth.uid = uid
    req.data = {}
    return req


def _build_subscriptions_db(user_doc, sub_doc, *, user_ref_get_side_effect=None):
    db = MagicMock()
    user_ref = MagicMock()
    sub_ref = MagicMock()
    user_ref.get.side_effect = user_ref_get_side_effect or [user_doc]
    sub_ref.get.return_value = sub_doc

    def collection_side_effect(name):
        col = MagicMock()
        if name == Collections.USERS:
            col.document.return_value = user_ref
        elif name in (Collections.SUBSCRIPTIONS, "subscriptions"):
            col.document.return_value = sub_ref
        else:
            col.document.return_value = MagicMock()
        return col

    db.collection.side_effect = collection_side_effect
    return db, user_ref, sub_ref


class TestSubscriptionHelpersDeep:
    @patch("handlers.subscriptions._get_db")
    def test_fetch_user_for_email_returns_empty_on_db_error(self, mock_get_db):
        from handlers import subscriptions

        mock_get_db.side_effect = RuntimeError("db down")
        with patch.object(subscriptions.logging.getLogger(__name__), "warning"):
            result = subscriptions._fetch_user_for_email("u1")
        assert result == {}

    @patch("handlers.subscriptions._get_db")
    def test_fetch_user_for_email_returns_doc_data(self, mock_get_db):
        from handlers.subscriptions import _fetch_user_for_email

        doc = MagicMock()
        doc.exists = True
        doc.to_dict.return_value = {"email": "a@example.com"}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc
        assert _fetch_user_for_email("u1")["email"] == "a@example.com"

    @patch("handlers.subscriptions.get_stripe_secret_key", return_value="sk_test_cached")
    def test_stripe_init_caches_secret(self, mock_key):
        from handlers import subscriptions

        subscriptions._STRIPE_KEY_CACHE = None
        subscriptions._stripe_init()
        subscriptions._stripe_init()
        assert subscriptions.stripe.api_key == "sk_test_cached"
        mock_key.assert_called_once()

    def test_get_or_create_stripe_customer_raises_when_user_missing(self):
        from handlers.subscriptions import _get_or_create_stripe_customer

        user_snap = MagicMock()
        user_snap.exists = False
        with pytest.raises(https_fn.HttpsError) as exc:
            _get_or_create_stripe_customer("u1", user_snap)
        assert exc.value.code == "not-found"

    @patch("handlers.subscriptions._stripe_init")
    def test_get_or_create_stripe_customer_reuses_existing(self, _mock_init):
        from handlers.subscriptions import _get_or_create_stripe_customer

        user_snap = MagicMock()
        user_snap.exists = True
        user_snap.to_dict.return_value = {Fields.CUSTOMER_ID: "cus_existing"}
        assert _get_or_create_stripe_customer("u1", user_snap) == "cus_existing"

    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions.stripe")
    def test_get_or_create_stripe_customer_creates_and_persists(
        self,
        mock_stripe,
        _mock_init,
        mock_get_db,
    ):
        from handlers.subscriptions import _get_or_create_stripe_customer

        user_snap = MagicMock()
        user_snap.exists = True
        user_snap.to_dict.return_value = {Fields.EMAIL: "buyer@example.com", Fields.NAME: "Buyer"}

        created = SimpleNamespace(id="cus_new")
        mock_stripe.Customer.create.return_value = created

        result = _get_or_create_stripe_customer("u1", user_snap)
        assert result == "cus_new"
        mock_get_db.return_value.collection.return_value.document.return_value.update.assert_called_once()


class TestCreateSubscriptionDeep:
    @patch("handlers.subscriptions._get_db")
    def test_create_subscription_raises_when_user_profile_missing(self, mock_get_db):
        from handlers.subscriptions import create_subscription

        missing_user = MagicMock()
        missing_user.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = missing_user

        with pytest.raises(https_fn.HttpsError) as exc:
            create_subscription(_auth_req())
        assert exc.value.code == "not-found"

    @patch("handlers.subscriptions.get_stripe_premium_price_id", return_value="price_123")
    @patch("handlers.subscriptions._get_or_create_stripe_customer", return_value="cus_abc")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.stripe")
    def test_create_subscription_idempotency_returns_cached_url(
        self,
        mock_stripe,
        mock_get_db,
        _mock_init,
        _mock_customer,
        _mock_price_id,
    ):
        from handlers.subscriptions import create_subscription

        class DummyIdempotencyError(Exception):
            pass

        class DummyStripeError(Exception):
            pass

        mock_stripe.error.IdempotencyError = DummyIdempotencyError
        mock_stripe.StripeError = DummyStripeError
        mock_stripe.checkout.Session.create.side_effect = DummyIdempotencyError("dup")

        user_doc = MagicMock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.ROLES: ["buyer"]}
        cached_doc = MagicMock()
        cached_doc.to_dict.return_value = {Fields.LAST_CHECKOUT_SESSION: "https://cached.example/session"}
        sub_doc = MagicMock()
        sub_doc.exists = False
        db, _user_ref, _sub_ref = _build_subscriptions_db(user_doc, sub_doc, user_ref_get_side_effect=[user_doc, cached_doc])
        mock_get_db.return_value = db

        result = create_subscription(_auth_req())
        assert result["success"] is True
        assert result["checkoutUrl"] == "https://cached.example/session"

    @patch("handlers.subscriptions.get_stripe_premium_price_id", return_value="price_123")
    @patch("handlers.subscriptions._get_or_create_stripe_customer", return_value="cus_abc")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.stripe")
    def test_create_subscription_idempotency_without_cached_url_raises(
        self,
        mock_stripe,
        mock_get_db,
        _mock_init,
        _mock_customer,
        _mock_price_id,
    ):
        from handlers.subscriptions import create_subscription

        class DummyIdempotencyError(Exception):
            pass

        class DummyStripeError(Exception):
            pass

        mock_stripe.error.IdempotencyError = DummyIdempotencyError
        mock_stripe.StripeError = DummyStripeError
        mock_stripe.checkout.Session.create.side_effect = DummyIdempotencyError("dup")

        user_doc = MagicMock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.ROLES: ["buyer"]}
        cached_doc = MagicMock()
        cached_doc.to_dict.return_value = {}
        sub_doc = MagicMock()
        sub_doc.exists = False
        db, _user_ref, _sub_ref = _build_subscriptions_db(user_doc, sub_doc, user_ref_get_side_effect=[user_doc, cached_doc])
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            create_subscription(_auth_req())
        assert exc.value.code == "already-exists"

    @patch("handlers.subscriptions.get_stripe_premium_price_id", return_value="price_123")
    @patch("handlers.subscriptions._get_or_create_stripe_customer", return_value="cus_abc")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.stripe")
    def test_create_subscription_maps_stripe_error(
        self,
        mock_stripe,
        mock_get_db,
        _mock_init,
        _mock_customer,
        _mock_price_id,
    ):
        from handlers.subscriptions import create_subscription

        class DummyIdempotencyError(Exception):
            pass

        class DummyStripeError(Exception):
            pass

        mock_stripe.error.IdempotencyError = DummyIdempotencyError
        mock_stripe.StripeError = DummyStripeError
        mock_stripe.checkout.Session.create.side_effect = DummyStripeError("stripe down")

        user_doc = MagicMock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.ROLES: ["buyer"]}
        sub_doc = MagicMock()
        sub_doc.exists = False
        db, _user_ref, _sub_ref = _build_subscriptions_db(user_doc, sub_doc)
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            create_subscription(_auth_req())
        assert exc.value.code == "internal"


class TestCancelSubscriptionDeep:
    @patch("handlers.subscriptions._get_db")
    def test_cancel_subscription_raises_when_stripe_subscription_id_missing(self, mock_get_db):
        from handlers.subscriptions import cancel_subscription

        sub_doc = MagicMock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {Fields.STATUS: SubscriptionStatusValues.ACTIVE}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = sub_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_subscription(_auth_req())
        assert exc.value.code == "not-found"

    @patch("handlers.subscriptions._get_server_timestamp", return_value="server_ts")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions._fetch_user_for_email", return_value={"email": "buyer@example.com", "preferredLanguage": "fr"})
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.stripe")
    @patch("services.email_service.get_premium_cancellation_email", return_value="<p>cancelled</p>")
    @patch("services.email_task.enqueue_email_task")
    def test_cancel_subscription_sends_cancellation_email(
        self,
        mock_enqueue,
        _mock_template,
        mock_stripe,
        mock_get_db,
        _mock_fetch_user,
        _mock_init,
        _mock_server_ts,
    ):
        from handlers.subscriptions import cancel_subscription

        sub_doc = MagicMock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.ACTIVE,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_123",
            Fields.CANCEL_AT_PERIOD_END: False,
            "currentPeriodEnd": datetime(2027, 1, 1, tzinfo=UTC),
        }

        db = MagicMock()
        db.collection.return_value.document.return_value.get.return_value = sub_doc
        mock_get_db.return_value = db

        result = cancel_subscription(_auth_req())
        assert result["success"] is True
        mock_stripe.Subscription.modify.assert_called_once_with("sub_123", cancel_at_period_end=True)
        assert mock_enqueue.called

    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.stripe")
    def test_cancel_subscription_maps_stripe_error(
        self,
        mock_stripe,
        mock_get_db,
        _mock_init,
    ):
        from handlers.subscriptions import cancel_subscription

        class DummyStripeError(Exception):
            pass

        mock_stripe.StripeError = DummyStripeError
        mock_stripe.Subscription.modify.side_effect = DummyStripeError("cannot cancel")

        sub_doc = MagicMock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.ACTIVE,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_123",
            Fields.CANCEL_AT_PERIOD_END: False,
        }
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = sub_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_subscription(_auth_req())
        assert exc.value.code == "internal"

    @patch("handlers.subscriptions._get_server_timestamp", return_value="server_ts")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions._fetch_user_for_email", return_value={"email": "buyer@example.com", "preferredLanguage": "en"})
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.stripe")
    @patch("services.email_service.get_premium_cancellation_email", side_effect=RuntimeError("template down"))
    def test_cancel_subscription_logs_email_error_but_still_succeeds(
        self,
        _mock_template,
        mock_stripe,
        mock_get_db,
        _mock_fetch_user,
        _mock_init,
        _mock_server_ts,
    ):
        from handlers import subscriptions

        sub_doc = MagicMock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.ACTIVE,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_123",
            Fields.CANCEL_AT_PERIOD_END: False,
        }
        db = MagicMock()
        db.collection.return_value.document.return_value.get.return_value = sub_doc
        mock_get_db.return_value = db

        with patch.object(subscriptions.logger, "error") as mock_error:
            result = subscriptions.cancel_subscription(_auth_req())
        assert result["success"] is True
        mock_stripe.Subscription.modify.assert_called_once_with("sub_123", cancel_at_period_end=True)
        mock_error.assert_called()


class TestReactivateSubscriptionDeep:
    @patch("handlers.subscriptions._get_db")
    def test_reactivate_subscription_raises_when_subscription_missing(self, mock_get_db):
        from handlers.subscriptions import reactivate_subscription

        sub_doc = MagicMock()
        sub_doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = sub_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            reactivate_subscription(_auth_req())
        assert exc.value.code == "not-found"

    @patch("handlers.subscriptions._get_db")
    def test_reactivate_subscription_raises_when_stripe_id_missing(self, mock_get_db):
        from handlers.subscriptions import reactivate_subscription

        sub_doc = MagicMock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {Fields.CANCEL_AT_PERIOD_END: True}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = sub_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            reactivate_subscription(_auth_req())
        assert exc.value.code == "not-found"

    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.stripe")
    def test_reactivate_subscription_maps_stripe_error(self, mock_stripe, mock_get_db, _mock_init):
        from handlers.subscriptions import reactivate_subscription

        class DummyStripeError(Exception):
            pass

        mock_stripe.StripeError = DummyStripeError
        mock_stripe.Subscription.modify.side_effect = DummyStripeError("cannot reactivate")

        sub_doc = MagicMock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {
            Fields.CANCEL_AT_PERIOD_END: True,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_abc",
        }
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = sub_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            reactivate_subscription(_auth_req())
        assert exc.value.code == "internal"


class TestStatusAndWebhookDeep:
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions._sync_subscription")
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.stripe")
    def test_get_subscription_status_self_heals_when_period_end_missing(
        self,
        mock_stripe,
        mock_get_db,
        mock_sync,
        _mock_init,
    ):
        from handlers.subscriptions import get_subscription_status

        sub_before = MagicMock()
        sub_before.exists = True
        sub_before.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.ACTIVE,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_abc",
            Fields.CURRENT_PERIOD_END: None,
            Fields.CANCEL_AT_PERIOD_END: False,
        }
        period_end = datetime(2027, 1, 1, tzinfo=UTC)
        sub_after = MagicMock()
        sub_after.exists = True
        sub_after.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.ACTIVE,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_abc",
            Fields.CURRENT_PERIOD_END: period_end,
            Fields.CANCEL_AT_PERIOD_END: False,
        }
        mock_get_db.return_value.collection.return_value.document.return_value.get.side_effect = [sub_before, sub_after]
        mock_stripe.Subscription.retrieve.return_value = {"id": "sub_abc", "metadata": {"uid": "user_123"}, "status": "active"}

        result = get_subscription_status(_auth_req())
        assert result["isPremium"] is True
        assert result["premiumExpiresAt"] == period_end.isoformat()
        mock_sync.assert_called_once()

    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.stripe")
    def test_get_subscription_status_logs_warning_when_resync_fails(self, mock_stripe, mock_get_db, _mock_init):
        from handlers import subscriptions

        sub_before = MagicMock()
        sub_before.exists = True
        sub_before.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.ACTIVE,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_abc",
            Fields.CURRENT_PERIOD_END: None,
            Fields.CANCEL_AT_PERIOD_END: False,
        }
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = sub_before
        mock_stripe.Subscription.retrieve.side_effect = RuntimeError("stripe unavailable")

        with patch.object(subscriptions.logger, "warning") as mock_warning:
            result = subscriptions.get_subscription_status(_auth_req())
        assert result["isPremium"] is True
        assert result["premiumExpiresAt"] is None
        mock_warning.assert_called_once()

    @patch("handlers.subscriptions._sync_subscription")
    @patch("handlers.subscriptions._fetch_user_for_email", return_value={"email": "buyer@example.com", "preferredLanguage": "en"})
    @patch("services.email_service.get_premium_welcome_email", return_value="<p>welcome</p>")
    @patch("services.email_task.enqueue_email_task")
    def test_handle_subscription_created_sends_welcome_email(
        self,
        mock_enqueue,
        _mock_template,
        _mock_fetch,
        mock_sync,
    ):
        from handlers.subscriptions import handle_subscription_created

        event = {
            "data": {
                "object": {
                    "id": "sub_123",
                    "status": "active",
                    "metadata": {"uid": "user_123"},
                    "current_period_end": 1700000000,
                }
            }
        }
        handle_subscription_created(event)
        mock_sync.assert_called_once()
        mock_enqueue.assert_called_once()

    @patch("handlers.subscriptions._sync_subscription")
    @patch("handlers.subscriptions._fetch_user_for_email", return_value={"email": "buyer@example.com", "preferredLanguage": "en"})
    @patch("services.email_service.get_premium_welcome_email", side_effect=RuntimeError("template failure"))
    def test_handle_subscription_created_logs_email_error(self, _mock_template, _mock_fetch, mock_sync):
        from handlers import subscriptions

        event = {
            "data": {
                "object": {
                    "id": "sub_123",
                    "status": "active",
                    "metadata": {"uid": "user_123"},
                    "current_period_end": 1700000000,
                }
            }
        }
        with patch.object(subscriptions.logger, "error") as mock_error:
            subscriptions.handle_subscription_created(event)
        mock_sync.assert_called_once()
        mock_error.assert_called_once()

    @patch("handlers.subscriptions._sync_subscription")
    def test_handle_subscription_updated_syncs(self, mock_sync):
        from handlers.subscriptions import handle_subscription_updated

        event = {"data": {"object": {"id": "sub_1"}}}
        handle_subscription_updated(event)
        mock_sync.assert_called_once_with({"id": "sub_1"})

    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions._get_firestore")
    def test_handle_subscription_deleted_warns_when_uid_missing(self, _mock_get_firestore, _mock_get_db):
        from handlers import subscriptions

        event = {"data": {"object": {"id": "sub_1", "metadata": {}}}}
        with patch.object(subscriptions.logger, "warning") as mock_warning:
            subscriptions.handle_subscription_deleted(event)
        mock_warning.assert_called_once()

    @patch("handlers.subscriptions._fetch_user_for_email", return_value={"email": "buyer@example.com", "preferredLanguage": "fr"})
    @patch("services.email_service.get_premium_expired_email", return_value="<p>expired</p>")
    @patch("services.email_task.enqueue_email_task")
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions._get_firestore")
    def test_handle_subscription_deleted_sends_expired_email_and_clears_status(
        self,
        mock_get_firestore,
        mock_get_db,
        mock_enqueue,
        _mock_template,
        _mock_user,
    ):
        from handlers.subscriptions import handle_subscription_deleted

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        user_doc = MagicMock()
        user_doc.exists = True
        db.collection.return_value.document.return_value.get.return_value = user_doc
        mock_get_db.return_value = db

        mock_get_firestore.return_value.transactional = lambda fn: fn

        event = {"data": {"object": {"id": "sub_1", "metadata": {"uid": "user_123"}, "current_period_end": 1700000000}}}
        handle_subscription_deleted(event)

        assert tx.set.called
        assert tx.update.called
        mock_enqueue.assert_called_once()

    @patch("handlers.subscriptions._fetch_user_for_email", return_value={})
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions._get_firestore")
    def test_handle_subscription_deleted_user_missing_skips_user_update(
        self,
        mock_get_firestore,
        mock_get_db,
        _mock_user,
    ):
        from handlers import subscriptions

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        user_doc = MagicMock()
        user_doc.exists = False
        db.collection.return_value.document.return_value.get.return_value = user_doc
        mock_get_db.return_value = db
        mock_get_firestore.return_value.transactional = lambda fn: fn

        event = {"data": {"object": {"id": "sub_1", "metadata": {"uid": "user_123"}, "current_period_end": 1700000000}}}
        with patch.object(subscriptions.logger, "warning") as mock_warning:
            subscriptions.handle_subscription_deleted(event)
        assert tx.set.called
        tx.update.assert_not_called()
        mock_warning.assert_called()

    @patch("handlers.subscriptions._fetch_user_for_email", return_value={"email": "buyer@example.com", "preferredLanguage": "en"})
    @patch("services.email_service.get_premium_expired_email", side_effect=RuntimeError("template down"))
    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions._get_firestore")
    def test_handle_subscription_deleted_logs_email_error(self, mock_get_firestore, mock_get_db, _mock_template, _mock_user):
        from handlers import subscriptions

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        user_doc = MagicMock()
        user_doc.exists = True
        db.collection.return_value.document.return_value.get.return_value = user_doc
        mock_get_db.return_value = db
        mock_get_firestore.return_value.transactional = lambda fn: fn

        event = {"data": {"object": {"id": "sub_1", "metadata": {"uid": "user_123"}, "current_period_end": 1700000000}}}
        with patch.object(subscriptions.logger, "error") as mock_error:
            subscriptions.handle_subscription_deleted(event)
        mock_error.assert_called()

    @patch("handlers.subscriptions._sync_subscription")
    @patch("handlers.subscriptions._fetch_user_for_email", return_value={"email": "buyer@example.com", "preferredLanguage": "en"})
    @patch("services.email_service.get_premium_payment_failed_email", return_value="<p>payment failed</p>")
    @patch("services.email_task.enqueue_email_task")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions.stripe")
    def test_handle_invoice_payment_failed_retrieves_subscription_and_sends_email(
        self,
        mock_stripe,
        _mock_init,
        mock_enqueue,
        _mock_template,
        _mock_user,
        mock_sync,
    ):
        from handlers.subscriptions import handle_invoice_payment_failed

        mock_stripe.Subscription.retrieve.return_value = {"id": "sub_123", "metadata": {"uid": "user_123"}, "status": "past_due"}
        event = {"data": {"object": {"subscription": "sub_123"}}}
        handle_invoice_payment_failed(event)
        mock_sync.assert_called_once()
        mock_enqueue.assert_called_once()

    @patch("handlers.subscriptions._fetch_user_for_email", return_value={"email": "buyer@example.com", "preferredLanguage": "en"})
    @patch("services.email_service.get_premium_payment_failed_email", return_value="<p>payment failed</p>")
    @patch("services.email_task.enqueue_email_task")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions.stripe")
    def test_handle_invoice_payment_failed_uses_invoice_metadata_when_retrieve_fails(
        self,
        mock_stripe,
        _mock_init,
        mock_enqueue,
        _mock_template,
        _mock_user,
    ):
        from handlers.subscriptions import handle_invoice_payment_failed

        class DummyStripeError(Exception):
            pass

        mock_stripe.StripeError = DummyStripeError
        mock_stripe.Subscription.retrieve.side_effect = DummyStripeError("boom")
        event = {"data": {"object": {"subscription": "sub_123", "metadata": {"uid": "user_123"}}}}
        handle_invoice_payment_failed(event)
        mock_enqueue.assert_called_once()

    @patch("handlers.subscriptions._sync_subscription")
    @patch("handlers.subscriptions._fetch_user_for_email", return_value={"email": "buyer@example.com", "preferredLanguage": "en"})
    @patch("services.email_service.get_premium_payment_failed_email", side_effect=RuntimeError("template down"))
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions.stripe")
    def test_handle_invoice_payment_failed_logs_email_error(
        self, mock_stripe, _mock_init, _mock_template, _mock_user, _mock_sync
    ):
        from handlers import subscriptions

        mock_stripe.Subscription.retrieve.return_value = {"id": "sub_123", "metadata": {"uid": "user_123"}, "status": "past_due"}
        event = {"data": {"object": {"subscription": "sub_123"}}}
        with patch.object(subscriptions.logger, "error") as mock_error:
            subscriptions.handle_invoice_payment_failed(event)
        mock_error.assert_called()

    def test_handle_invoice_payment_failed_returns_when_subscription_missing(self):
        from handlers.subscriptions import handle_invoice_payment_failed

        # Just ensure no crash/side effects when subscription id is absent.
        handle_invoice_payment_failed({"data": {"object": {"metadata": {"uid": "user_123"}}}})


class TestSyncSubscriptionDeep:
    @patch("handlers.subscriptions._get_db")
    def test_sync_subscription_logs_and_returns_when_uid_missing(self, mock_get_db):
        from handlers import subscriptions

        with patch.object(subscriptions.logger, "warning") as mock_warning:
            subscriptions._sync_subscription({"id": "sub_1", "status": "active", "metadata": {}})
        mock_warning.assert_called_once()
        mock_get_db.assert_not_called()

    @patch("handlers.subscriptions._get_db")
    def test_sync_subscription_uses_subscription_items_period_fields(self, mock_get_db):
        from handlers.subscriptions import _sync_subscription

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        user_snap = MagicMock()
        user_snap.exists = True
        user_snap.to_dict.return_value = {}

        user_ref = MagicMock()
        user_ref.get.return_value = user_snap
        sub_ref = MagicMock()

        def collection_side_effect(name):
            col = MagicMock()
            if name == Collections.USERS:
                col.document.return_value = user_ref
            else:
                col.document.return_value = sub_ref
            return col

        db.collection.side_effect = collection_side_effect
        mock_get_db.return_value = db

        sub = {
            "id": "sub_1",
            "status": "active",
            "metadata": {"uid": "user_123"},
            "current_period_end": None,
            "current_period_start": None,
            "cancel_at_period_end": False,
            "items": {"data": [{"current_period_end": 1700000000, "current_period_start": 1690000000}]},
        }
        _sync_subscription(sub)
        assert tx.set.called
        assert tx.update.called

    @patch("handlers.subscriptions._get_db")
    def test_sync_subscription_for_non_premium_status_sets_expiry(self, mock_get_db):
        from handlers.subscriptions import _sync_subscription

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        user_snap = MagicMock()
        user_snap.exists = True
        user_snap.to_dict.return_value = {Fields.PREMIUM_SINCE: datetime(2025, 1, 1, tzinfo=UTC)}

        user_ref = MagicMock()
        user_ref.get.return_value = user_snap
        sub_ref = MagicMock()

        def collection_side_effect(name):
            col = MagicMock()
            if name == Collections.USERS:
                col.document.return_value = user_ref
            else:
                col.document.return_value = sub_ref
            return col

        db.collection.side_effect = collection_side_effect
        mock_get_db.return_value = db

        sub = {
            "id": "sub_1",
            "status": SubscriptionStatusValues.CANCELED,
            "metadata": {"uid": "user_123"},
            "current_period_end": 1700000000,
            "current_period_start": 1690000000,
            "cancel_at_period_end": True,
        }
        _sync_subscription(sub)
        user_update = tx.update.call_args.args[1]
        assert user_update[Fields.IS_PREMIUM] is False
        assert Fields.PREMIUM_EXPIRES_AT in user_update

    def test_ts_to_datetime_handles_none_and_timestamp(self):
        from handlers.subscriptions import _ts_to_datetime

        assert _ts_to_datetime(None) is None
        converted = _ts_to_datetime(1700000000)
        assert isinstance(converted, datetime)

    @patch("handlers.subscriptions._get_db")
    def test_sync_subscription_malformed_items_logs_parse_debug(self, mock_get_db):
        from handlers import subscriptions

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        user_snap = MagicMock()
        user_snap.exists = True
        user_snap.to_dict.return_value = {}
        user_ref = MagicMock()
        user_ref.get.return_value = user_snap
        sub_ref = MagicMock()

        def collection_side_effect(name):
            col = MagicMock()
            if name == Collections.USERS:
                col.document.return_value = user_ref
            else:
                col.document.return_value = sub_ref
            return col

        db.collection.side_effect = collection_side_effect
        mock_get_db.return_value = db

        malformed_sub = {
            "id": "sub_1",
            "status": "active",
            "metadata": {"uid": "user_123"},
            "current_period_end": None,
            "current_period_start": None,
            "cancel_at_period_end": False,
            "items": None,  # triggers parse exception branch
        }

        with patch.object(subscriptions.logger, "debug") as mock_debug:
            subscriptions._sync_subscription(malformed_sub)
        mock_debug.assert_called_once()

    @patch("handlers.subscriptions._get_db")
    def test_sync_subscription_reads_period_fields_from_object_items(self, mock_get_db):
        from handlers import subscriptions

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        user_snap = MagicMock()
        user_snap.exists = True
        user_snap.to_dict.return_value = {}
        user_ref = MagicMock()
        user_ref.get.return_value = user_snap
        sub_ref = MagicMock()

        def collection_side_effect(name):
            col = MagicMock()
            if name == Collections.USERS:
                col.document.return_value = user_ref
            else:
                col.document.return_value = sub_ref
            return col

        db.collection.side_effect = collection_side_effect
        mock_get_db.return_value = db

        item_obj = SimpleNamespace(current_period_end=1700000001, current_period_start=1690000001)
        sub = {
            "id": "sub_obj_period",
            "status": "active",
            "metadata": {"uid": "user_123"},
            "current_period_end": None,
            "current_period_start": None,
            "cancel_at_period_end": False,
            "items": {"data": [item_obj]},
        }

        subscriptions._sync_subscription(sub)
        # Ensure the transaction path completed and attempted writes with parsed period fields.
        assert tx.set.called
        assert tx.update.called
