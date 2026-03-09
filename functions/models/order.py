"""
Order models for OrignaGTA
Includes OrderItem, Taxes, Ratings, SellerPayout, and Order
"""

import re
from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from schema_constants import (
    BusinessRules,
    CarrierValues,
    DeliveryStatusValues,
    Fields,
    PayoutStatusValues,
    ValidationLimits,
)

from .base import Address, OrderStatusEnum, PaymentStatusEnum, ShippingApprovalStatusEnum
from .product import SellerDeliveryOption


class OrderItem(BaseModel):
    """Individual item in an order — immutable snapshot at time of purchase."""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                Fields.PRODUCT_ID: "prod_123",
                Fields.NAME: "Organic Apples",
                Fields.DESCRIPTION: "Fresh organic apples",
                Fields.PRICE: 4.99,
                Fields.QUANTITY: 2,
                Fields.IMAGE_URLS: ["https://example.com/image.jpg"],
                Fields.SELLER_ID: "seller_123",
                Fields.SELLER_ADDRESS: {
                    Fields.STREET: "123 Farm Road",
                    Fields.CITY: "Toronto",
                    Fields.STATE: "ON",
                    Fields.POSTAL_CODE: "M5V 3A8",
                    Fields.COUNTRY: "Canada",
                },
                Fields.STATUS: "pending",
            }
        }
    )

    productId: str = Field(..., min_length=1)
    cartItemId: str | None = Field(
        default=None,
        description="Canonical cart item ID — opaque key that survives duplicate-productId carts (F-001/F-003)",
    )
    name: str = Field(..., min_length=1, max_length=120)
    description: str = Field(default="", max_length=4000)
    price: float = Field(..., gt=0)
    quantity: int = Field(..., gt=0, le=ValidationLimits.MAX_ITEM_QUANTITY)
    imageUrls: list[str] = Field(..., min_length=1, description="Product image URLs")
    sellerId: str = Field(..., min_length=1)
    sellerAddress: Address | None = Field(default=None)
    fulfillmentWarehouseId: str | None = Field(
        default=None, description="Warehouse from which this item was fulfilled (TASK 02)"
    )
    trackingNumber: str | None = Field(default=None, max_length=100)
    carrier: str | None = Field(default=None, max_length=100)
    carrierNote: str | None = Field(default=None, max_length=500, description="Free-text override when carrier='other'")
    sellerSku: str | None = Field(default=None, max_length=100, description="Seller's SKU snapshotted at purchase time")
    sellerName: str | None = Field(default=None, max_length=200, description="Seller display name snapshotted at purchase time")
    confirmedByBuyer: bool = Field(default=False)

    # Variant tracking (immutable snapshot at order creation — Medusa/Saleor/Shopify pattern)
    variantId: str | None = Field(default=None, description="Variant ID at time of purchase")
    variantTitle: str | None = Field(default=None, max_length=255, description="Human-readable variant label e.g. 'Size: M / Color: Blue'")
    variantOptions: dict[str, str] | None = Field(default=None, description="Variant option key-value map e.g. {'Size': 'M', 'Color': 'Blue'}")
    variantSku: str | None = Field(default=None, max_length=100, description="Variant SKU snapshotted at purchase time")

    # Per-item status
    status: str = Field(
        default=DeliveryStatusValues.PENDING, description="Item status: pending, shipped, delivered, refunded"
    )

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        """Function validate_status."""
        if v not in DeliveryStatusValues.ALL:
            raise ValueError(f"Invalid status: {v}. Must be one of: {DeliveryStatusValues.ALL}")
        return v

    @field_validator("carrier")
    @classmethod
    def validate_carrier(cls, v: str | None) -> str | None:
        """Function validate_carrier."""
        if v is not None and v not in CarrierValues.ALL:
            raise ValueError(f"carrier must be one of {CarrierValues.ALL}")
        return v

    # Timestamps
    shippedAt: datetime | None = Field(default=None)
    deliveredAt: datetime | None = Field(default=None)

    # Refund tracking
    refundReason: str | None = Field(default=None, max_length=500)
    refundAmountCents: int | None = Field(default=None, ge=0)
    refundId: str | None = Field(default=None)

    # Shipping metadata (captured at purchase time)
    weightKg: float | None = Field(default=None, gt=0)
    lengthCm: float | None = Field(default=None, gt=0)
    widthCm: float | None = Field(default=None, gt=0)
    heightCm: float | None = Field(default=None, gt=0)
    isLocalDeliveryOnly: bool = Field(default=False)
    isPerishable: bool = Field(default=False)
    estimatedShipDays: int = Field(default=3, ge=0)
    deliveryOptions: list[SellerDeliveryOption] = Field(default_factory=list)
    minimumOrderQuantity: int = Field(default=1, ge=1)
    freeShipping: bool = Field(default=False)
    isDigital: bool = Field(default=False, description="Whether this item is a digital product")

    # Digital product delivery fields (set on payment capture)
    licenseKey: str | None = Field(default=None, description="License key reference into licenses collection")
    digitalUnlocked: bool = Field(default=False, description="True after license has been generated on payment")
    digitalType: str | None = Field(default=None, description="Type of digital product: 'software' or 'book'")
    digitalBuilds: dict[str, str] | None = Field(
        default=None, description="Platform -> download URL map (software only)"
    )

    taxCode: str | None = Field(default=None, description="Tax code for this item")

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        """Reject HTML/script injection in product names"""
        if re.search(r"[<>]", v):
            raise ValueError("Name contains disallowed characters")
        return v

    @field_validator("imageUrls")
    @classmethod
    def validate_image_urls(cls, v: list[str]) -> list[str]:
        """Validate image URLs"""
        for url in v:
            if not url.startswith(("http://", "https://")):
                raise ValueError(f"Invalid image URL: {url}")
        return v

    def subtotal(self) -> float:
        """Calculate item subtotal"""
        return self.price * self.quantity


class Taxes(BaseModel):
    """Tax breakdown for an order (Canadian taxes)."""

    GST: float = Field(default=0.0, ge=0, description="Goods and Services Tax (Federal)")
    PST: float = Field(default=0.0, ge=0, description="Provincial Sales Tax")
    HST: float = Field(default=0.0, ge=0, description="Harmonized Sales Tax")
    QST: float = Field(default=0.0, ge=0, description="Quebec Sales Tax")

    def total(self) -> float:
        """Calculate total tax amount"""
        return self.GST + self.PST + self.HST + self.QST


class Ratings(BaseModel):
    """Product rating within an order."""

    productId: str = Field(..., min_length=1)
    rating: float = Field(..., ge=0, le=5)
    review: str | None = Field(default=None, max_length=1000)
    createdAt: datetime = Field(default_factory=lambda: datetime.now(UTC))

    @field_validator("review")
    @classmethod
    def validate_review(cls, v: str | None) -> str | None:
        """Reject HTML/script injection in reviews"""
        if v is not None and re.search(r"[<>]", v):
            raise ValueError("Review contains disallowed characters")
        return v


class SellerPayout(BaseModel):
    """Payout information for a seller in an order. All money in cents."""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                Fields.SELLER_ID: "seller_123",
                Fields.STRIPE_ACCOUNT_ID: "acct_123",
                Fields.AMOUNT_CENTS: 4750,
                Fields.PLATFORM_FEE_CENTS: 119,
                Fields.NET_AMOUNT_CENTS: 4631,
                Fields.STATUS: "pending",
            }
        }
    )

    sellerId: str = Field(..., min_length=1)
    stripeAccountId: str | None = Field(default=None)
    amountCents: int = Field(..., ge=0, description="Gross amount in cents")
    platformFeeCents: int = Field(..., ge=0, description="Platform fee in cents")
    netAmountCents: int = Field(..., ge=0, description="Net amount in cents")
    status: str = Field(default=PayoutStatusValues.PENDING, description="Payout status")
    payoutDate: datetime | None = Field(default=None)
    stripeTransferId: str | None = Field(default=None)
    failureReason: str | None = Field(default=None, max_length=500)

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        """Function validate_status."""
        if v not in PayoutStatusValues.ALL:
            raise ValueError(f"Invalid payout status: {v}. Must be one of: {PayoutStatusValues.ALL}")
        return v


class Order(BaseModel):
    """Complete order model. All money in integer cents."""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                Fields.ORDER_ID: "order_123abc",
                Fields.USER_ID: "user_123",
                Fields.CUSTOMER_ID: "cus_stripe123",
                "customerEmail": "buyer@example.com",
                Fields.ITEMS: [],
                Fields.SUBTOTAL_CENTS: 4999,
                Fields.SHIPPING_COST_CENTS: 500,
                Fields.TAX_AMOUNT_CENTS: 650,
                Fields.TOTAL_AMOUNT_CENTS: 6149,
                Fields.TAXES: {"GST": 2.50, "PST": 3.50},
                Fields.ORDER_STATUS: "pending",
                Fields.PAYMENT_STATUS: "awaiting_payment",
                Fields.SHIPPING_ADDRESS: {},
                Fields.CREATED_AT: "2026-02-01T10:00:00Z",
            }
        }
    )

    orderId: str = Field(..., min_length=1)
    userId: str = Field(..., min_length=1)
    version: int = Field(default=1, ge=1, description="Optimistic concurrency version — increment on every state mutation")
    schemaVersion: int = Field(default=1, ge=1, description="Schema layout version for migration tracking")

    # Optional identity fields (can be fetched from user doc)
    customerId: str | None = Field(default=None, min_length=1)
    customerEmail: str | None = Field(default=None, pattern=r"^[^@]+@[^@]+\.[^@]+$")

    items: list[OrderItem] = Field(..., min_length=1)
    sellerIds: list[str] = Field(default_factory=list)

    # Money — all in integer cents
    subtotalCents: int = Field(..., ge=0)
    shippingCostCents: int = Field(default=0, ge=0)
    taxAmountCents: int = Field(default=0, ge=0)
    totalAmountCents: int = Field(..., ge=0)

    taxes: Taxes = Field(default_factory=Taxes)

    # Status
    orderStatus: OrderStatusEnum = Field(default=OrderStatusEnum.PENDING)
    paymentStatus: PaymentStatusEnum = Field(default=PaymentStatusEnum.AWAITING_PAYMENT)

    # Address
    shippingAddress: Address | None = Field(default=None)
    deliveryInstructions: str | None = Field(default=None, max_length=500)

    # Timestamps
    createdAt: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updatedAt: datetime | None = Field(default=None)

    # Payment provider IDs
    stripeSessionId: str | None = Field(default=None, min_length=1)
    stripePaymentIntentId: str | None = Field(default=None, min_length=1)

    currency: str = Field(default=BusinessRules.DEFAULT_CURRENCY)

    # Shipping approval
    shippingApprovalStatus: ShippingApprovalStatusEnum = Field(default=ShippingApprovalStatusEnum.NOT_REQUIRED)
    shippingApprovalRequired: bool = Field(default=False)
    actualShippingCents: int = Field(default=0, ge=0)
    pendingTotalCents: int = Field(default=0, ge=0)

    # Payout tracking
    sellerPayouts: list[SellerPayout] = Field(default_factory=list)
    confirmedByClient: bool = Field(default=False)
    confirmedAt: datetime | None = None
    autoConfirmed: bool = Field(default=False)
    autoCaptured: bool = Field(default=False)
    platformFeeTotalCents: int = Field(default=0, ge=0)
    payoutStatus: str = Field(default=PayoutStatusValues.PENDING, description="Overall payout status")

    # Capture tracking
    captureAttempts: int = Field(default=0, ge=0)
    capturedAt: datetime | None = Field(default=None)
    expiresAt: datetime | None = Field(default=None)

    # Cancellation tracking
    cancelledBy: str | None = Field(default=None)
    cancelledAt: datetime | None = Field(default=None)
    cancellationReason: str | None = Field(default=None, max_length=500)
    stockRestored: bool = Field(default=False)

    # Refund tracking
    refundAmountCents: int = Field(default=0, ge=0)
    refundedAt: datetime | None = Field(default=None)

    # Coupon / promo code (N-07)
    couponCode: str | None = Field(default=None, max_length=20)
    discountAmountCents: int = Field(default=0, ge=0)

    # Manual review
    requiresManualReview: bool = Field(default=False)
    manualReviewReason: str | None = Field(default=None, max_length=500)
    payoutErrors: list[str] = Field(default_factory=list)

    # Tax fields
    itemTaxes: list[dict] = Field(default_factory=list, description="Per-item tax breakdown")
    taxExempt: bool = Field(default=False)
    taxExemption: dict | None = Field(default=None)

    # Shipping approval response
    respondedAt: datetime | None = Field(default=None)
    actualCost: float | None = Field(default=None, ge=0)

    # Ratings
    ratings: list[Ratings] = Field(default_factory=list)

    @field_validator("currency")
    @classmethod
    def validate_currency(cls, v: str) -> str:
        """Function validate_currency."""
        if v.lower() not in BusinessRules.SUPPORTED_SELLING_CURRENCIES:
            raise ValueError(f"Only {BusinessRules.SUPPORTED_SELLING_CURRENCIES} currencies supported")
        return v.lower()

    @field_validator("payoutStatus")
    @classmethod
    def validate_payout_status(cls, v: str) -> str:
        """Function validate_payout_status."""
        if v not in PayoutStatusValues.ALL:
            raise ValueError(f"Invalid payout status: {v}")
        return v


class OrderCreate(BaseModel):
    """Model for creating new orders (excludes orderId and createdAt which are generated)."""

    userId: str = Field(..., min_length=1)
    customerId: str = Field(..., min_length=1)
    customerEmail: str = Field(..., pattern=r"^[^@]+@[^@]+\.[^@]+$")
    items: list[OrderItem] = Field(..., min_length=1)
    shippingAddress: Address
    shippingCost: float = Field(default=0.0, ge=0)
    currency: str = Field(default=BusinessRules.DEFAULT_CURRENCY)
    shippingApprovalRequired: bool = Field(default=False)
