from datetime import UTC, datetime
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn
from google.api_core import exceptions as google_exceptions

from schema_constants import (
    ApiKeys,
    Collections,
    Fields,
    ProductLifecycleStatusValues,
    UserRoleValues,
)


def _req(uid: str | None, data: dict | None = None):
    req = Mock()
    req.auth = Mock(uid=uid) if uid else None
    req.data = data or {}
    return req


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _recent_admin_data():
    return {
        Fields.ROLES: [UserRoleValues.ADMIN],
        Fields.MFA_ENABLED: True,
        Fields.LAST_MFA_VERIFY: datetime.now(UTC),
    }


class TestCronDispatcherGuardBranchesMore:
    @patch("handlers.cron_jobs._run_auto_capture")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    def test_stale_orders_dispatcher_skips_when_locked(self, _mock_lock, mock_run):
        from handlers.cron_jobs import stale_orders_dispatcher

        stale_orders_dispatcher(Mock())
        mock_run.assert_not_called()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs._alert_cron_failure")
    @patch("handlers.cron_jobs._dispatch_stale_orders", side_effect=RuntimeError("dispatch failed"))
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    def test_stale_orders_dispatcher_alerts_and_releases(
        self, _mock_lock, _mock_dispatch, mock_alert, mock_release
    ):
        from handlers.cron_jobs import stale_orders_dispatcher

        stale_orders_dispatcher(Mock())
        mock_alert.assert_called_once()
        mock_release.assert_called_once_with("stale_orders_dispatcher")

    @patch.dict("os.environ", {}, clear=True)
    def test_dispatch_stale_orders_requires_env(self):
        from handlers.cron_jobs import _dispatch_stale_orders

        with pytest.raises(ValueError):
            _dispatch_stale_orders()

    @patch.dict(
        "os.environ",
        {"STALE_ORDER_WORKER_URL": "https://worker.example.com", "TASK_HANDLER_SA_EMAIL": "tasks@example.com"},
        clear=True,
    )
    @patch("handlers.cron_jobs.tasks_v2.CloudTasksClient")
    @patch("handlers.cron_jobs.get_db")
    def test_dispatch_stale_orders_no_orders_short_circuit(self, mock_get_db, mock_tasks_client_cls):
        from handlers.cron_jobs import _dispatch_stale_orders

        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.stream.return_value = []
        db = Mock()
        db.collection.return_value = q
        mock_get_db.return_value = db

        _dispatch_stale_orders()
        mock_tasks_client_cls.assert_not_called()

    @patch("services.algolia_service.get_index_stats", return_value=0)
    @patch("handlers.cron_jobs.get_db")
    def test_monitor_algolia_sync_handles_zero_firestore_or_zero_algolia(self, mock_get_db, _mock_stats):
        from handlers.cron_jobs import monitor_algolia_sync

        # firestore_count == 0 branch
        count_query = Mock()
        count_query.get.return_value = [[Mock(value=0)]]
        products_query = Mock()
        products_query.count.return_value = count_query
        products_col = Mock()
        products_col.where.return_value = products_query

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col, Collections.SECURITY_ALERTS: Mock()}[name]
        mock_get_db.return_value = db
        monitor_algolia_sync(Mock())

        # algolia_count == 0 branch with non-zero firestore count
        count_query.get.return_value = [[Mock(value=10)]]
        monitor_algolia_sync(Mock())


class TestAdminGuardBranchesMore:
    def test_update_user_roles_requires_auth(self):
        from handlers.admin import update_user_roles

        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_roles(_req(None))
        assert exc.value.code == "unauthenticated"

    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_roles_rate_limit_and_validation(self, mock_rl):
        from handlers.admin import update_user_roles

        mock_rl.return_value.check_rate_limit.return_value = (False, "too many")
        with pytest.raises(https_fn.HttpsError) as limited:
            update_user_roles(_req("admin_1", {}))
        assert limited.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        with pytest.raises(https_fn.HttpsError) as missing_target:
            update_user_roles(_req("admin_1", {}))
        assert missing_target.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as invalid_arrays:
            update_user_roles(_req("admin_1", {Fields.TARGET_USER_ID: "u1", ApiKeys.ADD: "seller", ApiKeys.REMOVE: []}))
        assert invalid_arrays.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as invalid_role:
            update_user_roles(_req("admin_1", {Fields.TARGET_USER_ID: "u1", ApiKeys.ADD: ["invalid-role"], ApiKeys.REMOVE: []}))
        assert invalid_role.value.code == "invalid-argument"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.admin.get_db")
    @patch("handlers.admin.auth.set_custom_user_claims")
    def test_update_user_roles_admin_and_target_guard_paths(self, mock_set_claims, mock_get_db, mock_rl):
        from handlers.admin import update_user_roles

        mock_set_claims.return_value = None
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        admin_ref = Mock()
        target_ref = Mock()
        users_col = Mock()
        users_col.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else target_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.USERS: users_col, Collections.SECURITY_ALERTS: Mock()}[name]
        mock_get_db.return_value = db

        # Admin not found
        admin_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing_admin:
            update_user_roles(_req("admin_1", {Fields.TARGET_USER_ID: "target_1", ApiKeys.ADD: [], ApiKeys.REMOVE: []}))
        assert missing_admin.value.code == "not-found"

        # Cannot modify own roles
        admin_ref.get.return_value = _snap(_recent_admin_data(), exists=True)
        with pytest.raises(https_fn.HttpsError) as self_edit:
            update_user_roles(_req("admin_1", {Fields.TARGET_USER_ID: "admin_1", ApiKeys.ADD: [], ApiKeys.REMOVE: []}))
        assert self_edit.value.code == "permission-denied"

        # Target missing
        target_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as target_missing:
            update_user_roles(_req("admin_1", {Fields.TARGET_USER_ID: "target_1", ApiKeys.ADD: [], ApiKeys.REMOVE: []}))
        assert target_missing.value.code == "not-found"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.admin.get_db")
    @patch("handlers.admin.auth.set_custom_user_claims")
    def test_update_user_roles_readds_buyer_role_when_removed(self, mock_set_claims, mock_get_db, mock_rl):
        from handlers.admin import update_user_roles

        mock_set_claims.return_value = None
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        admin_ref = Mock()
        admin_ref.get.return_value = _snap(_recent_admin_data(), exists=True)

        target_ref = Mock()
        target_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, exists=True)

        users_col = Mock()
        users_col.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else target_ref
        alerts_col = Mock()

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SECURITY_ALERTS: alerts_col,
        }[name]
        mock_get_db.return_value = db

        out = update_user_roles(
            _req(
                "admin_1",
                {
                    Fields.TARGET_USER_ID: "target_1",
                    ApiKeys.ADD: [],
                    ApiKeys.REMOVE: [UserRoleValues.SELLER],
                },
            )
        )

        assert out["success"] is True
        updated_roles = target_ref.update.call_args.args[0][Fields.ROLES]
        assert UserRoleValues.BUYER in updated_roles

    def test_suspend_unsuspend_and_stock_update_require_auth(self):
        from handlers.admin import admin_update_product_stock, suspend_seller, unsuspend_seller

        for fn in (suspend_seller, unsuspend_seller, admin_update_product_stock):
            with pytest.raises(https_fn.HttpsError) as exc:
                fn(_req(None))
            assert exc.value.code == "unauthenticated"

    @patch("handlers.admin.RateLimiter")
    def test_suspend_unsuspend_and_stock_update_rate_limit(self, mock_rl):
        from handlers.admin import admin_update_product_stock, suspend_seller, unsuspend_seller

        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")

        with pytest.raises(https_fn.HttpsError) as suspend_limited:
            suspend_seller(_req("admin_1", {}))
        assert suspend_limited.value.code == "resource-exhausted"

        with pytest.raises(https_fn.HttpsError) as unsuspend_limited:
            unsuspend_seller(_req("admin_1", {}))
        assert unsuspend_limited.value.code == "resource-exhausted"

        with pytest.raises(https_fn.HttpsError) as stock_limited:
            admin_update_product_stock(_req("admin_1", {}))
        assert stock_limited.value.code == "resource-exhausted"

    @patch("handlers.admin.RateLimiter")
    @patch("handlers.admin.get_db")
    def test_suspend_unsuspend_and_stock_update_core_validation(self, mock_get_db, mock_rl):
        from handlers.admin import admin_update_product_stock, suspend_seller, unsuspend_seller

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        # Missing required args
        with pytest.raises(https_fn.HttpsError) as suspend_missing:
            suspend_seller(_req("admin_1", {}))
        assert suspend_missing.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as unsuspend_missing:
            unsuspend_seller(_req("admin_1", {}))
        assert unsuspend_missing.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as stock_missing:
            admin_update_product_stock(_req("admin_1", {Fields.PRODUCT_ID: ""}))
        assert stock_missing.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as stock_bad_qty:
            admin_update_product_stock(_req("admin_1", {Fields.PRODUCT_ID: "p1", Fields.STOCK_QUANTITY: -1}))
        assert stock_bad_qty.value.code == "invalid-argument"

        admin_ref = Mock()
        seller_ref = Mock()
        product_ref = Mock()

        users_col = Mock()
        users_col.document.side_effect = lambda uid: admin_ref if uid == "admin_1" else seller_ref
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.SECURITY_ALERTS: Mock(),
            Collections.ADMIN_LOGS: Mock(),
        }[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        # Admin not found
        admin_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as suspend_no_admin:
            suspend_seller(_req("admin_1", {Fields.SELLER_ID: "seller_1"}))
        assert suspend_no_admin.value.code == "not-found"

        with pytest.raises(https_fn.HttpsError) as unsuspend_no_admin:
            unsuspend_seller(_req("admin_1", {Fields.SELLER_ID: "seller_1"}))
        assert unsuspend_no_admin.value.code == "not-found"

        with pytest.raises(https_fn.HttpsError) as stock_no_admin:
            admin_update_product_stock(_req("admin_1", {Fields.PRODUCT_ID: "p1", Fields.STOCK_QUANTITY: 1}))
        assert stock_no_admin.value.code == "not-found"

        # Admin present but missing admin role
        admin_ref.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER], Fields.MFA_ENABLED: True, Fields.LAST_MFA_VERIFY: datetime.now(UTC)}, exists=True)
        with pytest.raises(https_fn.HttpsError) as suspend_role:
            suspend_seller(_req("admin_1", {Fields.SELLER_ID: "seller_1"}))
        assert suspend_role.value.code == "permission-denied"

        with pytest.raises(https_fn.HttpsError) as unsuspend_role:
            unsuspend_seller(_req("admin_1", {Fields.SELLER_ID: "seller_1"}))
        assert unsuspend_role.value.code == "permission-denied"

        with pytest.raises(https_fn.HttpsError) as stock_role:
            admin_update_product_stock(_req("admin_1", {Fields.PRODUCT_ID: "p1", Fields.STOCK_QUANTITY: 1}))
        assert stock_role.value.code == "permission-denied"

        # Valid admin + MFA then target/product checks
        admin_ref.get.return_value = _snap(_recent_admin_data(), exists=True)
        seller_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as seller_missing_suspend:
            suspend_seller(_req("admin_1", {Fields.SELLER_ID: "seller_1"}))
        assert seller_missing_suspend.value.code == "not-found"

        with pytest.raises(https_fn.HttpsError) as seller_missing_unsuspend:
            unsuspend_seller(_req("admin_1", {Fields.SELLER_ID: "seller_1"}))
        assert seller_missing_unsuspend.value.code == "not-found"

        product_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as product_missing:
            admin_update_product_stock(_req("admin_1", {Fields.PRODUCT_ID: "p1", Fields.STOCK_QUANTITY: 1}))
        assert product_missing.value.code == "not-found"
