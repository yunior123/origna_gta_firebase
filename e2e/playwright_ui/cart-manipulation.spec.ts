/**
 * OrignaGTA — Cart Manipulation E2E Tests
 * ========================================
 * Tests cart add/update/remove via direct Firestore REST writes
 * (cart is a subcollection under users, not a callable function),
 * plus a UI test that verifies cart items render on the /cart screen.
 *
 * Cart path: users/{userId}/cart/{productId}
 * Cart document fields: productId, quantity, createdAt
 *
 * Target: https://orignagta-dev.web.app (dev Firebase)
 * Run: cd e2e && npx playwright test cart-manipulation.spec.ts --config=playwright.config.dev.ts
 */
import { test, expect } from '@playwright/test';
import {
  signIn,
  callCallable,
  callOk,
  TEST_ACCOUNTS,
  TEST_UIDS,
  WEB_APP_URL,
  getDoc,
  writeDoc,
  deleteDoc,
  toFirestoreFields,
} from './api-helpers';
import {
  waitForFlutter,
  requireWebApp,
  checkSemantics,
  ensureLoggedInAsAdmin,
  BTN_SETTINGS,
} from './flutter-helpers';

// ════════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════════

const TARGET_URL = WEB_APP_URL;
const PRODUCT_ID = 'e2e_product_test_seller';
const BUYER_UID = TEST_UIDS.BUYER;
const CART_DOC_PATH = `users/${BUYER_UID}/cart/${PRODUCT_ID}`;

test.describe('Cart Manipulation', () => {
  test.setTimeout(300_000);
  test.describe.configure({ mode: 'serial' });

  let buyerToken: string;

  test.beforeAll(async () => {
    const auth = await signIn(TEST_ACCOUNTS.BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS);
    buyerToken = auth.idToken;
  });

  // ── T01: Add item to cart via Firestore REST ──────────────────────
  test('T01: Add item to cart via Firestore write', async () => {
    // First, clean up any existing cart entry for this product
    await deleteDoc(CART_DOC_PATH, buyerToken);

    // Write a cart document with required fields
    const cartFields = toFirestoreFields({
      productId: PRODUCT_ID,
      quantity: 1,
      createdAt: new Date(),
    });

    const success = await writeDoc(CART_DOC_PATH, cartFields, buyerToken, false);
    expect(success, 'writeDoc to cart should succeed').toBe(true);

    // Verify the cart item was created
    const doc = await getDoc(CART_DOC_PATH, buyerToken);
    expect(doc, 'Cart document should exist after write').toBeTruthy();
    expect(doc?.productId).toBe(PRODUCT_ID);
    expect(doc?.quantity).toBe(1);
  });

  // ── T02: Update cart quantity via Firestore REST ──────────────────
  test('T02: Update cart item quantity via Firestore write', async () => {
    // Full document update — Firestore rules require all required fields to be present
    // (productId is string, createdAt is timestamp), so we send the full document.
    const updateFields = toFirestoreFields({
      productId: PRODUCT_ID,
      quantity: 3,
      createdAt: new Date(),
    });

    const success = await writeDoc(CART_DOC_PATH, updateFields, buyerToken, false);
    expect(success, 'writeDoc update should succeed').toBe(true);

    // Verify quantity was updated
    const doc = await getDoc(CART_DOC_PATH, buyerToken);
    expect(doc, 'Cart document should still exist').toBeTruthy();
    expect(doc?.quantity).toBe(3);
  });

  // ── T03: Remove item from cart via Firestore REST ─────────────────
  test('T03: Remove item from cart via Firestore delete', async () => {
    const success = await deleteDoc(CART_DOC_PATH, buyerToken);
    expect(success, 'deleteDoc from cart should succeed').toBe(true);

    // Verify cart item was deleted
    const doc = await getDoc(CART_DOC_PATH, buyerToken);
    expect(doc, 'Cart document should not exist after delete').toBeNull();
  });

  // ── T04: Cart shows items on UI ──────────────────────────────────
  test('T04: Cart screen displays added items', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);

    // Step 1: Add item to cart via Firestore so there is at least one item
    const cartFields = toFirestoreFields({
      productId: PRODUCT_ID,
      quantity: 1,
      createdAt: new Date(),
    });
    const writeOk = await writeDoc(CART_DOC_PATH, cartFields, buyerToken, false);
    expect(writeOk, 'Cart item seeded for UI test').toBe(true);

    // Step 2: Navigate to the app and log in as buyer
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);
    await ensureLoggedInAsAdmin(
      page,
      TARGET_URL,
      TEST_ACCOUNTS.BUYER_EMAIL,
      TEST_ACCOUNTS.BUYER_PASS,
    );

    // Step 3: Navigate to cart via the cart button
    const cartBtn = page.getByRole('button', { name: /cart|shopping|panier/i }).first();
    await expect(cartBtn).toBeAttached({ timeout: 30_000 });
    await cartBtn.click();
    await expect(page).toHaveURL(/\/cart/i, { timeout: 20_000 });
    await waitForFlutter(page);

    // Step 4: Verify cart page loaded with "Your Cart" header and has content.
    // Flutter renders in canvas — check for header text and any content below it.
    await page.waitForTimeout(3000); // Let cart items load

    // Verify the cart page title is visible
    const cartTitle = page.locator('flt-semantics').filter({ hasText: /your cart|votre panier/i }).first();
    const hasTitleVisible = await cartTitle.isVisible({ timeout: 15_000 }).catch(() => false);

    // Check for any cart item indicators — use multiple strategies
    const hasProductCard = await page.locator('[aria-label^="product-card-"]').count() > 0;
    const hasCheckoutBtn = await page.getByRole('button', { name: /checkout|proceed|passer/i }).first()
      .isVisible({ timeout: 5_000 }).catch(() => false);
    // Cart with items renders multiple flt-semantics nodes (header + item cards)
    const semanticsCount = await page.locator('flt-semantics').count();
    const hasMultipleNodes = semanticsCount > 3; // header + at least one item card

    // At least the title should be present, and either items or multiple DOM nodes
    const cartLoaded = hasTitleVisible && (hasProductCard || hasCheckoutBtn || hasMultipleNodes);
    expect(cartLoaded, `Cart should load with items (title=${hasTitleVisible}, cards=${hasProductCard}, checkout=${hasCheckoutBtn}, nodes=${semanticsCount})`).toBe(true);

    // Cleanup: remove the item we added
    await deleteDoc(CART_DOC_PATH, buyerToken);
  });
});
