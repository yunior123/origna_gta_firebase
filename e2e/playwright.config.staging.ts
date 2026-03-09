// playwright.config.staging.ts — Staging environment (orignagta-staging.web.app)
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './playwright_ui',
  testMatch: '**/*.spec.ts',
  testIgnore: ['*.py'],
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: process.env.CI ? 'list' : 'html',
  timeout: 300 * 1000,
  expect: { timeout: 20 * 1000 },
  use: {
    actionTimeout: 20 * 1000,
    baseURL: process.env.E2E_TARGET_URL ?? 'https://orignagta-staging.web.app',
    trace: 'on-first-retry',
    screenshot: 'on',
    bypassCSP: true,
  },
  outputDir: `${process.env.HOME}/Desktop/origna-screenshots/staging`,
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
