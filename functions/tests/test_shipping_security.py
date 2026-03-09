"""Module test_shipping_security.py."""
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# Add parent directory to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# Set TESTING environment variable BEFORE importing main
os.environ["TESTING"] = "true"
os.environ.setdefault("FUNCTIONS_EMULATOR", "true")
os.environ.setdefault("UNSUBSCRIBE_HMAC_SECRET", "origna-unsub-default-dev-key")

# 1. Setup global mocks BEFORE importing main
mock_firebase_functions = MagicMock()
mock_firebase_admin = MagicMock()
mock_stripe = MagicMock()
mock_boto3 = MagicMock()
mock_mailjet = MagicMock()
mock_google_auth = MagicMock()
mock_google_cloud_firestore = MagicMock()
mock_secret_manager = MagicMock()


# Decorator passthrough
def pass_through_decorator(*args, **kwargs):
    """Function pass_through_decorator."""
    def decorator(f):
        """Function decorator."""
        return f

    return decorator


mock_firebase_functions.https_fn.on_call.side_effect = pass_through_decorator
mock_firebase_functions.https_fn.on_request.side_effect = pass_through_decorator
mock_firebase_functions.firestore_fn.on_document_updated.side_effect = pass_through_decorator
mock_firebase_functions.params.SecretParam.return_value.value = "test_key"
mock_firebase_admin.firestore.transactional = lambda f: f


class MockHttpsError(Exception):
    """Class MockHttpsError."""
    def __init__(self, code, message, details=None):
        """Function __init__."""
        self.code = code
        self.message = message
        self.details = details


mock_firebase_functions.https_fn.HttpsError = MockHttpsError
mock_firebase_functions.https_fn.FunctionsErrorCode = MagicMock()

module_mocks = {
    "firebase_functions": mock_firebase_functions,
    "firebase_functions.https_fn": mock_firebase_functions.https_fn,
    "firebase_functions.firestore_fn": mock_firebase_functions.firestore_fn,
    "firebase_functions.params": mock_firebase_functions.params,
    "firebase_functions.options": mock_firebase_functions.options,
    "firebase_functions.tasks_fn": mock_firebase_functions.tasks_fn,
    "firebase_admin": mock_firebase_admin,
    "firebase_admin.firestore": mock_firebase_admin.firestore,
    "firebase_admin.auth": mock_firebase_admin.auth,
    "firebase_admin.credentials": mock_firebase_admin.credentials,
    "stripe": mock_stripe,
    "google.cloud.firestore": mock_google_cloud_firestore,
    "google.cloud.firestore_v1.base_client": MagicMock(),
    "google.auth": mock_google_auth,
    "google.auth.transport.requests": MagicMock(),
    "google.cloud.secretmanager": mock_secret_manager,
    "google.cloud.secretmanager.SecretManagerServiceClient": MagicMock(),
    "mailjet_rest": mock_mailjet,
    "boto3": mock_boto3,
}

with patch.dict(sys.modules, module_mocks):
    import main
    from handlers import payment_stripe
    from main import create_checkout_session
    from services.shipping_service import calculate_shipping_cost


class TestPaymentSecurity(unittest.TestCase):
    """Class TestPaymentSecurity."""
    def setUp(self):
        # Configure Firebase Admin mock properly
        """Function setUp."""
        main.firebase_admin = mock_firebase_admin
        mock_firebase_admin.initialize_app = MagicMock()
        mock_firebase_admin._apps = {}
        mock_firebase_admin.get_app = MagicMock()
        mock_firebase_admin.delete_app = MagicMock()

        main.stripe = mock_stripe
        mock_stripe.checkout.Session.create.reset_mock()

        # Create default mock db and rate limiter for all tests
        self.mock_db = MagicMock()

        # Default mock documents for user and seller
        mock_user = MagicMock()
        mock_user.exists = True
        mock_user.to_dict.return_value = {"suspended": False, "roles": ["buyer"]}

        mock_seller = MagicMock()
        mock_seller.exists = True
        mock_seller.to_dict.return_value = {"suspended": False, "roles": ["seller"]}

        mock_seller_profile = MagicMock()
        mock_seller_profile.exists = True
        mock_seller_profile.to_dict.return_value = {
            "onboardingCompleted": True,
            "chargesEnabled": True,
            "payoutsEnabled": True,
        }

        # We need a default product mock too so other tests don't break if they rely on the default
        mock_default_product = MagicMock()
        mock_default_product.exists = True
        mock_default_product.to_dict.return_value = {
            "name": "Test Product",
            "price": 10.0,
            "lifecycleStatus": "active",
            "stockQuantity": 10,
            "sellerId": "seller_1",
        }

        def mock_collection(name):
            """Function mock_collection."""
            mock_coll = MagicMock()
            def mock_document(doc_id=None):
                """Function mock_document."""
                mock_doc_ref = MagicMock()
                mock_doc_ref.id = doc_id or "default_id"
                if name == "users":
                    if doc_id and "seller" in doc_id:
                        mock_doc_ref.get.return_value = mock_seller
                    else:
                        mock_doc_ref.get.return_value = mock_user
                elif name == "seller_profiles":
                    mock_doc_ref.get.return_value = mock_seller_profile
                elif name == "products":
                    mock_doc_ref.get.return_value = mock_default_product
                else:
                    mock_doc_ref.get.return_value = MagicMock(exists=True, to_dict=lambda: {})
                return mock_doc_ref
            mock_coll.document = mock_document
            return mock_coll

        self.mock_db.collection.side_effect = mock_collection

        # Implement get_all() for batch product fetches (used by create_checkout_session)
        def _get_all_impl(refs):
            results = []
            for ref in refs:
                doc = ref.get()
                try:
                    if isinstance(ref.id, str):
                        doc.id = ref.id
                except Exception:
                    pass
                results.append(doc)
            return results

        self.mock_db.get_all = MagicMock(side_effect=_get_all_impl)

        self.mock_rate_limiter = MagicMock()
        self.mock_rate_limiter.check_rate_limit.return_value = (True, "OK")

        # Patch get_db and get_rate_limiter for all tests
        self.patcher_db = patch.object(payment_stripe, "get_db", return_value=self.mock_db)
        self.patcher_rate_limiter = patch.object(
            payment_stripe, "get_rate_limiter", return_value=self.mock_rate_limiter
        )
        self.patcher_db.start()
        self.patcher_rate_limiter.start()

    def tearDown(self):
        """Function tearDown."""
        self.patcher_db.stop()
        self.patcher_rate_limiter.stop()

    def test_price_tampering_protection(self):
        """
        Scenario: Malicious user sends price=1 for a $100 product.
        Expectation: Session rejected due to price mismatch.
        """
        req = MagicMock()
        req.auth.uid = "user_1"
        req.data = {
            "userId": "user_1",
            "customerEmail": "hacker@example.com",
            "amount": 100,
            "subtotalCents": 100,
            "items": [
                {
                    "productId": "prod_1",
                    "quantity": 1,
                    "price": 1.00,  # FAKE PRICE
                    "sellerId": "seller_elon",
                    "name": "Tesla Cybertruck",
                    "description": "Electric pickup truck",
                    "imageUrls": ["http://img.com/truck.jpg"],
                    "sellerAddress": {
                        "street": "1 Tesla St",
                        "city": "Markham",
                        "state": "ON",
                        "postalCode": "L3R 4H5",
                        "country": "Canada",
                    },
                }
            ],
            "shippingAddress": {
                "street": "123 Test St",
                "city": "Toronto",
                "postalCode": "M5V 1A1",
                "state": "ON",
                "country": "Canada",
                "longitude": -79.0,
                "latitude": 43.0,
            },
        }

        # Mock DB Product Return (REAL PRICE)
        mock_product = MagicMock()
        mock_product.exists = True
        mock_product.to_dict.return_value = {
            "name": "Tesla Cybertruck",
            "price": 100000.00,  # REAL PRICE
            "stockQuantity": 5,
            "sellerId": "seller_elon",
            "lifecycleStatus": "active",
            "sellerAddress": {"state": "TX", "longitude": -97.0, "latitude": 30.0},
        }

        # Mock seller
        mock_seller = MagicMock()
        mock_seller.exists = True
        mock_seller.to_dict.return_value = {
            "roles": ["seller"],
            "suspended": False,
            "onboardingCompleted": True,
            "chargesEnabled": True,
            "payoutsEnabled": True,
        }

        # Setup Database mocks
        original_side_effect = self.mock_db.collection.side_effect

        def custom_mock_collection(name):
            """Function custom_mock_collection."""
            if name == "products":
                mock_coll = MagicMock()

                def make_product_ref(doc_id=None):
                    """Function make_product_ref."""
                    mock_doc_ref = MagicMock()
                    mock_doc_ref.id = doc_id or "prod_1"
                    mock_doc_ref.get.return_value = mock_product
                    return mock_doc_ref

                mock_coll.document = make_product_ref
                return mock_coll
            return original_side_effect(name)

        self.mock_db.collection.side_effect = custom_mock_collection

        mock_transaction = MagicMock()
        mock_transaction.get.return_value = mock_seller
        self.mock_db.transaction.return_value = mock_transaction
        self.mock_db.transaction.return_value.__enter__.return_value = mock_transaction
        self.mock_db.transaction.return_value.__exit__.return_value = None

        # Mock Stripe Return
        mock_stripe.checkout.Session.create.return_value = MagicMock(id="sess_1", url="http://pay")

        # Execute - Should REJECT the tampered price
        with self.assertRaises(payment_stripe.https_fn.HttpsError) as context:
            create_checkout_session(req)

        # Verify the error message indicates price mismatch
        msg = str(context.exception.message)
        self.assertTrue("Price changed" in msg or "Price mismatch" in msg)

        # Verify Stripe was NOT called (transaction rejected before payment)
        mock_stripe.checkout.Session.create.assert_not_called()

    def test_server_side_shipping_calculation(self):
        """
        Test that shipping is calculated using helper function, ignoring client request.
        """
        # Scenario: Same province (ON to ON) fallback shipping
        items = [{"sellerId": "s1", "sellerAddress": {"state": "ON"}, "quantity": 1}]
        buyer_addr = {
            "street": "123 Test St",
            "city": "Toronto",
            "postalCode": "M5V 1A1",
            "state": "ON",
            "country": "Canada",
            "latitude": 43.0,
            "longitude": -79.0,
        }

        cost, breakdown = calculate_shipping_cost(items, buyer_addr)

        # Fallback same province = 12.99
        self.assertEqual(cost, 12.99)
        self.assertIsInstance(breakdown, dict)

    def test_free_shipping_items_are_ignored(self):
        """
        Scenario: All items are marked freeShipping.
        Expectation: Shipping cost is zero (no fixed/tiered/fallback applied).
        """
        items = [{"sellerId": "s1", "sellerAddress": {"state": "ON"}, "quantity": 2, "freeShipping": True}]
        buyer_addr = {
            "street": "123 Test St",
            "city": "Toronto",
            "postalCode": "M5V 1A1",
            "state": "ON",
            "country": "Canada",
            "latitude": 43.0,
            "longitude": -79.0,
        }

        cost, breakdown = calculate_shipping_cost(items, buyer_addr)
        self.assertEqual(cost, 0.0)
        self.assertEqual(breakdown, {})

    def test_multi_seller_fixed_price_shipping(self):
        """
        Scenario: Multiple sellers, all items have fixed price for speed.
        Expectation: Fixed price total is used (no tiered/fallback).
        """
        items = [
            {
                "sellerId": "s1",
                "sellerAddress": {"state": "ON"},
                "quantity": 2,
                "deliveryOptions": [{"deliverySpeed": "express", "isEnabled": True, "price": 4.0}],
            },
            {
                "sellerId": "s2",
                "sellerAddress": {"state": "ON"},
                "quantity": 1,
                "deliveryOptions": [{"deliverySpeed": "express", "isEnabled": True, "price": 7.5}],
            },
        ]
        buyer_addr = {
            "street": "123 Test St",
            "city": "Toronto",
            "postalCode": "M5V 1A1",
            "state": "ON",
            "country": "Canada",
            "latitude": 43.0,
            "longitude": -79.0,
        }

        cost, breakdown = calculate_shipping_cost(items, buyer_addr, speed="express")
        # Seller s1: 2 * 4.0 = 8.0, Seller s2: 1 * 7.5 = 7.5
        self.assertEqual(cost, 15.5)
        self.assertIsInstance(breakdown, dict)

    def test_mixed_delivery_options_fallback(self):
        """
        Scenario: Mixed delivery options across sellers.
        Expectation: Fixed price used only for seller with full coverage, fallback for others.
        """
        items = [
            {
                "sellerId": "s1",
                "sellerAddress": {"state": "ON"},
                "quantity": 1,
                "deliveryOptions": [{"deliverySpeed": "standard", "isEnabled": True, "price": 5.0}],
            },
            {"sellerId": "s2", "sellerAddress": {"state": "ON"}, "quantity": 1, "deliveryOptions": []},
        ]
        buyer_addr = {
            "street": "123 Test St",
            "city": "Toronto",
            "postalCode": "M5V 1A1",
            "state": "ON",
            "country": "Canada",
            "latitude": 43.0,
            "longitude": -79.0,
        }

        # For seller s1: fixed price 5.0, seller s2: fallback same province 12.99
        cost, breakdown = calculate_shipping_cost(items, buyer_addr, speed="standard")
        self.assertAlmostEqual(cost, 17.99, places=2)
        self.assertIsInstance(breakdown, dict)

    def test_checkout_rejects_abusive_quantity(self):
        """
        Scenario: Malicious user sends quantity above allowed max (100).
        Expectation: HttpsError thrown.
        """
        req = MagicMock()
        req.auth.uid = "user_1"
        req.data = {
            "userId": "user_1",
            "customerEmail": "abuse@example.com",
            "amount": 100,
            "subtotalCents": 101000,
            "items": [
                {
                    "productId": "prod_1",
                    "quantity": 101,  # ABUSIVE QUANTITY
                    "price": 10.0,
                    "sellerId": "seller_1",
                    "name": "Test Product",
                }
            ],
            "shippingAddress": {
                "street": "123 Test St",
                "city": "Toronto",
                "postalCode": "M5V 1A1",
                "state": "ON",
                "country": "Canada",
            },
        }

        # Mock DB Product with stock check
        mock_product = MagicMock()
        mock_product.exists = True
        mock_product.to_dict.return_value = {
            "name": "Test Product",
            "price": 10.0,
            "stockQuantity": 50,  # Only 50 in stock
            "sellerId": "seller_1",
            "lifecycleStatus": "active",
        }

        original_side_effect = self.mock_db.collection.side_effect
        def custom_mock_collection(name):
            """Function custom_mock_collection."""
            if name == "products":
                mock_coll = MagicMock()
                mock_doc_ref = MagicMock()
                mock_doc_ref.get.return_value = mock_product
                mock_coll.document.return_value = mock_doc_ref
                return mock_coll
            return original_side_effect(name)
        self.mock_db.collection.side_effect = custom_mock_collection

        with self.assertRaises(payment_stripe.https_fn.HttpsError) as context:
            create_checkout_session(req)
        self.assertIn("exceeds limit", str(context.exception.message))

    def test_checkout_rejects_missing_address_fields(self):
        """
        Scenario: Malicious user sends incomplete address.
        Expectation: HttpsError thrown.
        """
        req = MagicMock()
        req.auth.uid = "user_1"
        req.data = {
            "userId": "user_1",
            "customerEmail": "abuse@example.com",
            "amount": 10,
            "subtotalCents": 1000,
            "items": [
                {"productId": "prod_1", "quantity": 1, "price": 10.0, "sellerId": "seller_1", "name": "Test Product"}
            ],
            "shippingAddress": {"state": "ON", "country": "Canada"},
        }

        with self.assertRaises(payment_stripe.https_fn.HttpsError) as context:
            create_checkout_session(req)
        self.assertIn("Shipping address is incomplete", str(context.exception.message))

    def test_checkout_rejects_invalid_postal_code(self):
        """
        Scenario: Malicious user sends invalid postal code.
        Expectation: HttpsError thrown.
        """
        req = MagicMock()
        req.auth.uid = "user_1"
        req.data = {
            "userId": "user_1",
            "customerEmail": "abuse@example.com",
            "amount": 10,
            "subtotalCents": 1000,
            "items": [
                {"productId": "prod_1", "quantity": 1, "price": 10.0, "sellerId": "seller_1", "name": "Test Product"}
            ],
            "shippingAddress": {
                "street": "123 Test St",
                "city": "Toronto",
                "postalCode": "INVALID",
                "state": "ON",
                "country": "Canada",
            },
        }

        with self.assertRaises(payment_stripe.https_fn.HttpsError) as context:
            create_checkout_session(req)
        self.assertIn("Invalid Canadian postal code format", str(context.exception.message))

    def test_checkout_rejects_overlong_address_fields(self):
        """
        Scenario: Malicious user sends overly long address fields.
        Expectation: HttpsError thrown.
        """
        req = MagicMock()
        req.auth.uid = "user_1"
        req.data = {
            "userId": "user_1",
            "customerEmail": "abuse@example.com",
            "amount": 10,
            "subtotalCents": 1000,
            "items": [
                {"productId": "prod_1", "quantity": 1, "price": 10.0, "sellerId": "seller_1", "name": "Test Product"}
            ],
            "shippingAddress": {
                "street": "X" * 201,
                "city": "Toronto",
                "postalCode": "M5V 1A1",
                "state": "ON",
                "country": "Canada",
            },
        }

        with self.assertRaises(payment_stripe.https_fn.HttpsError) as context:
            create_checkout_session(req)
        self.assertIn("Address field", str(context.exception.message))


if __name__ == "__main__":
    unittest.main()
