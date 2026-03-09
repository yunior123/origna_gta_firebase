"""ReturnRequest model — tracks physical return of an item."""

from datetime import UTC, datetime

from pydantic import BaseModel, Field, field_validator

from schema_constants import ReturnStatusValues


class ReturnRequest(BaseModel):
    """Class ReturnRequest."""
    returnId: str = Field(..., description="Auto-generated doc ID")
    orderId: str = Field(..., description="Parent order ID")
    orderItemId: str = Field(..., description="Cart item ID of the item being returned")
    buyerId: str
    sellerId: str
    productId: str
    productName: str
    quantity: int = Field(default=1, ge=1)
    returnStatus: str = Field(default=ReturnStatusValues.REQUESTED)
    returnReason: str = Field(..., max_length=1000, description="Buyer's reason for return")
    returnAdminNote: str | None = Field(default=None, max_length=1000)
    returnTrackingNumber: str | None = Field(default=None, max_length=100)
    returnRefundAmountCents: int | None = Field(default=None, ge=0)
    requestedAt: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updatedAt: datetime = Field(default_factory=lambda: datetime.now(UTC))
    resolvedAt: datetime | None = Field(default=None)

    @field_validator("returnStatus")
    @classmethod
    def validate_return_status(cls, v: str) -> str:
        """Function validate_return_status."""
        if v not in ReturnStatusValues.ALL:
            raise ValueError(f"Invalid return status: {v}. Must be one of: {ReturnStatusValues.ALL}")
        return v
