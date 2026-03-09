/**
 * Playwright Global Setup — pre-authenticate all test accounts before workers start.
 * This prevents QUOTA_EXCEEDED when 8 workers all try to sign in simultaneously.
 * Tokens are written to /tmp/origna_e2e_tokens.json and loaded by each worker.
 */
import { signIn, TEST_ACCOUNTS, DEFAULT_PASS } from './api-helpers';

export default async function globalSetup() {
  console.log('🔑 Pre-warming auth tokens...');
  // Clear stale cache
  try { require('fs').unlinkSync('/tmp/origna_e2e_tokens.json'); } catch {}
  // Sign in all accounts sequentially to avoid quota
  await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
  await signIn(TEST_ACCOUNTS.SELLER_EMAIL, DEFAULT_PASS);
  await signIn(TEST_ACCOUNTS.BUYER_EMAIL, DEFAULT_PASS);
  console.log('✅ Auth tokens cached to disk for all workers');
}
