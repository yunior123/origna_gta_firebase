# E2E Test Suite README

This document outlines how to set up, run, and debug the End-to-End (E2E) test suite for the Origna GTA project using Playwright.

## Remote-first note

The strict E2E and coverage gate is designed to run remotely, not on the local 8GB Mac:

- GitHub Actions: `Strict Quality Audit`
- Codemagic: `quality-gate-remote`

Local Playwright runs are still supported for focused debugging and selector work.

## 1. Prerequisites

Before running the E2E tests, ensure you have the following installed:

*   **Node.js**: LTS version recommended.
*   **Playwright**: The Playwright test runner and browsers are automatically installed when you run `npm install` in the `e2e/` directory.
*   **Firebase CLI**: For interacting with Firebase projects (e.g., `firebase use`).
*   **Stripe CLI**: Used for local testing of Stripe webhooks or specific payment scenarios.

## 2. Environment Setup

Tests run against a live Firebase project, NOT emulators. It is critical to select the correct Firebase project and set the `TEST_ENVIRONMENT` variable.

1.  **Select Firebase Project**:
    Use the Firebase CLI to select the target project. For development E2E tests, you will typically use `orignagta-dev`:
    ```bash
    firebase use orignagta-dev
    ```

2.  **Set `TEST_ENVIRONMENT`**:
    The `TEST_ENVIRONMENT` variable in `api-helpers.ts` determines which Firebase project the API helpers will target.
    *   `dev` (default, used by `playwright.config.dev.ts`): Targets `orignagta-dev` Firebase project.
    *   `staging`: Targets `orignagta-staging` Firebase project.
    *   `production`: Targets `orignagta` Firebase project.

    You can set this in your shell environment (e.g., `~/.bashrc` / `~/.zshrc`) or before running tests:
    ```bash
    export TEST_ENVIRONMENT=dev
    ```
    **IMPORTANT**: Tests run against live Firebase (NOT emulators) because the local Mac has only 8GB RAM, which is insufficient to run Firebase emulators alongside Playwright. The dev Firebase project handles the test load.

## 3. How to Run Tests

All commands should be run from the `e2e/` directory.

*   **Run all tests**:
    ```bash
    npx playwright test --config=playwright.config.dev.ts
    ```

*   **Run a single test file**:
    Specify the path to the individual test file you wish to run.
    ```bash
    npx playwright test <path/to/your/test-file.spec.ts> --config=playwright.config.dev.ts
    # Example:
    # npx playwright test playwright_ui/buyer-flow.spec.ts --config=playwright.config.dev.ts
    ```

*   **Run with specific workers (parallelism)**:
    Keep local worker counts conservative on low-memory machines.
    ```bash
    npx playwright test --workers=2 --config=playwright.config.dev.ts
    ```

*   **Run the deterministic Playwright coverage gate**:
    ```bash
    npx --yes c8 --all \
      --reporter=lcovonly \
      --reporter=text-summary \
      --report-dir=coverage-playwright \
      --include=playwright_ui/coverage_gate.ts \
      npx playwright test playwright_ui/coverage-gate.spec.ts \
      --config=playwright.config.dev.ts \
      --project=chromium \
      --workers=1 \
      --fail-on-flaky-tests
    ```

## 4. Test Accounts

The following test accounts are defined in `e2e/api-helpers.ts` and are pre-seeded into the Firebase project by `mega-seed.ts`. These accounts have known credentials and are designed for various testing roles.

| Role                   | Email                       | Password       |
| :--------------------- | :-------------------------- | :------------- |
| Admin                  | `yr62813@gmail.com`         | `REDACTED_TEST_PASSWORD` |
| Seller 1               | `seller1@test.origna.ca`    | `REDACTED_TEST_PASSWORD` |
| Seller 2               | `seller2@test.origna.ca`    | `REDACTED_TEST_PASSWORD` |
| Buyer 1                | `buyer1@test.origna.ca`     | `REDACTED_TEST_PASSWORD` |
| Buyer 2                | `buyer2@test.origna.ca`     | `REDACTED_TEST_PASSWORD` |
| Buyer 3                | `buyer3@test.origna.ca`     | `REDACTED_TEST_PASSWORD` |
| Suspended User         | `suspended@test.origna.ca`  | `REDACTED_TEST_PASSWORD` |
| Non-Onboarded Seller   | `seller9@test.origna.ca`    | `REDACTED_TEST_PASSWORD` |

*Note: All test accounts use the same password (`REDACTED_TEST_PASSWORD`).*

## 5. Seed Data

The `mega-seed.ts` script is crucial for populating the Firebase project with a consistent and comprehensive dataset required for E2E tests. It creates users, products, orders, and other necessary entities.

*   **Location**: `e2e/mega-seed.ts`
*   **Usage**: To seed or re-seed the database, run:
    ```bash
    npx ts-node mega-seed.ts
    ```
*   **Recommendation**: Run this script whenever you need to refresh the test environment data or after significant schema changes.

## 6. Stable Test Products

For tests requiring consistent product data, the following stable product IDs are defined in `e2e/api-helpers.ts`. These products are created by `mega-seed.ts` and their characteristics should not be altered without updating dependent tests.

*   `HIGH_STOCK`: `product_024` (Example: "Budget Sticker Pack", ~500 stock, associated with `seller1`)
*   `DIGITAL`: `product_010` (Example: A digital product, useful for digital-only purchase flows)
*   `SELLER2`: `product_004` (Example: "BC Cedar Incense Set", associated with `seller2`)

## 7. Screenshot Output Location

Screenshots captured during test failures or on explicit command (`screenshot: 'on'`) are saved to your desktop:

*   `~/Desktop/origna-screenshots/dev` (for tests run against the `dev` environment)

## 8. Debugging Tips

Playwright offers powerful debugging tools:

*   **Headed mode (UI visible)**:
    Runs tests with a visible browser window, allowing you to observe interactions.
    ```bash
    npx playwright test --headed --config=playwright.config.dev.ts
    ```
*   **Playwright Inspector (`--debug`)**:
    Launches the Playwright Inspector, providing a GUI to step through tests, inspect the DOM, and try selectors.
    ```bash
    npx playwright test --debug --config=playwright.config.dev.ts
    ```
*   **Trace Viewer**:
    Playwright automatically saves detailed traces on the first retry of a failed test (`trace: 'on-first-retry'` in config). These traces contain screenshots, videos, and logs for debugging. To open a trace:
    ```bash
    npx playwright show-trace <path/to/trace.zip>
    # Trace files are typically found in the test-results directory after a run.
    ```

## 9. Rate Limiting Considerations

Be mindful of Firebase and external service rate limits during test execution. Notably, the `create_checkout_session` function (and potentially others) has a rate limit of approximately **5 requests per minute**. Rapid, successive calls exceeding this limit can lead to test failures. Structure your tests to minimize concurrent calls to such endpoints or implement appropriate delays.

## 10. Test File Categories

The `e2e/playwright_ui/` directory contains the current browser specs plus dedicated coverage gate files. This table highlights the core areas rather than trying to freeze an exact count that will drift.

| Test File                      | Category / Focus Area                                     |
| :----------------------------- | :-------------------------------------------------------- |
| `add-product-e2e.spec.ts`      | Seller Product Management, Product Creation               |
| `admin-actions.spec.ts`        | Admin Operations, User/Product Moderation                 |
| `admin-panel.spec.ts`          | Admin Panel UI, Data Management                           |
| `admin-security.spec.ts`       | Admin Access Control, Security                            |
| `buyer-flow.spec.ts`           | Core Buyer Journey, Product Browsing, Cart, Checkout      |
| `checkout-validation.spec.ts`  | Checkout Process, Input Validation, Error Handling        |
| `digital-product-e2e.spec.ts`  | Digital Product Purchase, Delivery, Access                |
| `edge-cases-security.spec.ts`  | Security Vulnerabilities, Boundary Conditions             |
| `favorites.spec.ts`            | User Favorites/Wishlist Functionality                     |
| `multi-seller-orders.spec.ts`  | Orders Involving Multiple Sellers, Split Payments         |
| `new-coverage-e2e.spec.ts`     | New Feature Coverage (general)                            |
| `new-notification-features.spec.ts`| New Notification System Features                          |
| `notifications.spec.ts`        | User Notifications, Alerts, In-app Messaging              |
| `order-cancellation-refund.spec.ts`| Order Cancellation, Refund Process                        |
| `order-lifecycle.spec.ts`      | End-to-end Order Flow, Status Changes                     |
| `order-notifications.spec.ts`  | Order Status Notifications (Buyer/Seller)                 |
| `password-reset.spec.ts`       | User Authentication, Password Recovery                    |
| `payment-edge-cases.spec.ts`   | Payment Failures, Retries, Alternative Payment Methods    |
| `premium-subscription.spec.ts` | Premium Features, Subscription Management                 |
| `product-video-e2e.spec.ts`    | Product Video Upload, Display, Playback                   |
| `profile-management.spec.ts`   | User Profile Editing, Account Settings                    |
| `rate-limiting.spec.ts`        | API Rate Limit Testing, Protection Mechanisms             |
| `return-request.spec.ts`       | Product Return Process, Customer Support Flow             |
| `search-products.spec.ts`      | Product Search Functionality, Filtering                   |
| `seller-flow.spec.ts`          | Core Seller Journey, Dashboard, Listings                  |
| `seller-product-management.spec.ts`| Seller's Ability to Manage (CRUD) Products                |
| `seller-registration.spec.ts`  | Seller Onboarding, Account Setup                          |
| `shipping-approval.spec.ts`    | Seller Shipping Approval Process                          |
| `shipping-calculation.spec.ts` | Shipping Cost Calculation, Options                        |
| `smoke-home-profile.spec.ts`   | Basic Smoke Tests, Homepage, User Profile Access          |
| `stock-notif.spec.ts`          | Low Stock Notifications, Inventory Alerts                 |
| `stripe-payment.spec.ts`       | Stripe Payment Gateway Integration, Checkout              |
| `trending-products.spec.ts`    | Display of Trending Products, Algorithms                  |
| `warehouse-multi-location.spec.ts`| Multi-Location Inventory, Warehouse Management            |
| `api-coverage.spec.ts`         | Headless API tests for all 65+ uncovered Cloud Functions  |
| `deep-ui-scenarios.spec.ts`    | Deep browser E2E: full buyer/seller/admin journeys        |
