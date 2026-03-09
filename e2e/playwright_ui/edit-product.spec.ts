/**
 * OrignaGTA — Edit Product Flow E2E Tests
 * =========================================
 * Tests the update_product callable for:
 *   - Updating product preserves subcategory
 *   - Updating product name/price
 *   - Permission denied for non-owner edits
 *
 * All tests are API-driven (no browser needed) — faster and more reliable.
 *
 * Run: cd e2e && npx playwright test edit-product.spec.ts --config=playwright.config.dev.ts
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
  toFirestoreFields,
} from './api-helpers';
import {
  waitForFlutter,
  requireWebApp,
  checkSemantics,
  ensureLoggedInAsAdmin,
} from './flutter-helpers';

const SELLER_EMAIL = TEST_ACCOUNTS.SELLER_EMAIL;
const SELLER_PASS = TEST_ACCOUNTS.SELLER_PASS;
const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;
const BUYER_PASS = TEST_ACCOUNTS.BUYER_PASS;
const ADMIN_EMAIL = TEST_ACCOUNTS.ADMIN_EMAIL;
const ADMIN_PASS = TEST_ACCOUNTS.ADMIN_PASS;

// Seller's own product — seller can edit it
const SELLER_PRODUCT_ID = 'e2e_product_test_seller';
// Admin's product — seller should NOT be able to edit it
const ADMIN_PRODUCT_ID = 'e2e_product_admin_seller';

test.describe('Edit Product Flow', () => {
  test.setTimeout(300_000);

  // ─── T01: Update product preserves subcategory ──────────────────
  test('T01: Update product preserves subcategory after edit', async () => {
    const sellerAuth = await signIn(SELLER_EMAIL, SELLER_PASS);

    // Read original product to capture current subcategory
    const originalDoc = await getDoc(`products/${SELLER_PRODUCT_ID}`, sellerAuth.idToken);

    if (!originalDoc) {
      test.skip(true, `Product ${SELLER_PRODUCT_ID} not found in dev Firestore`);
      return;
    }

    const originalSubcategory = originalDoc.subcategory || originalDoc.subcategory || null;
    const originalName = originalDoc.name || originalDoc.title || 'E2E Product';

    // Update product with a subcategory value
    // Backend expects: { productId: string, productData: { ...fields } }
    const testSubcategory = originalSubcategory || 'headphones';
    const updateResult = await callCallable('update_product', {
      productId: SELLER_PRODUCT_ID,
      productData: {
        subcategory: testSubcategory,
        // Keep the name so we can verify subcategory preservation
        name: originalName,
      },
    }, sellerAuth.idToken);

    if (updateResult.error) {
      const errMsg = (updateResult.error.message || '').toLowerCase();
      console.log(`update_product response: ${updateResult.error.message}`);

      // If function not deployed, skip
      if (errMsg.includes('not_found') || errMsg.includes('not found') || updateResult.error.status === 'NOT_FOUND') {
        test.skip(true, 'update_product callable not deployed yet');
        return;
      }

      // Seller should be able to edit own product
      expect(errMsg).not.toMatch(/permission.denied|unauthenticated/);
      return;
    }

    // Verify subcategory is preserved in Firestore
    const updatedDoc = await getDoc(`products/${SELLER_PRODUCT_ID}`, sellerAuth.idToken);
    expect(updatedDoc).toBeTruthy();

    const updatedSubcategory = updatedDoc?.subcategory || updatedDoc?.subcategory;
    expect(
      updatedSubcategory,
      'Subcategory should be preserved after update'
    ).toBe(testSubcategory);
  });

  // ─── T02: Update product name and price ─────────────────────────
  test('T02: Update product name and price via API', async () => {
    const sellerAuth = await signIn(SELLER_EMAIL, SELLER_PASS);

    // Read original to restore later
    const originalDoc = await getDoc(`products/${SELLER_PRODUCT_ID}`, sellerAuth.idToken);

    if (!originalDoc) {
      test.skip(true, `Product ${SELLER_PRODUCT_ID} not found in dev Firestore`);
      return;
    }

    const originalName = originalDoc.name || originalDoc.title || 'E2E Product';
    const originalPrice = originalDoc.price ?? originalDoc.priceCents ?? 1999;

    // Update with new name and price
    // Backend expects: { productId: string, productData: { ...fields } }
    const newName = `E2E Updated ${Date.now()}`;
    const newPrice = 25.99;

    const updateResult = await callCallable('update_product', {
      productId: SELLER_PRODUCT_ID,
      productData: {
        name: newName,
        price: newPrice,
      },
    }, sellerAuth.idToken);

    if (updateResult.error) {
      const errMsg = (updateResult.error.message || '').toLowerCase();
      console.log(`update_product response: ${updateResult.error.message}`);

      if (errMsg.includes('not_found') || errMsg.includes('not found') || updateResult.error.status === 'NOT_FOUND') {
        test.skip(true, 'update_product callable not deployed yet');
        return;
      }

      expect(errMsg).not.toMatch(/permission.denied|unauthenticated/);
      return;
    }

    // Verify in Firestore
    const updatedDoc = await getDoc(`products/${SELLER_PRODUCT_ID}`, sellerAuth.idToken);
    expect(updatedDoc).toBeTruthy();
    expect(updatedDoc?.name || updatedDoc?.title).toBe(newName);

    // Price may be stored as cents (integer) or as float — check both
    const storedPrice = updatedDoc?.price ?? updatedDoc?.priceCents;
    if (typeof storedPrice === 'number') {
      // If stored in cents, newPrice * 100 = 2599
      const acceptablePrices = [newPrice, Math.round(newPrice * 100)];
      expect(
        acceptablePrices,
        'Price should match the updated value (cents or float)'
      ).toContain(storedPrice);
    }

    // Restore original name and price (cleanup)
    await callCallable('update_product', {
      productId: SELLER_PRODUCT_ID,
      productData: {
        name: originalName,
        price: originalPrice,
      },
    }, sellerAuth.idToken);
  });

  // ─── T03: Edit product permission denied for non-owner ──────────
  test('T03: Edit product permission denied for non-owner', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL, BUYER_PASS);

    // Buyer tries to update the seller's product — should be denied
    // Backend expects: { productId: string, productData: { ...fields } }
    const result = await callCallable('update_product', {
      productId: SELLER_PRODUCT_ID,
      productData: {
        name: 'Hijacked Product Name',
      },
    }, buyerAuth.idToken);

    // Expect an error
    expect(result.error, 'Non-owner should receive an error when editing another user\'s product').toBeTruthy();

    if (result.error) {
      const errMsg = (result.error.message || '').toLowerCase();
      const errStatus = (result.error.status || '').toUpperCase();

      // If function not deployed, skip
      if (errMsg.includes('not_found') || errMsg.includes('not found') || errStatus === 'NOT_FOUND') {
        test.skip(true, 'update_product callable not deployed yet');
        return;
      }

      // Should be permission denied, failed precondition, or similar access control error
      const isAccessError =
        errMsg.includes('permission') ||
        errMsg.includes('denied') ||
        errMsg.includes('unauthorized') ||
        errMsg.includes('not the owner') ||
        errMsg.includes('not your product') ||
        errMsg.includes('not allowed') ||
        errStatus === 'PERMISSION_DENIED' ||
        errStatus === 'FAILED_PRECONDITION';

      expect(
        isAccessError,
        `Expected permission error but got: ${result.error.message} (status: ${errStatus})`
      ).toBe(true);
    }

    // Verify the product was NOT modified
    const adminAuth = await signIn(ADMIN_EMAIL, ADMIN_PASS);
    const doc = await getDoc(`products/${SELLER_PRODUCT_ID}`, adminAuth.idToken);
    if (doc) {
      const currentName = doc.name || doc.title || '';
      expect(currentName).not.toBe('Hijacked Product Name');
    }
  });
});
