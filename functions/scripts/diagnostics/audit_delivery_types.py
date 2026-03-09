#!/usr/bin/env python3
"""
Audit script for Express and Standard Delivery logic.
Tests:
1. Express delivery cost and distance behavior.
2. Standard delivery fallback behavior.
"""

import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# Add functions directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

from schema_constants import DeliveryTypeValues, Fields, ShippingTiers
from services import shipping_service


class TestDeliveryTypes(unittest.TestCase):
    """Class TestDeliveryTypes."""
    def setUp(self):
        """Function setUp."""
        self.seller_address = {
            Fields.LATITUDE: 43.6532,
            Fields.LONGITUDE: -79.3832,
            Fields.STATE: "ON",
            Fields.CITY: "Toronto",
        }
        self.buyer_address = {
            Fields.LATITUDE: 43.6532,
            Fields.LONGITUDE: -79.3832,
            Fields.STATE: "ON",
            Fields.CITY: "Toronto",
        }
        self.items = [
            {
                Fields.SELLER_ID: "seller_1",
                Fields.SELLER_ADDRESS: self.seller_address,
                Fields.QUANTITY: 1,
                Fields.PRICE: 20.00,
                Fields.WEIGHT_KG: 1.0,
                Fields.DELIVERY_OPTIONS: [],
            }
        ]

    @patch("services.shipping_service.get_geoapify_api_key", return_value="mock_key")
    @patch("services.shipping_service.requests.post")
    def test_express_delivery_pricing(self, mock_post):
        """Test Express Delivery pricing for regional distance."""
        # Mock 100km distance
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"sources_to_targets": [[{"distance": 100000}]]}
        mock_post.return_value = mock_response

        cost = shipping_service.calculate_shipping_cost(
            self.items, self.buyer_address, speed=DeliveryTypeValues.EXPRESS
        )

        # Base cost checks:
        # Distance > 50km -> Base cost 9.99 (ShippingTiers.TIERS)
        # Express Multiplier for 50-150km (regional) -> 1.5 (ShippingTiers.EXPRESS_MULTIPLIERS["regional"])
        # Expected: 9.99 * 1.5 = 14.985
        print(f"\n[Express Regional] Cost: {cost}")
        self.assertAlmostEqual(cost, 9.99 * 1.5, delta=0.01)

    @patch("services.shipping_service.get_geoapify_api_key", return_value="mock_key")
    @patch("services.shipping_service.requests.post")
    def test_express_delivery_fallback(self, mock_post):
        """Test Express Delivery fallback when API fails."""
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_post.return_value = mock_response

        cost = shipping_service.calculate_shipping_cost(
            self.items, self.buyer_address, speed=DeliveryTypeValues.EXPRESS
        )

        # New behavior: Falls back to standard * 1.5 (Regional Multiplier)
        # Standard fallback (Same Province) = 12.99
        # Expected: 12.99 * 1.5 = 19.485
        print(f"\n[Express Fallback] Cost: {cost}")
        self.assertAlmostEqual(cost, 12.99 * 1.5, delta=0.01)

    def test_standard_delivery_calculation(self):
        """Test Standard Delivery calculation (Province based)."""
        # Standard delivery usually skips Geoapify if coordinates present but speed is standard?
        # Actually logic says: `should_call_geoapify = speed in [EXPRESS, SAME_DAY] or has_perishable`
        # So Standard skips Geoapify and uses fallback logic directly.

        cost = shipping_service.calculate_shipping_cost(
            self.items, self.buyer_address, speed=DeliveryTypeValues.STANDARD
        )

        print(f"\n[Standard Delivery] Cost: {cost}")
        self.assertEqual(cost, ShippingTiers.FALLBACK_SAME_PROVINCE)


if __name__ == "__main__":
    unittest.main()
