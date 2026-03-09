import importlib
import sys
from unittest.mock import Mock, patch

import pytest

from schema_constants import (
    Collections,
    DeliveryTypeValues,
    Fields,
    NotificationTypes,
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


def _order_event(order_id: str, before: dict, after: dict):
    event = Mock()
    event.params = {Fields.ORDER_ID: order_id}
    event.data = Mock()
    event.data.before.to_dict.return_value = before
    event.data.after.to_dict.return_value = after
    return event


def _return_event(return_id: str, before: dict, after: dict):
    event = Mock()
    event.params = {"returnId": return_id}
    event.data = Mock()
    event.data.before.to_dict.return_value = before
    event.data.after.to_dict.return_value = after
    return event


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


def _prepare_db_for_order_status(order_id: str):
    tx = Mock()

    order_ref = Mock()
    order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, doc_id=order_id)

    orders_col = Mock()
    orders_col.document.return_value = order_ref

    seller_doc = _snap({Fields.EMAIL: "seller@example.com", Fields.PREFERRED_LANGUAGE: "en"}, doc_id="seller_1")
    buyer_doc = _snap({Fields.EMAIL: "buyer@example.com", Fields.PREFERRED_LANGUAGE: "en"}, doc_id="buyer_1")

    users_col = Mock()

    def _user_ref(uid):
        ref = Mock()
        if uid == "buyer_1":
            ref.get.return_value = buyer_doc
        else:
            ref.get.return_value = seller_doc
        return ref

    users_col.document.side_effect = _user_ref

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

    return db, tx


class TestOrderStatusChangedMore:
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_seller_notification_email", return_value="<p>seller shipped</p>")
    @patch("handlers.orders.get_order_shipped_email", return_value="<p>buyer shipped</p>")
    @patch("handlers.orders._email_t", side_effect=lambda key, _lang="en": f"{key} {{oid}}")
    @patch("handlers.orders.get_db")
    def test_shipped_branch_notifies_buyer_and_seller(
        self,
        mock_get_db,
        _mock_email_t,
        _mock_buyer_tpl,
        _mock_seller_tpl,
        mock_enqueue,
        mock_push,
    ):
        from handlers.orders import on_order_status_changed

        db, tx = _prepare_db_for_order_status("order_1")
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.TRACKING_NUMBER: "TRK-1",
            Fields.CARRIER: "UPS",
            Fields.DELIVERY_SPEED: "standard",
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
        }

        evt = _order_event("order_1", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        assert mock_enqueue.call_count >= 2
        assert mock_push.call_count >= 2

    @patch("services.email_service._email_wrapper", return_value="<p>wrapper</p>")
    @patch("services.email_service._hero_header", return_value="<h1>header</h1>")
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_db")
    def test_delivered_confirmed_branch_sends_buyer_and_seller_notifications(
        self,
        mock_get_db,
        mock_enqueue,
        mock_push,
        _mock_hh,
        _mock_ew,
    ):
        from handlers.orders import on_order_status_changed

        db, tx = _prepare_db_for_order_status("order_2")
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.CONFIRMED_BY_CLIENT: True,
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
        }

        evt = _order_event("order_2", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        assert mock_enqueue.call_count >= 2
        assert mock_push.call_count >= 2

    @patch("services.email_service._email_wrapper", return_value="<p>wrapper</p>")
    @patch("services.email_service._hero_header", return_value="<h1>header</h1>")
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_db")
    def test_failed_branch_sends_failure_email_and_push(
        self,
        mock_get_db,
        mock_enqueue,
        mock_push,
        _mock_hh,
        _mock_ew,
    ):
        from handlers.orders import on_order_status_changed

        db, tx = _prepare_db_for_order_status("order_3")
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.FAILED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.ITEMS: [],
        }

        evt = _order_event("order_3", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        mock_enqueue.assert_called_once()
        mock_push.assert_called_once()

    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_db")
    def test_pickup_shipped_skips_buyer_shipped_email(self, mock_get_db, mock_enqueue, mock_push):
        from handlers.orders import on_order_status_changed

        db, tx = _prepare_db_for_order_status("order_4")
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.DELIVERY_SPEED: DeliveryTypeValues.PICKUP,
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
        }

        evt = _order_event("order_4", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        assert mock_enqueue.call_count >= 1
        assert mock_push.call_count >= 2

    @patch("services.email_service._email_wrapper", return_value="<p>wrapper</p>")
    @patch("services.email_service._hero_header", return_value="<h1>header</h1>")
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_db")
    def test_expired_branch_sends_email_and_push(
        self,
        mock_get_db,
        mock_enqueue,
        mock_push,
        _mock_hh,
        _mock_ew,
    ):
        from handlers.orders import on_order_status_changed

        db, tx = _prepare_db_for_order_status("order_8")
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.EXPIRED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.ITEMS: [],
        }

        evt = _order_event("order_8", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        mock_enqueue.assert_called_once()
        mock_push.assert_called_once()

    @patch("services.email_service._email_wrapper", return_value="<p>wrapper</p>")
    @patch("services.email_service._hero_header", return_value="<h1>header</h1>")
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_db")
    def test_disputed_branch_sends_email_and_push(
        self,
        mock_get_db,
        mock_enqueue,
        mock_push,
        _mock_hh,
        _mock_ew,
    ):
        from handlers.orders import on_order_status_changed

        db, tx = _prepare_db_for_order_status("order_9")
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.DISPUTED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.ITEMS: [],
        }

        evt = _order_event("order_9", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        mock_enqueue.assert_called_once()
        mock_push.assert_called_once()

    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_order_processing_email", return_value="<p>processing</p>")
    @patch("handlers.orders._email_t", side_effect=lambda key, _lang="en": f"{key} {{oid}}")
    @patch("handlers.orders.get_db")
    def test_processing_branch_and_stock_cleanup_error_path(
        self,
        mock_get_db,
        _mock_t,
        _mock_tpl,
        mock_enqueue,
        mock_push,
    ):
        from handlers.orders import on_order_status_changed

        db, tx = _prepare_db_for_order_status("order_proc")

        stock_query = Mock()
        stock_query.where.return_value = stock_query
        stock_query.stream.side_effect = RuntimeError("subs down")
        stock_col = Mock()
        stock_col.where.return_value = stock_query

        base_collection = db.collection.side_effect

        def _collection(name):
            if name == Collections.STOCK_NOTIFICATIONS:
                return stock_col
            return base_collection(name)

        db.collection.side_effect = _collection
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.VARIANT_KEY: "", Fields.SELLER_ID: "seller_1"}],
        }

        evt = _order_event("order_proc", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        mock_enqueue.assert_called_once()
        mock_push.assert_called_once()

    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_order_in_transit_email", return_value="<p>in-transit</p>")
    @patch("handlers.orders._email_t", side_effect=lambda key, _lang="en": f"{key} {{oid}}")
    @patch("handlers.orders.get_db")
    def test_in_transit_branch_sends_email_and_push(
        self,
        mock_get_db,
        _mock_t,
        _mock_tpl,
        mock_enqueue,
        mock_push,
    ):
        from handlers.orders import on_order_status_changed

        db, tx = _prepare_db_for_order_status("order_transit")
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.IN_TRANSIT,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.ITEMS: [],
        }

        evt = _order_event("order_transit", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        mock_enqueue.assert_called_once()
        mock_push.assert_called_once()

    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_order_delivered_email", return_value="<p>delivered</p>")
    @patch("handlers.orders._email_t", side_effect=lambda key, _lang="en": f"{key} {{oid}}")
    @patch("handlers.orders.get_db")
    def test_delivered_unconfirmed_branch_requests_buyer_confirmation(
        self,
        mock_get_db,
        _mock_t,
        _mock_tpl,
        mock_enqueue,
        mock_push,
    ):
        from handlers.orders import on_order_status_changed

        db, tx = _prepare_db_for_order_status("order_deliv_req")
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.CONFIRMED_BY_CLIENT: False,
            Fields.AUTO_CONFIRMED: False,
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
        }

        evt = _order_event("order_deliv_req", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        assert mock_enqueue.call_count >= 2
        assert mock_push.call_count >= 2

    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_order_cancelled_email", return_value="<p>cancelled</p>")
    @patch("handlers.orders._email_t", side_effect=lambda key, _lang="en": f"{key} {{oid}}")
    @patch("handlers.orders.get_db")
    def test_cancelled_branch_sends_email_and_push(
        self,
        mock_get_db,
        _mock_t,
        _mock_tpl,
        mock_enqueue,
        mock_push,
    ):
        from handlers.orders import on_order_status_changed

        db, tx = _prepare_db_for_order_status("order_cancel")
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.CANCELLED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.CANCELLATION_REASON: "Seller out of stock",
            Fields.ITEMS: [],
        }

        evt = _order_event("order_cancel", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        mock_enqueue.assert_called_once()
        mock_push.assert_called_once()

    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_db")
    def test_buyer_email_fetch_error_skips_notification(self, mock_get_db, mock_enqueue, mock_push):
        from handlers.orders import on_order_status_changed

        tx = Mock()
        order_ref = Mock()
        order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, doc_id="order_no_email")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        users_col = Mock()
        users_col.document.return_value.get.side_effect = RuntimeError("user read failed")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
            Collections.STOCK_NOTIFICATIONS: Mock(),
        }[name]
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.ITEMS: [],
        }

        evt = _order_event("order_no_email", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()
        mock_enqueue.assert_not_called()
        mock_push.assert_not_called()

    @patch("handlers.orders.logger.error")
    @patch("handlers.orders.get_order_processing_email", side_effect=RuntimeError("template fail"))
    @patch("handlers.orders.get_db")
    def test_order_status_changed_outer_exception_is_logged(self, mock_get_db, _mock_tpl, mock_log_error):
        from handlers.orders import on_order_status_changed

        db, _tx = _prepare_db_for_order_status("order_fail")
        mock_get_db.return_value = db

        before = {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        }
        after = {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.ITEMS: [],
        }

        evt = _order_event("order_fail", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        assert mock_log_error.called

    @patch("handlers.orders.get_seller_notification_email", return_value="<p>seller</p>")
    @patch("handlers.orders.get_order_confirmation_email", return_value="<p>buyer</p>")
    @patch("handlers.orders._email_t", side_effect=lambda key, _lang="en": f"{key} {{oid}}")
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_db")
    def test_confirmed_branch_seller_and_perishable_error_paths(
        self,
        mock_get_db,
        mock_enqueue,
        mock_push,
        _mock_t,
        _mock_buyer_tpl,
        _mock_seller_tpl,
    ):
        from handlers.orders import on_order_status_changed

        def _push_side_effect(_uid, title, *_args, **_kwargs):
            if title == "New Order!":
                raise RuntimeError("seller push failed")
            if title == "URGENT: Perishable Order":
                raise RuntimeError("perishable push failed")
            return None

        def _enqueue_side_effect(*_args, **kwargs):
            if str(kwargs.get("subject", "")).startswith("sub.perishable_urgent"):
                raise RuntimeError("perishable email failed")
            return None

        mock_push.side_effect = _push_side_effect
        mock_enqueue.side_effect = _enqueue_side_effect

        db, tx = _prepare_db_for_order_status("order_conf_err")
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

        evt = _order_event("order_conf_err", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_order_status_changed(evt)

        tx.update.assert_called_once()


class TestReturnEmailAndStatusChangedMore:
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_return_request_submitted_email", return_value="<p>submitted</p>")
    @patch("handlers.orders._email_t", side_effect=lambda key, _lang="en": f"{key} {{oid}}")
    @patch("handlers.orders.get_db")
    def test_send_return_email_requested_hits_buyer_and_seller(
        self,
        mock_get_db,
        _mock_t,
        _mock_tpl,
        mock_enqueue,
    ):
        from handlers.orders import _send_return_email

        buyer_doc = _snap({Fields.EMAIL: "buyer@example.com", Fields.PREFERRED_LANGUAGE: "en"}, doc_id="buyer_1")
        seller_doc = _snap({Fields.EMAIL: "seller@example.com", Fields.PREFERRED_LANGUAGE: "fr"}, doc_id="seller_1")

        users_col = Mock()

        def _doc(uid):
            ref = Mock()
            ref.get.return_value = buyer_doc if uid == "buyer_1" else seller_doc
            return ref

        users_col.document.side_effect = _doc
        db = Mock()
        db.collection.return_value = users_col
        mock_get_db.return_value = db

        _send_return_email({}, "ret_1", "order_5", "buyer_1", "seller_1", ReturnStatusValues.REQUESTED)

        assert mock_enqueue.call_count == 2

    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_return_request_approved_email", return_value="<p>approved</p>")
    @patch("handlers.orders._email_t", side_effect=lambda key, _lang="en": f"{key} {{oid}}")
    @patch("handlers.orders.get_db")
    def test_send_return_email_approved(self, mock_get_db, _mock_t, _mock_tpl, mock_enqueue):
        from handlers.orders import _send_return_email

        buyer_doc = _snap({Fields.EMAIL: "buyer@example.com", Fields.PREFERRED_LANGUAGE: "en"}, doc_id="buyer_1")
        users_col = Mock()
        users_col.document.return_value.get.return_value = buyer_doc
        db = Mock()
        db.collection.return_value = users_col
        mock_get_db.return_value = db

        _send_return_email({}, "ret_appr", "order_10", "buyer_1", "seller_1", ReturnStatusValues.APPROVED)
        mock_enqueue.assert_called_once()

    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_return_request_rejected_email", return_value="<p>rejected</p>")
    @patch("handlers.orders._email_t", side_effect=lambda key, _lang="en": f"{key} {{oid}}")
    @patch("handlers.orders.get_db")
    def test_send_return_email_rejected(self, mock_get_db, _mock_t, _mock_tpl, mock_enqueue):
        from handlers.orders import _send_return_email

        buyer_doc = _snap({Fields.EMAIL: "buyer@example.com", Fields.PREFERRED_LANGUAGE: "en"}, doc_id="buyer_1")
        users_col = Mock()
        users_col.document.return_value.get.return_value = buyer_doc
        db = Mock()
        db.collection.return_value = users_col
        mock_get_db.return_value = db

        _send_return_email({}, "ret_rej", "order_11", "buyer_1", "seller_1", ReturnStatusValues.REJECTED)
        mock_enqueue.assert_called_once()

    @patch("services.email_service._email_wrapper", return_value="<p>wrapper</p>")
    @patch("services.email_service._hero_header", return_value="<h1>header</h1>")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_db")
    def test_send_return_email_label_issued_with_tracking(
        self,
        mock_get_db,
        mock_enqueue,
        _mock_hh,
        _mock_ew,
    ):
        from handlers.orders import _send_return_email

        buyer_doc = _snap({Fields.EMAIL: "buyer@example.com", Fields.PREFERRED_LANGUAGE: "fr"}, doc_id="buyer_1")
        users_col = Mock()
        users_col.document.return_value.get.return_value = buyer_doc
        db = Mock()
        db.collection.return_value = users_col
        mock_get_db.return_value = db

        _send_return_email(
            {Fields.RETURN_TRACKING_NUMBER: "RET-123"},
            "ret_label",
            "order_12",
            "buyer_1",
            "seller_1",
            ReturnStatusValues.LABEL_ISSUED,
        )
        mock_enqueue.assert_called_once()

    @patch("services.email_service._email_wrapper", return_value="<p>wrapper</p>")
    @patch("services.email_service._hero_header", return_value="<h1>header</h1>")
    @patch("handlers.orders.enqueue_email_task")
    @patch("handlers.orders.get_db")
    def test_send_return_email_escalated(
        self,
        mock_get_db,
        mock_enqueue,
        _mock_hh,
        _mock_ew,
    ):
        from handlers.orders import _send_return_email

        buyer_doc = _snap({Fields.EMAIL: "buyer@example.com", Fields.PREFERRED_LANGUAGE: "en"}, doc_id="buyer_1")
        users_col = Mock()
        users_col.document.return_value.get.return_value = buyer_doc
        db = Mock()
        db.collection.return_value = users_col
        mock_get_db.return_value = db

        _send_return_email({}, "ret_esc", "order_13", "buyer_1", "seller_1", ReturnStatusValues.ESCALATED)
        mock_enqueue.assert_called_once()

    @patch("handlers.orders._send_return_email")
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.get_db")
    def test_on_return_status_received_sends_buyer_and_seller_push(
        self,
        mock_get_db,
        mock_push,
        mock_send_return_email,
    ):
        from handlers.orders import on_return_request_status_changed

        tx = Mock()
        return_ref = Mock()
        return_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, doc_id="ret_2")
        returns_col = Mock()
        returns_col.document.return_value = return_ref

        db = Mock()
        db.collection.return_value = returns_col
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        before = {Fields.RETURN_STATUS: ReturnStatusValues.LABEL_ISSUED}
        after = {
            Fields.RETURN_STATUS: ReturnStatusValues.RECEIVED,
            Fields.ORDER_ID: "order_6",
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
        }

        evt = _return_event("ret_2", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_return_request_status_changed(evt)

        tx.update.assert_called_once()
        assert mock_push.call_count == 2
        mock_send_return_email.assert_called_once()

    @patch("handlers.orders._send_return_email")
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.get_db")
    def test_on_return_status_rejected_pushes_buyer_and_emails(
        self,
        mock_get_db,
        mock_push,
        mock_send_return_email,
    ):
        from handlers.orders import on_return_request_status_changed

        tx = Mock()
        return_ref = Mock()
        return_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, doc_id="ret_rej")
        returns_col = Mock()
        returns_col.document.return_value = return_ref

        db = Mock()
        db.collection.return_value = returns_col
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        before = {Fields.RETURN_STATUS: ReturnStatusValues.APPROVED}
        after = {
            Fields.RETURN_STATUS: ReturnStatusValues.REJECTED,
            Fields.ORDER_ID: "order_14",
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
        }

        evt = _return_event("ret_rej", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_return_request_status_changed(evt)

        tx.update.assert_called_once()
        mock_push.assert_called_once()
        mock_send_return_email.assert_called_once()

    @patch("handlers.orders._send_return_email")
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.get_db")
    def test_on_return_status_label_issued_pushes_buyer_and_emails(
        self,
        mock_get_db,
        mock_push,
        mock_send_return_email,
    ):
        from handlers.orders import on_return_request_status_changed

        tx = Mock()
        return_ref = Mock()
        return_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, doc_id="ret_label")
        returns_col = Mock()
        returns_col.document.return_value = return_ref

        db = Mock()
        db.collection.return_value = returns_col
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        before = {Fields.RETURN_STATUS: ReturnStatusValues.APPROVED}
        after = {
            Fields.RETURN_STATUS: ReturnStatusValues.LABEL_ISSUED,
            Fields.ORDER_ID: "order_15",
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
        }

        evt = _return_event("ret_label", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_return_request_status_changed(evt)

        tx.update.assert_called_once()
        mock_push.assert_called_once()
        mock_send_return_email.assert_called_once()

    @patch("handlers.orders._send_return_email")
    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.get_db")
    def test_on_return_status_refunded_pushes_buyer_and_emails(
        self,
        mock_get_db,
        mock_push,
        mock_send_return_email,
    ):
        from handlers.orders import on_return_request_status_changed

        tx = Mock()
        return_ref = Mock()
        return_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, doc_id="ret_ref")
        returns_col = Mock()
        returns_col.document.return_value = return_ref

        db = Mock()
        db.collection.return_value = returns_col
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        before = {Fields.RETURN_STATUS: ReturnStatusValues.RECEIVED}
        after = {
            Fields.RETURN_STATUS: ReturnStatusValues.REFUNDED,
            Fields.ORDER_ID: "order_16",
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
        }

        evt = _return_event("ret_ref", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_return_request_status_changed(evt)

        tx.update.assert_called_once()
        mock_push.assert_called_once()
        mock_send_return_email.assert_called_once()

    @patch("handlers.orders.send_push_notification")
    @patch("handlers.orders.get_db")
    def test_on_return_status_escalated_pushes_buyer(self, mock_get_db, mock_push):
        from handlers.orders import on_return_request_status_changed

        tx = Mock()
        return_ref = Mock()
        return_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, doc_id="ret_3")
        returns_col = Mock()
        returns_col.document.return_value = return_ref

        db = Mock()
        db.collection.return_value = returns_col
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        before = {Fields.RETURN_STATUS: ReturnStatusValues.REJECTED}
        after = {
            Fields.RETURN_STATUS: ReturnStatusValues.ESCALATED,
            Fields.ORDER_ID: "order_7",
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
        }

        evt = _return_event("ret_3", before, after)
        with patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda f: f):
            on_return_request_status_changed(evt)

        tx.update.assert_called_once()
        mock_push.assert_called_once_with(
            "buyer_1",
            "Return Escalated",
            "Your return for order #order_7 has been escalated to our support team",
            data={
                "type": NotificationTypes.RETURN_REQUEST,
                "orderId": "order_7",
                "returnId": "ret_3",
                "status": ReturnStatusValues.ESCALATED,
            },
        )
