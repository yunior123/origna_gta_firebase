"""
Integration tests for backend API endpoints with Pydantic models
Tests validate that utils.py and main.py work correctly with new models
"""

import pytest
from pydantic import ValidationError

from models.base import Address
from models.order import OrderItem, Taxes
from models.product import Product
from models.user import User
from utils.helpers import validate_address_map, validate_item, validate_order_data


def test_validate_address_map_valid():
    """Test that validate_address_map returns Address object for valid input"""
    address_dict = {
        "street": "123 Main St",
        "city": "Toronto",
        "state": "ON",
        "postalCode": "M5V3A8",
        "country": "Canada",
        "phoneNumber": "4161234567",
    }

    result = validate_address_map(address_dict)

    assert isinstance(result, Address)
    assert result.street == "123 Main St"
    assert result.city == "Toronto"
    assert result.state == "ON"
    assert result.postalCode == "M5V 3A8"  # Normalized with space
    assert result.phoneNumber == "4161234567"


def test_validate_address_map_invalid_postal_code():
    """Test that validate_address_map raises ValueError for invalid postal code"""
    address_dict = {
        "street": "123 Main St",
        "city": "Toronto",
        "state": "ON",
        "postalCode": "INVALID",
        "country": "Canada",
    }

    with pytest.raises(ValueError) as exc_info:
        validate_address_map(address_dict)

    # Check that error mentions postal code (case-insensitive)
    error_msg = str(exc_info.value).lower()
    assert "postal" in error_msg or "postalcode" in error_msg


def test_validate_address_map_invalid_province():
    """Test that validate_address_map raises ValueError for invalid province"""
    address_dict = {
        "street": "123 Main St",
        "city": "Toronto",
        "state": "XX",  # Invalid province
        "postalCode": "M5V3A8",
        "country": "Canada",
    }

    with pytest.raises(ValueError) as exc_info:
        validate_address_map(address_dict)

    assert "state" in str(exc_info.value).lower() or "province" in str(exc_info.value).lower()


def test_validate_item_valid():
    """Test that validate_item returns success for valid OrderItem"""
    item_dict = {
        "productId": "prod123",
        "name": "Test Product",
        "description": "A great product",
        "price": 29.99,
        "quantity": 2,
        "sellerId": "seller123",
        "imageUrls": ["https://example.com/image.jpg"],
        "categoryId": 5,
        "sellerAddress": {
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V3A8",
            "country": "Canada",
        },
    }

    is_valid, error_msg = validate_item(item_dict)

    assert is_valid is True
    assert error_msg == ""


def test_validate_item_invalid_quantity():
    """Test that validate_item fails for quantity > 100"""
    item_dict = {
        "productId": "prod123",
        "name": "Test Product",
        "description": "A great product",
        "price": 29.99,
        "quantity": 150,  # Exceeds max
        "sellerId": "seller123",
        "imageUrls": ["https://example.com/image.jpg"],
        "categoryId": 5,
        "sellerAddress": {
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V3A8",
            "country": "Canada",
        },
    }

    is_valid, error_msg = validate_item(item_dict)

    assert is_valid is False
    assert "100" in error_msg or "maximum" in error_msg.lower()


def test_validate_item_missing_required_field():
    """Test that validate_item fails for missing required field (sellerId)"""
    item_dict = {
        "productId": "prod123",
        "name": "Test Product",
        "description": "A great product",
        "price": 29.99,
        "quantity": 2,
        # Missing sellerId (required field)
        "imageUrls": ["https://example.com/image.jpg"],
        "categoryId": 5,
        "sellerAddress": {
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V3A8",
            "country": "Canada",
        },
    }

    is_valid, error_msg = validate_item(item_dict)

    assert is_valid is False
    assert "sellerid" in error_msg.lower() or "seller" in error_msg.lower()


def test_validate_order_data_valid():
    """Test that validate_order_data succeeds for valid order"""
    order_dict = {
        "userId": "user123",
        "customerEmail": "test@example.com",
        "totalAmountCents": 10050,
        "items": [
            {
                "productId": "prod123",
                "name": "Test Product",
                "description": "A great product",
                "price": 29.99,
                "quantity": 2,
                "sellerId": "seller123",
                "imageUrls": ["https://example.com/image.jpg"],
                "categoryId": 5,
                "sellerAddress": {
                    "street": "456 Seller St",
                    "city": "Toronto",
                    "state": "ON",
                    "postalCode": "M4B1B3",
                    "country": "Canada",
                },
            }
        ],
        "shippingAddress": {
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V3A8",
            "country": "Canada",
        },
    }

    is_valid, error_msg = validate_order_data(order_dict)

    assert is_valid is True
    assert error_msg is None


def test_validate_order_data_invalid_email():
    """Test that validate_order_data fails for invalid email"""
    order_dict = {
        "userId": "user123",
        "customerEmail": "invalid-email",
        "totalAmountCents": 10050,
        "items": [
            {
                "productId": "prod123",
                "name": "Test Product",
                "description": "A great product",
                "price": 29.99,
                "quantity": 2,
                "sellerId": "seller123",
                "imageUrls": ["https://example.com/image.jpg"],
                "categoryId": 5,
                "sellerAddress": {
                    "street": "456 Seller St",
                    "city": "Toronto",
                    "state": "ON",
                    "postalCode": "M4B1B3",
                    "country": "Canada",
                },
            }
        ],
        "shippingAddress": {
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V3A8",
            "country": "Canada",
        },
    }

    is_valid, error_msg = validate_order_data(order_dict)

    assert is_valid is False
    assert "email" in error_msg.lower()


def test_validate_order_data_missing_field():
    """Test that validate_order_data fails for missing required field"""
    order_dict = {
        "userId": "user123",
        "customerEmail": "test@example.com",
        # Missing totalAmountCents
        "items": [
            {
                "productId": "prod123",
                "name": "Test Product",
                "description": "A great product",
                "price": 29.99,
                "quantity": 2,
                "sellerId": "seller123",
                "imageUrls": ["https://example.com/image.jpg"],
                "categoryId": 5,
                "sellerAddress": {
                    "street": "456 Seller St",
                    "city": "Toronto",
                    "state": "ON",
                    "postalCode": "M4B1B3",
                    "country": "Canada",
                },
            }
        ],
        "shippingAddress": {
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V3A8",
            "country": "Canada",
        },
    }

    is_valid, error_msg = validate_order_data(order_dict)

    assert is_valid is False
    assert "amount" in error_msg.lower()


def test_taxes_model_integration():
    """Test that Taxes model works correctly with real data"""
    taxes = Taxes(GST=5.0, PST=7.0, HST=0.0, QST=0.0)

    # Test total calculation
    assert taxes.total() == 12.0

    # Test JSON serialization
    taxes_dict = taxes.model_dump()
    assert taxes_dict["GST"] == 5.0
    assert taxes_dict["PST"] == 7.0

    # Test JSON deserialization
    taxes_restored = Taxes(**taxes_dict)
    assert taxes_restored.total() == 12.0


def test_order_item_model_integration():
    """Test that OrderItem model works correctly with real data"""
    item = OrderItem(
        productId="prod123",
        name="Test Product",
        description="A great product",
        price=29.99,
        quantity=3,
        sellerId="seller123",
        imageUrls=["https://example.com/image.jpg"],
        categoryId=5,
        sellerAddress=Address(
            street="123 Seller St", city="Toronto", state="ON", postalCode="M5V 3A8", country="Canada"
        ),
    )

    # Test subtotal calculation
    assert item.subtotal() == 89.97

    # Test JSON serialization
    item_dict = item.model_dump()
    assert item_dict["productId"] == "prod123"
    assert item_dict["quantity"] == 3


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
