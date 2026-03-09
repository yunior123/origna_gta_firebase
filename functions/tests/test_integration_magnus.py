"""
Magnus Carlsen Level Integration Tests — OrignaGta
Focuses on deep adversarial scenarios, edge cases, and complex business logic.
Target: >10 tests per critical cloud function.
"""

import json
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock, Mock, patch

import pytest
from firebase_functions import https_fn

from handlers.orders import cancel_order

# Import handlers
from handlers.payment_stripe import capture_payment, create_checkout_session, stripe_webhook
from schema_constants import (
    Collections,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
    ProductLifecycleStatusValues,
    UserRoleValues,
)


@pytest.fixture(autouse=True)
def disable_rate_limiter():
    """Disable rate limiter for all tests in this module."""
    with patch("services.rate_limiter.RateLimiter.check_rate_limit", return_value=(True, "OK")):
        yield


@pytest.fixture
def base_request():
    """Base request with auth."""
    req = Mock()
    req.auth = Mock(uid="buyer_123")
    req.auth.token = {"email_verified": True}
    return req


class TestCreateCheckoutSessionMagnus:
    """
    Comprehensive tests for create_checkout_session.
    """

    @pytest.fixture
    def setup_mocks(self, firestore_mock_builder, monkeypatch):
        """Setup common mocks for checkout session."""
        # Stripe
        with patch("handlers.payment_stripe.stripe.checkout.Session.create") as mock_stripe:
            mock_stripe.return_value = Mock(id="cs_123", url="https://stripe.com/pay")

            # Tax/shipping helpers
            with (
                patch("handlers.payment_stripe.get_tax_rate", return_value=0.13),
                patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(10.00, {}))
            ):
                yield firestore_mock_builder, mock_stripe

    def test_01_successful_multi_item(self, setup_mocks, base_request):
        """Function test_01_successful_multi_item."""
        builder, stripe_mock = setup_mocks
        builder.add_user("buyer_123")
        builder.add_seller("s1")
        builder.add_seller("s2")
        builder.add_product("p1", "s1", price=50.0)
        builder.add_product("p2", "s2", price=30.0)

        mock_db = builder.build_mock_db()
        with patch("handlers.payment_stripe.get_db", return_value=mock_db):
            base_request.data = {
                "items": [
                    {"productId": "p1", "quantity": 1, "price": 50.0, "sellerId": "s1"},
                    {"productId": "p2", "quantity": 2, "price": 30.0, "sellerId": "s2"}
                ],
                "subtotalCents": 11000,
                "shippingAddress": {
                    "street": "123 Main St", "city": "Toronto", "country": "Canada", "state": "ON", "postalCode": "M5V2A8"
                }
            }
            res = create_checkout_session(base_request)
            assert res["success"] is True

    def test_02_price_tampering(self, setup_mocks, base_request):
        """Function test_02_price_tampering."""
        builder, _ = setup_mocks
        builder.add_user("buyer_123")
        builder.add_seller("s1")
        builder.add_product("p1", "s1", price=50.0)

        mock_db = builder.build_mock_db()
        with patch("handlers.payment_stripe.get_db", return_value=mock_db):
            base_request.data = {
                "items": [{"productId": "p1", "quantity": 1, "price": 40.0, "sellerId": "s1"}],
                "subtotalCents": 4000,
                "shippingAddress": {"street": "1 S", "city": "T", "country": "Canada", "state": "ON", "postalCode": "M5V2A8"}
            }
            with pytest.raises(https_fn.HttpsError) as exc:
                create_checkout_session(base_request)
            assert exc.value.code == "invalid-argument"


class TestStripeWebhookMagnus:
    """
    Comprehensive tests for stripe_webhook.
    """

    @pytest.fixture
    def setup_mocks(self, firestore_mock_builder, monkeypatch):
        """Setup common mocks."""
        monkeypatch.setattr("handlers.payment_stripe.IS_EMULATOR", False)
        with patch("handlers.payment_stripe.stripe.Webhook.construct_event") as mock_construct:
            yield firestore_mock_builder, mock_construct

    def test_01_signature_missing(self, setup_mocks):
        """Function test_01_signature_missing."""
        builder, _ = setup_mocks
        req = Mock()
        req.method = "POST"
        req.headers = {}
        req.data = b'{}'

        mock_db = builder.build_mock_db()
        with patch("handlers.payment_stripe.get_db", return_value=mock_db):
            res = stripe_webhook(req)
            assert res.status_code == 400


class TestCapturePaymentMagnus:
    """
    Comprehensive tests for capture_payment.
    """

    @pytest.fixture
    def setup_mocks(self, firestore_mock_builder, monkeypatch):
        """Setup common mocks."""
        with patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve") as pi_ret, \
             patch("handlers.payment_stripe.stripe.PaymentIntent.capture") as pi_cap, \
             patch("handlers.payment_stripe.stripe.Charge.retrieve") as ch_ret:
            yield firestore_mock_builder, pi_ret, pi_cap, ch_ret

    def test_01_successful_capture(self, setup_mocks, base_request):
        """Function test_01_successful_capture."""
        builder, pi_ret, pi_cap, ch_ret = setup_mocks
        builder.add_order("o1", payment_status="authorized", order_status="shipped")

        base_request.auth.token = {"admin": True}
        base_request.data = {"orderId": "o1"}

        pi_ret.return_value = Mock(status="requires_capture", amount=10000)
        pi_cap.return_value = Mock(status="succeeded", latest_charge="ch_1")
        ch_ret.return_value = Mock(dispute=None)

        mock_db = builder.build_mock_db()
        with patch("handlers.payment_stripe.get_db", return_value=mock_db):
            res = capture_payment(base_request)
            assert res["success"] is True

    def test_02_non_admin_rejection(self, setup_mocks, base_request):
        """Function test_02_non_admin_rejection."""
        base_request.auth.token = {"admin": False}
        base_request.data = {"orderId": "o1"}
        with pytest.raises(https_fn.HttpsError) as exc:
            capture_payment(base_request)
        assert exc.value.code == "permission-denied"
