from unittest.mock import MagicMock, patch

from services import email_task


class TestEmailTask:
    def test_enqueue_email_task_uses_sync_send_in_emulator(self):
        with (
            patch.object(email_task, "IS_EMULATOR", True),
            patch.object(email_task, "_sync_send") as mock_sync,
        ):
            email_task.enqueue_email_task(
                to_email="buyer@example.com",
                subject="Order confirmed",
                html_content="<p>ok</p>",
                event_type="order_confirmed",
            )

        mock_sync.assert_called_once_with("buyer@example.com", "Order confirmed", "<p>ok</p>")

    def test_enqueue_email_task_queues_payload_when_not_emulator(self):
        mock_queue = MagicMock()
        with (
            patch.object(email_task, "IS_EMULATOR", False),
            patch("firebase_admin.functions.task_queue", return_value=mock_queue) as mock_task_queue,
        ):
            email_task.enqueue_email_task(
                to_email="seller@example.com",
                subject="New order",
                html_content="<p>new order</p>",
                event_type="seller_new_order",
                order_id="ord_123",
                seller_id="seller_1",
            )

        mock_task_queue.assert_called_once_with("sendEmailTask")
        payload = mock_queue.enqueue.call_args.args[0]
        assert payload["to"] == "seller@example.com"
        assert payload["subject"] == "New order"
        assert payload["html"] == "<p>new order</p>"
        assert payload["event_type"] == "seller_new_order"
        assert payload["order_id"] == "ord_123"
        assert payload["seller_id"] == "seller_1"

    def test_enqueue_email_task_falls_back_to_sync_when_enqueue_fails(self):
        with (
            patch.object(email_task, "IS_EMULATOR", False),
            patch("firebase_admin.functions.task_queue", side_effect=RuntimeError("queue down")),
            patch.object(email_task, "_sync_send") as mock_sync,
            patch.object(email_task.logger, "error") as mock_error,
        ):
            email_task.enqueue_email_task(
                to_email="ops@example.com",
                subject="Alert",
                html_content="<p>retry</p>",
                event_type="failure",
            )

        mock_sync.assert_called_once_with("ops@example.com", "Alert", "<p>retry</p>")
        mock_error.assert_called_once()

    def test_sync_send_calls_email_service(self):
        with patch("services.email_service.send_email") as mock_send_email:
            email_task._sync_send("a@example.com", "Subject", "<p>Body</p>")

        mock_send_email.assert_called_once_with(
            to_email="a@example.com",
            subject="Subject",
            html_content="<p>Body</p>",
        )

    def test_sync_send_logs_when_email_service_raises(self):
        with (
            patch("services.email_service.send_email", side_effect=RuntimeError("mailjet down")),
            patch.object(email_task.logger, "error") as mock_error,
        ):
            email_task._sync_send("a@example.com", "Subject", "<p>Body</p>")

        mock_error.assert_called_once()
