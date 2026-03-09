# Cross-Stack Auditor Memory

## Verified Field Mappings (2026-03-03)
- checkout: `subtotalCents` in Python (`ApiKeys.SUBTOTAL_CENTS`) = `subtotalCents` in Dart (`ApiKeys.subtotalCents`) -- OK
- checkout: `idempotencyKey` in Python = `idempotencyKey` in Dart -- OK
- checkout: `checkoutUrl` in both -- OK
- checkout: `sessionId` in both -- OK
- checkout: `orderId` (Fields) in both -- OK
- checkout: `taxAmountCents` (Fields) in both -- OK
- checkout: `shippingAddress` (Fields) in both -- OK
- checkout: `items` (Fields) in both -- OK
- checkout: `couponCode` (Fields.COUPON_CODE = "couponCode") backend reads `data.get(Fields.COUPON_CODE)`, Dart sends `Fields.couponCode` -- OK
- checkout: `deliverySpeed` (Fields) in both -- OK
- checkout: `deliveryInstructions` (Fields) in both -- OK
- subscription: `checkoutUrl` string key in both -- OK
- subscription: `Fields.status` / `Fields.STATUS` both = "status" -- OK
- subscription: `cancelAtPeriodEnd` / `CANCEL_AT_PERIOD_END` both = "cancelAtPeriodEnd" -- OK
- orders: `ApiKeys.newStatus` / `ApiKeys.NEW_STATUS` both = "newStatus" -- OK
- DeliveryStatusValues, DeliveryItemStatusTransitions, OrderStatusValues -- all aligned
- PaymentStatusValues -- all aligned (VOIDED now in Python ALL set — fixed 2026-03-03)
- Tax rates (BusinessRules) -- all 13 provinces match between Dart and Python
- SecurityAlertTypes.refundFailed: both = 'refund.failed' -- OK (memory was stale)
- Fields.newRoles: Dart = 'new_roles', Python = 'new_roles' -- OK (values match, memory was stale)
- Fields.sellerRating/sellerRatingCount: present in BOTH Dart (lines 680-681) and Python -- OK (memory was stale)
- Collections.platformDebt: present in BOTH Dart (line 414) and Python -- OK (memory was stale)
- BusinessRules.platformFeePercent: Dart = 2.5, Python = 2.5 (PLATFORM_FEE_PERCENT) -- OK
- BusinessRules.freeShippingThresholdCents: Dart = 7500, Python = 7500 -- OK
- BusinessRules.localDeliveryRadiusKm: Dart = 50.0, Python = 50.0 -- OK
- BusinessRules.autoConfirmDays: Dart = 5, Python = 5 -- OK
- BusinessRules.authorizationExpiryDays: Dart = 6, Python = 6 -- OK
- BusinessRules.returnWindowDays: Dart = 7, Python = 7 -- OK
- BusinessRules.maxCaptureAttempts: Dart = 3, Python = 3 -- OK
- BusinessRules.defaultCurrency: Dart = 'cad', Python = 'cad' -- OK
- BusinessRules.minCheckoutTotalCents: Dart = 100, Python = 100 -- OK
- BusinessRules.maxCouponDiscountRatio: Dart = 0.95, Python = 0.95 -- OK
- BusinessRules.maxAdminCouponDiscountPercent: Dart = 90, Python = 90 -- OK
- BusinessRules.trendingTopN: Dart = 20, Python = 20 -- OK
- BusinessRules.trendingWindowHours: Dart = 24, Python = 24 -- OK
- BusinessRules.trendingPurchaseWeight: Dart = 3, Python = 3 -- OK
- OrderItem model fields: aligned across Dart and Python -- OK
- Order model fields: aligned (couponCode, discountAmountCents, itemTaxes all present) -- OK
- User model fields: aligned across both stacks -- OK
- SellerDeliveryOption: costCents (int, cents) aligned in both -- OK

## Known Mismatches Found (2026-03-03)

### FIXED
1. **PaymentStatusValues.VOIDED missing from Python ALL set** -- FIXED 2026-03-03 in `functions/schema_constants.py` line 1007-1026

### OPEN — MEDIUM
2. **BusinessRules.trendingFavoriteWeight**: Dart = 1 (line 164), Python = 2 (line 1630) -- VALUE MISMATCH
   - Impact: Trending score calculation differs between frontend display estimate and backend actual
   - Fix: Align to one value. Backend is authoritative for trending calc. Dart value is display-only but misleading.

## Patterns That Frequently Cause Bugs
- PaymentStatusValues.ALL frozenset: Python can miss enum values that are declared but not added to the set
- SecurityAlertTypes: Some use dots (refund.failed), some use underscores — check carefully before adding new ones
- BusinessRules numeric constants: silently drift between Dart and Python — always cross-check after changes
- Checkout: backend reads couponCode via Fields.COUPON_CODE = "couponCode"; Dart sends Fields.couponCode = "couponCode" — aligned
- Price: always cents (int) in Dart ApiKeys.subtotalCents and Python ApiKeys.SUBTOTAL_CENTS; product price is dollars (float) in Firestore on both sides
