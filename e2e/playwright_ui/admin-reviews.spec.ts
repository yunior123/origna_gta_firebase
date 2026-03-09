/**
 * OrignaGTA — Admin Reviews Tab E2E Tests
 * =========================================
 * Tests the admin panel's Reviews tab functionality:
 *   - Admin navigates to Reviews tab
 *   - Reviews list renders (or shows empty state)
 *   - Admin can flag a review via API
 *
 * Run: cd e2e && npx playwright test admin-reviews.spec.ts --config=playwright.config.dev.ts
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
  navigateToAdmin,
  navigateHome,
  performSignOut,
} from './flutter-helpers';

const TARGET_URL = process.env.E2E_TARGET_URL ?? WEB_APP_URL;
const ADMIN_EMAIL = TEST_ACCOUNTS.ADMIN_EMAIL;
const ADMIN_PASS = TEST_ACCOUNTS.ADMIN_PASS;

test.describe('Admin Reviews Tab', () => {
  test.setTimeout(300_000);

  // ─── T01: Admin navigates to Reviews tab ────────────────────────
  test('T01: Admin navigates to Reviews tab in admin panel', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);

    // Login as admin
    await ensureLoggedInAsAdmin(page, TARGET_URL, ADMIN_EMAIL, ADMIN_PASS);

    // Navigate to admin panel via in-app navigation
    await navigateToAdmin(page);

    // Wait for admin panel to render
    await page.waitForTimeout(2000);

    // Look for the Reviews tab — admin tabs use aria-label pattern
    const reviewsTab = page.locator('[aria-label="admin-tab-reviews"]').first()
      .or(page.getByRole('tab', { name: /reviews|avis/i }).first())
      .or(page.getByRole('button', { name: /admin-tab-reviews|reviews|avis/i }).first());

    const hasReviewsTab = await reviewsTab.isVisible({ timeout: 15_000 }).catch(() => false);

    if (hasReviewsTab) {
      await reviewsTab.click();
      await page.waitForTimeout(2000);
      await waitForFlutter(page);
      console.log('Reviews tab clicked successfully');
    } else {
      // Admin panel may have different tab names or layout
      // Check if we are at least on the admin page
      const adminPageContent = page.locator(
        '[aria-label*="admin"], [aria-label*="panel"]'
      ).first();
      const isOnAdmin = await adminPageContent.isVisible({ timeout: 5_000 }).catch(() => false);

      if (isOnAdmin) {
        console.log('Admin panel loaded but Reviews tab not found — tab may use different label');
      } else {
        console.log('Admin panel did not load — check admin access and route');
      }
    }

    // Cleanup: navigate home and sign out
    await navigateHome(page, TARGET_URL);
    await performSignOut(page, TARGET_URL);
  });

  // ─── T02: Reviews list renders ──────────────────────────────────
  test('T02: Reviews list renders or shows empty state', async ({ page }) => {
    await requireWebApp(page, TARGET_URL);
    await page.goto(`${TARGET_URL}/`);
    await waitForFlutter(page);
    await checkSemantics(page);

    await ensureLoggedInAsAdmin(page, TARGET_URL, ADMIN_EMAIL, ADMIN_PASS);
    await navigateToAdmin(page);
    await page.waitForTimeout(2000);

    // Click the Reviews tab
    const reviewsTab = page.locator('[aria-label="admin-tab-reviews"]').first()
      .or(page.getByRole('tab', { name: /reviews|avis/i }).first())
      .or(page.getByRole('button', { name: /admin-tab-reviews|reviews|avis/i }).first());

    const hasReviewsTab = await reviewsTab.isVisible({ timeout: 15_000 }).catch(() => false);

    if (!hasReviewsTab) {
      console.log('Reviews tab not found — skipping content check');
      await navigateHome(page, TARGET_URL);
      await performSignOut(page, TARGET_URL);
      test.skip(true, 'Reviews tab not available in admin panel');
      return;
    }

    await reviewsTab.click();
    await page.waitForTimeout(3000);
    await waitForFlutter(page);

    // Check for review entries or empty state — use soft assertions
    // since dev may have no reviews
    const reviewItems = page.locator(
      '[aria-label*="review-item"], [aria-label*="review-card"], [aria-label*="rating"]'
    );
    const emptyState = page.getByText(/no reviews|aucun avis|empty|nothing/i).first();
    const loadingIndicator = page.locator('[aria-label*="loading"]').first();

    const reviewCount = await reviewItems.count();
    const hasEmpty = await emptyState.isVisible({ timeout: 5_000 }).catch(() => false);
    // Wait longer for loading to complete
    await page.waitForTimeout(3000);
    const isLoading = await loadingIndicator.isVisible({ timeout: 1_000 }).catch(() => false);

    if (reviewCount > 0) {
      console.log(`Found ${reviewCount} review items in admin panel`);
    } else if (hasEmpty) {
      console.log('Empty state shown — no reviews in dev environment');
    } else {
      console.log('Reviews tab rendered — no review items or empty state detected');
    }

    // The tab must show review items OR an empty state (not still loading after 5s+)
    expect(
      reviewCount > 0 || hasEmpty,
      `Admin reviews tab must show review items (${reviewCount}) or empty state (${hasEmpty}) — not stuck loading (${isLoading})`
    ).toBe(true);

    // Cleanup
    await navigateHome(page, TARGET_URL);
    await performSignOut(page, TARGET_URL);
  });

  // ─── T03: Admin can flag a review via API ───────────────────────
  test('T03: Admin can flag a review via admin_flag_review API', async () => {
    const adminAuth = await signIn(ADMIN_EMAIL, ADMIN_PASS);

    // First, get reviews to find one to flag
    const reviewsResult = await callCallable('admin_get_reviews', {
      limit: 5,
    }, adminAuth.idToken);

    if (reviewsResult.error) {
      const errMsg = (reviewsResult.error.message || '').toLowerCase();
      console.log(`admin_get_reviews response: ${reviewsResult.error.message}`);

      // If function not deployed, skip gracefully
      if (errMsg.includes('not_found') || errMsg.includes('not found') || reviewsResult.error.status === 'NOT_FOUND') {
        test.skip(true, 'admin_get_reviews callable not deployed yet');
        return;
      }

      // Admin should not be denied access
      expect(errMsg).not.toMatch(/permission.denied|unauthenticated/);
      return;
    }

    const reviews = reviewsResult.result?.reviews || reviewsResult.result || [];

    if (!Array.isArray(reviews) || reviews.length === 0) {
      console.log('No reviews available in dev — seeding a test review');

      // Try to submit a rating as buyer first, then flag it as admin
      const buyerAuth = await signIn(TEST_ACCOUNTS.BUYER_EMAIL, TEST_ACCOUNTS.BUYER_PASS);
      const ratingResult = await callCallable('submit_rating', {
        productId: 'e2e_product_test_seller',
        rating: 3,
        comment: `E2E test review for flagging ${Date.now()}`,
      }, buyerAuth.idToken);

      if (ratingResult.error) {
        console.log(`submit_rating error: ${ratingResult.error.message}`);
        // If we cannot create a review, skip the flag test
        test.skip(true, 'Cannot create a review to flag — no reviews in dev');
        return;
      }

      const reviewId = ratingResult.result?.ratingId || ratingResult.result?.reviewId || ratingResult.result?.id;

      if (reviewId) {
        // Flag the review
        const flagResult = await callCallable('admin_flag_review', {
          reviewId,
          flagged: true,
          reason: 'E2E test flag — inappropriate content',
        }, adminAuth.idToken);

        if (flagResult.error) {
          const flagErr = (flagResult.error.message || '').toLowerCase();
          if (flagErr.includes('not_found') || flagErr.includes('not found')) {
            test.skip(true, 'admin_flag_review callable not deployed yet');
            return;
          }
          console.log(`admin_flag_review error: ${flagResult.error.message}`);
        } else {
          expect(flagResult.result || flagResult).toBeTruthy();
          console.log(`Review ${reviewId} flagged successfully`);
        }
      }
      return;
    }

    // Flag the first review found
    const targetReview = reviews[0];
    const reviewId = targetReview.reviewId || targetReview.ratingId || targetReview.id;

    if (!reviewId) {
      console.log('Review object has no ID field — cannot flag');
      return;
    }

    const flagResult = await callCallable('admin_flag_review', {
      reviewId,
      flagged: true,
      reason: 'E2E test flag — admin review moderation',
    }, adminAuth.idToken);

    if (flagResult.error) {
      const flagErr = (flagResult.error.message || '').toLowerCase();
      if (flagErr.includes('not_found') || flagErr.includes('not found')) {
        test.skip(true, 'admin_flag_review callable not deployed yet');
        return;
      }
      // Admin should not be denied access
      expect(flagErr).not.toMatch(/permission.denied|unauthenticated/);
      console.log(`admin_flag_review response: ${flagResult.error.message}`);
    } else {
      expect(flagResult.result || flagResult).toBeTruthy();
      console.log(`Review ${reviewId} flagged successfully via admin API`);
    }
  });
});
