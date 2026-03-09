---
name: widget-finders
description: Widget finders and selectors for Flutter integration tests AND Playwright E2E tests. Use when writing or fixing integration/E2E tests.
---

# Widget Finders Reference

## Part 1: Flutter Integration Tests (Key-Based)

| Widget | Key | Type |
|--------|-----|------|
| Login Email | `login_email_field` | ModernTextField → TextFormField |
| Login Password | `login_password_field` | ModernTextField → TextFormField |
| Login Submit | `login_submit_button` | ModernButton → InkWell (NOT ElevatedButton) |
| Add Product | `home_add_product_button` | IconButton on AppBar |
| Product Name | `product_name_field` | _buildGlassTextField → TextFormField |
| Product Description | `product_description_field` | _buildGlassTextField |
| Product Price | `product_price_field` | _buildGlassTextField |
| Product Stock | `product_stock_field` | _buildGlassTextField |
| Publish Product | `find.text('Publish Product')` | InkWell |
| Cart Icon | `find.byIcon(Icons.shopping_cart_outlined)` | IconButton |
| Add to Cart | `find.text('Add to Cart')` | ModernButton → InkWell |
| Proceed to Checkout | `find.text('Proceed to Checkout')` | ModernButton |
| Place Order | `find.text('Place Order')` | ModernButton |

### Flutter Test Notes
- All buttons use `ModernButton` wrapping `InkWell`, NOT `ElevatedButton`
- Glass Toggle: `GestureDetector` > `AnimatedContainer` > `Switch.adaptive`
- Delivery Tier Card: Custom card with `Switch` + expandable children
- Use pump loops (10×1s) NOT `pumpAndSettle()`
- Only ONE `testWidgets` per file

### App Init for Tests
- Entry: `main_test.dart` → `mainTest()`
- Flow: `OrignaApp` → `AuthWrapper` (5s) → `MainScreen` (3s) → `HomeScreen`

---

## Part 2: Playwright E2E Tests (Semantics-Based)

### How It Works
- `main.dart` calls `SemanticsBinding.instance.ensureSemantics()` on web (always-on)
- Flutter generates a parallel DOM tree of `<flt-semantics>` elements with ARIA attributes
- Playwright uses `getByRole()`, `getByLabel()`, `locator('[aria-label="..."]')` to interact
- NO Tab-key hack needed — semantics is force-enabled in main.dart
- Works with both CanvasKit and Skwasm renderers

### Helper File: `e2e/flutter-helpers.ts`
```typescript
import { waitForFlutter, flutterButton, flutterInput, flutterCheckbox,
         flutterByLabel, flutterLink, fillFlutterInput, productCard,
         toggleFavorite, addToCart } from './flutter-helpers';
```

### Semantic Label Convention (kebab-case)
| Prefix | Usage | Example |
|--------|-------|---------|
| `btn-*` | Buttons | `btn-login-submit`, `btn-add-to-cart-{id}` |
| `input-*` | Text fields | `input-home-search`, `input-tracking-number` |
| `chk-*` | Checkboxes | `chk-terms-accepted`, `chk-seller-terms` |
| `chip-*` | Choice chips | `chip-address-label-home` |
| `link-*` | Links | `link-terms-conditions`, `link-privacy-policy` |
| `nav-*` | Navigation | `nav-home`, `nav-orders` |
| `menu-*` | Profile menu items | `menu-my-orders`, `menu-favorites` |
| `product-card-*` | Product cards | `product-card-{productId}` |

### Complete Widget → Playwright Selector Map

#### Reusable Widgets (auto-labeled)
| Widget | Semantic Label | Playwright Selector |
|--------|---------------|---------------------|
| ModernButton | `widget.label` (auto) | `page.getByRole('button', { name: /label/i })` |
| ModernProductCard | `product-card-{name}` | `page.locator('[aria-label*="product-card"]')` |
| ModernAppBar back | `tooltip: 'Back'` | `page.getByRole('button', { name: 'Back' })` |
| ModernAppBar nav | `nav-{label}` | `page.locator('[aria-label="nav-home"]')` |
| CustomAppBar back | `tooltip: 'Back'` | `page.getByRole('button', { name: 'Back' })` |
| CustomAppBar cart | `tooltip: 'Cart'` | `page.getByRole('button', { name: 'Cart' })` |
| RatingDialog stars | `btn-rating-star-{n}` | `page.locator('[aria-label="btn-rating-star-3"]')` |

#### Screen-Level Widgets
| Screen | Widget | Semantic Label |
|--------|--------|---------------|
| Login | Accept terms checkbox | `chk-accept-terms` |
| Login | Forgot password | `btn-forgot-password` |
| Login | Toggle auth mode | `btn-toggle-auth-mode` |
| Home | Search | `input-home-search` |
| Home | Clear search | `btn-clear-search` |
| Home | Add product | `tooltip: 'Add product'` |
| Home | Cart | `tooltip: 'Shopping cart'` |
| Home | Settings | `tooltip: 'Settings'` |
| CartItem | Qty minus | `btn-cart-qty-minus` |
| CartItem | Qty plus | `btn-cart-qty-plus` |
| CartItem | Delete | `tooltip: 'Remove from cart'` |
| Cart | Service fee info | `btn-info-service-fee` |
| Cart | Tax info | `btn-info-tax-estimate` |
| Cart | Delivery instructions | `btn-delivery-instructions` |
| ProductDetail | Fullscreen image | `btn-product-image-fullscreen` |
| ProductDetail | Qty buttons | `btn-qty-minus` / `btn-qty-plus` |
| ProductCard | Card tap | `product-card-{productId}` |
| ProductCard | Favorite | `btn-favorite-{productId}` |
| ProductCard | Add to cart | `btn-add-to-cart-{productId}` |
| AddProduct | Publish | `btn-publish-product` |
| EditProduct | Save | `btn-save-product` |
| Checkout | Edit address | `btn-edit-address` |
| Checkout | Place order | `btn-place-order` |
| Checkout | Delivery speed | `btn-delivery-speed-{name}` |
| Checkout | Add address | `btn-add-address` |
| Checkout | Terms checkbox | `chk-terms-accepted` |
| Checkout | Terms link | `link-terms-conditions` |
| Checkout | Privacy link | `link-privacy-policy` |
| Profile | Sign in | `btn-sign-in` |
| Profile | Delete account | `btn-delete-account` |
| Profile | Menu items | `menu-{title-kebab}` |
| Profile | Email support | `link-email-support` |
| Profile | Website | `link-website` |
| EditAddress | Label chips | `chip-address-label-{label}` |
| EditAddress | Save | `btn-save-address` |
| SellerReg | Terms checkbox | `chk-seller-terms` |
| SellerReg | Action button | `btn-seller-action` |
| ShippingApproval | Reject | `btn-reject-cancel` |
| ShippingApproval | Approve | `btn-approve-shipping` |
| ShippingApproval | Confirm cancel | `btn-confirm-cancel-order` |
| Orders | Action buttons | `btn-{label-kebab}` (dynamic) |
| Orders | Pending approvals | `btn-pending-approvals` |
| ProductAddImages | Add photo | `btn-add-photo` |
| ProductAddImages | Remove image | `btn-remove-image` |
| AddressManagement | Add address | `btn-add-address` |
| AddressManagement | Edit address | `btn-edit-address` |
| SellerOrders | Tracking number | `input-tracking-number` |
| SellerOrders | Actual cost | `input-actual-cost` |
| SellerOrders | Tracking (update) | `input-tracking-number-update` |

### Playwright Usage Examples
```typescript
// Wait for Flutter to load
await waitForFlutter(page);

// Click a button by semantic label
await flutterButton(page, 'btn-login-submit').click();

// Fill an input
await fillFlutterInput(page, 'Email', 'user@example.com');

// Click a product card
await productCard(page, 'abc123').click();

// Toggle favorite
await toggleFavorite(page, 'abc123');

// Add to cart
await addToCart(page, 'abc123');

// Check a checkbox
await flutterCheckbox(page, 'chk-terms-accepted').check();

// Click a link
await flutterLink(page, 'link-terms-conditions').click();

// Wait for specific widget to appear
await waitForSemanticLabel(page, 'product-card-abc123');
```

### Adding New Semantics Labels
When adding a new interactive widget:
1. Wrap with `Semantics(button: true, label: 'btn-widget-name', child: ...)` for buttons
2. Use `tooltip:` on `IconButton` (auto-generates aria-label)
3. Use `Semantics(label: 'input-field-name')` for text fields
4. Use `Semantics(checked: value, label: 'chk-name')` for checkboxes
5. Use `Semantics(link: true, label: 'link-name')` for links
6. Follow kebab-case convention with appropriate prefix
7. For dynamic IDs use string interpolation: `'btn-action-${item.id}'`
