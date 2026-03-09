"""Module test_checkout_business_rules.py."""
import logging
from datetime import datetime, timezone
from unittest.mock import MagicMock, Mock, patch

# Ensure Firebase functions are mocked before imports
import firebase_functions.https_fn as https_fn
import pytest

from handlers.orders import confirm_item_receipt
from handlers.payment_stripe import create_checkout_session
from schema_constants import BusinessRules, Collections, CouponDiscountTypeValues, DeliveryStatusValues, Fields, OrderStatusValues, PaymentStatusValues

logger = logging.getLogger(__name__)

class TestCheckoutFixesFeb2026:
    """Targeted tests for checkout and orders fixes implemented in Feb 2026"""

    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.calculate_shipping_cost")
    @patch("handlers.payment_stripe._check_premium_from_sub")
    @patch("handlers.payment_stripe.stripe.checkout.Session.create")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    def test_free_shipping_threshold_enforced(self, mock_ensure_key, mock_get_rate_limiter, mock_stripe_create, mock_premium, mock_shipping_calc, mock_get_db):
        """Verify that subtotals >= $75 get free shipping (C12)"""
        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        mock_rl = MagicMock()
        mock_rl.check_rate_limit.return_value = (True, "")
        mock_get_rate_limiter.return_value = mock_rl

        def mock_doc_get(*args, **kwargs):
            # doc_id is usually the first arg if called as ref.get() or implicitly in mocks
            """Function mock_doc_get."""
            doc = MagicMock()
            doc.exists = True

            # Since we can't easily get doc_id from the get() call on a mock ref without more setup,
            # we'll look at the record of which document created this mock.
            # But let's simplify: return a generic doc that has the fields needed
            # based on common keys it looks for.

            doc.to_dict.return_value = {
                Fields.EMAIL: "buyer@example.com",
                Fields.SUSPENDED: False,
                "onboardingCompleted": True, "chargesEnabled": True, "payoutsEnabled": True, "stripeConnectId": "acct_123",
                Fields.NAME: "Test Product",
                Fields.PRICE: 80.00, Fields.SELLER_ID: "seller_123",
                Fields.LIFECYCLE_STATUS: "active", Fields.STOCK_QUANTITY: 10,
                Fields.WAREHOUSE_STOCK: {"wh1": 100}
            }
            return doc

        # Track all .set() calls across all document refs
        set_calls_data = []

        def make_doc_ref(doc_id=None):
            """Function make_doc_ref."""
            mock_ref = MagicMock()
            if doc_id is not None:
                mock_ref.id = doc_id
            mock_ref.get.side_effect = mock_doc_get

            def capture_set(data, **kwargs):
                """Function capture_set."""
                set_calls_data.append(data)

            mock_ref.set.side_effect = capture_set
            return mock_ref

        mock_db.collection.return_value.document.side_effect = make_doc_ref

        mock_transaction = MagicMock()
        def capture_txn_set(ref, data, **kwargs):
            """Function capture_txn_set."""
            set_calls_data.append(data)
        mock_transaction.set.side_effect = capture_txn_set
        mock_db.transaction.return_value = mock_transaction

        def get_all_impl(refs):

            """Function get_all_impl."""
            results = []
            for ref in refs:
                doc = mock_doc_get()
                if hasattr(ref, "id") and isinstance(ref.id, str):
                    doc.id = ref.id
                results.append(doc)
            return results

        mock_db.get_all = MagicMock(side_effect=get_all_impl)

        mock_shipping_calc.return_value = (15.00, {})
        mock_premium.return_value = False
        mock_stripe_create.return_value = Mock(id="sess_123", url="https://stripe.com/pay")

        mock_req = MagicMock()
        mock_req.auth.uid = "user_123"
        mock_req.data = {
            "items": [{"productId": "prod_123", "quantity": 1, "price": 80.00, "sellerId": "seller_123"}],
            "subtotalCents": 8000,
            "shippingAddress": {
                Fields.STREET: "123 Main St",
                Fields.CITY: "Toronto",
                Fields.POSTAL_CODE: "M5V 2N8",
                Fields.STATE: "ON",
                Fields.COUNTRY: "Canada"
            },
            "deliverySpeed": "standard"
        }

        with patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False):
            with patch("handlers.payment_stripe.get_server_timestamp", return_value="mock_ts"):
                create_checkout_session(mock_req)

        order_save = next((d for d in set_calls_data if Fields.SHIPPING_COST_CENTS in d), None)

        assert order_save is not None, f"Order was not saved. Set calls: {set_calls_data}"
        assert order_save[Fields.SHIPPING_COST_CENTS] == 0

    @patch("handlers.orders.get_db")
    @patch("handlers.orders.get_firestore")
    def test_confirm_receipt_uses_product_id(self, mock_get_firestore, mock_get_db):
        """Verify confirm_item_receipt uses productId to identify the item (BUG-O1 fixed)"""
        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        mock_transaction = MagicMock()
        mock_get_firestore.return_value.transactional.side_effect = lambda f: lambda *args, **kwargs: f(mock_transaction)

        order_data = {
            Fields.USER_ID: "buyer_123",
            Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
            Fields.SELLER_IDS: ["seller_123"],
            Fields.ITEMS: [
                {Fields.CART_ITEM_ID: "cart_item_A", Fields.PRODUCT_ID: "p1", Fields.STATUS: DeliveryStatusValues.SHIPPED},
                {Fields.CART_ITEM_ID: "cart_item_B", Fields.PRODUCT_ID: "p2", Fields.STATUS: DeliveryStatusValues.SHIPPED},
            ]
        }

        mock_order_doc = MagicMock()
        mock_order_doc.exists = True
        mock_order_doc.to_dict.return_value = order_data
        mock_db.collection.return_value.document.return_value.get.return_value = mock_order_doc

        mock_req = MagicMock()
        mock_req.auth.uid = "buyer_123"
        mock_req.data = {
            Fields.ORDER_ID: "order_123",
            Fields.PRODUCT_ID: "p2",  # frontend sends productId (not cartItemId)
        }

        with patch("handlers.orders.get_server_timestamp", return_value="mock_ts"):
            confirm_item_receipt(mock_req)

        # Verify item with productId="p2" (index 1) was marked DELIVERED; item 0 unchanged
        mock_transaction.update.assert_called_once()
        args, _ = mock_transaction.update.call_args
        updated_items = args[1][Fields.ITEMS]

        assert updated_items[1][Fields.STATUS] == DeliveryStatusValues.DELIVERED
        assert updated_items[0][Fields.STATUS] == DeliveryStatusValues.SHIPPED


class TestCouponApplicationInCheckout:
    """Tests for coupon discount application inside create_checkout_session (M-01 bug fix)."""

    def _make_checkout_mocks(self, coupon_doc_data=None, coupon_exists=True):
        """Return (mock_db, set_calls_data) with collection-aware mocks."""
        set_calls_data: list = []

        # A generic doc that satisfies product/user/seller profile checks
        _FULL_DOC_FIELDS = {
            Fields.EMAIL: "buyer@example.com",
            Fields.SUSPENDED: False,
            Fields.ONBOARDING_COMPLETED: True,
            "chargesEnabled": True,
            "payoutsEnabled": True,
            "stripeConnectId": "acct_123",
            Fields.NAME: "Test Product",
            Fields.PRICE: 50.00,
            Fields.SELLER_ID: "seller_123",
            Fields.LIFECYCLE_STATUS: "active",
            Fields.STOCK_QUANTITY: 10,
            Fields.WAREHOUSE_STOCK: {"wh1": 100},
            Fields.AVAILABLE_QUANTITY: 100,
        }

        def make_full_doc(doc_id=None):
            """Function make_full_doc."""
            doc = MagicMock()
            doc.exists = True
            doc.id = doc_id or "mock_id"
            doc.to_dict.return_value = dict(_FULL_DOC_FIELDS)
            return doc

        def make_coupon_doc():
            """Function make_coupon_doc."""
            doc = MagicMock()
            doc.exists = coupon_exists
            doc.to_dict.return_value = dict(coupon_doc_data) if coupon_doc_data else {}
            return doc

        def make_collection(collection_name):
            """Function make_collection."""
            coll = MagicMock()

            if collection_name == "coupons":
                def make_coupon_ref(doc_id=None):
                    """Function make_coupon_ref."""
                    ref = MagicMock()
                    ref.id = doc_id
                    ref.get.side_effect = lambda *a, **kw: make_coupon_doc()
                    # coupon_uses subcollection (for _coupon_within_limits)
                    use_ref = MagicMock()
                    use_ref.get.side_effect = lambda *a, **kw: MagicMock(exists=False)
                    coll_use = MagicMock()
                    coll_use.document.return_value = use_ref
                    ref.collection.return_value = coll_use
                    return ref
                coll.document.side_effect = make_coupon_ref
            else:
                def make_generic_ref(doc_id=None):
                    """Function make_generic_ref."""
                    ref = MagicMock()
                    ref.id = doc_id or "mock_id"
                    ref.get.side_effect = lambda *a, **kw: make_full_doc(doc_id)
                    # inventory subcollection
                    inv_ref = MagicMock()
                    inv_ref.get.side_effect = lambda *a, **kw: make_full_doc()
                    inv_coll = MagicMock()
                    inv_coll.document.return_value = inv_ref
                    ref.collection.return_value = inv_coll

                    def capture_set(data, **kwargs):
                        """Function capture_set."""
                        set_calls_data.append(data)
                    ref.set.side_effect = capture_set
                    return ref
                coll.document.side_effect = make_generic_ref

            # Collection-level queries (orders idempotency check)
            query = MagicMock()
            query.where.return_value = query
            query.order_by.return_value = query
            query.limit.return_value = query
            query.stream.return_value = iter([])
            coll.where.return_value = query
            return coll

        mock_db = MagicMock()
        mock_db.collection.side_effect = make_collection

        def get_all_impl(refs):
            """Function get_all_impl."""
            return [make_full_doc(getattr(r, "id", None)) for r in refs]

        mock_db.get_all.side_effect = get_all_impl

        mock_transaction = MagicMock()

        def capture_txn_set(ref, data, **kwargs):
            """Function capture_txn_set."""
            set_calls_data.append(data)

        mock_transaction.set.side_effect = capture_txn_set
        mock_db.transaction.return_value = mock_transaction

        return mock_db, set_calls_data

    def _base_request(self, extra_data=None):
        mock_req = MagicMock()
        mock_req.auth.uid = "user_123"
        mock_req.data = {
            "items": [{"productId": "prod_123", "quantity": 1, "price": 50.00, "sellerId": "seller_123"}],
            "subtotalCents": 5000,
            "shippingAddress": {
                Fields.STREET: "123 Main St",
                Fields.CITY: "Toronto",
                Fields.POSTAL_CODE: "M5V 2N8",
                Fields.STATE: "ON",
                Fields.COUNTRY: "Canada",
            },
            "deliverySpeed": "standard",
        }
        if extra_data:
            mock_req.data.update(extra_data)
        return mock_req

    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.calculate_shipping_cost")
    @patch("handlers.payment_stripe._check_premium_from_sub")
    @patch("handlers.payment_stripe.stripe.checkout.Session.create")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    def test_percent_coupon_applied_to_checkout_total(
        self, mock_ensure_key, mock_get_rate_limiter, mock_stripe_create, mock_premium, mock_shipping_calc, mock_get_db
    ):
        """Coupon with 10% discount should reduce discounted_subtotal from 5000 → 4500 cents."""
        coupon_data = {
            Fields.COUPON_CODE: "SAVE10",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT,
            Fields.DISCOUNT_VALUE: 10,
            Fields.MAX_USES_TOTAL: 100,
            Fields.USED_COUNT: 0,
            Fields.MAX_USES_PER_USER: 5,
        }
        mock_db, set_calls_data = self._make_checkout_mocks(coupon_doc_data=coupon_data)
        mock_get_db.return_value = mock_db

        mock_rl = MagicMock()
        mock_rl.check_rate_limit.return_value = (True, "")
        mock_get_rate_limiter.return_value = mock_rl
        mock_shipping_calc.return_value = (10.00, {})
        mock_premium.return_value = False
        mock_stripe_create.return_value = Mock(id="sess_123", url="https://stripe.com/pay")

        mock_req = self._base_request(extra_data={Fields.COUPON_CODE: "SAVE10"})

        with patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False):
            with patch("handlers.payment_stripe.get_server_timestamp", return_value="mock_ts"):
                create_checkout_session(mock_req)

        order_save = next((d for d in set_calls_data if Fields.DISCOUNT_AMOUNT_CENTS in d), None)
        assert order_save is not None, "Order was not saved with discount info"
        assert order_save[Fields.DISCOUNT_AMOUNT_CENTS] == 500  # 10% of 5000
        assert order_save[Fields.COUPON_CODE] == "SAVE10"

    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.calculate_shipping_cost")
    @patch("handlers.payment_stripe._check_premium_from_sub")
    @patch("handlers.payment_stripe.stripe.checkout.Session.create")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    def test_fixed_cents_coupon_applied(
        self, mock_ensure_key, mock_get_rate_limiter, mock_stripe_create, mock_premium, mock_shipping_calc, mock_get_db
    ):
        """Coupon with fixed $5 (500 cents) discount reduces subtotal from 5000 → 4500."""
        coupon_data = {
            Fields.COUPON_CODE: "FLAT5",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.FIXED_CENTS,
            Fields.DISCOUNT_VALUE: 500,
            Fields.MAX_USES_TOTAL: 100,
            Fields.USED_COUNT: 0,
            Fields.MAX_USES_PER_USER: 5,
        }
        mock_db, set_calls_data = self._make_checkout_mocks(coupon_doc_data=coupon_data)
        mock_get_db.return_value = mock_db

        mock_rl = MagicMock()
        mock_rl.check_rate_limit.return_value = (True, "")
        mock_get_rate_limiter.return_value = mock_rl
        mock_shipping_calc.return_value = (10.00, {})
        mock_premium.return_value = False
        mock_stripe_create.return_value = Mock(id="sess_123", url="https://stripe.com/pay")

        mock_req = self._base_request(extra_data={Fields.COUPON_CODE: "FLAT5"})

        with patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False):
            with patch("handlers.payment_stripe.get_server_timestamp", return_value="mock_ts"):
                create_checkout_session(mock_req)

        order_save = next((d for d in set_calls_data if Fields.DISCOUNT_AMOUNT_CENTS in d), None)
        assert order_save is not None
        assert order_save[Fields.DISCOUNT_AMOUNT_CENTS] == 500
        assert order_save[Fields.COUPON_CODE] == "FLAT5"

    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    def test_expired_coupon_raises_error(self, mock_ensure_key, mock_get_rate_limiter, mock_get_db):
        """Expired coupon must raise failed-precondition, not silently charge full price."""
        past_ts = MagicMock()
        past_ts.ToDatetime.return_value = datetime(2020, 1, 1, tzinfo=timezone.utc)

        coupon_data = {
            Fields.COUPON_CODE: "EXPIRED",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT,
            Fields.DISCOUNT_VALUE: 10,
            Fields.EXPIRES_AT: past_ts,
            Fields.USED_COUNT: 0,
        }
        mock_db, _ = self._make_checkout_mocks(coupon_doc_data=coupon_data)
        mock_get_db.return_value = mock_db

        mock_rl = MagicMock()
        mock_rl.check_rate_limit.return_value = (True, "")
        mock_get_rate_limiter.return_value = mock_rl

        mock_req = self._base_request(extra_data={Fields.COUPON_CODE: "EXPIRED"})

        with pytest.raises(https_fn.HttpsError) as exc_info:
            with patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False):
                create_checkout_session(mock_req)

        assert exc_info.value.code == "failed-precondition"

    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    def test_missing_coupon_doc_raises_not_found(self, mock_ensure_key, mock_get_rate_limiter, mock_get_db):
        """Non-existent coupon code must raise not-found, not silently skip discount."""
        mock_db, _ = self._make_checkout_mocks(coupon_doc_data={}, coupon_exists=False)
        mock_get_db.return_value = mock_db

        mock_rl = MagicMock()
        mock_rl.check_rate_limit.return_value = (True, "")
        mock_get_rate_limiter.return_value = mock_rl

        mock_req = self._base_request(extra_data={Fields.COUPON_CODE: "GHOST"})

        with pytest.raises(https_fn.HttpsError) as exc_info:
            create_checkout_session(mock_req)

        assert exc_info.value.code == "not-found"
