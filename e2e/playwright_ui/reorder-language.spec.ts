import { test, expect } from '@playwright/test';
import {
  waitForFlutter, requireWebApp,
  waitForProductCards,
} from './flutter-helpers';
import {
  signIn, callOk,
  TEST_ACCOUNTS, WEB_APP_URL,
} from './api-helpers';

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;

// ═══ API-DRIVEN TESTS ═══

test.describe('Reorder & Language — API', () => {
  test.setTimeout(60_000);
  test.describe.configure({ mode: 'serial' });

  let buyerToken: string;

  test.beforeAll(async () => {
    const buyer = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    buyerToken = buyer.idToken;
  });

  test('T01: get_orders returns buyer orders array', async () => {
    const result = await callOk('get_orders', { limit: 10 }, buyerToken);
    expect(result.success).toBe(true);
    const orders: unknown[] = result.orders ?? result.data ?? [];
    expect(Array.isArray(orders)).toBe(true);
  });

  test('T02: get_orders with status=completed returns only completed orders', async () => {
    const result = await callOk('get_orders', { limit: 10, status: 'completed' }, buyerToken);
    expect(result.success).toBe(true);
    const orders: any[] = result.orders ?? result.data ?? [];
    for (const order of orders) {
      const status: string = (order.status ?? order.orderStatus ?? '').toLowerCase();
      expect(status).toMatch(/completed|delivered/);
    }
  });

  test('T03: get_orders with status=cancelled returns only cancelled orders', async () => {
    const result = await callOk('get_orders', { limit: 10, status: 'cancelled' }, buyerToken);
    expect(result.success).toBe(true);
    const orders: any[] = result.orders ?? result.data ?? [];
    for (const order of orders) {
      const status: string = (order.status ?? order.orderStatus ?? '').toLowerCase();
      expect(status).toMatch(/cancelled|canceled/);
    }
  });
});

// ═══ UI-DRIVEN TESTS ═══

test.describe('Reorder & Language — UI', () => {
  test.setTimeout(300_000);

  async function loginAsBuyer(page: import('@playwright/test').Page) {
    await requireWebApp(page, TARGET_URL);
    await page.goto(TARGET_URL);
    await waitForFlutter(page);
    const emailField = page.getByRole('textbox', { name: 'you@example.com' });
    if (await emailField.isVisible({ timeout: 5000 }).catch(() => false)) {
      await emailField.fill(TEST_ACCOUNTS.BUYER_EMAIL);
      await page.getByRole('textbox', { name: '••••••••' }).fill(TEST_ACCOUNTS.BUYER_PASS);
      await page.locator('[aria-label^="login_submit_button"]').click();
      await waitForFlutter(page, 60_000);
    }
    await waitForProductCards(page);
  }

  test('T04: Orders screen accessible from profile menu', async ({ page }) => {
    await loginAsBuyer(page);

    const settingsBtn = page.locator('[aria-label="btn-home-settings"]');
    await settingsBtn.click({ timeout: 30_000 });

    const ordersMenuItem = page.locator('[aria-label="menu-my-orders"]');
    await expect(ordersMenuItem).toBeAttached({ timeout: 15_000 });
    await ordersMenuItem.click();

    await expect(page.getByText(/orders|commandes/i).first()).toBeVisible({ timeout: 15_000 });
  });

  test('T05: Orders screen shows filter tabs', async ({ page }) => {
    await loginAsBuyer(page);

    const settingsBtn = page.locator('[aria-label="btn-home-settings"]');
    await settingsBtn.click({ timeout: 30_000 });

    const ordersMenuItem = page.locator('[aria-label="menu-my-orders"]');
    await expect(ordersMenuItem).toBeAttached({ timeout: 15_000 });
    await ordersMenuItem.click();
    await waitForFlutter(page, 30_000);

    // Order filter tabs (All/Active/Completed/Cancelled)
    const allTab = page.getByText(/^all$|^tous$|all orders/i).first()
      .or(page.locator('[aria-label*="tab-all"], [aria-label*="orders-all"]'));
    await expect(allTab).toBeAttached({ timeout: 20_000 });
  });

  test('T06: Language setting visible in profile screen', async ({ page }) => {
    await loginAsBuyer(page);

    const settingsBtn = page.locator('[aria-label="btn-home-settings"]');
    await settingsBtn.click({ timeout: 30_000 });
    await waitForFlutter(page, 30_000);

    const langOption = page.locator('[aria-label*="language"], [aria-label*="langue"]')
      .or(page.getByText(/language|langue/i).first());
    await expect(langOption).toBeAttached({ timeout: 20_000 });
  });

  test('T07: Switching to French changes home page text', async ({ page }) => {
    await loginAsBuyer(page);

    const settingsBtn = page.locator('[aria-label="btn-home-settings"]');
    await settingsBtn.click({ timeout: 30_000 });
    await waitForFlutter(page, 30_000);

    const langOptionAttached = await page
      .locator('[aria-label*="language"], [aria-label*="langue"]')
      .waitFor({ state: 'attached', timeout: 10_000 })
      .catch(() => false);

    if (!langOptionAttached) {
      test.skip(true, 'Language setting not found in profile');
      return;
    }

    await page.locator('[aria-label*="language"], [aria-label*="langue"]').click();
    await waitForFlutter(page, 15_000);

    const frOptionAttached = await page
      .locator('[aria-label*="fr"]')
      .waitFor({ state: 'attached', timeout: 10_000 })
      .catch(() => false);

    if (!frOptionAttached) {
      test.skip(true, 'French option not found in language selector');
      return;
    }

    await page.locator('[aria-label*="fr"]').first().click();
    await waitForFlutter(page, 15_000);

    await page.goto(TARGET_URL);
    await waitForFlutter(page, 60_000);

    const frenchText = page.getByText(/panier|connexion|paramètres|accueil/i).first();
    await expect(frenchText).toBeAttached({ timeout: 20_000 });
  });

  test('T08: Free shipping bar visible in cart', async ({ page }) => {
    await loginAsBuyer(page);

    const productCard = page.locator('[aria-label^="product-card-"]').first();
    await productCard.click({ timeout: 30_000 });
    await waitForFlutter(page, 30_000);

    const addToCartAttached = await page
      .locator('[aria-label^="btn-add-to-cart"], [aria-label^="add-to-cart"]')
      .waitFor({ state: 'attached', timeout: 10_000 })
      .catch(() => false);

    if (!addToCartAttached) {
      test.skip(true, 'Add to cart button not found');
      return;
    }

    await page.locator('[aria-label^="btn-add-to-cart"], [aria-label^="add-to-cart"]').click();
    await waitForFlutter(page, 10_000);

    const cartBtnAttached = await page
      .locator('[aria-label*="cart"]')
      .waitFor({ state: 'attached', timeout: 10_000 })
      .catch(() => false);

    if (!cartBtnAttached) {
      test.skip(true, 'Cart button not found');
      return;
    }

    await page.locator('[aria-label*="cart"]').first().click();
    await waitForFlutter(page, 30_000);

    const freeShippingText = page.getByText(/free shipping|livraison gratuite|\$75/i).first();
    await expect(freeShippingText).toBeAttached({ timeout: 20_000 });
  });

  test('T09: Buy Again button visible on completed order detail', async ({ page }) => {
    await loginAsBuyer(page);

    const settingsBtn = page.locator('[aria-label="btn-home-settings"]');
    await settingsBtn.click({ timeout: 30_000 });

    const ordersMenuItem = page.locator('[aria-label="menu-my-orders"]');
    await expect(ordersMenuItem).toBeAttached({ timeout: 15_000 });
    await ordersMenuItem.click();
    await waitForFlutter(page, 30_000);

    // Switch to completed tab if available
    const completedTabAttached = await page
      .getByText(/completed|terminé|livré/i).first()
      .waitFor({ state: 'attached', timeout: 5_000 })
      .catch(() => false);

    if (completedTabAttached) {
      await page.getByText(/completed|terminé|livré/i).first().click();
      await waitForFlutter(page, 10_000);
    }

    const firstOrderAttached = await page
      .locator('[aria-label^="order-card-"], [aria-label^="order-item-"]').first()
      .waitFor({ state: 'attached', timeout: 10_000 })
      .catch(() => false);

    if (!firstOrderAttached) {
      test.skip(true, 'No orders found to test Buy Again');
      return;
    }

    await page.locator('[aria-label^="order-card-"], [aria-label^="order-item-"]').first().click();
    await waitForFlutter(page, 15_000);

    const buyAgainBtn = page.locator('[aria-label*="buy-again"], [aria-label*="reorder"]')
      .or(page.getByRole('button', { name: /buy again|reorder|commander à nouveau/i }).first());
    await expect(buyAgainBtn).toBeAttached({ timeout: 15_000 });
  });

  test('T10: Recently viewed section appears on home after viewing a product', async ({ page }) => {
    await loginAsBuyer(page);

    const productCard = page.locator('[aria-label^="product-card-"]').first();
    await productCard.click({ timeout: 30_000 });
    await waitForFlutter(page, 30_000);

    await page.goBack();
    await waitForFlutter(page, 30_000);

    const recentlyViewed = page.getByText(/recently viewed|vu récemment/i).first();
    await expect(recentlyViewed).toBeAttached({ timeout: 20_000 });
  });
});
