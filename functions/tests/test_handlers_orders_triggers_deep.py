import importlib
import sys
from unittest.mock import Mock, patch

import pytest

from schema_constants import (
    Collections,
    DeliveryStatusValues,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
    ReturnStatusValues,
)


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _decorator_passthrough(*args, **kwargs):
    if len(args) == 1 and callable(args[0]) and not kwargs:
        return args[0]

    def _decorator(func):
        return func

    return _decorator


@pytest.fixture(autouse=True)
def _reload_orders_module_with_firestore_passthrough():
    ff = sys.modules["firebase_functions"]
    if not hasattr(ff, "firestore_fn"):
        ff.firestore_fn = Mock()
    ff.firestore_fn.on_document_updated = _decorator_passthrough
    ff.firestore_fn.on_document_created = _decorator_passthrough
    ff.firestore_fn.on_document_deleted = _decorator_passthrough

    import handlers.orders as orders

    importlib.reload(orders)
    yield


class TestOrderTriggerPathsDeep:
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_order_refunded_email", return_value="<p>refunded</p>")
    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_handle_payment_status_email_refunded_sends_email_once(
        self,
        mock_get_db,
        mock_get_firestore,
        _mock_template,
        mock_enqueue,
    ):
        from handlers.orders import _handle_payment_status_email

        mock_get_firestore.return_value.ArrayUnion.side_effect = lambda vals: ("au", vals)

        tx = Mock()
        order_ref = Mock()
        order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []})
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.collection.return_value = orders_col
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        after_data = {
            Fields.USER_ID: "buyer_1",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.CUMULATIVE_REFUNDED_CENTS: 500,
        }
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            _handle_payment_status_email("order_1", after_data, PaymentStatusValues.REFUNDED, buyer_email="buyer@example.com")

        tx.update.assert_called_once()
        mock_enqueue.assert_called_once()

    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_seller_notification_email", return_value="<p>seller</p>")
    @patch("handlers.orders.get_order_confirmation_email", return_value="<p>buyer</p>")
    @patch("handlers.orders._email_t", side_effect=lambda key, _lang="en": f"{key} {{oid}}")
    @patch("handlers.orders.get_db")
    def test_on_order_status_changed_confirmed_sends_buyer_seller_and_perishable_notifications(
        self,
        mock_get_db,
        _mock_email_t,
        _mock_buyer_tpl,
        _mock_seller_tpl,
        mock_enqueue,
        mock_push,
    ):
        from handlers.orders import on_order_status_changed

        tx = Mock()
        order_ref = Mock()
        order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []})

        orders_col = Mock()
        orders_col.document.return_value = order_ref

        seller_doc = _snap({Fields.EMAIL: "seller@example.com", Fields.PREFERRED_LANGUAGE: "en"}, doc_id="seller_1")
        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc

        stock_query = Mock()
        stock_query.where.return_value = stock_query
        stock_query.stream.return_value = []
        stock_col = Mock()
        stock_col.where.return_value = stock_query

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
            Collections.STOCK_NOTIFICATIONS: stock_col,
        }[name]
        db.transaction.return_value = tx
        db.get_all.return_value = [seller_doc]
        db.batch.return_value = Mock()
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.PENDING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.ITEMS: [
                {
                    Fields.SELLER_ID: "seller_1",
                    Fields.PRODUCT_ID: "prod_1",
                    Fields.VARIANT_KEY: "",
                    Fields.IS_PERISHABLE: True,
                    Fields.NAME: "Milk",
                }
            ],
        }
        event = Mock()
        event.params = {Fields.ORDER_ID: "order_1"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(event)

        assert mock_enqueue.call_count >= 3
        assert mock_push.call_count >= 2

    @patch("handlers.orders.send_push_notification")
    @patch("services.email_task.enqueue_email_task")
    @patch("handlers.orders.get_order_item_shipped_email", return_value="<p>shipped</p>")
    @patch("handlers.orders.get_db")
    def test_on_order_item_shipped_notifies_on_item_transition(
        self,
        mock_get_db,
        _mock_tpl,
        mock_enqueue,
        mock_push,
    ):
        from handlers.orders import on_order_item_shipped

        claim_ref = Mock()
        webhooks_col = Mock()
        webhooks_col.document.return_value = claim_ref

        user_doc = _snap({Fields.PREFERRED_LANGUAGE: "en"})
        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.WEBHOOK_EVENTS: webhooks_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.ITEMS: [
                {
                    Fields.CART_ITEM_ID: "ci_1",
                    Fields.STATUS: DeliveryStatusValues.SHIPPED,
                    Fields.NAME: "Headphones",
                    Fields.TRACKING_NUMBER: "TRK-1",
                    Fields.CARRIER: "UPS",
                }
            ],
        }
        event = Mock()
        event.params = {"orderId": "order_2"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        on_order_item_shipped(event)
        claim_ref.create.assert_called_once()
        mock_push.assert_called_once()
        mock_enqueue.assert_called_once()

    @patch("handlers.orders.get_db")
    def test_on_order_item_shipped_skips_when_order_status_transitions_to_shipped(self, mock_get_db):
        from handlers.orders import on_order_item_shipped

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
            Fields.DELIVERY_SPEED: "standard",
            Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.SHIPPED}],
        }
        event = Mock()
        event.params = {"orderId": "order_ship_skip"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        on_order_item_shipped(event)
        mock_get_db.assert_not_called()

    @patch("handlers.orders.send_push_notification")
    @patch("services.email_task.enqueue_email_task")
    @patch("handlers.orders.get_order_item_shipped_email", return_value="<p>shipped</p>")
    @patch("handlers.orders.get_db")
    def test_on_order_item_shipped_duplicate_claim_returns_early(
        self,
        mock_get_db,
        _mock_tpl,
        mock_enqueue,
        mock_push,
    ):
        from handlers.orders import on_order_item_shipped

        claim_ref = Mock()
        claim_ref.create.side_effect = RuntimeError("duplicate")
        webhooks_col = Mock()
        webhooks_col.document.return_value = claim_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.PREFERRED_LANGUAGE: "en"})

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.WEBHOOK_EVENTS: webhooks_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.SHIPPED}],
        }
        event = Mock()
        event.params = {"orderId": "order_dup"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        on_order_item_shipped(event)
        mock_push.assert_not_called()
        mock_enqueue.assert_not_called()

    @patch("handlers.orders.get_db")
    def test_on_order_item_shipped_requires_cart_item_ids(self, mock_get_db):
        from handlers.orders import on_order_item_shipped

        db = Mock()
        mock_get_db.return_value = db

        before = {Fields.ORDER_STATUS: OrderStatusValues.PROCESSING, Fields.ITEMS: [{}]}
        after = {Fields.ORDER_STATUS: OrderStatusValues.PROCESSING, Fields.ITEMS: [{}]}
        event = Mock()
        event.params = {"orderId": "order_bad_item"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        with pytest.raises(ValueError):
            on_order_item_shipped(event)

    @patch("handlers.orders.send_push_notification")
    @patch("services.email_task.enqueue_email_task")
    @patch("handlers.orders.get_order_item_delivered_email", return_value="<p>delivered</p>")
    @patch("handlers.orders.get_db")
    def test_on_order_item_delivered_notifies_on_item_transition(
        self,
        mock_get_db,
        _mock_tpl,
        mock_enqueue,
        mock_push,
    ):
        from handlers.orders import on_order_item_delivered

        claim_ref = Mock()
        webhooks_col = Mock()
        webhooks_col.document.return_value = claim_ref

        user_doc = _snap({Fields.PREFERRED_LANGUAGE: "en", Fields.EMAIL: "buyer@example.com"})
        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.WEBHOOK_EVENTS: webhooks_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        before = {
            Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.SHIPPED}],
        }
        after = {
            Fields.USER_ID: "buyer_1",
            Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.DELIVERED, Fields.NAME: "Headphones"}],
        }
        event = Mock()
        event.params = {"orderId": "order_3"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        on_order_item_delivered(event)
        claim_ref.create.assert_called_once()
        mock_push.assert_called_once()
        mock_enqueue.assert_called_once()

    @patch("handlers.orders.send_push_notification")
    @patch("services.email_task.enqueue_email_task")
    @patch("handlers.orders.get_order_item_delivered_email", return_value="<p>delivered</p>")
    @patch("handlers.orders.get_db")
    def test_on_order_item_delivered_duplicate_claim_is_ignored(
        self,
        mock_get_db,
        _mock_tpl,
        mock_enqueue,
        mock_push,
    ):
        from handlers.orders import on_order_item_delivered

        claim_ref = Mock()
        claim_ref.create.side_effect = RuntimeError("duplicate")
        webhooks_col = Mock()
        webhooks_col.document.return_value = claim_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.PREFERRED_LANGUAGE: "en"})

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.WEBHOOK_EVENTS: webhooks_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        before = {Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.SHIPPED}]}
        after = {
            Fields.USER_ID: "buyer_1",
            Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.DELIVERED}],
        }
        event = Mock()
        event.params = {"orderId": "order_dup_delivered"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        on_order_item_delivered(event)
        mock_push.assert_not_called()
        mock_enqueue.assert_not_called()

    @patch("handlers.orders.get_db")
    def test_on_order_item_delivered_returns_when_user_id_missing(self, mock_get_db):
        from handlers.orders import on_order_item_delivered

        claim_ref = Mock()
        webhooks_col = Mock()
        webhooks_col.document.return_value = claim_ref
        db = Mock()
        db.collection.return_value = webhooks_col
        mock_get_db.return_value = db

        before = {Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.SHIPPED}]}
        after = {Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.DELIVERED}]}
        event = Mock()
        event.params = {"orderId": "order_no_user"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        on_order_item_delivered(event)
        claim_ref.create.assert_not_called()

    @patch("handlers.orders._send_return_email")
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.get_db")
    def test_on_return_request_status_changed_approved_path(
        self,
        mock_get_db,
        mock_push,
        mock_send_return_email,
    ):
        from handlers.orders import on_return_request_status_changed

        tx = Mock()
        return_ref = Mock()
        return_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []})
        returns_col = Mock()
        returns_col.document.return_value = return_ref

        db = Mock()
        db.collection.return_value = returns_col
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        before = {Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED}
        after = {
            Fields.RETURN_STATUS: ReturnStatusValues.APPROVED,
            Fields.ORDER_ID: "order_4",
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
        }
        event = Mock()
        event.params = {"returnId": "ret_1"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_return_request_status_changed(event)

        tx.update.assert_called_once()
        mock_push.assert_called_once()
        mock_send_return_email.assert_called_once()
