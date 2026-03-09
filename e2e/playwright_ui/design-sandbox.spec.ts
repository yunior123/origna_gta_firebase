/**
 * design-sandbox.spec.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Visual design sandbox for OrignaGTA Flutter Web.
 *
 * Navigates to every major screen/route, captures full-page screenshots at
 * three viewport widths, and saves them to ~/Desktop/origna-sandbox/.
 *
 * Rules:
 *   - Never fails if a route redirects — it captures whatever is shown.
 *   - Auth routes attempt sign-in first via the in-app flow (no page.goto for
 *     auth screens — Firebase Auth indexedDB state survives only within a
 *     browser session, not across full page reloads).
 *   - 3-second settle wait after each navigation.
 *   - Target runtime: ~5 minutes (serial, single worker).
 *
 * Output:  ~/Desktop/origna-sandbox/{screen}-{width}.png
 *
 * Run:
 *   npx playwright test design-sandbox.spec.ts --config e2e/playwright.config.dev.ts
 */

import { test } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import {
    waitForFlutter,
    requireWebApp,
    ensureLoggedInAsAdmin,
    navigateHome,
    clearServiceWorkers,
} from './flutter-helpers';
import { TEST_ACCOUNTS, WEB_APP_URL } from './api-helpers';

// ─── CONFIG ─────────────────────────────────────────────────────────────────

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;

const SANDBOX_DIR = path.join(os.homedir(), 'Desktop', 'origna-sandbox');

const VIEWPORTS = [
    { name: 'mobile',  width: 375,  height: 812  },
    { name: 'tablet',  width: 768,  height: 1024 },
    { name: 'desktop', width: 1440, height: 900  },
] as const;

/** Settle time (ms) after navigation before taking a screenshot. */
const SETTLE_MS = 3000;

/**
 * All screens to capture.
 * `requireAuth: true` means we must be signed in before navigating there.
 * Navigation strategy is always in-app (via in-app back / forward) to preserve
 * Firebase Auth state — except for public routes where page.goto() is safe
 * because we have not yet established an auth session.
 */
const SCREENS: Array<{
    name: string;
    route: string;
    requireAuth: boolean;
    /** Optional in-app navigation helper; called instead of page.goto() when auth is active. */
    inAppNav?: 'settings-btn' | 'cart-btn' | 'back-to-home' | 'direct-from-home';
}> = [
    // ── Public ──────────────────────────────────────────────────────────────
    { name: 'home',             route: '/',                requireAuth: false },
    { name: 'login',            route: '/login',           requireAuth: false },
    { name: 'privacy-policy',   route: '/privacy-policy',  requireAuth: false },
    { name: 'terms-of-service', route: '/terms-of-service',requireAuth: false },
    { name: 'categories',       route: '/categories',      requireAuth: false },

    // ── Auth-required ────────────────────────────────────────────────────────
    { name: 'cart',         route: '/cart',         requireAuth: true, inAppNav: 'cart-btn'     },
    { name: 'profile',      route: '/profile',      requireAuth: true, inAppNav: 'settings-btn' },
    { name: 'orders',       route: '/orders',       requireAuth: true },
    { name: 'favorites',    route: '/favorites',    requireAuth: true },
    { name: 'subscription', route: '/subscription', requireAuth: true },
    { name: 'addresses',    route: '/addresses',    requireAuth: true },
];

// ─── HELPERS ─────────────────────────────────────────────────────────────────

/** Ensure the sandbox output directory exists. */
function ensureSandboxDir(): void {
    if (!fs.existsSync(SANDBOX_DIR)) {
        fs.mkdirSync(SANDBOX_DIR, { recursive: true });
    }
}

/** Collect and print a summary of failed screens at the end. */
const failures: Array<{ screen: string; viewport: string; reason: string }> = [];

function recordFailure(screen: string, viewport: string, reason: string): void {
    failures.push({ screen, viewport, reason });
    console.log(`   [FAIL] ${screen} @ ${viewport}: ${reason}`);
}

// ─── TEST ─────────────────────────────────────────────────────────────────────

test.describe('Design Sandbox — Full Visual Capture', () => {
    /**
     * Serial execution: screenshots are viewport-dependent and share a single
     * browser context. Parallel workers cannot share auth state.
     */
    test.describe.configure({ mode: 'serial' });

    test.setTimeout(10 * 60 * 1000); // 10 min safety ceiling

    test('capture all screens at all viewports', async ({ page }) => {
        ensureSandboxDir();

        // ── Preflight: ensure the app is reachable ───────────────────────────
        await requireWebApp(page, TARGET_URL);

        // ── Bootstrap Flutter (first load — full init) ───────────────────────
        await page.goto(`${TARGET_URL}/`);
        await clearServiceWorkers(page);
        await waitForFlutter(page, 120_000);

        // ── Sign in once — auth persists in indexedDB for the session ─────────
        await ensureLoggedInAsAdmin(
            page,
            TARGET_URL,
            TEST_ACCOUNTS.ADMIN_EMAIL,
            TEST_ACCOUNTS.ADMIN_PASS,
        );

        // ── Iterate screens ──────────────────────────────────────────────────
        for (const screen of SCREENS) {
            console.log(`\n── Screen: ${screen.name} (${screen.route}) ──`);

            for (const vp of VIEWPORTS) {
                // Set viewport before navigation so Flutter renders at the right size
                await page.setViewportSize({ width: vp.width, height: vp.height });

                try {
                    await captureScreen(page, screen, vp.name, vp.width);
                } catch (err) {
                    recordFailure(screen.name, vp.name, String(err));
                }
            }

            // Reset to a desktop-ish viewport between screens to avoid
            // Flutter layout state leaking across subsequent in-app navigations
            await page.setViewportSize({ width: 1440, height: 900 });
        }

        // ── Summary ──────────────────────────────────────────────────────────
        console.log('\n════ Design Sandbox Complete ════');
        console.log(`Screenshots saved to: ${SANDBOX_DIR}`);
        if (failures.length === 0) {
            console.log('All screens captured successfully.');
        } else {
            console.log(`\n${failures.length} screen(s) failed to capture:`);
            for (const f of failures) {
                console.log(`  - ${f.screen} @ ${f.viewport}: ${f.reason}`);
            }
        }
        // NOTE: test does not throw on failures — sandbox is diagnostic, not a
        // pass/fail gate. Adjust if you want hard failures.
    });
});

// ─── CAPTURE HELPER ──────────────────────────────────────────────────────────

/**
 * Navigate to a single screen + viewport and save a screenshot.
 * Never throws on redirect — captures whatever the app shows.
 */
async function captureScreen(
    page: import('@playwright/test').Page,
    screen: (typeof SCREENS)[number],
    vpName: string,
    vpWidth: number,
): Promise<void> {
    const label = `${screen.name}-${vpName}-${vpWidth}`;
    const outputPath = path.join(SANDBOX_DIR, `${screen.name}-${vpName}.png`);

    console.log(`   [${vpName}] navigating...`);

    // ── Navigate ─────────────────────────────────────────────────────────────
    if (screen.inAppNav === 'settings-btn') {
        // Navigate to /profile via the settings button (preserves auth)
        await navigateHome(page, TARGET_URL);
        await waitForFlutter(page, 30_000);
        const settingsBtn = page.getByRole('button', { name: 'btn-home-settings' }).first();
        await settingsBtn.waitFor({ state: 'attached', timeout: 15_000 }).catch(() => {});
        await settingsBtn.click().catch(() => {});
        await page.waitForURL(/\/profile/i, { timeout: 15_000 }).catch(() => {});

    } else if (screen.inAppNav === 'cart-btn') {
        // Navigate to /cart via the cart button on home (preserves auth)
        await navigateHome(page, TARGET_URL);
        await waitForFlutter(page, 30_000);
        const cartBtn = page.getByRole('button', { name: /cart|shopping|panier/i }).first();
        await cartBtn.waitFor({ state: 'attached', timeout: 15_000 }).catch(() => {});
        await cartBtn.click().catch(() => {});
        await page.waitForURL(/\/cart/i, { timeout: 15_000 }).catch(() => {});

    } else if (screen.requireAuth) {
        // Auth route without a dedicated in-app nav helper:
        // Use page.goto() — auth is already persisted in indexedDB, so a direct
        // navigation will work as long as Flutter picks up the stored token.
        // The app may redirect to /login for routes it guards — that's fine,
        // we just capture what's shown.
        await page.goto(`${TARGET_URL}${screen.route}`, { waitUntil: 'commit' });
        await waitForFlutter(page, 60_000);

    } else {
        // Public route — safe to use page.goto() directly.
        // NOTE: after a public goto(), Firebase Auth state may be lost.
        // We only do this for screens that appear before auth is needed.
        await page.goto(`${TARGET_URL}${screen.route}`, { waitUntil: 'commit' });
        await waitForFlutter(page, 60_000);
    }

    // ── Settle ───────────────────────────────────────────────────────────────
    await page.waitForTimeout(SETTLE_MS);

    // ── Activate Flutter semantics (no-op if already active) ─────────────────
    const semCount = await page.locator('flt-semantics').count();
    if (semCount === 0) {
        const placeholder = page.locator('flt-semantics-placeholder');
        if ((await placeholder.count()) > 0) {
            await placeholder.first().click({ force: true }).catch(() => {});
        }
        await page.keyboard.press('Tab');
        await page.locator('flt-semantics').first()
            .waitFor({ state: 'attached', timeout: 10_000 })
            .catch(() => {});
    }

    // ── Current URL after potential redirect ─────────────────────────────────
    const finalUrl = page.url();
    const redirected = !finalUrl.endsWith(screen.route) && !finalUrl.includes(screen.route);
    if (redirected) {
        console.log(`   [${vpName}] redirected → ${finalUrl} (capturing as-is)`);
    }

    // ── Screenshot ───────────────────────────────────────────────────────────
    await page.screenshot({
        path: outputPath,
        fullPage: true,
        animations: 'disabled',
    });

    console.log(`   [${vpName}] saved → ${outputPath}`);
}
