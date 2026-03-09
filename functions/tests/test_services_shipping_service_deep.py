from unittest.mock import MagicMock, patch

import pytest

from schema_constants import (
    DeliveryTypeValues,
    DiscountTypeValues,
    Fields,
    ShippingTiers,
    ShippingSourceValues,
)
from services import shipping_service as shipping


def _item(
    product_id: str = "prod_1",
    seller_id: str = "seller_1",
    qty: int = 1,
    seller_state: str = "ON",
    **overrides,
):
    data = {
        Fields.PRODUCT_ID: product_id,
        Fields.CART_ITEM_ID: f"cart_{product_id}",
        Fields.SELLER_ID: seller_id,
        Fields.QUANTITY: qty,
        Fields.SELLER_ADDRESS: {
            Fields.STATE: seller_state,
            Fields.LATITUDE: 43.7,
            Fields.LONGITUDE: -79.4,
        },
        Fields.WEIGHT_KG: 0.5,
        Fields.LENGTH_CM: 10,
        Fields.WIDTH_CM: 10,
        Fields.HEIGHT_CM: 10,
        Fields.FREE_SHIPPING: False,
        Fields.IS_DIGITAL: False,
    }
    data.update(overrides)
    return data


def _buyer(state: str = "ON"):
    return {
        Fields.STATE: state,
        Fields.LATITUDE: 45.5,
        Fields.LONGITUDE: -73.5,
    }


class _MockGeoResponse:
    def __init__(self, status_code: int, distance_m: float = 10000):
        self.status_code = status_code
        self._distance_m = distance_m

    def json(self):
        return {"sources_to_targets": [[{"distance": self._distance_m}]]}


class TestEstimateDeliveryDateRange:
    def test_supplier_override_parse_error_falls_back_to_supplier_default(self):
        out = shipping.estimate_delivery_date_range(
            supplier_info={
                Fields.TYPE: "aliexpress",
                Fields.SHIPPING_DAYS: "bad-format",
                Fields.HAS_TRACKING: True,
            },
            speed=DeliveryTypeValues.STANDARD,
        )
        assert out["min_days"] == 15
        assert out["max_days"] == 30
        assert out["source"] == ShippingSourceValues.INTERNATIONAL_SUPPLIER

    def test_generic_international_express(self):
        out = shipping.estimate_delivery_date_range(
            supplier_info=None,
            is_international=True,
            speed=DeliveryTypeValues.EXPRESS,
        )
        assert out["min_days"] == 5
        assert out["max_days"] == 10
        assert out["source"] == ShippingSourceValues.INTERNATIONAL_GENERIC

    def test_generic_international_standard_uses_default_range(self):
        out = shipping.estimate_delivery_date_range(
            supplier_info=None,
            is_international=True,
            speed=DeliveryTypeValues.STANDARD,
        )
        assert out["min_days"] == ShippingTiers.INTL_GENERIC_MIN_DAYS
        assert out["max_days"] == ShippingTiers.INTL_GENERIC_MAX_DAYS
        assert out["source"] == ShippingSourceValues.INTERNATIONAL_GENERIC

    def test_domestic_same_day(self):
        out = shipping.estimate_delivery_date_range(
            supplier_info=None,
            is_international=False,
            speed=DeliveryTypeValues.SAME_DAY,
        )
        assert out["display_text"] == "Today"
        assert out["source"] == ShippingSourceValues.DOMESTIC

    def test_domestic_express(self):
        out = shipping.estimate_delivery_date_range(
            supplier_info=None,
            is_international=False,
            speed=DeliveryTypeValues.EXPRESS,
        )
        assert out["display_text"] == "1-3 business days"
        assert out["source"] == ShippingSourceValues.DOMESTIC


class TestShippingHelpers:
    def test_tiered_shipping_itemized_with_weight_surcharge(self):
        items = [
            _item(
                product_id="heavy",
                qty=2,
                **{
                    Fields.WEIGHT_KG: 3.0,
                    Fields.LENGTH_CM: 20,
                    Fields.WIDTH_CM: 20,
                    Fields.HEIGHT_CM: 20,
                },
            )
        ]
        total, breakdown = shipping._calculate_tiered_shipping_itemized(100, items, DeliveryTypeValues.STANDARD)

        assert total == pytest.approx(sum(breakdown.values()))
        assert breakdown["cart_heavy"] > 0

    def test_tiered_shipping_itemized_express_multiplier_path(self):
        items = [_item(product_id="exp", qty=1)]
        total, breakdown = shipping._calculate_tiered_shipping_itemized(10, items, DeliveryTypeValues.EXPRESS)
        assert total == pytest.approx(sum(breakdown.values()))
        assert breakdown["cart_exp"] > 0

    def test_tiered_shipping_itemized_express_default_multiplier_path(self):
        items = [_item(product_id="exp_far", qty=1)]
        total, breakdown = shipping._calculate_tiered_shipping_itemized(300, items, DeliveryTypeValues.EXPRESS)
        assert total == pytest.approx(sum(breakdown.values()))
        assert breakdown["cart_exp_far"] > 0

    def test_tiered_shipping_itemized_same_day_multiplier_path(self):
        items = [_item(product_id="same", qty=1)]
        total, breakdown = shipping._calculate_tiered_shipping_itemized(10, items, DeliveryTypeValues.SAME_DAY)
        assert total == pytest.approx(sum(breakdown.values()))
        assert breakdown["cart_same"] > 0

    def test_tiered_shipping_itemized_same_day_local_and_default_paths(self):
        local_items = [_item(product_id="same_local", qty=1)]
        local_total, local_breakdown = shipping._calculate_tiered_shipping_itemized(
            40, local_items, DeliveryTypeValues.SAME_DAY
        )
        assert local_total == pytest.approx(sum(local_breakdown.values()))
        assert local_breakdown["cart_same_local"] > 0

        default_items = [_item(product_id="same_default", qty=1)]
        default_total, default_breakdown = shipping._calculate_tiered_shipping_itemized(
            200, default_items, DeliveryTypeValues.SAME_DAY
        )
        assert default_total == pytest.approx(sum(default_breakdown.values()))
        assert default_breakdown["cart_same_default"] > 0

    def test_tiered_shipping_itemized_uses_additional_item_pricing_after_first_item(self):
        items = [_item(product_id="first", qty=1), _item(product_id="second", qty=2)]
        total, breakdown = shipping._calculate_tiered_shipping_itemized(20, items, DeliveryTypeValues.STANDARD)
        assert total == pytest.approx(sum(breakdown.values()))
        assert breakdown["cart_second"] > 0

    def test_fallback_shipping_itemized_same_region_express(self):
        # NB and NL are in same region but not adjacent -> SAME_REGION branch
        total, breakdown = shipping._calculate_fallback_shipping_itemized(
            [_item(product_id="f1", seller_state="NB")],
            "NB",
            "NL",
            speed=DeliveryTypeValues.EXPRESS,
        )

        expected = ShippingTiers.FALLBACK_SAME_REGION * ShippingTiers.EXPRESS_MULTIPLIERS["regional"]
        assert total == pytest.approx(expected)
        assert breakdown["cart_f1"] == pytest.approx(expected)

    def test_best_quantity_discount_skips_malformed_entries(self):
        discounts = [
            {Fields.MIN_QUANTITY: "bad", Fields.DISCOUNT_VALUE: 99},
            {Fields.MIN_QUANTITY: 2, Fields.DISCOUNT_VALUE: 15},
        ]
        best = shipping._best_quantity_discount(discounts, quantity=3)
        assert best[Fields.MIN_QUANTITY] == 2


class TestDeliveryOptionPricing:
    def test_delivery_option_percent_discount_is_clamped(self):
        option = {
            Fields.TYPE: DeliveryTypeValues.STANDARD,
            Fields.COST_CENTS: 1000,
            Fields.QUANTITY_DISCOUNTS: [
                {
                    Fields.MIN_QUANTITY: 1,
                    Fields.DISCOUNT_TYPE: DiscountTypeValues.PERCENT,
                    Fields.DISCOUNT_VALUE: 200,
                }
            ],
        }
        assert shipping._calculate_delivery_option_cost(option, quantity=1) == 0.0

    def test_delivery_option_fixed_discount(self):
        option = {
            Fields.TYPE: DeliveryTypeValues.STANDARD,
            Fields.COST_CENTS: 1000,
            Fields.QUANTITY_DISCOUNTS: [
                {
                    Fields.MIN_QUANTITY: 1,
                    Fields.DISCOUNT_TYPE: DiscountTypeValues.FIXED,
                    Fields.DISCOUNT_VALUE: 3,
                }
            ],
        }
        assert shipping._calculate_delivery_option_cost(option, quantity=1) == pytest.approx(7.0)

    def test_delivery_option_flat_rate_discount(self):
        option = {
            Fields.TYPE: DeliveryTypeValues.STANDARD,
            Fields.COST_CENTS: 1000,
            Fields.QUANTITY_DISCOUNTS: [
                {
                    Fields.MIN_QUANTITY: 1,
                    Fields.DISCOUNT_TYPE: DiscountTypeValues.FLAT_RATE,
                    Fields.DISCOUNT_VALUE: 2.5,
                }
            ],
        }
        assert shipping._calculate_delivery_option_cost(option, quantity=1) == pytest.approx(2.5)

    def test_delivery_option_unknown_discount_type_returns_base(self):
        option = {
            Fields.TYPE: DeliveryTypeValues.STANDARD,
            Fields.COST_CENTS: 1000,
            Fields.QUANTITY_DISCOUNTS: [
                {
                    Fields.MIN_QUANTITY: 1,
                    Fields.DISCOUNT_TYPE: "unknown_type",
                    Fields.DISCOUNT_VALUE: 999,
                }
            ],
        }
        assert shipping._calculate_delivery_option_cost(option, quantity=1) == pytest.approx(10.0)

    def test_delivery_option_handles_malformed_numeric_fields(self):
        option = {
            Fields.TYPE: DeliveryTypeValues.STANDARD,
            Fields.COST_CENTS: "bad",
            Fields.MAX_ITEMS_PER_SHIPMENT: "bad",
            Fields.ADDITIONAL_ITEM_COST_CENTS: "bad",
            Fields.QUANTITY_DISCOUNTS: [
                {
                    Fields.MIN_QUANTITY: 1,
                    Fields.DISCOUNT_TYPE: DiscountTypeValues.PERCENT,
                    Fields.DISCOUNT_VALUE: "bad",
                }
            ],
        }
        assert shipping._calculate_delivery_option_cost(option, quantity=3) == 0.0

    def test_alternate_delivery_schema_with_bad_price_defaults_zero(self):
        option = {
            Fields.DELIVERY_SPEED: DeliveryTypeValues.STANDARD,
            "isEnabled": True,
            Fields.PRICE: "not-a-number",
        }
        assert shipping._calculate_delivery_option_cost(option, quantity=4) == 0.0

    def test_find_matching_delivery_option_canonical(self):
        options = [{Fields.TYPE: DeliveryTypeValues.EXPRESS, Fields.COST_CENTS: 1000}]
        match = shipping._find_matching_delivery_option(options, DeliveryTypeValues.EXPRESS)
        assert match[Fields.TYPE] == DeliveryTypeValues.EXPRESS

    def test_find_matching_delivery_option_alternate_schema(self):
        options = [
            {"invalid": True},
            {
                Fields.DELIVERY_SPEED: DeliveryTypeValues.SAME_DAY,
                "isEnabled": True,
                Fields.PRICE: 10,
            },
        ]
        match = shipping._find_matching_delivery_option(options, DeliveryTypeValues.SAME_DAY)
        assert match[Fields.DELIVERY_SPEED] == DeliveryTypeValues.SAME_DAY

    def test_find_matching_delivery_option_returns_none_when_not_found(self):
        options = ["bad-entry", {Fields.TYPE: DeliveryTypeValues.STANDARD}]
        assert shipping._find_matching_delivery_option(options, DeliveryTypeValues.EXPRESS) is None


class TestCalculateShippingCostDeep:
    def test_missing_buyer_address_returns_default_min_cost(self):
        total, breakdown = shipping.calculate_shipping_cost([_item()], None)
        assert total == ShippingTiers.DEFAULT_MIN_COST
        assert breakdown == {}

    def test_uses_ship_from_province_when_seller_address_missing(self):
        item = _item(
            product_id="warehouse",
            **{
                Fields.SELLER_ADDRESS: None,
                Fields.SHIP_FROM_PROVINCE: "BC",
            },
        )
        with patch("services.shipping_service.get_geoapify_api_key", return_value=""):
            total, breakdown = shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.STANDARD)

        assert total > 0
        assert "cart_warehouse" in breakdown

    def test_missing_seller_address_and_ship_from_skips_seller_bucket(self):
        item = _item(
            product_id="missing_origin",
            **{
                Fields.SELLER_ADDRESS: None,
                Fields.SHIP_FROM_PROVINCE: None,
            },
        )
        total, breakdown = shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.STANDARD)
        assert total == 0.0
        assert breakdown == {}

    def test_international_items_use_supplier_estimates_per_item(self):
        item = _item(
            product_id="intl",
            qty=2,
            **{
                Fields.IS_INTERNATIONAL: True,
                Fields.SUPPLIER_TYPE: "aliexpress",
                Fields.WEIGHT_KG: 0.5,
            },
        )
        total, breakdown = shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.STANDARD)

        expected_item = shipping.get_international_shipping_estimate("aliexpress", speed="standard", weight_kg=0.5)["cost"] * 2
        assert total == pytest.approx(expected_item)
        assert breakdown["cart_intl"] == pytest.approx(expected_item)

    def test_local_delivery_only_blocks_cross_province(self):
        item = _item(
            product_id="local_only",
            seller_state="BC",
            **{Fields.IS_LOCAL_DELIVERY_ONLY: True, Fields.NAME: "Fresh Milk"},
        )
        with pytest.raises(ValueError, match="Local delivery only"):
            shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.STANDARD)

    def test_perishable_cross_province_adds_fallback_surcharge(self):
        item = _item(
            product_id="perishable",
            seller_state="BC",
            **{Fields.IS_PERISHABLE: True},
        )
        with patch("services.shipping_service.get_geoapify_api_key", return_value=""):
            total, breakdown = shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.STANDARD)

        assert total >= ShippingTiers.PERISHABLE_CROSS_PROVINCE
        assert breakdown["cart_perishable"] >= ShippingTiers.PERISHABLE_CROSS_PROVINCE

    def test_geoapify_same_day_distance_limit_blocks_request(self):
        item = _item(product_id="same_day_far")
        with (
            patch("services.shipping_service.get_geoapify_api_key", return_value="geo_key"),
            patch("services.shipping_service.requests.post", return_value=_MockGeoResponse(200, distance_m=60000)),
        ):
            with pytest.raises(ValueError, match="Same Day delivery temporarily unavailable"):
                shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.SAME_DAY)

    def test_geoapify_same_day_non_200_fails_safe(self):
        item = _item(product_id="same_day_api_fail")
        with (
            patch("services.shipping_service.get_geoapify_api_key", return_value="geo_key"),
            patch("services.shipping_service.requests.post", return_value=_MockGeoResponse(500)),
        ):
            with pytest.raises(ValueError, match="Same Day delivery temporarily unavailable"):
                shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.SAME_DAY)

    def test_geoapify_same_day_exception_fails_safe(self):
        item = _item(product_id="same_day_exception")
        with (
            patch("services.shipping_service.get_geoapify_api_key", return_value="geo_key"),
            patch("services.shipping_service.requests.post", side_effect=RuntimeError("timeout")),
        ):
            with pytest.raises(ValueError, match="Same Day delivery temporarily unavailable"):
                shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.SAME_DAY)

    def test_geoapify_perishable_long_distance_uses_long_distance_surcharge(self):
        item = _item(product_id="perishable_geo", **{Fields.IS_PERISHABLE: True})
        with (
            patch("services.shipping_service.get_geoapify_api_key", return_value="geo_key"),
            patch("services.shipping_service.requests.post", return_value=_MockGeoResponse(200, distance_m=200000)),
        ):
            total, breakdown = shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.STANDARD)

        assert total >= ShippingTiers.PERISHABLE_LONG_DISTANCE
        assert breakdown["cart_perishable_geo"] >= ShippingTiers.PERISHABLE_LONG_DISTANCE

    def test_seller_fixed_delivery_option_wins_when_all_items_have_options(self):
        option = {
            Fields.TYPE: DeliveryTypeValues.STANDARD,
            Fields.COST_CENTS: 800,
            Fields.MAX_ITEMS_PER_SHIPMENT: 1,
            Fields.ADDITIONAL_ITEM_COST_CENTS: 200,
        }
        item = _item(product_id="fixed_opt", qty=3, **{Fields.DELIVERY_OPTIONS: [option]})

        total, breakdown = shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.STANDARD)
        assert total == pytest.approx(12.0)
        assert breakdown["cart_fixed_opt"] == pytest.approx(12.0)

    def test_zero_cost_fixed_delivery_option_falls_back_to_computed_shipping(self):
        option = {
            Fields.TYPE: DeliveryTypeValues.STANDARD,
            Fields.COST_CENTS: 0,
        }
        item = _item(product_id="fixed_zero", qty=1, **{Fields.DELIVERY_OPTIONS: [option]})

        with patch("services.shipping_service.get_geoapify_api_key", return_value=""):
            total, breakdown = shipping.calculate_shipping_cost([item], _buyer("ON"), speed=DeliveryTypeValues.STANDARD)

        assert total > 0
        assert breakdown["cart_fixed_zero"] > 0
