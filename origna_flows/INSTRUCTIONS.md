# Origna GTA — Playwright AI Audit Instructions

> This document is the **complete reference** for any AI agent auditing, extending, or creating new Playwright E2E tests for the Origna GTA marketplace.

---

## 1. Architecture Overview

**App**: Flutter Web (CanvasKit) + Firebase Firestore + Cloud Functions (Python) + Stripe + Algolia

**Critical Flutter Web Playwright Rules:**
- Flutter renders to `<canvas>`. The ARIA/semantics tree is a **shadow DOM** (`<flt-semantics>`).
- Find elements by: `role`, `aria-label`, or Flutter `Key` (via `[data-key]` or label patterns).
- **NEVER** use text-based selectors like `page.getByText('No Platform Fee')` — i18n text is NOT in the DOM as searchable nodes.
- `fill()` **NEVER works** for Flutter Web text inputs. Use: `locator.click(); locator.pressSequentially('text', { delay: 30 });`
- `page.keyboard.type()` **drifts focus** when multiple fields visible. Use `locator.pressSequentially()` always.
- `Switch.adaptive` needs `Semantics(label:)` wrapper — find with `getByRole('switch', { name: /label/i })`.

**Selectors in order of reliability:**
1. `page.getByRole('button', { name: /pattern/i })` — for buttons (text inside element)
2. `page.locator('[aria-label="exact-label"]')` — for groups/containers
3. `page.locator('[aria-label^="product-card-"]')` — for prefixed groups
4. `page.getByRole('textbox', { name: /field label/i })` — for inputs
5. `page.getByRole('checkbox', { name: /label/i })` — for checkboxes
6. `page.getByRole('switch', { name: /label/i })` — for toggles

---

## 2. Test Environments

| Config | URL | Firebase | When to use |
|--------|-----|----------|-------------|
| `playwright.config.dev.ts` | `https://orignagta-dev.web.app` | `orignagta-dev` | Standard E2E (default) |
| `playwright.config.staging.ts` | `https://orignagta-staging.web.app` | `orignagta-staging` | Pre-release verification |
| `playwright.config.ts` | `http://localhost:5005` | emulator | Local dev |

**Run tests:**
```bash
cd e2e && npx playwright test --config=playwright.config.dev.ts --workers=2
cd e2e && npx playwright test --config=playwright.config.dev.ts --workers=1 --headed
```

**Screenshots** are auto-saved to `~/Desktop/origna-screenshots/<env>/` for UI/UX review.

---

## 3. Test Accounts (Dev Firebase)

| Role | Email | Password | UID |
|------|-------|----------|-----|
| Admin + Seller + Buyer | yr62813@gmail.com | REDACTED_TEST_PASSWORD | RU9MI8vYFkQCakMrJfG8iGTuc012 |
| Seller 1 (Alice Chen) | seller1@mseed.ca | — (no auth, Firestore only) | mseed_seller_1 |
| Seller 2 (Bob Tremblay) | seller2@mseed.ca | — | mseed_seller_2 |
| Seller 3 (Carlos Rivera) | seller3@mseed.ca | — | mseed_seller_3 |
| Seller 4 (incomplete onboarding) | seller4@mseed.ca | — | mseed_seller_4 |

**Mega-seed data** (run `python scripts/mega_seed_dev.py --project orignagta-dev` to re-seed):
- 30 products across all categories and lifecycle states
- 16 orders in every status (pending → disputed)
- 3 return requests (requested, approved, refunded)
- 3 coupons: WELCOME10 (10%), SAVE5NOW ($5), EXPIRED20 (expired)
- 15 favorites + 3 cart items for admin
- 2 digital licenses (REDACTED_SECRET software, REDACTED_SECRET book)

---

## 4. Screen Inventory + Semantics Map

See `SEMANTICS.md` for the complete Flutter semantics label/key reference.

### Routes (named routes from AppRoutes):
| Path | Screen | Auth Required |
|------|--------|---------------|
| `/` | HomeScreen | No |
| `/login` | LoginScreen | No (guest) |
| `/profile` | ProfileScreen | No (shows sign-in if guest) |
| `/product/:id` | ProductDetailsScreen | No |
| `/cart` | CartScreen | Yes |
| `/checkout` | CheckoutScreen | Yes |
| `/orders` | OrdersScreen | Yes |
| `/seller/orders` | SellerOrdersScreen | Seller |
| `/seller/products` | SellerProductsScreen | Seller |
| `/seller/add-product` | AddProductScreen | Seller |
| `/seller/register` | SellerRegistrationScreen | Buyer |
| `/seller/warehouses` | SellerWarehousesScreen | Seller |
| `/admin` | AdminPanelScreen | Admin |
| `/subscription` | SubscriptionScreen | Yes |
| `/favorites` | FavoritesScreen | Yes |
| `/addresses` | AddressManagementScreen | Yes |
| `/chat/:chatId` | ChatScreen | Premium |
| `/payment-success` | PaymentSuccessScreen | Yes |
| `/payment-cancel` | PaymentCancelScreen | Yes |

---

## 5. Existing Test Files

| File | Scope | Approx tests |
|------|-------|-------------|
| `buyer-flow.spec.ts` | Full buyer journey | ~20 |
| `seller-flow.spec.ts` | Seller dashboard | ~15 |
| `seller-registration.spec.ts` | Seller onboarding | ~10 |
| `seller-product-management.spec.ts` | Product CRUD | ~18 |
| `add-product-e2e.spec.ts` | Add product form | ~25 |
| `checkout-validation.spec.ts` | Checkout validations | ~15 |
| `stripe-payment.spec.ts` | Real Stripe checkout | ~12 |
| `payment-edge-cases.spec.ts` | Edge cases | ~20 |
| `order-lifecycle.spec.ts` | Order state machine | ~18 |
| `order-cancellation-refund.spec.ts` | Cancel + refund | ~15 |
| `multi-seller-orders.spec.ts` | Cross-seller orders | ~20 |
| `premium-subscription.spec.ts` | Subscription flows | ~30 |
| `digital-products-e2e.spec.ts` | Digital products | ~20 |
| `favorites.spec.ts` | Favorites | ~10 |
| `search-products.spec.ts` | Search + Algolia | ~12 |
| `shipping-calculation.spec.ts` | Shipping costs | ~15 |
| `shipping-approval.spec.ts` | Shipping approval | ~10 |
| `admin-panel.spec.ts` | Admin operations | ~20 |
| `admin-actions.spec.ts` | Admin actions | ~15 |
| `admin-security.spec.ts` | Admin security | ~12 |
| `edge-cases-security.spec.ts` | Security attacks | ~25 |
| `profile-management.spec.ts` | Profile + addresses | ~15 |
| `rate-limiting.spec.ts` | Rate limiting | ~10 |
| `warehouse-multi-location.spec.ts` | Warehouses | ~15 |
| `new-coverage-e2e.spec.ts` | Misc new coverage | ~20 |
| `smoke-home-profile.spec.ts` | Smoke tests | ~8 |
| `trending-products.spec.ts` | Trending | ~10 |

---

## 6. What to Test — Coverage Gaps to Fill

AI agents writing new tests should prioritize these **uncovered areas**:

### 6.1 Return Request Flow
- Buyer requests return on delivered order
- Seller approves return
- Admin escalation after timeout
- Refund issued on return received
- Test UI states: requested, approved, label_issued, received, refunded, rejected

### 6.2 Coupon / Promo Codes
- Apply WELCOME10 at checkout (10% discount)
- Apply SAVE5NOW ($5 off)
- Try EXPIRED20 → expect error
- Try invalid code → expect error
- Discount shows correctly in order summary
- Coupon usage limit enforced

### 6.3 Product Q&A
- Buyer asks question on product detail page
- Seller answers question
- Other buyers can see Q&A
- Non-seller cannot answer (permission check)

### 6.4 Admin Product Lifecycle
- Admin approves under_review product
- Admin rejects under_review product with reason
- Admin views all products in all states (draft, rejected, archived)

### 6.5 Seller Metrics Dashboard
- Seller can see their metrics
- Admin can view all seller metrics
- Suspicious metrics trigger security alert

### 6.6 Address Book
- Add new Canadian address with Geoapify autocomplete
- Set default address
- Delete address
- Province dropdown works correctly
- Invalid postal code rejected

### 6.7 Chat (Premium)
- Non-premium buyer cannot access chat
- Premium buyer can open chat with seller
- Messages appear in real-time
- Chat marked as read

### 6.8 Digital Product Activation
- Download book after purchase
- Activate software license (REDACTED_SECRET)
- License activation on wrong platform rejected
- Duplicate activation rejected

---

## 7. AI Agent Instructions for Writing New Tests

### Step 1: Read existing similar test
Find the closest existing spec to your new test and use it as a template.

### Step 2: Use `api-helpers.ts` utilities
```typescript
import { ensureLoggedInAsAdmin, callOk, getDoc, writeDoc, deleteDoc } from './api-helpers';

// Login
await ensureLoggedInAsAdmin(page, baseURL, 'yr62813@gmail.com', 'REDACTED_TEST_PASSWORD');

// Seed data
await writeDoc('orders/test-order-1', { orderStatus: 'pending', ... });

// Verify Firestore
const order = await getDoc('orders/test-order-1');
expect(order.orderStatus).toBe('confirmed');

// Cleanup
await deleteDoc('orders/test-order-1');
```

### Step 3: Use Flutter semantics selectors
```typescript
// Buttons
await page.getByRole('button', { name: /proceed to checkout/i }).click();
await page.locator('[aria-label="btn-place-order"]').click();

// Inputs (NEVER fill(), ALWAYS pressSequentially)
const emailField = page.getByRole('textbox', { name: /email/i });
await emailField.click();
await emailField.pressSequentially('test@example.com', { delay: 30 });

// Checkboxes
await page.getByRole('checkbox', { name: /checkbox-accept-terms/i }).check();

// Toggles (Switch)
await page.getByRole('switch', { name: /switch-notify-new-products/i }).click();

// Product cards
await page.locator('[aria-label^="product-card-"]').first().click();
```

### Step 4: Wait for Flutter navigation
```typescript
import { waitForFlutterNavigation, waitForFlutterReady } from './flutter-helpers';
await waitForFlutterReady(page);
await page.locator('[aria-label="btn-place-order"]').click();
await waitForFlutterNavigation(page, '/payment-success');
```

### Step 5: Screenshot after key actions
```typescript
await page.screenshot({ path: `${process.env.HOME}/Desktop/origna-screenshots/dev/test-name-step.png` });
```

---

## 8. Critical Business Rules to Test

### Payment + Stripe
- Price verification: backend re-fetches from Firestore (test price tampering)
- Self-purchase blocked: `sellerId != buyerId`
- Authorization capture window: 7 days (test expired authorization)
- Idempotency: double-click checkout does not create double order

### Canadian Compliance
- Buyers must have Canadian address (postal code validation)
- GST/HST shown on checkout
- CASL: email consent captured at signup
- Quebec users see French content (if `lang=fr`)

### Stock Management
- Out-of-stock product cannot be added to cart
- Low stock warning shown (< 5 units)
- Concurrent purchase does not oversell

### Admin Security
- Admin cannot bypass seller permission for other sellers' products
  - Use SELLER trying to update ADMIN's product (not vice versa — admin bypasses)
- Firestore rules enforced server-side (test without auth token)

---

## 9. Common Test Patterns

### Pattern: Test state after Stripe checkout
```typescript
// 1. Seed product + cart
// 2. Login as buyer
// 3. Navigate to cart → checkout
// 4. Fill Stripe test card: 4242 4242 4242 4242, exp 12/26, cvv 123
// 5. Submit → wait for redirect to /payment-success
// 6. Verify order created in Firestore
// 7. Cleanup: delete order + restore stock
```

### Pattern: Test order lifecycle
```typescript
// 1. Create order with status 'pending' via writeDoc
// 2. Login as seller
// 3. Confirm order → status 'confirmed'
// 4. Mark shipped → status 'shipped'
// 5. Login as buyer
// 6. Confirm receipt → status 'delivered'
// 7. Verify capture triggered
```

### Pattern: Test permissions (security)
```typescript
// 1. Login as USER_A
// 2. Try to modify USER_B's resource
// 3. Expect 403 / permission denied error shown in UI
// 4. Verify Firestore unchanged
```

---

## 10. Debugging Failed Tests

1. Check screenshot at `~/Desktop/origna-screenshots/dev/`
2. Check trace: `npx playwright show-trace test-results/*/trace.zip`
3. Check Flutter semantics present: `page.locator('flt-semantics').count()` — if 0, app built in release mode (no semantics)
4. Run headed: `--headed --workers=1` to watch
5. Check dev Firebase console for function errors
6. Webhook signature error = Stripe webhook URL wrong region

---

## 11. When to Create a New Test File

Create a NEW spec file when:
- Testing a completely separate feature domain (e.g., `return-requests.spec.ts`)
- Tests need isolated `beforeAll`/`afterAll` lifecycle
- More than 10 new tests for one screen/flow

Add to EXISTING spec when:
- 1-5 tests covering edge cases of an existing flow
- Minor variants of existing scenarios

---

## 12. Re-Seeding Dev Data

```bash
cd origna_gta
source functions/venv/bin/activate
python scripts/mega_seed_dev.py --project orignagta-dev
```

This is idempotent — safe to re-run. All docs use `mseed_` prefix.
