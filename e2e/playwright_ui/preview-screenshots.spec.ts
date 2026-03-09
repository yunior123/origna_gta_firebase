/**
 * preview-screenshots.spec.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Screenshots every Flutter Widget Preview at desktop (1440×900).
 * Saves to ~/Desktop/origna-desktop-previews/<group>/<name>.png
 *
 * Run:
 *   npx playwright test preview-screenshots.spec.ts --config e2e/playwright.config.preview.ts
 */

import { test, chromium } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

const PREVIEWER_URL = process.env.PREVIEWER_URL ?? 'http://localhost:5555';
const OUT_DIR = path.join(os.homedir(), 'Desktop', 'origna-desktop-previews');
const DESKTOP_W = 1440;
const DESKTOP_H = 900;
const SETTLE_MS = 2500;

test.describe('Widget Preview Screenshots — Desktop', () => {
  test.describe.configure({ mode: 'serial' });
  test.setTimeout(20 * 60 * 1000);

  test('screenshot all previews', async () => {
    const browser = await chromium.launch({ headless: true });
    const ctx = await browser.newContext({ viewport: { width: DESKTOP_W, height: DESKTOP_H } });
    const page = await ctx.newPage();

    fs.mkdirSync(OUT_DIR, { recursive: true });

    await page.goto(PREVIEWER_URL, { waitUntil: 'networkidle', timeout: 60_000 });
    await page.waitForTimeout(4000);

    // The Flutter widget previewer renders an iframe per preview.
    // The sidebar lists all preview items. Each item has data attributes or text.
    // Collect all preview list items.
    const items = await page.locator('[data-preview-id], [data-testid*="preview"], li[role="option"]').all();

    console.log(`Found ${items.length} preview items via role selectors`);

    // Fallback: try all sidebar clickable items
    const sidebarItems = await page.locator('aside li, [class*="sidebar"] li, [class*="list-item"], [class*="PreviewListItem"]').all();
    console.log(`Sidebar items found: ${sidebarItems.length}`);

    const allItems = items.length > 0 ? items : sidebarItems;

    let count = 0;
    for (let i = 0; i < allItems.length; i++) {
      try {
        const item = allItems[i];
        const text = (await item.textContent() ?? '').trim().replace(/[^a-zA-Z0-9_\-\s]/g, '').trim();
        if (!text) continue;

        await item.click();
        await page.waitForTimeout(SETTLE_MS);

        const safeName = text.replace(/\s+/g, '_').slice(0, 80);
        const outPath = path.join(OUT_DIR, `${String(i).padStart(3, '0')}_${safeName}.png`);

        await page.screenshot({ path: outPath, fullPage: false, animations: 'disabled' });
        console.log(`[${i + 1}/${allItems.length}] ${safeName} → ${outPath}`);
        count++;
      } catch (e) {
        console.log(`  [SKIP] item ${i}: ${e}`);
      }
    }

    await browser.close();
    console.log(`\nDone. ${count} screenshots saved to ${OUT_DIR}`);
  });
});
