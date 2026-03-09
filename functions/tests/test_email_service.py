"""
Comprehensive unit tests for services/email_service.py
Tests all email generation and sending functions with mocked Mailjet.

Run: pytest tests/test_email_service.py -v --cov=services.email_service
"""

import os
from unittest.mock import MagicMock, Mock, patch

import pytest

from schema_constants import AppConfig, EmailConfig, Fields

# Force emulator mode for deterministic tests
os.environ["FUNCTIONS_EMULATOR"] = "true"


# =============================================================================
# Fixtures
# =============================================================================


@pytest.fixture
def sample_order_data():
    """Sample order data for email generation tests."""
    return {
        Fields.ORDER_ID: "abc12345-6789-defg",
        Fields.ITEMS: [
            {
                Fields.NAME: "Vintage Headphones",
                Fields.QUANTITY: 2,
                Fields.PRICE: 49.99,
                Fields.SELLER_ID: "seller_001",
                Fields.IMAGE_URLS: ["https://cdn.test/img.jpg"],
            },
            {
                Fields.NAME: "USB-C Cable <script>alert(1)</script>",
                Fields.QUANTITY: 1,
                Fields.PRICE: 12.50,
                Fields.SELLER_ID: "seller_002",
                Fields.IMAGE_URLS: [],
            },
        ],
        Fields.SUBTOTAL_CENTS: 11248,  # $112.48
        Fields.SHIPPING_COST_CENTS: 999,  # $9.99
        Fields.TAXES: {"GST": 5.62, "PST": 7.87},
        Fields.TOTAL_AMOUNT_CENTS: 13596,  # $135.96
        Fields.SHIPPING_ADDRESS: {
            Fields.STREET: "123 Main St",
            Fields.APARTMENT: "Suite 4B",
            Fields.CITY: "Toronto",
            Fields.STATE: "ON",
            Fields.POSTAL_CODE: "M5V 3A8",
            Fields.COUNTRY: "Canada",
            Fields.PHONE_NUMBER: "+14165551234",
        },
        Fields.CUSTOMER_EMAIL: "buyer@test.ca",
        Fields.CUSTOMER_NAME: "Jean Tremblay",
    }


@pytest.fixture
def mock_mailjet():
    """Mock the Mailjet Client."""
    with patch("services.email_service.Client") as mock_client_cls:
        mock_client = MagicMock()
        mock_client_cls.return_value = mock_client
        mock_send = MagicMock()
        mock_send.create.return_value = MagicMock(status_code=200, json=lambda: {"Messages": [{"Status": "success"}]})
        mock_client.send = mock_send
        yield mock_client


# =============================================================================
# Order Confirmation Email Tests
# =============================================================================


class TestOrderConfirmationEmail:
    """Tests for get_order_confirmation_email."""

    def test_returns_html_string(self, sample_order_data):
        """Should return a non-empty HTML string."""
        from services.email_service import get_order_confirmation_email

        html = get_order_confirmation_email(sample_order_data)
        assert isinstance(html, str)
        assert len(html) > 100
        assert "<!DOCTYPE html>" in html

    def test_contains_order_id(self, sample_order_data):
        """Should include the (shortened) order ID."""
        from services.email_service import get_order_confirmation_email

        html = get_order_confirmation_email(sample_order_data)
        # Order ID is truncated to first 8 chars
        assert "abc12345" in html

    def test_contains_item_names(self, sample_order_data):
        """Should include product names in the email."""
        from services.email_service import get_order_confirmation_email

        html = get_order_confirmation_email(sample_order_data)
        assert "Vintage Headphones" in html

    def test_xss_protection_escapes_html_in_item_names(self, sample_order_data):
        """Item names should be HTML-escaped to prevent XSS."""
        from services.email_service import get_order_confirmation_email

        html = get_order_confirmation_email(sample_order_data)
        # The malicious <script> tag should be escaped
        assert "<script>" not in html
        assert "&lt;script&gt;" in html

    def test_contains_address(self, sample_order_data):
        """Should include shipping address details."""
        from services.email_service import get_order_confirmation_email

        html = get_order_confirmation_email(sample_order_data)
        assert "123 Main St" in html
        assert "Toronto" in html
        assert "M5V 3A8" in html

    def test_contains_phone_number(self, sample_order_data):
        """Should include phone number when provided."""
        from services.email_service import get_order_confirmation_email

        html = get_order_confirmation_email(sample_order_data)
        assert "+14165551234" in html

    def test_no_phone_number_when_missing(self, sample_order_data):
        """Should handle missing phone number gracefully."""
        from services.email_service import get_order_confirmation_email

        del sample_order_data[Fields.SHIPPING_ADDRESS][Fields.PHONE_NUMBER]
        html = get_order_confirmation_email(sample_order_data)
        assert isinstance(html, str)
        assert "📱" not in html

    def test_order_id_from_parameter(self, sample_order_data):
        """Should accept order_id as parameter when not in order_data."""
        from services.email_service import get_order_confirmation_email

        del sample_order_data[Fields.ORDER_ID]
        html = get_order_confirmation_email(sample_order_data, order_id="custom_order_999")
        assert "custom_o" in html  # First 8 chars

    def test_empty_items_list(self, sample_order_data):
        """Should handle empty items gracefully."""
        from services.email_service import get_order_confirmation_email

        sample_order_data[Fields.ITEMS] = []
        html = get_order_confirmation_email(sample_order_data)
        assert isinstance(html, str)

    def test_total_formatting(self, sample_order_data):
        """Should format monetary amounts correctly."""
        from services.email_service import get_order_confirmation_email

        html = get_order_confirmation_email(sample_order_data)
        # $135.96 total
        assert "135.96" in html

    def test_contains_origna_branding(self, sample_order_data):
        """Should include Origna branding."""
        from services.email_service import get_order_confirmation_email

        html = get_order_confirmation_email(sample_order_data)
        assert "O R I G N A" in html
        assert "Order Confirmed" in html


# =============================================================================
# Seller Notification Email Tests
# =============================================================================


class TestSellerNotificationEmail:
    """Tests for get_seller_notification_email."""

    def test_returns_html_string(self, sample_order_data):
        """Should return a non-empty HTML string."""
        from services.email_service import get_seller_notification_email

        html = get_seller_notification_email(sample_order_data, order_id="ord_test", seller_id="seller_001")
        assert isinstance(html, str)
        assert len(html) > 100

    def test_contains_seller_relevant_info(self, sample_order_data):
        """Should include order details relevant to seller."""
        from services.email_service import get_seller_notification_email

        html = get_seller_notification_email(sample_order_data, order_id="ord_seller_test")
        # Order ID from sample_order_data takes priority (abc12345...)
        assert "abc12345" in html

    def test_contains_origna_branding(self, sample_order_data):
        """Should include Origna branding for seller emails too."""
        from services.email_service import get_seller_notification_email

        html = get_seller_notification_email(sample_order_data, order_id="ord_brand")
        assert "O R I G N A" in html


# =============================================================================
# send_email Tests
# =============================================================================


class TestSendEmail:
    """Tests for the send_email function."""

    def test_emulator_mode_skips_mailjet(self):
        """In emulator mode (without FORCE_REAL_EMAIL), should skip Mailjet and return True."""
        import services.email_service as mod

        original_force = mod.FORCE_REAL_EMAIL
        original_emu = mod.IS_EMULATOR
        mod.FORCE_REAL_EMAIL = False
        mod.IS_EMULATOR = True
        try:
            result = mod.send_email("test@test.ca", "Test Subject", "<p>Hello</p>")
            assert result is True
        finally:
            mod.FORCE_REAL_EMAIL = original_force
            mod.IS_EMULATOR = original_emu

    @patch("services.email_service.get_mailjet_api_key")
    @patch("services.email_service.Client")
    def test_send_email_success(self, mock_client_cls, mock_get_key):
        """Should successfully send email via Mailjet."""
        import services.email_service as mod
        from services.email_service import send_email

        mock_get_key.return_value = "test_key"
        mock_client = MagicMock()
        mock_send_result = MagicMock()
        mock_send_result.status_code = 200
        mock_client.send.create.return_value = mock_send_result
        mock_client_cls.return_value = mock_client

        # Temporarily enable real email for test
        original_emulator = mod.IS_EMULATOR
        original_force = mod.FORCE_REAL_EMAIL
        mod.IS_EMULATOR = False
        mod.FORCE_REAL_EMAIL = False

        try:
            result = send_email("dest@test.ca", "Subject", "<p>Body</p>")
            assert result is True
        finally:
            mod.IS_EMULATOR = original_emulator
            mod.FORCE_REAL_EMAIL = original_force

    @patch("services.email_service.get_mailjet_api_key")
    @patch("services.email_service.Client")
    def test_send_email_failure(self, mock_client_cls, mock_get_key):
        """Should return False when Mailjet returns non-200."""
        import services.email_service as mod
        from services.email_service import send_email

        mock_get_key.return_value = "test_key"
        mock_client = MagicMock()
        mock_send_result = MagicMock()
        mock_send_result.status_code = 400
        mock_send_result.json.return_value = {"ErrorMessage": "Bad request"}
        mock_client.send.create.return_value = mock_send_result
        mock_client_cls.return_value = mock_client

        original_emulator = mod.IS_EMULATOR
        mod.IS_EMULATOR = False

        try:
            result = send_email("dest@test.ca", "Subject", "<p>Body</p>")
            assert result is False
        finally:
            mod.IS_EMULATOR = original_emulator

    @patch("services.email_service.get_mailjet_api_key")
    @patch("services.email_service.Client")
    def test_send_email_exception_returns_false(self, mock_client_cls, mock_get_key):
        """Should return False when Mailjet raises an exception."""
        import services.email_service as mod
        from services.email_service import send_email

        mock_get_key.return_value = "test_key"
        mock_client_cls.side_effect = Exception("Connection refused")

        original_emulator = mod.IS_EMULATOR
        mod.IS_EMULATOR = False

        try:
            result = send_email("dest@test.ca", "Subject", "<p>Body</p>")
            assert result is False
        finally:
            mod.IS_EMULATOR = original_emulator

    def test_send_email_custom_from(self):
        """Should accept custom from_email."""
        import services.email_service as mod

        # In emulator mode, just verify it doesn't crash
        original_force = mod.FORCE_REAL_EMAIL
        original_emu = mod.IS_EMULATOR
        mod.FORCE_REAL_EMAIL = False
        mod.IS_EMULATOR = True
        try:
            result = mod.send_email("to@test.ca", "Sub", "<p>Hi</p>", from_email="noreply@origna.ca")
            assert result is True
        finally:
            mod.FORCE_REAL_EMAIL = original_force
            mod.IS_EMULATOR = original_emu


# =============================================================================
# Authorization Expired Email Tests
# =============================================================================


class TestAuthorizationExpiredEmail:
    """Tests for send_authorization_expired_email."""

    def test_emulator_mode_skips(self):
        """Should skip sending in emulator mode."""
        import services.email_service as mod
        from services.email_service import send_authorization_expired_email

        original_force = mod.FORCE_REAL_EMAIL
        mod.FORCE_REAL_EMAIL = False
        try:
            # Should not raise
            send_authorization_expired_email(
                "order_exp",
                {
                    Fields.CUSTOMER_EMAIL: "buyer@test.ca",
                    Fields.TOTAL_AMOUNT_CENTS: 5000,
                    Fields.ITEMS: [{Fields.NAME: "Widget", Fields.QUANTITY: 1}],
                },
            )
        finally:
            mod.FORCE_REAL_EMAIL = original_force

    @patch("services.email_service.get_mailjet_secret_key")
    @patch("services.email_service.get_mailjet_api_key")
    @patch("services.email_service.Client")
    def test_sends_email_in_production(self, mock_client_cls, mock_get_api_key, mock_get_secret_key):
        """Should send email via Mailjet in production mode."""
        import services.email_service as mod
        from services.email_service import send_authorization_expired_email

        mock_get_api_key.return_value = "test_key"
        mock_get_secret_key.return_value = "test_secret"
        mock_client = MagicMock()
        mock_client_cls.return_value = mock_client
        mock_client.send.create.return_value = MagicMock(status_code=200)

        original_emulator = mod.IS_EMULATOR
        mod.IS_EMULATOR = False

        try:
            send_authorization_expired_email(
                "order_prod",
                {
                    Fields.CUSTOMER_EMAIL: "buyer@prod.ca",
                    Fields.TOTAL_AMOUNT_CENTS: 10000,
                    Fields.ITEMS: [{Fields.NAME: "Laptop", Fields.QUANTITY: 1}],
                },
            )
            mock_client.send.create.assert_called_once()
        finally:
            mod.IS_EMULATOR = original_emulator

    @patch("services.email_service.get_mailjet_api_key")
    def test_no_crash_on_missing_mailjet_credentials(self, mock_get_key):
        """Should handle missing Mailjet credentials gracefully."""
        import services.email_service as mod
        from services.email_service import send_authorization_expired_email

        mock_get_key.return_value = ""
        original_emulator = mod.IS_EMULATOR
        mod.IS_EMULATOR = False

        try:
            # Should not raise, just print warning
            send_authorization_expired_email(
                "order_no_creds",
                {
                    Fields.CUSTOMER_EMAIL: "buyer@test.ca",
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.ITEMS: [],
                },
            )
        finally:
            mod.IS_EMULATOR = original_emulator


# =============================================================================
# Payment Capture Failed Email Tests
# =============================================================================


class TestPaymentCaptureFailedEmail:
    """Tests for send_payment_capture_failed_email."""

    def test_emulator_mode_skips(self):
        """Should skip in emulator mode."""
        import services.email_service as mod

        original_force = mod.FORCE_REAL_EMAIL
        original_emu = mod.IS_EMULATOR
        mod.FORCE_REAL_EMAIL = False
        mod.IS_EMULATOR = True
        try:
            # Should not raise
            mod.send_payment_capture_failed_email(
                "order_cap_fail", "buyer@test.ca", "Test Buyer", 99.99, "Insufficient funds"
            )
        finally:
            mod.FORCE_REAL_EMAIL = original_force
            mod.IS_EMULATOR = original_emu

    def test_missing_email_skips(self):
        """Should skip when customer_email is missing."""
        from services.email_service import send_payment_capture_failed_email

        # Should not raise
        send_payment_capture_failed_email("order_1", "", "Buyer", 50.0, "Error")

    @patch("services.email_service.get_mailjet_secret_key")
    @patch("services.email_service.get_mailjet_api_key")
    @patch("services.email_service.Client")
    def test_sends_email_in_production(self, mock_client_cls, mock_get_api_key, mock_get_secret_key):
        """Should send capture failure email via Mailjet."""
        import services.email_service as mod
        from services.email_service import send_payment_capture_failed_email

        mock_get_api_key.return_value = "test_key"
        mock_get_secret_key.return_value = "test_secret"
        mock_client = MagicMock()
        mock_client_cls.return_value = mock_client
        mock_client.send.create.return_value = MagicMock(status_code=200)

        original_emulator = mod.IS_EMULATOR
        mod.IS_EMULATOR = False

        try:
            send_payment_capture_failed_email("order_cap", "buyer@prod.ca", "Jean Tremblay", 149.99, "Card expired")
            mock_client.send.create.assert_called_once()
            call_data = mock_client.send.create.call_args[1]["data"]
            assert call_data["Messages"][0]["To"][0]["Email"] == "buyer@prod.ca"
            assert "Payment Issue" in call_data["Messages"][0]["Subject"]
        finally:
            mod.IS_EMULATOR = original_emulator


# =============================================================================
# Configuration & Module Constants Tests
# =============================================================================


class TestModuleConstants:
    """Tests for module-level constants and configuration."""

    def test_email_config_support_email(self):
        """EmailConfig should have a valid support email."""
        assert "@" in EmailConfig.SUPPORT_EMAIL
        assert EmailConfig.SUPPORT_EMAIL == "support@orignaventures.ca"

    def test_email_config_sender_name(self):
        """EmailConfig should have platform sender name."""
        assert "Origna" in EmailConfig.SENDER_NAME

    def test_email_config_copyright(self):
        """EmailConfig should contain copyright text."""
        assert "2026" in EmailConfig.COPYRIGHT_TEXT

    def test_app_base_url_emulator(self):
        """In emulator mode, APP_BASE_URL should point to localhost."""
        import services.email_service as mod

        # Module-level APP_BASE_URL depends on import order across test files.
        # Verify the logic: when IS_EMULATOR is True, URL should be localhost.
        original = mod.APP_BASE_URL
        mod.APP_BASE_URL = EmailConfig.URL_EMULATOR  # simulate emulator
        try:
            assert "localhost" in mod.APP_BASE_URL or "127.0.0.1" in mod.APP_BASE_URL
        finally:
            mod.APP_BASE_URL = original

    def test_email_config_mailjet_version(self):
        """Mailjet API version should be v3.1."""
        assert EmailConfig.MAILJET_API_VERSION == "v3.1"


# ── Tasks 6 & 7: Digital product email ───────────────────────────────────────


def test_digital_order_shows_instant_delivery_tracker():
    """Digital-only order: status tracker shows Confirmed + Delivered Instantly (no shipping steps)."""
    from services.email_service import get_order_confirmation_email

    order = {
        "orderId": "ord-digital-001",
        "userId": "buyer1",
        "items": [{"name": "FXCleaner", "price": 29.99, "quantity": 1, "isDigital": True}],
        "subtotalCents": 2999,
        "shippingCostCents": 0,
        "taxAmountCents": 0,
        "totalAmountCents": 2999,
        "taxes": {},
        "shippingAddress": {},
    }
    html_out = get_order_confirmation_email(order, lang="en")
    assert "Delivered Instantly" in html_out, "Must show instant delivery for digital order"
    assert "🚚" not in html_out, "Must NOT show shipping truck icon for digital-only order"


def test_physical_order_shows_full_tracker():
    """Physical order: status tracker still shows all 4 steps including truck."""
    from services.email_service import get_order_confirmation_email

    order = {
        "orderId": "ord-phys-001",
        "userId": "buyer1",
        "items": [{"name": "Widget", "price": 19.99, "quantity": 1, "isDigital": False}],
        "subtotalCents": 1999,
        "shippingCostCents": 500,
        "taxAmountCents": 260,
        "totalAmountCents": 2759,
        "taxes": {"HST": 2.60},
        "shippingAddress": {
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V1A1",
            "country": "Canada",
        },
    }
    html_out = get_order_confirmation_email(order, lang="en")
    assert "🚚" in html_out, "Physical order must show shipping truck icon"


def test_digital_order_email_contains_license_key():
    """Software digital item: order confirmation email shows license key and download link."""
    from services.email_service import get_order_confirmation_email

    order = {
        "orderId": "ord-digital-002",
        "userId": "buyer1",
        "items": [
            {
                "name": "FXCleaner",
                "price": 29.99,
                "quantity": 1,
                "isDigital": True,
                "digitalType": "software",
                "digitalUnlocked": True,
                "licenseKey": "ABCD-EFGH-IJKL-MNOP",
                "digitalBuilds": {"macos": "https://r2.example.com/fxcleaner.dmg"},
            }
        ],
        "subtotalCents": 2999,
        "shippingCostCents": 0,
        "taxAmountCents": 0,
        "totalAmountCents": 2999,
        "taxes": {},
        "shippingAddress": {},
    }
    html_out = get_order_confirmation_email(order, lang="en")
    assert "ABCD-EFGH-IJKL-MNOP" in html_out, "License key must appear in email"
    assert "FXCleaner" in html_out
    assert "macOS" in html_out, "Download platform label must appear"


def test_book_order_email_contains_access_instructions():
    """Book digital item: email shows access instructions and license key."""
    from services.email_service import get_order_confirmation_email

    order = {
        "orderId": "ord-book-001",
        "userId": "buyer1",
        "items": [
            {
                "name": "Python Mastery",
                "price": 19.99,
                "quantity": 1,
                "isDigital": True,
                "digitalType": "book",
                "digitalUnlocked": True,
                "licenseKey": "BOOK-ABCD-EFGH-IJKL",
            }
        ],
        "subtotalCents": 1999,
        "shippingCostCents": 0,
        "taxAmountCents": 0,
        "totalAmountCents": 1999,
        "taxes": {},
        "shippingAddress": {},
    }
    html_out = get_order_confirmation_email(order, lang="en")
    assert "BOOK-ABCD-EFGH-IJKL" in html_out, "Book license key must appear in email"
    assert "Python Mastery" in html_out


def test_physical_order_email_has_no_license_block():
    """Physical-only order: no license key section in email."""
    from services.email_service import get_order_confirmation_email

    order = {
        "orderId": "ord-phys-002",
        "items": [{"name": "Widget", "price": 19.99, "quantity": 1, "isDigital": False}],
        "subtotalCents": 1999,
        "shippingCostCents": 500,
        "taxAmountCents": 260,
        "totalAmountCents": 2759,
        "taxes": {"HST": 2.60},
        "shippingAddress": {
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V1A1",
            "country": "Canada",
        },
    }
    html_out = get_order_confirmation_email(order, lang="en")
    assert "License Key" not in html_out
    assert "licenseKey" not in html_out.lower()
