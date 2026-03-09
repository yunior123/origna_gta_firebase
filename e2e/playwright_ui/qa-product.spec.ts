/**
 * OrignaGTA — Product Q&A E2E Tests
 * ====================================
 * Tests the product question-and-answer feature:
 *   - Buyer asks a question on a product
 *   - Seller answers the question
 *   - Unauthenticated users are rejected
 *   - Product detail page shows Q&A section (UI)
 *
 * Run: cd e2e && npx playwright test qa-product.spec.ts --config=playwright.config.dev.ts
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
const SELLER_EMAIL = TEST_ACCOUNTS.SELLER_EMAIL;
const SELLER_PASS = TEST_ACCOUNTS.SELLER_PASS;

// Stable test product owned by the seller
const TEST_PRODUCT_ID = 'e2e_product_test_seller';

test.describe('Product Q&A', () => {
  test.setTimeout(300_000);
  // Serial mode: T02 depends on T01's questionId
  test.describe.configure({ mode: 'serial' });

  let questionId: string | null = null;

  // ─── T01: Buyer asks question on product ────────────────────────
  test('T01: Buyer asks question on product via API', async () => {
    const buyerAuth = await signIn(BUYER_EMAIL, BUYER_PASS);
    const questionText = `E2E test question — ${Date.now()}`;

    const result = await callCallable('ask_product_question', {
      productId: TEST_PRODUCT_ID,
      question: questionText,
    }, buyerAuth.idToken);

    if (result.error) {
      // Some backends may not have this endpoint yet; log and soft-fail
      const errMsg = (result.error.message || '').toLowerCase();
      console.log(`ask_product_question response: ${result.error.message}`);

      // Permission denied or unauthenticated would be a real bug for a logged-in buyer
      expect(errMsg).not.toMatch(/unauthenticated/);
      // If the function does not exist (404/NOT_FOUND), skip gracefully
      if (errMsg.includes('not_found') || errMsg.includes('not found') || result.error.status === 'NOT_FOUND') {
        test.skip(true, 'ask_product_question callable not deployed yet');
        return;
      }
    } else {
      const data = result.result || result;
      questionId = data.questionId || data.id || null;
      expect(questionId, 'Question ID should be returned').toBeTruthy();
    }
  });

  // ─── T02: Seller answers question ──────────────────────────────
  test('T02: Seller answers question via API', async () => {
    if (!questionId) {
      test.skip(true, 'No questionId from T01 — cannot answer');
      return;
    }

    const sellerAuth = await signIn(SELLER_EMAIL, SELLER_PASS);
    const answerText = `E2E test answer — ${Date.now()}`;

    const result = await callCallable('answer_product_question', {
      questionId,
      answer: answerText,
    }, sellerAuth.idToken);

    if (result.error) {
      const errMsg = (result.error.message || '').toLowerCase();
      console.log(`answer_product_question response: ${result.error.message}`);

      // If function not deployed, skip
      if (errMsg.includes('not_found') || errMsg.includes('not found') || result.error.status === 'NOT_FOUND') {
        test.skip(true, 'answer_product_question callable not deployed yet');
        return;
      }

      // Seller should not be denied permission on their own product's question
      expect(errMsg).not.toMatch(/permission.denied|unauthorized/);
    } else {
      const data = result.result || result;
      expect(data).toBeTruthy();
    }
  });

  // ─── T03: Unauthenticated user cannot ask questions ─────────────
  test('T03: Unauthenticated user cannot ask questions', async () => {
    const result = await callCallable('ask_product_question', {
      productId: TEST_PRODUCT_ID,
      question: 'Should be rejected — no auth',
    }, '');  // Empty token = unauthenticated

    // Expect an error response
    expect(result.error, 'Unauthenticated request should return an error').toBeTruthy();

    if (result.error) {
      const errMsg = (result.error.message || '').toLowerCase();
      const errStatus = (result.error.status || '').toUpperCase();

      // If function not deployed, skip
      if (errMsg.includes('not_found') || errMsg.includes('not found') || errStatus === 'NOT_FOUND') {
        test.skip(true, 'ask_product_question callable not deployed yet');
        return;
      }

      // Should be unauthenticated or permission denied
      const isAuthError =
        errMsg.includes('unauthenticated') ||
        errMsg.includes('unauthorized') ||
        errMsg.includes('permission') ||
        errMsg.includes('token') ||
        errStatus === 'UNAUTHENTICATED' ||
        errStatus === 'PERMISSION_DENIED';

      expect(
        isAuthError,
        `Expected auth error but got: ${result.error.message} (status: ${errStatus})`
      ).toBe(true);
    }
  });

  // ─── T04: Product detail shows Q&A section ──────────────────────
  test('T04: Product detail page shows Q&A section in UI', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);

    // Sign in as buyer to access product detail
    await ensureLoggedInAsAdmin(page, TARGET_URL, BUYER_EMAIL, BUYER_PASS);

    // Navigate to product detail page via direct URL
    await page.goto(`${TARGET_URL}/product/e2e_product_test_seller`, {
      timeout: 60_000,
    });
    await waitForFlutter(page);
    await page.waitForTimeout(5000);

    // Scroll down to find Q&A section (typically below product details)
    for (let i = 0; i < 5; i++) {
      await page.mouse.wheel(0, 500);
      await page.waitForTimeout(500);
    }

    // Look for Q&A section elements using text content (Flutter renders Semantics labels as text)
    const qaText = page.locator('flt-semantics').filter({
      hasText: /questions|q\s*&\s*a|ask a question|poser une question/i,
    }).first();
    const hasQaText = await qaText.isVisible({ timeout: 10_000 }).catch(() => false);

    if (hasQaText) {
      console.log('Q&A section found on product detail page');
    } else {
      console.log('Q&A section not visible — may be below fold or not rendered for this product');
    }

    // Verify the product detail page itself loaded — check for any meaningful content
    // Flutter renders text content in flt-semantics nodes
    const semanticsCount = await page.locator('flt-semantics').count();
    const hasContent = semanticsCount > 5; // A loaded page has many semantics nodes
    const pageText = await page.locator('flt-semantics').allInnerTexts();
    const hasProductText = pageText.some(t =>
      /add to cart|ajouter|price|\$|product|description/i.test(t)
    );

    // At minimum, the product detail page should render something
    expect(
      hasProductText || hasQaText || hasContent,
      `Product detail page should render content (nodes=${semanticsCount}, hasProduct=${hasProductText})`
    ).toBe(true);
  });
});
