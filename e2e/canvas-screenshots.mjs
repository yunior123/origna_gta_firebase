/**
 * canvas-screenshots.mjs
 * Screenshots the Flutter CanvasKit previewer by reading the WebGL canvas
 * directly — bypasses Playwright's font-loading wait completely.
 *
 * Run: CDP_PORT=52724 node e2e/canvas-screenshots.mjs
 */

import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import os from 'os';

const CDP_PORT = process.env.CDP_PORT ?? '52724';
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-desktop-previews');
fs.mkdirSync(OUT_DIR, { recursive: true });

const browser = await chromium.connectOverCDP(`http://localhost:${CDP_PORT}`);
const ctx = browser.contexts()[0];
const page = ctx.pages().find(p => p.url().includes('localhost')) ?? ctx.pages()[0];
console.log('Connected:', page.url());

await page.setViewportSize({ width: 1440, height: 900 });
await page.waitForTimeout(2000);

// Screenshot via canvas.toDataURL (bypasses font-wait)
async function canvasScreenshot(filename) {
  const dataUrl = await page.evaluate(() => {
    // Flutter CanvasKit uses a WebGL canvas
    const canvases = document.querySelectorAll('canvas');
    if (canvases.length === 0) return null;

    // Find the largest canvas (main rendering canvas)
    let largest = null, maxArea = 0;
    for (const c of canvases) {
      const area = c.width * c.height;
      if (area > maxArea) { maxArea = area; largest = c; }
    }
    if (!largest) return null;

    // For WebGL canvas, we need to preserve drawing buffer
    // or use a 2D canvas fallback
    try {
      return largest.toDataURL('image/png');
    } catch(e) {
      // WebGL might need preserveDrawingBuffer
      return `ERROR: ${e.message}`;
    }
  });

  if (!dataUrl || dataUrl.startsWith('ERROR')) {
    console.log(`  CANVAS FAIL: ${dataUrl}`);
    return false;
  }

  const base64 = dataUrl.replace(/^data:image\/png;base64,/, '');
  const outPath = path.join(OUT_DIR, filename);
  fs.writeFileSync(outPath, Buffer.from(base64, 'base64'));
  console.log(`  → ${filename} (${(base64.length * 0.75 / 1024).toFixed(0)}KB)`);
  return true;
}

// Test first screenshot
const ok = await canvasScreenshot('000_overview.png');
if (!ok) {
  console.log('\nCanvas approach failed. Trying screenshot with font-hack...');

  // Hack: override document.fonts to resolve immediately
  await page.addInitScript(() => {
    Object.defineProperty(document, 'fonts', {
      get: () => ({
        ready: Promise.resolve(new FontFaceSet()),
        status: 'loaded',
        check: () => true,
        load: () => Promise.resolve([]),
        forEach: () => {},
        [Symbol.iterator]: function*() {},
        size: 0,
      }),
    });
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(5000);
}

// Read preview names
const SCAFFOLD_DIR = '/var/folders/bc/650vj62175vcn92kgbffvhzw0000gp/T/flutter_tools.Xqs1Ax/widget_preview_scaffoldh7X1ZG';
const genPreviewPath = path.join(SCAFFOLD_DIR, 'lib/src/generated_preview.dart');
let previewNames = [];
if (fs.existsSync(genPreviewPath)) {
  const content = fs.readFileSync(genPreviewPath, 'utf8');
  const matches = [...content.matchAll(/name:\s*'([^']+)'/g)];
  previewNames = matches.map(m => m[1]);
}
console.log(`\nPreview names: ${previewNames.length}`);

// Navigate through sidebar by clicking at known positions
// The previewer sidebar is in the left panel.
// After extensive analysis, the sidebar items are at approximately:
// x ≈ 130-150px (center of sidebar), varying y positions

// The previewer renders a NavigationDrawer on the left.
// Looking at the Flutter widget previewer source (widget_preview_rendering.dart):
// It uses a SplitView with left panel width ~280px.
// Inside: ExpansionTile for each group, ListTile for each preview.
// ListTile height ≈ 48-56px. Groups are collapsed by default.

// Strategy:
// 1. Click on the left panel to focus it
// 2. Click on group headers to expand them
// 3. Click on preview items
// 4. Take canvas screenshot

console.log('\nNavigating through previews...');
await page.mouse.click(140, 50);
await page.waitForTimeout(500);

await canvasScreenshot('001_after_first_click.png');

// Now scroll down through the left panel using mouse wheel
// The sidebar should be scrollable
for (let scroll = 0; scroll < 5; scroll++) {
  await page.mouse.wheel(0, 300);
  await page.waitForTimeout(400);
}
await canvasScreenshot('002_after_scroll.png');

// Reset scroll
await page.mouse.move(140, 400);
for (let scroll = 0; scroll < 5; scroll++) {
  await page.mouse.wheel(0, -300);
  await page.waitForTimeout(300);
}

// Click systematically at different y positions in the sidebar
const N = Math.min(previewNames.length, 136);
const SIDEBAR_X = 140;
const START_Y = 60;
const STEP = 48;

let screenshotted = 0;
let yOffset = 0;

for (let i = 0; i < N; i++) {
  let clickY = START_Y + (i * STEP) - yOffset;

  // If click position is too low, scroll the sidebar
  if (clickY > 820) {
    const scrollAmt = STEP * 5;
    yOffset += scrollAmt;
    await page.mouse.move(SIDEBAR_X, 400);
    await page.mouse.wheel(0, scrollAmt);
    await page.waitForTimeout(400);
    clickY = START_Y + (i * STEP) - yOffset;
  }

  if (clickY < 0 || clickY > 900) continue;

  await page.mouse.click(SIDEBAR_X, clickY);
  await page.waitForTimeout(1500); // wait for preview render

  const name = previewNames[i] ?? `preview_${i + 1}`;
  const safeName = name.replace(/[^a-zA-Z0-9_\-\s]/g, '').trim().replace(/\s+/g, '_').slice(0, 60);
  const fname = `${String(i + 1).padStart(3, '0')}_${safeName}.png`;

  if (await canvasScreenshot(fname)) {
    screenshotted++;
  }
}

await browser.close();
console.log(`\n✓ Done. ${screenshotted} screenshots saved to ${OUT_DIR}`);
