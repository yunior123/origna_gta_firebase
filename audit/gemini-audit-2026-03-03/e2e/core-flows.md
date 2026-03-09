# E2E Audit — Core Flows
**Files:** buyer-flow, cart-manipulation, checkout-validation, payment-edge-cases, stripe-payment
**Date:** 2026-03-03
**Model:** gemini-3-pro-preview

---

## buyer-flow.spec.ts

**[HIGH]** TEST: `Complete Buyer Journey`
ISSUE: Race conditions — uses `waitForTimeout(2000)` and `waitForTimeout(1500)` instead of element-state waits.
FIX: Replace with `await locator.waitFor({ state: 'attached' })` or `await expect(locator).toBeVisible()`.

**[HIGH]** TEST: `Complete Buyer Journey`
ISSUE: Doesn't test what it claims — test never places an order; it navigates to checkout, checks the tax line, then calls `page.goBack()`.
FIX: Either complete the purchase (click "Place Order") or rename the test to reflect it only tests navigation up to checkout.

**[MEDIUM]** TEST: `Complete Buyer Journey`
ISSUE: Flaky selector — uses `page.locator('flt-semantics[role="button"]').nth(0)` to click address suggestion; nth() index is non-deterministic in Flutter's semantic tree.
FIX: Use `getByRole('button', { name: 'Specific Address Text' })` instead.

---

## cart-manipulation.spec.ts

**[CRITICAL]** TEST: All tests
ISSUE: Hardcoded test data — `const PRODUCT_ID = 'e2e_product_test_seller'`. If this product is deleted or goes out of stock the entire suite fails.
FIX: Dynamically create an isolated product in `beforeAll` and use its generated ID.

**[HIGH]** TEST: `T04: Cart screen displays added items`
ISSUE: Weak assertion — `hasProductCard || hasCheckoutBtn` passes even if the product added via API is not the one shown in the cart.
FIX: Assert the specific product name/ID is present and quantity matches the API payload.

---

## checkout-validation.spec.ts

**[HIGH]** TEST: `Rejects self-purchase`
ISSUE: Hardcoded product ID — `getSellerOwnProduct` hardcodes `const productId = 'e2e_product_test_seller'`.
FIX: Query Firestore for a product where `sellerId` matches the test seller, or create one dynamically.

**[MEDIUM]** TEST: N/A (missing test)
ISSUE: No coverage for inventory edge cases — out-of-stock items, inactive products, deleted product IDs are not tested at checkout.
FIX: Add negative tests attempting checkout with `stockQuantity = 0` and with a non-existent `productId`.

---

## payment-edge-cases.spec.ts

**[HIGH]** TEST: `Declined card shows error on Stripe page`
ISSUE: Flaky selectors + arbitrary waits — uses `waitForTimeout(10_000)` and volatile Stripe CSS classes (`.Alert--error`, `[class*="DeclineMessage"]`). Stripe updates their DOM frequently.
FIX: Use `getByText()` exclusively for user-facing Stripe error messages; replace hard sleep with `expect(...).toBeVisible({ timeout: X })`.

**[MEDIUM]** TEST: `Declined card does not decrement stock`
ISSUE: Faulty assertion — `expect(stockAfter).toBeGreaterThanOrEqual(stockBefore - 1)` masks bugs where the webhook completely fails to restore stock.
FIX: Wait deterministically for exact stock restoration and assert `toBe(stockBefore)`. If webhooks are too slow, trigger them manually or poll order status.

**[HIGH]** TEST: All Stripe Checkout Tests
ISSUE: Hardcoded timeouts and conditional test logic (e.g., `if (await locator.isVisible())`) throughout Stripe UI interactions cause severe flakiness.
FIX: Remove arbitrary timeouts; use `page.waitForURL` or `await expect(locator).toBeVisible({ timeout: X })`.

**[HIGH]** TEST: `3D Secure card triggers authentication challenge`
ISSUE: The 3DS iframe interaction is inside a `try/catch` with a silent fallback — the test can pass even if the 3DS challenge never renders.
FIX: Remove `try/catch` and strictly assert the 3DS iframe appears and "Complete" is clicked.

**[MEDIUM]** TEST: `Currency is always CAD for Canadian buyers`
ISSUE: Never explicitly provisions the buyer's billing address to Canada before asserting currency — relies on implicit account state.
FIX: Explicitly set the test user's country/billing address to Canada during test setup.

**[MEDIUM]** TEST: `Declined card does not decrement stock`
ISSUE: Manual `while` loop + `waitForTimeout(3_000)` to poll stock restoration.
FIX: Replace with `expect.poll(async () => await getProductStock(...)).toBeGreaterThanOrEqual(...)`.

---

## stripe-payment.spec.ts

**[CRITICAL]** TEST: `[BONUS] Cart is cleared after successful order creation`
ISSUE: Doesn't test what it claims — `fullCheckoutAndPay` is called but the product is never added to the cart beforehand; it asserts an already-empty cart stays empty.
FIX: Explicitly add the item to the user's cart via `writeDoc` or UI before calling the checkout flow.

**[HIGH]** TEST: `Stock decremented by exact ordered quantity after payment`
ISSUE: Flaky assertion — `expect(delta).toBeGreaterThanOrEqual(1)` accepts incorrect decrements (2 or 3) due to parallel test assumption with shared product.
FIX: Use `uniqueSuffix`-named isolated product per test to strictly assert `expect(delta).toBe(1)`.

---

## api-helpers.ts

**[CRITICAL]** FUNCTION: `signIn` / `_saveDiskTokens`
ISSUE: Race condition on JSON token cache file — synchronous `fs` methods without file-locking on `/tmp/origna_e2e_tokens.json` corrupt the file in multi-worker environments.
FIX: Use atomic write (write to temp file, rename to final path) or a locking library like `proper-lockfile`.

**[HIGH]** FUNCTION: Global Scope
ISSUE: Hardcoded secrets — `FIREBASE_API_KEY`, user emails, and passwords (`REDACTED_TEST_PASSWORD`) are checked into the repository.
FIX: Move to environment variables: `process.env.FIREBASE_API_KEY`, `process.env.E2E_TEST_PASS`.

**[HIGH]** FUNCTION: `dismissStripeModals` & `fillStripeCheckout`
ISSUE: Relies on Stripe internal volatile CSS classes (`.LinkModal--close`, `.SubmitButton`, etc.) that change frequently.
FIX: Use only `[data-testid="..."]`, `aria-label`, or `button:has-text("Close")` text locators.

**[MEDIUM]** FUNCTION: `readDoc`
ISSUE: Swallows all errors with `if (!res.ok) return null` — masks 401, 403, and 429 as "not found".
FIX: Check `res.status`: return `null` on 404, throw descriptive error on all other 4xx/5xx.

**[MEDIUM]** FUNCTION: `discoverProducts` & `ensureOosProduct`
ISSUE: Concurrent workers mutate shared dev data (restoring stock to 200, forcing to 0) on `STABLE_TEST_PRODUCTS`, causing random assertion failures.
FIX: Use `uniqueSuffix` to create per-worker isolated products instead of global shared IDs.

**[MEDIUM]** FUNCTION: `callOk`
ISSUE: Retry logic handles 500 (cold starts) but fails fast on 429. Transient rate limits during large parallel runs crash tests immediately.
FIX: Include HTTP 429 in retry loop with exponential backoff.

---

## flutter-helpers.ts

**[HIGH]** FUNCTION: `navigateHome`
ISSUE: `for` loop calling `page.goBack()` up to 5 times to reach home is brittle; fails if history stack is deeper or contains external domains (Stripe).
FIX: Provide a reliable semantic home button or inject JS interop to reset the Flutter router.

**[MEDIUM]** FUNCTION: `ensureLoggedInAsBuyer`
ISSUE: Is a plain alias for `ensureLoggedInAsAdmin` — does not enforce buyer credentials; misleading naming.
FIX: Wrap to inject explicit Buyer credentials: `return ensureLoggedIn(page, targetUrl, TEST_ACCOUNTS.BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS)`.

**[MEDIUM]** FUNCTION: `waitForProductCards`
ISSUE: Scrolling 20 times via `page.mouse.wheel(0, 250)` is viewport-dependent and flaky.
FIX: Press `End` key or click a bottom-of-list element; add a semantic "loading complete" Flutter locator.

**[LOW]** FUNCTION: `ensureLoggedInAsAdmin`
ISSUE: Typing race condition — `page.keyboard.type(email, { delay: 30 })` after 800ms wait can drop characters if Flutter refocuses.
FIX: After typing, read `inputValue()` and retry if it doesn't match.
