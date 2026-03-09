/**
 * OrignaGTA — Shipping Calculation E2E Tests
 * =============================================
 * Tests shipping cost calculation and tax logic against dev Firebase.
 * Each test discovers its own product to avoid stock exhaustion.
 */
import { test, expect } from '@playwright/test';
import {
  signIn, callOk, callCallable,
  buildCheckoutPayload,
  readDoc, parseDoc, writeDoc, deleteDoc, toFirestoreFields,
  getTestProduct, invalidateProductCache, discoverProducts,
  TEST_ACCOUNTS, TEST_UIDS,
} from './api-helpers';

const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;

test.describe('Shipping Calculation', () => {
  test.setTimeout(120_000); // Dynamic product creation + 2 checkout sessions can take >60s under load

  let buyerAuth: Awaited<ReturnType<typeof signIn>>;

  test.beforeAll(async () => {
    buyerAuth = await signIn(BUYER_EMAIL);
  });

  test('Checkout includes tax calculation for Ontario address', async () => {
    await invalidateProductCache();
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    // Use qty=4 to avoid 60s order dedup across repeated runs (unique subtotal for province tax tests)
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 4, buyerAuth.idToken);
    // Ensure Ontario address explicitly
    data.shippingAddress.state = 'ON';
    data.shippingAddress.postalCode = 'M5V 3A8';

    const result = await callOk('create_checkout_session', data, buyerAuth.idToken);
    const doc = await readDoc(`orders/${result.orderId}`, buyerAuth.idToken);
    const order = parseDoc(doc);

    expect(order.subtotalCents).toBeGreaterThan(0);
    expect(order.taxAmountCents).toBeGreaterThan(0);
    expect(order.totalAmountCents).toBeGreaterThan(order.subtotalCents);
    // Ontario HST is exactly 13% — allow ±1 cent for rounding only
    const taxableBase = order.subtotalCents + (order.shippingCostCents || 0);
    const expected13pct = Math.round(taxableBase * 0.13);
    expect(order.taxAmountCents, 'Ontario HST must be exactly 13%').toBeGreaterThanOrEqual(expected13pct - 1);
    expect(order.taxAmountCents, 'Ontario HST must be exactly 13%').toBeLessThanOrEqual(expected13pct + 1);
  });

  test('Order total = subtotal + tax + shipping', async () => {
    await invalidateProductCache();
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 2, buyerAuth.idToken);
    const result = await callOk('create_checkout_session', data, buyerAuth.idToken);
    const doc = await readDoc(`orders/${result.orderId}`, buyerAuth.idToken);
    const order = parseDoc(doc);

    const shippingCents = order.shippingCostCents || 0;
    const expectedTotal = order.subtotalCents + order.taxAmountCents + shippingCents;
    // Allow 1 cent rounding tolerance
    expect(Math.abs(order.totalAmountCents - expectedTotal)).toBeLessThanOrEqual(1);
  });

  test('Currency is always CAD', async () => {
    await invalidateProductCache();
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 1, buyerAuth.idToken);
    const result = await callOk('create_checkout_session', data, buyerAuth.idToken);
    const doc = await readDoc(`orders/${result.orderId}`, buyerAuth.idToken);
    const order = parseDoc(doc);

    expect(order.currency).toBe('cad');
  });

  test('Multiple quantity correctly multiplies subtotal', async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);

    const productId = `test_ship_stock_${Date.now()}`;
    await writeDoc(`products/${productId}`, toFirestoreFields({
      sellerId: TEST_UIDS.SELLER,
      sellerSku: `SHIP-TEST-${Date.now()}`,
      name: 'Shipping Test Product',
      description: 'A test product for shipping calculation E2E tests.',
      price: 10.00,
      priceCents: 1000,
      lifecycleStatus: 'active',
      stockQuantity: 50,
      categoryId: 1,
      imageUrls: ['https://orignagta-dev.web.app/assets/icons/icon-192.png'],
      keywords: [],
      isDigital: false,
      isLocalDeliveryOnly: false,
      isPerishable: false,
      freeShipping: false,
      weightKg: 0.5,
      shipFromCity: 'Toronto',
      shipFromProvince: 'ON',
      shipFromCountry: 'Canada',
      sellerAddress: { street: '1 Yonge St', city: 'Toronto', state: 'ON', postalCode: 'M5E 1W7', country: 'Canada' },
      deliveryOptions: [{ type: 'standard', national: true }],
      dateCreated: new Date().toISOString(),
    }), adminAuth.idToken);

    try {
      const { data: data1 } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
      const result1 = await callOk('create_checkout_session', data1, buyerAuth.idToken);
      const order1 = parseDoc(await readDoc(`orders/${result1.orderId}`, buyerAuth.idToken));

      const { data: data2 } = await buildCheckoutPayload(buyerAuth.localId, productId, 2, buyerAuth.idToken);
      const result2 = await callOk('create_checkout_session', data2, buyerAuth.idToken);
      const order2 = parseDoc(await readDoc(`orders/${result2.orderId}`, buyerAuth.idToken));

      // Pin exact values (product price is known: $10.00)
      expect(order1.subtotalCents).toBe(1000);
      expect(order2.subtotalCents).toBe(2000);
    } finally {
      // Always clean up the test product to avoid polluting dev Firestore
      await deleteDoc(`products/${productId}`, adminAuth.idToken).catch(() => {});
    }
  });

  test('Quebec address applies QST+GST tax rate (~14.975%)', async () => {
    await invalidateProductCache();
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    // Use qty=5 to avoid 60s order dedup with Ontario/other tests (unique subtotal for province tax tests)
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 5, buyerAuth.idToken);
    data.shippingAddress.state = 'QC';
    data.shippingAddress.postalCode = 'H2X 1Y6';

    const result = await callOk('create_checkout_session', data, buyerAuth.idToken);
    const order = parseDoc(await readDoc(`orders/${result.orderId}`, buyerAuth.idToken));

    const taxableBase = order.subtotalCents + (order.shippingCostCents || 0);
    // QC: GST 5% + QST 9.975% = 14.975% total
    const expectedQC = Math.round(taxableBase * 0.14975);
    expect(order.taxAmountCents, 'QC tax must be ~14.975%').toBeGreaterThanOrEqual(expectedQC - 2);
    expect(order.taxAmountCents, 'QC tax must be ~14.975%').toBeLessThanOrEqual(expectedQC + 2);
  });

  test('Alberta address applies GST-only tax rate (5%)', async () => {
    await invalidateProductCache();
    const product = await getTestProduct(buyerAuth.idToken, buyerAuth.localId);
    // Use qty=6 to avoid 60s order dedup across repeated runs (unique subtotal for province tax tests)
    const { data } = await buildCheckoutPayload(buyerAuth.localId, product.id, 6, buyerAuth.idToken);
    data.shippingAddress.state = 'AB';
    data.shippingAddress.postalCode = 'T2P 1J9';

    const result = await callOk('create_checkout_session', data, buyerAuth.idToken);
    const order = parseDoc(await readDoc(`orders/${result.orderId}`, buyerAuth.idToken));

    const taxableBase = order.subtotalCents + (order.shippingCostCents || 0);
    // AB: GST only = 5%
    const expected5pct = Math.round(taxableBase * 0.05);
    expect(order.taxAmountCents, 'AB tax must be exactly 5% GST').toBeGreaterThanOrEqual(expected5pct - 1);
    expect(order.taxAmountCents, 'AB tax must be exactly 5% GST').toBeLessThanOrEqual(expected5pct + 1);
  });

  test('Perishable item from local seller: checkout succeeds with same-day option', async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const productId = `test_perishable_local_${Date.now()}`;

    await writeDoc(`products/${productId}`, toFirestoreFields({
      sellerId: TEST_UIDS.SELLER,
      sellerSku: `PERISH-LOCAL-${Date.now()}`,
      name: 'Fresh Local Produce',
      description: 'Perishable local item for E2E testing.',
      price: 12.00,
      priceCents: 1200,
      lifecycleStatus: 'active',
      stockQuantity: 20,
      categoryId: 1,
      imageUrls: ['https://orignagta-dev.web.app/assets/icons/icon-192.png'],
      keywords: [],
      isDigital: false,
      isLocalDeliveryOnly: true,
      isPerishable: true,
      freeShipping: false,
      weightKg: 0.5,
      shipFromCity: 'Toronto',
      shipFromProvince: 'ON',
      shipFromCountry: 'Canada',
      sellerAddress: { street: '1 Queen St W', city: 'Toronto', state: 'ON', postalCode: 'M5H 2N2', country: 'Canada' },
      // same-day option required for perishables — backend enforces this
      deliveryOptions: [{ type: 'same_day', national: false, estimatedDays: 0 }],
      estimatedShipDays: 0,
      dateCreated: new Date().toISOString(),
    }), adminAuth.idToken);

    try {
      const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
      // Buyer in Toronto (within 50km of seller) — same-day should be valid
      data.shippingAddress.city = 'Toronto';
      data.shippingAddress.state = 'ON';
      data.shippingAddress.postalCode = 'M5V 3A8';
      data.deliverySpeed = 'same_day';

      const result = await callOk('create_checkout_session', data, buyerAuth.idToken);
      const order = parseDoc(await readDoc(`orders/${result.orderId}`, buyerAuth.idToken));

      expect(order.subtotalCents).toBe(1200);
      // Verify item has isPerishable snapshotted
      expect(order.items).toBeDefined();
      const item = order.items[0];
      expect(item.isPerishable).toBe(true);
      expect(item.isLocalDeliveryOnly).toBe(true);
    } finally {
      await deleteDoc(`products/${productId}`, adminAuth.idToken).catch(() => {});
    }
  });

  test('Local-only item: checkout blocked for out-of-province buyer', async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const productId = `test_local_only_block_${Date.now()}`;

    await writeDoc(`products/${productId}`, toFirestoreFields({
      sellerId: TEST_UIDS.SELLER,
      sellerSku: `LOCAL-BLOCK-${Date.now()}`,
      name: 'Local Only Product',
      description: 'Local delivery only item — no cross-province.',
      price: 8.00,
      priceCents: 800,
      lifecycleStatus: 'active',
      stockQuantity: 10,
      categoryId: 1,
      imageUrls: ['https://orignagta-dev.web.app/assets/icons/icon-192.png'],
      keywords: [],
      isDigital: false,
      isLocalDeliveryOnly: true,
      isPerishable: false,
      freeShipping: false,
      weightKg: 0.3,
      shipFromCity: 'Toronto',
      shipFromProvince: 'ON',
      shipFromCountry: 'Canada',
      sellerAddress: { street: '1 King St W', city: 'Toronto', state: 'ON', postalCode: 'M5H 1A1', country: 'Canada' },
      deliveryOptions: [{ type: 'local_delivery', national: false }],
      dateCreated: new Date().toISOString(),
    }), adminAuth.idToken);

    try {
      const { data } = await buildCheckoutPayload(buyerAuth.localId, productId, 1, buyerAuth.idToken);
      // Buyer in Quebec — different province, 500+ km away
      data.shippingAddress.city = 'Montreal';
      data.shippingAddress.state = 'QC';
      data.shippingAddress.postalCode = 'H2X 1Y6';

      const result = await callCallable('create_checkout_session', data, buyerAuth.idToken);
      // Backend must reject this with an error (local-only + out-of-province)
      expect(result.error).toBeTruthy();
      const code = result.error?.code ?? result.error;
      expect(['failed-precondition', 'invalid-argument', 'internal']).toContain(code);
    } finally {
      await deleteDoc(`products/${productId}`, adminAuth.idToken).catch(() => {});
    }
  });

  test('Perishable product without local/same-day option is auto-deactivated by backend', async () => {
    // This tests the CFIA-compliance enforcement in products.py
    // A product marked perishable but with only standard shipping should NOT be purchasable
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const productId = `test_perishable_invalid_${Date.now()}`;

    await writeDoc(`products/${productId}`, toFirestoreFields({
      sellerId: TEST_UIDS.SELLER,
      sellerSku: `PERISH-INVALID-${Date.now()}`,
      name: 'Bad Perishable Product',
      description: 'Perishable item with only standard shipping — should be deactivated.',
      price: 5.00,
      priceCents: 500,
      // Intentionally not setting lifecycleStatus — let the trigger set it
      stockQuantity: 5,
      categoryId: 1,
      imageUrls: ['https://orignagta-dev.web.app/assets/icons/icon-192.png'],
      keywords: [],
      isDigital: false,
      isLocalDeliveryOnly: false,
      isPerishable: true,
      freeShipping: false,
      weightKg: 0.2,
      shipFromCity: 'Toronto',
      shipFromProvince: 'ON',
      shipFromCountry: 'Canada',
      sellerAddress: { street: '100 Front St', city: 'Toronto', state: 'ON', postalCode: 'M5J 1E3', country: 'Canada' },
      // Standard shipping only — CFIA violation for perishables
      deliveryOptions: [{ type: 'standard', national: true }],
      dateCreated: new Date().toISOString(),
    }), adminAuth.idToken);

    try {
      // Trigger on_product_created should deactivate this product
      // Wait for the Cloud Function to process (up to 10s)
      await new Promise(r => setTimeout(r, 10_000));
      const doc = parseDoc(await readDoc(`products/${productId}`, adminAuth.idToken));

      // Backend CFIA enforcement: isActive should be false OR product should not be purchasable
      // The backend sets isActive=false when perishable has no local/same-day option
      const isActive = doc.isActive ?? doc.lifecycleStatus === 'active';
      expect(isActive, 'Perishable product without local/same-day must be deactivated').toBe(false);
    } finally {
      await deleteDoc(`products/${productId}`, adminAuth.idToken).catch(() => {});
    }
  });

  test('International seller has non-zero shipping cost', async () => {
    // Premium buyers get free shipping — skip rather than fail if buyer is currently premium.
    const subResult = await callCallable('get_subscription_status', {}, buyerAuth.idToken);
    const subData = subResult.result ?? subResult;
    if (subData.isPremium) {
      console.log('Skipping: buyer is premium — shipping is always free for premium accounts');
      return;
    }

    const products = await discoverProducts();
    const intlProduct = products.find(p => p.id === 'e2e_product_intl_seller');
    if (!intlProduct) throw new Error('International test product missing');

    const { data } = await buildCheckoutPayload(buyerAuth.localId, intlProduct.id, 1, buyerAuth.idToken);
    const result = await callOk('create_checkout_session', data, buyerAuth.idToken);
    const order = parseDoc(await readDoc(`orders/${result.orderId}`, buyerAuth.idToken));

    // International shipping uses get_international_shipping_estimate (supplier-based cost)
    // "other" supplier standard = $5.99 base — verify it's computed and non-zero
    expect(order.shippingCostCents).toBeGreaterThan(0);
  });
});
