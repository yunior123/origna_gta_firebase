from types import SimpleNamespace
from unittest.mock import Mock, patch

import pytest
import stripe
from firebase_functions import https_fn

from schema_constants import (
    ApiKeys,
    Collections,
    DeliveryStatusValues,
    DeliveryTypeValues,
    Fields,
    OrderItemIdValues,
    OrderStatusValues,
    PaymentStatusValues,
    ShippingApprovalStatusValues,
)


def _snap(data=None, *, exists=True):
    snap = Mock()
    snap.exists = exists
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _query(*, stream_return=None):
    q = Mock()
    q.where.return_value = q
    q.limit.return_value = q
    q.order_by.return_value = q
    q.stream.return_value = [] if stream_return is None else stream_return
    return q


class TestUpdateOrderStatusDeep:
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_order_status_rate_limited_returns_resource_exhausted(self, mock_get_db, mock_rl):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (False, "too many")
        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED}

        with pytest.raises(https_fn.HttpsError) as exc:
            update_order_status(req)
        assert exc.value.code == "resource-exhausted"
        mock_get_db.return_value.collection.assert_not_called()

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_order_status_blocks_archived_orders(self, mock_get_db, mock_rl):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        order_ref.get.return_value = _snap({Fields.ARCHIVED: True, Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED})
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED}

        with pytest.raises(https_fn.HttpsError) as exc:
            update_order_status(req)
        assert exc.value.code == "failed-precondition"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_order_status_requires_existing_user_doc(self, mock_get_db, mock_rl):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap(exists=False)

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED}

        with pytest.raises(https_fn.HttpsError) as exc:
            update_order_status(req)
        assert exc.value.code == "not-found"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_order_status_blocks_shipping_when_approval_pending(self, mock_get_db, mock_rl):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
                Fields.SHIPPING_APPROVAL: {Fields.STATUS: ShippingApprovalStatusValues.PENDING},
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED}
        with pytest.raises(https_fn.HttpsError) as exc:
            update_order_status(req)
        assert exc.value.code == "failed-precondition"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_order_status_blocks_shipping_when_approval_rejected(self, mock_get_db, mock_rl):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
                Fields.SHIPPING_APPROVAL: {Fields.STATUS: ShippingApprovalStatusValues.REJECTED},
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED}

        with pytest.raises(https_fn.HttpsError) as exc:
            update_order_status(req)
        assert exc.value.code == "failed-precondition"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.is_valid_order_status_transition", return_value=False)
    @patch("handlers.orders.get_db")
    def test_update_order_status_rejects_invalid_transition(self, mock_get_db, _mock_transition, mock_rl):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED}

        with pytest.raises(https_fn.HttpsError) as exc:
            update_order_status(req)
        assert exc.value.code == "failed-precondition"

    @patch("handlers.orders.get_firestore")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("handlers.orders.get_db")
    def test_update_order_status_seller_transaction_missing_fresh_order_returns_permission_denied(
        self, mock_get_db, _mock_transition, mock_rl, mock_get_fs
    ):
        from handlers.orders import update_order_status

        mock_get_fs.return_value.transactional = lambda fn: fn
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        # Initial read for top-level checks.
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
            }
        )
        # Transactional re-read returns missing fresh doc.
        missing_fresh = _snap(exists=False)
        order_ref.get.side_effect = [order_ref.get.return_value, missing_fresh]

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED}

        with pytest.raises(https_fn.HttpsError) as exc:
            update_order_status(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.OrderEvent.write")
    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_db")
    def test_update_order_status_admin_shipped_cascades_item_statuses(
        self,
        mock_get_db,
        _mock_ts,
        mock_rl,
        _mock_transition,
        _mock_event,
        _mock_resp,
    ):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [
                    {Fields.STATUS: DeliveryStatusValues.PENDING, Fields.SELLER_ID: "s1"},
                    {Fields.STATUS: DeliveryStatusValues.DELIVERED, Fields.SELLER_ID: "s1"},
                ],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["admin"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="admin_1")
        req.data = {
            Fields.ORDER_ID: "order_1",
            ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED,
            Fields.TRACKING_NUMBER: "TRK-1",
            Fields.CARRIER: "CarrierX",
        }

        out = update_order_status(req)

        assert out["success"] is True
        update_payload = order_ref.update.call_args.args[0]
        assert update_payload[Fields.ORDER_STATUS] == OrderStatusValues.SHIPPED
        assert update_payload[Fields.SHIPPED_AT] == "ts"
        assert update_payload[Fields.TRACKING_NUMBER] == "TRK-1"
        assert update_payload[Fields.ITEMS][0][Fields.STATUS] == DeliveryStatusValues.SHIPPED
        assert update_payload[Fields.ITEMS][1][Fields.STATUS] == DeliveryStatusValues.DELIVERED

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_order_status_blocks_multi_seller_order_level_shipping(self, mock_get_db, mock_rl):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.ITEMS: [
                {Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING},
                {Fields.SELLER_ID: "seller_2", Fields.STATUS: DeliveryStatusValues.PENDING},
            ],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data)

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED}

        with pytest.raises(https_fn.HttpsError) as exc:
            update_order_status(req)
        assert exc.value.code == "failed-precondition"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_order_status_blocks_manual_shipping_for_digital_items(self, mock_get_db, mock_rl):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1", Fields.IS_DIGITAL: True}],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED}

        with pytest.raises(https_fn.HttpsError) as exc:
            update_order_status(req)
        assert exc.value.code == "failed-precondition"

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("handlers.orders.get_firestore")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_order_status_seller_transaction_updates_own_items(
        self, mock_get_db, mock_rl, mock_get_fs, _mock_transition, _mock_resp
    ):
        from handlers.orders import update_order_status

        mock_get_fs.return_value.transactional = lambda fn: fn
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.ITEMS: [
                {Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING, Fields.PRODUCT_ID: "p1"},
                {Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING, Fields.PRODUCT_ID: "p2"},
            ],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data)
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {
            Fields.ORDER_ID: "order_1",
            ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED,
            Fields.TRACKING_NUMBER: "TRK123",
            Fields.CARRIER: "Purolator",
        }

        out = update_order_status(req)

        assert out["success"] is True
        assert out[ApiKeys.NEW_STATUS] == OrderStatusValues.SHIPPED
        tx.update.assert_called_once()

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.OrderEvent.write")
    @patch("handlers.orders.get_stripe_secret_key", return_value="sk_test")
    @patch("handlers.orders.stripe")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_order_status_admin_delivered_captures_payment(
        self, mock_get_db, mock_rl, mock_stripe, _mock_key, mock_event, _mock_resp
    ):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_stripe.PaymentIntent.retrieve.return_value = SimpleNamespace(status="requires_capture")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123",
                Fields.ITEMS: [{Fields.STATUS: DeliveryStatusValues.SHIPPED}],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["admin"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="admin_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.DELIVERED}

        out = update_order_status(req)
        assert out["success"] is True
        mock_stripe.PaymentIntent.capture.assert_called_once()
        mock_event.assert_called_once()

    @patch("handlers.orders.get_stripe_secret_key", return_value="sk_test")
    @patch("handlers.orders.stripe")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_order_status_admin_capture_failure_returns_internal(
        self, mock_get_db, mock_rl, mock_stripe, _mock_key
    ):
        from handlers.orders import update_order_status

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_stripe.PaymentIntent.retrieve.side_effect = RuntimeError("stripe down")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123",
                Fields.ITEMS: [{Fields.STATUS: DeliveryStatusValues.SHIPPED}],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["admin"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="admin_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.NEW_STATUS: OrderStatusValues.DELIVERED}

        with pytest.raises(https_fn.HttpsError) as exc:
            update_order_status(req)
        assert exc.value.code == "internal"


class TestUpdateItemStatusDeep:
    def test_update_item_status_callable_requires_auth(self):
        from handlers.orders import update_item_status

        req = Mock()
        req.auth = None
        req.data = {}

        with pytest.raises(https_fn.HttpsError) as exc:
            update_item_status(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.orders._update_item_status_logic", return_value={"success": True})
    def test_update_item_status_callable_delegates_to_logic(self, mock_logic):
        from handlers.orders import update_item_status

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1"}

        out = update_item_status(req)
        assert out["success"] is True
        mock_logic.assert_called_once_with("seller_1", req.data)

    def test_update_item_status_logic_requires_order_product_and_status(self):
        from handlers.orders import _update_item_status_logic

        with pytest.raises(https_fn.HttpsError) as exc:
            _update_item_status_logic("seller_1", {})
        assert exc.value.code == "invalid-argument"

    @patch("services.rate_limiter.RateLimiter")
    def test_update_item_status_logic_rate_limited(self, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (False, "too many")

        with pytest.raises(https_fn.HttpsError) as exc:
            _update_item_status_logic(
                "seller_1",
                {
                    Fields.ORDER_ID: "order_1",
                    Fields.PRODUCT_ID: "p1",
                    ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED,
                },
            )
        assert exc.value.code == "resource-exhausted"

    @patch("services.rate_limiter.RateLimiter")
    def test_update_item_status_logic_rejects_invalid_status_value(self, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        with pytest.raises(https_fn.HttpsError) as exc:
            _update_item_status_logic(
                "seller_1",
                {
                    Fields.ORDER_ID: "order_1",
                    Fields.PRODUCT_ID: "p1",
                    ApiKeys.NEW_STATUS: "teleported",
                },
            )
        assert exc.value.code == "invalid-argument"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_item_status_logic_blocks_archived_order(self, mock_get_db, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        order_ref.get.return_value = _snap({Fields.ARCHIVED: True, Fields.ITEMS: []})
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            _update_item_status_logic(
                "seller_1",
                {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED},
            )
        assert exc.value.code == "failed-precondition"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_item_status_logic_order_not_found(self, mock_get_db, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        order_ref.get.return_value = _snap(exists=False)
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            _update_item_status_logic(
                "admin_1",
                {Fields.ORDER_ID: "order_missing", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED},
                is_admin=True,
            )
        assert exc.value.code == "not-found"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_item_status_logic_requires_user_doc_when_is_admin_not_forced(self, mock_get_db, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}]}
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap(exists=False)

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            _update_item_status_logic(
                "seller_1",
                {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED},
            )
        assert exc.value.code == "not-found"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_item_status_logic_all_sentinel_no_items_for_seller(self, mock_get_db, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "other_seller", Fields.STATUS: DeliveryStatusValues.PENDING}],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            _update_item_status_logic(
                "seller_1",
                {
                    Fields.ORDER_ID: "order_1",
                    Fields.PRODUCT_ID: OrderItemIdValues.ALL,
                    ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED,
                },
                is_admin=False,
            )
        assert exc.value.code == "not-found"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_db")
    def test_update_item_status_logic_all_sentinel_sets_carrier_when_provided(self, mock_get_db, _mock_ts, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        out = _update_item_status_logic(
            "seller_1",
            {
                Fields.ORDER_ID: "order_1",
                Fields.PRODUCT_ID: OrderItemIdValues.ALL,
                ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED,
                Fields.TRACKING_NUMBER: "TRK-1",
                Fields.CARRIER: "DHL",
            },
            is_admin=False,
        )
        assert out["success"] is True
        update_payload = order_ref.update.call_args.args[0]
        assert update_payload[Fields.ITEMS][0][Fields.CARRIER] == "DHL"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_db")
    def test_update_item_status_logic_all_sentinel_delivered_sets_delivered_at(
        self, mock_get_db, _mock_ts, mock_rl
    ):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.SHIPPED}],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        out = _update_item_status_logic(
            "admin_1",
            {
                Fields.ORDER_ID: "order_1",
                Fields.PRODUCT_ID: OrderItemIdValues.ALL,
                ApiKeys.NEW_STATUS: DeliveryStatusValues.DELIVERED,
            },
            is_admin=True,
        )
        assert out["success"] is True
        update_payload = order_ref.update.call_args.args[0]
        assert Fields.DELIVERED_AT in update_payload[Fields.ITEMS][0]

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_item_status_logic_single_item_permission_and_state_guards(self, mock_get_db, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        base_order = {
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
            Fields.DELIVERY_SPEED: "standard",
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }

        order_ref = Mock()
        user_ref = Mock()
        orders_col = Mock()
        users_col = Mock()
        orders_col.document.return_value = order_ref
        users_col.document.return_value = user_ref

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        # Product missing
        order_ref.get.return_value = _snap({Fields.ITEMS: []})
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"], Fields.SUSPENDED: False})
        with pytest.raises(https_fn.HttpsError) as missing:
            _update_item_status_logic(
                "seller_1",
                {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p_missing", ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED},
            )
        assert missing.value.code == "not-found"

        # Not seller/admin
        order_ref.get.return_value = _snap(base_order)
        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"], Fields.SUSPENDED: False})
        with pytest.raises(https_fn.HttpsError) as denied:
            _update_item_status_logic(
                "other_user",
                {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED},
            )
        assert denied.value.code == "permission-denied"

        # Suspended seller
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"], Fields.SUSPENDED: True})
        with pytest.raises(https_fn.HttpsError) as suspended:
            _update_item_status_logic(
                "seller_1",
                {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED},
            )
        assert suspended.value.code == "permission-denied"

        # Seller cannot self-mark delivered
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"], Fields.SUSPENDED: False})
        with pytest.raises(https_fn.HttpsError) as self_delivered:
            _update_item_status_logic(
                "seller_1",
                {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.DELIVERED},
            )
        assert self_delivered.value.code == "permission-denied"

        # Invalid transition from pending -> refunded
        with pytest.raises(https_fn.HttpsError) as bad_transition:
            _update_item_status_logic(
                "seller_1",
                {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.REFUNDED},
            )
        assert bad_transition.value.code == "failed-precondition"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_item_status_logic_transaction_item_missing_raises_not_found(self, mock_get_db, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        initial_order = {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.DELIVERY_SPEED: DeliveryTypeValues.PICKUP,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
        }
        fresh_order_without_item = {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.ITEMS: [{Fields.PRODUCT_ID: "other", Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
        }

        order_ref = Mock()
        order_ref.get.side_effect = [_snap(initial_order), _snap(fresh_order_without_item)]
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"], Fields.SUSPENDED: False})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            _update_item_status_logic(
                "seller_1",
                {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED},
                is_admin=False,
            )
        assert exc.value.code == "not-found"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_item_status_all_admin_updates_every_item(self, mock_get_db, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ITEMS: [
                    {Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "s1", Fields.STATUS: DeliveryStatusValues.PENDING},
                    {Fields.PRODUCT_ID: "p2", Fields.SELLER_ID: "s2", Fields.STATUS: DeliveryStatusValues.PENDING},
                ],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        out = _update_item_status_logic(
            "admin_1",
            {
                Fields.ORDER_ID: "order_1",
                Fields.PRODUCT_ID: OrderItemIdValues.ALL,
                ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED,
                Fields.TRACKING_NUMBER: "TRK-ALL",
            },
            is_admin=True,
        )
        assert out["success"] is True
        order_ref.update.assert_called_once()

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.OrderEvent.write")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_item_status_pickup_shipped_without_tracking_is_allowed(
        self, mock_get_db, mock_rl, _mock_event, _mock_resp
    ):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.DELIVERY_SPEED: DeliveryTypeValues.PICKUP,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"], Fields.SUSPENDED: False})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        out = _update_item_status_logic(
            "seller_1",
            {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED},
            is_admin=False,
        )
        assert out["success"] is True
        tx.update.assert_called_once()

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_item_status_non_pickup_shipped_requires_tracking(self, mock_get_db, mock_rl):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.DELIVERY_SPEED: "standard",
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"], Fields.SUSPENDED: False})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            _update_item_status_logic(
                "seller_1",
                {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.SHIPPED},
                is_admin=False,
            )
        assert exc.value.code == "invalid-argument"

    @patch("handlers.orders.logger.warning")
    @patch("handlers.orders.OrderEvent.write")
    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_item_status_single_item_delivered_uncaptured_payment_skips_order_promotion(
        self,
        mock_get_db,
        mock_rl,
        _mock_resp,
        _mock_event,
        mock_warning,
    ):
        from handlers.orders import _update_item_status_logic

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_payload = {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.DELIVERY_SPEED: DeliveryTypeValues.STANDARD,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.SHIPPED}],
        }
        order_ref = Mock()
        order_ref.get.side_effect = [_snap(order_payload), _snap(order_payload)]

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db = Mock()
        tx = Mock()
        db.transaction.return_value = tx
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        out = _update_item_status_logic(
            "admin_1",
            {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "p1", ApiKeys.NEW_STATUS: DeliveryStatusValues.DELIVERED},
            is_admin=True,
        )
        assert out["success"] is True
        update_payload = tx.update.call_args.args[1]
        assert update_payload.get(Fields.ORDER_STATUS) != OrderStatusValues.DELIVERED
        assert mock_warning.called


class TestCancelOrderDeep:
    @patch("services.rate_limiter.RateLimiter")
    def test_cancel_order_rate_limited(self, mock_rl):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.ORDER_ID: "order_1"}

        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_order(req)
        assert exc.value.code == "resource-exhausted"

    @patch("services.rate_limiter.RateLimiter")
    def test_cancel_order_requires_order_id(self, mock_rl):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {}

        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_order(req)
        assert exc.value.code == "invalid-argument"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_cancel_order_not_found_archived_and_missing_user(self, mock_get_db, mock_rl):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_ref = Mock()
        user_ref = Mock()
        orders_col = Mock()
        users_col = Mock()
        orders_col.document.return_value = order_ref
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.ORDER_ID: "order_1"}

        order_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as not_found:
            cancel_order(req)
        assert not_found.value.code == "not-found"

        order_ref.get.return_value = _snap({Fields.ARCHIVED: True, Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED})
        with pytest.raises(https_fn.HttpsError) as archived:
            cancel_order(req)
        assert archived.value.code == "failed-precondition"

        order_ref.get.return_value = _snap(
            {
                Fields.ARCHIVED: False,
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.USER_ID: "buyer_1",
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            }
        )
        user_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing_user:
            cancel_order(req)
        assert missing_user.value.code == "not-found"

    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_cancel_order_blocks_buyer_in_non_cancellable_stage(self, mock_get_db, mock_rl, _mock_transition):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.ORDER_ID: "order_1", ApiKeys.REASON: "changed mind"}

        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_order(req)
        assert exc.value.code == "failed-precondition"

    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_cancel_order_blocks_seller_on_multi_seller_order(self, mock_get_db, mock_rl, _mock_transition):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}, {Fields.SELLER_ID: "seller_2"}],
            }
        )
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.ORDER_ID: "order_1"}

        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_order(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.OrderEvent.write")
    @patch("handlers.orders._restore_stock_to_batch")
    @patch("handlers.orders.get_stripe_secret_key", return_value="sk_test")
    @patch("handlers.orders.stripe")
    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_cancel_order_authorized_payment_success_path(
        self,
        mock_get_db,
        mock_rl,
        _mock_transition,
        mock_stripe,
        _mock_key,
        mock_restore,
        mock_event,
        _mock_resp,
    ):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123",
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
        }

        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data)
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        tx = Mock()
        batch = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.batch.return_value = batch
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.ORDER_ID: "order_1"}

        out = cancel_order(req)
        assert out["success"] is True
        assert out["refunded"] is False
        mock_stripe.PaymentIntent.cancel.assert_called_once()
        batch.commit.assert_called_once()
        mock_restore.assert_called_once()
        mock_event.assert_called_once()

    @patch("handlers.orders._restore_stock_to_batch")
    @patch("handlers.orders.get_stripe_secret_key", return_value="sk_test")
    @patch("handlers.orders.stripe")
    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_cancel_order_batch_commit_failure_flags_cancel_failed(
        self, mock_get_db, mock_rl, _mock_transition, mock_stripe, _mock_key, mock_restore
    ):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123",
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data)
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        tx = Mock()
        batch = Mock()
        batch.commit.side_effect = RuntimeError("firestore down")

        db = Mock()
        db.transaction.return_value = tx
        db.batch.return_value = batch
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.ORDER_ID: "order_1"}

        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_order(req)
        assert exc.value.code == "internal"
        assert order_ref.update.called
        mock_restore.assert_called_once()

    @patch("handlers.orders.get_stripe_secret_key", return_value="sk_test")
    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_cancel_order_captured_refund_error_sets_manual_review(
        self, mock_get_db, mock_rl, _mock_transition, _mock_key
    ):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123",
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data)
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        with patch("handlers.orders.stripe.Refund.create", side_effect=stripe.error.StripeError("refund failure")):
            req = Mock()
            req.auth = Mock(uid="buyer_1")
            req.data = {Fields.ORDER_ID: "order_1"}

            with pytest.raises(https_fn.HttpsError) as exc:
                cancel_order(req)
            assert exc.value.code == "internal"
            assert order_ref.update.called

    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_cancel_order_lock_for_cancel_guards(self, mock_get_db, mock_rl, _mock_transition):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        base_order = {
            Fields.USER_ID: "buyer_1",
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
        }

        order_ref = Mock()
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"]})
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.ORDER_ID: "order_1"}

        order_ref.get.side_effect = [
            _snap(base_order),
            _snap(base_order | {Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURING}),
        ]
        with pytest.raises(https_fn.HttpsError) as in_progress:
            cancel_order(req)
        assert in_progress.value.code == "failed-precondition"

        order_ref.get.side_effect = [
            _snap(base_order),
            _snap(base_order | {Fields.ORDER_STATUS: OrderStatusValues.SHIPPED}),
        ]
        with pytest.raises(https_fn.HttpsError) as changed:
            cancel_order(req)
        assert changed.value.code == "failed-precondition"

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.OrderEvent.write")
    @patch("handlers.orders._restore_stock_to_batch")
    @patch("handlers.orders.get_stripe_secret_key", return_value="sk_test")
    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_cancel_order_captured_refund_success_path(
        self,
        mock_get_db,
        mock_rl,
        _mock_transition,
        _mock_key,
        mock_restore,
        _mock_event,
        _mock_resp,
    ):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123",
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data)
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"]})
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        db = Mock()
        db.transaction.return_value = Mock()
        db.batch.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        with patch("handlers.orders.stripe.Refund.create", return_value=SimpleNamespace(id="re_1")):
            req = Mock()
            req.auth = Mock(uid="buyer_1")
            req.data = {Fields.ORDER_ID: "order_1"}
            out = cancel_order(req)
        assert out["success"] is True
        assert out["refunded"] is True
        mock_restore.assert_called_once()

    @patch("handlers.orders.get_stripe_secret_key", return_value="sk_test")
    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_cancel_order_authorized_cancel_stripe_error_sets_cancel_failed(
        self, mock_get_db, mock_rl, _mock_transition, _mock_key
    ):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123",
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data)
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"]})
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        with patch("handlers.orders.stripe.PaymentIntent.cancel", side_effect=stripe.error.StripeError("cancel failed")):
            req = Mock()
            req.auth = Mock(uid="buyer_1")
            req.data = {Fields.ORDER_ID: "order_1"}
            with pytest.raises(https_fn.HttpsError) as exc:
                cancel_order(req)
        assert exc.value.code == "internal"
        assert order_ref.update.called

    @patch("handlers.orders._restore_stock_to_batch")
    @patch("handlers.orders.get_stripe_secret_key", return_value="sk_test")
    @patch("handlers.orders.stripe")
    @patch("handlers.orders.is_valid_order_status_transition", return_value=True)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_cancel_order_batch_commit_failure_and_cancel_failed_update_failure(
        self, mock_get_db, mock_rl, _mock_transition, _mock_stripe, _mock_key, _mock_restore
    ):
        from handlers.orders import cancel_order

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123",
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data)
        order_ref.update.side_effect = RuntimeError("cannot mark cancel_failed")
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"]})
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        batch = Mock()
        batch.commit.side_effect = RuntimeError("batch fail")

        db = Mock()
        db.transaction.return_value = Mock()
        db.batch.return_value = batch
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.ORDER_ID: "order_1"}
        with pytest.raises(https_fn.HttpsError) as exc:
            cancel_order(req)
        assert exc.value.code == "internal"
