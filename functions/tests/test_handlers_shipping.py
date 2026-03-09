from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn


class TestCalculateShippingCostHandler:
    def test_requires_authentication(self):
        from handlers.shipping import calculate_shipping_cost

        req = Mock()
        req.auth = None
        req.data = {}

        with pytest.raises(https_fn.HttpsError) as exc:
            calculate_shipping_cost(req)
        assert exc.value.code == "unauthenticated"

    def test_requires_items(self):
        from handlers.shipping import calculate_shipping_cost

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {"items": [], "address": {"country": "CA"}}

        with pytest.raises(https_fn.HttpsError) as exc:
            calculate_shipping_cost(req)
        assert exc.value.code == "invalid-argument"
        assert "Items are required" in str(exc.value)

    def test_requires_address(self):
        from handlers.shipping import calculate_shipping_cost

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {"items": [{"productId": "p1"}], "address": {}}

        with pytest.raises(https_fn.HttpsError) as exc:
            calculate_shipping_cost(req)
        assert exc.value.code == "invalid-argument"
        assert "Address is required" in str(exc.value)

    @patch("handlers.shipping._calculate_shipping_cost", return_value=12.5)
    def test_returns_successful_cost_response(self, mock_calc):
        from handlers.shipping import calculate_shipping_cost

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {
            "items": [{"productId": "p1", "quantity": 1}],
            "address": {"country": "CA", "state": "ON"},
            "speed": "express",
        }

        result = calculate_shipping_cost(req)
        assert result == {"success": True, "cost": 12.5}
        mock_calc.assert_called_once_with(req.data["items"], req.data["address"], speed="express")

    @patch("handlers.shipping._calculate_shipping_cost", side_effect=ValueError("bad shipping payload"))
    def test_maps_value_error_to_invalid_argument(self, _mock_calc):
        from handlers.shipping import calculate_shipping_cost

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {
            "items": [{"productId": "p1", "quantity": 1}],
            "address": {"country": "CA"},
        }

        with pytest.raises(https_fn.HttpsError) as exc:
            calculate_shipping_cost(req)
        assert exc.value.code == "invalid-argument"
        assert "bad shipping payload" in str(exc.value)

    @patch("handlers.shipping._calculate_shipping_cost", side_effect=RuntimeError("db timeout"))
    def test_maps_unexpected_error_to_internal(self, _mock_calc):
        from handlers.shipping import calculate_shipping_cost

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {
            "items": [{"productId": "p1", "quantity": 1}],
            "address": {"country": "CA"},
        }

        with pytest.raises(https_fn.HttpsError) as exc:
            calculate_shipping_cost(req)
        assert exc.value.code == "internal"
