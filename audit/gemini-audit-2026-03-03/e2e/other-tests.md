# E2E Audit — Other Tests
**Files:** api-coverage, chat-screen, deep-ui-scenarios, digital-product-e2e, edge-cases-security, favorites, premium-subscription, product-video-e2e, profile-management, qa-product, rate-limiting, return-request, search-products, shipping-approval, shipping-calculation, smoke-home-profile, stock-notif, subcategory-filtering, trending-products, warehouse-multi-location
**Date:** 2026-03-03
**Model:** gemini-3-pro-preview

---

## api-coverage.spec.ts

**[HIGH]** TEST: Multiple (`D2`, `E4`, `L1`, others)
ISSUE: Extremely weak assertions — tests execute a callable and assert `expect(result).toBeTruthy()`. A returned error object is truthy, so broken endpoints pass.
FIX: Assert `expect(result.error).toBeUndefined()` and validate the expected response shape.

**[LOW]** TEST: `B1`, `B3` Address CRUD
ISSUE: Missing coverage for address limit boundary — handles the 10-address limit by conditionally deleting, but no explicit test asserts that adding an 11th address returns the expected error.
FIX: Add a dedicated test creating 10 dummy addresses and asserting the 11th call fails with the limit error.

---

## chat-screen.spec.ts

**[CRITICAL]** TEST: `T02: Premium user can open chat screen after seeding premium subscription`
ISSUE: Doesn't test what it claims — only makes an API call (`get_chat_threads`) and asserts the response. Never navigates to or renders the chat screen UI.
FIX: Add Playwright page navigation and UI assertions to verify chat screen renders without a paywall.

**[HIGH]** TEST: `T01: Non-premium user sees paywall on chat`
ISSUE: Flaky selector + race condition — `waitForTimeout(5000)` then dumps all `flt-semantics` inner text and runs regex. Fails if app takes 6+ seconds.
FIX: Replace with `await page.waitForSelector('flt-semantics[aria-label*="Premium"]', { state: 'attached' })`.

**[MEDIUM]** TEST: `T04: Message limit boundary — API accepts messages within 500 cap`
ISSUE: Doesn't test what it claims — only sends 3 messages and asserts `successCount >= 1`. Never actually tests the 500 cap boundary.
FIX: Seed a thread with 499 messages via admin DB write, then send 1 (expect success) and 1 more (expect rejection).

---

## deep-ui-scenarios.spec.ts

**[HIGH]** TEST: `A1: Buyer can browse home, see product cards, and view product details`
ISSUE: Hardcoded mouse coordinates and wheel scrolling — viewport-dependent, prone to breaking in CI.
FIX: Use `await buyNowBtn.scrollIntoViewIfNeeded()` and rely on Playwright's auto-scrolling.

**[HIGH]** TEST: `A2: Buyer can search for products using the search bar`
ISSUE: Race condition — `waitForTimeout(3_000)` for "Algolia debounce" is arbitrary and slow.
FIX: Use `page.waitForResponse(res => res.url().includes('algolia'))` or wait for loading spinner to detach.

**[LOW]** TEST: `F2: Home screen loads with product cards and navigation works`
ISSUE: `expect(count).toBeGreaterThanOrEqual(0)` — always passes even if 0 products load due to error.
FIX: Seed at least one product in `beforeAll` and assert `toBeGreaterThan(0)`.

**[LOW]** TEST: `C1: Admin navigates to admin panel and verifies all tabs`
ISSUE: `waitForTimeout(2_000)` used for tab content load.
FIX: Assert a specific element inside the tab panel becomes visible instead.

---

## digital-product-e2e.spec.ts

**[CRITICAL]** TEST: `E.4 Book download session token is single-use` & `G.2 software download token is single-use`
ISSUE: False logic — asserts `[200, 302, 410].includes(firstUse.status)` passes on first use even if token is already expired (410 on first use).
FIX: Strictly assert `[200, 302]` on first use, and `410` only on second use.

**[MEDIUM]** TEST: Suite A, B, C (all tests)
ISSUE: Hardcoded product IDs (`DIGITAL_SW_ID = 'product_031'`, `DIGITAL_BOOK_ID = 'product_010'`) — entire suite fails if DB is re-seeded.
FIX: In `beforeAll`, dynamically query Firestore for a product where `isDigital == true && digitalType == 'software'`.

**[MEDIUM]** TEST: `C.2 Mixed cart checkout creates order`
ISSUE: `waitForTimeout(5_000)` after `fillStripeCheckout` — race condition.
FIX: Remove static timeout; wait for success redirect URL or success DOM element before polling order status.

---

## edge-cases-security.spec.ts

**[HIGH]** TEST: `5. Duplicate checkout within 60s returns existing order (duplicate=true)`
ISSUE: Fallback assertion `expect(typeof second.orderId).toBe('string')` means the test passes even if idempotency fails entirely.
FIX: Remove fallback. Strictly assert `expect(second.duplicate).toBe(true)` and `expect(second.orderId).toBe(first.orderId)`.

**[LOW]** TEST: Setup (`rawCheckoutPayload`)
ISSUE: Hardcoded shipping address — can cause cache collisions or false positives in deduplication logic.
FIX: Use dynamic fake data generation (Faker) for shipping addresses.

---

## favorites.spec.ts

**[MEDIUM]** TEST: `T06: UI — Favorite toggle on product card updates heart state`
ISSUE: Toggles button, waits 2000ms, toggles again — never asserts UI actually updated (heart icon state).
FIX: Remove `waitForTimeout`. Assert semantic state changes before second click: `await expect(favBtn).toHaveAttribute('aria-pressed', 'true')`.

---

## premium-subscription.spec.ts

**[CRITICAL]** TEST: `G4: invoice.payment_failed → subscription status becomes past_due`
ISSUE: Does not trigger the webhook — only calls status API and conditionally asserts state if already `past_due`. Never verifies the actual state transition.
FIX: Actively trigger the webhook (Stripe CLI or mock HTTP POST) and verify status changes from `active` to `past_due`.

**[HIGH]** TEST: Multiple tests (Suites B, I, M)
ISSUE: CSS attribute selectors for ARIA props (`locator('[aria-label="btn-cancel-subscription"]')`) instead of Playwright's native locators.
FIX: Use `page.getByLabel('btn-cancel-subscription')` or `page.getByRole()`.

**[MEDIUM]** TEST: Multiple (`C2`, `C3`, `D1`, `D4`, `E1`, `E2`, `E3`, `F1`, `F2`)
ISSUE: `page.waitForLoadState('networkidle')` — Playwright discourages this; background analytics/tracking requests on Stripe pages cause timeouts.
FIX: Replace with waiting for a specific deterministic UI element: `await page.locator('h2:has-text("Subscribe")').waitFor()`.

**[MEDIUM]** TEST: `Suite J (Platform Fee Waiver)`
ISSUE: Only tests API-level fee waiver logic — never verifies the Cart/Checkout UI hides or zeroes the fee for premium users.
FIX: Add a UI-driven test logging in as a premium user, going to checkout, and asserting the platform fee is $0.00 or absent.

**[MEDIUM]** TEST: `D1: 4242 card → successful subscription`
ISSUE: Manual `for` loop + `setTimeout` polling Firestore for `currentPeriodEnd`.
FIX: Replace with `expect.poll(async () => await getDoc(...)).toMatchObject({ currentPeriodEnd: expect.any(Number) })`.

**[LOW]** TEST: `M2: SubscriptionSuccessScreen renders at /subscription/success route`
ISSUE: Fallback logic accepts arbitrary elements (login screen, loading indicator) as passing — dilutes test intent.
FIX: Remove fallback conditionals and strictly assert `expect(screenVisible).toBe(true)`.

**[MEDIUM]** TEST: Missing coverage
ISSUE: No tests for updating payment methods on active subscription, managing expired cards, or tier upgrades/downgrades.
FIX: Add new tests for payment method update flow and renewal failure handling.

---

## product-video-e2e.spec.ts

**[HIGH]** TEST: `T01: Upload valid video and verify playback UI state`
ISSUE: Doesn't test what it claims — uploads a file and checks if the word "Video" appears on screen. Never clicks play, checks duration, or submits form to verify E2E persistence.
FIX: Add video player control interactions, form submission, and verify video loads on the product details page.

---

## profile-management.spec.ts

**[HIGH]** TEST: `T05: Add second address`
ISSUE: `isDefault` assertion skipped due to parallel workers mutating the same shared `BUYER_EMAIL` account — the test acknowledges the flakiness in a comment and skips instead of fixing it.
FIX: Dynamically create a unique test user per suite rather than using a shared seed account.

**[HIGH]** TEST: `T10`, `T11`
ISSUE: Race conditions — `waitForTimeout(1000)` and `waitForTimeout(2000)`.
FIX: Replace with `await expect(page).toHaveURL(...)` or `await locator.waitFor({ state: 'visible' })`.

**[MEDIUM]** TEST: `T09`, `T10`, `T11`
ISSUE: CSS attribute selectors `[aria-label^="menu-my-orders"]` inside `waitForSemantic`.
FIX: Use `page.getByLabel(/menu-my-orders/i)` or `page.getByRole()`.

**[LOW]** TEST: API Tests suite
ISSUE: Missing coverage — no tests for updating an existing address or validating form rejections (empty mandatory fields).
FIX: Add API tests for `update_buyer_address` and invalid payload submissions.

---

## qa-product.spec.ts

**[HIGH]** TEST: `T04: Product detail shows Q&A section`
ISSUE: Race condition + blind scrolling — `waitForTimeout(5000)` + scroll loop with `waitForTimeout(500)`.
FIX: Use `locator.scrollIntoViewIfNeeded()` and `await expect(qaText).toBeVisible()`.

**[MEDIUM]** TEST: `T01`, `T02`
ISSUE: This is a UI E2E suite, but T01 and T02 only hit the API. The Q&A UI form is completely untested.
FIX: Add UI interactions to fill the Q&A form, click submit, and verify UI updates.

**[MEDIUM]** TEST: `T04`
ISSUE: Directly targets Flutter's internal `flt-semantics` DOM nodes.
FIX: Use `page.getByText(/questions|q\s*&\s*a/i)` or `page.getByRole()`.

**[MEDIUM]** TEST: All
ISSUE: Hardcoded `TEST_PRODUCT_ID = 'e2e_product_test_seller'`.
FIX: Dynamically create a test product in `beforeAll`.

---

## rate-limiting.spec.ts

**[HIGH]** TEST: `Rapid checkout requests trigger rate limiting`
ISSUE: Doesn't strictly test what it claims — passes if 0 rate limit errors are thrown (as long as total responses = 10).
FIX: Add strict assertion: `expect(rateLimitErrors.length).toBeGreaterThan(0)`.

**[LOW]** TEST: `Rapid checkout requests trigger rate limiting`
ISSUE: No coverage for rate limit expiration — test never verifies that after the window expires, requests succeed again.
FIX: Wait for the rate limit window to expire and assert subsequent request succeeds.

---

## return-request.spec.ts

**[CRITICAL]** TEST: `Cannot request return for digital products`
ISSUE: Empty test block — test exists but has no implementation. Critical business rule (no returns on digital products) is entirely untested.
FIX: Implement: fetch a digital product, complete checkout, assert `create_return_request` throws the expected API/UI error.

**[HIGH]** TEST: `Buyer can request return...`
ISSUE: Hardcoded `productId = 'product_001'`.
FIX: Dynamically create a physical product for this suite.

**[MEDIUM]** TEST: `Buyer can request return...`
ISSUE: Calls `update_order_status` multiple times but doesn't verify "delivered" state was actually reached before initiating return request.
FIX: Await `waitForOrderStatus(orderId, ['delivered'], ...)` before calling `create_return_request`.

**[MEDIUM]** TEST: `Flow 6`
ISSUE: Missing coverage for alternative return paths — seller rejecting the return, buyer cancelling.
FIX: Add tests for rejection and cancellation lifecycle scenarios.

---

## search-products.spec.ts

**[CRITICAL]** TEST: `T05: Search bar accepts input and filters products`
ISSUE: `expect(hasResults >= 0).toBe(true)` is mathematically always true — passes even if search is completely broken.
FIX: Assert product cards match the search query (check text content) or intercept Algolia network response to verify filtering.

**[HIGH]** TEST: `T05: Search bar accepts input and filters products`
ISSUE: CSS attribute selector fallback — `page.locator('input[type="text"]').first()`.
FIX: Use `page.getByRole('textbox')` or ensure `aria-label` is reliably exposed.

**[LOW]** TEST: API Tests (`T01`–`T03`)
ISSUE: Only happy paths tested — missing validation for invalid limits (`-1`, `1000`), malformed cursors, non-existent category IDs.
FIX: Add negative test cases using `callExpectError` helper.

---

## shipping-approval.spec.ts

**[HIGH]** TEST: `Only the order seller can submit shipping cost`
ISSUE: Relies on `sharedOrderId` generated by the previous test — if that test fails or is skipped, this test crashes. No isolation.
FIX: Create a new order via API helpers directly inside this test (or in a `beforeEach` hook).

---

## shipping-calculation.spec.ts

**[MEDIUM]** TEST: `Perishable product without local/same-day option is auto-deactivated by backend`
ISSUE: Race condition — `await new Promise(r => setTimeout(r, 10_000))` waits for Cloud Function processing. Flakes if function takes 11+ seconds or wastes time at 1 second.
FIX: Use `expect.poll()` to continuously query the Firestore doc until `isActive === false` or timeout.

**[MEDIUM]** TEST: `International seller has non-zero shipping cost`
ISSUE: Hardcoded `'e2e_product_intl_seller'` dependency — breaks if deleted or modified in dev environment.
FIX: Dynamically create an international test product and delete in `finally` block.

---

## smoke-home-profile.spec.ts

**[MEDIUM]** TEST: All
ISSUE: Rampant hardcoded waits (`waitForTimeout(500)`, `1500`, `2000`) and raw CSS selector `page.locator('flt-semantics')`.
FIX: Replace static timeouts with `await expect(locator).toBeVisible()` or `page.waitForURL()`. Replace CSS selector with `aria-label` assertion on a known persistent element.

---

## stock-notif.spec.ts

**[HIGH]** TEST: `Suite 2: UI — Stock Restored Removes Notify Me`
ISSUE: Hardcoded `TEMP_PRODUCT_ID = 'test_notif_stock_restore'` — parallel runs or unclean teardowns cause collisions.
FIX: Make dynamic: `const TEMP_PRODUCT_ID = 'test_notif_stock_restore_' + Date.now()`.

**[HIGH]** TEST: Multiple UI tests
ISSUE: Hardcoded `waitForTimeout` calls (3s, 5s, 8s) throughout.
FIX: Replace with `await expect(locator).toBeVisible()` or `page.waitForResponse(...)`.

**[MEDIUM]** TEST: `1.7 Own product (seller) shows "Your Product" message not Notify Me`
ISSUE: `if/else` assertion `expect(isOwn || hasNotify).toBe(true)` — may never test the "Own product" branch.
FIX: Create a temporary OOS product assigned specifically to `TEST_UIDS.ADMIN` to deterministically verify the "Own product" message.

---

## subcategory-filtering.spec.ts

**[HIGH]** TEST: Multiple UI tests
ISSUE: Hardcoded `waitForTimeout` calls throughout.
FIX: Replace with state-based waits.

**[MEDIUM]** TEST: `T07: Click subcategory chip — products filter`
ISSUE: Gracefully skips if no products match — never tests the "empty state" UX.
FIX: Add a specific test selecting a known empty subcategory and asserting the "No products found" message.

---

## trending-products.spec.ts

**[HIGH]** TEST: Multiple UI tests
ISSUE: Hardcoded `waitForTimeout` calls throughout.
FIX: Replace with state-based waits.

**[MEDIUM]** TEST: `Premium user can toggle Trending Products notifications`
ISSUE: Manual `for` loop + `setTimeout` polling Firestore for document updates.
FIX: Use `await expect.poll(async () => await getDoc(...)).toMatchObject({ notifyTrending: true })`.

---

## warehouse-multi-location.spec.ts

**[CRITICAL]** TEST: `T3: duplicate sellerSku products cannot coexist`
ISSUE: Doesn't test what it claims — writes directly to Firestore via `writeDoc` (bypassing backend checks) and only asserts the SKU was saved, not that the duplicate was blocked.
FIX: Call `create_product_atomic` Cloud Function instead of `writeDoc`; assert it throws an error or sets `lifecycleStatus: 'draft'`.

**[CRITICAL]** TEST: `T4`, `T5` (Warehouse inventory logic)
ISSUE: Doesn't test what it claims — manually injects expected final state into Firestore and reads it back. This tests Firestore, not the application logic.
FIX: Use the application's Cloud Function API to create the product with warehouse locations, then read Firestore to assert the backend correctly denormalized data.

**[HIGH]** TEST: Multiple UI tests
ISSUE: Hardcoded `waitForTimeout` throughout.
FIX: Replace with state-based waits.

**[MEDIUM]** TEST: `T2: seller can have multiple warehouses and list them all`
ISSUE: Missing isolation — verifies the seller's warehouses are in the response but doesn't verify other sellers' warehouses are excluded.
FIX: Create a warehouse under a different seller and assert its label does NOT appear in the first seller's response.
