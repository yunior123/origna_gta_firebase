from __future__ import annotations

import importlib
import sys
from datetime import UTC, datetime, timedelta
from types import ModuleType, SimpleNamespace
from unittest.mock import Mock, patch

import pytest
import stripe
from firebase_functions import https_fn

from schema_constants import (
    ApiKeys,
    BusinessRules,
    Collections,
    DeliveryStatusValues,
    DeliveryTypeValues,
    Fields,
    NotificationTypes,
    OrderStatusValues,
    PaymentStatusValues,
    ReturnStatusValues,
    ShippingApprovalStatusValues,
    UserRoleValues,
)


def _snap(data=None, *, exists: bool = True, doc_id: str = "doc_1", reference: Mock | None = None):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.reference = reference or Mock()
    snap.to_dict.return_value = {} if data is None else data
    return snap


def _req(uid: str | None, data: dict):
    req = Mock()
    req.auth = Mock(uid=uid) if uid else None
    req.data = data
    return req


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

    def _decorator(fn):
        return fn

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


class _SneakyStatus:
    """Pass allowed-payment check once, then bypass PI-blocked tuple check."""

    def __init__(self):
        self._calls = 0

    def __eq__(self, other):
        self._calls += 1
        if self._calls <= 2:
            return other in (PaymentStatusValues.AUTHORIZED, PaymentStatusValues.CAPTURED)
        return False


class _FlakyRefundStatusItem(dict):
    """First status read is not-refunded, second status read is refunded."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._status_reads = 0

    def get(self, key, default=None):
        if key == Fields.STATUS:
            self._status_reads += 1
            if self._status_reads == 1:
                return DeliveryStatusValues.DELIVERED
            return DeliveryStatusValues.REFUNDED
        return super().get(key, default)


class _PerishableItem(dict):
    def get(self, key, default=None):
        if key == Fields.NAME:
            raise RuntimeError("name explode")
        return super().get(key, default)


@patch("handlers.orders.get_firestore")
@patch("handlers.orders.get_db")
@patch("handlers.orders.is_valid_order_status_transition", return_value=True)
@patch("services.rate_limiter.RateLimiter")
def test_update_order_status_seller_without_owned_items_returns_permission_denied(
    mock_rl,
    _mock_transition,
    mock_get_db,
    mock_get_firestore,
):
    from handlers.orders import update_order_status

    mock_get_firestore.return_value = SimpleNamespace(transactional=lambda fn: fn)
    mock_rl.return_value.check_rate_limit.return_value = (True, "")

    order_ref = Mock()
    initial = {
        Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
        Fields.ITEMS: [{Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
    }
    fresh_no_seller_items = {
        Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
        Fields.ITEMS: [{Fields.SELLER_ID: "other_seller", Fields.STATUS: DeliveryStatusValues.PENDING}],
    }
    order_ref.get.side_effect = [_snap(initial), _snap(fresh_no_seller_items)]

    user_ref = Mock()
    user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, exists=True)

    orders_coll = Mock()
    orders_coll.document.return_value = order_ref
    users_coll = Mock()
    users_coll.document.return_value = user_ref

    db = Mock()
    db.transaction.return_value = Mock()
    db.collection.side_effect = lambda name: {
        Collections.ORDERS: orders_coll,
        Collections.USERS: users_coll,
    }[name]
    mock_get_db.return_value = db

    with pytest.raises(https_fn.HttpsError) as exc:
        update_order_status(
            _req(
                "seller_1",
                {Fields.ORDER_ID: "o_1", ApiKeys.NEW_STATUS: OrderStatusValues.SHIPPED},
            )
        )
    assert exc.value.code == "permission-denied"


@patch("handlers.orders.OrderEvent.write")
@patch("firebase_admin.firestore.transactional", side_effect=lambda fn: fn)
@patch("services.rate_limiter.RateLimiter")
@patch("handlers.orders.get_db")
def test_update_item_status_delivered_promotes_order_when_payment_captured(
    mock_get_db,
    mock_rl,
    _mock_txn,
    _mock_evt,
):
    from handlers.orders import _update_item_status_logic

    mock_rl.return_value.check_rate_limit.return_value = (True, "")
    order_ref = Mock()
    base_order = {
        Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
        Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        Fields.ITEMS: [
            {
                Fields.PRODUCT_ID: "p1",
                Fields.SELLER_ID: "seller_1",
                Fields.STATUS: DeliveryStatusValues.SHIPPED,
            },
            {
                Fields.PRODUCT_ID: "p2",
                Fields.SELLER_ID: "seller_2",
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
            },
        ],
    }
    order_ref.get.side_effect = [_snap(base_order), _snap(base_order)]
    orders_col = Mock()
    orders_col.document.return_value = order_ref
    db = Mock()
    db.transaction.return_value = Mock()
    db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
    mock_get_db.return_value = db

    out = _update_item_status_logic(
        "admin_1",
        {
            Fields.ORDER_ID: "o_2",
            Fields.PRODUCT_ID: "p1",
            ApiKeys.NEW_STATUS: DeliveryStatusValues.DELIVERED,
        },
        is_admin=True,
    )
    assert out["success"] is True
    update_payload = db.transaction.return_value.update.call_args.args[1]
    assert update_payload[Fields.ORDER_STATUS] == OrderStatusValues.DELIVERED


@patch("services.rate_limiter.RateLimiter")
@patch("handlers.orders.get_db")
def test_refund_order_item_precheck_already_refunded_branch(mock_get_db, mock_rl):
    from handlers.orders import refund_order_item

    mock_rl.return_value.check_rate_limit.return_value = (True, "")

    flaky_item = _FlakyRefundStatusItem(
        {
            Fields.PRODUCT_ID: "prod_1",
            Fields.SELLER_ID: "seller_1",
            Fields.PRICE: 10.0,
            Fields.QUANTITY: 1,
            Fields.DELIVERED_AT: datetime.now(UTC),
        }
    )
    order_ref = Mock()
    order_ref.get.return_value = _snap(
        {
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_1",
            Fields.SUBTOTAL_CENTS: 1000,
            Fields.ITEMS: [flaky_item],
        },
        exists=True,
    )
    user_ref = Mock()
    user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)

    orders_coll = Mock()
    orders_coll.document.return_value = order_ref
    users_coll = Mock()
    users_coll.document.return_value = user_ref

    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.ORDERS: orders_coll,
        Collections.USERS: users_coll,
    }[name]
    mock_get_db.return_value = db

    out = refund_order_item(_req("admin_1", {Fields.ORDER_ID: "o_3", Fields.PRODUCT_ID: "prod_1"}))
    assert out["success"] is True
    assert out["alreadyRefunded"] is True


@patch("services.rate_limiter.RateLimiter")
@patch("handlers.orders.get_db")
def test_refund_order_item_maps_stripe_refund_error_to_internal(mock_get_db, mock_rl):
    from handlers.orders import refund_order_item

    mock_rl.return_value.check_rate_limit.return_value = (True, "")

    order_item = {
        Fields.PRODUCT_ID: "prod_1",
        Fields.SELLER_ID: "seller_1",
        Fields.PRICE: 10.0,
        Fields.QUANTITY: 1,
        Fields.STATUS: DeliveryStatusValues.DELIVERED,
        Fields.DELIVERED_AT: datetime.now(UTC),
    }
    order_ref = Mock()
    order_ref.get.return_value = _snap(
        {
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_2",
            Fields.SUBTOTAL_CENTS: 1000,
            Fields.ITEMS: [order_item],
        },
        exists=True,
    )
    user_ref = Mock()
    user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, exists=True)

    orders_coll = Mock()
    orders_coll.document.return_value = order_ref
    users_coll = Mock()
    users_coll.document.return_value = user_ref
    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.ORDERS: orders_coll,
        Collections.USERS: users_coll,
    }[name]
    mock_get_db.return_value = db

    with patch("handlers.orders.stripe.error.StripeError", stripe.error.StripeError):
        with patch("handlers.orders.stripe.Refund.create", side_effect=stripe.error.StripeError("down")):
            with pytest.raises(https_fn.HttpsError) as exc:
                refund_order_item(_req("seller_1", {Fields.ORDER_ID: "o_4", Fields.PRODUCT_ID: "prod_1"}))
    assert exc.value.code == "internal"


def _shipping_reject_order_ref(data):
    order_ref = Mock()
    order_ref.get.return_value = _snap(data, exists=True, doc_id="ord_ship")
    return order_ref


@patch("firebase_admin.firestore.transactional", side_effect=lambda fn: fn)
@patch("services.rate_limiter.RateLimiter")
@patch("handlers.orders.get_db")
def test_approve_shipping_cost_reject_branches_and_status_transitions(mock_get_db, mock_rl, _mock_txn):
    from handlers.orders import approve_shipping_cost

    mock_rl.return_value.check_rate_limit.return_value = (True, "")
    tx = Mock()

    base = {
        Fields.USER_ID: "buyer_1",
        Fields.SHIPPING_APPROVAL: {Fields.STATUS: ShippingApprovalStatusValues.PENDING},
        Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
    }

    # order missing in transaction -> line 1571
    order_ref_missing = Mock()
    order_ref_missing.get.side_effect = [_snap(base, exists=True), _snap(exists=False)]
    orders_col = Mock()
    orders_col.document.return_value = order_ref_missing
    db = Mock()
    db.transaction.return_value = tx
    db.batch.return_value = Mock()
    db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
    mock_get_db.return_value = db
    with pytest.raises(https_fn.HttpsError) as missing_exc:
        approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "ord_ship", ApiKeys.APPROVED: False}))
    assert missing_exc.value.code == "not-found"

    # no pending in fresh transaction state -> line 1576
    top_pending = dict(base)
    fresh_not_pending = dict(base)
    fresh_not_pending[Fields.SHIPPING_APPROVAL] = {Fields.STATUS: ShippingApprovalStatusValues.APPROVED}
    order_ref_np = Mock()
    order_ref_np.get.side_effect = [_snap(top_pending, exists=True), _snap(fresh_not_pending, exists=True)]
    orders_col.document.return_value = order_ref_np
    with pytest.raises(https_fn.HttpsError) as np_exc:
        approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "ord_ship", ApiKeys.APPROVED: False}))
    assert np_exc.value.code == "failed-precondition"

    # already refunded guard -> line 1586
    refunded = dict(base)
    refunded[Fields.PAYMENT_STATUS] = PaymentStatusValues.REFUNDED
    order_ref_ref = _shipping_reject_order_ref(refunded)
    orders_col.document.return_value = order_ref_ref
    with pytest.raises(https_fn.HttpsError) as ref_exc:
        approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "ord_ship", ApiKeys.APPROVED: False}))
    assert ref_exc.value.code == "failed-precondition"

    # authorized path sets cancel payment status -> line 1594
    authorized = dict(base)
    authorized[Fields.PAYMENT_STATUS] = PaymentStatusValues.AUTHORIZED
    authorized[Fields.STRIPE_PAYMENT_INTENT_ID] = "pi_auth"
    order_ref_auth = _shipping_reject_order_ref(authorized)
    orders_col.document.return_value = order_ref_auth
    with patch("handlers.orders.stripe.PaymentIntent.cancel"):
        with patch("handlers.orders._restore_stock_to_batch"):
            out_auth = approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "ord_ship", ApiKeys.APPROVED: False}))
    assert out_auth["success"] is True
    tx_payload = tx.update.call_args_list[-1].args[1]
    assert tx_payload[Fields.PAYMENT_STATUS] == PaymentStatusValues.CANCELLED

    # captured path sets refunded payment status -> line 1606
    captured = dict(base)
    captured[Fields.PAYMENT_STATUS] = PaymentStatusValues.CAPTURED
    captured[Fields.STRIPE_PAYMENT_INTENT_ID] = "pi_cap"
    order_ref_cap = _shipping_reject_order_ref(captured)
    orders_col.document.return_value = order_ref_cap
    with patch("handlers.orders.stripe.Refund.create"):
        with patch("handlers.orders._restore_stock_to_batch"):
            out_cap = approve_shipping_cost(_req("buyer_1", {Fields.ORDER_ID: "ord_ship", ApiKeys.APPROVED: False}))
    assert out_cap["success"] is True
    tx_payload2 = tx.update.call_args_list[-1].args[1]
    assert tx_payload2[Fields.PAYMENT_STATUS] == PaymentStatusValues.REFUNDED


@patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
@patch("services.rate_limiter.RateLimiter")
@patch("handlers.orders.get_db")
def test_update_shipping_cost_large_increase_requires_approval(mock_get_db, mock_rl, _mock_sanitized):
    from handlers.orders import update_shipping_cost

    mock_rl.return_value.check_rate_limit.return_value = (True, "")

    order_ref = Mock()
    order_ref.get.return_value = _snap(
        {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            Fields.SELLER_SHIPPING_COSTS: {"seller_1": 1000},
            Fields.SHIPPING_COST_CENTS: 1000,
        },
        exists=True,
    )
    orders_col = Mock()
    orders_col.document.return_value = order_ref
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
    mock_get_db.return_value = db

    out = update_shipping_cost(
        _req(
            "seller_1",
            {
                Fields.ORDER_ID: "ord_upd_1",
                ApiKeys.NEW_SHIPPING_COST: 20.00,
            },
        )
    )
    assert out[ApiKeys.APPROVAL_REQUIRED] is True


@patch("handlers.orders.get_server_timestamp", return_value="ts")
@patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
@patch("services.rate_limiter.RateLimiter")
@patch("handlers.orders.get_db")
def test_update_shipping_cost_tax_fallback_and_total_updates(
    mock_get_db,
    mock_rl,
    _mock_sanitized,
    _mock_ts,
):
    from handlers.orders import update_shipping_cost

    mock_rl.return_value.check_rate_limit.return_value = (True, "")

    order_ref = Mock()
    order_ref.get.return_value = _snap(
        {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            Fields.SELLER_SHIPPING_COSTS: {"seller_1": 1000},
            Fields.SHIPPING_COST_CENTS: 1000,
            Fields.TAX_AMOUNT_CENTS: 100,
            Fields.TOTAL_AMOUNT_CENTS: 1100,
            Fields.TAXES: {"GST": 0.5},
            Fields.SHIPPING_ADDRESS: {Fields.STATE: "ZZ"},
            Fields.STRIPE_PAYMENT_INTENT_ID: "",
        },
        exists=True,
    )
    orders_col = Mock()
    orders_col.document.return_value = order_ref
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
    mock_get_db.return_value = db

    def _tax_rate(code):
        if code == "ZZ":
            raise ValueError("unknown province")
        return 0.05

    with patch("services.shipping_service.get_tax_rate", side_effect=_tax_rate):
        out = update_shipping_cost(
            _req("seller_1", {Fields.ORDER_ID: "ord_upd_2", ApiKeys.NEW_SHIPPING_COST: 12.00})
        )
    assert out[ApiKeys.APPROVAL_REQUIRED] is False
    payload = order_ref.update.call_args.args[0]
    assert Fields.TAX_AMOUNT_CENTS in payload
    assert Fields.TOTAL_AMOUNT_CENTS in payload
    assert Fields.TAXES in payload


@patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
@patch("services.rate_limiter.RateLimiter")
@patch("handlers.orders.get_db")
def test_update_shipping_cost_pi_modify_error_branch(mock_get_db, mock_rl, _mock_sanitized):
    from handlers.orders import update_shipping_cost

    mock_rl.return_value.check_rate_limit.return_value = (True, "")

    sneaky_status = _SneakyStatus()
    order_ref = Mock()
    order_ref.get.return_value = _snap(
        {
            Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
            Fields.PAYMENT_STATUS: sneaky_status,
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            Fields.SELLER_SHIPPING_COSTS: {"seller_1": 1000},
            Fields.SHIPPING_COST_CENTS: 1000,
            Fields.TAX_AMOUNT_CENTS: 0,
            Fields.TOTAL_AMOUNT_CENTS: 1000,
            Fields.SHIPPING_ADDRESS: {Fields.STATE: BusinessRules.DEFAULT_PROVINCE},
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_needs_modify",
        },
        exists=True,
    )
    orders_col = Mock()
    orders_col.document.return_value = order_ref
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
    mock_get_db.return_value = db

    with patch("services.shipping_service.get_tax_rate", return_value=0.05):
        with patch("handlers.orders.stripe.error.StripeError", stripe.error.StripeError):
            with patch("handlers.orders.stripe.PaymentIntent.modify", side_effect=stripe.error.StripeError("modify failed")):
                with pytest.raises(https_fn.HttpsError) as exc:
                    update_shipping_cost(
                        _req("seller_1", {Fields.ORDER_ID: "ord_upd_3", ApiKeys.NEW_SHIPPING_COST: 12.00})
                    )
    assert exc.value.code == "internal"
    assert order_ref.update.called


def test_assert_within_return_window_normalizes_naive_datetime():
    from handlers.orders import _assert_within_return_window

    item = {Fields.DELIVERED_AT: datetime.utcnow() - timedelta(days=1)}
    _assert_within_return_window(item)


@patch("handlers.orders.get_server_timestamp", return_value="ts")
@patch("handlers.orders.get_db")
def test_finalise_return_refunded_updates_return_doc(mock_get_db, _mock_ts):
    from handlers.orders import _finalise_return_refunded

    return_ref = Mock()
    returns_col = Mock()
    returns_col.document.return_value = return_ref
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.RETURN_REQUESTS: returns_col}[name]
    mock_get_db.return_value = db

    _finalise_return_refunded("o1", "p1", "r1", refund_amount_cents=333)
    first_patch = return_ref.update.call_args.args[0]
    assert first_patch[Fields.RETURN_REFUND_AMOUNT_CENTS] == 333

    _finalise_return_refunded("o1", "p1", "r2", refund_amount_cents=None)
    second_patch = return_ref.update.call_args.args[0]
    assert Fields.RETURN_REFUND_AMOUNT_CENTS not in second_patch


@patch("services.rate_limiter.RateLimiter")
@patch("handlers.orders.get_db")
def test_approve_return_request_approve_sets_tracking_and_note(mock_get_db, mock_rl):
    from handlers.orders import approve_return_request

    mock_rl.return_value.check_rate_limit.return_value = (True, "")

    user_ref = Mock()
    user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
    return_ref = Mock()
    return_ref.get.return_value = _snap(
        {
            Fields.SELLER_ID: "seller_1",
            Fields.BUYER_ID: "buyer_1",
            Fields.ORDER_ID: "ord_ret_1",
            Fields.PRODUCT_ID: "prod_1",
            Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED,
        },
        exists=True,
    )

    users_col = Mock()
    users_col.document.return_value = user_ref
    returns_col = Mock()
    returns_col.document.return_value = return_ref
    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.USERS: users_col,
        Collections.RETURN_REQUESTS: returns_col,
    }[name]
    mock_get_db.return_value = db

    out = approve_return_request(
        _req(
            "admin_1",
            {
                Fields.RETURN_ID: "ret_1",
                "action": "approve",
                Fields.RETURN_TRACKING_NUMBER: "RTN-123",
                Fields.RETURN_ADMIN_NOTE: "Approved by admin",
            },
        )
    )
    assert out["success"] is True
    patch_payload = return_ref.update.call_args.args[0]
    assert patch_payload[Fields.RETURN_TRACKING_NUMBER] == "RTN-123"
    assert patch_payload[Fields.RETURN_ADMIN_NOTE] == "Approved by admin"


@patch("services.rate_limiter.RateLimiter")
@patch("firebase_admin.firestore.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_approve_return_request_mark_received_swallows_sentry_capture_failure(mock_get_db, _mock_txn, mock_rl):
    from handlers.orders import approve_return_request

    mock_rl.return_value.check_rate_limit.return_value = (True, "")

    user_ref = Mock()
    user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
    return_ref = Mock()
    return_ref.get.side_effect = [
        _snap(
            {
                Fields.SELLER_ID: "seller_1",
                Fields.BUYER_ID: "buyer_1",
                Fields.ORDER_ID: "ord_ret_2",
                Fields.PRODUCT_ID: "prod_1",
                    Fields.RETURN_STATUS: ReturnStatusValues.LABEL_ISSUED,
                    Fields.QUANTITY: 1,
                },
                exists=True,
            ),
            _snap({Fields.RETURN_STATUS: ReturnStatusValues.LABEL_ISSUED}, exists=True),
        ]

    users_col = Mock()
    users_col.document.return_value = user_ref
    returns_col = Mock()
    returns_col.document.return_value = return_ref
    products_col = Mock()
    products_col.document.return_value = Mock()

    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.USERS: users_col,
        Collections.RETURN_REQUESTS: returns_col,
        Collections.PRODUCTS: products_col,
    }[name]
    db.transaction.return_value = Mock()
    mock_get_db.return_value = db

    sentry = ModuleType("sentry_sdk")
    sentry.capture_exception = Mock(side_effect=RuntimeError("sentry down"))
    sys.modules["sentry_sdk"] = sentry

    with patch("handlers.orders._process_return_refund", side_effect=RuntimeError("refund failed")):
        out = approve_return_request(_req("admin_1", {Fields.RETURN_ID: "ret_2", "action": "mark_received"}))
    assert out["success"] is True


@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_handle_payment_status_email_fetch_failure_returns_without_email(mock_get_db, _mock_txn):
    from handlers.orders import _handle_payment_status_email

    order_ref = Mock()
    order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, exists=True)
    orders_col = Mock()
    orders_col.document.return_value = order_ref

    db = Mock()
    db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
    db.transaction.return_value = Mock()
    mock_get_db.return_value = db

    with patch("firebase_admin.firestore.client", side_effect=RuntimeError("client down")):
        _handle_payment_status_email(
            "ord_ps_1",
            {Fields.USER_ID: "buyer_1"},
            PaymentStatusValues.REFUNDED,
            buyer_email=None,
        )


@patch("handlers.orders.enqueue_email_task")
@patch("handlers.orders.get_order_refunded_email", return_value="<p>refunded</p>")
@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_handle_payment_status_email_fetches_buyer_email_from_firestore_client(
    mock_get_db,
    _mock_txn,
    _mock_tpl,
    mock_enqueue,
):
    from handlers.orders import _handle_payment_status_email

    order_ref = Mock()
    order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, exists=True)
    orders_col = Mock()
    orders_col.document.return_value = order_ref

    db = Mock()
    db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
    db.transaction.return_value = Mock()
    mock_get_db.return_value = db

    buyer_doc = _snap({Fields.EMAIL: "buyer@example.com"}, exists=True)
    fs_db = Mock()
    fs_db.collection.return_value.document.return_value.get.return_value = buyer_doc
    with patch("firebase_admin.firestore.client", return_value=fs_db):
        _handle_payment_status_email(
            "ord_ps_2",
            {Fields.USER_ID: "buyer_1", Fields.CUMULATIVE_REFUNDED_CENTS: 100, Fields.PREFERRED_LANGUAGE: "en"},
            PaymentStatusValues.REFUNDED,
            buyer_email=None,
        )
    mock_enqueue.assert_called_once()


@patch("handlers.orders.get_db")
def test_on_order_status_changed_returns_when_before_or_after_missing(mock_get_db):
    from handlers.orders import on_order_status_changed

    evt = _order_event("ord_evt_1", {}, {Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED})
    on_order_status_changed(evt)
    mock_get_db.assert_not_called()


@patch("handlers.orders._handle_payment_status_email")
def test_on_order_status_changed_payment_status_change_then_same_order_status_returns(mock_ps):
    from handlers.orders import on_order_status_changed

    evt = _order_event(
        "ord_evt_2",
        {Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED, Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED},
        {Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
    )
    on_order_status_changed(evt)
    mock_ps.assert_called_once()


@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_on_order_status_changed_claim_false_paths(mock_get_db, _mock_txn):
    from handlers.orders import on_order_status_changed

    # missing fresh doc -> claim returns False (line 2581)
    order_ref_missing = Mock()
    order_ref_missing.get.return_value = _snap(exists=False)
    orders_col = Mock()
    orders_col.document.return_value = order_ref_missing
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
    db.transaction.return_value = Mock()
    mock_get_db.return_value = db
    on_order_status_changed(
        _order_event(
            "ord_evt_3",
            {Fields.ORDER_STATUS: OrderStatusValues.PENDING, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
            {Fields.ORDER_STATUS: OrderStatusValues.PROCESSING, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
        )
    )

    # duplicate sent status -> claim returns False (line 2584)
    order_ref_dup = Mock()
    order_ref_dup.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: [OrderStatusValues.PROCESSING]}, exists=True)
    orders_col.document.return_value = order_ref_dup
    on_order_status_changed(
        _order_event(
            "ord_evt_4",
            {Fields.ORDER_STATUS: OrderStatusValues.PENDING, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
            {Fields.ORDER_STATUS: OrderStatusValues.PROCESSING, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
        )
    )


@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_on_order_status_changed_claim_exception_branch(mock_get_db, _mock_txn):
    from handlers.orders import on_order_status_changed

    order_ref = Mock()
    order_ref.get.side_effect = RuntimeError("txn fail")
    orders_col = Mock()
    orders_col.document.return_value = order_ref
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
    db.transaction.return_value = Mock()
    mock_get_db.return_value = db

    on_order_status_changed(
        _order_event(
            "ord_evt_5",
            {Fields.ORDER_STATUS: OrderStatusValues.PENDING, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
            {Fields.ORDER_STATUS: OrderStatusValues.PROCESSING, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
        )
    )


@patch("handlers.orders.send_push_notification")
@patch("handlers.orders.enqueue_email_task")
@patch("handlers.orders.get_order_processing_email", return_value="<p>proc</p>")
@patch("handlers.orders._email_t", side_effect=lambda k, _lang="en": f"{k} {{oid}}")
@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_on_order_status_changed_fetches_buyer_email_from_user_doc(
    mock_get_db,
    _mock_txn,
    _mock_t,
    _mock_tpl,
    _mock_enqueue,
    _mock_push,
):
    from handlers.orders import on_order_status_changed

    order_ref = Mock()
    order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, exists=True)
    orders_col = Mock()
    orders_col.document.return_value = order_ref

    user_doc = _snap({Fields.EMAIL: "buyer@example.com", Fields.PREFERRED_LANGUAGE: "en"}, exists=True, doc_id="buyer_1")
    users_col = Mock()
    users_col.document.return_value.get.return_value = user_doc

    stock_q = Mock()
    stock_q.where.return_value = stock_q
    stock_q.stream.return_value = []
    stock_col = Mock()
    stock_col.where.return_value = stock_q

    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.ORDERS: orders_col,
        Collections.USERS: users_col,
        Collections.STOCK_NOTIFICATIONS: stock_col,
    }[name]
    db.transaction.return_value = Mock()
    db.batch.return_value = Mock()
    mock_get_db.return_value = db

    on_order_status_changed(
        _order_event(
            "ord_evt_6",
            {Fields.ORDER_STATUS: OrderStatusValues.PENDING, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
            {
                Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.USER_ID: "buyer_1",
                Fields.ITEMS: [],
            },
        )
    )


@patch("handlers.orders.get_seller_notification_email", return_value="<p>seller</p>")
@patch("handlers.orders.get_order_confirmation_email", return_value="<p>buyer</p>")
@patch("handlers.orders._email_t", side_effect=lambda k, _lang="en": f"{k} {{oid}}")
@patch("handlers.orders.enqueue_email_task")
@patch("handlers.orders.send_push_notification")
@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_on_order_status_changed_perishable_outer_exception_logged(
    mock_get_db,
    _mock_txn,
    _mock_push,
    _mock_enqueue,
    _mock_t,
    _mock_buyer_tpl,
    _mock_seller_tpl,
):
    from handlers.orders import on_order_status_changed

    order_ref = Mock()
    order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, exists=True)
    orders_col = Mock()
    orders_col.document.return_value = order_ref

    users_col = Mock()
    users_col.document.return_value.get.return_value = _snap(
        {Fields.EMAIL: "seller@example.com", Fields.PREFERRED_LANGUAGE: "en"},
        exists=True,
        doc_id="seller_1",
    )

    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.ORDERS: orders_col,
        Collections.USERS: users_col,
        Collections.STOCK_NOTIFICATIONS: Mock(),
    }[name]
    db.transaction.return_value = Mock()
    db.get_all.return_value = [_snap({Fields.EMAIL: "seller@example.com"}, exists=True, doc_id="seller_1")]
    db.batch.return_value = Mock()
    mock_get_db.return_value = db

    bad_item = _PerishableItem(
        {
            Fields.SELLER_ID: "seller_1",
            Fields.IS_PERISHABLE: True,
            Fields.PRODUCT_ID: "prod_1",
        }
    )
    on_order_status_changed(
        _order_event(
            "ord_evt_7",
            {Fields.ORDER_STATUS: OrderStatusValues.PENDING, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
            {
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.USER_ID: "buyer_1",
                Fields.CUSTOMER_EMAIL: "buyer@example.com",
                Fields.PREFERRED_LANGUAGE: "en",
                Fields.ITEMS: [bad_item],
            },
        )
    )


@patch("handlers.orders.send_push_notification")
@patch("handlers.orders.enqueue_email_task")
@patch("handlers.orders.get_order_processing_email", return_value="<p>processing</p>")
@patch("handlers.orders._email_t", side_effect=lambda k, _lang="en": f"{k} {{oid}}")
@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_on_order_status_changed_cleanup_missing_pid_and_deletes_subscriptions(
    mock_get_db,
    _mock_txn,
    _mock_t,
    _mock_tpl,
    _mock_enqueue,
    _mock_push,
):
    from handlers.orders import on_order_status_changed

    order_ref = Mock()
    order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, exists=True)
    orders_col = Mock()
    orders_col.document.return_value = order_ref

    sub_doc = _snap({}, exists=True)
    sub_q = Mock()
    sub_q.where.return_value = sub_q
    sub_q.stream.return_value = [sub_doc]
    stock_col = Mock()
    stock_col.where.return_value = sub_q

    users_col = Mock()
    users_col.document.return_value.get.return_value = _snap({Fields.EMAIL: "buyer@example.com"}, exists=True)
    batch = Mock()

    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.ORDERS: orders_col,
        Collections.USERS: users_col,
        Collections.STOCK_NOTIFICATIONS: stock_col,
    }[name]
    db.transaction.return_value = Mock()
    db.batch.return_value = batch
    mock_get_db.return_value = db

    on_order_status_changed(
        _order_event(
            "ord_evt_8",
            {Fields.ORDER_STATUS: OrderStatusValues.PENDING, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
            {
                Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.USER_ID: "buyer_1",
                Fields.CUSTOMER_EMAIL: "buyer@example.com",
                Fields.PREFERRED_LANGUAGE: "en",
                Fields.ITEMS: [{Fields.VARIANT_KEY: ""}, {Fields.PRODUCT_ID: "prod_1", Fields.VARIANT_KEY: ""}],
            },
        )
    )
    batch.delete.assert_called()


@patch("handlers.orders.send_push_notification")
@patch("handlers.orders.enqueue_email_task")
@patch("handlers.orders.get_seller_notification_email", return_value="<p>seller shipped</p>")
@patch("handlers.orders.get_order_shipped_email", return_value="<p>buyer shipped</p>")
@patch("handlers.orders._email_t", side_effect=lambda k, _lang="en": f"{k} {{oid}}")
@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_on_order_status_changed_shipped_skip_actor_and_handles_seller_exception(
    mock_get_db,
    _mock_txn,
    _mock_t,
    _mock_buyer_tpl,
    _mock_seller_tpl,
    _mock_enqueue,
    mock_push,
):
    from handlers.orders import on_order_status_changed

    order_ref = Mock()
    order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, exists=True)
    orders_col = Mock()
    orders_col.document.return_value = order_ref

    seller_actor = _snap({Fields.EMAIL: "actor@example.com"}, exists=True, doc_id="seller_actor")
    seller_other = _snap({Fields.EMAIL: "other@example.com"}, exists=True, doc_id="seller_other")
    users_col = Mock()
    users_col.document.return_value.get.return_value = _snap({Fields.EMAIL: "buyer@example.com"}, exists=True)

    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.ORDERS: orders_col,
        Collections.USERS: users_col,
    }[name]
    db.transaction.return_value = Mock()
    db.get_all.return_value = [seller_actor, seller_other]
    mock_get_db.return_value = db

    def _push_side_effect(uid, *args, **kwargs):
        if uid == "seller_other":
            raise RuntimeError("push fail")
        return None

    mock_push.side_effect = _push_side_effect
    on_order_status_changed(
        _order_event(
            "ord_evt_9",
            {Fields.ORDER_STATUS: OrderStatusValues.PROCESSING, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
            {
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.USER_ID: "buyer_1",
                Fields.CUSTOMER_EMAIL: "buyer@example.com",
                Fields.PREFERRED_LANGUAGE: "en",
                Fields.LAST_ACTOR_ID: "seller_actor",
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_actor"}, {Fields.SELLER_ID: "seller_other"}],
            },
        )
    )


@patch("services.email_service._email_wrapper", return_value="<p>wrapper</p>")
@patch("services.email_service._hero_header", return_value="<h1>head</h1>")
@patch("handlers.orders.enqueue_email_task")
@patch("handlers.orders.send_push_notification")
@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_on_order_status_changed_delivered_seller_notification_exception(
    mock_get_db,
    _mock_txn,
    mock_push,
    _mock_enqueue,
    _mock_hh,
    _mock_ew,
):
    from handlers.orders import on_order_status_changed

    order_ref = Mock()
    order_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, exists=True)
    orders_col = Mock()
    orders_col.document.return_value = order_ref

    seller_doc = _snap({Fields.EMAIL: "seller@example.com", Fields.PREFERRED_LANGUAGE: "en"}, exists=True, doc_id="seller_1")
    users_col = Mock()
    users_col.document.return_value.get.return_value = _snap({Fields.EMAIL: "buyer@example.com"}, exists=True)

    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.ORDERS: orders_col,
        Collections.USERS: users_col,
    }[name]
    db.transaction.return_value = Mock()
    db.get_all.return_value = [seller_doc]
    mock_get_db.return_value = db

    def _push_side_effect(uid, *args, **kwargs):
        if uid == "seller_1":
            raise RuntimeError("seller push fail")
        return None

    mock_push.side_effect = _push_side_effect

    on_order_status_changed(
        _order_event(
            "ord_evt_10",
            {Fields.ORDER_STATUS: OrderStatusValues.SHIPPED, Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED},
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.USER_ID: "buyer_1",
                Fields.CUSTOMER_EMAIL: "buyer@example.com",
                Fields.PREFERRED_LANGUAGE: "en",
                Fields.CONFIRMED_BY_CLIENT: False,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            },
        )
    )


@patch("handlers.orders.enqueue_email_task")
@patch("handlers.orders.get_return_refunded_email", return_value="<p>refunded</p>")
@patch("handlers.orders.get_return_received_email", return_value="<p>received</p>")
@patch("handlers.orders.get_db")
def test_send_return_email_handles_fetch_guards_and_received_refunded_branches(
    mock_get_db,
    _mock_recv,
    _mock_ref,
    mock_enqueue,
):
    from handlers.orders import _send_return_email

    bad_ref = Mock()
    bad_ref.get.side_effect = RuntimeError("read fail")
    good_ref = Mock()
    good_ref.get.return_value = _snap({Fields.EMAIL: "buyer@example.com", Fields.PREFERRED_LANGUAGE: "fr"}, exists=True)

    users_col = Mock()

    def _doc(uid):
        if uid == "seller_bad":
            return bad_ref
        return good_ref

    users_col.document.side_effect = _doc
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.USERS: users_col}[name]
    mock_get_db.return_value = db

    # Missing buyer uid + seller fetch exception -> line 3051 and 3057-3059
    _send_return_email({}, "ret_30", "order_30", "", "seller_bad", ReturnStatusValues.REQUESTED)

    # RECEIVED and REFUNDED status branches
    _send_return_email({}, "ret_31", "order_31", "buyer_1", "seller_bad", ReturnStatusValues.RECEIVED)
    _send_return_email({}, "ret_32", "order_32", "buyer_1", "seller_bad", ReturnStatusValues.REFUNDED)
    assert mock_enqueue.call_count >= 2


@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_on_return_request_status_changed_guard_and_claim_paths(mock_get_db, _mock_txn):
    from handlers.orders import on_return_request_status_changed

    # before/after missing -> line 3185
    on_return_request_status_changed(_return_event("ret_evt_1", {}, {Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED}))

    # old/new same -> line 3191
    on_return_request_status_changed(
        _return_event(
            "ret_evt_2",
            {Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED},
            {Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED},
        )
    )

    return_ref = Mock()
    returns_col = Mock()
    returns_col.document.return_value = return_ref
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.RETURN_REQUESTS: returns_col}[name]
    db.transaction.return_value = Mock()
    mock_get_db.return_value = db

    # missing fresh doc claim -> line 3207 then 3220 return
    return_ref.get.return_value = _snap(exists=False)
    on_return_request_status_changed(
        _return_event(
            "ret_evt_3",
            {Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED},
            {Fields.RETURN_STATUS: ReturnStatusValues.APPROVED},
        )
    )

    # already sent claim -> line 3210 then 3220
    return_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: [ReturnStatusValues.APPROVED]}, exists=True)
    on_return_request_status_changed(
        _return_event(
            "ret_evt_4",
            {Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED},
            {Fields.RETURN_STATUS: ReturnStatusValues.APPROVED},
        )
    )

    # claim exception path -> lines 3216-3218 and 3220
    return_ref.get.side_effect = RuntimeError("claim err")
    on_return_request_status_changed(
        _return_event(
            "ret_evt_5",
            {Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED},
            {Fields.RETURN_STATUS: ReturnStatusValues.APPROVED},
        )
    )


@patch("handlers.orders._send_return_email")
@patch("handlers.orders.send_push_notification")
@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_on_return_request_status_changed_requested_sends_push_and_email(
    mock_get_db,
    _mock_txn,
    mock_push,
    mock_send_return_email,
):
    from handlers.orders import on_return_request_status_changed

    return_ref = Mock()
    return_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, exists=True)
    returns_col = Mock()
    returns_col.document.return_value = return_ref
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.RETURN_REQUESTS: returns_col}[name]
    db.transaction.return_value = Mock()
    mock_get_db.return_value = db

    on_return_request_status_changed(
        _return_event(
            "ret_evt_6",
            {Fields.RETURN_STATUS: ReturnStatusValues.REJECTED},
            {
                Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED,
                Fields.ORDER_ID: "ord_600",
                Fields.BUYER_ID: "buyer_1",
                Fields.SELLER_ID: "seller_1",
            },
        )
    )
    mock_push.assert_called_once()
    mock_send_return_email.assert_called_once()


@patch("handlers.orders.send_push_notification", side_effect=RuntimeError("push fail"))
@patch("google.cloud.firestore_v1.transaction.transactional", side_effect=lambda fn: fn)
@patch("handlers.orders.get_db")
def test_on_return_request_status_changed_exception_path_logs(mock_get_db, _mock_txn, _mock_push):
    from handlers.orders import on_return_request_status_changed

    return_ref = Mock()
    return_ref.get.return_value = _snap({Fields.NOTIFICATIONS_SENT: []}, exists=True)
    returns_col = Mock()
    returns_col.document.return_value = return_ref
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.RETURN_REQUESTS: returns_col}[name]
    db.transaction.return_value = Mock()
    mock_get_db.return_value = db

    on_return_request_status_changed(
        _return_event(
            "ret_evt_7",
            {Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED},
            {
                Fields.RETURN_STATUS: ReturnStatusValues.APPROVED,
                Fields.ORDER_ID: "ord_700",
                Fields.BUYER_ID: "buyer_1",
                Fields.SELLER_ID: "seller_1",
            },
        )
    )


@patch("handlers.orders.get_db")
def test_on_order_item_shipped_guard_and_missing_user_email_paths(mock_get_db):
    from handlers.orders import on_order_item_shipped

    # before/after missing -> line 3303
    on_order_item_shipped(_order_event("ord_ship_1", {}, {Fields.ITEMS: []}))

    # no shipped transition -> line 3347
    on_order_item_shipped(
        _order_event(
            "ord_ship_2",
            {
                Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
                Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
            },
            {
                Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
                Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
            },
        )
    )

    # missing user/email -> 3354-3355
    claim_ref = Mock()
    wh_col = Mock()
    wh_col.document.return_value = claim_ref
    db = Mock()
    db.collection.side_effect = lambda name: {Collections.WEBHOOK_EVENTS: wh_col, Collections.USERS: Mock()}[name]
    mock_get_db.return_value = db
    on_order_item_shipped(
        _order_event(
            "ord_ship_3",
            {
                Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
                Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
            },
            {
                Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
                Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.SHIPPED}],
            },
        )
    )


@patch("services.email_task.enqueue_email_task")
@patch("handlers.orders.send_push_notification")
@patch("handlers.orders.get_order_item_shipped_email", return_value="<p>shipped</p>")
@patch("handlers.orders.get_db")
def test_on_order_item_shipped_pickup_variants_and_exception_branch(
    mock_get_db,
    _mock_tpl,
    mock_push,
    mock_enqueue,
):
    from handlers.orders import on_order_item_shipped

    claim_ref = Mock()
    wh_col = Mock()
    wh_col.document.return_value = claim_ref

    user_doc = _snap({Fields.PREFERRED_LANGUAGE: "en"}, exists=True)
    users_col = Mock()
    users_col.document.return_value.get.return_value = user_doc

    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.WEBHOOK_EVENTS: wh_col,
        Collections.USERS: users_col,
    }[name]
    mock_get_db.return_value = db

    # pickup single -> line 3391-3392 + subject line 3423
    evt_pickup_single = _order_event(
        "ord_ship_4",
        {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.PENDING}],
        },
        {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.DELIVERY_SPEED: DeliveryTypeValues.PICKUP,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.ITEMS: [
                {
                    Fields.CART_ITEM_ID: "ci_1",
                    Fields.STATUS: DeliveryStatusValues.SHIPPED,
                    Fields.NAME: "Widget",
                }
            ],
        },
    )
    on_order_item_shipped(evt_pickup_single)
    assert mock_push.call_args.args[2].startswith("Your item")
    assert "Ready for Pickup" in mock_enqueue.call_args.kwargs["subject"]

    # pickup multiple -> line 3394
    evt_pickup_multi = _order_event(
        "ord_ship_5",
        {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.ITEMS: [
                {Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.PENDING},
                {Fields.CART_ITEM_ID: "ci_2", Fields.STATUS: DeliveryStatusValues.PENDING},
            ],
        },
        {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.DELIVERY_SPEED: DeliveryTypeValues.PICKUP,
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.ITEMS: [
                {Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.SHIPPED},
                {Fields.CART_ITEM_ID: "ci_2", Fields.STATUS: DeliveryStatusValues.SHIPPED},
            ],
        },
    )
    on_order_item_shipped(evt_pickup_multi)
    assert "ready for pickup" in mock_push.call_args.args[2].lower()

    # shipped multiple + unexpected delivery speed warning -> lines 3385 + 3399
    evt_ship_multi = _order_event(
        "ord_ship_6",
        {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.ITEMS: [
                {Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.PENDING},
                {Fields.CART_ITEM_ID: "ci_2", Fields.STATUS: DeliveryStatusValues.PENDING},
            ],
        },
        {
            Fields.ORDER_STATUS: OrderStatusValues.PROCESSING,
            Fields.DELIVERY_SPEED: "teleport",
            Fields.USER_ID: "buyer_1",
            Fields.CUSTOMER_EMAIL: "buyer@example.com",
            Fields.ITEMS: [
                {Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.SHIPPED},
                {Fields.CART_ITEM_ID: "ci_2", Fields.STATUS: DeliveryStatusValues.SHIPPED},
            ],
        },
    )
    on_order_item_shipped(evt_ship_multi)
    assert "items from your order have been shipped" in mock_push.call_args.args[2]

    # outer exception branch lines 3435-3436
    with patch("handlers.orders.get_order_item_shipped_email", side_effect=RuntimeError("render fail")):
        on_order_item_shipped(evt_ship_multi)


@patch("handlers.orders.get_db")
def test_on_order_item_delivered_guard_and_value_error_paths(mock_get_db):
    from handlers.orders import on_order_item_delivered

    # before/after missing -> line 3448
    on_order_item_delivered(_order_event("ord_del_1", {}, {Fields.ITEMS: []}))

    # _item_key ValueError -> line 3458
    with pytest.raises(ValueError):
        on_order_item_delivered(
            _order_event(
                "ord_del_2",
                {Fields.ITEMS: [{Fields.STATUS: DeliveryStatusValues.PENDING}]},
                {Fields.ITEMS: [{Fields.STATUS: DeliveryStatusValues.DELIVERED}]},
            )
        )

    # no delivered transitions -> line 3473
    on_order_item_delivered(
        _order_event(
            "ord_del_3",
            {Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.DELIVERED}]},
            {Fields.ITEMS: [{Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.DELIVERED}]},
        )
    )


@patch("services.email_task.enqueue_email_task")
@patch("handlers.orders.send_push_notification")
@patch("handlers.orders.get_order_item_delivered_email", return_value="<p>delivered</p>")
@patch("handlers.orders.get_db")
def test_on_order_item_delivered_multi_body_and_exception_branch(
    mock_get_db,
    _mock_tpl,
    mock_push,
    _mock_enqueue,
):
    from handlers.orders import on_order_item_delivered

    claim_ref = Mock()
    wh_col = Mock()
    wh_col.document.return_value = claim_ref

    user_doc = _snap({Fields.PREFERRED_LANGUAGE: "en", Fields.EMAIL: "buyer@example.com"}, exists=True)
    users_col = Mock()
    users_col.document.return_value.get.return_value = user_doc

    db = Mock()
    db.collection.side_effect = lambda name: {
        Collections.WEBHOOK_EVENTS: wh_col,
        Collections.USERS: users_col,
    }[name]
    mock_get_db.return_value = db

    evt = _order_event(
        "ord_del_4",
        {
            Fields.ITEMS: [
                {Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.SHIPPED},
                {Fields.CART_ITEM_ID: "ci_2", Fields.STATUS: DeliveryStatusValues.SHIPPED},
            ]
        },
        {
            Fields.USER_ID: "buyer_1",
            Fields.ITEMS: [
                {Fields.CART_ITEM_ID: "ci_1", Fields.STATUS: DeliveryStatusValues.DELIVERED},
                {Fields.CART_ITEM_ID: "ci_2", Fields.STATUS: DeliveryStatusValues.DELIVERED},
            ],
        },
    )
    on_order_item_delivered(evt)
    assert "items from your order have been delivered" in mock_push.call_args.args[2]

    with patch("handlers.orders.get_order_item_delivered_email", side_effect=RuntimeError("render fail")):
        on_order_item_delivered(evt)
