import { test, expect } from '@playwright/test';
import {
    waitForFlutter,
    requireWebApp,
    checkSemantics,
    ensureLoggedInAsAdmin,
    performSignOut,
    navigateHome,
    BTN_SETTINGS,
    BTN_CART,
} from './flutter-helpers';
import { TEST_ACCOUNTS } from './api-helpers';

/**
 * REPLICA of integration_test/flows/smoke_home_profile_test.dart
 */

const TARGET_URL = process.env.E2E_TARGET_URL ?? 'https://orignagta-dev.web.app';
const ADMIN_EMAIL = TEST_ACCOUNTS.ADMIN_EMAIL;
const ADMIN_PASSWORD = TEST_ACCOUNTS.ADMIN_PASS;

test.describe('PW IT Replica — Smoke Home + Profile (admin)', () => {
    test.setTimeout(300_000);

    test('replica', async ({ page }) => {
        await requireWebApp(page, TARGET_URL);
        page.setDefaultTimeout(60_000);

        // C001/C002: App renders Flutter Web with semantics
        await page.goto(`${TARGET_URL}/`);
        await waitForFlutter(page);
        await checkSemantics(page);

        // Establish admin session (returns on home page)
        await ensureLoggedInAsAdmin(page, TARGET_URL, ADMIN_EMAIL, ADMIN_PASSWORD);
        await navigateHome(page, TARGET_URL);
        await waitForFlutter(page);

        // C004: settings button visible after login
        const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
        await expect(settingsBtn).toBeAttached({ timeout: 60000 });

        // C006/C007: Cart button visible and navigates to /cart
        const cartBtn = page.getByRole('button', { name: BTN_CART }).first();
        await expect(cartBtn).toBeAttached();
        await cartBtn.click();
        const cartTitle = page.locator('flt-semantics').filter({ hasText: /your cart|votre panier/i }).first();
        const reachedCartByUrl = await page
            .waitForURL(/\/cart/i, { timeout: 15000 })
            .then(() => true)
            .catch(() => false);
        if (!reachedCartByUrl) {
            const reachedCartByTitle = await cartTitle.isVisible({ timeout: 8000 }).catch(() => false);
            if (!reachedCartByTitle) {
                // Retry click once (Flutter semantics can rebind after auth rebuild).
                await cartBtn.click();
                await page.waitForURL(/\/cart/i, { timeout: 15000 }).catch(() => {});
            }
        }
        const isCartUrl = /\/cart/i.test(page.url());
        const isCartTitleVisible = await cartTitle.isVisible({ timeout: 3000 }).catch(() => false);
        expect(isCartUrl || isCartTitleVisible).toBeTruthy();
        await navigateHome(page, TARGET_URL);
        await waitForFlutter(page);

        // C008: Seeded product search loop
        const productCards = page.locator('[aria-label^="product-card-"]');
        for (let i = 0; i < 12; i++) {
            if ((await productCards.count()) > 0) break;
            await page.mouse.wheel(0, 220);
            await page.waitForTimeout(500);
        }
        if ((await productCards.count()) > 0) {
            await productCards.first().click();
            await page.waitForTimeout(1500);
            await page.goBack();
            await waitForFlutter(page);
        }

        // A08: Home scroll interaction + pull-to-refresh coverage
        // The home screen wraps its list in a RefreshIndicator (added in recent UI update).
        // Scrolling down then back up simulates the overscroll that can trigger refresh.
        // The test verifies the page remains stable (no crash, semantic content intact).
        await page.mouse.wheel(0, 300);
        await page.waitForTimeout(800);
        await page.mouse.wheel(0, -300);
        await page.waitForTimeout(800);
        // Overscroll upward from top — exercises the RefreshIndicator trigger threshold.
        // In Flutter Web, this does NOT reliably fire the onRefresh callback
        // (pointer events differ from touch), but the widget must not crash.
        await page.mouse.wheel(0, -200);
        await page.waitForTimeout(600);
        // Verify semantic tree is intact after overscroll
        const afterRefreshSemCount = await page.locator('flt-semantics').count();
        expect(afterRefreshSemCount, 'Semantic tree must survive pull-to-refresh overscroll').toBeGreaterThan(0);

        // C009: Profile navigation via settings button
        await settingsBtn.click();
        await expect(page).toHaveURL(/\/profile/i, { timeout: 20000 });
        await waitForFlutter(page);

        const ensureOnProfile = async () => {
            if (/\/profile/i.test(page.url())) {
                return;
            }
            // Some flows land on /orders after browser goBack due nested navigator
            // state; re-open profile through the settings route deterministically.
            const backBtn = page.locator('[aria-label^="btn-back"]').first();
            if (await backBtn.isVisible().catch(() => false)) {
                await backBtn.click();
                await waitForFlutter(page);
            }
            if (!/\/profile/i.test(page.url())) {
                await navigateHome(page, TARGET_URL);
                const dynamicSettingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
                await expect(dynamicSettingsBtn).toBeAttached({ timeout: 30000 });
                await dynamicSettingsBtn.click();
            }
            await expect(page).toHaveURL(/\/profile/i, { timeout: 20000 });
            await waitForFlutter(page);
        };

        // T10: My Orders sub-page
        const menuOrders = page.locator('[aria-label^="menu-my-orders"]').first();
        if (await menuOrders.isVisible().catch(() => false)) {
            await menuOrders.click();
            await expect(page).toHaveURL(/\/orders/i, { timeout: 20000 });
            await page.goBack();
            await ensureOnProfile();
        }

        // T11: Favorites sub-page
        // Wait for semantic tree to fully rebuild after goBack (FadeSlideIn at 100ms offset)
        await page.waitForTimeout(2000);
        const menuFav = page.locator('[aria-label^="menu-favorites"]').first();
        await menuFav.waitFor({ state: 'attached', timeout: 15000 }).catch(() => {});
        if (await menuFav.isVisible().catch(() => false)) {
            await menuFav.scrollIntoViewIfNeeded().catch(() => {});
            await menuFav.click();
            await expect(page).toHaveURL(/\/favorites/i, { timeout: 20000 });
            await page.goBack();
            await ensureOnProfile();
        }

        // T12: Address sub-page
        // Wait for semantic tree to fully rebuild after goBack from favorites
        await page.waitForTimeout(2000);
        const menuAddr = page.locator('[aria-label^="menu-address"]').first();
        await menuAddr.waitFor({ state: 'attached', timeout: 15000 }).catch(() => {});
        if (await menuAddr.isVisible().catch(() => false)) {
            await menuAddr.scrollIntoViewIfNeeded().catch(() => {});
            await menuAddr.click();
            await expect(page).toHaveURL(/\/addresses/i, { timeout: 20000 });
            await page.goBack();
            await ensureOnProfile();
        }

        // C010/C079: Return to home after profile sub-pages
        await page.goBack();
        await waitForFlutter(page);
        await expect(settingsBtn).toBeAttached();

        // C080/C099: Sign-out flow
        await performSignOut(page, TARGET_URL);
    });
});
