from __future__ import annotations

import hashlib
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock, Mock, patch

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
    ProductLifecycleStatusValues,
    UserRoleValues,
)


def _req(*, uid: str = "user_1", data: dict | None = None, auth: bool = True) -> Mock:
    req = Mock()
    req.auth = Mock(uid=uid) if auth else None
    req.data = data or {}
    return req


def _snap(
    data: dict | None = None,
    *,
    exists: bool = True,
    doc_id: str = "doc_1",
    reference: Mock | None = None,
) -> Mock:
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.reference = reference or Mock()
    snap.to_dict.return_value = data or {}
    return snap


def _query(stream_results: list[list]) -> Mock:
    q = Mock()
    q.where.return_value = q
    q.limit.return_value = q
    q.order_by.return_value = q
    q.start_after.return_value = q
    q.stream.side_effect = stream_results
    return q


def _recent_admin_data() -> dict:
    return {
        Fields.ROLES: [UserRoleValues.ADMIN],
        Fields.MFA_ENABLED: True,
        Fields.LAST_MFA_VERIFY: datetime.now(UTC),
    }


def _build_delete_account_db(user_id: str = "user_1") -> tuple[Mock, dict[str, Mock]]:
    db = Mock()

    user_ref = Mock()
    security_ref = Mock()
    sp_ref = Mock()
    sub_ref = Mock()

    # users/{uid}
    users_coll = Mock()
    users_coll.document.return_value = user_ref

    # users/{uid}/subcollections
    sub_docs = {}
    for sub_name in [
        Collections.CART,
        Collections.FAVORITES,
        Collections.ADDRESSES,
        Collections.NOTIFICATIONS,
        Collections.WAREHOUSES,
        Collections.SELLER_METRICS,
        Collections.FCM_TOKENS,
    ]:
        d = _snap({}, doc_id=f"{sub_name}_doc", reference=Mock())
        sub_q = Mock()
        sub_q.limit.return_value = sub_q
        sub_q.stream.side_effect = [[d], []]
        sub_docs[sub_name] = sub_q
    user_ref.collection.side_effect = lambda name: sub_docs[name]

    # seller_profiles/{uid}
    sp_doc = _snap({Fields.STRIPE_ACCOUNT_ID: "acct_123"}, exists=True)
    sp_ref.get.side_effect = [sp_doc, sp_doc]
    sp_coll = Mock()
    sp_coll.document.return_value = sp_ref

    # user_security/{uid}
    security_ref.get.return_value = _snap({}, exists=True)
    sec_coll = Mock()
    sec_coll.document.return_value = security_ref

    # subscriptions/{uid}
    sub_coll = Mock()
    sub_coll.document.return_value = sub_ref

    # orders collection:
    # 1) pending_orders check -> []
    # 2) active_sales check -> []
    # 3) anonymize batch -> [doc]
    # 4) anonymize batch -> []
    order_doc_ref = Mock()
    order_doc = _snap({}, doc_id="ord_1", reference=order_doc_ref)
    orders_coll = Mock()
    orders_coll.where.side_effect = [
        _query([[]]),
        _query([[]]),
        _query([[order_doc]]),
        _query([[]]),
    ]

    # products collection anonymization -> [doc], []
    product_doc_ref = Mock()
    product_doc = _snap({}, doc_id="prod_1", reference=product_doc_ref)
    products_coll = Mock()
    products_coll.where.side_effect = [_query([[product_doc]]), _query([[]])]

    # payouts:
    # 1) pending payouts check -> []
    # 2) anonymize batch -> [doc]
    # 3) anonymize batch -> []
    payout_doc_ref = Mock()
    payout_doc = _snap({}, doc_id="payout_1", reference=payout_doc_ref)
    payouts_coll = Mock()
    payouts_coll.where.side_effect = [_query([[]]), _query([[payout_doc]]), _query([[]])]

    # product_questions:
    # asker loop [doc], []
    # seller loop [doc], []
    pq_doc_ref = Mock()
    pq_doc = _snap({}, doc_id="q_1", reference=pq_doc_ref)
    product_questions_coll = Mock()
    product_questions_coll.where.side_effect = [_query([[pq_doc]]), _query([[]]), _query([[pq_doc]]), _query([[]])]

    # product_ratings loop [doc], []
    rating_doc_ref = Mock()
    rating_doc = _snap({}, doc_id="rate_1", reference=rating_doc_ref)
    ratings_coll = Mock()
    ratings_coll.where.side_effect = [_query([[rating_doc]]), _query([[]])]

    # stock_notifications loop [doc], []
    notif_doc_ref = Mock()
    notif_doc = _snap({}, doc_id="notif_1", reference=notif_doc_ref)
    stock_notifs_coll = Mock()
    stock_notifs_coll.where.side_effect = [_query([[notif_doc]]), _query([[]])]

    # chats:
    # buyer loop [chat], []
    # seller loop [chat], []
    msg_doc = _snap({}, doc_id="msg_1", reference=Mock())

    def _chat_doc(doc_id: str, buyer_id: str, seller_id: str) -> Mock:
        chat_ref = Mock()
        msg_q = Mock()
        msg_q.limit.return_value = msg_q
        msg_q.stream.side_effect = [[msg_doc], []]
        chat_ref.collection.return_value = msg_q
        return _snap(
            {Fields.BUYER_ID: buyer_id, Fields.SELLER_ID: seller_id},
            doc_id=doc_id,
            reference=chat_ref,
        )

    chat_buyer = _chat_doc("chat_buyer", buyer_id=user_id, seller_id="seller_x")
    chat_seller = _chat_doc("chat_seller", buyer_id="buyer_x", seller_id=user_id)
    chats_coll = Mock()
    chats_coll.where.side_effect = [
        _query([[chat_buyer]]),
        _query([[]]),
        _query([[chat_seller]]),
        _query([[]]),
    ]

    security_alerts_coll = Mock()
    admin_logs_coll = Mock()

    def _collection(name: str) -> Mock:
        mapping = {
            Collections.USERS: users_coll,
            Collections.ORDERS: orders_coll,
            Collections.PAYOUTS: payouts_coll,
            Collections.SELLER_PROFILES: sp_coll,
            Collections.USER_SECURITY: sec_coll,
            Collections.PRODUCTS: products_coll,
            Collections.PRODUCT_QUESTIONS: product_questions_coll,
            Collections.PRODUCT_RATINGS: ratings_coll,
            Collections.STOCK_NOTIFICATIONS: stock_notifs_coll,
            Collections.CHATS: chats_coll,
            Collections.SUBSCRIPTIONS: sub_coll,
            Collections.SECURITY_ALERTS: security_alerts_coll,
            Collections.ADMIN_LOGS: admin_logs_coll,
        }
        return mapping[name]

    db.collection.side_effect = _collection
    db.batch.side_effect = lambda: Mock(update=Mock(), delete=Mock(), commit=Mock())

    return db, {
        "user_ref": user_ref,
        "security_ref": security_ref,
        "sp_ref": sp_ref,
        "sub_ref": sub_ref,
        "security_alerts_coll": security_alerts_coll,
        "product_doc": product_doc,
    }


class TestAdminMoreBranches:
    def test_require_recent_admin_mfa_missing_last_verify_denied(self):
        from handlers.admin import _require_recent_admin_mfa

        with pytest.raises(https_fn.HttpsError) as exc:
            _require_recent_admin_mfa({Fields.MFA_ENABLED: True})
        assert exc.value.code == "permission-denied"

    @patch("handlers.admin.get_db")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.admin.auth.set_custom_user_claims")
    def test_update_user_roles_claims_failure_and_revert_failure_logs_alert(
        self, mock_set_claims, mock_rl_cls, mock_get_db
    ):
        from handlers.admin import update_user_roles

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        mock_set_claims.side_effect = RuntimeError("claims down")

        db = Mock()
        mock_get_db.return_value = db

        admin_ref = Mock()
        admin_ref.get.return_value = _snap(_recent_admin_data(), exists=True)

        target_ref = Mock()
        target_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER]}, exists=True)
        target_ref.update.side_effect = [None, RuntimeError("revert failed")]

        users_coll = Mock()
        users_coll.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else target_ref

        alerts_coll = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.SECURITY_ALERTS: alerts_coll,
        }[name]

        req = _req(
            uid="admin_1",
            data={Fields.TARGET_USER_ID: "target_1", ApiKeys.ADD: [UserRoleValues.SELLER], ApiKeys.REMOVE: []},
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_roles(req)
        assert exc.value.code == "internal"
        assert alerts_coll.add.called

    @patch("handlers.admin.get_db")
    @patch("handlers.admin.RateLimiter")
    @patch("handlers.admin.get_delete_field", return_value="DELETE")
    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("services.algolia_service.batch_partial_update_products")
    def test_unsuspend_seller_reactivates_and_skips_invalid_products(
        self, _mock_algolia, _mock_ts, _mock_delete, mock_rl_cls, mock_get_db
    ):
        from handlers.admin import unsuspend_seller

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = Mock()
        mock_get_db.return_value = db

        admin_ref = Mock()
        admin_ref.get.return_value = _snap(_recent_admin_data(), exists=True)
        seller_ref = Mock()
        seller_ref.get.return_value = _snap({Fields.SUSPENDED: True, Fields.ROLES: [UserRoleValues.SELLER]}, exists=True)

        good_doc = _snap(
            {
                Fields.STOCK_QUANTITY: 5,
                Fields.PRICE: 10,
                Fields.DELETED_AT: None,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
            },
            doc_id="prod_good",
            reference=Mock(),
        )
        skip_doc = _snap(
            {
                Fields.STOCK_QUANTITY: 0,
                Fields.PRICE: 10,
                Fields.DELETED_AT: None,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
            },
            doc_id="prod_skip",
            reference=Mock(),
        )
        products_q1 = _query([[good_doc, skip_doc]])
        products_q2 = _query([[]])
        products_coll = Mock()
        products_coll.where.side_effect = [products_q1, products_q2]

        users_coll = Mock()
        users_coll.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else seller_ref
        alerts_coll = Mock()

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.PRODUCTS: products_coll,
            Collections.SECURITY_ALERTS: alerts_coll,
        }[name]

        batch = Mock()
        db.batch.return_value = batch

        out = unsuspend_seller(_req(uid="admin_1", data={Fields.SELLER_ID: "seller_1"}))
        assert out["success"] is True
        assert out["productsReactivated"] == 1
        assert out["productsSkipped"] == 1
        batch.commit.assert_called_once()

    @patch("handlers.admin.get_db")
    @patch("handlers.admin.RateLimiter")
    def test_admin_mfa_disable_success(self, mock_rl_cls, mock_get_db):
        from handlers.admin import admin_mfa_disable
        from utils.crypto_utils import encrypt_mfa_secret

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = Mock()
        mock_get_db.return_value = db

        secret = pyotp.random_base32()
        encrypted_secret = encrypt_mfa_secret(secret, associated_data="admin_1")
        code = pyotp.TOTP(secret).now()

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        sec_ref = Mock()
        sec_ref.get.return_value = _snap({Fields.MFA_SECRET: encrypted_secret}, exists=True)

        users_coll = Mock()
        users_coll.document.return_value = user_ref
        sec_coll = Mock()
        sec_coll.document.return_value = sec_ref
        admin_logs_coll = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.USER_SECURITY: sec_coll,
            Collections.ADMIN_LOGS: admin_logs_coll,
        }[name]

        out = admin_mfa_disable(_req(uid="admin_1", data={ApiKeys.CODE: code}))
        assert out["success"] is True
        assert out[Fields.MFA_ENABLED] is False
        sec_ref.delete.assert_called_once()

    @patch("handlers.admin.get_db")
    @patch("handlers.admin.RateLimiter")
    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    def test_admin_mfa_verify_backup_low_remaining_logs_alert(self, _mock_ts, mock_rl_cls, mock_get_db):
        from handlers.admin import admin_mfa_verify_backup

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = Mock()
        mock_get_db.return_value = db

        salt = "s1"
        valid_code = "ABCD1234"
        h0 = hashlib.sha256((valid_code + salt).encode()).hexdigest()
        h1 = hashlib.sha256(("EEEE1111" + salt).encode()).hexdigest()
        h2 = hashlib.sha256(("FFFF2222" + salt).encode()).hexdigest()

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.MFA_ENABLED: True}, exists=True)
        sec_ref = Mock()
        sec_ref.get.return_value = _snap(
            {
                Fields.MFA_BACKUP_CODES: [h0, h1, h2],
                Fields.MFA_BACKUP_CODES_SALT: salt,
            },
            exists=True,
        )
        alerts_coll = Mock()

        users_coll = Mock()
        users_coll.document.return_value = user_ref
        sec_coll = Mock()
        sec_coll.document.return_value = sec_ref
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.USER_SECURITY: sec_coll,
            Collections.SECURITY_ALERTS: alerts_coll,
        }[name]

        out = admin_mfa_verify_backup(_req(uid="admin_1", data={ApiKeys.CODE: valid_code}))
        assert out["success"] is True
        assert out[ApiKeys.REMAINING_CODES] == 2
        assert alerts_coll.add.called

    @patch("handlers.admin.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.get_delete_field", return_value="DELETE")
    @patch("handlers.admin.auth.delete_user")
    @patch("handlers.admin.stripe.Account.delete")
    @patch("services.algolia_service.delete_products_from_algolia")
    @patch("firebase_admin.storage.bucket")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.admin.get_db")
    def test_delete_account_success_executes_full_cleanup(
        self,
        mock_get_db,
        mock_rl_cls,
        mock_bucket,
        mock_delete_products_algolia,
        _mock_stripe_delete,
        mock_delete_user,
        _mock_delete_field,
        _mock_ts,
        _mock_resp,
    ):
        from handlers.admin import delete_account

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db, refs = _build_delete_account_db("user_1")
        mock_get_db.return_value = db

        # Storage cleanup
        blob = Mock()
        mock_bucket.return_value.list_blobs.side_effect = [[blob], [blob], [blob]]

        out = delete_account(_req(uid="user_1"))
        assert out["success"] is True
        assert "deleted" in out[ApiKeys.MESSAGE].lower()
        refs["user_ref"].update.assert_called_once()
        refs["security_ref"].delete.assert_called_once()
        refs["sp_ref"].delete.assert_called_once()
        refs["sub_ref"].delete.assert_called_once()
        mock_delete_products_algolia.assert_called_once_with(["prod_1"])
        mock_delete_user.assert_called_once_with("user_1")

    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.get_delete_field", return_value="DELETE")
    @patch("handlers.admin.auth.delete_user", side_effect=RuntimeError("auth delete failed"))
    @patch("handlers.admin.stripe.Account.delete")
    @patch("services.algolia_service.delete_products_from_algolia")
    @patch("firebase_admin.storage.bucket")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.admin.get_db")
    def test_delete_account_auth_delete_failure_raises_internal(
        self,
        mock_get_db,
        mock_rl_cls,
        _mock_bucket,
        _mock_delete_products_algolia,
        _mock_stripe_delete,
        _mock_delete_user,
        _mock_delete_field,
        _mock_ts,
    ):
        from handlers.admin import delete_account

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db, refs = _build_delete_account_db("user_1")
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            delete_account(_req(uid="user_1"))
        assert exc.value.code == "internal"
        assert refs["security_alerts_coll"].add.called

    @patch("handlers.admin.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_export_my_data_success_serializes_profile_and_orders(self, mock_rl_cls, mock_get_db):
        from handlers.admin import export_my_data

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_ref.get.return_value = _snap(
            {
                Fields.EMAIL: "user@example.com",
                Fields.CREATED_AT: datetime(2026, 1, 1, tzinfo=UTC),
                "internalField": "not-exported",
            },
            exists=True,
        )

        order_doc = _snap(
            {
                Fields.CREATED_AT: datetime(2026, 2, 2, tzinfo=UTC),
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
            },
            doc_id="ord_1",
        )
        orders_q = _query([[order_doc], []])

        fav1 = _snap({}, doc_id="fav_1")
        fav2 = _snap({}, doc_id="fav_2")
        fav_coll = Mock()
        fav_coll.stream.return_value = [fav1, fav2]
        user_ref.collection.return_value = fav_coll

        users_coll = Mock()
        users_coll.document.return_value = user_ref
        orders_coll = Mock()
        orders_coll.where.return_value = orders_q
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.ORDERS: orders_coll,
        }[name]

        out = export_my_data(_req(uid="user_1"))
        assert out["success"] is True
        assert out[ApiKeys.PROFILE][Fields.EMAIL] == "user@example.com"
        assert "internalField" not in out[ApiKeys.PROFILE]
        assert len(out[ApiKeys.ORDERS]) == 1
        assert out[ApiKeys.ORDERS][0][Fields.ORDER_ID] == "ord_1"
        assert out[ApiKeys.FAVORITES] == ["fav_1", "fav_2"]

    @patch("config.CURRENT_ENV")
    @patch("handlers.admin.get_firestore")
    @patch("handlers.admin.get_db")
    def test_e2e_get_mail_logs_success(
        self, mock_get_db, mock_get_firestore, mock_env
    ):
        from config import Environment
        from handlers.admin import e2e_get_mail_logs

        mock_env.__eq__.side_effect = lambda other: False
        mock_get_firestore.return_value = SimpleNamespace(Query=SimpleNamespace(DESCENDING="DESC"))

        db = Mock()
        mock_get_db.return_value = db

        admin_user = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        users_coll = Mock()
        users_coll.document.return_value.get.return_value = admin_user

        sent_at = datetime(2026, 3, 1, tzinfo=UTC)
        log_doc = _snap({"to": "a@example.com", "sentAt": sent_at}, doc_id="mail_1")
        logs_q = _query([[log_doc]])
        mail_logs_coll = Mock()
        mail_logs_coll.where.return_value = logs_q

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.MAIL_LOGS: mail_logs_coll,
        }[name]

        out = e2e_get_mail_logs(_req(uid="admin_1", data={"to": "a@example.com"}))
        assert out["success"] is True
        assert out["logs"][0]["id"] == "mail_1"
        assert isinstance(out["logs"][0]["sentAt"], str)

    @patch("config.CURRENT_ENV")
    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.get_db")
    def test_e2e_seed_license_create_and_delete_paths(self, mock_get_db, _mock_ts, mock_env):
        from handlers.admin import e2e_seed_license

        mock_env.__eq__.side_effect = lambda other: False

        db = Mock()
        mock_get_db.return_value = db

        admin_user = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        users_coll = Mock()
        users_coll.document.return_value.get.return_value = admin_user

        license_ref = Mock()
        licenses_coll = Mock()
        licenses_coll.document.return_value = license_ref

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.LICENSES: licenses_coll,
        }[name]

        created = e2e_seed_license(
            _req(uid="admin_1", data={"action": "create", "licenseKey": "LIC-1", "data": {"platform": "windows"}})
        )
        assert created["success"] is True
        license_ref.set.assert_called_once()

        deleted = e2e_seed_license(_req(uid="admin_1", data={"action": "delete", "licenseKey": "LIC-1"}))
        assert deleted["success"] is True
        license_ref.delete.assert_called_once()

    @patch("handlers.admin.get_db")
    def test_admin_get_reviews_flagged_and_start_after(self, mock_get_db):
        from handlers.admin import admin_get_reviews

        db = Mock()
        mock_get_db.return_value = db

        admin_user = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        users_coll = Mock()
        users_coll.document.return_value.get.return_value = admin_user

        start_after_snap = _snap({}, exists=True, doc_id="r_start")
        ratings_coll = Mock()
        ratings_coll.document.return_value.get.return_value = start_after_snap

        review_doc = _snap(
            {
                Fields.PRODUCT_ID: "p1",
                Fields.USER_ID: "u1",
                Fields.RATING: 5,
                Fields.COMMENT: "great",
                Fields.IS_FLAGGED: True,
            },
            doc_id="r1",
        )
        ratings_q = _query([[review_doc]])
        ratings_coll.order_by.return_value = ratings_q

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.PRODUCT_RATINGS: ratings_coll,
        }[name]

        out = admin_get_reviews(_req(uid="admin_1", data={"flaggedOnly": True, "startAfter": "r_start", "limit": 10}))
        assert out["success"] is True
        assert out["count"] == 1
        assert out["reviews"][0][Fields.REVIEW_ID] == "r1"

    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.get_db")
    def test_admin_delete_review_recalculates_even_if_algolia_sync_fails(self, mock_get_db, _mock_ts):
        from handlers.admin import admin_delete_review

        db = Mock()
        mock_get_db.return_value = db

        admin_user = _snap(_recent_admin_data(), exists=True)
        review_ref = Mock()
        review_ref.get.return_value = _snap(
            {Fields.PRODUCT_ID: "prod_1", Fields.RATING: 4},
            exists=True,
            doc_id="rev_1",
        )

        product_ref = Mock()
        p_snap_before = _snap({Fields.RATING: 5.0, Fields.RATING_COUNT: 2}, exists=True)
        p_snap_after = _snap({Fields.RATING: 5.0, Fields.RATING_COUNT: 2}, exists=True)
        product_ref.get.side_effect = [p_snap_before, p_snap_after]

        users_coll = Mock()
        users_coll.document.return_value.get.return_value = admin_user
        ratings_coll = Mock()
        ratings_coll.document.return_value = review_ref
        products_coll = Mock()
        products_coll.document.return_value = product_ref
        admin_logs_coll = Mock()

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.PRODUCT_RATINGS: ratings_coll,
            Collections.PRODUCTS: products_coll,
            Collections.ADMIN_LOGS: admin_logs_coll,
        }[name]

        txn = Mock()
        db.transaction.return_value = txn

        out = admin_delete_review(_req(uid="admin_1", data={Fields.REVIEW_ID: "rev_1"}))
        assert out["success"] is True
        review_ref.delete.assert_called_once()
        assert txn.update.called

    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.get_db")
    def test_admin_flag_review_success(self, mock_get_db, _mock_ts):
        from handlers.admin import admin_flag_review

        db = Mock()
        mock_get_db.return_value = db

        admin_user = _snap(_recent_admin_data(), exists=True)
        review_ref = Mock()
        review_ref.get.return_value = _snap({}, exists=True)

        users_coll = Mock()
        users_coll.document.return_value.get.return_value = admin_user
        ratings_coll = Mock()
        ratings_coll.document.return_value = review_ref
        admin_logs_coll = Mock()

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.PRODUCT_RATINGS: ratings_coll,
            Collections.ADMIN_LOGS: admin_logs_coll,
        }[name]

        out = admin_flag_review(_req(uid="admin_1", data={Fields.REVIEW_ID: "rev_1", "flagged": True}))
        assert out["success"] is True
        review_ref.update.assert_called_once()

    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.get_db")
    def test_admin_refund_order_success_updates_order_and_stock(self, mock_get_db, _mock_ts):
        from handlers.admin import admin_refund_order

        db = Mock()
        mock_get_db.return_value = db

        admin_user = _snap(_recent_admin_data(), exists=True)
        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_1",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.QUANTITY: 2}],
            },
            exists=True,
            doc_id="ord_1",
        )
        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.STOCK_QUANTITY: 5}, exists=True, doc_id="prod_1", reference=product_ref)

        payout_q = _query([[]])
        payouts_coll = Mock()
        payouts_coll.where.return_value = payout_q

        users_coll = Mock()
        users_coll.document.return_value.get.return_value = admin_user
        orders_coll = Mock()
        orders_coll.document.return_value = order_ref
        products_coll = Mock()
        products_coll.document.return_value = product_ref
        admin_logs_coll = Mock()

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.ORDERS: orders_coll,
            Collections.PAYOUTS: payouts_coll,
            Collections.PRODUCTS: products_coll,
            Collections.ADMIN_LOGS: admin_logs_coll,
        }[name]

        txn = Mock()
        db.transaction.return_value = txn

        with patch("handlers.admin.stripe.Refund.create", return_value=SimpleNamespace(id="re_1", status="succeeded")):
            with patch("handlers.digital._revoke_digital_licenses_for_order", return_value=1):
                out = admin_refund_order(_req(uid="admin_1", data={Fields.ORDER_ID: "ord_1"}))

        assert out["success"] is True
        assert out["refundId"] == "re_1"
        order_ref.update.assert_called_once()
        assert txn.update.called

    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.get_db")
    def test_admin_refund_order_reversal_failure_aborts_refund(self, mock_get_db, _mock_ts):
        from handlers.admin import admin_refund_order

        class _InvalidRequest(Exception):
            pass

        db = Mock()
        mock_get_db.return_value = db

        admin_user = _snap(_recent_admin_data(), exists=True)
        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_1",
                Fields.ITEMS: [],
            },
            exists=True,
            doc_id="ord_1",
        )

        payout_doc = _snap(
            {Fields.STRIPE_TRANSFER_ID: "tr_1", Fields.SELLER_ID: "seller_1"},
            exists=True,
            doc_id="payout_1",
            reference=Mock(),
        )
        payout_q = _query([[payout_doc]])
        payouts_coll = Mock()
        payouts_coll.where.return_value = payout_q

        users_coll = Mock()
        users_coll.document.return_value.get.return_value = admin_user
        orders_coll = Mock()
        orders_coll.document.return_value = order_ref
        alerts_coll = Mock()

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.ORDERS: orders_coll,
            Collections.PAYOUTS: payouts_coll,
            Collections.SECURITY_ALERTS: alerts_coll,
        }[name]

        with patch("handlers.admin.stripe.error.InvalidRequestError", _InvalidRequest):
            with patch("handlers.admin.stripe.Transfer.create_reversal", side_effect=_InvalidRequest("cannot reverse")):
                with pytest.raises(https_fn.HttpsError) as exc:
                    admin_refund_order(_req(uid="admin_1", data={Fields.ORDER_ID: "ord_1"}))
        assert exc.value.code == "internal"
        assert alerts_coll.add.called

    @patch("handlers.admin.get_db")
    def test_create_stripe_login_link_success(self, mock_get_db):
        from handlers.admin import create_stripe_login_link

        db = Mock()
        mock_get_db.return_value = db

        sp_ref = Mock()
        sp_ref.get.return_value = _snap({Fields.STRIPE_ACCOUNT_ID: "acct_123"}, exists=True)
        sp_coll = Mock()
        sp_coll.document.return_value = sp_ref
        db.collection.side_effect = lambda name: {Collections.SELLER_PROFILES: sp_coll}[name]

        with patch("handlers.admin.stripe.Account.create_login_link", return_value=SimpleNamespace(url="https://stripe/link")):
            out = create_stripe_login_link(_req(uid="seller_1"))
        assert out["success"] is True
        assert out["url"] == "https://stripe/link"

    @patch("handlers.admin.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_roles_blocks_admin_demotion(self, mock_rl_cls, mock_get_db):
        from handlers.admin import update_user_roles

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = Mock()
        mock_get_db.return_value = db

        admin_ref = Mock()
        admin_ref.get.return_value = _snap(_recent_admin_data(), exists=True)
        target_ref = Mock()
        target_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN, UserRoleValues.BUYER]}, exists=True)

        users_coll = Mock()
        users_coll.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else target_ref
        db.collection.side_effect = lambda name: {Collections.USERS: users_coll}[name]

        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_roles(
                _req(
                    uid="admin_1",
                    data={
                        Fields.TARGET_USER_ID: "target_1",
                        ApiKeys.REMOVE: [UserRoleValues.ADMIN],
                    },
                )
            )
        assert exc.value.code == "permission-denied"

    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.get_firestore")
    @patch("services.algolia_service.batch_partial_update_products")
    @patch("handlers.admin.stripe.Refund.create")
    @patch("handlers.admin.stripe.PaymentIntent.cancel")
    @patch("firebase_admin.auth.revoke_refresh_tokens")
    @patch("handlers.admin.get_db")
    @patch("handlers.admin.RateLimiter")
    def test_suspend_seller_full_flow_covers_product_order_payment_and_stock_restore(
        self,
        mock_rl_cls,
        mock_get_db,
        _mock_revoke_tokens,
        _mock_pi_cancel,
        _mock_refund_create,
        _mock_algolia_update,
        mock_get_firestore,
        _mock_ts,
    ):
        from handlers.admin import suspend_seller

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        mock_get_firestore.return_value = SimpleNamespace(transactional=lambda f: lambda txn: f(txn))

        db = Mock()
        mock_get_db.return_value = db

        admin_ref = Mock()
        admin_ref.get.return_value = _snap(_recent_admin_data(), exists=True)
        seller_ref = Mock()
        seller_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, exists=True)

        product_doc = _snap(
            {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE},
            doc_id="prod_1",
            reference=Mock(),
        )
        products_q = _query([[product_doc]])
        products_coll = Mock()
        products_coll.where.return_value = products_q

        cancel_order_ref = Mock()
        cancel_order_doc = _snap(
            {
                Fields.ITEMS: [
                    {Fields.SELLER_ID: "seller_1", Fields.PRODUCT_ID: "prod_1", Fields.QUANTITY: 2},
                    {Fields.SELLER_ID: "other", Fields.PRODUCT_ID: "prod_other", Fields.QUANTITY: 1},
                ],
                Fields.SELLER_IDS: ["seller_1"],
            },
            doc_id="ord_cancel",
            reference=cancel_order_ref,
        )
        auth_order_doc = _snap(
            {
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_auth",
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
            },
            doc_id="ord_auth",
            reference=Mock(),
        )
        captured_order_doc = _snap(
            {
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_cap",
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            },
            doc_id="ord_cap",
            reference=Mock(),
        )

        cancel_q = _query([[cancel_order_doc]])
        payment_q = _query([[auth_order_doc, captured_order_doc]])
        orders_coll = Mock()
        orders_coll.where.side_effect = [cancel_q, payment_q]

        users_coll = Mock()
        users_coll.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else seller_ref
        alerts_coll = Mock()

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.PRODUCTS: products_coll,
            Collections.ORDERS: orders_coll,
            Collections.SECURITY_ALERTS: alerts_coll,
        }[name]

        batches: list[Mock] = []

        def _new_batch():
            b = Mock()
            batches.append(b)
            return b

        db.batch.side_effect = _new_batch

        stock_snap = _snap({Fields.STOCK_QUANTITY: 5}, exists=True, doc_id="prod_1", reference=Mock())
        txn = Mock()
        txn.get_all.return_value = [stock_snap]
        db.transaction.return_value = txn

        out = suspend_seller(_req(uid="admin_1", data={Fields.SELLER_ID: "seller_1", ApiKeys.REASON: "risk"}))
        assert out["success"] is True
        assert out[Fields.PRODUCTS_DEACTIVATED] == 1
        assert out[Fields.ORDERS_CANCELLED] == 1
        assert any(batch.commit.called for batch in batches)
        assert txn.update.called

    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.get_firestore")
    @patch("handlers.admin.get_db")
    @patch("handlers.admin.RateLimiter")
    def test_admin_update_product_stock_success(self, mock_rl_cls, mock_get_db, mock_get_firestore, _mock_ts):
        from handlers.admin import admin_update_product_stock

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        mock_get_firestore.return_value = SimpleNamespace(transactional=lambda f: lambda txn, ref: f(txn, ref))

        db = Mock()
        mock_get_db.return_value = db

        admin_ref = Mock()
        admin_ref.get.return_value = _snap(_recent_admin_data(), exists=True)

        product_ref = Mock()
        product_snap = _snap({Fields.STOCK_QUANTITY: 3}, exists=True)
        product_ref.get.return_value = product_snap

        users_coll = Mock()
        users_coll.document.return_value = admin_ref
        products_coll = Mock()
        products_coll.document.return_value = product_ref
        logs_coll = Mock()

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.PRODUCTS: products_coll,
            Collections.ADMIN_LOGS: logs_coll,
        }[name]
        db.transaction.return_value = Mock()

        out = admin_update_product_stock(
            _req(
                uid="admin_1",
                data={Fields.PRODUCT_ID: "prod_1", Fields.STOCK_QUANTITY: 10, ApiKeys.REASON: "manual correction"},
            )
        )
        assert out["success"] is True
        assert out["oldQuantity"] == 3
        assert out["newQuantity"] == 10
        logs_coll.add.assert_called_once()

    @patch("handlers.admin.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_admin_mfa_enroll_rejects_when_already_enabled(self, mock_rl_cls, mock_get_db):
        from handlers.admin import admin_mfa_enroll

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_ref.get.return_value = _snap(
            {
                Fields.ROLES: [UserRoleValues.ADMIN],
                Fields.MFA_ENABLED: True,
            },
            exists=True,
        )
        users_coll = Mock()
        users_coll.document.return_value = user_ref
        db.collection.side_effect = lambda name: {Collections.USERS: users_coll}[name]

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_mfa_enroll(_req(uid="admin_1"))
        assert exc.value.code == "failed-precondition"

    @patch("handlers.admin.get_firestore")
    @patch("handlers.admin.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_admin_mfa_enroll_rejects_when_temp_secret_exists(self, mock_rl_cls, mock_get_db, mock_get_firestore):
        from handlers.admin import admin_mfa_enroll

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        mock_get_firestore.return_value = SimpleNamespace(transactional=lambda f: lambda txn, ref: f(txn, ref))

        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_ref.get.return_value = _snap(
            {
                Fields.ROLES: [UserRoleValues.ADMIN],
                Fields.MFA_ENABLED: False,
                Fields.EMAIL: "admin@example.com",
            },
            exists=True,
        )
        sec_ref = Mock()
        sec_ref.get.return_value = _snap({Fields.MFA_SECRET_TEMP: "encrypted-temp"}, exists=True)

        users_coll = Mock()
        users_coll.document.return_value = user_ref
        sec_coll = Mock()
        sec_coll.document.return_value = sec_ref

        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.USER_SECURITY: sec_coll,
        }[name]
        db.transaction.return_value = Mock()

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_mfa_enroll(_req(uid="admin_1"))
        assert exc.value.code == "failed-precondition"

    @patch("handlers.admin.get_db")
    def test_admin_mfa_verify_denies_when_lockout_in_future(self, mock_get_db):
        from handlers.admin import admin_mfa_verify
        from utils.crypto_utils import encrypt_mfa_secret

        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_ref.get.return_value = _snap({}, exists=True)
        sec_ref = Mock()
        sec_ref.get.return_value = _snap(
            {
                Fields.MFA_SECRET: encrypt_mfa_secret(pyotp.random_base32(), associated_data="admin_1"),
                Fields.MFA_LOCKOUT_UNTIL: datetime.now(UTC).replace(microsecond=0) + timedelta(minutes=1),
            },
            exists=True,
        )

        users_coll = Mock()
        users_coll.document.return_value = user_ref
        sec_coll = Mock()
        sec_coll.document.return_value = sec_ref
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.USER_SECURITY: sec_coll,
        }[name]

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_mfa_verify(_req(uid="admin_1", data={ApiKeys.CODE: "000000"}))
        assert exc.value.code == "permission-denied"

    @patch("handlers.admin.get_firestore")
    @patch("handlers.admin.get_db")
    def test_admin_mfa_verify_invalid_code_triggers_lockout_counter(self, mock_get_db, mock_get_firestore):
        from handlers.admin import admin_mfa_verify
        from utils.crypto_utils import encrypt_mfa_secret

        mock_get_firestore.return_value = SimpleNamespace(Increment=lambda n: ("inc", n))
        db = Mock()
        mock_get_db.return_value = db

        secret = pyotp.random_base32()
        sec_ref = Mock()
        sec_ref.get.side_effect = [
            _snap(
                {
                    Fields.MFA_SECRET: encrypt_mfa_secret(secret, associated_data="admin_1"),
                    Fields.MFA_FAILED_ATTEMPTS: 4,
                },
                exists=True,
            ),
            _snap({Fields.MFA_FAILED_ATTEMPTS: 5}, exists=True),
        ]

        user_ref = Mock()
        user_ref.get.return_value = _snap({}, exists=True)
        users_coll = Mock()
        users_coll.document.return_value = user_ref
        sec_coll = Mock()
        sec_coll.document.return_value = sec_ref
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.USER_SECURITY: sec_coll,
        }[name]

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_mfa_verify(_req(uid="admin_1", data={ApiKeys.CODE: "123456"}))
        assert exc.value.code == "unauthenticated"
        assert sec_ref.update.call_count >= 2

    @patch("handlers.admin.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.admin.get_delete_field", return_value="__DELETE__")
    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.time.sleep")
    @patch("handlers.admin.get_db")
    def test_admin_mfa_verify_success_persists_temp_backup_codes(
        self,
        mock_get_db,
        _mock_sleep,
        _mock_ts,
        _mock_delete,
        _mock_resp,
    ):
        from handlers.admin import admin_mfa_verify
        from utils.crypto_utils import encrypt_mfa_secret

        secret = pyotp.random_base32()
        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_ref.get.return_value = _snap({}, exists=True)

        sec_ref = Mock()
        sec_ref.get.return_value = _snap(
            {
                Fields.MFA_SECRET_TEMP: encrypt_mfa_secret(secret, associated_data="admin_1"),
                Fields.MFA_BACKUP_CODES_TEMP: ["h1", "h2"],
                Fields.MFA_BACKUP_CODES_SALT: "salt123",
                Fields.MFA_FAILED_ATTEMPTS: 0,
            },
            exists=True,
        )

        users_coll = Mock()
        users_coll.document.return_value = user_ref
        sec_coll = Mock()
        sec_coll.document.return_value = sec_ref
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.USER_SECURITY: sec_coll,
        }[name]

        with patch("handlers.admin.pyotp.TOTP.verify", return_value=True):
            out = admin_mfa_verify(_req(uid="admin_1", data={ApiKeys.CODE: "123456"}))

        assert out["success"] is True
        set_payload = sec_ref.set.call_args.args[0]
        assert set_payload[Fields.MFA_BACKUP_CODES] == ["h1", "h2"]
        assert set_payload[Fields.MFA_BACKUP_CODES_TEMP] == "__DELETE__"
        assert set_payload[Fields.MFA_BACKUP_CODES_SALT] == "salt123"

    @patch("handlers.admin.get_db")
    @patch("handlers.admin.RateLimiter")
    def test_admin_mfa_disable_invalid_code_rejected(self, mock_rl_cls, mock_get_db):
        from handlers.admin import admin_mfa_disable
        from utils.crypto_utils import encrypt_mfa_secret

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        sec_ref = Mock()
        sec_ref.get.return_value = _snap(
            {Fields.MFA_SECRET: encrypt_mfa_secret(pyotp.random_base32(), associated_data="admin_1")},
            exists=True,
        )

        users_coll = Mock()
        users_coll.document.return_value = user_ref
        sec_coll = Mock()
        sec_coll.document.return_value = sec_ref
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.USER_SECURITY: sec_coll,
        }[name]

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_mfa_disable(_req(uid="admin_1", data={ApiKeys.CODE: "000000"}))
        assert exc.value.code == "unauthenticated"

    @patch("handlers.admin.get_db")
    @patch("handlers.admin.RateLimiter")
    def test_admin_mfa_verify_backup_invalid_code_rejected(self, mock_rl_cls, mock_get_db):
        from handlers.admin import admin_mfa_verify_backup

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.MFA_ENABLED: True}, exists=True)
        sec_ref = Mock()
        sec_ref.get.return_value = _snap(
            {
                Fields.MFA_BACKUP_CODES: [hashlib.sha256(("VALID123" + "s").encode()).hexdigest()],
                Fields.MFA_BACKUP_CODES_SALT: "s",
            },
            exists=True,
        )
        users_coll = Mock()
        users_coll.document.return_value = user_ref
        sec_coll = Mock()
        sec_coll.document.return_value = sec_ref
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.USER_SECURITY: sec_coll,
        }[name]

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_mfa_verify_backup(_req(uid="admin_1", data={ApiKeys.CODE: "WRONG000"}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.admin.get_server_timestamp", return_value="ts")
    @patch("handlers.admin.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_unsubscribe_email_success_and_not_found(self, mock_rl_cls, mock_get_db, _mock_ts):
        from handlers.admin import unsubscribe_email

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")

        # not-found branch
        db_nf = Mock()
        user_ref_nf = Mock()
        user_ref_nf.get.return_value = _snap({}, exists=False)
        users_coll_nf = Mock()
        users_coll_nf.document.return_value = user_ref_nf
        db_nf.collection.side_effect = lambda name: {Collections.USERS: users_coll_nf}[name]
        mock_get_db.return_value = db_nf
        with pytest.raises(https_fn.HttpsError) as exc:
            unsubscribe_email(_req(uid="u_nf"))
        assert exc.value.code == "not-found"

        # success branch
        db_ok = Mock()
        user_ref_ok = Mock()
        user_ref_ok.get.return_value = _snap({}, exists=True)
        users_coll_ok = Mock()
        users_coll_ok.document.return_value = user_ref_ok
        db_ok.collection.side_effect = lambda name: {Collections.USERS: users_coll_ok}[name]
        mock_get_db.return_value = db_ok
        out = unsubscribe_email(_req(uid="u_ok"))
        assert out["success"] is True
        user_ref_ok.update.assert_called_once()

    @patch("config.CURRENT_ENV")
    @patch("handlers.admin.get_db")
    def test_e2e_get_mail_logs_missing_to_rejected(self, mock_get_db, mock_env):
        from handlers.admin import e2e_get_mail_logs

        mock_env.__eq__.side_effect = lambda other: False
        db = Mock()
        mock_get_db.return_value = db
        users_coll = Mock()
        users_coll.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        db.collection.side_effect = lambda name: {Collections.USERS: users_coll}[name]

        with pytest.raises(https_fn.HttpsError) as exc:
            e2e_get_mail_logs(_req(uid="admin_1", data={}))
        assert exc.value.code == https_fn.FunctionsErrorCode.INVALID_ARGUMENT

    @patch("config.CURRENT_ENV")
    @patch("handlers.admin.get_db")
    def test_e2e_seed_license_create_requires_data_dict(self, mock_get_db, mock_env):
        from handlers.admin import e2e_seed_license

        mock_env.__eq__.side_effect = lambda other: False
        db = Mock()
        mock_get_db.return_value = db

        users_coll = Mock()
        users_coll.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        licenses_coll = Mock()
        licenses_coll.document.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.LICENSES: licenses_coll,
        }[name]

        with pytest.raises(https_fn.HttpsError) as exc:
            e2e_seed_license(_req(uid="admin_1", data={"action": "create", "licenseKey": "LIC"}))
        assert exc.value.code == https_fn.FunctionsErrorCode.INVALID_ARGUMENT

    @patch("handlers.admin.get_db")
    def test_admin_get_reviews_requires_admin(self, mock_get_db):
        from handlers.admin import admin_get_reviews

        db = Mock()
        mock_get_db.return_value = db
        users_coll = Mock()
        users_coll.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER]}, exists=True)
        db.collection.side_effect = lambda name: {Collections.USERS: users_coll}[name]

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_get_reviews(_req(uid="u1"))
        assert exc.value.code == "permission-denied"

    @patch("handlers.admin.get_db")
    def test_admin_delete_review_not_found(self, mock_get_db):
        from handlers.admin import admin_delete_review

        db = Mock()
        mock_get_db.return_value = db
        users_coll = Mock()
        users_coll.document.return_value.get.return_value = _snap(_recent_admin_data(), exists=True)
        ratings_coll = Mock()
        ratings_coll.document.return_value.get.return_value = _snap({}, exists=False)
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.PRODUCT_RATINGS: ratings_coll,
        }[name]

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_delete_review(_req(uid="admin_1", data={Fields.REVIEW_ID: "r1"}))
        assert exc.value.code == "not-found"

    @patch("handlers.admin.get_db")
    def test_admin_flag_review_invalid_payload(self, mock_get_db):
        from handlers.admin import admin_flag_review

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_flag_review(_req(uid="admin_1", data={Fields.REVIEW_ID: "r1", "flagged": "yes"}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.admin.get_db")
    def test_admin_refund_order_precondition_guards(self, mock_get_db):
        from handlers.admin import admin_refund_order

        db = Mock()
        mock_get_db.return_value = db

        users_coll = Mock()
        users_coll.document.return_value.get.return_value = _snap(_recent_admin_data(), exists=True)
        order_ref = Mock()
        orders_coll = Mock()
        orders_coll.document.return_value = order_ref
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_coll,
            Collections.ORDERS: orders_coll,
        }[name]

        # Non-refundable status
        order_ref.get.return_value = _snap({Fields.ORDER_STATUS: "cancelled"}, exists=True)
        with pytest.raises(https_fn.HttpsError) as status_exc:
            admin_refund_order(_req(uid="admin_1", data={Fields.ORDER_ID: "o1"}))
        assert status_exc.value.code == "failed-precondition"

        # Missing payment intent
        order_ref.get.return_value = _snap({Fields.ORDER_STATUS: OrderStatusValues.DELIVERED}, exists=True)
        with pytest.raises(https_fn.HttpsError) as pi_exc:
            admin_refund_order(_req(uid="admin_1", data={Fields.ORDER_ID: "o1"}))
        assert pi_exc.value.code == "failed-precondition"

    @patch("handlers.admin.get_db")
    def test_create_stripe_login_link_guard_paths(self, mock_get_db):
        from handlers.admin import create_stripe_login_link

        # unauthenticated
        with pytest.raises(https_fn.HttpsError) as unauth:
            create_stripe_login_link(_req(auth=False))
        assert unauth.value.code == "unauthenticated"

        # missing seller profile
        db = Mock()
        mock_get_db.return_value = db
        sp_ref = Mock()
        sp_ref.get.return_value = _snap({}, exists=False)
        sp_coll = Mock()
        sp_coll.document.return_value = sp_ref
        db.collection.side_effect = lambda name: {Collections.SELLER_PROFILES: sp_coll}[name]
        with pytest.raises(https_fn.HttpsError) as missing_profile:
            create_stripe_login_link(_req(uid="seller_1"))
        assert missing_profile.value.code == "not-found"

        # no stripe account
        sp_ref.get.return_value = _snap({}, exists=True)
        with pytest.raises(https_fn.HttpsError) as missing_stripe:
            create_stripe_login_link(_req(uid="seller_1"))
        assert missing_stripe.value.code == "failed-precondition"

    @patch("handlers.admin.stripe.Account.create_login_link", side_effect=stripe.StripeError("stripe down"))
    @patch("handlers.admin.stripe.api_key", "sk_test_123")
    @patch("handlers.admin.get_db")
    def test_create_stripe_login_link_stripe_error_maps_to_internal(self, mock_get_db, _mock_login):
        from handlers.admin import create_stripe_login_link

        db = Mock()
        sp_ref = Mock()
        sp_ref.get.return_value = _snap({Fields.STRIPE_ACCOUNT_ID: "acct_123"}, exists=True)
        sp_coll = Mock()
        sp_coll.document.return_value = sp_ref
        db.collection.side_effect = lambda name: {Collections.SELLER_PROFILES: sp_coll}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            create_stripe_login_link(_req(uid="seller_1"))
        assert exc.value.code == "internal"
