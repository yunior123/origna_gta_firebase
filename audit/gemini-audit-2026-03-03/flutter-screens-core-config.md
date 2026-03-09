# Flutter Audit — lib/screens/ + lib/core/ + lib/config/
**Date:** 2026-03-03
**Model:** gemini-2.5-pro
**Files audited:** 57 dart files (lib/screens/, lib/core/, lib/config/)
**Batches:** 4 (15 / 15 / 15 / 12 files)

---

## BATCH 1 — lib/config/ + lib/core/ (files 1–15)

SEVERITY: CRITICAL
FILE: lib/config/firebase_config_dev.dart
LINE: 5-11
ISSUE: Hardcoded API keys and project identifiers are present in the source code. These are sensitive credentials that should not be committed to version control.
FIX: Externalize these configurations. Use environment variables or a configuration file that is excluded from Git (e.g., via .gitignore) to load these values at runtime. For Flutter, you can use `.env` files with `flutter_dotenv` or compile-time variables with `--dart-define`.
---
SEVERITY: CRITICAL
FILE: lib/config/firebase_config_prod.dart
LINE: 8-46
ISSUE: Hardcoded API keys and project identifiers for production are present in the source code. These are sensitive credentials that should not be committed to version control. Exposing production keys is a major security risk.
FIX: Externalize these configurations immediately. Use environment variables or a secure secret management service (like GCP Secret Manager or AWS Secrets Manager) to load these values at runtime. For Flutter, you can use compile-time variables with `--dart-define` which is a secure way to handle secrets.
---
SEVERITY: CRITICAL
FILE: lib/config/firebase_config_staging.dart
LINE: 5-11
ISSUE: Hardcoded API keys and project identifiers for the staging environment are present in the source code. These are sensitive credentials that should not be committed to version control.
FIX: Externalize these configurations. Use environment variables or a configuration file that is excluded from Git (e.g., via .gitignore) to load these values at runtime. For Flutter, you can use `.env` files with `flutter_dotenv` or compile-time variables with `--dart-define`.
---
SEVERITY: CRITICAL
FILE: lib/core/repositories/product_repository.dart
LINE: 227-229
ISSUE: The `getAutocompleteSuggestions` method in `FirebaseProductRepository` contains a hardcoded API key for the Geoapify service. This is a major security vulnerability as the key can be extracted from the compiled application.
FIX: The API key must be removed from the source code. Since this is a client-side repository, making a direct call to a third-party service with a secret key is insecure. The call should be proxied through a backend service (like a Cloud Function) that can securely store and use the API key. The `GeoapifyLocationRepository` already does this for address suggestions; this should be done for product autocomplete as well.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 35
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'aliexpress' uses a hardcoded `Color(0xFFE62E04)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFE62E04)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 47
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'alibaba' uses a hardcoded `Color(0xFFFF6A00)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFFF6A00)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 59
ISSUE: The `color` property of the `SupplierPlatformConfig` for '1688' uses a hardcoded `Color(0xFFFF4400)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFFF4400)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 71
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'dhgate' uses a hardcoded `Color(0xFF1E88E5)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF1E88E5)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 83
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'temu' uses a hardcoded `Color(0xFFFB7701)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFFB7701)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 95
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'made_in_china' uses a hardcoded `Color(0xFF2196F3)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF2196F3)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 107
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'global_sources' uses a hardcoded `Color(0xFF00ACC1)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF00ACC1)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 120
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'cjdropshipping' uses a hardcoded `Color(0xFF4CAF50)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF4CAF50)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 133
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'spocket' uses a hardcoded `Color(0xFF9C27B0)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF9C27B0)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 146
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'printful' uses a hardcoded `Color(0xFFE91E63)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFE91E63)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 159
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'printify' uses a hardcoded `Color(0xFF00BCD4)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF00BCD4)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 172
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'gmarket' uses a hardcoded `Color(0xFFE53935)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFE53935)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 184
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'coupang' uses a hardcoded `Color(0xFF6A1B9A)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF6A1B9A)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 197
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'rakuten' uses a hardcoded `Color(0xFFBF0000)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFBF0000)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 209
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'amazon_japan' uses a hardcoded `Color(0xFFFF9900)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFFF9900)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 222
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'indiamart' uses a hardcoded `Color(0xFF1565C0)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF1565C0)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 234
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'tradeindia' uses a hardcoded `Color(0xFFFF5722)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFFF5722)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 247
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'faire' uses a hardcoded `Color(0xFF000000)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF000000)` with a corresponding color from the `DesignTokens` class, like `DesignTokens.black`.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 260
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'amazon_europe' uses a hardcoded `Color(0xFFFF9900)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFFF9900)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 273
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'amazon_usa' uses a hardcoded `Color(0xFFFF9900)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFFF9900)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 285
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'walmart' uses a hardcoded `Color(0xFF0071DC)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF0071DC)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 297
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'costco' uses a hardcoded `Color(0xFFE31837)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFE31837)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 310
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'local' uses a hardcoded `Color(0xFFD32F2F)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFD32F2F)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 323
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'etsy_wholesale' uses a hardcoded `Color(0xFFEB6D20)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFFEB6D20)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 337
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'oberlo' uses a hardcoded `Color(0xFF9E9E9E)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF9E9E9E)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 351
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'custom' uses a hardcoded `Color(0xFF607D8B)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF607D8B)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: HIGH
FILE: lib/core/config/supplier_config.dart
LINE: 363
ISSUE: The `color` property of the `SupplierPlatformConfig` for 'other' uses a hardcoded `Color(0xFF9E9E9E)` instead of a value from `DesignTokens`. This violates the project's design system conventions.
FIX: Replace `Color(0xFF9E9E9E)` with a corresponding color from the `DesignTokens` class. If a suitable color does not exist, one should be added to maintain a centralized design system.
---
SEVERITY: MEDIUM
FILE: lib/core/repositories/user_repository.dart
LINE: 191
ISSUE: The hardcoded string literal '• ' is used for formatting the pending requirements description. This is not localizable and may not be ideal for all platforms or locales.
FIX: Use a localizable approach for joining the list items. For example, `descriptions.toSet().map((d) => '• $d').join('\n')`. The bullet point and separator should ideally come from a localized resource file.
---
SEVERITY: MEDIUM
FILE: lib/core/repositories/product_repository.dart
LINE: 379
ISSUE: The exception message 'product.image_upload_failed' is a hardcoded string that is expected to be a localization key. This couples the repository layer with the presentation layer's localization mechanism.
FIX: Repositories should throw domain-specific exceptions, not localization keys. Create a specific exception class, e.g., `ImageUploadFailedException`, and throw that instead. The UI/ViewModel layer can then catch this specific exception and show the appropriate localized message to the user.
---
SEVERITY: MEDIUM
FILE: lib/core/repositories/product_repository.dart
LINE: 393
ISSUE: The exception message 'product.video_upload_failed' is a hardcoded string that is expected to be a localization key. This couples the repository layer with the presentation layer's localization mechanism.
FIX: Repositories should throw domain-specific exceptions, not localization keys. Create a specific exception class, e.g., `VideoUploadFailedException`, and throw that instead. The UI/ViewModel layer can then catch this specific exception and show the appropriate localized message to the user.
---
SEVERITY: LOW
FILE: lib/core/repositories/location_repository.dart
LINE: 16-17
ISSUE: The code uses `print()` for logging an error. In a production app, a dedicated logging framework (like `logger` or `FirebaseCrashlytics`) should be used to properly categorize and report errors.
FIX: Replace `print()` with a call to a proper logging service. For example, `Logger().e('get_address_suggestions CF failed: $e')` or `FirebaseCrashlytics.instance.recordError(e, stack)`.
---
SEVERITY: LOW
FILE: lib/core/repositories/auth_repository.dart
LINE: 135
ISSUE: A failure to send a verification email is caught and printed to the debug console, but the error is not re-thrown or handled in a way that would inform the user. The user will not know that the email failed to send.
FIX: The exception should be re-thrown or a result object should be returned to the caller. This allows the UI layer to inform the user that the verification email could not be sent and they should try again. Printing to debug console is not sufficient for user-facing operations.
---
SEVERITY: LOW
FILE: lib/core/routes.dart
LINE: 31
ISSUE: The route `sellerSetup` is commented out with the note "screen not implemented". This is dead code.
FIX: Remove the commented-out `sellerSetup` route and the associated comment to clean up the code.
---

## BATCH 2 — lib/screens/ addproduct through editproduct (files 16–30)

SEVERITY: HIGH
FILE: lib/screens/categories_screen.dart
LINE: 27-50
ISSUE: The `_categoryColors` list contains 21 hardcoded `LinearGradient` color pairs. This directly violates the project mandate to use `DesignTokens` for all colors and avoids the benefits of a centralized design system. Hardcoding colors makes theme changes difficult, leads to inconsistency, and bloats the widget with configuration data.
FIX: Move this color list to the `DesignTokens` class as a static list of gradients, e.g., `DesignTokens.categoryGradients`. The screen can then access this list, keeping the color definitions centralized.
---
SEVERITY: HIGH
FILE: lib/screens/editproduct_screen.dart
LINE: 80-99
ISSUE: The `_provinceNames` map is a hardcoded duplication of province data. The `lib/core/schema/schema_constants.dart` file already contains a canonical `ProvinceCodeValues.names` map for this exact purpose. This duplication can lead to inconsistencies if one is updated and the other is not.
FIX: Remove the local `_provinceNames` map entirely. Use the single source of truth from `lib/core/schema/schema_constants.dart` by referencing `ProvinceCodeValues.names` where needed.
---
SEVERITY: HIGH
FILE: lib/screens/editproduct_screen.dart
LINE: 53-68
ISSUE: The `_EditDigitalTypeChip` widget uses `Theme.of(context).colorScheme` for its styling (e.g., `primaryContainer`, `primary`). This bypasses the app's design system defined in `DesignTokens`. All UI components should exclusively use `DesignTokens` to ensure visual consistency and easy theming.
FIX: Replace all `Theme.of(context).colorScheme` calls with the appropriate constants from the `DesignTokens` class (e.g., `DesignTokens.primaryContainer`, `DesignTokens.primary`).
---
SEVERITY: MEDIUM
FILE: lib/core/schema/schema_constants.dart
LINE: 999
ISSUE: The field constant `new_roles` is defined using snake_case. This violates the file's own documented naming convention which states, "Dart constants: camelCase (e.g., createdAt)" and "Firestore fields: camelCase (e.g., 'createdAt')".
FIX: Rename the constant to `newRoles` to conform to the established camelCase convention for Dart constants. The string value should also likely be `'newRoles'` to match the Firestore field convention. If the backend requires `'new_roles'`, the constant should still be `newRoles` while the value remains `new_roles`.
---
SEVERITY: MEDIUM
FILE: lib/screens/addproduct_screen.dart
LINE: 147, 154, 198
ISSUE: The file contains multiple instances of hardcoded `Colors.white.withValues(alpha: 0.xx)` and other direct `Color` instantiations (e.g., for the French flag section). This violates the principle of using a centralized design system (`DesignTokens`) for all UI colors, making the app harder to theme and maintain.
FIX: Replace all hardcoded `Color` and `Colors` values with appropriate constants from the `DesignTokens` class. If transparent or variant colors are needed, they should be added to the `DesignTokens` system (e.g., `DesignTokens.primary.withOpacity(0.1)` or `DesignTokens.white15`).
---
SEVERITY: MEDIUM
FILE: lib/screens/addressmanagement_screen.dart
LINE: 226-227
ISSUE: The `PopupMenuButton` icon color is hardcoded using `isDark ? Colors.white70 : Colors.black54`. This bypasses the `DesignTokens` system and will not adapt correctly to theme changes.
FIX: Replace the hardcoded colors with appropriate constants from `DesignTokens`, such as `DesignTokens.textSecondary` or `DesignTokens.textDisabled`.
---
SEVERITY: MEDIUM
FILE: lib/core/schema/schema_constants.dart
LINE: 835
ISSUE: The constant `supportEmail` is defined as `'support @orignaventures.ca'`. The space after the `@` symbol will cause email validation or `mailto:` links to fail if this constant is used directly in application logic.
FIX: Remove the space from the email string to be `'support@orignaventures.ca'`. If the space was added to prevent scraping from the source code, a comment should clarify this, and the value should never be used directly in code without removing the space first.
---
SEVERITY: LOW
FILE: lib/screens/addressmanagement_screen.dart
LINE: 40
ISSUE: The maximum address count is hardcoded as `10` directly in the build method. This "magic number" makes the business rule difficult to find and update.
FIX: Move the address limit to `lib/core/schema/schema_constants.dart` under the `BusinessRules` class as a new constant, e.g., `static const maxUserAddresses = 10;`. Reference this constant in the widget.
---
SEVERITY: LOW
FILE: lib/screens/cart_screen.dart
LINE: 312, 420
ISSUE: The `NumberFormat` constructors use hardcoded locale and currency symbol strings: `"en_CA"` and `"CAD \$"`. These should be sourced from a central configuration or localization provider to support multiple regions or currencies in the future.
FIX: Abstract these values into constants, ideally within a localization or configuration file, and reference the constants here.
---
SEVERITY: LOW
FILE: lib/screens/chat_conversations_screen.dart
LINE: 225-230
ISSUE: The `_formatTime` function uses hardcoded strings (`'now'`, `'m'`, `'h'`, `'d'`) for relative time formatting. These strings are not localized and will not be translated for users with different language settings.
FIX: Replace the hardcoded strings with localized versions using the `easy_localization` package, for example: `'chat.time_now'.tr()`, `'chat.time_minutes'.tr(namedArgs: {'minutes': diff.inMinutes.toString()})`, etc.
---
SEVERITY: LOW
FILE: lib/screens/addproduct_screen.dart
LINE: 2012, 2020
ISSUE: The file defines its previews using `@lib/previews/premium_paywall_preview.dart`. This creates an unnecessary dependency where a screen's previews are located in another feature's file. It suggests a disorganized preview setup.
FIX: Create a dedicated preview file for the Add Product screen, such as `@lib/previews/addproduct_screen_preview.dart`, and move these preview definitions there to improve modularity.
---
SEVERITY: LOW
FILE: lib/screens/checkout_screen.dart
LINE: 1105
ISSUE: The `_TermsText` widget hardcodes a URL for the terms of service (`https://www.orignagta.ca/buyer-protection`). This should be defined in a central constants file to avoid magic strings and make it easier to update.
FIX: Move the URL to the `ExternalUrls` class in `lib/core/schema/schema_constants.dart` and reference the constant here.
---
SEVERITY: LOW
FILE: lib/screens/cart_screen.dart
LINE: 622
ISSUE: The `CartItemDetailModelExtension` provides a `copyWith` method. The model appears to be generated (based on its location and other conventions). Generated data classes (e.g., from Freezed) typically already include a `copyWith` implementation, making this extension potentially redundant and a source of confusion.
FIX: Verify if the `CartItemDetailModel` class has a generated `copyWith` method. If it does, remove this extension. If it does not, consider using a code generation package like `freezed` to automatically create it and other boilerplate.
---

## BATCH 3 — lib/screens/ favorites through profile (files 31–45)

SEVERITY: HIGH
FILE: lib/screens/main_screen.dart
LINE: 31-38
ISSUE: A 3-second safety timeout is implemented to prevent an infinite loading screen if the `userProfileProvider` is slow. This is a workaround, not a fix for the potential root cause of the provider hanging. It suggests that the underlying data fetch from Firestore might be unreliable or slow, and while this improves UX by preventing a hang, it masks a deeper architectural or performance issue.
FIX: Investigate the `userProfileProvider` and its dependencies (e.g., the auth repository, Firestore connection) to identify and fix the root cause of the potential delay. Remove the timeout mechanism once the provider is reliable.
---
SEVERITY: MEDIUM
FILE: lib/screens/home_screen.dart
LINE: 115
ISSUE: Hardcoded `Colors.white` is used for the icon color on the "Add Product" button. This bypasses the app's design token system, making it difficult to manage themes and ensure consistency.
FIX: Replace `color: Colors.white` with a theme-appropriate token from `DesignTokens`, such as `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/home_screen.dart
LINE: 192
ISSUE: Hardcoded `Colors.white` is used for the shopping cart icon color. This should be a value from the design token system to support theming.
FIX: Replace `color: Colors.white` with a suitable token like `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/home_screen.dart
LINE: 212
ISSUE: The cart item count badge background is a hardcoded `Colors.white`.
FIX: Replace `color: Colors.white` with a design token, for example `DesignTokens.surface` or a specific badge background color token if available.
---
SEVERITY: MEDIUM
FILE: lib/screens/home_screen.dart
LINE: 661
ISSUE: The AppBar's leading icon has a hardcoded `color: Colors.white`.
FIX: Use a design token for icon colors on a primary background, like `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/home_screen.dart
LINE: 673-678
ISSUE: The AppBar title's `ShaderMask` uses a `LinearGradient` with hardcoded `Colors.white`. The text style also specifies a hardcoded `color: Colors.white`.
FIX: Replace hardcoded `Colors.white` with design tokens. The gradient should use tokens, and the text style should use a token like `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/home_screen.dart
LINE: 1046
ISSUE: The settings button icon color is a hardcoded `Colors.white`.
FIX: Use `DesignTokens.textOnPrimary` or a similar token for the icon color.
---
SEVERITY: MEDIUM
FILE: lib/screens/login_screen.dart
LINE: 78
ISSUE: The hero logo in the login screen uses a hardcoded `color: Colors.white`.
FIX: Replace `color: Colors.white` with a design token like `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/login_screen.dart
LINE: 86
ISSUE: The app title on the login screen uses a hardcoded `color: Colors.white` in its `TextStyle`.
FIX: Replace `color: Colors.white` with `DesignTokens.textOnPrimary` or a similar token.
---
SEVERITY: MEDIUM
FILE: lib/screens/login_screen.dart
LINE: 310
ISSUE: The app tagline in the desktop view of the login screen uses a hardcoded `color: Colors.white`.
FIX: Use a design token for the text color, such as `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/login_screen.dart
LINE: 321
ISSUE: The checkmark icon in the feature list on the desktop login view has a hardcoded `color: Colors.white`.
FIX: Replace `color: Colors.white` with `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/login_screen.dart
LINE: 414
ISSUE: The "Send" button in the forgot password dialog uses a hardcoded `foregroundColor: Colors.white`.
FIX: Replace `foregroundColor: Colors.white` with a design token like `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/login_screen.dart
LINE: 415
ISSUE: The loading indicator within the "Send" button uses a hardcoded `color: Colors.white`.
FIX: Use a design token for the indicator color, e.g., `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/notifications_screen.dart
LINE: 215
ISSUE: A `BoxShadow` uses a hardcoded `Colors.black.withValues(alpha: isDark ? 0.15 : 0.04)`.
FIX: Replace the hardcoded black color with a shadow color defined in `DesignTokens`.
---
SEVERITY: MEDIUM
FILE: lib/screens/notifications_screen.dart
LINE: 268
ISSUE: The background color for a read notification tile is hardcoded to `Colors.white` in light mode.
FIX: Replace `Colors.white.withValues(alpha: 0.9)` with a theme-appropriate token from `DesignTokens`, such as `DesignTokens.surface`.
---
SEVERITY: MEDIUM
FILE: lib/screens/ordersuccess_screen.dart
LINE: 101
ISSUE: The "Order Placed" title text uses a hardcoded `color: Colors.white`.
FIX: Use `DesignTokens.textOnPrimary` or a similar design token for the text color.
---
SEVERITY: MEDIUM
FILE: lib/screens/ordersuccess_screen.dart
LINE: 160
ISSUE: The total price text style in the order summary has a hardcoded `color: Colors.white`.
FIX: Replace `color: Colors.white` with a design token like `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/ordersuccess_screen.dart
LINE: 300-303
ISSUE: The `_Particle` factory uses a hardcoded list of `Color` objects for the confetti animation. While decorative, these colors are not part of the theme system.
FIX: Move these colors into `DesignTokens` as a list of accent or confetti colors (e.g., `DesignTokens.confettiColors`) to make them configurable.
---
SEVERITY: MEDIUM
FILE: lib/screens/payment_screens.dart
LINE: 102
ISSUE: The title text on the timeout fallback screen uses a hardcoded `color: isDark ? Colors.white : DesignTokens.textPrimary`.
FIX: Replace `Colors.white` with `DesignTokens.textOnDark` or a similar token.
---
SEVERITY: MEDIUM
FILE: lib/screens/payment_screens.dart
LINE: 150
ISSUE: The loading indicator in the `_ConfirmingPaymentView` uses a hardcoded `color: Colors.white`.
FIX: Use a design token like `DesignTokens.textOnPrimary` for the indicator color.
---
SEVERITY: MEDIUM
FILE: lib/screens/payment_screens.dart
LINE: 156
ISSUE: The message text in `_ConfirmingPaymentView` uses a hardcoded `color: widget.isDark ? Colors.white : DesignTokens.textPrimary`.
FIX: Replace `Colors.white` with `DesignTokens.textOnDark`.
---
SEVERITY: MEDIUM
FILE: lib/screens/payment_screens.dart
LINE: 207
ISSUE: The title on the `PaymentCanceledScreen` uses a hardcoded `color: isDark ? Colors.white : DesignTokens.textPrimary`.
FIX: Replace `Colors.white` with `DesignTokens.textOnDark`.
---
SEVERITY: MEDIUM
FILE: lib/screens/product_card_screen.dart
LINE: 66
ISSUE: The `ProductCard` container uses a hardcoded `color: isDark ? DesignTokens.darkCard : Colors.white`.
FIX: Replace `Colors.white` with `DesignTokens.surface` to adhere to the app's theming.
---
SEVERITY: MEDIUM
FILE: lib/screens/product_card_screen.dart
LINE: 132
ISSUE: The `ColorFilter` for an out-of-stock product image uses a hardcoded `Colors.grey`.
FIX: Use a color from `DesignTokens` intended for disabled or unavailable states, for example `DesignTokens.disabled`.
---
SEVERITY: MEDIUM
FILE: lib/screens/product_card_screen.dart
LINE: 148
ISSUE: The camera icon used as a placeholder has a hardcoded `color: Colors.white.withValues(alpha: 0.8)`.
FIX: Replace `Colors.white` with `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/product_card_screen.dart
LINE: 156
ISSUE: The out-of-stock overlay uses a hardcoded `color: Colors.black.withValues(alpha: 0.3)`.
FIX: Use a scrim or overlay color from `DesignTokens`.
---
SEVERITY: MEDIUM
FILE: lib/screens/product_card_screen.dart
LINE: 223
ISSUE: The `Material` widget for the favorite button has a hardcoded `color: Colors.white`.
FIX: Use `DesignTokens.surface` or a similar token for the background color.
---
SEVERITY: MEDIUM
FILE: lib/screens/product_card_screen.dart
LINE: 306
ISSUE: The product name text uses a hardcoded `color: isDark ? Colors.white : DesignTokens.textPrimary`.
FIX: Replace `Colors.white` with `DesignTokens.textOnDark`.
---
SEVERITY: MEDIUM
FILE: lib/screens/product_card_screen.dart
LINE: 400
ISSUE: The "Add to Cart" button icon uses a hardcoded `color: Colors.white`.
FIX: Use `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/product_card_screen.dart
LINE: 442
ISSUE: The "Delete" button in the delete confirmation dialog uses `foregroundColor: Colors.white`.
FIX: Replace the hardcoded color with a token like `DesignTokens.textOnDanger` or `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/product_card_screen.dart
LINE: 926-930
ISSUE: The `_RankBadge` widget uses hardcoded `Color` values for the gold, silver, and bronze rank gradients.
FIX: Move these rank-specific colors into `DesignTokens` (e.g., `DesignTokens.rankGoldStart`, `DesignTokens.rankGoldEnd`) to centralize color definitions.
---
SEVERITY: MEDIUM
FILE: lib/screens/product_card_screen.dart
LINE: 961
ISSUE: The `_TrendingBadge` widget uses a hardcoded `Color(0xFFFF3D00)` for the "HOT" gradient.
FIX: Add this color to `DesignTokens` (e.g., `DesignTokens.trendingHotEnd`) to avoid magic values in the UI code.
---
SEVERITY: MEDIUM
FILE: lib/screens/productaddimages_screen.dart
LINE: 164
ISSUE: The "Cover" badge on the primary product image uses a hardcoded `color: Colors.white`.
FIX: Use `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/productaddimages_screen.dart
LINE: 185
ISSUE: The remove button on the image tile uses a hardcoded `boxShadow` with `Colors.black` and an icon with `color: Colors.white`.
FIX: The shadow color should come from `DesignTokens`, and the icon color should be `DesignTokens.textOnDanger` or similar.
---
SEVERITY: MEDIUM
FILE: lib/screens/productaddvideo_screen.dart
LINE: 141
ISSUE: The `_VideoTile` container uses a hardcoded `color: Colors.black87`.
FIX: Use a color from `DesignTokens` for dark backgrounds or overlays, like `DesignTokens.scrim` or `DesignTokens.darkSurface`.
---
SEVERITY: MEDIUM
FILE: lib/screens/productaddvideo_screen.dart
LINE: 153
ISSUE: The "Video" badge on the video tile has a background of `Colors.black.withValues(alpha: 0.6)` and `color: Colors.white`.
FIX: Use tokens for the overlay background and text color, like `DesignTokens.scrim` and `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/productdetails_screen.dart
LINE: 117
ISSUE: The "play" icon on the video thumbnail has a hardcoded `color: Colors.white`.
FIX: Use `DesignTokens.textOnPrimary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/productdetails_screen.dart
LINE: 182
ISSUE: The product name title text style includes a hardcoded `color: Colors.white`.
FIX: Use `DesignTokens.textOnPrimary` or a similar token.
---
SEVERITY: MEDIUM
FILE: lib/screens/productdetails_screen.dart
LINE: 223-235
ISSUE: The price display section uses multiple hardcoded `Colors.white` and `Colors.white70` values.
FIX: Replace these with appropriate design tokens, such as `DesignTokens.textOnPrimary` and `DesignTokens.textOnPrimary.withOpacity(0.7)`.
---
SEVERITY: MEDIUM
FILE: lib/screens/productdetails_screen.dart
LINE: 368
ISSUE: The `barrierColor` for the video player dialog is a hardcoded `Colors.black`.
FIX: Use a scrim color from `DesignTokens`, such as `DesignTokens.scrim` or `DesignTokens.darkSurface`.
---
SEVERITY: MEDIUM
FILE: lib/screens/productdetails_screen.dart
LINE: 834
ISSUE: The `_QACard` widget uses `isDark ? Colors.grey.shade900 : Colors.white` for its background.
FIX: Replace the hardcoded colors with `DesignTokens.darkCard` (or `darkSurface`) and `DesignTokens.surface` respectively.
---
SEVERITY: MEDIUM
FILE: lib/screens/productdetails_screen.dart
LINE: 1500
ISSUE: The text style for the product description uses `isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary`. Using an outline color for text is semantically incorrect and may lead to poor contrast or unintended visual appearance.
FIX: Replace `DesignTokens.outlineVariant` with a proper text color token for dark mode, such as `DesignTokens.textOnDark` or `DesignTokens.textOnDarkSecondary`.
---
SEVERITY: MEDIUM
FILE: lib/screens/profile_screen.dart
LINE: 68
ISSUE: The background gradient for the `ProfileScreen` body uses a hardcoded `Colors.white` for the light theme.
FIX: Replace `Colors.white` with `DesignTokens.surface` or another appropriate background token.
---
SEVERITY: MEDIUM
FILE: lib/screens/profile_screen.dart
LINE: 980
ISSUE: The `_ThemePill` widget uses a hardcoded `color: selected ? Colors.white : DesignTokens.textSecondary`.
FIX: Replace `Colors.white` with a token for text on a primary background, like `DesignTokens.textOnPrimary`.
---
SEVERITY: LOW
FILE: lib/screens/profile_screen.dart
LINE: 960
ISSUE: The `_checkVerification` method contains a `print` statement (`print('User is not null, reloading...')`) which is likely for debugging and should be removed from production code.
FIX: Remove the `print` statement. Use a proper logging service if detailed logging is needed in development or production environments.
---
SEVERITY: LOW
FILE: lib/screens/product_card_screen.dart
LINE: 164
ISSUE: The out-of-stock label uses a hardcoded `color: Colors.white`.
FIX: Replace `color: Colors.white` with `DesignTokens.textOnPrimary` or `textOnDark`.
---
SEVERITY: LOW
FILE: lib/screens/product_card_screen.dart
LINE: 175
ISSUE: The image count indicator on the product card uses a hardcoded background `color: Colors.black.withValues(alpha: 0.5)`.
FIX: Use a scrim or overlay color from `DesignTokens`.
---
SEVERITY: LOW
FILE: lib/screens/productaddvideo_screen.dart
LINE: 104
ISSUE: The `_initializeVideo` method has a `debugPrint` statement. This should be removed from production code.
FIX: Remove the `debugPrint('Error initializing video: $e');` call. Use a formal logging service for error tracking.
---
SEVERITY: LOW
FILE: lib/screens/productdetails_screen.dart
LINE: 357
ISSUE: The close button in the image dialog uses a hardcoded background `color: Colors.black.withValues(alpha: 0.5)` and icon `color: Colors.white`.
FIX: Replace with `DesignTokens.scrim` and `DesignTokens.textOnPrimary` respectively.
---
SEVERITY: LOW
FILE: lib/screens/profile_screen.dart
LINE: 651-754
ISSUE: The `_buildProfileHeader` widget contains numerous hardcoded `Colors.white` and `Colors.white.withValues(alpha: ...)` for text, borders, and backgrounds.
FIX: Systematically replace all instances of hardcoded white colors with their semantic equivalents from `DesignTokens` (e.g., `DesignTokens.textOnPrimary`, `DesignTokens.textOnPrimary.withOpacity(0.7)`, `DesignTokens.borderOnPrimary`).
---
SEVERITY: LOW
FILE: lib/screens/profile_screen.dart
LINE: 938
ISSUE: The `_resendEmail` function has a hardcoded error message string: `'Please wait before requesting another email.'`.
FIX: Move this string to the localization file and retrieve it with `.tr()` to support internationalization. For example: `'errors.too_many_requests'.tr()`
---

## BATCH 4 — lib/screens/ seller/shipping/subscription/terms (files 46–57)

SEVERITY: CRITICAL
FILE: lib/screens/seller_registration_screen.dart
LINE: 226-227
ISSUE: The check for `payoutsEnabled` is directly assigned from `chargesEnabled`. The comment mentions this is an implication from the `SellerAccountStatus` model, but this makes the code brittle and hard to understand. If the underlying Stripe logic or the model changes, this could lead to a state where a seller cannot receive payouts but the UI indicates they can, or vice-versa.
FIX: The `SellerAccountStatus` model should have a distinct boolean getter `isFullyEnabled` or `canTransact` that correctly encapsulates the logic `chargesEnabled && payoutsEnabled`. The UI should read this single, clear property from the view model to determine the account status, rather than recreating the logic. If `payoutsEnabled` is a separate field, it should be checked explicitly.
---
SEVERITY: CRITICAL
FILE: lib/screens/seller_integration_screen.dart
LINE: 407, 442
ISSUE: The Swift and Python code snippets for sellers have the API endpoint URL (`$activateEndpoint`) hardcoded directly within the string. When a seller copies this code, it will contain a non-functional URL literal instead of the actual dynamic endpoint.
FIX: The code snippets should be rewritten to accept the endpoint URL as a function parameter. For example, in Python: `def activate_license(key: str, endpoint_url: str, ...):` and update the call to `requests.post(endpoint_url, ...)`. Clearly label in the UI that the seller must pass their specific endpoint URL to the function.
---
SEVERITY: HIGH
FILE: lib/screens/subscription_success_screen.dart
LINE: 254
ISSUE: The `_startTimeout` function creates a 30-second timer that calls `setState` when it completes. If the user navigates away from the screen and the widget is disposed before the timer fires, calling `setState` will result in a runtime error ("setState() called after dispose()").
FIX: Add a check within the timer's callback to ensure the widget is still mounted before calling `setState`. Change `_activationTimeout = Timer(const Duration(seconds: 30), () => setState(() => _timedOut = true));` to `_activationTimeout = Timer(const Duration(seconds: 30), () { if (mounted) setState(() => _timedOut = true); });`.
---
SEVERITY: HIGH
FILE: lib/screens/seller_orders_screen.dart
LINE: 258
ISSUE: The `_UnansweredQaBadge` widget's `onPressed` action incorrectly navigates to the seller products screen (`AppRoutes.sellerProducts`) instead of a screen for managing questions and answers. This provides a confusing user experience, as the UI element for "questions" does not lead to a place to answer them.
FIX: The `onPressed` callback should navigate to a dedicated Q&A management screen. If one does not exist, this feature should be implemented or the badge should be removed to avoid confusion. The navigation should be `Navigator.pushNamed(context, AppRoutes.sellerQaManagement);` (assuming such a route exists).
---
SEVERITY: HIGH
FILE: lib/screens/seller_products_screen.dart
LINE: 335
ISSUE: The `_UnansweredQaBadge` widget's `onPressed` action incorrectly navigates to the seller orders screen (`AppRoutes.sellerOrders`). This creates a navigation loop with the badge on the orders screen, which navigates back to the products screen. The user is trapped between two screens if they click these badges.
FIX: The `onPressed` callback should navigate to a dedicated Q&A management screen. The navigation should be `Navigator.pushNamed(context, AppRoutes.sellerQaManagement);` (assuming such a route exists). This makes the badge's behavior consistent and correct across the app.
---
SEVERITY: HIGH
FILE: lib/screens/terms_screen.dart
LINE: 422-423
ISSUE: The `_buildSectionBody` widget uses hardcoded hex colors (`const Color(0xFF4A4A5A)` and `const Color(0xFF6A6A7A)`). This violates the project's convention of using the centralized `DesignTokens` class for all colors, making the app's theme inconsistent and harder to maintain.
FIX: Replace the hardcoded `Color` instances with appropriate values from `DesignTokens`. For example, replace `const Color(0xFF4A4A5A)` with `DesignTokens.textPrimary` or `DesignTokens.textSecondary` depending on the desired appearance in both light and dark modes.
---
SEVERITY: HIGH
FILE: lib/screens/seller/seller_warehouses_screen.dart
LINE: 153-155
ISSUE: The `onSave` callback in `_showWarehouseForm` is implemented with an `assert(false)`, indicating it should never be called. This is a potential bug, as any accidental use would crash the app in debug mode and fail silently in release. The form should not expose a callback that is explicitly meant to be non-functional.
FIX: Remove the `onSave` parameter entirely from the `_WarehouseFormSheet` widget and its constructor. The form should only use the `onSaveFull` callback, which is correctly implemented. This makes the component's API safer and less confusing.
---
SEVERITY: MEDIUM
FILE: lib/screens/seller_registration_screen.dart
LINE: 70
ISSUE: The `PaymentProviderConfig` class and its `availablePaymentProviders` list contain multiple user-facing strings (e.g., `name`, `payoutTiming`, `features`, `recommendedFor`) that are hardcoded. These strings are not internationalized using `.tr()`, which means they will not be translated for users in different locales.
FIX: All user-facing strings in the `PaymentProviderConfig` and the `availablePaymentProviders` list must be replaced with translation keys and have `.tr()` called on them. For example, `name: 'Stripe'` should become `name: 'providers.stripe_name'.tr()`.
---
SEVERITY: MEDIUM
FILE: lib/screens/terms_screen.dart
LINE: 62
ISSUE: The screen file contains business logic for parsing and formatting the terms content (`_parseSections`, `_iconForSection`, `_titleCase`). This violates the MVVM architecture by mixing view logic with data transformation logic. It makes the code harder to test and maintain.
FIX: Move the parsing and formatting logic into a dedicated `TermsViewModel` or a helper class. The screen should receive the already-parsed `List<_TermsSection>` from the provider, not the raw string.
---
SEVERITY: MEDIUM
FILE: lib/screens/seller_orders_screen.dart
LINE: 17
ISSUE: The file contains an unused import for `package:origna_gta/features/products/products_provider.dart`. This adds unnecessary code and can increase compile times slightly.
FIX: Remove the unused import statement: `import 'package:origna_gta/features/products/products_provider.dart';`.
---
SEVERITY: MEDIUM
FILE: N/A (multiple files)
ISSUE: Multiple screen files (`seller_integration_screen.dart`, `seller_orders_screen.dart`, `seller_products_screen.dart`, `seller_registration_screen.dart`, `seller_setup_screen.dart`, `shipping_approval_screen.dart`, `subscription_cancel_screen.dart`, `subscription_screen.dart`, `subscription_success_screen.dart`, `terms_of_service_screen.dart`, `terms_screen.dart`) contain Flutter-preview-related annotations (`@lib/previews/...`). This mixes production code with test/preview-only code, violating separation of concerns and potentially increasing app binary size if not properly stripped.
FIX: Consolidate all preview annotations into dedicated files inside a `previews/` or `test/previews` directory. For example, all previews for `SellerOrdersScreen` should be in a file like `previews/seller_orders_screen_previews.dart`. This keeps screen files clean and focused on their primary function.
---
SEVERITY: LOW
FILE: lib/screens/seller/seller_warehouses_screen.dart
LINE: 521
ISSUE: The `_countryCtrl` `TextEditingController` is initialized with a hardcoded string literal 'Canada'. This may not be the desired default for all users and is not localized.
FIX: Replace the hardcoded string with a constant defined in a configuration file or a translatable string, such as `kDefaultCountry.tr()`, to support internationalization and easier maintenance.
---
SEVERITY: LOW
FILE: lib/screens/seller_orders_screen.dart
LINE: 1049
ISSUE: The `_buildSellerItem` widget contains a hardcoded string 'Digital' for digital products. This string is not internationalized and will not be translated for users with different locales.
FIX: Replace the hardcoded string with a translation key and call `.tr()`. For example, use `'product.digital_type'.tr()`.
---
SEVERITY: LOW
FILE: lib/screens/seller_integration_screen.dart
LINE: 133
ISSUE: The `_CodeBlock` widget uses a hardcoded color `const Color(0xFFF4F4F8)` for its background in light mode. This violates the project's convention of using `DesignTokens` for all UI colors.
FIX: Replace the hardcoded color with an appropriate color from `DesignTokens`, such as `DesignTokens.surfaceVariant` or `DesignTokens.surfaceSubtle`, to ensure theme consistency.
---

## SUMMARY

| Severity | Count |
|----------|-------|
| CRITICAL | 6     |
| HIGH     | 36    |
| MEDIUM   | 42    |
| LOW      | 22    |
| **TOTAL**| **106** |

### Top Issues by Category

**Security (CRITICAL priority):**
- All 3 Firebase config files have hardcoded API keys / project credentials
- `product_repository.dart` has a hardcoded Geoapify API key in client code

**Logic Bugs (CRITICAL/HIGH priority):**
- `seller_registration_screen.dart:226` — `payoutsEnabled` incorrectly derived from `chargesEnabled`
- `seller_integration_screen.dart:407,442` — SDK code snippets embed non-functional URL literal
- `subscription_success_screen.dart:254` — Timer fires `setState` after widget dispose (crash risk)
- `seller_orders_screen.dart:258` + `seller_products_screen.dart:335` — Q&A badge creates navigation loop between two screens
- `seller_warehouses_screen.dart:153` — `assert(false)` in exposed callback is a debug-mode crash

**Design Token Violations (HIGH/MEDIUM — most numerous):**
- `supplier_config.dart` — 28+ hardcoded `Color(0xFF...)` values for supplier brand colors
- `categories_screen.dart` — 21 hardcoded `LinearGradient` color pairs
- `home_screen.dart`, `login_screen.dart`, `product_card_screen.dart`, `productdetails_screen.dart`, `profile_screen.dart`, `payment_screens.dart`, `ordersuccess_screen.dart`, `notifications_screen.dart` — widespread `Colors.white` / `Colors.black` instead of `DesignTokens.*`

**Architecture / Code Quality:**
- `editproduct_screen.dart` — duplicates `ProvinceCodeValues.names` from schema_constants
- `terms_screen.dart` — business/parsing logic (`_parseSections`, `_titleCase`) inside screen, violates MVVM
- `product_repository.dart` — throws localization keys as exception messages (repository/presentation coupling)
- `schema_constants.dart:835` — `supportEmail` has a space in the address (`support @orignaventures.ca`)
- `schema_constants.dart:999` — `new_roles` constant uses snake_case instead of camelCase

**Logging / Dead Code:**
- `location_repository.dart`, `auth_repository.dart`, `profile_screen.dart` — bare `print()` / `debugPrint()` calls in production paths
- `routes.dart:31` — commented-out `sellerSetup` route (dead code)
- `seller_orders_screen.dart:17` — unused import
