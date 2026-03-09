from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import (
    Collections,
    DeliveryStatusValues,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
)


def _snap(data=None, *, exists=True):
    snap = Mock()
    snap.exists = exists
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _req(uid: str | None, data: dict):
    req = Mock()
    req.auth = Mock(uid=uid) if uid else None
    req.data = data
    return req


def _base_order(*, user_id="buyer_1", product_id="p1", seller_id="seller_1", item_status=DeliveryStatusValues.SHIPPED, payment_status=PaymentStatusValues.CAPTURED):
    return {
        Fields.USER_ID: user_id,
        Fields.PAYMENT_STATUS: payment_status,
        Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
        Fields.ITEMS: [
            {
                Fields.PRODUCT_ID: product_id,
                Fields.SELLER_ID: seller_id,
                Fields.STATUS: item_status,
            }
        ],
    }


class TestConfirmItemReceiptDeep:
    def test_requires_authentication(self):
        from handlers.orders import confirm_item_receipt

        with pytest.raises(https_fn.HttpsError) as exc:
            confirm_item_receipt(_req(None, {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert exc.value.code == "unauthenticated"

    def test_requires_order_id_and_product_id(self):
        from handlers.orders import confirm_item_receipt

        with pytest.raises(https_fn.HttpsError) as exc:
            confirm_item_receipt(_req("buyer_1", {Fields.ORDER_ID: "o1"}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_order_not_found_raises(self, mock_get_db, mock_get_fs):
        from handlers.orders import confirm_item_receipt

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        order_ref = Mock()
        order_ref.get.return_value = _snap(exists=False)
        db.collection.return_value.document.return_value = order_ref
        mock_get_db.return_value = db
        mock_get_fs.return_value.transactional = lambda fn: fn

        with pytest.raises(https_fn.HttpsError) as exc:
            confirm_item_receipt(_req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert exc.value.code == "not-found"

    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_non_owner_cannot_confirm(self, mock_get_db, mock_get_fs):
        from handlers.orders import confirm_item_receipt

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        order_ref = Mock()
        order_ref.get.return_value = _snap(_base_order(user_id="someone_else"))
        db.collection.return_value.document.return_value = order_ref
        mock_get_db.return_value = db
        mock_get_fs.return_value.transactional = lambda fn: fn

        with pytest.raises(https_fn.HttpsError) as exc:
            confirm_item_receipt(_req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert exc.value.code == "permission-denied"

    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_item_not_found_in_order_raises(self, mock_get_db, mock_get_fs):
        from handlers.orders import confirm_item_receipt

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        order_ref = Mock()
        order_ref.get.return_value = _snap(_base_order(product_id="other"))
        db.collection.return_value.document.return_value = order_ref
        mock_get_db.return_value = db
        mock_get_fs.return_value.transactional = lambda fn: fn

        with pytest.raises(https_fn.HttpsError) as exc:
            confirm_item_receipt(_req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert exc.value.code == "not-found"

    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_self_purchase_is_blocked(self, mock_get_db, mock_get_fs):
        from handlers.orders import confirm_item_receipt

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        order_ref = Mock()
        order_ref.get.return_value = _snap(_base_order(user_id="seller_1", seller_id="seller_1"))
        db.collection.return_value.document.return_value = order_ref
        mock_get_db.return_value = db
        mock_get_fs.return_value.transactional = lambda fn: fn

        with pytest.raises(https_fn.HttpsError) as exc:
            confirm_item_receipt(_req("seller_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert exc.value.code == "permission-denied"

    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_already_delivered_is_idempotent(self, mock_get_db, mock_get_fs):
        from handlers.orders import confirm_item_receipt

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        order_ref = Mock()
        order_ref.get.return_value = _snap(_base_order(item_status=DeliveryStatusValues.DELIVERED))
        db.collection.return_value.document.return_value = order_ref
        mock_get_db.return_value = db
        mock_get_fs.return_value.transactional = lambda fn: fn

        out = confirm_item_receipt(_req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert out["success"] is True
        assert "already marked as delivered" in out["message"]
        tx.update.assert_not_called()

    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_non_shipped_item_cannot_be_confirmed(self, mock_get_db, mock_get_fs):
        from handlers.orders import confirm_item_receipt

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        order_ref = Mock()
        order_ref.get.return_value = _snap(_base_order(item_status=DeliveryStatusValues.PENDING))
        db.collection.return_value.document.return_value = order_ref
        mock_get_db.return_value = db
        mock_get_fs.return_value.transactional = lambda fn: fn

        with pytest.raises(https_fn.HttpsError) as exc:
            confirm_item_receipt(_req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert exc.value.code == "failed-precondition"

    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_last_item_confirmed_with_captured_payment_sets_order_delivered(
        self,
        mock_get_db,
        mock_get_fs,
        _mock_ts,
    ):
        from handlers.orders import confirm_item_receipt

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        order_ref = Mock()
        order_ref.get.return_value = _snap(_base_order(item_status=DeliveryStatusValues.SHIPPED))
        db.collection.return_value.document.return_value = order_ref
        mock_get_db.return_value = db
        mock_get_fs.return_value.transactional = lambda fn: fn

        out = confirm_item_receipt(_req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert out["success"] is True
        assert out["allDelivered"] is True
        update_payload = tx.update.call_args.args[1]
        assert update_payload[Fields.ORDER_STATUS] == OrderStatusValues.DELIVERED
        assert update_payload[Fields.CONFIRMED_BY_CLIENT] is True
        assert update_payload[Fields.UPDATED_AT] == "ts"

    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_last_item_confirmed_without_captured_payment_does_not_promote_order(
        self,
        mock_get_db,
        mock_get_fs,
        _mock_ts,
    ):
        from handlers.orders import confirm_item_receipt

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        order_ref = Mock()
        order_ref.get.return_value = _snap(
            _base_order(
                item_status=DeliveryStatusValues.SHIPPED,
                payment_status=PaymentStatusValues.AWAITING_PAYMENT,
            )
        )
        db.collection.return_value.document.return_value = order_ref
        mock_get_db.return_value = db
        mock_get_fs.return_value.transactional = lambda fn: fn

        out = confirm_item_receipt(_req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert out["success"] is True
        assert out["allDelivered"] is True
        update_payload = tx.update.call_args.args[1]
        assert Fields.ORDER_STATUS not in update_payload
