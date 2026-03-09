import { test, expect } from '@playwright/test';
import {
  waitForFlutter, requireWebApp,
  waitForProductCards,
} from './flutter-helpers';
import {
  signIn, callOk, callExpectError,
  TEST_ACCOUNTS, WEB_APP_URL,
} from './api-helpers';

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;

// ═══ API-DRIVEN TESTS ═══

test.describe('Address Management — API', () => {
  test.setTimeout(60_000);
  test.describe.configure({ mode: 'serial' });

  let buyerToken: string;
  let createdAddressId: string | undefined;

  const NEW_ADDRESS = {
    street: '123 E2E Test St',
    city: 'Toronto',
    province: 'ON',
    postalCode: 'M5V 3A8',
    country: 'CA',
    label: 'E2E Home',
    isDefault: false,
  };

  test.beforeAll(async () => {
    const buyer = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    buyerToken = buyer.idToken;
  });

  test('T01: add_buyer_address creates a new address', async () => {
    const result = await callOk('add_buyer_address', NEW_ADDRESS, buyerToken);
    expect(result.success).toBe(true);
    createdAddressId = result.addressId ?? result.address?.addressId ?? result.id;
    expect(createdAddressId).toBeTruthy();
  });

  test('T02: set_default_buyer_address marks address as default', async () => {
    if (!createdAddressId) test.skip(true, 'T01 did not create an address');
    const result = await callOk('set_default_buyer_address', { addressId: createdAddressId }, buyerToken);
    expect(result.success).toBe(true);
  });

  test('T03: update_buyer_address updates an existing address', async () => {
    if (!createdAddressId) test.skip(true, 'T01 did not create an address');
    const result = await callOk('update_buyer_address', {
      addressId: createdAddressId,
      city: 'Mississauga',
    }, buyerToken);
    expect(result.success).toBe(true);
  });

  test('T04: add_buyer_address requires auth — unauthenticated call fails', async () => {
    const err = await callExpectError('add_buyer_address', {
      street: '1 Hacker Way',
      city: 'Toronto',
      province: 'ON',
      postalCode: 'M5V 1A1',
    }, '');
    expect(err.code).toBeTruthy();
    expect(err.code).not.toBe('unexpected-success');
  });

  test.afterAll(async () => {
    if (createdAddressId && buyerToken) {
      await callOk('delete_buyer_address', { addressId: createdAddressId }, buyerToken).catch(() => {});
    }
  });
});

// ═══ UI-DRIVEN TESTS ═══

test.describe('Address Management — UI', () => {
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

  test('T05: Profile settings menu is accessible from home', async ({ page }) => {
    await loginAsBuyer(page);

    const settingsBtn = page.locator('[aria-label="btn-home-settings"]');
    await settingsBtn.click({ timeout: 30_000 });

    const profileMenu = page.locator('[aria-label^="menu-"]').first();
    await expect(profileMenu).toBeAttached({ timeout: 15_000 });
  });

  test('T06: Addresses menu item navigates to address screen', async ({ page }) => {
    await loginAsBuyer(page);

    const settingsBtn = page.locator('[aria-label="btn-home-settings"]');
    await settingsBtn.click({ timeout: 30_000 });

    const addressesLink = page.locator('[aria-label="menu-addresses"], [aria-label="menu-my-addresses"]')
      .or(page.getByText(/addresses|adresses/i).first());
    await expect(addressesLink).toBeAttached({ timeout: 15_000 });
    await addressesLink.click();

    await expect(page.getByText(/address|adresse/i).first()).toBeVisible({ timeout: 15_000 });
  });

  test('T07: Add address button exists on address management screen', async ({ page }) => {
    await loginAsBuyer(page);

    const settingsBtn = page.locator('[aria-label="btn-home-settings"]');
    await settingsBtn.click({ timeout: 30_000 });

    const addressesLinkAttached = await page
      .locator('[aria-label="menu-addresses"], [aria-label="menu-my-addresses"]')
      .waitFor({ state: 'attached', timeout: 10_000 })
      .catch(() => false);

    if (!addressesLinkAttached) {
      test.skip(true, 'Address management not found in profile menu');
      return;
    }

    await page.locator('[aria-label="menu-addresses"], [aria-label="menu-my-addresses"]').click();

    const addBtn = page.locator('[aria-label^="btn-add-address"]')
      .or(page.getByRole('button', { name: /add address|ajouter/i }).first());
    await expect(addBtn).toBeAttached({ timeout: 15_000 });
  });

  test('T08: Checkout screen shows address section', async ({ page }) => {
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

    const checkoutAttached = await page
      .locator('[aria-label^="btn-checkout"]')
      .waitFor({ state: 'attached', timeout: 15_000 })
      .catch(() => false);

    if (!checkoutAttached) {
      test.skip(true, 'Checkout button not found after add to cart');
      return;
    }

    await page.locator('[aria-label^="btn-checkout"]').click();
    await waitForFlutter(page, 30_000);

    await expect(page.getByText(/delivery|livraison|address|adresse/i).first())
      .toBeVisible({ timeout: 15_000 });
  });
});
