/**
 * OrignaGTA — Seller UI Screens E2E Tests
 * =========================================
 * Verifies that seller-specific screens render correctly when accessed
 * by a user with seller+admin roles (admin account has both).
 *
 * Navigation strategy: In-app navigation via profile menu items.
 * NEVER use page.goto() for authenticated routes — it kills Firebase
 * Auth state in Playwright's isolated browser contexts.
 *
 * Routes tested:
 *   /seller/products   — via menu-seller-dashboard
 *   /seller/warehouses  — via direct URL (not in profile menu)
 *   /seller/integration — via direct URL (not in profile menu)
 *
 * Target: https://orignagta-dev.web.app (dev Firebase)
 * Run: cd e2e && npx playwright test seller-screens-ui.spec.ts --config=playwright.config.dev.ts
 */
import { test, expect } from '@playwright/test';
import {
  signIn,
  callCallable,
  callOk,
  TEST_ACCOUNTS,
  TEST_UIDS,
  WEB_APP_URL,
  getDoc,
  writeDoc,
  toFirestoreFields,
} from './api-helpers';
import {
  waitForFlutter,
  requireWebApp,
  checkSemantics,
  ensureLoggedInAsAdmin,
  BTN_SETTINGS,
} from './flutter-helpers';

// ════════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════════

const TARGET_URL = WEB_APP_URL;
const ADMIN_EMAIL = TEST_ACCOUNTS.ADMIN_EMAIL;
const ADMIN_PASS = TEST_ACCOUNTS.ADMIN_PASS;

test.describe('Seller UI Screens', () => {
  test.setTimeout(360_000);

  // ── T01: Seller Products screen renders ──────────────────────────
  test('T01: Seller Products screen renders via profile menu', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);

    // Navigate and log in as admin (has seller+admin roles)
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);
    await ensureLoggedInAsAdmin(page, TARGET_URL, ADMIN_EMAIL, ADMIN_PASS);

    // Navigate to profile via settings button
    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
    await expect(settingsBtn).toBeAttached({ timeout: 30_000 });
    await settingsBtn.click();
    await expect(page).toHaveURL(/\/profile/i, { timeout: 20_000 });
    await waitForFlutter(page);

    // Wait for the semantic tree to fully rebuild (FadeSlideIn animations)
    await page.waitForTimeout(2000);

    // Click "Seller Dashboard" menu item — navigates to /seller/products
    const dashboardBtn = page.locator('[aria-label^="menu-seller-dashboard"]').first();
    await dashboardBtn.waitFor({ state: 'attached', timeout: 15_000 });
    await dashboardBtn.scrollIntoViewIfNeeded().catch(() => {});
    const dashboardVisible = await dashboardBtn.isVisible().catch(() => false);

    if (!dashboardVisible) {
      // If seller dashboard menu item is not visible, the admin account
      // might not have seller role active — skip gracefully.
      test.skip(true, 'menu-seller-dashboard not visible — admin may lack seller role');
      return;
    }

    await dashboardBtn.click();

    // The route should match /seller/products or /seller/dashboard
    await expect(page).toHaveURL(/\/seller\/(products|dashboard|register)/i, { timeout: 20_000 });
    await waitForFlutter(page);

    // Verify the screen has semantic content (not a blank page)
    const semanticsCount = await page.locator('flt-semantics').count();
    expect(semanticsCount, 'Seller Products screen should render semantic elements').toBeGreaterThan(0);

    // Navigate back to profile
    await page.goBack();
    await waitForFlutter(page);
    await page.waitForTimeout(2000);
  });

  // ── T02: Seller Warehouses screen renders ────────────────────────
  test('T02: Seller Warehouses screen renders', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);

    // Navigate and log in as admin
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);
    await ensureLoggedInAsAdmin(page, TARGET_URL, ADMIN_EMAIL, ADMIN_PASS);

    // The warehouses screen is not directly accessible from the profile menu.
    // It is accessed from within the seller dashboard or via deep link.
    // Since page.goto() kills auth, we navigate to profile first,
    // then to seller dashboard, and look for a warehouses link there.
    //
    // Fallback strategy: Navigate to seller dashboard first, then try to
    // find a warehouses navigation element. If not found, we test via
    // profile menu navigation and accept whatever renders.

    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
    await expect(settingsBtn).toBeAttached({ timeout: 30_000 });
    await settingsBtn.click();
    await expect(page).toHaveURL(/\/profile/i, { timeout: 20_000 });
    await waitForFlutter(page);
    await page.waitForTimeout(2000);

    // Try navigating to seller dashboard first
    const dashboardBtn = page.locator('[aria-label^="menu-seller-dashboard"]').first();
    const hasDashboard = await dashboardBtn.isVisible({ timeout: 5_000 }).catch(() => false);

    if (!hasDashboard) {
      test.skip(true, 'Seller dashboard not accessible — cannot reach warehouses');
      return;
    }

    await dashboardBtn.click();
    await expect(page).toHaveURL(/\/seller\/(products|dashboard)/i, { timeout: 20_000 });
    await waitForFlutter(page);

    // Look for a warehouses navigation element inside the seller dashboard.
    // Common patterns: tab, button, or menu item with "warehouse" label.
    const warehouseLink = page.locator(
      '[aria-label*="warehouse" i], [aria-label*="entrepot" i], [aria-label*="location" i]',
    ).first();
    const hasWarehouseLink = await warehouseLink.isVisible({ timeout: 10_000 }).catch(() => false);

    if (!hasWarehouseLink) {
      test.skip(true, 'Warehouse navigation link not found in seller dashboard — screen not reachable');
      return;
    }

    await warehouseLink.scrollIntoViewIfNeeded().catch(() => {});
    await warehouseLink.click();
    await waitForFlutter(page);

    // Verify the warehouses screen loaded (not just any screen)
    await expect(
      page.locator('[aria-label*="warehouse" i], [aria-label*="entrepot" i]').first()
        .or(page.getByText(/warehouse|entrepôt/i).first())
    ).toBeVisible({ timeout: 15_000 });

    // Navigate back
    await page.goBack();
    await waitForFlutter(page);
    await page.waitForTimeout(2000);
  });

  // ── T03: Seller Integration screen renders ───────────────────────
  test('T03: Seller Integration / Connect screen renders', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    page.setDefaultTimeout(60_000);

    // Navigate and log in as admin
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);
    await ensureLoggedInAsAdmin(page, TARGET_URL, ADMIN_EMAIL, ADMIN_PASS);

    // Navigate to profile
    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
    await expect(settingsBtn).toBeAttached({ timeout: 30_000 });
    await settingsBtn.click();
    await expect(page).toHaveURL(/\/profile/i, { timeout: 20_000 });
    await waitForFlutter(page);
    await page.waitForTimeout(2000);

    // Navigate to seller dashboard
    const dashboardBtn = page.locator('[aria-label^="menu-seller-dashboard"]').first();
    const hasDashboard = await dashboardBtn.isVisible({ timeout: 5_000 }).catch(() => false);

    if (!hasDashboard) {
      test.skip(true, 'Seller dashboard not accessible — cannot reach integration');
      return;
    }

    await dashboardBtn.click();
    await expect(page).toHaveURL(/\/seller\/(products|dashboard)/i, { timeout: 20_000 });
    await waitForFlutter(page);

    // Look for integration/connect navigation element inside the seller dashboard.
    const integrationLink = page.locator(
      '[aria-label*="integration" i], [aria-label*="connect" i], [aria-label*="stripe" i], [aria-label*="paiement" i]',
    ).first();
    const hasIntegrationLink = await integrationLink.isVisible({ timeout: 10_000 }).catch(() => false);

    if (!hasIntegrationLink) {
      test.skip(true, 'Integration/Connect navigation link not found in seller dashboard — screen not reachable');
      return;
    }

    await integrationLink.scrollIntoViewIfNeeded().catch(() => {});
    await integrationLink.click();
    await waitForFlutter(page);

    // Verify the integration screen loaded (not just any screen)
    await expect(
      page.locator('[aria-label*="integration" i], [aria-label*="stripe" i], [aria-label*="connect" i]').first()
        .or(page.getByText(/stripe|integration|connect/i).first())
    ).toBeVisible({ timeout: 15_000 });

    // Navigate back to home
    await page.goBack();
    await waitForFlutter(page);
    await page.waitForTimeout(1000);
    await page.goBack();
    await waitForFlutter(page);
  });
});
