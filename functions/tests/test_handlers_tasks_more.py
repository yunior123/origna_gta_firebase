from unittest.mock import Mock, patch

import stripe

from schema_constants import Collections, Fields, OrderStatusValues, PaymentStatusValues


def _setup_order_db(order_data: dict, fresh_data: dict):
    db = Mock()
    db.transaction.return_value = Mock()
    order_ref = Mock()

    order_doc = Mock()
    order_doc.exists = True
    order_doc.to_dict.return_value = order_data

    fresh_doc = Mock()
    fresh_doc.exists = True
    fresh_doc.to_dict.return_value = fresh_data

    def _get_side_effect(*_args, **kwargs):
        if kwargs.get("transaction") is not None:
            return fresh_doc
        return order_doc

    order_ref.get.side_effect = _get_side_effect
    db.collection.return_value.document.return_value = order_ref
    return db, order_ref, fresh_doc


class TestTasksMoreBranches:
    @patch("handlers.tasks.get_firestore")
    @patch("handlers.tasks.get_db")
    def test_process_one_stale_order_handles_missing_doc_in_transaction(self, mock_get_db, mock_get_fs):
        from handlers.tasks import _process_one_stale_order

        db = Mock()
        mock_get_db.return_value = db
        db.transaction.return_value = Mock()
        order_ref = Mock()
        db.collection.return_value.document.return_value = order_ref

        outer_doc = Mock(exists=True, to_dict=Mock(return_value={}))
        missing_fresh = Mock(exists=False)

        def _get_side_effect(*_args, **kwargs):
            if kwargs.get("transaction") is not None:
                return missing_fresh
            return outer_doc

        order_ref.get.side_effect = _get_side_effect

        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        mock_get_fs.return_value = fs

        assert _process_one_stale_order("order_1") is True

    @patch("handlers.tasks.get_firestore")
    @patch("handlers.tasks.get_db")
    def test_process_one_stale_order_skips_when_locked_by_capture(self, mock_get_db, mock_get_fs):
        from handlers.tasks import _process_one_stale_order

        order_data = {}
        fresh_data = {
            Fields.ORDER_STATUS: OrderStatusValues.PENDING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURING,
            Fields.ITEMS: [],
        }
        db, _order_ref, _fresh_doc = _setup_order_db(order_data, fresh_data)
        mock_get_db.return_value = db

        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        mock_get_fs.return_value = fs

        assert _process_one_stale_order("order_1") is True

    @patch("handlers.tasks.get_server_timestamp", return_value="ts")
    @patch("handlers.tasks.get_firestore")
    @patch("handlers.tasks.get_db")
    @patch("handlers.tasks.stripe.PaymentIntent.cancel", side_effect=stripe.error.StripeError("cancel failed"))
    def test_process_one_stale_order_ignores_stripe_cancel_errors(
        self, _mock_cancel, mock_get_db, mock_get_fs, _mock_ts
    ):
        from handlers.tasks import _process_one_stale_order

        order_data = {Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123"}
        fresh_data = {
            Fields.ORDER_STATUS: OrderStatusValues.PENDING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.ITEMS: [],
            Fields.STOCK_RESTORED: True,
        }
        db, order_ref, _fresh_doc = _setup_order_db(order_data, fresh_data)
        mock_get_db.return_value = db

        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        mock_get_fs.return_value = fs

        assert _process_one_stale_order("order_1") is True
        order_ref.update.assert_called_once()

    @patch("handlers.tasks.get_server_timestamp", return_value="ts")
    @patch("handlers.tasks.get_firestore")
    @patch("handlers.tasks.get_db")
    def test_process_one_stale_order_skips_items_without_product_id(self, mock_get_db, mock_get_fs, _mock_ts):
        from handlers.tasks import _process_one_stale_order

        db = Mock()
        mock_get_db.return_value = db
        db.transaction.return_value = Mock()
        batch = Mock()
        db.batch.return_value = batch

        order_ref = Mock()
        db.collection.return_value.document.return_value = order_ref
        order_doc = Mock(exists=True, to_dict=Mock(return_value={}))
        fresh_doc = Mock(
            exists=True,
            to_dict=Mock(
                return_value={
                    Fields.ORDER_STATUS: OrderStatusValues.PENDING,
                    Fields.PAYMENT_STATUS: PaymentStatusValues.SESSION_EXPIRED,
                    Fields.ITEMS: [{Fields.QUANTITY: 1}],  # missing productId -> line 157 continue
                    Fields.STOCK_RESTORED: False,
                }
            ),
        )

        def _get_side_effect(*_args, **kwargs):
            if kwargs.get("transaction") is not None:
                return fresh_doc
            return order_doc

        order_ref.get.side_effect = _get_side_effect

        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        mock_get_fs.return_value = fs

        assert _process_one_stale_order("order_1") is True
        batch.update.assert_not_called()

    @patch("handlers.tasks.get_server_timestamp", return_value="ts")
    @patch("handlers.tasks.get_firestore")
    @patch("handlers.tasks.get_db")
    @patch("handlers.tasks.stripe.PaymentIntent.cancel")
    @patch("services.email_service.send_authorization_expired_email", side_effect=Exception("email down"))
    def test_process_one_stale_order_logs_email_failures_but_succeeds(
        self,
        _mock_email,
        _mock_cancel,
        mock_get_db,
        mock_get_fs,
        _mock_ts,
    ):
        from handlers.tasks import _process_one_stale_order

        order_data = {Fields.STRIPE_PAYMENT_INTENT_ID: "pi_123", Fields.PREFERRED_LANGUAGE: "en"}
        fresh_data = {
            Fields.ORDER_STATUS: OrderStatusValues.PENDING,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.ITEMS: [],
            Fields.STOCK_RESTORED: True,
        }
        db, _order_ref, _fresh_doc = _setup_order_db(order_data, fresh_data)
        mock_get_db.return_value = db

        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        mock_get_fs.return_value = fs

        assert _process_one_stale_order("order_1") is True
