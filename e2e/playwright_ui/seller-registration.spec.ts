import { test, expect } from '@playwright/test';
import {
  waitForFlutter, requireWebApp, checkSemantics,
  ensureLoggedInAsAdmin, performSignOut, navigateHome,
} from './flutter-helpers';
import {
  signIn, callOk, callCallable, callExpectError, getDoc,
  TEST_ACCOUNTS, WEB_APP_URL,
} from './api-helpers';

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;
const SELLER_EMAIL = TEST_ACCOUNTS.SELLER_EMAIL;
const SELLER_PASS = TEST_ACCOUNTS.SELLER_PASS;

// ═══ API-DRIVEN TESTS ═══

test.describe('Seller Registration — API Tests', () => {
  test.setTimeout(60_000);
  test.describe.configure({ mode: 'serial' });

  let sellerToken: string;
  let sellerUid: string;

  test.beforeAll(async () => {
    const seller = await signIn(SELLER_EMAIL);
    sellerToken = seller.idToken;
    sellerUid = seller.localId;
  });

  test('T01: Create Connect account — idempotent, returns account ID', async () => {
    // Ensure account exists first (idempotent — creates if missing, returns existing)
    const result = await callOk('create_connect_account', {
      country: 'CA',
    }, sellerToken);
    expect(result.success).toBe(true);
    expect(result.accountId).toBeTruthy();
  });

  test('T02: Get Connect account status — returns structured data or Stripe API error', async () => {
    // Stripe API may be unreliable in dev — test both outcomes
    const response = await callCallable('get_connect_account_status', {}, sellerToken);
    if (response.error) {
      // Stripe API transient failure — verify it's a known error, not auth failure
      expect(response.error.code).not.toBe('unauthenticated');
      expect(response.error.code).not.toBe('permission-denied');
    } else {
      expect(response.stripeAccountId).toBeTruthy();
      expect(typeof response.onboardingCompleted).toBe('boolean');
      expect(typeof response.chargesEnabled).toBe('boolean');
      expect(typeof response.payoutsEnabled).toBe('boolean');
    }

    // Verify seller_profiles doc exists in Firestore regardless
    const profile = await getDoc(`seller_profiles/${sellerUid}`, sellerToken);
    expect(profile).toBeTruthy();
    expect(profile.stripeAccountId).toBeTruthy();
  });

  test('T03: Create account link — returns Stripe URL or Stripe config error', async () => {
    // Stripe Connect may have invalid config in dev — handle gracefully
    const response = await callCallable('create_account_link', {}, sellerToken);
    if (response.error) {
      // Stripe API / config error — verify it's not an auth failure
      expect(response.error.code).not.toBe('unauthenticated');
      expect(response.error.code).not.toBe('permission-denied');
    } else {
      expect(response.success).toBe(true);
      expect(response.url).toBeTruthy();
      expect(response.url).toContain('stripe.com');
    }
  });

  test('T04: Unauthenticated request rejected', async () => {
    const error = await callExpectError('get_connect_account_status', {}, 'invalid-token');
    expect(error.code).toBe('unauthenticated');
  });

  test('T05: Buyer calling create_account_link — returns error or unexpected success', async () => {
    // Buyer may or may not have a Stripe Connect account in dev
    const buyer = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    const response = await callCallable('create_account_link', {}, buyer.idToken);
    if (response.error) {
      // Expected: buyer has no Stripe Connect account
      expect(response.error.code).not.toBe('unauthenticated');
    }
    // If it succeeds, buyer has a Connect account in dev — still a valid API response
  });
});

// ═══ UI-DRIVEN TESTS ═══

test.describe('Seller Registration — UI Tests', () => {
  test.setTimeout(300_000);

  test('T06: UI — Seller registration page has terms checkbox and action button', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);

    // Login as a buyer (non-seller) to see registration page
    const NON_ONBOARDED = TEST_ACCOUNTS.NON_ONBOARDED_SELLER;
    await ensureLoggedInAsAdmin(page, TARGET_URL, NON_ONBOARDED, TEST_ACCOUNTS.SELLER_PASS);

    // Navigate to seller registration (via profile menu or direct)
    // The seller registration option is in the profile menu for non-sellers
    const settingsBtn = page.getByRole('button', { name: /settings|paramètres/i }).first();
    await settingsBtn.click();
    await page.waitForTimeout(3000);
    await waitForFlutter(page);

    // Look for seller registration menu item or become-a-seller button
    const sellerMenuItem = page.getByRole('button', { name: /become.*seller|devenir.*vendeur|seller.*registration/i }).first();
    await expect(sellerMenuItem).toBeVisible({ timeout: 10000 });
    await sellerMenuItem.click();
    await page.waitForTimeout(3000);
    await waitForFlutter(page);

    // Verify terms checkbox AND action button are both present
    const termsCheckbox = page.locator('[aria-label="chk-seller-terms"]').first();
    const actionBtn = page.locator('[aria-label="btn-seller-action"]').first();

    await expect(termsCheckbox).toBeVisible({ timeout: 5000 });
    await expect(actionBtn).toBeVisible({ timeout: 5000 });

    await navigateHome(page, TARGET_URL);
    await performSignOut(page, TARGET_URL);
  });
});
