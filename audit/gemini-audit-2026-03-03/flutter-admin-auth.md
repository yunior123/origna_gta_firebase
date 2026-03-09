# Flutter Audit — features/admin + features/auth
**Date:** 2026-03-03
**Model:** gemini-2.5-pro
---

## Files Audited

**lib/features/admin/**
- admin_actions_viewmodel.dart
- admin_panel_screen.dart
- admin_providers.dart
- admin_repository.dart
- tabs/admin_orders_tab.dart
- tabs/admin_payment_providers_tab.dart
- tabs/admin_products_tab.dart
- tabs/admin_reviews_tab.dart
- tabs/admin_security_tab.dart
- tabs/admin_sellers_tab.dart
- tabs/admin_users_tab.dart

**lib/features/auth/**
- auth_provider.dart
- login_state.dart
- login_viewmodel.dart
- reset_password_state.dart
- reset_password_state.freezed.dart
- reset_password_view_model.dart

---

## Batch 1 Findings (files 1–15)

SEVERITY: CRITICAL
FILE: lib/features/admin/tabs/admin_security_tab.dart
LINE: 44
ISSUE: An unsafe dynamic cast is used to read the `mfaEnabled` property. The code uses `(userData as dynamic)?.mfaEnabled as bool? ?? false`, which bypasses static type checking. The `UserModel` (aliased from `User`) already has a type-safe `mfaEnabled` getter, making this cast unnecessary and dangerous. The comment above this line is outdated and incorrect.
FIX: Replace the unsafe cast with direct, type-safe property access. Change the line to: `_mfaEnabled = ref.read(userProfileProvider).valueOrNull?.mfaEnabled ?? false;`
---

SEVERITY: CRITICAL
FILE: lib/features/auth/reset_password_state.dart
LINE: 6
ISSUE: The file contains a syntax error: an invalid statement `@lib/models/generated/user_models.freezed.dart` exists between the `part` directive and the class definition. This makes the file un-compilable. Additionally, the class uses the `freezed` package's `with _$ResetPasswordState` mixin, which requires a corresponding generated part file (`reset_password_state.freezed.dart`) that is missing.
FIX: Remove the invalid line `@lib/models/generated/user_models.freezed.dart`. Then, run the build runner to generate the required `reset_password_state.freezed.dart` file using the command: `flutter pub run build_runner build --delete-conflicting-outputs`.
---

SEVERITY: HIGH
FILE: lib/features/admin/tabs/admin_payment_providers_tab.dart
LINE: 31-523
ISSUE: The entire widget contains numerous hardcoded user-facing strings for titles, descriptions, warnings, button labels, and dialog content. This prevents localization and makes maintenance difficult.
FIX: Replace every hardcoded string literal with a `'.tr()'` call and add the corresponding keys and values to the `assets/translations/` files. For example, change `Text('Enable Payment Provider')` to `Text('admin.payments.enable_title'.tr())`.
---

SEVERITY: HIGH
FILE: lib/features/admin/tabs/admin_products_tab.dart
LINE: 279-285, 307-333
ISSUE: The widget uses multiple hardcoded strings for UI elements, including the product approval status badge (`'Approved'`, `'Rejected'`, `'Under Review'`) and the product action menu (`'Approve Product'`, `'Reject Product'`, etc.). This prevents localization.
FIX: All user-facing strings must be replaced with keys and translated using `.tr()`. For example, `_ApprovalBadge` should receive a translation key and use `label.tr()`. The `_menuItem`s in `_ProductCard` should be passed translated labels.
---

SEVERITY: MEDIUM
FILE: lib/features/admin/admin_actions_viewmodel.dart
LINE: 50, 60, 70, 93, 104, 127, 138, 149
ISSUE: Methods in the view model use hardcoded English strings as fallback error messages (e.g., 'Failed to approve product'). These messages are not localized and will appear in English for all users regardless of their locale.
FIX: Replace the hardcoded strings with translation keys and use the `.tr()` extension method. For example: `errorMessage: AppError.getMessage(e, 'admin.errors.delete_product_failed'.tr())`.
---

SEVERITY: MEDIUM
FILE: lib/features/admin/tabs/admin_orders_tab.dart
LINE: 439-454
ISSUE: The `_formatDate` method manually constructs a date string using a hardcoded list of English month names (`'Jan'`, `'Feb'`, etc.). This is not locale-aware and will not format dates correctly for users in other regions.
FIX: Use the `DateFormat` class from the `intl` package to provide localized date formatting. Example: `return DateFormat.yMMMd(context.locale.toString()).format(date);`.
---

SEVERITY: MEDIUM
FILE: lib/features/admin/tabs/admin_sellers_tab.dart
LINE: 310
ISSUE: The `_formatDate` method uses `DateFormat` with a hardcoded format string ('MMM dd, yyyy'). This format is not appropriate for all locales and does not adapt to user preferences.
FIX: Use a locale-aware `DateFormat` constructor, such as `DateFormat.yMMMd(context.locale.toString()).format(date)`, which will adapt to the user's language and region.
---

SEVERITY: MEDIUM
FILE: lib/features/admin/tabs/admin_users_tab.dart
LINE: 411
ISSUE: The `_formatDate` method uses `DateFormat` with a hardcoded format string ('MMM dd, yyyy'), which is not locale-aware.
FIX: Use a locale-aware `DateFormat` constructor that respects the device's locale, for instance: `DateFormat.yMMMd(context.locale.toString()).format(date)`.
---

SEVERITY: MEDIUM
FILE: lib/features/admin/tabs/admin_reviews_tab.dart
LINE: 161
ISSUE: Date and time are formatted using `createdAt.toString().substring(0, 19)`. This is highly brittle and will crash if the string representation of the date changes length. It is also not localized.
FIX: Use the `DateFormat` class from the `intl` package for safe and localized date/time formatting. For example: `DateFormat.yMd(context.locale.toString()).add_jm().format(createdAt)`. Ensure `createdAt` is not null before formatting.
---

SEVERITY: MEDIUM
FILE: lib/features/admin/tabs/admin_reviews_tab.dart
LINE: 147-148
ISSUE: The string `'Product: ... • User: ...'` is constructed using string interpolation. This is not localizable.
FIX: Use a translated string with named arguments. Example: `'admin.reviews.metadata'.tr(namedArgs: {'productId': productId, 'userId': userId})`.
---

SEVERITY: MEDIUM
FILE: lib/features/admin/tabs/admin_users_tab.dart
LINE: 415-585
ISSUE: The `_handleAction` method shows multiple dialogs (`AlertDialog`) with hardcoded titles and content text for actions like making a user a seller or suspending a user. These strings are not translated.
FIX: Replace all hardcoded string literals in `AlertDialog` widgets with `'.tr()'` calls and add the corresponding keys to the translation files.
---

SEVERITY: MEDIUM
FILE: lib/features/admin/admin_panel_screen.dart
LINE: 272
ISSUE: The `IconButton` in the wide layout has a hardcoded tooltip: `tooltip: 'Back'`. This is not localized.
FIX: Replace the hardcoded string with a translation key: `tooltip: 'common.back'.tr()`.
---

SEVERITY: MEDIUM
FILE: lib/features/admin/tabs/admin_payment_providers_tab.dart
LINE: 512-518
ISSUE: The error handling logic in `_toggleProvider` relies on string matching (`errorMessage.contains('...')`) to identify specific errors. This is brittle and will break if the backend changes its error message format.
FIX: Refactor the backend to return distinct error codes. The client should check for these codes instead of parsing the error string. For example, catch a `PlatformException` and check `e.code == 'cannot-disable-all-providers'`.
---

SEVERITY: MEDIUM
FILE: lib/features/auth/login_viewmodel.dart
LINE: 172-177
ISSUE: The generic catch block in `handleAuth` parses the error's string representation (`e.toString().toLowerCase().contains(...)`) to identify the error type. This is unreliable and can fail if the error's string format changes.
FIX: Catch more specific exception types if possible (e.g., `PlatformException`). If the exception type is generic, inspect its `code` or `message` properties directly rather than converting the whole object to a string.
---

SEVERITY: LOW
FILE: lib/features/admin/admin_repository.dart
LINE: 43, 73, 76, 107
ISSUE: The repository methods use hardcoded default strings for reasons in function calls (e.g., `reason = 'Admin refund'`). While these may be for internal logs, using magic strings is poor practice.
FIX: Define these default reasons as `const` strings in a central place like `schema_constants.dart` to improve maintainability and avoid typos.
---

SEVERITY: LOW
FILE: lib/features/admin/admin_panel_screen.dart
LINE: 154, 172, 237-246, 269
ISSUE: The file uses `Colors.white`, `Colors.white60`, `Colors.transparent`, and `Colors.black.withValues(alpha: 0.04)` directly, bypassing the project's `DesignTokens` system.
FIX: Replace direct `Color` usage with equivalents from the `DesignTokens` class to ensure visual consistency. For example, use `DesignTokens.textOnPrimary` instead of `Colors.white` for text on a primary background.
---

SEVERITY: LOW
FILE: lib/features/admin/tabs/admin_products_tab.dart
LINE: 23, 115
ISSUE: The `_stockFilter` state variable uses magic strings like `'all'`, `'in_stock'`, and `'pending_review'` for filtering logic. This is prone to typos.
FIX: Define these filter values as `const` strings or, preferably, create an enum `ProductStockFilter` to ensure type safety.
---

SEVERITY: LOW
FILE: lib/features/admin/tabs/admin_users_tab.dart
LINE: 20, 114
ISSUE: The `_roleFilter` state variable uses magic strings like `'all'`, `'seller'`, `'admin'`, and `'buyer'`. This can lead to bugs from typos.
FIX: Use constants for these values. The `UserRoles` class already provides constants for roles, so `'all'` should be defined as a `const` string, e.g., `const kAllRolesFilter = 'all'`.
---

SEVERITY: LOW
FILE: lib/features/admin/admin_actions_viewmodel.dart
LINE: 107-112
ISSUE: The `fetchUserById` method has a broad `catch (_)` block that returns `null` without logging the error. This can make it difficult to debug issues with fetching user data.
FIX: While returning null is acceptable, the error should be logged to aid in debugging. Add a logging statement within the catch block, e.g., `print('Error fetching user $userId: $_');`
---

## Batch 2 Findings (files 16–17)

SEVERITY: MEDIUM
FILE: lib/features/auth/reset_password_view_model.dart
LINE: 45
ISSUE: When a new password reset attempt is initiated by calling `resetPassword`, the `isSuccess` flag from a previous successful attempt is not reset. If the user action succeeds, then they try again with invalid data (e.g., mismatched passwords), the state will contain both `isSuccess: true` and a new `errorMessage`. This can lead to a contradictory and confusing UI, potentially showing success and error messages simultaneously.
FIX: Reset the `isSuccess` flag at the beginning of any new password reset attempt. Update the validation failure blocks and the loading state update to explicitly set `isSuccess` to false. For example, change `state = state.copyWith(isLoading: true, errorMessage: null);` to `state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);`.
---

SEVERITY: MEDIUM
FILE: lib/features/auth/reset_password_view_model.dart
LINE: 33-36
ISSUE: The generic `catch (e)` block in the `_verifyCode` method hardcodes the error message to `'auth.reset_link_invalid'`. This is misleading if the underlying error is unrelated to the link itself, such as a network connection failure or other unexpected issue. The `resetPassword` method correctly uses a generic error message in its equivalent block, making the implementation inconsistent.
FIX: Use a generic error message for unknown errors to provide accurate feedback to the user. Change `errorMessage: 'auth.reset_link_invalid'.tr()` to `errorMessage: 'auth.errors.generic_error'.tr()`, which aligns with the error handling strategy elsewhere in the class.
---

SEVERITY: LOW
FILE: lib/features/auth/reset_password_view_model.dart
LINE: 24-27
ISSUE: The state update upon successful code verification in `_verifyCode` does not clear pre-existing error messages. If a previous operation (like a validation failure in `resetPassword`) had set an `errorMessage`, that error message would persist in the state even after the verification succeeds, potentially being displayed incorrectly in the UI.
FIX: Explicitly clear the `errorMessage` when the verification is successful to ensure a clean state. Change the state update to `state = state.copyWith(userEmail: email, isVerifying: false, errorMessage: null);`.
---

SEVERITY: LOW
FILE: lib/features/auth/reset_password_view_model.dart
LINE: 56-57
ISSUE: The Firebase `weak-password` error code is mapped to the same localization key (`'auth.validation.password_min_8'`) as the frontend password length validation. This is potentially confusing for the user. A password could satisfy the 8-character minimum length (e.g., "12345678") but still be rejected as weak by Firebase, causing an inaccurate error message about length to be displayed.
FIX: Differentiate the error messages. Create a new localization key, such as `'auth.validation.password_too_weak'`, and map the `weak-password` case to it: `case 'weak-password': return 'auth.validation.password_too_weak'.tr();`.
---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 2     |
| HIGH     | 2     |
| MEDIUM   | 12    |
| LOW      | 7     |
| **TOTAL**| **23**|

### Priority Actions
1. **admin_security_tab.dart:44** — unsafe `as dynamic` cast bypassing type system; fix immediately.
2. **reset_password_state.dart:6** — invalid syntax / missing freezed generated file; will not compile.
3. **admin_payment_providers_tab.dart** — entire screen missing `.tr()` calls; full i18n pass required.
4. **admin_products_tab.dart:279-333** — approval badge and action menu strings not localized.
5. **reset_password_view_model.dart:45** — `isSuccess` not cleared on retry; contradictory UI state.
