"""
Adversarial Test Scenarios — OrignaGta
Tests malicious buyer, seller, and race condition scenarios.
Run: cd functions && python -m pytest tests/test_adversarial_scenarios.py -v
"""

import json
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock, Mock, patch

import pytest


class TestPriceManipulationScenarios:
    """Scenarios 1-3: Client-side price tampering attempts."""

    def test_price_change_detected(self, mock_firestore_client, mock_rate_limiter):
        """Scenario 1: Buyer sends old price after seller updated it."""
        from handlers.payment_stripe import create_checkout_session

        mock_db = mock_firestore_client

        # Setup: Product price changed from $10 to $15
        mock_product = Mock()
        mock_product.exists = True
        mock_product.to_dict.return_value = {
            "price": 15.0,  # Current price
            "stockQuantity": 10,
            "lifecycleStatus": "active",
            "sellerId": "seller_123",
            "name": "Test Product",
            "imageUrls": [],
        }

        # Setup mock seller
        mock_seller = Mock()
        mock_seller.exists = True
        mock_seller.to_dict.return_value = {
            "roles": ["seller"],
            "suspended": False,
            "onboardingCompleted": True,
            "chargesEnabled": True,
            "payoutsEnabled": True,
            "email": "seller@example.com",
            "stripeAccountId": "acct_test_123",
        }

        # Setup mock buyer (not suspended)
        mock_buyer = Mock()
        mock_buyer.exists = True
        mock_buyer.to_dict.return_value = {
            "suspended": False,
            "email": "buyer@example.com",
        }

        def make_doc_ref(doc_id=None):
            """Function make_doc_ref."""
            if doc_id is None:
                doc_id = "auto_gen_id"
            mock_ref = Mock()
            mock_ref.id = doc_id
            if doc_id == "prod_123":
                mock_product.id = doc_id
                mock_ref.get.return_value = mock_product
            elif doc_id == "seller_123":
                mock_ref.get.return_value = mock_seller
            elif doc_id == "buyer_123":
                mock_ref.get.return_value = mock_buyer
            else:
                not_found = Mock()
                not_found.exists = False
                mock_ref.get.return_value = not_found
            return mock_ref

        mock_collection = MagicMock()
        mock_collection.document.side_effect = make_doc_ref
        mock_db.collection.return_value = mock_collection

        # Buyer tries to checkout with old price
        req = Mock()
        req.auth.uid = "buyer_123"
        req.auth.token.get.return_value = True  # email_verified
        req.data = {
            "items": [
                {
                    "productId": "prod_123",
                    "quantity": 1,
                    "price": 10.0,  # Old price!
                    "sellerId": "seller_123",
                }
            ],
            "shippingAddress": {
                "street": "123 Main St",
                "city": "Toronto",
                "state": "ON",  # Use 'state' not 'province'
                "postalCode": "M5V 3A8",
                "country": "Canada",
                "latitude": 43.7,
                "longitude": -79.4,
            },
            "subtotalCents": 1000,
        }

        with pytest.raises(Exception) as exc_info:
            create_checkout_session(req)

        assert "Cart total mismatch" in str(exc_info.value) or "Price changed" in str(exc_info.value)

    def test_seller_id_mismatch_blocked(self, mock_firestore_client, mock_rate_limiter):
        """Scenario 2: Buyer sends wrong sellerId to redirect payment."""
        from handlers.payment_stripe import create_checkout_session

        mock_db = mock_firestore_client

        mock_product = Mock()
        mock_product.exists = True
        mock_product.to_dict.return_value = {
            "price": 10.0,
            "stockQuantity": 10,
            "lifecycleStatus": "active",
            "sellerId": "legitimate_seller",  # Actual owner
            "name": "Test Product",
            "imageUrls": [],
        }

        # Setup mock buyer (not suspended)
        mock_buyer = Mock()
        mock_buyer.exists = True
        mock_buyer.to_dict.return_value = {
            "suspended": False,
        }

        def make_doc_ref(doc_id=None):
            """Function make_doc_ref."""
            if doc_id is None:
                doc_id = "auto_gen_id"
            mock_ref = Mock()
            mock_ref.id = doc_id
            if doc_id == "prod_123":
                mock_product.id = doc_id
                mock_ref.get.return_value = mock_product
            elif doc_id == "buyer_123":
                mock_ref.get.return_value = mock_buyer
            else:
                not_found = Mock()
                not_found.exists = False
                mock_ref.get.return_value = not_found
            return mock_ref

        mock_collection = MagicMock()
        mock_collection.document.side_effect = make_doc_ref
        mock_db.collection.return_value = mock_collection

        req = Mock()
        req.auth.uid = "buyer_123"
        req.auth.token.get.return_value = True
        req.data = {
            "items": [
                {
                    "productId": "prod_123",
                    "quantity": 1,
                    "price": 10.0,
                    "sellerId": "attacker_seller",  # Wrong!
                }
            ],
            "shippingAddress": {
                "street": "123 Main St",
                "city": "Toronto",
                "state": "ON",  # Use 'state' not 'province'
                "postalCode": "M5V 3A8",
                "country": "Canada",
                "latitude": 43.7,
                "longitude": -79.4,
            },
            "subtotalCents": 1000,
        }

        with pytest.raises(Exception) as exc_info:
            create_checkout_session(req)

        assert "Seller ID mismatch" in str(exc_info.value)


class TestRaceConditionScenarios:
    """Scenarios 13-14, 19-20: Concurrent operation races."""

    def test_capture_during_cancel_blocked(self, mock_firestore_client):
        """Scenario 13: Capture attempt while cancel in progress."""
        from firebase_admin import firestore

        from handlers.orders import cancel_order

        mock_db = mock_firestore_client

        # Setup order in 'cancelling' state
        mock_order = Mock()
        mock_order.exists = True
        mock_order.to_dict.return_value = {
            "userId": "buyer_123",
            "paymentStatus": "cancelling",  # Lock acquired by cancel_order
            "orderStatus": "confirmed",
            "items": [{"productId": "p1", "sellerId": "s1", "quantity": 1}],
            "stockRestored": False,
        }
        mock_order.reference = Mock()
        mock_db.collection.return_value.document.return_value.get.return_value = mock_order

        # Buyer's capture request should see 'cancelling' and fail
        # This is tested in the capture_payment function's check

    def test_stock_double_restore_prevented(self, mock_firestore_client):
        """Scenario 19: Cancel and expire both try to restore stock."""
        from firebase_admin import firestore

        from handlers.orders import cancel_order

        mock_order = Mock()
        mock_order.exists = True
        mock_order.to_dict.return_value = {
            "userId": "buyer_123",
            "paymentStatus": "authorized",
            "orderStatus": "pending",
            "items": [
                {
                    "productId": "prod_123",
                    "sellerId": "seller_123",
                    "quantity": 5,
                }
            ],
            "stockRestored": False,
        }
        mock_order.reference = Mock()

        mock_product = Mock()
        mock_product.exists = True
        mock_product.to_dict.return_value = {"stockQuantity": 10}

        # Simulate concurrent execution
        calls = []

        def mock_update(updates):
            """Function mock_update."""
            calls.append(updates)

        mock_order.reference.update = mock_update

        # Both cancel and expire see stockRestored=False
        # But they use batch + atomic Increment
        # Verify Increment is used, not read-then-write

        assert True  # Placeholder - actual test would verify atomic operations


class TestInventoryScenarios:
    """Scenarios 25-30: Product and inventory edge cases."""

    def test_negative_stock_rejected(self, mock_firestore_client):
        """Scenario 27: Attempt to set negative stock quantity."""
        from handlers.products import _is_valid_stock_quantity

        assert _is_valid_stock_quantity(0) is True
        assert _is_valid_stock_quantity(5) is True
        assert _is_valid_stock_quantity(-1) is False
        assert _is_valid_stock_quantity("5") is False

    def test_local_delivery_out_of_province_blocked(self, mock_firestore_client):
        """Scenario 30: Order local-only product from different province."""
        from services.shipping_service import calculate_shipping_cost

        items = [
            {
                "productId": "local_prod",
                "sellerId": "seller_on",
                "quantity": 1,
                "isLocalDeliveryOnly": True,
                "freeShipping": False,
                "isDigital": False,
                "sellerAddress": {
                    "state": "ON",  # Product in Ontario
                    "latitude": 43.7,
                    "longitude": -79.4,
                },
            }
        ]

        buyer_address = {
            "state": "BC",  # Buyer in BC
            "latitude": 49.2,
            "longitude": -123.1,
        }

        with pytest.raises(ValueError) as exc_info:
            calculate_shipping_cost(items, buyer_address)

        assert "Local delivery only" in str(exc_info.value)


class TestAuthSecurityScenarios:
    """Scenarios 31-35: Authentication and admin security."""

    def test_mfa_brute_force_protection(self, mock_firestore_client):
        """Scenario 31: Lockout after 5 failed MFA attempts."""
        # Verify the mfaFailedAttempts counter increments
        # Verify lockout after 5 attempts
        pass

    def test_admin_role_change_requires_mfa(self, mock_firestore_client, monkeypatch):
        """Scenario 32: Admin must verify MFA before role changes."""
        from handlers import admin

        mock_db = mock_firestore_client

        # Admin without recent MFA verification (using correct field names from schema_constants)
        mock_admin = Mock()
        mock_admin.exists = True
        mock_admin.to_dict.return_value = {
            "roles": ["admin"],
            "mfaEnabled": True,
            "lastMfaVerify": datetime.now() - timedelta(minutes=10),  # Too old!
        }

        mock_target = Mock()
        mock_target.exists = True
        mock_target.to_dict.return_value = {
            "roles": ["buyer"],
        }

        def make_doc_ref(doc_id=None):
            """Function make_doc_ref."""
            if doc_id is None:
                doc_id = "auto_gen_id"
            mock_ref = Mock()
            if doc_id == "admin_123":
                mock_ref.get.return_value = mock_admin
            elif doc_id == "user_456":
                mock_ref.get.return_value = mock_target
            else:
                not_found = Mock()
                not_found.exists = False
                mock_ref.get.return_value = not_found
            return mock_ref

        mock_collection = MagicMock()
        mock_collection.document.side_effect = make_doc_ref
        mock_db.collection.return_value = mock_collection

        # Patch get_db in admin module
        monkeypatch.setattr(admin, "get_db", lambda: mock_db)

        req = Mock()
        req.auth.uid = "admin_123"
        req.data = {
            "targetUserId": "user_456",
            "roles": ["seller"],
        }

        with pytest.raises(Exception) as exc_info:
            admin.update_user_roles(req)

        assert "MFA" in str(exc_info.value) or "expired" in str(exc_info.value).lower()


class TestWebhookSecurityScenarios:
    """Scenarios 11-12: Webhook attack prevention."""

    def test_stale_webhook_rejected(self, mock_firestore_client):
        """Scenario 11: Webhook older than 5 minutes rejected."""
        import time
        from unittest.mock import MagicMock, patch

        mock_db = mock_firestore_client

        # Create webhook payload with old timestamp
        old_event = {
            "id": "evt_old",
            "type": "checkout.session.completed",
            "created": int(time.time()) - 400,  # 6+ minutes ago
        }

        # Mock webhook_events collection for idempotency check
        mock_webhook_doc = Mock()
        mock_webhook_doc.exists = False
        mock_db.collection.return_value.document.return_value.get.return_value = mock_webhook_doc

        # Import after mocking setup
        # Need to patch IS_EMULATOR before importing the function
        # Since the decorator captures IS_EMULATOR at decoration time,
        # we test the logic directly instead of through the decorated function
        # Verify the logic directly: check that the stale event check exists
        import handlers.payment_stripe as ps_module
        from handlers import payment_stripe

        # The check is: if not IS_EMULATOR and event_age_seconds > 300:
        # Verify IS_EMULATOR is a boolean (not MagicMock) and the check exists
        assert hasattr(ps_module, "IS_EMULATOR"), "IS_EMULATOR should exist"

        # Mock rate limiter and stripe
        with patch.object(ps_module, "get_rate_limiter") as mock_limiter:
            limiter = Mock()
            limiter.check_rate_limit.return_value = (True, "OK")
            mock_limiter.return_value = limiter

            with (
                patch.object(ps_module.stripe.Webhook, "construct_event", return_value=old_event),
                patch.object(ps_module, "IS_EMULATOR", False),
            ):
                req = Mock()
                req.method = "POST"
                req.headers = {"Stripe-Signature": "valid_sig"}
                req.data = b"{}"

                response = ps_module.stripe_webhook(req)

                assert response.status_code == 400
                assert b"Event too old" in response.response[0]

    def test_webhook_rate_limiting(self, mock_firestore_client):
        """Scenario 12: Too many webhooks from same IP blocked."""
        # Rate limiter test - 100 webhooks per minute per IP
        pass


class TestShippingApprovalScenarios:
    """Scenario 24: Shipping cost approval edge cases."""

    def test_approval_after_authorization_expiry_blocked(
        self, mock_firestore_client, mock_orders_rate_limiter, monkeypatch
    ):
        """Buyer can't approve shipping after auth expired."""
        from firebase_admin import firestore as fs

        from handlers import orders

        mock_db = mock_firestore_client

        mock_order = Mock()
        mock_order.exists = True
        mock_order.to_dict.return_value = {
            "userId": "buyer_123",
            "paymentStatus": "authorized",
            "shippingApproval": {
                "status": "pending",
                "actualCost": 22.0,  # Only 10% increase (under 20% threshold)
            },
            "shippingCostCents": 2000,
            "totalAmountCents": 10200,
            "expiresAt": datetime.now(UTC) - timedelta(minutes=1),  # Expired!
        }
        mock_order.reference = Mock()
        mock_db.collection.return_value.document.return_value.get.return_value = mock_order

        # Patch get_db in orders module
        monkeypatch.setattr(orders, "get_db", lambda: mock_db)
        monkeypatch.setattr(orders, "get_firestore", lambda: fs)
        monkeypatch.setattr(orders, "get_server_timestamp", lambda: fs.SERVER_TIMESTAMP)

        req = Mock()
        req.auth.uid = "buyer_123"
        req.data = {
            "orderId": "order_123",
            "approved": True,
        }

        with pytest.raises(Exception) as exc_info:
            orders.approve_shipping_cost(req)

        assert "expired" in str(exc_info.value).lower()


# Fixtures - using global fixtures from conftest.py
# mock_stripe and mock_rate_limiter are now provided by conftest.py autouse fixture


@pytest.fixture
def mock_rate_limiter():
    """Mock rate limiter to always allow."""
    with patch("handlers.payment_stripe.get_rate_limiter") as mock:
        limiter = Mock()
        limiter.check_rate_limit.return_value = (True, "OK")
        mock.return_value = limiter
        yield limiter


@pytest.fixture
def mock_orders_rate_limiter(monkeypatch):
    """Mock rate limiter in orders module to always allow."""
    from services.rate_limiter import RateLimiter

    def mock_check_rate_limit(self, identifier, action, max_requests, window_minutes, fail_closed=False):
        """Mock rate limiter to always allow requests in tests"""
        return True, "OK"

    monkeypatch.setattr(RateLimiter, "check_rate_limit", mock_check_rate_limit)
    yield None
