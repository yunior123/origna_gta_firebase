from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import ANY, Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import (
    ApiKeys,
    Collections,
    Fields,
    PaymentStatusValues,
    ProductLifecycleStatusValues,
    StripeConstants,
    StripeEventTypes,
)


def _checkout_req(uid: str = "buyer_1", data: dict | None = None, token: dict | None = None):
    req = Mock()
    req.auth = Mock(uid=uid, token=(token or {"email_verified": True}))
    req.data = data or {}
    return req


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _shipping_address(**overrides):
    base = {
        Fields.STREET: "123 Main St",
        Fields.CITY: "Toronto",
        Fields.STATE: "ON",
        Fields.POSTAL_CODE: "M5V 3A8",
        Fields.COUNTRY: "CA",
    }
    base.update(overrides)
    return base


def _webhook_req(headers: dict | None = None):
    req = Mock()
    req.method = "POST"
    req.headers = headers or {}
    req.get_data.return_value = b"{}"
    return req


def _basic_checkout_db():
    db = Mock()
    user_doc = Mock()
    user_doc.exists = True
    user_doc.to_dict.return_value = {Fields.SUSPENDED: False, Fields.EMAIL: "buyer@example.com"}
    db.collection.return_value.document.return_value.get.return_value = user_doc
    return db


def _checkout_db_simple(
    *,
    product_data: dict | None = None,
    seller_data: dict | None = None,
    seller_profile_data: dict | None = None,
    coupon_data: dict | None = None,
    recent_orders: list | None = None,
):
    db = Mock()

    buyer_ref = Mock()
    buyer_ref.get.return_value = _snap({Fields.SUSPENDED: False, Fields.EMAIL: "buyer@example.com"}, exists=True)

    # Inventory pre-query path used before the transaction.
    inv_q = Mock()
    inv_q.order_by.return_value = inv_q
    inv_q.limit.return_value = inv_q
    inv_q.get.return_value = []
    product_ref = Mock(id="p1")
    product_ref.collection.return_value = inv_q
    products_col = Mock()
    products_col.document.return_value = product_ref

    users_col = Mock()
    users_col.document.side_effect = lambda uid: buyer_ref if uid == "buyer_1" else Mock(id=uid)

    subscriptions_col = Mock()
    subscriptions_col.document.return_value.get.return_value = _snap({}, exists=False)

    orders_query = Mock()
    orders_query.where.return_value = orders_query
    orders_query.order_by.return_value = orders_query
    orders_query.limit.return_value = orders_query
    orders_query.get.return_value = recent_orders or []
    order_ref = Mock(id="order_new")
    orders_col = Mock()
    orders_col.where.return_value = orders_query
    orders_col.document.return_value = order_ref

    coupons_col = Mock()
    coupons_col.document.return_value.get.return_value = _snap(coupon_data or {}, exists=bool(coupon_data))

    seller_profiles_col = Mock()
    seller_profiles_col.document.side_effect = lambda sid: Mock(id=sid)

    db.collection.side_effect = lambda name: {
        Collections.USERS: users_col,
        Collections.SUBSCRIPTIONS: subscriptions_col,
        Collections.PRODUCTS: products_col,
        Collections.ORDERS: orders_col,
        Collections.COUPONS: coupons_col,
        Collections.SELLER_PROFILES: seller_profiles_col,
    }[name]
    db.get_all.side_effect = [
        [
            _snap(
                product_data
                or {
                    Fields.SELLER_ID: "seller_1",
                    Fields.PRICE: 10.0,
                    Fields.NAME: "Product 1",
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                    Fields.IS_DIGITAL: True,
                },
                exists=True,
                doc_id="p1",
            )
        ],
        [_snap(seller_data or {Fields.SUSPENDED: False, Fields.IS_SMALL_SUPPLIER: False}, exists=True, doc_id="seller_1")],
        [
            _snap(
                seller_profile_data or {Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True},
                exists=True,
                doc_id="seller_1",
            )
        ],
    ]
    db.transaction.return_value = Mock()
    return db, order_ref


def _checkout_db_for_duplicate_paths(recent_orders: list, *, small_supplier: bool = False):
    db = Mock()

    buyer_ref = Mock()
    buyer_ref.get.return_value = _snap({Fields.SUSPENDED: False, Fields.EMAIL: "buyer@example.com"}, exists=True)

    product_ref_for_lookup = Mock(id="p1")
    inv_q = Mock()
    inv_q.order_by.return_value = inv_q
    inv_q.limit.return_value = inv_q
    inv_q.get.side_effect = RuntimeError("inventory read failed")
    product_ref_for_lookup.collection.return_value = inv_q

    products_col = Mock()
    products_col.document.return_value = product_ref_for_lookup

    users_col = Mock()
    users_col.document.side_effect = lambda uid: buyer_ref if uid == "buyer_1" else Mock(id=uid)

    orders_query = Mock()
    orders_query.where.return_value = orders_query
    orders_query.order_by.return_value = orders_query
    orders_query.limit.return_value = orders_query
    orders_query.get.return_value = recent_orders

    order_ref = Mock(id="order_new")
    orders_col = Mock()
    orders_col.where.return_value = orders_query
    orders_col.document.return_value = order_ref

    seller_profiles_col = Mock()
    seller_profiles_col.document.side_effect = lambda sid: Mock(id=sid)

    db.collection.side_effect = lambda name: {
        Collections.USERS: users_col,
        Collections.PRODUCTS: products_col,
        Collections.ORDERS: orders_col,
        Collections.SELLER_PROFILES: seller_profiles_col,
    }[name]
    db.get_all.side_effect = [
        [
            _snap(
                {
                    Fields.SELLER_ID: "seller_1",
                    Fields.PRICE: 10.0,
                    Fields.NAME: "Product 1",
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                },
                exists=True,
                doc_id="p1",
            )
        ],
        [_snap({Fields.SUSPENDED: False, Fields.IS_SMALL_SUPPLIER: small_supplier}, exists=True, doc_id="seller_1")],
        [_snap({Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True}, exists=True, doc_id="seller_1")],
    ]
    db.transaction.return_value = Mock()
    return db, order_ref


class TestCreateCheckoutSessionGuardBranches:
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_no_valid_product_ids_branch(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
    ):
        from handlers.payment_stripe import create_checkout_session

        class _FlipPidDict(dict):
            def __init__(self):
                super().__init__({Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1})
                self._pid_reads = 0

            def get(self, key, default=None):
                if key == Fields.PRODUCT_ID:
                    self._pid_reads += 1
                    return "p1" if self._pid_reads == 1 else None
                return super().get(key, default)

        mock_get_db.return_value = _basic_checkout_db()
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [_FlipPidDict()],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )

        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "invalid-argument"
        assert "No valid product IDs in cart" in str(exc.value)

    @patch("utils.helpers.compare_addresses", return_value=True)
    @patch("handlers.payment_stripe.stripe.checkout.Session.create", return_value=Mock(id="cs_new", url="https://checkout.stripe.com/new", payment_intent="pi_new"))
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda _fn: (lambda _tx: True))
    @patch("handlers.payment_stripe.stripe.checkout.Session.retrieve")
    @patch("handlers.payment_stripe.calculate_tax_with_stripe", return_value=(None, None, None, None))
    @patch("handlers.payment_stripe.get_item_tax_rate", return_value=0.13)
    @patch("handlers.payment_stripe.get_tax_rate", return_value=0.13)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(12.34, {"p1": 12.34}))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", True)
    @patch("handlers.payment_stripe._check_premium_from_sub", return_value=False)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_shipping_tax_fallback_and_dedup_retrieve_error_path(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_premium,
        mock_calc_shipping,
        _mock_tax_rate,
        _mock_item_tax_rate,
        _mock_tax_with_stripe,
        mock_session_retrieve,
        _mock_get_txn,
        _mock_session_create,
        _mock_compare_addresses,
    ):
        from handlers.payment_stripe import create_checkout_session

        now_naive = datetime.now(UTC).replace(tzinfo=None)
        recent_orders = [
            _snap(
                {
                    ApiKeys.IDEMPOTENCY_KEY: "other",
                    Fields.SUBTOTAL_CENTS: 1000,
                    Fields.SHIPPING_ADDRESS: _shipping_address(),
                    Fields.CREATED_AT: now_naive,
                    Fields.STRIPE_SESSION_ID: "cs_other",
                },
                exists=True,
                doc_id="order_other",
            ),
            _snap(
                {
                    ApiKeys.IDEMPOTENCY_KEY: "dup_key",
                    Fields.SUBTOTAL_CENTS: 1000,
                    Fields.SHIPPING_ADDRESS: _shipping_address(),
                    Fields.CREATED_AT: now_naive,  # tz-naive path
                    Fields.STRIPE_SESSION_ID: "cs_old",
                },
                exists=True,
                doc_id="order_old",
            ),
        ]

        db, _order_ref = _checkout_db_for_duplicate_paths(recent_orders, small_supplier=True)
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")
        mock_session_retrieve.side_effect = RuntimeError("session missing")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                ApiKeys.IDEMPOTENCY_KEY: "dup_key",
                Fields.DELIVERY_SPEED: "hyper-fast",  # invalid -> default branch
                Fields.DELIVERY_INSTRUCTIONS: "x" * 2000,  # trim branch
            }
        )

        out = create_checkout_session(req)
        assert out[ApiKeys.SUCCESS] is True
        assert out[ApiKeys.SESSION_ID] == "cs_new"
        assert mock_session_retrieve.call_count == 1
        assert mock_calc_shipping.call_args.kwargs["speed"] == "standard"

    @patch("handlers.payment_stripe.stripe.checkout.Session.create", return_value=Mock(id="cs_new", url="https://checkout.stripe.com/new", payment_intent="pi_new"))
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda _fn: (lambda _tx: True))
    @patch("handlers.payment_stripe.calculate_tax_with_stripe", return_value=(123, {"GST": 1.23}, [{Fields.PRODUCT_ID: "p1", Fields.TAX_CENTS: 123, Fields.TAX_RATE: 0.13}], False))
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(8.0, {"p1": 8.0}))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", True)
    @patch("handlers.payment_stripe._check_premium_from_sub", return_value=True)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_premium_shipping_zero_and_inventory_prequery_failure_non_fatal(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_premium,
        _mock_calc_shipping,
        _mock_tax_with_stripe,
        _mock_get_txn,
        _mock_session_create,
    ):
        from handlers.payment_stripe import create_checkout_session

        db, order_ref = _checkout_db_for_duplicate_paths([], small_supplier=False)
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                Fields.DELIVERY_SPEED: "sameDay",
                Fields.DELIVERY_INSTRUCTIONS: "Leave at concierge",
            }
        )

        out = create_checkout_session(req)
        assert out[ApiKeys.SUCCESS] is True
        assert out[ApiKeys.SESSION_ID] == "cs_new"
        order_ref.update.assert_called_once()

    @patch("handlers.payment_stripe.calculate_shipping_cost", side_effect=RuntimeError("shipping down"))
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_shipping_generic_error_maps_to_internal(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
    ):
        from handlers.payment_stripe import create_checkout_session

        db, _ = _checkout_db_for_duplicate_paths([])
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                Fields.DELIVERY_SPEED: "standard",
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "internal"

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.IS_EMULATOR", False)
    def test_rejects_unverified_email(self, _mock_provider, _mock_key):
        from handlers.payment_stripe import create_checkout_session

        req = _checkout_req(token={})
        req.data = {}

        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "permission-denied"

    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.IS_EMULATOR", False)
    def test_rejects_digital_cart_without_eula(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
    ):
        from handlers.payment_stripe import create_checkout_session

        mock_get_db.return_value = _basic_checkout_db()
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1, Fields.IS_DIGITAL: True}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                ApiKeys.EULA_ACCEPTED: False,
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "failed-precondition"

    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_rejects_age_restricted_cart_without_age_confirmation(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
    ):
        from handlers.payment_stripe import create_checkout_session

        mock_get_db.return_value = _basic_checkout_db()
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1, Fields.IS_AGE_RESTRICTED: True}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                ApiKeys.AGE_VERIFICATION_ACCEPTED: False,
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "failed-precondition"

    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_rejects_invalid_item_and_missing_product_id(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
    ):
        from handlers.payment_stripe import create_checkout_session

        mock_get_db.return_value = _basic_checkout_db()
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        bad_req = _checkout_req(
            data={
                Fields.ITEMS: ["not-a-dict"],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )
        with pytest.raises(https_fn.HttpsError) as bad_item:
            create_checkout_session(bad_req)
        assert bad_item.value.code == "invalid-argument"

        missing_pid_req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )
        with pytest.raises(https_fn.HttpsError) as missing_pid:
            create_checkout_session(missing_pid_req)
        assert missing_pid.value.code == "invalid-argument"

    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_rejects_non_integer_subtotal_country_and_province(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
    ):
        from handlers.payment_stripe import create_checkout_session

        mock_get_db.return_value = _basic_checkout_db()
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req_subtotal = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: "1000",
            }
        )
        with pytest.raises(https_fn.HttpsError) as subtotal_exc:
            create_checkout_session(req_subtotal)
        assert subtotal_exc.value.code == "invalid-argument"

        req_country = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(country="US"),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )
        with pytest.raises(https_fn.HttpsError) as country_exc:
            create_checkout_session(req_country)
        assert country_exc.value.code == "invalid-argument"

        req_province = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(state="ZZ"),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )
        with pytest.raises(https_fn.HttpsError) as province_exc:
            create_checkout_session(req_province)
        assert province_exc.value.code == "invalid-argument"

    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_rejects_suspended_buyer(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
    ):
        from handlers.payment_stripe import create_checkout_session

        db = _basic_checkout_db()
        db.collection.return_value.document.return_value.get.return_value.to_dict.return_value = {Fields.SUSPENDED: True}
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.payment_stripe.get_db")
    def test_coupon_not_expired_astimezone_and_fallback_paths(self, mock_get_db):
        from handlers.payment_stripe import _coupon_not_expired

        class _HasAstimezone:
            def __init__(self, dt):
                self._dt = dt

            def astimezone(self, _tz):
                return self._dt

        now = datetime.now(UTC)
        assert _coupon_not_expired({Fields.EXPIRES_AT: _HasAstimezone(now + timedelta(minutes=10))}) is True
        assert _coupon_not_expired({Fields.EXPIRES_AT: object()}) is True
        mock_get_db.assert_not_called()

    def test_stock_reservation_plan_guard_branches(self):
        from handlers.payment_stripe import _build_stock_reservation_plan

        with pytest.raises(https_fn.HttpsError) as not_found:
            _build_stock_reservation_plan(
                validated_items=[{Fields.PRODUCT_ID: "missing", Fields.QUANTITY: 1}],
                product_data_by_id={},
                inventory_candidates={},
            )
        assert not_found.value.code == "not-found"

        with pytest.raises(https_fn.HttpsError) as bad_qty:
            _build_stock_reservation_plan(
                validated_items=[{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 0}],
                product_data_by_id={"p1": {Fields.STOCK_QUANTITY: 5}},
                inventory_candidates={},
            )
        assert bad_qty.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as missing_variant:
            _build_stock_reservation_plan(
                validated_items=[{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                product_data_by_id={"p1": {Fields.HAS_VARIANTS: True, Fields.NAME: "Shirt", Fields.STOCK_QUANTITY: 5}},
                inventory_candidates={},
            )
        assert missing_variant.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as low_variant_stock:
            _build_stock_reservation_plan(
                validated_items=[{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 2, Fields.VARIANT_ID: "v1"}],
                product_data_by_id={
                    "p1": {
                        Fields.HAS_VARIANTS: True,
                        Fields.NAME: "Variant Product",
                        Fields.STOCK_QUANTITY: 5,
                        Fields.INVENTORY: {Fields.ALLOW_BACKORDER: False},
                        Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 1}],
                    }
                },
                inventory_candidates={},
            )
        assert low_variant_stock.value.code == "resource-exhausted"

        plan = _build_stock_reservation_plan(
            validated_items=[{Fields.PRODUCT_ID: "p2", Fields.QUANTITY: 1, Fields.IS_DIGITAL: True}],
            product_data_by_id={"p2": {Fields.STOCK_QUANTITY: 5, Fields.VARIANTS: "not-a-list"}},
            inventory_candidates={},
        )
        assert plan["stock_deduct_by_product"] == {}

    @pytest.mark.parametrize(
        ("product_data", "seller_data", "profile_data", "expected_code"),
        [
            (
                {Fields.SELLER_ID: "seller_1", Fields.PRICE: 10.0, Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED},
                {Fields.SUSPENDED: False},
                {Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True},
                "failed-precondition",
            ),
            (
                {Fields.SELLER_ID: "buyer_1", Fields.PRICE: 10.0, Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE},
                {Fields.SUSPENDED: False},
                {Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True},
                "invalid-argument",
            ),
            (
                {Fields.SELLER_ID: "seller_1", Fields.PRICE: 10.0, Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE},
                {Fields.SUSPENDED: True},
                {Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True},
                "failed-precondition",
            ),
            (
                {Fields.SELLER_ID: "seller_1", Fields.PRICE: 10.0, Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE},
                {Fields.SUSPENDED: False},
                {Fields.ONBOARDING_COMPLETED: False, Fields.CHARGES_ENABLED: True},
                "failed-precondition",
            ),
            (
                {Fields.SELLER_ID: "seller_1", Fields.PRICE: 10.0, Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE},
                {Fields.SUSPENDED: False},
                {Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: False},
                "failed-precondition",
            ),
        ],
    )
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_product_seller_profile_guard_branches(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        product_data,
        seller_data,
        profile_data,
        expected_code,
    ):
        from handlers.payment_stripe import create_checkout_session

        db = _basic_checkout_db()
        db.get_all.side_effect = [
            [_snap(product_data, exists=True, doc_id="p1")],  # products
            [_snap(seller_data, exists=True, doc_id=product_data[Fields.SELLER_ID])],  # sellers
            [_snap(profile_data, exists=True, doc_id=product_data[Fields.SELLER_ID])],  # seller profiles
        ]

        # Keep collection(document(id)) refs with ids for get_all.
        def _collection(name):
            coll = Mock()
            if name == Collections.USERS:
                buyer_ref = Mock()
                buyer_ref.get.return_value = _snap({Fields.SUSPENDED: False, Fields.EMAIL: "buyer@example.com"}, exists=True)
                coll.document.side_effect = lambda uid: buyer_ref if uid == "buyer_1" else Mock(id=uid)
            elif name in (Collections.PRODUCTS, Collections.SELLER_PROFILES):
                coll.document.side_effect = lambda doc_id: Mock(id=doc_id)
            else:
                coll.document.side_effect = lambda doc_id: Mock(id=doc_id)
            return coll

        db.collection.side_effect = _collection
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == expected_code

    @pytest.mark.parametrize(
        ("within_limits", "seller_allowed", "min_order_met", "expected_code"),
        [
            (False, True, True, "resource-exhausted"),
            (True, False, True, "failed-precondition"),
            (True, True, False, "failed-precondition"),
        ],
    )
    @patch("handlers.payment_stripe._coupon_compute_discount", return_value=100)
    @patch("handlers.payment_stripe._coupon_min_order_met")
    @patch("handlers.payment_stripe._coupon_seller_allowed")
    @patch("handlers.payment_stripe._coupon_within_limits")
    @patch("handlers.payment_stripe._coupon_not_expired", return_value=True)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_coupon_rejection_branches(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_not_expired,
        mock_within_limits,
        mock_seller_allowed,
        mock_min_order_met,
        _mock_coupon_compute,
        within_limits,
        seller_allowed,
        min_order_met,
        expected_code,
    ):
        from handlers.payment_stripe import create_checkout_session

        mock_within_limits.return_value = within_limits
        mock_seller_allowed.return_value = seller_allowed
        mock_min_order_met.return_value = min_order_met

        db = _basic_checkout_db()
        db.get_all.side_effect = [
            [_snap({Fields.SELLER_ID: "seller_1", Fields.PRICE: 10.0, Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}, exists=True, doc_id="p1")],
            [_snap({Fields.SUSPENDED: False}, exists=True, doc_id="seller_1")],
            [_snap({Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True}, exists=True, doc_id="seller_1")],
        ]

        coupons_col = Mock()
        coupons_col.document.return_value.get.return_value = _snap({Fields.COUPON_CODE: "SAVE10"}, exists=True)

        def _collection(name):
            coll = Mock()
            if name == Collections.USERS:
                buyer_ref = Mock()
                buyer_ref.get.return_value = _snap({Fields.SUSPENDED: False, Fields.EMAIL: "buyer@example.com"}, exists=True)
                coll.document.side_effect = lambda uid: buyer_ref if uid == "buyer_1" else Mock(id=uid)
                return coll
            if name == Collections.COUPONS:
                return coupons_col
            coll.document.side_effect = lambda doc_id: Mock(id=doc_id)
            return coll

        db.collection.side_effect = _collection
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                Fields.COUPON_CODE: "save10",
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == expected_code

    @patch("utils.helpers.compare_addresses", return_value=True)
    @patch("handlers.payment_stripe.stripe.checkout.Session.retrieve")
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_returns_existing_duplicate_session_for_digital_cart(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        mock_session_retrieve,
        _mock_compare_addresses,
    ):
        from handlers.payment_stripe import create_checkout_session

        mock_session_retrieve.return_value = Mock(url="https://checkout.stripe.com/existing")
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        # Recent pending order matching idempotency key and address
        existing_order = _snap(
            {
                ApiKeys.IDEMPOTENCY_KEY: "dup_key",
                Fields.SUBTOTAL_CENTS: 1000,
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                Fields.CREATED_AT: datetime.now(UTC),
                Fields.STRIPE_SESSION_ID: "cs_existing",
            },
            exists=True,
            doc_id="order_existing",
        )
        existing_order.to_dict.return_value = existing_order.to_dict.return_value

        orders_query = Mock()
        orders_query.where.return_value = orders_query
        orders_query.order_by.return_value = orders_query
        orders_query.limit.return_value = orders_query
        orders_query.get.return_value = [existing_order]

        db = _basic_checkout_db()
        db.get_all.side_effect = [
            [
                _snap(
                    {
                        Fields.SELLER_ID: "seller_1",
                        Fields.PRICE: 10.0,
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                        Fields.IS_DIGITAL: True,
                    },
                    exists=True,
                    doc_id="p1",
                )
            ],
            [_snap({Fields.SUSPENDED: False}, exists=True, doc_id="seller_1")],
            [_snap({Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True}, exists=True, doc_id="seller_1")],
        ]

        def _collection(name):
            coll = Mock()
            if name == Collections.USERS:
                buyer_ref = Mock()
                buyer_ref.get.return_value = _snap({Fields.SUSPENDED: False, Fields.EMAIL: "buyer@example.com"}, exists=True)
                coll.document.side_effect = lambda uid: buyer_ref if uid == "buyer_1" else Mock(id=uid)
                return coll
            if name == Collections.ORDERS:
                return orders_query
            coll.document.side_effect = lambda doc_id: Mock(id=doc_id)
            return coll

        db.collection.side_effect = _collection
        mock_get_db.return_value = db

        req = _checkout_req(
            data={
                Fields.ITEMS: [
                    {
                        Fields.PRODUCT_ID: "p1",
                        Fields.QUANTITY: 1,
                        Fields.VARIANT_ID: "v1",
                        Fields.VARIANT_TITLE: "Blue",
                        Fields.VARIANT_OPTIONS: {"color": "blue"},
                        Fields.VARIANT_SKU: "SKU-1",
                    }
                ],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                ApiKeys.IDEMPOTENCY_KEY: "dup_key",
            }
        )
        out = create_checkout_session(req)

        assert out[ApiKeys.SUCCESS] is True
        assert out[ApiKeys.DUPLICATE] is True
        assert out[ApiKeys.SESSION_ID] == "cs_existing"

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.IS_EMULATOR", False)
    def test_checkout_denies_unverified_email_branch(self, _mock_provider, _mock_key):
        from handlers.payment_stripe import create_checkout_session

        req = _checkout_req(token={"email_verified": False})
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.payment_stripe.calculate_shipping_cost", side_effect=ValueError("bad shipping"))
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_shipping_value_error_maps_to_invalid_argument(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
    ):
        from handlers.payment_stripe import create_checkout_session

        db, _ = _checkout_db_simple(
            product_data={
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 10.0,
                Fields.NAME: "Physical Product",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.IS_DIGITAL: False,
            }
        )
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.payment_stripe.stripe.checkout.Session.create", return_value=Mock(id="cs_tax", url="https://checkout.stripe.com/tax", payment_intent="pi_tax"))
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda _fn: (lambda _tx: True))
    @patch("handlers.payment_stripe.get_tax_rate", return_value=0.13)
    @patch("handlers.payment_stripe.get_item_tax_rate", return_value=0.13)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(1.0, {"ci_1": 1.0}))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_manual_tax_small_supplier_zeroes_item_tax(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_item_rate,
        _mock_tax_rate,
        _mock_get_txn,
        _mock_session_create,
    ):
        from handlers.payment_stripe import create_checkout_session

        db, _ = _checkout_db_simple(
            product_data={
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 10.0,
                Fields.NAME: "Physical Product",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.IS_DIGITAL: False,
            },
            seller_data={Fields.SUSPENDED: False, Fields.IS_SMALL_SUPPLIER: True},
        )
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1, Fields.CART_ITEM_ID: "ci_1"}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )
        out = create_checkout_session(req)
        assert out[ApiKeys.SUCCESS] is True
        # Small supplier item tax is zeroed; only shipping tax remains (100c * 13% = 13c)
        assert out[Fields.TAX_AMOUNT_CENTS] == 13

    @patch("handlers.payment_stripe.stripe.checkout.Session.create", return_value=Mock(id="cs_round", url="https://checkout.stripe.com/round", payment_intent="pi_round"))
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda _fn: (lambda _tx: True))
    @patch("handlers.payment_stripe._coupon_compute_discount", return_value=1)
    @patch("handlers.payment_stripe._coupon_min_order_met", return_value=True)
    @patch("handlers.payment_stripe._coupon_seller_allowed", return_value=True)
    @patch("handlers.payment_stripe._coupon_within_limits", return_value=True)
    @patch("handlers.payment_stripe._coupon_not_expired", return_value=True)
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(0.0, {}))
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_rounding_delta_appends_price_adjustment_line(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_not_expired,
        _mock_within_limits,
        _mock_seller_allowed,
        _mock_min_order,
        _mock_compute_discount,
        _mock_get_txn,
        mock_session_create,
    ):
        from handlers.payment_stripe import create_checkout_session

        db, _ = _checkout_db_simple(
            product_data={
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 1.0,
                Fields.NAME: "Rounded Product",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.IS_DIGITAL: True,
            },
            coupon_data={Fields.COUPON_CODE: "SAVE1"},
        )
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 3, Fields.IS_DIGITAL: True}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 300,
                Fields.COUPON_CODE: "SAVE1",
                ApiKeys.EULA_ACCEPTED: True,
            }
        )
        out = create_checkout_session(req)
        assert out[ApiKeys.SUCCESS] is True
        line_items = mock_session_create.call_args.kwargs["line_items"]
        assert any(
            li[StripeConstants.PRICE_DATA][StripeConstants.PRODUCT_DATA].get(StripeConstants.NAME) == "Price adjustment"
            for li in line_items
        )

    @patch("handlers.payment_stripe.stripe.checkout.Session.create", return_value=Mock(id="cs_round2", url="https://checkout.stripe.com/round2", payment_intent="pi_round2"))
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda _fn: (lambda _tx: True))
    @patch("handlers.payment_stripe._coupon_compute_discount", return_value=100)
    @patch("handlers.payment_stripe._coupon_min_order_met", return_value=True)
    @patch("handlers.payment_stripe._coupon_seller_allowed", return_value=True)
    @patch("handlers.payment_stripe._coupon_within_limits", return_value=True)
    @patch("handlers.payment_stripe._coupon_not_expired", return_value=True)
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(0.0, {}))
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_rounding_delta_skip_branch_when_adjusted_under_one(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_not_expired,
        _mock_within_limits,
        _mock_seller_allowed,
        _mock_min_order,
        _mock_compute_discount,
        _mock_get_txn,
        mock_session_create,
    ):
        from handlers.payment_stripe import create_checkout_session

        db, _ = _checkout_db_simple(
            product_data={
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 1.0,
                Fields.NAME: "Zeroed Product",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.IS_DIGITAL: True,
            },
            coupon_data={Fields.COUPON_CODE: "FREE100"},
        )
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1, Fields.IS_DIGITAL: True}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 100,
                Fields.COUPON_CODE: "FREE100",
                ApiKeys.EULA_ACCEPTED: True,
            }
        )
        out = create_checkout_session(req)
        assert out[ApiKeys.SUCCESS] is True
        line_items = mock_session_create.call_args.kwargs["line_items"]
        assert len(line_items) == 1

    @patch("handlers.payment_stripe._rollback_checkout")
    @patch("handlers.payment_stripe.stripe.checkout.Session.create")
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda _fn: (lambda _tx: True))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(0.0, {}))
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_stripe_error_mapping_branches(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_get_txn,
        mock_session_create,
        mock_rollback,
    ):
        from handlers.payment_stripe import create_checkout_session

        def _fresh_db():
            db, _ = _checkout_db_simple(
                product_data={
                    Fields.SELLER_ID: "seller_1",
                    Fields.PRICE: 10.0,
                    Fields.NAME: "Product",
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                    Fields.IS_DIGITAL: True,
                }
            )
            return db

        mock_get_db.return_value = _fresh_db()
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1, Fields.IS_DIGITAL: True}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                ApiKeys.EULA_ACCEPTED: True,
            }
        )

        class _CardErr(Exception):
            def __init__(self, user_message):
                super().__init__("card")
                self.user_message = user_message

        class _RateErr(Exception):
            pass

        class _ConnErr(Exception):
            pass

        class _StripeErr(Exception):
            pass

        with patch("handlers.payment_stripe.stripe.error.CardError", _CardErr):
            mock_session_create.side_effect = _CardErr("declined")
            with pytest.raises(https_fn.HttpsError) as card_exc:
                create_checkout_session(req)
            assert card_exc.value.code == "failed-precondition"

        with patch("handlers.payment_stripe.stripe.error.RateLimitError", _RateErr):
            mock_get_db.return_value = _fresh_db()
            mock_session_create.side_effect = _RateErr("busy")
            with pytest.raises(https_fn.HttpsError) as rate_exc:
                create_checkout_session(req)
            assert rate_exc.value.code == "unavailable"

        with patch("handlers.payment_stripe.stripe.error.APIConnectionError", _ConnErr):
            mock_get_db.return_value = _fresh_db()
            mock_session_create.side_effect = _ConnErr("offline")
            with pytest.raises(https_fn.HttpsError) as conn_exc:
                create_checkout_session(req)
            assert conn_exc.value.code == "unavailable"

        with patch("handlers.payment_stripe.stripe.error.StripeError", _StripeErr):
            mock_get_db.return_value = _fresh_db()
            mock_session_create.side_effect = _StripeErr("stripe-down")
            with pytest.raises(https_fn.HttpsError) as stripe_exc:
                create_checkout_session(req)
            assert stripe_exc.value.code == "internal"

        mock_get_db.return_value = _fresh_db()
        mock_session_create.side_effect = https_fn.HttpsError("invalid-argument", "bad")
        with pytest.raises(https_fn.HttpsError) as passthrough_exc:
            create_checkout_session(req)
        assert passthrough_exc.value.code == "invalid-argument"
        assert mock_rollback.call_count >= 4

    @patch("handlers.payment_stripe._build_stock_reservation_plan")
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.stripe.checkout.Session.create", return_value=Mock(id="cs_txn", url="https://checkout.stripe.com/txn", payment_intent="pi_txn"))
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(0.0, {}))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_transactional_inventory_coupon_and_private_snapshot_error_paths(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_get_txn,
        _mock_session_create,
        mock_get_firestore,
        mock_plan,
    ):
        from handlers.payment_stripe import create_checkout_session

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")
        mock_get_firestore.return_value.Increment.side_effect = lambda n: ("inc", n)

        # Product refs used inside transaction.
        inv_ref = Mock()
        inv_ref.get.return_value = _snap({}, exists=True, doc_id="wh_1")
        inv_levels_p1 = Mock()
        inv_levels_p1.order_by.return_value = inv_levels_p1
        inv_levels_p1.limit.return_value = inv_levels_p1
        inv_levels_p1.get.return_value = [_snap({Fields.AVAILABLE_QUANTITY: 4}, exists=True, doc_id="wh_1")]
        inv_levels_p1.document.return_value = inv_ref

        inv_levels_p2 = Mock()
        inv_levels_p2.order_by.return_value = inv_levels_p2
        inv_levels_p2.limit.return_value = inv_levels_p2
        inv_levels_p2.get.return_value = []
        inv_levels_p2.document.return_value = Mock()

        product_ref_p1 = Mock(id="p1")
        product_ref_p1.collection.return_value = inv_levels_p1
        product_ref_p1.get.return_value = _snap(
            {Fields.HAS_VARIANTS: True, Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 3}]},
            exists=True,
            doc_id="p1",
        )
        product_ref_p2 = Mock(id="p2")
        product_ref_p2.collection.return_value = inv_levels_p2
        product_ref_p2.get.return_value = _snap({Fields.HAS_VARIANTS: False}, exists=True, doc_id="p2")

        products_col = Mock()
        products_col.document.side_effect = lambda pid: {"p1": product_ref_p1, "p2": product_ref_p2}[pid]

        buyer_ref = Mock()
        buyer_ref.get.return_value = _snap({Fields.SUSPENDED: False, Fields.EMAIL: "buyer@example.com"}, exists=True)
        users_col = Mock()
        users_col.document.side_effect = lambda uid: buyer_ref if uid == "buyer_1" else Mock(id=uid)

        sub_col = Mock()
        sub_col.document.return_value.get.return_value = _snap(exists=False)

        # Orders collection used for dedupe query and for order/private writes.
        order_ref = Mock(id="order_txn")
        private_doc = Mock()
        private_doc.set.side_effect = RuntimeError("private write failed")
        order_private_ref = Mock()
        order_private_ref.collection.return_value.document.return_value = private_doc

        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.order_by.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.get.return_value = []
        orders_col = Mock()
        orders_col.where.return_value = orders_q
        orders_col.document.side_effect = lambda doc_id=None: order_ref if doc_id is None else order_private_ref

        # Coupon refs for both pre-validation and transactional updates.
        coupon_ref = Mock()
        coupon_ref.get.return_value = _snap(
            {Fields.USED_COUNT: 0, Fields.MAX_USES_TOTAL: 10, Fields.MAX_USES_PER_USER: 5, Fields.SELLER_ID: "seller_1"},
            exists=True,
        )
        coupon_use_ref = Mock()
        coupon_use_ref.get.return_value = _snap({Fields.USE_COUNT: 1}, exists=True)
        coupon_ref.collection.return_value.document.return_value = coupon_use_ref
        coupons_col = Mock()
        coupons_col.document.return_value = coupon_ref

        seller_profile_ref = Mock()
        seller_profile_ref.get.return_value = _snap(
            {Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True, Fields.STRIPE_ACCOUNT_ID: "acct_1"},
            exists=True,
            doc_id="seller_1",
        )
        seller_profiles_col = Mock()
        seller_profiles_col.document.return_value = seller_profile_ref

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SUBSCRIPTIONS: sub_col,
            Collections.PRODUCTS: products_col,
            Collections.ORDERS: orders_col,
            Collections.COUPONS: coupons_col,
            Collections.SELLER_PROFILES: seller_profiles_col,
        }[name]
        db.get_all.side_effect = [
            [
                _snap(
                    {
                        Fields.SELLER_ID: "seller_1",
                        Fields.PRICE: 10.0,
                        Fields.NAME: "Product 1",
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                        Fields.IS_DIGITAL: False,
                    },
                    exists=True,
                    doc_id="p1",
                ),
                _snap(
                    {
                        Fields.SELLER_ID: "seller_1",
                        Fields.PRICE: 20.0,
                        Fields.NAME: "Product 2",
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                        Fields.IS_DIGITAL: False,
                    },
                    exists=True,
                    doc_id="p2",
                ),
            ],
            [_snap({Fields.SUSPENDED: False}, exists=True, doc_id="seller_1")],
            [_snap({Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True}, exists=True, doc_id="seller_1")],
        ]
        mock_get_db.return_value = db

        mock_plan.return_value = {
            "stock_deduct_by_product": {"p1": 1, "p2": 0},
            "warehouse_deduct_by_product": {"p1": {"wh_1": 1}},
            "item_warehouse_by_index": {0: "wh_1"},
            "variant_state_by_product": {"p1": [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 2}]},
        }

        req = _checkout_req(
            data={
                Fields.ITEMS: [
                    {Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1, Fields.CART_ITEM_ID: "ci_1"},
                    {Fields.PRODUCT_ID: "p2", Fields.QUANTITY: 1, Fields.CART_ITEM_ID: "ci_2"},
                ],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 3000,
                Fields.COUPON_CODE: "SAVE10",
                Fields.DELIVERY_SPEED: "standard",
            }
        )

        out = create_checkout_session(req)
        assert out[ApiKeys.SUCCESS] is True
        assert inv_ref.get.called
        assert private_doc.set.called  # private snapshot write attempted (and failed non-fatally)

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(0.0, {}))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_transaction_rechecks_product_exists_inside_txn(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_get_txn,
    ):
        from handlers.payment_stripe import create_checkout_session

        db, _ = _checkout_db_simple(
            product_data={
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 10.0,
                Fields.NAME: "Product",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.IS_DIGITAL: False,
            }
        )
        db.collection(Collections.PRODUCTS).document("p1").get.return_value = _snap(exists=False, doc_id="p1")
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )

        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "not-found"
        assert "Product p1 not found" in str(exc.value)

    @patch("handlers.payment_stripe._coupon_within_limits", return_value=True)
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(0.0, {}))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_transaction_rechecks_coupon_missing_inside_txn(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_get_txn,
        _mock_coupon_limits,
    ):
        from handlers.payment_stripe import create_checkout_session

        pre_coupon = {
            Fields.COUPON_CODE: "SAVE10",
            Fields.USED_COUNT: 0,
            Fields.MAX_USES_TOTAL: 10,
            Fields.MAX_USES_PER_USER: 5,
            Fields.SELLER_ID: "seller_1",
        }
        db, _ = _checkout_db_simple(
            product_data={
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 10.0,
                Fields.NAME: "Product",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.IS_DIGITAL: False,
            },
            coupon_data=pre_coupon,
        )
        db.collection(Collections.PRODUCTS).document("p1").get.return_value = _snap(
            {Fields.HAS_VARIANTS: False},
            exists=True,
            doc_id="p1",
        )
        coupon_ref = db.collection(Collections.COUPONS).document.return_value
        coupon_ref.get.side_effect = [
            _snap(pre_coupon, exists=True, doc_id="SAVE10"),
            _snap(exists=False, doc_id="SAVE10"),
        ]
        coupon_use_ref = coupon_ref.collection.return_value.document.return_value
        coupon_use_ref.get.return_value = _snap({Fields.USE_COUNT: 0}, exists=True, doc_id="buyer_1")

        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                Fields.COUPON_CODE: "SAVE10",
            }
        )

        with (
            patch(
                "handlers.payment_stripe._build_stock_reservation_plan",
                return_value={
                    "stock_deduct_by_product": {},
                    "warehouse_deduct_by_product": {},
                    "item_warehouse_by_index": {},
                    "variant_state_by_product": {},
                },
            ),
            pytest.raises(https_fn.HttpsError) as exc,
        ):
            create_checkout_session(req)
        assert exc.value.code == "not-found"
        assert "Coupon invalid" in str(exc.value)

    @patch(
        "handlers.payment_stripe._build_stock_reservation_plan",
        return_value={
            "stock_deduct_by_product": {},
            "warehouse_deduct_by_product": {},
            "item_warehouse_by_index": {},
            "variant_state_by_product": {},
        },
    )
    @patch("handlers.payment_stripe._coupon_within_limits", return_value=True)
    @patch("handlers.payment_stripe._coupon_not_expired", side_effect=[True, False])
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(0.0, {}))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_transaction_rechecks_coupon_expiry_inside_txn(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_get_txn,
        _mock_coupon_expiry,
        _mock_coupon_limits,
        _mock_plan,
    ):
        from handlers.payment_stripe import create_checkout_session

        pre_coupon = {
            Fields.COUPON_CODE: "SAVE10",
            Fields.USED_COUNT: 0,
            Fields.MAX_USES_TOTAL: 10,
            Fields.MAX_USES_PER_USER: 5,
            Fields.SELLER_ID: "seller_1",
        }
        db, _ = _checkout_db_simple(
            product_data={
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 10.0,
                Fields.NAME: "Product",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.IS_DIGITAL: False,
            },
            coupon_data=pre_coupon,
        )
        db.collection(Collections.PRODUCTS).document("p1").get.return_value = _snap(
            {Fields.HAS_VARIANTS: False},
            exists=True,
            doc_id="p1",
        )
        coupon_ref = db.collection(Collections.COUPONS).document.return_value
        coupon_ref.get.side_effect = [
            _snap(pre_coupon, exists=True, doc_id="SAVE10"),
            _snap(pre_coupon, exists=True, doc_id="SAVE10"),
        ]
        coupon_use_ref = coupon_ref.collection.return_value.document.return_value
        coupon_use_ref.get.return_value = _snap({Fields.USE_COUNT: 0}, exists=True, doc_id="buyer_1")

        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                Fields.COUPON_CODE: "SAVE10",
            }
        )

        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "failed-precondition"
        assert "Coupon has expired" in str(exc.value)

    @patch(
        "handlers.payment_stripe._build_stock_reservation_plan",
        return_value={
            "stock_deduct_by_product": {},
            "warehouse_deduct_by_product": {},
            "item_warehouse_by_index": {},
            "variant_state_by_product": {},
        },
    )
    @patch("handlers.payment_stripe._coupon_within_limits", return_value=True)
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(0.0, {}))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_transaction_rechecks_coupon_usage_caps_inside_txn(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_get_txn,
        _mock_coupon_limits,
        _mock_plan,
    ):
        from handlers.payment_stripe import create_checkout_session

        pre_coupon = {
            Fields.COUPON_CODE: "SAVE10",
            Fields.USED_COUNT: 0,
            Fields.MAX_USES_TOTAL: 10,
            Fields.MAX_USES_PER_USER: 5,
            Fields.SELLER_ID: "seller_1",
        }
        txn_coupon_fully_used = {
            Fields.COUPON_CODE: "SAVE10",
            Fields.USED_COUNT: 10,
            Fields.MAX_USES_TOTAL: 10,
            Fields.MAX_USES_PER_USER: 5,
            Fields.SELLER_ID: "seller_1",
        }
        db, _ = _checkout_db_simple(
            product_data={
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 10.0,
                Fields.NAME: "Product",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.IS_DIGITAL: False,
            },
            coupon_data=pre_coupon,
        )
        db.collection(Collections.PRODUCTS).document("p1").get.return_value = _snap(
            {Fields.HAS_VARIANTS: False},
            exists=True,
            doc_id="p1",
        )
        coupon_ref = db.collection(Collections.COUPONS).document.return_value
        coupon_ref.get.side_effect = [
            _snap(pre_coupon, exists=True, doc_id="SAVE10"),
            _snap(txn_coupon_fully_used, exists=True, doc_id="SAVE10"),
        ]
        coupon_use_ref = coupon_ref.collection.return_value.document.return_value
        coupon_use_ref.get.return_value = _snap({Fields.USE_COUNT: 0}, exists=True, doc_id="buyer_1")

        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                Fields.COUPON_CODE: "SAVE10",
            }
        )

        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "resource-exhausted"
        assert "Coupon fully used" in str(exc.value)

        # Same setup, but hit per-user cap branch in transaction validation.
        txn_coupon_per_user = {
            Fields.COUPON_CODE: "SAVE10",
            Fields.USED_COUNT: 1,
            Fields.MAX_USES_TOTAL: 10,
            Fields.MAX_USES_PER_USER: 1,
            Fields.SELLER_ID: "seller_1",
        }
        coupon_ref.get.side_effect = [
            _snap(pre_coupon, exists=True, doc_id="SAVE10"),
            _snap(txn_coupon_per_user, exists=True, doc_id="SAVE10"),
        ]
        coupon_use_ref.get.return_value = _snap({Fields.USE_COUNT: 1}, exists=True, doc_id="buyer_1")
        db.get_all.side_effect = [
            [
                _snap(
                    {
                        Fields.SELLER_ID: "seller_1",
                        Fields.PRICE: 10.0,
                        Fields.NAME: "Product",
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                        Fields.IS_DIGITAL: False,
                    },
                    exists=True,
                    doc_id="p1",
                )
            ],
            [_snap({Fields.SUSPENDED: False, Fields.IS_SMALL_SUPPLIER: False}, exists=True, doc_id="seller_1")],
            [_snap({Fields.ONBOARDING_COMPLETED: True, Fields.CHARGES_ENABLED: True}, exists=True, doc_id="seller_1")],
        ]

        with pytest.raises(https_fn.HttpsError) as per_user_exc:
            create_checkout_session(req)
        assert per_user_exc.value.code == "resource-exhausted"
        assert "Coupon limit per user reached" in str(per_user_exc.value)

    @patch("handlers.payment_stripe._build_stock_reservation_plan", side_effect=RuntimeError("plan failed"))
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(0.0, {}))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_transaction_generic_failure_maps_internal(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_get_txn,
        _mock_plan,
    ):
        from handlers.payment_stripe import create_checkout_session

        db, _ = _checkout_db_simple(
            product_data={
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 10.0,
                Fields.NAME: "Product",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.IS_DIGITAL: False,
            }
        )
        # Allow transactional reads used by the inner function.
        p_ref = db.collection(Collections.PRODUCTS).document("p1")
        p_ref.get.return_value = _snap({Fields.HAS_VARIANTS: False}, exists=True, doc_id="p1")
        db.collection(Collections.SELLER_PROFILES).document.return_value.get.return_value = _snap(
            {Fields.STRIPE_ACCOUNT_ID: "acct_1"},
            exists=True,
            doc_id="seller_1",
        )
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "internal"

    @patch("handlers.payment_stripe._rollback_checkout")
    @patch("handlers.payment_stripe.stripe.checkout.Session.create", side_effect=RuntimeError("unexpected checkout failure"))
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda _fn: (lambda _tx: True))
    @patch("handlers.payment_stripe.calculate_shipping_cost", return_value=(0.0, {}))
    @patch("handlers.payment_stripe.STRIPE_TAX_ENABLED", False)
    @patch("utils.helpers.validate_postal_code")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    def test_checkout_unexpected_session_error_maps_internal(
        self,
        _mock_provider,
        _mock_key,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_validate_postal,
        _mock_calc_shipping,
        _mock_get_txn,
        _mock_session,
        mock_rollback,
    ):
        from handlers.payment_stripe import create_checkout_session

        db, _ = _checkout_db_simple(
            product_data={
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 10.0,
                Fields.NAME: "Product",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.IS_DIGITAL: True,
            }
        )
        mock_get_db.return_value = db
        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _checkout_req(
            data={
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.QUANTITY: 1, Fields.IS_DIGITAL: True}],
                Fields.SHIPPING_ADDRESS: _shipping_address(),
                ApiKeys.SUBTOTAL_CENTS: 1000,
                ApiKeys.EULA_ACCEPTED: True,
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            create_checkout_session(req)
        assert exc.value.code == "internal"
        mock_rollback.assert_called_once()


class TestStripeWebhookBranches:
    @patch("handlers.payment_stripe.IS_EMULATOR", False)
    @patch("handlers.payment_stripe.get_rate_limiter")
    def test_webhook_rate_limited_returns_429(self, mock_get_rate_limiter):
        from handlers.payment_stripe import stripe_webhook

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (False, "busy")
        req = _webhook_req(headers={"Stripe-Signature": "sig", "X-Forwarded-For": "1.1.1.1"})
        response = stripe_webhook(req)
        assert getattr(response, "status_code", 429) == 429

    def test_webhook_rejects_non_post(self):
        from handlers.payment_stripe import stripe_webhook

        req = _webhook_req()
        req.method = "GET"
        response = stripe_webhook(req)
        assert getattr(response, "status_code", 405) == 405

    @patch("handlers.payment_stripe.get_rate_limiter")
    def test_webhook_missing_signature(self, mock_get_rate_limiter):
        from handlers.payment_stripe import stripe_webhook

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")
        req = _webhook_req(headers={"X-Forwarded-For": "1.1.1.1"})
        response = stripe_webhook(req)
        assert getattr(response, "status_code", 400) == 400

    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.stripe.Webhook.construct_event")
    def test_webhook_invalid_payload_and_verification_error(self, mock_construct, mock_get_rate_limiter):
        from handlers.payment_stripe import stripe_webhook

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        req = _webhook_req(headers={"Stripe-Signature": "sig", "X-Forwarded-For": "1.1.1.1"})
        mock_construct.side_effect = ValueError("bad payload")
        bad_payload_resp = stripe_webhook(req)
        assert getattr(bad_payload_resp, "status_code", 400) == 400

        class _AnyWebhookError(Exception):
            pass

        mock_construct.side_effect = _AnyWebhookError("boom")
        verify_resp = stripe_webhook(req)
        assert getattr(verify_resp, "status_code", 500) == 500

    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.stripe.Webhook.construct_event")
    def test_webhook_signature_verification_exception_name_maps_to_400(self, mock_construct, mock_get_rate_limiter):
        from handlers.payment_stripe import stripe_webhook

        class SignatureVerificationError(Exception):
            pass

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")
        mock_construct.side_effect = SignatureVerificationError("bad sig")
        req = _webhook_req(headers={"Stripe-Signature": "sig", "X-Forwarded-For": "1.1.1.1"})
        response = stripe_webhook(req)
        assert getattr(response, "status_code", 400) == 400

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe._get_webhook_secret", return_value="whsec_test")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.stripe.Webhook.construct_event")
    def test_webhook_duplicate_completed_event_short_circuits(
        self,
        mock_construct,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_secret,
        _mock_ensure,
    ):
        from handlers.payment_stripe import stripe_webhook

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        webhook_doc = Mock()
        webhook_doc.exists = True
        webhook_doc.to_dict.return_value = {Fields.STATUS: "completed"}

        webhook_ref = Mock()
        webhook_ref.create.side_effect = RuntimeError("already exists")
        webhook_ref.get.return_value = webhook_doc

        db = Mock()
        db.collection.return_value.document.return_value = webhook_ref
        mock_get_db.return_value = db

        mock_construct.return_value = {
            StripeConstants.OBJECT_ID: "evt_dup",
            Fields.TYPE: StripeEventTypes.CHECKOUT_COMPLETED,
            StripeConstants.CREATED: int(datetime.now(UTC).timestamp()),
            StripeConstants.DATA: {StripeConstants.OBJECT: {StripeConstants.METADATA: {}}},
        }

        response = stripe_webhook(_webhook_req(headers={"Stripe-Signature": "sig", "X-Forwarded-For": "1.1.1.1"}))
        assert getattr(response, "status_code", 200) == 200

    @patch("handlers.payment_stripe.IS_EMULATOR", False)
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.stripe.Webhook.construct_event")
    def test_webhook_rejects_stale_payment_events(self, mock_construct, mock_get_rate_limiter):
        from handlers.payment_stripe import stripe_webhook

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")
        stale_created = int((datetime.now(UTC) - timedelta(days=2)).timestamp())
        mock_construct.return_value = {
            StripeConstants.OBJECT_ID: "evt_stale",
            Fields.TYPE: StripeEventTypes.PAYMENT_INTENT_SUCCEEDED,
            StripeConstants.CREATED: stale_created,
            StripeConstants.DATA: {StripeConstants.OBJECT: {StripeConstants.METADATA: {}}},
        }

        req = _webhook_req(headers={"Stripe-Signature": "sig", "X-Forwarded-For": "1.1.1.1"})
        response = stripe_webhook(req)
        assert getattr(response, "status_code", 400) == 400

    @pytest.mark.parametrize(
        ("event_type", "patch_target"),
        [
            (StripeEventTypes.ASYNC_PAYMENT_SUCCEEDED, "handlers.payment_stripe.process_async_payment_succeeded"),
            (StripeEventTypes.ASYNC_PAYMENT_FAILED, "handlers.payment_stripe.process_async_payment_failed"),
            (StripeEventTypes.SESSION_EXPIRED, "handlers.payment_stripe.process_session_expired"),
            (StripeEventTypes.PAYMENT_INTENT_SUCCEEDED, "handlers.payment_stripe.process_payment_intent_succeeded"),
            (StripeEventTypes.PAYMENT_INTENT_PAYMENT_FAILED, "handlers.payment_stripe.process_payment_intent_failed"),
            (StripeEventTypes.CHARGE_REFUNDED, "handlers.payment_stripe.process_charge_refunded"),
            (StripeEventTypes.DISPUTE_CREATED, "handlers.payment_stripe.process_dispute_created"),
            (StripeEventTypes.DISPUTE_UPDATED, "handlers.payment_stripe.process_dispute_updated"),
            (StripeEventTypes.DISPUTE_CLOSED, "handlers.payment_stripe.process_dispute_closed"),
            (StripeEventTypes.DISPUTE_FUNDS_REINSTATED, "handlers.payment_stripe.process_dispute_funds_reinstated"),
            (StripeEventTypes.TRANSFER_REVERSED, "handlers.payment_stripe.process_transfer_reversed"),
            (StripeEventTypes.PAYOUT_FAILED, "handlers.payment_stripe.process_payout_failed"),
            (StripeEventTypes.REFUND_FAILED, "handlers.payment_stripe.process_refund_failed"),
            (StripeEventTypes.PAYMENT_INTENT_CANCELED, "handlers.payment_stripe.process_payment_intent_canceled"),
            (StripeEventTypes.ACCOUNT_UPDATED, "handlers.payment_stripe.process_account_updated"),
        ],
    )
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe._get_webhook_secret", return_value="whsec_test")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.stripe.Webhook.construct_event")
    def test_webhook_routes_core_events(
        self,
        mock_construct,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_secret,
        _mock_ensure_key,
        event_type,
        patch_target,
    ):
        from handlers.payment_stripe import stripe_webhook

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")
        webhook_ref = Mock()
        webhook_ref.create.return_value = None
        db = Mock()
        db.collection.return_value.document.return_value = webhook_ref
        mock_get_db.return_value = db

        event_obj = {StripeConstants.METADATA: {StripeConstants.METADATA_ORDER_ID: "order_1"}}
        mock_construct.return_value = {
            StripeConstants.OBJECT_ID: f"evt_{event_type}",
            Fields.TYPE: event_type,
            StripeConstants.CREATED: int(datetime.now(UTC).timestamp()),
            StripeConstants.DATA: {StripeConstants.OBJECT: event_obj},
        }

        with patch(patch_target) as routed:
            response = stripe_webhook(_webhook_req(headers={"Stripe-Signature": "sig", "X-Forwarded-For": "1.1.1.1"}))

        assert getattr(response, "status_code", 200) == 200
        routed.assert_called_once_with(event_obj)

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe._get_webhook_secret", return_value="whsec_test")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.stripe.Webhook.construct_event")
    def test_webhook_handles_failed_idempotency_doc_then_retries_failed_event(
        self,
        mock_construct,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_secret,
        _mock_ensure_key,
    ):
        from handlers.payment_stripe import stripe_webhook

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        webhook_doc = Mock()
        webhook_doc.exists = True
        webhook_doc.to_dict.return_value = {Fields.STATUS: "failed"}

        webhook_ref = Mock()
        webhook_ref.create.side_effect = RuntimeError("exists")
        webhook_ref.get.return_value = webhook_doc

        db = Mock()
        db.collection.return_value.document.return_value = webhook_ref
        mock_get_db.return_value = db

        mock_construct.return_value = {
            StripeConstants.OBJECT_ID: "evt_retry",
            Fields.TYPE: "unhandled.event",
            StripeConstants.CREATED: int(datetime.now(UTC).timestamp()),
            StripeConstants.DATA: {StripeConstants.OBJECT: {StripeConstants.METADATA: {}}},
        }

        response = stripe_webhook(_webhook_req(headers={"Stripe-Signature": "sig", "X-Forwarded-For": "1.1.1.1"}))
        assert getattr(response, "status_code", 200) == 200
        webhook_ref.update.assert_any_call({Fields.STATUS: "processing", Fields.TIMESTAMP: ANY})

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe._get_webhook_secret", return_value="whsec_test")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.stripe.Webhook.construct_event")
    def test_webhook_idempotency_read_error_is_swallowed(
        self,
        mock_construct,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_secret,
        _mock_ensure_key,
    ):
        from handlers.payment_stripe import stripe_webhook

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")

        webhook_ref = Mock()
        webhook_ref.create.side_effect = RuntimeError("already exists")
        webhook_ref.get.side_effect = RuntimeError("read failed")

        db = Mock()
        db.collection.return_value.document.return_value = webhook_ref
        mock_get_db.return_value = db

        mock_construct.return_value = {
            StripeConstants.OBJECT_ID: "evt_retry_read_err",
            Fields.TYPE: "unhandled.event",
            StripeConstants.CREATED: int(datetime.now(UTC).timestamp()),
            StripeConstants.DATA: {StripeConstants.OBJECT: {StripeConstants.METADATA: {}}},
        }

        response = stripe_webhook(_webhook_req(headers={"Stripe-Signature": "sig", "X-Forwarded-For": "1.1.1.1"}))
        assert getattr(response, "status_code", 200) == 200

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe._get_webhook_secret", return_value="whsec_test")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.stripe.Webhook.construct_event")
    @patch("handlers.payment_stripe.process_checkout_session_completed", side_effect=RuntimeError("processor boom"))
    def test_webhook_marks_failed_when_processor_crashes(
        self,
        _mock_processor,
        mock_construct,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_secret,
        _mock_ensure_key,
    ):
        from handlers.payment_stripe import stripe_webhook

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")
        webhook_ref = Mock()
        webhook_ref.create.return_value = None

        db = Mock()
        db.collection.return_value.document.return_value = webhook_ref
        mock_get_db.return_value = db

        mock_construct.return_value = {
            StripeConstants.OBJECT_ID: "evt_fail",
            Fields.TYPE: StripeEventTypes.CHECKOUT_COMPLETED,
            StripeConstants.CREATED: int(datetime.now(UTC).timestamp()),
            StripeConstants.DATA: {StripeConstants.OBJECT: {StripeConstants.METADATA: {}}},
        }

        response = stripe_webhook(_webhook_req(headers={"Stripe-Signature": "sig", "X-Forwarded-For": "1.1.1.1"}))
        assert getattr(response, "status_code", 500) == 500
        webhook_ref.update.assert_any_call({Fields.STATUS: "failed", Fields.ERROR: "RuntimeError"})

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe._get_webhook_secret", return_value="whsec_test")
    @patch("handlers.payment_stripe.get_rate_limiter")
    @patch("handlers.payment_stripe.get_db")
    @patch("handlers.payment_stripe.stripe.Webhook.construct_event")
    @patch("handlers.subscriptions.handle_subscription_created")
    @patch("handlers.subscriptions.handle_subscription_updated")
    @patch("handlers.subscriptions.handle_subscription_deleted")
    @patch("handlers.subscriptions.handle_invoice_payment_failed")
    @patch("handlers.payment_stripe.stripe.Subscription.retrieve", return_value=SimpleNamespace(id="sub_live"))
    def test_webhook_routes_subscription_events(
        self,
        _mock_sub_retrieve,
        mock_invoice_failed,
        mock_sub_deleted,
        mock_sub_updated,
        mock_sub_created,
        mock_construct,
        mock_get_db,
        mock_get_rate_limiter,
        _mock_secret,
        _mock_ensure_key,
    ):
        from handlers.payment_stripe import stripe_webhook

        mock_get_rate_limiter.return_value.check_rate_limit.return_value = (True, "")
        webhook_ref = Mock()
        db = Mock()
        db.collection.return_value.document.return_value = webhook_ref
        mock_get_db.return_value = db

        now_ts = int(datetime.now(UTC).timestamp())

        def _set_event(event_type, obj):
            mock_construct.return_value = {
                StripeConstants.OBJECT_ID: f"evt_{event_type}",
                Fields.TYPE: event_type,
                StripeConstants.CREATED: now_ts,
                StripeConstants.DATA: {StripeConstants.OBJECT: obj},
            }

        _set_event(StripeEventTypes.SUBSCRIPTION_CREATED, {})
        assert getattr(stripe_webhook(_webhook_req({"Stripe-Signature": "sig"})), "status_code", 200) == 200
        mock_sub_created.assert_called_once()

        _set_event(StripeEventTypes.SUBSCRIPTION_UPDATED, {})
        assert getattr(stripe_webhook(_webhook_req({"Stripe-Signature": "sig"})), "status_code", 200) == 200
        mock_sub_updated.assert_called()

        _set_event(StripeEventTypes.SUBSCRIPTION_DELETED, {})
        assert getattr(stripe_webhook(_webhook_req({"Stripe-Signature": "sig"})), "status_code", 200) == 200
        mock_sub_deleted.assert_called_once()

        _set_event(StripeEventTypes.INVOICE_PAYMENT_FAILED, {})
        assert getattr(stripe_webhook(_webhook_req({"Stripe-Signature": "sig"})), "status_code", 200) == 200
        mock_invoice_failed.assert_called_once()

        _set_event(StripeEventTypes.INVOICE_PAID, {StripeConstants.SUBSCRIPTION: "sub_live"})
        assert getattr(stripe_webhook(_webhook_req({"Stripe-Signature": "sig"})), "status_code", 200) == 200
        # invoice.paid calls handle_subscription_updated with transformed sub_event
        assert mock_sub_updated.call_count >= 2
