/**
 * OrignaGTA — Checkout Validation E2E Tests
 * ==========================================
 * Tests checkout input validation against dev Firebase.
 * No emulators — all requests hit orignagta-dev deployed functions.
 */
import { test, expect } from '@playwright/test';
import {
  signIn, callOk, callExpectError,
  readDoc, parseDoc,
  buildCheckoutPayload, getTestProduct,
  TEST_ACCOUNTS, TEST_UIDS, FUNCTIONS_URL,
} from './api-helpers';

const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;
const SELLER_EMAIL = TEST_ACCOUNTS.SELLER_EMAIL;

/** Get the product owned by the SELLER for self-purchase test. */
async function getSellerOwnProduct(sellerIdToken: string): Promise<{ id: string; sellerId: string }> {
  // Use the stable product owned by SELLER
  const productId = 'e2e_product_test_seller';
  const doc = await readDoc(`products/${productId}`, sellerIdToken);
  const data = parseDoc(doc);
  if (!data) throw new Error(`Seller product ${productId} not found`);
  return { id: productId, sellerId: data.sellerId ?? TEST_UIDS.SELLER };
}

test.describe('Checkout Validation', () => {
  test.setTimeout(60_000);

  let productId: string;
  let buyerAuth: Awaited<ReturnType<typeof signIn>>;
  let sellerAuth: Awaited<ReturnType<typeof signIn>>;

  test.beforeAll(async () => {
    buyerAuth = await signIn(BUYER_EMAIL);
    sellerAuth = await signIn(SELLER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    productId = product.id;
  });

  test('Rejects unauthenticated checkout request', async () => {
    const res = await fetch(`${FUNCTIONS_URL}/create_checkout_session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: {} }),
    });
    const body = await res.json();
    expect(body.error || res.status !== 200).toBeTruthy();
  });

  test('Rejects empty items array', async () => {
    const error = await callExpectError('create_checkout_session', {
      userId: buyerAuth.localId,
      items: [],
      subtotalCents: 0,
      shippingAddress: {
        street: '1 Test St',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5V 3A8',
        country: 'Canada',
      },
    }, buyerAuth.idToken);
    expect(error.code, 'Empty items should be invalid-argument').toBe('invalid-argument');
  });

  test('Rejects missing shipping address fields', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
    data.shippingAddress = { street: '1 Test' };
    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code, 'Missing address fields should be invalid-argument').toBe('invalid-argument');
  });

  test('Rejects invalid postal code format', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
    data.shippingAddress.postalCode = 'INVALID';
    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code, 'Invalid postal code should be invalid-argument').toBe('invalid-argument');
  });

  test('Rejects invalid province code', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
    data.shippingAddress.state = 'XX';
    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code, 'Invalid province should be invalid-argument').toBe('invalid-argument');
    expect(error.message.toLowerCase()).toContain('province');
  });

  test('Rejects price tampering (client sends lower price)', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
    data.items[0].price = 0.01;
    data.subtotalCents = 1;
    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code, 'Price tampering should be rejected').toBe('invalid-argument');
  });

  test('Rejects subtotal mismatch', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
    data.subtotalCents = data.subtotalCents + 99900;
    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code, 'Subtotal mismatch should be rejected').toBe('invalid-argument');
  });

  test('Rejects negative price', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
    data.items[0].price = -50.00;
    data.subtotalCents = -5000;
    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code, 'Negative price should be rejected').toBe('invalid-argument');
  });

  test('Rejects quantity zero', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 0, buyerAuth.idToken);
    data.items[0].quantity = 0;
    data.subtotalCents = 0;
    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code, 'Zero quantity should be rejected').toBe('invalid-argument');
  });

  test('Rejects quantity exceeding max cap (>100)', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
    data.items[0].quantity = 150;
    data.subtotalCents = Math.round(data.items[0].price * 150 * 100);
    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code, 'Over-limit quantity should be rejected').toBe('invalid-argument');
  });

  test('Rejects negative quantity', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
    data.items[0].quantity = -1;
    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code, 'Negative quantity should be rejected').toBe('invalid-argument');
  });

  test('Rejects self-purchase (buyer is the seller of the product)', async () => {
    // Get a product OWNED BY the seller (not excludeSellerId which filters them out)
    const sellerOwnProduct = await getSellerOwnProduct(sellerAuth.idToken);
    const { data } = await buildCheckoutPayload(sellerAuth.localId, sellerOwnProduct.id, 1, sellerAuth.idToken);
    const error = await callExpectError('create_checkout_session', data, sellerAuth.idToken);
    expect(error.code, 'Self-purchase should be rejected').toBe('invalid-argument');
    expect(error.message.toLowerCase()).toContain('own');
  });

  test('Rejects non-Canadian shipping address (USA)', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
    data.shippingAddress.country = 'United States';
    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code, 'Non-Canadian address should be rejected').toBe('invalid-argument');
  });

  test('Valid checkout creates session with Stripe URL', async () => {
    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
    const result = await callOk('create_checkout_session', data, buyerAuth.idToken);

    expect(result.orderId, 'Should return orderId').toBeTruthy();
    expect(result.checkoutUrl, 'Should return Stripe checkout URL').toContain('checkout.stripe.com');

    const doc = await readDoc(`orders/${result.orderId}`, buyerAuth.idToken);
    const order = parseDoc(doc);
    expect(order, 'Order doc should exist').toBeTruthy();
    expect(order.orderStatus).toBe('pending');
    expect(order.currency).toBe('cad');
    expect(order.subtotalCents).toBeGreaterThan(0);
    expect(order.totalAmountCents).toBeGreaterThan(0);
    expect(order.platformFeeRatio, 'platformFeeRatio must be stored at order creation').toBe(0.025);
  });
});
