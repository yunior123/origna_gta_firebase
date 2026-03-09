import { test, expect } from '@playwright/test';
import {
  waitForFlutter, requireWebApp, checkSemantics,
  ensureLoggedInAsAdmin, performSignOut, navigateHome,
  BTN_ADD_PRODUCT,
} from './flutter-helpers';
import {
  signIn, callOk, callExpectError,
  getDoc, deleteDoc,
  TEST_ACCOUNTS, WEB_APP_URL, uid,
} from './api-helpers';
import * as path from 'path';
import * as os from 'os';

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;
const ADMIN_EMAIL = process.env.E2E_ADMIN_EMAIL ?? TEST_ACCOUNTS.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? TEST_ACCOUNTS.ADMIN_PASS;
const SELLER_EMAIL = TEST_ACCOUNTS.SELLER_EMAIL;
const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;

// Track created product IDs for cleanup
const createdProductIds: string[] = [];

async function scrollToBottom(page: any) {
  await page.mouse.move(640, 400);
  for (let i = 0; i < 6; i++) {
    await page.mouse.wheel(0, 4000);
    await page.waitForTimeout(300);
  }
}

async function screenshotOnFailure(page: any, testInfo: { title: string; status?: string }) {
  if (testInfo.status === 'failed' || testInfo.status === 'timedOut') {
    const slug = testInfo.title.replace(/\W+/g, '_').slice(0, 80);
    const dest = path.join(os.homedir(), 'Desktop', `FAILED_${slug}_${Date.now()}.png`);
    try { await page.screenshot({ path: dest, fullPage: true }); } catch {}
  }
}

function getPublishBtn(page: any) {
  return page.getByRole('button', { name: /btn-publish-product/i }).first();
}

// ═══ API-DRIVEN TESTS (no browser needed) ═══

test.describe('Add Product — API Tests', () => {
  test.setTimeout(120_000);
  test.describe.configure({ mode: 'serial' });

  let sellerToken: string;
  let sellerUid: string;
  let adminToken: string;
  let buyerToken: string;

  test.beforeAll(async () => {
    const seller = await signIn(SELLER_EMAIL);
    sellerToken = seller.idToken;
    sellerUid = seller.localId;
    const admin = await signIn(ADMIN_EMAIL, ADMIN_PASSWORD);
    adminToken = admin.idToken;
    const buyer = await signIn(BUYER_EMAIL);
    buyerToken = buyer.idToken;
  });

  test.afterAll(async () => {
    // Cleanup: soft-delete all created products via callable (respects security rules)
    for (const pid of createdProductIds) {
      try {
        await callOk('delete_product', { productId: pid }, sellerToken);
      } catch {
        // Fallback to hard-delete if callable fails (product may already be archived)
        try { await deleteDoc(`products/${pid}`, sellerToken); } catch {}
      }
    }
  });

  test('T01: Create product via callable — verify Firestore doc', async () => {
    const testName = `E2E Product ${uid()}`;
    // Use ebook digital type to avoid geocoding timeout on address verification
    const result = await callOk('create_product_atomic', {
      productData: {
        name: testName,
        description: 'E2E test product',
        price: 29.99,
        stockQuantity: 10,
        categoryId: '1',
        isDigital: true,
        digitalType: 'book',
        bookSourceUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      },
      testImageUrls: ['https://picsum.photos/400/400'],
    }, sellerToken);

    expect(result.success).toBe(true);
    expect(result.productId).toBeTruthy();
    createdProductIds.push(result.productId);

    // Verify Firestore doc
    const doc = await getDoc(`products/${result.productId}`, sellerToken);
    expect(doc).toBeTruthy();
    expect(doc.name).toBe(testName);
    expect(doc.price).toBe(29.99);
    expect(doc.stockQuantity).toBe(10);
    expect(doc.sellerId).toBe(sellerUid);
    expect(doc.lifecycleStatus).toBe('under_review');
    expect(doc.imageUrls).toBeTruthy();
    expect(doc.imageUrls.length).toBeGreaterThan(0);
  });

  test('T02: Create digital product — verify digital fields in Firestore', async () => {
    const testName = `E2E Digital ${uid()}`;
    const result = await callOk('create_product_atomic', {
      productData: {
        name: testName,
        description: 'E2E test digital product',
        price: 9.99,
        stockQuantity: 999,
        categoryId: '1',
        isDigital: true,
        digitalType: 'software',
        digitalBuilds: { windows: 'https://example.com/setup.exe' },
      },
      testImageUrls: ['https://picsum.photos/400/400'],
    }, sellerToken);

    expect(result.success).toBe(true);
    createdProductIds.push(result.productId);

    const doc = await getDoc(`products/${result.productId}`, sellerToken);
    expect(doc).toBeTruthy();
    expect(doc.isDigital).toBe(true);
    expect(doc.digitalType).toBe('software');
    // Digital products should NOT have ship-from fields
    expect(doc.shipFromCity).toBeFalsy();
    expect(doc.shipFromProvince).toBeFalsy();
  });

  test('T03: Validation — missing required fields returns invalid-argument', async () => {
    const error = await callExpectError('create_product_atomic', {
      productData: {},
      testImageUrls: ['https://picsum.photos/400/400'],
    }, sellerToken);
    expect(error.code).toBe('invalid-argument');
  });

  test('T04: Validation — negative price returns invalid-argument', async () => {
    const error = await callExpectError('create_product_atomic', {
      productData: {
        name: 'Negative Price Product',
        description: 'Should fail',
        price: -5,
        stockQuantity: 10,
        categoryId: '1',
      },
      testImageUrls: ['https://picsum.photos/400/400'],
    }, sellerToken);
    expect(error.code).toBe('invalid-argument');
  });

  test('T05: Buyer cannot create products — permission-denied', async () => {
    const error = await callExpectError('create_product_atomic', {
      productData: {
        name: 'Buyer Trying Product',
        description: 'Should fail',
        price: 10,
        stockQuantity: 5,
        categoryId: '1',
      },
      testImageUrls: ['https://picsum.photos/400/400'],
    }, buyerToken);
    expect(error.code).toBe('permission-denied');
  });

  test('T06: Duplicate SKU rejected', async () => {
    const skuVal = `sku-dup-test-${uid()}`;
    // Create first product with SKU (digital to avoid geocoding)
    const result = await callOk('create_product_atomic', {
      productData: {
        name: `SKU Test 1 ${uid()}`,
        description: 'First with this SKU',
        price: 15,
        stockQuantity: 5,
        categoryId: '1',
        sellerSku: skuVal,
        isDigital: true,
        digitalType: 'book',
        bookSourceUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      },
      testImageUrls: ['https://picsum.photos/400/400'],
    }, sellerToken);
    createdProductIds.push(result.productId);

    // Try same SKU again
    const error = await callExpectError('create_product_atomic', {
      productData: {
        name: `SKU Test 2 ${uid()}`,
        description: 'Duplicate SKU',
        price: 20,
        stockQuantity: 3,
        categoryId: '1',
        sellerSku: skuVal,
        isDigital: true,
        digitalType: 'book',
        bookSourceUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      },
      testImageUrls: ['https://picsum.photos/400/400'],
    }, sellerToken);
    // SKU collision should return already-exists or invalid-argument
    expect(['already-exists', 'invalid-argument']).toContain(error.code);
  });

  test('T07: Update product name — verify change in Firestore', async () => {
    const result = await callOk('create_product_atomic', {
      productData: {
        name: `Update Test ${uid()}`,
        description: 'Will be updated',
        price: 12,
        stockQuantity: 8,
        categoryId: '1',
        isDigital: true,
        digitalType: 'book',
        bookSourceUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      },
      testImageUrls: ['https://picsum.photos/400/400'],
    }, sellerToken);
    createdProductIds.push(result.productId);

    const newName = `Updated Product ${uid()}`;
    const updateResult = await callOk('update_product', {
      productId: result.productId,
      productData: { name: newName },
    }, sellerToken);
    expect(updateResult.success).toBe(true);

    const doc = await getDoc(`products/${result.productId}`, sellerToken);
    expect(doc.name).toBe(newName);
  });

  test('T08: Delete product — verify soft delete in Firestore', async () => {
    const result = await callOk('create_product_atomic', {
      productData: {
        name: `Delete Test ${uid()}`,
        description: 'Will be deleted',
        price: 5,
        stockQuantity: 1,
        categoryId: '1',
        isDigital: true,
        digitalType: 'book',
        bookSourceUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      },
      testImageUrls: ['https://picsum.photos/400/400'],
    }, sellerToken);
    // Don't add to cleanup — we're deleting it here

    const delResult = await callOk('delete_product', {
      productId: result.productId,
    }, sellerToken);
    expect(delResult.success).toBe(true);

    const doc = await getDoc(`products/${result.productId}`, sellerToken);
    expect(doc.lifecycleStatus).toBe('archived');
  });

  test('T09: Admin approve product — verify lifecycleStatus=active', async () => {
    const result = await callOk('create_product_atomic', {
      productData: {
        name: `Approve Test ${uid()}`,
        description: 'Will be approved by admin',
        price: 25,
        stockQuantity: 20,
        categoryId: '1',
        isDigital: true,
        digitalType: 'book',
        bookSourceUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      },
      testImageUrls: ['https://picsum.photos/400/400'],
    }, sellerToken);
    createdProductIds.push(result.productId);

    // Verify it starts as under_review
    let doc = await getDoc(`products/${result.productId}`, sellerToken);
    expect(doc.lifecycleStatus).toBe('under_review');

    // Admin approves
    const approveResult = await callOk('admin_approve_product', {
      productId: result.productId,
    }, adminToken);
    expect(approveResult.success).toBe(true);

    // Verify approved
    doc = await getDoc(`products/${result.productId}`, adminToken);
    expect(doc.lifecycleStatus).toBe('active');
  });
});

// ═══ UI-DRIVEN TESTS (browser required) ═══

test.describe('Add Product — UI Tests', () => {
  test.setTimeout(300_000);

  test.beforeEach(async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);
    await ensureLoggedInAsAdmin(page, TARGET_URL, ADMIN_EMAIL, ADMIN_PASSWORD);
    const addProductBtn = page.getByRole('button', { name: BTN_ADD_PRODUCT }).first();
    await expect(addProductBtn).toBeAttached({ timeout: 30_000 });
    await addProductBtn.click();
    await expect(page).toHaveURL(/\/add-product/i, { timeout: 30_000 });
    await waitForFlutter(page);
  });

  test.afterEach(async ({ page }, testInfo) => {
    await screenshotOnFailure(page, testInfo);
    try {
      await navigateHome(page, TARGET_URL);
      await performSignOut(page, TARGET_URL);
    } catch {}
  });

  test('T10: UI — Fill form and attempt publish', async ({ page }) => {
    // Fill Product Name — use keyboard.type for Flutter Web (not pressSequentially)
    const nameInput = page.getByRole('textbox', { name: /product name/i }).first();
    await nameInput.click();
    await page.waitForTimeout(800);
    await page.keyboard.type(`E2E UI Product ${uid()}`, { delay: 30 });

    // Fill Description
    const descInput = page.getByRole('textbox', { name: /^description$/i }).first();
    await descInput.click();
    await page.waitForTimeout(800);
    await page.keyboard.type('E2E test product created via UI', { delay: 30 });

    // Fill Price
    const priceInput = page.getByRole('textbox', { name: /price \(cad\)|prix/i }).first();
    await priceInput.click();
    await page.waitForTimeout(800);
    await page.keyboard.type('24.99', { delay: 30 });

    // Fill Stock
    const stockInput = page.getByRole('textbox', { name: /^stock$/i }).first();
    await stockInput.click();
    await page.waitForTimeout(800);
    await page.keyboard.type('15', { delay: 30 });

    // Verify inputs accepted values — use toHaveValue() for retry logic (DOM sync delay)
    await expect(nameInput).toHaveValue(/E2E UI Product/);
    await expect(priceInput).toHaveValue(/24\.99/);
    await expect(stockInput).toHaveValue(/15/);

    // Select category
    const categorySelector = page.getByRole('button', { name: /category|catégorie/i }).first();
    if (await categorySelector.isVisible({ timeout: 5000 }).catch(() => false)) {
      await categorySelector.click();
      await page.waitForTimeout(2000);
      // [LK-1] category options use aria-label on role="group" — safe to use locator here
      // But also try getByText as fallback for deployed builds without semantic labels
      const categoryOption = page.getByRole('option', { name: /category-option-1/i }).first();
      const catText = page.getByText(/electronics|électronique/i).first();
      const catLabel = page.locator('[aria-label="category-option-1"]').first();
      if (await categoryOption.isVisible({ timeout: 3000 }).catch(() => false)) {
        await categoryOption.click();
      } else if (await catLabel.isVisible({ timeout: 3000 }).catch(() => false)) {
        await catLabel.click();
      } else if (await catText.isVisible({ timeout: 3000 }).catch(() => false)) {
        await catText.click();
      } else {
        await page.keyboard.press('Escape');
      }
    }

    // Scroll to bottom and click publish
    await scrollToBottom(page);
    const publishBtn = getPublishBtn(page);
    await expect(publishBtn).toBeVisible({ timeout: 10_000 });
    await publishBtn.click();
    await page.waitForTimeout(3000);

    // Check outcome: success snackbar OR navigation away OR stayed (validation failed)
    const successSnackbar = page.getByText(/product.*created|produit.*créé|success/i).first();
    const snackbarVisible = await successSnackbar.isVisible({ timeout: 5000 }).catch(() => false);
    const currentUrl = page.url();
    // At least one meaningful outcome must be true:
    // 1. Success snackbar appeared
    // 2. Navigated away from add-product (published successfully)
    // 3. Stayed on add-product (validation caught missing fields like address/images)
    // Without uploading images, validation should keep us on form OR snackbar appears
    if (snackbarVisible) {
      // Product was created — navigated away from add-product
      expect(currentUrl).not.toMatch(/\/add-product/i);
    } else {
      // Validation prevented submission — stayed on add-product page
      expect(currentUrl).toMatch(/\/add-product/i);
    }
  });

  test('T11: UI — Form validation prevents empty submission', async ({ page }) => {
    // Try to publish without filling any fields
    await scrollToBottom(page);
    const publishBtn = getPublishBtn(page);
    await expect(publishBtn).toBeVisible({ timeout: 10_000 });
    await publishBtn.click();
    await page.waitForTimeout(1000);
    // Should stay on add-product page (validation prevents navigation)
    await expect(page).toHaveURL(/\/add-product/i, { timeout: 5000 });
  });

  test('T12: UI — Form state resets on navigation', async ({ page }) => {
    const nameInput = page.getByRole('textbox', { name: /product name/i }).first();
    await nameInput.click();
    await nameInput.pressSequentially('Temporary Product', { delay: 30 });

    // Navigate away via in-app navigation (NOT page.goto)
    await navigateHome(page, TARGET_URL);
    await waitForFlutter(page);

    // Return to add product
    const addProductBtn = page.getByRole('button', { name: BTN_ADD_PRODUCT }).first();
    await expect(addProductBtn).toBeVisible({ timeout: 20_000 });
    await addProductBtn.click();
    await waitForFlutter(page);

    // Verify form is empty
    const nameInputNew = page.getByRole('textbox', { name: /product name/i }).first();
    expect(await nameInputNew.inputValue()).toBe('');
  });
});
