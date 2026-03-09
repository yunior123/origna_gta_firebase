"""
Base models and enums for OrignaGTA
Includes Address, enumerations, and common types
"""

import re
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, field_validator

from schema_constants import BusinessRules, Fields

# ============================================================================
# ENUMERATIONS
# ============================================================================


class OrderStatusEnum(StrEnum):
    """Order status values"""

    PENDING = "pending"
    CONFIRMED = "confirmed"
    PROCESSING = "processing"
    SHIPPED = "shipped"
    IN_TRANSIT = "in_transit"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"
    FAILED = "failed"
    EXPIRED = "expired"
    REFUNDED = "refunded"
    PARTIALLY_REFUNDED = "partially_refunded"
    DISPUTED = "disputed"


class PaymentStatusEnum(StrEnum):
    """Payment status values"""

    AWAITING_PAYMENT = "awaiting_payment"
    PROCESSING = "processing"
    PAID = "paid"
    AUTHORIZED = "authorized"
    CAPTURED = "captured"
    PAYMENT_FAILED = "payment_failed"
    REFUNDED = "refunded"
    SESSION_EXPIRED = "session_expired"
    CANCELLED = "cancelled"
    AUTHORIZATION_EXPIRED = "authorization_expired"
    DISPUTED = "disputed"
    PARTIALLY_REFUNDED = "partially_refunded"
    # Transitional states (persisted briefly for idempotency/race-condition guards)
    CAPTURING = "capturing"
    CANCELLING = "cancelling"
    EXPIRING = "expiring"
    VOIDED = "voided"


class DeliveryStatusEnum(StrEnum):
    """Delivery status for individual items"""

    PENDING = "pending"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    REFUNDED = "refunded"


class ShippingApprovalStatusEnum(StrEnum):
    """Shipping approval status"""

    NOT_REQUIRED = "not_required"
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class UserRole(StrEnum):
    """User roles"""

    ADMIN = "admin"
    SELLER = "seller"
    BUYER = "buyer"


# ============================================================================
# ADDRESS MODELS
# ============================================================================


class Address(BaseModel):
    """
    Complete address model with validation
    Used for delivery, seller locations, and user addresses
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                Fields.STREET: "123 Main Street",
                Fields.APARTMENT: "Apt 4B",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V 3A8",
                Fields.COUNTRY: "Canada",
                Fields.PHONE_NUMBER: "4165551234",
                Fields.IS_DEFAULT: True,
                Fields.LABEL: "Home",
            }
        }
    )

    street: str = Field(..., min_length=1, max_length=100, description="Street address")
    apartment: str = Field(default="", max_length=20, description="Unit, Suite, Apt number")
    city: str = Field(..., min_length=2, max_length=50, description="City name")
    state: str = Field(..., min_length=2, max_length=2, description="Province/State code (e.g., ON, QC, BC)")
    postalCode: str = Field(..., description="Canadian postal code (e.g., M5V 3A8)")
    country: str = Field(default="Canada", description="Country name")
    phoneNumber: str | None = Field(default=None, description="Contact phone number for delivery")
    isDefault: bool = Field(default=False, description="Whether this is the default address")
    label: str | None = Field(default=None, max_length=20, description="Address label (Home, Work, Other)")
    addressId: str | None = Field(default=None, description="Unique identifier for the address document")
    latitude: float | None = Field(default=None, ge=-90, le=90, description="Latitude for mapping/delivery routing")
    longitude: float | None = Field(default=None, ge=-180, le=180, description="Longitude for mapping/delivery routing")

    @field_validator("postalCode")
    @classmethod
    def validate_postal_code(cls, v: str) -> str:
        """Validate Canadian postal code format"""
        # Canadian postal code: A1A 1A1 or A1A1A1
        postal_pattern = re.compile(r"^[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d$")
        if not postal_pattern.match(v):
            raise ValueError("Invalid Canadian postal code format (expected: A1A 1A1)")
        # Normalize: remove existing space/dash, then add space in middle
        v_clean = v.replace(" ", "").replace("-", "").upper()
        return f"{v_clean[:3]} {v_clean[3:]}"  # Format as A1A 1A1

    @field_validator("phoneNumber")
    @classmethod
    def validate_phone(cls, v: str | None) -> str | None:
        """Validate phone number (10-15 digits)"""
        if v is None:
            return None
        # Remove all non-digit characters
        digits = re.sub(r"\D", "", v)
        if not 10 <= len(digits) <= 15:
            raise ValueError("Phone number must be 10-15 digits")
        return digits

    @field_validator("state")
    @classmethod
    def validate_state(cls, v: str) -> str:
        """Validate and normalize province code"""
        v_upper = v.upper()
        if v_upper not in BusinessRules.VALID_PROVINCES:
            raise ValueError(f"Invalid Canadian province code: {v}")
        return v_upper

    def formatted_address(self) -> str:
        """Get formatted address with line breaks"""
        lines = [
            self.street,
            self.apartment if self.apartment else None,
            f"{self.city}, {self.state} {self.postalCode}",
            self.country,
        ]
        return "\n".join(line for line in lines if line)

    def full_address(self) -> str:
        """Get single-line address"""
        parts = [
            self.street,
            self.apartment if self.apartment else None,
            self.city,
            self.state,
            self.postalCode,
            self.country,
        ]
        return ", ".join(part for part in parts if part)


class AddressDetails(BaseModel):
    """
    Simplified address for delivery info
    Includes geolocation coordinates
    """

    street: str = Field(..., min_length=1, max_length=100)
    city: str = Field(..., min_length=2, max_length=50)
    state: str = Field(..., min_length=2, max_length=2)
    postalCode: str = Field(...)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)

    @field_validator("postalCode")
    @classmethod
    def validate_postal_code(cls, v: str) -> str:
        """Validate and normalize Canadian postal code"""
        postal_pattern = re.compile(r"^[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d$")
        if not postal_pattern.match(v):
            raise ValueError("Invalid postal code format")
        # Normalize: remove existing space/dash, then add space in middle
        v_clean = v.replace(" ", "").replace("-", "").upper()
        return f"{v_clean[:3]} {v_clean[3:]}"  # Format as A1A 1A1

    @field_validator("state")
    @classmethod
    def validate_state(cls, v: str) -> str:
        """Validate province/state code"""
        v_upper = v.upper()
        if v_upper not in BusinessRules.VALID_PROVINCES:
            raise ValueError(f"Invalid province: {v}")
        return v_upper
