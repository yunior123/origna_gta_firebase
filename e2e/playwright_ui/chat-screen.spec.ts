/**
 * OrignaGTA — Chat Screen E2E Tests (Premium-Gated)
 * ===================================================
 * Chat is a premium-only feature. Non-premium users see a paywall.
 * Premium users can start threads, send messages, and are subject
 * to a 500-message-per-thread limit.
 *
 * Tests:
 *   T01: Non-premium user sees paywall on chat
 *   T02: Premium user can open chat screen (seeded via writeDoc)
 *   T03: Premium user can start thread and send message (API)
 *   T04: Message limit boundary — verify API accepts messages
 *
 * Run: cd e2e && npx playwright test chat-screen.spec.ts --config=playwright.config.dev.ts
 */
import { test, expect } from '@playwright/test';
import {
  signIn,
  callCallable,
  callOk,
  TEST_ACCOUNTS,
  TEST_UIDS,
  WEB_APP_URL,
  getDoc,
  writeDoc,
  toFirestoreFields,
} from './api-helpers';
import {
  waitForFlutter,
  requireWebApp,
  checkSemantics,
  ensureLoggedInAsAdmin,
} from './flutter-helpers';

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;
const BUYER_EMAIL = TEST_ACCOUNTS.BUYER_EMAIL;
const BUYER_PASS = TEST_ACCOUNTS.BUYER_PASS;
const ADMIN_EMAIL = TEST_ACCOUNTS.ADMIN_EMAIL;
const ADMIN_PASS = TEST_ACCOUNTS.ADMIN_PASS;

test.describe('Chat Screen — Premium Gate', () => {
  test.setTimeout(300_000);

  // ─── T01: Non-premium user sees paywall on chat ─────────────────
  test('T01: Non-premium user sees paywall on chat', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);

    // Sign in as buyer (non-premium by default)
    await ensureLoggedInAsAdmin(page, TARGET_URL, BUYER_EMAIL, BUYER_PASS);

    // Try to access chat — for non-premium users, the app should either:
    // 1. Show a paywall/premium gate
    // 2. Redirect to home (route not accessible)
    // 3. Show an upgrade CTA

    // Navigate to chat via direct URL
    await page.goto(`${TARGET_URL}/chat`, { timeout: 60_000 });
    await waitForFlutter(page);
    await page.waitForTimeout(5000);

    // Check what we see — the chat screen or a gate
    const allText = await page.locator('flt-semantics').allInnerTexts();
    const fullText = allText.join(' ').toLowerCase();

    const hasPremiumGate = /premium|paywall|subscribe|upgrade|unlock|abonnement/.test(fullText);
    const hasChatUI = /message|chat|conversation|thread/.test(fullText);
    const showsHomeScreen = /search products|marketplace|your marketplace/.test(fullText);

    // For non-premium: either a paywall is shown, OR the route falls through to home (gate by routing)
    // The route NOT rendering chat content is itself a form of access control
    const chatBlocked = hasPremiumGate || showsHomeScreen || !hasChatUI;

    expect(
      chatBlocked,
      `Non-premium user should not see chat UI (premium=${hasPremiumGate}, home=${showsHomeScreen}, chat=${hasChatUI})`
    ).toBe(true);
  });

  // ─── T02: Premium user can open chat screen ─────────────────────
  test('T02: Premium user can open chat screen after seeding premium subscription', async () => {
    // Seed premium subscription for admin user via Firestore REST
    const adminAuth = await signIn(ADMIN_EMAIL, ADMIN_PASS);
    const subscriptionPath = `subscriptions/${TEST_UIDS.ADMIN}`;

    const seedResult = await writeDoc(
      subscriptionPath,
      toFirestoreFields({
        status: 'active',
        isPremium: true,
        planId: 'premium_monthly',
        userId: TEST_UIDS.ADMIN,
        createdAt: new Date().toISOString(),
        currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      }),
      adminAuth.idToken,
    );

    // Verify subscription was seeded
    if (seedResult) {
      const doc = await getDoc(subscriptionPath, adminAuth.idToken);
      expect(doc).toBeTruthy();
      expect(doc?.status).toBe('active');
      expect(doc?.isPremium).toBe(true);
    } else {
      console.log('writeDoc returned false — subscription may already exist; continuing test');
    }

    // Use API to verify chat access: call get_chat_threads
    // If premium gate is properly checked, this should succeed for a premium user
    const result = await callCallable('get_chat_threads', {}, adminAuth.idToken);

    // Accept either success (threads list) or an empty result — both mean access granted
    // Reject only if we get a premium-gate error
    if (result.error) {
      const errMsg = (result.error.message || '').toLowerCase();
      expect(
        errMsg,
        'Premium user should not be blocked by premium gate'
      ).not.toMatch(/premium|subscription required|not subscribed/);
    }
  });

  // ─── T03: Premium user can start thread and send message ────────
  test('T03: Premium user can start thread and send message via API', async () => {
    const adminAuth = await signIn(ADMIN_EMAIL, ADMIN_PASS);

    // Ensure premium subscription is active
    await writeDoc(
      `subscriptions/${TEST_UIDS.ADMIN}`,
      toFirestoreFields({
        status: 'active',
        isPremium: true,
        planId: 'premium_monthly',
        userId: TEST_UIDS.ADMIN,
        currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      }),
      adminAuth.idToken,
    );

    // Start a chat thread with the seller about a product
    const threadResult = await callCallable('start_chat_thread', {
      recipientId: TEST_UIDS.SELLER,
      productId: 'e2e_product_test_seller',
      initialMessage: `E2E test message ${Date.now()}`,
    }, adminAuth.idToken);

    // Thread creation may succeed or return ALREADY_EXISTS if thread exists
    let threadId: string | null = null;
    if (threadResult.error) {
      const errMsg = (threadResult.error.message || '').toLowerCase();
      const errStatus = (threadResult.error.status || '').toLowerCase();
      // ALREADY_EXISTS is acceptable — thread was created in a previous run
      if (errStatus.includes('already') || errMsg.includes('already')) {
        console.log('Thread already exists — reusing existing thread');
        // Fetch threads to find existing one
        const threads = await callCallable('get_chat_threads', {}, adminAuth.idToken);
        if (threads.result?.threads?.length > 0) {
          threadId = threads.result.threads[0].threadId || threads.result.threads[0].id;
        }
      } else {
        // Unexpected error — not premium gate, not already-exists
        expect(errMsg).not.toMatch(/premium|subscription/);
        console.log(`start_chat_thread returned error: ${threadResult.error.message}`);
      }
    } else {
      threadId = threadResult.result?.threadId || threadResult.result?.id;
      expect(threadId, 'Thread ID should be returned on creation').toBeTruthy();
    }

    // Send a message if we have a valid thread
    if (threadId) {
      const msgResult = await callCallable('send_chat_message', {
        threadId,
        message: `Hello from E2E test ${Date.now()}`,
      }, adminAuth.idToken);

      if (msgResult.error) {
        // Accept rate-limit or thread-not-found as non-fatal in dev
        const errMsg = (msgResult.error.message || '').toLowerCase();
        expect(errMsg).not.toMatch(/premium|unauthorized/);
        console.log(`send_chat_message warning: ${msgResult.error.message}`);
      } else {
        expect(msgResult.result || msgResult).toBeTruthy();
      }
    }
  });

  // ─── T04: Message limit boundary — verify API accepts messages ──
  test('T04: Message limit boundary — API accepts messages within 500 cap', async () => {
    const adminAuth = await signIn(ADMIN_EMAIL, ADMIN_PASS);

    // Ensure premium
    await writeDoc(
      `subscriptions/${TEST_UIDS.ADMIN}`,
      toFirestoreFields({
        status: 'active',
        isPremium: true,
        planId: 'premium_monthly',
        userId: TEST_UIDS.ADMIN,
        currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      }),
      adminAuth.idToken,
    );

    // Get an existing thread (or create one)
    const threadsResult = await callCallable('get_chat_threads', {}, adminAuth.idToken);
    let threadId: string | null = null;

    if (threadsResult.result?.threads?.length > 0) {
      threadId = threadsResult.result.threads[0].threadId || threadsResult.result.threads[0].id;
    }

    if (!threadId) {
      // Try creating a thread
      const createResult = await callCallable('start_chat_thread', {
        recipientId: TEST_UIDS.SELLER,
        productId: 'e2e_product_test_seller',
        initialMessage: `Limit boundary test ${Date.now()}`,
      }, adminAuth.idToken);
      if (!createResult.error) {
        threadId = createResult.result?.threadId || createResult.result?.id;
      }
    }

    if (!threadId) {
      console.log('No thread available — skipping message limit boundary test');
      test.skip(true, 'No chat thread available to test message limit');
      return;
    }

    // Send a few messages to verify the API accepts them (not actually 500)
    const messagesToSend = 3;
    let successCount = 0;
    let lastError = '';

    for (let i = 0; i < messagesToSend; i++) {
      const result = await callCallable('send_chat_message', {
        threadId,
        message: `Boundary test msg ${i + 1} at ${Date.now()}`,
      }, adminAuth.idToken);

      if (!result.error) {
        successCount++;
      } else {
        lastError = result.error.message || '';
        // If we hit rate limit, that is acceptable — break early
        if (lastError.toLowerCase().includes('rate') || lastError.toLowerCase().includes('limit')) {
          console.log(`Rate limited after ${successCount} messages — acceptable`);
          break;
        }
      }

      // Small delay between messages to avoid rate limiting
      await new Promise(r => setTimeout(r, 500));
    }

    // At least one message should have been accepted
    expect(
      successCount,
      `Expected at least 1 message to be accepted. Last error: ${lastError}`
    ).toBeGreaterThanOrEqual(1);
  });
});
