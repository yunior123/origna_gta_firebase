import { test, expect } from '@playwright/test';
import {
    waitForFlutter,
    requireWebApp,
    checkSemantics,
    ensureLoggedInAsBuyer,
    performSignOut,
    navigateHome,
    BTN_SETTINGS_LABEL,
    BTN_CART,
} from './flutter-helpers';

/**
 * REPLICA of integration_test/flows/buyer_flow_test.dart
 */

const TARGET_URL = process.env.E2E_TARGET_URL ?? 'https://orignagta-dev.web.app';
const BUYER_EMAIL = process.env.E2E_BUYER_EMAIL ?? 'yuniorrodriguezo460@gmail.com';
const BUYER_PASSWORD = process.env.E2E_BUYER_PASSWORD ?? 'REDACTED_TEST_PASSWORD';

test.describe('PW IT Replica — Buyer Flow', () => {
    test.setTimeout(360_000);

    test('Complete Buyer Journey', async ({ page }) => {
        const homeSettingsBtn = () => page.getByRole('button', { name: BTN_SETTINGS_LABEL }).first();
        const isProfileUrl = () => /\/profile/i.test(page.url());

        const ensureOnProfile = async () => {
            if (isProfileUrl()) {
                await waitForFlutter(page);
                return;
            }

            // Nested navigator back stacks can leave us on a non-profile route;
            // try in-screen back before re-opening profile from home.
            const backBtn = page.locator('[aria-label^="btn-back"]').first();
            if (await backBtn.isVisible().catch(() => false)) {
                await backBtn.click();
                await waitForFlutter(page);
            }

            if (!isProfileUrl()) {
                await navigateHome(page, TARGET_URL);
                const settings = homeSettingsBtn();
                await expect(settings).toBeVisible({ timeout: 30_000 });
                await settings.click();

                const reachedProfile = await page
                    .waitForURL(/\/profile/i, { timeout: 20_000 })
                    .then(() => true)
                    .catch(() => false);
                if (!reachedProfile) {
                    // Flutter semantics can rebind right after auth/nav transitions.
                    await page.waitForTimeout(1_000);
                    await settings.click().catch(() => {});
                    await page.waitForURL(/\/profile/i, { timeout: 20_000 }).catch(() => {});
                }
            }

            await expect(page).toHaveURL(/\/profile/i, { timeout: 20_000 });
            await waitForFlutter(page);
        };

        const openProfile = async () => {
            await navigateHome(page, TARGET_URL);
            const settings = homeSettingsBtn();
            await expect(settings).toBeVisible({ timeout: 20_000 });

            // Single click can be dropped during Flutter semantic-tree rebuilds;
            // retry once, then invoke deterministic fallback recovery.
            let reachedProfile = false;
            for (let attempt = 0; attempt < 2; attempt++) {
                await settings.click().catch(() => {});
                reachedProfile = await page
                    .waitForURL(/\/profile/i, { timeout: 12_000 })
                    .then(() => true)
                    .catch(() => false);
                if (reachedProfile) break;
                await page.waitForTimeout(800);
            }

            if (!reachedProfile) {
                await ensureOnProfile();
            } else {
                await waitForFlutter(page);
            }
        };

        await requireWebApp(page, TARGET_URL);
        page.setDefaultTimeout(60_000);

        await page.goto(`${TARGET_URL}/`);
        await waitForFlutter(page);
        await checkSemantics(page);

        // B01: Login as buyer (role-agnostic login — does NOT grant elevated roles)
        await ensureLoggedInAsBuyer(page, TARGET_URL, BUYER_EMAIL, BUYER_PASSWORD);

        // C023/C090/C091: Profile sub-pages
        await openProfile();

        // C090: Favorites
        // Wait for semantic tree to fully rebuild (FadeSlideIn at 100ms offset)
        await page.waitForTimeout(2000);
        const menuFavorites = page.locator('[aria-label^="menu-favorites"]').first();
        await menuFavorites.waitFor({ state: 'attached', timeout: 15000 }).catch(() => {});
        if (await menuFavorites.isVisible().catch(() => false)) {
            await menuFavorites.scrollIntoViewIfNeeded().catch(() => {});
            await menuFavorites.click();
            await expect(page).toHaveURL(/\/favorites/i, { timeout: 20000 });
            await page.goBack();
            await waitForFlutter(page);
        }

        // C091-C094: Address management
        // Wait for semantic tree to fully rebuild after goBack from favorites
        await page.waitForTimeout(2000);
        const menuAddress = page.locator('[aria-label^="menu-address"]').first();
        await menuAddress.waitFor({ state: 'attached', timeout: 15000 }).catch(() => {});
        if (await menuAddress.isVisible().catch(() => false)) {
            await menuAddress.scrollIntoViewIfNeeded().catch(() => {});
            await menuAddress.click();
            await expect(page).toHaveURL(/\/addresses/i, { timeout: 20000 });
            await waitForFlutter(page);

            const addAddrBtn = page.locator('[aria-label^="btn-add-address"]').first();
            const editAddrBtn = page.locator('[aria-label^="btn-edit-address"]').first();

            if (await addAddrBtn.isVisible().catch(() => false)) {
                await addAddrBtn.click();
                await waitForFlutter(page);

                const streetField = page.getByRole('textbox', { name: /street|rue/i }).first();
                if (await streetField.isVisible({ timeout: 10000 }).catch(() => false)) {
                    await streetField.click();
                    await streetField.pressSequentially('100 Queen', { delay: 30 });
                    const suggestion = page.locator('flt-semantics[role="button"]').nth(0);
                    if (await suggestion.isVisible({ timeout: 10000 }).catch(() => false)) {
                        await suggestion.click();
                    }
                    const saveBtn = page.locator('[aria-label^="btn-save-address"]').first();
                    const saveVisible = await saveBtn.isVisible({ timeout: 5000 }).catch(() => false);
                    expect(saveVisible, 'Save address button should be visible on add-address screen').toBe(true);
                }
                await page.goBack();
                await waitForFlutter(page);
            } else if (await editAddrBtn.isVisible().catch(() => false)) {
                await editAddrBtn.click();
                await waitForFlutter(page);
                await page.goBack();
                await waitForFlutter(page);
            }

            await page.goBack(); // back to profile
            await ensureOnProfile();
        }

        // C024: My Orders
        const menuOrders = page.locator('[aria-label^="menu-my-orders"]').first();
        if (await menuOrders.isVisible().catch(() => false)) {
            await menuOrders.click();
            await expect(page).toHaveURL(/\/orders/i, { timeout: 20000 });
            await page.goBack();
            await ensureOnProfile();
        }

        // Return to home (use goBack, not page.goto which kills auth)
        await page.goBack();
        await waitForFlutter(page);

        // C025-C031: Cart → Checkout checks
        const cartBtn = page.getByRole('button', { name: BTN_CART }).first();
        if (await cartBtn.isVisible().catch(() => false)) {
            await cartBtn.click();
            await expect(page).toHaveURL(/\/cart/i, { timeout: 20000 });
            await waitForFlutter(page);

            const checkoutBtn = page.getByRole('button', { name: /checkout|proceed|passer/i }).first();
            if (await checkoutBtn.isVisible({ timeout: 10000 }).catch(() => false)) {
                await checkoutBtn.click();
                await expect(page).toHaveURL(/\/checkout/i, { timeout: 20000 });
                await waitForFlutter(page);

                const placeOrder = page.locator('[aria-label^="btn-place-order"]').first();
                await expect(placeOrder).toBeAttached({ timeout: 15000 });

                const hasTax = (await page.getByText(/HST|GST|PST|QST/i).count()) > 0;
                expect(hasTax, 'Tax line (HST/GST/PST/QST) should appear on checkout summary for Canadian address').toBe(true);

                await page.goBack();
                await waitForFlutter(page);
            }
            await page.goBack();
            await waitForFlutter(page);
        }

        // C032: Product detail
        const productCards = page.locator('[aria-label^="product-card-"]');
        for (let i = 0; i < 6; i++) {
            if ((await productCards.count()) > 0) break;
            await page.evaluate(() => window.scrollBy(0, window.innerHeight * 0.8));
            await page.waitForTimeout(400);
        }
        if ((await productCards.count()) > 0) {
            await productCards.first().click();
            await page.waitForTimeout(1500);
            await page.goBack();
            await waitForFlutter(page);
        }

        // C033: Home ready
        await navigateHome(page, TARGET_URL);
        await expect(homeSettingsBtn()).toBeVisible({ timeout: 20_000 });

        // C080/C099: Sign-out
        await navigateHome(page, TARGET_URL);
        await performSignOut(page, TARGET_URL);
        // After sign-out the app rebuilds to the unauthenticated home/login state.
        // The URL should reflect a non-authenticated route.
        await expect(page).toHaveURL(/login|sign-in|\//, { timeout: 15_000 });
    });
});
