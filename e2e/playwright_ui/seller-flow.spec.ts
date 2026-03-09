import { test, expect } from '@playwright/test';
import {
    waitForFlutter,
    requireWebApp,
    checkSemantics,
    ensureLoggedInAsAdmin,
    performSignOut,
    navigateHome,
    BTN_SETTINGS_LABEL,
    BTN_CART,
    BTN_ADD_PRODUCT,
} from './flutter-helpers';

/**
 * REPLICA of integration_test/flows/seller_flow_test.dart
 */

const TARGET_URL = process.env.E2E_TARGET_URL ?? 'https://orignagta-dev.web.app';
const SELLER_EMAIL = process.env.E2E_SELLER_EMAIL ?? 'yuniorrodriguezo4601@yahoo.com';
const SELLER_PASSWORD = process.env.E2E_SELLER_PASSWORD ?? 'REDACTED_TEST_PASSWORD';

test.describe('PW IT Replica — Seller Flow', () => {
    test.setTimeout(300_000);

    test('Complete Seller Journey', async ({ page }) => {
        const homeSettingsBtn = () => page.getByRole('button', { name: BTN_SETTINGS_LABEL }).first();
        const openProfile = async () => {
            await navigateHome(page, TARGET_URL);
            const settings = homeSettingsBtn();
            await expect(settings).toBeVisible({ timeout: 20_000 });
            await settings.click();
            await expect(page).toHaveURL(/\/profile/i, { timeout: 20_000 });
            await waitForFlutter(page);
        };

        await requireWebApp(page, TARGET_URL);
        page.setDefaultTimeout(60_000);

        await page.goto(`${TARGET_URL}/`);
        await waitForFlutter(page);
        await checkSemantics(page);

        // C01: Login as seller (returns on home page)
        await ensureLoggedInAsAdmin(page, TARGET_URL, SELLER_EMAIL, SELLER_PASSWORD);

        await navigateHome(page, TARGET_URL);
        await expect(homeSettingsBtn()).toBeVisible({ timeout: 20_000 });

        // C034/C035: Add product button visible and navigates to /add-product
        const addProductBtn = page.getByRole('button', { name: BTN_ADD_PRODUCT }).first();
        await expect(addProductBtn).toBeVisible({ timeout: 20000 });
        await addProductBtn.click();
        await expect(page).toHaveURL(/\/add-product/i, { timeout: 20000 });
        await page.goBack();
        await waitForFlutter(page);
        await navigateHome(page, TARGET_URL);

        // C036-C040: Profile → seller tools
        await openProfile();

        // C038: become-seller button must NOT be visible for a seller
        const becomeSellerBtn = page.locator('[aria-label^="menu-become-seller"]').first();
        const becomeSellerVisible = await becomeSellerBtn.isVisible({ timeout: 3000 }).catch(() => false);
        expect(becomeSellerVisible).toBeFalsy();

        // C037/C039: Seller dashboard
        const dashboardBtn = page.locator('[aria-label^="menu-seller-dashboard"]').first();
        if (await dashboardBtn.isVisible().catch(() => false)) {
            await dashboardBtn.click();
            await expect(page).toHaveURL(/\/seller\/(products|register|dashboard)/i, { timeout: 20000 });
            await page.goBack();
            await waitForFlutter(page);
        }

        // C040: Seller orders
        const ordersBtn = page.locator('[aria-label^="menu-seller-orders"]').first();
        if (await ordersBtn.isVisible().catch(() => false)) {
            await ordersBtn.click();
            await expect(page).toHaveURL(/\/seller\/orders/i, { timeout: 20000 });
            await page.goBack();
            await waitForFlutter(page);
        }

        // C041/C062: Return to home; buyer-side cart still accessible
        await page.goBack();
        await waitForFlutter(page);
        await navigateHome(page, TARGET_URL);
        await expect(homeSettingsBtn()).toBeVisible({ timeout: 20000 });

        const cartBtn = page.getByRole('button', { name: BTN_CART }).first();
        await expect(cartBtn).toBeAttached();

        // C080/C099: Sign-out
        await navigateHome(page, TARGET_URL);
        await performSignOut(page, TARGET_URL);
    });
});
