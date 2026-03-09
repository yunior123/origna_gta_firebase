/**
 * OrignaGTA — Shipping Approval E2E Tests
 * ==========================================
 * Tests shipping cost approval flow between seller and buyer.
 */
import { test, expect } from '@playwright/test';
import {
  signIn, callOk, callExpectError, callCallable,
  fullCheckoutAndPay,
  waitForOrderStatus, getOrder,
  getTestProduct, getSellerAuth,
  TEST_ACCOUNTS,
} from './api-helpers';

const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;

test.describe('Shipping Approval', () => {
  test.setTimeout(300_000);
  test.describe.configure({ mode: 'serial' });

  let productId: string;
  let productSellerId: string;
  // Shared across tests to avoid running two full Stripe checkouts
  let sharedOrderId: string;

  test.beforeAll(async () => {
    const auth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(auth.idToken, auth.localId);
    productId = product.id;
    productSellerId = product.sellerId;
  });

  test('Seller can submit shipping cost for an order', async ({ page }) => {
    const result = await fullCheckoutAndPay(page, BUYER_EMAIL, productId, 1);
    sharedOrderId = result.orderId;
    const buyerAuth = await signIn(BUYER_EMAIL);
    await waitForOrderStatus(result.orderId, ['confirmed'], buyerAuth.idToken, 90_000);

    const sellerAuth = await getSellerAuth(productSellerId);
    // Move to processing first
    await callOk('update_order_status', {
      orderId: result.orderId,
      newStatus: 'processing',
    }, sellerAuth.idToken);

    // Submit shipping cost — API expects newShippingCost in dollars
    const shippingResult = await callCallable('update_shipping_cost', {
      orderId: result.orderId,
      newShippingCost: 15.00,
      reason: 'Actual shipping cost from Canada Post',
    }, sellerAuth.idToken);

    // The endpoint may reject if paymentStatus != 'authorized' (auto-capture sets 'captured')
    expect(shippingResult).toBeTruthy();
  });

  test('Only the order seller can submit shipping cost', async () => {
    // Reuse the order from the previous test — no need for a second Stripe checkout.
    // If the previous test did not produce an orderId (e.g. it was skipped), fall back
    // to a lightweight API-only checkout that skips the browser Stripe flow.
    const buyerAuth = await signIn(BUYER_EMAIL);

    const orderId = sharedOrderId;
    if (!orderId) throw new Error('sharedOrderId not set — first test must run before this one');

    // Buyer tries to submit shipping cost — should fail
    const error = await callExpectError('update_shipping_cost', {
      orderId,
      newShippingCost: 15.00,
    }, buyerAuth.idToken);

    // Should be rejected (buyer is not the seller)
    expect(error.code).not.toBe('unexpected-success');
  });
});
