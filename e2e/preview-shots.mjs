/**
 * preview-shots.mjs
 * ─────────────────────────────────────────────────────────────────────────────
 * Screenshots the Flutter widget previewer at desktop.
 * Patches document.fonts.ready → resolved immediately so Playwright's
 * font-wait doesn't block the screenshot.
 *
 * Run:
 *   CDP_PORT=52724 node e2e/preview-shots.mjs
 */

import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import os from 'os';

const CDP_PORT = process.env.CDP_PORT ?? '52724';
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-desktop-previews');
fs.mkdirSync(OUT_DIR, { recursive: true });

// ─── helpers ─────────────────────────────────────────────────────────────────

function patchFonts(page) {
  return page.evaluate(() => {
    try {
      // Make document.fonts.ready resolve immediately so Playwright screenshot won't hang.
      Object.defineProperty(document.fonts, 'ready', {
        get: () => Promise.resolve(document.fonts),
        configurable: true,
      });
      Object.defineProperty(document.fonts, 'status', {
        get: () => 'loaded',
        configurable: true,
      });
    } catch (_) { /* may fail if already defined */ }
  });
}

async function shot(page, filename) {
  await patchFonts(page);
  const outPath = path.join(OUT_DIR, filename);
  await page.screenshot({
    path: outPath,
    fullPage: false,
    animations: 'disabled',
    timeout: 15_000,
  });
  console.log(`  → ${filename}`);
}

// ─── connect ─────────────────────────────────────────────────────────────────

const browser = await chromium.connectOverCDP(`http://localhost:${CDP_PORT}`);
const ctx = browser.contexts()[0];
const page = ctx.pages().find(p => p.url().includes('localhost')) ?? ctx.pages()[0];
console.log('Connected:', page.url());
await page.setViewportSize({ width: 1440, height: 900 });
await page.waitForTimeout(2000);

// ─── read preview names ───────────────────────────────────────────────────────

const genFile = '/var/folders/bc/650vj62175vcn92kgbffvhzw0000gp/T/flutter_tools.Xqs1Ax/widget_preview_scaffoldh7X1ZG/lib/src/generated_preview.dart';
let previewNames = [];
if (fs.existsSync(genFile)) {
  const src = fs.readFileSync(genFile, 'utf8');
  previewNames = [...src.matchAll(/name:\s*'([^']+)'/g)].map(m => m[1]);
}
console.log(`Previews to capture: ${previewNames.length}`);

// ─── overview screenshot ─────────────────────────────────────────────────────
await shot(page, '000_overview.png');

// ─── The previewer shows all previews in a scrollable list on the right panel.
//     The left sidebar (~250px) lists them for navigation. Clicking a sidebar
//     item scrolls/highlights the right panel. BUT all previews are also
//     rendered in the right panel at once (list mode).
//
//     Strategy: scroll the MAIN panel (right side) to each preview section
//     and screenshot each section. This is the most reliable approach since
//     the sidebar interaction is fragile (no aria labels on list items).
//
//     The right panel starts at approximately x=250px (after the sidebar).
// ─────────────────────────────────────────────────────────────────────────────

// Scroll the main area using mouse wheel positioned in the right panel
const MAIN_X = 800;
const MAIN_Y = 450;

// Scroll back to the very top first
await page.mouse.move(MAIN_X, MAIN_Y);
for (let i = 0; i < 30; i++) {
  await page.mouse.wheel(0, -500);
}
await page.waitForTimeout(1500);

await shot(page, '001_top.png');

// Now take a series of screenshots as we scroll through all previews
// Each preview in list mode takes roughly 300-600px of height (at 1440px viewport)
// For 136 previews, total scroll height ≈ 50,000-80,000px
// We'll take screenshots every ~800px

let screenshotCount = 2;
const SCROLL_STEP = 800;
const MAX_SCROLLS = 200; // safety limit

for (let scroll = 0; scroll < MAX_SCROLLS; scroll++) {
  await page.mouse.move(MAIN_X, MAIN_Y);
  await page.mouse.wheel(0, SCROLL_STEP);
  await page.waitForTimeout(400);

  const fname = `${String(screenshotCount).padStart(3, '0')}_scroll_${scroll * SCROLL_STEP}.png`;
  await shot(page, fname);
  screenshotCount++;

  // Check if we've reached the bottom
  const atBottom = await page.evaluate(() => {
    return window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 50;
  });
  if (atBottom) {
    console.log(`Reached bottom of page at scroll ${scroll}`);
    break;
  }
}

await browser.close();
console.log(`\n✓ Done. ${screenshotCount} screenshots in ${OUT_DIR}`);
