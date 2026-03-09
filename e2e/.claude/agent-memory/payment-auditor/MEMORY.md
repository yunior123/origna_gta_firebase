# Payment Auditor Memory

## Key Learnings (2026-02-18)

### Backend Payment Flow (auto-capture mode)
- `create_checkout_session` creates Stripe Checkout Session WITHOUT `capture_method: "manual"`
- Webhook `checkout.session.completed` sets `paymentStatus: "captured"` (never "authorized")
- `PLATFORM_FEE_PERCENT` in config.py is actually `0.025` (ratio), not `2.5` (percent)
- Platform fee applied to subtotal only (not shipping/tax): `round(subtotalCents * 0.025)`
- `totalAmountCents = subtotalCents + shippingCostCents + taxAmountCents`

### Country Validation (FIXED in api-helpers.ts)
- Backend: `country.lower() != "canada"` -- only accepts full name "Canada"
- `BusinessRules.ALLOWED_SHIPPING_COUNTRIES = {"Canada", "CA"}` exists but is NOT used in the check
- E2E test helpers now default to `'Canada'` (was `'CA'`, now fixed)
- Backend bug still exists (should use ALLOWED_SHIPPING_COUNTRIES)

### Item Status vs Order Status
- `update_item_status` uses `DeliveryStatusValues`: pending, shipped, delivered, refunded
- `update_order_status` uses `OrderStatusValues`: pending, confirmed, processing, shipped, etc.
- NO "processing" in DeliveryStatusValues -- tests must use "shipped" for item-level updates
- Multi-seller orders: backend blocks `update_order_status` -- must use `update_item_status`

### update_shipping_cost API Contract
- Backend expects: `newShippingCost` (dollars, float), `reason` (string)
- Backend rejects if `paymentStatus != "authorized"` -- but auto-capture mode sets "captured"
- This means `update_shipping_cost` is UNREACHABLE in current auto-capture flow

### Test Architecture
- E2E tests target `orignagta-dev` (deployed, not emulator)
- No direct Firestore writes -- all mutations via Cloud Functions
- `waitForOrderStatus` polls Firestore REST API every 3s
- Dev credentials are hardcoded in api-helpers.ts (security hygiene issue)

### Stripe Test Cards (verified correct)
- 4242424242424242 = success
- 4000000000000002 = decline
- 4000000000009995 = insufficient funds
- 4000002500003155 = 3DS required

### Audit Findings (2026-02-18)
- cron_jobs.py line 280: reads `Fields.PLATFORM_FEE_CENTS` (payout field) instead of `Fields.PLATFORM_FEE_TOTAL_CENTS` (order field). Always returns None -> falls back to config.
- payment_stripe.py line 2330: `SeverityLevels.INFO` does not exist (only LOW/MEDIUM/HIGH/CRITICAL). Runtime AttributeError.
- process_payment_intent_failed (line 1751): stock restore is NOT inside a Firestore transaction -- race condition with duplicate webhooks.
- Dart schema_constants.dart has `disputeStatus` (line 304) and `platformFeeTotalCents` (line 194) -- both match Python.
