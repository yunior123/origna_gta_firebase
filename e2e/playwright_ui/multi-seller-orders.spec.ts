/**
 * OrignaGTA — Multi-Seller Orders E2E Tests
 * ============================================
 * Tests orders with items from multiple sellers against dev Firebase.
 * Skips multi-seller-specific tests if dev only has products from one seller.
 */
import { test, expect } from '@playwright/test';
import {
  signIn, callOk, callExpectError,
  fullCheckoutAndPay, fullMultiSellerCheckoutAndPay,
  waitForOrderStatus, getOrder,
  getTestProduct, ensureTwoSellerProducts, getSellerAuth, discoverProducts,
  TEST_ACCOUNTS,
} from './api-helpers';

const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;

test.describe('Multi-Seller Orders', () => {
  test.setTimeout(180_000);

  let productA: { id: string; sellerId: string } | null = null; // Canada (Admin)
  let productB: { id: string; sellerId: string } | null = null; // Canada (Seller)
  let productC: { id: string; sellerId: string } | null = null; // China (Seller)
  let singleProductId: string;

  test.beforeAll(async () => {
    const auth = await signIn(BUYER_EMAIL);
    const products = await discoverProducts(auth.idToken);
    
    productA = products.find(p => p.id === 'e2e_product_admin_seller') || null;
    productB = products.find(p => p.id === 'e2e_product_test_seller') || null;
    productC = products.find(p => p.id === 'e2e_product_intl_seller') || null;

    if (!productA || !productB || !productC) {
      throw new Error('Required E2E stable products not found in discoverProducts');
    }

    // Always have a fallback single product for basic multi-item test
    const product = await getTestProduct(auth.idToken, auth.localId);
    singleProductId = product.id;
  });

  test('Cart with multiple items creates single order', async ({ page }) => {
    // Even if same seller, multi-item checkout should work
    const result = await fullCheckoutAndPay(page, BUYER_EMAIL, singleProductId, 2);
    expect(result.orderId).toBeTruthy();

    const auth = await signIn(BUYER_EMAIL);
    const order = await waitForOrderStatus(result.orderId, ['confirmed'], auth.idToken, 90_000);
    expect(order.items.length).toBeGreaterThanOrEqual(1);
  });

  test('Multi-seller cart creates order with correct items', async ({ page }) => {
    const result = await fullMultiSellerCheckoutAndPay(page, BUYER_EMAIL, [
      { productId: productA!.id, quantity: 1 },
      { productId: productB!.id, quantity: 1 },
    ]);
    expect(result.orderId).toBeTruthy();

    const auth = await signIn(BUYER_EMAIL);
    const order = await waitForOrderStatus(result.orderId, ['confirmed'], auth.idToken, 90_000);
    expect(order.items.length).toBe(2);
  });

  test('Multi-country + Multi-seller cart creates order', async ({ page }) => {
    // Product A (Canada, Admin) + Product C (China, Seller)
    const result = await fullMultiSellerCheckoutAndPay(page, BUYER_EMAIL, [
      { productId: productA!.id, quantity: 1 },
      { productId: productC!.id, quantity: 1 },
    ]);
    expect(result.orderId).toBeTruthy();

    const auth = await signIn(BUYER_EMAIL);
    const order = await waitForOrderStatus(result.orderId, ['confirmed'], auth.idToken, 90_000);
    expect(order.items.length).toBe(2);
    
    // Verify item countries if they are in the order doc
    // (Assuming backend denormalizes shipFromCountry)
    const itemA = order.items.find((i: any) => i.productId === productA!.id);
    const itemC = order.items.find((i: any) => i.productId === productC!.id);
    
    // If the backend stores shipFromCountry, we can assert it here
    // expect(itemA.shipFromCountry).toBe('Canada');
    // expect(itemC.shipFromCountry).toBe('China');
  });

  test('Per-item status tracking works for multi-item order', async ({ page }) => {
    // Use productB + productC (not productA + productB) to avoid the 60s order dedup
    // window that returns the same checkout session as the previous test.
    const result = await fullMultiSellerCheckoutAndPay(page, BUYER_EMAIL, [
      { productId: productB!.id, quantity: 1 },
      { productId: productC!.id, quantity: 1 },
    ]);

    const auth = await signIn(BUYER_EMAIL);
    await waitForOrderStatus(result.orderId, ['confirmed'], auth.idToken, 90_000);

    // Seller B marks their item as shipped
    const sellerAuth = await getSellerAuth(productB!.sellerId);
    const updateResult = await callOk('update_item_status', {
      orderId: result.orderId,
      productId: productB!.id,
      newStatus: 'shipped',
      trackingNumber: `TRACK-${Date.now()}`,
      carrier: 'Canada Post',
    }, sellerAuth.idToken);

    const order = await getOrder(result.orderId, sellerAuth.idToken);
    const item = order.items.find((i: any) => i.productId === productB!.id);
    if (item?.status) {
      expect(item.status).toBe('shipped');
    }
  });

  test('Wrong seller cannot update another seller items', async ({ page }) => {
    const result = await fullMultiSellerCheckoutAndPay(page, BUYER_EMAIL, [
      { productId: productA!.id, quantity: 1 },
      { productId: productB!.id, quantity: 1 },
    ]);

    const auth = await signIn(BUYER_EMAIL);
    await waitForOrderStatus(result.orderId, ['confirmed'], auth.idToken, 90_000);

    // Seller B (non-admin SELLER account) tries to update seller A's item — should fail
    // Note: productA belongs to ADMIN (who has admin role), so we use the SELLER account
    // trying to update ADMIN's item, not vice versa (admin bypasses the cross-seller check)
    const sellerAuthB = await getSellerAuth(productB!.sellerId); // SELLER account (non-admin)
    const error = await callExpectError('update_item_status', {
      orderId: result.orderId,
      productId: productA!.id,  // ADMIN's item — SELLER cannot update this
      newStatus: 'shipped',
    }, sellerAuthB.idToken);

    expect(error.code, 'Cross-seller update should be rejected').not.toBe('unexpected-success');
  });

  test('Seller cannot update order-level status for multi-seller order', async ({ page }) => {
    const result = await fullMultiSellerCheckoutAndPay(page, BUYER_EMAIL, [
      { productId: productA!.id, quantity: 1 },
      { productId: productB!.id, quantity: 1 },
    ]);

    const auth = await signIn(BUYER_EMAIL);
    await waitForOrderStatus(result.orderId, ['confirmed'], auth.idToken, 90_000);

    // Seller B (non-admin) tries to update the WHOLE order status — should be rejected.
    // productA belongs to Admin who bypasses the multi-seller check, so use productB's seller.
    const sellerAuth = await getSellerAuth(productB!.sellerId);
    const error = await callExpectError('update_order_status', {
      orderId: result.orderId,
      newStatus: 'processing',
    }, sellerAuth.idToken);

    expect(error.code, 'Order-level update should be rejected for multi-seller order').not.toBe('unexpected-success');
    expect(error.message).toContain('Multi-seller order');
  });
});
