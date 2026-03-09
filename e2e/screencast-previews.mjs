/**
 * screencast-previews.mjs
 * ─────────────────────────────────────────────────────────────────────────────
 * Uses Chrome's Page.startScreencast CDP command to capture frames without
 * blocking. Completely bypasses the font-loading hang in Page.captureScreenshot.
 *
 * Run:
 *   CDP_PORT=52724 node e2e/screencast-previews.mjs
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

// DO NOT call setViewportSize — it breaks things on Retina displays.
// The viewport is already set to the window's natural size.
const viewport = page.viewportSize();
console.log('Current viewport:', viewport);

// ─── CDP session for non-blocking screenshots ─────────────────────────────────
const session = await ctx.newCDPSession(page);

let latestFrame = null;

session.on('Page.screencastFrame', async (event) => {
  latestFrame = event.data;
  // Ack the frame to keep receiving
  await session.send('Page.screencastFrameAck', { sessionId: event.sessionId }).catch(() => {});
});

// Start screencast at a high quality to capture the Flutter content
await session.send('Page.startScreencast', {
  format: 'png',
  quality: 100,
  maxWidth: viewport?.width ?? 1200,
  maxHeight: viewport?.height ?? 700,
  everyNthFrame: 1,
});

// Wait for first frame
await page.waitForTimeout(3000);

async function captureFrame(filename, settleMs = 1000) {
  latestFrame = null;
  // Wait for a fresh frame
  let waited = 0;
  while (!latestFrame && waited < 5000) {
    await page.waitForTimeout(200);
    waited += 200;
  }
  if (!latestFrame) {
    console.log(`  [${filename}] no frame received`);
    return false;
  }
  const outPath = path.join(OUT_DIR, filename);
  fs.writeFileSync(outPath, Buffer.from(latestFrame, 'base64'));
  const size = fs.statSync(outPath).size;
  console.log(`  → ${filename} (${(size / 1024).toFixed(0)}KB)`);
  return true;
}

// ─── Read preview names ───────────────────────────────────────────────────────
const genFile = '/var/folders/bc/650vj62175vcn92kgbffvhzw0000gp/T/flutter_tools.Xqs1Ax/widget_preview_scaffoldh7X1ZG/lib/src/generated_preview.dart';
let previewNames = [];
if (fs.existsSync(genFile)) {
  const src = fs.readFileSync(genFile, 'utf8');
  previewNames = [...src.matchAll(/name:\s*'([^']+)'/g)].map(m => m[1]);
}
console.log(`Previews: ${previewNames.length}`);

// ─── Overview ────────────────────────────────────────────────────────────────
await captureFrame('000_overview.png');

// ─── Scroll to top ────────────────────────────────────────────────────────────
// The Flutter widget previewer is a web app. The main panel is on the right side.
// Let's scroll through by using the mouse wheel in the main content area.
const MAIN_X = Math.floor((viewport?.width ?? 1200) * 0.65); // 65% = right panel
const MAIN_Y = Math.floor((viewport?.height ?? 700) * 0.5);

// Scroll to top
await page.mouse.move(MAIN_X, MAIN_Y);
for (let i = 0; i < 40; i++) await page.mouse.wheel(0, -800);
await page.waitForTimeout(2000);
await captureFrame('001_scrolled_to_top.png');

// ─── Scroll-based screenshots (captures all previews in list view) ─────────
console.log('\nScroll-based capture...');
const SCROLL_STEP = 750;
for (let scroll = 0; scroll < 200; scroll++) {
  await page.mouse.move(MAIN_X, MAIN_Y);
  await page.mouse.wheel(0, SCROLL_STEP);
  await page.waitForTimeout(500);

  const fname = `scroll_${String(scroll + 1).padStart(3, '0')}.png`;
  await captureFrame(fname, 500);

  // Check bottom
  const atBottom = await page.evaluate(() =>
    Math.abs(document.documentElement.scrollHeight - window.scrollY - window.innerHeight) < 100
  ).catch(() => false);
  if (atBottom) { console.log(`Bottom at scroll ${scroll + 1}`); break; }
}

// ─── Individual preview captures via sidebar clicks ───────────────────────────
console.log('\nIndividual preview captures...');

// Scroll sidebar back to top
const SIDEBAR_X = Math.floor((viewport?.width ?? 1200) * 0.12);
await page.mouse.move(SIDEBAR_X, 200);
for (let i = 0; i < 40; i++) await page.mouse.wheel(0, -800);
await page.waitForTimeout(1500);

const SIDEBAR_START_Y = 80;
const ITEM_H = 52;
const N = previewNames.length;
const VISIBLE_ITEMS = Math.floor(((viewport?.height ?? 700) - SIDEBAR_START_Y) / ITEM_H);

for (let i = 0; i < N; i++) {
  const itemInPage = i % VISIBLE_ITEMS;

  if (itemInPage === 0 && i > 0) {
    // Scroll sidebar
    await page.mouse.move(SIDEBAR_X, 300);
    await page.mouse.wheel(0, ITEM_H * VISIBLE_ITEMS);
    await page.waitForTimeout(400);
  }

  const clickY = SIDEBAR_START_Y + itemInPage * ITEM_H;
  await page.mouse.click(SIDEBAR_X, Math.min(clickY, (viewport?.height ?? 700) - 20));
  await page.waitForTimeout(1200);

  const name = previewNames[i] ?? `preview_${i + 1}`;
  const safeName = name.replace(/[^a-zA-Z0-9_\-\s]/g, '').trim().replace(/\s+/g, '_').slice(0, 60);
  await captureFrame(`p${String(i + 1).padStart(3, '0')}_${safeName}.png`);
}

await session.send('Page.stopScreencast');
await browser.close();

const files = fs.readdirSync(OUT_DIR).filter(f => f.endsWith('.png'));
console.log(`\n✓ Done. ${files.length} screenshots in ${OUT_DIR}`);
