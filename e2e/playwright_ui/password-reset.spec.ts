import { test, expect } from '@playwright/test';
import { waitForFlutter } from './flutter-helpers';

test.describe('Password Reset Routing', () => {
  // Valid-format oobCode (10+ alphanumeric chars) — triggers routing but Firebase rejects it
  const FAKE_OOB = 'fake_oob_code_123456789';

  test('should render ResetPasswordScreen when mode=resetPassword is in URL', async ({ page, baseURL }) => {
    await page.goto(`${baseURL}/?mode=resetPassword&oobCode=${FAKE_OOB}`);
    await waitForFlutter(page);

    // Firebase rejects the fake oobCode immediately → error state shows "Go to Login"
    // This confirms ResetPasswordScreen was rendered (routing worked)
    await expect(page.getByLabel('Go to Login'))
      .toBeVisible({ timeout: 25000 });
  });

  test('should show error and Go to Login when oobCode is invalid/expired', async ({ page, baseURL }) => {
    await page.goto(`${baseURL}/?mode=resetPassword&oobCode=${FAKE_OOB}`);
    await waitForFlutter(page);

    // After Firebase rejects the invalid code, error state shows "Go to Login" button
    const goToLoginBtn = page.getByLabel('Go to Login');
    await expect(goToLoginBtn).toBeVisible({ timeout: 25000 });

    // Password form must NOT be visible for invalid oobCode
    await expect(page.getByLabel('New Password')).not.toBeVisible();
  });

  test('should reject URL with invalid oobCode format', async ({ page, baseURL }) => {
    // Malformed oobCode (less than 10 chars) must not route to ResetPasswordScreen
    await page.goto(`${baseURL}/?mode=resetPassword&oobCode=short`);
    await waitForFlutter(page);

    // Should fall through to home/auth page — Go to Login button from ResetPasswordScreen not present
    await expect(page.getByLabel('Go to Login')).not.toBeVisible({ timeout: 5000 });
  });
});
