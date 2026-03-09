from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from config import CATEGORY_TAX_CODE_MAP
from schema_constants import (
    ApiKeys,
    BusinessRules,
    CartVerificationReasonValues,
    Collections,
    Fields,
    ProductLifecycleStatusValues,
    StripeConstants,
)


class _FakeProtoTimestamp:
    """Mimic protobuf timestamp objects that expose ToDatetime()."""

    def __init__(self, dt: datetime):
        self._dt = dt

    def ToDatetime(self) -> datetime:  # noqa: N802 (matches protobuf API)
        return self._dt


def _build_seller_db(seller_data: dict | None, profile_data: dict | None, seller_exists: bool = True, profile_exists: bool = True):
    db = Mock()

    seller_doc = Mock()
    seller_doc.exists = seller_exists
    seller_doc.to_dict.return_value = seller_data or {}

    profile_doc = Mock()
    profile_doc.exists = profile_exists
    profile_doc.to_dict.return_value = profile_data or {}

    def _collection_side_effect(name):
        coll = Mock()
        if name == Collections.USERS:
            coll.document.return_value.get.return_value = seller_doc
        elif name == Collections.SELLER_PROFILES:
            coll.document.return_value.get.return_value = profile_doc
        return coll

    db.collection.side_effect = _collection_side_effect
    return db


def _doc(doc_id: str, data: dict | None = None, *, exists: bool = True):
    snap = Mock()
    snap.id = doc_id
    snap.exists = exists
    snap.to_dict.return_value = {} if data is None else data
    return snap


class TestPaymentStripeHelpers:
    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.payment_stripe.get_db")
    def test_check_premium_from_sub_uses_authoritative_service(self, mock_get_db, mock_is_premium):
        from handlers.payment_stripe import _check_premium_from_sub

        db = Mock()
        mock_get_db.return_value = db
        assert _check_premium_from_sub("buyer_1") is True
        mock_is_premium.assert_called_once_with("buyer_1", db=db)

    def test_get_tax_code_for_category_returns_mapping(self):
        from handlers.payment_stripe import get_tax_code_for_category

        key, val = next(iter(CATEGORY_TAX_CODE_MAP.items()))
        assert get_tax_code_for_category(key) == val
        assert get_tax_code_for_category("unknown-category") is None

    @patch("handlers.payment_stripe.RateLimiter")
    @patch("handlers.payment_stripe.get_db")
    def test_get_rate_limiter_lazy_singleton(self, mock_get_db, mock_rate_limiter):
        from handlers import payment_stripe

        payment_stripe._rate_limiter = None
        mock_get_db.return_value = Mock()
        rl_instance = Mock()
        mock_rate_limiter.return_value = rl_instance

        first = payment_stripe.get_rate_limiter()
        second = payment_stripe.get_rate_limiter()

        assert first is rl_instance
        assert second is rl_instance
        mock_rate_limiter.assert_called_once()
        payment_stripe._rate_limiter = None

    def test_ensure_stripe_key_sets_key_when_missing(self):
        from handlers import payment_stripe

        original_key = payment_stripe.stripe.api_key
        payment_stripe.stripe.api_key = ""
        try:
            with patch("handlers.payment_stripe.get_stripe_secret_key", return_value="sk_test_helper"):
                payment_stripe.ensure_stripe_key()
            assert payment_stripe.stripe.api_key == "sk_test_helper"
        finally:
            payment_stripe.stripe.api_key = original_key

    def test_coupon_not_expired_handles_none_and_protobuf_timestamps(self):
        from handlers.payment_stripe import _coupon_not_expired

        assert _coupon_not_expired({Fields.EXPIRES_AT: None}) is True

        future = datetime.now(UTC) + timedelta(days=1)
        past = datetime.now(UTC) - timedelta(days=1)
        assert _coupon_not_expired({Fields.EXPIRES_AT: _FakeProtoTimestamp(future)}) is True
        assert _coupon_not_expired({Fields.EXPIRES_AT: _FakeProtoTimestamp(past)}) is False

    @patch("handlers.payment_stripe.get_db")
    def test_coupon_within_limits_blocks_total_and_per_user_caps(self, mock_get_db):
        from handlers.payment_stripe import _coupon_within_limits

        # Global cap reached -> no Firestore read needed.
        assert (
            _coupon_within_limits(
                {
                    Fields.MAX_USES_TOTAL: 10,
                    Fields.USED_COUNT: 10,
                },
                "buyer_1",
            )
            is False
        )

        db = Mock()
        mock_get_db.return_value = db
        use_doc = Mock()
        use_doc.exists = True
        use_doc.to_dict.return_value = {"useCount": 2}
        db.collection.return_value.document.return_value.collection.return_value.document.return_value.get.return_value = use_doc

        assert (
            _coupon_within_limits(
                {
                    Fields.COUPON_CODE: "SAVE10",
                    Fields.MAX_USES_TOTAL: 100,
                    Fields.USED_COUNT: 1,
                    Fields.MAX_USES_PER_USER: 2,
                },
                "buyer_1",
            )
            is False
        )

    @patch("handlers.payment_stripe.get_db")
    def test_coupon_within_limits_allows_when_user_under_cap(self, mock_get_db):
        from handlers.payment_stripe import _coupon_within_limits

        db = Mock()
        mock_get_db.return_value = db
        use_doc = Mock()
        use_doc.exists = True
        use_doc.to_dict.return_value = {"useCount": 1}
        db.collection.return_value.document.return_value.collection.return_value.document.return_value.get.return_value = use_doc

        assert (
            _coupon_within_limits(
                {
                    Fields.COUPON_CODE: "SAVE10",
                    Fields.MAX_USES_TOTAL: 100,
                    Fields.USED_COUNT: 1,
                    Fields.MAX_USES_PER_USER: 2,
                },
                "buyer_1",
            )
            is True
        )

    def test_coupon_seller_allowed_and_min_order_checks(self):
        from handlers.payment_stripe import _coupon_min_order_met, _coupon_seller_allowed

        assert _coupon_seller_allowed({Fields.SELLER_ID: None}, {"seller_a"}) is True
        assert _coupon_seller_allowed({Fields.SELLER_ID: "seller_a"}, {"seller_a"}) is True
        assert _coupon_seller_allowed({Fields.SELLER_ID: "seller_b"}, {"seller_a"}) is False

        assert _coupon_min_order_met({Fields.MIN_ORDER_CENTS: None}, 1000) is True
        assert _coupon_min_order_met({Fields.MIN_ORDER_CENTS: 1000}, 1000) is True
        assert _coupon_min_order_met({Fields.MIN_ORDER_CENTS: 1500}, 1000) is False

    @patch("handlers.payment_stripe.get_db")
    def test_get_seller_stripe_snapshot_reads_private_subcollection(self, mock_get_db):
        from handlers.payment_stripe import _get_seller_stripe_snapshot

        db = Mock()
        mock_get_db.return_value = db
        snap = Mock()
        snap.exists = True
        snap.to_dict.return_value = {
            Fields.SELLER_STRIPE_ACCOUNTS: {"seller_1": "acct_1"},
        }
        db.collection.return_value.document.return_value.collection.return_value.document.return_value.get.return_value = snap

        out = _get_seller_stripe_snapshot("order_1", {})
        assert out == {"seller_1": "acct_1"}

    @patch("handlers.payment_stripe.get_db")
    def test_get_seller_stripe_snapshot_returns_empty_on_exception(self, mock_get_db):
        from handlers.payment_stripe import _get_seller_stripe_snapshot

        mock_get_db.side_effect = RuntimeError("db down")
        assert _get_seller_stripe_snapshot("order_1", {}) == {}

    @patch("handlers.payment_stripe.get_db")
    def test_assert_seller_active_rejects_not_found_and_suspended(self, mock_get_db):
        from handlers.payment_stripe import _assert_seller_active

        mock_get_db.return_value = _build_seller_db(None, None, seller_exists=False)
        with pytest.raises(https_fn.HttpsError) as not_found:
            _assert_seller_active("seller_missing")
        assert not_found.value.code == "not-found"

        mock_get_db.return_value = _build_seller_db({Fields.SUSPENDED: True}, {})
        with pytest.raises(https_fn.HttpsError) as suspended:
            _assert_seller_active("seller_suspended")
        assert suspended.value.code == "permission-denied"

    @patch("handlers.payment_stripe.get_db")
    def test_assert_seller_active_requires_onboarding_flags_when_enabled(self, mock_get_db):
        from handlers.payment_stripe import _assert_seller_active

        base_seller = {Fields.SUSPENDED: False}

        mock_get_db.return_value = _build_seller_db(base_seller, {Fields.ONBOARDING_COMPLETED: False})
        with pytest.raises(https_fn.HttpsError) as missing_onboarding:
            _assert_seller_active("seller_1", require_approval=True)
        assert missing_onboarding.value.code == "failed-precondition"

        mock_get_db.return_value = _build_seller_db(
            base_seller,
            {Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: False, Fields.PAYOUTS_ENABLED: True},
        )
        with pytest.raises(https_fn.HttpsError) as missing_charges:
            _assert_seller_active("seller_1", require_approval=True)
        assert missing_charges.value.code == "failed-precondition"

        mock_get_db.return_value = _build_seller_db(
            base_seller,
            {Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True, Fields.PAYOUTS_ENABLED: False},
        )
        with pytest.raises(https_fn.HttpsError) as missing_payouts:
            _assert_seller_active("seller_1", require_approval=True)
        assert missing_payouts.value.code == "failed-precondition"

    @patch("handlers.payment_stripe.get_db")
    def test_assert_seller_active_returns_data_when_approval_not_required(self, mock_get_db):
        from handlers.payment_stripe import _assert_seller_active

        seller_data = {Fields.SUSPENDED: False, "displayName": "Seller"}
        mock_get_db.return_value = _build_seller_db(seller_data, None)
        assert _assert_seller_active("seller_1", require_approval=False) == seller_data

    def test_sanitize_metadata_keeps_primitives_and_stringifies_complex_types(self):
        from handlers.payment_stripe import sanitize_metadata

        out = sanitize_metadata(
            {
                "s": "text",
                "i": 1,
                "f": 1.5,
                "b": True,
                "n": None,
                "obj": {"k": "v"},
                "list": [1, 2, 3],
            }
        )

        assert out["s"] == "text"
        assert out["i"] == 1
        assert out["f"] == 1.5
        assert out["b"] is True
        assert out["n"] is None
        assert isinstance(out["obj"], str)
        assert isinstance(out["list"], str)
        assert sanitize_metadata("not-a-dict") == {}

    def test_verify_cart_prices_rejects_unauthenticated(self):
        from handlers.payment_stripe import verify_cart_prices

        req = Mock()
        req.auth = None
        req.data = {}

        with pytest.raises(https_fn.HttpsError) as exc:
            verify_cart_prices(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.payment_stripe.get_rate_limiter")
    def test_verify_cart_prices_rate_limited(self, mock_get_rate_limiter):
        from handlers.payment_stripe import verify_cart_prices

        limiter = Mock()
        limiter.check_rate_limit.return_value = (False, "too many")
        mock_get_rate_limiter.return_value = limiter

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.ITEMS: [{Fields.PRODUCT_ID: "p_1"}]}

        with pytest.raises(https_fn.HttpsError) as exc:
            verify_cart_prices(req)
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.payment_stripe.get_rate_limiter")
    def test_verify_cart_prices_requires_items(self, mock_get_rate_limiter):
        from handlers.payment_stripe import verify_cart_prices

        limiter = Mock()
        limiter.check_rate_limit.return_value = (True, "ok")
        mock_get_rate_limiter.return_value = limiter

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.ITEMS: []}

        with pytest.raises(https_fn.HttpsError) as exc:
            verify_cart_prices(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    def test_verify_cart_prices_detects_removed_price_and_stock_changes(self, mock_get_db, mock_get_rate_limiter):
        from handlers.payment_stripe import verify_cart_prices

        limiter = Mock()
        limiter.check_rate_limit.return_value = (True, "ok")
        mock_get_rate_limiter.return_value = limiter

        products_col = Mock()
        products_col.document.side_effect = lambda doc_id: SimpleNamespace(id=doc_id)

        db = Mock()
        db.collection.return_value = products_col
        db.get_all.return_value = [
            _doc("p_missing", exists=False),
            _doc(
                "p_inactive",
                {
                    Fields.NAME: "Inactive Listing",
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                },
            ),
            _doc(
                "p_changed",
                {
                    Fields.NAME: "Changed Listing",
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                    Fields.PRICE: 14.99,
                    Fields.STOCK_QUANTITY: 1,
                },
            ),
        ]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {
            Fields.ITEMS: [
                {Fields.PRODUCT_ID: "", Fields.PRICE: 1.0, Fields.QUANTITY: 1},  # skipped: missing id
                {Fields.PRODUCT_ID: "p_missing", Fields.PRICE: 1.0, Fields.QUANTITY: 1},
                {Fields.PRODUCT_ID: "p_inactive", Fields.PRICE: 9.0, Fields.QUANTITY: 1},
                {Fields.PRODUCT_ID: "p_changed", Fields.PRICE: 10.0, Fields.QUANTITY: 3},
            ]
        }

        out = verify_cart_prices(req)
        assert out[ApiKeys.SUCCESS] is True
        assert out[ApiKeys.HAS_CHANGES] is True
        assert any(x[Fields.PRODUCT_ID] == "p_missing" for x in out[ApiKeys.REMOVED_PRODUCTS])
        assert any(
            x[Fields.PRODUCT_ID] == "p_inactive" and x[Fields.REASON] == CartVerificationReasonValues.DEACTIVATED
            for x in out[ApiKeys.REMOVED_PRODUCTS]
        )
        assert any(
            x[Fields.PRODUCT_ID] == "p_changed" and x[ApiKeys.OLD_PRICE] == 10.0 and x[ApiKeys.NEW_PRICE] == 14.99
            for x in out[ApiKeys.PRICE_CHANGES]
        )
        assert any(
            x[Fields.PRODUCT_ID] == "p_changed" and x[ApiKeys.REQUESTED] == 3 and x[ApiKeys.AVAILABLE] == 1
            for x in out[ApiKeys.STOCK_CHANGES]
        )

    @patch("handlers.payment_stripe.get_tax_rate", return_value=0.13)
    def test_get_item_tax_rate_honors_exempt_codes(self, mock_get_tax_rate):
        from handlers.payment_stripe import (
            STRIPE_TAX_CODE_BASIC_GROCERIES,
            STRIPE_TAX_CODE_CHILDRENS_CLOTHING,
            get_item_tax_rate,
        )

        exempt_province = next(iter(BusinessRules.CHILDRENS_CLOTHING_EXEMPT_PROVINCES))
        assert get_item_tax_rate({Fields.TAX_CODE: STRIPE_TAX_CODE_CHILDRENS_CLOTHING}, exempt_province) == 0.0
        assert get_item_tax_rate({Fields.TAX_CODE: STRIPE_TAX_CODE_BASIC_GROCERIES}, "ON") == 0.0
        assert get_item_tax_rate({Fields.TAX_CODE: "txcd_general"}, "ON") == 0.13
        mock_get_tax_rate.assert_called_once_with("ON")

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe.stripe.tax.Calculation.create")
    def test_calculate_tax_with_stripe_success_maps_breakdown_and_reverse_charge(self, mock_calc_create, _mock_ensure):
        from handlers.payment_stripe import calculate_tax_with_stripe

        mock_calc_create.return_value = SimpleNamespace(
            tax_breakdown=[
                SimpleNamespace(tax_type="gst", amount=130),
                SimpleNamespace(tax_type="pst", amount=40),
            ],
            tax_amount_exclusive=170,
            line_items=SimpleNamespace(
                data=[
                    SimpleNamespace(reference="prod_1", amount_tax=130, amount=1000),
                    SimpleNamespace(reference=StripeConstants.SHIPPING_REFERENCE, amount_tax=40, amount=400),
                    SimpleNamespace(reference="prod_zero", amount_tax=0, amount=0),
                ]
            ),
            customer_details=SimpleNamespace(tax_exempt=StripeConstants.REVERSE_CHARGE),
        )

        tax_cents, breakdown, item_taxes, reverse_charge = calculate_tax_with_stripe(
            validated_items=[
                {
                    Fields.PRODUCT_ID: "prod_small",
                    Fields.CATEGORY_ID: 1,
                    Fields.PRICE: 5.0,
                    Fields.QUANTITY: 1,
                    Fields.IS_SMALL_SUPPLIER: True,
                },
                {
                    Fields.PRODUCT_ID: "prod_1",
                    Fields.CATEGORY_ID: "unknown",
                    Fields.PRICE: 10.0,
                    Fields.QUANTITY: 1,
                },
            ],
            shipping_address={
                Fields.STREET: "123 Main",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V3A8",
            },
            shipping_cost_cents=400,
            gst_number="123456789RT0001",
        )

        assert tax_cents == 170
        assert isinstance(breakdown, dict) and breakdown
        assert reverse_charge is True
        assert len(item_taxes) == 2
        assert any(t[Fields.PRODUCT_ID] == "prod_1" and t[Fields.TAX_RATE] > 0 for t in item_taxes)
        assert any(t[Fields.PRODUCT_ID] == "prod_zero" and t[Fields.TAX_RATE] == 0 for t in item_taxes)

        kwargs = mock_calc_create.call_args.kwargs
        assert kwargs["currency"] == BusinessRules.DEFAULT_CURRENCY
        assert len(kwargs["line_items"]) == 2  # small supplier skipped, shipping appended
        assert kwargs["customer_details"][StripeConstants.CUSTOMER_TAX_ID][StripeConstants.VALUE] == "123456789RT0001"

    @patch("handlers.payment_stripe.stripe.tax.Calculation.create", side_effect=RuntimeError("stripe down"))
    def test_calculate_tax_with_stripe_fallback_on_exception(self, _mock_calc_create):
        from handlers.payment_stripe import calculate_tax_with_stripe

        out = calculate_tax_with_stripe(
            validated_items=[{Fields.PRODUCT_ID: "prod_1", Fields.CATEGORY_ID: 1, Fields.PRICE: 10.0, Fields.QUANTITY: 1}],
            shipping_address={},
            shipping_cost_cents=0,
        )
        assert out == (None, None, None, False)

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.get_db")
    def test_rollback_checkout_restores_warehouse_and_coupon_use_count(
        self,
        mock_get_db,
        mock_get_firestore,
        _mock_ts,
        _mock_get_transactional,
    ):
        from handlers.payment_stripe import _rollback_checkout

        fs = Mock()
        fs.transactional = lambda fn: fn
        fs.Increment.side_effect = lambda n: ("inc", n)
        mock_get_firestore.return_value = fs

        stock_txn = Mock()
        coupon_txn = Mock()
        db = Mock()
        db.transaction.side_effect = [stock_txn, coupon_txn]
        mock_get_db.return_value = db

        product_ref = Mock()
        product_ref.get.return_value = _doc("p_1", exists=True)
        inv_ref = Mock()
        product_ref.collection.return_value.document.return_value = inv_ref
        products_col = Mock()
        products_col.document.return_value = product_ref

        coupon_ref = Mock()
        coupon_ref.get.return_value = _doc("SAVE10", {Fields.USED_COUNT: 2})
        user_use_ref = Mock()
        user_use_ref.get.return_value = _doc("buyer_1", {"useCount": 3})
        coupon_ref.collection.return_value.document.return_value = user_use_ref
        coupons_col = Mock()
        coupons_col.document.return_value = coupon_ref

        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.COUPONS: coupons_col,
        }[name]

        order_ref = Mock()
        _rollback_checkout(
            validated_items=[
                {
                    Fields.PRODUCT_ID: "p_1",
                    Fields.QUANTITY: 2,
                    Fields.FULFILLMENT_WAREHOUSE_ID: "wh_1",
                }
            ],
            order_ref=order_ref,
            coupon_code="SAVE10",
            user_id="buyer_1",
        )

        stock_txn.update.assert_called_once()
        stock_patch = stock_txn.update.call_args.args[1]
        assert stock_patch[Fields.STOCK_QUANTITY] == ("inc", 2)
        assert stock_patch[f"{Fields.WAREHOUSE_STOCK}.wh_1"] == ("inc", 2)

        stock_txn.set.assert_called_once_with(
            inv_ref,
            {
                Fields.AVAILABLE_QUANTITY: ("inc", 2),
                Fields.LAST_SYNCED_AT: "ts",
            },
            merge=True,
        )
        coupon_txn.update.assert_any_call(coupon_ref, {Fields.USED_COUNT: 1})
        coupon_txn.update.assert_any_call(user_use_ref, {"useCount": 2})
        order_ref.update.assert_called_once()

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.get_db")
    def test_rollback_checkout_deletes_coupon_use_doc_when_single_use(
        self,
        mock_get_db,
        mock_get_firestore,
        _mock_ts,
        _mock_get_transactional,
    ):
        from handlers.payment_stripe import _rollback_checkout

        fs = Mock()
        fs.transactional = lambda fn: fn
        mock_get_firestore.return_value = fs

        stock_txn = Mock()
        coupon_txn = Mock()
        db = Mock()
        db.transaction.side_effect = [stock_txn, coupon_txn]
        mock_get_db.return_value = db

        products_col = Mock()
        coupons_col = Mock()

        coupon_ref = Mock()
        coupon_ref.get.return_value = _doc("SAVE10", {Fields.USED_COUNT: 1})
        user_use_ref = Mock()
        user_use_ref.get.return_value = _doc("buyer_1", {"useCount": 1})
        coupon_ref.collection.return_value.document.return_value = user_use_ref
        coupons_col.document.return_value = coupon_ref

        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.COUPONS: coupons_col,
        }[name]

        order_ref = Mock()
        _rollback_checkout(validated_items=[], order_ref=order_ref, coupon_code="SAVE10", user_id="buyer_1")

        coupon_txn.update.assert_called_once_with(coupon_ref, {Fields.USED_COUNT: 0})
        coupon_txn.delete.assert_called_once_with(user_use_ref)
        order_ref.update.assert_called_once()

    @patch("handlers.payment_stripe.logger")
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.get_db")
    def test_rollback_checkout_handles_stock_and_order_update_failures(
        self,
        mock_get_db,
        _mock_get_transactional,
        mock_logger,
    ):
        from handlers.payment_stripe import _rollback_checkout

        db = Mock()
        db.collection.side_effect = RuntimeError("firestore down")
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        order_ref = Mock()
        order_ref.update.side_effect = RuntimeError("update failed")

        _rollback_checkout(
            validated_items=[{Fields.PRODUCT_ID: "p_1", Fields.QUANTITY: 1}],
            order_ref=order_ref,
        )

        assert mock_logger.critical.call_count >= 2

    @patch("handlers.payment_stripe.logger")
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.get_db")
    def test_rollback_checkout_logs_coupon_rollback_errors(
        self,
        mock_get_db,
        mock_get_firestore,
        _mock_get_transactional,
        mock_logger,
    ):
        from handlers.payment_stripe import _rollback_checkout

        fs = Mock()
        fs.transactional = lambda fn: fn
        mock_get_firestore.return_value = fs

        db = Mock()
        db.collection.side_effect = lambda name: (_ for _ in ()).throw(RuntimeError("coupon boom")) if name == Collections.COUPONS else Mock()
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        order_ref = Mock()
        _rollback_checkout(validated_items=[], order_ref=order_ref, coupon_code="SAVE10", user_id="buyer_1")

        mock_logger.error.assert_called_once()

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.get_db")
    def test_rollback_checkout_coupon_missing_inside_transaction_returns_early(
        self,
        mock_get_db,
        mock_get_firestore,
        _mock_ts,
        _mock_get_transactional,
    ):
        from handlers.payment_stripe import _rollback_checkout

        fs = Mock()
        fs.transactional = lambda fn: fn
        mock_get_firestore.return_value = fs

        stock_txn = Mock()
        coupon_txn = Mock()
        db = Mock()
        db.transaction.side_effect = [stock_txn, coupon_txn]
        mock_get_db.return_value = db

        coupons_col = Mock()
        coupon_ref = Mock()
        coupon_ref.get.return_value = _doc("SAVE10", exists=False)
        coupon_use_ref = Mock()
        coupon_use_ref.get.return_value = _doc("buyer_1", {"useCount": 1}, exists=True)
        coupon_ref.collection.return_value.document.return_value = coupon_use_ref
        coupons_col.document.return_value = coupon_ref

        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: Mock(),
            Collections.COUPONS: coupons_col,
        }[name]

        order_ref = Mock()
        _rollback_checkout(validated_items=[], order_ref=order_ref, coupon_code="SAVE10", user_id="buyer_1")

        coupon_txn.update.assert_not_called()
        coupon_txn.delete.assert_not_called()
        order_ref.update.assert_called_once()
