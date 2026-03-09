/**
 * screenshot-previewer.mjs
 * ─────────────────────────────────────────────────────────────────────────────
 * Connects to the running Flutter widget previewer via CDP, scrolls through
 * the preview panel, and takes a screenshot every ~900px of content.
 * Also attempts to click sidebar items one by one.
 *
 * Run: CDP_PORT=52724 PREVIEWER_URL=http://localhost:52695 node e2e/screenshot-previewer.mjs
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
await page.waitForTimeout(3000);

// ─── 1. Full-page scroll screenshot ──────────────────────────────────────────
// Get the total scrollable height of the page
const totalHeight = await page.evaluate(() => {
  const body = document.querySelector('flt-glass-pane') ?? document.body;
  return document.body.scrollHeight;
});
console.log(`Total scroll height: ${totalHeight}px`);

// Scroll through the page taking viewport-sized screenshots
const vpHeight = 900;
const scrollStep = 800;
let scrollY = 0;
let chunk = 1;

while (scrollY <= totalHeight + vpHeight) {
  await page.evaluate((y) => window.scrollTo(0, y), scrollY);
  await page.waitForTimeout(600);

  const outPath = path.join(OUT_DIR, `scroll_${String(chunk).padStart(3, '0')}_y${scrollY}.png`);
  try {
    await page.screenshot({
      path: outPath,
      fullPage: false,
      animations: 'disabled',
      timeout: 10000,
    });
    console.log(`[scroll ${chunk}] y=${scrollY} → saved`);
  } catch (e) {
    console.log(`[scroll ${chunk}] SKIP: ${e.message?.slice(0, 60)}`);
  }

  scrollY += scrollStep;
  chunk++;
  if (chunk > 80) break; // safety
}

// ─── 2. Try to get the content area dimensions via Flutter canvas ─────────────
const canvasInfo = await page.evaluate(() => {
  const canvas = document.querySelector('canvas');
  if (!canvas) return null;
  return { w: canvas.width, h: canvas.height, style: canvas.getAttribute('style')?.slice(0, 100) };
});
console.log('\nCanvas info:', canvasInfo);

// ─── 3. Scroll back to top and look at the sidebar ───────────────────────────
await page.evaluate(() => window.scrollTo(0, 0));
await page.waitForTimeout(1000);

// Look for sidebar items: flutter renders the sidebar as a widget.
// The previewer scaffold has a NavigationRail or a narrow left column.
// At 1440px, the sidebar is ~280px wide.
// The flutter glass pane covers the whole viewport.
// We need to click in the SIDEBAR area.

// Get all semantics nodes and their actual positions
const semData = await page.evaluate(() => {
  const all = document.querySelectorAll('flt-semantics');
  return Array.from(all).map((el, i) => {
    const r = el.getBoundingClientRect();
    return {
      i,
      role: el.getAttribute('role'),
      label: el.getAttribute('aria-label'),
      x: Math.round(r.x),
      y: Math.round(r.y),
      w: Math.round(r.width),
      h: Math.round(r.height),
    };
  });
});

console.log(`\nAll semantics nodes (${semData.length} total):`);
// Show first 20 nodes with any position in left column (x < 300)
const leftNodes = semData.filter(n => n.x >= 0 && n.x < 300 && n.w > 0);
console.log(`Left-panel nodes (x < 300): ${leftNodes.length}`);
leftNodes.slice(0, 20).forEach(n =>
  console.log(`  [${n.i}] x=${n.x},y=${n.y} ${n.w}x${n.h} role=${n.role} label=${n.label?.slice(0,40)}`)
);

// Find list items in the sidebar (likely role=generic or no role, with small heights, on left side)
const sidebarCandidates = semData.filter(n =>
  n.x >= 0 && n.x < 300 &&
  n.y >= 0 && n.y < 900 &&
  n.h > 20 && n.h < 80 &&
  n.w > 50
);
console.log(`\nSidebar candidates: ${sidebarCandidates.length}`);
sidebarCandidates.forEach(n =>
  console.log(`  [${n.i}] x=${n.x},y=${n.y} ${n.w}x${n.h} role=${n.role} label=${n.label?.slice(0,40)}`)
);

await browser.close();
console.log(`\nDone. Screenshots in: ${OUT_DIR}`);
