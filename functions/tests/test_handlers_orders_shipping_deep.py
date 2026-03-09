from datetime import UTC, datetime, timedelta
from unittest.mock import Mock, patch

import pytest
import stripe
from firebase_functions import https_fn

from schema_constants import (
    ApiKeys,
    Collections,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
    ShippingApprovalStatusValues,
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


class TestApproveShippingCostDeep:
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_approve_shipping_cost_guard_matrix(self, mock_get_db, mock_rl):
        from handlers.orders import approve_shipping_cost

        with pytest.raises(https_fn.HttpsError) as unauth:
            approve_shipping_cost(_req(None, {Fields.ORDER_ID: "order_1", ApiKeys.APPROVED: True}))
        assert unauth.value.code == "unauthenticated"

        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        with pytest.raises(https_fn.HttpsError) as limited:
            approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_1", ApiKeys.APPROVED: True}))
        assert limited.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        db = Mock()
        order_ref = Mock()
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as missing_order_id:
            approve_shipping_cost(_req("buyer_1", {ApiKeys.APPROVED: True}))
        assert missing_order_id.value.code == "invalid-argument"

        order_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as not_found:
            approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_x", ApiKeys.APPROVED: True}))
        assert not_found.value.code == "not-found"

        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "other_buyer",
                Fields.SHIPPING_APPROVAL: {Fields.STATUS: ShippingApprovalStatusValues.PENDING},
            }
        )
        with pytest.raises(https_fn.HttpsError) as permission:
            approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_x", ApiKeys.APPROVED: True}))
        assert permission.value.code == "permission-denied"

        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.SHIPPING_APPROVAL: {Fields.STATUS: ShippingApprovalStatusValues.APPROVED},
            }
        )
        with pytest.raises(https_fn.HttpsError) as no_pending:
            approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_x", ApiKeys.APPROVED: True}))
        assert no_pending.value.code == "failed-precondition"

    @patch("firebase_admin.firestore.transactional", side_effect=lambda fn: fn)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_approve_shipping_cost_approve_branch_validation_paths(self, mock_get_db, mock_rl, _mock_txn_dec):
        from handlers.orders import approve_shipping_cost

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_ref = Mock()
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        base = {
            Fields.USER_ID: "buyer_1",
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.SHIPPING_COST_CENTS: 1000,
            Fields.TAX_AMOUNT_CENTS: 130,
            Fields.TOTAL_AMOUNT_CENTS: 2130,
            Fields.SELLER_SHIPPING_COSTS: {"seller_1": 1000},
            Fields.SHIPPING_APPROVAL: {
                Fields.STATUS: ShippingApprovalStatusValues.PENDING,
                Fields.REQUESTED_BY: "seller_1",
                Fields.ACTUAL_COST: 12.0,
                Fields.NEW_COST_CENTS: 1200,
            },
            Fields.SHIPPING_ADDRESS: {Fields.STATE: "ON"},
        }

        # Fresh order missing in transaction.
        order_ref.get.side_effect = [_snap(base, doc_id="order_1"), _snap(exists=False)]
        with pytest.raises(https_fn.HttpsError) as missing_fresh:
            approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_1", ApiKeys.APPROVED: True}))
        assert missing_fresh.value.code == "not-found"

        # Fresh approval no longer pending.
        fresh_non_pending = dict(base)
        fresh_non_pending[Fields.SHIPPING_APPROVAL] = {Fields.STATUS: ShippingApprovalStatusValues.REJECTED}
        order_ref.get.side_effect = [_snap(base, doc_id="order_2"), _snap(fresh_non_pending, doc_id="order_2")]
        with pytest.raises(https_fn.HttpsError) as stale_state:
            approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_2", ApiKeys.APPROVED: True}))
        assert stale_state.value.code == "failed-precondition"

        # Cost exceeds threshold.
        high_cost = dict(base)
        high_cost[Fields.SHIPPING_APPROVAL] = {
            Fields.STATUS: ShippingApprovalStatusValues.PENDING,
            Fields.REQUESTED_BY: "seller_1",
            Fields.ACTUAL_COST: 1000.0,
            Fields.NEW_COST_CENTS: 100000,
        }
        order_ref.get.side_effect = [_snap(base, doc_id="order_3"), _snap(high_cost, doc_id="order_3")]
        with pytest.raises(https_fn.HttpsError) as too_high:
            approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_3", ApiKeys.APPROVED: True}))
        assert too_high.value.code == "invalid-argument"

        # Authorization expired.
        expired = dict(base)
        expired[Fields.EXPIRES_AT] = datetime.now(UTC) - timedelta(minutes=1)
        order_ref.get.side_effect = [_snap(base, doc_id="order_4"), _snap(expired, doc_id="order_4")]
        with pytest.raises(https_fn.HttpsError) as expired_exc:
            approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_4", ApiKeys.APPROVED: True}))
        assert expired_exc.value.code == "failed-precondition"

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders._restore_stock_to_batch")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_reject_shipping_authorized_cancels_pi_and_restores_stock(
        self,
        mock_get_db,
        mock_rl,
        mock_restore_stock,
        _mock_ts,
        _mock_resp,
    ):
        from handlers.orders import approve_shipping_cost

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_auth",
            Fields.SHIPPING_APPROVAL: {
                Fields.STATUS: ShippingApprovalStatusValues.PENDING,
            },
            Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.QUANTITY: 2}],
        }

        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="order_auth")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        tx = Mock()
        batch = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.batch.return_value = batch
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
        }[name]
        mock_get_db.return_value = db

        out = approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_auth", ApiKeys.APPROVED: False}))

        assert out["success"] is True
        assert out[ApiKeys.APPROVED] is False
        mock_restore_stock.assert_called_once_with(batch, order_data[Fields.ITEMS])
        batch.commit.assert_called_once()
        assert tx.update.call_count == 1
        assert order_ref.update.call_count == 1

    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders._restore_stock_to_batch")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_reject_shipping_captured_refund_failure_flags_manual_review(
        self,
        mock_get_db,
        mock_rl,
        mock_restore_stock,
        _mock_ts,
    ):
        from handlers.orders import approve_shipping_cost

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_cap",
            Fields.SHIPPING_APPROVAL: {
                Fields.STATUS: ShippingApprovalStatusValues.PENDING,
            },
            Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.QUANTITY: 1}],
        }

        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="order_cap")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.batch.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
        }[name]
        mock_get_db.return_value = db

        with patch("handlers.orders.stripe.Refund.create", side_effect=stripe.error.StripeError("refund failed")):
            with pytest.raises(https_fn.HttpsError) as exc:
                approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_cap", ApiKeys.APPROVED: False}))

        assert exc.value.code == "internal"
        assert tx.update.call_count == 1
        mock_restore_stock.assert_not_called()

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_approve_shipping_expected_cost_mismatch_rejected(self, mock_get_db, mock_rl):
        from handlers.orders import approve_shipping_cost

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_auth2",
            Fields.SHIPPING_COST_CENTS: 1000,
            Fields.TAX_AMOUNT_CENTS: 100,
            Fields.TOTAL_AMOUNT_CENTS: 3000,
            Fields.SELLER_SHIPPING_COSTS: {"seller_1": 1000},
            Fields.SHIPPING_APPROVAL: {
                Fields.STATUS: ShippingApprovalStatusValues.PENDING,
                Fields.REQUESTED_BY: "seller_1",
                Fields.ACTUAL_COST: 12.50,
                Fields.NEW_COST_CENTS: 1250,
            },
            Fields.SHIPPING_ADDRESS: {Fields.STATE: "ON"},
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="order_exp_mismatch")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            approve_shipping_cost(
                _req(
                    "buyer_1",
                    {
                        Fields.ORDER_ID: "order_exp_mismatch",
                        ApiKeys.APPROVED: True,
                        "expectedCostCents": 1200,
                    },
                )
            )

        assert exc.value.code == "failed-precondition"

    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.stripe.PaymentIntent.modify", side_effect=stripe.error.StripeError("pi modify failed"))
    @patch("services.shipping_service.get_tax_rate", side_effect=[ValueError("bad province"), 0.13])
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_approve_shipping_non_blocked_pi_modify_failure_raises_internal_and_flags_review(
        self,
        mock_get_db,
        mock_rl,
        _mock_tax_rate,
        _mock_pi_modify,
        _mock_ts,
    ):
        from handlers.orders import approve_shipping_cost

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.PAYMENT_STATUS: PaymentStatusValues.AWAITING_PAYMENT,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_pending",
            Fields.SHIPPING_COST_CENTS: 1000,
            Fields.TAX_AMOUNT_CENTS: 100,
            Fields.TOTAL_AMOUNT_CENTS: 2100,
            Fields.SELLER_SHIPPING_COSTS: {"seller_1": 1000},
            Fields.SHIPPING_APPROVAL: {
                Fields.STATUS: ShippingApprovalStatusValues.PENDING,
                Fields.REQUESTED_BY: "seller_1",
                Fields.ACTUAL_COST: 12.00,
                Fields.NEW_COST_CENTS: 1200,
            },
            Fields.SHIPPING_ADDRESS: {Fields.STATE: "XX"},
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="order_pi_fail")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "order_pi_fail", ApiKeys.APPROVED: True}))

        assert exc.value.code == "internal"
        assert tx.update.call_count >= 1


class TestUpdateShippingCostDeep:
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_shipping_cost_guard_matrix(self, mock_get_db, mock_rl, _mock_sanitized):
        from handlers.orders import update_shipping_cost

        with pytest.raises(https_fn.HttpsError) as unauth:
            update_shipping_cost(_req(None, {Fields.ORDER_ID: "o1", ApiKeys.NEW_SHIPPING_COST: 1.0}))
        assert unauth.value.code == "unauthenticated"

        mock_rl.return_value.check_rate_limit.return_value = (False, "limited")
        with pytest.raises(https_fn.HttpsError) as limited:
            update_shipping_cost(_req("seller_1", {Fields.ORDER_ID: "o1", ApiKeys.NEW_SHIPPING_COST: 1.0}))
        assert limited.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        db = Mock()
        order_ref = Mock()
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as missing_order_id:
            update_shipping_cost(_req("seller_1", {ApiKeys.NEW_SHIPPING_COST: 1.0}))
        assert missing_order_id.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_cost:
            update_shipping_cost(_req("seller_1", {Fields.ORDER_ID: "o1", ApiKeys.NEW_SHIPPING_COST: -1.0}))
        assert bad_cost.value.code == "invalid-argument"

        order_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as not_found:
            update_shipping_cost(_req("seller_1", {Fields.ORDER_ID: "o1", ApiKeys.NEW_SHIPPING_COST: 1.0}))
        assert not_found.value.code == "not-found"

        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.ITEMS: [{Fields.SELLER_ID: "other_seller"}],
            }
        )
        with pytest.raises(https_fn.HttpsError) as no_items:
            update_shipping_cost(_req("seller_1", {Fields.ORDER_ID: "o1", ApiKeys.NEW_SHIPPING_COST: 1.0}))
        assert no_items.value.code == "permission-denied"

        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.CANCELLED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            }
        )
        with pytest.raises(https_fn.HttpsError) as bad_status:
            update_shipping_cost(_req("seller_1", {Fields.ORDER_ID: "o1", ApiKeys.NEW_SHIPPING_COST: 1.0}))
        assert bad_status.value.code == "failed-precondition"

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_shipping_free_shipping_order_requires_buyer_approval(
        self,
        mock_get_db,
        mock_rl,
        _mock_sanitized,
        _mock_ts,
        _mock_resp,
    ):
        from handlers.orders import update_shipping_cost

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.SHIPPING_COST_CENTS: 0,
            Fields.SELLER_SHIPPING_COSTS: {},
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1", Fields.PRODUCT_ID: "prod_1", Fields.QUANTITY: 1}],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="order_free_ship")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        out = update_shipping_cost(
            _req(
                "seller_1",
                {
                    Fields.ORDER_ID: "order_free_ship",
                    ApiKeys.NEW_SHIPPING_COST: 3.75,
                    ApiKeys.REASON: "Carrier fee",
                },
            )
        )

        assert out["success"] is True
        assert out[ApiKeys.APPROVAL_REQUIRED] is True
        update_payload = order_ref.update.call_args.args[0]
        assert update_payload[Fields.SHIPPING_APPROVAL][Fields.STATUS] == ShippingApprovalStatusValues.PENDING
        assert update_payload[Fields.SHIPPING_APPROVAL][Fields.ORIGINAL_COST_CENTS] == 0

    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_shipping_rejects_invalid_payment_status(self, mock_get_db, mock_rl, _mock_sanitized):
        from handlers.orders import update_shipping_cost

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.USER_ID: "buyer_1",
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: "pending",
            Fields.SHIPPING_COST_CENTS: 500,
            Fields.SELLER_SHIPPING_COSTS: {"seller_1": 500},
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1", Fields.PRODUCT_ID: "prod_1", Fields.QUANTITY: 1}],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="order_bad_pay")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            update_shipping_cost(
                _req(
                    "seller_1",
                    {
                        Fields.ORDER_ID: "order_bad_pay",
                        ApiKeys.NEW_SHIPPING_COST: 7.25,
                        ApiKeys.REASON: "Carrier update",
                    },
                )
            )

        assert exc.value.code == "failed-precondition"

    @patch("handlers.orders.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("services.shipping_service.get_tax_rate", return_value=0.13)
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_update_shipping_cost_captured_with_pi_modify_blocked_flags_manual_review(
        self,
        mock_get_db,
        mock_rl,
        _mock_tax,
        _mock_sanitized,
        _mock_ts,
        _mock_resp,
    ):
        from handlers.orders import update_shipping_cost

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        order_data = {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_cap_blocked",
            Fields.SHIPPING_COST_CENTS: 500,
            Fields.SELLER_SHIPPING_COSTS: {"seller_1": 500},
            Fields.TAX_AMOUNT_CENTS: 50,
            Fields.TOTAL_AMOUNT_CENTS: 1550,
            Fields.TAXES: {"HST": 0.65},
            Fields.SHIPPING_ADDRESS: {Fields.STATE: "ON"},
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1", Fields.PRODUCT_ID: "prod_1", Fields.QUANTITY: 1}],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="order_cap_blocked")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
        mock_get_db.return_value = db

        out = update_shipping_cost(
            _req(
                "seller_1",
                {
                    Fields.ORDER_ID: "order_cap_blocked",
                    ApiKeys.NEW_SHIPPING_COST: 5.5,
                    ApiKeys.REASON: "Carrier surcharge",
                },
            )
        )

        assert out[ApiKeys.APPROVAL_REQUIRED] is False
        # one manual-review update + one order totals update
        assert order_ref.update.call_count >= 2
