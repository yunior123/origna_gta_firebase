"""
Pydantic models for OrignaGTA
Single source of truth for all shared data structures
"""

from .base import (
    Address,
    AddressDetails,
    DeliveryStatusEnum,
    OrderStatusEnum,
    PaymentStatusEnum,
    ShippingApprovalStatusEnum,
    UserRole,
)
from .order import (
    Order,
    OrderCreate,
    OrderItem,
    Ratings,
    SellerPayout,
    Taxes,
)
from .order_event import OrderEvent
from .product import (
    InventoryConfig,
    Product,
    ProductCreate,
    SellerDeliveryOption,
    ShippingQuantityDiscount,
    SupplierInfo,
)
from .return_request import ReturnRequest
from .user import (
    User,
    UserCreate,
)

__all__ = [
    # Base types
    "Address",
    "AddressDetails",
    "OrderStatusEnum",
    "PaymentStatusEnum",
    "DeliveryStatusEnum",
    "ShippingApprovalStatusEnum",
    "UserRole",
    # Product
    "Product",
    "ProductCreate",
    "SellerDeliveryOption",
    "ShippingQuantityDiscount",
    "SupplierInfo",
    "InventoryConfig",
    # Order
    "OrderItem",
    "Taxes",
    "Ratings",
    "SellerPayout",
    "Order",
    "OrderCreate",
    "OrderEvent",
    "ReturnRequest",
    # User
    "User",
    "UserCreate",
]
