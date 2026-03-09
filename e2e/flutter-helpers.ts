/**
 * Flutter Web E2E Test Helpers
 *
 * Provides Playwright selectors and utilities for Flutter Web (CanvasKit/Skwasm).
 * Flutter renders to <canvas> but exposes a parallel DOM tree of <flt-semantics>
 * elements with ARIA attributes when semantics is enabled.
 *
 * IMPORTANT: main.dart calls `SemanticsBinding.instance.ensureSemantics()` on web,
 * so the semantic tree is always available — no Tab-key hack needed.
 *
 * Convention for semantic labels: kebab-case technical IDs
 *   - btn-*          → buttons (e.g., btn-login-submit, btn-add-to-cart-{id})
 *   - input-*        → text fields (e.g., input-home-search)
 *   - chk-*          → checkboxes (e.g., chk-terms-accepted)
 *   - chip-*         → choice chips (e.g., chip-address-label-home)
 *   - link-*         → links (e.g., link-terms-conditions)
 *   - nav-*          → navigation items (e.g., nav-home)
 *   - menu-*         → profile menu items (e.g., menu-my-orders)
 *   - product-card-* → product cards (e.g., product-card-{productId})
 */

import { Page, Locator } from '@playwright/test';
import * as path from 'path';
import * as fs from 'fs';

// ─── SCREENSHOT UTILITIES ───────────────────────────────────────────

/**
 * Capture a screenshot and save it to the desktop for UI/UX review.
 * Screenshots are organized by date and test worker.
 * 
 * @param page The Playwright page object
 * @param label Descriptive label for the screenshot filename
 */
export async function takeScreenshot(page: Page, label: string): Promise<void> {
  const desktopPath = path.join(process.env.HOME || '', 'Desktop', 'origna-screenshots');
  
  // Ensure directory exists
  if (!fs.existsSync(desktopPath)) {
    try {
      fs.mkdirSync(desktopPath, { recursive: true });
    } catch (e) {
      console.warn(`⚠️ Could not create screenshot directory at ${desktopPath}: ${e}`);
      return;
    }
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const filename = `${timestamp}_${label.replace(/[^a-z0-9]/gi, '_')}.png`;
  const fullPath = path.join(desktopPath, filename);

  try {
    await page.screenshot({ path: fullPath, fullPage: true });
    // console.log(`📸 Screenshot saved: ${fullPath}`);
  } catch (e) {
    console.warn(`⚠️ Failed to capture screenshot "${label}": ${e}`);
  }
}

// ─── FLUTTER INITIALIZATION ─────────────────────────────────────────

/**
 * Wait for Flutter Web to fully initialize and semantics tree to be ready.
 * No Tab-key hack needed — semantics is force-enabled in main.dart.
 */
export async function waitForFlutter(page: Page, timeout = 90000): Promise<void> {
  console.log(`⏳ Waiting for Flutter Web to initialize (timeout: ${timeout}ms)...`);
  const startTime = Date.now();

  // 1) Wait for Flutter host element OR a sized canvas
  await page.waitForFunction(() => {
    const glasspane = document.querySelector('flt-glass-pane');
    const flutterView = document.querySelector('flutter-view');
    const canvas = document.querySelector('canvas');
    return (
      !!glasspane ||
      !!flutterView ||
      (canvas instanceof HTMLCanvasElement && canvas.getBoundingClientRect().width > 0)
    );
  }, { timeout });
  console.log(`   ✅ Flutter host element found (${Date.now() - startTime}ms)`);

  // 2) Wait for splash screen to disappear
  await page
    .waitForFunction(() => {
      const splash = document.getElementById('splash');
      return !splash || splash.style.display === 'none' || splash.getAttribute('hidden') !== null;
    }, { timeout })
    .catch(() => {});
  console.log(`   ✅ Splash screen gone (${Date.now() - startTime}ms)`);

  // 3) Wait for canvas with actual dimensions
  await page
    .waitForFunction(
      () => {
        const canvas = document.querySelector('canvas');
        if (!(canvas instanceof HTMLCanvasElement)) return false;
        const rect = canvas.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
      },
      { timeout: Math.min(30000, timeout) },
    )
    .catch(() => {});
  console.log(`   ✅ Canvas rendered (${Date.now() - startTime}ms)`);

  // 4) Activate semantics tree
  const enableA11yBtn = page.locator('button:has-text("Enable accessibility")');
  const placeholder = page.locator('flt-semantics-placeholder');
  if ((await enableA11yBtn.count()) > 0) {
    await enableA11yBtn.first().click({ force: true }).catch(() => {});
    console.log(`   ✅ Semantics activated via "Enable accessibility" button (${Date.now() - startTime}ms)`);
    await page.waitForTimeout(2_000); // Allow semantics tree to build
  } else if ((await placeholder.count()) > 0) {
    await placeholder.first().click({ force: true }).catch(() => {});
    await page.keyboard.press('Tab');
    console.log(`   ✅ Semantics activated via placeholder (${Date.now() - startTime}ms)`);
  } else {
    // Try Tab key as last resort to trigger semantics
    await page.keyboard.press('Tab');
    console.log(`   ℹ️ No accessibility button found — pressed Tab to trigger semantics (${Date.now() - startTime}ms)`);
  }

  // 5) Wait for semantics tree to appear
  await page
    .locator('flt-semantics')
    .first()
    .waitFor({ state: 'attached', timeout: Math.min(30000, timeout) })
    .catch(() => {});
  
  console.log(`   ✅ Flutter initialized in ${Date.now() - startTime}ms`);
  
  // Take auto-screenshot after initialization
  await takeScreenshot(page, 'flutter_initialized');
}

// ─── SELECTORS ──────────────────────────────────────────────────────

/**
 * Locate a Flutter button by its semantic label or visible text.
 */
export function flutterButton(page: Page, nameOrLabel: string | RegExp): Locator {
  return page.getByRole('button', { name: nameOrLabel });
}

/**
 * Locate a Flutter text input field.
 */
export function flutterInput(page: Page, label: string | RegExp): Locator {
  return page.getByRole('textbox', { name: label });
}

/**
 * Locate a Flutter checkbox by its semantic label.
 */
export function flutterCheckbox(page: Page, label: string | RegExp): Locator {
  return page.getByRole('checkbox', { name: label });
}

/**
 * Locate any Flutter widget by its aria-label (from Semantics(label:) or tooltip).
 */
export function flutterByLabel(page: Page, label: string | RegExp): Locator {
  if (typeof label === 'string') {
    return page.locator(`[aria-label="${label}"]`);
  }
  return page.locator('flt-semantics').filter({ has: page.locator(`[aria-label]`) }).filter({
    hasText: label,
  });
}

/**
 * Locate a Flutter widget by exact aria-label.
 */
export function flutterByExactLabel(page: Page, label: string): Locator {
  return page.locator(`[aria-label="${label}"]`);
}

/**
 * Locate a Flutter link by its semantic label.
 */
export function flutterLink(page: Page, label: string | RegExp): Locator {
  return page.getByRole('link', { name: label });
}

// ─── ACTIONS ────────────────────────────────────────────────────────

/**
 * Fill a Flutter text input by its label.
 */
export async function fillFlutterInput(
  page: Page,
  label: string | RegExp,
  value: string,
): Promise<void> {
  const input = flutterInput(page, label);
  await input.click();
  await input.fill(value);
  await takeScreenshot(page, `fill_input_${label.toString().replace(/[^a-z0-9]/gi, '_')}`);
}

/**
 * Click a Flutter button and optionally wait for navigation.
 */
export async function clickFlutterButton(
  page: Page,
  nameOrLabel: string | RegExp,
): Promise<void> {
  await flutterButton(page, nameOrLabel).click();
  await takeScreenshot(page, `click_btn_${nameOrLabel.toString().replace(/[^a-z0-9]/gi, '_')}`);
}

/**
 * Wait for a specific semantic label to appear in the DOM.
 */
export async function waitForSemanticLabel(
  page: Page,
  label: string,
  timeout = 10000,
): Promise<void> {
  await page.locator(`[aria-label="${label}"]`).first().waitFor({
    state: 'attached',
    timeout,
  });
  await takeScreenshot(page, `wait_for_label_${label}`);
}

/**
 * Check if a semantic label exists in the DOM (non-blocking).
 */
export async function hasSemanticLabel(page: Page, label: string): Promise<boolean> {
  return (await page.locator(`[aria-label="${label}"]`).count()) > 0;
}

// ─── NAVIGATION HELPERS ─────────────────────────────────────────────

/**
 * Navigate to a Flutter route via URL hash and wait for rendering.
 */
export async function navigateToRoute(
  page: Page,
  route: string,
  baseUrl: string,
): Promise<void> {
  await page.goto(`${baseUrl}/#${route}`);
  await waitForFlutter(page, 30000);
  await takeScreenshot(page, `nav_to_${route.replace(/\//g, '_')}`);
}

// ─── PRODUCT HELPERS ────────────────────────────────────────────────

export function productCard(page: Page, productId: string): Locator {
  return flutterByExactLabel(page, `product-card-${productId}`);
}

export async function toggleFavorite(page: Page, productId: string): Promise<void> {
  await flutterByExactLabel(page, `btn-favorite-${productId}`).click();
  await takeScreenshot(page, `toggle_favorite_${productId}`);
}

export async function addToCart(page: Page, productId: string): Promise<void> {
  await flutterByExactLabel(page, `btn-add-to-cart-${productId}`).click();
  await takeScreenshot(page, `add_to_cart_${productId}`);
}

// ─── UNIQUE SUFFIX (for parallel tests) ─────────────────────────────

export function uniqueSuffix(testInfo: { workerIndex: number; parallelIndex: number }): string {
  const rnd = Math.random().toString(16).slice(2, 8);
  return `w${testInfo.workerIndex}-p${testInfo.parallelIndex}-${Date.now()}-${rnd}`;
}
