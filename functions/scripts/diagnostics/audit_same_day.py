#!/usr/bin/env python3
"""
Audit script for Same Day Delivery logic.
Tests:
1. Multipliers for different distances.
2. Fallback behavior when Geoapify fails.
"""

import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# Add functions directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

from schema_constants import DeliveryTypeValues, Fields
from services import shipping_service


class TestSameDayDelivery(unittest.TestCase):
    """Class TestSameDayDelivery."""
    def setUp(self):
        """Function setUp."""
        self.seller_address = {
            Fields.LATITUDE: 43.6532,  # Toronto
            Fields.LONGITUDE: -79.3832,
            Fields.STATE: "ON",
            Fields.CITY: "Toronto",
        }
        self.buyer_address = {
            Fields.LATITUDE: 43.6532,  # Same location (0 distance)
            Fields.LONGITUDE: -79.3832,
            Fields.STATE: "ON",
            Fields.CITY: "Toronto",
        }
        self.items = [
            {
                Fields.SELLER_ID: "seller_1",
                Fields.SELLER_ADDRESS: self.seller_address,
                Fields.QUANTITY: 1,
                Fields.PRICE: 10.00,
                Fields.WEIGHT_KG: 0.5,
                Fields.DELIVERY_OPTIONS: [
                    {
                        Fields.TYPE: DeliveryTypeValues.SAME_DAY,
                        Fields.COST_CENTS: 0,  # Base cost usually calculated dynamically
                        "isEnabled": True,
                    }
                ],
            }
        ]

    @patch("services.shipping_service.get_geoapify_api_key", return_value="mock_key")
    @patch("services.shipping_service.requests.post")
    def test_same_day_short_distance(self, mock_post):
        """Test Same Day Delivery for short distance (<15km)."""
        # Mock Geoapify response for 5km
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "sources_to_targets": [[{"distance": 5000}]]  # 5000 meters = 5km
        }
        mock_post.return_value = mock_response

        cost = shipping_service.calculate_shipping_cost(
            self.items, self.buyer_address, speed=DeliveryTypeValues.SAME_DAY
        )

        # Base cost for <15km is 1.99
        # Multiplier for hyper_local same_day is 4.5 (from schema_constants.py)
        # Expected: 1.99 * 4.5 = 8.955
        print(f"\n[Short Distance] Cost: {cost}")
        self.assertAlmostEqual(cost, 1.99 * 4.5, delta=0.01)

    @patch("services.shipping_service.get_geoapify_api_key", return_value="mock_key")
    @patch("services.shipping_service.requests.post")
    def test_same_day_long_distance(self, mock_post):
        """Test Same Day Delivery for long distance (>50km) - Should Fail."""
        # Mock Geoapify response for 200km
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "sources_to_targets": [[{"distance": 200000}]]  # 200km
        }
        mock_post.return_value = mock_response

        # Expect ValueError for distance > 50km
        with self.assertRaises(ValueError) as context:
            shipping_service.calculate_shipping_cost(self.items, self.buyer_address, speed=DeliveryTypeValues.SAME_DAY)
        print(f"\n[Long Distance] Caught expected error: {context.exception}")

    @patch("services.shipping_service.get_geoapify_api_key", return_value="mock_key")
    @patch("services.shipping_service.requests.post")
    def test_geoapify_failure_fallback(self, mock_post):
        """Test behavior when Geoapify fails - Should Fail Safely."""
        # Mock Geoapify failure
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_post.return_value = mock_response

        # Expect ValueError instead of fallback
        with self.assertRaises(ValueError) as context:
            shipping_service.calculate_shipping_cost(self.items, self.buyer_address, speed=DeliveryTypeValues.SAME_DAY)

        print(f"\n[Geoapify Failure] Caught expected error: {context.exception}")


if __name__ == "__main__":
    unittest.main()
