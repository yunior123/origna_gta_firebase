"""
Seller profile model for OrignaGTA
Stored in seller_profiles/{uid} — split from users doc to avoid billing buyers for null seller fields.
"""

from datetime import datetime

from pydantic import BaseModel, Field

from .base import Address


class SellerProfile(BaseModel):
    """
    Seller-specific data — lives in seller_profiles/{uid}.
    Buyers never read this doc; only the seller, admins, and backend access it.
    """

    # Stripe Connect
    stripeAccountId: str | None = Field(default=None, description="Stripe Connect account ID")
    payoutsEnabled: bool = Field(default=False, description="Whether seller can receive payouts")
    chargesEnabled: bool = Field(default=False, description="Whether seller can accept charges")
    onboardingCompleted: bool = Field(default=False, description="Whether Stripe Connect onboarding is complete")
    pendingRequirements: list[str] | None = Field(default=None, description="Outstanding Stripe onboarding requirements")

    # Commission (basis points — 250 = 2.50%)
    commissionRateBps: int = Field(default=250, ge=0, le=10000, description="Platform commission in basis points (250 = 2.50%)")

    # Seller stats (denormalized for fast display)
    avgRating: float = Field(default=0.0, ge=0, le=5, description="Average seller rating")
    totalReviews: int = Field(default=0, ge=0, description="Total number of reviews")
    totalSales: int = Field(default=0, ge=0, description="Total completed sales")

    # Warehouse references
    warehouseIds: list[str] | None = Field(default=None, description="IDs of seller warehouses")

    # Business info
    businessName: str | None = Field(default=None, max_length=120, description="Seller business name")
    businessAddress: Address | None = Field(default=None, description="Seller business address")

    # Returns policy
    acceptsReturns: bool = Field(default=True, description="Whether seller accepts returns")
    returnWindowDays: int = Field(default=30, ge=0, le=365, description="Days buyer has to initiate a return")

    # Verification
    verified: bool = Field(default=False, description="Whether seller identity is verified")
    verificationStatus: str | None = Field(default=None, description="Verification status: pending, verified, rejected")
    platform: str | None = Field(default=None, description="Seller platform/source: aliexpress, alibaba, 1688, dhgate, temu, local, custom")
    payoutHoldDays: int | None = Field(default=None, ge=0, le=30, description="Days to hold payouts after delivery")

    # Payment
    bankAccountLast4: str | None = Field(default=None, max_length=4, description="Last 4 digits of bank account")

    # Timestamps
    createdAt: datetime | None = Field(default=None, description="When seller profile was created")
    updatedAt: datetime | None = Field(default=None, description="Last update timestamp")
