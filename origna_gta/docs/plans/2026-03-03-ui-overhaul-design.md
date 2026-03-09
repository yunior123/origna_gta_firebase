# UI Overhaul — Bug Fixes + Full Preview Coverage
Date: 2026-03-03

## Scope
20 reported issues split into two parallel tracks executed sequentially.

---

## Track A — Bug Fixes (16 items)

### Wave A1 — Crashes & Navigation
1. Remove `categories_screen.dart` + route `/categories` — screen is redundant; home chips cover it.
2. Fix Firebase exception in chat screen — wrap Firestore stream with error handler / null guard.
3. PasskeyAuthenticator stub already fixed (full 7-method stub in web/index.html + start-preview.sh).

### Wave A2 — Overflow Fixes
All overflow fixes use `Flexible`, `Expanded` correctly, `FittedBox`, or `ConstrainedBox`.
Screens to fix:
- `home_screen.dart` — category chips: replace Column/Row with `SingleChildScrollView(scrollDirection: Axis.horizontal)`
- `favorites_screen.dart` — overflow
- `product_card_screen.dart` + `productdetails_screen.dart` — overflow
- `login_screen.dart` — overflow + missing Apple Sign In / Google branding
- `notifications_screen.dart` — overflow when empty
- `order_detail_screen.dart` — retry button full-width + overflow
- `orders_screen.dart` — overflow
- `ordersuccess_screen.dart` — overflow
- `payment_screens.dart` (canceled) — overflow
- `seller_orders_screen.dart`, `seller_products_screen.dart`, `seller_setup_screen.dart` — overflow
- `subscription_screen.dart` — overflow
- All other screens: audit `RenderFlex overflowed` patterns

### Wave A3 — UI Polish
- `editaddress_screen.dart` — toggle (Switch) uses dark color in light theme → use `DesignTokens.primary` for active track color
- Login screen: Apple Sign In button → use `sign_in_with_apple` package `SignInWithAppleButton` with correct branding (black on white / white on black per Apple HIG)
- Login screen: Google button → use official Google G logo (CustomPainter already exists as `_GoogleSignInButton`); verify it renders correctly
- Search bar: add `suffixIcon` with `Icons.clear` that appears when field is non-empty; clears on tap
- Notifications screen empty state: fix overflow, constrain to available height

---

## Track B — Preview Coverage (200+ previews)

### Wave B1 — Infrastructure
**`_preview_theme.dart` additions:**
```dart
// Layout size constants
const Size kMobile  = Size(390, 844);   // iPhone 14
const Size kTablet  = Size(768, 1024);  // iPad
const Size kDesktop = Size(1280, 900);  // Laptop
const Size kWeb     = Size(1440, 900);  // Wide browser

// EasyLocalization-backed wrapper (real translations, not stubs)
Widget previewWithLocale({
  required Widget child,
  String locale = 'en',
  ThemeData? theme,
  Color? background,
}) => EasyLocalization(
  supportedLocales: [Locale('en'), Locale('fr')],
  path: 'assets/translations',
  fallbackLocale: Locale('en'),
  startLocale: Locale(locale),
  child: Builder(builder: (ctx) => previewWrapper(child: child, theme: theme, background: background)),
);

// Responsive wrappers
Widget previewMobile({required Widget child, ...})  => previewWithLocale(child: SizedBox(...));
Widget previewTablet({required Widget child, ...})  => previewWithLocale(child: SizedBox(...));
Widget previewDesktop({required Widget child, ...}) => previewWithLocale(child: SizedBox(...));
Widget previewWeb({required Widget child, ...})     => previewWithLocale(child: SizedBox(...));
```

Each responsive wrapper constrains the child to the given breakpoint size. The real `EasyLocalization` asset loader handles translations — `en.json` and `fr.json` are loaded from `assets/translations/`.

### Wave B2 — Auth + Commerce Screens
New file: `lib/previews/screens/auth_screens_preview.dart`
New file: `lib/previews/screens/home_screen_preview.dart`
New file: `lib/previews/screens/product_screens_preview.dart`
New file: `lib/previews/screens/cart_checkout_preview.dart`
New file: `lib/previews/screens/search_screen_preview.dart`

Each file covers: Mobile + Tablet + Desktop + Web × dark + light = 8 previews minimum per screen.
Plus state variants: loading, empty, error where applicable.

### Wave B3 — Orders + Seller Screens
New file: `lib/previews/screens/orders_preview.dart`
New file: `lib/previews/screens/order_detail_preview.dart`
New file: `lib/previews/screens/seller_preview.dart`

### Wave B4 — Profile + Edge Screens
New file: `lib/previews/screens/profile_preview.dart`
New file: `lib/previews/screens/notifications_preview.dart`
New file: `lib/previews/screens/favorites_preview.dart`
New file: `lib/previews/screens/subscription_preview.dart`
New file: `lib/previews/screens/chat_preview.dart`
New file: `lib/previews/screens/address_preview.dart`
New file: `lib/previews/screens/payment_preview.dart`

### Wave B5 — Existing Component Previews (upgrade)
All existing `lib/previews/*.dart` files upgraded with:
- 4 layout variants (Mobile/Tablet/Desktop/Web) replacing `size:` param
- Real EasyLocalization via `previewWithLocale`
- French locale variants for key text-heavy components

---

## Directory Structure After
```
lib/previews/
  _preview_theme.dart          ← add 4 size constants + previewWithLocale + responsive helpers
  screens/
    auth_screens_preview.dart
    home_screen_preview.dart
    product_screens_preview.dart
    cart_checkout_preview.dart
    search_screen_preview.dart
    orders_preview.dart
    order_detail_preview.dart
    seller_preview.dart
    profile_preview.dart
    notifications_preview.dart
    favorites_preview.dart
    subscription_preview.dart
    chat_preview.dart
    address_preview.dart
    payment_preview.dart
  buttons_preview.dart         ← upgraded
  cards_preview.dart           ← upgraded
  app_bar_preview.dart         ← upgraded
  ... (all existing upgraded)
```

---

## Constraints
- 8GB RAM: bug fixes run sequentially; preview agents run max 3 parallel
- No emulators — all fixes tested with `flutter analyze`
- Each wave ends with `flutter analyze → 0 issues`
- preview agents are READ-ONLY on screen files; only write to `lib/previews/screens/`
