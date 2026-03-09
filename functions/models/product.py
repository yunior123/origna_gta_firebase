"""
Product models for OrignaGTA
"""

import re
import uuid
from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from schema_constants import (
    CategoryIds,
    DeliveryTypeValues,
    DiscountTypeValues,
    Fields,
    ProductConditionValues,
    ProductLifecycleStatusValues,
    SupplierCurrencyValues,
    SupplierTypeValues,
    WarehouseTypeValues,
)

from .base import Address

# ============================================================================
# SHIPPING QUANTITY DISCOUNT - Volume-based shipping discounts
# ============================================================================


class ShippingQuantityDiscount(BaseModel):
    """Volume-based shipping discount thresholds"""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "minQuantity": 5,
                "discountType": "percent",
                "discountValue": 10.0,
                Fields.LABEL: "10% off shipping for 5+ items",
            }
        }
    )

    minQuantity: int = Field(..., ge=2, description="Minimum quantity to qualify for this discount")
    discountType: str = Field(
        default=DiscountTypeValues.PERCENT, description="Discount type: percent, fixed, flat_rate"
    )
    discountValue: float = Field(..., ge=0, description="Discount value (interpretation depends on discountType)")
    label: str | None = Field(default=None, max_length=100, description="Optional label for display")

    @field_validator("discountType")
    @classmethod
    def validate_discount_type(cls, v: str) -> str:
        """Function validate_discount_type."""
        if v not in DiscountTypeValues.ALL:
            raise ValueError(f"Invalid discount type: {v}. Must be one of: {DiscountTypeValues.ALL}")
        return v

    @model_validator(mode="after")
    def validate_discount_value_range(self) -> "ShippingQuantityDiscount":
        """Ensure percent discounts don't exceed 100%"""
        if self.discountType == DiscountTypeValues.PERCENT and self.discountValue > 100:
            raise ValueError("Percent discount cannot exceed 100%")
        return self


class SellerDeliveryOption(BaseModel):
    """Seller-specific delivery options with quantity-based pricing"""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                Fields.TYPE: "standard",
                Fields.DESCRIPTION: "Standard shipping",
                "costCents": 599,
                "estimatedDays": 5,
                "quantityDiscounts": [],
                "maxItemsPerShipment": 10,
                "additionalItemCostCents": 150,
                "availableNationwide": True,
            }
        }
    )

    type: str = Field(..., description="Delivery type: pickup, standard, express, same_day")
    description: str = Field(default="", max_length=200, description="Description of delivery option")
    costCents: int = Field(..., ge=0, description="Base shipping cost in cents (CAD)")
    estimatedDays: int = Field(..., ge=0, le=90, description="Estimated delivery days")
    quantityDiscounts: list[ShippingQuantityDiscount] = Field(
        default_factory=list, description="Quantity-based shipping discounts"
    )
    maxItemsPerShipment: int = Field(default=0, ge=0, description="Max items before cost increases (0 = no limit)")
    additionalItemCostCents: int = Field(
        default=0, ge=0, description="Additional cost per item after maxItemsPerShipment, in cents"
    )
    availableNationwide: bool = Field(
        default=True, description="Whether this delivery option ships anywhere in Canada (vs local-only)"
    )

    @field_validator("type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        """Validate delivery type"""
        if v not in DeliveryTypeValues.ALL:
            raise ValueError(f"Invalid delivery type: {v}. Must be one of: {DeliveryTypeValues.ALL}")
        return v


# ============================================================================
# SUPPLIER INFO - For dropshipping/marketplace products
# NOTE: The 'currency' field is for SUPPLIER COST tracking only.
#       All SELLING prices on the platform are in CAD (Canadian Dollars).
# ============================================================================


class SupplierInfo(BaseModel):
    """
    Supplier information for dropshipping/international products.
    IMPORTANT: The currency field is for tracking what you PAY the supplier.
    All selling prices to customers are in CAD only.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                Fields.TYPE: "aliexpress",
                "supplierSku": "ABC123456",
                "supplierUrl": "https://aliexpress.com/item/123.html",
                "cost": 15.99,
                Fields.CURRENCY: "USD",  # What you pay supplier (selling price is always CAD)
                "shippingDays": "15-30",
                "hasTracking": True,
                "notes": "Good quality supplier",
            }
        }
    )

    type: str = Field(
        ..., description="Supplier platform: aliexpress, alibaba, 1688, dhgate, temu, amazon_usa, custom, etc."
    )
    supplierSku: str | None = Field(default=None, max_length=100, description="Supplier's product SKU")
    supplierUrl: str | None = Field(default=None, max_length=500, description="Direct URL to supplier product")
    cost: float | None = Field(default=None, ge=0, le=100000, description="Cost price from supplier (what seller pays)")
    currency: str = Field(
        default=SupplierCurrencyValues.DEFAULT,
        description="Currency of SUPPLIER cost (for tracking). Selling price is always CAD.",
    )
    shippingDays: str | None = Field(
        default=None, max_length=20, description="Estimated shipping days range (e.g., '7-15')"
    )
    hasTracking: bool = Field(default=False, description="Whether supplier provides tracking")
    notes: str | None = Field(default=None, max_length=500, description="Internal notes about supplier")

    @field_validator("type")
    @classmethod
    def validate_supplier_type(cls, v: str) -> str:
        """Validate supplier type against allowed values."""
        if v not in SupplierTypeValues.ALL:
            raise ValueError(f"Invalid supplier type: {v}. Must be one of: {SupplierTypeValues.ALL}")
        return v

    @field_validator("currency")
    @classmethod
    def validate_supplier_currency(cls, v: str) -> str:
        """Validate supplier cost currency (these are for cost tracking, not selling)"""
        if v.upper() not in SupplierCurrencyValues.ALL:
            raise ValueError(f"Invalid currency: {v}. Must be one of: {SupplierCurrencyValues.ALL}")
        return v.upper()

    @field_validator("supplierUrl")
    @classmethod
    def validate_supplier_url(cls, v: str | None) -> str | None:
        """SECURITY: supplierUrl must be https:// to prevent javascript: / data: URI injection.
        This field is internal (not shown to buyers) but may be rendered as a link in admin
        panels — an unvalidated URL allows XSS or SSRF via crafted schemes."""
        if v is None:
            return v
        v = v.strip()
        if not v:
            return None
        if not v.startswith("https://"):
            raise ValueError("supplierUrl must start with https://")
        # Block common dangerous schemes that could slip past naive checks
        v_lower = v.lower()
        dangerous = ["javascript:", "data:", "vbscript:", "file://", "\\x", "%00"]
        for pat in dangerous:
            if pat in v_lower:
                raise ValueError(f"supplierUrl contains disallowed content: {pat}")
        return v

    @field_validator("notes")
    @classmethod
    def validate_supplier_notes(cls, v: str | None) -> str | None:
        """SECURITY: strip HTML/script injection from internal notes.
        notes is shown in admin panels — inject here → stored XSS."""
        if v is None:
            return v
        dangerous_patterns = ["<script", "javascript:", "data:text/html", "vbscript:", "expression("]
        v_lower = v.lower()
        for pattern in dangerous_patterns:
            if pattern in v_lower:
                raise ValueError("Supplier notes contain disallowed content")
        if re.search(r"<[a-zA-Z/!]", v):
            raise ValueError("Supplier notes must not contain HTML tags")
        return v


# ============================================================================
# INVENTORY CONFIG - For flexible inventory management
# ============================================================================


class InventoryConfig(BaseModel):
    """Inventory management configuration"""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "managed": True,
                "trackQuantity": True,
                "allowBackorder": False,
                "lowStockThreshold": 5,
                "reservationHoldMinutes": 30,
            }
        }
    )

    managed: bool = Field(default=True, description="Whether inventory is actively managed")
    trackQuantity: bool = Field(default=True, description="Track stock quantity (false = unlimited)")
    allowBackorder: bool = Field(default=False, description="Allow orders when out of stock")
    lowStockThreshold: int = Field(default=5, ge=0, le=1000, description="Alert threshold for low stock")
    lastLowStockAlertAt: datetime | None = Field(default=None, description="When the last low-stock alert was sent")
    reservationHoldMinutes: int = Field(
        default=30, ge=5, le=120, description="How long to hold inventory during checkout"
    )


class SellerWarehouse(BaseModel):
    """Seller shipping location — can be a warehouse facility or a personal/home address."""

    warehouseId: str = Field(default="", max_length=100, description="Unique ID (assigned by Firestore)")
    label: str = Field(..., min_length=1, max_length=100, description="Display name, e.g. 'Toronto Warehouse'")
    type: str = Field(default=WarehouseTypeValues.WAREHOUSE, description="'warehouse' or 'personal'")
    address: Address = Field(..., description="Physical location of this warehouse")
    isDefault: bool = Field(default=False, description="Primary shipping origin for this seller")
    createdAt: datetime | None = Field(default=None)

    @field_validator("type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        """Function validate_type."""
        if v not in WarehouseTypeValues.ALL:
            raise ValueError(f"type must be one of: {WarehouseTypeValues.ALL}")
        return v


class VariantOption(BaseModel):
    """Option for a product variant (e.g., Size, Color)"""

    name: str = Field(..., min_length=1, max_length=50, description="Option name (e.g., 'Size')")
    values: list[str] = Field(..., min_length=1, max_length=50, description="Available values (e.g., ['S', 'M', 'L'])")


class ProductVariant(BaseModel):
    """Specific variant combination for a product"""

    variantId: str = Field(default="", max_length=100, description="Unique variant identifier (auto-generated by backend if empty)")
    optionValues: dict[str, str] = Field(..., description="Selected options: { 'Size': 'M', 'Color': 'Red' }")
    priceCents: int | None = Field(default=None, ge=0, description="Override price for this variant in integer cents")
    stockQuantity: int = Field(..., ge=0, description="Available stock for this variant")
    sku: str | None = Field(default=None, max_length=100, description="Variant SKU")
    isActive: bool = Field(default=True, description="Whether variant is active")

    @field_validator("variantId", mode="after")
    @classmethod
    def auto_assign_variant_id(cls, v: str) -> str:
        """Auto-generate a UUID variantId when Flutter sends an empty string (new variants)."""
        return v if v else str(uuid.uuid4())

    @property
    def price_dollars(self) -> float | None:
        """Price in dollars for display/computation."""
        return self.priceCents / 100.0 if self.priceCents is not None else None


class Product(BaseModel):
    """
    Complete product model
    Single source of truth for product data
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                Fields.PRODUCT_ID: "prod_123abc",
                Fields.NAME: "Organic Apples",
                Fields.PRICE: 4.99,
                Fields.DESCRIPTION: "Fresh organic apples from local farm",
                Fields.IMAGE_URLS: ["https://example.com/image1.jpg"],
                Fields.SELLER_ID: "seller_123",
                Fields.SELLER_ADDRESS: {
                    Fields.STREET: "123 Farm Road",
                    Fields.CITY: "Toronto",
                    Fields.STATE: "ON",
                    Fields.POSTAL_CODE: "M5V 3A8",
                    Fields.COUNTRY: "Canada",
                },
                Fields.CATEGORY_ID: 1,
                Fields.STOCK_QUANTITY: 100,
                Fields.RATING: 4.5,
                Fields.CREATED_AT: "2026-02-01T10:00:00Z",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            }
        }
    )

    productId: str = Field(
        default="", max_length=100, description="Unique product identifier (assigned by Firestore on create)"
    )
    name: str = Field(..., min_length=1, max_length=120, description="Product name")
    nameF: str | None = Field(default=None, max_length=200, description="French product name (Quebec Bill 96 compliance)")
    price: float = Field(..., gt=0, le=100000, description="Price in CAD")
    priceCents: int | None = Field(default=None, ge=0, description="Price in integer cents — derived from price at write time")
    compareAtPrice: float | None = Field(
        default=None, gt=0, le=100000, description="Original/crossed-out price for sale display (must be > price)"
    )
    description: str = Field(..., min_length=10, max_length=4000, description="Product description")
    descriptionF: str | None = Field(default=None, max_length=5000, description="French product description")
    imageUrls: list[str] = Field(..., min_length=1, max_length=5, description="Product image URLs (1-5 images)")
    videoUrl: str | None = Field(default=None, description="Product video URL")
    videoDurationSeconds: int | None = Field(default=None, ge=1, le=60, description="Product video duration in seconds (PROD-L2)")
    sellerId: str = Field(..., min_length=1, description="Seller user ID")
    madeInCountry: str | None = Field(default=None, max_length=100, description="F-277: Country of manufacture (for USMCA/Duty info)")
    sellerAddress: Address | None = Field(default=None, description="Seller's address for shipping calculations")
    categoryId: int = Field(..., ge=CategoryIds.MIN, le=CategoryIds.MAX, description="Product category ID")
    stockQuantity: int = Field(..., ge=0, description="Available stock quantity")
    rating: float = Field(default=0.0, ge=0, le=5, description="Average product rating (0-5)")
    ratingCount: int = Field(default=0, ge=0, description="Number of ratings")
    createdAt: datetime = Field(default_factory=lambda: datetime.now(UTC), description="Product creation timestamp")

    # Single lifecycle state replacing isActive + status + approvalStatus
    lifecycleStatus: str = Field(
        default=ProductLifecycleStatusValues.DRAFT,
        description="Single lifecycle state: draft|under_review|approved|active|paused|archived|rejected",
    )

    # Optional shipping metadata
    weightKg: float | None = Field(default=None, gt=0, le=1000, description="Product weight in kilograms")
    weightUnit: str = Field(default="kg", description="F-280: Original weight unit: 'kg' or 'lb'")
    lengthCm: float | None = Field(default=None, gt=0, le=1000, description="Package length in centimeters")
    widthCm: float | None = Field(default=None, gt=0, le=1000, description="Package width in centimeters")
    heightCm: float | None = Field(default=None, gt=0, le=1000, description="Package height in centimeters")
    dimensionUnit: str = Field(default="cm", description="F-280: Original dimension unit: 'cm' or 'in'")

    # Delivery options
    isLocalDeliveryOnly: bool = Field(default=False, description="Only available for local delivery")
    isPerishable: bool = Field(default=False, description="Product is perishable (affects shipping)")
    estimatedShipDays: int = Field(default=3, ge=0, le=90, description="Estimated days to ship")
    deliveryOptions: list[SellerDeliveryOption] = Field(
        default_factory=list, description="Seller-specific delivery options"
    )
    minimumOrderQuantity: int = Field(default=1, ge=1, le=100, description="Minimum order quantity")
    freeShipping: bool = Field(default=False, description="Free shipping offered by seller")

    # Digital product flag
    isDigital: bool = Field(default=False, description="Whether this is a digital product (no shipping required)")

    # Digital product extended fields
    digitalType: str | None = Field(
        default=None,
        description="Type of digital product: 'software' or 'book'",
    )
    slug: str | None = Field(
        default=None,
        max_length=80,
        description="URL-safe unique slug for sharing (e.g., macbook-cleaner-a4f2)",
    )
    digitalBuilds: dict[str, str] | None = Field(
        default=None,
        description="Platform -> external download URL map (software only)",
    )
    bookSourceUrl: str | None = Field(
        default=None,
        max_length=2048,
        description="External PDF/EPUB download URL (book only, NEVER sent to client)",
    )
    deviceLimit: int | None = Field(
        default=None,
        ge=1,
        description="Max activations allowed (software only, null = unlimited)",
    )

    # Tax and metadata
    taxCode: str | None = Field(default=None, description="Tax code override for specific products")
    keywords: list[str] = Field(default_factory=list, description="Search keywords for Algolia")

    # Multi-warehouse support
    sellerSku: str | None = Field(
        default=None,
        max_length=100,
        description="Seller's unique product identifier — enforced unique per seller at write time",
    )
    warehouseIds: list[str] | None = Field(default=None, description="IDs of seller warehouses this product ships from")
    warehouseStockMap: dict[str, int] | None = Field(
        default=None, description="Per-warehouse stock allocation: {warehouseId: qty}. Sum equals stockQuantity."
    )
    # Denormalized for O(1) card rendering — set from default/primary warehouse on write
    shipFromCity: str | None = Field(
        default=None, max_length=100, description="City of primary shipping warehouse (denormalized)"
    )
    shipFromProvince: str | None = Field(
        default=None, max_length=10, description="Province code of primary warehouse (denormalized)"
    )
    shipFromCountry: str | None = Field(
        default=None, max_length=100, description="Country of primary warehouse (denormalized)"
    )
    shipFromCountries: list[str] | None = Field(
        default=None, description="All unique countries across warehouses (denormalized for card display)"
    )

    # Admin approval — rejection reason preserved for seller feedback
    approvalRejectionReason: str | None = Field(
        default=None,
        max_length=1000,
        description="Admin rejection reason (only set when lifecycleStatus=rejected)",
    )

    # NEW: Structured objects for scalability
    supplier: SupplierInfo | None = Field(
        default=None, description="Supplier information for dropshipping/marketplace products"
    )
    inventory: InventoryConfig | None = Field(default=None, description="Inventory management configuration")

    # === TRENDING & ENGAGEMENT ===
    trendingScore: int = Field(
        default=0, ge=0, description="Computed trending score (views + purchases×3 + favorites×2)"
    )
    viewCount: int = Field(default=0, ge=0, description="Total product page views")
    purchaseCount: int = Field(default=0, ge=0, description="Total number of purchases")
    isTrending: bool = Field(default=False, description="Whether product is currently in trending list")
    trendingAt: datetime | None = Field(default=None, description="When product last entered trending")

    # === N-09: Product Variants ===
    hasVariants: bool = Field(default=False, description="Whether this product has variants (size, color, etc.)")
    variants: list[ProductVariant] = Field(default_factory=list, description="List of variant objects")
    variantOptions: list[VariantOption] = Field(default_factory=list, description="Variant option definitions")

    # === N-11: Subcategories ===
    subcategory: str | None = Field(
        default=None, max_length=100, description="Optional subcategory within the main category"
    )
    condition: str | None = Field(default=None, description="Product condition: new|like_new|good|fair|for_parts")

    @model_validator(mode="after")
    def derive_price_cents(self) -> "Product":
        """Auto-derive priceCents from price if not explicitly set."""
        if self.price is not None and self.priceCents is None:
            object.__setattr__(self, "priceCents", round(self.price * 100))
        return self

    @field_validator("lifecycleStatus")
    @classmethod
    def validate_lifecycle_status(cls, v: str) -> str:
        """Function validate_lifecycle_status."""
        if v not in ProductLifecycleStatusValues.ALL:
            raise ValueError(f"Invalid lifecycleStatus: {v}. Must be one of: {ProductLifecycleStatusValues.ALL}")
        return v

    @field_validator("categoryId")
    @classmethod
    def validate_category_id(cls, v: int) -> int:
        """Function validate_category_id."""
        if v not in CategoryIds.ALL:
            raise ValueError(f"Invalid categoryId: {v}. Must be one of: {CategoryIds.ALL}")
        return v

    @field_validator("condition")
    @classmethod
    def validate_condition(cls, v: str | None) -> str | None:
        """Function validate_condition."""
        if v is not None and v not in ProductConditionValues.ALL:
            raise ValueError(f"Invalid condition: {v}. Must be one of: {ProductConditionValues.ALL}")
        return v

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        """Reject HTML/script injection in product names"""
        if re.search(r"[<>]", v):
            raise ValueError("Name contains disallowed characters")
        dangerous_patterns = ["javascript:", "data:text/html", "vbscript:", "expression("]
        v_lower = v.lower()
        for pattern in dangerous_patterns:
            if pattern in v_lower:
                raise ValueError("Name contains disallowed content")
        return v

    @field_validator("imageUrls")
    @classmethod
    def validate_image_urls(cls, v: list[str]) -> list[str]:
        """Validate image URLs"""
        for url in v:
            if not url.startswith(("http://", "https://")):
                raise ValueError(f"Invalid image URL: {url}")
        return v

    @field_validator("videoUrl")
    @classmethod
    def validate_video_url(cls, v: str | None) -> str | None:
        """Validate video URL origin"""
        if v is None:
            return v
        from schema_constants import BusinessRules
        if not v.startswith(BusinessRules.CDN_BASE_URL + "/"):
             raise ValueError(f"Video URL must originate from {BusinessRules.CDN_BASE_URL}")
        return v

    @field_validator("description")
    @classmethod
    def validate_description(cls, v: str) -> str:
        """Function validate_description."""
        dangerous_patterns = ["javascript:", "data:text/html", "vbscript:", "expression("]
        v_lower = v.lower()
        for pattern in dangerous_patterns:
            if pattern in v_lower:
                raise ValueError("Description contains disallowed content")
        return v

    @field_validator("digitalType")
    @classmethod
    def validate_digital_type(cls, v: str | None) -> str | None:
        """Function validate_digital_type."""
        if v is not None and v not in ["software", "book"]:
            raise ValueError(f"digitalType must be 'software' or 'book', got '{v}'")
        return v

    @field_validator("digitalBuilds")
    @classmethod
    def validate_digital_builds(cls, v: dict[str, str] | None) -> dict[str, str] | None:
        """Function validate_digital_builds."""
        if v is None:
            return v
        valid_platforms = {"macos", "windows", "linux"}
        for platform, url in v.items():
            if platform not in valid_platforms:
                raise ValueError(f"Invalid platform '{platform}'. Must be one of: {valid_platforms}")
            if not url.startswith("https://"):
                raise ValueError(f"Build URL for '{platform}' must start with https://")
        return v

    @field_validator("bookSourceUrl")
    @classmethod
    def validate_book_source_url(cls, v: str | None) -> str | None:
        """Function validate_book_source_url."""
        if v is not None and not v.startswith("https://"):
            raise ValueError("bookSourceUrl must start with https://")
        return v

    @model_validator(mode="after")
    def validate_compare_at_price(self) -> "Product":
        """Ensure compareAtPrice is at least $0.50 above price (must represent a real discount)."""
        if self.compareAtPrice is not None:
            if self.compareAtPrice <= self.price:
                raise ValueError(
                    "compareAtPrice must be greater than price (it represents the original, higher price before discount)"
                )
            if (self.compareAtPrice - self.price) < 0.50:
                raise ValueError(
                    "compareAtPrice must be at least $0.50 above price to show a meaningful discount"
                )
        return self

    @model_validator(mode="after")
    def validate_digital_consistency(self) -> "Product":
        """Ensure digital product sub-fields are consistent."""
        if self.isDigital:
            if self.digitalType not in ["software", "book"]:
                raise ValueError("digitalType must be 'software' or 'book' when isDigital=True")
            if self.digitalType == "software":
                if not self.digitalBuilds:
                    raise ValueError("digitalBuilds must have at least one platform URL for software products")
            elif self.digitalType == "book" and not self.bookSourceUrl:
                raise ValueError("bookSourceUrl is required for book products")
        return self


class ProductCreate(BaseModel):
    """
    Model for creating new products
    (excludes productId and createdAt which are generated)
    Sellers can be from any country — no country restriction on seller addresses
    """

    name: str = Field(..., min_length=1, max_length=120)
    nameF: str | None = Field(default=None, max_length=200)
    price: float = Field(..., gt=0.99, le=100000)
    compareAtPrice: float | None = Field(
        default=None, gt=0, le=100000, description="Original/crossed-out price (must be > price when set)"
    )
    description: str = Field(..., min_length=10, max_length=4000)
    descriptionF: str | None = Field(default=None, max_length=5000)
    imageUrls: list[str] = Field(..., min_length=1, max_length=5)
    videoUrl: str | None = Field(default=None)
    videoDurationSeconds: int | None = Field(default=None, ge=1, le=60)
    sellerId: str = Field(..., min_length=1)
    madeInCountry: str | None = Field(default=None, max_length=100)
    sellerAddress: Address | None = Field(
        default=None, description="Seller address; required if warehouseIds is not provided"
    )
    categoryId: int = Field(..., ge=CategoryIds.MIN, le=CategoryIds.MAX)
    stockQuantity: int = Field(..., ge=0)
    rating: float = Field(default=0.0, ge=0, le=5)
    lifecycleStatus: str = Field(default=ProductLifecycleStatusValues.DRAFT)
    weightKg: float | None = Field(default=None, gt=0, le=1000)
    weightUnit: str = Field(default="kg", description="Original weight unit: 'kg' or 'lb'")
    lengthCm: float | None = Field(default=None, gt=0, le=1000)
    widthCm: float | None = Field(default=None, gt=0, le=1000)
    heightCm: float | None = Field(default=None, gt=0, le=1000)
    dimensionUnit: str = Field(default="cm", description="Original dimension unit: 'cm' or 'in'")

    @model_validator(mode="before")
    @classmethod
    def convert_units_to_metric(cls, data: dict) -> dict:
        """F-280: Automatically convert imperial units to metric before validation."""
        if not isinstance(data, dict):
            return data

        # Weight conversion: lb -> kg
        weight = data.get("weightKg")
        unit_w = data.get("weightUnit", "kg").lower()
        if weight is not None and unit_w == "lb":
            data["weightKg"] = round(float(weight) * 0.453592, 3)
            data["weightUnit"] = "kg"  # Normalize to kg after conversion

        # Dimension conversion: in -> cm
        unit_d = data.get("dimensionUnit", "cm").lower()
        if unit_d == "in":
            for field in ["lengthCm", "widthCm", "heightCm"]:
                val = data.get(field)
                if val is not None:
                    data[field] = round(float(val) * 2.54, 2)
            data["dimensionUnit"] = "cm"  # Normalize to cm after conversion

        return data
    isLocalDeliveryOnly: bool = Field(default=False)
    isPerishable: bool = Field(default=False)
    estimatedShipDays: int = Field(default=3, ge=0, le=90)
    deliveryOptions: list[SellerDeliveryOption] = Field(default_factory=list)
    minimumOrderQuantity: int = Field(default=1, ge=1, le=100)
    freeShipping: bool = Field(default=False)
    isDigital: bool = Field(default=False)
    taxCode: str | None = None
    keywords: list[str] = Field(default_factory=list)
    # Multi-warehouse support
    sellerSku: str | None = Field(default=None, max_length=100)
    warehouseIds: list[str] | None = Field(default=None)
    warehouseStockMap: dict[str, int] | None = Field(default=None)
    shipFromCity: str | None = Field(default=None, max_length=100)
    shipFromProvince: str | None = Field(default=None, max_length=10)
    shipFromCountry: str | None = Field(default=None, max_length=100)
    shipFromCountries: list[str] | None = Field(default=None)
    # === N-09: Product Variants ===
    hasVariants: bool = Field(default=False)
    variants: list[ProductVariant] = Field(default_factory=list)
    variantOptions: list[VariantOption] = Field(default_factory=list)
    # === N-11: Subcategories ===
    subcategory: str | None = Field(default=None, max_length=100)
    # NEW: Structured objects
    supplier: SupplierInfo | None = Field(default=None)
    inventory: InventoryConfig | None = Field(default=None)

    # === Digital product fields ===
    condition: str | None = Field(default=None, description="Product condition: new|like_new|good|fair|for_parts")
    digitalType: str | None = Field(default=None, description="'software' or 'book' for digital products")
    digitalBuilds: dict[str, str] | None = Field(default=None, description="Platform→download URL map for software")
    bookSourceUrl: str | None = Field(default=None, description="R2 URL for book file (PDF/EPUB)")
    deviceLimit: int | None = Field(default=None, ge=1, le=100, description="Max concurrent device licenses")

    @model_validator(mode="after")
    def validate_shipping_source(self) -> "ProductCreate":
        """
        Validate that shipping source is provided.
        Individual sellers provide sellerAddress.
        Warehouse sellers provide warehouseIds.
        Denormalization may populate both in the final DB document.
        """
        if not self.isDigital:
            has_addr = bool(self.sellerAddress)
            has_wh = bool(self.warehouseIds)
            if not has_addr and not has_wh:
                raise ValueError("A product must have either a sellerAddress or at least one warehouseId")
        return self

    @field_validator("sellerAddress")
    @classmethod
    def validate_seller_address(cls, v: Address | None) -> Address | None:
        """Validate seller address has a non-empty country (sellers can be from any country)"""
        if v is not None and (not v.country or not v.country.strip()):
            raise ValueError("Seller address must include a country")
        return v

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        """Reject HTML/script injection in product names"""
        if re.search(r"[<>]", v):
            raise ValueError("Name contains disallowed characters")
        dangerous_patterns = ["javascript:", "data:text/html", "vbscript:", "expression("]
        v_lower = v.lower()
        for pattern in dangerous_patterns:
            if pattern in v_lower:
                raise ValueError("Name contains disallowed content")
        return v

    @field_validator("imageUrls")
    @classmethod
    def validate_image_urls(cls, v: list[str]) -> list[str]:
        """Validate image URLs"""
        for url in v:
            if not url.startswith(("http://", "https://")):
                raise ValueError(f"Invalid image URL: {url}")
        return v

    @field_validator("description")
    @classmethod
    def validate_description(cls, v: str) -> str:
        """Validate description doesn't contain disallowed HTML/script content"""
        if re.search(r"<[^>]*>", v):
            raise ValueError("Description contains disallowed HTML content")
        dangerous_patterns = ["javascript:", "data:text/html", "vbscript:", "expression("]
        v_lower = v.lower()
        for pattern in dangerous_patterns:
            if pattern in v_lower:
                raise ValueError("Description contains disallowed content")
        return v

    @field_validator("lifecycleStatus")
    @classmethod
    def validate_lifecycle_status_create(cls, v: str) -> str:
        # Sellers can only create in 'draft'. The handler overwrites to 'under_review',
        # but we enforce this at the model layer too (defense-in-depth against model misuse).
        """Function validate_lifecycle_status_create."""
        if v != ProductLifecycleStatusValues.DRAFT:
            raise ValueError(
                f"lifecycleStatus must be '{ProductLifecycleStatusValues.DRAFT}' when creating a product; "
                f"got '{v}'. Status transitions are managed by the backend."
            )
        return v

    @field_validator("condition")
    @classmethod
    def validate_condition_create(cls, v: str | None) -> str | None:
        """Function validate_condition_create."""
        if v is not None and v not in ProductConditionValues.ALL:
            raise ValueError(f"Invalid condition: {v}. Must be one of: {ProductConditionValues.ALL}")
        return v

    @field_validator("digitalType")
    @classmethod
    def validate_digital_type_create(cls, v: str | None) -> str | None:
        """Function validate_digital_type_create."""
        if v is not None and v not in ("software", "book"):
            raise ValueError(f"digitalType must be 'software' or 'book', got '{v}'")
        return v

    @field_validator("bookSourceUrl")
    @classmethod
    def validate_book_source_url_create(cls, v: str | None) -> str | None:
        """Function validate_book_source_url_create."""
        if v is not None and not v.startswith("https://"):
            raise ValueError("bookSourceUrl must start with https://")
        return v

    @model_validator(mode="after")
    def validate_variant_sku_uniqueness(self) -> "ProductCreate":
        """Variant SKUs must be unique within a product when set."""
        skus = [v.sku for v in self.variants if v.sku]
        if len(skus) != len(set(skus)):
            raise ValueError("Each variant SKU must be unique within the product")
        return self

    @model_validator(mode="after")
    def validate_digital_consistency_create(self) -> "ProductCreate":
        """Validate digital product fields are consistent."""
        if self.isDigital:
            if not self.digitalType or self.digitalType not in ("software", "book"):
                raise ValueError("digitalType must be 'software' or 'book' when isDigital=True")
            if self.digitalType == "software" and not self.digitalBuilds:
                raise ValueError("digitalBuilds must have at least one platform URL for software products")
            elif self.digitalType == "book" and not self.bookSourceUrl:
                raise ValueError("bookSourceUrl is required for book products")
        return self


class ProductUpdate(BaseModel):
    """
    Model for updating existing products (partial update).
    Ensures sellers can't bypass validation via direct Firestore writes.
    """
    name: str | None = Field(default=None, min_length=1, max_length=120)
    nameF: str | None = Field(default=None, max_length=200)
    price: float | None = Field(default=None, gt=0.99, le=100000)
    compareAtPrice: float | None = Field(default=None, gt=0, le=100000)
    description: str | None = Field(default=None, min_length=10, max_length=4000)
    descriptionF: str | None = Field(default=None, max_length=5000)
    imageUrls: list[str] | None = Field(default=None, max_length=5)
    videoUrl: str | None = Field(default=None)
    videoDurationSeconds: int | None = Field(default=None, ge=1, le=60)
    sellerAddress: Address | None = Field(default=None)
    madeInCountry: str | None = Field(default=None, max_length=100)
    categoryId: int | None = Field(default=None, ge=CategoryIds.MIN, le=CategoryIds.MAX)
    subcategory: str | None = Field(default=None, max_length=100)
    stockQuantity: int | None = Field(default=None, ge=0)
    lifecycleStatus: str | None = Field(default=None)
    weightKg: float | None = Field(default=None, gt=0, le=1000)
    weightUnit: str | None = Field(default=None)
    lengthCm: float | None = Field(default=None, gt=0, le=1000)
    widthCm: float | None = Field(default=None, gt=0, le=1000)
    heightCm: float | None = Field(default=None, gt=0, le=1000)
    dimensionUnit: str | None = Field(default=None)

    @model_validator(mode="before")
    @classmethod
    def convert_units_to_metric_update(cls, data: dict) -> dict:
        """F-280: Automatically convert imperial units to metric before validation."""
        if not isinstance(data, dict):
            return data

        # Weight conversion: lb -> kg
        weight = data.get("weightKg")
        unit_w = data.get("weightUnit")
        if weight is not None and unit_w == "lb":
            data["weightKg"] = round(float(weight) * 0.453592, 3)
            data["weightUnit"] = "kg"

        # Dimension conversion: in -> cm
        unit_d = data.get("dimensionUnit")
        if unit_d == "in":
            for field in ["lengthCm", "widthCm", "heightCm"]:
                val = data.get(field)
                if val is not None:
                    data[field] = round(float(val) * 2.54, 2)
            data["dimensionUnit"] = "cm"

        return data
    isLocalDeliveryOnly: bool | None = Field(default=None)
    isPerishable: bool | None = Field(default=None)
    estimatedShipDays: int | None = Field(default=None, ge=0, le=90)
    deliveryOptions: list[SellerDeliveryOption] | None = Field(default=None)
    minimumOrderQuantity: int | None = Field(default=None, ge=1, le=100)
    freeShipping: bool | None = Field(default=None)
    isDigital: bool | None = Field(default=None)
    taxCode: str | None = None
    keywords: list[str] | None = Field(default_factory=list)
    # Multi-warehouse support
    sellerSku: str | None = Field(default=None, max_length=100)
    warehouseIds: list[str] | None = Field(default=None)
    warehouseStockMap: dict[str, int] | None = Field(default=None)
    shipFromCity: str | None = Field(default=None, max_length=100)
    shipFromProvince: str | None = Field(default=None, max_length=10)
    shipFromCountry: str | None = Field(default=None, max_length=100)
    shipFromCountries: list[str] | None = Field(default=None)
    hasVariants: bool | None = Field(default=None)
    variants: list[ProductVariant] | None = Field(default=None)
    variantOptions: list[VariantOption] | None = Field(default=None)
    subcategory: str | None = Field(default=None, max_length=100)
    inventory: InventoryConfig | None = Field(default=None)
    # Digital product fields
    condition: str | None = Field(default=None)
    digitalType: str | None = Field(default=None)
    digitalBuilds: dict[str, str] | None = Field(default=None)
    bookSourceUrl: str | None = Field(default=None)
    deviceLimit: int | None = Field(default=None, ge=1, le=100)

    @field_validator("name")
    @classmethod
    def validate_name_update(cls, v: str | None) -> str | None:
        """Function validate_name_update."""
        if v is None:
            return v
        import re
        if re.search(r"[<>]", v):
            raise ValueError("Name contains disallowed characters")
        dangerous_patterns = ["javascript:", "data:text/html", "vbscript:", "expression("]
        v_lower = v.lower()
        for pattern in dangerous_patterns:
            if pattern in v_lower:
                raise ValueError("Name contains disallowed content")
        return v
