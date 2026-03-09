# UI Overhaul — Bug Fixes + Full Preview Coverage

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 16 UI bugs (overflows, crashes, branding) and add 200+ widget previews covering all screens at 4 responsive breakpoints with real EasyLocalization translations.

**Architecture:** Track A (bugs) runs first, then Track B (previews) so previews reflect fixed UI. Each task ends with `flutter analyze --no-fatal-infos → 0 issues`. No emulators — 8GB RAM constraint.

**Tech Stack:** Flutter/Dart, Riverpod, easy_localization, sign_in_with_apple, flutter_riverpod, DesignTokens

---

## TRACK A — BUG FIXES

---

### Task A1: Remove Categories Screen

**Files:**
- Delete: `lib/screens/categories_screen.dart`
- Modify: `lib/origna_app.dart` (remove import + route at lines 19, 569-570)
- Modify: `lib/core/routes.dart` (remove `static const String categories = '/categories'` at line 48)
- Modify: `lib/screens/home_screen.dart` (remove "Browse All Categories" button at line 549)

**Step 1: Remove route constant**

In `lib/core/routes.dart`, delete the line:
```dart
static const String categories = '/categories';
```

**Step 2: Remove route handler in origna_app.dart**

Delete lines:
```dart
import 'package:origna_gta/screens/categories_screen.dart';
```
And delete:
```dart
if (uri.path == AppRoutes.categories) {
  return SlidePageRoute(settings: settings, page: const CategoriesScreen());
```

**Step 3: Remove "Browse All Categories" button in home_screen.dart**

Find and remove the button block around line 542-552:
```dart
// Browse All Categories button
```
This is the `onPressed: () => Navigator.pushNamed(context, AppRoutes.categories)` block.

**Step 4: Delete the file**
```bash
rm lib/screens/categories_screen.dart
```

**Step 5: Verify**
```bash
cd origna_gta && flutter analyze --no-fatal-infos 2>&1 | tail -3
```
Expected: `No issues found!`

**Step 6: Commit**
```bash
git add -A && git commit -m "feat: remove redundant categories screen — home chips cover all categories"
```

---

### Task A2: Fix Category Chips — Horizontal Scroll on ALL Breakpoints

**File:** `lib/screens/home_screen.dart`

**Problem:** On tablet/desktop, `_CategoryChips` uses `Wrap` (lines ~323-331), showing all 21 categories in a grid. User wants horizontal scroll on all breakpoints.

**Step 1: Read the current _CategoryChips widget**

Find `class _CategoryChips` in home_screen.dart. The tablet/desktop branch uses `Wrap`. Replace the entire conditional so ALL breakpoints use `ListView.builder(scrollDirection: Axis.horizontal)`.

The tablet/desktop branch (starting around `// On tablet/desktop: Wrap`) should become:
```dart
// All breakpoints: horizontal scroll — keeps UI consistent
return SizedBox(
  height: 44,
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: productCategories.length + 1,
    itemBuilder: (context, index) {
      final isAll = index == 0;
      final category = isAll ? null : productCategories[index - 1];
      return _buildChip(context, isAll, category, isSelected(category));
    },
  ),
);
```
Remove the `if (isTabletOrDesktop) { return Wrap(...) }` branch entirely.

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "fix: category chips horizontal scroll on all breakpoints"
```

---

### Task A3: Fix Firebase Exception in Chat Screen

**File:** `lib/screens/chat_screen.dart`

**Step 1: Read the stream/catch blocks** — lines 64, 146, 225

Wrap the Firestore stream with `handleError` to catch `FirebaseException` and emit an empty list / error state instead of crashing:

```dart
// In the StreamProvider or StreamBuilder, add:
.handleError((e) {
  if (e is FirebaseException) {
    AppError.log(e, hint: 'chat_stream');
    return; // emit nothing — StreamBuilder shows last good state
  }
  throw e;
})
```

If the exception is in a `catch (_)` block that silently swallows, replace with:
```dart
} catch (e, st) {
  AppError.log(e, hint: 'chat_screen', stackTrace: st);
}
```

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "fix: handle FirebaseException in chat stream without crash"
```

---

### Task A4: Fix editaddress Toggle in Light Theme

**File:** `lib/screens/editaddress_screen.dart`

**Problem:** `SwitchListTile.adaptive` around line 275 renders a black toggle in light theme.

**Step 1: Read the SwitchListTile.adaptive block**

Add `activeColor` and `activeTrackColor` parameters:
```dart
SwitchListTile.adaptive(
  activeColor: DesignTokens.primary,
  activeTrackColor: DesignTokens.primary.withValues(alpha: 0.4),
  // ... existing params
)
```

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "fix: editaddress toggle uses primary color in light theme"
```

---

### Task A5: Fix Login Screen — Overflows + Apple/Google Branding

**File:** `lib/screens/login_screen.dart`

**Step 1: Read the full login screen**

**Overflow fix:** The login form column likely overflows on small screens. Wrap the root `Column` in a `SingleChildScrollView`:
```dart
// Wrap existing Column in:
SingleChildScrollView(
  child: Column(
    // existing children
  ),
)
```

**Apple Sign In branding:** The `SignInWithAppleButton` at line 347 must follow Apple HIG:
- `style: SignInWithAppleButtonStyle.black` on dark backgrounds ✅ (already correct)
- `style: SignInWithAppleButtonStyle.white` or `SignInWithAppleButtonStyle.whiteOutlined` on light backgrounds
- Height must be ≥ 44px

Fix: Make style conditional on theme brightness:
```dart
SignInWithAppleButton(
  text: state.isLogin ? 'auth.apple_sign_in'.tr() : 'auth.sign_up_with_apple'.tr(),
  style: Theme.of(context).brightness == Brightness.dark
      ? SignInWithAppleButtonStyle.white
      : SignInWithAppleButtonStyle.black,
  height: 52,
  onPressed: state.isLoading ? () {} : viewModel.handleAppleSignIn,
)
```

**Google branding:** Read `_GoogleSignInButton` at line 559+. Common issues:
- Logo too small or wrong colors
- Button background must be white (#FFFFFF) per Google branding
- Text: "Sign in with Google" in Roboto or system font, #3C4043 color
- G logo: exact Google colors (red, yellow, green, blue)

Verify the CustomPainter in `_GoogleSignInButtonState` draws the G correctly. If it doesn't, replace with a properly sized `SizedBox(width: 18, height: 18)` `CustomPainter`.

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "fix: login overflow + correct Apple/Google sign-in branding"
```

---

### Task A6: Fix Favorites Screen Overflow

**File:** `lib/screens/favorites_screen.dart`

**Step 1: Read the screen**

The overflow is in a `Column` without `Expanded`/`Flexible` around the list. Common pattern:

```dart
// BROKEN — Column child with unbounded height
Column(
  children: [
    SomeHeader(),
    ListView(...), // overflows
  ]
)

// FIX — wrap list in Expanded
Column(
  children: [
    SomeHeader(),
    Expanded(child: ListView(...)),
  ]
)
```

Apply the same fix to all unbounded list/column patterns in favorites_screen.dart.

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "fix: favorites screen overflow — Expanded wraps ListView"
```

---

### Task A7: Fix Product Card + Product Details Overflows

**Files:**
- `lib/screens/product_card_screen.dart`
- `lib/screens/productdetails_screen.dart`

**Step 1: Read both files**

Common overflow sources in product cards:
- Product name `Text` without `maxLines` + `overflow: TextOverflow.ellipsis`
- Price row `Row` children not using `Flexible`/`Expanded`
- Image aspect ratio not constrained

Fix patterns:
```dart
// Text overflow
Text(
  productName,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
)

// Row children
Row(children: [
  Flexible(child: Text(price)),
  const SizedBox(width: 8),
  Text(currency),
])
```

In `productdetails_screen.dart`, the SliverAppBar or body Column may overflow. Ensure `SliverList` / `CustomScrollView` is used correctly and all `Column` children inside slivers have proper constraints.

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "fix: product card and product details overflow"
```

---

### Task A8: Fix Notifications Screen Overflow + Empty State

**File:** `lib/screens/notifications_screen.dart`

**Step 1: Read the screen**

Empty state overflow: the empty state `Column` (icon + text) is inside a `Column` without being centered/constrained. Fix:
```dart
// Wrap empty state in Expanded + Center
Expanded(
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.notifications_none_outlined, size: 64, color: DesignTokens.darkOutline),
        const SizedBox(height: 16),
        Text('notifications.empty'.tr(), ...),
      ],
    ),
  ),
)
```

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "fix: notifications empty state overflow"
```

---

### Task A9: Fix Order Detail, Orders, Order Success Overflows

**Files:**
- `lib/screens/order_detail_screen.dart`
- `lib/screens/orders_screen.dart`
- `lib/screens/ordersuccess_screen.dart`

**Step 1: Fix order detail retry button (line 88)**

The `ModernButton` for retry takes full width. Constrain it:
```dart
// BROKEN
ModernButton(onPressed: ..., label: 'orders.retry'.tr(), icon: Icons.refresh)

// FIX — wrap in Center with max width
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 280),
    child: ModernButton(onPressed: ..., label: 'orders.retry'.tr(), icon: Icons.refresh),
  ),
)
```

Fix overflow in the outer Column (line 37, 75, 102) by ensuring all unbounded children have proper constraints. Wrap the Column in `SingleChildScrollView` if the screen content can exceed viewport height.

**Step 2: Read orders_screen.dart + ordersuccess_screen.dart** and apply same patterns.

**Step 3: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 4: Commit**
```bash
git commit -m "fix: order detail/orders/order success overflows and retry button width"
```

---

### Task A10: Fix Payment Canceled + Seller Screen Overflows

**Files:**
- `lib/screens/payment_screens.dart` (canceled screen)
- `lib/screens/seller_orders_screen.dart`
- `lib/screens/seller_products_screen.dart`
- `lib/screens/seller_setup_screen.dart`

**Step 1: Read each file and identify overflow Column/Row patterns**

Apply consistent fixes:
- Unbounded `Column` inside `Column` → add `mainAxisSize: MainAxisSize.min` or wrap in `Expanded`
- `Row` children with long text → wrap in `Flexible`
- Full-width buttons that overflow narrow screens → `ConstrainedBox(constraints: BoxConstraints(maxWidth: 400))`

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "fix: payment canceled and seller screens overflow"
```

---

### Task A11: Fix Subscription Screen Overflow

**File:** `lib/screens/subscription_screen.dart`

**Step 1: Read the screen**

Subscription screens often have a `Column` of feature cards + button that overflows. Fix:
- Wrap the content `Column` in `SingleChildScrollView`
- Or use `ListView` for the features list
- Constrain the CTA button to `BoxConstraints(maxWidth: 400)`

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "fix: subscription screen overflow"
```

---

## TRACK B — PREVIEW COVERAGE

---

### Task B1: Upgrade _preview_theme.dart — Responsive Helpers + EasyLocalization

**File:** `lib/previews/_preview_theme.dart`

**Step 1: Add 4 breakpoint size constants and responsive wrappers**

Add to the end of `_preview_theme.dart`:
```dart
import 'package:easy_localization/easy_localization.dart';

// ── Responsive breakpoint sizes ──────────────────────────────────────────────
const Size kMobile  = Size(390, 844);    // iPhone 14
const Size kTablet  = Size(768, 1024);   // iPad
const Size kDesktop = Size(1280, 900);   // Laptop
const Size kWeb     = Size(1440, 900);   // Wide browser / desktop web

// ── EasyLocalization-backed preview wrapper ───────────────────────────────────
/// Wraps child with real EasyLocalization (en.json / fr.json from assets).
/// `.tr()` keys resolve to actual translations in preview mode.
Widget previewLocalized({
  required Widget child,
  String locale = 'en',
  ThemeData? theme,
  Color? background,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('fr')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    startLocale: Locale(locale),
    child: Builder(
      builder: (ctx) => previewWrapper(
        child: child,
        theme: theme,
        background: background,
      ),
    ),
  );
}

// ── Responsive preview wrappers ───────────────────────────────────────────────
Widget previewMobile({
  required Widget child,
  String locale = 'en',
  ThemeData? theme,
  Color? background,
}) => previewLocalized(
  locale: locale,
  theme: theme,
  background: background,
  child: SizedBox(
    width: kMobile.width,
    height: kMobile.height,
    child: child,
  ),
);

Widget previewTablet({
  required Widget child,
  String locale = 'en',
  ThemeData? theme,
  Color? background,
}) => previewLocalized(
  locale: locale,
  theme: theme,
  background: background,
  child: SizedBox(
    width: kTablet.width,
    height: kTablet.height,
    child: child,
  ),
);

Widget previewDesktop({
  required Widget child,
  String locale = 'en',
  ThemeData? theme,
  Color? background,
}) => previewLocalized(
  locale: locale,
  theme: theme,
  background: background,
  child: SizedBox(
    width: kDesktop.width,
    height: kDesktop.height,
    child: child,
  ),
);

Widget previewWeb({
  required Widget child,
  String locale = 'en',
  ThemeData? theme,
  Color? background,
}) => previewLocalized(
  locale: locale,
  theme: theme,
  background: background,
  child: SizedBox(
    width: kWeb.width,
    height: kWeb.height,
    child: child,
  ),
);
```

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "feat(previews): add responsive helpers + real EasyLocalization in preview wrappers"
```

---

### Task B2: Create screens/ preview directory + Auth Screen Previews

**Files to create:**
- `lib/previews/screens/auth_screens_preview.dart`

**Step 1: Create auth_screens_preview.dart**

Structure — 4 layouts × dark + light + FR locale = 10 previews minimum:
```dart
library;
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/screens/login_screen.dart';
import '../_preview_theme.dart';

Widget _loginDark(Widget sizedBox) => ProviderScope(child: MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: previewDarkTheme,
  home: sizedBox,
));

Widget _loginLight(Widget sizedBox) => ProviderScope(child: MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: previewLightTheme,
  home: sizedBox,
));

// ── Login — Mobile ─────────────────────────────────────────────────────────
@Preview(name: 'Login — Mobile Dark', group: 'LoginScreen', size: kMobile)
Widget previewLoginMobileDark() => _loginDark(const LoginScreen());

@Preview(name: 'Login — Mobile Light', group: 'LoginScreen', size: kMobile)
Widget previewLoginMobileLight() => _loginLight(const LoginScreen());

@Preview(name: 'Login — Mobile FR', group: 'LoginScreen', size: kMobile)
Widget previewLoginMobileFr() => previewMobile(locale: 'fr', child: const LoginScreen());

// ── Login — Tablet ────────────────────────────────────────────────────────
@Preview(name: 'Login — Tablet Dark', group: 'LoginScreen', size: kTablet)
Widget previewLoginTabletDark() => _loginDark(const LoginScreen());

// ── Login — Desktop ────────────────────────────────────────────────────────
@Preview(name: 'Login — Desktop Dark', group: 'LoginScreen', size: kDesktop)
Widget previewLoginDesktopDark() => _loginDark(const LoginScreen());

// ── Login — Web ────────────────────────────────────────────────────────────
@Preview(name: 'Login — Web Dark', group: 'LoginScreen', size: kWeb)
Widget previewLoginWebDark() => _loginDark(const LoginScreen());

@Preview(name: 'Login — Web Light', group: 'LoginScreen', size: kWeb)
Widget previewLoginWebLight() => _loginLight(const LoginScreen());
```

Apply the same 4-layout × dark/light/FR pattern for:
- `ResetPasswordScreen` → group: `'ResetPasswordScreen'`

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "feat(previews): auth screens — mobile/tablet/desktop/web × dark/light/FR"
```

---

### Task B3: Home + Search Screen Previews

**File to create:** `lib/previews/screens/home_screen_preview.dart`

Follow the exact same pattern as Task B2. Cover:
- `HomeScreen` — 4 layouts × dark + light + FR + loading state + empty results state
- Key states: category selected, search active, no results

Use `ProviderScope(overrides: [...])` to simulate loading/error/empty states by overriding Riverpod providers.

**File to create:** `lib/previews/screens/search_screen_preview.dart`

If search is inline in HomeScreen, show the search-focused variant by passing `autofocus: true` or simulating state.

**Step 1: Write both files**

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "feat(previews): home + search screens — all layouts + states"
```

---

### Task B4: Product Screens Previews

**File to create:** `lib/previews/screens/product_screens_preview.dart`

Cover:
- `ProductDetailsScreen` — 4 layouts × dark/light/FR + loading + out-of-stock + no reviews
- `ProductCardScreen` (if separate from `ModernProductCard`) — 4 layouts

For screens requiring a `productId`, use a mock string `'preview-product-123'`.
Wrap with `ProviderScope(overrides: [productDetailsProvider('preview-product-123').overrideWith(...)])`.

**Step 1: Find the productDetailsProvider**
```bash
grep -n "productDetailsProvider\|productByIdProvider" lib/features/products/*.dart | head -10
```

**Step 2: Write preview file with mock overrides**

**Step 3: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 4: Commit**
```bash
git commit -m "feat(previews): product detail + product card screens — all layouts"
```

---

### Task B5: Cart + Checkout Previews

**File to create:** `lib/previews/screens/cart_checkout_preview.dart`

Cover:
- `CartScreen` — 4 layouts × empty + with items + loading
- `CartItemScreen`
- `CheckoutScreen` — 4 layouts × payment step + shipping step + review step

Override cart/checkout providers with mock data.

**Step 1: Find cart + checkout providers**
```bash
grep -n "cartProvider\|checkoutProvider" lib/features/cart/*.dart lib/features/checkout/*.dart 2>/dev/null | head -10
```

**Step 2: Write preview file**

**Step 3: Verify + Commit**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
git commit -m "feat(previews): cart + checkout — all layouts + states"
```

---

### Task B6: Orders Previews

**File to create:** `lib/previews/screens/orders_preview.dart`

Cover:
- `OrdersScreen` — 4 layouts × empty + with orders + loading
- `OrderDetailScreen` — 4 layouts × confirmed/shipped/delivered states
- `OrderSuccessScreen` — 4 layouts

**Step 1: Find order providers**
```bash
grep -rn "ordersProvider\|orderByIdProvider" lib/features/ | head -10
```

**Step 2: Write preview file with state overrides**

**Step 3: Verify + Commit**
```bash
git commit -m "feat(previews): orders screens — all layouts + states"
```

---

### Task B7: Seller Screens Previews

**File to create:** `lib/previews/screens/seller_preview.dart`

Cover:
- `SellerOrdersScreen` — 4 layouts × empty + with orders
- `SellerProductsScreen` — 4 layouts × empty + with products
- `SellerSetupScreen` — 4 layouts
- `SellerRegistrationScreen` — 4 layouts (step 1 + step 2)
- `SellerIntegrationScreen` — 4 layouts
- `ShippingApprovalScreen` — 4 layouts

**Step 1: Find seller providers**
```bash
grep -rn "sellerOrdersProvider\|sellerProductsProvider" lib/features/ | head -10
```

**Step 2: Write previews with mock seller data**

**Step 3: Verify + Commit**
```bash
git commit -m "feat(previews): seller screens — all layouts + states"
```

---

### Task B8: Profile + Notifications + Favorites Previews

**File to create:** `lib/previews/screens/profile_preview.dart`
**File to create:** `lib/previews/screens/notifications_preview.dart`
**File to create:** `lib/previews/screens/favorites_preview.dart`

**Notifications — required variants:**
- Empty (no notifications) — dark + light + all 4 layouts
- With notifications (mock list of 5) — dark + light + all 4 layouts

```dart
// Mock notifications override
notificationsProvider.overrideWith((_) => Stream.value([
  NotificationModel(id: '1', title: 'Order shipped', body: 'Your order #ORD-123 has shipped', createdAt: DateTime.now()),
  NotificationModel(id: '2', title: 'Price drop', body: 'Jacket you liked dropped to \$65', createdAt: DateTime.now().subtract(Duration(hours: 2))),
]))
```

**Favorites — required variants:**
- Empty + With items × 4 layouts × dark/light

**Step 1: Write all three files**

**Step 2: Verify + Commit**
```bash
git commit -m "feat(previews): profile + notifications (with/empty) + favorites — all layouts"
```

---

### Task B9: Subscription + Chat + Address + Payment Previews

**Files to create:**
- `lib/previews/screens/subscription_preview.dart`
- `lib/previews/screens/chat_preview.dart`
- `lib/previews/screens/address_preview.dart`
- `lib/previews/screens/payment_preview.dart`

**Subscription variants:**
- Non-premium (upsell view) × 4 layouts
- Premium active × 4 layouts
- Cancel confirmation × 4 layouts

**Chat variants:**
- Conversations list × 4 layouts × empty + with conversations
- Chat thread × 4 layouts

**Address variants:**
- `AddressManagementScreen` × 4 layouts × empty + with addresses
- `EditAddressScreen` × 4 layouts × dark + light (to verify toggle fix from Task A4)

**Payment variants:**
- `PaymentCanceledScreen` × 4 layouts
- `SubscriptionSuccessScreen` × 4 layouts

**Step 1: Write all four files**

**Step 2: Verify + Commit**
```bash
git commit -m "feat(previews): subscription + chat + address + payment — all layouts + states"
```

---

### Task B10: Upgrade Existing Component Previews to Responsive + Real Translations

**Files to modify:**
- `lib/previews/buttons_preview.dart`
- `lib/previews/cards_preview.dart`
- `lib/previews/app_bar_preview.dart`
- `lib/previews/product_card_preview.dart`
- `lib/previews/loading_preview.dart`
- `lib/previews/textfields_preview.dart`
- `lib/previews/rating_preview.dart`
- `lib/previews/order_status_preview.dart`
- `lib/previews/design_tokens_preview.dart`
- `lib/previews/premium_paywall_preview.dart`
- `lib/previews/language_selector_preview.dart`

**For each file:**
1. Replace `previewWrapper(child: ...)` with `previewMobile(child: ...)` for existing previews
2. Add Tablet/Desktop/Web variants for any component that behaves differently at larger sizes
3. Add FR locale variant for any component with translated text (uses `previewMobile(locale: 'fr', child: ...)`)
4. Replace `size: Size(...)` params with `kMobile` / `kTablet` / `kDesktop` / `kWeb` constants

**Pattern:**
```dart
// BEFORE
@Preview(name: 'Primary — dark', group: 'Buttons')
Widget previewPrimaryButtonDark() => previewWrapper(child: ModernButton(...));

// AFTER
@Preview(name: 'Primary — Mobile', group: 'Buttons', size: kMobile)
Widget previewPrimaryButtonMobile() => previewMobile(child: ModernButton(...));

@Preview(name: 'Primary — Tablet', group: 'Buttons', size: kTablet)
Widget previewPrimaryButtonTablet() => previewTablet(child: ModernButton(...));

@Preview(name: 'Primary — Desktop', group: 'Buttons', size: kDesktop)
Widget previewPrimaryButtonDesktop() => previewDesktop(child: ModernButton(...));

@Preview(name: 'Primary — Web', group: 'Buttons', size: kWeb)
Widget previewPrimaryButtonWeb() => previewWeb(child: ModernButton(...));
```

**Step 1: Update each file following the pattern above**

**Step 2: Verify**
```bash
flutter analyze --no-fatal-infos 2>&1 | tail -3
```

**Step 3: Commit**
```bash
git commit -m "feat(previews): upgrade all component previews to 4-layout responsive + real translations"
```

---

### Task B11: Add Missing Widget Previews

**Gap audit — run this to find uncovered widgets:**
```bash
ls lib/widgets/ && ls lib/previews/
# Compare — any widget without a preview file needs one
```

**Missing widgets likely include:**
- `language_selector.dart` — already has basic preview; upgrade to responsive
- Any new widgets added since initial audit

For each missing widget, create a preview file in `lib/previews/` following the existing pattern.

**Step 1: Run gap audit**
**Step 2: Create missing preview files**
**Step 3: Verify + Commit**
```bash
git commit -m "feat(previews): add missing widget previews"
```

---

## Final Verification

```bash
cd origna_gta
flutter analyze --no-fatal-infos 2>&1 | tail -3
# Expected: No issues found!

# Count total previews
grep -r "@Preview" lib/previews/ lib/screens/ lib/widgets/ | wc -l
# Expected: 200+
```

---

## RAM Safety Notes
- Never run `flutter build` and preview agent simultaneously
- Preview agents are READ operations on screen files + WRITE to lib/previews/ — safe to run 3 at a time
- Bug fix tasks (A1-A11) run sequentially — one at a time
- Kill previewer before running any build: `kill $(cat /tmp/flutter-preview.pid)`
