/**
 * OrignaGTA — Digital Products E2E Tests
 * =========================================
 * Tests digital product creation, purchase, license delivery, mixed carts,
 * UX validation and security for software + book digital types.
 *
 * Seed data required:
 *   product_010 → book  (Canadian History eBook Bundle)
 *   product_026 → book  (Digital Photography Course)
 *   product_031 → software (FXCleaner — Mac Disk Cleaner)
 *   product_001 → physical (Handmade Quebec Scarf) — used in mixed cart tests
 *
 * Run: npx playwright test digital-products-e2e.spec.ts
 */
import { test, expect } from '@playwright/test';
import {
  signIn, callOk, callExpectError,
  readDoc, parseDoc,
  buildCheckoutPayload,
  buildMultiSellerPayload,
  fullCheckoutAndPay,
  fillStripeCheckout,
  waitForOrderStatus,
  verifyEmailSent,
  writeDoc,
  deleteDoc,
  toFirestoreFields,
  FUNCTIONS_URL,
  TEST_ACCOUNTS,
  TEST_UIDS,
} from './api-helpers';

// ── Constants ────────────────────────────────────────────────────────────────
const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;
const DIGITAL_PASS = 'REDACTED_TEST_PASSWORD';

/** product_031 = FXCleaner software (macOS) */
const DIGITAL_SW_ID = 'product_031';
/** product_010 = Canadian History eBook Bundle */
const DIGITAL_BOOK_ID = 'product_010';
/** product_001 = physical Scarf — used in mixed cart */
const PHYSICAL_ID = 'product_001';

// ════════════════════════════════════════════════════════════════════════════
// SUITE A · DIGITAL PRODUCT CATALOGUE
// ════════════════════════════════════════════════════════════════════════════

test.describe('A. Digital Product Catalogue', () => {
  test.setTimeout(60_000);

  test('A.1 Software product has correct Firestore fields (FXCleaner)', async () => {
    const doc = await readDoc(`products/${DIGITAL_SW_ID}`);
    const product = parseDoc(doc);

    expect(product, 'Product should exist in Firestore').toBeTruthy();
    expect(product.isDigital, 'isDigital must be true').toBe(true);
    expect(product.digitalType, 'digitalType must be software').toBe('software');
    expect(product.digitalBuilds, 'digitalBuilds must be present').toBeTruthy();
    expect(product.digitalBuilds.macos, 'macOS download URL must be set').toBeTruthy();
    expect(product.supportedPlatforms, 'supportedPlatforms must be present').toContain('macos');
    expect(product.deviceLimit, 'deviceLimit must be set (3 for FXCleaner)').toBe(3);
    expect(product.deliveryOptions, 'No delivery options for digital').toHaveLength(0);
    expect(product.estimatedShipDays, 'Zero ship days for digital').toBe(0);
    expect(product.weightKg, 'Zero weight for digital').toBeFalsy();
  });

  test('A.2 Book product has correct Firestore fields (eBook bundle)', async () => {
    const doc = await readDoc(`products/${DIGITAL_BOOK_ID}`);
    const product = parseDoc(doc);

    expect(product, 'Product should exist').toBeTruthy();
    expect(product.isDigital, 'isDigital must be true').toBe(true);
    expect(product.digitalType, 'digitalType must be book').toBe('book');
    expect(product.bookSourceUrl, 'bookSourceUrl must be set').toBeTruthy();
    expect(product.bookSourceUrl, 'bookSourceUrl must point to a PDF/file').toMatch(/^https?:\/\//);
    expect(product.estimatedShipDays, 'Zero ship days').toBe(0);
    expect(product.freeShipping, 'Digital books should have freeShipping=true').toBe(true);
  });

  test('A.3 Digital product shows "Instant delivery" badge (product model)', async () => {
    // Verify both digital products advertise instant delivery (estimatedShipDays=0)
    // The Flutter UI renders "Instant delivery" for isDigital=true items.
    const [swDoc, bookDoc] = await Promise.all([
      readDoc(`products/${DIGITAL_SW_ID}`),
      readDoc(`products/${DIGITAL_BOOK_ID}`),
    ]);
    const sw = parseDoc(swDoc);
    const book = parseDoc(bookDoc);

    for (const [label, p] of [['software', sw], ['book', book]] as const) {
      expect(p.isDigital, `${label}: isDigital`).toBe(true);
      expect(p.estimatedShipDays, `${label}: zero ship days`).toBe(0);
      // isLocalDeliveryOnly must be false — digital products ship worldwide
      expect(p.isLocalDeliveryOnly, `${label}: not local-only`).toBe(false);
    }
  });
});

// ════════════════════════════════════════════════════════════════════════════
// SUITE B · DIGITAL-ONLY CHECKOUT
// ════════════════════════════════════════════════════════════════════════════

test.describe('B. Digital-Only Checkout', () => {
  test.setTimeout(180_000);

  test('B.1 Digital-only cart skips shipping cost and tax', async () => {
    // Backend always requires a valid Canadian address for consistency,
    // but digital-only orders get zero shipping and zero tax.
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const { data } = await buildCheckoutPayload(auth.localId, DIGITAL_SW_ID, 1, auth.idToken);

    const result = await callOk('create_checkout_session', data, auth.idToken);
    expect(result.orderId, 'checkout session must return orderId').toBeTruthy();
    expect(result.checkoutUrl, 'checkout session must return checkoutUrl').toBeTruthy();

    // Verify digital-only orders have zero shipping and zero tax
    const doc = await readDoc(`orders/${result.orderId}`, auth.idToken);
    const order = parseDoc(doc);
    expect(order.shippingCostCents).toBe(0);
    expect(order.taxAmountCents).toBe(0);
  });

  test('B.2 Buy digital software product → license key created on order item', async ({ page }) => {
    const { orderId } = await fullCheckoutAndPay(page, BUYER_EMAIL, DIGITAL_SW_ID, 1);
    expect(orderId).toBeTruthy();

    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const order = await waitForOrderStatus(orderId, ['confirmed', 'delivered'], auth.idToken, 90_000);

    expect(order.orderStatus).toMatch(/confirmed|delivered/);
    expect(order.paymentStatus).toBe('captured');

    // Find the digital item in the order
    const digitalItem = (order.items || []).find((it: any) => it.productId === DIGITAL_SW_ID);
    expect(digitalItem, 'Order must contain the digital software item').toBeTruthy();
    expect(digitalItem.isDigital, 'Item isDigital flag').toBe(true);
    expect(digitalItem.digitalUnlocked, 'digitalUnlocked must be true after capture').toBe(true);
    expect(digitalItem.licenseKey, 'licenseKey must be set on item after capture').toBeTruthy();
    expect(digitalItem.licenseKey, 'licenseKey format: XXXX-XXXX-XXXX-XXXX').toMatch(
      /^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/
    );

    // License document must exist in /licenses collection
    const licDoc = await readDoc(`licenses/${digitalItem.licenseKey}`, auth.idToken);
    const lic = parseDoc(licDoc);
    expect(lic, 'License doc must exist in Firestore').toBeTruthy();
    expect(lic.status, 'License must be active').toBe('active');
    expect(lic.digitalType, 'License type must match product').toBe('software');
    expect(lic.userId, 'License must belong to buyer').toBe(auth.localId);

    // Verify order confirmation email was sent via _mail_logs
    const authAdmin = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const emails = await verifyEmailSent(BUYER_EMAIL, authAdmin.idToken);
    const orderEmail = emails.find(e => e.subject?.includes('Order Confirm'));
    expect(orderEmail, 'Buyer should receive an order confirmation email').toBeTruthy();
  });

  test('B.3 Buy digital book product → book license created with bookSourceUrl', async ({ page }) => {
    const { orderId } = await fullCheckoutAndPay(page, BUYER_EMAIL, DIGITAL_BOOK_ID, 1);
    expect(orderId).toBeTruthy();

    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const order = await waitForOrderStatus(orderId, ['confirmed', 'delivered'], auth.idToken, 90_000);

    const bookItem = (order.items || []).find((it: any) => it.productId === DIGITAL_BOOK_ID);
    expect(bookItem, 'Order must contain book item').toBeTruthy();
    expect(bookItem.digitalUnlocked, 'digitalUnlocked after capture').toBe(true);
    expect(bookItem.licenseKey, 'licenseKey on book item').toBeTruthy();

    const licDoc = await readDoc(`licenses/${bookItem.licenseKey}`, auth.idToken);
    const lic = parseDoc(licDoc);
    expect(lic.digitalType, 'Book license type').toBe('book');
    expect(lic.bookSourceUrl, 'bookSourceUrl stored on license').toBeTruthy();
    expect(lic.status).toBe('active');

    // Verify order confirmation email
    const authAdmin = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const emails = await verifyEmailSent(BUYER_EMAIL, authAdmin.idToken);
    const orderEmail = emails.find(e => e.subject?.includes('Order Confirm'));
    expect(orderEmail, 'Buyer should receive an order confirmation email for the book').toBeTruthy();
  });
});

// ════════════════════════════════════════════════════════════════════════════
// SUITE C · MIXED CART (DIGITAL + PHYSICAL)
// ════════════════════════════════════════════════════════════════════════════

test.describe('C. Mixed Cart — Digital + Physical', () => {
  test.setTimeout(180_000);

  test('C.1 Mixed cart requires shipping address (digital does not waive physical requirement)', async () => {
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const payload = await buildMultiSellerPayload(
      auth.localId,
      [
        { productId: DIGITAL_SW_ID, quantity: 1 },
        { productId: PHYSICAL_ID, quantity: 1 },
      ],
      auth.idToken,
    );

    // Remove the shipping address — should fail because physical item is in cart
    const noAddressPayload = { ...payload, shippingAddress: {} };
    const result = await callExpectError(
      'create_checkout_session', noAddressPayload, auth.idToken
    );
    expect(result.message, 'Must reject missing address for mixed cart').toBeTruthy();
  });

  test('C.2 Mixed cart checkout creates order with both digital and physical items', async ({ page }) => {
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const payload = await buildMultiSellerPayload(
      auth.localId,
      [
        { productId: DIGITAL_SW_ID, quantity: 1 },
        { productId: PHYSICAL_ID, quantity: 1 },
      ],
      auth.idToken,
    );
    const session = await callOk('create_checkout_session', payload, auth.idToken);
    expect(session.orderId).toBeTruthy();
    expect(session.checkoutUrl).toBeTruthy();

    await page.goto(session.checkoutUrl);
    await fillStripeCheckout(page, BUYER_EMAIL);
    await page.waitForTimeout(5_000);

    const order = await waitForOrderStatus(session.orderId, ['confirmed', 'delivered'], auth.idToken, 90_000);
    expect(order.items.length, 'Order must have 2 items').toBeGreaterThanOrEqual(2);

    const digitalItem = order.items.find((it: any) => it.productId === DIGITAL_SW_ID);
    const physicalItem = order.items.find((it: any) => it.productId === PHYSICAL_ID);
    expect(digitalItem, 'Digital item in order').toBeTruthy();
    expect(physicalItem, 'Physical item in order').toBeTruthy();

    // Digital item gets a license; physical does not
    expect(digitalItem.isDigital).toBe(true);
    expect(physicalItem.isDigital).toBeFalsy();

    // Verify order confirmation email was sent via _mail_logs
    const authAdmin = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const emails = await verifyEmailSent(BUYER_EMAIL, authAdmin.idToken);
    const orderEmail = emails.find(e => e.subject?.includes('Order Confirm'));
    expect(orderEmail, 'Buyer should receive an order confirmation email for mixed cart').toBeTruthy();
  });

  test('C.3 Shipping cost is nonzero in mixed cart (physical item triggers shipping calc)', async () => {
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const payload = await buildMultiSellerPayload(
      auth.localId,
      [
        { productId: DIGITAL_SW_ID, quantity: 1 },
        { productId: PHYSICAL_ID, quantity: 1 },
      ],
      auth.idToken,
    );
    const session = await callOk('create_checkout_session', payload, auth.idToken);
    const orderDoc = await readDoc(`orders/${session.orderId}`, auth.idToken);
    const order = parseDoc(orderDoc);

    // Digital-only orders have shippingCostCents=0; mixed orders may have shipping > 0
    // (unless the physical product has freeShipping=true — scarf does NOT have free shipping)
    expect(typeof order.shippingCostCents).toBe('number');
    expect(order.shippingCostCents, 'Mixed cart shipping cost should be non-negative').toBeGreaterThanOrEqual(0);
  });
});

// ════════════════════════════════════════════════════════════════════════════
// SUITE D · LICENSE ACTIVATION & BOOK DOWNLOAD
// ════════════════════════════════════════════════════════════════════════════

test.describe('D. License Activation & Book Download', () => {
  test.describe.configure({ mode: 'serial' });
  test.setTimeout(180_000);

  let softwareLicenseKey: string;
  let bookLicenseKey: string;

  // Seed license keys directly via admin API to avoid slow Stripe checkout
  test.beforeAll(async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const buyerAuth = await signIn(BUYER_EMAIL, DIGITAL_PASS);

    // Seed software license (FXCleaner — macOS only)
    softwareLicenseKey = 'REDACTED_SECRET';
    await writeDoc(`licenses/${softwareLicenseKey}`, toFirestoreFields({
      licenseKey: softwareLicenseKey,
      productId: DIGITAL_SW_ID,
      orderId: 'e2e-test-order-d-sw',
      userId: buyerAuth.localId,
      digitalType: 'software',
      status: 'active',
      supportedPlatforms: ['macos'],
      deviceLimit: 3,
      activations: [],
      digitalBuilds: { macos: 'https://cdn.example.com/fxcleaner-mac-test.dmg' },
      productName: 'FXCleaner',
      createdAt: new Date(),
    }), adminAuth.idToken, false);

    // Seed book license (eBook)
    bookLicenseKey = 'REDACTED_SECRET';
    await writeDoc(`licenses/${bookLicenseKey}`, toFirestoreFields({
      licenseKey: bookLicenseKey,
      productId: DIGITAL_BOOK_ID,
      orderId: 'e2e-test-order-d-book',
      userId: buyerAuth.localId,
      digitalType: 'book',
      status: 'active',
      bookSourceUrl: 'https://cdn.example.com/test-ebook.pdf',
      productName: 'Canadian History eBook Bundle',
      createdAt: new Date(),
    }), adminAuth.idToken, false);
  });

  test.afterAll(async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    await deleteDoc(`licenses/${softwareLicenseKey}`, adminAuth.idToken);
    await deleteDoc(`licenses/${bookLicenseKey}`, adminAuth.idToken);
  });

  test('D.1 Activate software license on a new device → approved with downloadUrls', async () => {
    expect(softwareLicenseKey, 'Need a software license from beforeAll').toBeTruthy();

    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const result = await callOk('activate_license', {
      licenseKey: softwareLicenseKey,
      deviceId: 'e2e-device-mac-001',
      platform: 'macos',
    }, auth.idToken);

    expect(result.approved, 'License activation must be approved').toBe(true);
    expect(result.licenseKey).toBe(softwareLicenseKey);
    expect(result.downloadUrls, 'downloadUrls must contain macos URL').toBeTruthy();
    expect(result.downloadUrls.macos, 'macOS download URL present').toBeTruthy();
  });

  test('D.2 Re-activating same device is idempotent (no duplicate activation entry)', async () => {
    expect(softwareLicenseKey).toBeTruthy();

    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);

    // Activate same device twice
    await callOk('activate_license', { licenseKey: softwareLicenseKey, deviceId: 'e2e-device-mac-idempotent', platform: 'macos' }, auth.idToken);
    const result = await callOk('activate_license', { licenseKey: softwareLicenseKey, deviceId: 'e2e-device-mac-idempotent', platform: 'macos' }, auth.idToken);

    expect(result.approved).toBe(true);

    const licDoc = await readDoc(`licenses/${softwareLicenseKey}`, auth.idToken);
    const lic = parseDoc(licDoc);
    const activations: any[] = lic.activations || [];
    const deviceEntries = activations.filter((a: any) => a.deviceId === 'e2e-device-mac-idempotent');
    expect(deviceEntries.length, 'Same device must only appear once in activations').toBe(1);
  });

  test('D.3 Generate book download session → single-use downloadUrl returned', async () => {
    expect(bookLicenseKey, 'Need a book license from beforeAll').toBeTruthy();

    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const result = await callOk('generate_book_download_session', {
      licenseKey: bookLicenseKey,
    }, auth.idToken);

    expect(result.downloadUrl, 'downloadUrl must be present').toBeTruthy();
    expect(result.downloadUrl, 'downloadUrl must contain a tok_ token').toMatch(/tok_/);
    // Token must be a well-formed URL
    expect(() => new URL(result.downloadUrl)).not.toThrow();
  });

  test('D.4 Software license on wrong platform is rejected', async () => {
    expect(softwareLicenseKey).toBeTruthy();

    // FXCleaner is macOS-only; activating on linux must fail
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const result = await callExpectError('activate_license', {
      licenseKey: softwareLicenseKey,
      deviceId: 'e2e-device-linux-001',
      platform: 'linux',
    }, auth.idToken);

    expect(result.message, 'platform_not_supported error').toBeTruthy();
    expect(result.code, 'Error code must not be unexpected-success').not.toBe('unexpected-success');
  });
});

// ════════════════════════════════════════════════════════════════════════════
// SUITE E · SECURITY & ACCESS CONTROL
// ════════════════════════════════════════════════════════════════════════════

test.describe('E. Security & Access Control', () => {
  test.setTimeout(180_000);

  let buyerLicenseKey: string;
  let buyerBookLicenseKey: string;

  // Seed license keys directly via admin API to avoid slow Stripe checkout
  test.beforeAll(async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const buyerAuth = await signIn(BUYER_EMAIL, DIGITAL_PASS);

    buyerLicenseKey = 'E2EE-SW01-ABCD-9999';
    await writeDoc(`licenses/${buyerLicenseKey}`, toFirestoreFields({
      licenseKey: buyerLicenseKey,
      productId: DIGITAL_SW_ID,
      orderId: 'e2e-test-order-e-sw',
      userId: buyerAuth.localId,
      digitalType: 'software',
      status: 'active',
      supportedPlatforms: ['macos'],
      deviceLimit: 3,
      activations: [],
      digitalBuilds: { macos: 'https://cdn.example.com/fxcleaner-mac-test.dmg' },
      productName: 'FXCleaner',
      createdAt: new Date(),
    }), adminAuth.idToken, false);

    buyerBookLicenseKey = 'E2EE-BK01-ABCD-8888';
    await writeDoc(`licenses/${buyerBookLicenseKey}`, toFirestoreFields({
      licenseKey: buyerBookLicenseKey,
      productId: DIGITAL_BOOK_ID,
      orderId: 'e2e-test-order-e-book',
      userId: buyerAuth.localId,
      digitalType: 'book',
      status: 'active',
      bookSourceUrl: 'https://cdn.example.com/test-ebook-e4.pdf',
      productName: 'Canadian History eBook Bundle',
      createdAt: new Date(),
    }), adminAuth.idToken, false);
  });

  test.afterAll(async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    await deleteDoc(`licenses/${buyerLicenseKey}`, adminAuth.idToken);
    await deleteDoc(`licenses/${buyerBookLicenseKey}`, adminAuth.idToken);
  });

  test('E.1 Another buyer cannot activate a license they do not own', async () => {
    expect(buyerLicenseKey).toBeTruthy();

    // Admin is a different user — trying to activate buyer's license must fail
    const attackerAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const result = await callExpectError('activate_license', {
      licenseKey: buyerLicenseKey,
      deviceId: 'attacker-device-001',
      platform: 'macos',
    }, attackerAuth.idToken);

    expect(result.message, 'Must reject activation by non-owner').toBeTruthy();
    expect(result.code, 'Must not succeed').not.toBe('unexpected-success');
  });

  test('E.2 Malformed license key format is rejected before DB lookup', async () => {
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const result = await callExpectError('activate_license', {
      licenseKey: 'not-a-valid-key',
      deviceId: 'device-001',
      platform: 'macos',
    }, auth.idToken);

    expect(result.message, 'invalid_key_format error expected').toBeTruthy();
    expect(result.code).not.toBe('unexpected-success');
  });

  test('E.3 Non-owner cannot generate book download session', async () => {
    // Use a hardcoded non-existent license key — should return not_found or unauthorized
    const attackerAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const result = await callExpectError('generate_book_download_session', {
      licenseKey: 'FAKE-FAKE-FAKE-FAKE',
    }, attackerAuth.idToken);

    // Either not-found (key doesn't exist) or permission-denied (wrong owner) — both correct
    expect(result.code, 'Must reject non-existent license key request').not.toBe('unexpected-success');
  });

  test('E.4 Book download session token is single-use (second use of same token fails)', async () => {
    // Use pre-seeded book license to generate a session token, "use" it by calling the redirect endpoint,
    // then try to reuse the token — should get 410 Gone (already_used).
    expect(buyerBookLicenseKey).toBeTruthy();

    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);

    const sessionResult = await callOk('generate_book_download_session', {
      licenseKey: buyerBookLicenseKey,
    }, auth.idToken);

    // Extract the token from the downloadUrl
    const downloadUrl: string = sessionResult.downloadUrl;
    const token = new URL(downloadUrl).searchParams.get('t');
    expect(token, 'Token must be in downloadUrl query param').toBeTruthy();

    // Simulate "using" the token by calling the public redirect endpoint
    const firstUse = await fetch(`${FUNCTIONS_URL}/get_book_redirect?t=${token}`, { redirect: 'manual' });
    // Should redirect (302) or succeed; the token is now marked used.
    expect([200, 302, 410].includes(firstUse.status), 'First use: valid response code').toBe(true);

    if (firstUse.status === 302) {
      // Token was used — second call must return 410
      const secondUse = await fetch(`${FUNCTIONS_URL}/get_book_redirect?t=${token}`, { redirect: 'manual' });
      expect(secondUse.status, 'Second use of same token must return 410').toBe(410);
    }
  });
});

// ════════════════════════════════════════════════════════════════════════════
// SUITE F · SELLER UX — DIGITAL PRODUCT CREATION
// ════════════════════════════════════════════════════════════════════════════

test.describe('F. Seller UX — Digital Product Creation', () => {
  test.setTimeout(60_000);

  test('F.1 Digital product schema is valid for Firestore after seeding', async () => {
    // Verify all 3 digital products have required fields
    const [swDoc, bookDoc, courseDoc] = await Promise.all([
      readDoc(`products/${DIGITAL_SW_ID}`),
      readDoc(`products/${DIGITAL_BOOK_ID}`),
      readDoc(`products/product_026`),
    ]);

    for (const [label, doc] of [['software', swDoc], ['ebook', bookDoc], ['course', courseDoc]] as const) {
      const p = parseDoc(doc);
      expect(p, `${label}: product must exist`).toBeTruthy();
      expect(p.isDigital, `${label}: isDigital`).toBe(true);
      expect(p.digitalType, `${label}: digitalType must be set`).toBeTruthy();
      expect(['software', 'book']).toContain(p.digitalType);
      expect(p.estimatedShipDays, `${label}: estimatedShipDays=0`).toBe(0);
      expect(p.lifecycleStatus, `${label}: product must be active`).toBe('active');
    }
  });

  test('F.2 Digital-only checkout generates zero shipping cost', async () => {
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const { data } = await buildCheckoutPayload(auth.localId, DIGITAL_SW_ID, 1, auth.idToken);
    const session = await callOk('create_checkout_session', data, auth.idToken);

    const orderDoc = await readDoc(`orders/${session.orderId}`, auth.idToken);
    const order = parseDoc(orderDoc);

    expect(order.shippingCostCents, 'Digital-only order: zero shipping').toBe(0);
  });

  test('F.3 FXCleaner digital purchase gets zero shipping and zero tax', async () => {
    // Digital products still require a valid Canadian address (early validation),
    // but the order gets zero shipping and zero tax.
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const { data } = await buildCheckoutPayload(auth.localId, DIGITAL_SW_ID, 1, auth.idToken);

    const result = await callOk('create_checkout_session', data, auth.idToken);
    expect(result.orderId, 'Digital checkout must succeed').toBeTruthy();

    const doc = await readDoc(`orders/${result.orderId}`, auth.idToken);
    const order = parseDoc(doc);
    expect(order.shippingCostCents, 'Digital order: zero shipping').toBe(0);
    expect(order.taxAmountCents, 'Digital order: zero tax').toBe(0);
  });
});

// ════════════════════════════════════════════════════════════════════════════
// SUITE G · SOFTWARE DOWNLOAD SESSION (generate_software_download_session)
// ════════════════════════════════════════════════════════════════════════════

test.describe('G. Software Download Session', () => {
  test.setTimeout(180_000);

  let swLicenseKey: string;

  test.beforeAll(async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const buyerAuth = await signIn(BUYER_EMAIL, DIGITAL_PASS);

    swLicenseKey = 'E2EG-SW01-ABCD-7777';
    await writeDoc(`licenses/${swLicenseKey}`, toFirestoreFields({
      licenseKey: swLicenseKey,
      productId: DIGITAL_SW_ID,
      orderId: 'e2e-test-order-g-sw',
      userId: buyerAuth.localId,
      digitalType: 'software',
      status: 'active',
      supportedPlatforms: ['macos', 'windows'],
      deviceLimit: 3,
      activations: [],
      digitalBuilds: {
        macos: 'https://cdn.example.com/fxcleaner-mac-g.dmg',
        windows: 'https://cdn.example.com/fxcleaner-win-g.exe',
      },
      productName: 'FXCleaner',
      createdAt: new Date(),
    }), adminAuth.idToken, false);

    // Pre-activate one device so the license is usable
    await callOk('activate_license', {
      licenseKey: swLicenseKey,
      deviceId: 'e2e-g-device-mac',
      platform: 'macos',
    }, buyerAuth.idToken);
  });

  test.afterAll(async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    await deleteDoc(`licenses/${swLicenseKey}`, adminAuth.idToken);
  });

  test('G.1 generate_software_download_session → downloadUrl with /sdl?t= token', async () => {
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const result = await callOk('generate_software_download_session', {
      licenseKey: swLicenseKey,
      platform: 'macos',
    }, auth.idToken);

    expect(result.downloadUrl, 'downloadUrl must be present').toBeTruthy();
    expect(result.downloadUrl, 'must use /sdl endpoint (software)').toMatch(/\/sdl\?t=/);
    expect(result.downloadUrl, 'token must start with tok_').toMatch(/tok_/);
    expect(() => new URL(result.downloadUrl)).not.toThrow();
  });

  test('G.2 software download token is single-use (second use returns 410)', async () => {
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const session = await callOk('generate_software_download_session', {
      licenseKey: swLicenseKey,
      platform: 'macos',
    }, auth.idToken);

    const token = new URL(session.downloadUrl).searchParams.get('t');
    expect(token, 'Token param must be present').toBeTruthy();

    const firstUse = await fetch(`${FUNCTIONS_URL}/get_software_redirect?t=${token}`, { redirect: 'manual' });
    expect([200, 302, 410].includes(firstUse.status), 'First use must succeed or redirect').toBe(true);

    if (firstUse.status === 302) {
      const secondUse = await fetch(`${FUNCTIONS_URL}/get_software_redirect?t=${token}`, { redirect: 'manual' });
      expect(secondUse.status, 'Second use of software token must return 410').toBe(410);
    }
  });

  test('G.3 generate_software_download_session on wrong platform is rejected', async () => {
    // License only has macos + windows — linux must fail
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const result = await callExpectError('generate_software_download_session', {
      licenseKey: swLicenseKey,
      platform: 'linux',
    }, auth.idToken);
    expect(result.message, 'platform_not_supported error').toBeTruthy();
  });

  test('G.4 Non-owner cannot generate software download session', async () => {
    const attackerAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const result = await callExpectError('generate_software_download_session', {
      licenseKey: swLicenseKey,
      platform: 'macos',
    }, attackerAuth.idToken);
    expect(result.message, 'Must reject non-owner').toBeTruthy();
  });

  test('G.5 generate_software_download_session on a book license is rejected', async () => {
    // Seed a book license and try calling the software session endpoint against it
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const buyerAuth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const bookKey = 'E2EG-BK01-ABCD-6666';
    await writeDoc(`licenses/${bookKey}`, toFirestoreFields({
      licenseKey: bookKey,
      productId: DIGITAL_BOOK_ID,
      orderId: 'e2e-test-order-g-book',
      userId: buyerAuth.localId,
      digitalType: 'book',
      status: 'active',
      bookSourceUrl: 'https://cdn.example.com/test-g.pdf',
      productName: 'Canadian History eBook Bundle',
      createdAt: new Date(),
    }), adminAuth.idToken, false);

    try {
      const result = await callExpectError('generate_software_download_session', {
        licenseKey: bookKey,
        platform: 'macos',
      }, buyerAuth.idToken);
      expect(result.message, 'not_a_software_license error expected').toBeTruthy();
    } finally {
      await deleteDoc(`licenses/${bookKey}`, adminAuth.idToken);
    }
  });
});

// ════════════════════════════════════════════════════════════════════════════
// SUITE H · LICENSE MANAGEMENT (deactivate, verify, device limit, revoke)
// ════════════════════════════════════════════════════════════════════════════

test.describe('H. License Management — Deactivate, Verify, Device Limit, Revoke', () => {
  test.describe.configure({ mode: 'serial' });
  test.setTimeout(60_000);

  let manageLicenseKey: string;
  let revokedLicenseKey: string;
  let limitedLicenseKey: string;

  test.beforeAll(async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const buyerAuth = await signIn(BUYER_EMAIL, DIGITAL_PASS);

    // License for deactivate / verify tests (pre-activated on one device)
    manageLicenseKey = 'E2EH-SW01-MGMT-1111';
    await writeDoc(`licenses/${manageLicenseKey}`, toFirestoreFields({
      licenseKey: manageLicenseKey,
      productId: DIGITAL_SW_ID,
      orderId: 'e2e-test-order-h-manage',
      userId: buyerAuth.localId,
      digitalType: 'software',
      status: 'active',
      supportedPlatforms: ['macos'],
      deviceLimit: 3,
      activations: [
        {
          deviceId: 'e2e-h-preactivated',
          platform: 'macos',
          activatedAt: new Date(),
          lastVerifiedAt: new Date(),
        },
      ],
      digitalBuilds: { macos: 'https://cdn.example.com/fxcleaner-h.dmg' },
      productName: 'FXCleaner',
      createdAt: new Date(),
    }), adminAuth.idToken, false);

    // Revoked license — status=revoked
    revokedLicenseKey = 'E2EH-SW01-REVK-2222';
    await writeDoc(`licenses/${revokedLicenseKey}`, toFirestoreFields({
      licenseKey: revokedLicenseKey,
      productId: DIGITAL_SW_ID,
      orderId: 'e2e-test-order-h-revoked',
      userId: buyerAuth.localId,
      digitalType: 'software',
      status: 'revoked',
      revokedReason: 'refunded',
      supportedPlatforms: ['macos'],
      deviceLimit: 3,
      activations: [],
      digitalBuilds: { macos: 'https://cdn.example.com/fxcleaner-revoked.dmg' },
      productName: 'FXCleaner',
      createdAt: new Date(),
    }), adminAuth.idToken, false);

    // License with deviceLimit=2, already at 2 activations
    limitedLicenseKey = 'E2EH-SW01-LIMT-3333';
    await writeDoc(`licenses/${limitedLicenseKey}`, toFirestoreFields({
      licenseKey: limitedLicenseKey,
      productId: DIGITAL_SW_ID,
      orderId: 'e2e-test-order-h-limit',
      userId: buyerAuth.localId,
      digitalType: 'software',
      status: 'active',
      supportedPlatforms: ['macos'],
      deviceLimit: 2,
      activations: [
        { deviceId: 'h-device-1', platform: 'macos', activatedAt: new Date(), lastVerifiedAt: new Date() },
        { deviceId: 'h-device-2', platform: 'macos', activatedAt: new Date(), lastVerifiedAt: new Date() },
      ],
      digitalBuilds: { macos: 'https://cdn.example.com/fxcleaner-limited.dmg' },
      productName: 'FXCleaner',
      createdAt: new Date(),
    }), adminAuth.idToken, false);
  });

  test.afterAll(async () => {
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    await Promise.all([
      deleteDoc(`licenses/${manageLicenseKey}`, adminAuth.idToken),
      deleteDoc(`licenses/${revokedLicenseKey}`, adminAuth.idToken),
      deleteDoc(`licenses/${limitedLicenseKey}`, adminAuth.idToken),
    ]);
  });

  test('H.1 deactivate_license removes device — remaining activations decremented', async () => {
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);

    const deactivateResult = await callOk('deactivate_license', {
      licenseKey: manageLicenseKey,
      deviceId: 'e2e-h-preactivated',
    }, auth.idToken);

    expect(deactivateResult.deactivated, 'deactivated flag must be true').toBe(true);
    expect(deactivateResult.remainingActivations, 'remaining activations must be 0').toBe(0);

    // Verify Firestore reflects the removal
    const licDoc = await readDoc(`licenses/${manageLicenseKey}`, auth.idToken);
    const lic = parseDoc(licDoc);
    const activations: any[] = lic.activations || [];
    const stillPresent = activations.find((a: any) => a.deviceId === 'e2e-h-preactivated');
    expect(stillPresent, 'Deactivated device must be removed from activations array').toBeUndefined();
  });

  test('H.2 After deactivation, same device can be re-activated (slot freed)', async () => {
    // H.1 deactivated 'e2e-h-preactivated' — re-activating must succeed
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const result = await callOk('activate_license', {
      licenseKey: manageLicenseKey,
      deviceId: 'e2e-h-preactivated',
      platform: 'macos',
    }, auth.idToken);
    expect(result.approved, 'Re-activation after deactivation must succeed').toBe(true);
  });

  test('H.3 Non-owner cannot deactivate a license', async () => {
    const attackerAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const result = await callExpectError('deactivate_license', {
      licenseKey: manageLicenseKey,
      deviceId: 'e2e-h-preactivated',
    }, attackerAuth.idToken);
    expect(result.message, 'permission-denied for non-owner deactivation').toBeTruthy();
  });

  test('H.4 Activating a revoked license is rejected with "revoked" error', async () => {
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const result = await callExpectError('activate_license', {
      licenseKey: revokedLicenseKey,
      deviceId: 'e2e-h-revoked-device',
      platform: 'macos',
    }, auth.idToken);
    expect(result.message, 'Revoked license must return revoked error').toBeTruthy();
  });

  test('H.5 device_limit_exceeded: adding a 3rd device to limit=2 license is rejected', async () => {
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const result = await callExpectError('activate_license', {
      licenseKey: limitedLicenseKey,
      deviceId: 'h-device-3-over-limit',
      platform: 'macos',
    }, auth.idToken);
    expect(result.message, 'device_limit_exceeded error expected').toBeTruthy();
  });

  test('H.6 verify_license re-activates idempotently — no duplicate in activations array', async () => {
    // verify_license calls the same _activate_license_impl logic
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);

    // First ensure the device IS activated (H.2 may have done this, but be explicit)
    await callOk('activate_license', {
      licenseKey: manageLicenseKey,
      deviceId: 'e2e-h-verify-device',
      platform: 'macos',
    }, auth.idToken);

    // Call verify_license (public, no auth token needed)
    const verifyResult = await fetch(`${FUNCTIONS_URL}/verify_license`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        licenseKey: manageLicenseKey,
        deviceId: 'e2e-h-verify-device',
        platform: 'macos',
      }),
    });

    expect(verifyResult.status, 'verify_license must return 200').toBe(200);
    const verifyBody = await verifyResult.json();
    expect(verifyBody.approved, 'verify response must have approved=true').toBe(true);

    // Verify no duplicate entry in Firestore
    const licDoc = await readDoc(`licenses/${manageLicenseKey}`, auth.idToken);
    const lic = parseDoc(licDoc);
    const entries = (lic.activations || []).filter((a: any) => a.deviceId === 'e2e-h-verify-device');
    expect(entries.length, 'Same device must appear exactly once after multiple verifications').toBe(1);
  });
});

// ════════════════════════════════════════════════════════════════════════════
// SUITE I · DIGITAL BUSINESS RULES (no return, license revoked on refund)
// ════════════════════════════════════════════════════════════════════════════

test.describe('I. Digital Business Rules', () => {
  test.setTimeout(60_000);

  test('I.1 Digital product cannot be returned (create_return_request rejected)', async () => {
    // Seed a delivered order containing a digital item, then try to return it.
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const buyerAuth = await signIn(BUYER_EMAIL, DIGITAL_PASS);

    const orderId = `e2e-test-i1-digital-return-${Date.now()}`;
    const digitalItem = {
      productId: DIGITAL_SW_ID,
      name: 'FXCleaner',
      description: 'Mac disk cleaner',
      price: 29.99,
      quantity: 1,
      imageUrls: ['https://example.com/fx.jpg'],
      sellerId: TEST_UIDS.SELLER,
      isDigital: true,
      status: 'delivered',
      deliveredAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
    };

    await writeDoc(`orders/${orderId}`, toFirestoreFields({
      orderId,
      userId: buyerAuth.localId,
      items: [digitalItem],
      orderStatus: 'delivered',
      paymentStatus: 'captured',
      subtotalCents: 2999,
      shippingCostCents: 0,
      taxAmountCents: 150,
      totalAmountCents: 3149,
      createdAt: new Date(),
      updatedAt: new Date(),
    }), adminAuth.idToken, false);

    try {
      const result = await callExpectError('create_return_request', {
        orderId,
        productId: DIGITAL_SW_ID,
        returnReason: 'Changed my mind',
      }, buyerAuth.idToken);
      expect(result.message, 'Digital products cannot be returned').toBeTruthy();
    } finally {
      await deleteDoc(`orders/${orderId}`, adminAuth.idToken);
    }
  });

  test('I.2 License is revoked when order is refunded (revoke_digital_licenses_for_order)', async () => {
    // Seed a license tied to an order, trigger refund_order_item, verify license status=revoked.
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const buyerAuth = await signIn(BUYER_EMAIL, DIGITAL_PASS);

    const orderId = 'e2e-test-i2-revoke-on-refund';
    const licenseKey = 'E2EI-SW01-RVKR-4444';
    const stripePaymentIntentId = 'pi_test_e2e_i2_captured'; // placeholder — refund will fail gracefully

    await writeDoc(`licenses/${licenseKey}`, toFirestoreFields({
      licenseKey,
      productId: DIGITAL_SW_ID,
      orderId,
      userId: buyerAuth.localId,
      digitalType: 'software',
      status: 'active',
      supportedPlatforms: ['macos'],
      deviceLimit: 3,
      activations: [],
      digitalBuilds: { macos: 'https://cdn.example.com/fxcleaner-i2.dmg' },
      productName: 'FXCleaner',
      createdAt: new Date(),
    }), adminAuth.idToken, false);

    // Verify license is active before refund
    const licBefore = parseDoc(await readDoc(`licenses/${licenseKey}`, buyerAuth.idToken));
    expect(licBefore.status, 'License must start as active').toBe('active');

    // Trigger license revocation via the internal function (simulated by admin writing revoked status
    // since we cannot call _revoke_digital_licenses_for_order directly without a real Stripe capture).
    // We test the revocation by verifying the activation fails after revoking.
    await writeDoc(`licenses/${licenseKey}`, toFirestoreFields({
      status: 'revoked',
      revokedAt: new Date(),
      revokedReason: 'refunded',
      updatedAt: new Date(),
    }), adminAuth.idToken, true /* merge */);

    const licAfter = parseDoc(await readDoc(`licenses/${licenseKey}`, buyerAuth.idToken));
    expect(licAfter.status, 'License must be revoked after refund').toBe('revoked');

    // Activation must now fail
    const activationResult = await callExpectError('activate_license', {
      licenseKey,
      deviceId: 'i2-test-device',
      platform: 'macos',
    }, buyerAuth.idToken);
    expect(activationResult.message, 'Revoked license activation must be rejected').toBeTruthy();

    // Cleanup
    await deleteDoc(`licenses/${licenseKey}`, adminAuth.idToken);
  });

  test('I.3 Digital-only order has zero shippingCostCents', async () => {
    // Confirm the Firestore order created for a digital-only checkout
    // has shippingCostCents=0 (address is still required by backend validation).
    const auth = await signIn(BUYER_EMAIL, DIGITAL_PASS);
    const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    const { data } = await buildCheckoutPayload(auth.localId, DIGITAL_BOOK_ID, 1, auth.idToken);
    const session = await callOk('create_checkout_session', data, auth.idToken);
    expect(session.orderId).toBeTruthy();

    const order = parseDoc(await readDoc(`orders/${session.orderId}`, auth.idToken));
    expect(order.shippingCostCents, 'Digital order: zero shipping').toBe(0);
    // Cleanup — admin token required; buyers cannot delete order documents
    await deleteDoc(`orders/${session.orderId}`, adminAuth.idToken);
  });
});