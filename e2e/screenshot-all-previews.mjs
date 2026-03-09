/**
 * screenshot-all-previews.mjs
 * ─────────────────────────────────────────────────────────────────────────────
 * Screenshots every Flutter Widget Preview at desktop (1440×900).
 *
 * Strategy: The previewer sidebar has unlabeled buttons. We click them all
 * by index, settle, screenshot the main content area only (right panel).
 *
 * Run:
 *   CDP_PORT=52724 PREVIEWER_URL=http://localhost:52695 node e2e/screenshot-all-previews.mjs
 */

import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import os from 'os';

const CDP_PORT = process.env.CDP_PORT ?? '52724';
const PREVIEWER_URL = process.env.PREVIEWER_URL ?? 'http://localhost:52695';
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-desktop-previews');
const SETTLE_MS = 2000;

fs.mkdirSync(OUT_DIR, { recursive: true });

const browser = await chromium.connectOverCDP(`http://localhost:${CDP_PORT}`);
const ctx = browser.contexts()[0];
const page = ctx.pages().find(p => p.url().includes('localhost')) ?? ctx.pages()[0];

console.log('Connected to:', page.url());
await page.setViewportSize({ width: 1440, height: 900 });
await page.waitForTimeout(2000);

// ── Explore the Flutter state to find preview list ────────────────────────────
const flutterInfo = await page.evaluate(() => {
  const state = window.__flutterState;
  if (!state) return { error: '__flutterState not found' };
  return {
    keys: Object.keys(state),
    stateStr: JSON.stringify(state).slice(0, 500),
  };
});
console.log('Flutter state:', JSON.stringify(flutterInfo, null, 2));

// ── Try to get preview names from the Dart state ─────────────────────────────
// The previewer uses DDS (Dart Development Service). Try reading from window.
const previewData = await page.evaluate(() => {
  // Try common ways the previewer might expose preview list
  const checks = {};

  // Check if there's a preview manifest in the page
  const scripts = Array.from(document.querySelectorAll('script')).map(s => s.src || s.innerText?.slice(0, 100));
  checks.scriptCount = scripts.length;

  // Try reading the DDS/DTD state
  if (window._flutter?.loader) {
    checks.loaderKeys = Object.keys(window._flutter.loader);
  }

  // Check if dart:developer postMessage reveals info
  checks.dartLoader = window.$dartLoader ? Object.keys(window.$dartLoader).slice(0, 10) : null;

  return checks;
});
console.log('Preview data checks:', JSON.stringify(previewData, null, 2));

// ── Read preview manifest from disk ──────────────────────────────────────────
// The previewer writes a manifest to /tmp during scaffold creation.
// We already know: /var/folders/bc/650vj62175vcn92kgbffvhzw0000gp/T/flutter_tools.Xqs1Ax/widget_preview_scaffoldh7X1ZG/
import { execSync } from 'child_process';

let previewNames = [];
try {
  const manifestPath = execSync(
    "find /var/folders -name 'preview_manifest.json' 2>/dev/null | head -1",
    { encoding: 'utf8', timeout: 5000 }
  ).trim();
  console.log('\nManifest path:', manifestPath);
  if (manifestPath) {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    console.log('Manifest keys:', Object.keys(manifest));
    console.log('Manifest sample:', JSON.stringify(manifest).slice(0, 500));
    // Extract preview names/ids
    if (Array.isArray(manifest)) {
      previewNames = manifest.map(p => p.name ?? p.id ?? JSON.stringify(p).slice(0, 40));
    } else if (manifest.previews) {
      previewNames = manifest.previews.map(p => p.name ?? p.id ?? JSON.stringify(p).slice(0, 40));
    } else {
      previewNames = Object.keys(manifest);
    }
  }
} catch (e) {
  console.log('Manifest read error:', e.message);
}
console.log(`\nPreview names from manifest (${previewNames.length}):`, previewNames.slice(0, 10));

// ── Find sidebar clickable items ──────────────────────────────────────────────
// Enable semantics first
await page.evaluate(() => {
  const ph = document.querySelector('flt-semantics-placeholder');
  if (ph) ph.click();
});
await page.keyboard.press('Tab');
await page.waitForTimeout(1500);

// The previewer sidebar: all flt-semantics buttons that are NOT inside the preview area.
// The preview area is on the right side (larger). The sidebar is on the left (narrow).
// Strategy: find ALL flt-semantics[role=button] by their x position.
// Sidebar items are on the left side (x < 300px for a 1440px viewport).

const sidebarItems = await page.evaluate(() => {
  const allButtons = document.querySelectorAll('flt-semantics[role="button"]');
  const items = [];
  for (const btn of allButtons) {
    const rect = btn.getBoundingClientRect();
    // Sidebar is roughly the left 15% of the viewport (< 216px for 1440px)
    if (rect.x < 250 && rect.width > 20 && rect.height > 10) {
      items.push({
        x: rect.x,
        y: rect.y,
        w: rect.width,
        h: rect.height,
        label: btn.getAttribute('aria-label'),
      });
    }
  }
  return items;
});

console.log(`\nSidebar items by position (x<250): ${sidebarItems.length}`);
sidebarItems.slice(0, 10).forEach((item, i) => console.log(`  [${i}] x=${item.x.toFixed(0)},y=${item.y.toFixed(0)} w=${item.w.toFixed(0)} h=${item.h.toFixed(0)} label=${item.label}`));

// ── Screenshot full overview ──────────────────────────────────────────────────
await page.screenshot({ path: path.join(OUT_DIR, '000_overview.png'), fullPage: false });
console.log('\nSaved overview.');

// ── Click each sidebar item and screenshot ────────────────────────────────────
if (sidebarItems.length > 0) {
  let idx = 1;
  // Sort by y position (top to bottom = order in sidebar)
  sidebarItems.sort((a, b) => a.y - b.y);

  for (const item of sidebarItems) {
    try {
      await page.mouse.click(item.x + item.w / 2, item.y + item.h / 2);
      await page.waitForTimeout(SETTLE_MS);

      const name = item.label ?? `item_${idx}`;
      const safeName = name.replace(/[^a-zA-Z0-9_\-]/g, '_').slice(0, 80);
      const outPath = path.join(OUT_DIR, `${String(idx).padStart(3, '0')}_${safeName}.png`);
      await page.screenshot({ path: outPath, fullPage: false, animations: 'disabled' });
      console.log(`[${idx}] ${name} → saved`);
      idx++;
    } catch (e) {
      console.log(`[${idx}] SKIP: ${e.message?.slice(0, 80)}`);
      idx++;
    }
  }
} else {
  console.log('\nNo sidebar items found. Dumping full page screenshot for debugging.');
  await page.screenshot({ path: path.join(OUT_DIR, '001_debug.png'), fullPage: true });
}

await browser.close();
console.log(`\nComplete. Saved to ${OUT_DIR}`);
