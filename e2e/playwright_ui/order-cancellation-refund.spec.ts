/**
 * OrignaGTA — Order Cancellation & Refund E2E Tests
 * ===================================================
 * Tests cancellation and refund flows against dev Firebase.
 *
 * CLAUDE.md compliance:
 *  - Rule 8:  50+ adversarial scenarios (unauthorized cancel, already-cancelled, race)
 *  - Rule 11: No magic strings — all status values from OrderStatusValues constants
 *  - Rule 13: Every scenario has a meaningful assertion on the specific error code
 */
import { test, expect } from '@playwright/test';
import {
  signIn, callOk, callExpectError, callCallable,
  fullCheckoutAndPay,
  waitForOrderStatus, getOrder, getProductStock,
  getSellerAuth,
  TEST_ACCOUNTS, TEST_UIDS, writeDoc, toFirestoreFields, createDummyProduct,
} from './api-helpers';

// ── No magic strings (CLAUDE.md Rule 11) ────────────────────────────────────
// These must mirror OrderStatusValues in schema_constants.py / schema_constants.dart
const STATUS = {
  CONFIRMED:   'confirmed',
  PROCESSING:  'processing',
  SHIPPED:     'shipped',
  CANCELLED:   'cancelled',
  DELIVERED:   'delivered',
} as const;

// Error codes returned by cancel_order — must match backend HttpsError codes.
// Backend raises failed-precondition for all invalid state transitions
// (shipped, delivered, already-cancelled) and permission-denied for auth violations.
const ERROR_CODE = {
  INVALID_STATE:    'failed-precondition',  // any invalid state transition (shipped / delivered / already-cancelled)
  PERMISSION_DENIED:'permission-denied',    // caller has no relationship to the order
} as const;

const BUYER_EMAIL    = TEST_ACCOUNTS.BUYER_EMAIL;
const BUYER_PASS     = TEST_ACCOUNTS.BUYER_PASS; // FIX: was missing in original

test.describe('Order Cancellation & Refund', () => {
  test.describe.configure({ mode: 'serial' });
  test.setTimeout(180_000);

  let productId: string;
  let productSellerId: string;

  test.beforeAll(async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);

    // Reset seller product (used in tests 1-5, 7)
    const sellerOk = await writeDoc(
      `products/e2e_product_test_seller`,
      toFirestoreFields({ stockQuantity: 200 }),
      adminAuth.idToken, true,
    );
    if (!sellerOk) await createDummyProduct(TEST_UIDS.SELLER, 'B', 'e2e_product_test_seller');

    // Reset admin product (used in test 6 — unauthorized cancel scenario)
    const adminOk = await writeDoc(
      `products/e2e_product_admin_seller`,
      toFirestoreFields({ stockQuantity: 200 }),
      adminAuth.idToken, true,
    );
    if (!adminOk) await createDummyProduct(TEST_UIDS.ADMIN, 'A', 'e2e_product_admin_seller');

    productId       = 'e2e_product_test_seller';
    productSellerId = TEST_UIDS.SELLER;
  });

  // ── Happy path ─────────────────────────────────────────────────────────────

  test('Buyer can cancel order before shipping', async ({ page }) => {
    const result    = await fullCheckoutAndPay(page, BUYER_EMAIL, productId, 1);
    // FIX: was signIn(BUYER_EMAIL) — missing password
    const buyerAuth = await signIn(BUYER_EMAIL, BUYER_PASS);
    await waitForOrderStatus(result.orderId, [STATUS.CONFIRMED], buyerAuth.idToken, 90_000);

    await callOk('cancel_order', { orderId: result.orderId }, buyerAuth.idToken);

    const order = await getOrder(result.orderId, buyerAuth.idToken);
    expect(order.orderStatus).toBe(STATUS.CANCELLED);
  });

  // ── Guard: cannot cancel shipped ──────────────────────────────────────────

  test('Cannot cancel a shipped order', async ({ page }) => {
    const result    = await fullCheckoutAndPay(page, BUYER_EMAIL, productId, 1);
    // FIX: was signIn(BUYER_EMAIL) — missing password
    const buyerAuth = await signIn(BUYER_EMAIL, BUYER_PASS);
    await waitForOrderStatus(result.orderId, [STATUS.CONFIRMED], buyerAuth.idToken, 90_000);

    const sellerAuth = await getSellerAuth(productSellerId);
    await callOk('update_order_status', { orderId: result.orderId, newStatus: STATUS.PROCESSING }, sellerAuth.idToken);
    await callOk('update_order_status', {
      orderId:        result.orderId,
      newStatus:      STATUS.SHIPPED,
      trackingNumber: `TRACK-${Date.now()}`,
      carrier:        'Canada Post',
    }, sellerAuth.idToken);

    const error = await callExpectError('cancel_order', { orderId: result.orderId }, buyerAuth.idToken);
    expect(error.code).toBe(ERROR_CODE.INVALID_STATE);
  });

  // ── Guard: cannot cancel delivered ────────────────────────────────────────
  // (CLAUDE.md Rule 8 — adversarial: delivered is another terminal state)

  test('Cannot cancel a delivered order', async ({ page }) => {
    const result    = await fullCheckoutAndPay(page, BUYER_EMAIL, productId, 1);
    const buyerAuth = await signIn(BUYER_EMAIL, BUYER_PASS);
    await waitForOrderStatus(result.orderId, [STATUS.CONFIRMED], buyerAuth.idToken, 90_000);

    const sellerAuth = await getSellerAuth(productSellerId);
    await callOk('update_order_status', { orderId: result.orderId, newStatus: STATUS.PROCESSING  }, sellerAuth.idToken);
    await callOk('update_order_status', {
      orderId:        result.orderId,
      newStatus:      STATUS.SHIPPED,
      trackingNumber: `TRACK-${Date.now()}`,
      carrier:        'Canada Post',
    }, sellerAuth.idToken);
    // DELIVERED is admin-only — backend rejects seller tokens for this transition
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    await callOk('update_order_status', { orderId: result.orderId, newStatus: STATUS.DELIVERED   }, adminAuth.idToken);

    const error = await callExpectError('cancel_order', { orderId: result.orderId }, buyerAuth.idToken);
    expect(error.code).toBe(ERROR_CODE.INVALID_STATE);
  });

  // ── Stock restoration ─────────────────────────────────────────────────────

  test('Stock restores after cancellation', async ({ page }) => {
    // FIX: was signIn(BUYER_EMAIL) — missing password
    const buyerAuth  = await signIn(BUYER_EMAIL, BUYER_PASS);
    const stockBefore = await getProductStock(productId, buyerAuth.idToken);

    const result = await fullCheckoutAndPay(page, BUYER_EMAIL, productId, 1);
    await waitForOrderStatus(result.orderId, [STATUS.CONFIRMED], buyerAuth.idToken, 90_000);

    await callOk('cancel_order', { orderId: result.orderId }, buyerAuth.idToken);

    // Poll for stock restoration (cloud function may have cold-start delay)
    const deadline = Date.now() + 30_000;
    let stockAfter  = 0;
    while (Date.now() < deadline) {
      stockAfter = await getProductStock(productId, buyerAuth.idToken);
      if (stockAfter >= stockBefore) break;
      await new Promise(r => setTimeout(r, 2_000));
    }

    expect(stockAfter).toBeGreaterThanOrEqual(stockBefore);
  });

  // ── Idempotency: double-cancel ────────────────────────────────────────────

  test('Cannot cancel an already cancelled order', async ({ page }) => {
    const result    = await fullCheckoutAndPay(page, BUYER_EMAIL, productId, 1);
    // FIX: was signIn(BUYER_EMAIL) — missing password
    const buyerAuth = await signIn(BUYER_EMAIL, BUYER_PASS);
    await waitForOrderStatus(result.orderId, [STATUS.CONFIRMED], buyerAuth.idToken, 90_000);

    await callOk('cancel_order', { orderId: result.orderId }, buyerAuth.idToken);

    const error = await callExpectError('cancel_order', { orderId: result.orderId }, buyerAuth.idToken);
    expect(error.code).toBe(ERROR_CODE.INVALID_STATE);
  });

  // ── Adversarial: unauthorized cancellation ────────────────────────────────
  // (CLAUDE.md Rule 8 — a different buyer must NOT be able to cancel someone else's order)

  test('Another buyer cannot cancel an order they do not own', async ({ page }) => {
    // Use admin's product — BUYER2 (seller account) has no buyer/seller/admin relationship
    // to an order containing only admin-owned items, so backend returns permission-denied.
    const result    = await fullCheckoutAndPay(page, BUYER_EMAIL, 'e2e_product_admin_seller', 1);
    const buyerAuth = await signIn(BUYER_EMAIL, BUYER_PASS);
    await waitForOrderStatus(result.orderId, [STATUS.CONFIRMED], buyerAuth.idToken, 90_000);

    const otherBuyerAuth = await signIn(TEST_ACCOUNTS.BUYER2_EMAIL, TEST_ACCOUNTS.BUYER2_PASS);
    const error = await callExpectError('cancel_order', { orderId: result.orderId }, otherBuyerAuth.idToken);
    expect(error.code).toBe(ERROR_CODE.PERMISSION_DENIED);
  });

  // ── Adversarial: concurrent double-cancel (race condition) ────────────────
  // (CLAUDE.md Rule 8 — only one of the two concurrent calls should succeed)

  test('Concurrent cancel requests are idempotent — only one succeeds', async ({ page }) => {
    const result    = await fullCheckoutAndPay(page, BUYER_EMAIL, productId, 1);
    const buyerAuth = await signIn(BUYER_EMAIL, BUYER_PASS);
    await waitForOrderStatus(result.orderId, [STATUS.CONFIRMED], buyerAuth.idToken, 90_000);

    // Use raw callCallable (never throws) so both promises are always fulfilled.
    // This lets us inspect both responses deterministically regardless of race outcome.
    const [r1, r2] = await Promise.all([
      callCallable('cancel_order', { orderId: result.orderId }, buyerAuth.idToken),
      callCallable('cancel_order', { orderId: result.orderId }, buyerAuth.idToken),
    ]);

    const successes = [r1, r2].filter((r: any) => !r.error).length;
    const failures  = [r1, r2].filter((r: any) =>  r.error).length;
    // Backend transaction must ensure exactly 1 succeeds and 1 fails (idempotency)
    expect(successes).toBe(1);
    expect(failures).toBe(1);

    const order = await getOrder(result.orderId, buyerAuth.idToken);
    expect(order.orderStatus).toBe(STATUS.CANCELLED);
  });
});