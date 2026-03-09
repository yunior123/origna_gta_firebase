# Cross-Stack Auditor Memory

## Verified Field Mappings (2026-02-18)

### Schema Constants
- Collections: Python and Dart match exactly (all 15 collections identical)
- Fields: ~150+ fields verified, all camelCase Firestore values match
- Enum values: OrderStatus, PaymentStatus, DeliveryStatus, PayoutStatus, ShippingApproval all match
- State machines: VALID_TRANSITIONS identical in both stacks
- BusinessRules: TAX_RATES, platformFeePercent (2.5), defaultCurrency ("cad") all match
- CategoryIds: 1-21 range identical

### Known Mismatches Found

#### CRITICAL: updateItemStatus sends wrong key for newStatus
- Dart sends `Fields.status` ("status") but Python reads `ApiKeys.NEW_STATUS` ("newStatus")
- File: order_repository.dart:53 vs orders.py:316
- Impact: update_item_status always fails (newStatus is None -> "required" error)

#### CRITICAL: Backend writes `platformFeeCents` but Dart Order reads `platformFeeTotalCents`
- Backend: payment_stripe.py:980 writes `Fields.PLATFORM_FEE_CENTS` ("platformFeeCents")
- Frontend: order_models.dart:358 reads `Fields.platformFeeTotalCents` ("platformFeeTotalCents")
- Impact: platformFeeTotal always 0 in Dart UI

#### MEDIUM: Python classes missing from Dart
- SupplierCurrencyValues, CronLockStatusValues, AlgoliaActionValues, AdminActionValues
- ShippingSourceValues, ErrorCodeValues, CartVerificationReasonValues, PlaceholderAddressValues
- ValidationLimits, WebhookResponseStatus, AppConfig
- Impact: Frontend cannot reference these constants (uses hardcoded or no validation)

#### LOW: Order.description field optionality mismatch
- Python OrderItem: `description: str = Field(..., max_length=4000)` (required)
- Dart OrderItem: `required String description` but checkout_provider does NOT send description
- Backend populates from DB so no runtime failure, but data contract inconsistency

## Patterns That Cause Bugs
1. `Fields.status` vs `ApiKeys.newStatus` - Frontend uses field names for API params
2. `platformFeeCents` (per-payout) vs `platformFeeTotalCents` (order-level) naming confusion
3. Python has more enum/config classes than Dart (Dart is always the one missing entries)
