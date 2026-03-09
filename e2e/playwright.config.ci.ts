// playwright.config.ci.ts — CI-safe subset (excludes tests requiring full Stripe UI checkout)
// Tests excluded: stripe-payment, payment-edge-cases, multi-seller-orders, order-cancellation-refund,
//                 order-lifecycle, shipping-approval
// Reason: Stripe's hosted checkout page does not reliably complete in headless GitHub Actions.
// Run these locally or on staging where interactive browser is available.
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './playwright_ui',
  testMatch: '**/*.spec.ts',
  testIgnore: [
    '*.py',
    '**/stripe-payment.spec.ts',
    '**/payment-edge-cases.spec.ts',
    '**/multi-seller-orders.spec.ts',
    '**/order-cancellation-refund.spec.ts',
    '**/order-lifecycle.spec.ts',
    '**/shipping-approval.spec.ts',
  ],
  fullyParallel: true,
  forbidOnly: true,
  retries: 1,
  workers: 1,
  reporter: 'list',
  timeout: 300 * 1000,
  expect: { timeout: 15 * 1000 },
  use: {
    actionTimeout: 15 * 1000,
    baseURL: process.env.E2E_TARGET_URL ?? 'http://localhost:5005',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    bypassCSP: true,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
