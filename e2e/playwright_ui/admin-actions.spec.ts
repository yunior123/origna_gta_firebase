/**
 * OrignaGTA — Admin Actions E2E Tests
 * =====================================
 * Tests admin panel operations via UI against dev Firebase.
 */
import { test, expect } from '@playwright/test';
import {
  waitForFlutter,
  requireWebApp,
  checkSemantics,
  ensureLoggedInAsAdmin,
  performSignOut,
  navigateHome,
  BTN_SETTINGS,
} from './flutter-helpers';
import { signIn, callOk, callCallable, TEST_ACCOUNTS, WEB_APP_URL } from './api-helpers';

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;
const ADMIN_EMAIL = process.env.E2E_ADMIN_EMAIL ?? TEST_ACCOUNTS.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? TEST_ACCOUNTS.ADMIN_PASS;

test.describe('Admin Actions', () => {
  test.setTimeout(300_000);

  test('Admin can access admin panel via profile', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);

    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);

    await ensureLoggedInAsAdmin(page, TARGET_URL, ADMIN_EMAIL, ADMIN_PASSWORD);
    // ensureLoggedInAsAdmin already navigates back to home — no page.goto() here

    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
    await settingsBtn.click();
    await expect(page).toHaveURL(/\/profile/i, { timeout: 20000 });
    await waitForFlutter(page);

    const adminMenu = page.getByRole('button', { name: /menu-admin-panel|admin panel/i }).first();
    await adminMenu.scrollIntoViewIfNeeded().catch(() => {});
    await expect(adminMenu).toBeVisible({ timeout: 20000 });
    await adminMenu.click();
    await expect(page).toHaveURL(/\/admin/i, { timeout: 20000 });
    await waitForFlutter(page);

    // Verify admin tabs are visible
    const tabNames = [
      /admin-tab-sellers|sellers/i,
      /admin-tab-users|users/i,
      /admin-tab-orders|orders/i,
    ];
    for (const tabName of tabNames) {
      const tab = page.getByRole('tab', { name: tabName }).or(
        page.getByRole('button', { name: tabName })
      ).first();
      await expect(tab).toBeVisible({ timeout: 15000 });
    }

    await navigateHome(page, TARGET_URL);
    await performSignOut(page, TARGET_URL);
  });

  test('Admin can call admin-only endpoints via API', async () => {
    const auth = await signIn(ADMIN_EMAIL, ADMIN_PASSWORD);
    // admin_update_product_stock is an admin-only endpoint
    const result = await callCallable('admin_update_product_stock', {
      productId: 'nonexistent_test',
      newStock: 10,
    }, auth.idToken);

    // Should either succeed or return a business-logic error (not permission-denied)
    if (result.error) {
      const msg = (result.error.message || '').toLowerCase();
      // Acceptable: product not found, invalid argument — NOT permission-denied
      expect(msg).not.toContain('permission');
      expect(msg).not.toContain('unauthenticated');
    }
  });

  test('Non-admin cannot access admin endpoints', async () => {
    const buyerAuth = await signIn(TEST_ACCOUNTS.BUYER_EMAIL);
    const result = await callCallable('admin_update_product_stock', {
      productId: 'nonexistent_test',
      newStock: 10,
    }, buyerAuth.idToken);

    // Should be rejected — buyer is not admin
    expect(result.error).toBeTruthy();
  });
});
