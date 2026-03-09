/**
 * design-audit.spec.ts
 *
 * Visual design audit: navigates to every screen in the app, takes a
 * labelled screenshot, and saves it to ~/Desktop/origna-design-audit/
 *
 * Run with:
 *   cd e2e
 *   E2E_TARGET_URL=http://localhost:8080 npx playwright test design-audit.spec.ts \
 *     --config playwright.config.dev.ts --headed
 *
 * The screenshots show the actual Flutter Web app at each route, which can
 * then be compared against the Figma mockup frames.
 */

import * as fs from 'fs';
import * as path from 'path';
import { test, expect, Page } from '@playwright/test';
import {
  waitForFlutter,
  ensureLoggedInAsAdmin,
  ensureLoggedInAsBuyer,
  clearServiceWorkers,
  requireWebApp,
} from './flutter-helpers';
import { TEST_ACCOUNTS } from './api-helpers';

// ─── Config ───────────────────────────────────────────────────────────────
const TARGET = process.env.E2E_TARGET_URL ?? 'https://orignagta-dev.web.app';
const DESKTOP = path.join(process.env.HOME ?? '/tmp', 'Desktop', 'origna-design-audit');

// Mobile viewport — matches 390px mockup width
const MOBILE_VIEWPORT = { width: 390, height: 844 };
// Tablet viewport
const TABLET_VIEWPORT = { width: 768, height: 1024 };
// Desktop viewport
const DESKTOP_VIEWPORT = { width: 1280, height: 800 };

function ensureDir(dir: string) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

async function snap(page: Page, name: string, folder = 'mobile') {
  const dir = path.join(DESKTOP, folder);
  ensureDir(dir);
  const file = path.join(dir, `${name}.png`);
  await page.screenshot({ path: file, fullPage: false });
  console.log(`  📸 ${folder}/${name}.png`);
}

async function goTo(page: Page, route: string, extraWait = 1200) {
  await page.goto(`${TARGET}${route}`);
  await waitForFlutter(page, 90_000);
  await page.waitForTimeout(extraWait); // let animations + deferred widgets settle
}

// ─── Auth screens (no login required) ─────────────────────────────────────
test.describe('Auth Screens', () => {
  test.use({ viewport: MOBILE_VIEWPORT });

  test('Login screen — all states', async ({ page }) => {
    await requireWebApp(page, TARGET);
    await goTo(page, '/login');

    // Default: Login tab
    await snap(page, '01-login-tab');

    // Click Sign Up tab
    const signUpTab = page.getByRole('tab', { name: /sign.?up|register|créer/i }).first();
    const hasSignUpTab = await signUpTab.isVisible({ timeout: 3000 }).catch(() => false);
    if (hasSignUpTab) {
      await signUpTab.click();
      await page.waitForTimeout(500);
      await snap(page, '02-signup-tab');
    }

    // Click Forgot Password tab
    const forgotTab = page.getByRole('tab', { name: /forgot|reset|mot.?de.?passe/i }).first();
    const hasForgotTab = await forgotTab.isVisible({ timeout: 3000 }).catch(() => false);
    if (hasForgotTab) {
      await forgotTab.click();
      await page.waitForTimeout(500);
      await snap(page, '03-forgot-password-tab');
    }
  });

  test('Privacy Policy screen', async ({ page }) => {
    await requireWebApp(page, TARGET);
    await goTo(page, '/privacy-policy');
    await snap(page, '04-privacy-policy');
  });

  test('Terms of Service screen', async ({ page }) => {
    await requireWebApp(page, TARGET);
    await goTo(page, '/terms-of-service');
    await snap(page, '05-terms-of-service');
  });
});

// ─── Buyer screens (buyer login) ──────────────────────────────────────────
test.describe('Buyer Screens — Mobile', () => {
  test.use({ viewport: MOBILE_VIEWPORT });

  test.beforeEach(async ({ page }) => {
    await requireWebApp(page, TARGET);
    await ensureLoggedInAsBuyer(page, TARGET, TEST_ACCOUNTS.BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS);
  });

  test('Home screen', async ({ page }) => {
    await goTo(page, '/');
    await snap(page, '06-home-loaded');

    // Scroll down to show more products
    await page.mouse.wheel(0, 400);
    await page.waitForTimeout(800);
    await snap(page, '07-home-scrolled');
    await page.mouse.wheel(0, -400);
  });

  test('Product Detail screen', async ({ page }) => {
    await goTo(page, '/');
    await waitForFlutter(page);

    // Find first product card
    const cards = page.locator('[aria-label^="product-card-"]');
    await cards.first().waitFor({ timeout: 15000 }).catch(() => {});
    const count = await cards.count();
    if (count === 0) {
      console.log('  ⚠️  No product cards found — skipping product detail');
      return;
    }
    await cards.first().click();
    await waitForFlutter(page, 30_000);
    await page.waitForTimeout(1500);
    await snap(page, '08-product-detail-images');

    // Scroll to details tab
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(800);
    await snap(page, '09-product-detail-scrolled');
  });

  test('Cart screen — empty', async ({ page }) => {
    await goTo(page, '/cart');
    await snap(page, '10-cart-empty');
  });

  test('Favorites screen', async ({ page }) => {
    await goTo(page, '/favorites');
    await snap(page, '11-favorites');
  });

  test('Orders screen', async ({ page }) => {
    await goTo(page, '/orders');
    await snap(page, '12-orders-list');
  });

  test('Profile screen — buyer', async ({ page }) => {
    await goTo(page, '/profile');
    await snap(page, '13-profile-buyer');

    // Scroll down to see all sections
    await page.mouse.wheel(0, 400);
    await page.waitForTimeout(600);
    await snap(page, '14-profile-buyer-scrolled');
  });

  test('Address Management screen', async ({ page }) => {
    await goTo(page, '/addresses');
    await snap(page, '15-address-management');
  });

  test('Subscription screen', async ({ page }) => {
    await goTo(page, '/subscription');
    await snap(page, '16-subscription-plans');
  });
});

// ─── Seller screens (admin = seller + buyer) ──────────────────────────────
test.describe('Seller Screens — Mobile', () => {
  test.use({ viewport: MOBILE_VIEWPORT });

  test.beforeEach(async ({ page }) => {
    await requireWebApp(page, TARGET);
    await ensureLoggedInAsAdmin(page, TARGET, TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
  });

  test('Seller Products screen', async ({ page }) => {
    await goTo(page, '/seller/products');
    await snap(page, '17-seller-products');
  });

  test('Seller Orders screen', async ({ page }) => {
    await goTo(page, '/seller/orders');
    await snap(page, '18-seller-orders');
  });

  test('Seller Warehouses screen', async ({ page }) => {
    await goTo(page, '/seller/warehouses');
    await snap(page, '19-seller-warehouses');
  });

  test('Seller Integration screen', async ({ page }) => {
    await goTo(page, '/seller/integration');
    await snap(page, '20-seller-integration');
  });

  test('Admin Panel screen', async ({ page }) => {
    await goTo(page, '/admin');
    await snap(page, '21-admin-panel-users');

    // Click each admin tab
    const tabs = [
      { label: /seller/i, name: '22-admin-panel-sellers' },
      { label: /order/i, name: '23-admin-panel-orders' },
      { label: /product/i, name: '24-admin-panel-products' },
    ];
    for (const { label, name } of tabs) {
      const tab = page.getByRole('tab', { name: label }).first();
      const visible = await tab.isVisible({ timeout: 3000 }).catch(() => false);
      if (visible) {
        await tab.click();
        await page.waitForTimeout(800);
        await snap(page, name);
      }
    }
  });

  test('Seller Shipping Approval screen', async ({ page }) => {
    await goTo(page, '/shipping-approval');
    await snap(page, '25-shipping-approval');
  });
});

// ─── Desktop responsive layout ────────────────────────────────────────────
test.describe('Desktop Layouts', () => {
  test.setTimeout(360_000);
  test.use({ viewport: DESKTOP_VIEWPORT });

  test.beforeEach(async ({ page }) => {
    await requireWebApp(page, TARGET);
    await ensureLoggedInAsBuyer(page, TARGET, TEST_ACCOUNTS.BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS);
  });

  test('Home — desktop layout', async ({ page }) => {
    await goTo(page, '/');
    await snap(page, '26-home-desktop', 'desktop');
  });

  test('Product Detail — desktop layout', async ({ page }) => {
    await goTo(page, '/');
    const cards = page.locator('[aria-label^="product-card-"]');
    await cards.first().waitFor({ timeout: 15000 }).catch(() => {});
    if (await cards.count() > 0) {
      await cards.first().click();
      await waitForFlutter(page, 30_000);
      await page.waitForTimeout(1500);
      await snap(page, '27-product-detail-desktop', 'desktop');
    }
  });

  test('Cart — desktop layout', async ({ page }) => {
    await goTo(page, '/cart');
    await snap(page, '28-cart-desktop', 'desktop');
  });

  test('Profile — desktop layout', async ({ page }) => {
    await goTo(page, '/profile');
    await snap(page, '29-profile-desktop', 'desktop');
  });

  test('Seller Products — desktop layout', async ({ page }) => {
    await ensureLoggedInAsAdmin(page, TARGET, TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    await goTo(page, '/seller/products');
    await snap(page, '30-seller-products-desktop', 'desktop');
  });
});

// ─── Tablet responsive layout ─────────────────────────────────────────────
test.describe('Tablet Layouts', () => {
  test.setTimeout(360_000);
  test.use({ viewport: TABLET_VIEWPORT });

  test.beforeEach(async ({ page }) => {
    await requireWebApp(page, TARGET);
    await ensureLoggedInAsBuyer(page, TARGET, TEST_ACCOUNTS.BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS);
  });

  test('Home — tablet layout', async ({ page }) => {
    await goTo(page, '/');
    await snap(page, '31-home-tablet', 'tablet');
  });

  test('Product Detail — tablet layout', async ({ page }) => {
    await goTo(page, '/');
    const cards = page.locator('[aria-label^="product-card-"]');
    await cards.first().waitFor({ timeout: 15000 }).catch(() => {});
    if (await cards.count() > 0) {
      await cards.first().click();
      await waitForFlutter(page, 30_000);
      await page.waitForTimeout(1500);
      await snap(page, '32-product-detail-tablet', 'tablet');
    }
  });
});

// ─── Design token smoke checks ────────────────────────────────────────────
test.describe('Design Token Verification', () => {
  test.use({ viewport: MOBILE_VIEWPORT });

  /**
   * Verifies that key Flutter Semantics labels exist on each critical screen.
   * These labels are set in the Flutter source and serve as design anchors.
   */
  test('Login screen — semantics anchors present', async ({ page }) => {
    await requireWebApp(page, TARGET);
    await goTo(page, '/login');

    // The login form must have these semantics anchors per origna_flows/SEMANTICS.md
    const anchors = [
      'input-login-email',
      'input-login-password',
      'login_submit_button',
    ];
    for (const anchor of anchors) {
      const el = page.locator(`[aria-label="${anchor}"], [aria-label^="${anchor}"]`).first();
      const found = await el.isVisible({ timeout: 8000 }).catch(() => false);
      console.log(`  ${found ? '✅' : '❌'} Semantics anchor: ${anchor}`);
      // Not a hard assertion — just informational for audit
    }
    await snap(page, '33-login-semantics-check', 'audit');
  });

  test('Home screen — bottom nav present', async ({ page }) => {
    await requireWebApp(page, TARGET);
    await ensureLoggedInAsBuyer(page, TARGET, TEST_ACCOUNTS.BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS);
    await goTo(page, '/');

    // Bottom navigation should be visible
    const nav = page.locator('[aria-label="bottom-nav"], [role="navigation"]').first();
    const cartBtn = page.getByRole('button', { name: /cart|panier/i }).first();
    const hasCart = await cartBtn.isVisible({ timeout: 5000 }).catch(() => false);
    console.log(`  ${hasCart ? '✅' : '❌'} Cart button in bottom nav`);

    await snap(page, '34-home-bottom-nav', 'audit');
  });

  test('Profile screen — all sections visible', async ({ page }) => {
    await requireWebApp(page, TARGET);
    await ensureLoggedInAsBuyer(page, TARGET, TEST_ACCOUNTS.BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS);
    await goTo(page, '/profile');

    const sections = [
      { label: 'menu-my-orders', name: 'My Orders' },
      { label: 'menu-addresses', name: 'Addresses' },
      { label: 'menu-subscription', name: 'Subscription' },
    ];
    for (const { label, name } of sections) {
      const el = page.locator(`[aria-label^="${label}"]`).first();
      const found = await el.isVisible({ timeout: 5000 }).catch(() => false);
      console.log(`  ${found ? '✅' : '❌'} Profile section: ${name}`);
    }
    await snap(page, '35-profile-sections-audit', 'audit');
  });
});
