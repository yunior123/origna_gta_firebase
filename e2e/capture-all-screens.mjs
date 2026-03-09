/**
 * capture-all-screens.mjs
 * Standalone Node.js script — captures all app routes with full-page screenshots.
 *
 * Auth strategy (proven, per flutter-helpers.ts line 284):
 *   - IndexedDB injection does NOT work in Playwright isolated contexts.
 *   - page.goto() resets JavaScript context → in-memory Firebase auth lost.
 *   - Solution: UI login once, then in-app navigation via history.pushState + popstate.
 *     pushState changes URL without reloading the page → Flutter's router handles the
 *     route change AND the Firebase auth state persists in memory.
 *
 * Run: node capture-all-screens.mjs
 * Env: E2E_TARGET_URL, ADMIN_EMAIL, ADMIN_PASS
 */

import { chromium } from 'playwright';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

const TARGET_URL  = process.env.E2E_TARGET_URL ?? 'https://orignagta-dev.web.app';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL    ?? 'yr62813@gmail.com';
const ADMIN_PASS  = process.env.ADMIN_PASS     ?? 'REDACTED_TEST_PASSWORD';
const OUT_DIR     = path.join(os.homedir(), 'Desktop', 'origna-visual-audit');
const SETTLE_MS   = 5000; // ms to let Flutter rebuild after navigation

const SCREENS = [
  { name: '01-home',               route: '/'                      },
  { name: '02-login',              route: '/login'                 },
  { name: '03-privacy-policy',     route: '/privacy-policy'        },
  { name: '04-terms-of-service',   route: '/terms-of-service'      },
  { name: '05-categories',         route: '/categories'            },
  { name: '06-payment-success',    route: '/payment-success'       },
  { name: '07-payment-cancel',     route: '/payment-cancel'        },
  { name: '08-sub-success',        route: '/subscription/success'  },
  { name: '09-sub-cancel',         route: '/subscription/cancel'   },
  { name: '11-cart',               route: '/cart'                  },
  { name: '12-profile',            route: '/profile'               },
  { name: '13-orders',             route: '/orders'                },
  { name: '14-favorites',          route: '/favorites'             },
  { name: '15-subscription',       route: '/subscription'          },
  { name: '16-addresses',          route: '/addresses'             },
  { name: '17-address-edit',       route: '/address/edit'          },
  { name: '18-notifications',      route: '/notifications'         },
  { name: '19-chat-inbox',         route: '/chat/inbox'            },
  { name: '20-chat',               route: '/chat'                  },
  { name: '21-checkout',           route: '/checkout'              },
  { name: '22-order-success',      route: '/order-success'         },
  { name: '23-add-product',        route: '/add-product',          extraWait: 4000 },
  { name: '24-seller-register',    route: '/seller/register'       },
  { name: '25-seller-orders',      route: '/seller/orders'         },
  { name: '26-seller-products',    route: '/seller/products'       },
  { name: '27-seller-warehouses',  route: '/seller/warehouses'     },
  { name: '28-seller-integration', route: '/seller/integration'    },
  { name: '30-admin',              route: '/admin',                extraWait: 4000 },
  { name: '31-notifications-2',    route: '/notifications'         },
];

const VIEWPORTS = [
  { name: 'mobile',  width: 375,  height: 812  },
  { name: 'desktop', width: 1440, height: 900  },
];

async function waitForFlutter(page, timeout = 60000) {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    const ready = await page.evaluate(() => {
      const canvas    = document.querySelector('canvas') || document.querySelector('flt-glass-pane');
      const semantics = document.querySelector('flt-semantics') || document.querySelector('flt-semantics-placeholder');
      return !!(canvas || semantics);
    }).catch(() => false);
    if (ready) return;
    await new Promise(r => setTimeout(r, 800));
  }
}

/** Enable Flutter's semantic tree so locators work. */
async function enableSemantics(page) {
  await page.evaluate(() => {
    const ph = document.querySelector('flt-semantics-placeholder');
    if (ph) ph.click();
  });
  await page.keyboard.press('Tab');
  await new Promise(r => setTimeout(r, 1500));
}

/**
 * Navigate in-app via history.pushState + popstate.
 * This does NOT reload the page, so Firebase auth state stays in memory.
 * Flutter's URL strategy registers a popstate listener and handles the route change.
 */
async function navigateInApp(page, route) {
  await page.evaluate((route) => {
    history.pushState(null, '', route);
    window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
  }, route);
}

/**
 * Login via Flutter UI. Called once per viewport context.
 * After this, auth is in Firebase's in-memory state and persists across navigateInApp() calls.
 */
async function uiLogin(page, email, pass) {
  console.log('  🔐 Logging in via Flutter UI...');

  // Navigate to home first (page.goto is ok here — we're not authenticated yet)
  await page.goto(`${TARGET_URL}/`, { waitUntil: 'commit', timeout: 60000 });
  await waitForFlutter(page, 90000);
  await new Promise(r => setTimeout(r, 3000));

  // Enable Flutter semantics
  await enableSemantics(page);

  // Navigate to /login via in-app navigation (no page reload)
  await navigateInApp(page, '/login');
  await new Promise(r => setTimeout(r, 3000));

  // Find email field — Flutter renders two textboxes per field:
  //   1. Disabled label field (not interactable)
  //   2. Enabled placeholder field ("you@example.com")
  // We target the enabled one.
  const emailInput = page.getByRole('textbox', { name: /you@example\.com/i }).first();
  try {
    await emailInput.waitFor({ state: 'visible', timeout: 15000 });
  } catch {
    // Fallback: if /login page didn't load via pushState, try page.goto (auth will be lost
    // from this navigation, but we'll type credentials and Firebase will auth us in-memory)
    console.log('  ⚠️  pushState to /login failed — falling back to page.goto /login');
    await page.goto(`${TARGET_URL}/login`, { waitUntil: 'commit', timeout: 30000 });
    await waitForFlutter(page, 30000);
    await enableSemantics(page);
    await new Promise(r => setTimeout(r, 2000));
    await emailInput.waitFor({ state: 'visible', timeout: 10000 });
  }

  // Type email
  await emailInput.click();
  await new Promise(r => setTimeout(r, 800));
  await page.keyboard.type(email, { delay: 30 });
  await new Promise(r => setTimeout(r, 300));

  // Type password
  const passInput = page.getByRole('textbox', { name: /[•]{6,}/}).first();
  await passInput.click();
  await new Promise(r => setTimeout(r, 800));
  await page.keyboard.type(pass, { delay: 30 });
  await new Promise(r => setTimeout(r, 300));

  // Submit
  const submitBtn = page.locator('[aria-label^="login_submit_button"]').first();
  await submitBtn.click();

  // Wait for login form to disappear (auth succeeded)
  await emailInput.waitFor({ state: 'hidden', timeout: 30000 });
  await new Promise(r => setTimeout(r, 4000));
  await waitForFlutter(page, 30000);

  console.log('  ✅ Login successful');
}

async function main() {
  if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

  console.log(`\n🎬 OrignaGTA Visual Audit (UI login + in-app navigation)`);
  console.log(`📁 Output:  ${OUT_DIR}`);
  console.log(`🌐 Target:  ${TARGET_URL}`);
  console.log(`👤 Account: ${ADMIN_EMAIL}\n`);

  const browser = await chromium.launch({ headless: true });
  const results = [];

  for (const vp of VIEWPORTS) {
    console.log(`\n═══════════ ${vp.name.toUpperCase()} (${vp.width}×${vp.height}) ═══════════`);

    const context = await browser.newContext({
      viewport:          { width: vp.width, height: vp.height },
      ignoreHTTPSErrors: true,
      bypassCSP:         true,
    });

    const page = await context.newPage();

    // ── Login once — auth state stays in memory for all navigateInApp() calls ──
    try {
      await uiLogin(page, ADMIN_EMAIL, ADMIN_PASS);
    } catch (err) {
      console.error(`  ❌ Login failed: ${err.message} — screens will be unauthenticated`);
    }

    // Navigate back to home (in-app) before starting screen loop
    await navigateInApp(page, '/');
    await new Promise(r => setTimeout(r, 3000));

    console.log('\n  Capturing screens...\n');

    for (const screen of SCREENS) {
      const outPath = path.join(OUT_DIR, `${screen.name}-${vp.name}.png`);
      process.stdout.write(`  [${vp.name}] ${screen.name}...`);

      try {
        // Use in-app navigation — preserves Firebase in-memory auth state
        await navigateInApp(page, screen.route);

        // Wait for Flutter to rebuild the screen
        await new Promise(r => setTimeout(r, SETTLE_MS + (screen.extraWait ?? 0)));

        // Scroll to trigger lazy-loaded content, then back to top
        await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight)).catch(() => {});
        await new Promise(r => setTimeout(r, 500));
        await page.evaluate(() => window.scrollTo(0, 0)).catch(() => {});
        await new Promise(r => setTimeout(r, 400));

        await page.screenshot({
          path:       outPath,
          fullPage:   true,
          animations: 'disabled',
        });

        const finalRoute = new URL(page.url()).pathname;
        const expected   = screen.route === '/' ? '/' : screen.route.replace(/^\//, '');
        const redirected = screen.route !== '/' && !finalRoute.includes(expected);
        const status     = redirected ? `→ ${finalRoute}` : 'ok';
        process.stdout.write(` ✓ ${status}\n`);
        results.push({ screen: screen.name, vp: vp.name, status: 'ok', path: outPath });
      } catch (err) {
        await page.screenshot({ path: outPath, fullPage: true, animations: 'disabled' }).catch(() => {});
        process.stdout.write(` ✗ ${err.message.slice(0, 60)}\n`);
        results.push({ screen: screen.name, vp: vp.name, status: 'error', path: outPath });
      }
    }

    await context.close();
  }

  await browser.close();

  const ok     = results.filter(r => r.status === 'ok').length;
  const errors = results.filter(r => r.status === 'error').length;
  console.log(`\n\n════ DONE ════`);
  console.log(`✅ OK: ${ok}  |  ❌ Errors: ${errors}  |  Total: ${results.length}`);
  console.log(`📁 ${OUT_DIR}`);

  const manifest = { timestamp: new Date().toISOString(), target: TARGET_URL, screens: results };
  fs.writeFileSync(path.join(OUT_DIR, 'manifest.json'), JSON.stringify(manifest, null, 2));
  console.log('📋 manifest.json written');
}

main().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});
