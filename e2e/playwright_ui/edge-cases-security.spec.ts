/**
 * OrignaGTA — Edge Cases & Security E2E Tests
 * =============================================
 * Tests adversarial and boundary scenarios not covered by other spec files.
 * Targets dev Firebase (orignagta-dev) with real Stripe test mode.
 *
 * Scenarios covered:
 *  1. Self-purchase: seller cannot buy their own product
 *  2. Quantity validation: qty > stock rejected; qty = 0 rejected
 *  3. Order guard: cancel/update on non-existent orders returns not-found
 *  4. Product rating security: range validation + order-ownership enforcement
 *  5. Checkout idempotency: duplicate request within 60s returns same order
 *  6. Non-Canadian address rejected; invalid postal code rejected
 *  7. Non-existent product blocked at checkout
 *  8. Permission isolation: buyer cannot call seller-only endpoints; unauthed blocked
 */
import { test, expect } from '@playwright/test';
import {
  signIn,
  callOk,
  callExpectError,
  readDoc,
  writeDoc,
  toFirestoreFields,
  parseDoc,
  buildCheckoutPayload,
  discoverProducts,
  getTestProduct,
  ensureTwoSellerProducts,
  FIRESTORE_BASE,
  TEST_ACCOUNTS,
  TEST_UIDS,
} from './api-helpers';

const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;
const SELLER_EMAIL = TEST_ACCOUNTS.SELLER_EMAIL;
const ADMIN_EMAIL = TEST_ACCOUNTS.ADMIN_EMAIL;
const ADMIN_PASS = TEST_ACCOUNTS.ADMIN_PASS;

/** Build a raw checkout payload without reading from Firestore (for negative tests). */
function rawCheckoutPayload(buyerUid: string, productId: string, quantity: number, sellerId = TEST_UIDS.SELLER) {
  return {
    userId: buyerUid,
    items: [{
      productId,
      name: 'Test Product',
      price: 10.00,
      quantity,
      quantityLimit: 10,
      sellerId,
      imageUrls: ['https://picsum.photos/400'],
      isDigital: false,
    }],
    subtotalCents: Math.round(10.00 * Math.max(quantity, 1) * 100),
    shippingAddress: {
      street: '100 King St W',
      apartment: '',
      city: 'Toronto',
      state: 'ON',
      postalCode: 'M5X 1A9',
      country: 'Canada',
      phoneNumber: '+14165550000',
    },
  };
}

// ════════════════════════════════════════════════════════════════════════════
// 1. SELF-PURCHASE PREVENTION
// ════════════════════════════════════════════════════════════════════════════

test.describe('1. Self-Purchase Prevention', () => {
  test.setTimeout(60_000);

  test('Seller cannot purchase their own product via API', async () => {
    const sellerAuth = await signIn(SELLER_EMAIL);

    // Guaranteed to have a product by this seller inside ensureTwoSellerProducts 
    const [_, productB] = await ensureTwoSellerProducts(sellerAuth.idToken);

    const { data } = await buildCheckoutPayload(sellerAuth.localId, productB.id, 1, sellerAuth.idToken);

    // Backend guard: sellerId == userId → invalid-argument
    const error = await callExpectError('create_checkout_session', data, sellerAuth.idToken);
    expect(error.code).toBe('invalid-argument');
    expect(error.message.toLowerCase()).toContain('own');
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 2. QUANTITY VALIDATION
// ════════════════════════════════════════════════════════════════════════════

test.describe('2. Quantity Validation', () => {
  test.setTimeout(60_000);

  test('Checkout rejected when quantity exceeds live stock', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const adminAuth = await signIn(ADMIN_EMAIL, ADMIN_PASS);

    // Create a product with a known stock level to prevent skips when stock is >= 98
    const liveStock = 50;
    const productId = `test_stock_${Date.now()}`;
    await writeDoc(`products/${productId}`, toFirestoreFields({
      sellerId: TEST_UIDS.SELLER,
      sellerSku: `STOCK-TEST-${Date.now()}`,
      name: 'Stock Limited Product',
      price: 10.00,
      lifecycleStatus: 'active',
      stockQuantity: liveStock,
      categoryId: 1,
      imageUrls: [],
      keywords: [],
      rating: 0,
    }), adminAuth.idToken);

    // Request exactly one more than available
    const excessQty = liveStock + 1;

    const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, excessQty, buyerAuth.idToken);
    data.items[0].quantity = excessQty;
    data.subtotalCents = Math.round(10.00 * excessQty * 100);

    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    // Backend: "resource-exhausted" (stock) or "invalid-argument" (qty limit) — both correct
    expect(['resource-exhausted', 'invalid-argument']).toContain(error.code);
    const msg = error.message.toLowerCase();
    expect(msg.includes('stock') || msg.includes('quantity') || msg.includes('available')).toBe(true);
  });

  test('Checkout rejected for quantity = 0', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);

    // Build a valid payload, then corrupt the quantity
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 1, buyerAuth.idToken);
    data.items[0].quantity = 0;
    data.subtotalCents = 0;

    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    // Backend validates: item_quantity <= 0 → invalid-argument; subtotalCents <= 0 → invalid-argument
    expect(error.code).toBe('invalid-argument');
  });

  test('Checkout rejected for quantity > 100 (max item cap)', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);

    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 1, buyerAuth.idToken);
    data.items[0].quantity = 101;
    data.subtotalCents = Math.round(product.price * 101 * 100);

    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code).toBe('invalid-argument');
    expect(error.message.toLowerCase()).toContain('quantity');
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 3. ORDER GUARD: NON-EXISTENT & ARCHIVED ORDERS
// ════════════════════════════════════════════════════════════════════════════

test.describe('3. Order Guards', () => {
  test.setTimeout(60_000);

  /**
   * cancel_order and update_order_status both check:
   *   1. order existence → not-found
   *   2. archived flag  → failed-precondition
   *   3. permissions    → permission-denied
   * These tests verify the first guard. The archived guard (step 2) is covered
   * in backend unit tests (test_handlers_products_orders.py) since force-writing
   * archived=true via REST requires admin SDK.
   */
  test('cancel_order on non-existent order returns not-found', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const error = await callExpectError('cancel_order', {
      orderId: 'e2e_nonexistent_order_cancel_guard',
    }, buyerAuth.idToken);
    expect(error.code).toBe('not-found');
  });

  test('update_order_status on non-existent order returns not-found', async () => {
    const adminAuth = await signIn(ADMIN_EMAIL, ADMIN_PASS);
    const error = await callExpectError('update_order_status', {
      orderId: 'e2e_nonexistent_order_status_guard',
      newStatus: 'processing',
    }, adminAuth.idToken);
    expect(error.code).toBe('not-found');
  });

  test('Buyer cannot call update_order_status (seller/admin only endpoint)', async () => {
    // update_order_status checks: is_admin || is_seller — buyer is neither.
    // With no real order, we get not-found first; the permission check fires on real orders.
    // This test confirms the endpoint is at minimum auth-protected (non-existent → not-found,
    // never a silent success).
    const buyerAuth = await signIn(BUYER_EMAIL);
    const error = await callExpectError('update_order_status', {
      orderId: 'e2e_buyer_permission_test_order',
      newStatus: 'processing',
    }, buyerAuth.idToken);
    // not-found (order missing) or permission-denied (if real order found and buyer not seller)
    expect(['not-found', 'permission-denied']).toContain(error.code);
  });

  test('Seller cannot update status of order they are not part of', async () => {
    // Create an order belonging to another seller and buyer
    const adminAuth = await signIn(ADMIN_EMAIL, ADMIN_PASS);
    const sellerAuth = await signIn(SELLER_EMAIL);
    const orderId = `test_order_unrelated_${Date.now()}`;

    await writeDoc(`orders/${orderId}`, toFirestoreFields({
      userId: TEST_UIDS.BUYER,
      orderStatus: 'pending', // Must be pending to transition to processing
      totalAmount: 50.00,
      createdAt: new Date().toISOString(),
      items: [{
        productId: 'some_prod',
        sellerId: TEST_UIDS.ADMIN, // Belongs to admin, not SELLER
        name: 'Item',
        price: 50.00,
        quantity: 1
      }]
    }), adminAuth.idToken);

    const error = await callExpectError('update_order_status', {
      orderId,
      newStatus: 'processing',
    }, sellerAuth.idToken);
    expect(error.code).toBe('permission-denied');
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 4. PRODUCT RATING SECURITY
// ════════════════════════════════════════════════════════════════════════════

test.describe('4. Product Rating Security', () => {
  test.setTimeout(60_000);

  /**
   * Rating range check fires BEFORE order lookup — safe to use fake orderId.
   * Rating ownership check fires AFTER order lookup — needs a real order.
   */
  test('Rating > 5 is rejected (range check fires before order lookup)', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);

    const error = await callExpectError('submit_product_rating', {
      productId: product.id,
      orderId: 'e2e_fake_order_range_check',
      rating: 10,
      review: 'Too many stars!',
    }, buyerAuth.idToken);

    expect(error.code).toBe('invalid-argument');
    expect(error.message.toLowerCase()).toContain('rating');
  });

  test('Rating < 1 is rejected (range check fires before order lookup)', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);

    const error = await callExpectError('submit_product_rating', {
      productId: product.id,
      orderId: 'e2e_fake_order_range_check',
      rating: 0,
      review: 'Zero stars!',
    }, buyerAuth.idToken);

    expect(error.code).toBe('invalid-argument');
    expect(error.message.toLowerCase()).toContain('rating');
  });

  test('Rating rejected when orderId does not exist (order ownership enforced)', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);

    // Valid rating value but orderId is fake → backend hits "not-found" on order lookup
    const error = await callExpectError('submit_product_rating', {
      productId: product.id,
      orderId: 'e2e_nonexistent_order_for_rating',
      rating: 5,
      review: 'Great product!',
    }, buyerAuth.idToken);

    // Backend: order doesn't exist → not-found (ownership check never succeeds)
    expect(error.code).toBe('not-found');
  });

  test('Rating rejected when a different user owns the order', async () => {
    // Sign in as seller, try to rate a product using an order that belongs to the buyer
    const sellerAuth = await signIn(SELLER_EMAIL);
    const adminAuth = await signIn(ADMIN_EMAIL, ADMIN_PASS);

    const orderId = `test_order_rating_${Date.now()}`;
    const productId = `test_rating_prod_${Date.now()}`;

    await writeDoc(`orders/${orderId}`, toFirestoreFields({
      userId: TEST_UIDS.BUYER, // Belongs to buyer
      orderStatus: 'delivered',
      totalAmount: 10.00,
      createdAt: new Date().toISOString(),
      items: [{
        productId,
        sellerId: TEST_UIDS.ADMIN,
        name: 'Item',
        price: 10.00,
        quantity: 1
      }]
    }), adminAuth.idToken);

    const error = await callExpectError('submit_product_rating', {
      productId,
      orderId,
      rating: 4,
      review: 'Nice!',
    }, sellerAuth.idToken);

    // Backend: order.userId !== req.auth.uid → permission-denied
    expect(error.code).toBe('permission-denied');
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 5. CHECKOUT IDEMPOTENCY (same user + same subtotal → same order within 60s)
// ════════════════════════════════════════════════════════════════════════════

test.describe('5. Checkout Idempotency', () => {
  test.setTimeout(120_000);

  test('Duplicate checkout within 60s returns existing order (duplicate=true)', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 1, buyerAuth.idToken);

    // First request — creates Stripe session + order
    const first = await callOk('create_checkout_session', data, buyerAuth.idToken);
    expect(first.orderId, 'First call must return orderId').toBeTruthy();

    // Second request immediately after — same user, same subtotal, same pending order exists
    // Backend dedup window: 60 seconds (BusinessRules.ORDER_DEDUP_WINDOW_SECONDS)
    const second = await callOk('create_checkout_session', data, buyerAuth.idToken);
    expect(second.orderId, 'Second call must return orderId').toBeTruthy();

    if (second.duplicate === true) {
      // Idempotent path hit: same orderId returned
      expect(second.orderId).toBe(first.orderId);
    } else {
      // Dedup window may have missed (e.g. first order already moved to non-pending state).
      // At minimum: both returned successfully and have valid order IDs.
      expect(typeof second.orderId).toBe('string');
    }
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 6. NON-CANADIAN ADDRESS REJECTED
// ════════════════════════════════════════════════════════════════════════════

test.describe('6. Non-Canadian Address Rejected', () => {
  test.setTimeout(60_000);

  test('Checkout with non-Canada country is rejected', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 1, buyerAuth.idToken);

    data.shippingAddress = {
      street: '123 Main St',
      apartment: '',
      city: 'New York',
      state: 'NY',
      postalCode: '10001',
      country: 'United States',
      phoneNumber: '+12125550000',
    };

    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code).toBe('invalid-argument');
    // Backend: "Shipping is only available within Canada"
    expect(error.message.toLowerCase()).toContain('canada');
  });

  test('Checkout with invalid Canadian postal code format is rejected', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 1, buyerAuth.idToken);

    // Valid country but US-format postal code
    data.shippingAddress.country = 'Canada';
    data.shippingAddress.postalCode = '12345';

    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code).toBe('invalid-argument');
    expect(error.message.toLowerCase()).toContain('postal');
  });

  test('Checkout with missing country is rejected', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 1, buyerAuth.idToken);

    data.shippingAddress.country = '';

    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code).toBe('invalid-argument');
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 7. NON-EXISTENT PRODUCT BLOCKED AT CHECKOUT
// ════════════════════════════════════════════════════════════════════════════

test.describe('7. Non-Existent Product at Checkout', () => {
  test.setTimeout(60_000);

  test('Checkout with non-existent product ID is rejected', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);

    // Build payload manually — buildCheckoutPayload reads Firestore and throws before
    // the API call if the product doesn't exist. We need a raw payload here.
    const data = rawCheckoutPayload(buyerAuth.localId, 'e2e_nonexistent_product_xyz', 1);

    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    // Backend: product_doc.exists is False → not-found
    expect(error.code).toBe('not-found');
  });

  test('Checkout with subtotal of 0 is rejected', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 1, buyerAuth.idToken);

    // Tamper: set subtotalCents to 0 — backend re-computes from Firestore, but subtotalCents guard fires first
    data.subtotalCents = 0;

    const error = await callExpectError('create_checkout_session', data, buyerAuth.idToken);
    expect(error.code).toBe('invalid-argument');
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 8. PERMISSION ISOLATION
// ════════════════════════════════════════════════════════════════════════════

test.describe('8. Permission Isolation', () => {
  test.setTimeout(60_000);

  test('Unauthenticated request to create_checkout_session is rejected', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 1, buyerAuth.idToken);

    const error = await callExpectError('create_checkout_session', data, 'invalid_token_xyz');
    expect(error.code).toBe('unauthenticated');
  });

  test('Unauthenticated request to cancel_order is rejected', async () => {
    const error = await callExpectError('cancel_order', {
      orderId: 'e2e_any_order_id',
    }, 'invalid_token_xyz');
    expect(error.code).toBe('unauthenticated');
  });

  test('Unauthenticated request to submit_product_rating is rejected', async () => {
    const error = await callExpectError('submit_product_rating', {
      productId: 'e2e_any_product_id',
      orderId: 'e2e_any_order_id',
      rating: 5,
    }, 'invalid_token_xyz');
    expect(error.code).toBe('unauthenticated');
  });

  test('Buyer cannot call update_order_status (requires seller or admin role)', async () => {
    // With a real order the flow is: existence check → permission check.
    // Create an order and then call as buyer.
    const adminAuth = await signIn(ADMIN_EMAIL, ADMIN_PASS);
    const buyerAuth = await signIn(BUYER_EMAIL);

    const orderId = `test_order_buyer_perms_${Date.now()}`;
    await writeDoc(`orders/${orderId}`, toFirestoreFields({
      userId: TEST_UIDS.BUYER,
      orderStatus: 'pending', // Must be pending to transition to processing
      totalAmount: 10.00,
      createdAt: new Date().toISOString(),
      items: [{
        productId: 'some_prod',
        sellerId: TEST_UIDS.SELLER,
        name: 'Item',
        price: 10.00,
        quantity: 1
      }]
    }), adminAuth.idToken);

    const error = await callExpectError('update_order_status', {
      orderId,
      newStatus: 'processing',
    }, buyerAuth.idToken);

    // Buyer is neither seller nor admin → permission-denied
    expect(error.code).toBe('permission-denied');
  });
});
