# Figma Design Inventory — OrignaGTA

## Canonical File

**Keep**: `qmo1fxXnEejzzhOwr4vrjM` → "OrignaGTA — Mobile UI Design System"
- Contains all actual UI screens
- **This is the single source of truth for design**

**Delete/repurpose**: `JouoXGhUuq7wXbJDSMAtYH` → "OrignaGTA — Complete Design System"
- Contains only design tokens
- Merge the design tokens page into File 2 then delete

---

## Pages Structure (for canonical file)

```
File: OrignaGTA — Mobile UI Design System
├── 🎨 Design Tokens         ← merge from File 1
├── 🛍️  Buyer Flows
├── ⭐ Premium Buyer Flows
├── 🏪 Seller Flows
├── 🛡️  Admin Flows
└── 📦 Component Library
```

---

## All Screens by Role

### 🛍️ Buyer Flows (unauthenticated + authenticated)

| Screen | Route | File | Variants Needed |
|--------|-------|------|-----------------|
| Home / Product Feed | `/` | `home_screen.dart` | Guest, Logged-in, Empty state |
| Login / Register | `/login` | `login_screen.dart` | Login tab, Register tab, Loading, Error |
| Reset Password | via email | `reset_password_screen.dart` | Enter email, Confirm |
| Email Verification | — | `common_screens.dart` | Verification pending |
| Product Details | `/product-details` | `productdetails_screen.dart` | In stock, Out of stock, Multiple images |
| Product by Slug | `/p/{slug}` | — | SEO landing page |
| Categories | `/categories` | `categories_screen.dart` | All, With subcategories |
| Cart | `/cart` | `cart_screen.dart` | Empty, 1 item, Multiple items |
| Cart Item | `/cart-item` | `cartitem_screen.dart` | Single item detail |
| Checkout | `/checkout` | `checkout_screen.dart` | Address step, Payment step, Review step |
| Order Success | `/order-success` | `ordersuccess_screen.dart` | Confirmation |
| Payment Success | `/payment-success` | `payment_screens.dart` | Confirmed |
| Payment Cancel | `/payment-cancel` | `payment_screens.dart` | Cancelled |
| Orders List | `/orders` | `orders_screen.dart` | Empty, List view |
| Order Detail | `/orders/detail` | `order_detail_screen.dart` | **See order lifecycle variants below** |
| Favorites | `/favorites` | `favorites_screen.dart` | Empty, List |
| Profile | `/profile` | `profile_screen.dart` | Own profile |
| Address Management | `/addresses` | `addressmanagement_screen.dart` | Empty, List |
| Edit/Add Address | `/address/edit` | `editaddress_screen.dart` | New, Edit |
| Privacy Policy | `/privacy-policy` | `privacy_policy_screen.dart` | — |
| Terms of Service | `/terms-of-service` | `terms_of_service_screen.dart` | — |
| Subscription | `/subscription` | `subscription_screen.dart` | Non-premium CTA |
| Subscription Success | `/subscription/success` | `subscription_success_screen.dart` | — |
| Subscription Cancel | `/subscription/cancel` | `subscription_cancel_screen.dart` | — |

### ⭐ Premium Buyer Flows (additional screens)

| Screen | Route | File | Variants Needed |
|--------|-------|------|-----------------|
| Chat with Seller | `/chat` | `chat_screen.dart` | Active conversation, Empty, Premium paywall |
| Photo Review (premium) | — | — | Premium badge, Non-premium locked |
| Order Detail (full) | `/orders/detail` | `order_detail_screen.dart` | Return request option visible |

### 🏪 Seller Flows

| Screen | Route | File | Variants Needed |
|--------|-------|------|-----------------|
| Seller Registration | `/seller/register` | `seller_registration_screen.dart` | Step 1: Info, Step 2: Stripe, Pending review |
| Seller Setup | — | `seller_setup_screen.dart` | Onboarding checklist |
| Seller Products | `/seller/products` | `seller_products_screen.dart` | Empty, List, Filter |
| Add Product | `/add-product` | `addproduct_screen.dart` | Step 1: Details, Step 2: Images, Step 3: Video |
| Add Product Images | — | `productaddimages_screen.dart` | Upload state |
| Add Product Video | — | `productaddvideo_screen.dart` | Upload state |
| Edit Product | `/edit-product` | `editproduct_screen.dart` | Edit form |
| Seller Orders | `/seller/orders` | `seller_orders_screen.dart` | Pending, Active, History |
| Shipping Approval | `/shipping-approval` | `shipping_approval_screen.dart` | Ready to ship, Label issued |
| Seller Warehouses | `/seller/warehouses` | `seller_warehouses_screen.dart` | Empty, List |
| Seller Integration | `/seller/integration` | `seller_integration_screen.dart` | Stripe dashboard link |
| Seller Return | `/seller/return` | — | Return callback |

### 🛡️ Admin Flows

| Screen | Route | File | Variants Needed |
|--------|-------|------|-----------------|
| Admin Panel | `/admin` | `admin_panel_screen.dart` | Dashboard, Users tab, Products tab, Orders tab, Security tab |

---

## State Variants Required

### Order Lifecycle (12 states)
Each state must have a design variant in Order Detail:

| State | Color | Description |
|-------|-------|-------------|
| `pending` | Yellow | Awaiting confirmation |
| `confirmed` | Blue | Seller confirmed |
| `processing` | Blue | Being prepared |
| `shipped` | Purple | Label created |
| `in_transit` | Purple | In delivery |
| `delivered` | Green | Received |
| `cancelled` | Red | Cancelled |
| `failed` | Red | Payment failed |
| `expired` | Grey | Session expired |
| `disputed` | Orange | Dispute opened |
| `refunded` | Green | Full refund |
| `partially_refunded` | Green | Partial refund |

### Product Lifecycle
| State | Visible to |
|-------|-----------|
| `active` | Everyone |
| `draft` | Seller only |
| `archived` | Admin only |
| `pending_review` | Admin + Seller |
| `rejected` | Seller only |

### Return Request States (7 states)
| State | Description |
|-------|-------------|
| `requested` | Buyer initiated |
| `approved` | Seller approved |
| `label_issued` | Return label created |
| `received` | Item back at warehouse |
| `refunded` | Refund processed |
| `rejected` | Seller rejected |
| `escalated` | Admin escalated |

### Subscription States
| State | UI |
|-------|----|
| Non-premium | Paywall/upgrade CTA |
| Premium active | Full access, premium badge |
| Premium canceled | Grace period notice |

---

## Component Library (required in design)

- [ ] Buttons (Primary, Secondary, Danger, Ghost, Loading state)
- [ ] Input fields (Default, Error, Disabled, Search)
- [ ] Cards (Product card, Order card, Seller card)
- [ ] Status badges (all order/product states)
- [ ] Bottom navigation bar
- [ ] App bar variants (with back, with actions)
- [ ] Loading indicators
- [ ] Empty states (with CTA, without CTA)
- [ ] Error states
- [ ] Toast/Snackbar messages
- [ ] Dialogs (Confirm, Alert, Info)
- [ ] Premium badge / lock overlay
- [ ] Price display (with/without discount, CAD)

---

## Consolidation Steps (do when Figma MCP rate limit resets)

1. In File 2, create a new page: "Design Tokens"
2. Copy all frames from File 1 (JouoXGhUuq7wXbJDSMAtYH) into the Design Tokens page of File 2
3. Rename File 2 to "OrignaGTA — Complete App Design"
4. Delete File 1 (JouoXGhUuq7wXbJDSMAtYH)
5. Audit all screens against the inventory above
6. Add missing screens/variants
7. Use Gemini CLI design feedback loop: take Flutter screenshots → compare with Figma frames

---

## Design Feedback Loop (Gemini CLI)

```bash
# Take screenshot of a Flutter web screen
playwright screenshot https://orignagta-dev.web.app/ ~/Desktop/flutter_home.png

# Download Figma frame screenshot
# (use Figma MCP get_screenshot or export manually)

# Ask Gemini to compare
gemini "Compare these two images: [flutter_home.png] vs [figma_home.png].
List all discrepancies in: colors, fonts, spacing, layout, missing elements."
```
