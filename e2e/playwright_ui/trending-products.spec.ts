import { test, expect } from '@playwright/test';
import {
    signIn,
    writeDoc,
    toFirestoreFields,
    getDoc,
    callCallable,
    TEST_UIDS,
    TEST_ACCOUNTS,
    WEB_APP_URL,
    DEFAULT_PASS,
    setProductTrending,
    createDummyProduct
} from './api-helpers';
import {
    requireWebApp,
    waitForFlutter,
    ensureLoggedInAsAdmin,
    checkSemantics,
    BTN_SETTINGS
} from './flutter-helpers';

test.describe('Trending Products flows', () => {
    // Serial mode: prevents afterAll (cleanup) from running while the UI test is still in progress.
    // Without this, test 2 (admin, fast) finishes first → afterAll writes status:'canceled' →
    // subscriptionStreamProvider gets corrupted while test 1 (UI, slow) is still running.
    test.describe.configure({ mode: 'serial' });

    let userEmail = TEST_ACCOUNTS.BUYER_EMAIL;
    let userPass = DEFAULT_PASS;
    let userId = TEST_UIDS.BUYER;

    test.beforeEach(async () => {
        // Authenticate once as admin for the data setup
        const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);

        // Force the buyer to be a premium member so they can access the notification preferences
        await writeDoc(`users/${userId}`, toFirestoreFields({
            email: userEmail,
            isPremium: true,
            notifyTrending: false // Start with it off to test toggling
        }), adminAuth.idToken);

        // Also create an active subscription doc so the subscription screen shows the premium view
        const now = new Date();
        const periodEnd = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000); // 30 days from now
        await writeDoc(`subscriptions/${userId}`, toFirestoreFields({
            status: 'active',
            customerId: 'cus_test_e2e',
            subscriptionId: 'sub_test_e2e',
            currentPeriodStart: now,
            currentPeriodEnd: periodEnd,
            cancelAtPeriodEnd: false,
        }), adminAuth.idToken, false);
    });

    test.afterAll(async () => {
        const adminAuth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
        // Reset buyer premium state to avoid polluting subsequent test suites
        await writeDoc(`users/${userId}`, toFirestoreFields({ isPremium: false }), adminAuth.idToken, true);
        await writeDoc(`subscriptions/${userId}`, toFirestoreFields({ status: 'canceled' }), adminAuth.idToken, false);
    });

    test('Premium user can toggle Trending Products notifications', async ({ page }) => {
        // 1. Ensure target URL is reachable
        await requireWebApp(page, WEB_APP_URL);
        page.setDefaultTimeout(60_000);

        // Get tokens for API calls
        const adminToken = (await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS)).idToken;
        const buyerAuth = await signIn(userEmail, userPass);

        // 2. Load the page and wait for Flutter web initialization
        await page.goto(`${WEB_APP_URL}/`);
        await waitForFlutter(page);
        await checkSemantics(page);

        // 3. Login using the universal Flutter helper flow
        await ensureLoggedInAsAdmin(page, WEB_APP_URL, userEmail, userPass);

        // 4. Open Profile
        const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS }).first();
        await settingsBtn.click();
        await expect(page).toHaveURL(/\/profile/i, { timeout: 20000 });
        await waitForFlutter(page);

        // 5. Go to Premium Subscription using the semantics label.
        // First visit: allows Firestore to fetch server data and update IndexedDB cache.
        // subscriptionStreamProvider (autoDispose) creates a fresh stream on each mount.
        // On first mount the IndexedDB cache may be stale/empty → non-premium. We let Firestore
        // sync for 8s, then navigate away, then come back. Second mount uses the cached
        // 'active' value as the FIRST emission → isPremium=true immediately.
        const premiumBtn = page.getByRole('button', { name: /menu-premium/i }).first();
        await premiumBtn.click();
        await expect(page).toHaveURL(/\/subscription/i, { timeout: 20000 });
        await waitForFlutter(page);
        // Let Firestore establish connection and cache the server value in IndexedDB
        await page.waitForTimeout(8_000);
        // Navigate back to profile (disposes subscriptionStreamProvider, IndexedDB now has 'active')
        await page.goBack();
        await waitForFlutter(page, 30000);
        // Navigate to subscription again — this time the FIRST emission from IndexedDB = 'active'
        const premiumBtn2 = page.getByRole('button', { name: /menu-premium/i }).first();
        await premiumBtn2.click();
        await expect(page).toHaveURL(/\/subscription/i, { timeout: 20000 });
        await waitForFlutter(page);

        // 6. Verify premium UI shows the notification prefs (switch is visible → isPremium=true).
        // Flutter Web: Semantics(label: 'switch-notify-trending') creates an flt-semantics node
        // with aria-label. The inner Switch.adaptive creates a child flt-semantics with role="switch"
        // and aria-checked. getByRole('switch', { name }) fails because the label and role are on
        // separate DOM nodes. Use the inner [role="switch"] descendant of the labelled container.
        //
        // The switch is below the fold — scroll progressively until it appears in Flutter's
        // accessibility tree (Flutter only adds off-screen Semantics nodes when scrolled into view).
        // Flutter merges the Semantics label and Switch role onto the SAME DOM element.
        // Selector: [role="switch"][aria-label^="switch-notify-trending"] (same element, not descendant)
        const trendingSwitch = page.locator('[role="switch"][aria-label^="switch-notify-trending"]').first();
        let switchFound = false;
        for (let i = 0; i < 25 && !switchFound; i++) {
            await page.mouse.wheel(0, 200);
            await page.waitForTimeout(1_200);
            switchFound = await trendingSwitch.isVisible({ timeout: 300 }).catch(() => false);
        }
        await expect(trendingSwitch).toBeVisible({ timeout: 5_000 });
        // Verify it starts unchecked (notifyTrending: false from beforeEach)
        await expect(trendingSwitch).toHaveAttribute('aria-checked', 'false');

        // 7. Toggle via Cloud Function (buyer token) — verifies the full backend E2E path
        const cfResult = await callCallable('update_notification_preferences', { notifyTrending: true }, buyerAuth.idToken);
        expect(cfResult?.result?.success ?? cfResult?.success).toBeTruthy();

        // 8. Verify Firestore reflects the change
        let updatedDoc;
        for (let i = 0; i < 15; i++) {
            updatedDoc = await getDoc(`users/${userId}`, adminToken);
            if (updatedDoc?.notifyTrending === true) break;
            await page.waitForTimeout(1000);
        }
        expect(updatedDoc?.notifyTrending).toBe(true);
    });

    test('Admin can mark a product as trending programmatically', async () => {
        const adminToken = (await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS)).idToken;
        const testProduct = await createDummyProduct(TEST_UIDS.ADMIN, 'TREND');

        await setProductTrending(testProduct.id, true, adminToken);

        const updatedProductDoc = await getDoc(`products/${testProduct.id}`, adminToken);
        expect(updatedProductDoc.isTrending).toBe(true);
        expect(updatedProductDoc.trendingAt).toBeDefined();

        // Cleanup
        await setProductTrending(testProduct.id, false, adminToken);
    });
});
