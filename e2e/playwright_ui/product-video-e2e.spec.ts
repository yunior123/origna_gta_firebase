import { test, expect } from '@playwright/test';
import {
    waitForFlutter,
    requireWebApp,
    ensureLoggedIn,
    navigateHome,
    uniqueSuffix,
    BTN_ADD_PRODUCT,
} from './flutter-helpers';
import * as path from 'path';

const TARGET_URL = process.env.E2E_TARGET_URL ?? 'http://localhost:5005';
const ADMIN_EMAIL = process.env.E2E_ADMIN_EMAIL ?? 'yr62813@gmail.com';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'REDACTED_TEST_PASSWORD';

test.beforeEach(async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    await ensureLoggedIn(page, TARGET_URL, ADMIN_EMAIL, ADMIN_PASSWORD);
});

test.describe('Product Video Flow', () => {
  test.setTimeout(300_000);

    test('T01: Upload valid video and verify playback UI state', async ({ page }, testInfo) => {
        const { workerIndex, parallelIndex } = testInfo;
        const suffix = uniqueSuffix({ workerIndex, parallelIndex });
        const productName = `Video Test ${suffix}`;

        // 1. Navigate to Add Product
        await page.getByRole('button', { name: BTN_ADD_PRODUCT }).click();
        await waitForFlutter(page);

        // 2. Fill basic info
        await page.getByRole('textbox', { name: 'Product Name' }).click();
        await page.keyboard.type(productName);
        await page.getByRole('textbox', { name: 'Price (CAD)' }).click();
        await page.keyboard.type('10.00');
        await page.getByRole('textbox', { name: 'Stock' }).click();
        await page.keyboard.type('5');

        // 3. Upload Video
        const videoPath = path.resolve(__dirname, '../assets/test_video_valid.mp4');
        const [fileChooser] = await Promise.all([
            page.waitForEvent('filechooser'),
            page.locator('[aria-label="btn-add-video"]').click(),
        ]);
        await fileChooser.setFiles(videoPath);

        // Wait for video to initialize (preview remove button should appear)
        await page.locator('[aria-label="btn-remove-video"]').waitFor({ state: 'visible', timeout: 30000 });

        // 4. Verification of UI presence
        await expect(page.locator('flt-semantics:has-text("Video")')).toBeVisible();
    });

    // T02 and T03 require test asset files > 100MB and > 1 minute duration respectively.
    // The current stub assets (15KB, 57KB) are too small to trigger validation.
    // TODO: Generate proper-sized test assets via a script before these tests can run.
    test.skip('T02: Validation - Oversized video', async ({ page }) => {
        await page.getByRole('button', { name: BTN_ADD_PRODUCT }).click();
        await waitForFlutter(page);

        const videoPath = path.resolve(__dirname, '../assets/test_video_too_large.mp4');
        const [fileChooser] = await Promise.all([
            page.waitForEvent('filechooser'),
            page.locator('[aria-label="btn-add-video"]').first().click(),
        ]);
        await fileChooser.setFiles(videoPath);

        // Verify error snackbar content (English or French)
        const errorText = page.locator('flt-semantics').filter({ hasText: /exceeds 100MB|dépasse la limite de 100 Mo/i });
        await expect(errorText.first()).toBeVisible({ timeout: 15000 });
    });

    test.skip('T03: Validation - Overly long video', async ({ page }) => {
        await page.getByRole('button', { name: BTN_ADD_PRODUCT }).click();
        await waitForFlutter(page);

        const videoPath = path.resolve(__dirname, '../assets/test_video_too_long.mp4');
        const [fileChooser] = await Promise.all([
            page.waitForEvent('filechooser'),
            page.locator('[aria-label="btn-add-video"]').first().click(),
        ]);
        await fileChooser.setFiles(videoPath);

        const errorText = page.locator('flt-semantics').filter({ hasText: /exceeds 1 minute|dépasse la limite de 1 minute/i });
        await expect(errorText.first()).toBeVisible({ timeout: 15000 });
    });
});
