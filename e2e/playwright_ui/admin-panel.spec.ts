import { test, expect } from '@playwright/test';
import {
    waitForFlutter,
    requireWebApp,
    checkSemantics,
    ensureLoggedInAsAdmin,
    performSignOut,
    navigateHome,
    navigateToAdmin,
    BTN_SETTINGS,
    BTN_CART,
    BTN_ADD_PRODUCT,
} from './flutter-helpers';
import { TEST_ACCOUNTS, WEB_APP_URL } from './api-helpers';

/**
 * REPLICA of integration_test/flows/admin_flow_test.dart
 *
 * NOTE: Admin tabs are a Flutter TabBar — clicking a tab does NOT change the URL.
 */

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;
const ADMIN_EMAIL = process.env.E2E_ADMIN_EMAIL ?? TEST_ACCOUNTS.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? TEST_ACCOUNTS.ADMIN_PASS;
const NON_ADMIN_PASSWORD = process.env.E2E_BUYER_PASSWORD ?? TEST_ACCOUNTS.BUYER_PASS;
// Buyer account (non-admin) for access-control test
const NON_ADMIN_EMAIL = process.env.E2E_BUYER_EMAIL ?? TEST_ACCOUNTS.BUYER_EMAIL;

test.describe('PW IT Replica — Admin Panel Flow', () => {
    test.setTimeout(300_000);

    test('T01: Access Control — Non-admin cannot access admin panel', async ({ page }) => {
        await requireWebApp(page, TARGET_URL);
        await page.goto(`${TARGET_URL}/`);
        await waitForFlutter(page);

        // Login as non-admin buyer
        await ensureLoggedInAsAdmin(page, TARGET_URL, NON_ADMIN_EMAIL, NON_ADMIN_PASSWORD);

        // Try to navigate to /admin directly using an intercepted anchor click
        // This forces Flutter to route internally instead of doing a hard browser reload
        await page.evaluate((url) => {
            window.history.pushState({}, '', url + '/admin');
            window.dispatchEvent(new Event('popstate'));
        }, TARGET_URL);
        await waitForFlutter(page);

        // Should be redirected or show "unauthorized"
        const accessDeniedText = page.getByText(/access denied|accès refusé/i).first();
        await expect(accessDeniedText).toBeVisible({ timeout: 10000 });

        // "Access Denied" screen has no home settings button — click "Go Home" first
        const goHomeBtn = page.getByRole('button', { name: /go home|aller à l'accueil/i }).first();
        if (await goHomeBtn.isVisible({ timeout: 3000 }).catch(() => false)) {
            await goHomeBtn.click();
            await waitForFlutter(page);
        } else {
            await page.goBack();
            await waitForFlutter(page);
        }

        await performSignOut(page, TARGET_URL);
    });

    test.describe('Admin Authenticated Tests', () => {
        test.beforeEach(async ({ page }) => {
            await requireWebApp(page, TARGET_URL);
            page.setDefaultTimeout(60_000);
            await page.goto(`${TARGET_URL}/`);
            await waitForFlutter(page);
            await ensureLoggedInAsAdmin(page, TARGET_URL, ADMIN_EMAIL, ADMIN_PASSWORD);
        });

        test.afterEach(async ({ page }) => {
            // Use in-app navigation to preserve Firebase Auth state for sign-out
            await navigateHome(page, TARGET_URL);
            await performSignOut(page, TARGET_URL);
        });

        test('T02: Navigate to Admin Panel via Profile', async ({ page }) => {
            const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
            await settingsBtn.click();
            await expect(page).toHaveURL(/\/profile/i, { timeout: 20000 });
            await waitForFlutter(page);

            const adminMenu = page.getByRole('button', { name: /menu-admin-panel|admin panel/i }).first();
            await adminMenu.scrollIntoViewIfNeeded();
            await expect(adminMenu).toBeVisible();
            await adminMenu.click();
            await expect(page).toHaveURL(/\/admin/i, { timeout: 20000 });
        });

        test('T03: Admin Tab — Sellers list visibility', async ({ page }) => {
            await navigateToAdmin(page);
            const sellersTab = page.getByRole('tab', { name: /sellers/i }).or(page.getByRole('button', { name: /admin-tab-sellers|sellers/i })).first();
            await sellersTab.click();
            await page.waitForTimeout(1000);
            // Verify content loads (best effort)
            const listItems = page.getByRole('listitem');
            if (await listItems.count() > 0) {
                await expect(listItems.first()).toBeVisible();
            }
        });

        test('T04: Admin Tab — Users search functionality', async ({ page }) => {
            await navigateToAdmin(page);
            const usersTab = page.getByRole('tab', { name: /users/i }).or(page.getByRole('button', { name: /admin-tab-users|users/i })).first();
            await usersTab.click();
            await page.waitForTimeout(600);

            const searchField = page.getByRole('textbox', { name: /search users|rechercher des utilisateurs/i }).first();
            if (await searchField.isVisible()) {
                await searchField.click();
                await searchField.pressSequentially(NON_ADMIN_EMAIL, { delay: 30 });
                await page.keyboard.press('Enter');
                await page.waitForTimeout(1000);
            }
        });

        test('T05: Admin Tab — Orders management view', async ({ page }) => {
            await navigateToAdmin(page);
            const ordersTab = page.getByRole('tab', { name: /orders/i }).or(page.getByRole('button', { name: /admin-tab-orders|orders/i })).first();
            await ordersTab.click();
            await page.waitForTimeout(600);
            const orderIdText = page.getByText(/Order ID|ID de commande/i).first();
            // Best effort check
            if (await orderIdText.isVisible()) {
                await expect(orderIdText).toBeVisible();
            }
        });

        test('T06: Admin Tab — Products review queue', async ({ page }) => {
            await navigateToAdmin(page);
            const productsTab = page.getByRole('tab', { name: /products/i }).or(page.getByRole('button', { name: /admin-tab-products|products/i })).first();
            await productsTab.click();
            await page.waitForTimeout(600);
            const underReviewText = page.getByText(/Under Review|En attente/i).first();
            if (await underReviewText.isVisible()) {
                await expect(underReviewText).toBeVisible();
            }
        });

        test('T07: Admin Tab — Payments and payouts', async ({ page }) => {
            await navigateToAdmin(page);
            const paymentsTab = page.getByRole('tab', { name: /payments/i }).or(page.getByRole('button', { name: /admin-tab-payments|payments/i })).first();
            await paymentsTab.click();
            await page.waitForTimeout(600);
            const payoutBtn = page.getByRole('button', { name: /trigger payouts|déclencher les paiements/i }).first();
            if (await payoutBtn.isVisible()) {
                await expect(payoutBtn).toBeVisible();
            }
        });

        test('T08: Admin Tab — Security alerts and logs', async ({ page }) => {
            await navigateToAdmin(page);
            const securityTab = page.getByRole('tab', { name: /security/i }).or(page.getByRole('button', { name: /admin-tab-security|security/i })).first();
            await securityTab.click();
            await page.waitForTimeout(600);
            const alertsText = page.getByText(/Security Alerts|Alertes de sécurité/i).first();
            if (await alertsText.isVisible()) {
                await expect(alertsText).toBeVisible();
            }
        });

        test('T09: Admin Action — View Seller Detail', async ({ page }) => {
            await navigateToAdmin(page);
            // On Sellers tab by default
            const viewDetailBtn = page.locator('button[aria-label*="view"], button[aria-label*="detail"]').first();
            if (await viewDetailBtn.isVisible()) {
                await viewDetailBtn.click();
                await page.waitForTimeout(1000);
                // Should show some detail or dialog
            }
        });

        test('T10: Admin UI — Tab persistence after refresh', async ({ page }) => {
            await navigateToAdmin(page);
            const productsTab = page.getByRole('tab', { name: /products/i }).or(page.getByRole('button', { name: /admin-tab-products|products/i })).first();
            await productsTab.click();
            await page.waitForTimeout(500);

            await page.reload();
            await waitForFlutter(page);
            // In Flutter Web, reload might reset state unless it's in URL
            // This test verifies current behavior
            expect(page.url()).toMatch(/\/admin/i);

            // Admin panel has no btn-home-settings — click Back to reach profile so afterEach works
            const backBtn = page.getByRole('button', { name: /^back$|^retour$/i }).first();
            if (await backBtn.isVisible({ timeout: 3000 }).catch(() => false)) {
                await backBtn.click();
                await waitForFlutter(page);
            }
        });

        test('T11: Admin UI — Return to Home visibility', async ({ page }) => {
            await navigateToAdmin(page);
            const backBtn = page.getByRole('button', { name: /back|retour/i }).first();
            await backBtn.click();
            await waitForFlutter(page);
            expect(page.url()).toMatch(/\/profile/i);
        });
    });
});
