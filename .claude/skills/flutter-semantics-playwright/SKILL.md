---
name: flutter-semantics-playwright
description: Use when writing or debugging Playwright E2E tests, or modifying Flutter Semantics labels — covers flt-semantics DOM structure, aria-label vs text selectors, and selector patterns.
---

# Flutter Web Semantics → Playwright E2E Testing

## Architecture

Flutter Web (CanvasKit/Skwasm) renders UI to `<canvas>`. A parallel **`<flt-semantics>`**
DOM tree is generated with ARIA attributes when semantics is active. Playwright targets
these `<flt-semantics>` elements — NOT the canvas pixels.

```
Flutter Widget Tree
    ↓ (Semantics API)
<flt-semantics> DOM tree (aria-label, role, etc.)
    ↓ (Playwright selectors)
page.getByRole(), page.locator('[aria-label="..."]')
```

### Activation (main.dart)
```dart
if (kIsWeb) {
  SemanticsBinding.instance.ensureSemantics();
}
```
This is ALWAYS-ON for web builds. No Tab-key hack needed.

### How Labels Map to DOM
| Flutter | DOM Result |
|---------|-----------|
| `Semantics(label: 'x', child: ...)` | `<flt-semantics aria-label="x">` |
| `Semantics(button: true, ...)` | `role="button"` |
| `Semantics(link: true, ...)` | `role="link"` |
| `Semantics(checked: true, ...)` | `role="checkbox"` + `aria-checked="true"` |
| `IconButton(tooltip: 'x')` | `<flt-semantics aria-label="x">` |
| `TextField(decoration: InputDecoration(labelText: 'x'))` | `<flt-semantics aria-label="x">` |
| `Key('x')` on any widget | **NOT in DOM** — keys are Flutter-internal only |

## Naming Convention

**kebab-case** with semantic prefixes:

| Prefix | Usage | Example |
|--------|-------|---------|
| `btn-*` | Interactive buttons | `btn-login-submit`, `btn-place-order` |
| `input-*` | Text fields | `input-home-search`, `input-tracking-number` |
| `chk-*` | Checkboxes | `chk-terms-accepted`, `chk-seller-terms` |
| `chip-*` | Choice chips | `chip-address-label-home` |
| `link-*` | Hyperlinks | `link-terms-conditions`, `link-privacy-policy` |
| `nav-*` | Navigation items | `nav-home`, `nav-orders` |
| `menu-*` | Profile menu items | `menu-my-orders`, `menu-favorites` |
| `product-card-*` | Product cards | `product-card-{productId}` |

Dynamic IDs use string interpolation: `'btn-add-to-cart-${widget.productId}'`

## Playwright Helper File

**`e2e/flutter-helpers.ts`** — Single import for all Flutter-specific selectors:

```typescript
import {
  waitForFlutter,     // Wait for Flutter to finish loading (canvas + semantics ready)
  flutterButton,      // locator('[aria-label="label"]') with button filter
  flutterInput,       // locator('flt-semantics') filtered by name
  flutterCheckbox,    // getByRole('checkbox', { name })
  flutterByLabel,     // locator('[aria-label*="partial"]')
  flutterByExactLabel,// locator('[aria-label="exact"]')
  flutterLink,        // locator('flt-semantics') with link role
  fillFlutterInput,   // Focus + fill a text field
  clearAndFillFlutterInput,
  clickFlutterButton,
  waitForSemanticLabel,
  hasSemanticLabel,
  navigateToRoute,
  productCard,        // Product card by ID
  toggleFavorite,     // Toggle favorite by product ID
  addToCart,          // Add to cart by product ID
  uniqueSuffix,       // Generate unique test data suffix
} from './flutter-helpers';
```

### Usage Patterns

```typescript
// Wait for Flutter to load
await waitForFlutter(page);

// Click button by semantic label
await flutterButton(page, 'btn-place-order').click();

// Fill input by label text (InputDecoration.labelText)
await fillFlutterInput(page, 'Email', 'user@example.com');

// Click product card
await productCard(page, 'abc123').click();

// Toggle favorite
await toggleFavorite(page, 'abc123');

// Check a checkbox
await flutterCheckbox(page, 'chk-terms-accepted').check();

// Wait for widget to appear
await waitForSemanticLabel(page, 'product-card-abc123');
```

## Adding New Semantics Labels

### Buttons
```dart
Semantics(
  button: true,
  label: 'btn-my-action',
  child: GestureDetector(...),
)
```

### IconButtons (use tooltip — auto-generates aria-label)
```dart
IconButton(
  tooltip: 'My Action',
  icon: Icon(Icons.add),
  onPressed: () {},
)
```

### Text Fields
```dart
Semantics(
  label: 'input-my-field',
  child: TextFormField(...),
)
```
Or rely on `InputDecoration(labelText: 'My Field')` — Flutter auto-generates the label.

### Checkboxes
```dart
Semantics(
  checked: isChecked,
  label: 'chk-my-checkbox',
  child: Checkbox(value: isChecked, onChanged: ...),
)
```

### Links
```dart
Semantics(
  link: true,
  label: 'link-my-link',
  child: GestureDetector(onTap: () => launchUrl(...), child: Text('Click me')),
)
```

## Critical Gotchas

1. **ModernButton auto-labels**: The `ModernButton` widget wraps its child with `Semantics(button: true, label: widget.label)`, so ~50 buttons get labels automatically from their text.

2. **Wrapping pattern**: When wrapping `Widget W` with `Semantics(child: W)`:
   - Add `Semantics(` before the widget
   - Add matching `)` AFTER the widget's closing
   - Do NOT duplicate parent widgets
   - Run `flutter analyze` after wrapping to catch unclosed parentheses

3. **Dynamic labels**: Use `${}` interpolation for product-specific or item-specific IDs. Playwright can match with `[aria-label*="partial"]` for partial matches.

4. **Tooltip vs Semantics**: For `IconButton`, prefer `tooltip:` parameter (cleaner, also shows tooltip on hover). For other widgets, use `Semantics(label:)` wrapper.

5. **No Tab hack**: The Tab-key hack (`page.keyboard.press('Tab')`) is NOT needed when semantics is force-enabled via `ensureSemantics()` in main.dart.

6. **Canvas clicks don't work reliably**: Always target `<flt-semantics>` elements, never try to click canvas coordinates.

## Complete Enriched Files

### Widgets (Phase 2)
- `modern_button.dart` — Auto `Semantics(button: true, label: widget.label)`
- `modern_textfield.dart` — Password toggle `btn-toggle-password-visibility`
- `modern_product_card.dart` — Card + cart button labels
- `modern_appbar.dart` — Back tooltip + nav items
- `custom_app_bar.dart` — Back + Cart tooltips
- `modern_card.dart` — Optional `semanticLabel` parameter
- `rating_dialog.dart` — Star buttons + Cancel/Submit
- `legal_screen_body.dart` — Back tooltip

### Screens (Phase 3)
- `login_screen.dart` — Checkbox, forgot password, toggle auth, dialog buttons
- `home_screen.dart` — Search, clear, add product, cart, settings
- `cartitem_screen.dart` — Quantity minus/plus, delete
- `productdetails_screen.dart` — Back, fullscreen image, quantity buttons
- `product_card_screen.dart` — Card, favorite, add-to-cart (all with productId)
- `addproduct_screen.dart` — Publish button
- `editproduct_screen.dart` — Save button
- `cart_screen.dart` — Service fee info, tax info, delivery instructions
- `checkout_screen.dart` — Edit/add address, place order, delivery speed, terms
- `profile_screen.dart` — Sign in, delete account, menu items, email, website
- `editaddress_screen.dart` — Address label chips, save button
- `seller_registration_screen.dart` — Terms checkbox, action button
- `shipping_approval_screen.dart` — Reject, approve, confirm cancel
- `orders_screen.dart` — Dynamic action buttons, pending approvals
- `productaddimages_screen.dart` — Add photo, remove image
- `addressmanagement_screen.dart` — Add address, edit address
- `seller_orders_screen.dart` — Tracking number, actual cost, tracking update
