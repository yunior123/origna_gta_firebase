import { test, expect } from '@playwright/test';
import {
  waitForFlutter, requireWebApp, checkSemantics,
  ensureLoggedInAsAdmin, performSignOut, navigateHome,
  waitForProductCards, waitForSemantic,
  BTN_SETTINGS,
} from './flutter-helpers';
import {
  signIn, callOk, callExpectError, getDoc, deleteDoc,
  TEST_ACCOUNTS, WEB_APP_URL, TEST_PRODUCTS,
} from './api-helpers';

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;
const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;
const PRODUCT_ID = TEST_PRODUCTS.HIGH_STOCK; // product_024

// ═══ API-DRIVEN TESTS ═══

test.describe('Favorites — API Tests', () => {
  test.setTimeout(60_000);
  test.describe.configure({ mode: 'serial' });

  let buyerToken: string;
  let buyerUid: string;

  test.beforeAll(async () => {
    const buyer = await signIn(BUYER_EMAIL);
    buyerToken = buyer.idToken;
    buyerUid = buyer.localId;
    // Cleanup: ensure product is NOT favorited before tests
    await deleteDoc(`users/${buyerUid}/favorites/${PRODUCT_ID}`, buyerToken).catch(() => {});
  });

  test.afterAll(async () => {
    await deleteDoc(`users/${buyerUid}/favorites/${PRODUCT_ID}`, buyerToken).catch(() => {});
  });

  test('T01: Toggle favorite ON via callable — verify Firestore doc created', async () => {
    const result = await callOk('toggle_favorite', { productId: PRODUCT_ID }, buyerToken);
    expect(result.success).toBe(true);
    expect(result.favorited).toBe(true);

    const favDoc = await getDoc(`users/${buyerUid}/favorites/${PRODUCT_ID}`, buyerToken);
    expect(favDoc).toBeTruthy();
  });

  test('T02: Toggle favorite OFF — verify Firestore doc deleted', async () => {
    const result = await callOk('toggle_favorite', { productId: PRODUCT_ID }, buyerToken);
    expect(result.success).toBe(true);
    expect(result.favorited).toBe(false);

    const favDoc = await getDoc(`users/${buyerUid}/favorites/${PRODUCT_ID}`, buyerToken);
    expect(favDoc).toBeFalsy();
  });

  test('T03: Double toggle is consistent — ends in same state', async () => {
    const r1 = await callOk('toggle_favorite', { productId: PRODUCT_ID }, buyerToken);
    expect(r1.favorited).toBe(true);
    const r2 = await callOk('toggle_favorite', { productId: PRODUCT_ID }, buyerToken);
    expect(r2.favorited).toBe(false);
    const favDoc = await getDoc(`users/${buyerUid}/favorites/${PRODUCT_ID}`, buyerToken);
    expect(favDoc).toBeFalsy();
  });

  test('T04: Favorite non-existent product returns not-found', async () => {
    const error = await callExpectError('toggle_favorite', {
      productId: 'nonexistent_product_xyz',
    }, buyerToken);
    expect(error.code).toBe('not-found');
  });

  test('T05: Unauthenticated favorite returns unauthenticated', async () => {
    const error = await callExpectError('toggle_favorite', {
      productId: PRODUCT_ID,
    }, 'invalid-token');
    expect(error.code).toBe('unauthenticated');
  });
});

// ═══ UI-DRIVEN TESTS ═══

test.describe('Favorites — UI Tests', () => {
  test.describe.configure({ timeout: 600_000 });

  test('T06: UI — Favorite toggle on product card updates heart state', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);
    await ensureLoggedInAsAdmin(page, TARGET_URL, BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS);

    // Wait for product cards to load (login gives Firestore time to warm up)
    const count = await waitForProductCards(page, 60000);
    expect(count).toBeGreaterThan(0);

    // [LK-1] btn-favorite-* is on a Semantics(label:) wrapper, not a role="button" —
    // aria-label locator is correct here (not on a button element)
    const favBtn = await waitForSemantic(page, '[aria-label^="btn-favorite-"]', 30000);
    await expect(favBtn).toBeAttached({ timeout: 10000 });
    await favBtn.click({ force: true });
    await page.waitForTimeout(2000);
    // Verify toggle happened — click again to toggle off
    await favBtn.click({ force: true });
    await page.waitForTimeout(1000);

    await navigateHome(page, TARGET_URL);
    await performSignOut(page, TARGET_URL);
  });

  test('T07: UI — Favorites page is accessible from profile menu', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);
    await ensureLoggedInAsAdmin(page, TARGET_URL, BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS);

    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
    await expect(settingsBtn).toBeAttached({ timeout: 30000 });
    await settingsBtn.click();
    await expect(page).toHaveURL(/\/profile/i, { timeout: 30000 });
    await waitForFlutter(page);

    const menuFavorites = await waitForSemantic(page, '[aria-label^="menu-favorites"]', 30000);
    await expect(menuFavorites).toBeAttached({ timeout: 10000 });
    await menuFavorites.scrollIntoViewIfNeeded();
    await page.waitForTimeout(1000);
    await menuFavorites.click({ force: true });
    await expect(page).toHaveURL(/\/favorites/i, { timeout: 30000 });
    await waitForFlutter(page);

    await navigateHome(page, TARGET_URL);
    await performSignOut(page, TARGET_URL);
  });
});
