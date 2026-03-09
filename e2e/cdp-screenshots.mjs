/**
 * cdp-screenshots.mjs
 * Uses raw CDP to take screenshots of the Flutter widget previewer,
 * bypassing Playwright's font-loading wait that causes timeouts.
 *
 * Run: CDP_PORT=52724 node e2e/cdp-screenshots.mjs
 */

import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import os from 'os';

const CDP_PORT = process.env.CDP_PORT ?? '52724';
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-desktop-previews');
fs.mkdirSync(OUT_DIR, { recursive: true });

// Connect via CDP
const browser = await chromium.connectOverCDP(`http://localhost:${CDP_PORT}`);
const ctx = browser.contexts()[0];
const page = ctx.pages().find(p => p.url().includes('localhost')) ?? ctx.pages()[0];

// Get the raw CDP session
const cdpSession = await page.context().newCDPSession(page);

console.log('Connected:', page.url());
await page.setViewportSize({ width: 1440, height: 900 });
await page.waitForTimeout(3000);

async function cdpScreenshot(filename) {
  try {
    const result = await cdpSession.send('Page.captureScreenshot', {
      format: 'png',
      fromSurface: true,
      captureBeyondViewport: false,
    });
    const outPath = path.join(OUT_DIR, filename);
    fs.writeFileSync(outPath, Buffer.from(result.data, 'base64'));
    console.log(`  → saved: ${filename}`);
    return true;
  } catch (e) {
    console.log(`  → FAIL: ${e.message?.slice(0, 80)}`);
    return false;
  }
}

// Overview
await cdpScreenshot('000_overview.png');

// Now extract all preview names from the generated_preview.dart
const SCAFFOLD_DIR = '/var/folders/bc/650vj62175vcn92kgbffvhzw0000gp/T/flutter_tools.Xqs1Ax/widget_preview_scaffoldh7X1ZG';
const genPreviewPath = path.join(SCAFFOLD_DIR, 'lib/src/generated_preview.dart');
let previewNames = [];
if (fs.existsSync(genPreviewPath)) {
  const content = fs.readFileSync(genPreviewPath, 'utf8');
  const matches = [...content.matchAll(/name:\s*'([^']+)'/g)];
  previewNames = matches.map(m => m[1]);
  console.log(`Found ${previewNames.length} preview names from generated file`);
}

// The previewer shows all previews in the main panel as a scrollable list.
// Each preview is rendered inside an ExpansionTile (grouped by @Preview.group).
// We can navigate by scrolling the main Flutter canvas area.

// Get page total scroll height by scrolling via JS
const scrollInfo = await page.evaluate(() => {
  // Flutter intercepts pointer events on the glass pane.
  // The actual scroll happens on the flutter view, not the window.
  // Return info about the page structure.
  const glassPane = document.querySelector('flt-glass-pane');
  const body = document.body;
  return {
    windowScrollHeight: document.documentElement.scrollHeight,
    bodyScrollHeight: body.scrollHeight,
    glassPaneH: glassPane ? glassPane.scrollHeight : 0,
    innerH: window.innerHeight,
    innerW: window.innerWidth,
  };
});
console.log('\nScroll info:', scrollInfo);

// Approach: use keyboard navigation to cycle through previews.
// The Flutter widget previewer likely supports keyboard navigation.
// Press Tab to focus sidebar, then Arrow Down to select each preview.

// First, focus the Flutter glass pane
await page.evaluate(() => {
  const gp = document.querySelector('flt-glass-pane');
  if (gp) gp.focus();
  // Simulate a click in the sidebar area (left ~250px, top ~100px)
});

// Click the sidebar area (left panel) to focus it
await page.mouse.click(200, 100);
await page.waitForTimeout(500);

await cdpScreenshot('001_after_sidebar_click.png');

// Now try pressing down arrow to navigate previews
// The previewer uses a NavigationDrawer or ListView for the sidebar
// Let's try: Tab to navigate into the list, then arrows

for (let i = 0; i < 5; i++) {
  await page.keyboard.press('Tab');
  await page.waitForTimeout(200);
}

await cdpScreenshot('002_after_tabs.png');

// Try clicking each preview in the sidebar by position
// The sidebar is ~250px wide. Preview list starts at around y=50.
// Each item is ~48px tall.

console.log('\nClicking through sidebar items...');
const SIDEBAR_X = 130;
const SIDEBAR_START_Y = 60;
const ITEM_HEIGHT = 48;
const N_ITEMS = Math.min(previewNames.length || 30, 50);

// First, click once to ensure the sidebar is focused
await page.mouse.click(SIDEBAR_X, SIDEBAR_START_Y);
await page.waitForTimeout(800);

for (let i = 0; i < N_ITEMS; i++) {
  const clickY = SIDEBAR_START_Y + i * ITEM_HEIGHT;

  // If we're past the viewport height, scroll the sidebar
  if (clickY > 850) {
    // Scroll the sidebar
    await page.evaluate((dy) => {
      // Try scrolling via pointer events on the sidebar area
      window.scrollBy(0, dy);
    }, ITEM_HEIGHT * 5);
    await page.waitForTimeout(300);
  }

  await page.mouse.click(SIDEBAR_X, Math.min(clickY, 850));
  await page.waitForTimeout(1200); // wait for preview to render

  const name = previewNames[i] ?? `item_${i + 1}`;
  const safeName = name.replace(/[^a-zA-Z0-9_\-\s]/g, '').trim().replace(/\s+/g, '_').slice(0, 60);
  await cdpScreenshot(`${String(i + 1).padStart(3, '0')}_${safeName}.png`);
}

await cdpSession.detach();
await browser.close();

console.log(`\n✓ Done. ${N_ITEMS + 3} screenshots in ${OUT_DIR}`);
