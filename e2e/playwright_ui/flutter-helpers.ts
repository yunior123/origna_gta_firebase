/**
 * Flutter Web E2E Test Helpers (Isolated)
 *
 * Bilingual (EN/FR) selector conventions — the app may render in French:
 *  - Home Settings button  → /settings|paramètres/i
 *  - Home Cart button      → /cart|shopping|panier/i
 *  - Home Add Product btn  → /add product|ajouter/i
 *  - Sign-in button        → /sign\s*in|se\s*connecter|connexion/i
 *  - Profile menu items    → locator('[aria-label="menu-my-orders"]') etc.  (language-independent)
 *  - Sign-out              → locator('[aria-label^="btn-sign-out"]')
 *  - Login email           → getByRole('textbox', { name: 'you@example.com' })
 *  - Login password        → getByRole('textbox', { name: '••••••••' })
 *  - Login submit          → locator('[aria-label^="login_submit_button"]')
 *  - Home search bar       → locator('[aria-label="input-home-search"]')
 *  - Product cards         → locator('[aria-label^="product-card-"]')
 *  - Admin tabs            → locator('[aria-label="admin-tab-sellers"]') etc.
 */

import { Page, Locator, test, expect } from '@playwright/test';
import { WEB_APP_URL } from './api-helpers';

// ─── BILINGUAL PATTERNS ────────────────────────────────────────────
const BTN_SETTINGS = /settings|paramètres/i;
// Stable aria-label for the home settings button (language-independent)
const BTN_SETTINGS_LABEL = 'btn-home-settings';
const BTN_SIGN_IN = /sign\s*in|se\s*connecter|connexion/i;
const BTN_CART = /cart|shopping|panier/i;
const BTN_ADD_PRODUCT = /add\s*product|ajouter/i;

export { BTN_SETTINGS, BTN_SETTINGS_LABEL, BTN_SIGN_IN, BTN_CART, BTN_ADD_PRODUCT };

// ─── SERVICE WORKER CLEANUP ────────────────────────────────────────

export async function clearServiceWorkers(page: Page): Promise<void> {
    try {
        await page.evaluate(async () => {
            const regs = await navigator.serviceWorker?.getRegistrations() ?? [];
            for (const reg of regs) await reg.unregister();
            const names = await caches?.keys() ?? [];
            for (const n of names) await caches.delete(n);
        });
    } catch { /* SW not available */ }
}

// ─── FLUTTER INITIALIZATION ─────────────────────────────────────────

export async function waitForFlutter(page: Page, timeout = 180000): Promise<void> {
    const t0 = Date.now();

    // Fast path: if Flutter is already loaded (canvas exists + semantics present),
    // skip all expensive checks. This makes subsequent calls near-instant.
    const isLoaded = await page.evaluate(() => {
        return !!(
            document.querySelector('flt-glass-pane') ||
            document.querySelector('flutter-view') ||
            document.querySelector('canvas')
        );
    });
    const hasSem = await page.locator('flt-semantics').count();
    if (isLoaded && hasSem > 0) {
        // Flutter is fully loaded with semantics — no work needed.
        await page.waitForTimeout(500); // minimal settle
        return;
    }

    // Step 1: Wait for Flutter's rendering host element (first load only).
    if (!isLoaded) {
        await page.waitForFunction(() => {
            const glasspane = document.querySelector('flt-glass-pane');
            const flutterView = document.querySelector('flutter-view');
            const canvas = document.querySelector('canvas');
            return (
                !!glasspane ||
                !!flutterView ||
                (canvas instanceof HTMLCanvasElement && canvas.getBoundingClientRect().width > 0)
            );
        }, { timeout }).catch(() => { });
    }

    // Step 2: Wait for loading indicator — short timeout only.
    // Flutter paints OVER #loading div; it may never get display:none.
    await page.waitForFunction(() => {
        const loading = document.getElementById('loading');
        return !loading || loading.style.display === 'none' || loading.getAttribute('hidden') !== null;
    }, { timeout: 5000 }).catch(() => { });

    // Step 3: Activate semantics if not already active (FORCE_SEMANTICS build skips this).
    if (hasSem === 0) {
        const semanticsTimeout = Math.min(timeout, 15000);

        const enableA11yBtn = page.locator('button:has-text("Enable accessibility")');
        if ((await enableA11yBtn.count()) > 0) {
            await enableA11yBtn.first().click({ force: true }).catch(() => { });
        }

        const placeholder = page.locator('flt-semantics-placeholder');
        await placeholder.first().waitFor({ state: 'attached', timeout: semanticsTimeout }).catch(() => { });
        if ((await placeholder.count()) > 0) {
            await placeholder.first().click({ force: true }).catch(() => { });
        }

        await page.keyboard.press('Tab');

        await page.locator('flt-semantics').first()
            .waitFor({ state: 'attached', timeout: semanticsTimeout })
            .catch(() => {
                console.log('   ⚠️  flt-semantics not found after activation attempts');
            });
    }

    // Settle time for semantic tree flush.
    await page.waitForTimeout(1000);

    const elapsed = Date.now() - t0;
    if (elapsed > 5000) {
        console.log(`   ✅ Flutter ready in ${elapsed}ms`);
    }
}

/**
 * Wait for a specific semantic element to appear after navigation.
 * Flutter Web rebuilds the semantic tree after route changes — this can take
 * several seconds if the new screen loads data from remote Firestore.
 * Returns the locator for further interaction.
 */
export async function waitForSemantic(
    page: Page,
    selector: string,
    timeout = 30000,
): Promise<Locator> {
    const loc = page.locator(selector).first();
    await loc.waitFor({ state: 'attached', timeout }).catch(() => {
        console.log(`   ⚠️  Semantic element not found: ${selector} (waited ${timeout}ms)`);
    });
    return loc;
}

/**
 * Wait for product cards to load from Firestore and appear in the semantic tree.
 * Scrolls to trigger lazy loading and retries multiple times.
 */
export async function waitForProductCards(
    page: Page,
    timeout = 45000,
): Promise<number> {
    const startTime = Date.now();
    const cards = page.locator('[aria-label^="product-card-"]');

    // First, wait for at least one card to appear (Firestore data loading)
    await cards.first().waitFor({ state: 'attached', timeout }).catch(() => {});

    if ((await cards.count()) > 0) return cards.count();

    // If no cards yet, scroll to trigger lazy loading and wait
    for (let i = 0; i < 20; i++) {
        if (Date.now() - startTime > timeout) break;
        await page.mouse.wheel(0, 250);
        await page.waitForTimeout(1500);
        if ((await cards.count()) > 0) return cards.count();
    }

    const finalCount = await cards.count();
    if (finalCount === 0) {
        console.log(`   ⚠️  No product cards found after ${Date.now() - startTime}ms`);
    }
    return finalCount;
}

// ─── REPLICA UTILS ──────────────────────────────────────────────────

export async function requireWebApp(page: Page, targetUrl: string): Promise<void> {
    const res = await page.request.get(`${targetUrl}/`).catch(() => null);
    const status = res?.status();
    if (!status || status < 200 || status >= 400) {
        test.skip(true, `Target not reachable at ${targetUrl} (status: ${status ?? 'ERR'})`);
    }
}

export async function checkSemantics(page: Page): Promise<void> {
    let sems = await page.locator('flt-semantics').count();
    if (sems > 0) return;

    // Retry: try activating semantics one more time before skipping.
    // Sometimes the placeholder needs a second click or Tab press.
    console.log('   ♿ checkSemantics: 0 flt-semantics found, retrying activation...');
    const placeholder = page.locator('flt-semantics-placeholder');
    if ((await placeholder.count()) > 0) {
        await placeholder.first().click({ force: true }).catch(() => { });
    }
    await page.keyboard.press('Tab');
    await page.locator('flt-semantics').first()
        .waitFor({ state: 'attached', timeout: 15000 })
        .catch(() => { });

    sems = await page.locator('flt-semantics').count();
    if (sems === 0) {
        test.skip(true, 'No <flt-semantics> — build with --dart-define=FORCE_SEMANTICS=true');
    }
}

// ─── LOGIN HELPER ───────────────────────────────────────────────────
// Flutter Web routing: page.goto('/login') shows the home screen underneath.
// The login form is only rendered via IN-APP navigation:
//   Settings button → "login required" dialog → "Se connecter" → LoginScreen at /login
//
// Session detection: click Settings → if dialog appears = logged out, else → /profile = logged in.

export async function ensureLoggedInAsAdmin(page: Page, targetUrl: string, email?: string, pass?: string): Promise<void> {
    if (!email || !pass) {
        test.skip(true, 'Missing credentials');
        return;
    }

    console.log(`   ⌨️  Logging in as ${email}...`);

    // Clear service workers that might cache old builds
    await clearServiceWorkers(page);

    // Ensure we're at home before checking auth state
    if (!page.url().startsWith(targetUrl) || page.url().includes('/login') || page.url().includes('/profile')) {
        await page.goto(`${targetUrl}/`);
        await waitForFlutter(page, 120000);
    }

    // Click Settings — this reveals auth state:
    //   logged in  → navigates to /profile (no dialog)
    //   logged out → shows "Connexion requise" / "Login required" dialog
    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS_LABEL }).first();
    await expect(settingsBtn).toBeAttached({ timeout: 60000 });
    await settingsBtn.click();

    // Check for sign-in dialog button (unauthenticated state)
    // Dialog shows "Se connecter" / "Sign in" button
    const signInPrompt = page.getByRole('button', { name: BTN_SIGN_IN }).first();
    const isLoggedOut = await signInPrompt.isVisible({ timeout: 5000 }).catch(() => false);

    if (!isLoggedOut) {
        // Already logged in — might be on /profile or still at home
        console.log(`   ✅ Already logged in. Skipping login.`);
        // Use in-app back navigation (NOT page.goto — kills auth in Playwright)
        await page.goBack();
        await waitForFlutter(page, 30000);
        return;
    }

    // Tap "Se connecter" / "Sign in" to trigger in-app navigation to /login
    await signInPrompt.click();
    // Wait for the login form to appear — more robust than URL check because
    // some Flutter Web routing setups (nested navigators) may not update the URL.
    // rootNavigator: true in utils.dart ensures the URL updates, but we also
    // wait for form content as a belt-and-suspenders approach.
    // Flutter Web text inputs: there are two textboxes per field:
    //   1. Disabled one with the label ("Adresse courriel" / "Email Address")
    //   2. Enabled one with placeholder text ("you@example.com" / "••••••••")
    // We fill the ENABLED ones using their placeholder names.
    // IMPORTANT: Flutter Web text inputs need careful handling.
    // 1. fill() may not trigger Flutter's form state updates.
    // 2. pressSequentially() can lose the first character if focus isn't settled.
    // Solution: click → wait for focus → clear → type key-by-key.
    const emailInput = page.getByRole('textbox', { name: 'you@example.com' });
    // Wait for login form (URL or form appearance — URL may not update in nested nav)
    await Promise.race([
        page.waitForURL(/\/login/i, { timeout: 20000 }).catch(() => { }),
        emailInput.waitFor({ state: 'visible', timeout: 20000 }),
    ]);
    await expect(emailInput).toBeVisible({ timeout: 20000 });
    await emailInput.click();
    await page.waitForTimeout(800); // Wait for Flutter focus to settle
    await page.keyboard.type(email, { delay: 30 });
    await page.waitForTimeout(300);

    const passInput = page.getByRole('textbox', { name: '••••••••' });
    await passInput.click();
    await page.waitForTimeout(800); // Wait for Flutter focus to settle
    await page.keyboard.type(pass, { delay: 30 });
    await page.waitForTimeout(300);

    // Submit via the semantic-labeled button (language-independent)
    const submitBtn = page.locator('[aria-label^="login_submit_button"]').first();
    await submitBtn.click();

    // After login, Flutter rebuilds and shows the home screen in-place.
    // The URL may stay at /login but the content changes.
    // IMPORTANT: Do NOT use page.goto() — Firebase Auth indexedDB
    // persistence does not survive full page reloads in Playwright's
    // isolated browser contexts. Use in-app navigation only.

    // Wait for the login form to disappear (auth succeeded, app rebuilt)
    // Note: once email is typed the hint-text locator may resolve immediately — so also
    // wait for the submit button loading state to resolve via a broader Flutter wait.
    await expect(emailInput).not.toBeVisible({ timeout: 30000 });

    // Wait for Flutter to rebuild the home screen after login (dev server can be slow)
    await page.waitForTimeout(3000);
    await waitForFlutter(page, 60000);

    // Verify login: Settings button should be visible (home screen loaded)
    // 120s timeout — 8 parallel workers create resource contention on dev; login + Flutter
    // rebuild can take >60s under load (confirmed by error-context screenshots showing login
    // form still open at 60s mark).
    const verifySettingsBtn = page.getByRole('button', { name: BTN_SETTINGS_LABEL }).first();
    await expect(verifySettingsBtn).toBeAttached({ timeout: 120000 });
    // Wait for button to be visible before clicking (Flutter re-renders on login)
    // 60s to handle resource contention under 4 parallel workers
    await expect(verifySettingsBtn).toBeVisible({ timeout: 60000 });

    // Extra check: clicking Settings should navigate to /profile (not show dialog)
    await verifySettingsBtn.click({ timeout: 30000 });
    const signInCheck = page.getByRole('button', { name: BTN_SIGN_IN }).first();
    const stillLoggedOut = await signInCheck.isVisible({ timeout: 5000 }).catch(() => false);
    if (stillLoggedOut) {
        throw new Error(`Login failed for ${email} — sign-in dialog still showing after submit`);
    }

    // Navigate back to home via in-app back navigation (NOT page.goto)
    await page.goBack();
    await waitForFlutter(page, 30000);

    console.log(`   ✅ Login successful for ${email}`);
}

/** Generic alias for any user role — the underlying login is role-agnostic. */
export const ensureLoggedIn = ensureLoggedInAsAdmin;

/**
 * Login helper for buyer tests — same underlying flow as ensureLoggedInAsAdmin
 * but named to make explicit that no elevated roles are granted during login.
 * The login function is purely credential-based and never modifies user roles.
 */
export const ensureLoggedInAsBuyer = ensureLoggedInAsAdmin;

// ─── NAVIGATE HOME (auth-safe, no full page reload) ────────────────

/**
 * Navigate to the home screen without page.goto() — which would kill
 * Firebase Auth state in Playwright's isolated browser contexts.
 * Uses the app heading / logo click or browser back navigation.
 */
export async function navigateHome(page: Page, targetUrl: string): Promise<void> {
    const url = page.url();
    // Already at home
    if (url === `${targetUrl}/` || url === targetUrl || url.endsWith(':5005/') || url.endsWith(':5005')) {
        return;
    }
    // Try clicking the app heading/logo to navigate home
    const heading = page.getByRole('heading', { name: /origna/i }).first();
    const hasHeading = await heading.isVisible({ timeout: 3000 }).catch(() => false);
    if (hasHeading) {
        await heading.click();
        await waitForFlutter(page, 15000);
        return;
    }
    // Fallback: use browser back until we reach home
    for (let i = 0; i < 5; i++) {
        await page.goBack();
        await page.waitForTimeout(1000);
        if (page.url() === `${targetUrl}/` || page.url() === targetUrl) break;
    }
    await waitForFlutter(page, 15000);
}

/**
 * Navigate to the subscription screen in-app (auth-safe).
 * Route: home → settings → profile → premium menu item → subscription.
 * Never uses page.goto() which would kill Firebase Auth state.
 */
export async function navigateToSubscription(page: Page): Promise<void> {
    // Go to profile screen via settings button
    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS_LABEL }).first();
    await expect(settingsBtn).toBeAttached({ timeout: 15000 });
    await settingsBtn.click();
    await page.waitForURL(/\/profile/i, { timeout: 20000 }).catch(() => { });

    // Wait for profile-specific content — Flutter puts label text in node textContent not aria-label
    // when child has text nodes, so use getByRole + name regex (stable identifier in textContent)
    const premiumBtn = page.getByRole('button', { name: /menu-premium/i }).first();
    await expect(premiumBtn).toBeAttached({ timeout: 30000 });

    await premiumBtn.click();
    await page.waitForURL(/\/subscription/i, { timeout: 20000 }).catch(() => { });
    await waitForFlutter(page, 30000);
}

/**
 * Navigate to the admin panel in-app (auth-safe).
 * Route: home → settings → profile → admin panel menu item → /admin.
 * Never uses page.goto() which would kill Firebase Auth state.
 */
export async function navigateToAdmin(page: Page): Promise<void> {
    // Go to profile screen via settings button
    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS_LABEL }).first();
    await expect(settingsBtn).toBeAttached({ timeout: 15000 });
    await settingsBtn.click();
    await page.waitForURL(/\/profile/i, { timeout: 20000 }).catch(() => { });

    // Wait for profile-specific content - Admin Panel menu item
    const adminBtn = page.getByRole('button', { name: /menu-admin-panel|admin panel/i }).first();
    await expect(adminBtn).toBeAttached({ timeout: 30000 });
    await adminBtn.scrollIntoViewIfNeeded();

    await adminBtn.click();
    await page.waitForURL(/\/admin/i, { timeout: 20000 }).catch(() => { });
    await waitForFlutter(page, 30000);
}

// ─── SIGN OUT HELPER ─────────────────────────────────────────────────

export async function performSignOut(page: Page, targetUrl: string): Promise<void> {
    const settingsBtn = page.getByRole('button', { name: BTN_SETTINGS_LABEL }).first();
    await settingsBtn.click();
    await page.waitForURL(/\/profile/i, { timeout: 20000 }).catch(() => { });
    await waitForFlutter(page, 30000);

    const signOut = page.locator('[aria-label^="btn-sign-out"]').first();
    await expect(signOut).toBeAttached({ timeout: 15000 });
    await signOut.scrollIntoViewIfNeeded().catch(() => { });
    await signOut.click();
    await page.waitForTimeout(3000);

    // After sign-out, the app rebuilds to home (logged out).
    // Verify by clicking Settings — should show login dialog.
    const homeSettingsBtn = page.getByRole('button', { name: BTN_SETTINGS_LABEL }).first();
    await expect(homeSettingsBtn).toBeAttached({ timeout: 15000 });
    await homeSettingsBtn.click();
    await expect(
        page.getByRole('button', { name: BTN_SIGN_IN }).first()
    ).toBeVisible({ timeout: 20000 });
    // Dismiss the dialog
    const cancelBtn = page.getByRole('button', { name: /cancel|annuler/i }).first();
    await cancelBtn.click().catch(() => { });
    await page.waitForTimeout(500);
    console.log('   ✅ Sign-out confirmed');
}

// ─── UNIQUE SUFFIX ──────────────────────────────────────────────────

export function uniqueSuffix(testInfo: { workerIndex: number; parallelIndex: number }): string {
    const rnd = Math.random().toString(16).slice(2, 8);
    return `w${testInfo.workerIndex}-p${testInfo.parallelIndex}-${Date.now()}-${rnd}`;
}

// ─── SELECTORS ──────────────────────────────────────────────────────

export function flutterButton(page: Page, nameOrLabel: string | RegExp): Locator {
    return page.getByRole('button', { name: nameOrLabel });
}

export function flutterInput(page: Page, label: string | RegExp): Locator {
    return page.getByRole('textbox', { name: label });
}

export function flutterCheckbox(page: Page, label: string | RegExp): Locator {
    return page.getByRole('checkbox', { name: label });
}

export function flutterByLabel(page: Page, label: string | RegExp): Locator {
    if (typeof label === 'string') {
        return page.locator(`[aria-label="${label}"]`);
    }
    return page.locator('flt-semantics').filter({ has: page.locator(`[aria-label]`) }).filter({
        hasText: label,
    });
}

export function flutterByExactLabel(page: Page, label: string): Locator {
    return page.locator(`[aria-label="${label}"]`);
}
