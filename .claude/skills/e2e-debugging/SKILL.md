---
name: e2e-debugging
description: Use when debugging Playwright E2E test failures — flt-semantics timeouts, Flutter web init failures, Firebase assertion errors, test flakiness, or Stripe checkout failures.
---

# Skill: E2E Debugging Methodology

> Comprehensive guide for debugging Playwright E2E tests against Firebase Emulators + Stripe CLI.
> Load this before investigating any E2E test failure.

---

## Infrastructure Setup

### Required Services (all must be running)

| Service | Port | Command |
|---------|------|---------|
| Firebase Auth Emulator | 9099 | `firebase emulators:start --import=./emulator-data` |
| Firestore Emulator | 8080 | (included above) |
| Functions Emulator | 5001 | (included above) |
| Hosting Emulator | 5005 | (included above) |
| Storage Emulator | 9199 | (included above) |
| Stripe CLI | — | `stripe listen --forward-to localhost:5001/orignagta/us-central1/stripe_webhook` |

**CRITICAL**: Firebase project ID is `orignagta` (NO hyphen). The Stripe webhook URL must match exactly.

### Emulator Data

- Seed data lives in `./emulator-data/` (imported on startup)
- Functions emulator auto-reloads Python files on save — no restart needed
- **Exception**: Changes to `requirements.txt` or `main.py` route registration require emulator restart

### Stripe CLI

```bash
stripe listen --forward-to localhost:5001/orignagta/us-central1/stripe_webhook
```

- The signing secret from `stripe listen` output must match `.env` or emulator env
- Stripe CLI must be authenticated: `stripe login`
- Verify with: `stripe trigger payment_intent.created`

---

## Playwright Configuration

| Setting | Value |
|---------|-------|
| Test runner | Playwright v1.58.2 |
| Browser | Chromium only |
| Workers | 2 (parallel) |
| Retries | 1 |
| Timeout | 120s per test |
| Base URL | `http://localhost:5005` |
| Config | `e2e/playwright.config.ts` |

### Run Commands

```bash
cd e2e
npx playwright test                              # All tests
npx playwright test shipping-lifecycle            # One spec file
npx playwright test -g "A.1"                      # Grep by test name
npx playwright test --reporter=list               # Verbose output
npx playwright test --debug                       # Step-through debugger
```

---

## Test Spec Files (9 files, 279 tests)

| File | Tests | Focus |
|------|-------|-------|
| `shipping-lifecycle-e2e.spec.ts` | ~50 | Suites A-K: full order lifecycle |
| `payment-workflow-e2e.spec.ts` | ~40 | Payment flows, refunds, disputes |
| `full-marketplace-e2e.spec.ts` | ~36 | Marketplace operations |
| `comprehensive-flows-e2e.spec.ts` | ~35 | Cross-cutting flows |
| `fullstack-e2e.spec.ts` | ~30 | API-level integration |
| `flutter-web-e2e.spec.ts` | ~25 | Flutter web UI tests |
| `regression-e2e.spec.ts` | ~25 | Regression coverage |
| `logic-failures-e2e.spec.ts` | ~25 | Error handling, edge cases |
| `admin-email-test.spec.ts` | ~13 | Admin panel, email verification |

---

## Common Failure Patterns & Solutions

### 1. Firestore SERVER_TIMESTAMP in Arrays
**Symptom**: `Cannot convert to a Firestore Value, Sentinel: Value used to set a document field to the server timestamp`
**Cause**: `get_server_timestamp()` used inside array elements or `ArrayUnion()`
**Fix**: Use `datetime.now(timezone.utc)` for any timestamp nested in arrays

### 2. paymentStatus Mismatch
**Symptom**: Tests assert `paymentStatus: 'authorized'` but get `'captured'`
**Cause**: Auto-capture mode — funds captured at checkout, never just authorized
**Fix**: Assert `paymentStatus: 'captured'` in all auto-capture tests

### 3. Seller Cannot Mark as Delivered
**Symptom**: `update_order_status` returns 403 for seller trying to mark DELIVERED
**Cause**: Backend restricts DELIVERED transitions to admin-only
**Fix**: Use admin credentials for delivered assertions, or use `update_item_status` for per-item

### 4. Multi-Seller Order Status Update Blocked
**Symptom**: `update_order_status` rejects with "multi-seller restriction"
**Cause**: Order-level status changes blocked for multi-seller orders
**Fix**: Use `update_item_status` for per-item transitions instead

### 5. CallableRequest vs Flask Request
**Symptom**: `capture_payment` works from frontend but crashes when called from `confirm_order_receipt`
**Cause**: `capture_payment` is `@on_call` decorated (Flask Request), but `confirm_order_receipt` passes CallableRequest
**Fix**: Call `_capture_payment_impl` (undecorated) from other Python functions

### 6. Missing isActive on Products
**Symptom**: Product not returned by queries, tests can't find it
**Cause**: Product document missing `isActive: true` field
**Fix**: Always set `isActive: true` when seeding products via Firestore REST

### 7. signIn Response Property
**Symptom**: `Cannot read property 'idToken' of undefined` or login fails
**Cause**: Firebase Auth emulator `signInWithPassword` returns `{idToken}`, not `{token}`
**Fix**: Access `response.data.idToken` (not `response.data.token`)

### 8. Rating Test Pollution
**Symptom**: Rating test fails with "already rated" or duplicate key error
**Cause**: Previous test run left rating documents in Firestore
**Fix**: Clean existing ratings before test: query ratings collection, delete matching docs

### 9. Stock Field Name
**Symptom**: Stock assertions fail — expected >0 but got undefined
**Cause**: Field is `stockQuantity` (not `stock`)
**Fix**: Use `stockQuantity` in all Firestore queries and assertions

---

## Debugging Workflow

### Step 1: Check Infrastructure
```bash
# Verify emulators running
curl http://localhost:5001/orignagta/us-central1/health_check
curl http://localhost:8080/  # Firestore emulator UI

# Verify Stripe CLI
# Look for "Ready!" message in Stripe terminal
```

### Step 2: Isolate the Failing Test
```bash
cd e2e
npx playwright test -g "test name" --reporter=list
```

### Step 3: Check Functions Emulator Logs
```bash
# Functions emulator prints to its terminal
# Look for Python tracebacks, 500 errors, permission denied
```

### Step 4: Direct Firestore REST Queries
```bash
# Read a document
curl "http://localhost:8080/v1/projects/orignagta/databases/(default)/documents/orders/ORDER_ID"

# Query a collection
curl -X POST "http://localhost:8080/v1/projects/orignagta/databases/(default)/documents:runQuery" \
  -H "Content-Type: application/json" \
  -d '{
    "structuredQuery": {
      "from": [{"collectionId": "products"}],
      "where": {"fieldFilter": {"field": {"fieldPath": "sellerId"}, "op": "EQUAL", "value": {"stringValue": "SELLER_ID"}}},
      "limit": 5
    }
  }'
```

### Step 5: Reset Stock (if stock tests fail)
```bash
curl -X PATCH "http://localhost:8080/v1/projects/orignagta/databases/(default)/documents/products/PRODUCT_ID" \
  -H "Content-Type: application/json" \
  -d '{"fields": {"stockQuantity": {"integerValue": "100"}}}'
```

### Step 6: Check Test Assertions vs Backend Reality
- Read the exact backend handler code for the endpoint being tested
- Compare response shape with what the test expects
- Check status codes (200 vs 400 vs 403 vs 500)

---

## Test Account Credentials

| Role | Email | Password | UID |
|------|-------|----------|-----|
| Admin | `yr62813@gmail.com` | `960227Y#y` | (check emulator-data) |
| Buyer | varies by test | varies | Created in beforeAll |
| Seller | varies by test | varies | Created in beforeAll |

---

## Product-Seller Mapping

Tests create products linked to specific sellers. When debugging:
1. Find the product ID in the test
2. Query Firestore for the product's `sellerId`
3. Verify the seller account exists and has Stripe Connect

---

## Run Progression (E2E Marathon Results)

| Run | Passed | Failed | Key Fix |
|-----|--------|--------|---------|
| 1 | 200 | 67 | Baseline — identified SERVER_TIMESTAMP bug |
| 2 | 243 | 24 | Fixed 8 SERVER_TIMESTAMP locations |
| 3 | 252 | 15 | paymentStatus auto-capture, seller restrictions |
| 4 | 258 | 9 | Multi-seller update_item_status, auto-promote SHIPPED |
| 5 | 262 | 5 | _capture_payment_impl extraction, Yahoo isActive |
| 6 | 264 | 2 | signIn idToken fix, payout records |
| 7 | 266 | 0 | Rating cleanup, stock field fix (1 flaky, 12 skipped) |

Total: **12 root causes** fixed across 7 runs to go from 200→266 passing (279 total, 12 intentionally skipped, 1 flaky).
