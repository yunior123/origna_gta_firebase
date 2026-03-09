# Deep E2E Tests Design — 2026-03-01

## Goal
Upgrade 6 shallow Playwright test files from DOM-visibility-only to full-stack tests that actually write to Firestore and verify DB state.

## Approach
- **UI-driven** tests: Fill forms, click buttons through Flutter Web → verify Firestore docs
- **Add-product** gets both callable (API) + UI tests
- Tests run against **dev Firebase** (not emulators)
- Use existing `api-helpers.ts` utilities (`callOk`, `readDoc`, `writeDoc`, `signIn`, etc.)
- Cleanup test data in `afterAll` blocks

---

## File 1: `add-product-e2e.spec.ts` (13 → 12 tests)

| # | Type | Test | Verification |
|---|------|------|-------------|
| T01 | API | Publish physical product via `create_product_atomic` | `readDoc` → name, price, stockQuantity, sellerId, lifecycleStatus=under_review |
| T02 | API | Publish digital product (isDigital, digitalType=software) | `readDoc` → isDigital, digitalType, no shipFrom fields |
| T03 | API | Publish with warehouse | `readDoc` → shipFromCity/Province match warehouse |
| T04 | API | Missing required fields → `invalid-argument` | Error code |
| T05 | API | Negative price → `invalid-argument` | Error code |
| T06 | API | Buyer cannot publish → `permission-denied` | Error code |
| T07 | API | Duplicate SKU rejected | Error code |
| T08 | UI | Fill form end-to-end → publish → success snackbar | `readDoc` → all fields match |
| T09 | UI | Form reset on navigation | No DB write |
| T10 | API | Update product name | `readDoc` → name changed, updatedAt newer |
| T11 | API | Delete product → soft delete | `readDoc` → lifecycleStatus=archived |
| T12 | API | Admin approve product | lifecycleStatus=active, isActive=true |

## File 2: `favorites.spec.ts` (2 → 7 tests)

| # | Type | Test | Verification |
|---|------|------|-------------|
| T01 | UI | Toggle favorite on (click heart) | `readDoc` favorites subcollection, favoriteCount++ |
| T02 | UI | Toggle favorite off | Doc deleted, favoriteCount-- |
| T03 | API | Toggle via callable | `readDoc` verifies state |
| T04 | API | Double-toggle idempotent | Count consistent |
| T05 | API | Favorite non-existent product → not-found | Error code |
| T06 | API | Unauthenticated → unauthenticated | Error code |
| T07 | UI | Favorites page shows favorited product | product-card visible |

## File 3: `profile-management.spec.ts` (4 → 11 tests)

| # | Type | Test | Verification |
|---|------|------|-------------|
| T01 | API | Get profile | Assert uid, email, name, roles present |
| T02 | API | Update profile name | `readDoc` → name changed |
| T03 | API | Update email consent | `readDoc` → emailConsent flipped |
| T04 | API | Add first address (auto-default) | `readDoc` addresses subcol → isDefault=true |
| T05 | API | Add second address (not default) | isDefault=false |
| T06 | API | Set default address | Old default cleared |
| T07 | API | Delete address | Doc gone |
| T08 | API | Max 10 addresses enforced | failed-precondition on 11th |
| T09 | API | Non-Canadian address rejected | invalid-argument |
| T10 | UI | Navigate to addresses page | btn-add-address visible |
| T11 | UI | Add address via form | `readDoc` verifies new address |

## File 4: `search-products.spec.ts` (4 → 8 tests)

| # | Type | Test | Verification |
|---|------|------|-------------|
| T01 | UI | Products load on home | Known product card visible |
| T02 | UI | Search by known product name | Matching card appears |
| T03 | UI | Search with no results | Empty state visible |
| T04 | UI | Product card → detail page | product_detail_name matches |
| T05 | API | Paginated products (limit=5) | products.length ≤ 5, each has required fields |
| T06 | API | Pagination cursor works | No overlap between pages |
| T07 | API | Category filter | All products match category |
| T08 | UI | Clear search resets | Original list returns |

## File 5: `seller-registration.spec.ts` (4 → 7 tests)

| # | Type | Test | Verification |
|---|------|------|-------------|
| T01 | API | Create Connect account | `readDoc` seller_profiles → stripeAccountId exists |
| T02 | API | Get account status | Fields present: stripeAccountId, onboardingCompleted, chargesEnabled |
| T03 | API | Create account link | URL starts with stripe.com |
| T04 | API | Idempotent create | Same accountId, existing=true |
| T05 | API | Suspended user blocked | permission-denied |
| T06 | UI | Registration page elements | chk-seller-terms, btn-seller-action visible |
| T07 | UI | Accept terms → start onboarding | Redirect to Stripe |

## File 6: `seller-product-management.spec.ts` (4 → 7 tests)

| # | Type | Test | Verification |
|---|------|------|-------------|
| T01 | UI | Seller sees own products | product-card-e2e_product_test_seller visible |
| T02 | UI | Navigate to add product | URL = /add-product |
| T03 | API | Get seller products paginated | Products returned with correct sellerId |
| T04 | API | Bulk pause products | readDoc → lifecycleStatus=paused |
| T05 | API | Bulk activate products | lifecycleStatus restored |
| T06 | API | Cannot manage another seller's products | permission-denied |
| T07 | UI | Product detail matches Firestore | readDoc comparison |

---

## Key Patterns
- **Auth:** `signIn(email, password)` from api-helpers
- **Callable:** `callOk(fnName, data, token)` / `callExpectError(fnName, data, token, expectedCode)`
- **DB verification:** `readDoc(collection, id)` → `parseDoc(doc)`
- **Cleanup:** `deleteDoc` or soft-delete in `afterAll`
- **Test products:** Use stable `e2e_product_*` IDs from MEMORY.md
- **Serial mode:** Required for suites sharing state
- **Timeouts:** 60s per test (Flutter Web is slow)
