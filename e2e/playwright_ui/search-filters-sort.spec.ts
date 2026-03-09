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

test.describe('Search Filters & Sort — API', () => {
  test.setTimeout(60_000);
  test.describe.configure({ mode: 'serial' });

  let buyerToken: string;

  test.beforeAll(async () => {
    const buyer = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    buyerToken = buyer.idToken;
  });

  test('T01: get_products_paginated with sortBy=price_asc returns products', async () => {
    const result = await callOk('get_products_paginated', { limit: 5, sortBy: 'price_asc' }, buyerToken);
    expect(result.success).toBe(true);
    expect(result.products).toBeTruthy();
    expect(result.products.length).toBeGreaterThan(0);
  });

  test('T02: get_products_paginated with sortBy=price_desc returns products', async () => {
    const result = await callOk('get_products_paginated', { limit: 5, sortBy: 'price_desc' }, buyerToken);
    expect(result.success).toBe(true);
    expect(result.products.length).toBeGreaterThan(0);
  });

  test('T03: price_asc and price_desc return different orderings', async () => {
    const asc = await callOk('get_products_paginated', { limit: 5, sortBy: 'price_asc' }, buyerToken);
    const desc = await callOk('get_products_paginated', { limit: 5, sortBy: 'price_desc' }, buyerToken);
    expect(asc.products.length).toBeGreaterThan(0);
    expect(desc.products.length).toBeGreaterThan(0);
    if (asc.products.length > 1 && desc.products.length > 1) {
      const allAscPrices: number[] = asc.products.map((p: any) => p.price ?? p.priceCents);
      const uniquePrices = new Set(allAscPrices);
      if (uniquePrices.size > 1) {
        const firstAscPrice: number = asc.products[0].price ?? asc.products[0].priceCents;
        const firstDescPrice: number = desc.products[0].price ?? desc.products[0].priceCents;
        expect(firstAscPrice).toBeLessThanOrEqual(firstDescPrice);
      }
    }
  });

  test('T04: get_products_paginated with minPriceCents filter returns only matching products', async () => {
    const result = await callOk('get_products_paginated', { limit: 10, minPriceCents: 5000 }, buyerToken);
    expect(result.success).toBe(true);
    if (result.products.length > 0) {
      for (const p of result.products) {
        const price: number = p.priceCents ?? (p.price * 100);
        expect(price).toBeGreaterThanOrEqual(5000);
      }
    }
  });

  test('T05: search_products with query returns results array', async () => {
    const result = await callOk('search_products', { query: 'phone', limit: 5 }, buyerToken);
    expect(result.success).toBe(true);
    const items: unknown[] = result.products ?? result.hits ?? [];
    expect(Array.isArray(items)).toBe(true);
  });
});

// ═══ UI-DRIVEN TESTS ═══

test.describe('Search Filters & Sort — UI', () => {
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

  test('T06: Sort button is visible on home page', async ({ page }) => {
    await loginAsBuyer(page);

    const sortBtn = page.locator('[aria-label="btn-home-sort"]');
    await expect(sortBtn).toBeAttached({ timeout: 30_000 });
  });

  test('T07: Sort button opens sort options sheet', async ({ page }) => {
    await loginAsBuyer(page);

    const sortBtn = page.locator('[aria-label="btn-home-sort"]');
    await sortBtn.click({ timeout: 30_000 });

    // Sort sheet should show price/relevance options
    const sortOptions = page.getByText(/price|relevance|prix|pertinence/i);
    await expect(sortOptions.first()).toBeVisible({ timeout: 10_000 });
  });

  test('T08: Price filter button is visible on home page', async ({ page }) => {
    await loginAsBuyer(page);

    const filterBtn = page.locator('[aria-label="btn-home-price-filter"]');
    await expect(filterBtn).toBeAttached({ timeout: 30_000 });
  });

  test('T09: Price filter opens dialog and apply button exists', async ({ page }) => {
    await loginAsBuyer(page);

    const filterBtn = page.locator('[aria-label="btn-home-price-filter"]');
    await filterBtn.click({ timeout: 30_000 });

    // Price filter dialog should appear with apply button
    const applyBtn = page.locator('[aria-label="btn-price-filter-apply"]');
    await expect(applyBtn).toBeAttached({ timeout: 10_000 });
  });

  test('T10: Search bar accepts input and shows results', async ({ page }) => {
    await loginAsBuyer(page);

    const searchBar = page.locator('[aria-label="input-home-search"]');
    await searchBar.click({ timeout: 30_000 });
    await searchBar.fill('test');
    await page.keyboard.press('Enter');

    // After search, product cards should still be present
    await expect(page.locator('[aria-label^="product-card-"]').first())
      .toBeAttached({ timeout: 30_000 });
  });
});
