
import pytest
from unittest.mock import MagicMock, patch
import sys
from pathlib import Path

# Add functions to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from services.shipping_service import calculate_shipping_cost
from schema_constants import Fields, PaymentStatusValues

def test_calculate_shipping_cost_itemized():
    """Verify calculate_shipping_cost returns total and itemized breakdown."""
    items = [
        {
            "productId": "p1",
            "quantity": 2,
            "sellerId": "s1",
            "sellerAddress": {"state": "ON", "latitude": 43.6, "longitude": -79.3},
        },
        {
            "productId": "p2",
            "quantity": 1,
            "sellerId": "s1",
            "sellerAddress": {"state": "ON", "latitude": 43.6, "longitude": -79.3},
        }
    ]
    buyer = {"state": "ON", "latitude": 43.7, "longitude": -79.4}
    
    # Mock fallback to avoid Geoapify dependency if needed, 
    # but here we are in same province so it uses FALLBACK_SAME_PROVINCE
    with patch("services.shipping_service.get_geoapify_api_key", return_value=""):
        total_cost, breakdown = calculate_shipping_cost(items, buyer)
    
    assert isinstance(total_cost, (int, float))
    assert total_cost > 0
    assert isinstance(breakdown, dict)
    assert "p1" in breakdown
    assert "p2" in breakdown
    
    # Sum of breakdown should equal total_cost (approximately due to float)
    assert abs(sum(breakdown.values()) - total_cost) < 0.01

def test_refund_order_item_uses_stored_shipping():
    """Verify refund_order_item uses itemShippingCents if available."""
    from handlers.orders import refund_order_item
    
    order_id = "order_123"
    item_to_refund = {
        "productId": "p1", 
        "quantity": 2, 
        "price": 10.0,
        "sellerId": "s1",
        Fields.ITEM_SHIPPING_CENTS: 250 # Stored per-item shipping
    }
    
    order_data = {
        "orderId": order_id,
        "stripePaymentIntentId": "pi_123",
        "subtotalCents": 3000,
        "shippingCostCents": 750,
        "taxAmountCents": 300,
        "totalAmountCents": 4050,
        "items": [item_to_refund, {"productId": "p2", "quantity": 1, "price": 10.0, "sellerId": "s1"}],
        "shippingAddress": {"state": "ON"},
        "sellerShippingCosts": {"s1": 750},
        Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
    }
    
    mock_db = MagicMock()
    mock_order_doc = MagicMock()
    mock_order_doc.exists = True
    mock_order_doc.to_dict.return_value = order_data
    mock_user_doc = MagicMock()
    mock_user_doc.exists = True
    mock_user_doc.to_dict.return_value = {Fields.ROLES: ["admin"]}

    def _collection_side_effect(name):
        coll = MagicMock()
        if name == "orders":
            coll.document.return_value.get.return_value = mock_order_doc
        elif name == "users":
            coll.document.return_value.get.return_value = mock_user_doc
        return coll

    mock_db.collection.side_effect = _collection_side_effect
    
    mock_request = MagicMock()
    mock_request.auth.uid = "admin_123"
    mock_request.data = {
        "orderId": order_id,
        "productId": "p1",
        "quantity": 1,
        "reason": "Customer request"
    }
    
    with patch("handlers.orders.get_db", return_value=mock_db), \
         patch("services.rate_limiter.RateLimiter.check_rate_limit", return_value=(True, "OK")), \
         patch("handlers.orders.stripe.Refund.create") as mock_refund, \
         patch("handlers.orders.get_server_timestamp", return_value="now"), \
         patch("handlers.orders.create_success_response") as mock_response, \
         patch("services.shipping_service.get_tax_rate", return_value=0.13):
        
        refund_order_item(mock_request)
        
        # Current refund logic uses full item line (quantity=2):
        # item subtotal 2000 + stored shipping 250 + proportional tax 200 = 2450.
        
        args, kwargs = mock_refund.call_args
        assert kwargs["amount"] == 2450
        
def test_refund_order_item_fallback_proportional():
    """Verify refund_order_item falls back to proportional if itemShippingCents is missing."""
    from handlers.orders import refund_order_item
    
    order_id = "order_123"
    item_to_refund = {
        "productId": "p1", 
        "quantity": 1, 
        "price": 10.0,
        "sellerId": "s1"
        # ITEM_SHIPPING_CENTS is missing (legacy order)
    }
    
    order_data = {
        "orderId": order_id,
        "stripePaymentIntentId": "pi_123",
        "subtotalCents": 2000, # item is 50% of subtotal
        "shippingCostCents": 1000,
        "taxAmountCents": 260,
        "totalAmountCents": 3260,
        "items": [item_to_refund, {"productId": "p2", "quantity": 1, "price": 10.0, "sellerId": "s1"}],
        "shippingAddress": {"state": "ON"},
        "sellerShippingCosts": {"s1": 1000},
        Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
    }
    
    mock_db = MagicMock()
    mock_order_doc = MagicMock()
    mock_order_doc.exists = True
    mock_order_doc.to_dict.return_value = order_data
    mock_user_doc = MagicMock()
    mock_user_doc.exists = True
    mock_user_doc.to_dict.return_value = {Fields.ROLES: ["admin"]}

    def _collection_side_effect(name):
        coll = MagicMock()
        if name == "orders":
            coll.document.return_value.get.return_value = mock_order_doc
        elif name == "users":
            coll.document.return_value.get.return_value = mock_user_doc
        return coll

    mock_db.collection.side_effect = _collection_side_effect
    
    mock_request = MagicMock()
    mock_request.auth.uid = "admin_123"
    mock_request.data = {
        "orderId": order_id,
        "productId": "p1",
        "quantity": 1,
        "reason": "Customer request"
    }
    
    with patch("handlers.orders.get_db", return_value=mock_db), \
         patch("services.rate_limiter.RateLimiter.check_rate_limit", return_value=(True, "OK")), \
         patch("handlers.orders.stripe.Refund.create") as mock_refund, \
         patch("handlers.orders.get_server_timestamp", return_value="now"), \
         patch("handlers.orders.create_success_response") as mock_response, \
         patch("services.shipping_service.get_tax_rate", return_value=0.13):
        
        refund_order_item(mock_request)
        
        # Proportional refund with legacy shipping:
        # item subtotal 1000 + proportional shipping 500 + proportional tax 130 = 1630.
        
        args, kwargs = mock_refund.call_args
        assert kwargs["amount"] == 1630
