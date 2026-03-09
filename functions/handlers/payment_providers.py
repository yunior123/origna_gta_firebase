"""
Payment Provider Management
============================
Admin controls for enabling/disabling payment providers.
Prevents payment operations when provider is disabled.

Collections:
- config/payment_providers: Global payment provider settings

Providers Supported:
- stripe: Stripe payment processing (ACTIVE at launch)
"""

import logging
from datetime import UTC, datetime, timedelta
from typing import Any, ClassVar

from firebase_functions import https_fn

from schema_constants import (
    AdminActionValues,
    ApiKeys,
    BusinessRules,
    Collections,
    Documents,
    Fields,
    PaymentProviderValues,
    RateLimitActions,
    SecurityAlertTypes,
    SeverityLevels,
    UserRoleValues,
)
from services.rate_limiter import RateLimiter
from utils.db import get_db, get_server_timestamp
from utils.function_options import DEFAULT_OPTIONS

logger = logging.getLogger(__name__)

# ============================================================================
# LAZY INITIALIZATION
# ============================================================================


def _is_provider_configured(provider: str) -> tuple:
    """
    Check if a payment provider has API keys configured.

    Returns:
        Tuple of (is_configured: bool, missing_keys: list)
    """
    if provider == PaymentProviderValues.STRIPE:
        from config import get_stripe_secret_key, get_stripe_webhook_secret

        missing = []
        if not get_stripe_secret_key():
            missing.append("STRIPE_SECRET_KEY")
        if not get_stripe_webhook_secret():
            missing.append("STRIPE_WEBHOOK_SECRET")
        return (len(missing) == 0, missing)

    return (False, ["Unknown provider"])


# ============================================================================
# PAYMENT PROVIDER CONSTANTS
# ============================================================================


class PaymentProvider:
    """Supported payment providers."""

    STRIPE: str = "stripe"
    ALL: ClassVar[list[str]] = [STRIPE]


# Default provider settings
DEFAULT_PROVIDER_CONFIG = {
    PaymentProvider.STRIPE: {
        ApiKeys.ENABLED: True,
        Fields.NAME: "Stripe",
        Fields.DESCRIPTION: "Primary payment processor",
        ApiKeys.SUPPORTED_CURRENCIES: ["CAD", "USD"],
        ApiKeys.SUPPORTED_COUNTRIES: ["CA", "US"],
        ApiKeys.FEATURES: ["cards", "apple_pay", "google_pay"],
    },
}


# ============================================================================
# UTILITY FUNCTIONS (Used by other handlers)
# ============================================================================


def is_provider_enabled(provider: str) -> bool:
    """
    Check if a payment provider is enabled.

    Args:
        provider: Provider name ("stripe")

    Returns:
        True if provider is enabled, False otherwise

    Usage:
        from handlers.payment_providers import is_provider_enabled, PaymentProvider

        if not is_provider_enabled(PaymentProvider.STRIPE):
            raise https_fn.HttpsError("failed-precondition", "Stripe payments are currently disabled")
    """
    if provider not in PaymentProvider.ALL:
        return False

    try:
        config_ref = get_db().collection(Collections.CONFIG).document(Documents.PAYMENT_PROVIDERS)
        config_doc = config_ref.get()

        if not config_doc.exists:
            # Return default value
            return DEFAULT_PROVIDER_CONFIG.get(provider, {}).get(ApiKeys.ENABLED, False)

        config_data = config_doc.to_dict()
        provider_config = config_data.get(provider, {})

        return provider_config.get(
            ApiKeys.ENABLED, DEFAULT_PROVIDER_CONFIG.get(provider, {}).get(ApiKeys.ENABLED, False)
        )

    except Exception as e:
        logger.error(f"Error checking provider status: {str(e)}")
        # Fail open for stripe (essential), closed for others
        return provider == PaymentProvider.STRIPE


def get_enabled_providers() -> list:
    """
    Get list of all enabled payment providers.

    Returns:
        List of enabled provider names
    """
    enabled = []

    try:
        config_ref = get_db().collection(Collections.CONFIG).document(Documents.PAYMENT_PROVIDERS)
        config_doc = config_ref.get()

        if not config_doc.exists:
            # Return defaults
            for provider, config in DEFAULT_PROVIDER_CONFIG.items():
                if config.get(ApiKeys.ENABLED, False):
                    enabled.append(provider)
            return enabled

        config_data = config_doc.to_dict()

        for provider in PaymentProvider.ALL:
            provider_config = config_data.get(provider, DEFAULT_PROVIDER_CONFIG.get(provider, {}))
            if provider_config.get(ApiKeys.ENABLED, False):
                enabled.append(provider)

        return enabled

    except Exception as e:
        logger.error(f"Error getting enabled providers: {str(e)}")
        # Default to stripe only
        return [PaymentProvider.STRIPE]


def require_provider_enabled(provider: str) -> None:
    """
    Raises an HttpsError if the provider is disabled.
    Use this at the start of payment functions.

    Args:
        provider: Provider name to check

    Raises:
        https_fn.HttpsError: If provider is disabled
    """
    if not is_provider_enabled(provider):
        provider_name = DEFAULT_PROVIDER_CONFIG.get(provider, {}).get(Fields.NAME, provider)
        raise https_fn.HttpsError(
            "failed-precondition", f"{provider_name} payments are currently disabled by administrator"
        )


# ============================================================================
# ADMIN HELPER
# ============================================================================


def _require_recent_mfa(admin_data: dict[str, Any]) -> None:
    """Require admin to have verified MFA within the last 5 minutes (same policy as admin.py)."""
    if not admin_data.get(Fields.MFA_ENABLED, False):
        raise https_fn.HttpsError(
            "failed-precondition", "Admin MFA is not enabled. Please enable MFA before performing sensitive operations."
        )
    last_mfa_verify = admin_data.get(Fields.LAST_MFA_VERIFY)
    if not last_mfa_verify:
        raise https_fn.HttpsError("permission-denied", "MFA verification required.")
    now = datetime.now(UTC)
    last_mfa_utc = last_mfa_verify.astimezone(UTC) if last_mfa_verify.tzinfo is not None else last_mfa_verify.replace(tzinfo=UTC)
    if (now - last_mfa_utc) > timedelta(minutes=BusinessRules.MFA_VERIFICATION_VALIDITY_MINUTES):
        raise https_fn.HttpsError("permission-denied", "MFA verification expired. Please verify again.")


def _require_admin(req: https_fn.CallableRequest) -> tuple:
    """
    Validates admin permissions.

    Returns:
        Tuple of (admin_id, admin_data)

    Raises:
        https_fn.HttpsError: If not authenticated or not admin
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    admin_id = req.auth.uid
    admin_ref = get_db().collection(Collections.USERS).document(admin_id)
    admin_doc = admin_ref.get()

    if not admin_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    admin_data = admin_doc.to_dict()

    if UserRoleValues.ADMIN not in admin_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    return admin_id, admin_data


# ============================================================================
# ADMIN FUNCTIONS
# ============================================================================


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_payment_providers(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Get all payment provider configurations (admin only).

    Returns:
        {
            success: True,
            providers: {
                stripe: { enabled: true, name: "Stripe", configured: true, ... },
            },
            enabledProviders: ["stripe"]
        }
    """
    admin_id, _ = _require_admin(req)

    # Rate limit: 30/min for admin reads
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=admin_id, action=RateLimitActions.GET_PAYMENT_PROVIDERS, max_requests=30, window_minutes=1, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    try:
        config_ref = get_db().collection(Collections.CONFIG).document(Documents.PAYMENT_PROVIDERS)
        config_doc = config_ref.get()

        config_data = {} if not config_doc.exists else config_doc.to_dict()

        # Merge with defaults for any missing providers
        providers = {}
        for provider in PaymentProvider.ALL:
            default = DEFAULT_PROVIDER_CONFIG.get(provider, {})
            stored = config_data.get(provider, {})
            is_configured, missing_keys = _is_provider_configured(provider)
            providers[provider] = {
                **default,
                **stored,
                ApiKeys.CONFIGURED: is_configured,
                ApiKeys.MISSING_KEYS: missing_keys if not is_configured else [],
            }

        # Return dict directly for on_call functions (not Response object)
        return {ApiKeys.SUCCESS: True, ApiKeys.PROVIDERS: providers, ApiKeys.ENABLED_PROVIDERS: get_enabled_providers()}

    except Exception as e:
        logger.error(f"get_payment_providers error: {str(e)}")
        raise https_fn.HttpsError("internal", "Failed to get provider config") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def update_payment_provider(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Enable or disable a payment provider (admin only).

    Request data:
        provider: Provider name ("stripe")
        enabled: Boolean - whether to enable the provider
        reason: Optional string - reason for the change (logged)

    Returns:
        {success: True, provider: "stripe", enabled: true}
    """
    admin_id, admin_data = _require_admin(req)

    # MFA check — required for all destructive payment configuration changes
    _require_recent_mfa(admin_data)
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=admin_id, action=RateLimitActions.UPDATE_PAYMENT_PROVIDER, max_requests=5, window_minutes=1, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    provider = req.data.get(ApiKeys.PROVIDER)
    enabled = req.data.get(ApiKeys.ENABLED)
    reason = req.data.get(ApiKeys.REASON, "")

    # Validate inputs
    if provider not in PaymentProvider.ALL:
        raise https_fn.HttpsError(
            "invalid-argument", f"Invalid provider. Must be one of: {', '.join(PaymentProvider.ALL)}"
        )

    if not isinstance(enabled, bool):
        raise https_fn.HttpsError("invalid-argument", "enabled must be a boolean")

    # If enabling, check that API keys are configured
    if enabled:
        is_configured, missing_keys = _is_provider_configured(provider)
        if not is_configured:
            provider_name = DEFAULT_PROVIDER_CONFIG.get(provider, {}).get(Fields.NAME, provider)
            raise https_fn.HttpsError(
                "failed-precondition",
                f"{provider_name} is not configured. Missing API keys: {', '.join(missing_keys)}. "
                f"Please configure the {provider_name} account first.",
            )

    # Safety check: don't allow disabling all providers
    if not enabled:
        current_enabled = get_enabled_providers()
        remaining = [p for p in current_enabled if p != provider]

        if len(remaining) == 0:
            raise https_fn.HttpsError(
                "failed-precondition", "Cannot disable all payment providers. At least one must remain enabled."
            )

        # Block disabling a provider that has active authorized (captured-pending) orders.
        # Orders with AUTHORIZED or CAPTURING status will be stranded if the provider is
        # disabled — capture_payment() calls require_provider_enabled() before processing.
        # All pending authorizations must expire or be captured first.
        from schema_constants import PaymentStatusValues as PSV

        active_orders = (
            get_db()
            .collection(Collections.ORDERS)
            .where(Fields.PAYMENT_PROVIDER, "==", provider)
            .where(Fields.PAYMENT_STATUS, "in", [PSV.AUTHORIZED, PSV.CAPTURING])
            .limit(1)
            .get()
        )

        if len(active_orders) > 0:
            raise https_fn.HttpsError(
                "failed-precondition",
                f"Cannot disable {provider}: there are orders with active authorizations. "
                f"Wait for all pending orders to be captured or expired before disabling.",
            )

    try:
        config_ref = get_db().collection(Collections.CONFIG).document(Documents.PAYMENT_PROVIDERS)

        # Get current config or use defaults
        config_doc = config_ref.get()

        config_data = dict(DEFAULT_PROVIDER_CONFIG) if not config_doc.exists else config_doc.to_dict()

        # Update the provider
        if provider not in config_data:
            config_data[provider] = dict(DEFAULT_PROVIDER_CONFIG.get(provider, {}))

        old_enabled = config_data[provider].get(ApiKeys.ENABLED, False)
        config_data[provider][ApiKeys.ENABLED] = enabled
        config_data[provider][Fields.UPDATED_AT] = get_server_timestamp()
        config_data[provider][Fields.UPDATED_BY] = admin_id

        # Save config
        config_ref.set(config_data, merge=True)

        # Log the change
        get_db().collection(Collections.ADMIN_LOGS).add(
            {
                Fields.ACTION: AdminActionValues.PAYMENT_PROVIDER_UPDATE,
                Fields.ADMIN_ID: admin_id,
                Fields.PROVIDER: provider,
                Fields.OLD_ENABLED: old_enabled,
                Fields.NEW_ENABLED: enabled,
                Fields.REASON: reason[:500] if reason else "",  # Limit reason length
                Fields.TIMESTAMP: get_server_timestamp(),
            }
        )

        # Log security alert if disabling
        if old_enabled and not enabled:
            get_db().collection(Collections.SECURITY_ALERTS).add(
                {
                    Fields.TYPE: SecurityAlertTypes.PAYMENT_PROVIDER_DISABLED,
                    Fields.SEVERITY: SeverityLevels.HIGH,
                    Fields.ADMIN_ID: admin_id,
                    Fields.PROVIDER: provider,
                    Fields.REASON: reason[:500] if reason else "",
                    Fields.TIMESTAMP: get_server_timestamp(),
                    Fields.RESOLVED: True,
                }
            )

        # Return dict directly for on_call functions (not Response object)
        return {
            ApiKeys.SUCCESS: True,
            ApiKeys.PROVIDER: provider,
            ApiKeys.ENABLED: enabled,
            ApiKeys.PROVIDER_NAME: DEFAULT_PROVIDER_CONFIG.get(provider, {}).get(Fields.NAME, provider),
        }

    except https_fn.HttpsError:
        raise
    except Exception as e:
        logger.error(f"update_payment_provider error: {str(e)}")
        raise https_fn.HttpsError("internal", "Failed to update provider") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_provider_status(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Get status of enabled payment providers (public - for payment UI).
    Only returns enabled/disabled status, not full config.

    Returns:
        {
            success: True,
            providers: {
                stripe: { enabled: true, name: "Stripe" },
            }
        }
    """
    # This can be called by any authenticated user
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    # Rate limit: 30/min per user (anti-scraping)
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=req.auth.uid, action=RateLimitActions.GET_PROVIDER_STATUS, max_requests=30, window_minutes=1, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    try:
        providers = {}

        for provider in PaymentProvider.ALL:
            default = DEFAULT_PROVIDER_CONFIG.get(provider, {})
            is_configured, _ = _is_provider_configured(provider)
            providers[provider] = {
                ApiKeys.ENABLED: is_provider_enabled(provider),
                ApiKeys.CONFIGURED: is_configured,
                Fields.NAME: default.get(Fields.NAME, provider),
                ApiKeys.FEATURES: default.get(ApiKeys.FEATURES, []),
            }

        # Return dict directly for on_call functions (not Response object)
        return {ApiKeys.SUCCESS: True, ApiKeys.PROVIDERS: providers}

    except Exception as e:
        logger.error(f"get_provider_status error: {str(e)}")
        raise https_fn.HttpsError("internal", "Failed to get provider status") from e
