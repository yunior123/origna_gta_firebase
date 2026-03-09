---
name: e2e-test-suites
description: 'Catalog of all 33 E2E Playwright tests files (~272 test cases) and 449 backend pytest tests with file locations. Use when running tests, adding tests, or debugging test failures.'
---

# E2E Test Suite Reference

## Test Suite (33 E2E Spec Files — ~272 test cases) + 449 Backend

| File | ~Tests | Focus |
|------|--------|-------|
| premium-subscription.spec.ts | 49 | Subscription lifecycle, Stripe 3DS |
| digital-product-e2e.spec.ts | 34 | Digital delivery, license, download |
| stock-notif.spec.ts | 23 | Back-in-stock notifications |
| edge-cases-security.spec.ts | 22 | Adversarial/security scenarios |
| new-coverage-e2e.spec.ts | 14 | Gap coverage |
| checkout-validation.spec.ts | 14 | Cart/checkout guards |
| add-product-e2e.spec.ts | 12 | Product creation flow |
| admin-panel.spec.ts | 11 | Admin dashboard |
| stripe-payment.spec.ts | 7 | Payment pipeline |
| shipping-calculation.spec.ts | 7 | Cost calculation |
| order-cancellation-refund.spec.ts | 7 | Cancel/refund lifecycle |
| multi-seller-orders.spec.ts | 6 | Split-order handling |
| warehouse-multi-location.spec.ts | 5 | Multi-warehouse ops |
| order-notifications.spec.ts | 5 | Order status emails |
| order-lifecycle.spec.ts | 5 | Full order state machine |
| admin-security.spec.ts | 5 | Admin access controls |
| seller-registration.spec.ts | 4 | Stripe Connect onboarding |
| seller-product-management.spec.ts | 4 | Seller CRUD |
| search-products.spec.ts | 4 | Algolia search |
| profile-management.spec.ts | 4 | User profile CRUD |
| payment-edge-cases.spec.ts | 4 | Stripe edge cases |
| notifications.spec.ts | 4 | Notification flows |
| password-reset.spec.ts | 3 | Auth recovery |
| new-notification-features.spec.ts | 3 | Push/in-app notifications |
| admin-actions.spec.ts | 3 | Admin-only operations |
| trending-products.spec.ts | 2 | Trending algorithm |
| shipping-approval.spec.ts | 2 | Shipping workflow |
| return-request.spec.ts | 2 | Return/refund requests |
| rate-limiting.spec.ts | 2 | Rate limit enforcement |
| favorites.spec.ts | 2 | Wishlist operations |
| smoke-home-profile.spec.ts | 1 | Smoke tests |
| seller-flow.spec.ts | 1 | Seller journey |
| buyer-flow.spec.ts | 1 | Full buyer journey |

### Critical: api-helpers.ts — Canonical E2E Module
**ALL spec files import from `e2e/api-helpers.ts`** (~830 lines, 40+ exports). Never duplicate these utilities.

Key exports:
- **Auth**: `signIn(email, password?)` — fail-fast, throws if no idToken
- **Callables**: `callCallable(fn, data, token)`, `callOk(fn, data, token)` (throws on error), `callExpectError(fn, data, token, code)`
- **Firestore REST**: `readDoc(collection, id)`, `writeDoc(collection, id, fields)`, `patchDoc(collection, id, fields)` (uses updateMask!), `deleteDoc(collection, id)`, `listDocs(collection)`, `listSubcollection(collection, id, sub)`
- **Firestore encoding**: `toFirestoreFields(obj)`, `toFsVal(v)`, `sv()/iv()/bv()`, `parseVal(v)`, `parseDoc(doc)`
- **Checkout**: `buildCheckoutPayload()`, `buildMultiSellerPayload()`, `createOrder()`, `forceOrderStatus()`
- **Polling**: `pollDocField(collection, id, field, expected, timeout)`, `waitForOrderStatus()`
- **Stripe UI**: `fillStripeCheckout(page)` (handles Link popup + 3DS + overlay), `fullCheckoutAndPay(page, token)`, `fullMultiSellerCheckoutAndPay(page, token)`
- **Setup**: `checkInfrastructure()`, `ensureSeedData()`, `createTestUser(email, pass, displayName)`
- **Constants**: `AUTH_EMULATOR`, `FIRESTORE_EMULATOR`, `FUNCTIONS_EMULATOR`, `WEB_APP_URL`, `PROJECT_ID`, `FIRESTORE_BASE`, `DEFAULT_PASS`, `STRIPE_CARD`, `TEST_ACCOUNTS`, `TEST_PRODUCTS`

### Stripe E2E Knowledge
- Card `4242424242424242` is NOT enrolled in 3D Secure
- "VerificationModal" is Stripe's "Link" login popup — dismiss with `page.locator('[data-testid="VerificationModal"]')` close button
- `fillStripeCheckout()` handles: Link popup dismissal → iframe card fill → Pay button → wait for navigation
- Tests needing Stripe webhooks require `stripe listen --forward-to localhost:5001/orignagta/us-central1/stripeWebhook` running
- NOTE: fill() IS correct for Stripe native HTML inputs (card number, expiry, CVC, email fields). The pressSequentially() rule applies only to Flutter Web semantic DOM elements.

---

### comprehensive-flows-e2e.spec.ts — 32 tests (NEW)
10 suites (A-J) covering previously untested Cloud Function endpoints:
- A. Seller Onboarding (3): request, check status, get dashboard link
- B. User Profile (4): get, update, update address (Canada), reject non-Canada
- C. Cart & Favorites (3): add/get cart items, toggle favorites
- D. Admin MFA (3): setup, verify, status check
- E. Payment Providers (3): list providers, get connect status, check Stripe account
- F. Webhook Edge Cases (3): missing signature, invalid event, duplicate event
- G. Product Lifecycle (3): create, update, soft-delete
- H. GDPR & Roles (3): export data, delete account request, role management
- I. Multi-Province Tax (4): ON(HST 13%), QC(GST+QST 14.975%), AB(GST 5%), BC(GST+PST 12%)
- J. Shipping Cost (3): standard calculation, free shipping threshold, bulk/heavy surcharge

**Key constants**: `BUYER1_EMAIL = 'yuniorrodriguezo460@gmail.com'`, `SELLER1_EMAIL = 'seller1@test.origna.ca'`, `PRODUCT_HIGH_STOCK = 'product_001'`
**Rate limit note**: J.1 has 65s delay because `create_checkout_session` has 5 req/min limit and I.* tests exhaust it.

### fullstack-e2e.spec.ts — 37 tests
Core marketplace flow: auth, products, cart, checkout, orders

### payment-workflow-e2e.spec.ts — 62 tests  
Mega payment workflow: 10 suites (A-J) covering edge cases, multi-seller, stock, auth, refunds

### regression-e2e.spec.ts — 42 tests
10 regression suites (A-J): order statuses, timeline, confirm receipt, checkout data, cart ops, item status, payment status, schema consistency, rating formula, multi-seller
**Fixes applied (Feb 2026):**
1. `patchDoc()` now uses `updateMask.fieldPaths` to avoid replacing entire Firestore documents
2. H3: Fixed contradictory assertion (`createdAt` both defined AND undefined) → now checks `createdAt` vs `dateCreated`
3. G1: Restores `order_test_004.paymentStatus` to `captured` before asserting (C3 had modified it to `authorized`)

### logic-failures-e2e.spec.ts — 29 tests
7 logic attack suites (A-G):
- A. Financial Integrity (5): price tampering, subtotal mismatch, platform fee, zero/negative qty
- B. State Machine Violations (5): skip transitions, terminal revival, double ship, uncaptured refund
- C. Cron Job Logic (4): auto-confirm 7d, expired auth 7d, archive 30d, rate limit cleanup
- D. Suspension Cascade (4): deactivated products, blocked add, self-suspend, ghost seller
- E. Stock Integrity (4): cancel restores, double-cancel idempotent, delete blocked, concurrent race
- F. Permission Boundary (3): buyer self-refund, non-onboarded seller, fake rating
- G. Cross-Boundary (4): self-purchase, wrong seller, MFA-gated, GDPR active orders

### flutter-web-e2e.spec.ts — 14 tests
Flutter web app smoke tests: page loads, navigation, responsive layout

### shipping-lifecycle-e2e.spec.ts — 48 tests
Full shipping lifecycle: label generation, tracking, delivery confirmation, multi-province

### admin-email-test.spec.ts — 3 tests
Real email delivery verification (requires real Mailjet credentials)

---

### Seed Scripts
| Script | Data | Notes |
|--------|------|-------|
| `mega-seed.ts` | 76 users, 30 products, ~20 carts, 8 orders | **Use this for E2E** |
| `seed-emulator.ts` | 25 users, 16 products, 3 carts | Deprecated — NOT recommended |
| `seed-orders.py` | 8 orders at various statuses | Deprecated — now built into mega-seed.ts |
| `write_cycle.py` | Cycles order through all statuses (10s each) | — |

### mega-seed.ts — CRITICAL for E2E
**MUST run before any E2E test**: `cd e2e && npx ts-node mega-seed.ts`

Seeds:
- **76 users** in Auth Emulator + Firestore /users collection (buyers, sellers, admins)
- **30 products** in Firestore /products (various categories, prices, stock levels)
- **Cart items** for buyer accounts
- **8 orders** (`order_test_001` to `order_test_008`):
  - 001: pending/pending
  - 002: confirmed/captured
  - 003: processing/captured
  - 004: shipped/captured (with trackingNumber + carrier)
  - 005: in_transit/captured (with trackingNumber + carrier)
  - 006: delivered/captured
  - 007: cancelled/refunded
  - 008: multi-seller (2 items from different sellers, sellerAddress array)

Order fields: `orderStatus`, `paymentStatus`, `paymentProvider: 'stripe'`, `subtotalCents/shippingCostCents/taxAmountCents/totalAmountCents`, `stripePaymentIntentId` (pi_test_* prefix), `items` with `imageUrls` (picsum.photos), `shippingAddress`, `createdAt`

Key user: `yuniorrodriguezo460@gmail.com` — used as buyer by regression + payment tests

### Stock Warning
- `product_002` (Leather Bag) can run out from repeated tests
- Prefer `product_001` (Scarf, 25 stock) or `product_007` (Jerky, 60 stock)

---

### Firestore REST API Quick Reference (Emulator)

```bash
# Read a document
curl "http://localhost:8080/v1/projects/orignagta/databases/(default)/documents/COLLECTION/DOC_ID" \

# PATCH a document (MUST use updateMask to avoid replacing entire doc!)
curl -X PATCH \
  "http://localhost:8080/v1/projects/orignagta/databases/(default)/documents/COLLECTION/DOC_ID?updateMask.fieldPaths=field1&updateMask.fieldPaths=field2" \
  -H "Content-Type: application/json" \
  -d '{"fields":{"field1":{"stringValue":"value"}}}'

# List all documents in a collection
curl "http://localhost:8080/v1/projects/orignagta/databases/(default)/documents/COLLECTION" \
```

**⚠️ CRITICAL**: Firestore REST PATCH without `updateMask` replaces the ENTIRE document. Always include `updateMask.fieldPaths` for partial updates.

### Test Ordering Gotchas
- Tests within a file run sequentially and can modify shared Firestore data
- If test C modifies a document, test G must restore it before asserting
- Rate limiter now has 100x multiplier in emulator mode (`functions/services/rate_limiter.py`) — but still not infinite
- `create_checkout_session` base limit: 5 req/min × 100 = 500 req/min in emulator
- **Firestore REST PATCH without `updateMask`** replaces the ENTIRE document — `patchDoc()` in api-helpers.ts handles this correctly

### E2E Startup Checklist
```bash
# 1. Start emulators
firebase emulators:start --import=./emulator-data

# 2. Seed data (REQUIRED — Auth Emulator starts with 0 users!)
cd e2e && npx ts-node mega-seed.ts

# 3. (Optional) Start Stripe webhook forwarding for payment tests
stripe listen --forward-to localhost:5001/orignagta/us-central1/stripeWebhook

# 4. Run tests
npx playwright test regression-e2e.spec.ts  # or any spec file
```

### Emulator Detection in Backend
`functions/services/rate_limiter.py` checks `os.environ.get('FIRESTORE_EMULATOR_HOST')` to detect emulator mode. When detected, applies `_EMULATOR_RATE_MULTIPLIER = 100` to `max_requests`. This prevents rate limit throttling during parallel E2E test execution.
