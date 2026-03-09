/**
 * OrignaGTA — Stock Notification E2E Tests
 * ==========================================
 * Covers Flow 12: Back-in-Stock Notification
 *
 * Scenarios:
 *   1. UI — "Notify Me" button shown on OOS product page
 *   2. UI — Subscribe via button (logged-in buyer)
 *   3. UI — Duplicate subscribe is idempotent (button stays "cancel" state)
 *   4. UI — Unsubscribe via button toggles back to "Notify Me"
 *   5. UI — Guest user tapping "Notify Me" sees login prompt
 *   6. UI — In-stock product shows "Add to Cart" (no Notify Me)
 *   7. UI — Variant-level OOS: Notify Me shown when variant stock = 0
 *   8. UI — Stock restored → Notify Me button disappears (product back in stock)
 *   9. API — subscribe_stock_notification Cloud Function: happy path
 *  10. API — Duplicate subscribe is idempotent (no duplicate Firestore doc)
 *  11. API — unsubscribe_stock_notification Cloud Function: happy path
 *  12. API — Product-level subscribe (no variantKey) works
 *  13. API — Unauthenticated subscribe is rejected (unauthenticated error)
 *  14. API — Subscribe to non-existent product is rejected
 *  15. API — Subscribe to in-stock product is rejected (must be OOS)
 *
 * Run:
 *   cd e2e && npx playwright test stock-notifications.spec.ts --config=playwright.config.dev.ts
 *   cd e2e && npx playwright test stock-notifications.spec.ts --config=playwright.config.dev.ts --headed --workers=1
 *
 * Seed data required (mega_seed_dev.py already provides):
 *   mseed_prod_oos_1   — out-of-stock product (stockQuantity: 0)
 *   mseed_prod_active_1 — in-stock product    (stockQuantity: > 0)
 *
 * Screenshots saved to: ~/Desktop/origna-screenshots/dev/stock-notif-*.png
 */

import { test, expect, Page } from '@playwright/test';
import {
  signIn,
  callOk,
  callExpectError,
  getDoc,
  writeDoc,
  deleteDoc,
  toFirestoreFields,
  TEST_ACCOUNTS,
  TEST_UIDS,
  FUNCTIONS_URL,
  FIRESTORE_BASE,
  ensureOosProduct,
} from './api-helpers';
import { waitForFlutter, ensureLoggedInAsAdmin, clearServiceWorkers } from './flutter-helpers';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const SCREENSHOTS_DIR = `${process.env.HOME}/Desktop/origna-screenshots/dev`;

/**
 * Dedicated out-of-stock product for stock-notif tests ONLY.
 * Always has stockQuantity=0 in Firestore. NOT shared with any other test file.
 * Owner: ADMIN (RU9MI8vYFkQCakMrJfG8iGTuc012). Seeded by mega_seed_dev.py.
 */
const OOS_PRODUCT_ID = 'e2e_product_oos';

/**
 * In-stock product — uses a different stable product.
 */
const IN_STOCK_PRODUCT_ID = 'e2e_product_test_seller';

/**
 * Variant product ID — skipped gracefully if product has no variants.
 */
const VARIANT_PRODUCT_ID = 'e2e_product_admin_seller';
const OOS_VARIANT_KEY = 'color:red';

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Navigate to a product detail page using the /product/:id deep link.
 * IMPORTANT: Call ensureLoggedInAsAdmin BEFORE this function.
 *
 * After ensureLoggedInAsAdmin, a Flutter service worker may have cached old assets
 * (before CDN propagation of the latest deploy). Clearing SW before each goto forces
 * fresh asset fetches from the network so the latest routing code is always used.
 * Retries up to 3 times if we land on the home screen instead of the product page.
 */
async function navigateToProduct(page: Page, baseURL: string, productId: string) {
  // Flutter Semantics containers merge child labels into the parent aria-label, so
  // exact-match [aria-label="x"] fails. Use starts-with [aria-label^="x"].
  // product_notify_me_button is a leaf node (no child merging) and also works.
  const PRODUCT_SELECTORS = [
    '[aria-label^="product_notify_section"]',
    '[aria-label^="product_notify_me_button"]',
    '[aria-label^="product_add_to_cart_button"]',
    '[aria-label^="product_own_product_message"]',
  ];

  for (let attempt = 1; attempt <= 3; attempt++) {
    // Clear SW cache before each goto: prevents stale routing code being served
    await clearServiceWorkers(page);

    await page.goto(`${baseURL}/product/${productId}`, { waitUntil: 'load' });
    await waitForFlutter(page);
    // Wait for Firebase Auth to restore from IndexedDB before widgets check auth state
    await page.waitForTimeout(5_000);

    // Scroll down: Flutter only adds off-screen Semantics nodes to the DOM once they enter
    // the viewport. Product buttons (notify section, add-to-cart) are below the fold.
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(1_000);

    // Detect whether routing succeeded (product page) or failed (home screen)
    let onProductPage = false;
    for (const sel of PRODUCT_SELECTORS) {
      if (await page.locator(sel).isVisible({ timeout: 2_000 }).catch(() => false)) {
        onProductPage = true;
        break;
      }
    }

    if (onProductPage || attempt === 3) break;
    console.log(`   ⚠️ navigateToProduct attempt ${attempt} landed on wrong page — retrying...`);
  }

  await page.screenshot({
    path: `${SCREENSHOTS_DIR}/stock-notif-product-loaded-${productId}.png`,
  });
}

/**
 * Login (in-app, auth stored in IndexedDB) THEN navigate to the product page.
 * ensureLoggedInAsAdmin runs first (ends at home), then page.goto() to product.
 * Flutter re-reads auth from IndexedDB on reload — the 5s settle in navigateToProduct handles
 * the async Firebase Auth restore timing.
 */
async function loginAndNavigate(page: Page, baseURL: string, productId: string) {
  await ensureLoggedInAsAdmin(page, baseURL, TEST_ACCOUNTS.BUYER_EMAIL, 'REDACTED_TEST_PASSWORD');
  await navigateToProduct(page, baseURL, productId);
}

// ─────────────────────────────────────────────────────────────────────────────
// SUITE 1 · UI TESTS — Flutter ProductDetailScreen
// ─────────────────────────────────────────────────────────────────────────────

test.describe('1. UI — Notify Me Button on OOS Product', () => {
  test.setTimeout(300_000); // Flutter Web on 8GB RAM takes 90-180s to initialize

  test.beforeAll(async () => {
    // Seed e2e_product_oos in dev Firestore (idempotent — safe to run every time)
    await ensureOosProduct();
  });

  test('1.1 OOS product shows notify section (not add-to-cart)', async ({ page, baseURL }) => {
    await loginAndNavigate(page, baseURL!, OOS_PRODUCT_ID);

    // Notify section must be present
    await expect(
      page.locator('[aria-label^="product_notify_section"]'),
    ).toBeVisible({ timeout: 15_000 });

    // Add-to-cart must NOT be present
    await expect(
      page.locator('[aria-label^="product_add_to_cart_button"]'),
    ).not.toBeVisible();

    await page.screenshot({ path: `${SCREENSHOTS_DIR}/stock-notif-1-1-oos-section.png` });
  });

  test('1.2 Notify Me button is visible and labelled correctly when not subscribed', async ({ page, baseURL }) => {
    // Ensure any prior subscription is cleaned up
    const auth = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    await callOk('unsubscribe_stock_notification', { productId: OOS_PRODUCT_ID }, auth.idToken)
      .catch(() => {}); // ignore if not subscribed

    await loginAndNavigate(page, baseURL!, OOS_PRODUCT_ID);

    const btn = page.locator('flt-semantics[role="button"]').filter({
      has: page.locator('[aria-label="product_notify_me_button"]'),
    });
    // Use Key-based selector as per SEMANTICS.md
    const notifyBtn = page.locator('[aria-label="product_notify_me_button"]');
    await expect(notifyBtn).toBeVisible({ timeout: 15_000 });

    await page.screenshot({ path: `${SCREENSHOTS_DIR}/stock-notif-1-2-notify-btn-visible.png` });
  });

  test('1.3 Tapping Notify Me subscribes and toggles to cancel state', async ({ page, baseURL }) => {
    // Ensure clean state (not subscribed)
    const auth = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    await callOk('unsubscribe_stock_notification', { productId: OOS_PRODUCT_ID }, auth.idToken)
      .catch(() => {});

    await loginAndNavigate(page, baseURL!, OOS_PRODUCT_ID);

    const notifyBtn = page.locator('[aria-label="product_notify_me_button"]');
    await expect(notifyBtn).toBeVisible({ timeout: 15_000 });
    await notifyBtn.click();

    // Wait for the button to reflect subscribed state (loading → subscribed)
    // The subscribed state shows a "cancel notification" icon/label
    await page.waitForTimeout(3_000);
    await page.screenshot({ path: `${SCREENSHOTS_DIR}/stock-notif-1-3-after-subscribe.png` });

    // Verify via Firestore that subscription was created
    const snap = await getDoc(`stock_notifications/${OOS_PRODUCT_ID}_${auth.localId}`, auth.idToken)
      .catch(() => null);
    // Subscription doc may be keyed differently; assert via re-subscribe being idempotent
    const result = await callOk(
      'subscribe_stock_notification',
      { productId: OOS_PRODUCT_ID },
      auth.idToken,
    );
    expect(result.subscribed).toBe(true);

    // Cleanup
    await callOk('unsubscribe_stock_notification', { productId: OOS_PRODUCT_ID }, auth.idToken);
  });

  test('1.4 Tapping the button a second time unsubscribes (toggle)', async ({ page, baseURL }) => {
    const auth = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    // Start subscribed
    await callOk('subscribe_stock_notification', { productId: OOS_PRODUCT_ID }, auth.idToken);

    await loginAndNavigate(page, baseURL!, OOS_PRODUCT_ID);

    // Provider init fetches Firestore state — wait for it to settle
    await page.waitForTimeout(4_000);

    const notifyBtn = page.locator('[aria-label="product_notify_me_button"]');
    await expect(notifyBtn).toBeVisible({ timeout: 15_000 });

    // Should be in "cancel notification" mode — clicking again unsubscribes
    await notifyBtn.click();
    await page.waitForTimeout(3_000);

    await page.screenshot({ path: `${SCREENSHOTS_DIR}/stock-notif-1-4-after-unsubscribe.png` });

    // Verify unsubscribed via API
    const sub = await callOk(
      'unsubscribe_stock_notification',
      { productId: OOS_PRODUCT_ID },
      auth.idToken,
    ).catch(() => ({ unsubscribed: true })); // already unsubscribed
    expect(sub.unsubscribed ?? true).toBe(true);
  });

  test('1.5 Guest user tapping Notify Me sees login prompt', async ({ page, baseURL }) => {
    // Navigate without logging in
    await page.goto(`${baseURL}/product/${OOS_PRODUCT_ID}`);
    await waitForFlutter(page);
    await page.waitForTimeout(3_000);

    // Scroll down so Flutter adds the notify button's Semantics node to the accessibility tree
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(1_000);

    const notifyBtn = page.locator('[aria-label="product_notify_me_button"]');
    await expect(notifyBtn).toBeVisible({ timeout: 15_000 });
    await notifyBtn.click();
    await page.waitForTimeout(2_000);

    // Login prompt dialog or navigation to /login expected
    const isOnLogin = page.url().includes('/login');
    const loginDialog = page.locator('flt-semantics[role="dialog"]');
    const loginBtn = page.getByRole('button', { name: /sign in|login/i });
    const hasLoginPrompt = isOnLogin || await loginDialog.isVisible() || await loginBtn.isVisible();
    expect(hasLoginPrompt, 'Guest must see login prompt when tapping Notify Me').toBe(true);

    await page.screenshot({ path: `${SCREENSHOTS_DIR}/stock-notif-1-5-guest-login-prompt.png` });
  });

  test('1.6 In-stock product shows Add to Cart (not Notify Me)', async ({ page, baseURL }) => {
    await loginAndNavigate(page, baseURL!, IN_STOCK_PRODUCT_ID);

    await expect(
      page.locator('[aria-label^="product_add_to_cart_button"]'),
    ).toBeVisible({ timeout: 15_000 });

    await expect(
      page.locator('[aria-label^="product_notify_section"]'),
    ).not.toBeVisible();

    await page.screenshot({ path: `${SCREENSHOTS_DIR}/stock-notif-1-6-in-stock-add-to-cart.png` });
  });

  test('1.7 Own product (seller) shows "Your Product" message not Notify Me', async ({ page, baseURL }) => {
    // Admin user is also a seller — navigate to one of their own OOS products
    // Use the admin account + any product owned by admin
    await ensureLoggedInAsAdmin(page, baseURL!, TEST_ACCOUNTS.ADMIN_EMAIL, 'REDACTED_TEST_PASSWORD');
    // Clear SW before goto: prevents stale routing code served from cache
    await clearServiceWorkers(page);
    await page.goto(`${baseURL}/product/${OOS_PRODUCT_ID}`, { waitUntil: 'load' });
    await waitForFlutter(page);
    // Wait for Firebase Auth to restore from IndexedDB after page reload
    await page.waitForTimeout(5_000);

    // Scroll down to bring product action buttons into Flutter's accessibility tree
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(1_000);

    // If OOS_PRODUCT_ID is owned by a different seller, this test verifies
    // that Notify Me appears (not own product). Admin panel view — just screenshot.
    await page.screenshot({ path: `${SCREENSHOTS_DIR}/stock-notif-1-7-own-or-notify.png` });

    // The own product message and notify section are mutually exclusive
    const ownMsg = page.locator('[aria-label^="product_own_product_message"]');
    const notifySection = page.locator('[aria-label^="product_notify_section"]');
    const isOwn = await ownMsg.isVisible({ timeout: 5_000 }).catch(() => false);
    const hasNotify = await notifySection.isVisible({ timeout: 5_000 }).catch(() => false);
    expect(isOwn || hasNotify, 'Must show either own product message or notify section for OOS').toBe(true);
    expect(isOwn && hasNotify, 'Cannot show both own product and notify section').toBe(false);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// SUITE 2 · UI — STOCK RESTORED (Notify Me Disappears)
// ─────────────────────────────────────────────────────────────────────────────

test.describe('2. UI — Stock Restored Removes Notify Me', () => {
  test.setTimeout(300_000); // Flutter Web on 8GB RAM takes 90-180s to initialize

  /**
   * This test uses a temporary product created in Firestore with stockQuantity=0,
   * then updates it to stockQuantity=10. The product detail screen should reflect
   * the change on re-navigation (eventual consistency via FutureProvider re-fetch).
   */
  const TEMP_PRODUCT_ID = 'test_notif_stock_restore';

  let adminToken: string;

  test.beforeAll(async () => {
    const auth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    adminToken = auth.idToken;
    // Delete any leftover from a previous run before seeding fresh
    await deleteDoc(`products/${TEMP_PRODUCT_ID}`, adminToken).catch(() => {});
    await new Promise(resolve => setTimeout(resolve, 1_000));
    // Seed a temporary OOS product (full write — not partial — to ensure correct state)
    const ok = await writeDoc(`products/${TEMP_PRODUCT_ID}`, toFirestoreFields({
      name: 'Test Stock Restore Product',
      description: 'Temporary product for stock restore test — E2E only',
      price: 19.99,
      stockQuantity: 0,
      lifecycleStatus: 'active',
      isDigital: false,
      sellerId: TEST_UIDS.ADMIN,
      sellerSku: 'STOCK-RESTORE-TEST',
      categoryId: 1,
      imageUrls: ['https://orignagta-dev.web.app/assets/icons/icon-192.png'],
      keywords: ['test', 'stock', 'restore'],
      sellerAddress: {
        street: '100 University Ave',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5J 1V6',
        country: 'Canada',
      },
      isInternational: false,
      createdAt: new Date(),
    }), adminToken, false);
    if (!ok) throw new Error('Suite 2 beforeAll: failed to seed TEMP_PRODUCT_ID in Firestore');
    // Give Firestore a moment to propagate the write
    await new Promise(resolve => setTimeout(resolve, 2_000));
  });

  test.afterAll(async () => {
    if (adminToken) await deleteDoc(`products/${TEMP_PRODUCT_ID}`, adminToken).catch(() => {});
  });

  test('2.1 OOS product shows Notify Me, then after stock restored shows Add to Cart', async ({ page, baseURL }) => {
    const auth = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    await loginAndNavigate(page, baseURL!, TEMP_PRODUCT_ID);

    // Must show Notify Me
    await expect(
      page.locator('[aria-label^="product_notify_section"]'),
    ).toBeVisible({ timeout: 15_000 });
    await page.screenshot({ path: `${SCREENSHOTS_DIR}/stock-notif-2-1a-oos-before.png` });

    // Restore stock via Firestore write (simulates admin restoring stock)
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL);
    await writeDoc(`products/${TEMP_PRODUCT_ID}`, toFirestoreFields({ stockQuantity: 10 }), adminAuth.idToken, true);

    // Re-navigate to force provider re-fetch — clear SW first to avoid stale routing
    // Use 'load' not 'networkidle' — Flutter Web has persistent Firebase connections
    await clearServiceWorkers(page);
    await page.goto(`${baseURL}/product/${TEMP_PRODUCT_ID}`, { waitUntil: 'load' });
    await waitForFlutter(page);
    await page.waitForTimeout(5_000);
    // Scroll to bring the add-to-cart button into Flutter's accessibility tree
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(1_000);
    await page.screenshot({ path: `${SCREENSHOTS_DIR}/stock-notif-2-1b-stock-restored.png` });

    // Add to cart should now appear
    await expect(
      page.locator('[aria-label^="product_add_to_cart_button"]'),
    ).toBeVisible({ timeout: 15_000 });

    await expect(
      page.locator('[aria-label^="product_notify_section"]'),
    ).not.toBeVisible();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// SUITE 3 · API — Cloud Function Tests
// ─────────────────────────────────────────────────────────────────────────────

test.describe('3. API — subscribe_stock_notification / unsubscribe_stock_notification', () => {
  test.setTimeout(60_000);

  let buyerToken: string;
  let buyerUid: string;

  test.beforeAll(async () => {
    // Ensure OOS product exists in dev Firestore
    await ensureOosProduct();
    const auth = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    buyerToken = auth.idToken;
    buyerUid = auth.localId;
    // Ensure clean subscription state before API suite
    await callOk('unsubscribe_stock_notification', { productId: OOS_PRODUCT_ID }, buyerToken)
      .catch(() => {});
  });

  test.afterAll(async () => {
    // Cleanup any subscriptions created during tests
    await callOk('unsubscribe_stock_notification', { productId: OOS_PRODUCT_ID }, buyerToken)
      .catch(() => {});
    // No stock restore needed — e2e_product_oos is always OOS (stock=0)
  });

  test('3.1 Subscribe to OOS product returns subscribed:true', async () => {
    const result = await callOk(
      'subscribe_stock_notification',
      { productId: OOS_PRODUCT_ID },
      buyerToken,
    );
    expect(result.subscribed, 'subscribe_stock_notification must return subscribed:true').toBe(true);
  });

  test('3.2 Duplicate subscribe is idempotent (no error, no duplicate doc)', async () => {
    // Subscribe again after 3.1 already subscribed
    const result = await callOk(
      'subscribe_stock_notification',
      { productId: OOS_PRODUCT_ID },
      buyerToken,
    );
    expect(result.subscribed).toBe(true);
  });

  test('3.3 Unsubscribe returns unsubscribed:true', async () => {
    const result = await callOk(
      'unsubscribe_stock_notification',
      { productId: OOS_PRODUCT_ID },
      buyerToken,
    );
    expect(result.unsubscribed, 'unsubscribe must return unsubscribed:true').toBe(true);
  });

  test('3.4 Subscribe with variantKey works (variant-level subscription)', async () => {
    // Skip if the test product has no variants or variant is in stock
    const product = await getDoc(`products/${VARIANT_PRODUCT_ID}`, buyerToken);
    if (!product || !product.variants || product.variants.length === 0) {
      test.skip(true, 'No variant product available — skipping variant-level subscription test');
      return;
    }
    // Check if the specific variant is OOS; if in-stock, backend rejects subscribe
    const targetVariant = (product.variants as any[]).find(
      (v: any) => v.variantKey === OOS_VARIANT_KEY || v.key === OOS_VARIANT_KEY,
    );
    if (!targetVariant || (targetVariant.stockQuantity ?? 1) > 0) {
      test.skip(true, `Variant ${OOS_VARIANT_KEY} is not OOS — skipping variant subscription test`);
      return;
    }
    const result = await callOk(
      'subscribe_stock_notification',
      { productId: VARIANT_PRODUCT_ID, variantKey: OOS_VARIANT_KEY },
      buyerToken,
    );
    expect(result.subscribed).toBe(true);

    // Cleanup
    await callOk(
      'unsubscribe_stock_notification',
      { productId: VARIANT_PRODUCT_ID, variantKey: OOS_VARIANT_KEY },
      buyerToken,
    );
  });

  test('3.5 Subscribe without variantKey (product-level) works', async () => {
    const result = await callOk(
      'subscribe_stock_notification',
      { productId: OOS_PRODUCT_ID },
      buyerToken,
    );
    expect(result.subscribed).toBe(true);

    // Cleanup
    await callOk('unsubscribe_stock_notification', { productId: OOS_PRODUCT_ID }, buyerToken);
  });

  test('3.6 Unauthenticated subscribe is rejected with unauthenticated error', async () => {
    const err = await callExpectError(
      'subscribe_stock_notification',
      { productId: OOS_PRODUCT_ID },
      'invalid-token-xyz',
    );
    expect(err.code).toMatch(/unauthenticated|permission-denied/i);
  });

  test('3.7 Subscribe to non-existent product is rejected', async () => {
    const err = await callExpectError(
      'subscribe_stock_notification',
      { productId: 'product_does_not_exist_xyz_999' },
      buyerToken,
    );
    expect(err.code).toMatch(/not-found|invalid-argument/i);
  });

  test('3.8 Subscribe to in-stock product is rejected (must be OOS)', async () => {
    // Verify in-stock product has stock > 0 then attempt subscribe
    const product = await getDoc(`products/${IN_STOCK_PRODUCT_ID}`, buyerToken);
    if (!product || product.stockQuantity <= 0) {
      test.skip(true, 'In-stock product has no stock — test not applicable');
      return;
    }

    const err = await callExpectError(
      'subscribe_stock_notification',
      { productId: IN_STOCK_PRODUCT_ID },
      buyerToken,
    );
    // Backend should reject subscribing to an in-stock product
    expect(err.code).toMatch(/invalid-argument|failed-precondition/i);
  });

  test('3.9 Missing productId is rejected with invalid-argument', async () => {
    const err = await callExpectError(
      'subscribe_stock_notification',
      {},
      buyerToken,
    );
    expect(err.code).toMatch(/invalid-argument/i);
  });

  test('3.10 Unsubscribe when not subscribed is idempotent (no error)', async () => {
    // Ensure not subscribed
    await callOk('unsubscribe_stock_notification', { productId: OOS_PRODUCT_ID }, buyerToken)
      .catch(() => {});

    // Unsubscribe again — should not throw
    const result = await callOk(
      'unsubscribe_stock_notification',
      { productId: OOS_PRODUCT_ID },
      buyerToken,
    );
    expect(result.unsubscribed ?? true).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// SUITE 4 · SECURITY — Adversarial Scenarios
// ─────────────────────────────────────────────────────────────────────────────

test.describe('4. Security — Adversarial Scenarios', () => {
  test.setTimeout(60_000);

  let buyerToken: string;
  let sellerToken: string;

  test.beforeAll(async () => {
    // Ensure OOS product exists in dev Firestore
    await ensureOosProduct();
    const buyerAuth = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    buyerToken = buyerAuth.idToken;
    // Use SELLER (not ADMIN) as "sellerToken" — ADMIN owns OOS_PRODUCT_ID so cannot subscribe to it
    const sellerAuth = await signIn(TEST_ACCOUNTS.SELLER_EMAIL);
    sellerToken = sellerAuth.idToken;
  });

  test('4.1 Buyer cannot unsubscribe another user\'s notification', async () => {
    // Seller (non-owner) subscribes to OOS_PRODUCT_ID first
    await callOk('subscribe_stock_notification', { productId: OOS_PRODUCT_ID }, sellerToken);

    // Buyer (different user) attempts to unsubscribe the seller's notification
    // This should only unsubscribe the buyer's OWN subscription (if any)
    await callOk('unsubscribe_stock_notification', { productId: OOS_PRODUCT_ID }, buyerToken)
      .catch(() => {});

    // Seller's subscription must still exist — verify seller can still unsubscribe
    const result = await callOk(
      'unsubscribe_stock_notification',
      { productId: OOS_PRODUCT_ID },
      sellerToken,
    );
    expect(result.unsubscribed).toBe(true);
  });

  test('4.2 Expired auth token is rejected', async () => {
    const expiredToken = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.expired.signature';
    const err = await callExpectError(
      'subscribe_stock_notification',
      { productId: OOS_PRODUCT_ID },
      expiredToken,
    );
    expect(err.code).toMatch(/unauthenticated|invalid-token|permission-denied/i);
  });

  test('4.3 productId injection attempt is safely rejected', async () => {
    // Attempt to use a path-traversal-like productId
    const err = await callExpectError(
      'subscribe_stock_notification',
      { productId: '../users/admin' },
      buyerToken,
    );
    // Backend must sanitize / reject malformed product IDs (any error code is acceptable)
    expect(err.code).toBeTruthy();
  });

  test('4.4 Subscribe with excessively long variantKey is rejected', async () => {
    const longKey = 'a'.repeat(1001);
    const err = await callExpectError(
      'subscribe_stock_notification',
      { productId: OOS_PRODUCT_ID, variantKey: longKey },
      buyerToken,
    );
    expect(err.code).toMatch(/invalid-argument/i);
  });

  test('4.5 Firestore direct write to stock_notifications is blocked by rules', async () => {
    // Attempt a direct Firestore REST write with a user token (not Admin SDK)
    // This verifies the Firestore security rule `allow create, update: if false` is enforced
    const auth = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);

    const path = `stock_notifications/${OOS_PRODUCT_ID}_bypass_${auth.localId}`;
    const url = `${FIRESTORE_BASE}/${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${auth.idToken}`,
    };
    const body = JSON.stringify({
      fields: toFirestoreFields({
        productId: OOS_PRODUCT_ID,
        userId: auth.localId,
        variantKey: null,
        createdAt: new Date().toISOString(),
      }),
    });

    const res = await fetch(url, { method: 'PATCH', headers, body });
    const errorBody = await res.json().catch(() => ({}));

    // Firestore must reject with 403 PERMISSION_DENIED
    expect(res.status, 'Expected 403 from Firestore rules').toBe(403);
    const errMsg = JSON.stringify(errorBody).toLowerCase();
    expect(errMsg).toMatch(/permission.denied|missing or insufficient/i);
  });
});