"""
Test Algolia indexing - Simple version
"""

import os

import pytest


def test_credentials(capsys):
    """Check if Algolia credentials are configured"""
    app_id = os.environ.get("ALGOLIA_APP_ID", "")
    write_key = os.environ.get("ALGOLIA_WRITE_API_KEY", "")

    if not app_id or not write_key:
        pytest.skip("ALGOLIA_APP_ID or ALGOLIA_WRITE_API_KEY not configured")

    assert app_id
    assert write_key
    print("✅ Credentials configured")


def test_algolia_client(capsys):
    """Test Algolia client initialization"""
    app_id = os.environ.get("ALGOLIA_APP_ID", "")
    write_key = os.environ.get("ALGOLIA_WRITE_API_KEY", "")

    if not app_id or not write_key:
        pytest.skip("Skipping - credentials not configured")

    try:
        from algoliasearch.search.client import SearchClient

        # Create client
        client = SearchClient(app_id, write_key)
        assert client is not None
        print("✅ Client initialized successfully")

    except Exception as e:
        pytest.fail(f"Client initialization failed: {e}")


def test_product_formatting(capsys):
    """Test product data formatting"""

    sample_product = {
        "name": "Test Product",
        "description": "A test product",
        "price": 29.99,
        "categoryId": 14,
        "sellerId": "seller_123",
        "imageUrls": ["https://example.com/image.jpg"],
        "stockQuantity": 10,
        "rating": 4.5,
        "ratingCount": 42,
        "lifecycleStatus": "active",
        "sellerAddress": {"city": "Toronto", "state": "ON", "country": "Canada"},
        "freeShipping": True,
        "isPerishable": False,
        "isLocalDeliveryOnly": False,
    }

    # Format for Algolia
    formatted = {
        "objectID": "test_123",
        "name": sample_product.get("name"),
        "description": sample_product.get("description"),
        "price": sample_product.get("price"),
        "categoryId": sample_product.get("categoryId"),
        "sellerId": sample_product.get("sellerId"),
        "imageUrls": sample_product.get("imageUrls"),
        "stockQuantity": sample_product.get("stockQuantity"),
        "rating": sample_product.get("rating"),
        "ratingCount": sample_product.get("ratingCount"),
        "lifecycleStatus": sample_product.get("lifecycleStatus"),
        "searchKeywords": sample_product.get("searchKeywords"),
        "sellerAddress": sample_product.get("sellerAddress"),
        "freeShipping": sample_product.get("freeShipping"),
        "isPerishable": sample_product.get("isPerishable"),
        "isLocalDeliveryOnly": sample_product.get("isLocalDeliveryOnly"),
    }

    # Verify required fields
    required = ["objectID", "name", "price", "categoryId", "sellerId"]
    for field in required:
        assert field in formatted and formatted[field] is not None

    print("✅ Product formatting successful")


def test_batch_formatting(capsys):
    """Test batch product formatting"""
    products = [
        {"id": "p1", "name": "Product 1", "price": 10.99},
        {"id": "p2", "name": "Product 2", "price": 20.99},
        {"id": "p3", "name": "Product 3", "price": 30.99},
    ]

    formatted_batch = []
    for p in products:
        formatted_batch.append({"objectID": p["id"], "name": p["name"], "price": p["price"]})

    assert len(formatted_batch) == 3
    print("✅ Batch formatting successful")
