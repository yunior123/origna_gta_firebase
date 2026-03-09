/**
 * visual-audit.spec.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Comprehensive visual audit — captures EVERY route at mobile + desktop.
 * Designed for Gemini visual bug detection:
 *   - fullPage: true (captures scrollable content)
 *   - Captures whatever is shown (error screens, redirects, flutter errors)
 *   - No test failures — diagnostic only
 *
 * Output: ~/Desktop/origna-visual-audit/{screen}-{viewport}.png
 *
 * Run:
 *   npx playwright test visual-audit.spec.ts \
 *     --config e2e/playwright.config.dev.ts \
 *     --workers 1
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

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-visual-audit');
const SETTLE_MS = 4000;

const VIEWPORTS = [
    { name: 'mobile',  width: 375,  height: 812  },
    { name: 'desktop', width: 1440, height: 900  },
] as const;

interface Screen {
    name: string;
    route: string;
    requireAuth: boolean;
    /** Extra wait after navigation (ms) for heavier screens */
    extraWait?: number;
}

const SCREENS: Screen[] = [
    // ── PUBLIC ────────────────────────────────────────────────────────────────
    { name: '01-home',             route: '/',                     requireAuth: false },
    { name: '02-login',            route: '/login',                requireAuth: false },
    { name: '03-privacy-policy',   route: '/privacy-policy',       requireAuth: false },
    { name: '04-terms-of-service', route: '/terms-of-service',     requireAuth: false },
    { name: '05-categories',       route: '/categories',           requireAuth: false },
    { name: '06-payment-success',  route: '/payment-success',      requireAuth: false },
    { name: '07-payment-cancel',   route: '/payment-cancel',       requireAuth: false },
    { name: '08-sub-success',      route: '/subscription/success', requireAuth: false },
    { name: '09-sub-cancel',       route: '/subscription/cancel',  requireAuth: false },
    { name: '10-seller-refresh',   route: '/seller/refresh',       requireAuth: false },

    // ── AUTH REQUIRED ─────────────────────────────────────────────────────────
    { name: '11-cart',             route: '/cart',                 requireAuth: true },
    { name: '12-profile',          route: '/profile',              requireAuth: true },
    { name: '13-orders',           route: '/orders',               requireAuth: true },
    { name: '14-favorites',        route: '/favorites',            requireAuth: true },
    { name: '15-subscription',     route: '/subscription',         requireAuth: true },
    { name: '16-addresses',        route: '/addresses',            requireAuth: true },
    { name: '17-address-edit',     route: '/address/edit',         requireAuth: true },
    { name: '18-notifications',    route: '/notifications',        requireAuth: true },
    { name: '19-chat-inbox',       route: '/chat/inbox',           requireAuth: true },
    { name: '20-chat',             route: '/chat',                 requireAuth: true },
    { name: '21-checkout',         route: '/checkout',             requireAuth: true },
    { name: '22-order-success',    route: '/order-success',        requireAuth: true },
    { name: '23-add-product',      route: '/add-product',          requireAuth: true, extraWait: 3000 },
    { name: '24-seller-register',  route: '/seller/register',      requireAuth: true },
    { name: '25-seller-orders',    route: '/seller/orders',        requireAuth: true },
    { name: '26-seller-products',  route: '/seller/products',      requireAuth: true },
    { name: '27-seller-warehouses',route: '/seller/warehouses',    requireAuth: true },
    { name: '28-seller-integration',route: '/seller/integration',  requireAuth: true },
    { name: '29-seller-return',    route: '/seller/return',        requireAuth: true },
    { name: '30-admin',            route: '/admin',                requireAuth: true, extraWait: 3000 },
    { name: '31-shipping-approval',route: '/shipping-approval',    requireAuth: true },
];

function ensureDir(): void {
    if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });
}

test.describe('Visual Audit — All Screens', () => {
    test.describe.configure({ mode: 'serial' });
    test.setTimeout(25 * 60 * 1000); // 25 min ceiling

    test('capture all routes at mobile + desktop (fullPage)', async ({ page }) => {
        ensureDir();

        await requireWebApp(page, TARGET_URL);

        // Bootstrap Flutter
        await page.goto(`${TARGET_URL}/`, { waitUntil: 'commit' });
        await clearServiceWorkers(page);
        await waitForFlutter(page, 120_000);

        // Sign in as admin once — persists in indexedDB
        await ensureLoggedInAsAdmin(
            page,
            TARGET_URL,
            TEST_ACCOUNTS.ADMIN_EMAIL,
            TEST_ACCOUNTS.ADMIN_PASS,
        );

        const results: Array<{ screen: string; vp: string; status: string }> = [];

        for (const screen of SCREENS) {
            for (const vp of VIEWPORTS) {
                await page.setViewportSize({ width: vp.width, height: vp.height });

                const outPath = path.join(OUT_DIR, `${screen.name}-${vp.name}.png`);
                console.log(`\n[${screen.name}] ${vp.name} → ${screen.route}`);

                try {
                    // Navigate
                    await page.goto(`${TARGET_URL}${screen.route}`, {
                        waitUntil: 'commit',
                        timeout: 30_000,
                    });
                    await waitForFlutter(page, 60_000).catch(() => {});
                    await page.waitForTimeout(SETTLE_MS + (screen.extraWait ?? 0));

                    // Trigger lazy content by scrolling to bottom then back to top
                    await page.evaluate(() => {
                        window.scrollTo({ top: document.body.scrollHeight, behavior: 'instant' });
                    }).catch(() => {});
                    await page.waitForTimeout(800);
                    await page.evaluate(() => {
                        window.scrollTo({ top: 0, behavior: 'instant' });
                    }).catch(() => {});
                    await page.waitForTimeout(500);

                    const finalUrl = page.url();
                    const redirected = !finalUrl.includes(screen.route.replace('/', ''));

                    await page.screenshot({
                        path: outPath,
                        fullPage: true,
                        animations: 'disabled',
                    });

                    const status = redirected ? `redirected→${new URL(finalUrl).pathname}` : 'ok';
                    results.push({ screen: screen.name, vp: vp.name, status });
                    console.log(`  ✓ saved (${status})`);
                } catch (err) {
                    // Still capture whatever is on screen even on error
                    await page.screenshot({
                        path: outPath,
                        fullPage: true,
                        animations: 'disabled',
                    }).catch(() => {});
                    results.push({ screen: screen.name, vp: vp.name, status: `ERROR: ${String(err).slice(0, 80)}` });
                    console.log(`  ✗ error (screenshot saved anyway)`);
                }
            }
        }

        // Summary
        console.log('\n══════════════════════════════════');
        console.log(`Visual Audit Complete — ${OUT_DIR}`);
        console.log(`Total: ${results.length} screenshots`);
        const errors = results.filter(r => r.status.startsWith('ERROR'));
        const redirects = results.filter(r => r.status.startsWith('redirect'));
        const ok = results.filter(r => r.status === 'ok');
        console.log(`  OK: ${ok.length}  |  Redirected: ${redirects.length}  |  Errors: ${errors.length}`);
        if (errors.length > 0) {
            console.log('Errors:');
            errors.forEach(e => console.log(`  - ${e.screen} @ ${e.vp}: ${e.status}`));
        }
    });
});
