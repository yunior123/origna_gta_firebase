from unittest.mock import Mock, patch

from google.api_core import exceptions as google_exceptions

from schema_constants import Collections, Fields, OrderStatusValues, PaymentStatusValues


def _response_text(resp) -> str:
    payload = b"".join(resp.response)
    return payload.decode("utf-8")


class TestStaleOrdersWorker:
    @patch("handlers.tasks._process_one_stale_order")
    def test_worker_rejects_missing_order_id(self, _mock_process):
        from handlers.tasks import stale_orders_worker

        req = Mock()
        req.get_json.return_value = {}

        resp = stale_orders_worker(req)
        assert resp.status_code == 400
        assert "missing order_id" in _response_text(resp)

    @patch("handlers.tasks.get_stripe_secret_key", return_value="sk_test_123")
    @patch("handlers.tasks._process_one_stale_order", return_value=True)
    def test_worker_returns_200_when_processing_succeeds(self, mock_process, _mock_secret):
        from handlers.tasks import stale_orders_worker

        req = Mock()
        req.get_json.return_value = {"order_id": "order_1"}

        resp = stale_orders_worker(req)
        assert resp.status_code == 200
        assert "processed successfully" in _response_text(resp)
        mock_process.assert_called_once_with("order_1")

    @patch("handlers.tasks.get_stripe_secret_key", return_value="sk_test_123")
    @patch("handlers.tasks._process_one_stale_order", return_value=False)
    def test_worker_returns_500_when_processing_fails(self, mock_process, _mock_secret):
        from handlers.tasks import stale_orders_worker

        req = Mock()
        req.get_json.return_value = {"order_id": "order_1"}

        resp = stale_orders_worker(req)
        assert resp.status_code == 500
        assert "Failed to process order" in _response_text(resp)
        mock_process.assert_called_once_with("order_1")

    @patch("handlers.tasks.sentry_sdk.capture_exception")
    @patch("handlers.tasks._process_one_stale_order", side_effect=RuntimeError("boom"))
    @patch("handlers.tasks.get_stripe_secret_key", return_value="sk_test_123")
    def test_worker_catches_unhandled_exceptions(self, _mock_secret, _mock_process, mock_capture):
        from handlers.tasks import stale_orders_worker

        req = Mock()
        req.get_json.return_value = {"order_id": "order_1"}

        resp = stale_orders_worker(req)
        assert resp.status_code == 500
        assert "Internal Server Error" in _response_text(resp)
        assert mock_capture.called


class TestProcessOneStaleOrder:
    @patch("handlers.tasks.get_db")
    def test_returns_true_for_missing_order(self, mock_get_db):
        from handlers.tasks import _process_one_stale_order

        db = Mock()
        mock_get_db.return_value = db
        order_ref = Mock()
        db.collection.return_value.document.return_value = order_ref

        order_doc = Mock()
        order_doc.exists = False
        order_ref.get.return_value = order_doc

        assert _process_one_stale_order("order_missing") is True

    @patch("handlers.tasks.get_firestore")
    @patch("handlers.tasks.get_db")
    def test_skips_when_order_status_is_not_expirable(self, mock_get_db, mock_get_firestore):
        from handlers.tasks import _process_one_stale_order

        db = Mock()
        mock_get_db.return_value = db
        txn = Mock()
        db.transaction.return_value = txn
        order_ref = Mock()
        db.collection.return_value.document.return_value = order_ref

        order_doc = Mock()
        order_doc.exists = True
        order_doc.to_dict.return_value = {Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123"}

        fresh_doc = Mock()
        fresh_doc.exists = True
        fresh_doc.to_dict.return_value = {
            Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.ITEMS: [],
        }

        def _get_side_effect(*_args, **kwargs):
            if kwargs.get("transaction") is not None:
                return fresh_doc
            return order_doc

        order_ref.get.side_effect = _get_side_effect

        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        mock_get_firestore.return_value = fs

        assert _process_one_stale_order("order_1") is True

    @patch("handlers.tasks.get_firestore")
    @patch("handlers.tasks.get_db")
    def test_returns_false_on_transient_firestore_error(self, mock_get_db, mock_get_firestore):
        from handlers.tasks import _process_one_stale_order

        db = Mock()
        mock_get_db.return_value = db
        db.transaction.return_value = Mock()
        order_ref = Mock()
        db.collection.return_value.document.return_value = order_ref

        order_doc = Mock()
        order_doc.exists = True
        order_doc.to_dict.return_value = {}

        def _get_side_effect(*_args, **kwargs):
            if kwargs.get("transaction") is not None:
                raise google_exceptions.GoogleAPICallError("transient")
            return order_doc

        order_ref.get.side_effect = _get_side_effect

        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        mock_get_firestore.return_value = fs

        assert _process_one_stale_order("order_1") is False

    @patch("handlers.tasks.get_server_timestamp", return_value="ts")
    @patch("handlers.tasks.get_firestore")
    @patch("handlers.tasks.get_db")
    @patch("handlers.tasks.stripe.PaymentIntent.cancel")
    @patch("services.email_service.send_authorization_expired_email")
    def test_expires_authorized_order_cancels_pi_restores_stock_and_sends_email(
        self,
        mock_send_email,
        mock_cancel_pi,
        mock_get_db,
        mock_get_firestore,
        _mock_ts,
    ):
        from handlers.tasks import _process_one_stale_order

        db = Mock()
        mock_get_db.return_value = db
        txn = Mock()
        db.transaction.return_value = txn
        batch = Mock()
        db.batch.return_value = batch

        order_ref = Mock()
        product_ref = Mock()

        def _collection_side_effect(name):
            coll = Mock()
            if name == Collections.ORDERS:
                coll.document.return_value = order_ref
            elif name == Collections.PRODUCTS:
                coll.document.return_value = product_ref
            return coll

        db.collection.side_effect = _collection_side_effect

        order_data = {
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123",
            Fields.PREFERRED_LANGUAGE: "en",
        }
        order_doc = Mock()
        order_doc.exists = True
        order_doc.to_dict.return_value = order_data

        fresh_doc = Mock()
        fresh_doc.exists = True
        fresh_doc.to_dict.return_value = {
            Fields.ORDER_STATUS: OrderStatusValues.PENDING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.ITEMS: [
                {
                    Fields.PRODUCT_ID: "prod_1",
                    Fields.QUANTITY: 2,
                    Fields.FULFILLMENT_WAREHOUSE_ID: "wh_1",
                }
            ],
            Fields.STOCK_RESTORED: False,
        }

        def _get_side_effect(*_args, **kwargs):
            if kwargs.get("transaction") is not None:
                return fresh_doc
            return order_doc

        order_ref.get.side_effect = _get_side_effect

        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        mock_get_firestore.return_value = fs

        assert _process_one_stale_order("order_1") is True
        mock_cancel_pi.assert_called_once_with("pi_123", idempotency_key="cancel_auth_order_1")
        assert batch.update.called
        assert batch.set.called
        batch.commit.assert_called_once()
        assert order_ref.update.called
        mock_send_email.assert_called_once()

    @patch("handlers.tasks.sentry_sdk.capture_exception")
    @patch("handlers.tasks.get_server_timestamp", return_value="ts")
    @patch("handlers.tasks.get_firestore")
    @patch("handlers.tasks.get_db")
    def test_returns_false_when_stock_restore_batch_fails(
        self,
        mock_get_db,
        mock_get_firestore,
        _mock_ts,
        mock_capture,
    ):
        from handlers.tasks import _process_one_stale_order

        db = Mock()
        mock_get_db.return_value = db
        db.transaction.return_value = Mock()
        batch = Mock()
        batch.commit.side_effect = RuntimeError("batch failed")
        db.batch.return_value = batch

        order_ref = Mock()
        product_ref = Mock()

        def _collection_side_effect(name):
            coll = Mock()
            if name == Collections.ORDERS:
                coll.document.return_value = order_ref
            elif name == Collections.PRODUCTS:
                coll.document.return_value = product_ref
            return coll

        db.collection.side_effect = _collection_side_effect

        order_doc = Mock()
        order_doc.exists = True
        order_doc.to_dict.return_value = {}

        fresh_doc = Mock()
        fresh_doc.exists = True
        fresh_doc.to_dict.return_value = {
            Fields.ORDER_STATUS: OrderStatusValues.PENDING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.SESSION_EXPIRED,
            Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.QUANTITY: 1}],
            Fields.STOCK_RESTORED: False,
        }

        def _get_side_effect(*_args, **kwargs):
            if kwargs.get("transaction") is not None:
                return fresh_doc
            return order_doc

        order_ref.get.side_effect = _get_side_effect

        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        mock_get_firestore.return_value = fs

        assert _process_one_stale_order("order_1") is False
        assert mock_capture.called

    @patch("handlers.tasks.get_server_timestamp", return_value="ts")
    @patch("handlers.tasks.get_firestore")
    @patch("handlers.tasks.get_db")
    @patch("handlers.tasks.stripe.PaymentIntent.cancel")
    def test_expired_needs_stock_path_skips_cancel_and_restores_stock(
        self,
        mock_cancel_pi,
        mock_get_db,
        mock_get_firestore,
        _mock_ts,
    ):
        from handlers.tasks import _process_one_stale_order

        db = Mock()
        mock_get_db.return_value = db
        db.transaction.return_value = Mock()
        batch = Mock()
        db.batch.return_value = batch

        order_ref = Mock()
        product_ref = Mock()

        def _collection_side_effect(name):
            coll = Mock()
            if name == Collections.ORDERS:
                coll.document.return_value = order_ref
            elif name == Collections.PRODUCTS:
                coll.document.return_value = product_ref
            return coll

        db.collection.side_effect = _collection_side_effect

        order_doc = Mock()
        order_doc.exists = True
        order_doc.to_dict.return_value = {Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123"}

        fresh_doc = Mock()
        fresh_doc.exists = True
        fresh_doc.to_dict.return_value = {
            Fields.ORDER_STATUS: OrderStatusValues.EXPIRED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.QUANTITY: 1}],
            Fields.STOCK_RESTORED: False,
        }

        def _get_side_effect(*_args, **kwargs):
            if kwargs.get("transaction") is not None:
                return fresh_doc
            return order_doc

        order_ref.get.side_effect = _get_side_effect

        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        mock_get_firestore.return_value = fs

        assert _process_one_stale_order("order_1") is True
        mock_cancel_pi.assert_not_called()
        batch.commit.assert_called_once()
