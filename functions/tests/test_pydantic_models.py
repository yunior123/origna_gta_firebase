"""
Tests for Pydantic models
Validates schema consistency, validation rules, and serialization
"""

import sys
from datetime import datetime
from pathlib import Path

import pytest
from pydantic import ValidationError

functions_dir = Path(__file__).parent.parent
sys.path.insert(0, str(functions_dir))

from models import (  # noqa: E402
    Address,
    AddressDetails,
    DeliveryStatusEnum,
    Order,
    OrderCreate,
    OrderItem,
    OrderStatusEnum,
    PaymentStatusEnum,
    Product,
    ProductCreate,
    Ratings,
    SellerDeliveryOption,
    SellerPayout,
    Taxes,
    User,
    UserCreate,
    UserRole,
)

# ============================================================================
# ADDRESS TESTS
# ============================================================================


def test_address_valid():
    """Test creating a valid address"""
    address = Address(
        street="123 Main Street",
        apartment="Apt 4B",
        city="Toronto",
        state="ON",
        postalCode="M5V 3A8",
        country="Canada",
        phoneNumber="4165551234",
        isDefault=True,
        label="Home",
        latitude=43.6532,
        longitude=-79.3832,
    )
    assert address.street == "123 Main Street"
    assert address.city == "Toronto"
    assert address.state == "ON"
    assert address.formatted_address().count("\n") == 3


def test_address_postal_code_validation():
    """Test postal code validation"""
    # Valid postal codes
    address1 = Address(
        street="123 Main St",
        city="Toronto",
        state="ON",
        postalCode="M5V 3A8",
        country="Canada",
    )
    assert address1.postalCode == "M5V 3A8"

    address2 = Address(
        street="123 Main St",
        city="Toronto",
        state="ON",
        postalCode="M5V3A8",  # No space
        country="Canada",
    )
    assert " " in address2.postalCode  # Should normalize with space

    # Invalid postal code
    with pytest.raises(ValidationError):
        Address(
            street="123 Main St",
            city="Toronto",
            state="ON",
            postalCode="12345",  # Invalid format
            country="Canada",
        )


def test_address_province_validation():
    """Test province code validation"""
    # Valid province
    address = Address(
        street="123 Main St",
        city="Montreal",
        state="qc",  # Lowercase should be normalized
        postalCode="H3A 1A1",
        country="Canada",
    )
    assert address.state == "QC"  # Should be uppercase

    # Invalid province
    with pytest.raises(ValidationError):
        Address(
            street="123 Main St",
            city="Toronto",
            state="XX",  # Invalid province
            postalCode="M5V 3A8",
            country="Canada",
        )


def test_address_phone_validation():
    """Test phone number validation"""
    # Valid phone
    address = Address(
        street="123 Main St",
        city="Toronto",
        state="ON",
        postalCode="M5V 3A8",
        country="Canada",
        phoneNumber="(416) 555-1234",  # Formatted phone
    )
    assert address.phoneNumber == "4165551234"  # Should be digits only

    # Invalid phone (too short)
    with pytest.raises(ValidationError):
        Address(
            street="123 Main St",
            city="Toronto",
            state="ON",
            postalCode="M5V 3A8",
            country="Canada",
            phoneNumber="12345",  # Too short
        )


# ============================================================================
# PRODUCT TESTS
# ============================================================================


def test_product_valid():
    """Test creating a valid product"""
    address = Address(
        street="123 Farm Road",
        city="Toronto",
        state="ON",
        postalCode="M5V 3A8",
        country="Canada",
    )

    product = Product(
        productId="prod_123",
        name="Organic Apples",
        price=4.99,
        description="Fresh organic apples from local farm",
        imageUrls=["https://example.com/image1.jpg"],
        sellerId="seller_123",
        sellerAddress=address,
        categoryId=1,
        stockQuantity=100,
        rating=4.5,
        createdAt=datetime.now(),
        isActive=True,
    )

    assert product.name == "Organic Apples"
    assert product.price == 4.99
    assert product.categoryId == 1


def test_product_price_validation():
    """Test price validation (must be positive)"""
    address = Address(
        street="123 Farm Road",
        city="Toronto",
        state="ON",
        postalCode="M5V 3A8",
        country="Canada",
    )

    # Invalid: negative price
    with pytest.raises(ValidationError):
        Product(
            productId="prod_123",
            name="Organic Apples",
            price=-4.99,  # Negative price
            description="Fresh organic apples",
            imageUrls=["https://example.com/image1.jpg"],
            sellerId="seller_123",
            sellerAddress=address,
            categoryId=1,
            stockQuantity=100,
            createdAt=datetime.now(),
        )

    # Invalid: zero price
    with pytest.raises(ValidationError):
        Product(
            productId="prod_123",
            name="Organic Apples",
            price=0.0,  # Zero price
            description="Fresh organic apples",
            imageUrls=["https://example.com/image1.jpg"],
            sellerId="seller_123",
            sellerAddress=address,
            categoryId=1,
            stockQuantity=100,
            createdAt=datetime.now(),
        )


def test_product_category_validation():
    """Test category ID validation (1-21)"""
    address = Address(
        street="123 Farm Road",
        city="Toronto",
        state="ON",
        postalCode="M5V 3A8",
        country="Canada",
    )

    # Invalid: category 0
    with pytest.raises(ValidationError):
        Product(
            productId="prod_123",
            name="Organic Apples",
            price=4.99,
            description="Fresh organic apples",
            imageUrls=["https://example.com/image1.jpg"],
            sellerId="seller_123",
            sellerAddress=address,
            categoryId=0,  # Invalid
            stockQuantity=100,
            createdAt=datetime.now(),
        )

    # Invalid: category 22
    with pytest.raises(ValidationError):
        Product(
            productId="prod_123",
            name="Organic Apples",
            price=4.99,
            description="Fresh organic apples",
            imageUrls=["https://example.com/image1.jpg"],
            sellerId="seller_123",
            sellerAddress=address,
            categoryId=22,  # Invalid
            stockQuantity=100,
            createdAt=datetime.now(),
        )


def test_product_image_urls_validation():
    """Test image URLs validation"""
    address = Address(
        street="123 Farm Road",
        city="Toronto",
        state="ON",
        postalCode="M5V 3A8",
        country="Canada",
    )

    # Invalid: invalid URL
    with pytest.raises(ValidationError):
        Product(
            productId="prod_123",
            name="Organic Apples",
            price=4.99,
            description="Fresh organic apples",
            imageUrls=["not-a-url"],  # Invalid URL
            sellerId="seller_123",
            sellerAddress=address,
            categoryId=1,
            stockQuantity=100,
            createdAt=datetime.now(),
        )


# ============================================================================
# TAXES TESTS
# ============================================================================


def test_taxes_total_calculation():
    """Test taxes total calculation"""
    taxes = Taxes(GST=2.5, PST=3.5, HST=0.0, QST=0.0)
    assert taxes.total() == 6.0

    taxes2 = Taxes(GST=0.0, PST=0.0, HST=13.0, QST=0.0)
    assert taxes2.total() == 13.0


def test_taxes_default_values():
    """Test taxes default values are all zero"""
    taxes = Taxes()
    assert taxes.GST == 0.0
    assert taxes.PST == 0.0
    assert taxes.HST == 0.0
    assert taxes.QST == 0.0
    assert taxes.total() == 0.0


# ============================================================================
# ORDER ITEM TESTS
# ============================================================================


def test_order_item_subtotal_calculation():
    """Test order item subtotal calculation"""
    address = Address(
        street="123 Farm Road",
        city="Toronto",
        state="ON",
        postalCode="M5V 3A8",
        country="Canada",
    )

    item = OrderItem(
        productId="prod_123",
        name="Organic Apples",
        description="Fresh organic apples",
        price=4.99,
        quantity=3,
        imageUrls=["https://example.com/image1.jpg"],
        sellerId="seller_123",
        sellerAddress=address,
    )

    assert item.subtotal() == 14.97  # 4.99 * 3


# ============================================================================
# SELLER PAYOUT TESTS
# ============================================================================


def test_seller_payout_status_validation():
    """Test seller payout status validation"""
    # Valid statuses
    payout1 = SellerPayout(
        sellerId="seller_123",
        amountCents=10000,
        platformFeeCents=250,
        netAmountCents=9750,
        status="pending",
    )
    assert payout1.status == "pending"

    payout2 = SellerPayout(
        sellerId="seller_123",
        amountCents=10000,
        platformFeeCents=250,
        netAmountCents=9750,
        status="completed",
    )
    assert payout2.status == "completed"

    # Invalid status
    with pytest.raises(ValidationError):
        SellerPayout(
            sellerId="seller_123",
            amountCents=10000,
            platformFeeCents=250,
            netAmountCents=9750,
            status="invalid_status",  # Invalid
        )


# ============================================================================
# USER TESTS
# ============================================================================


def test_user_valid():
    """Test creating a valid user"""
    user = User(
        uid="user_123",
        email="user@example.com",
        name="John Doe",
        roles=[UserRole.BUYER],
        createdAt=datetime.now(),
    )

    assert user.uid == "user_123"
    assert user.email == "user@example.com"
    assert UserRole.BUYER in user.roles


def test_user_name_validation():
    """Test user name validation (letters, spaces, hyphens, apostrophes, periods)"""
    # Valid names
    valid_names = ["John Doe", "Jean-Pierre", "O'Brien", "Mary Jr.", "María José"]
    for name in valid_names:
        user = User(
            uid="user_123",
            email="user@example.com",
            name=name,
            roles=[UserRole.BUYER],
            createdAt=datetime.now(),
        )
        assert user.name == name

    # Invalid: contains numbers
    with pytest.raises(ValidationError):
        User(
            uid="user_123",
            email="user@example.com",
            name="John123",  # Invalid: contains numbers
            roles=[UserRole.BUYER],
            createdAt=datetime.now(),
        )


def test_user_roles_validation():
    """Test at least one role is required"""
    # Valid: has roles
    user = User(
        uid="user_123",
        email="user@example.com",
        name="John Doe",
        roles=[UserRole.BUYER, UserRole.SELLER],
        createdAt=datetime.now(),
    )
    assert len(user.roles) == 2

    # Invalid: empty roles
    with pytest.raises(ValidationError):
        User(
            uid="user_123",
            email="user@example.com",
            name="John Doe",
            roles=[],  # Empty roles list
            createdAt=datetime.now(),
        )


def test_user_helper_methods():
    """Test user helper methods"""
    # Buyer only
    buyer = User(
        uid="user_123",
        email="buyer@example.com",
        name="Jane Buyer",
        roles=[UserRole.BUYER],
        createdAt=datetime.now(),
    )
    assert not buyer.is_seller()
    assert not buyer.is_admin()
    assert not buyer.can_sell()

    # Seller (not suspended)
    seller_incomplete = User(
        uid="user_123",
        email="seller@example.com",
        name="John Seller",
        roles=[UserRole.SELLER],
        createdAt=datetime.now(),
        suspended=True,
    )
    assert seller_incomplete.is_seller()
    assert not seller_incomplete.can_sell()  # Suspended

    # Seller (active)
    seller_complete = User(
        uid="user_123",
        email="seller@example.com",
        name="John Seller",
        roles=[UserRole.SELLER],
        createdAt=datetime.now(),
    )
    assert seller_complete.is_seller()
    assert seller_complete.can_sell()

    # Admin
    admin = User(
        uid="user_123",
        email="admin@example.com",
        name="Admin User",
        roles=[UserRole.ADMIN, UserRole.BUYER],
        createdAt=datetime.now(),
    )
    assert admin.is_admin()


# ============================================================================
# SERIALIZATION TESTS
# ============================================================================


def test_address_json_serialization():
    """Test Address JSON serialization/deserialization"""
    address = Address(
        street="123 Main Street",
        city="Toronto",
        state="ON",
        postalCode="M5V 3A8",
        country="Canada",
    )

    # Serialize to JSON
    json_data = address.model_dump()
    assert json_data["street"] == "123 Main Street"
    assert json_data["city"] == "Toronto"

    # Deserialize from JSON
    address2 = Address(**json_data)
    assert address2.street == address.street
    assert address2.city == address.city


def test_product_json_serialization():
    """Test Product JSON serialization/deserialization"""
    address = Address(
        street="123 Farm Road",
        city="Toronto",
        state="ON",
        postalCode="M5V 3A8",
        country="Canada",
    )

    product = Product(
        productId="prod_123",
        name="Organic Apples",
        price=4.99,
        description="Fresh organic apples",
        imageUrls=["https://example.com/image1.jpg"],
        sellerId="seller_123",
        sellerAddress=address,
        categoryId=1,
        stockQuantity=100,
        createdAt=datetime.now(),
    )

    # Serialize to JSON
    json_data = product.model_dump()
    assert json_data["name"] == "Organic Apples"
    assert json_data["price"] == 4.99

    # Deserialize from JSON
    product2 = Product(**json_data)
    assert product2.name == product.name
    assert product2.price == product.price


# ============================================================================
# DIGITAL PRODUCT TESTS (Task 3 & 4)
# ============================================================================


def test_product_digital_software_fields():
    """Product model accepts digital software fields"""
    from models.product import Product

    p = Product(
        name="MacBook Cleaner Pro",
        description="Cleans your macOS system thoroughly for better performance",
        price=29.99,
        categoryId=1,
        stockQuantity=9999,
        imageUrls=["https://cdn.example.com/img.jpg"],
        sellerId="seller123",
        isDigital=True,
        digitalType="software",
        slug="macbook-cleaner-pro-a4f2",
        digitalBuilds={"macos": "https://releases.example.com/cleaner.dmg"},
        deviceLimit=3,
    )
    assert p.digitalType == "software"
    assert p.slug == "macbook-cleaner-pro-a4f2"
    assert p.digitalBuilds["macos"] == "https://releases.example.com/cleaner.dmg"
    assert p.deviceLimit == 3


def test_product_digital_book_fields():
    """Product model accepts digital book fields"""
    from models.product import Product

    p = Product(
        name="Python Mastery",
        description="Complete guide to Python programming for developers",
        price=19.99,
        categoryId=1,
        stockQuantity=9999,
        imageUrls=["https://cdn.example.com/book.jpg"],
        sellerId="seller123",
        isDigital=True,
        digitalType="book",
        slug="python-mastery-b3c1",
        bookSourceUrl="https://storage.example.com/python-mastery.pdf",
    )
    assert p.digitalType == "book"
    assert p.bookSourceUrl == "https://storage.example.com/python-mastery.pdf"


def test_product_digital_type_invalid():
    """Invalid digitalType is rejected"""
    import pytest
    from pydantic import ValidationError

    from models.product import Product

    with pytest.raises(ValidationError):
        Product(
            name="Test",
            description="Test description for product validation testing",
            price=9.99,
            categoryId=1,
            stockQuantity=1,
            imageUrls=["https://cdn.example.com/img.jpg"],
            sellerId="seller123",
            isDigital=True,
            digitalType="video",
        )


def test_product_software_requires_https_build_urls():
    """Software build URLs must be https"""
    import pytest
    from pydantic import ValidationError

    from models.product import Product

    with pytest.raises(ValidationError):
        Product(
            name="Test App",
            description="Test description for product validation testing",
            price=9.99,
            categoryId=1,
            stockQuantity=1,
            imageUrls=["https://cdn.example.com/img.jpg"],
            sellerId="seller123",
            isDigital=True,
            digitalType="software",
            digitalBuilds={"macos": "http://insecure.example.com/app.dmg"},
        )


def test_product_software_requires_at_least_one_platform():
    """Software product must have at least one platform URL"""
    import pytest
    from pydantic import ValidationError

    from models.product import Product

    with pytest.raises(ValidationError):
        Product(
            name="Test App",
            description="Test description for product validation testing",
            price=9.99,
            categoryId=1,
            stockQuantity=1,
            imageUrls=["https://cdn.example.com/img.jpg"],
            sellerId="seller123",
            isDigital=True,
            digitalType="software",
            digitalBuilds={},
        )


def test_product_book_requires_https_source_url():
    """Book source URL must be https"""
    import pytest
    from pydantic import ValidationError

    from models.product import Product

    with pytest.raises(ValidationError):
        Product(
            name="Test Book",
            description="Test description for product validation testing",
            price=9.99,
            categoryId=1,
            stockQuantity=1,
            imageUrls=["https://cdn.example.com/img.jpg"],
            sellerId="seller123",
            isDigital=True,
            digitalType="book",
            bookSourceUrl="http://insecure.example.com/book.pdf",
        )


def test_product_book_requires_source_url():
    """Book product must have bookSourceUrl"""
    import pytest
    from pydantic import ValidationError

    from models.product import Product

    with pytest.raises(ValidationError):
        Product(
            name="Test Book",
            description="Test description for product validation testing",
            price=9.99,
            categoryId=1,
            stockQuantity=1,
            imageUrls=["https://cdn.example.com/img.jpg"],
            sellerId="seller123",
            isDigital=True,
            digitalType="book",
        )


def test_product_software_invalid_platform_key():
    """Invalid platform key in digitalBuilds is rejected"""
    import pytest
    from pydantic import ValidationError

    from models.product import Product

    with pytest.raises(ValidationError):
        Product(
            name="Test App",
            description="Test description for product validation testing",
            price=9.99,
            categoryId=1,
            stockQuantity=1,
            imageUrls=["https://cdn.example.com/img.jpg"],
            sellerId="seller123",
            isDigital=True,
            digitalType="software",
            digitalBuilds={"android": "https://example.com/app.apk"},
        )


def test_order_item_digital_fields():
    """OrderItem model accepts digital unlock fields"""
    from models.order import OrderItem

    item = OrderItem(
        productId="prod123",
        name="MacBook Cleaner Pro",
        price=29.99,
        quantity=1,
        imageUrls=["https://cdn.example.com/img.jpg"],
        sellerId="seller123",
        isDigital=True,
        licenseKey="ABCD-EFGH-IJKL-MNOP",
        digitalUnlocked=True,
        digitalType="software",
        digitalBuilds={"macos": "https://example.com/app.dmg"},
    )
    assert item.licenseKey == "ABCD-EFGH-IJKL-MNOP"
    assert item.digitalUnlocked is True
    assert item.digitalType == "software"
    assert item.digitalBuilds["macos"] == "https://example.com/app.dmg"


# ============================================================================
# COMPARE AT PRICE TESTS (TASK 08)
# ============================================================================


_BASE_ADDR = dict(street="123 Test St", city="Toronto", state="ON", postalCode="M5V 3A8", country="Canada")


def test_compare_at_price_must_be_higher_than_price():
    """compareAtPrice <= price must raise ValidationError."""
    from pydantic import ValidationError

    from models.product import Product

    # Equal price → rejected
    with pytest.raises(ValidationError, match="compare"):
        Product(
            name="Test Product",
            description="A valid product description long enough to pass",
            price=29.99,
            compareAtPrice=29.99,  # Equal — not allowed
            categoryId=1,
            stockQuantity=10,
            imageUrls=["https://cdn.example.com/img.jpg"],
            sellerId="seller_123",
        )

    # Lower price → rejected
    with pytest.raises(ValidationError, match="compare"):
        Product(
            name="Test Product",
            description="A valid product description long enough to pass",
            price=29.99,
            compareAtPrice=19.99,  # Lower than price — not allowed
            categoryId=1,
            stockQuantity=10,
            imageUrls=["https://cdn.example.com/img.jpg"],
            sellerId="seller_123",
        )


def test_compare_at_price_null_is_allowed():
    """compareAtPrice = None (no sale) must be valid."""
    from models.product import Product

    product = Product(
        name="Regular Product",
        description="A valid product description long enough to pass",
        price=29.99,
        compareAtPrice=None,  # No sale — allowed
        categoryId=1,
        stockQuantity=10,
        imageUrls=["https://cdn.example.com/img.jpg"],
        sellerId="seller_123",
    )
    assert product.compareAtPrice is None


def test_compare_at_price_higher_is_allowed():
    """compareAtPrice > price must be valid and stored correctly."""
    from models.product import Product

    product = Product(
        name="Sale Product",
        description="A valid product description long enough to pass",
        price=29.99,
        compareAtPrice=49.99,  # Higher than price — allowed
        categoryId=1,
        stockQuantity=10,
        imageUrls=["https://cdn.example.com/img.jpg"],
        sellerId="seller_123",
    )
    assert product.compareAtPrice == 49.99
    assert product.price == 29.99


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
