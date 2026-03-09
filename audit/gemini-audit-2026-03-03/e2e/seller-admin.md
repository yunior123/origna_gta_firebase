# E2E Audit — Seller & Admin Tests
**Files:** seller-flow, seller-registration, seller-product-management, seller-screens-ui, admin-actions, admin-panel, admin-reviews, admin-security, add-product-e2e, edit-product
**Date:** 2026-03-03
**Model:** gemini-3-pro-preview

---

## seller-flow.spec.ts

**[HIGH]** TEST: `Complete Seller Journey`
ISSUE: Flaky isVisible() check — `await dashboardBtn.isVisible().catch(() => false)` evaluates immediately during Flutter route animation and returns false, silently skipping the block.
FIX: Replace with `waitFor({ state: 'visible', timeout: 5000 })` or `expect().toBeVisible()`.

**[HIGH]** TEST: `Complete Seller Journey`
ISSUE: Doesn't test what it claims — test only clicks nav menu items and goes back immediately; never adds a product, edits a profile, or processes an order.
FIX: Rename to `Seller Navigation Menu Flow`, or implement actual product creation and order management.

**[MEDIUM]** TEST: `Complete Seller Journey`
ISSUE: Flaky selector — `.first()` on generic Flutter buttons can match hidden semantic overlay nodes.
FIX: Use specific `aria-label` selectors (e.g., `[aria-label="add-product-button"]`) and drop `.first()`.

---

## seller-registration.spec.ts

**[HIGH]** TEST: `T06: UI — Seller registration page...`
ISSUE: Race conditions — heavy reliance on `waitForTimeout(3000)` throughout.
FIX: Replace timeouts with element-state assertions: `await expect(page.locator('[aria-label="chk-seller-terms"]')).toBeVisible()`.

**[MEDIUM]** TEST: `T01: Create Connect account`
ISSUE: Hardcoded `country: 'CA'` — may fail if the test account's locale or Stripe validation rules change.
FIX: Parameterize country code via environment variable or profile data.

**[LOW]** TEST: API Tests suite
ISSUE: Only happy paths and generic auth failures tested — missing coverage for rejected terms, incomplete Stripe Connect onboarding.
FIX: Add tests simulating invalid onboarding payloads and incomplete Stripe states.

---

## seller-product-management.spec.ts

**[CRITICAL]** TEST: `T08: UI — Seller sees rejection banner...`
ISSUE: Doesn't test what it claims — if "Fix & Resubmit" button is not found it logs a warning and passes. Defeats the test's entire purpose.
FIX: Remove soft-pass logic. Assert strictly: `await expect(fixBtn).toBeVisible({ timeout: 10000 })`.

**[HIGH]** TEST: `T06`, `T07`, `T08`
ISSUE: Blind scrolling with `page.mouse.wheel(0, 220)` + `waitForTimeout(500)` to find elements — highly flaky in Flutter Web's virtualized accessibility tree.
FIX: Use API calls to filter to the test product, or use app's search/filter UI to navigate directly.

**[HIGH]** TEST: API-driven `beforeAll`
ISSUE: Hardcoded external dependency — uses `https://picsum.photos/400/400` for test image URLs. If Picsum is down or rate-limits CI, product creation fails.
FIX: Use a project-hosted dummy image URL or base64 encoded string.

**[MEDIUM]** TEST: `T07: UI — Product detail page shows product information`
ISSUE: Asserts `hasBuyNow || hasCart || hasOwnMsg || hasNotify` — test doesn't know the state of the product it clicked because it clicks a random product from the home screen.
FIX: Navigate directly to the specific `testProductId` created in `beforeAll` and assert the exact expected state.

---

## seller-screens-ui.spec.ts

**[CRITICAL]** TEST: `T02: Seller Warehouses screen renders`
ISSUE: Doesn't test what it claims — if the warehouse link is not found, falls back to verifying the dashboard rendered (`semanticsCount > 0`) and passes.
FIX: Fail the test if the warehouse link cannot be found; ensure the test user has warehouse data populated.

**[CRITICAL]** TEST: `T03: Seller Integration / Connect screen renders`
ISSUE: Same critical pattern as T02 — missing link causes dashboard verification fallback and false pass.
FIX: Fail the test if the integration link is missing.

**[HIGH]** TEST: `T01`, `T02`, `T03`
ISSUE: Race conditions — `waitForTimeout(2000)` used to wait for FadeSlideIn animation to complete.
FIX: Await a specific unique element on the loaded page rather than an arbitrary timer.

**[MEDIUM]** TEST: `T01`, `T02`, `T03`
ISSUE: Only checks `flt-semantics` node count `> 0` — confirms Flutter didn't crash but not that the correct screen loaded.
FIX: Assert specific header text, unique buttons, or container `aria-label`s exclusive to each screen.

---

## admin-actions.spec.ts

**[HIGH]** TEST: `Non-admin cannot access admin endpoints`
ISSUE: Hardcoded `productId: 'nonexistent_test'` — error may be "Not Found" rather than "Permission Denied", invalidating the security check.
FIX: Assert the error specifically contains `permission-denied` or `unauthenticated`.

**[HIGH]** TEST: `Admin can call admin-only endpoints via API`
ISSUE: Weak assertion — only verifies the error isn't a permission error. A generic 500 also passes.
FIX: Seed valid test data and assert a successful execution with expected response shape.

**[MEDIUM]** TEST: `Admin can access admin panel via profile`
ISSUE: `adminMenu.scrollIntoViewIfNeeded().catch(() => {})` silently suppresses errors.
FIX: Remove `.catch()` and rely on Playwright's auto-waiting/assertions.

---

## admin-panel.spec.ts

**[CRITICAL]** TEST: `T03` through `T09` (all tab tests)
ISSUE: Conditional assertions — `if (await listItems.count() > 0) { expect(...) }`. If UI is broken and elements don't load, tests silently pass.
FIX: Remove conditional `if` statements; seed data so lists are never empty; use strict `await expect(...).toBeVisible()`.

**[HIGH]** TEST: `T03` through `T10`
ISSUE: Race conditions — heavy use of `waitForTimeout(600)` throughout.
FIX: Replace with web-first assertions: `await expect(locator).toBeVisible()`.

**[MEDIUM]** TEST: `T09: Admin Action — View Seller Detail`
ISSUE: Flaky CSS attribute selector `button[aria-label*="view"]`.
FIX: Use `page.getByRole('button', { name: /view|detail/i })`.

**[MEDIUM]** TEST: `T01: Access Control`
ISSUE: Branching test logic based on what happens to render — `if (await goHomeBtn.isVisible().catch(...))` is non-deterministic.
FIX: Ensure app reaches a predictable state before asserting/interacting.

---

## admin-reviews.spec.ts

**[CRITICAL]** TEST: `T02: Reviews list renders or shows empty state`
ISSUE: Ends with `expect(true).toBe(true)` — this test can never fail. It provides zero coverage.
FIX: Assert either review items `toBeVisible()` OR the empty state `toBeVisible()`.

**[HIGH]** TEST: `T01: Admin navigates to Reviews tab`
ISSUE: Conditional execution — `if (hasReviewsTab) { ... } else { console.log(...) }`. Test passes even if tab is missing.
FIX: Remove `if` block; unconditionally `await expect(reviewsTab).toBeVisible()`.

**[HIGH]** TEST: `T03: Admin can flag a review via admin_flag_review API`
ISSUE: Massive conditional logic tree that silently skips mid-execution when dependencies are missing instead of failing.
FIX: Fail explicitly if environment dependencies (seeded data, deployed endpoints) are missing.

**[LOW]** TEST: `T01`, `T02`
ISSUE: `page.locator('[aria-label="admin-tab-reviews"]')` — should use `page.getByLabel()`.
FIX: Replace with `page.getByLabel('admin-tab-reviews')`.

**[LOW]** TEST: `T03`
ISSUE: Hardcoded `productId: 'e2e_product_test_seller'`.
FIX: Generate product dynamically or use a shared constants file for seeded entities.

---

## admin-security.spec.ts

**[HIGH]** TEST: `Non-seller cannot access seller-only endpoints` & `wrong user cannot modify others orders`
ISSUE: Invalid security tests — use `productId: 'nonexistent_test'` and `orderId: 'nonexistent_order_id'`. API rejects these with "Not Found" before checking permissions, creating false positives.
FIX: Use real IDs belonging to a different user and assert specifically for `permission-denied` error codes.

**[MEDIUM]** TEST: Multiple tests
ISSUE: Only tests negative access (unauthorized users blocked). Missing positive counterparts.
FIX: Add tests verifying authorized users (actual sellers, actual order owners) can successfully hit the endpoints.

---

## add-product-e2e.spec.ts

**[CRITICAL]** TEST: `T10: UI — Fill form and attempt publish`
ISSUE: Accepts multiple divergent outcomes as a pass (either navigated away OR stayed due to validation). Never definitively tests a successful product creation happy path.
FIX: Provide all required data (including image), then strictly assert success snackbar appears and app navigates to expected view.

**[HIGH]** TEST: All tests
ISSUE: Extensive hardcoded waits (`waitForTimeout(3000)`, `800`, `300`) throughout.
FIX: Replace with `await expect(publishBtn).toBeVisible()`, `page.waitForURL()`, or network response waits.

**[HIGH]** TEST: `T01`, `T02`, `T06`, `T07`, `T08`, `T09` (API Tests)
ISSUE: Hardcoded external URLs (`https://picsum.photos/...`, `https://www.w3.org/.../dummy.pdf`) — if these services are down or rate-limit CI, tests fail randomly.
FIX: Use internal mocked URLs, test storage bucket URLs, or base64 encoded strings.

**[HIGH]** TEST: `T11: UI — Form validation prevents empty submission`
ISSUE: Only verifies URL doesn't change on empty submit — never checks if validation error messages are displayed.
FIX: Add assertions for specific validation error messages visibility.

**[MEDIUM]** TEST: `T10: UI — Fill form and attempt publish`
ISSUE: Branching `if/else if` chain for category selection — if the primary selector is broken but a loose text fallback works, test passes while accessibility degrades.
FIX: Use a single strict selector: `page.getByRole('option', { name: 'Electronics' })`.

---

## edit-product.spec.ts

**[CRITICAL]** TEST: `T01`, `T02`, `T03`
ISSUE: Hardcoded `SELLER_PRODUCT_ID = 'e2e_product_test_seller'`. If this document doesn't exist, tests call `test.skip()` — false positives (passing builds) in clean CI environments.
FIX: Use `beforeAll` to dynamically create a test product and delete it in `afterAll`.

**[HIGH]** TEST: API Tests
ISSUE: No UI tests — entire file only covers API-level edits.
FIX: Add UI-driven tests: navigate to seller product catalog, open edit form, change values, verify save.

**[MEDIUM]** TEST: `T02: Update product name and price via API`
ISSUE: Accepts price as either float or cents `[newPrice, Math.round(newPrice * 100)]` — does not enforce data contract.
FIX: Determine actual backend format (cents vs float) and assert strictly on that one format.

**[LOW]** TEST: `T01`, `T02`, `T03`
ISSUE: Tests silently `test.skip()` if `update_product` callable returns "not found" — should fail the environment as broken.
FIX: Remove `test.skip` fallback; fail the test explicitly if the callable is missing.
