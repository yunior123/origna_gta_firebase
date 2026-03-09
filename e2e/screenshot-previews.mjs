/**
 * screenshot-previews.mjs
 * Connects to the running Flutter widget previewer via CDP and screenshots
 * every preview item at desktop (1440×900).
 *
 * Run: node e2e/screenshot-previews.mjs
 */

import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import os from 'os';

const CDP_PORT = process.env.CDP_PORT ?? '52724';
const PREVIEWER_URL = process.env.PREVIEWER_URL ?? 'http://localhost:52695';
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-desktop-previews');
const SETTLE_MS = 3000;

fs.mkdirSync(OUT_DIR, { recursive: true });

const browser = await chromium.connectOverCDP(`http://localhost:${CDP_PORT}`);
const contexts = browser.contexts();
console.log(`Connected. Contexts: ${contexts.length}`);

const ctx = contexts[0];
const pages = ctx.pages();
console.log(`Pages: ${pages.length}`);

const page = pages.find(p => p.url().includes('localhost')) ?? pages[0];
console.log(`Active page: ${page.url()}`);

// Resize to desktop
await page.setViewportSize({ width: 1440, height: 900 });
await page.waitForTimeout(2000);

// Screenshot the full previewer UI first
await page.screenshot({ path: path.join(OUT_DIR, '000_previewer_overview.png'), fullPage: false });
console.log('Saved overview screenshot');

// Flutter widget previewer uses flt-semantics when semantics are on.
// Try to get the list of preview items via the previewer's JS state.
// The previewer scaffold exposes preview list via window or dart:js interop.

// Strategy: use Flutter semantics tree to find clickable preview items in the sidebar.
// Activate semantics first.
await page.evaluate(() => {
  // Flutter exposes semantics via keyboard event or placeholder click
  const placeholder = document.querySelector('flt-semantics-placeholder');
  if (placeholder) placeholder.click();
});
await page.keyboard.press('Tab');
await page.waitForTimeout(1000);

// Count semantics nodes
const semCount = await page.locator('flt-semantics').count();
console.log(`Semantics nodes: ${semCount}`);

if (semCount === 0) {
  // Semantics not enabled. Fall back to evaluating the previewer's internal state.
  // The Flutter widget previewer scaffold has a Dart-side list of all previews.
  // We can read the DOM for any data attributes or the page title changes.
  console.log('No semantics. Trying URL-based navigation...');

  // Try common URL schemes for widget previewer
  const previewUrl = `${PREVIEWER_URL}`;
  const resp = await page.goto(previewUrl, { waitUntil: 'networkidle', timeout: 30_000 }).catch(() => null);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(OUT_DIR, '001_no_semantics.png') });
  console.log('Saved no-semantics fallback screenshot');

  await browser.close();
  process.exit(0);
}

// Get all flt-semantics elements that have button role or appear clickable (in sidebar)
const allSemNodes = await page.locator('flt-semantics').all();
console.log(`Total flt-semantics nodes: ${allSemNodes.length}`);

// The sidebar in the previewer has a list of preview names.
// Find nodes that have aria-label or contain text (preview names are labels).
const clickableItems = [];
for (const node of allSemNodes) {
  const label = await node.getAttribute('aria-label').catch(() => null);
  const role = await node.getAttribute('role').catch(() => null);
  if (label && label.trim() && role === 'button') {
    clickableItems.push({ node, label });
  }
}

console.log(`Clickable button items: ${clickableItems.length}`);

// If we found sidebar items, screenshot each one
if (clickableItems.length > 0) {
  for (let i = 0; i < clickableItems.length; i++) {
    const { node, label } = clickableItems[i];
    const safeName = label.replace(/[^a-zA-Z0-9_\-\s]/g, '').trim().replace(/\s+/g, '_').slice(0, 80);
    try {
      await node.click({ force: true });
      await page.waitForTimeout(SETTLE_MS);
      const outPath = path.join(OUT_DIR, `${String(i + 1).padStart(3, '0')}_${safeName}.png`);
      await page.screenshot({ path: outPath, fullPage: false, animations: 'disabled' });
      console.log(`[${i + 1}/${clickableItems.length}] ${label} → ${outPath}`);
    } catch (e) {
      console.log(`  [SKIP] ${label}: ${e}`);
    }
  }
} else {
  // No clickable items found — take a full overview and dump all aria-labels
  console.log('No clickable sidebar items found via semantics.');
  const allLabels = [];
  for (const node of allSemNodes.slice(0, 50)) {
    const label = await node.getAttribute('aria-label').catch(() => null);
    if (label) allLabels.push(label);
  }
  console.log('Sample labels:', allLabels.slice(0, 20));
  await page.screenshot({ path: path.join(OUT_DIR, '001_debug_state.png'), fullPage: true });
}

await browser.close();
console.log(`\nDone. Screenshots saved to ${OUT_DIR}`);
