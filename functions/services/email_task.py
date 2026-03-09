"""
Email task queue helper using Firebase Admin SDK + Cloud Tasks.

Replaces synchronous send_email() calls inside Firestore triggers and
webhooks to avoid blocking on Mailjet SLA.

In emulator mode, Cloud Tasks has no emulator — falls back to sync send.
Free tier: 1M tasks/month (OrignaGTA uses << 5K/month at launch).
"""

import logging

from config import IS_EMULATOR

logger = logging.getLogger(__name__)


def enqueue_email_task(
    to_email: str,
    subject: str,
    html_content: str,
    event_type: str = "",
    **kwargs
) -> None:
    """
    Enqueue an email for async delivery via Cloud Tasks.

    Falls back to synchronous send in emulator mode or on enqueue failure
    so emails are never silently dropped.
    """
    if IS_EMULATOR:
        # Cloud Tasks emulator not available — send synchronously
        _sync_send(to_email, subject, html_content)
        return

    try:
        from firebase_admin import functions as admin_functions

        queue = admin_functions.task_queue("sendEmailTask")
        payload = {
            "to": to_email,
            "subject": subject,
            "html": html_content,
            "event_type": event_type,
        }
        payload.update(kwargs)
        queue.enqueue(payload)
    except Exception as e:
        logger.error(f"Failed to enqueue email task for {to_email}: {e}. Falling back to sync send.")
        _sync_send(to_email, subject, html_content)


def _sync_send(to_email: str, subject: str, html_content: str) -> None:
    try:
        from services.email_service import send_email

        send_email(to_email=to_email, subject=subject, html_content=html_content)
    except Exception as e:
        logger.error(f"Sync email fallback also failed for {to_email}: {e}")
