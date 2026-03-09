/**
 * scroll-shots.mjs
 * ─────────────────────────────────────────────────────────────────────────────
 * Loads the Flutter widget previewer in a fresh headless browser,
 * expands ALL groups in the sidebar, then scrolls through every preview
 * section in the main panel and takes screenshots.
 *
 * Run: PREVIEWER_PORT=52695 node e2e/scroll-shots.mjs
 */

import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import os from 'os';

const PORT = process.env.PREVIEWER_PORT ?? '52695';
const BASE_URL = `http://localhost:${PORT}`;
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-desktop-previews');
fs.mkdirSync(OUT_DIR, { recursive: true });

// ─── Preview names ────────────────────────────────────────────────────────────
const genFile = '/var/folders/bc/650vj62175vcn92kgbffvhzw0000gp/T/flutter_tools.Xqs1Ax/widget_preview_scaffoldh7X1ZG/lib/src/generated_preview.dart';
let allPreviews = [];
if (fs.existsSync(genFile)) {
  const src = fs.readFileSync(genFile, 'utf8');
  // Extract name + group pairs
  const blocks = src.split('WidgetPreview(');
  for (const block of blocks.slice(1)) {
    const name = block.match(/name:\s*'([^']+)'/)?.[1] ?? '';
    const group = block.match(/group:\s*'([^']+)'/)?.[1] ?? 'Default';
    if (name) allPreviews.push({ name, group });
  }
}
console.log(`Total previews: ${allPreviews.length}`);

// ─── Launch headless browser ──────────────────────────────────────────────────
const browser = await chromium.launch({
  headless: true,
  args: [
    '--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage',
    '--enable-webgl', '--use-gl=swiftshader', '--ignore-gpu-blocklist',
  ],
});

const ctx = await browser.newContext({
  viewport: { width: 1400, height: 900 },
  deviceScaleFactor: 1,
});
const page = await ctx.newPage();

console.log(`Loading ${BASE_URL}...`);
await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 30_000 });
await page.waitForTimeout(8000); // wait for Flutter boot

const rendered = await page.evaluate(() => ({
  glassPane: !!document.querySelector('flt-glass-pane'),
  semNodes: document.querySelectorAll('flt-semantics').length,
}));
console.log('Flutter ready:', rendered);

// ─── Expand all groups in the sidebar ────────────────────────────────────────
// The sidebar shows group headers. Click each one to expand.
// After initial load, some groups may be collapsed (showing ▶ icon).
// We need to click ALL group headers to expand them.
//
// Group headers are rendered as large clickable rows in the sidebar.
// The sidebar is in the LEFT ~15% of the viewport (x < ~210px for 1400px).
// Each group header is ~48px tall.
// After groups are expanded, clicking a preview item scrolls to it in main panel.

console.log('\nExpanding all groups...');

// The previewer sidebar: groups are collapsed by default.
// Click systematically at sidebar positions to expand groups.
const SIDEBAR_X = 140;
const START_Y = 30;

// First screenshot to see initial state
await page.screenshot({ path: path.join(OUT_DIR, '000_initial.png'), animations: 'disabled', timeout: 20_000 });
console.log('  → 000_initial.png');

// Try clicking groups to expand them (they toggle on click)
// The previewer shows the list in the right panel by default (all collapsed groups).
// Let's count groups: from the gen file
const groups = [...new Set(allPreviews.map(p => p.group))];
console.log(`Groups (${groups.length}): ${groups.slice(0, 8).join(', ')}...`);

// Click each visible group header in the right panel
// The groups are shown as ExpansionTile in the main panel.
// Click on each one to expand it.
const VP_W = 1400;
const MAIN_X = Math.floor(VP_W * 0.55);
const MAIN_Y_START = 50;
const GROUP_H = 55;

for (let i = 0; i < groups.length; i++) {
  const y = MAIN_Y_START + i * GROUP_H;
  if (y < 880) {
    await page.mouse.click(MAIN_X, y);
    await page.waitForTimeout(200);
  }
}

// Scroll down and keep clicking more groups
await page.mouse.move(MAIN_X, 450);
for (let pass = 0; pass < 3; pass++) {
  await page.mouse.wheel(0, 800);
  await page.waitForTimeout(300);
  // Click anything that might be a group header
  for (let y = 50; y < 880; y += GROUP_H) {
    await page.mouse.click(MAIN_X, y);
    await page.waitForTimeout(150);
  }
}

// Scroll back to top
for (let i = 0; i < 50; i++) await page.mouse.wheel(0, -1000);
await page.waitForTimeout(2000);

await page.screenshot({ path: path.join(OUT_DIR, '001_after_expand.png'), animations: 'disabled', timeout: 20_000 });
console.log('  → 001_after_expand.png');

// ─── Now scroll through and capture everything ────────────────────────────────
console.log('\nScrolling and capturing all previews...');

let shotIdx = 2;
const SCROLL_STEP = 850;

for (let s = 0; s < 300; s++) {
  await page.mouse.move(MAIN_X, 450);
  await page.mouse.wheel(0, SCROLL_STEP);
  await page.waitForTimeout(350);

  const fname = `${String(shotIdx).padStart(3, '0')}_scroll_${s + 1}.png`;
  const outPath = path.join(OUT_DIR, fname);
  try {
    await page.screenshot({ path: outPath, animations: 'disabled', timeout: 12_000 });
    const sz = fs.statSync(outPath).size;
    if (s % 5 === 0) console.log(`  [${s + 1}] ${fname} (${(sz/1024).toFixed(0)}KB)`);
  } catch (e) {
    console.log(`  [${s + 1}] SKIP: ${e.message?.slice(0, 50)}`);
  }
  shotIdx++;

  // Check bottom
  const atBottom = await page.evaluate(() =>
    Math.abs(document.documentElement.scrollHeight - window.scrollY - window.innerHeight) < 50
  ).catch(() => false);
  if (atBottom) { console.log(`  Bottom reached at scroll ${s + 1}`); break; }
}

await browser.close();
const count = fs.readdirSync(OUT_DIR).filter(f => f.endsWith('.png')).length;
console.log(`\n✓ Done. ${count} screenshots in ${OUT_DIR}`);
