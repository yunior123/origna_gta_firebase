/**
 * capture-all-previews.mjs
 * ─────────────────────────────────────────────────────────────────────────────
 * Headless Playwright captures all 136+ Flutter widget previews.
 *
 * Key fixes over previous attempts:
 * 1. NO DOM atBottom check — Flutter doesn't use DOM scroll, always reported "bottom".
 * 2. Proper group expansion — click every ~55px in main panel, scroll, repeat.
 * 3. Fixed scroll count — 220 steps × 800px = 176,000px, more than enough.
 *
 * Run: PREVIEWER_PORT=52695 node e2e/capture-all-previews.mjs
 */

import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import os from 'os';

const PORT = process.env.PREVIEWER_PORT ?? '52695';
const BASE_URL = `http://localhost:${PORT}`;
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-desktop-previews');

// Clear and recreate output dir
fs.rmSync(OUT_DIR, { recursive: true, force: true });
fs.mkdirSync(OUT_DIR, { recursive: true });
console.log(`Output: ${OUT_DIR}`);

// ─── Launch headless browser ──────────────────────────────────────────────────
const browser = await chromium.launch({
  headless: true,
  args: [
    '--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage',
    '--enable-webgl', '--use-gl=swiftshader', '--ignore-gpu-blocklist',
    '--disable-gpu-sandbox',
  ],
});

const ctx = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  deviceScaleFactor: 1,
});
const page = await ctx.newPage();

console.log(`Loading ${BASE_URL}...`);
await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 30_000 });

// Wait for Flutter to fully boot (first compile takes time)
console.log('Waiting 15s for Flutter to initialize...');
await page.waitForTimeout(15_000);

// Verify Flutter rendered
const state = await page.evaluate(() => ({
  glassPane: !!document.querySelector('flt-glass-pane'),
  semNodes: document.querySelectorAll('flt-semantics').length,
}));
console.log('Flutter state:', state);

// ─── Screenshot helper ────────────────────────────────────────────────────────
let shotCount = 0;
async function shot(filename, settleMs = 0) {
  if (settleMs > 0) await page.waitForTimeout(settleMs);
  const outPath = path.join(OUT_DIR, filename);
  try {
    await page.screenshot({ path: outPath, animations: 'disabled', timeout: 15_000 });
    const kb = (fs.statSync(outPath).size / 1024).toFixed(0);
    shotCount++;
    console.log(`  [${shotCount}] ${filename} (${kb}KB)`);
    return true;
  } catch (e) {
    console.log(`  SKIP ${filename}: ${e.message?.slice(0, 60)}`);
    return false;
  }
}

// ─── Layout constants ─────────────────────────────────────────────────────────
// Widget previewer: left sidebar (~250px) + right main panel (~1190px)
// Main panel center X: ~870px (for 1440 viewport)
const MAIN_X = 870;
const MAIN_Y = 450;

// ─── Step 1: Initial screenshot ───────────────────────────────────────────────
await shot('000_initial.png', 500);

// ─── Step 2: Expand ALL groups in main panel ─────────────────────────────────
// Groups show as ExpansionTile rows ~55px tall in the main panel.
// Strategy: systematically click at every 55px across 3 viewport heights,
// scrolling down after each pass to reach groups below the fold.
console.log('\nExpanding all groups...');

const GROUP_H = 55;
const CLICKS_PER_PASS = Math.ceil(900 / GROUP_H); // ~16 clicks per pass

// 3 passes down to expand all 40 groups
for (let pass = 0; pass < 3; pass++) {
  // Click every group header position visible in viewport
  for (let i = 0; i < CLICKS_PER_PASS; i++) {
    const y = 30 + i * GROUP_H;
    await page.mouse.click(MAIN_X, y);
    await page.waitForTimeout(80);
  }
  await page.waitForTimeout(200);

  if (pass < 2) {
    // Scroll down to see next batch of group headers
    for (let s = 0; s < 5; s++) {
      await page.mouse.move(MAIN_X, MAIN_Y);
      await page.mouse.wheel(0, 800);
      await page.waitForTimeout(100);
    }
    await page.waitForTimeout(300);
  }
}

await shot('001_after_expand_pass.png', 500);

// ─── Step 3: Scroll back to top ───────────────────────────────────────────────
console.log('\nScrolling to top...');
await page.mouse.move(MAIN_X, MAIN_Y);
for (let i = 0; i < 80; i++) {
  await page.mouse.wheel(0, -2000);
}
await page.waitForTimeout(2000);
await shot('002_top.png', 500);

// ─── Step 4: Scroll-through capture ──────────────────────────────────────────
// DO NOT check document.documentElement.scrollHeight — Flutter doesn't use DOM scroll.
// Use a generous fixed scroll count instead.
console.log('\nScroll-through capture (220 steps)...');

const SCROLL_STEP = 800;
const MAX_STEPS = 220;

for (let s = 0; s < MAX_STEPS; s++) {
  await page.mouse.move(MAIN_X, MAIN_Y);
  await page.mouse.wheel(0, SCROLL_STEP);
  await page.waitForTimeout(300);

  const fname = `scroll_${String(s + 1).padStart(3, '0')}.png`;
  await shot(fname);

  // Log progress every 20 steps
  if ((s + 1) % 20 === 0) {
    console.log(`  --- ${s + 1}/${MAX_STEPS} steps done ---`);
  }
}

// ─── Done ─────────────────────────────────────────────────────────────────────
await browser.close();
const files = fs.readdirSync(OUT_DIR).filter(f => f.endsWith('.png'));
console.log(`\n✓ Done. ${files.length} screenshots in ${OUT_DIR}`);
