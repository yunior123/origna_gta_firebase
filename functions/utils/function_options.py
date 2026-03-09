"""
Global configuration options for Firebase Cloud Functions
Optimized for FREE TIER - minimal resource usage, reasonable timeouts
"""

from firebase_functions import options

from config import APP_SECRETS_PARAM
from schema_constants import AppConfig

# Canonical CORS policy — applied to all on_call functions
_CORS = options.CorsOptions(
    cors_origins=AppConfig.CORS_ORIGINS,
    cors_methods=["POST", "OPTIONS"],
)

# Region — Canada (Montreal) for PIPEDA data-residency compliance + <5ms latency from GTA
_REGION = "northamerica-northeast1"

# APP_SECRETS mounted into every Cloud Run service so _secrets() can read from Secret Manager.
_SECRETS = [APP_SECRETS_PARAM]

# Default: 256MB memory, 60s timeout (Firebase defaults - FREE TIER friendly)
DEFAULT_OPTIONS = {
    "cors": _CORS,
    "region": _REGION,
    "secrets": _SECRETS,
}

# Firestore triggers: No CORS (not HTTP-accessible). Used by on_document_*
FIRESTORE_TRIGGER_OPTIONS: dict = {
    "region": _REGION,
    "secrets": _SECRETS,
}

# Firestore triggers for payment-adjacent collections (orders, payouts).
# Higher memory to survive burst writes at scale without OOM.
FIRESTORE_PAYMENT_TRIGGER_OPTIONS: dict = {
    "memory": options.MemoryOption.MB_512,
    "timeout_sec": 120,
    "region": _REGION,
    "secrets": _SECRETS,
}

# Webhooks: 512MB memory (stripe_webhook processes orders + payouts + digital licenses),
# 90s timeout (Stripe retries on timeout, need margin)
WEBHOOK_OPTIONS = {
    "memory": options.MemoryOption.MB_512,
    "timeout_sec": 90,
    "region": _REGION,
    "secrets": _SECRETS,
}

# Payment on_call handlers: 120s timeout (Stripe API calls + DB writes can be slow)
PAYMENT_OPTIONS = {
    "cors": _CORS,
    "timeout_sec": 120,
    "region": _REGION,
    "secrets": _SECRETS,
}

# Cron jobs: 256MB memory, 300s timeout (batch processing up to 500 orders)
CRON_OPTIONS = {
    "timeout_sec": 300,
    "region": _REGION,
    "secrets": _SECRETS,
}

# Cloud Task workers: HTTP-triggered by Cloud Tasks (no CORS needed), 60s timeout per task.
# These are internal functions — not callable by clients.
TASK_WORKER_OPTIONS = {
    "timeout_sec": 60,
    "region": _REGION,
    "secrets": _SECRETS,
}

# Alias used in handlers/tasks.py
V2_OPTIONS = TASK_WORKER_OPTIONS
