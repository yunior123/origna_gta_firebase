# Testing Quality Audit — 2026-03-05

## Scope
- Backend unit/integration tests (`functions/tests`)
- Flutter unit tests (`origna_gta/test/unit`)
- Real browser E2E smoke (`e2e/playwright_ui/smoke-home-profile.spec.ts`)

## Commands Used
- `./scripts/run_quality_gate.sh`
- `./scripts/run_quality_gate.sh --backend-threshold 30 --skip-flutter --skip-e2e`
- `./scripts/run_quality_gate.sh --backend-threshold 50 --flutter-threshold 20 --skip-e2e`

## Current Status (Strict Mode)
- Backend coverage threshold `100%`: **FAIL**
  - Measured source coverage (handlers + services + models + utils): **34.21%**
- Flutter coverage threshold `100%`: **FAIL**
  - Measured unit coverage (`test/unit`): **22.83%**
- Real Playwright E2E smoke: **PASS with flakiness**
  - Test retried and passed, but initial attempt failed on navigation expectation.

## Highest-Risk Coverage Gaps (Backend)
- `handlers/tasks.py` — 11.93%
- `handlers/products.py` — 14.53%
- `handlers/cron_jobs.py` — 15.03%
- `handlers/coupons.py` — 15.76%
- `handlers/orders.py` — 16.38%
- `handlers/payment_stripe.py` — 42.86%

## Highest-Risk Coverage Gaps (Flutter)
- `lib/core/repositories/auth_repository.dart` — 0.00%
- `lib/core/repositories/user_repository.dart` — 0.00%
- `lib/core/repositories/order_repository.dart` — 0.00%
- `lib/core/repositories/cart_repository.dart` — 0.00%
- `lib/core/repositories/product_repository.dart` — 8.18%

## Interpretation
- Real E2E exists and runs, but determinism is not stable yet.
- 100% coverage is not currently close in either backend or Flutter.
- Strict 100% gating is now implemented and will continue to fail until the test suite closes the reported gaps.

## Recommendation Path to True 100%
1. Stabilize E2E smoke (remove flaky navigation assumptions in `smoke-home-profile.spec.ts`).
2. Lift backend first in this order:
   - `handlers/orders.py`
   - `handlers/payment_stripe.py`
   - `handlers/products.py`
   - `handlers/cron_jobs.py`
3. Lift Flutter repository coverage:
   - add repository-level unit tests using fake Firestore/auth layers
   - prioritize `auth_repository.dart`, `user_repository.dart`, `order_repository.dart`, `cart_repository.dart`
4. Keep strict gate enabled and run daily via workflow:
   - `.github/workflows/strict-quality-audit.yml`

## Follow-up Work Completed (same date)
- Added duplicate-line stock reservation planner in `handlers/payment_stripe.py`:
  - `_build_stock_reservation_plan(...)`
  - Aggregates per-product decrements and prevents duplicate-line under-reservation.
  - Simulates warehouse consumption to avoid overbooking the same warehouse candidate.
- Added backend regression tests:
  - `functions/tests/test_handlers_payment_stripe.py` (`TestStockReservationPlan`)
  - `functions/tests/test_handlers_products_orders.py`:
    - seller ownership enforcement for `update_shipping_cost`
    - captured-payment shipping delta behavior
    - seller bulk delivered-block in `_update_item_status_logic`
- Strengthened smoke E2E stability in `e2e/playwright_ui/smoke-home-profile.spec.ts`:
  - deterministic post-login home navigation
  - cart URL + semantic fallback
  - resilient profile recovery helper
- Enforced strict flaky handling for E2E:
  - `scripts/run_quality_gate.sh` now runs Playwright with `--fail-on-flaky-tests`
  - `scripts/run_real_e2e_smoke.sh` also supports fail-on-flaky

## Continuation Work Completed (same date, later pass)
- Added backend helper test suites:
  - `functions/tests/test_handlers_helper_coverage.py` (18 tests)
  - `functions/tests/test_handlers_payment_stripe_helpers.py` (14 tests)
  - `functions/tests/test_handlers_tasks.py` (10 tests)
  - `functions/tests/test_handlers_shipping.py` (6 tests)
  - `functions/tests/test_handlers_addresses.py` (7 tests)
- Fixed a production-facing error mapping bug in `handlers/shipping.py`:
  - Explicit `HttpsError("invalid-argument")` validation failures were being converted to `HttpsError("internal")`.
  - Added `except https_fn.HttpsError: raise` to preserve original error codes.
- Fixed two backend refund-path defects in `handlers/orders.py`:
  - `refund_order_item` now defines `order_subtotal_cents` before proportional computations.
  - `refund_order_item` now defines `proportional_shipping_cents` for Stripe refund metadata.
- Coverage impact from this continuation:
  - `handlers/addresses.py`: **30.00% → 100%**
  - `handlers/tasks.py`: **11.93% → 94%**
  - `handlers/shipping.py`: **29.17% → 100%**
  - `handlers/payment_stripe.py` (targeted + suite alignment): **~29% targeted → 31% targeted / 45.70% full-suite**
  - `handlers/orders.py` (targeted + refund fixes/tests): **~20% targeted → 22% targeted / 31.30% full-suite**
  - Backend strict gate total: **36.56% → 38.44%**
- Strict gate re-runs:
  - Backend strict gate (`100%`) still fails by design at current suite breadth:
    - `589 passed`, total backend coverage `38.44%`
    - test execution is green; failure is only `--cov-fail-under=100`
  - Real Playwright smoke strict gate (fail on flaky) passed cleanly again:
    - `playwright_ui/smoke-home-profile.spec.ts` `1 passed` (latest rerun: ~2.4m)

## Current Bottlenecks To Reach True 100%
- Largest low-coverage backend files still dominating denominator:
  - `handlers/cron_jobs.py` — 15.03%
  - `handlers/coupons.py` — 15.76%
  - `handlers/products.py` — 18.60%
  - `handlers/admin.py` — 24.02%
  - `handlers/orders.py` — 24.71%
  - `handlers/payment_stripe.py` — 45.62%
- Practical implication:
  - A true 100% gate requires systematic branch coverage in these large handlers plus the Flutter repository layer (still substantially below 100%).
