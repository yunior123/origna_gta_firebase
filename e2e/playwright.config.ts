import { defineConfig, devices } from '@playwright/test';

const runAllProjects = process.env.E2E_PROJECTS === 'all' || process.env.E2E_ALL_PROJECTS === '1';

export default defineConfig({
  testDir: './playwright_ui',
  testMatch: '**/*.spec.ts',
  testIgnore: ['*.py'],
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: process.env.CI ? 'list' : 'html',
  timeout: 300 * 1000, // 5min per test (Stripe + Flutter init are slow)
  expect: {
    timeout: 15 * 1000,
  },
  use: {
    actionTimeout: 15 * 1000,
    baseURL: process.env.E2E_TARGET_URL ?? 'https://orignagta-dev.web.app',
    trace: 'on-first-retry',
    screenshot: 'on',
    bypassCSP: true,
  },
  outputDir: `${process.env.HOME}/Desktop/origna-screenshots/emulator`,

  projects: [
    ...(runAllProjects
      ? [
        {
          name: 'chromium',
          use: { ...devices['Desktop Chrome'] },
        },
        {
          name: 'webkit',
          use: { ...devices['Desktop Safari'] },
        },
        {
          name: 'Mobile Chrome',
          use: { ...devices['Pixel 5'] },
        },
        {
          name: 'Mobile Safari',
          use: { ...devices['iPhone 12'] },
        },
      ]
      : [
        {
          name: 'chromium',
          use: { ...devices['Desktop Chrome'] },
        },
      ]),
  ],
});
