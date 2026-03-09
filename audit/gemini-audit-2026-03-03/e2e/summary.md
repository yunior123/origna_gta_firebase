# E2E Playwright Audit — Summary
**Date:** 2026-03-03
**Model:** gemini-3-pro-preview
**Files audited:** 35 spec files + 2 helper files

---

## Critical Coverage Gaps

1. **Digital product return rule is untested** (`return-request.spec.ts`)
   The test `Cannot request return for digital products` has an empty test body. A critical business rule — that digital products cannot be returned — has zero test coverage. Any regression would ship silently.

2. **Happy path purchase flow never completes** (`buyer-flow.spec.ts`, `stripe-payment.spec.ts`)
   `Complete Buyer Journey` navigates to checkout and goes back without placing an order. The `[BONUS] Cart is cleared after successful order creation` test in `stripe-payment.spec.ts` adds nothing to the cart before asserting it is empty. End-to-end purchase completion is not verified.

3. **Webhook-driven state transitions untested** (`premium-subscription.spec.ts`)
   The `invoice.payment_failed → subscription past_due` test never triggers the webhook. Stripe webhook processing — a critical integration path — is conditionally asserted only if the state already happens to be `past_due`.

4. **Warehouse/inventory logic bypasses the backend** (`warehouse-multi-location.spec.ts`)
   T3, T4, T5 write directly to Firestore via `writeDoc`, bypassing Cloud Functions entirely. They test that Firestore can store a document, not that the application enforces business rules (duplicate SKU prevention, inventory denormalization).

5. **Token cache race condition in multi-worker runs** (`api-helpers.ts`)
   All workers share `/tmp/origna_e2e_tokens.json` with no file-locking. Concurrent writes corrupt the JSON, causing cascading auth failures across the entire test suite. This is a systemic infrastructure bug.

6. **Security tests assert "not found" rather than "permission denied"** (`admin-security.spec.ts`, `admin-actions.spec.ts`)
   Tests use non-existent document IDs (`'nonexistent_test'`, `'nonexistent_order_id'`). The API returns `NOT_FOUND` before reaching permission checks, creating false positive security coverage. Actual authorization rules are never exercised.

7. **Admin/Seller screen tests pass on fallback** (`admin-panel.spec.ts`, `seller-screens-ui.spec.ts`, `admin-reviews.spec.ts`)
   Multiple tests use conditional `if` blocks that silently pass when the target UI element is missing. `T02` and `T03` in `seller-screens-ui.spec.ts` fall back to verifying the dashboard loads. `T02` in `admin-reviews.spec.ts` ends with `expect(true).toBe(true)`.

---

## Most Common Flaky Selector Patterns

**Pattern 1 — Raw `flt-semantics` CSS targeting (24 occurrences across 12 files)**
```typescript
// BAD — Flutter's internal DOM, not stable
page.locator('flt-semantics[role="button"]').nth(0)
page.locator('flt-semantics')
```
FIX: Use `page.getByRole('button', { name: '...' })` or `page.getByLabel('...')`.

**Pattern 2 — CSS attribute selector prefix-match (18 occurrences)**
```typescript
// BAD — String prefix matching is fragile
page.locator('[aria-label^="btn-sign-out"]')
page.locator('[aria-label^="login_submit_button"]')
```
FIX: Use `page.getByLabel(/btn-sign-out/i)` (regex, Playwright-native).

**Pattern 3 — `.nth(0)` / `.first()` on generic roles (15 occurrences)**
```typescript
// BAD — Flutter renders hidden semantic overlay nodes; .first() hits the wrong element
page.getByRole('button', { name: BTN_ADD_PRODUCT }).first()
```
FIX: Use a unique, specific `aria-label` and assert exactly one match.

**Pattern 4 — Hardcoded `waitForTimeout` instead of element waits (40+ occurrences across 20 files)**
```typescript
// BAD — arbitrary sleeps
await page.waitForTimeout(2000);
await page.waitForTimeout(5000);
await new Promise(r => setTimeout(r, 10_000));
```
FIX: `await expect(locator).toBeVisible()`, `page.waitForURL()`, `expect.poll()`.

**Pattern 5 — `page.waitForLoadState('networkidle')` on Stripe pages (8 occurrences)**
```typescript
// BAD — analytics/tracking scripts keep network alive indefinitely
await page.waitForLoadState('networkidle');
```
FIX: Wait for a specific deterministic UI element on the Stripe page.

**Pattern 6 — Volatile Stripe CSS classes (6 occurrences in api-helpers.ts)**
```typescript
// BAD — Stripe obfuscates/changes these
'.LinkModal--close', '.SubmitButton', '[class*="DeclineMessage"]'
```
FIX: Use `[data-testid="..."]`, `aria-label`, or `button:has-text("Close")`.

---

## Top 5 Tests Needing Rewrite

### 1. `buyer-flow.spec.ts` — `Complete Buyer Journey`
Current state: Navigates to checkout and calls `page.goBack()`. Does not place an order.
What it should do: Complete a full purchase: browse → add to cart → checkout → payment → confirm order created.
Blockers to fix first: Relies on hardcoded product ID; needs isolated test product via `beforeAll`.

### 2. `warehouse-multi-location.spec.ts` — `T3`, `T4`, `T5`
Current state: Writes directly to Firestore via `writeDoc`, bypassing all application logic.
What it should do: Call the actual Cloud Function APIs and assert the backend enforces business rules (duplicate SKU blocks, inventory denormalization, subcollection creation).
Blockers to fix first: Needs actual `create_product_atomic` callable wired up in E2E test environment.

### 3. `admin-reviews.spec.ts` — `T02: Reviews list renders or shows empty state`
Current state: Ends unconditionally with `expect(true).toBe(true)`. This test cannot fail under any circumstances.
What it should do: Assert either review items OR empty-state element is visible; assert the correct API response is reflected in the UI.
Blockers to fix first: Needs seeded review data in `beforeAll` for deterministic assertions.

### 4. `seller-screens-ui.spec.ts` — `T02`, `T03`
Current state: Falls back to asserting the dashboard loaded when target screens (Warehouses, Integration) cannot be found.
What it should do: Navigate explicitly to the Warehouses and Integration screens and assert screen-specific headers, buttons, or data tables are visible.
Blockers to fix first: Test seller account must have at least one warehouse and a connected Stripe account seeded.

### 5. `stripe-payment.spec.ts` — `[BONUS] Cart is cleared after successful order creation`
Current state: Asserts an already-empty cart stays empty. The product is never added to the cart before checkout.
What it should do: Add a product to the cart via API or UI, complete checkout, then assert the cart is empty.
Blockers to fix first: Needs isolated product created per test run to avoid shared-state conflicts with other parallel tests.

---

## Overall Statistics

| Severity | Count |
|----------|-------|
| CRITICAL | 18    |
| HIGH     | 42    |
| MEDIUM   | 38    |
| LOW      | 12    |
| **Total**| **110** |

Files with the most findings:
1. `admin-panel.spec.ts` — 6 findings (4 CRITICAL/HIGH)
2. `warehouse-multi-location.spec.ts` — 6 findings (2 CRITICAL)
3. `premium-subscription.spec.ts` — 7 findings (1 CRITICAL)
4. `stripe-payment.spec.ts` — 3 findings (1 CRITICAL)
5. `api-helpers.ts` — 5 findings (1 CRITICAL)
