# Flutter Audit — features/orders + features/products + features/profile + features/seller
**Date:** 2026-03-03
**Model:** gemini-2.5-pro
---

## Files Audited (26 total)

### features/orders
- lib/features/orders/buyer_orders_viewmodel.dart
- lib/features/orders/orders_provider.dart
- lib/features/orders/seller_orders_state.dart
- lib/features/orders/seller_orders_viewmodel.dart
- lib/features/orders/shipping_approval_viewmodel.dart

### features/products
- lib/features/products/add_product_state.dart
- lib/features/products/add_product_viewmodel.dart
- lib/features/products/edit_product_state.dart
- lib/features/products/edit_product_viewmodel.dart
- lib/features/products/product_actions_viewmodel.dart
- lib/features/products/product_detail_viewmodel.dart
- lib/features/products/product_rating_viewmodel.dart
- lib/features/products/products_provider.dart
- lib/features/products/stock_notification_provider.dart
- lib/features/products/variant_models.dart

### features/profile
- lib/features/profile/address_management_viewmodel.dart
- lib/features/profile/address_state.dart
- lib/features/profile/address_viewmodel.dart
- lib/features/profile/profile_provider.dart
- lib/features/profile/profile_state.dart
- lib/features/profile/profile_viewmodel.dart

### features/seller
- lib/features/seller/seller_account_status_viewmodel.dart
- lib/features/seller/seller_products_viewmodel.dart
- lib/features/seller/seller_registration_state.dart
- lib/features/seller/seller_registration_view_model.dart
- lib/features/seller/warehouses_viewmodel.dart

---

## Findings — Batch 1 (files 1–13)

SEVERITY: HIGH
FILE: lib/features/products/product_detail_viewmodel.dart
LINE: 106
ISSUE: An empty catch block `catch (_)` is used, which swallows the error completely. The error is not logged or reported, making it impossible to debug failures in fetching seller metrics. The UI will simply stop showing loading and display empty metrics without any indication of what went wrong.
FIX: At a minimum, log the error. A better solution would be to also set an error message in the state so the UI can inform the user of the failure. Replace `catch (_)` with `catch (e, st) { AppError.log(e, stackTrace: st, context: 'fetchSellerMetrics'); state = state.copyWith(sellerMetricsLoading: false, sellerMetrics: null); }`.
---
SEVERITY: HIGH
FILE: lib/features/products/product_detail_viewmodel.dart
LINE: 89-93
ISSUE: The ViewModel directly accesses Firestore using `_ref.read(firestoreProvider)`. This is a violation of the project's architecture, which dictates that data access should be handled by a repository. This makes the ViewModel harder to test, couples it to the data layer implementation, and scatters data logic across the app.
FIX: Create a method in an appropriate repository (e.g., `SellerRepository` or `UserRepository`) called `fetchSellerMetrics(String sellerId)`. Move the Firestore query and data parsing logic into that method. The repository method should return a typed `SellerMetrics` object. The ViewModel should then call `await _ref.read(sellerRepositoryProvider).fetchSellerMetrics(sellerId);`.
---
SEVERITY: HIGH
FILE: lib/features/products/edit_product_viewmodel.dart
LINE: 235-311
ISSUE: Multiple user-facing error messages in the `updateProduct` method are hardcoded strings (e.g., 'Product name is required', 'Stock cannot be negative'). This violates internationalization (i18n) best practices, as these strings cannot be translated. The `add_product_viewmodel.dart` file correctly uses `.tr()` for these types of validations.
FIX: Replace all hardcoded user-facing error strings with translation keys and apply the `.tr()` method, consistent with the rest of the application. For example, change `'Product name is required'` to `'product.please_enter_name'.tr()`.
---
SEVERITY: HIGH
FILE: lib/features/orders/buyer_orders_viewmodel.dart
LINE: 35-39
ISSUE: The `confirmingItemId` state field is set when a confirmation begins but is never cleared when the operation succeeds or fails. This will prevent the user from confirming any other item after the first attempt, as the guard `if (state.confirmingItemId != null) return false;` will always fail.
FIX: Reset the `confirmingItemId` to null in all terminal `copyWith` calls within the `confirmReceipt` method. Update line 35 to `state = state.copyWith(isLoading: false, isSuccess: true, confirmingItemId: null);` and line 38 to `state = state.copyWith(isLoading: false, errorMessage: ..., confirmingItemId: null);`.
---
SEVERITY: MEDIUM
FILE: lib/features/products/products_provider.dart
LINE: 153
ISSUE: The method `FavoritesController.isFavorite` uses `_ref.read(favoritesProvider)`. `ref.read` does not subscribe to changes, so if the favorites list changes, any widget using this method will not rebuild and will show stale data (e.g., a heart icon will not update when a product is favorited).
FIX: Replace the `FavoritesController` with a more idiomatic Riverpod approach. Create a family provider that directly returns the favorite status for a given product ID: `final isFavoriteProvider = Provider.autoDispose.family<bool, String>((ref, productId) { final favorites = ref.watch(favoritesProvider).asData?.value ?? {}; return favorites.contains(productId); });`. Widgets can then `watch` this provider for reactive updates.
---
SEVERITY: MEDIUM
FILE: lib/features/products/product_detail_viewmodel.dart
LINE: 98-105
ISSUE: The ViewModel is responsible for parsing the raw data map from Firestore into the `SellerMetrics` model. This logic belongs in the data layer (repository). Keeping it in the ViewModel violates separation of concerns, makes the ViewModel more complex, and couples it to the database schema.
FIX: Move the parsing logic into the repository method that fetches the data. The repository should be responsible for returning a fully-typed `SellerMetrics` object, not a raw `DocumentSnapshot`.
---
SEVERITY: MEDIUM
FILE: lib/features/orders/orders_provider.dart
LINE: 48-60
ISSUE: The file defines a sealed class hierarchy (`OrderResult`, `OrderSuccess`, `OrderError`) which does not appear to be used by any of the provided ViewModel files. The ViewModels use their own `State` classes with boolean flags (`isLoading`, `isSuccess`) and a `String? errorMessage` to manage state, which is a different pattern. This unused code adds clutter and can be confusing for future maintenance.
FIX: Either refactor the ViewModels (`SellerOrdersViewModel`, `BuyerOrdersViewModel`, etc.) to use the `OrderResult` sealed class for a more robust state management pattern, or remove the `OrderResult`, `OrderSuccess`, and `OrderError` classes if they are truly obsolete.
---
SEVERITY: MEDIUM
FILE: lib/features/products/edit_product_viewmodel.dart
LINE: 427
ISSUE: The `catch` block in `updateProduct` calls `AppError.getMessage(e)` without providing a default fallback message. Other parts of the application provide a translated fallback string, e.g., `AppError.getMessage(e, 'product.update_failed'.tr())`. Without the fallback, a generic, untranslated message will be shown for unexpected errors, leading to a poor user experience.
FIX: Provide a translated, user-friendly fallback error message to the `AppError.getMessage` call. For example: `final msg = AppError.getMessage(e, 'product.update_failed'.tr());`.
---
SEVERITY: LOW
FILE: lib/features/orders/buyer_orders_viewmodel.dart
LINE: 38
ISSUE: The error message 'Failed to confirm order receipt' is a hardcoded string. It should be added to the localization files and accessed via the `.tr()` extension method to support internationalization.
FIX: Replace the hardcoded string with a translation key, for example: `AppError.getMessage(e, 'orders.confirm_receipt_failed'.tr())`.
---
SEVERITY: LOW
FILE: lib/features/orders/seller_orders_viewmodel.dart
LINE: 49
ISSUE: The error message 'Failed to update shipping cost' is a hardcoded string. It should use the translation extension `.tr()` for internationalization.
FIX: Replace the hardcoded string with a translation key. For example: `errorMessage: AppError.getMessage(e, 'seller_orders.update_shipping_failed'.tr())`.
---
SEVERITY: LOW
FILE: lib/features/orders/seller_orders_viewmodel.dart
LINE: 81
ISSUE: The error message 'Failed to update item status' is a hardcoded string. It should use the translation extension `.tr()` for internationalization.
FIX: Replace the hardcoded string with a translation key. For example: `errorMessage: AppError.getMessage(e, 'seller_orders.update_item_status_failed'.tr())`.
---
SEVERITY: LOW
FILE: lib/features/orders/shipping_approval_viewmodel.dart
LINE: 30
ISSUE: The error message 'Failed to process shipping approval' is a hardcoded string. It should be translated using a key and the `.tr()` method.
FIX: Replace the hardcoded string with a translation key. Example: `errorMessage: AppError.getMessage(e, 'orders.shipping_approval_failed'.tr())`.
---
SEVERITY: LOW
FILE: lib/features/products/add_product_viewmodel.dart
LINE: 346
ISSUE: The exception message 'Failed to compress images. Please try different images.' is a hardcoded string. If this error propagates to the user, it will not be translated.
FIX: Replace the hardcoded string with a translation key, like `throw Exception('product.image_compression_failed'.tr());`. The `catch` block in `addProduct` will then display the translated message.
---
SEVERITY: LOW
FILE: lib/features/products/product_actions_viewmodel.dart
LINE: 30
ISSUE: The error message 'Failed to perform action' is a generic, hardcoded string. It should be made more specific and translated.
FIX: Replace the hardcoded string with a more descriptive and translatable key, such as `AppError.getMessage(e, 'product.delete_failed'.tr())`.
---
SEVERITY: LOW
FILE: lib/features/products/product_rating_viewmodel.dart
LINE: 47
ISSUE: The error message 'Failed to submit rating' is a hardcoded string. For an internationalized app, all user-facing strings should be translatable.
FIX: Replace the hardcoded string with a translation key and use the `.tr()` method. For example: `errorMessage: AppError.getMessage(e, 'rating.submit_failed'.tr())`.
---

## Findings — Batch 2 (files 14–26)

SEVERITY: HIGH
FILE: lib/features/seller/seller_account_status_viewmodel.dart
LINE: 36-39
ISSUE: The code uses an unsafe cast `(data[ApiKeys.requirementsCurrentlyDue] as List<dynamic>)` which will crash if the key is missing, null, or not a list. This is not robust for handling API responses.
FIX: Use type-checking with `is` to safely parse the list. Replace the line with:
```dart
final requirementsList = data[ApiKeys.requirementsCurrentlyDue];
final requirementsDue = (requirementsList is List)
    ? requirementsList.map((e) => e.toString()).toList()
    : <String>[];
```
---
SEVERITY: HIGH
FILE: lib/features/seller/seller_products_viewmodel.dart
LINE: 66-69
ISSUE: The success message string is constructed manually, including logic for pluralization (`product${updated == 1 ? '' : 's'}`). This is not localization-friendly and will not work correctly in other languages.
FIX: Use the `easy_localization` package's `plural` helper for quantity-sensitive strings. Define a key in your translation files (e.g., `seller_bulk_update_success`) and use it like this: `successMessage: 'seller_bulk_update_success'.plural(updated, namedArgs: {'action': action, 'skipped': skipped.toString()})`.
---
SEVERITY: MEDIUM
FILE: lib/features/products/variant_models.dart
LINE: 12-16, 62-70
ISSUE: The `fromMap` and `toMap` methods use hardcoded string literals for keys (e.g., 'name', 'values', 'variantId'). This is error-prone and inconsistent with other parts of the codebase that use a `Fields` class from `schema_constants.dart`.
FIX: Add these keys to the `schema_constants.dart` file and reference them here. For example, replace `'name'` with `Fields.name` and so on for all keys in both `VariantOption` and `ProductVariantEntry` models.
---
SEVERITY: MEDIUM
FILE: lib/features/profile/address_viewmodel.dart
LINE: 40
ISSUE: A user-facing error message is hardcoded, preventing translation.
FIX: Replace the hardcoded string with a key from your translation files and use the `.tr()` extension. For example: `state = state.copyWith(errorMessage: 'profile.address.select_from_suggestions'.tr());`
---
SEVERITY: MEDIUM
FILE: lib/features/profile/address_viewmodel.dart
LINE: 65
ISSUE: The fallback error message in `AppError.getMessage` is a hardcoded string ('Failed to save address'), which prevents translation.
FIX: Replace the hardcoded string with a translation key. Change the call to: `AppError.getMessage(e, 'profile.address.save_failed'.tr())`
---
SEVERITY: MEDIUM
FILE: lib/features/profile/profile_viewmodel.dart
LINE: 27, 36, 41, 48
ISSUE: User-facing strings for error messages and confirmations are hardcoded (e.g., 'Failed to update language', 'Please type DELETE to confirm'). This prevents them from being translated for different locales.
FIX: Replace all hardcoded user-facing strings with translation keys and use the `.tr()` extension method.
- Line 27: `'errors.language_update_failed'.tr()`
- Line 36: `'errors.export_data_failed'.tr()`
- Line 41: `'profile.delete_confirmation_prompt'.tr()`
- Line 48: `'errors.delete_account_failed'.tr()`
---
SEVERITY: MEDIUM
FILE: lib/features/seller/seller_registration_view_model.dart
LINE: 22-29
ISSUE: The `paymentProviderStatusProvider` performs an unsafe cast `result.data as Map` and `data[ApiKeys.providers] as Map`. This can cause a runtime crash if the data is not in the expected format.
FIX: Use type-safe checks to validate the data structure before casting.
```dart
final result = await callable.call();
final data = result.data;
if (data is Map && data[ApiKeys.success] == true) {
  final providers = data[ApiKeys.providers];
  if (providers is Map) {
    return Map<String, dynamic>.from(providers);
  }
}
return {}; // Return default value on failure
```
---
SEVERITY: MEDIUM
FILE: lib/features/seller/seller_registration_view_model.dart
LINE: 106, 108, 110, 121, 130, 145, 148, 178, 181, 183, 185
ISSUE: Multiple user-facing error messages are hardcoded as string literals throughout the ViewModel. This prevents translation and makes maintenance difficult.
FIX: Replace all hardcoded error strings with translation keys from your localization files. For example, change `'Could not open Stripe Dashboard'` to `'errors.stripe_dashboard_failed'.tr()` and do the same for all other hardcoded strings.
---
SEVERITY: MEDIUM
FILE: lib/features/seller/warehouses_viewmodel.dart
LINE: 83, 87, 163-169
ISSUE: All user-facing error messages for validation and backend exceptions are hardcoded string literals, which prevents translation.
FIX: Replace all hardcoded strings in the validation logic and the `_parseError` method with translation keys (e.g., `'warehouses.errors.label_length'.tr()`). Use the `.tr()` extension to display localized messages to the user.
---
SEVERITY: LOW
FILE: lib/features/products/stock_notification_provider.dart
LINE: 53, 67
ISSUE: The `subscribe()` and `unsubscribe()` methods do not check if a user is logged in before attempting to call the Cloud Function. While the backend function is likely secured, it's best practice to fail early on the client.
FIX: At the beginning of both `subscribe()` and `unsubscribe()`, check for the current user and return early if they are null.
```dart
Future<void> subscribe() async {
  if (FirebaseAuth.instance.currentUser?.uid == null) {
    state = AsyncValue.error('User not logged in', StackTrace.current);
    return;
  }
  state = const AsyncValue.loading();
  // ... rest of the method
}
```
---
SEVERITY: LOW
FILE: lib/features/profile/address_viewmodel.dart
LINE: 52
ISSUE: The code uses the `!` (bang) operator to force-unwrap `state.selectedProvince`. While `selectedProvince` has a default value and is likely never null, using `!` can make code more brittle and harder to refactor safely.
FIX: Use a local variable and a null check to guard against a potential null value.
```dart
final province = state.selectedProvince;
if (province == null) {
  state = state.copyWith(errorMessage: 'profile.address.province_required'.tr());
  return;
}
final address = Address(state: province, ...);
```
---
SEVERITY: LOW
FILE: lib/features/seller/seller_account_status_viewmodel.dart
LINE: 12, 22
ISSUE: The error message 'Please log in to continue' is hardcoded. This prevents translation.
FIX: Replace the hardcoded string with a translation key and use `.tr()`. For example: `Exception('auth.login_required'.tr())`
---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 0     |
| HIGH     | 6     |
| MEDIUM   | 11    |
| LOW      | 11    |
| **Total**| **28**|

### Top Priorities

1. **buyer_orders_viewmodel.dart L35-39 (HIGH)** — `confirmingItemId` never cleared after success/failure; blocks all subsequent order confirmations. Immediate bug.
2. **seller_account_status_viewmodel.dart L36-39 (HIGH)** — Unsafe `as List<dynamic>` cast on API response will crash at runtime if key is missing or wrong type.
3. **seller_registration_view_model.dart L22-29 (HIGH)** — Double unsafe cast on Cloud Function result; can crash with any unexpected API shape.
4. **product_detail_viewmodel.dart L89-106 (HIGH)** — Direct Firestore access in ViewModel (arch violation) + silent error swallowing in `catch (_)`.
5. **edit_product_viewmodel.dart L235-311 (HIGH)** — Validation error strings not translated while `add_product_viewmodel.dart` correctly uses `.tr()` — inconsistency creates untranslated UX.
6. **seller_products_viewmodel.dart L66-69 (HIGH)** — Manual pluralization breaks for French/other languages; use `easy_localization`'s `.plural()`.

### Recurring Pattern: Hardcoded i18n Strings (MEDIUM/LOW)
Affects: `orders/` (4 instances), `products/` (3 instances), `profile/` (4 instances), `seller/` (10+ instances).
Bulk fix: run a grep for all hardcoded English strings in catch blocks and copyWith calls, then add translation keys.
