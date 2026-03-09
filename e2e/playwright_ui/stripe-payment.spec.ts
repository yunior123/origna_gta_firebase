/**
 * OrignaGTA — Stripe Payment E2E Tests
 * ======================================
 * Full Stripe Checkout flow against dev Firebase with real Stripe test mode.
 * Each test discovers its own product to avoid stale IDs and stock exhaustion.
 */
import { test, expect } from '@playwright/test';
import {
  signIn, callOk,
  buildCheckoutPayload,
  fillStripeCheckout,
  fullCheckoutAndPay,
  readDoc, parseDoc, listCollection,
  waitForOrderStatus,
  getOrder, getProductStock,
  getTestProduct, invalidateProductCache,
  TEST_ACCOUNTS, STRIPE_CARD, uid,
} from './api-helpers';

const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;

test.describe('Stripe Payment Flow', () => {
  test.setTimeout(180_000);

  test('Full checkout → Stripe payment → order confirmed', async ({ page }) => {
    const auth = await signIn(BUYER_EMAIL);
    await invalidateProductCache();
    const product = await getTestProduct(auth.idToken, auth.localId);

    const result = await fullCheckoutAndPay(page, BUYER_EMAIL, product.id, 1);
    expect(result.orderId).toBeTruthy();
    expect(result.checkoutUrl).toContain('checkout.stripe.com');

    const order = await waitForOrderStatus(result.orderId, ['confirmed', 'processing'], auth.idToken, 90_000);
    expect(order).toBeTruthy();
    expect(order.paymentStatus).toBe('captured');
    expect(order.stripePaymentIntentId).toBeTruthy();
  });

  test('Order document has correct structure after payment', async ({ page }) => {
    const auth = await signIn(BUYER_EMAIL);
    await invalidateProductCache();
    const product = await getTestProduct(auth.idToken, auth.localId);

    const { data } = await buildCheckoutPayload(auth.localId, product.id, 1, auth.idToken);
    const result = await callOk('create_checkout_session', data, auth.idToken);

    await page.goto(result.checkoutUrl);
    await fillStripeCheckout(page, BUYER_EMAIL);

    const order = await waitForOrderStatus(result.orderId, ['confirmed', 'processing'], auth.idToken, 90_000);
    expect(order.orderId).toBe(result.orderId);
    expect(order.userId).toBe(auth.localId);
    expect(order.currency).toBe('cad');
    expect(order.items.length).toBeGreaterThan(0);
    expect(order.subtotalCents).toBeGreaterThan(0);
    expect(order.taxAmountCents).toBeGreaterThanOrEqual(0);
    expect(order.totalAmountCents).toBeGreaterThanOrEqual(order.subtotalCents);
    expect(order.shippingAddress).toBeTruthy();
    expect(order.customerEmail).toBeTruthy();
    // Platform fee ratio must be stored at order creation time
    expect(order.platformFeeRatio, 'platformFeeRatio must be 0.025').toBe(0.025);
    expect(order.stripeSessionId, 'stripeSessionId must be stored').toBeTruthy();
  });

  test('Stock decremented by exact ordered quantity after payment', async ({ page }) => {
    const auth = await signIn(BUYER_EMAIL);
    await invalidateProductCache();
    const product = await getTestProduct(auth.idToken, auth.localId);

    const stockBefore = await getProductStock(product.id, auth.idToken);

    // Pass unique idempotencyKey to prevent time-window dedup from returning an existing
    // parallel test's order (which would show no stock change for this test's checkout).
    const { data } = await buildCheckoutPayload(auth.localId, product.id, 1, auth.idToken);
    const uniqueData = { ...data, idempotencyKey: `stock-test-${Date.now()}-${Math.random().toString(36).slice(2)}` };
    const result = await callOk('create_checkout_session', uniqueData, auth.idToken);
    await page.goto(result.checkoutUrl);
    await fillStripeCheckout(page, BUYER_EMAIL);
    await waitForOrderStatus(result.orderId, ['confirmed', 'processing'], auth.idToken, 90_000);

    const stockAfter = await getProductStock(product.id, auth.idToken);
    // Stock must have decreased — parallel tests may buy the same product simultaneously,
    // so we can't assert an exact delta of 1, but we must assert at least 1 deducted.
    expect(stockAfter).toBeLessThan(stockBefore);
    const delta = stockBefore - stockAfter;
    expect(delta).toBeGreaterThanOrEqual(1); // this order's qty=1 was deducted
  });

  test('Checkout URL redirects to Stripe hosted page', async ({ page }) => {
    const auth = await signIn(BUYER_EMAIL);
    await invalidateProductCache();
    const product = await getTestProduct(auth.idToken, auth.localId);

    const { data } = await buildCheckoutPayload(auth.localId, product.id, 1, auth.idToken);
    const result = await callOk('create_checkout_session', data, auth.idToken);

    expect(result.checkoutUrl).toContain('checkout.stripe.com');
    await page.goto(result.checkoutUrl);
    await page.waitForLoadState('networkidle', { timeout: 30_000 }).catch(() => {});
    expect(page.url()).toContain('checkout.stripe.com');
  });

  test('Duplicate checkout with same idempotency key returns same order', async () => {
    const auth = await signIn(BUYER_EMAIL);
    await invalidateProductCache();
    const product = await getTestProduct(auth.idToken, auth.localId);
    const { data } = await buildCheckoutPayload(auth.localId, product.id, 1, auth.idToken);

    // Pass an explicit idempotency key so the backend can match this specific request
    // even when other parallel tests have created newer pending orders for the same buyer.
    const idempotencyKey = `dedup-test-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    const dedupData = { ...data, idempotencyKey };

    const r1 = await callOk('create_checkout_session', dedupData, auth.idToken);
    const r2 = await callOk('create_checkout_session', dedupData, auth.idToken);
    expect(r1.orderId, 'Duplicate checkout must return same orderId').toBe(r2.orderId);
  });

  test('[BONUS] Order expiresAt is within 6-day authorization window', async ({ page }) => {
    const auth = await signIn(BUYER_EMAIL);
    await invalidateProductCache();
    const product = await getTestProduct(auth.idToken, auth.localId);

    const result = await fullCheckoutAndPay(page, BUYER_EMAIL, product.id, 1);
    const order = await waitForOrderStatus(result.orderId, ['confirmed', 'processing'], auth.idToken, 90_000);

    if (order.expiresAt) {
      // parseDoc returns timestamps as ISO strings; convert to unix seconds
      const toSec = (ts: any): number =>
        ts?._seconds ?? (typeof ts === 'string' ? Math.floor(new Date(ts).getTime() / 1000) : Number(ts));
      const expiresSec = toSec(order.expiresAt);
      const nowSec = Math.floor(Date.now() / 1000);
      // Backend sets expiresAt = now + 6 days (AUTHORIZATION_EXPIRY_DAYS=6) as a safety
      // margin before Stripe auto-voids at day 7. Allow ±10 minutes tolerance.
      expect(expiresSec, 'expiresAt must be ~6 days from now').toBeGreaterThanOrEqual(nowSec + 6 * 86_400 - 600);
      expect(expiresSec, 'expiresAt must be ~6 days from now').toBeLessThanOrEqual(nowSec + 6 * 86_400 + 600);
    }
    // If expiresAt is absent, that's acceptable for auto-capture mode
  });

  test('[BONUS] Cart is cleared after successful order creation', async ({ page }) => {
    const auth = await signIn(BUYER_EMAIL);
    await invalidateProductCache();
    const product = await getTestProduct(auth.idToken, auth.localId);

    const result = await fullCheckoutAndPay(page, BUYER_EMAIL, product.id, 1);
    await waitForOrderStatus(result.orderId, ['confirmed', 'processing'], auth.idToken, 90_000);

    // Cart items should be cleared after checkout session creation
    const cartItems = await listCollection(`users/${auth.localId}/cart`, auth.idToken);
    expect(cartItems.length, 'Cart must be empty after successful checkout').toBe(0);
  });
});
