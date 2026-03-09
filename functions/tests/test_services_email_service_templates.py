from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import Mock, patch

import pytest

from schema_constants import Fields, UserRoleValues


def _order_data():
    return {
        Fields.ITEMS: [
            {
                Fields.NAME: "Maple Syrup",
                Fields.QUANTITY: 2,
                Fields.PRICE: 12.5,
                Fields.SELLER_ADDRESS: {Fields.COUNTRY: "USA"},
            },
            {
                Fields.NAME: "Coffee Beans",
                Fields.QUANTITY: 1,
                Fields.PRICE: 18.0,
                Fields.SELLER_ADDRESS: {Fields.COUNTRY: "Canada"},
            },
        ],
        Fields.SUBTOTAL_CENTS: 4300,
        Fields.SHIPPING_COST_CENTS: 700,
        Fields.TAXES: {"HST": 6.50},
        Fields.TOTAL_AMOUNT_CENTS: 5630,
        Fields.CUSTOMER_EMAIL: "buyer@example.com",
        Fields.TRACKING_NUMBER: "TRK-123",
        Fields.CARRIER: "Canada Post",
    }


def _return_data():
    return {
        Fields.RETURN_REASON: "Damaged in transit",
        Fields.RETURN_REFUND_AMOUNT_CENTS: 1250,
        Fields.CUSTOMER_EMAIL: "buyer@example.com",
    }


def _user_data():
    return {"name": "Buyer One", "email": "buyer@example.com"}


class TestEmailTemplateBuilders:
    def test_template_components_render(self):
        from services.email_service import (
            _cta_button,
            _email_wrapper,
            _hero_header,
            _items_summary_table,
            _order_status_tracker,
            _price_summary_block,
        )

        hero = _hero_header("🚚", "Heading", "Subtext")
        tracker = _order_status_tracker(3, "en")
        items = _items_summary_table(_order_data()[Fields.ITEMS], "en")
        price = _price_summary_block(43.0, 7.0, 6.5, 56.3, "en")
        button = _cta_button("https://example.com/orders", "Track order")
        wrapped = _email_wrapper("Title", hero + tracker + items + price + button, include_gst=True, recipient_email="buyer@example.com")

        assert "Heading" in hero
        assert "Track order" in button
        assert "Maple Syrup" in items
        assert "CAD" in price
        assert "<html" in wrapped

    def test_order_status_templates_render_non_empty_html(self):
        from services.email_service import (
            get_order_cancelled_email,
            get_order_delivered_email,
            get_order_in_transit_email,
            get_order_item_delivered_email,
            get_order_item_shipped_email,
            get_order_partially_refunded_email,
            get_order_processing_email,
            get_order_refunded_email,
            get_order_shipped_email,
        )

        order = _order_data()
        oid = "order_12345678"

        shipped = get_order_shipped_email(order, oid, tracking_number="TRK1", carrier="UPS", lang="en")
        partial_shipped = get_order_item_shipped_email(order, oid, order[Fields.ITEMS], tracking_number="TRK2", carrier="UPS", lang="en")
        in_transit = get_order_in_transit_email(order, oid, lang="fr")
        delivered = get_order_delivered_email(order, oid, lang="en")
        cancelled = get_order_cancelled_email(order, oid, reason="Out of stock", lang="en")
        processing = get_order_processing_email(order, oid, lang="fr")
        refunded = get_order_refunded_email(order, oid, refund_amount_cents=1250, lang="en")
        partial_refunded = get_order_partially_refunded_email(order, oid, refund_amount_cents=500, lang="en")
        item_delivered = get_order_item_delivered_email(order, oid, [order[Fields.ITEMS][0]], lang="en")

        for html in [
            shipped,
            partial_shipped,
            in_transit,
            delivered,
            cancelled,
            processing,
            refunded,
            partial_refunded,
            item_delivered,
        ]:
            assert "<html" in html
            assert "order" in html.lower()

    def test_return_and_premium_templates_render(self):
        from services.email_service import (
            get_premium_cancellation_email,
            get_premium_expired_email,
            get_premium_payment_failed_email,
            get_premium_renewal_reminder_email,
            get_premium_welcome_email,
            get_return_received_email,
            get_return_refunded_email,
            get_return_request_approved_email,
            get_return_request_rejected_email,
            get_return_request_submitted_email,
        )

        ret = _return_data()
        user = _user_data()
        oid = "order_12345678"
        rid = "return_87654321"

        rendered = [
            get_return_request_submitted_email(ret, rid, oid, recipient="buyer", lang="en"),
            get_return_request_approved_email(ret, rid, oid, lang="fr"),
            get_return_request_rejected_email(ret, rid, oid, lang="en"),
            get_return_received_email(ret, rid, oid, lang="en"),
            get_return_refunded_email(ret, rid, oid, lang="fr"),
            get_premium_welcome_email(user, period_end=datetime.now(UTC), lang="en"),
            get_premium_cancellation_email(user, period_end=datetime.now(UTC), lang="fr"),
            get_premium_expired_email(user, lang="en"),
            get_premium_payment_failed_email(user, lang="fr"),
            get_premium_renewal_reminder_email(user, period_end=datetime.now(UTC), days_remaining=1, lang="en"),
        ]

        for html in rendered:
            assert "<html" in html
            assert "origna" in html.lower()

    def test_items_summary_table_empty_returns_empty(self):
        from services.email_service import _items_summary_table

        assert _items_summary_table([], "en") == ""

    def test_order_confirmation_same_day_fr_uses_french_item_label(self):
        from services.email_service import get_order_confirmation_email

        order = _order_data()
        order[Fields.ITEMS] = [{Fields.NAME: "Maple Syrup", Fields.QUANTITY: 1, Fields.PRICE: 9.99}]
        order[Fields.DELIVERY_SPEED] = "same_day"
        html = get_order_confirmation_email(order, "order_1", lang="fr")
        assert "article commandé" in html

    def test_order_processing_email_en_uses_english_payment_copy(self):
        from services.email_service import get_order_processing_email

        html = get_order_processing_email(_order_data(), "order_12345678", lang="en")
        assert "has been captured" in html

    def test_partial_refund_email_fr_uses_french_timeline_copy(self):
        from services.email_service import get_order_partially_refunded_email

        html = get_order_partially_refunded_email(_order_data(), "order_12345678", refund_amount_cents=500, lang="fr")
        assert "Les remboursements partiels" in html

    def test_return_request_submitted_seller_branch_renders(self):
        from services.email_service import get_return_request_submitted_email

        html = get_return_request_submitted_email(
            _return_data(),
            "return_87654321",
            "order_12345678",
            recipient=UserRoleValues.SELLER,
            lang="en",
        )
        assert "return request" in html.lower()

    def test_seller_notification_urgent_branch_uses_fallback_strings(self):
        from services.email_service import get_seller_notification_email

        order = _order_data()
        order[Fields.ITEMS][0][Fields.SELLER_ID] = "seller_1"
        order[Fields.SHIPPING_ADDRESS] = {
            Fields.STREET: "1 Main St",
            Fields.CITY: "Toronto",
            Fields.STATE: "ON",
            Fields.POSTAL_CODE: "M5V2T6",
            Fields.COUNTRY: "Canada",
        }
        with patch("services.email_service._t", side_effect=lambda key, _lang="en": key):
            html = get_seller_notification_email(
                order,
                order_id="order_12345678",
                seller_id="seller_1",
                lang="en",
                seller_email="seller@example.com",
                is_urgent_perishable=True,
            )
        assert "URGENT: PERISHABLE ORDER" in html
        assert "CFIA Compliance Required: Ship Today" in html

    def test_premium_templates_swallow_bad_period_end_formatting(self):
        from services.email_service import (
            get_premium_cancellation_email,
            get_premium_renewal_reminder_email,
            get_premium_welcome_email,
        )

        class BadPeriod:
            def strftime(self, _fmt):
                raise RuntimeError("bad date")

        user = _user_data()
        assert "<html" in get_premium_welcome_email(user, period_end=BadPeriod(), lang="en")
        assert "<html" in get_premium_cancellation_email(user, period_end=BadPeriod(), lang="en")
        assert "<html" in get_premium_renewal_reminder_email(user, period_end=BadPeriod(), days_remaining=7, lang="en")

    def test_get_unsubscribe_secret_raises_when_missing_outside_emulator(self):
        from services import email_service

        email_service._UNSUBSCRIBE_SECRET = None
        with (
            patch("services.email_service.get_unsubscribe_hmac_secret", return_value=None),
            patch("services.email_service.IS_EMULATOR", False),
        ):
            with pytest.raises(RuntimeError, match="not configured"):
                email_service._get_unsubscribe_secret()

    def test_get_unsubscribe_secret_uses_emulator_default_when_missing(self):
        from services import email_service

        email_service._UNSUBSCRIBE_SECRET = None
        with (
            patch("services.email_service.get_unsubscribe_hmac_secret", return_value=None),
            patch("services.email_service.IS_EMULATOR", True),
        ):
            secret = email_service._get_unsubscribe_secret()
        assert secret == "origna-unsub-default-dev-key"
        email_service._UNSUBSCRIBE_SECRET = None

    def test_seller_notification_email_fr_uses_french_datetime_format(self):
        from services.email_service import get_seller_notification_email

        order = _order_data()
        order[Fields.ITEMS][0][Fields.SELLER_ID] = "seller_1"
        order[Fields.SHIPPING_ADDRESS] = {
            Fields.STREET: "1 Main St",
            Fields.CITY: "Montreal",
            Fields.STATE: "QC",
            Fields.POSTAL_CODE: "H2Y1C6",
            Fields.COUNTRY: "Canada",
        }
        html = get_seller_notification_email(
            order,
            order_id="order_12345678",
            seller_id="seller_1",
            lang="fr",
            seller_email="seller@example.com",
        )
        assert " à " in html


class TestEmailSendPaths:
    @patch("services.email_service._log_email_for_testing")
    @patch("services.email_service.get_mailjet_api_key", return_value=None)
    @patch("services.email_service.FORCE_REAL_EMAIL", False)
    @patch("services.email_service.IS_EMULATOR", True)
    def test_send_email_emulator_path_returns_true(self, _mock_key, _mock_log):
        from services.email_service import send_email

        ok = send_email(
            "buyer@example.com",
            "Subject",
            "<p>Hello</p>",
            attachments=[{"Filename": "invoice.pdf", "Base64Content": "AA==", "ContentType": "application/pdf"}],
        )
        assert ok is True

    @patch("services.email_service._log_email_for_testing")
    @patch("services.email_service._get_signed_unsubscribe_url", return_value="https://example.com/u")
    @patch("services.email_service._get_mailjet")
    @patch("services.email_service.get_mailjet_api_key", return_value="key_live")
    @patch("services.email_service.IS_EMULATOR", False)
    def test_send_email_real_path_success(self, _mock_key, mock_get_mailjet, _mock_unsub, _mock_log):
        from services.email_service import send_email

        mailjet = Mock()
        mailjet.send.create.return_value = SimpleNamespace(status_code=200)
        mock_get_mailjet.return_value = mailjet

        ok = send_email("buyer@example.com", "Subject", "<p>Hello</p>", to_name="Buyer")
        assert ok is True
        mailjet.send.create.assert_called_once()

    @patch("services.email_service._log_email_for_testing")
    @patch("services.email_service._get_signed_unsubscribe_url", return_value="https://example.com/u")
    @patch("services.email_service._get_mailjet")
    @patch("services.email_service.get_mailjet_api_key", return_value="key_live")
    @patch("services.email_service.IS_EMULATOR", False)
    def test_send_email_real_path_includes_attachments(self, _mock_key, mock_get_mailjet, _mock_unsub, _mock_log):
        from services.email_service import send_email

        mailjet = Mock()
        mailjet.send.create.return_value = SimpleNamespace(status_code=200)
        mock_get_mailjet.return_value = mailjet
        attachments = [{"Filename": "invoice.pdf", "Base64Content": "AA==", "ContentType": "application/pdf"}]

        ok = send_email("buyer@example.com", "Subject", "<p>Hello</p>", attachments=attachments)
        assert ok is True
        payload = mailjet.send.create.call_args.kwargs["data"]
        assert payload["Messages"][0]["Attachments"] == attachments

    @patch("services.email_service._log_email_for_testing")
    @patch("services.email_service._get_signed_unsubscribe_url", return_value="https://example.com/u")
    @patch("services.email_service._get_mailjet")
    @patch("services.email_service.get_mailjet_api_key", return_value="key_live")
    @patch("services.email_service.IS_EMULATOR", False)
    def test_send_email_real_path_failure_status_returns_false(
        self, _mock_key, mock_get_mailjet, _mock_unsub, _mock_log
    ):
        from services.email_service import send_email

        failed_result = Mock()
        failed_result.status_code = 500
        failed_result.json.return_value = {"error": "bad request"}
        mailjet = Mock()
        mailjet.send.create.return_value = failed_result
        mock_get_mailjet.return_value = mailjet

        assert send_email("buyer@example.com", "Subject", "<p>Hello</p>") is False

    @patch("services.email_service.send_email")
    def test_send_authorization_expired_email_handles_missing_customer_email(self, mock_send):
        from services.email_service import send_authorization_expired_email

        send_authorization_expired_email("order_1", {Fields.TOTAL_AMOUNT_CENTS: 1000}, lang="en")
        mock_send.assert_not_called()

    @patch("services.email_service.send_email")
    def test_send_authorization_expired_email_calls_send(self, mock_send):
        from services.email_service import send_authorization_expired_email

        send_authorization_expired_email(
            "order_1",
            {Fields.CUSTOMER_EMAIL: "buyer@example.com", Fields.TOTAL_AMOUNT_CENTS: 1500},
            lang="en",
        )
        mock_send.assert_called_once()

    @patch("services.email_service.send_email")
    def test_send_payment_capture_failed_email_paths(self, mock_send):
        from services.email_service import send_payment_capture_failed_email

        send_payment_capture_failed_email("order_1", "", "Buyer", 12.5, "Card declined", lang="en")
        mock_send.assert_not_called()

        send_payment_capture_failed_email("order_1", "buyer@example.com", "Buyer", 12.5, "Card declined", lang="en")
        mock_send.assert_called_once()

    def test_log_email_for_testing_skips_production(self):
        from config import Environment
        from services.email_service import _log_email_for_testing

        with (
            patch("config.CURRENT_ENV", Environment.PRODUCTION),
            patch("firebase_admin.firestore.client") as mock_client,
        ):
            _log_email_for_testing("buyer@example.com", "Subject", "<p>Hello</p>")
        mock_client.assert_not_called()

    def test_log_email_for_testing_writes_mail_log_in_dev(self):
        from config import Environment
        from services.email_service import _log_email_for_testing

        db = Mock()
        with (
            patch("config.CURRENT_ENV", Environment.DEV),
            patch("firebase_admin.firestore.client", return_value=db),
        ):
            _log_email_for_testing("buyer@example.com", "Subject", "<p>Hello</p>")
        db.collection.return_value.add.assert_called_once()
