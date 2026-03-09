/**
 * macos-preview-shots.mjs
 * ─────────────────────────────────────────────────────────────────────────────
 * Scrolls through the Flutter widget previewer using Playwright for interaction,
 * then uses macOS screencapture for the actual screenshots (bypasses CDP hang).
 *
 * Run:
 *   CDP_PORT=52724 node e2e/macos-preview-shots.mjs
 */

import { chromium } from 'playwright';
import { execSync, spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import os from 'os';

const CDP_PORT = process.env.CDP_PORT ?? '52724';
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-desktop-previews');
fs.mkdirSync(OUT_DIR, { recursive: true });

// ─── Get Chrome window bounds via AppleScript ─────────────────────────────────
function getChromeWindowBounds() {
  try {
    const raw = execSync(`osascript -e '
tell application "Google Chrome"
  set theWin to front window
  set b to bounds of theWin
  return (item 1 of b) & "," & (item 2 of b) & "," & (item 3 of b) & "," & (item 4 of b)
end tell'`, { encoding: 'utf8' }).trim();
    const [left, top, right, bottom] = raw.split(',').map(Number);
    const TAB_BAR_H = 75; // Chrome tabs + address bar height
    return {
      x: left,
      y: top + TAB_BAR_H,
      w: right - left,
      h: bottom - top - TAB_BAR_H,
    };
  } catch (e) {
    console.log('Could not get window bounds:', e.message);
    return { x: 22, y: 122, w: 1200, h: 671 };
  }
}

// ─── Take screenshot via macOS screencapture ──────────────────────────────────
function macScreenshot(filename) {
  const b = getChromeWindowBounds();
  const outPath = path.join(OUT_DIR, filename);
  spawnSync('screencapture', [
    '-R', `${b.x},${b.y},${b.w},${b.h}`,
    '-x',  // no sound
    outPath,
  ], { stdio: 'inherit' });
  console.log(`  → ${filename}`);
}

// ─── Connect to Chrome via Playwright (for interaction only) ─────────────────
const browser = await chromium.connectOverCDP(`http://localhost:${CDP_PORT}`);
const ctx = browser.contexts()[0];
const page = ctx.pages().find(p => p.url().includes('localhost')) ?? ctx.pages()[0];
console.log('Connected:', page.url());
await page.setViewportSize({ width: 1440, height: 900 });
await page.waitForTimeout(1500);

// ─── Bring Chrome to front ────────────────────────────────────────────────────
execSync(`osascript -e 'tell application "Google Chrome" to activate'`);
await page.waitForTimeout(1000);

// ─── Read preview names ───────────────────────────────────────────────────────
const genFile = '/var/folders/bc/650vj62175vcn92kgbffvhzw0000gp/T/flutter_tools.Xqs1Ax/widget_preview_scaffoldh7X1ZG/lib/src/generated_preview.dart';
let previewNames = [];
if (fs.existsSync(genFile)) {
  const src = fs.readFileSync(genFile, 'utf8');
  previewNames = [...src.matchAll(/name:\s*'([^']+)'/g)].map(m => m[1]);
}
console.log(`Total previews: ${previewNames.length}`);

// ─── Overview screenshot ──────────────────────────────────────────────────────
macScreenshot('000_overview.png');

// ─── Scroll to top ────────────────────────────────────────────────────────────
const MAIN_X = 900; // center of the right (main) panel
const MAIN_Y = 450;
await page.mouse.move(MAIN_X, MAIN_Y);
for (let i = 0; i < 50; i++) {
  await page.mouse.wheel(0, -1000);
}
await page.waitForTimeout(1500);
macScreenshot('001_top.png');

// ─── Scroll strategy ─────────────────────────────────────────────────────────
// Each preview in the main panel is roughly 200-900px tall.
// For 136 previews ≈ 50,000-100,000px total.
// We take a screenshot every SCROLL_STEP pixels.
// This gives ~50-100 screenshots covering all previews.
const SCROLL_STEP = 850; // ~1 viewport height
const MAX_SHOTS = 150;

let shotIdx = 2;
let atBottom = false;

while (!atBottom && shotIdx < MAX_SHOTS + 2) {
  // Scroll down
  await page.mouse.move(MAIN_X, MAIN_Y);
  await page.mouse.wheel(0, SCROLL_STEP);
  await page.waitForTimeout(600); // let Flutter render

  // Check if we're at the bottom
  atBottom = await page.evaluate(() => {
    const el = document.documentElement;
    return Math.abs(el.scrollHeight - el.scrollTop - el.clientHeight) < 100;
  }).catch(() => false);

  const fname = `${String(shotIdx).padStart(3, '0')}_scroll_${(shotIdx - 1) * SCROLL_STEP}.png`;
  macScreenshot(fname);
  shotIdx++;

  if (atBottom) {
    console.log('Reached bottom.');
    break;
  }
}

console.log(`\n✓ ${shotIdx} scroll screenshots taken.`);

// ─── Now click through sidebar items for individual preview shots ─────────────
// The previewer sidebar is in the left ~250px of the Chrome content area.
// Sidebar items are listed with groups. Clicking a sidebar item scrolls
// to that preview and highlights it.
//
// Since we can't get aria labels, we'll click at evenly-spaced y positions
// in the sidebar, cycling through all items by scrolling the sidebar.

console.log('\nCapturing individual previews via sidebar clicks...');

// Scroll back to top first
await page.mouse.move(MAIN_X, MAIN_Y);
for (let i = 0; i < 50; i++) await page.mouse.wheel(0, -1000);
await page.waitForTimeout(1500);

const SIDEBAR_X = 140; // center of left sidebar panel
const SIDEBAR_Y_START = 100;
const ITEM_H = 52; // approximate item height in sidebar
const N = previewNames.length;
const ITEMS_VISIBLE = Math.floor((800 - SIDEBAR_Y_START) / ITEM_H); // items visible in sidebar

let sidebarScroll = 0;
const SIDEBAR_PAGE_SIZE = ITEMS_VISIBLE * ITEM_H;

for (let i = 0; i < N; i++) {
  const itemInPage = i % ITEMS_VISIBLE;

  // If we've gone through a full page of sidebar items, scroll the sidebar
  if (itemInPage === 0 && i > 0) {
    sidebarScroll += SIDEBAR_PAGE_SIZE;
    await page.mouse.move(SIDEBAR_X, 400);
    await page.mouse.wheel(0, SIDEBAR_PAGE_SIZE);
    await page.waitForTimeout(500);
  }

  const clickY = SIDEBAR_Y_START + itemInPage * ITEM_H;
  await page.mouse.click(SIDEBAR_X, clickY);
  await page.waitForTimeout(1000); // wait for preview to scroll/render

  const name = previewNames[i] ?? `item_${i + 1}`;
  const safeName = name.replace(/[^a-zA-Z0-9_\-\s]/g, '').trim().replace(/\s+/g, '_').slice(0, 60);
  const fname = `p${String(i + 1).padStart(3, '0')}_${safeName}.png`;
  macScreenshot(fname);
}

await browser.close();
console.log(`\n✓ Done. All screenshots in: ${OUT_DIR}`);
console.log(`Total files: ${fs.readdirSync(OUT_DIR).length}`);
