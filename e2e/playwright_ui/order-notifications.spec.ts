import { expect, test } from '@playwright/test';
import {
  TEST_ACCOUNTS,
  callOk,
  discoverProducts,
  fillStripeCheckout,
  fullMultiSellerCheckoutAndPay,
  signIn,
  waitForOrderStatus,
} from './api-helpers';

const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;
const ADMIN_EMAIL = TEST_ACCOUNTS.ADMIN_EMAIL;

/**
 * Order Notifications E2E
 * Verifies that push/email notifications are triggered correctly 
 * for various order lifecycle events, especially for multi-seller orders.
 */
test.describe('Order Notifications', () => {
  test.setTimeout(300_000);

  let productA: { id: string; sellerId: string; name?: string } | null = null;
  let productB: { id: string; sellerId: string; name?: string } | null = null;

  test.beforeAll(async () => {
    const auth = await signIn(BUYER_EMAIL);
    const products = await discoverProducts(auth.idToken);

    // Use stable E2E products
    productA = products.find(p => p.id === 'e2e_product_admin_seller') || null;
    productB = products.find(p => p.id === 'e2e_product_test_seller') || null;

    if (!productA || !productB) {
      throw new Error('Required E2E stable products not found');
    }
  });

  test('Buyer receives notification when individual items are shipped', async ({ page }) => {
    // 1. Create a 2-item multi-seller order
    const checkoutResult = await fullMultiSellerCheckoutAndPay(page, BUYER_EMAIL, [
      { productId: productA!.id, quantity: 1 },
      { productId: productB!.id, quantity: 1 },
    ]);
    const orderId = checkoutResult.orderId;
    expect(orderId).toBeTruthy();

    const auth = await signIn(BUYER_EMAIL);
    await waitForOrderStatus(orderId, ['confirmed', 'shipped', 'delivered'], auth.idToken, 90_000);

    // 2. Mark Item A as SHIPPED using Cloud Function (avoids 403 on direct write)
    const adminAuth = await signIn(ADMIN_EMAIL);
    await callOk('update_item_status', {
      orderId,
      productId: productA!.id,
      newStatus: 'shipped',
      trackingNumber: 'TRK123',
      carrier: 'Canada Post'
    }, adminAuth.idToken);

    // 3. Verify notification in mail_logs — allow 30s for async email pipeline
    // (Firestore trigger → Cloud Task queue → Mailjet → _mail_logs write)
    await page.waitForTimeout(30000);

    const mailLogsResult = await callOk('e2e_get_mail_logs', { orderId, to: BUYER_EMAIL }, adminAuth.idToken);
    const logs = mailLogsResult.logs;

    const shipmentMail = logs.find((l: any) => l.subject.includes('Shipment Update') || l.subject.includes('Mise à jour de livraison'));
    expect(shipmentMail, 'Should find a shipment notification email').toBeTruthy();
    expect(shipmentMail.to).toBe(BUYER_EMAIL);
    // Email should mention the tracking number
    expect(shipmentMail.html).toContain('TRK123');
  });

  test('Buyer receives notification when individual items are delivered', async ({ page }) => {
    // 1. Create a single-item order
    const checkoutResult = await fullMultiSellerCheckoutAndPay(page, BUYER_EMAIL, [
      { productId: productA!.id, quantity: 1 },
    ]);
    const orderId = checkoutResult.orderId;

    const auth = await signIn(BUYER_EMAIL);
    const adminAuth = await signIn(ADMIN_EMAIL);
    const order = await waitForOrderStatus(orderId, ['confirmed', 'shipped', 'delivered'], auth.idToken, 90_000);

    // 2a. Must ship before buyer can confirm receipt
    await callOk('update_item_status', {
      orderId,
      productId: productA!.id,
      newStatus: 'shipped',
      trackingNumber: 'TRK-DELIVER',
      carrier: 'Canada Post',
    }, adminAuth.idToken);

    // 2b. Mark Item as DELIVERED via confirm_item_receipt (requires cartItemId, not productId)
    const item = order.items?.find((i: any) => i.productId === productA!.id);
    const cartItemId = item?.cartItemId;
    if (!cartItemId) throw new Error('cartItemId not found for productA in order');

    await callOk('confirm_item_receipt', {
      orderId,
      cartItemId,
    }, auth.idToken);

    await page.waitForTimeout(10000);

    // 3. Verify notification
    const mailLogsResult = await callOk('e2e_get_mail_logs', { orderId, to: BUYER_EMAIL }, adminAuth.idToken);
    const logs = mailLogsResult.logs;

    const deliveryMail = logs.find((l: any) => l.subject.includes('Delivery Update') || l.subject.includes('Mise à jour de livraison'));
    expect(deliveryMail, 'Should find an item delivery notification email').toBeTruthy();
    expect(deliveryMail.to).toBe(BUYER_EMAIL);
  });

  test('Local pickup order receives "Ready for Pickup" notification', async ({ page }) => {
    const auth = await signIn(BUYER_EMAIL);
    const adminAuth = await signIn(ADMIN_EMAIL);

    // We manually build the payload to specify 'pickup' delivery speed
    // Use actual product price (backend rejects if it doesn't match Firestore price)
    const actualPrice = (productA as any).price ?? 9.99;
    const payload = {
      userId: auth.localId,
      items: [{
        productId: productA!.id,
        name: 'E2E Test Product A',
        price: actualPrice,
        quantity: 1,
        sellerId: productA!.sellerId,
        imageUrls: ['https://orignagta-dev.web.app/assets/icons/icon-192.png'],
        isDigital: false
      }],
      subtotalCents: Math.round(actualPrice * 100),
      shippingAddress: {
        street: '100 Queen St W',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5H 2N2',
        country: 'Canada',
        phoneNumber: '+14165550000'
      },
      deliverySpeed: 'pickup'
    };

    const checkoutResult = await callOk('create_checkout_session', payload, auth.idToken);
    const orderId = checkoutResult.orderId;
    expect(orderId).toBeTruthy();

    await page.goto(checkoutResult.checkoutUrl);
    await fillStripeCheckout(page, BUYER_EMAIL);
    await page.waitForTimeout(5000);

    await waitForOrderStatus(orderId, ['confirmed', 'shipped', 'delivered'], auth.idToken, 90_000);

    // 2. Mark as SHIPPED (Ready for Pickup)
    await callOk('update_item_status', {
      orderId,
      productId: productA!.id,
      newStatus: 'shipped',
      carrier: 'Pickup'
      // trackingNumber is optional for pickup now
    }, adminAuth.idToken);

    await page.waitForTimeout(10000);

    // 3. Verify notification subject contains "Ready for Pickup"
    const mailLogsResult = await callOk('e2e_get_mail_logs', { orderId, to: BUYER_EMAIL }, adminAuth.idToken);
    const logs = mailLogsResult.logs;

    const pickupMail = logs.find((l: any) =>
      l.subject.toLowerCase().includes('ready for pickup') ||
      l.subject.toLowerCase().includes('prêt pour ramassage')
    );

    expect(pickupMail, 'Should find a "Ready for Pickup" notification email').toBeTruthy();
    expect(pickupMail.to).toBe(BUYER_EMAIL);
  });

  test('Seller receives notification when a new order is placed', async ({ page }) => {
    // 1. Create a single-item order for productB (Test Seller)
    const checkoutResult = await fullMultiSellerCheckoutAndPay(page, BUYER_EMAIL, [
      { productId: productB!.id, quantity: 1 },
    ]);
    const orderId = checkoutResult.orderId;

    const auth = await signIn(BUYER_EMAIL);
    const adminAuth = await signIn(ADMIN_EMAIL);
    await waitForOrderStatus(orderId, ['confirmed', 'shipped', 'delivered'], auth.idToken, 90_000);

    await page.waitForTimeout(10000);

    // 2. Verify Seller receives "New Order" email
    const sellerAuth = await signIn(TEST_ACCOUNTS.SELLER_EMAIL);
    const mailLogsResult = await callOk('e2e_get_mail_logs', { orderId, to: TEST_ACCOUNTS.SELLER_EMAIL }, adminAuth.idToken);
    const logs = mailLogsResult.logs;

    const newOrderMail = logs.find((l: any) =>
      l.subject.toLowerCase().includes('new order') ||
      l.subject.toLowerCase().includes('nouvelle commande')
    );
    expect(newOrderMail, 'Seller should receive a new order notification').toBeTruthy();
  });

  test('Seller receives notification when a return is requested', async ({ page }) => {
    // 1. Create a single-item order and mark as DELIVERED
    const checkoutResult = await fullMultiSellerCheckoutAndPay(page, BUYER_EMAIL, [
      { productId: productA!.id, quantity: 1 },
    ]);
    const orderId = checkoutResult.orderId;
    const auth = await signIn(BUYER_EMAIL);
    const adminAuth = await signIn(ADMIN_EMAIL);

    const order = await waitForOrderStatus(orderId, ['confirmed', 'shipped', 'delivered'], auth.idToken, 90_000);

    // Ship first (confirm_item_receipt requires SHIPPED status)
    await callOk('update_item_status', {
      orderId,
      productId: productA!.id,
      newStatus: 'shipped',
      trackingNumber: 'TRK-RETURN',
      carrier: 'Canada Post',
    }, adminAuth.idToken);

    // Mark as delivered (requires cartItemId, not productId)
    const item = order.items?.find((i: any) => i.productId === productA!.id);
    const cartItemId = item?.cartItemId;
    if (!cartItemId) throw new Error('cartItemId not found for productA in order');
    await callOk('confirm_item_receipt', { orderId, cartItemId }, auth.idToken);

    // 2. Create return request
    await callOk('create_return_request', {
      orderId,
      productId: productA!.id,
      returnReason: 'E2E Test Reason'
    }, auth.idToken);

    await page.waitForTimeout(10000);

    // 3. Verify Seller (Admin for productA) receives return request notification
    const mailLogsResult = await callOk('e2e_get_mail_logs', { orderId, to: ADMIN_EMAIL }, adminAuth.idToken);
    const logs = mailLogsResult.logs;

    const returnMail = logs.find((l: any) =>
      l.subject.toLowerCase().includes('return request') ||
      l.subject.toLowerCase().includes('demande de retour')
    );
    expect(returnMail, 'Seller should receive a return request notification').toBeTruthy();
  });
});
