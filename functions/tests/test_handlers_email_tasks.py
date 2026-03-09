import sys
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


def _decorator_passthrough(*args, **kwargs):
    def decorator(fn):
        return fn

    return decorator


firebase_functions_mod = sys.modules.get("firebase_functions")
if firebase_functions_mod is None:
    firebase_functions_mod = MagicMock()
    sys.modules["firebase_functions"] = firebase_functions_mod

firebase_functions_mod.tasks_fn = SimpleNamespace(
    on_task_dispatched=_decorator_passthrough,
    CallableRequest=object,
)

sys.modules["firebase_functions.options"] = SimpleNamespace(
    RateLimits=lambda *args, **kwargs: None,
    RetryConfig=lambda *args, **kwargs: None,
)

from handlers import email_tasks


class TestSendEmailTask:
    def test_missing_required_fields_logs_and_returns(self):
        req = SimpleNamespace(data={"to": "buyer@example.com"})

        with (
            patch("handlers.email_tasks.send_email") as mock_send_email,
            patch.object(email_tasks.logger, "error") as mock_error,
        ):
            email_tasks.sendEmailTask(req)

        mock_send_email.assert_not_called()
        mock_error.assert_called_once()

    def test_valid_payload_sends_email_and_logs_info(self):
        req = SimpleNamespace(
            data={
                "to": "buyer@example.com",
                "subject": "Order update",
                "html": "<p>ok</p>",
                "event_type": "order_update",
            }
        )

        with (
            patch("handlers.email_tasks.send_email") as mock_send_email,
            patch.object(email_tasks.logger, "info") as mock_info,
        ):
            email_tasks.sendEmailTask(req)

        mock_send_email.assert_called_once_with(
            to_email="buyer@example.com",
            subject="Order update",
            html_content="<p>ok</p>",
        )
        mock_info.assert_called_once()
