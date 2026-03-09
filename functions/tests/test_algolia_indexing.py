"""
Test Algolia indexing functionality
"""

import os
import sys
from pathlib import Path

import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    from algoliasearch.search.client import SearchClient

    from services.algolia_service import configure_algolia_index
except ImportError:
    pass  # Will fail in tests if needed

# Load environment variables
ALGOLIA_APP_ID = os.environ.get("ALGOLIA_APP_ID", "")
ALGOLIA_WRITE_API_KEY = os.environ.get("ALGOLIA_WRITE_API_KEY", "")


def format_product_for_algolia(product_id: str, product_data: dict) -> dict:
    """Format product for Algolia (test version)"""
    algolia_object = {
        "objectID": product_id,
        "name": product_data.get("name", ""),
        "description": product_data.get("description", ""),
        "price": product_data.get("price", 0.0),
        "categoryId": product_data.get("categoryId", 0),
        "sellerId": product_data.get("sellerId", ""),
        "imageUrls": product_data.get("imageUrls", []),
        "stockQuantity": product_data.get("stockQuantity", 0),
        "rating": product_data.get("rating", 0.0),
        "ratingCount": product_data.get("ratingCount", 0),
        "lifecycleStatus": product_data.get("lifecycleStatus", "active"),
        "searchKeywords": product_data.get("searchKeywords", []),
        "sellerAddress": product_data.get("sellerAddress", {}),
        "freeShipping": product_data.get("freeShipping", False),
        "isPerishable": product_data.get("isPerishable", False),
        "isLocalDeliveryOnly": product_data.get("isLocalDeliveryOnly", False),
    }
    return algolia_object


def test_algolia_credentials(capsys):
    """Check if Algolia credentials are configured"""
    if not ALGOLIA_APP_ID or not ALGOLIA_WRITE_API_KEY:
        pytest.skip("ALGOLIA_APP_ID or ALGOLIA_WRITE_API_KEY not configured")

    assert ALGOLIA_APP_ID
    assert ALGOLIA_WRITE_API_KEY
    print(f"✅ Credentials configured: {ALGOLIA_APP_ID}")


def test_format_product(capsys):
    """Test product formatting for Algolia"""
    # Sample product data
    sample_product = {
        "name": "Test Product",
        "description": "A test product for Algolia indexing",
        "price": 29.99,
        "categoryId": 14,
        "sellerId": "seller_123",
        "imageUrls": ["https://example.com/image.jpg"],
        "stockQuantity": 10,
        "rating": 4.5,
        "ratingCount": 42,
        "lifecycleStatus": "active",
        "searchKeywords": ["test", "product", "sample"],
        "sellerAddress": {
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V1A1",
            "country": "Canada",
        },
        "freeShipping": True,
        "isPerishable": False,
        "isLocalDeliveryOnly": False,
    }

    formatted = format_product_for_algolia("test_product_123", sample_product)

    # Verify required fields
    required_fields = [
        "objectID",
        "name",
        "description",
        "price",
        "categoryId",
        "sellerId",
        "imageUrls",
        "stockQuantity",
    ]

    for field in required_fields:
        assert field in formatted, f"Missing required field: {field}"

    if ALGOLIA_APP_ID and ALGOLIA_WRITE_API_KEY:
        # Test that credentials are valid format (new API: direct constructor)
        client = SearchClient(ALGOLIA_APP_ID, ALGOLIA_WRITE_API_KEY)
        assert client is not None
        print("✅ Algolia client created successfully")


def test_algolia_configuration(capsys):
    """Test Algolia index configuration"""
    if not ALGOLIA_APP_ID or not ALGOLIA_WRITE_API_KEY:
        pytest.skip("Skipping - credentials not configured")

    try:
        configure_algolia_index()
        print("✅ Index configuration successful")
    except Exception as e:
        pytest.fail(f"Index configuration failed: {e}")


def test_mock_indexing(capsys):
    """Test indexing logic without actually sending to Algolia"""
    sample_products = [
        {
            "id": "prod_001",
            "data": {
                "name": "Organic Apples",
                "description": "Fresh organic apples from local farm",
                "price": 4.99,
                "categoryId": 14,
                "sellerId": "farmer_01",
                "imageUrls": ["https://example.com/apples.jpg"],
                "stockQuantity": 50,
                "rating": 4.8,
                "ratingCount": 120,
                "lifecycleStatus": "active",
                "searchKeywords": ["apples", "fruit", "organic"],
                "sellerAddress": {"city": "Toronto", "state": "ON", "country": "Canada"},
                "freeShipping": False,
                "isPerishable": True,
                "isLocalDeliveryOnly": True,
            },
        },
        {
            "id": "prod_002",
            "data": {
                "name": "Handmade Soap",
                "description": "Natural handmade soap with essential oils",
                "price": 8.99,
                "categoryId": 19,
                "sellerId": "artisan_02",
                "imageUrls": ["https://example.com/soap.jpg"],
                "stockQuantity": 30,
                "rating": 4.9,
                "ratingCount": 85,
                "lifecycleStatus": "active",
                "searchKeywords": ["soap", "handmade", "natural"],
                "sellerAddress": {"city": "Vancouver", "state": "BC", "country": "Canada"},
                "freeShipping": True,
                "isPerishable": False,
                "isLocalDeliveryOnly": False,
            },
        },
    ]

    formatted_products = []
    for product in sample_products:
        formatted = format_product_for_algolia(product["id"], product["data"])
        formatted_products.append(formatted)

    assert len(formatted_products) == 2
    assert formatted_products[0]["objectID"] == "prod_001"
    print(f"✅ Successfully formatted {len(formatted_products)} products")
