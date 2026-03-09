/**
 * OrignaGTA — Return Request E2E Tests
 * =====================================
 * Tests the return request lifecycle (Flow 6).
 */
import { test, expect } from '@playwright/test';
import {
  signIn, callOk,
  fullCheckoutAndPay,
  waitForOrderStatus, getOrder,
  getSellerAuth,
  TEST_ACCOUNTS,
  writeDoc, toFirestoreFields,
  readDoc, parseDoc,
} from './api-helpers';

const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;

test.describe('Return Request Flow (Flow 6)', () => {
  test.setTimeout(240_000);

  let productId: string;
  let productSellerId: string;

  test.beforeAll(async () => {
    // We need a physical product for returns
    const auth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL);
    productId = 'product_001'; // Organic Maple Syrup (physical)
    const prod = await readDoc(`products/${productId}`);
    productSellerId = parseDoc(prod).sellerId;
  });

  test('Buyer can request return and seller can approve', async ({ page }) => {
    // 1. Buyer purchases product
    const result = await fullCheckoutAndPay(page, BUYER_EMAIL, productId, 1);
    const buyerAuth = await signIn(BUYER_EMAIL);
    const orderId = result.orderId;

    // 2. Wait for confirmed status
    await waitForOrderStatus(orderId, ['confirmed'], buyerAuth.idToken, 90_000);

    // 3. Force order to delivered (returns are only allowed for delivered items)
    // In real flow: confirmed -> processing -> shipped -> delivered
    // We can use update_order_status to move it along or force it.
    // Let's use the API for realism.
    const sellerAuth = await getSellerAuth(productSellerId);
    
    await callOk('update_order_status', {
      orderId,
      newStatus: 'processing',
    }, sellerAuth.idToken);

    await callOk('update_order_status', {
      orderId,
      newStatus: 'shipped',
      trackingNumber: 'TEST-TRACK-123',
      carrier: 'Canada Post',
    }, sellerAuth.idToken);

    // 4. Admin marks order as delivered (or buyer confirms receipt)
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL);
    await callOk('update_order_status', {
      orderId,
      newStatus: 'delivered',
    }, adminAuth.idToken);

    const orderDoc = await readDoc(`orders/${orderId}`, adminAuth.idToken);
    const orderData = parseDoc(orderDoc);
    console.log('Order Items:', JSON.stringify(orderData?.items, null, 2));

    // 5. Buyer requests return
    const returnResult = await callOk('create_return_request', {
      orderId,
      productId,
      returnReason: 'Item not as described - too sweet!',
    }, buyerAuth.idToken);

    expect(returnResult.success).toBe(true);
    const returnId = returnResult.returnId;
    expect(returnId).toBeTruthy();

    // 6. Verify return request exists in Firestore
    const returnDoc = await readDoc(`return_requests/${returnId}`, adminAuth.idToken);
    const returnData = parseDoc(returnDoc);
    expect(returnData.returnStatus).toBe('requested');

    // 7. Seller approves return
    await callOk('approve_return_request', {
      returnId,
      adminNote: 'Return approved. Please ship back.',
    }, sellerAuth.idToken);

    // 8. Verify approved status
    const returnDocApproved = await readDoc(`return_requests/${returnId}`, adminAuth.idToken);
    const returnDataApproved = parseDoc(returnDocApproved);
    expect(returnDataApproved.returnStatus).toBe('approved');
  });

  test('Cannot request return for digital products', async () => {
    // Seed a fake delivered order with a digital item, then assert the backend rejects the return.
    const buyerAuth = await signIn(BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS);
    const fakeOrderId = `e2e_digital_return_${Date.now()}`;
    const fakeProductId = 'product_010'; // Canadian History eBook Bundle (isDigital: true)

    // Create minimal order doc with a delivered digital item
    await writeDoc(
      `orders/${fakeOrderId}`,
      toFirestoreFields({
        userId: buyerAuth.uid,
        status: 'completed',
        paymentStatus: 'paid',
        items: [
          {
            productId: fakeProductId,
            name: 'Canadian History eBook Bundle',
            price: 14.99,
            quantity: 1,
            isDigital: true,
            status: 'delivered',
            confirmedByBuyer: true,
            sellerId: 'seller_test',
            deliveredAt: new Date().toISOString(),
          },
        ],
        createdAt: new Date().toISOString(),
      }),
      buyerAuth.idToken
    );

    try {
      await callOk(
        'create_return_request',
        { orderId: fakeOrderId, productId: fakeProductId, returnReason: 'I want a refund' },
        buyerAuth.idToken
      );
      throw new Error('Expected create_return_request to reject digital product return');
    } catch (e: any) {
      expect(e.message).toMatch(/digital products cannot be returned/i);
    }
  });
});
