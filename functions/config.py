"""
Configuration Management for OrignaGTA Firebase Functions
==========================================================

ENVIRONMENT MODES:
- EMULATOR (Micro-Staging): Firebase Emulator only. External services (R2, Stripe, Algolia) are REAL.
- PRODUCTION: Firebase Cloud. All services are production.

WHAT'S EMULATED (Local):
- Firebase Auth (port 9099)
- Firestore (port 8080)
- Firebase Functions (port 5001)
- Firebase Storage (port 9199)

WHAT'S REAL (Even in Emulator Mode):
- Cloudflare R2 → Uses emulator/ folder prefix to separate test data
- Stripe → Uses test keys (sk_test_*) - real API, test mode
- Algolia → Uses products_emulator index to separate test data
- Mailjet, Geoapify → Real APIs

DETECTION:
- Emulator: FUNCTIONS_EMULATOR='true' (set by Firebase emulator automatically)
- Production: FUNCTIONS_EMULATOR='false' or not set (default in cloud deployment)

USAGE:
- Local dev: Run `firebase emulators:start` - Firebase is emulated, external APIs are real
- Production: Deployed via GitHub Actions after tests pass
"""

import json
import logging
import os
import time
from enum import Enum
from typing import Any

from firebase_functions import params

logger = logging.getLogger(__name__)

# ============================================================================
# ENVIRONMENT DETECTION
# ============================================================================


class Environment(Enum):
    """Class Environment."""
    EMULATOR = "emulator"  # Local development with Firebase emulators
    DEV = "dev"  # Development Firebase project (orignagta-dev)
    STAGING = "staging"  # Staging Firebase project (orignagta-staging)
    PRODUCTION = "production"  # Production Firebase project (orignagta)

    def get_base_url(self) -> str:
        """Get the base web URL for this environment."""
        from schema_constants import EmailConfig

        if self == Environment.EMULATOR:
            return EmailConfig.URL_EMULATOR
        elif self == Environment.STAGING:
            return EmailConfig.URL_STAGING
        elif self == Environment.DEV:
            return EmailConfig.URL_DEV
        return EmailConfig.URL_PROD

    def get_unsubscribe_url(self) -> str:
        """Get the unsubscribe URL for this environment."""
        from schema_constants import EmailConfig

        if self == Environment.EMULATOR:
            return EmailConfig.UNSUBSCRIBE_URL_EMULATOR
        elif self == Environment.STAGING:
            return EmailConfig.UNSUBSCRIBE_URL_STAGING
        elif self == Environment.DEV:
            return EmailConfig.UNSUBSCRIBE_URL_DEV
        return EmailConfig.UNSUBSCRIBE_URL_PROD


# Auto-detect environment
# 1. Check if running in emulator
IS_EMULATOR = os.environ.get("FUNCTIONS_EMULATOR", "false").lower() == "true"

# 2. Check GCP Project ID
PROJECT_ID = os.environ.get("GCP_PROJECT", os.environ.get("GCLOUD_PROJECT", "orignagta"))

if IS_EMULATOR:
    CURRENT_ENV = Environment.EMULATOR
elif PROJECT_ID == "orignagta-dev":
    CURRENT_ENV = Environment.DEV
elif PROJECT_ID == "orignagta-staging":
    CURRENT_ENV = Environment.STAGING
elif PROJECT_ID == "orignagta":
    CURRENT_ENV = Environment.PRODUCTION
else:
    raise RuntimeError(
        f"Unknown GCP_PROJECT '{PROJECT_ID}'. Expected one of: orignagta, orignagta-dev, orignagta-staging. "
        "Set GCP_PROJECT environment variable explicitly to avoid defaulting to PRODUCTION."
    )


def get_environment() -> Environment:
    """Get current environment."""
    return CURRENT_ENV


def is_emulator() -> bool:
    """Check if running in emulator mode."""
    return IS_EMULATOR


# Module-level environment URL helpers
BASE_URL = CURRENT_ENV.get_base_url()
UNSUBSCRIBE_URL = CURRENT_ENV.get_unsubscribe_url()


# ============================================================================
# CONSTANTS — Single source of truth is schema_constants.py
# Import all enums from there. DO NOT duplicate here.
# ============================================================================


class CaptureMethod:
    """Class CaptureMethod."""
    MANUAL = "manual"
    AUTOMATIC = "automatic"


# ============================================================================
# PLATFORM CONFIGURATION
# All business rule constants are canonically defined in BusinessRules
# in schema_constants.py.
# ============================================================================

from schema_constants import BusinessRules  # noqa: E402

PLATFORM_FEE_RATIO = BusinessRules.PLATFORM_FEE_RATIO
PREMIUM_MONTHLY_PRICE_CAD = BusinessRules.PREMIUM_MONTHLY_PRICE_CAD
PREMIUM_MONTHLY_PRICE_CENTS = BusinessRules.PREMIUM_MONTHLY_PRICE_CENTS
AUTO_CONFIRM_DAYS = BusinessRules.AUTO_CONFIRM_DAYS
SHIPPING_APPROVAL_THRESHOLD = BusinessRules.SHIPPING_APPROVAL_THRESHOLD

# ============================================================================
# FIRESTORE BACKUP — GCS bucket per environment (daily export via Admin API)
# Bucket naming: <project_id>-backups (e.g. orignagta-backups for prod)
# IAM needed: Cloud Functions SA → roles/datastore.importExportAdmin + roles/storage.objectAdmin
# ============================================================================

_BACKUP_BUCKETS: dict[str, str] = {
    "orignagta-dev": "gs://orignagta-dev-backups",
    "orignagta-staging": "gs://orignagta-staging-backups",
    "orignagta": "gs://orignagta-backups",
}
BACKUP_BUCKET: str = _BACKUP_BUCKETS.get(PROJECT_ID, f"gs://{PROJECT_ID}-backups")

# ============================================================================
# R2 STORAGE CONFIGURATION - REAL service, environment-aware paths
# R2 is always real (not emulated). We use folder prefixes to separate data.
# ============================================================================


class R2Config:
    """Cloudflare R2 Storage Configuration.

    NOTE: R2 is a REAL service even in emulator mode.
    We use 'emulator/' folder prefix to separate test uploads from production.
    """

    BUCKET_NAME = "orignagta-images"

    @staticmethod
    def get_products_folder() -> str:
        """Get folder path for product images based on environment."""
        if IS_EMULATOR:
            return "emulator/products"
        elif CURRENT_ENV == Environment.DEV:
            return "dev/products"
        elif CURRENT_ENV == Environment.STAGING:
            return "staging/products"
        return "products"

    @staticmethod
    def get_users_folder() -> str:
        """Get folder path for user images based on environment."""
        if IS_EMULATOR:
            return "emulator/users"
        elif CURRENT_ENV == Environment.DEV:
            return "dev/users"
        elif CURRENT_ENV == Environment.STAGING:
            return "staging/users"
        return "users"

    @staticmethod
    def get_image_path(category: str, filename: str) -> str:
        """Build full image path based on environment.

        Args:
            category: 'products' or 'users'
            filename: The image filename
        Returns:
            Full path like 'emulator/products/img.jpg' or 'products/img.jpg'
        """
        if category == "products":
            return f"{R2Config.get_products_folder()}/{filename}"
        elif category == "users":
            return f"{R2Config.get_users_folder()}/{filename}"
        else:
            if IS_EMULATOR:
                return f"emulator/{category}/{filename}"
            elif CURRENT_ENV == Environment.DEV:
                return f"dev/{category}/{filename}"
            elif CURRENT_ENV == Environment.STAGING:
                return f"staging/{category}/{filename}"
            return f"{category}/{filename}"


# ============================================================================
# ALGOLIA CONFIGURATION - REAL service, separate index per environment
# Algolia is always real (not emulated). We use separate indexes.
# ============================================================================


class AlgoliaConfig:
    """Algolia search configuration.

    NOTE: Algolia is a REAL service even in emulator mode.
    We use 'products_emulator' index to separate test data from production.
    """

    @staticmethod
    def get_index_name() -> str:
        """Get Algolia index name based on environment."""
        if IS_EMULATOR:
            return "products_emulator"
        elif CURRENT_ENV == Environment.DEV:
            return "products_dev"
        elif CURRENT_ENV == Environment.STAGING:
            return "products_staging"
        return "products"


# ============================================================================
# SECRETS MANAGEMENT
#
# STRATEGY: Single APP_SECRETS JSON blob = 1 active secret version per project.
# Free tier = 6 versions per billing account. 3 projects × 1 = 3 → always free.
#
# Production (Secret Manager): one secret "APP_SECRETS" with this shape:
#   {
#     "stripe":   {"secret_key":"","webhook_secret":"","premium_price_id":""},
#     "mailjet":  {"api_key":"","secret_key":""},
#     "algolia":  {"app_id":"","write_api_key":""},
#     "r2":       {"access_key":"","secret_key":"","account_id":""},
#     "unsubscribe_hmac": "",
#     "geoapify": "",
#     "sentry":   ""
#   }
#
# Emulator/local: reads individual env vars from .env (no changes for devs).
# ============================================================================

FORCE_LOCAL_SECRETS = os.environ.get("FORCE_LOCAL_SECRETS", "false").lower() == "true"
_USE_LOCAL = IS_EMULATOR or FORCE_LOCAL_SECRETS

APP_SECRETS_PARAM = params.SecretParam("APP_SECRETS")

# Parsed once per cold start, but with a TTL to allow rotation
_app_secrets: dict[str, Any] | None = None
_app_secrets_last_fetch: float = 0
SECRETS_TTL_SECONDS = 600  # 10 minutes


def _load_secret(key: str, required: bool = True) -> str:
    """Load a secret from env vars (emulator/local only)."""
    value = os.environ.get(key)
    if not value and required:
        raise ValueError(f"❌ {key} required in local mode. Add to .env or export {key}=...")
    return value or ""


def _secrets() -> dict[str, Any]:
    """Return parsed APP_SECRETS dict, cached with a 10-minute TTL."""
    global _app_secrets, _app_secrets_last_fetch
    now = time.time()

    # If using local mode, we don't need TTL as .env is usually static
    if _USE_LOCAL:
        return {}

    if _app_secrets is None or (now - _app_secrets_last_fetch) > SECRETS_TTL_SECONDS:
        try:
            # Firebase SecretParam.value is cached by the runtime, but we re-read
            # the parameter which might be updated if the version is alias-linked.
            # NOTE: For true runtime rotation, we should use Secret Manager SDK,
            # but updating the cache periodically is a good middle ground.
            raw = APP_SECRETS_PARAM.value
            _app_secrets = json.loads(raw) if isinstance(raw, (str, bytes, bytearray)) and raw else {}
            _app_secrets_last_fetch = now
            logger.info("Fetched APP_SECRETS from Secret Manager (TTL expired or first fetch)")
        except Exception as e:
            logger.error(f"Failed to fetch or parse APP_SECRETS: {e}")
            if _app_secrets is None:
                _app_secrets = {}

    return _app_secrets


# ============================================================================
# STRIPE CONFIGURATION
# ============================================================================


def get_stripe_secret_key() -> str:
    """Get Stripe Secret Key."""
    if _USE_LOCAL:
        return _load_secret("STRIPE_SECRET_KEY", required=False)
    return _secrets().get("stripe", {}).get("secret_key", "")


def get_stripe_webhook_secret() -> str:
    """Get Stripe Webhook Secret."""
    if _USE_LOCAL:
        return _load_secret("STRIPE_WEBHOOK_SECRET", required=False)
    return _secrets().get("stripe", {}).get("webhook_secret", "")


def get_stripe_premium_price_id() -> str:
    """Get Stripe Premium Subscription Price ID."""
    if _USE_LOCAL:
        return _load_secret("STRIPE_PREMIUM_PRICE_ID", required=False)
    return _secrets().get("stripe", {}).get("premium_price_id", "")


class StripeConfig:
    """Stripe payment configuration."""

    @staticmethod
    def is_test_mode() -> bool:
        """Check if using Stripe test keys (sk_test_*)."""
        key = get_stripe_secret_key()
        return key.startswith("sk_test_") if key else True


# ============================================================================
# MAILJET CONFIGURATION
# ============================================================================


def get_mailjet_api_key() -> str:
    """Get Mailjet API Key."""
    if _USE_LOCAL:
        return _load_secret("MAILJET_API_KEY", required=False)
    return _secrets().get("mailjet", {}).get("api_key", "")


def get_mailjet_secret_key() -> str:
    """Get Mailjet Secret Key."""
    if _USE_LOCAL:
        return _load_secret("MAILJET_SECRET_KEY", required=False)
    return _secrets().get("mailjet", {}).get("secret_key", "")


# ============================================================================
# UNSUBSCRIBE HMAC SECRET
# ============================================================================


def get_unsubscribe_hmac_secret() -> str:
    """Get Unsubscribe HMAC Secret."""
    if _USE_LOCAL:
        return _load_secret("UNSUBSCRIBE_HMAC_SECRET", required=False)
    return _secrets().get("unsubscribe_hmac", "")


# ============================================================================
# GEOAPIFY CONFIGURATION
# ============================================================================


def get_geoapify_api_key() -> str:
    """Get Geoapify API Key."""
    if _USE_LOCAL:
        return _load_secret("GEOAPIFY_API_KEY", required=False)
    return _secrets().get("geoapify", "")


# ============================================================================
# ALGOLIA SECRETS
# ============================================================================


def get_algolia_app_id() -> str:
    """Get Algolia App ID."""
    if _USE_LOCAL:
        return _load_secret("ALGOLIA_APP_ID", required=False)
    return _secrets().get("algolia", {}).get("app_id", "")


def get_algolia_write_api_key() -> str:
    """Get Algolia Write API Key."""
    if _USE_LOCAL:
        return _load_secret("ALGOLIA_WRITE_API_KEY", required=False)
    return _secrets().get("algolia", {}).get("write_api_key", "")


# ============================================================================
# CLOUDFLARE R2 SECRETS
# ============================================================================


def get_r2_credentials() -> dict:
    """Get R2 credentials."""
    if _USE_LOCAL:
        return {
            "access_key": os.environ.get("R2_ACCESS_KEY", ""),
            "secret_key": os.environ.get("R2_SECRET_KEY", ""),
            "account_id": os.environ.get("R2_ACCOUNT_ID", ""),
        }
    r2 = _secrets().get("r2", {})
    return {
        "access_key": r2.get("access_key", ""),
        "secret_key": r2.get("secret_key", ""),
        "account_id": r2.get("account_id", ""),
    }


# ============================================================================
# SENTRY ERROR MONITORING
# ============================================================================


def get_sentry_dsn() -> str:
    """Function get_sentry_dsn."""
    if _USE_LOCAL:
        return _load_secret("SENTRY_DSN_BACKEND", required=False)
    return _secrets().get("sentry", "")


def init_sentry():
    """Initialize Sentry SDK for backend error monitoring (production and staging only)."""
    if IS_EMULATOR or CURRENT_ENV == Environment.DEV:
        return

    dsn = get_sentry_dsn()
    if not dsn:
        return

    try:
        import sentry_sdk
        from sentry_sdk.integrations.flask import FlaskIntegration

        sentry_sdk.init(
            dsn=dsn,
            integrations=[FlaskIntegration()],
            traces_sample_rate=0.1,  # 10% of transactions for performance monitoring
            environment=CURRENT_ENV.value,
            release=os.environ.get("K_REVISION", "unknown"),
            # Scrub sensitive data
            send_default_pii=False,
            before_send=_sentry_before_send,
        )
        print("✅ Sentry initialized for backend monitoring")
    except Exception as e:
        print(f"⚠️ Sentry init failed: {type(e).__name__}")


def _sentry_before_send(event, hint):
    """Scrub sensitive data before sending to Sentry."""
    # Remove any accidentally captured secrets
    if "exception" in event:
        for exception in event.get("exception", {}).get("values", []):
            for frame in exception.get("stacktrace", {}).get("frames", []):
                # Redact variables that might contain secrets
                if "vars" in frame:
                    for key in list(frame["vars"].keys()):
                        key_lower = key.lower()
                        if any(s in key_lower for s in ("secret", "key", "token", "password", "dsn", "api_key")):
                            frame["vars"][key] = "[REDACTED]"
    return event


# ============================================================================
# OTHER CONFIGURATION
# ============================================================================

SELLER_EMAIL = os.environ.get("SELLER_EMAIL") or "support@orignagta.ca"

# Stripe Tax Feature Flag
STRIPE_TAX_ENABLED = os.environ.get("STRIPE_TAX_ENABLED", "false").lower() == "true"

# Stripe Tax Code Mapping
CATEGORY_TAX_CODE_MAP = {
    1: "txcd_99999999",  # Electronics → General Tangible Goods
    2: "txcd_99999999",  # Computers → General Tangible Goods
    3: "txcd_10201000",  # Gaming → Video Games
    4: "txcd_99999999",  # Home/Kitchen → General Tangible Goods
    5: "txcd_99999999",  # Fashion → General Tangible Goods
    6: "txcd_99999999",  # Shoes/Accessories → General Tangible Goods
    7: "txcd_99999999",  # Jewelry/Watches → General Tangible Goods
    8: "txcd_99999999",  # Beauty/Personal Care → General Tangible Goods
    9: "txcd_99999999",  # Health/Wellness → General Tangible Goods
    10: "txcd_99999999",  # Sports/Fitness → General Tangible Goods
    11: "txcd_99999999",  # Automotive → General Tangible Goods
    12: "txcd_99999999",  # Tools/Hardware → General Tangible Goods
    13: "txcd_99999999",  # Office Supplies → General Tangible Goods
    14: "txcd_10302000",  # Books → Digital Books (physical)
    15: "txcd_99999999",  # Music/Instruments → General Tangible Goods
    16: "txcd_99999999",  # Toys/Games → General Tangible Goods
    17: "txcd_20030002",  # Baby/Kids → Children's Clothing
    18: "txcd_99999999",  # Pet Supplies → General Tangible Goods
    19: "txcd_30060005",  # Groceries → Basic Groceries
    20: "txcd_99999999",  # Art/Collectibles → General Tangible Goods
    21: "txcd_10000000",  # Digital Products → Digital Services
}

# Stripe Tax Constants
STRIPE_TAX_CODE_GENERAL = "txcd_99999999"  # General Tangible Goods
STRIPE_TAX_CODE_CHILDRENS_CLOTHING = "txcd_20030002"  # Children's Clothing
STRIPE_TAX_CODE_BASIC_GROCERIES = "txcd_30060005"  # Basic Groceries
STRIPE_TAX_CODE_SHIPPING = "txcd_92010001"  # Shipping/Handling
STRIPE_TAX_TYPE_CA_GST_HST = "ca_gst_hst"  # Canadian GST/HST tax ID type
STRIPE_TAX_EXEMPT_NONE = "none"  # Let Stripe determine exemption

# ============================================================================
# DEBUG & LOGGING
# ============================================================================


def print_env_info():
    """Print current environment info for debugging."""
    print("=" * 60)
    print(f"🔧 ENVIRONMENT: {CURRENT_ENV.value.upper()}")
    print(f"   IS_EMULATOR: {IS_EMULATOR}")
    print(f"   R2 Products Folder: {R2Config.get_products_folder()}")
    print(f"   R2 Users Folder: {R2Config.get_users_folder()}")
    print(f"   Algolia Index: {AlgoliaConfig.get_index_name()}")
    print(f"   Stripe Test Mode: {StripeConfig.is_test_mode()}")
    print("=" * 60)


# Print environment info on module load in emulator mode
if IS_EMULATOR:
    print_env_info()
