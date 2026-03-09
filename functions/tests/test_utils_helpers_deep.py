from types import SimpleNamespace
from unittest.mock import patch

import pytest
import requests

from schema_constants import Fields
from utils import helpers


class _MockResponse:
    def __init__(self, status_code: int, payload: dict | None = None):
        self.status_code = status_code
        self._payload = payload or {}

    def json(self):
        return self._payload


class TestBasicSanitizersAndValidators:
    def test_sanitize_path_handles_none(self):
        assert helpers.sanitize_path(None) == ""

    def test_sanitize_text_rejects_none(self):
        with pytest.raises(ValueError, match="field is required"):
            helpers.sanitize_text(None, max_length=10, field_name="field")

    def test_sanitize_text_rejects_too_long(self):
        with pytest.raises(ValueError, match="exceeds max length"):
            helpers.sanitize_text("x" * 50, max_length=10, field_name="field")

    def test_sanitize_email_rejects_none(self):
        with pytest.raises(ValueError, match="Email is required"):
            helpers.sanitize_email(None)

    def test_validate_phone_rejects_none(self):
        with pytest.raises(ValueError, match="Phone is required"):
            helpers.validate_phone(None)

    def test_validate_phone_rejects_bad_format(self):
        with pytest.raises(ValueError, match="Invalid phone format"):
            helpers.validate_phone("+1-555-123-4567")

    def test_validate_phone_accepts_digits_only_format(self):
        assert helpers.validate_phone("1234567890") == "1234567890"

    def test_validate_message_returns_cleaned_text(self):
        assert helpers.validate_message("Hello world!") == "Hello world!"

    def test_validate_item_handles_quantity_business_rule(self):
        with patch.object(
            helpers,
            "OrderItem",
            return_value=SimpleNamespace(quantity=helpers.MAX_ITEM_QUANTITY + 1),
        ):
            ok, msg = helpers.validate_item(
                {
                    Fields.PRODUCT_ID: "p1",
                    Fields.NAME: "Test",
                    Fields.PRICE: 1.0,
                    Fields.QUANTITY: 2,
                    Fields.SELLER_ID: "seller_1",
                }
            )
        assert ok is False
        assert "quantity exceeds maximum" in msg

    def test_validate_item_returns_invalid_item_data_when_validation_error_has_no_details(self):
        class FakeValidationError(Exception):
            def errors(self):
                return []

        with (
            patch.object(helpers, "ValidationError", FakeValidationError),
            patch.object(helpers, "OrderItem", side_effect=FakeValidationError("bad item")),
        ):
            ok, msg = helpers.validate_item({Fields.PRODUCT_ID: "p1"})

        assert ok is False
        assert msg == "Invalid item data"

    def test_validate_item_handles_unexpected_exception(self):
        with patch.object(helpers, "OrderItem", side_effect=RuntimeError("boom")):
            ok, msg = helpers.validate_item({Fields.PRODUCT_ID: "p1"})
        assert ok is False
        assert msg == "boom"


class TestValidateOrderDataBranches:
    def test_validate_order_data_requires_user_id(self):
        ok, msg = helpers.validate_order_data({Fields.ITEMS: []})
        assert ok is False
        assert "Missing required field" in msg

    def test_validate_order_data_requires_non_empty_items(self):
        ok, msg = helpers.validate_order_data({Fields.USER_ID: "u1", Fields.ITEMS: []})
        assert ok is False
        assert "must be non-empty array" in msg

    def test_validate_order_data_requires_shipping_address_for_physical_items(self):
        ok, msg = helpers.validate_order_data(
            {
                Fields.USER_ID: "u1",
                Fields.ITEMS: [{Fields.IS_DIGITAL: False, Fields.PRODUCT_ID: "p1"}],
                Fields.TOTAL_AMOUNT_CENTS: 1000,
            }
        )
        assert ok is False
        assert "shippingAddress" in msg

    def test_validate_order_data_surfaces_address_validation_error(self):
        with patch.object(helpers, "validate_address_map", side_effect=ValueError("bad address")):
            ok, msg = helpers.validate_order_data(
                {
                    Fields.USER_ID: "u1",
                    Fields.ITEMS: [{Fields.IS_DIGITAL: False, Fields.PRODUCT_ID: "p1"}],
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.SHIPPING_ADDRESS: {Fields.COUNTRY: "Canada"},
                }
            )
        assert ok is False
        assert msg == "bad address"

    def test_validate_order_data_surfaces_item_validation_error(self):
        with patch.object(helpers, "validate_item", return_value=(False, "bad item")):
            ok, msg = helpers.validate_order_data(
                {
                    Fields.USER_ID: "u1",
                    Fields.ITEMS: [{Fields.IS_DIGITAL: True, Fields.PRODUCT_ID: "p1"}],
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                }
            )
        assert ok is False
        assert "Item 0: bad item" == msg


class TestChargeAndAddressHelpers:
    def test_get_charge_id_from_pi_none(self):
        assert helpers.get_charge_id_from_pi(None) is None

    def test_get_charge_id_from_pi_without_latest_charge(self):
        pi = SimpleNamespace(latest_charge=None)
        assert helpers.get_charge_id_from_pi(pi) is None

    def test_get_charge_id_from_pi_latest_charge_string(self):
        pi = SimpleNamespace(latest_charge="ch_123")
        assert helpers.get_charge_id_from_pi(pi) == "ch_123"

    def test_get_charge_id_from_pi_latest_charge_object(self):
        pi = SimpleNamespace(latest_charge=SimpleNamespace(id="ch_456"))
        assert helpers.get_charge_id_from_pi(pi) == "ch_456"

    def test_get_charge_id_from_pi_latest_charge_object_without_id(self):
        pi = SimpleNamespace(latest_charge=SimpleNamespace())
        assert helpers.get_charge_id_from_pi(pi) is None

    def test_compare_addresses_same_object_true(self):
        addr = {Fields.STREET: "123 Main", Fields.CITY: "Toronto"}
        assert helpers.compare_addresses(addr, addr) is True

    def test_compare_addresses_none_false(self):
        assert helpers.compare_addresses(None, {Fields.STREET: "123 Main"}) is False

    def test_compare_addresses_mismatch_false(self):
        a1 = {Fields.STREET: "123 Main", Fields.CITY: "Toronto", Fields.STATE: "ON"}
        a2 = {Fields.STREET: "124 Main", Fields.CITY: "Toronto", Fields.STATE: "ON"}
        assert helpers.compare_addresses(a1, a2) is False

    def test_compare_addresses_normalized_true(self):
        a1 = {
            Fields.STREET: " 123 Main St ",
            Fields.CITY: "TORONTO",
            Fields.STATE: "ON",
            Fields.POSTAL_CODE: "M5V 2H1",
            Fields.COUNTRY: "Canada",
            Fields.APARTMENT: None,
            Fields.PHONE_NUMBER: "1234567890",
        }
        a2 = {
            Fields.STREET: "123 main st",
            Fields.CITY: "toronto",
            Fields.STATE: "on",
            Fields.POSTAL_CODE: "m5v 2h1",
            Fields.COUNTRY: "canada",
            Fields.APARTMENT: "",
            Fields.PHONE_NUMBER: "1234567890",
        }
        assert helpers.compare_addresses(a1, a2) is True


class TestGeocodeAddress:
    def test_geocode_address_requires_configured_api_key(self):
        with patch("config.get_geoapify_api_key", return_value=""):
            success, msg, updated = helpers.geocode_address({Fields.STREET: "123 Main"})
        assert success is False
        assert "not configured" in msg
        assert updated[Fields.STREET] == "123 Main"

    def test_geocode_address_rejects_empty_query(self):
        with patch("config.get_geoapify_api_key", return_value="key"):
            success, msg, _updated = helpers.geocode_address({})
        assert success is False
        assert msg == "Address is empty"

    def test_geocode_address_handles_401(self):
        with (
            patch("config.get_geoapify_api_key", return_value="key"),
            patch("requests.get", return_value=_MockResponse(401)),
        ):
            success, msg, _updated = helpers.geocode_address({Fields.STREET: "123 Main", Fields.COUNTRY: "Canada"})
        assert success is False
        assert "authentication failed" in msg

    def test_geocode_address_handles_429(self):
        with (
            patch("config.get_geoapify_api_key", return_value="key"),
            patch("requests.get", return_value=_MockResponse(429)),
        ):
            success, msg, _updated = helpers.geocode_address({Fields.STREET: "123 Main", Fields.COUNTRY: "Canada"})
        assert success is False
        assert "rate limit" in msg

    def test_geocode_address_handles_generic_http_error(self):
        with (
            patch("config.get_geoapify_api_key", return_value="key"),
            patch("requests.get", return_value=_MockResponse(500)),
        ):
            success, msg, _updated = helpers.geocode_address({Fields.STREET: "123 Main", Fields.COUNTRY: "Canada"})
        assert success is False
        assert "HTTP 500" in msg

    def test_geocode_address_handles_no_features(self):
        with (
            patch("config.get_geoapify_api_key", return_value="key"),
            patch("requests.get", return_value=_MockResponse(200, {"features": []})),
        ):
            success, msg, _updated = helpers.geocode_address({Fields.STREET: "123 Main", Fields.CITY: "Toronto", Fields.COUNTRY: "Canada"})
        assert success is False
        assert "No coordinates found" in msg

    def test_geocode_address_success_returns_coordinates(self):
        payload = {
            "features": [
                {
                    "properties": {"rank": {"confidence": 0.99}},
                    "geometry": {"coordinates": [-79.38, 43.65]},
                }
            ]
        }
        with (
            patch("config.get_geoapify_api_key", return_value="key"),
            patch("requests.get", return_value=_MockResponse(200, payload)),
        ):
            success, msg, updated = helpers.geocode_address({Fields.STREET: "123 Main", Fields.CITY: "Toronto", Fields.COUNTRY: "Canada"})
        assert success is True
        assert msg == ""
        assert updated[Fields.LONGITUDE] == -79.38
        assert updated[Fields.LATITUDE] == 43.65

    def test_geocode_address_handles_invalid_coordinate_payload(self):
        payload = {
            "features": [
                {
                    "properties": {"rank": {"confidence": 0.1}},
                    "geometry": {"coordinates": [-79.38]},
                }
            ]
        }
        with (
            patch("config.get_geoapify_api_key", return_value="key"),
            patch("requests.get", return_value=_MockResponse(200, payload)),
        ):
            success, msg, _updated = helpers.geocode_address({Fields.STREET: "123 Main", Fields.CITY: "Toronto", Fields.COUNTRY: "Canada"})
        assert success is False
        assert msg == "Geocoding returned invalid results"

    def test_geocode_address_handles_timeout(self):
        with (
            patch("config.get_geoapify_api_key", return_value="key"),
            patch("requests.get", side_effect=requests.exceptions.Timeout),
        ):
            success, msg, _updated = helpers.geocode_address({Fields.STREET: "123 Main", Fields.CITY: "Toronto", Fields.COUNTRY: "Canada"})
        assert success is False
        assert "timed out" in msg

    def test_geocode_address_handles_unexpected_exception(self):
        with (
            patch("config.get_geoapify_api_key", return_value="key"),
            patch("requests.get", side_effect=RuntimeError("network down")),
            patch.object(helpers.logger, "error") as mock_error,
        ):
            success, msg, _updated = helpers.geocode_address({Fields.STREET: "123 Main", Fields.CITY: "Toronto", Fields.COUNTRY: "Canada"})
        assert success is False
        assert "unexpected error" in msg
        mock_error.assert_called_once()
