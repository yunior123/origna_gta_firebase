import pytest

from models.product import (
    Product,
    ProductCreate,
    ProductUpdate,
    ProductVariant,
    SellerDeliveryOption,
    SellerWarehouse,
    ShippingQuantityDiscount,
    SupplierInfo,
    VariantOption,
)
from schema_constants import (
    BusinessRules,
    CategoryIds,
    DeliveryTypeValues,
    DiscountTypeValues,
    ProductConditionValues,
    ProductLifecycleStatusValues,
)


VALID_ADDRESS = {
    "street": "123 Main St",
    "city": "Toronto",
    "state": "ON",
    "postalCode": "M5V2H1",
    "country": "Canada",
}


def _base_product():
    return {
        "name": "Valid Product Name",
        "price": 10.00,
        "description": "A valid description for this product.",
        "imageUrls": ["https://example.com/a.jpg"],
        "sellerId": "seller_1",
        "sellerAddress": VALID_ADDRESS,
        "categoryId": min(CategoryIds.ALL),
        "stockQuantity": 5,
    }


def _base_product_create():
    return {
        "name": "Valid Product Name",
        "price": 10.00,
        "description": "A valid description for this product.",
        "imageUrls": ["https://example.com/a.jpg"],
        "sellerId": "seller_1",
        "sellerAddress": VALID_ADDRESS,
        "categoryId": min(CategoryIds.ALL),
        "stockQuantity": 5,
        "lifecycleStatus": ProductLifecycleStatusValues.DRAFT,
    }


class TestProductModelDeepValidators:
    def test_direct_validators_cover_supplier_url_none_and_invalid_category(self):
        # Covers explicit `None` return path in supplier URL validator
        assert SupplierInfo.validate_supplier_url(None) is None

        # Covers explicit category allowlist validator branch
        with pytest.raises(ValueError, match="Invalid categoryId"):
            Product.validate_category_id(9999)

    def test_shipping_quantity_discount_and_delivery_option_valid_paths(self):
        discount = ShippingQuantityDiscount(
            minQuantity=2,
            discountType=DiscountTypeValues.PERCENT,
            discountValue=10,
        )
        assert discount.discountValue == 10

        option = SellerDeliveryOption(type=DeliveryTypeValues.STANDARD, costCents=500, estimatedDays=3)
        assert option.type == DeliveryTypeValues.STANDARD

    def test_shipping_quantity_discount_rejects_invalid_type(self):
        with pytest.raises(ValueError, match="Invalid discount type"):
            ShippingQuantityDiscount(minQuantity=2, discountType="invalid", discountValue=1)

    def test_shipping_quantity_discount_percent_cannot_exceed_100(self):
        with pytest.raises(ValueError, match="cannot exceed 100"):
            ShippingQuantityDiscount(minQuantity=2, discountType=DiscountTypeValues.PERCENT, discountValue=150)

    def test_seller_delivery_option_rejects_invalid_type(self):
        with pytest.raises(ValueError, match="Invalid delivery type"):
            SellerDeliveryOption(type="invalid", costCents=100, estimatedDays=3)

    def test_supplier_info_validates_type_currency_url_and_notes(self):
        with pytest.raises(ValueError, match="Invalid supplier type"):
            SupplierInfo(type="bad", currency="USD")

        with pytest.raises(ValueError, match="Invalid currency"):
            SupplierInfo(type="aliexpress", currency="xyz")

        info = SupplierInfo(type="aliexpress", currency="usd")
        assert info.currency == "USD"

        with pytest.raises(ValueError, match="must start with https://"):
            SupplierInfo(type="aliexpress", supplierUrl="http://bad.example", currency="USD")

        with pytest.raises(ValueError, match="disallowed content"):
            SupplierInfo(type="aliexpress", supplierUrl="https://example.com/javascript:alert(1)", currency="USD")

        with pytest.raises(ValueError, match="must not contain HTML tags"):
            SupplierInfo(type="aliexpress", notes="<b>x</b>", currency="USD")

        valid_url = SupplierInfo(type="aliexpress", supplierUrl="https://example.com/item", currency="USD")
        assert valid_url.supplierUrl == "https://example.com/item"

        blank_url = SupplierInfo(type="aliexpress", supplierUrl="   ", currency="USD")
        assert blank_url.supplierUrl is None

        valid_notes = SupplierInfo(type="aliexpress", notes="safe internal note", currency="USD")
        assert valid_notes.notes == "safe internal note"

        none_notes = SupplierInfo(type="aliexpress", notes=None, currency="USD")
        assert none_notes.notes is None

        with pytest.raises(ValueError, match="Supplier notes contain disallowed content"):
            SupplierInfo(type="aliexpress", notes="javascript:alert(1)", currency="USD")

    def test_seller_warehouse_type_validation(self):
        with pytest.raises(ValueError, match="type must be one of"):
            SellerWarehouse(label="A", type="bad", address=VALID_ADDRESS)

        ok = SellerWarehouse(label="A", type="warehouse", address=VALID_ADDRESS)
        assert ok.type == "warehouse"

    def test_product_variant_auto_id_and_price_property(self):
        variant = ProductVariant(variantId="", optionValues={"Size": "M"}, stockQuantity=2, priceCents=999)
        assert variant.variantId
        assert variant.price_dollars == 9.99

        no_price = ProductVariant(variantId="", optionValues={"Size": "S"}, stockQuantity=1, priceCents=None)
        assert no_price.price_dollars is None

    def test_product_field_validators_and_compare_at_price_rules(self):
        data = _base_product()
        with pytest.raises(ValueError, match="Invalid lifecycleStatus"):
            Product(**{**data, "lifecycleStatus": "bad"})

        with pytest.raises(ValueError):
            Product(**{**data, "categoryId": 9999})

        with pytest.raises(ValueError, match="Invalid condition"):
            Product(**{**data, "condition": "broken"})

        with pytest.raises(ValueError, match="Name contains disallowed characters"):
            Product(**{**data, "name": "<script>"})

        with pytest.raises(ValueError, match="disallowed content"):
            Product(**{**data, "name": "javascript:alert(1)"})

        with pytest.raises(ValueError, match="Invalid image URL"):
            Product(**{**data, "imageUrls": ["ftp://bad"]})

        with pytest.raises(ValueError, match="Video URL must originate from"):
            Product(**{**data, "videoUrl": "https://evil.example/video.mp4"})

        ok_video = Product(**{**data, "videoUrl": f"{BusinessRules.CDN_BASE_URL}/videos/clip.mp4"})
        assert ok_video.videoUrl.endswith("clip.mp4")

        with pytest.raises(ValueError, match="Description contains disallowed content"):
            Product(**{**data, "description": "javascript:alert(1) safe text"})

        with pytest.raises(ValueError, match="digitalType must be 'software' or 'book'"):
            Product(**{**data, "digitalType": "music"})

        with pytest.raises(ValueError, match="Invalid platform"):
            Product(**{**data, "digitalBuilds": {"android": "https://example.com/app"}})

        with pytest.raises(ValueError, match="must start with https://"):
            Product(**{**data, "bookSourceUrl": "http://book.pdf"})

        with pytest.raises(ValueError, match="must be greater than price"):
            Product(**{**data, "compareAtPrice": 10.0})

        with pytest.raises(ValueError, match="at least \\$0.50 above price"):
            Product(**{**data, "compareAtPrice": 10.20})

    def test_product_digital_consistency_rules(self):
        data = _base_product()
        with pytest.raises(ValueError, match="digitalType must be 'software' or 'book'"):
            Product(**{**data, "isDigital": True, "digitalType": None})

        with pytest.raises(ValueError, match="digitalBuilds must have at least one"):
            Product(**{**data, "isDigital": True, "digitalType": "software"})

        with pytest.raises(ValueError, match="bookSourceUrl is required"):
            Product(**{**data, "isDigital": True, "digitalType": "book"})


class TestProductCreateAndUpdateDeepValidators:
    def test_product_create_and_update_before_validators_accept_non_dict_inputs(self):
        assert ProductCreate.convert_units_to_metric([]) == []
        assert ProductUpdate.convert_units_to_metric_update([]) == []

    def test_product_create_converts_units_to_metric(self):
        model = ProductCreate(
            **{
                **_base_product_create(),
                "weightKg": 10,
                "weightUnit": "lb",
                "lengthCm": 10,
                "widthCm": 20,
                "heightCm": 30,
                "dimensionUnit": "in",
            }
        )
        assert model.weightKg == pytest.approx(4.536, rel=1e-3)
        assert model.weightUnit == "kg"
        assert model.lengthCm == pytest.approx(25.4)
        assert model.widthCm == pytest.approx(50.8)
        assert model.heightCm == pytest.approx(76.2)
        assert model.dimensionUnit == "cm"

    def test_product_create_requires_shipping_source_for_physical(self):
        data = _base_product_create()
        data.pop("sellerAddress")
        with pytest.raises(ValueError, match="either a sellerAddress or at least one warehouseId"):
            ProductCreate(**data)

    def test_product_create_validates_seller_address_country_presence(self):
        data = _base_product_create()
        data["sellerAddress"] = {**VALID_ADDRESS, "country": " "}
        with pytest.raises(ValueError, match="Seller address must include a country"):
            ProductCreate(**data)

    def test_product_create_validates_content_and_lifecycle(self):
        data = _base_product_create()
        with pytest.raises(ValueError, match="Name contains disallowed characters"):
            ProductCreate(**{**data, "name": "<bad>"})

        with pytest.raises(ValueError, match="Name contains disallowed content"):
            ProductCreate(**{**data, "name": "javascript:alert(1)"})

        with pytest.raises(ValueError, match="Invalid image URL"):
            ProductCreate(**{**data, "imageUrls": ["ftp://bad"]})

        with pytest.raises(ValueError, match="Description contains disallowed HTML content"):
            ProductCreate(**{**data, "description": "<b>bad html</b>"})

        with pytest.raises(ValueError, match="Description contains disallowed content"):
            ProductCreate(**{**data, "description": "javascript:alert(1) valid len"})

        with pytest.raises(ValueError, match="must be 'draft'"):
            ProductCreate(**{**data, "lifecycleStatus": ProductLifecycleStatusValues.ACTIVE})

        with pytest.raises(ValueError, match="Invalid condition"):
            ProductCreate(**{**data, "condition": "bad"})

        assert ProductCreate(**{**data, "condition": ProductConditionValues.NEW}).condition == ProductConditionValues.NEW

        with pytest.raises(ValueError, match="digitalType must be 'software' or 'book'"):
            ProductCreate(**{**data, "digitalType": "music"})

        with pytest.raises(ValueError, match="bookSourceUrl must start with https://"):
            ProductCreate(**{**data, "bookSourceUrl": "http://book.pdf"})

        assert ProductCreate(**{**data, "bookSourceUrl": "https://example.com/book.pdf"}).bookSourceUrl.endswith("book.pdf")

    def test_product_create_validates_variant_sku_uniqueness(self):
        data = _base_product_create()
        data["variants"] = [
            ProductVariant(variantId="", optionValues={"Size": "M"}, stockQuantity=1, sku="SKU-1"),
            ProductVariant(variantId="", optionValues={"Size": "L"}, stockQuantity=1, sku="SKU-1"),
        ]
        with pytest.raises(ValueError, match="variant SKU must be unique"):
            ProductCreate(**data)

    def test_product_create_validates_digital_consistency(self):
        data = _base_product_create()
        with pytest.raises(ValueError, match="digitalType must be 'software' or 'book'"):
            ProductCreate(**{**data, "isDigital": True, "digitalType": None})

        with pytest.raises(ValueError, match="digitalBuilds must have at least one"):
            ProductCreate(**{**data, "isDigital": True, "digitalType": "software"})

        with pytest.raises(ValueError, match="bookSourceUrl is required"):
            ProductCreate(**{**data, "isDigital": True, "digitalType": "book"})

    def test_product_update_converts_units_to_metric(self):
        model = ProductUpdate(
            weightKg=10,
            weightUnit="lb",
            lengthCm=10,
            widthCm=20,
            heightCm=30,
            dimensionUnit="in",
        )
        assert model.weightKg == pytest.approx(4.536, rel=1e-3)
        assert model.weightUnit == "kg"
        assert model.lengthCm == pytest.approx(25.4)
        assert model.widthCm == pytest.approx(50.8)
        assert model.heightCm == pytest.approx(76.2)
        assert model.dimensionUnit == "cm"

    def test_product_update_name_validator(self):
        assert ProductUpdate(name=None).name is None
        with pytest.raises(ValueError, match="Name contains disallowed characters"):
            ProductUpdate(name="<bad>")

        with pytest.raises(ValueError, match="Name contains disallowed content"):
            ProductUpdate(name="javascript:alert(1)")

        assert ProductUpdate(name="Valid Name").name == "Valid Name"
