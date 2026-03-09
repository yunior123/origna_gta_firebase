"""
User models for OrignaGTA
"""

from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from schema_constants import Fields, PaymentProviderValues

from .base import Address, UserRole


class UserSecurity(BaseModel):
    """
    Backend-only MFA secrets — stored in user_security/{uid}.
    Never readable by client (Firestore rules: allow read: if false).
    """

    mfaSecret: str | None = Field(default=None, description="TOTP secret (encrypted, server-only)")
    mfaSecretTemp: str | None = Field(default=None, description="Temp TOTP secret during enrollment")
    mfaBackupCodes: list[str] | None = Field(default=None, description="Hashed MFA backup codes (SHA-256)")
    mfaBackupCodesTemp: list[str] | None = Field(default=None, description="Temp hashed backup codes during enrollment")
    mfaBackupCodesSalt: str | None = Field(default=None, description="Salt for hashing backup codes")
    mfaFailedAttempts: int = Field(default=0, ge=0, description="Consecutive failed MFA attempts")
    mfaLockoutUntil: datetime | None = Field(default=None, description="Lockout expiry after max failed attempts")
    lastMfaVerify: datetime | None = Field(default=None, description="Last successful MFA verification")


class User(BaseModel):
    """
    Complete user model
    Includes buyer, seller, and admin information
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                Fields.UID: "user_123abc",
                Fields.EMAIL: "user@example.com",
                Fields.NAME: "John Doe",
                Fields.ROLES: ["buyer"],
                Fields.CREATED_AT: "2026-02-01T10:00:00Z",
            }
        }
    )

    uid: str = Field(..., min_length=1, max_length=128, description="Firebase Auth User ID")
    email: EmailStr = Field(..., description="User email address")
    name: str = Field(..., min_length=2, max_length=60, description="User display name")
    roles: list[UserRole] = Field(..., min_length=1, description="User roles (buyer, seller, admin)")
    address: Address | None = Field(default=None, description="User's default address")
    createdAt: datetime = Field(default_factory=lambda: datetime.now(UTC), description="Account creation timestamp")

    # Stripe buyer information
    customerId: str | None = Field(default=None, description="Stripe Customer ID for payments")
    lastCheckoutSession: str | None = Field(default=None, description="Last Stripe Checkout Session ID")
    lastOrderId: str | None = Field(default=None, description="Last created order ID")
    lastCheckoutTimestamp: datetime | None = Field(default=None, description="Timestamp of last checkout")

    # Seller flag (details in seller_profiles/{uid})
    isSeller: bool = Field(default=False, description="Quick flag — seller details live in seller_profiles collection")

    # Account status
    suspended: bool = Field(default=False, description="Whether account is suspended")
    suspendedAt: datetime | None = Field(default=None, description="When account was suspended")
    unsuspendedAt: datetime | None = Field(default=None, description="When account was unsuspended")
    paymentProvider: str | None = Field(
        default=PaymentProviderValues.STRIPE, description="Payment provider for seller payouts"
    )
    mfaEnabled: bool = Field(default=False, description="Whether admin MFA is enabled")
    mfaEnrolledAt: datetime | None = Field(default=None, description="When MFA was first enrolled (OK for display)")
    lastMfaVerify: datetime | None = Field(default=None, description="Last successful admin MFA verification")
    updatedAt: datetime | None = Field(default=None, description="Last update timestamp")

    # Tax exemption for businesses (structured map, e.g. {gstNumber: "123456789RT0001"})
    taxExemption: dict | None = Field(default=None, description="Tax exemption details map, e.g. {gstNumber: '123456789RT0001'}")

    # === CONSENT & COMPLIANCE (CASL + PIPEDA + Quebec Law 25) ===
    emailConsent: bool = Field(default=True, description="User consented to receive transactional emails")
    marketingOptIn: bool = Field(default=False, description="Explicit opt-in for marketing/promotional emails (CASL)")
    consentTimestamp: datetime | None = Field(default=None, description="When consent was given (ISO 8601)")
    consentMethod: str | None = Field(
        default=None, description="How consent was obtained: signup, checkbox, double_opt_in, implied"
    )
    privacyAcceptedAt: datetime | None = Field(default=None, description="When user accepted the privacy policy")
    termsAcceptedAt: datetime | None = Field(default=None, description="When user accepted the Terms of Service")
    privacyPolicyVersion: str | None = Field(default=None, description="Version of privacy policy the user accepted")
    termsVersion: str | None = Field(default=None, description="Version of Terms of Service the user accepted")
    preferredLanguage: str = Field(
        default="en", description="User preferred language: 'en' or 'fr' (for Quebec Bill 96 compliance)"
    )
    unsubscribedAt: datetime | None = Field(default=None, description="When user unsubscribed from marketing emails")
    dataProcessingConsent: bool = Field(
        default=False, description="Explicit consent for personal data processing (PIPEDA / Law 25)"
    )

    # === PREMIUM SUBSCRIPTION ===
    isPremium: bool = Field(
        default=False, description="Cached premium status — authoritative source: subscriptions/{uid}"
    )
    premiumSince: datetime | None = Field(default=None, description="When premium subscription started")
    premiumExpiresAt: datetime | None = Field(
        default=None, description="Current billing period end (premium expires after this)"
    )
    stripeSubscriptionId: str | None = Field(default=None, description="Stripe Subscription ID")
    notifyNewProducts: bool = Field(
        default=False, description="Opt-in: receive FCM notification when new products are added (premium only)"
    )
    notifyTrending: bool = Field(
        default=False, description="Opt-in: receive FCM notification for trending products (premium only)"
    )
    pushEnabled: bool = Field(
        default=True, description="User opted into push notifications — False means opt-out"
    )
    fcmToken: str | None = Field(
        default=None, description="Firebase Cloud Messaging device token for push notifications"
    )
    fcmTokenUpdatedAt: datetime | None = Field(default=None, description="Last FCM token update timestamp")

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        """Validate name: allow Unicode letters but reject digits, HTML, and dangerous characters.
        Canada is multicultural — support Chinese, Arabic, Korean, Cyrillic, etc."""
        import re
        import unicodedata

        # Reject HTML tags and dangerous characters
        if re.search(r"[<>]", v):
            raise ValueError("Name contains disallowed characters")
        # Reject digits
        if re.search(r"\d", v):
            raise ValueError("Name must not contain digits")
        # Allow only: Unicode letters, spaces, hyphens, apostrophes, periods
        for char in v:
            cat = unicodedata.category(char)
            if cat.startswith("L"):  # Any letter (Latin, CJK, Arabic, Cyrillic, etc.)
                continue
            if char in " '-.\u00b7":  # Space, apostrophe, hyphen, period, middle dot
                continue
            raise ValueError(f"Name contains disallowed character: {char!r}")
        return v

    @field_validator("roles")
    @classmethod
    def validate_roles(cls, v: list[UserRole]) -> list[UserRole]:
        """Ensure at least one role is assigned"""
        if not v:
            raise ValueError("At least one role must be assigned")
        return v

    def is_seller(self) -> bool:
        """Check if user has seller role"""
        return UserRole.SELLER in self.roles

    def is_admin(self) -> bool:
        """Check if user has admin role"""
        return UserRole.ADMIN in self.roles

    def can_sell(self) -> bool:
        """Check if user can sell products (seller flag + not suspended). Full check requires seller_profiles doc."""
        return self.is_seller() and not self.suspended


class UserCreate(BaseModel):
    """
    Model for creating new users
    (excludes uid and createdAt which are generated by Firebase Auth)
    """

    email: EmailStr
    name: str = Field(..., min_length=2, max_length=60)
    roles: list[UserRole] = Field(default=[UserRole.BUYER])
    address: Address | None = None
