// playwright.config.dev.ts — Dev environment (orignagta-dev Firebase)
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './playwright_ui',
  testMatch: '**/*.spec.ts',
  testIgnore: ['*.py'],
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 1,
  workers: process.env.CI ? 1 : 4,
  reporter: process.env.CI ? 'list' : 'html',
  timeout: 300 * 1000,
  expect: { timeout: 15 * 1000 },
  globalSetup: './playwright_ui/global-setup.ts',
  use: {
    actionTimeout: 15 * 1000,
    baseURL: process.env.E2E_TARGET_URL ?? 'https://orignagta-dev.web.app',
    trace: 'on-first-retry',
    screenshot: 'on',
    bypassCSP: true,
  },
  outputDir: `${process.env.HOME}/Desktop/origna-screenshots/dev`,
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
