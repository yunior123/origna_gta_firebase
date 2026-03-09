from __future__ import annotations

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import Mock, patch

import pyotp
import pytest
import stripe
from firebase_functions import https_fn

from schema_constants import (
    ApiKeys,
    Collections,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
    PayoutStatusValues,
    ProductLifecycleStatusValues,
    SecurityAlertTypes,
    SeverityLevels,
    UserRoleValues,
)
from utils.crypto_utils import encrypt_mfa_secret


def _req(*, uid: str = "user_1", data: dict | None = None, auth: bool = True):
    req = Mock()
    req.auth = Mock(uid=uid) if auth else None
    req.data = data or {}
    return req


def _snap(data: dict | None = None, *, exists: bool = True, doc_id: str = "doc_1", reference: Mock | None = None):
    s = Mock()
    s.exists = exists
    s.id = doc_id
    s.reference = reference or Mock()
    s.to_dict.return_value = data or {}
    return s


def _query(stream_results: list[list]):
    q = Mock()
    q.where.return_value = q
    q.limit.return_value = q
    q.order_by.return_value = q
    q.start_after.return_value = q
    q.stream.side_effect = stream_results
    return q


def _recent_admin() -> dict:
    return {
        Fields.ROLES: [UserRoleValues.ADMIN],
        Fields.MFA_ENABLED: True,
        Fields.LAST_MFA_VERIFY: datetime.now(UTC),
    }


@patch("handlers.admin.get_db")
@patch("handlers.admin.RateLimiter")
def test_suspend_seller_guard_paths_self_and_target_admin(mock_rl_cls, mock_get_db):
    from handlers.admin import suspend_seller

    mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
    db = Mock()
    mock_get_db.return_value = db

    admin_ref = Mock()
    admin_ref.get.return_value = _snap(_recent_admin(), exists=True)
    seller_ref = Mock()
    seller_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)

    users_coll = Mock()
    users_coll.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else seller_ref
    db.collection.side_effect = lambda name: {Collections.USERS: users_coll}[name]

    with pytest.raises(https_fn.HttpsError) as self_exc:
        suspend_seller(_req(uid="admin_1", data={Fields.SELLER_ID: "admin_1"}))
    assert self_exc.value.code == "permission-denied"

    with pytest.raises(https_fn.HttpsError) as target_admin:
        suspend_seller(_req(uid="admin_1", data={Fields.SELLER_ID: "other_admin"}))
    assert target_admin.value.code == "permission-denied"


@patch("handlers.admin.get_server_timestamp", return_value="ts")
@patch("handlers.admin.get_firestore")
@patch("handlers.admin.get_db")
@patch("handlers.admin.RateLimiter")
def test_suspend_seller_batch_rollover_skip_and_stripe_error_alert(
    mock_rl_cls,
    mock_get_db,
    mock_get_firestore,
    _mock_ts,
):
    from handlers.admin import suspend_seller

    mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
    mock_get_firestore.return_value = SimpleNamespace(transactional=lambda fn: lambda tx: fn(tx))

    db = Mock()
    mock_get_db.return_value = db
    db.transaction.return_value = Mock(get_all=Mock(return_value=[]))

    admin_ref = Mock()
    admin_ref.get.return_value = _snap(_recent_admin(), exists=True)
    seller_ref = Mock()
    seller_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, exists=True)

    product_docs = [_snap({}, doc_id=f"p{i}", reference=Mock()) for i in range(501)]
    products_q = _query([product_docs])
    products_coll = Mock()
    products_coll.where.return_value = products_q
    products_coll.document.return_value = Mock()

    multi_seller_order = _snap(
        {
            Fields.SELLER_IDS: ["seller_1", "other_seller"],
            Fields.ITEMS: [{Fields.SELLER_ID: "seller_1", Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
        },
        doc_id="o_multi",
        reference=Mock(),
    )
    single_orders = [
        _snap(
            {
                Fields.SELLER_IDS: ["seller_1"],
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1", Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
            },
            doc_id=f"o_{i}",
            reference=Mock(),
        )
        for i in range(501)
    ]
    cancel_q = _query([[multi_seller_order, *single_orders]])

    no_pi_doc = _snap({Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED}, doc_id="o_no_pi", reference=Mock())
    pi_fail_doc = _snap(
        {
            Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_fail",
        },
        doc_id="o_pi_fail",
        reference=Mock(),
    )
    pay_q = _query([[no_pi_doc, pi_fail_doc]])

    orders_coll = Mock()
    orders_coll.where.side_effect = [cancel_q, pay_q]

    users_coll = Mock()
    users_coll.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else seller_ref
    alerts_coll = Mock()

    batches: list[Mock] = []

    def _new_batch():
        b = Mock()
        batches.append(b)
        return b

    db.batch.side_effect = _new_batch
    db.collection.side_effect = lambda name: {
        Collections.USERS: users_coll,
        Collections.PRODUCTS: products_coll,
        Collections.ORDERS: orders_coll,
        Collections.SECURITY_ALERTS: alerts_coll,
    }[name]

    with patch("services.algolia_service.batch_partial_update_products", side_effect=RuntimeError("algolia down")):
        with patch("handlers.admin.stripe.PaymentIntent.cancel", side_effect=RuntimeError("stripe down")):
            out = suspend_seller(_req(uid="admin_1", data={Fields.SELLER_ID: "seller_1"}))
    assert out["success"] is True
    assert any(b.commit.called for b in batches)
    assert alerts_coll.add.called


@patch("handlers.admin.get_db")
@patch("handlers.admin.RateLimiter")
def test_unsuspend_seller_not_suspended_guard(mock_rl_cls, mock_get_db):
    from handlers.admin import unsuspend_seller

    mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
    db = Mock()
    mock_get_db.return_value = db

    admin_ref = Mock()
    admin_ref.get.return_value = _snap(_recent_admin(), exists=True)
    seller_ref = Mock()
    seller_ref.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True)
    users_coll = Mock()
    users_coll.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else seller_ref
    db.collection.side_effect = lambda name: {Collections.USERS: users_coll}[name]

    with pytest.raises(https_fn.HttpsError) as exc:
        unsuspend_seller(_req(uid="admin_1", data={Fields.SELLER_ID: "seller_1"}))
    assert exc.value.code == "failed-precondition"


@patch("handlers.admin.get_db")
@patch("handlers.admin.RateLimiter")
def test_unsuspend_seller_max_iterations_breaks(mock_rl_cls, mock_get_db):
    from handlers.admin import unsuspend_seller

    mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
    db = Mock()
    mock_get_db.return_value = db

    admin_ref = Mock()
    admin_ref.get.return_value = _snap(_recent_admin(), exists=True)
    seller_ref = Mock()
    seller_ref.get.return_value = _snap({Fields.SUSPENDED: True}, exists=True)

    stuck_doc = _snap(
        {
            Fields.STOCK_QUANTITY: 0,
            Fields.PRICE: 5,
            Fields.DELETED_AT: None,
        },
        exists=True,
        doc_id="stuck",
    )
    products_q = Mock()
    products_q.where.return_value = products_q
    products_q.limit.return_value = products_q
    products_q.stream.return_value = [stuck_doc]
    products_coll = Mock()
    products_coll.where.return_value = products_q

    users_coll = Mock()
    users_coll.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else seller_ref
    db.collection.side_effect = lambda name: {
        Collections.USERS: users_coll,
        Collections.PRODUCTS: products_coll,
        Collections.SECURITY_ALERTS: Mock(),
    }[name]
    db.batch.return_value = Mock()

    out = unsuspend_seller(_req(uid="admin_1", data={Fields.SELLER_ID: "seller_1"}))
    assert out["success"] is True


@patch("handlers.admin.get_db")
@patch("handlers.admin.RateLimiter")
def test_unsuspend_seller_algolia_error_branch(mock_rl_cls, mock_get_db):
    from handlers.admin import unsuspend_seller

    mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
    db = Mock()
    mock_get_db.return_value = db

    admin_ref = Mock()
    admin_ref.get.return_value = _snap(_recent_admin(), exists=True)
    seller_ref = Mock()
    seller_ref.get.return_value = _snap({Fields.SUSPENDED: True}, exists=True)

    p_doc = _snap(
        {
            Fields.STOCK_QUANTITY: 10,
            Fields.PRICE: 10,
            Fields.DELETED_AT: None,
        },
        exists=True,
        doc_id="p_ok",
    )
    products_q = _query([[p_doc], []])
    products_coll = Mock()
    products_coll.where.return_value = products_q

    users_coll = Mock()
    users_coll.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else seller_ref
    db.collection.side_effect = lambda name: {
        Collections.USERS: users_coll,
        Collections.PRODUCTS: products_coll,
        Collections.SECURITY_ALERTS: Mock(),
    }[name]
    db.batch.return_value = Mock()

    with patch("services.algolia_service.batch_partial_update_products", side_effect=RuntimeError("algolia err")):
        out = unsuspend_seller(_req(uid="admin_1", data={Fields.SELLER_ID: "seller_1"}))
    assert out["success"] is True


@patch("handlers.admin.get_firestore")
@patch("handlers.admin.get_db")
@patch("handlers.admin.RateLimiter")
def test_admin_update_product_stock_race_product_deleted_in_txn(mock_rl_cls, mock_get_db, mock_get_firestore):
    from handlers.admin import admin_update_product_stock

    mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
    mock_get_firestore.return_value = SimpleNamespace(transactional=lambda fn: lambda tx, ref: fn(tx, ref))
    db = Mock()
    mock_get_db.return_value = db
    db.transaction.return_value = Mock()

    admin_ref = Mock()
    admin_ref.get.return_value = _snap(_recent_admin(), exists=True)
    product_ref = Mock()
    product_ref.get.side_effect = [_snap({Fields.STOCK_QUANTITY: 1}, exists=True), _snap(exists=False)]

    users_coll = Mock()
    users_coll.document.return_value = admin_ref
    products_coll = Mock()
    products_coll.document.return_value = product_ref
    db.collection.side_effect = lambda name: {
        Collections.USERS: users_coll,
        Collections.PRODUCTS: products_coll,
    }[name]

    with pytest.raises(https_fn.HttpsError) as exc:
        admin_update_product_stock(
            _req(uid="admin_1", data={Fields.PRODUCT_ID: "p1", Fields.STOCK_QUANTITY: 10, ApiKeys.REASON: "adj"})
        )
    assert exc.value.code == "not-found"


def _setup_user_security_db(user_exists=True, user_roles=None, security_data=None):
    db = Mock()
    user_ref = Mock()
    user_ref.get.return_value = _snap({Fields.ROLES: user_roles or []}, exists=user_exists)
    sec_ref = Mock()
    sec_ref.get.return_value = _snap(security_data or {}, exists=security_data is not None)
    users_coll = Mock()
    users_coll.document.return_value = user_ref
    sec_coll = Mock()
    sec_coll.document.return_value = sec_ref
    db.collection.side_effect = lambda name: {
        Collections.USERS: users_coll,
        Collections.USER_SECURITY: sec_coll,
        Collections.ADMIN_LOGS: Mock(),
        Collections.SECURITY_ALERTS: Mock(),
    }[name]
    return db, user_ref, sec_ref


def test_admin_mfa_enroll_guard_matrix():
    from handlers.admin import admin_mfa_enroll

    with pytest.raises(https_fn.HttpsError) as unauth:
        admin_mfa_enroll(_req(auth=False))
    assert unauth.value.code == "unauthenticated"


@patch("handlers.admin.get_db")
@patch("services.rate_limiter.RateLimiter")
def test_admin_mfa_enroll_rate_limit_not_found_not_admin(mock_rl_cls, mock_get_db):
    from handlers.admin import admin_mfa_enroll

    # rate-limited
    mock_rl_cls.return_value.check_rate_limit.return_value = (False, "too many")
    mock_get_db.return_value = Mock()
    with pytest.raises(https_fn.HttpsError) as limited:
        admin_mfa_enroll(_req(uid="u1"))
    assert limited.value.code == "resource-exhausted"

    # user not found
    mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
    db_nf = Mock()
    user_ref_nf = Mock()
    user_ref_nf.get.return_value = _snap({}, exists=False)
    users_coll_nf = Mock()
    users_coll_nf.document.return_value = user_ref_nf
    db_nf.collection.side_effect = lambda name: {Collections.USERS: users_coll_nf}[name]
    mock_get_db.return_value = db_nf
    with pytest.raises(https_fn.HttpsError) as not_found:
        admin_mfa_enroll(_req(uid="u1"))
    assert not_found.value.code == "not-found"

    # non-admin
    db_na = Mock()
    user_ref_na = Mock()
    user_ref_na.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER]}, exists=True)
    users_coll_na = Mock()
    users_coll_na.document.return_value = user_ref_na
    db_na.collection.side_effect = lambda name: {Collections.USERS: users_coll_na}[name]
    mock_get_db.return_value = db_na
    with pytest.raises(https_fn.HttpsError) as perm:
        admin_mfa_enroll(_req(uid="u1"))
    assert perm.value.code == "permission-denied"


def test_admin_mfa_verify_guard_matrix():
    from handlers.admin import admin_mfa_verify

    with pytest.raises(https_fn.HttpsError) as unauth:
        admin_mfa_verify(_req(auth=False))
    assert unauth.value.code == "unauthenticated"

    with pytest.raises(https_fn.HttpsError) as missing_code:
        admin_mfa_verify(_req(uid="u1", data={}))
    assert missing_code.value.code == "invalid-argument"


@patch("handlers.admin.get_db")
def test_admin_mfa_verify_not_found_not_enrolled_lockout_tz_and_reset_attempts(mock_get_db):
    from handlers.admin import admin_mfa_verify

    # user not found
    db_nf, _, _ = _setup_user_security_db(user_exists=False)
    mock_get_db.return_value = db_nf
    with pytest.raises(https_fn.HttpsError) as nf:
        admin_mfa_verify(_req(uid="u1", data={ApiKeys.CODE: "111111"}))
    assert nf.value.code == "not-found"

    # no secret
    db_ns, _, _ = _setup_user_security_db(user_exists=True, user_roles=[UserRoleValues.ADMIN], security_data={})
    mock_get_db.return_value = db_ns
    with pytest.raises(https_fn.HttpsError) as no_secret:
        admin_mfa_verify(_req(uid="u1", data={ApiKeys.CODE: "111111"}))
    assert no_secret.value.code == "failed-precondition"

    # naive lockout timestamp + success path with attempts reset
    secret = pyotp.random_base32()
    enc = encrypt_mfa_secret(secret, associated_data="u1")
    past_naive = datetime.utcnow() - timedelta(minutes=1)
    security_data = {
        Fields.MFA_SECRET: enc,
        Fields.MFA_LOCKOUT_UNTIL: past_naive,
        Fields.MFA_FAILED_ATTEMPTS: 2,
    }
    db_ok, user_ref, sec_ref = _setup_user_security_db(
        user_exists=True,
        user_roles=[UserRoleValues.ADMIN],
        security_data=security_data,
    )
    mock_get_db.return_value = db_ok
    with patch("handlers.admin.pyotp.TOTP.verify", return_value=True):
        out = admin_mfa_verify(_req(uid="u1", data={ApiKeys.CODE: "123456"}))
    assert out["success"] is True
    assert sec_ref.update.called
    assert user_ref.update.called


def test_admin_mfa_disable_guard_matrix():
    from handlers.admin import admin_mfa_disable

    with pytest.raises(https_fn.HttpsError) as unauth:
        admin_mfa_disable(_req(auth=False))
    assert unauth.value.code == "unauthenticated"

    with pytest.raises(https_fn.HttpsError) as missing_code:
        admin_mfa_disable(_req(uid="u1", data={}))
    assert missing_code.value.code == "invalid-argument"


@patch("handlers.admin.RateLimiter")
@patch("handlers.admin.get_db")
def test_admin_mfa_disable_rate_limit_not_found_not_admin_not_enabled(mock_get_db, mock_rl):
    from handlers.admin import admin_mfa_disable

    # rate-limited
    mock_rl.return_value.check_rate_limit.return_value = (False, "slow")
    mock_get_db.return_value = Mock()
    with pytest.raises(https_fn.HttpsError) as limited:
        admin_mfa_disable(_req(uid="u1", data={ApiKeys.CODE: "123456"}))
    assert limited.value.code == "resource-exhausted"

    # user not found
    mock_rl.return_value.check_rate_limit.return_value = (True, "ok")
    db_nf = Mock()
    user_ref_nf = Mock()
    user_ref_nf.get.return_value = _snap({}, exists=False)
    users_coll_nf = Mock()
    users_coll_nf.document.return_value = user_ref_nf
    db_nf.collection.side_effect = lambda name: {Collections.USERS: users_coll_nf}[name]
    mock_get_db.return_value = db_nf
    with pytest.raises(https_fn.HttpsError) as nf:
        admin_mfa_disable(_req(uid="u1", data={ApiKeys.CODE: "123456"}))
    assert nf.value.code == "not-found"

    # non-admin
    db_na = Mock()
    user_ref_na = Mock()
    user_ref_na.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER]}, exists=True)
    sec_ref_na = Mock()
    sec_ref_na.get.return_value = _snap({Fields.MFA_SECRET: "x"}, exists=True)
    users_coll_na = Mock()
    users_coll_na.document.return_value = user_ref_na
    sec_coll_na = Mock()
    sec_coll_na.document.return_value = sec_ref_na
    db_na.collection.side_effect = lambda name: {Collections.USERS: users_coll_na, Collections.USER_SECURITY: sec_coll_na}[name]
    mock_get_db.return_value = db_na
    with pytest.raises(https_fn.HttpsError) as perm:
        admin_mfa_disable(_req(uid="u1", data={ApiKeys.CODE: "123456"}))
    assert perm.value.code == "permission-denied"

    # MFA not enabled
    db_ne = Mock()
    user_ref_ne = Mock()
    user_ref_ne.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
    sec_ref_ne = Mock()
    sec_ref_ne.get.return_value = _snap({}, exists=True)
    users_coll_ne = Mock()
    users_coll_ne.document.return_value = user_ref_ne
    sec_coll_ne = Mock()
    sec_coll_ne.document.return_value = sec_ref_ne
    db_ne.collection.side_effect = lambda name: {Collections.USERS: users_coll_ne, Collections.USER_SECURITY: sec_coll_ne}[name]
    mock_get_db.return_value = db_ne
    with pytest.raises(https_fn.HttpsError) as not_enabled:
        admin_mfa_disable(_req(uid="u1", data={ApiKeys.CODE: "123456"}))
    assert not_enabled.value.code == "failed-precondition"


def test_admin_mfa_verify_backup_guard_basic():
    from handlers.admin import admin_mfa_verify_backup

    with pytest.raises(https_fn.HttpsError) as unauth:
        admin_mfa_verify_backup(_req(auth=False))
    assert unauth.value.code == "unauthenticated"

    with pytest.raises(https_fn.HttpsError) as missing_code:
        admin_mfa_verify_backup(_req(uid="u1", data={}))
    assert missing_code.value.code == "invalid-argument"


@patch("handlers.admin.RateLimiter")
@patch("handlers.admin.get_db")
def test_admin_mfa_verify_backup_guard_remaining(mock_get_db, mock_rl):
    from handlers.admin import admin_mfa_verify_backup

    # rate-limited
    mock_rl.return_value.check_rate_limit.return_value = (False, "slow")
    mock_get_db.return_value = Mock()
    with pytest.raises(https_fn.HttpsError) as limited:
        admin_mfa_verify_backup(_req(uid="u1", data={ApiKeys.CODE: "ABCD1234"}))
    assert limited.value.code == "resource-exhausted"

    mock_rl.return_value.check_rate_limit.return_value = (True, "ok")

    # user not found
    db_nf = Mock()
    uref_nf = Mock()
    uref_nf.get.return_value = _snap({}, exists=False)
    users_nf = Mock()
    users_nf.document.return_value = uref_nf
    db_nf.collection.side_effect = lambda name: {Collections.USERS: users_nf}[name]
    mock_get_db.return_value = db_nf
    with pytest.raises(https_fn.HttpsError) as nf:
        admin_mfa_verify_backup(_req(uid="u1", data={ApiKeys.CODE: "ABCD1234"}))
    assert nf.value.code == "not-found"

    # mfa not enabled
    db_mfa = Mock()
    uref_mfa = Mock()
    uref_mfa.get.return_value = _snap({Fields.MFA_ENABLED: False}, exists=True)
    users_mfa = Mock()
    users_mfa.document.return_value = uref_mfa
    db_mfa.collection.side_effect = lambda name: {Collections.USERS: users_mfa}[name]
    mock_get_db.return_value = db_mfa
    with pytest.raises(https_fn.HttpsError) as mfa:
        admin_mfa_verify_backup(_req(uid="u1", data={ApiKeys.CODE: "ABCD1234"}))
    assert mfa.value.code == "failed-precondition"

    # no backup codes
    db_nb = Mock()
    uref_nb = Mock()
    uref_nb.get.return_value = _snap({Fields.MFA_ENABLED: True}, exists=True)
    sref_nb = Mock()
    sref_nb.get.return_value = _snap({Fields.MFA_BACKUP_CODES: []}, exists=True)
    users_nb = Mock()
    users_nb.document.return_value = uref_nb
    sec_nb = Mock()
    sec_nb.document.return_value = sref_nb
    db_nb.collection.side_effect = lambda name: {Collections.USERS: users_nb, Collections.USER_SECURITY: sec_nb}[name]
    mock_get_db.return_value = db_nb
    with pytest.raises(https_fn.HttpsError) as no_codes:
        admin_mfa_verify_backup(_req(uid="u1", data={ApiKeys.CODE: "ABCD1234"}))
    assert no_codes.value.code == "failed-precondition"


def _build_delete_account_db(user_id: str = "user_1"):
    db = Mock()
    user_ref = Mock()
    sec_ref = Mock()
    sp_ref = Mock()
    sub_ref = Mock()

    users_coll = Mock()
    users_coll.document.return_value = user_ref

    # user subcollections empty
    empty_sub_q = Mock()
    empty_sub_q.limit.return_value = empty_sub_q
    empty_sub_q.stream.return_value = []
    user_ref.collection.return_value = empty_sub_q

    # seller_profiles
    sp_doc = _snap({Fields.STRIPE_ACCOUNT_ID: "acct_123"}, exists=True)
    sp_ref.get.side_effect = [sp_doc, _snap({Fields.STRIPE_ACCOUNT_ID: "acct_123"}, exists=True)]
    sp_coll = Mock()
    sp_coll.document.return_value = sp_ref

    sec_ref.get.return_value = _snap({}, exists=False)
    sec_coll = Mock()
    sec_coll.document.return_value = sec_ref

    sub_coll = Mock()
    sub_coll.document.return_value = sub_ref

    # orders: pending check [], active sales check [], anonymize [doc], []
    order_doc = _snap({}, doc_id="ord_1", reference=Mock())
    orders_q = _query([[], [], [order_doc], []])
    orders_coll = Mock()
    orders_coll.where.return_value = orders_q

    # products anonymize [doc], []
    product_doc = _snap({}, doc_id="prod_1", reference=Mock())
    products_q = _query([[product_doc], []])
    products_coll = Mock()
    products_coll.where.return_value = products_q

    # payouts pending check [], anonymize []
    payouts_q = _query([[], []])
    payouts_coll = Mock()
    payouts_coll.where.return_value = payouts_q

    # all other where-based collections return [] (separate mocks to avoid side-effect exhaustion)
    def _empty_where_collection():
        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.stream.return_value = []
        c = Mock()
        c.where.return_value = q
        return c

    pq_coll = _empty_where_collection()
    ratings_coll = _empty_where_collection()
    notifs_coll = _empty_where_collection()
    chats_coll = _empty_where_collection()

    alerts_coll = Mock()

    db.collection.side_effect = lambda name: {
        Collections.USERS: users_coll,
        Collections.ORDERS: orders_coll,
        Collections.SELLER_PROFILES: sp_coll,
        Collections.USER_SECURITY: sec_coll,
        Collections.PRODUCTS: products_coll,
        Collections.PAYOUTS: payouts_coll,
        Collections.PRODUCT_QUESTIONS: pq_coll,
        Collections.PRODUCT_RATINGS: ratings_coll,
        Collections.STOCK_NOTIFICATIONS: notifs_coll,
        Collections.CHATS: chats_coll,
        Collections.SUBSCRIPTIONS: sub_coll,
        Collections.SECURITY_ALERTS: alerts_coll,
    }[name]
    db.batch.side_effect = lambda: Mock(update=Mock(), delete=Mock(), commit=Mock())
    return db, alerts_coll


def test_delete_account_unauthenticated_guard():
    from handlers.admin import delete_account

    with pytest.raises(https_fn.HttpsError) as exc:
        delete_account(_req(auth=False))
    assert exc.value.code == "unauthenticated"


@patch("services.rate_limiter.RateLimiter")
@patch("handlers.admin.get_db")
def test_delete_account_rate_limit_and_preconditions(mock_get_db, mock_rl):
    from handlers.admin import delete_account

    # rate-limited
    mock_rl.return_value.check_rate_limit.return_value = (False, "slow")
    mock_get_db.return_value = Mock()
    with pytest.raises(https_fn.HttpsError) as limited:
        delete_account(_req(uid="u1"))
    assert limited.value.code == "resource-exhausted"

    mock_rl.return_value.check_rate_limit.return_value = (True, "ok")

    # pending orders
    db1 = Mock()
    orders_q = _query([[ _snap({}, exists=True) ]])
    orders_coll = Mock()
    orders_coll.where.return_value = orders_q
    db1.collection.side_effect = lambda name: {Collections.ORDERS: orders_coll}[name]
    mock_get_db.return_value = db1
    with pytest.raises(https_fn.HttpsError) as pending_orders:
        delete_account(_req(uid="u1"))
    assert pending_orders.value.code == "failed-precondition"

    # active sales
    db2 = Mock()
    orders_q2 = _query([[], [_snap({}, exists=True)]])
    orders_coll2 = Mock()
    orders_coll2.where.return_value = orders_q2
    db2.collection.side_effect = lambda name: {Collections.ORDERS: orders_coll2}[name]
    mock_get_db.return_value = db2
    with pytest.raises(https_fn.HttpsError) as active_sales:
        delete_account(_req(uid="u1"))
    assert active_sales.value.code == "failed-precondition"

    # pending payouts
    db3 = Mock()
    orders_q3 = _query([[], []])
    orders_coll3 = Mock()
    orders_coll3.where.return_value = orders_q3
    payouts_q3 = _query([[_snap({}, exists=True)]])
    payouts_coll3 = Mock()
    payouts_coll3.where.return_value = payouts_q3
    sp_coll = Mock()
    sp_coll.document.return_value.get.return_value = _snap({}, exists=False)
    db3.collection.side_effect = lambda name: {
        Collections.ORDERS: orders_coll3,
        Collections.PAYOUTS: payouts_coll3,
        Collections.SELLER_PROFILES: sp_coll,
    }[name]
    mock_get_db.return_value = db3
    with pytest.raises(https_fn.HttpsError) as pending_payout:
        delete_account(_req(uid="u1"))
    assert pending_payout.value.code == "failed-precondition"


@patch("handlers.admin.auth.delete_user")
@patch("firebase_admin.storage.bucket", side_effect=RuntimeError("storage down"))
@patch("handlers.admin.stripe.Account.delete", side_effect=RuntimeError("stripe down"))
@patch("handlers.admin.get_delete_field", return_value="DELETE")
@patch("handlers.admin.get_server_timestamp", return_value="ts")
@patch("handlers.admin.get_db")
@patch("services.rate_limiter.RateLimiter")
def test_delete_account_stripe_storage_algolia_exceptions_are_logged(
    mock_rl,
    mock_get_db,
    _mock_ts,
    _mock_delete,
    _mock_stripe_delete,
    _mock_bucket,
    _mock_auth_delete,
):
    from handlers.admin import delete_account

    mock_rl.return_value.check_rate_limit.return_value = (True, "ok")
    db, alerts_coll = _build_delete_account_db("u1")
    mock_get_db.return_value = db

    with patch("services.algolia_service.delete_products_from_algolia", side_effect=RuntimeError("algolia down")):
        out = delete_account(_req(uid="u1"))
    assert out["success"] is True
    assert alerts_coll.add.called


def test_export_my_data_unauthenticated_guard():
    from handlers.admin import export_my_data

    with pytest.raises(https_fn.HttpsError) as exc:
        export_my_data(_req(auth=False))
    assert exc.value.code == "unauthenticated"


@patch("services.rate_limiter.RateLimiter")
@patch("handlers.admin.get_db")
def test_export_my_data_rate_limit_not_found_and_pagination(mock_get_db, mock_rl):
    from handlers.admin import export_my_data

    # rate-limited
    mock_rl.return_value.check_rate_limit.return_value = (False, "slow")
    mock_get_db.return_value = Mock()
    with pytest.raises(https_fn.HttpsError) as limited:
        export_my_data(_req(uid="u1"))
    assert limited.value.code == "resource-exhausted"

    mock_rl.return_value.check_rate_limit.return_value = (True, "ok")

    # user not found
    db_nf = Mock()
    users_coll_nf = Mock()
    users_coll_nf.document.return_value.get.return_value = _snap({}, exists=False)
    db_nf.collection.side_effect = lambda name: {Collections.USERS: users_coll_nf}[name]
    mock_get_db.return_value = db_nf
    with pytest.raises(https_fn.HttpsError) as not_found:
        export_my_data(_req(uid="u1"))
    assert not_found.value.code == "not-found"

    # pagination: first 500 docs then 1 doc (hits start_after and last_order_doc assignment)
    db_ok = Mock()
    users_coll = Mock()
    users_coll.document.return_value.get.return_value = _snap({Fields.EMAIL: "u1@example.com"}, exists=True)

    first_batch = [_snap({Fields.CREATED_AT: datetime.now(UTC)}, doc_id=f"o_{i}") for i in range(500)]
    second_batch = [_snap({Fields.CREATED_AT: datetime.now(UTC)}, doc_id="o_last")]

    orders_query = Mock()
    orders_query.where.return_value = orders_query
    orders_query.order_by.return_value = orders_query
    orders_query.limit.return_value = orders_query
    orders_query.start_after.return_value = orders_query
    orders_query.stream.side_effect = [first_batch, second_batch]
    orders_coll = Mock()
    orders_coll.where.return_value = orders_query

    fav_ref = Mock()
    fav_ref.collection.return_value.stream.return_value = []
    users_coll.document.return_value = fav_ref
    fav_ref.get.return_value = _snap({Fields.EMAIL: "u1@example.com"}, exists=True)

    db_ok.collection.side_effect = lambda name: {
        Collections.USERS: users_coll,
        Collections.ORDERS: orders_coll,
    }[name]
    mock_get_db.return_value = db_ok
    out = export_my_data(_req(uid="u1"))
    assert out["success"] is True
    assert len(out[ApiKeys.ORDERS]) == 501


def test_unsubscribe_email_unauthenticated_guard():
    from handlers.admin import unsubscribe_email

    with pytest.raises(https_fn.HttpsError) as exc:
        unsubscribe_email(_req(auth=False))
    assert exc.value.code == "unauthenticated"


@patch("services.rate_limiter.RateLimiter")
@patch("handlers.admin.get_db")
def test_unsubscribe_email_rate_limited_guard(mock_get_db, mock_rl):
    from handlers.admin import unsubscribe_email

    mock_rl.return_value.check_rate_limit.return_value = (False, "slow")
    mock_get_db.return_value = Mock()
    with pytest.raises(https_fn.HttpsError) as exc:
        unsubscribe_email(_req(uid="u1"))
    assert exc.value.code == "resource-exhausted"


def test_e2e_get_mail_logs_guard_paths():
    from config import Environment
    from handlers.admin import e2e_get_mail_logs

    with patch("config.CURRENT_ENV", Environment.PRODUCTION):
        with pytest.raises(https_fn.HttpsError) as prod:
            e2e_get_mail_logs(_req(uid="admin_1", data={"to": "a@example.com"}))
    assert prod.value.code == https_fn.FunctionsErrorCode.PERMISSION_DENIED

    with patch("config.CURRENT_ENV", Environment.DEV):
        with pytest.raises(https_fn.HttpsError) as unauth:
            e2e_get_mail_logs(_req(auth=False))
    assert unauth.value.code == https_fn.FunctionsErrorCode.UNAUTHENTICATED

    db = Mock()
    users_coll = Mock()
    users_coll.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER]}, exists=True)
    db.collection.side_effect = lambda name: {Collections.USERS: users_coll}[name]
    with patch("config.CURRENT_ENV", Environment.DEV):
        with patch("handlers.admin.get_db", return_value=db):
            with pytest.raises(https_fn.HttpsError) as perm:
                e2e_get_mail_logs(_req(uid="u1", data={"to": "x@example.com"}))
    assert perm.value.code == https_fn.FunctionsErrorCode.PERMISSION_DENIED


def test_e2e_seed_license_guard_paths():
    from config import Environment
    from handlers.admin import e2e_seed_license

    with patch("config.CURRENT_ENV", Environment.PRODUCTION):
        with pytest.raises(https_fn.HttpsError) as prod:
            e2e_seed_license(_req(uid="admin_1", data={"licenseKey": "L1"}))
    assert prod.value.code == https_fn.FunctionsErrorCode.PERMISSION_DENIED

    with patch("config.CURRENT_ENV", Environment.DEV):
        with pytest.raises(https_fn.HttpsError) as unauth:
            e2e_seed_license(_req(auth=False))
    assert unauth.value.code == https_fn.FunctionsErrorCode.UNAUTHENTICATED

    db = Mock()
    users_coll = Mock()
    users_coll.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER]}, exists=True)
    db.collection.side_effect = lambda name: {Collections.USERS: users_coll, Collections.LICENSES: Mock()}[name]
    with patch("config.CURRENT_ENV", Environment.DEV):
        with patch("handlers.admin.get_db", return_value=db):
            with pytest.raises(https_fn.HttpsError) as perm:
                e2e_seed_license(_req(uid="u1", data={"licenseKey": "L1"}))
    assert perm.value.code == https_fn.FunctionsErrorCode.PERMISSION_DENIED

    admin_db = Mock()
    users_admin = Mock()
    users_admin.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
    admin_db.collection.side_effect = lambda name: {Collections.USERS: users_admin, Collections.LICENSES: Mock()}[name]
    with patch("config.CURRENT_ENV", Environment.DEV):
        with patch("handlers.admin.get_db", return_value=admin_db):
            with pytest.raises(https_fn.HttpsError) as missing_key:
                e2e_seed_license(_req(uid="admin_1", data={"action": "create"}))
    assert missing_key.value.code == https_fn.FunctionsErrorCode.INVALID_ARGUMENT


def test_admin_get_reviews_unauthenticated_guard():
    from handlers.admin import admin_get_reviews

    with pytest.raises(https_fn.HttpsError) as exc:
        admin_get_reviews(_req(auth=False))
    assert exc.value.code == "unauthenticated"


def test_admin_delete_review_guard_paths():
    from handlers.admin import admin_delete_review

    with pytest.raises(https_fn.HttpsError) as unauth:
        admin_delete_review(_req(auth=False))
    assert unauth.value.code == "unauthenticated"

    with pytest.raises(https_fn.HttpsError) as missing:
        admin_delete_review(_req(uid="admin_1", data={}))
    assert missing.value.code == "invalid-argument"

    db = Mock()
    users_coll = Mock()
    users_coll.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER]}, exists=True)
    db.collection.side_effect = lambda name: {Collections.USERS: users_coll}[name]
    with patch("handlers.admin.get_db", return_value=db):
        with pytest.raises(https_fn.HttpsError) as perm:
            admin_delete_review(_req(uid="u1", data={Fields.REVIEW_ID: "r1"}))
    assert perm.value.code == "permission-denied"


@patch("handlers.admin.get_db")
@patch("handlers.admin.get_server_timestamp", return_value="ts")
def test_admin_delete_review_recalc_branches(mock_ts, mock_get_db):
    from handlers.admin import admin_delete_review

    db = Mock()
    mock_get_db.return_value = db

    admin_doc = _snap(_recent_admin(), exists=True)
    users_coll = Mock()
    users_coll.document.return_value.get.return_value = admin_doc

    review_ref = Mock()
    review_ref.get.return_value = _snap({Fields.PRODUCT_ID: "p1", Fields.RATING: 4}, exists=True)
    ratings_coll = Mock()
    ratings_coll.document.return_value = review_ref

    product_ref = Mock()
    products_coll = Mock()
    products_coll.document.return_value = product_ref

    logs_coll = Mock()

    db.collection.side_effect = lambda name: {
        Collections.USERS: users_coll,
        Collections.PRODUCT_RATINGS: ratings_coll,
        Collections.PRODUCTS: products_coll,
        Collections.ADMIN_LOGS: logs_coll,
    }[name]
    db.transaction.return_value = Mock()

    # product missing in transaction -> line 1905
    product_ref.get.side_effect = [_snap({}, exists=False), _snap({}, exists=True)]
    with patch("firebase_admin.firestore.transactional", side_effect=lambda fn: fn):
        out = admin_delete_review(_req(uid="admin_1", data={Fields.REVIEW_ID: "r1"}))
    assert out["success"] is True

    # old_count <= 1 reset to zero + algolia sync
    review_ref.get.return_value = _snap({Fields.PRODUCT_ID: "p2", Fields.RATING: 5}, exists=True)
    product_ref.get.side_effect = [
        _snap({Fields.RATING: 5.0, Fields.RATING_COUNT: 1}, exists=True),
        _snap({Fields.RATING: 0, Fields.RATING_COUNT: 0}, exists=True),
    ]
    with patch("firebase_admin.firestore.transactional", side_effect=lambda fn: fn):
        with patch("services.algolia_service.algolia_partial_update", create=True) as mock_alg:
            out2 = admin_delete_review(_req(uid="admin_1", data={Fields.REVIEW_ID: "r2"}))
    assert out2["success"] is True
    assert mock_alg.called


def test_admin_flag_review_guard_paths():
    from handlers.admin import admin_flag_review

    with pytest.raises(https_fn.HttpsError) as unauth:
        admin_flag_review(_req(auth=False))
    assert unauth.value.code == "unauthenticated"

    db = Mock()
    users_coll = Mock()
    users_coll.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER]}, exists=True)
    db.collection.side_effect = lambda name: {Collections.USERS: users_coll}[name]
    with patch("handlers.admin.get_db", return_value=db):
        with pytest.raises(https_fn.HttpsError) as perm:
            admin_flag_review(_req(uid="u1", data={Fields.REVIEW_ID: "r1", "flagged": True}))
    assert perm.value.code == "permission-denied"

    db2 = Mock()
    users2 = Mock()
    users2.document.return_value.get.return_value = _snap(_recent_admin(), exists=True)
    rev_ref = Mock()
    rev_ref.get.return_value = _snap({}, exists=False)
    ratings2 = Mock()
    ratings2.document.return_value = rev_ref
    db2.collection.side_effect = lambda name: {Collections.USERS: users2, Collections.PRODUCT_RATINGS: ratings2}[name]
    with patch("handlers.admin.get_db", return_value=db2):
        with pytest.raises(https_fn.HttpsError) as nf:
            admin_flag_review(_req(uid="admin_1", data={Fields.REVIEW_ID: "r1", "flagged": True}))
    assert nf.value.code == "not-found"


def test_admin_refund_order_basic_guard_paths():
    from handlers.admin import admin_refund_order

    with pytest.raises(https_fn.HttpsError) as unauth:
        admin_refund_order(_req(auth=False))
    assert unauth.value.code == "unauthenticated"

    with pytest.raises(https_fn.HttpsError) as missing_order:
        admin_refund_order(_req(uid="admin_1", data={}))
    assert missing_order.value.code == "invalid-argument"

    db_perm = Mock()
    users_perm = Mock()
    users_perm.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER]}, exists=True)
    db_perm.collection.side_effect = lambda name: {Collections.USERS: users_perm}[name]
    with patch("handlers.admin.get_db", return_value=db_perm):
        with pytest.raises(https_fn.HttpsError) as perm:
            admin_refund_order(_req(uid="u1", data={Fields.ORDER_ID: "o1"}))
    assert perm.value.code == "permission-denied"

    db_nf = Mock()
    users_nf = Mock()
    users_nf.document.return_value.get.return_value = _snap(_recent_admin(), exists=True)
    ord_ref = Mock()
    ord_ref.get.return_value = _snap({}, exists=False)
    orders_nf = Mock()
    orders_nf.document.return_value = ord_ref
    db_nf.collection.side_effect = lambda name: {Collections.USERS: users_nf, Collections.ORDERS: orders_nf}[name]
    with patch("handlers.admin.get_db", return_value=db_nf):
        with pytest.raises(https_fn.HttpsError) as nf:
            admin_refund_order(_req(uid="admin_1", data={Fields.ORDER_ID: "o1"}))
    assert nf.value.code == "not-found"


@patch("handlers.admin.get_server_timestamp", return_value="ts")
@patch("handlers.admin.get_db")
def test_admin_refund_order_payout_transfer_branches_and_stripe_refund_error(mock_get_db, _mock_ts):
    from handlers.admin import admin_refund_order

    db = Mock()
    mock_get_db.return_value = db

    users_coll = Mock()
    users_coll.document.return_value.get.return_value = _snap(_recent_admin(), exists=True)

    order_ref = Mock()
    order_ref.get.return_value = _snap(
        {
            Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_1",
            Fields.ITEMS: [],
        },
        exists=True,
    )
    orders_coll = Mock()
    orders_coll.document.return_value = order_ref

    payouts_docs = [
        _snap({Fields.SELLER_ID: "s1"}, doc_id="p_no_transfer", reference=Mock()),  # line 2034 continue
        _snap({Fields.SELLER_ID: "s2", Fields.STRIPE_TRANSFER_ID: "tr_ok"}, doc_id="p_ok", reference=Mock()),  # 2040 update
        _snap({Fields.SELLER_ID: "s3", Fields.STRIPE_TRANSFER_ID: "tr_already"}, doc_id="p_already", reference=Mock()),  # 2048 continue
    ]
    payouts_q = _query([payouts_docs])
    payouts_coll = Mock()
    payouts_coll.where.return_value = payouts_q

    db.collection.side_effect = lambda name: {
        Collections.USERS: users_coll,
        Collections.ORDERS: orders_coll,
        Collections.PAYOUTS: payouts_coll,
        Collections.SECURITY_ALERTS: Mock(),
    }[name]

    with patch("handlers.admin.stripe.Transfer.create_reversal") as mock_rev:
        mock_rev.side_effect = [None, stripe.error.InvalidRequestError(message="already reversed", param="id")]
        with patch("handlers.admin.stripe.Refund.create", side_effect=stripe.StripeError("refund down")):
            with pytest.raises(https_fn.HttpsError) as stripe_exc:
                admin_refund_order(_req(uid="admin_1", data={Fields.ORDER_ID: "ord_1"}))
    assert stripe_exc.value.code == "internal"
    assert payouts_docs[1].reference.update.called


@patch("handlers.admin.get_server_timestamp", return_value="ts")
@patch("handlers.admin.get_db")
def test_admin_refund_order_digital_revoke_exception_is_swallowed(mock_get_db, _mock_ts):
    from handlers.admin import admin_refund_order

    db = Mock()
    mock_get_db.return_value = db

    users_coll = Mock()
    users_coll.document.return_value.get.return_value = _snap(_recent_admin(), exists=True)

    order_ref = Mock()
    order_ref.get.return_value = _snap(
        {
            Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
            Fields.STRIPE_PAYMENT_INTENT_ID: "pi_2",
            Fields.ITEMS: [],
        },
        exists=True,
    )
    orders_coll = Mock()
    orders_coll.document.return_value = order_ref
    payouts_coll = Mock()
    payouts_coll.where.return_value = _query([[]])
    logs_coll = Mock()

    db.collection.side_effect = lambda name: {
        Collections.USERS: users_coll,
        Collections.ORDERS: orders_coll,
        Collections.PAYOUTS: payouts_coll,
        Collections.ADMIN_LOGS: logs_coll,
    }[name]

    with patch("handlers.admin.stripe.Refund.create", return_value=SimpleNamespace(id="re_1", status="succeeded")):
        with patch("handlers.admin._revoke_digital_licenses_for_order", side_effect=RuntimeError("revoke fail"), create=True):
            out = admin_refund_order(_req(uid="admin_1", data={Fields.ORDER_ID: "ord_2"}))
    assert out["success"] is True


@patch("handlers.admin.get_db")
def test_create_stripe_login_link_sets_api_key_when_missing(mock_get_db):
    from handlers.admin import create_stripe_login_link

    db = Mock()
    mock_get_db.return_value = db
    sp_ref = Mock()
    sp_ref.get.return_value = _snap({Fields.STRIPE_ACCOUNT_ID: "acct_999"}, exists=True)
    sp_coll = Mock()
    sp_coll.document.return_value = sp_ref
    db.collection.side_effect = lambda name: {Collections.SELLER_PROFILES: sp_coll}[name]

    with patch("handlers.admin.stripe.api_key", ""):
        with patch("config.get_stripe_secret_key", return_value="sk_test_from_cfg"):
            with patch("handlers.admin.stripe.Account.create_login_link", return_value=SimpleNamespace(url="https://stripe/link")):
                out = create_stripe_login_link(_req(uid="seller_1"))
    assert out["success"] is True
