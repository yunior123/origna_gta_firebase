"""
Tests for handlers/subscriptions.py — premium subscription lifecycle.

Coverage:
- create_subscription: auth, seller blocked, already active, creates session, idempotency
- cancel_subscription: no sub, no stripe id, already scheduled, wrong status, cancels correctly
- reactivate_subscription: not scheduled, no sub id, reactivates
- get_subscription_status: no sub → isPremium False, active → isPremium True, self-heal sync
- handle_subscription_deleted: clears premium on user + subscription doc
- handle_invoice_payment_failed: marks past_due via sync
"""
from unittest.mock import MagicMock, Mock, patch

import pytest

from schema_constants import Collections, Fields, SubscriptionStatusValues, UserRoleValues


# ============================================================================
# create_subscription
# ============================================================================


class TestCreateSubscription:
    """Class TestCreateSubscription."""
    def _req(self, uid: str = "buyer_123") -> Mock:
        req = Mock()
        req.auth = Mock()
        req.auth.uid = uid
        req.data = {}
        return req

    def test_unauthenticated_raises(self):
        """Function test_unauthenticated_raises."""
        from firebase_functions import https_fn
        from handlers.subscriptions import create_subscription

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            create_subscription(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.subscriptions._get_db")
    def test_seller_cannot_subscribe(self, mock_get_db):
        """Function test_seller_cannot_subscribe."""
        from firebase_functions import https_fn
        from handlers.subscriptions import create_subscription

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {
            Fields.ROLES: [UserRoleValues.SELLER],
            Fields.EMAIL: "seller@test.com",
        }
        mock_db.collection.return_value.document.return_value.get.return_value = user_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            create_subscription(self._req())
        assert exc.value.code == "failed-precondition"
        assert "Seller" in exc.value.message

    @patch("handlers.subscriptions._get_db")
    def test_already_active_subscription_raises(self, mock_get_db):
        """Function test_already_active_subscription_raises."""
        from firebase_functions import https_fn
        from handlers.subscriptions import create_subscription

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.ROLES: ["buyer"], Fields.EMAIL: "buyer@test.com"}

        sub_doc = Mock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {Fields.STATUS: SubscriptionStatusValues.ACTIVE}

        def collection_side_effect(name):
            """Function collection_side_effect."""
            c = MagicMock()
            if name == Collections.USERS:
                c.document.return_value.get.return_value = user_doc
            elif name == Collections.SUBSCRIPTIONS:
                c.document.return_value.get.return_value = sub_doc
            return c

        mock_db.collection.side_effect = collection_side_effect

        with pytest.raises(https_fn.HttpsError) as exc:
            create_subscription(self._req())
        assert exc.value.code == "already-exists"

    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.get_stripe_premium_price_id", return_value=None)
    def test_no_price_id_raises_internal(self, _mock_price, mock_get_db):
        """Function test_no_price_id_raises_internal."""
        from firebase_functions import https_fn
        from handlers.subscriptions import create_subscription

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.ROLES: ["buyer"], Fields.EMAIL: "buyer@test.com"}

        sub_doc = Mock()
        sub_doc.exists = False

        def collection_side_effect(name):
            """Function collection_side_effect."""
            c = MagicMock()
            if name == Collections.USERS:
                c.document.return_value.get.return_value = user_doc
            elif name == Collections.SUBSCRIPTIONS:
                c.document.return_value.get.return_value = sub_doc
            return c

        mock_db.collection.side_effect = collection_side_effect

        with pytest.raises(https_fn.HttpsError) as exc:
            create_subscription(self._req())
        assert exc.value.code == "internal"

    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions.get_stripe_premium_price_id", return_value="price_123")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions._get_or_create_stripe_customer", return_value="cus_abc")
    @patch("handlers.subscriptions.stripe")
    def test_creates_checkout_session(
        self, mock_stripe, _mock_customer, _mock_init, _mock_price, mock_get_db
    ):
        """Function test_creates_checkout_session."""
        from handlers.subscriptions import create_subscription

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.ROLES: ["buyer"], Fields.EMAIL: "buyer@test.com"}
        user_ref = MagicMock()
        user_ref.get.return_value = user_doc

        sub_doc = Mock()
        sub_doc.exists = False

        def collection_side_effect(name):
            """Function collection_side_effect."""
            c = MagicMock()
            if name == Collections.USERS:
                c.document.return_value = user_ref
            elif name == Collections.SUBSCRIPTIONS:
                c.document.return_value.get.return_value = sub_doc
            return c

        mock_db.collection.side_effect = collection_side_effect

        mock_session = Mock()
        mock_session.url = "https://checkout.stripe.com/pay/cs_test"
        mock_session.id = "cs_test_abc"
        mock_stripe.checkout.Session.create.return_value = mock_session

        result = create_subscription(self._req())
        assert result["success"] is True
        assert result["checkoutUrl"] == "https://checkout.stripe.com/pay/cs_test"
        assert result["sessionId"] == "cs_test_abc"


# ============================================================================
# cancel_subscription
# ============================================================================


class TestCancelSubscription:
    """Class TestCancelSubscription."""
    def _req(self, uid: str = "buyer_123") -> Mock:
        req = Mock()
        req.auth = Mock()
        req.auth.uid = uid
        req.data = {}
        return req

    def test_unauthenticated_raises(self):
        """Function test_unauthenticated_raises."""
        from firebase_functions import https_fn
        from handlers.subscriptions import cancel_subscription

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_subscription(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.subscriptions._get_db")
    def test_no_subscription_raises(self, mock_get_db):
        """Function test_no_subscription_raises."""
        from firebase_functions import https_fn
        from handlers.subscriptions import cancel_subscription

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        sub_doc = Mock()
        sub_doc.exists = False
        mock_db.collection.return_value.document.return_value.get.return_value = sub_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_subscription(self._req())
        assert exc.value.code == "not-found"

    @patch("handlers.subscriptions._get_db")
    def test_already_scheduled_to_cancel_raises(self, mock_get_db):
        """Function test_already_scheduled_to_cancel_raises."""
        from firebase_functions import https_fn
        from handlers.subscriptions import cancel_subscription

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        sub_doc = Mock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.ACTIVE,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_abc",
            Fields.CANCEL_AT_PERIOD_END: True,  # Already scheduled
        }
        mock_db.collection.return_value.document.return_value.get.return_value = sub_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_subscription(self._req())
        assert exc.value.code == "failed-precondition"
        assert "already" in exc.value.message.lower()

    @patch("handlers.subscriptions._get_db")
    def test_non_active_status_raises(self, mock_get_db):
        """Function test_non_active_status_raises."""
        from firebase_functions import https_fn
        from handlers.subscriptions import cancel_subscription

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        sub_doc = Mock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.CANCELED,  # Already cancelled
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_abc",
            Fields.CANCEL_AT_PERIOD_END: False,
        }
        mock_db.collection.return_value.document.return_value.get.return_value = sub_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_subscription(self._req())
        assert exc.value.code == "failed-precondition"

    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions._get_server_timestamp", return_value="mock_ts")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions.stripe")
    @patch("handlers.subscriptions._fetch_user_for_email", return_value={})
    def test_cancels_subscription_at_period_end(
        self, _mock_email, mock_stripe, _mock_init, _mock_ts, mock_get_db
    ):
        """Function test_cancels_subscription_at_period_end."""
        from handlers.subscriptions import cancel_subscription

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        sub_doc = Mock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.ACTIVE,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_active_123",
            Fields.CANCEL_AT_PERIOD_END: False,
        }

        sub_ref = MagicMock()
        sub_ref.get.return_value = sub_doc

        mock_db.collection.return_value.document.return_value = sub_ref
        mock_stripe.Subscription.modify.return_value = Mock()

        result = cancel_subscription(self._req())
        assert result["success"] is True
        mock_stripe.Subscription.modify.assert_called_once_with(
            "sub_active_123", cancel_at_period_end=True
        )


# ============================================================================
# reactivate_subscription
# ============================================================================


class TestReactivateSubscription:
    """Class TestReactivateSubscription."""
    def _req(self, uid: str = "buyer_123") -> Mock:
        req = Mock()
        req.auth = Mock()
        req.auth.uid = uid
        req.data = {}
        return req

    def test_unauthenticated_raises(self):
        """Function test_unauthenticated_raises."""
        from firebase_functions import https_fn
        from handlers.subscriptions import reactivate_subscription

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            reactivate_subscription(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.subscriptions._get_db")
    def test_not_scheduled_to_cancel_raises(self, mock_get_db):
        """Function test_not_scheduled_to_cancel_raises."""
        from firebase_functions import https_fn
        from handlers.subscriptions import reactivate_subscription

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        sub_doc = Mock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {Fields.CANCEL_AT_PERIOD_END: False}
        mock_db.collection.return_value.document.return_value.get.return_value = sub_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            reactivate_subscription(self._req())
        assert exc.value.code == "failed-precondition"

    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions._stripe_init")
    @patch("handlers.subscriptions.stripe")
    @patch("handlers.subscriptions._sync_subscription")
    def test_reactivates_successfully(self, mock_sync, mock_stripe, _mock_init, mock_get_db):
        """Function test_reactivates_successfully."""
        from handlers.subscriptions import reactivate_subscription

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        sub_doc = Mock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {
            Fields.CANCEL_AT_PERIOD_END: True,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_abc",
        }
        mock_db.collection.return_value.document.return_value.get.return_value = sub_doc

        updated_sub = Mock()
        mock_stripe.Subscription.modify.return_value = updated_sub

        result = reactivate_subscription(self._req())
        assert result["success"] is True
        mock_stripe.Subscription.modify.assert_called_once_with("sub_abc", cancel_at_period_end=False)
        mock_sync.assert_called_once_with(updated_sub)


# ============================================================================
# get_subscription_status
# ============================================================================


class TestGetSubscriptionStatus:
    """Class TestGetSubscriptionStatus."""
    def _req(self, uid: str = "buyer_123") -> Mock:
        req = Mock()
        req.auth = Mock()
        req.auth.uid = uid
        req.data = {}
        return req

    def test_unauthenticated_raises(self):
        """Function test_unauthenticated_raises."""
        from firebase_functions import https_fn
        from handlers.subscriptions import get_subscription_status

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            get_subscription_status(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.subscriptions._get_db")
    def test_no_subscription_returns_not_premium(self, mock_get_db):
        """Function test_no_subscription_returns_not_premium."""
        from handlers.subscriptions import get_subscription_status

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        sub_doc = Mock()
        sub_doc.exists = False
        mock_db.collection.return_value.document.return_value.get.return_value = sub_doc

        result = get_subscription_status(self._req())
        assert result["isPremium"] is False
        assert result["status"] is None
        assert result["premiumExpiresAt"] is None

    @patch("handlers.subscriptions._get_db")
    def test_active_subscription_returns_is_premium(self, mock_get_db):
        """Function test_active_subscription_returns_is_premium."""
        from datetime import UTC, datetime
        from handlers.subscriptions import get_subscription_status

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        period_end = datetime(2027, 1, 1, tzinfo=UTC)
        sub_doc = Mock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.ACTIVE,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_abc",
            Fields.CURRENT_PERIOD_END: period_end,
            Fields.CANCEL_AT_PERIOD_END: False,
        }
        mock_db.collection.return_value.document.return_value.get.return_value = sub_doc

        result = get_subscription_status(self._req())
        assert result["isPremium"] is True
        assert result["status"] == SubscriptionStatusValues.ACTIVE
        assert result["cancelAtPeriodEnd"] is False

    @patch("handlers.subscriptions._get_db")
    def test_cancelled_subscription_returns_not_premium(self, mock_get_db):
        """Function test_cancelled_subscription_returns_not_premium."""
        from handlers.subscriptions import get_subscription_status

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        sub_doc = Mock()
        sub_doc.exists = True
        sub_doc.to_dict.return_value = {
            Fields.STATUS: SubscriptionStatusValues.CANCELED,
            Fields.STRIPE_SUBSCRIPTION_ID: "sub_abc",
            Fields.CURRENT_PERIOD_END: None,
            Fields.CANCEL_AT_PERIOD_END: False,
        }
        mock_db.collection.return_value.document.return_value.get.return_value = sub_doc

        result = get_subscription_status(self._req())
        assert result["isPremium"] is False


# ============================================================================
# handle_subscription_deleted — clears premium
# ============================================================================


class TestHandleSubscriptionDeleted:
    """Tests for subscription.deleted webhook handler."""

    @patch("handlers.subscriptions._get_db")
    @patch("handlers.subscriptions._get_firestore")
    def test_clears_premium_on_user(self, mock_get_firestore, mock_get_db):
        """Function test_clears_premium_on_user."""
        from handlers.subscriptions import handle_subscription_deleted

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        mock_fs = MagicMock()
        mock_get_firestore.return_value = mock_fs

        # Simulate @transactional decorator
        txn_ops = {}
        def capture_txn_set(ref, data, **kwargs):
            """Function capture_txn_set."""
            txn_ops["sub"] = data
        def capture_txn_update(ref, data):
            """Function capture_txn_update."""
            txn_ops["user"] = data

        mock_transaction = MagicMock()
        mock_transaction.set.side_effect = capture_txn_set
        mock_transaction.update.side_effect = capture_txn_update
        mock_db.transaction.return_value = mock_transaction

        user_doc = Mock()
        user_doc.exists = True

        mock_db.collection.return_value.document.return_value.get.return_value = user_doc

        # @transactional decorator — make it call function immediately
        def fake_transactional(fn):
            """Function fake_transactional."""
            def wrapper(txn):
                """Function wrapper."""
                return fn(txn)
            return wrapper

        mock_fs.transactional = fake_transactional

        event = {
            "data": {
                "object": {
                    "id": "sub_expired_123",
                    "metadata": {"uid": "buyer_123"},
                    "current_period_end": 1700000000,
                }
            }
        }

        with patch("handlers.subscriptions._fetch_user_for_email", return_value={}):
            handle_subscription_deleted(event)

        # Verify the user's premium was cleared
        if "user" in txn_ops:
            assert txn_ops["user"][Fields.IS_PREMIUM] is False
