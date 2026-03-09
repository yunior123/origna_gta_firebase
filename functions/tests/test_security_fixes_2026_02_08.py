"""
Security Fixes Tests - 2026-02-08
Tests for:
1. Email verification bypass fix
2. Stock re-validation at payment completion
3. Rate limiting on suspend_seller and create_connect_account

Run: cd functions && python -m pytest tests/test_security_fixes_2026_02_08.py -v
"""

from datetime import datetime
from unittest.mock import MagicMock, Mock, patch

import pytest

# =============================================================================
# TEST FIX 1: Stock Re-validation in process_checkout_session_completed
# =============================================================================


class TestStockRevalidation:
    """Tests that products are re-validated when payment completes."""

    def test_product_deactivated_cancels_order(self, mock_firestore_client):
        """FIX-002: If product deactivated between checkout and payment, order cancelled."""
        from handlers.payment_stripe import process_checkout_session_completed

        mock_db = mock_firestore_client

        # Setup: Order with one item
        order_data = {
            "userId": "buyer_123",
            "orderStatus": "pending",
            "totalAmountCents": 2000,
            "items": [{"productId": "prod_123", "sellerId": "seller_123", "quantity": 2, "price": 10.0}],
            "stripePaymentIntentId": "pi_test_123",
            "stockRestored": False,
        }

        # Mock order reference that will be updated
        mock_order_ref = Mock()
        mock_order_ref.update = Mock()

        # Mock order exists
        mock_order_doc = Mock()
        mock_order_doc.exists = True
        mock_order_doc.to_dict.return_value = order_data
        mock_order_doc.reference = mock_order_ref

        # Mock product is DEACTIVATED
        mock_product_doc = Mock()
        mock_product_doc.exists = True
        mock_product_doc.to_dict.return_value = {"lifecycleStatus": "paused", "name": "Test Product"}

        # Mock seller is active
        mock_seller_doc = Mock()
        mock_seller_doc.exists = True
        mock_seller_doc.to_dict.return_value = {"suspended": False}

        def collection_side_effect(name):
            """Function collection_side_effect."""
            coll = Mock()
            if name == "orders":
                # document() should return order_ref which has .get() and .update()
                order_ref_mock = Mock()
                order_ref_mock.get.return_value = mock_order_doc
                # When order_ref.update() is called, record it on mock_order_ref
                order_ref_mock.update = mock_order_ref.update
                coll.document.return_value = order_ref_mock
            elif name == "products":
                coll.document.return_value.get.return_value = mock_product_doc
            elif name == "users":
                coll.document.return_value.get.return_value = mock_seller_doc
            return coll

        mock_db.collection.side_effect = collection_side_effect

        # Mock Stripe PaymentIntent.cancel and .retrieve
        with (
            patch("handlers.payment_stripe.stripe.PaymentIntent.cancel") as mock_cancel,
            patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve") as mock_retrieve,
        ):
            mock_retrieve.return_value = Mock(status="requires_capture")
            session = {
                "metadata": {"order_id": "order_123"},
                "payment_intent": "pi_test_123",
                "payment_status": "paid",
                "amount_total": 2000,
            }

            result = process_checkout_session_completed(session)

            # Order should be cancelled, not confirmed
            assert result is not None and "cancelled" in result.lower()
            # Stock restore uses a transaction
            mock_db.transaction.assert_called()
            mock_cancel.assert_called_once()

    def test_seller_suspended_cancels_order(self, mock_firestore_client):
        """FIX-002: If seller suspended between checkout and payment, order cancelled."""
        from handlers.payment_stripe import process_checkout_session_completed

        mock_db = mock_firestore_client

        order_data = {
            "userId": "buyer_123",
            "orderStatus": "pending",
            "totalAmountCents": 2000,
            "items": [{"productId": "prod_123", "sellerId": "seller_123", "quantity": 1, "price": 10.0}],
            "stripePaymentIntentId": "pi_test_123",
            "stockRestored": False,
        }

        mock_order_doc = Mock()
        mock_order_doc.exists = True
        mock_order_doc.to_dict.return_value = order_data
        mock_order_doc.reference = Mock()

        # Product is active
        mock_product_doc = Mock()
        mock_product_doc.exists = True
        mock_product_doc.to_dict.return_value = {"lifecycleStatus": "active"}

        # But SELLER IS SUSPENDED
        mock_seller_doc = Mock()
        mock_seller_doc.exists = True
        mock_seller_doc.to_dict.return_value = {"suspended": True}

        def collection_side_effect(name):
            """Function collection_side_effect."""
            coll = Mock()
            if name == "orders":
                coll.document.return_value.get.return_value = mock_order_doc
            elif name == "products":
                coll.document.return_value.get.return_value = mock_product_doc
            elif name == "users":
                coll.document.return_value.get.return_value = mock_seller_doc
            return coll

        mock_db.collection.side_effect = collection_side_effect

        with (
            patch("handlers.payment_stripe.stripe.PaymentIntent.cancel") as mock_cancel,
            patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve") as mock_retrieve,
        ):
            mock_retrieve.return_value = Mock(status="requires_capture")
            session = {
                "metadata": {"order_id": "order_123"},
                "payment_intent": "pi_test_123",
                "payment_status": "paid",
                "amount_total": 2000,
            }

            result = process_checkout_session_completed(session)

            assert result is not None and "cancelled" in result.lower()
            assert "cancelled - all sellers invalid" in result.lower()
            mock_cancel.assert_called_once()

    def test_product_removed_cancels_order(self, mock_firestore_client):
        """FIX-002: If product deleted between checkout and payment, order cancelled."""
        from handlers.payment_stripe import process_checkout_session_completed

        mock_db = mock_firestore_client

        order_data = {
            "userId": "buyer_123",
            "orderStatus": "pending",
            "totalAmountCents": 2000,
            "items": [{"productId": "prod_deleted", "sellerId": "seller_123", "quantity": 1, "price": 10.0}],
            "stripePaymentIntentId": "pi_test_123",
            "stockRestored": False,
        }

        mock_order_doc = Mock()
        mock_order_doc.exists = True
        mock_order_doc.to_dict.return_value = order_data
        mock_order_doc.reference = Mock()

        # Product NO LONGER EXISTS
        mock_product_doc = Mock()
        mock_product_doc.exists = False

        def collection_side_effect(name):
            """Function collection_side_effect."""
            coll = Mock()
            if name == "orders":
                coll.document.return_value.get.return_value = mock_order_doc
            elif name == "products":
                coll.document.return_value.get.return_value = mock_product_doc
            return coll

        mock_db.collection.side_effect = collection_side_effect

        with (
            patch("handlers.payment_stripe.stripe.PaymentIntent.cancel"),
            patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve") as mock_retrieve,
        ):
            mock_retrieve.return_value = Mock(status="requires_capture")
            session = {
                "metadata": {"order_id": "order_123"},
                "payment_intent": "pi_test_123",
                "payment_status": "paid",
                "amount_total": 2000,
            }

            result = process_checkout_session_completed(session)

            assert result is not None and "cancelled" in result.lower()
            assert "cancelled - all sellers invalid" in result.lower()

    def test_valid_product_confirms_order(self, mock_firestore_client):
        """FIX-002: Valid active product with non-suspended seller confirms order."""
        from handlers.payment_stripe import process_checkout_session_completed

        mock_db = mock_firestore_client

        order_data = {
            "userId": "buyer_123",
            "customerEmail": "buyer@example.com",
            "orderStatus": "pending",
            "totalAmountCents": 1000,
            "items": [{"productId": "prod_123", "sellerId": "seller_123", "quantity": 1, "price": 10.0}],
            "stripePaymentIntentId": "pi_test_123",
            "stockRestored": False,
        }

        # Mock order reference that will be updated
        mock_order_ref = Mock()
        mock_order_ref.update = Mock()

        mock_order_doc = Mock()
        mock_order_doc.exists = True
        mock_order_doc.to_dict.return_value = order_data
        mock_order_doc.reference = mock_order_ref

        # Product active
        mock_product_doc = Mock()
        mock_product_doc.exists = True
        mock_product_doc.to_dict.return_value = {"lifecycleStatus": "active"}

        # Seller active
        mock_seller_doc = Mock()
        mock_seller_doc.exists = True
        mock_seller_doc.to_dict.return_value = {"suspended": False}

        def collection_side_effect(name):
            """Function collection_side_effect."""
            coll = Mock()
            if name == "orders":
                # document() should return order_ref which has .get() and .update()
                order_ref_mock = Mock()
                order_ref_mock.get.return_value = mock_order_doc
                # When order_ref.update() is called, record it on mock_order_ref
                order_ref_mock.update = mock_order_ref.update
                coll.document.return_value = order_ref_mock
            elif name == "products":
                coll.document.return_value.get.return_value = mock_product_doc
            elif name == "users":
                coll.document.return_value.get.return_value = mock_seller_doc
            return coll

        mock_db.collection.side_effect = collection_side_effect

        # Mock email functions
        with (
            patch("handlers.payment_stripe.get_order_confirmation_email", return_value="html"),
            patch("handlers.payment_stripe.get_seller_notification_email", return_value="html"),
            patch("handlers.payment_stripe.send_email"),
            patch("handlers.payment_stripe._clear_user_cart"),
        ):
            session = {
                "metadata": {"order_id": "order_123"},
                "payment_intent": "pi_test_123",
                "payment_status": "paid",
                "amount_total": 1000,
            }

            result = process_checkout_session_completed(session)

            # Order should be confirmed
            assert result is not None and "confirmed" in result.lower()
            mock_order_ref.update.assert_called()


# =============================================================================
# TEST FIX 2: Rate Limiting on suspend_seller
# =============================================================================


class TestSuspendSellerRateLimit:
    """Tests rate limiting on seller suspension."""

    @patch("handlers.admin.get_db")
    def test_suspend_seller_rate_limited(self, mock_get_db):
        """FIX-003: suspend_seller respects rate limiting."""
        from firebase_functions import https_fn

        from handlers.admin import suspend_seller

        # Mock rate limiter to reject - patch inside the function
        with patch("handlers.admin.RateLimiter") as mock_limiter_class:
            mock_limiter = Mock()
            mock_limiter.check_rate_limit.return_value = (False, "Rate limit exceeded: 10 requests per 1 minutes")
            mock_limiter_class.return_value = mock_limiter

            mock_db = Mock()
            mock_get_db.return_value = mock_db

            req = Mock()
            req.auth.uid = "admin_123"
            req.data = {"sellerId": "seller_456", "reason": "Test"}

            with pytest.raises(https_fn.HttpsError) as exc_info:
                suspend_seller(req)

            assert exc_info.value.code == "resource-exhausted"
            assert "Rate limit exceeded" in exc_info.value.message


# =============================================================================
# TEST FIX 3: Rate Limiting on create_connect_account
# =============================================================================


class TestCreateConnectAccountRateLimit:
    """Tests rate limiting on seller account creation."""

    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.get_rate_limiter")
    def test_create_connect_account_rate_limited(self, mock_get_limiter, mock_db):
        """FIX-003: create_connect_account respects rate limiting."""
        from firebase_functions import https_fn

        from handlers.payment_stripe import create_connect_account

        # Mock rate limiter to reject
        mock_limiter = Mock()
        mock_limiter.check_rate_limit.return_value = (False, "Rate limit exceeded: 3 requests per 60 minutes")
        mock_get_limiter.return_value = mock_limiter

        # Mock user exists but no stripe account
        mock_user_doc = Mock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {"email": "test@example.com", "roles": ["buyer"]}

        mock_db.return_value.collection.return_value.document.return_value.get.return_value = mock_user_doc

        req = Mock()
        req.auth.uid = "user_123"
        req.data = {}

        with pytest.raises(https_fn.HttpsError) as exc_info:
            create_connect_account(req)

        assert exc_info.value.code == "resource-exhausted"
        assert "Rate limit exceeded" in exc_info.value.message

    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.get_rate_limiter")
    def test_create_connect_account_allowed(self, mock_get_limiter, mock_db):
        """FIX-003: create_connect_account works when under rate limit."""
        from handlers.payment_stripe import create_connect_account

        # Mock rate limiter to allow
        mock_limiter = Mock()
        mock_limiter.check_rate_limit.return_value = (True, "OK")
        mock_get_limiter.return_value = mock_limiter

        # Mock user with EXISTING stripe account (idempotent)
        mock_user_doc = Mock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {
            "email": "test@example.com",
            "roles": ["buyer"],
            "stripeAccountId": "acct_existing",
        }

        mock_db.return_value.collection.return_value.document.return_value.get.return_value = mock_user_doc

        req = Mock()
        req.auth.uid = "user_123"
        req.data = {}

        result = create_connect_account(req)

        # Should return existing account
        assert result["success"] is True
        assert result["existing"] is True
        assert result["accountId"] == "acct_existing"


# =============================================================================
# FIXTURES
# =============================================================================


@pytest.fixture
def mock_firestore_client():
    """Mock Firestore client for testing."""
    with patch("handlers.payment_stripe.get_db") as mock:
        yield mock.return_value


@pytest.fixture
def mock_firestore_client_admin():
    """Mock Firestore client for admin handler testing."""
    with patch("handlers.admin.get_db") as mock:
        yield mock.return_value
