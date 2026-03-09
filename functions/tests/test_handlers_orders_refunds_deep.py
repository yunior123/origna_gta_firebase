from datetime import UTC, datetime, timedelta
from unittest.mock import Mock, patch

import pytest
import stripe
from firebase_functions import https_fn

from schema_constants import (
    Collections,
    DeliveryStatusValues,
    Fields,
    PaymentStatusValues,
    PayoutStatusValues,
    UserRoleValues,
)


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _req(uid: str | None, data: dict):
    req = Mock()
    req.auth = Mock(uid=uid) if uid else None
    req.data = data
    return req


def _base_order_data(*, is_digital: bool = False):
    delivered = datetime.now(UTC) - timedelta(days=2)
    return {
        Fields.USER_ID: "buyer_1",
        Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        Fields.PAYOUT_STATUS: PayoutStatusValues.COMPLETED,
        Fields.STRIPE_PAYMENT_INTENT_ID: "pi_1",
        Fields.SUBTOTAL_CENTS: 4000,
        Fields.DISCOUNT_AMOUNT_CENTS: 400,
        Fields.SHIPPING_COST_CENTS: 1000,
        Fields.SELLER_SHIPPING_COSTS: {"seller_1": 1000},
        Fields.TAX_AMOUNT_CENTS: 390,
        Fields.ITEMS: [
            {
                Fields.PRODUCT_ID: "prod_1",
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 20.0,
                Fields.QUANTITY: 1,
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
                Fields.DELIVERED_AT: delivered,
                Fields.FULFILLMENT_WAREHOUSE_ID: "wh_1",
                Fields.IS_DIGITAL: is_digital,
            },
            {
                Fields.PRODUCT_ID: "prod_2",
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 20.0,
                Fields.QUANTITY: 1,
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
                Fields.DELIVERED_AT: delivered,
                Fields.IS_DIGITAL: is_digital,
            },
        ],
    }


class TestRefundOrderItemDeep:
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_refund_order_item_guard_matrix(self, mock_get_db, mock_rl, _mock_sanitized):
        from handlers.orders import refund_order_item

        unauth_req = _req(None, {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"})
        with pytest.raises(https_fn.HttpsError) as unauth:
            refund_order_item(unauth_req)
        assert unauth.value.code == "unauthenticated"

        mock_rl.return_value.check_rate_limit.return_value = (False, "too many")
        with pytest.raises(https_fn.HttpsError) as limited:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert limited.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        user_ref = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: Mock(document=Mock(return_value=order_ref)),
            Collections.USERS: Mock(document=Mock(return_value=user_ref)),
            Collections.PRODUCTS: Mock(document=Mock(return_value=Mock())),
            Collections.PAYOUTS: Mock(where=Mock(return_value=Mock(where=Mock(), limit=Mock(), get=Mock(return_value=[])))),
            Collections.LICENSES: Mock(where=Mock(return_value=Mock(where=Mock(), stream=Mock(return_value=[])))),
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as missing_args:
            refund_order_item(_req("seller_1", {}))
        assert missing_args.value.code == "invalid-argument"

        order_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as no_order:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert no_order.value.code == "not-found"

        base_order = {
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.PAYOUT_STATUS: PayoutStatusValues.COMPLETED,
            Fields.ITEMS: [
                {
                    Fields.PRODUCT_ID: "p1",
                    Fields.SELLER_ID: "seller_1",
                    Fields.STATUS: DeliveryStatusValues.DELIVERED,
                    Fields.PRICE: 10.0,
                    Fields.QUANTITY: 1,
                    Fields.DELIVERED_AT: datetime.now(UTC),
                }
            ],
        }

        order_ref.get.return_value = _snap(base_order)
        user_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as no_user:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert no_user.value.code == "not-found"

        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"]})
        with pytest.raises(https_fn.HttpsError) as denied:
            refund_order_item(_req("seller_2", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert denied.value.code == "permission-denied"

        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]})

        uncaptured = dict(base_order)
        uncaptured[Fields.PAYMENT_STATUS] = PaymentStatusValues.AUTHORIZED
        order_ref.get.return_value = _snap(uncaptured)
        with pytest.raises(https_fn.HttpsError) as uncaptured_exc:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert uncaptured_exc.value.code == "failed-precondition"

        payout_processing = dict(base_order)
        payout_processing[Fields.PAYOUT_STATUS] = PayoutStatusValues.PROCESSING
        order_ref.get.return_value = _snap(payout_processing)
        with pytest.raises(https_fn.HttpsError) as payout_busy:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert payout_busy.value.code == "unavailable"

        order_without_item = dict(base_order)
        order_without_item[Fields.ITEMS] = [{Fields.PRODUCT_ID: "other", Fields.SELLER_ID: "seller_1"}]
        order_ref.get.return_value = _snap(order_without_item)
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})
        with pytest.raises(https_fn.HttpsError) as item_missing:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert item_missing.value.code == "not-found"

        already_refunded = dict(base_order)
        already_refunded[Fields.ITEMS] = [
            {
                Fields.PRODUCT_ID: "p1",
                Fields.SELLER_ID: "seller_1",
                Fields.STATUS: DeliveryStatusValues.REFUNDED,
                Fields.PRICE: 10.0,
                Fields.QUANTITY: 1,
            }
        ]
        order_ref.get.return_value = _snap(already_refunded)
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]})
        with pytest.raises(https_fn.HttpsError) as already:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1"}))
        assert already.value.code == "failed-precondition"

    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_refund_order_item_return_window_timestamp_and_unknown_delivered_type(
        self, mock_get_db, mock_rl, _mock_sanitized
    ):
        from handlers.orders import refund_order_item

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        class _FakeTs:
            def __init__(self, ts):
                self._ts = ts

            def timestamp(self):
                return self._ts

        old_ts = datetime.now(UTC) - timedelta(days=20)

        order_ref = Mock()
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]})

        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
            Collections.PRODUCTS: Mock(document=Mock(return_value=Mock())),
            Collections.PAYOUTS: Mock(where=Mock(return_value=Mock(where=Mock(), limit=Mock(), get=Mock(return_value=[])))),
            Collections.LICENSES: Mock(where=Mock(return_value=Mock(where=Mock(), stream=Mock(return_value=[])))),
        }[name]
        mock_get_db.return_value = db

        expired_order = {
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.PAYOUT_STATUS: PayoutStatusValues.COMPLETED,
            Fields.SUBTOTAL_CENTS: 1000,
            Fields.SHIPPING_COST_CENTS: 100,
            Fields.TAX_AMOUNT_CENTS: 130,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_old",
            Fields.ITEMS: [
                {
                    Fields.PRODUCT_ID: "prod_1",
                    Fields.SELLER_ID: "seller_1",
                    Fields.STATUS: DeliveryStatusValues.DELIVERED,
                    Fields.PRICE: 10.0,
                    Fields.QUANTITY: 1,
                    Fields.DELIVERED_AT: _FakeTs(old_ts.timestamp()),
                }
            ],
        }
        order_ref.get.return_value = _snap(expired_order)

        with pytest.raises(https_fn.HttpsError) as expired_exc:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o_old", Fields.PRODUCT_ID: "prod_1"}))
        assert expired_exc.value.code == "failed-precondition"

        unknown_date_type = dict(expired_order)
        unknown_date_type[Fields.STRIPE_PAYMENT_INTENT_ID] = None
        unknown_date_type[Fields.ITEMS] = [
            {
                Fields.PRODUCT_ID: "prod_1",
                Fields.SELLER_ID: "seller_1",
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
                Fields.PRICE: 10.0,
                Fields.QUANTITY: 1,
                Fields.DELIVERED_AT: "not-a-datetime",
            }
        ]
        order_ref.get.return_value = _snap(unknown_date_type)
        with pytest.raises(https_fn.HttpsError) as no_pi_exc:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o_unknown", Fields.PRODUCT_ID: "prod_1"}))
        assert no_pi_exc.value.code == "failed-precondition"

    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_refund_order_item_zero_subtotal_guards(self, mock_get_db, mock_rl, _mock_sanitized):
        from handlers.orders import refund_order_item

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        base = {
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.PAYOUT_STATUS: PayoutStatusValues.COMPLETED,
            Fields.TAX_AMOUNT_CENTS: 100,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_zero",
            Fields.ITEMS: [
                {
                    Fields.PRODUCT_ID: "prod_1",
                    Fields.SELLER_ID: "seller_1",
                    Fields.STATUS: DeliveryStatusValues.DELIVERED,
                    Fields.PRICE: 10.0,
                    Fields.QUANTITY: 1,
                    Fields.DELIVERED_AT: datetime.now(UTC),
                }
            ],
        }

        order_ref = Mock()
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]})
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }.get(name, Mock())
        mock_get_db.return_value = db

        # No item shipping snapshot -> first zero-subtotal guard.
        no_snapshot = dict(base)
        no_snapshot[Fields.SUBTOTAL_CENTS] = 0
        no_snapshot[Fields.SHIPPING_COST_CENTS] = 200
        no_snapshot[Fields.SELLER_SHIPPING_COSTS] = {}
        order_ref.get.return_value = _snap(no_snapshot)
        with pytest.raises(https_fn.HttpsError) as first_guard:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o_zero_1", Fields.PRODUCT_ID: "prod_1"}))
        assert first_guard.value.code == "failed-precondition"

        # With shipping snapshot, second zero-subtotal guard triggers in tax section.
        with_snapshot = dict(base)
        with_snapshot[Fields.SUBTOTAL_CENTS] = 0
        with_snapshot[Fields.ITEMS] = [
            {
                Fields.PRODUCT_ID: "prod_1",
                Fields.SELLER_ID: "seller_1",
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
                Fields.PRICE: 10.0,
                Fields.QUANTITY: 1,
                Fields.ITEM_SHIPPING_CENTS: 50,
                Fields.DELIVERED_AT: datetime.now(UTC),
            }
        ]
        order_ref.get.return_value = _snap(with_snapshot)
        with pytest.raises(https_fn.HttpsError) as second_guard:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o_zero_2", Fields.PRODUCT_ID: "prod_1"}))
        assert second_guard.value.code == "failed-precondition"

    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.stripe.Refund.create", return_value=Mock(id="re_txn"))
    @patch("handlers.orders.get_db")
    def test_refund_order_item_atomic_order_and_item_not_found_branches(
        self,
        mock_get_db,
        _mock_refund_create,
        mock_get_fs,
        _mock_ts,
        mock_rl,
        _mock_sanitized,
    ):
        from handlers.orders import refund_order_item

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        fs = Mock()
        fs.transactional = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        mock_get_fs.return_value = fs

        base_order = _base_order_data(is_digital=False)
        order_ref = Mock()
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]})
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        products_col = Mock()
        products_col.document.return_value = Mock(collection=Mock(return_value=Mock(document=Mock(return_value=Mock()))))
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.get.return_value = []
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q
        licenses_q = Mock()
        licenses_q.where.return_value = licenses_q
        licenses_q.stream.return_value = []
        licenses_col = Mock()
        licenses_col.where.return_value = licenses_q

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.PAYOUTS: payouts_col,
            Collections.LICENSES: licenses_col,
        }[name]
        mock_get_db.return_value = db

        # Fresh order disappears inside transaction.
        order_ref.get.side_effect = [_snap(base_order, doc_id="o_txn_1"), _snap(exists=False)]
        with pytest.raises(https_fn.HttpsError) as missing_order:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o_txn_1", Fields.PRODUCT_ID: "prod_1"}))
        assert missing_order.value.code == "not-found"

        # Fresh order exists but product row gone.
        fresh_no_item = _base_order_data(is_digital=False)
        fresh_no_item[Fields.ITEMS] = [{Fields.PRODUCT_ID: "other", Fields.SELLER_ID: "seller_1"}]
        order_ref.get.side_effect = [_snap(base_order, doc_id="o_txn_2"), _snap(fresh_no_item, doc_id="o_txn_2")]
        with pytest.raises(https_fn.HttpsError) as missing_item:
            refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o_txn_2", Fields.PRODUCT_ID: "prod_1"}))
        assert missing_item.value.code == "not-found"

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.OrderEvent.write")
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_firestore")
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.stripe.Transfer.create_reversal")
    @patch("handlers.orders.stripe.Refund.create")
    @patch("handlers.orders.get_db")
    def test_refund_order_item_success_with_transfer_reversal_and_stock_restore(
        self,
        mock_get_db,
        mock_refund_create,
        mock_reversal_create,
        mock_rl,
        _mock_sanitized,
        mock_get_fs,
        _mock_ts,
        mock_order_event,
        _mock_resp,
    ):
        from handlers.orders import refund_order_item

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_refund_create.return_value = Mock(id="re_1")
        mock_reversal_create.return_value = Mock(id="trr_1")

        fs = Mock()
        fs.transactional = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        fs.ArrayUnion.side_effect = lambda values: ("arr_union", values)
        mock_get_fs.return_value = fs

        order_ref = Mock()
        order_ref.get.return_value = _snap(_base_order_data(is_digital=False), doc_id="order_1")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, doc_id="seller_1")
        users_col = Mock()
        users_col.document.return_value = user_ref

        product_ref = Mock()
        inv_ref = Mock()
        product_ref.collection.return_value.document.return_value = inv_ref
        products_col = Mock()
        products_col.document.return_value = product_ref

        payout_doc = _snap(
            {
                Fields.AMOUNT_CENTS: 3600,
                Fields.NET_AMOUNT_CENTS: 3000,
                Fields.PLATFORM_FEE_CENTS: 600,
                Fields.STRIPE_TRANSFER_ID: "tr_1",
            },
            doc_id="payout_1",
        )
        payout_query = Mock()
        payout_query.where.return_value = payout_query
        payout_query.limit.return_value = payout_query
        payout_query.get.return_value = [payout_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payout_query

        licenses_q = Mock()
        licenses_q.where.return_value = licenses_q
        licenses_q.stream.return_value = []
        licenses_col = Mock()
        licenses_col.where.return_value = licenses_q

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.PAYOUTS: payouts_col,
            Collections.LICENSES: licenses_col,
        }[name]
        mock_get_db.return_value = db

        out = refund_order_item(
            _req("seller_1", {Fields.ORDER_ID: "order_1", Fields.PRODUCT_ID: "prod_1", "reason": "Damaged"})
        )

        assert out["success"] is True
        assert out[Fields.REFUND_ID] == "re_1"
        mock_refund_create.assert_called_once()
        mock_reversal_create.assert_called_once()
        payout_doc.reference.update.assert_called_once()
        assert tx.update.call_count >= 2
        tx.set.assert_called_once()
        mock_order_event.assert_called_once()

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.OrderEvent.write")
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_firestore")
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.stripe.Transfer.create_reversal")
    @patch("handlers.orders.stripe.Refund.create")
    @patch("handlers.orders.get_db")
    def test_refund_order_item_reversal_error_is_logged_but_refund_succeeds(
        self,
        mock_get_db,
        mock_refund_create,
        mock_reversal_create,
        mock_rl,
        _mock_sanitized,
        mock_get_fs,
        _mock_ts,
        mock_order_event,
        _mock_resp,
    ):
        from handlers.orders import refund_order_item

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_refund_create.return_value = Mock(id="re_2")
        mock_reversal_create.side_effect = stripe.error.StripeError("reversal failed")

        fs = Mock()
        fs.transactional = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        fs.ArrayUnion.side_effect = lambda values: ("arr_union", values)
        mock_get_fs.return_value = fs

        order_ref = Mock()
        order_ref.get.return_value = _snap(_base_order_data(is_digital=False), doc_id="order_2")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, doc_id="seller_1")
        users_col = Mock()
        users_col.document.return_value = user_ref

        product_ref = Mock()
        product_ref.collection.return_value.document.return_value = Mock()
        products_col = Mock()
        products_col.document.return_value = product_ref

        payout_doc = _snap(
            {
                Fields.AMOUNT_CENTS: 3600,
                Fields.NET_AMOUNT_CENTS: 3000,
                Fields.STRIPE_TRANSFER_ID: "tr_2",
            },
            doc_id="payout_2",
        )
        payout_query = Mock()
        payout_query.where.return_value = payout_query
        payout_query.limit.return_value = payout_query
        payout_query.get.return_value = [payout_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payout_query

        licenses_q = Mock()
        licenses_q.where.return_value = licenses_q
        licenses_q.stream.return_value = []
        licenses_col = Mock()
        licenses_col.where.return_value = licenses_q

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.PAYOUTS: payouts_col,
            Collections.LICENSES: licenses_col,
        }[name]
        mock_get_db.return_value = db

        out = refund_order_item(
            _req("seller_1", {Fields.ORDER_ID: "order_2", Fields.PRODUCT_ID: "prod_1", "reason": "Defect"})
        )

        assert out["success"] is True
        assert out[Fields.REFUND_ID] == "re_2"
        mock_refund_create.assert_called_once()
        mock_reversal_create.assert_called_once()
        payout_doc.reference.update.assert_not_called()
        mock_order_event.assert_called_once()

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.OrderEvent.write")
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_firestore")
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.stripe.Refund.create")
    @patch("handlers.orders.get_db")
    def test_refund_order_item_digital_revokes_active_licenses(
        self,
        mock_get_db,
        mock_refund_create,
        mock_rl,
        _mock_sanitized,
        mock_get_fs,
        _mock_ts,
        mock_order_event,
        _mock_resp,
    ):
        from handlers.orders import refund_order_item

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_refund_create.return_value = Mock(id="re_3")

        fs = Mock()
        fs.transactional = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        fs.ArrayUnion.side_effect = lambda values: ("arr_union", values)
        mock_get_fs.return_value = fs

        order_ref = Mock()
        order_ref.get.return_value = _snap(_base_order_data(is_digital=True), doc_id="order_3")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, doc_id="seller_1")
        users_col = Mock()
        users_col.document.return_value = user_ref

        product_ref = Mock()
        products_col = Mock()
        products_col.document.return_value = product_ref

        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.get.return_value = []
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        lic_active = _snap({Fields.STATUS: "active"}, doc_id="lic_1")
        lic_revoked = _snap({Fields.STATUS: "revoked"}, doc_id="lic_2")
        licenses_q = Mock()
        licenses_q.where.return_value = licenses_q
        licenses_q.stream.return_value = [lic_active, lic_revoked]
        licenses_col = Mock()
        licenses_col.where.return_value = licenses_q

        tx = Mock()
        batch = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.batch.return_value = batch
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.PAYOUTS: payouts_col,
            Collections.LICENSES: licenses_col,
        }[name]
        mock_get_db.return_value = db

        out = refund_order_item(
            _req("seller_1", {Fields.ORDER_ID: "order_3", Fields.PRODUCT_ID: "prod_1", "reason": "Access issue"})
        )

        assert out["success"] is True
        batch.update.assert_called_once()
        batch.commit.assert_called_once()
        tx.update.assert_called_once()
        mock_order_event.assert_called_once()

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.OrderEvent.write")
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_firestore")
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.stripe.Refund.create")
    @patch("handlers.orders.get_db")
    def test_refund_order_item_digital_license_revoke_errors_are_swallowed(
        self,
        mock_get_db,
        mock_refund_create,
        mock_rl,
        _mock_sanitized,
        mock_get_fs,
        _mock_ts,
        mock_order_event,
        _mock_resp,
    ):
        from handlers.orders import refund_order_item

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_refund_create.return_value = Mock(id="re_lic_err")

        fs = Mock()
        fs.transactional = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        fs.ArrayUnion.side_effect = lambda values: ("arr_union", values)
        mock_get_fs.return_value = fs

        order_ref = Mock()
        order_ref.get.return_value = _snap(_base_order_data(is_digital=True), doc_id="order_lic_err")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, doc_id="seller_1")
        users_col = Mock()
        users_col.document.return_value = user_ref

        products_col = Mock()
        products_col.document.return_value = Mock()

        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.get.return_value = []
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        licenses_q = Mock()
        licenses_q.where.return_value = licenses_q
        licenses_q.stream.side_effect = RuntimeError("license query failed")
        licenses_col = Mock()
        licenses_col.where.return_value = licenses_q

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.PAYOUTS: payouts_col,
            Collections.LICENSES: licenses_col,
        }[name]
        mock_get_db.return_value = db

        out = refund_order_item(
            _req("seller_1", {Fields.ORDER_ID: "order_lic_err", Fields.PRODUCT_ID: "prod_1", "reason": "Access issue"})
        )

        assert out["success"] is True
        mock_order_event.assert_called_once()

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_firestore")
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.stripe.Refund.create")
    @patch("handlers.orders.get_db")
    def test_refund_order_item_race_returns_already_refunded_message(
        self,
        mock_get_db,
        mock_refund_create,
        mock_rl,
        _mock_sanitized,
        mock_get_fs,
        _mock_ts,
        _mock_resp,
    ):
        from handlers.orders import refund_order_item

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_refund_create.return_value = Mock(id="re_4")

        fs = Mock()
        fs.transactional = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        fs.ArrayUnion.side_effect = lambda values: ("arr_union", values)
        mock_get_fs.return_value = fs

        initial = _snap(_base_order_data(is_digital=False), doc_id="order_4")
        race_data = _base_order_data(is_digital=False)
        race_data[Fields.ITEMS][0][Fields.STATUS] = DeliveryStatusValues.REFUNDED
        fresh_refunded = _snap(race_data, doc_id="order_4")

        order_ref = Mock()
        order_ref.get.side_effect = [initial, fresh_refunded]
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, doc_id="seller_1")
        users_col = Mock()
        users_col.document.return_value = user_ref

        products_col = Mock()
        products_col.document.return_value = Mock()

        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.get.return_value = []
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        licenses_q = Mock()
        licenses_q.where.return_value = licenses_q
        licenses_q.stream.return_value = []
        licenses_col = Mock()
        licenses_col.where.return_value = licenses_q

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.PAYOUTS: payouts_col,
            Collections.LICENSES: licenses_col,
        }[name]
        mock_get_db.return_value = db

        out = refund_order_item(
            _req("seller_1", {Fields.ORDER_ID: "order_4", Fields.PRODUCT_ID: "prod_1", "reason": "Late race"})
        )

        assert out["success"] is True
        assert out["message"] == "Item was already refunded"
