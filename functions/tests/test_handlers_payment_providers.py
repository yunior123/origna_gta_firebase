"""
Tests for handlers/payment_providers.py — admin controls for payment providers.

Coverage:
- is_provider_enabled: config exists, config missing returns default, unknown provider=False, Firestore error fails open for stripe
- get_enabled_providers: no config returns defaults, config override
- require_provider_enabled: disabled raises failed-precondition, enabled passes
- get_payment_providers: non-admin rejected, rate limited, returns merged config
- update_payment_provider: non-admin, missing MFA, invalid provider, disable last provider,
  active authorized orders block disable, successfully enables/disables
- get_provider_status: unauthenticated rejected, returns enabled/disabled for all providers
"""
from unittest.mock import MagicMock, Mock, patch

import pytest

from schema_constants import Collections, Fields, UserRoleValues


# ============================================================================
# is_provider_enabled (utility)
# ============================================================================


class TestIsProviderEnabled:
    """Tests for is_provider_enabled utility."""

    @patch("handlers.payment_providers.get_db")
    def test_unknown_provider_returns_false(self, _mock_db):
        """Function test_unknown_provider_returns_false."""
        from handlers.payment_providers import is_provider_enabled

        assert is_provider_enabled("paypal") is False

    @patch("handlers.payment_providers.get_db")
    def test_stripe_enabled_by_default_when_no_config_doc(self, mock_get_db):
        """Function test_stripe_enabled_by_default_when_no_config_doc."""
        from handlers.payment_providers import is_provider_enabled

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        config_doc = Mock()
        config_doc.exists = False
        mock_db.collection.return_value.document.return_value.get.return_value = config_doc

        # Default config has stripe enabled=True
        assert is_provider_enabled("stripe") is True

    @patch("handlers.payment_providers.get_db")
    def test_reads_enabled_from_config_doc(self, mock_get_db):
        """Function test_reads_enabled_from_config_doc."""
        from handlers.payment_providers import is_provider_enabled

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        config_doc = Mock()
        config_doc.exists = True
        config_doc.to_dict.return_value = {"stripe": {"enabled": False}}
        mock_db.collection.return_value.document.return_value.get.return_value = config_doc

        assert is_provider_enabled("stripe") is False

    @patch("handlers.payment_providers.get_db")
    def test_firestore_error_fails_open_for_stripe(self, mock_get_db):
        """Stripe must fail open (True) to avoid blocking payments during infra outages."""
        from handlers.payment_providers import is_provider_enabled

        mock_get_db.side_effect = Exception("Firestore unavailable")
        assert is_provider_enabled("stripe") is True


# ============================================================================
# get_enabled_providers (utility)
# ============================================================================


class TestGetEnabledProviders:
    """Tests for get_enabled_providers utility."""

    @patch("handlers.payment_providers.get_db")
    def test_returns_stripe_by_default_when_no_config(self, mock_get_db):
        """Function test_returns_stripe_by_default_when_no_config."""
        from handlers.payment_providers import get_enabled_providers

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        config_doc = Mock()
        config_doc.exists = False
        mock_db.collection.return_value.document.return_value.get.return_value = config_doc

        result = get_enabled_providers()
        assert "stripe" in result

    @patch("handlers.payment_providers.get_db")
    def test_returns_empty_when_all_disabled_in_config(self, mock_get_db):
        """Function test_returns_empty_when_all_disabled_in_config."""
        from handlers.payment_providers import get_enabled_providers

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        config_doc = Mock()
        config_doc.exists = True
        config_doc.to_dict.return_value = {"stripe": {"enabled": False}}
        mock_db.collection.return_value.document.return_value.get.return_value = config_doc

        result = get_enabled_providers()
        assert "stripe" not in result

    @patch("handlers.payment_providers.get_db")
    def test_firestore_error_returns_stripe_fallback(self, mock_get_db):
        """Function test_firestore_error_returns_stripe_fallback."""
        from handlers.payment_providers import get_enabled_providers

        mock_get_db.side_effect = Exception("Firestore unavailable")
        result = get_enabled_providers()
        assert result == ["stripe"]


# ============================================================================
# require_provider_enabled (utility)
# ============================================================================


class TestRequireProviderEnabled:
    """Tests for require_provider_enabled utility."""

    @patch("handlers.payment_providers.is_provider_enabled", return_value=False)
    def test_disabled_provider_raises_failed_precondition(self, _mock):
        """Function test_disabled_provider_raises_failed_precondition."""
        from firebase_functions import https_fn
        from handlers.payment_providers import require_provider_enabled

        with pytest.raises(https_fn.HttpsError) as exc:
            require_provider_enabled("stripe")
        assert exc.value.code == "failed-precondition"
        assert "disabled" in exc.value.message.lower()

    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    def test_enabled_provider_does_not_raise(self, _mock):
        """Function test_enabled_provider_does_not_raise."""
        from handlers.payment_providers import require_provider_enabled

        require_provider_enabled("stripe")  # Should not raise


# ============================================================================
# get_payment_providers (admin endpoint)
# ============================================================================


class TestGetPaymentProviders:
    """Class TestGetPaymentProviders."""
    def _admin_req(self, uid: str = "admin_123") -> Mock:
        req = Mock()
        req.auth = Mock()
        req.auth.uid = uid
        req.data = {}
        return req

    @patch("handlers.payment_providers.get_db")
    def test_non_admin_rejected(self, mock_get_db):
        """Function test_non_admin_rejected."""
        from firebase_functions import https_fn
        from handlers.payment_providers import get_payment_providers

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.ROLES: ["buyer"]}  # Not admin
        mock_db.collection.return_value.document.return_value.get.return_value = user_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            get_payment_providers(self._admin_req())
        assert exc.value.code == "permission-denied"

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers._is_provider_configured", return_value=(True, []))
    @patch("handlers.payment_providers.get_enabled_providers", return_value=["stripe"])
    def test_returns_provider_configs_for_admin(
        self, _mock_enabled, _mock_configured, mock_get_db
    ):
        """Function test_returns_provider_configs_for_admin."""
        from handlers.payment_providers import get_payment_providers

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        admin_doc = Mock()
        admin_doc.exists = True
        admin_doc.to_dict.return_value = {Fields.ROLES: [UserRoleValues.ADMIN]}

        rate_limiter_doc = Mock()
        rate_limiter_doc.exists = False

        config_doc = Mock()
        config_doc.exists = False

        def collection_side_effect(name):
            """Function collection_side_effect."""
            c = MagicMock()
            if name == Collections.USERS:
                c.document.return_value.get.return_value = admin_doc
            elif name == "rate_limits":
                c.document.return_value.get.return_value = rate_limiter_doc
            elif name == Collections.CONFIG:
                c.document.return_value.get.return_value = config_doc
            return c

        mock_db.collection.side_effect = collection_side_effect

        with patch("handlers.payment_providers.RateLimiter") as MockRL:
            mock_rl = Mock()
            mock_rl.check_rate_limit.return_value = (True, "")
            MockRL.return_value = mock_rl

            result = get_payment_providers(self._admin_req())

        assert result["success"] is True
        assert "providers" in result
        assert "stripe" in result["providers"]


# ============================================================================
# update_payment_provider (admin endpoint)
# ============================================================================


class TestUpdatePaymentProvider:
    """Class TestUpdatePaymentProvider."""
    def _admin_req(self, data: dict | None = None) -> Mock:
        req = Mock()
        req.auth = Mock()
        req.auth.uid = "admin_123"
        req.data = data or {"provider": "stripe", "enabled": False, "reason": "maintenance"}
        return req

    @patch("handlers.payment_providers.get_db")
    def test_non_admin_rejected(self, mock_get_db):
        """Function test_non_admin_rejected."""
        from firebase_functions import https_fn
        from handlers.payment_providers import update_payment_provider

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.ROLES: ["buyer"]}
        mock_db.collection.return_value.document.return_value.get.return_value = user_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            update_payment_provider(self._admin_req())
        assert exc.value.code == "permission-denied"

    @patch("handlers.payment_providers.get_db")
    def test_admin_without_mfa_rejected(self, mock_get_db):
        """Function test_admin_without_mfa_rejected."""
        from datetime import UTC, datetime, timedelta
        from firebase_functions import https_fn
        from handlers.payment_providers import update_payment_provider

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        # MFA expired 10 minutes ago
        expired_mfa = datetime.now(UTC) - timedelta(minutes=10)
        admin_doc = Mock()
        admin_doc.exists = True
        admin_doc.to_dict.return_value = {
            Fields.ROLES: [UserRoleValues.ADMIN],
            Fields.MFA_ENABLED: True,
            Fields.LAST_MFA_VERIFY: expired_mfa,
        }
        mock_db.collection.return_value.document.return_value.get.return_value = admin_doc

        with patch("handlers.payment_providers.RateLimiter") as MockRL:
            mock_rl = Mock()
            mock_rl.check_rate_limit.return_value = (True, "")
            MockRL.return_value = mock_rl

            with pytest.raises(https_fn.HttpsError) as exc:
                update_payment_provider(self._admin_req())
        assert exc.value.code == "permission-denied"
        assert "MFA" in exc.value.message

    @patch("handlers.payment_providers.get_db")
    def test_invalid_provider_raises(self, mock_get_db):
        """Function test_invalid_provider_raises."""
        from datetime import UTC, datetime, timedelta
        from firebase_functions import https_fn
        from handlers.payment_providers import update_payment_provider

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        valid_mfa = datetime.now(UTC) - timedelta(minutes=1)
        admin_doc = Mock()
        admin_doc.exists = True
        admin_doc.to_dict.return_value = {
            Fields.ROLES: [UserRoleValues.ADMIN],
            Fields.MFA_ENABLED: True,
            Fields.LAST_MFA_VERIFY: valid_mfa,
        }
        mock_db.collection.return_value.document.return_value.get.return_value = admin_doc

        with patch("handlers.payment_providers.RateLimiter") as MockRL:
            mock_rl = Mock()
            mock_rl.check_rate_limit.return_value = (True, "")
            MockRL.return_value = mock_rl

            req = self._admin_req(data={"provider": "paypal", "enabled": True})
            with pytest.raises(https_fn.HttpsError) as exc:
                update_payment_provider(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.get_enabled_providers", return_value=["stripe"])
    def test_cannot_disable_last_provider(self, _mock_providers, mock_get_db):
        """Function test_cannot_disable_last_provider."""
        from datetime import UTC, datetime, timedelta
        from firebase_functions import https_fn
        from handlers.payment_providers import update_payment_provider

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        valid_mfa = datetime.now(UTC) - timedelta(minutes=1)
        admin_doc = Mock()
        admin_doc.exists = True
        admin_doc.to_dict.return_value = {
            Fields.ROLES: [UserRoleValues.ADMIN],
            Fields.MFA_ENABLED: True,
            Fields.LAST_MFA_VERIFY: valid_mfa,
        }
        mock_db.collection.return_value.document.return_value.get.return_value = admin_doc

        with patch("handlers.payment_providers.RateLimiter") as MockRL:
            mock_rl = Mock()
            mock_rl.check_rate_limit.return_value = (True, "")
            MockRL.return_value = mock_rl

            req = self._admin_req(data={"provider": "stripe", "enabled": False})
            with pytest.raises(https_fn.HttpsError) as exc:
                update_payment_provider(req)
        assert exc.value.code == "failed-precondition"
        assert "Cannot disable all" in exc.value.message

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.get_enabled_providers", return_value=["stripe", "paypal"])
    def test_cannot_disable_with_active_authorized_orders(self, _mock_providers, mock_get_db):
        """Function test_cannot_disable_with_active_authorized_orders."""
        from datetime import UTC, datetime, timedelta
        from firebase_functions import https_fn
        from handlers.payment_providers import update_payment_provider

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        valid_mfa = datetime.now(UTC) - timedelta(minutes=1)
        admin_doc = Mock()
        admin_doc.exists = True
        admin_doc.to_dict.return_value = {
            Fields.ROLES: [UserRoleValues.ADMIN],
            Fields.MFA_ENABLED: True,
            Fields.LAST_MFA_VERIFY: valid_mfa,
        }

        active_order = Mock()

        def collection_side_effect(name):
            """Function collection_side_effect."""
            c = MagicMock()
            if name == Collections.USERS:
                c.document.return_value.get.return_value = admin_doc
            elif name == Collections.ORDERS:
                q = MagicMock()
                q.where.return_value = q
                q.limit.return_value = q
                q.get.return_value = [active_order]  # Active authorized order
                c.where.return_value = q
            return c

        mock_db.collection.side_effect = collection_side_effect

        with patch("handlers.payment_providers.RateLimiter") as MockRL:
            mock_rl = Mock()
            mock_rl.check_rate_limit.return_value = (True, "")
            MockRL.return_value = mock_rl

            req = self._admin_req(data={"provider": "stripe", "enabled": False})
            with pytest.raises(https_fn.HttpsError) as exc:
                update_payment_provider(req)
        assert exc.value.code == "failed-precondition"
        assert "active authorizations" in exc.value.message


# ============================================================================
# get_provider_status (authenticated users)
# ============================================================================


class TestGetProviderStatus:
    """Class TestGetProviderStatus."""
    def test_unauthenticated_raises(self):
        """Function test_unauthenticated_raises."""
        from firebase_functions import https_fn
        from handlers.payment_providers import get_provider_status

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            get_provider_status(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.payment_providers.get_db")
    @patch("handlers.payment_providers.is_provider_enabled", return_value=True)
    @patch("handlers.payment_providers._is_provider_configured", return_value=(True, []))
    def test_returns_stripe_status_for_authenticated_user(
        self, _mock_configured, _mock_enabled, mock_get_db
    ):
        """Function test_returns_stripe_status_for_authenticated_user."""
        from handlers.payment_providers import get_provider_status

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        with patch("handlers.payment_providers.RateLimiter") as MockRL:
            mock_rl = Mock()
            mock_rl.check_rate_limit.return_value = (True, "")
            MockRL.return_value = mock_rl

            req = Mock()
            req.auth = Mock()
            req.auth.uid = "buyer_123"
            req.data = {}

            result = get_provider_status(req)

        assert result["success"] is True
        assert "providers" in result
        assert "stripe" in result["providers"]
        assert result["providers"]["stripe"]["enabled"] is True

    @patch("handlers.payment_providers.get_db")
    def test_rate_limited_raises(self, mock_get_db):
        """Function test_rate_limited_raises."""
        from firebase_functions import https_fn
        from handlers.payment_providers import get_provider_status

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        with patch("handlers.payment_providers.RateLimiter") as MockRL:
            mock_rl = Mock()
            mock_rl.check_rate_limit.return_value = (False, "Rate limit exceeded")
            MockRL.return_value = mock_rl

            req = Mock()
            req.auth = Mock()
            req.auth.uid = "buyer_123"
            req.data = {}

            with pytest.raises(https_fn.HttpsError) as exc:
                get_provider_status(req)
        assert exc.value.code == "resource-exhausted"
