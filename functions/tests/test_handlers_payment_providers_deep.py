from datetime import UTC, datetime
from unittest.mock import MagicMock, Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import Collections, Fields, UserRoleValues


def _admin_req(data: dict | None = None):
    req = Mock()
    req.auth = Mock()
    req.auth.uid = "admin_123"
    req.data = data or {}
    return req


def _admin_doc(*, mfa_enabled: bool = True, last_mfa_verify: datetime | None = None):
    doc = Mock()
    doc.exists = True
    doc.to_dict.return_value = {
        Fields.ROLES: [UserRoleValues.ADMIN],
        Fields.MFA_ENABLED: mfa_enabled,
        Fields.LAST_MFA_VERIFY: last_mfa_verify,
    }
    return doc


class TestProviderHelpersDeep:
    @patch("config.get_stripe_secret_key", return_value="")
    @patch("config.get_stripe_webhook_secret", return_value="")
    def test_is_provider_configured_reports_missing_stripe_keys(self, _mock_webhook, _mock_secret):
        from handlers.payment_providers import _is_provider_configured

        configured, missing = _is_provider_configured("stripe")
        assert configured is False
        assert "STRIPE_SECRET_KEY" in missing
        assert "STRIPE_WEBHOOK_SECRET" in missing

    def test_is_provider_configured_unknown_provider(self):
        from handlers.payment_providers import _is_provider_configured

        configured, missing = _is_provider_configured("unknown")
        assert configured is False
        assert missing == ["Unknown provider"]

    def test_require_recent_mfa_rejects_when_not_enabled(self):
        from handlers.payment_providers import _require_recent_mfa

        with pytest.raises(https_fn.HttpsError) as exc:
            _require_recent_mfa({Fields.MFA_ENABLED: False})
        assert exc.value.code == "failed-precondition"

    def test_require_recent_mfa_rejects_when_timestamp_missing(self):
        from handlers.payment_providers import _require_recent_mfa

        with pytest.raises(https_fn.HttpsError) as exc:
            _require_recent_mfa({Fields.MFA_ENABLED: True, Fields.LAST_MFA_VERIFY: None})
        assert exc.value.code == "permission-denied"

    def test_require_admin_rejects_unauthenticated(self):
        from handlers.payment_providers import _require_admin

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            _require_admin(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.payment_providers.get_db")
    def test_require_admin_rejects_missing_user(self, mock_get_db):
        from handlers.payment_providers import _require_admin

        doc = MagicMock()
        doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc

        with pytest.raises(https_fn.HttpsError) as exc:
            _require_admin(_admin_req())
        assert exc.value.code == "not-found"

    @patch("handlers.payment_providers.get_db")
    def test_get_enabled_providers_reads_enabled_flag_from_config(self, mock_get_db):
        from handlers.payment_providers import get_enabled_providers

        db = MagicMock()
        mock_get_db.return_value = db
        config_doc = MagicMock()
        config_doc.exists = True
        config_doc.to_dict.return_value = {"stripe": {"enabled": True}}
        db.collection.return_value.document.return_value.get.return_value = config_doc

        enabled = get_enabled_providers()
        assert enabled == ["stripe"]


class TestGetPaymentProvidersDeep:
    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.RateLimiter")
    def test_get_payment_providers_rate_limited(self, mock_rl_cls, mock_get_db):
        from handlers.payment_providers import get_payment_providers

        mock_rl_cls.return_value.check_rate_limit.return_value = (False, "limited")
        db = MagicMock()
        mock_get_db.return_value = db
        db.collection.return_value.document.return_value.get.return_value = _admin_doc(
            last_mfa_verify=datetime.now(UTC)
        )

        with pytest.raises(https_fn.HttpsError) as exc:
            get_payment_providers(_admin_req())
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.RateLimiter")
    def test_get_payment_providers_maps_internal_errors(self, mock_rl_cls, mock_get_db):
        from handlers.payment_providers import get_payment_providers

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = MagicMock()
        mock_get_db.return_value = db

        admin_doc = _admin_doc(last_mfa_verify=datetime.now(UTC))

        def collection_side_effect(name):
            c = MagicMock()
            if name == Collections.USERS:
                c.document.return_value.get.return_value = admin_doc
            elif name == Collections.CONFIG:
                c.document.return_value.get.side_effect = RuntimeError("firestore down")
            return c

        db.collection.side_effect = collection_side_effect

        with pytest.raises(https_fn.HttpsError) as exc:
            get_payment_providers(_admin_req())
        assert exc.value.code == "internal"


class TestUpdatePaymentProviderDeep:
    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.RateLimiter")
    def test_update_payment_provider_rate_limited(self, mock_rl_cls, mock_get_db):
        from handlers.payment_providers import update_payment_provider

        mock_rl_cls.return_value.check_rate_limit.return_value = (False, "limited")
        db = MagicMock()
        mock_get_db.return_value = db
        admin_doc = _admin_doc(last_mfa_verify=datetime.now(UTC))
        db.collection.return_value.document.return_value.get.return_value = admin_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            update_payment_provider(_admin_req({"provider": "stripe", "enabled": True}))
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.RateLimiter")
    def test_update_payment_provider_requires_boolean_enabled(self, mock_rl_cls, mock_get_db):
        from handlers.payment_providers import update_payment_provider

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = MagicMock()
        mock_get_db.return_value = db
        admin_doc = _admin_doc(last_mfa_verify=datetime.now(UTC))
        db.collection.return_value.document.return_value.get.return_value = admin_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            update_payment_provider(_admin_req({"provider": "stripe", "enabled": "yes"}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.RateLimiter")
    @patch("handlers.payment_providers._is_provider_configured", return_value=(False, ["STRIPE_SECRET_KEY"]))
    def test_update_payment_provider_rejects_enable_when_not_configured(
        self,
        _mock_configured,
        mock_rl_cls,
        mock_get_db,
    ):
        from handlers.payment_providers import update_payment_provider

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = MagicMock()
        mock_get_db.return_value = db
        admin_doc = _admin_doc(last_mfa_verify=datetime.now(UTC))
        db.collection.return_value.document.return_value.get.return_value = admin_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            update_payment_provider(_admin_req({"provider": "stripe", "enabled": True}))
        assert exc.value.code == "failed-precondition"

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.get_enabled_providers", return_value=["stripe", "other"])
    @patch("handlers.payment_providers.RateLimiter")
    def test_update_payment_provider_disable_success_logs_admin_and_security_alerts(
        self,
        mock_rl_cls,
        _mock_enabled_providers,
        mock_get_db,
    ):
        from handlers.payment_providers import update_payment_provider

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = MagicMock()
        mock_get_db.return_value = db

        admin_doc = _admin_doc(last_mfa_verify=datetime.now(UTC))
        config_doc = MagicMock()
        config_doc.exists = True
        config_doc.to_dict.return_value = {"stripe": {"enabled": True}}
        no_active_orders = []

        admin_logs_col = MagicMock()
        security_alerts_col = MagicMock()
        config_col = MagicMock()
        config_ref = MagicMock()
        config_ref.get.return_value = config_doc
        config_col.document.return_value = config_ref

        orders_col = MagicMock()
        orders_q = MagicMock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.get.return_value = no_active_orders
        orders_col.where.return_value = orders_q

        users_col = MagicMock()
        users_col.document.return_value.get.return_value = admin_doc

        def collection_side_effect(name):
            if name == Collections.USERS:
                return users_col
            if name == Collections.ORDERS:
                return orders_col
            if name == Collections.CONFIG:
                return config_col
            if name == Collections.ADMIN_LOGS:
                return admin_logs_col
            if name == Collections.SECURITY_ALERTS:
                return security_alerts_col
            return MagicMock()

        db.collection.side_effect = collection_side_effect

        result = update_payment_provider(
            _admin_req({"provider": "stripe", "enabled": False, "reason": "maintenance window"})
        )
        assert result["success"] is True
        assert result["provider"] == "stripe"
        assert result["enabled"] is False
        config_ref.set.assert_called_once()
        admin_logs_col.add.assert_called_once()
        security_alerts_col.add.assert_called_once()

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.get_enabled_providers", return_value=["stripe", "other"])
    @patch("handlers.payment_providers.RateLimiter")
    def test_update_payment_provider_maps_internal_errors(self, mock_rl_cls, _mock_enabled, mock_get_db):
        from handlers.payment_providers import update_payment_provider

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = MagicMock()
        mock_get_db.return_value = db

        admin_doc = _admin_doc(last_mfa_verify=datetime.now(UTC))
        config_doc = MagicMock()
        config_doc.exists = True
        config_doc.to_dict.return_value = {"stripe": {"enabled": True}}

        config_ref = MagicMock()
        config_ref.get.return_value = config_doc
        config_ref.set.side_effect = RuntimeError("write failed")

        users_col = MagicMock()
        users_col.document.return_value.get.return_value = admin_doc
        config_col = MagicMock()
        config_col.document.return_value = config_ref
        orders_col = MagicMock()
        orders_q = MagicMock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.get.return_value = []
        orders_col.where.return_value = orders_q

        def collection_side_effect(name):
            if name == Collections.USERS:
                return users_col
            if name == Collections.CONFIG:
                return config_col
            if name == Collections.ORDERS:
                return orders_col
            return MagicMock()

        db.collection.side_effect = collection_side_effect

        with pytest.raises(https_fn.HttpsError) as exc:
            update_payment_provider(_admin_req({"provider": "stripe", "enabled": False}))
        assert exc.value.code == "internal"

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.get_enabled_providers", return_value=["stripe", "other"])
    @patch("handlers.payment_providers.RateLimiter")
    def test_update_payment_provider_initializes_missing_provider_config(
        self,
        mock_rl_cls,
        _mock_enabled,
        mock_get_db,
    ):
        from handlers.payment_providers import update_payment_provider

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = MagicMock()
        mock_get_db.return_value = db

        admin_doc = _admin_doc(last_mfa_verify=datetime.now(UTC))
        config_doc = MagicMock()
        config_doc.exists = True
        config_doc.to_dict.return_value = {}  # triggers provider bootstrap path

        users_col = MagicMock()
        users_col.document.return_value.get.return_value = admin_doc
        config_ref = MagicMock()
        config_ref.get.return_value = config_doc
        config_col = MagicMock()
        config_col.document.return_value = config_ref
        orders_col = MagicMock()
        orders_q = MagicMock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.get.return_value = []
        orders_col.where.return_value = orders_q

        def collection_side_effect(name):
            if name == Collections.USERS:
                return users_col
            if name == Collections.CONFIG:
                return config_col
            if name == Collections.ORDERS:
                return orders_col
            return MagicMock()

        db.collection.side_effect = collection_side_effect

        result = update_payment_provider(_admin_req({"provider": "stripe", "enabled": False}))
        assert result["success"] is True
        payload = config_ref.set.call_args.args[0]
        assert "stripe" in payload

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.get_enabled_providers", return_value=["stripe", "other"])
    @patch("handlers.payment_providers.RateLimiter")
    def test_update_payment_provider_reraises_https_error_from_try_block(self, mock_rl_cls, _mock_enabled, mock_get_db):
        from handlers.payment_providers import update_payment_provider

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        db = MagicMock()
        mock_get_db.return_value = db

        admin_doc = _admin_doc(last_mfa_verify=datetime.now(UTC))
        config_doc = MagicMock()
        config_doc.exists = True
        config_doc.to_dict.return_value = {"stripe": {"enabled": True}}

        users_col = MagicMock()
        users_col.document.return_value.get.return_value = admin_doc
        config_ref = MagicMock()
        config_ref.get.return_value = config_doc
        config_ref.set.side_effect = https_fn.HttpsError("internal", "boom")
        config_col = MagicMock()
        config_col.document.return_value = config_ref
        orders_col = MagicMock()
        orders_q = MagicMock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.get.return_value = []
        orders_col.where.return_value = orders_q

        def collection_side_effect(name):
            if name == Collections.USERS:
                return users_col
            if name == Collections.CONFIG:
                return config_col
            if name == Collections.ORDERS:
                return orders_col
            return MagicMock()

        db.collection.side_effect = collection_side_effect

        with pytest.raises(https_fn.HttpsError) as exc:
            update_payment_provider(_admin_req({"provider": "stripe", "enabled": False}))
        assert exc.value.code == "internal"


class TestGetProviderStatusDeep:
    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.RateLimiter")
    @patch("handlers.payment_providers._is_provider_configured", side_effect=RuntimeError("secret error"))
    def test_get_provider_status_maps_internal_errors(self, _mock_configured, mock_rl_cls, mock_get_db):
        from handlers.payment_providers import get_provider_status

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        mock_get_db.return_value = MagicMock()

        req = Mock()
        req.auth = Mock()
        req.auth.uid = "buyer_123"
        req.data = {}

        with pytest.raises(https_fn.HttpsError) as exc:
            get_provider_status(req)
        assert exc.value.code == "internal"
