import { test, expect } from '@playwright/test';
import {
  waitForFlutter, requireWebApp, checkSemantics,
  ensureLoggedInAsAdmin, performSignOut, navigateHome,
  waitForSemantic,
  BTN_SETTINGS,
} from './flutter-helpers';
import {
  signIn, callOk, callExpectError, getDoc,
  listSubcollection, deleteDoc, uid,
  TEST_ACCOUNTS, WEB_APP_URL, FIRESTORE_BASE,
} from './api-helpers';

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;
const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;
const BUYER_PASS = TEST_ACCOUNTS.BUYER_PASS;

const createdAddressIds: string[] = [];

// ═══ API-DRIVEN TESTS ═══

test.describe('Profile Management — API Tests', () => {
  test.setTimeout(120_000);
  test.describe.configure({ mode: 'serial' });

  let buyerToken: string;
  let buyerUid: string;

  test.beforeAll(async () => {
    const buyer = await signIn(BUYER_EMAIL);
    buyerToken = buyer.idToken;
    buyerUid = buyer.localId;
  });

  test.afterAll(async () => {
    for (const addrId of createdAddressIds) {
      try { await callOk('delete_buyer_address', { addressId: addrId }, buyerToken); } catch {}
    }
  });

  test('T01: Get profile returns user data', async () => {
    const result = await callOk('get_user_profile', {}, buyerToken);
    expect(result.uid).toBe(buyerUid);
    expect(result.email).toBe(BUYER_EMAIL);
    expect(result.name).toBeTruthy();
    expect(result.roles).toBeTruthy();
  });

  test('T02: Update profile name — verify in Firestore', async () => {
    const newName = `E2E Buyer ${uid()}`;
    const result = await callOk('update_user_profile', { name: newName }, buyerToken);
    expect(result.success).toBe(true);

    const doc = await getDoc(`users/${buyerUid}`, buyerToken);
    expect(doc.name).toBe(newName);

    // Restore original name
    await callOk('update_user_profile', { name: 'Test Buyer' }, buyerToken);
  });

  test('T03: Update email consent — verify toggle in Firestore', async () => {
    const result = await callOk('update_email_consent', { emailConsent: true }, buyerToken);
    expect(result.success).toBe(true);
    expect(result.emailConsent).toBe(true);

    const doc = await getDoc(`users/${buyerUid}`, buyerToken);
    expect(doc.emailConsent).toBe(true);

    await callOk('update_email_consent', { emailConsent: false }, buyerToken);
  });

  test('T04: Add first address — auto-default, verify Firestore', async () => {
    // Clean up existing addresses — extract IDs from raw Firestore REST (parseDoc strips IDs)
    const res = await fetch(`${FIRESTORE_BASE}/users/${buyerUid}/addresses`, {
      headers: { 'Authorization': `Bearer ${buyerToken}` },
    });
    if (res.ok) {
      const json = await res.json();
      for (const doc of (json.documents || [])) {
        const addrId = (doc.name as string).split('/').pop()!;
        await callOk('delete_buyer_address', { addressId: addrId }, buyerToken).catch(() => {});
      }
    }

    const result = await callOk('add_buyer_address', {
      street: '100 Test Street',
      city: 'Toronto',
      state: 'ON',
      postalCode: 'M5V 3A8',
      country: 'Canada',
      phoneNumber: '+14165550001',
      label: 'Home',
    }, buyerToken);
    expect(result.success).toBe(true);
    expect(result.addressId).toBeTruthy();
    createdAddressIds.push(result.addressId);

    const doc = await getDoc(`users/${buyerUid}/addresses/${result.addressId}`, buyerToken);
    expect(doc).toBeTruthy();
    expect(doc.city).toBe('Toronto');
    expect(doc.state).toBe('ON');
    expect(doc.isDefault).toBe(true);
  });

  test('T05: Add second address — verify created, check default state', async () => {
    const result = await callOk('add_buyer_address', {
      street: '200 Queen Street',
      city: 'Ottawa',
      state: 'ON',
      postalCode: 'K1A 0A6',
      country: 'Canada',
      phoneNumber: '+16135550002',
      label: 'Work',
    }, buyerToken);
    expect(result.success).toBe(true);
    createdAddressIds.push(result.addressId);

    const doc = await getDoc(`users/${buyerUid}/addresses/${result.addressId}`, buyerToken);
    expect(doc.city).toBe('Ottawa');
    // isDefault not asserted — parallel workers manipulate same buyer's addresses,
    // making addressCount unreliable. T04 covers auto-default, T06 covers set_default.
  });

  test('T06: Set default address — old default cleared', async () => {
    const secondAddrId = createdAddressIds[createdAddressIds.length - 1];
    const result = await callOk('set_default_buyer_address', {
      addressId: secondAddrId,
    }, buyerToken);
    expect(result.success).toBe(true);

    const newDefault = await getDoc(`users/${buyerUid}/addresses/${secondAddrId}`, buyerToken);
    expect(newDefault.isDefault).toBe(true);

    const firstAddrId = createdAddressIds[0];
    const oldDefault = await getDoc(`users/${buyerUid}/addresses/${firstAddrId}`, buyerToken);
    expect(oldDefault.isDefault).toBe(false);
  });

  test('T07: Delete address — doc removed from Firestore', async () => {
    const addrToDelete = createdAddressIds.pop()!;
    const result = await callOk('delete_buyer_address', {
      addressId: addrToDelete,
    }, buyerToken);
    expect(result.success).toBe(true);

    const doc = await getDoc(`users/${buyerUid}/addresses/${addrToDelete}`, buyerToken);
    expect(doc).toBeFalsy();
  });

  test('T08: Non-Canadian address rejected — invalid-argument', async () => {
    const error = await callExpectError('add_buyer_address', {
      street: '1 Main St',
      city: 'New York',
      state: 'NY',
      postalCode: '10001',
      country: 'United States',
      phoneNumber: '+12125550003',
      label: 'Other',
    }, buyerToken);
    expect(error.code).toBe('invalid-argument');
  });
});

// ═══ UI-DRIVEN TESTS ═══

test.describe('Profile Management — UI Tests', () => {
  test.setTimeout(300_000);

  test('T09: UI — Profile page shows menu items', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);
    await ensureLoggedInAsAdmin(page, TARGET_URL, BUYER_EMAIL, BUYER_PASS);

    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
    await expect(settingsBtn).toBeAttached({ timeout: 30000 });
    await settingsBtn.click();
    await expect(page).toHaveURL(/\/profile/i, { timeout: 30000 });
    await waitForFlutter(page);

    // Wait for profile data to load from Firestore and semantic tree to flush.
    // Profile screen fetches user data async — menu items only render after data loads.
    const menuOrders = await waitForSemantic(page, '[aria-label^="menu-my-orders"]', 30000);
    const menuFavorites = await waitForSemantic(page, '[aria-label^="menu-favorites"]', 30000);
    const menuAddress = await waitForSemantic(page, '[aria-label^="menu-address"]', 30000);

    await expect(menuOrders).toBeAttached({ timeout: 10000 });
    await expect(menuFavorites).toBeAttached({ timeout: 10000 });
    await expect(menuAddress).toBeAttached({ timeout: 10000 });

    await navigateHome(page, TARGET_URL);
    await performSignOut(page, TARGET_URL);
  });

  test('T10: UI — Navigate to address management page', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);
    await ensureLoggedInAsAdmin(page, TARGET_URL, BUYER_EMAIL, BUYER_PASS);

    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
    await expect(settingsBtn).toBeAttached({ timeout: 30000 });
    await settingsBtn.click();
    await expect(page).toHaveURL(/\/profile/i, { timeout: 30000 });
    await waitForFlutter(page);

    const menuAddress = await waitForSemantic(page, '[aria-label^="menu-address"]', 30000);
    await expect(menuAddress).toBeAttached({ timeout: 10000 });
    await menuAddress.scrollIntoViewIfNeeded();
    await page.waitForTimeout(1000);
    await menuAddress.click({ force: true });
    await page.waitForTimeout(2000);
    await expect(page).toHaveURL(/\/addresses/i, { timeout: 30000 });
    await waitForFlutter(page);

    const addAddrBtn = page.getByRole('button', { name: /btn-add-address|add address/i }).first();
    await expect(addAddrBtn).toBeAttached({ timeout: 30000 });

    await navigateHome(page, TARGET_URL);
    await performSignOut(page, TARGET_URL);
  });

  test('T11: UI — Navigate to orders page', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);
    await ensureLoggedInAsAdmin(page, TARGET_URL, BUYER_EMAIL, BUYER_PASS);

    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
    await expect(settingsBtn).toBeAttached({ timeout: 30000 });
    await settingsBtn.click();
    await expect(page).toHaveURL(/\/profile/i, { timeout: 30000 });
    await waitForFlutter(page);

    const menuOrders = await waitForSemantic(page, '[aria-label^="menu-my-orders"]', 30000);
    await expect(menuOrders).toBeAttached({ timeout: 10000 });
    await menuOrders.scrollIntoViewIfNeeded();
    await page.waitForTimeout(1000);
    await menuOrders.click({ force: true });
    await page.waitForTimeout(2000);
    await expect(page).toHaveURL(/\/orders/i, { timeout: 30000 });

    await navigateHome(page, TARGET_URL);
    await performSignOut(page, TARGET_URL);
  });
});
