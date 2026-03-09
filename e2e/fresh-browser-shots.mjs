/**
 * fresh-browser-shots.mjs
 * ─────────────────────────────────────────────────────────────────────────────
 * Launches a FRESH headless Playwright browser (not the Flutter tooling Chrome)
 * and navigates to the running Flutter widget previewer at localhost:52695.
 * Headless Chromium supports Page.captureScreenshot without the WebGL hang.
 *
 * Run: PREVIEWER_PORT=52695 node e2e/fresh-browser-shots.mjs
 */

import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import os from 'os';

const PORT = process.env.PREVIEWER_PORT ?? '52695';
const BASE_URL = `http://localhost:${PORT}`;
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-desktop-previews');
fs.mkdirSync(OUT_DIR, { recursive: true });

// ─── Read preview names ───────────────────────────────────────────────────────
const genFile = '/var/folders/bc/650vj62175vcn92kgbffvhzw0000gp/T/flutter_tools.Xqs1Ax/widget_preview_scaffoldh7X1ZG/lib/src/generated_preview.dart';
let previewNames = [];
if (fs.existsSync(genFile)) {
  const src = fs.readFileSync(genFile, 'utf8');
  previewNames = [...src.matchAll(/name:\s*'([^']+)'/g)].map(m => m[1]);
}
console.log(`Previews to capture: ${previewNames.length}`);

// ─── Launch fresh headless browser ───────────────────────────────────────────
const browser = await chromium.launch({
  headless: true,
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--enable-webgl',
    '--ignore-gpu-blocklist',
    '--use-gl=swiftshader',  // software WebGL renderer (no GPU needed)
    '--disable-gpu-sandbox',
  ],
});

const ctx = await browser.newContext({
  viewport: { width: 1400, height: 900 },
  deviceScaleFactor: 1,
});
const page = await ctx.newPage();

console.log(`Navigating to ${BASE_URL}...`);
await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 30_000 });
console.log('Page loaded. Waiting for Flutter to initialize...');

// Wait for Flutter to boot
await page.waitForTimeout(10_000);

// Check if Flutter rendered anything
const rendered = await page.evaluate(() => {
  const glassPane = document.querySelector('flt-glass-pane');
  const semNodes = document.querySelectorAll('flt-semantics').length;
  const canvases = document.querySelectorAll('canvas').length;
  return { glassPane: !!glassPane, semNodes, canvases };
});
console.log('Flutter state:', rendered);

// ─── screenshot helper ─────────────────────────────────────────────────────────
async function shot(filename, settleMs = 800) {
  await page.waitForTimeout(settleMs);
  const outPath = path.join(OUT_DIR, filename);
  try {
    await page.screenshot({
      path: outPath,
      fullPage: false,
      animations: 'disabled',
      timeout: 20_000,
    });
    const size = fs.statSync(outPath).size;
    console.log(`  → ${filename} (${(size / 1024).toFixed(0)}KB)`);
    return size > 1000; // at least 1KB = real content
  } catch (e) {
    console.log(`  [SKIP] ${filename}: ${e.message?.slice(0, 60)}`);
    return false;
  }
}

// ─── Overview ────────────────────────────────────────────────────────────────
await shot('000_overview.png', 2000);

// If overview looks bad, try waiting longer
const overviewSize = fs.existsSync(path.join(OUT_DIR, '000_overview.png'))
  ? fs.statSync(path.join(OUT_DIR, '000_overview.png')).size : 0;
if (overviewSize < 5000) {
  console.log('Overview seems blank. Waiting longer for Flutter...');
  await page.waitForTimeout(15_000);
  await shot('000_overview_retry.png', 2000);
}

// ─── Scroll through all previews ─────────────────────────────────────────────
const VP_W = 1400;
const MAIN_X = Math.floor(VP_W * 0.65);
const MAIN_Y = 450;

// Scroll to top
await page.mouse.move(MAIN_X, MAIN_Y);
for (let i = 0; i < 30; i++) await page.mouse.wheel(0, -1000);
await page.waitForTimeout(1500);
await shot('001_top.png');

// Scroll-capture
let scrollCount = 0;
for (let s = 0; s < 200; s++) {
  await page.mouse.move(MAIN_X, MAIN_Y);
  await page.mouse.wheel(0, 800);
  await page.waitForTimeout(400);

  await shot(`scroll_${String(s + 1).padStart(3, '0')}.png`, 100);
  scrollCount++;

  const atBottom = await page.evaluate(() =>
    Math.abs(document.documentElement.scrollHeight - window.scrollY - window.innerHeight) < 50
  ).catch(() => false);
  if (atBottom) { console.log(`Bottom at scroll ${s + 1}`); break; }
}

// ─── Individual sidebar navigation ───────────────────────────────────────────
console.log('\nIndividual preview captures via sidebar...');

// Enable semantics first
await page.evaluate(() => {
  const ph = document.querySelector('flt-semantics-placeholder');
  if (ph) ph.click();
});
await page.keyboard.press('Tab');
await page.waitForTimeout(1000);

const SIDEBAR_X = Math.floor(VP_W * 0.12);
const START_Y = 80;
const ITEM_H = 52;
const VISIBLE = Math.floor((900 - START_Y) / ITEM_H);

// Scroll sidebar to top
await page.mouse.move(SIDEBAR_X, 400);
for (let i = 0; i < 30; i++) await page.mouse.wheel(0, -1000);
await page.waitForTimeout(1500);

for (let i = 0; i < previewNames.length; i++) {
  const itemInPage = i % VISIBLE;

  if (itemInPage === 0 && i > 0) {
    await page.mouse.move(SIDEBAR_X, 400);
    await page.mouse.wheel(0, ITEM_H * VISIBLE);
    await page.waitForTimeout(400);
  }

  const clickY = START_Y + itemInPage * ITEM_H;
  await page.mouse.click(SIDEBAR_X, Math.min(clickY, 870));
  await page.waitForTimeout(1200);

  const name = previewNames[i];
  const safeName = name.replace(/[^a-zA-Z0-9_\-\s]/g, '').trim().replace(/\s+/g, '_').slice(0, 60);
  await shot(`p${String(i + 1).padStart(3, '0')}_${safeName}.png`, 100);
}

await browser.close();
const count = fs.readdirSync(OUT_DIR).filter(f => f.endsWith('.png')).length;
console.log(`\n✓ Done. ${count} screenshots in ${OUT_DIR}`);
