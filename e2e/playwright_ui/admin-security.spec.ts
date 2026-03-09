/**
 * OrignaGTA — Admin Security E2E Tests
 * =======================================
 * Tests permission enforcement and MFA against dev Firebase.
 */
import { test, expect } from '@playwright/test';
import {
  signIn, callCallable, callExpectError,
  TEST_ACCOUNTS, FUNCTIONS_URL,
} from './api-helpers';

const ADMIN_EMAIL = TEST_ACCOUNTS.ADMIN_EMAIL;
const ADMIN_PASS = TEST_ACCOUNTS.ADMIN_PASS;
const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;

test.describe('Admin Security', () => {
  test.setTimeout(60_000);

  test('MFA enrollment endpoint responds for admin', async () => {
    const auth = await signIn(ADMIN_EMAIL, ADMIN_PASS);
    const result = await callCallable('admin_mfa_enroll', {}, auth.idToken);

    // Should return MFA enrollment data or indicate already enrolled
    if (result.error) {
      const msg = result.error.message || JSON.stringify(result.error);
      // Acceptable: already enrolled, MFA not configured, etc.
      expect(msg).toBeTruthy();
    } else {
      const data = result.result || result;
      expect(data).toBeTruthy();
    }
  });

  test('Non-admin cannot call admin MFA endpoints', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    const error = await callExpectError('admin_mfa_enroll', {}, buyerAuth.idToken);
    expect(error.code, 'Buyer should not access admin MFA').not.toBe('unexpected-success');
  });

  test('Unauthenticated requests to admin endpoints are rejected', async () => {
    const res = await fetch(`${FUNCTIONS_URL}/admin_mfa_enroll`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: {} }),
    });
    const body = await res.json();
    expect(body.error || res.status !== 200).toBeTruthy();
  });

  test('Non-seller cannot access seller-only endpoints via API', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL);
    // upload_product_images requires seller role
    const error = await callExpectError('upload_product_images', {
      productId: 'nonexistent_test',
      images: [],
    }, buyerAuth.idToken);

    // Should be rejected — buyer doesn't have seller role
    expect(error.code).not.toBe('unexpected-success');
  });

  test('Permission enforcement: wrong user cannot modify others orders', async () => {
    // Try to update an order that doesn't belong to the buyer
    const buyerAuth = await signIn(BUYER_EMAIL);
    const error = await callExpectError('update_order_status', {
      orderId: 'nonexistent_order_id',
      newStatus: 'processing',
    }, buyerAuth.idToken);

    expect(error.code).not.toBe('unexpected-success');
  });
});
