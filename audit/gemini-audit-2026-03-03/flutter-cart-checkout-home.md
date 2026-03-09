# Flutter Audit — features/cart + features/checkout + features/home
**Date:** 2026-03-03
**Model:** gemini-2.5-pro
---

## Files Audited (5 total)
- lib/features/cart/cart_provider.dart
- lib/features/checkout/checkout_provider.dart
- lib/features/checkout/checkout_state.dart
- lib/features/home/home_state.dart
- lib/features/home/home_viewmodel.dart

---

## Findings

SEVERITY: CRITICAL
FILE: lib/features/cart/cart_provider.dart
LINE: 309, 315, 331, 338
ISSUE: The `CartController` methods `removeFromCart`, `saveForLater`, `updateBuyerNote`, and `updateQuantity` accept a `productId` to identify a cart item. This is ambiguous and incorrect because a cart can contain multiple distinct items with the same `productId` (e.g., different product variants). The `_resolveCartItemId` helper method attempts to find the document ID but only fetches the *first* matching item (`limit(1)`), leading to unpredictable behavior where the wrong item is updated or removed.
FIX: Refactor the controller methods to accept the unique Firestore document ID of the cart item (e.g., `cartItemId`) instead of the `productId`. The UI is responsible for passing this unique ID. This removes the ambiguity and also eliminates the need for the inefficient `_resolveCartItemId` method, which performs an unnecessary database query for every action. For example, `Future<void> updateQuantity(String productId, int newQuantity)` should become `Future<void> updateQuantity(String cartItemId, int newQuantity)`.
---

SEVERITY: MEDIUM
FILE: lib/features/home/home_state.dart
LINE: 56-58
ISSUE: The `displayedProducts` getter uses the hardcoded magic string `'CA'` to filter for products from Canada. This violates the project's "no magic strings" rule and is inconsistent with other parts of the codebase that use constants like `CountryValues.canadaCode`.
FIX: Replace the hardcoded `'CA'` string with the appropriate constant from `schema_constants.dart`, which is likely `CountryValues.canadaCode`. The implementation should be: `p.shipFromCountry?.toUpperCase() == CountryValues.canadaCode || (p.shipFromCountries?.any((c) => c.toUpperCase() == CountryValues.canadaCode) ?? false)`.
---

SEVERITY: LOW
FILE: lib/features/cart/cart_provider.dart
LINE: 161
ISSUE: The `cartWithDetailsProvider` uses a hardcoded string `'Unknown Seller'` as a fallback value for the seller's name. This string is not localized and will not be translated for users with different language settings.
FIX: Replace the hardcoded string with a call to the localization library, for example: `'sellers.unknown_seller'.tr()`.
---

SEVERITY: LOW
FILE: lib/features/checkout/checkout_provider.dart
LINE: 365-366
ISSUE: The error message for a `CircuitBreakerOpenException` is a hardcoded string: `'Payment service is temporarily unavailable. Please try again in a moment.'`. This string is not localized.
FIX: Replace the hardcoded string with a translation key so it can be localized, for example: `'checkout.errors.payment_service_unavailable'.tr()`.
---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 1     |
| HIGH     | 0     |
| MEDIUM   | 1     |
| LOW      | 2     |
| **Total**| **4** |

### Priority Action Items
1. **[CRITICAL]** `cart_provider.dart` L309/315/331/338 — Cart item identification by `productId` instead of unique Firestore doc ID causes wrong-item mutations for variant products. Refactor all 4 methods + remove `_resolveCartItemId`.
2. **[MEDIUM]** `home_state.dart` L56-58 — Magic string `'CA'` → replace with `CountryValues.canadaCode`.
3. **[LOW]** `cart_provider.dart` L161 — `'Unknown Seller'` → localize with `.tr()`.
4. **[LOW]** `checkout_provider.dart` L365-366 — Circuit breaker error message → localize with `.tr()`.
