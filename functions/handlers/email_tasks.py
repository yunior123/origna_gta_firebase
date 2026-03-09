"""
Cloud Tasks handler for async email delivery.

Registered in main.py as a Firebase Cloud Function task queue handler.
Firebase CLI auto-creates the Cloud Tasks queue named 'sendEmailTask'
on first deploy. Note: Cloud Tasks queue IDs cannot contain underscores,
so camelCase is used here.

Queue config:
  - Max 5 retries with exponential backoff (10s → 600s)
  - Max 10 dispatches/second (well within Mailjet free-tier limits)
"""

import logging

from firebase_functions import tasks_fn
from firebase_functions.options import RateLimits, RetryConfig

from services.email_service import send_email
from utils.function_options import _REGION, _SECRETS

logger = logging.getLogger(__name__)


@tasks_fn.on_task_dispatched(
    retry_config=RetryConfig(
        max_attempts=5,
        min_backoff_seconds=10,
        max_backoff_seconds=600,
        max_doublings=5,
    ),
    rate_limits=RateLimits(max_dispatches_per_second=10),
    region=_REGION,
    secrets=_SECRETS,
)
def sendEmailTask(req: tasks_fn.CallableRequest) -> None:
    """Process a queued email — called by Cloud Tasks, never directly."""
    data = req.data
    to_email = data.get("to", "")
    subject = data.get("subject", "")
    html_content = data.get("html", "")

    if not to_email or not subject or not html_content:
        logger.error(f"sendEmailTask: missing required fields in payload: {list(data.keys())}")
        return

    send_email(to_email=to_email, subject=subject, html_content=html_content)
    logger.info(f"sendEmailTask: delivered to {to_email} | event={data.get('event_type','')}")
