---
name: payment-system
description: Complete Stripe payment integration guide — architecture, webhook handling, Stripe CLI testing, emulator setup, known bugs, audit checklist, and E2E test patterns. Load before editing ANY payment file.
---

# Payment System — OrignaGTA

## ⚠️ CRITICAL CONTEXT — READ FIRST

OrignaGTA uses **Stripe Connect Express** with **automatic capture** (funds collected at checkout).
Seller payouts use `stripe.Transfer.create()` after delivery confirmation.
Platform fee: **2.5%** (`BusinessRules.PLATFORM_FEE_RATIO = 0.025`).
Currency: **CAD only** (`BusinessRules.DEFAULT_CURRENCY = "cad"`).
Sellers can be worldwide; buyers are **Canada-only**.

---

## Architecture — Payment Flow

```
Buyer → [Flutter Frontend] → createCheckoutSession (on_call)
                                → Validates: auth, email, items, stock, prices, address
                                → Reserves stock atomically (Firestore transaction)
                                → Creates Order doc (status: pending / awaiting_payment)
                                → stripe.checkout.Session.create()
                                → Returns {sessionId, orderId, checkoutUrl}
         ← Redirect to Stripe Checkout (hosted) ←
                                
Stripe → [Webhook: checkout.session.completed]
                                → Validates products still active
                                → Updates order: confirmed / captured
                                → Sends confirmation emails
                                → Clears buyer's cart

         [Seller ships → buyer confirms receipt]
                                → capture_payment (on_call) — for manual capture mode
                                → OR cron auto_confirm_orders (after AUTO_CONFIRM_DAYS)
                                → stripe.Transfer.create() to each seller's Connect account

Stripe → [Various webhooks for edge cases]
```

### Two Capture Modes (Important!)

| Mode | How | When |
|------|-----|------|
| **Auto-capture** (current default) | Funds captured at checkout | `payment_intent_data` with no `capture_method` or `capture_method: 'automatic'` |
| **Manual capture** (optional) | Authorize → capture later | `capture_method: 'manual'` in `payment_intent_data` |

With auto-capture:
- `checkout.session.completed` → order is CONFIRMED + CAPTURED
- `_capture_payment_impl` idempotent path: returns "already captured" AND creates seller payout records + Stripe Transfers if none exist
- Seller transfers happen when buyer calls `confirm_order_receipt` (or cron `auto_confirm_orders`)
- **`paymentStatus` is ALWAYS `'captured'` after checkout** — never `'authorized'`

### `_capture_payment_impl` Architecture (CRITICAL)

```python
# payment_stripe.py
def _capture_payment_impl(req):    # Undecorated — all capture logic
    ...
    if payment_status == 'captured':
        # AUTO-CAPTURE IDEMPOTENT PATH:
        # 1. Persist confirmedByClient
        # 2. Create payout records if none exist
        # 3. Attempt Stripe Transfers
        return {success: True, captured: True, message: 'Payment already captured'}
    ...

@https_fn.on_call(...)
def capture_payment(req):          # Thin wrapper — Flask Request
    return _capture_payment_impl(req)
```

- **`confirm_order_receipt`** (in orders.py) calls `_capture_payment_impl(req)` directly
- **NEVER call `capture_payment` from Python** — it's decorated with `@on_call` which expects Flask Request, not CallableRequest
- `confirm_order_receipt` receives CallableRequest → must call undecorated `_capture_payment_impl`

### Firestore SERVER_TIMESTAMP in Arrays (CRITICAL BUG)

`get_server_timestamp()` returns `firestore.SERVER_TIMESTAMP` — a sentinel resolved server-side.
**It CANNOT be nested inside arrays or ArrayUnion.** Firestore raises:
```
('Cannot convert to a Firestore Value', Sentinel: Value used to set a document field to the server timestamp.)
```

**Rule**: Use `datetime.now(timezone.utc)` (or `datetime.now(UTC)`) for any timestamp inside:
- Array element updates (e.g., item shipped_at, delivered_at, refunded_at)
- `ArrayUnion()` values (e.g., partial_reversals, reversal_errors)

Keep `get_server_timestamp()` for top-level fields only (updatedAt, createdAt).

**Fixed locations (8 total)**:
- `orders.py`: update_order_status (shipped items), update_item_status (shipped_at, delivered_at), refund_order_item (refunded_at, partial_reversals)
- `payment_stripe.py`: handle_stripe_dispute (3 ArrayUnion reversal_errors)

---

## File Map — All Payment Files

### Backend (Python — Cloud Functions)
| File | What | Key Functions |
|------|------|---------------|
| `functions/handlers/payment_stripe.py` | **PRIMARY** — all Stripe logic | `create_checkout_session`, `stripe_webhook`, `capture_payment`, `create_connect_account`, `create_account_link`, `get_connect_account_status` |
| `functions/handlers/payment_providers.py` | Provider abstraction (Stripe / Airwallex) | `PaymentProvider`, `require_provider_enabled` |
| `functions/handlers/payment_airwallex.py` | Airwallex alternative (secondary) | `create_airwallex_checkout` |
| `functions/handlers/orders.py` | Order management | `confirm_order_receipt` → delegates to `capture_payment` |
| `functions/handlers/cron_jobs.py` | Automated payment capture | `auto_confirm_orders`, `expire_unpaid_orders` |
| `functions/handlers/admin.py` | Admin refund/cancel | `admin_refund_order`, `admin_cancel_order` |
| `functions/config.py` | Stripe keys + config | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `PLATFORM_FEE_RATIO` |
| `functions/schema_constants.py` | All status values | `OrderStatusValues`, `PaymentStatusValues`, `PayoutStatusValues`, `BusinessRules` |
| `functions/services/email_service.py` | Order confirmation emails | `get_order_confirmation_email`, `get_seller_notification_email` |
| `functions/services/shipping_service.py` | Shipping cost calculation | `calculate_shipping_cost`, `get_tax_rate` |
| `functions/services/rate_limiter.py` | Rate limiting | `check_rate_limit` |

### Frontend (Flutter/Dart)
| File | What |
|------|------|
| `lib/features/checkout/checkout_provider.dart` | Checkout state management (Riverpod) |
| `lib/features/checkout/checkout_state.dart` | Checkout state model + `CheckoutResult` sealed class |
| `lib/screens/checkout_screen.dart` | Checkout UI |
| `lib/screens/orders_screen.dart` | Order status display |
| `lib/core/repositories/order_repository.dart` | `createCheckoutSession()` HTTP call |
| `lib/utils/constants.dart` | `OrderStatus`, `PaymentStatus` enums |
| `lib/core/schema/schema_constants.dart` | `OrderStatusValues`, `PaymentStatusValues`, `ApiKeys` |

### Tests
| File | Tests | Scope |
|------|-------|-------|
| `functions/tests/test_handlers_payment_stripe.py` | ~50 | Unit: checkout, webhooks, capture |
| `functions/tests/test_payment_integration.py` | ~30 | Integration: full payment flows |
| `functions/tests/test_payment_security.py` | ~20 | Security: auth, rate limits |
| `functions/tests/test_critical_flow_scenarios.py` | ~40 | Edge cases: stock, validation |
| `functions/tests/test_tax_audit.py` | ~15 | Tax calculation |
| `functions/tests/test_shipping_security.py` | ~15 | Shipping validation |
| `functions/tests/test_edge_cases_advanced.py` | ~15 | Advanced edge cases |
| `e2e/payment-workflow-e2e.spec.ts` | 54 | E2E: 10 suites (A-J) |
| `e2e/shipping-lifecycle-e2e.spec.ts` | ~20 | E2E: shipping + capture |
| `e2e/logic-failures-e2e.spec.ts` | 29 | E2E: logic attack vectors |
| `e2e/regression-e2e.spec.ts` | 38 | E2E: regression suites |

### Scripts
| File | Purpose |
|------|---------|
| `scripts/audit-stripe-webhooks.sh` | Audit webhooks: code vs test vs live dashboard |
| `scripts/start-stripe-webhooks.sh` | Forward Stripe webhooks to local emulator |
| `start-dev.sh` | Full dev env: emulators + Stripe CLI + auto-inject webhook secret |

---

## Webhook Events Handled

| Event | Handler | What It Does |
|-------|---------|-------------|
| `checkout.session.completed` | `process_checkout_session_completed` | Validates products, updates order to CONFIRMED/CAPTURED, sends emails, clears cart |
| `checkout.session.async_payment_succeeded` | `process_async_payment_succeeded` | Updates payment status to CAPTURED (bank transfers) |
| `checkout.session.async_payment_failed` | `process_async_payment_failed` | Restores stock, cancels order |
| `checkout.session.expired` | `process_session_expired` | Restores stock, marks order EXPIRED |
| `payment_intent.succeeded` | `process_payment_intent_succeeded` | Only updates if status in {CAPTURING, AWAITING_PAYMENT} — prevents overwriting |
| `payment_intent.payment_failed` | `process_payment_intent_failed` | Restores stock, cancels order |
| `payment_intent.canceled` | `process_payment_intent_canceled` | Restores stock, cancels order (idempotent) |
| `charge.refunded` | `process_charge_refunded` | Distinguishes full/partial refund, reverses seller transfers |
| `charge.dispute.created` | `process_dispute_created` | Logs security alert, auto-reverses ALL seller transfers, updates order to DISPUTED |
| `charge.dispute.closed` | `process_dispute_closed` | Resolves security alert |
| `transfer.reversed` | `process_transfer_reversed` | Updates payout status to REVERSED |
| `payout.failed` | `process_payout_failed` | Logs HIGH severity security alert |
| `refund.failed` | `process_refund_failed` | Logs CRITICAL severity security alert |
| `account.updated` | `process_account_updated` | Updates seller Connect status, adds seller role on onboarding completion |

### Webhook Security Layers (in order)
1. **Method check** — Only POST accepted
2. **Rate limiting** — 100/min per IP (`BusinessRules.WEBHOOK_RATE_LIMIT_PER_MINUTE`)
3. **Signature verification** — `stripe.Webhook.construct_event()` with HMAC
4. **Stale rejection** — Events > 5 min rejected (`BusinessRules.WEBHOOK_MAX_AGE_SECONDS`)
5. **Idempotency** — `webhook_events` collection in Firestore
6. **Sanitized logging** — No sensitive data in logs

---

## Stripe CLI Testing — Complete Guide

### Prerequisites
```bash
brew install stripe/stripe-cli/stripe
stripe login
```

### Start Dev Environment (Recommended)
```bash
# Option 1: Full environment (emulators + Stripe CLI + auto-inject webhook secret)
./start-dev.sh

# Option 2: Manual
firebase emulators:start --only functions,firestore,auth,storage
# In another terminal:
stripe listen --forward-to http://127.0.0.1:5001/orignagta/us-central1/stripe_webhook
# Copy whsec_... to functions/.env as STRIPE_WEBHOOK_SECRET
```

### Trigger Test Events (All Supported)
```bash
# === CHECKOUT FLOW ===
stripe trigger checkout.session.completed
stripe trigger checkout.session.async_payment_succeeded
stripe trigger checkout.session.async_payment_failed
stripe trigger checkout.session.expired

# === PAYMENT INTENT LIFECYCLE ===
stripe trigger payment_intent.succeeded
stripe trigger payment_intent.payment_failed
stripe trigger payment_intent.canceled

# === REFUNDS & DISPUTES ===
stripe trigger charge.refunded
stripe trigger charge.dispute.created
stripe trigger charge.dispute.closed

# === CONNECT / TRANSFERS ===
stripe trigger account.updated
stripe trigger transfer.reversed
stripe trigger payout.failed
stripe trigger refund.failed
```

### Trigger With Custom Data (Advanced)
```bash
# Create a PaymentIntent and then trigger events on it
stripe payment_intents create --amount 5000 --currency cad \
  --metadata[orderId]=test_order_001 \
  --metadata[userId]=test_user_001

# Trigger checkout with specific fixture
stripe trigger checkout.session.completed \
  --override checkout_session:metadata.orderId=test_order_001

# Test 3D Secure failure
stripe trigger payment_intent.payment_failed \
  --override payment_intent:payment_method=pm_card_authenticationRequired
```

### Useful Stripe CLI Commands
```bash
# List recent events
stripe events list --limit 10

# Tail webhook logs in real-time
stripe listen --forward-to http://127.0.0.1:5001/orignagta/us-central1/stripe_webhook --print-json

# Check webhook endpoint status
stripe webhook_endpoints list

# Resend a specific event
stripe events resend evt_xxxxx

# Test specific card scenarios
stripe payment_intents create --amount 1000 --currency cad --payment-method pm_card_visa
stripe payment_intents create --amount 1000 --currency cad --payment-method pm_card_chargeDeclined
stripe payment_intents create --amount 1000 --currency cad --payment-method pm_card_chargeDeclinedInsufficientFunds
```

### Test Card Numbers (for Stripe Checkout in browser)
| Card | Number | Use Case |
|------|--------|----------|
| Visa (success) | `4242 4242 4242 4242` | Normal payment |
| Mastercard | `5555 5555 5555 4444` | Normal payment |
| 3D Secure | `4000 0025 0000 3155` | Requires authentication |
| Declined | `4000 0000 0000 0002` | Card declined |
| Insufficient funds | `4000 0000 0000 9995` | Declined: insufficient funds |
| Expired | `4000 0000 0000 0069` | Expired card |
| CVC fail | `4000 0000 0000 0127` | Incorrect CVC |
| Disputed | `4000 0000 0000 0259` | Creates a dispute |
| Interac (Canada) | `2223 0031 2200 3222` | Interac debit test |

All test cards: expiry = any future date, CVC = any 3 digits, postal = any valid Canadian.

---

## Audit Webhook Dashboard Tool
```bash
# Quick audit: compares code handlers vs Stripe Test dashboard vs Live dashboard
./scripts/audit-stripe-webhooks.sh
```

---

## ⚠️ Active Incidents (check before debugging)

### Staging Webhook Failure (2026-02-24 onwards)
- **URL:** `https://northamerica-northeast1-orignagta-staging.cloudfunctions.net/stripe_webhook`
- **Symptom:** 3,655+ failed webhook retries; Stripe stops retrying 2026-03-05
- **Impact:** Subscription invoices delayed ≤3 days; `checkout.session.completed` may not process
- **Fix:** Redeploy staging functions OR disable this webhook endpoint in Stripe dashboard
- **Diagnose:** `gcloud functions logs read stripe_webhook --project=orignagta-staging --limit=50`

### Webhook OOM (fixed, deployed)
- Default 256 MiB insufficient — stripe_webhook processes orders + payouts + digital licenses
- Fix: `WEBHOOK_OPTIONS` uses `memory: options.MemoryOption.MB_512` in `functions/utils/function_options.py`

---

## Known Bugs Found & Fixed (February 2026 Audit + E2E Marathon)

### P0 — `source_transaction` received PI ID instead of Charge ID
**File:** `payment_stripe.py` ~L2560 in `capture_payment`
**Bug:** `source_transaction=payment_intent_id` → Stripe rejects with "must be a non-platform charge"
**Fix:** Retrieve `payment_intent.latest_charge` after capture, use `charge_id` for transfers
**Note:** `cron_jobs.py` already had the correct pattern — `capture_payment` was inconsistent

### P0 — Duplicate order response crashed frontend
**Bug:** Backend returned `{duplicate: true}` without `checkoutUrl` → frontend cast `null as String`
**Fix:** Backend now retrieves existing session URL, frontend checks `duplicate` before casting

### P0 — SERVER_TIMESTAMP inside ArrayUnion crashes Firestore
**Bug:** 8 locations in `orders.py` and `payment_stripe.py` used `get_server_timestamp()` inside array elements or `ArrayUnion()`. Firestore cannot serialize the sentinel value inside arrays.
**Fix:** Replace with `datetime.now(timezone.utc)` for all nested timestamps. Keep `get_server_timestamp()` only for top-level fields.

### P0 — Missing payout records in auto-capture idempotent path
**Bug:** `_capture_payment_impl` returned early when `payment_status == 'captured'` without creating payout records or Stripe transfers.
**Fix:** Added payout record creation and transfer logic to the "already captured" idempotent path.

### P0 — `capture_payment` decorator incompatible with `confirm_order_receipt`
**Bug:** `confirm_order_receipt` (in `orders.py`) tried to call `capture_payment(req)` but `capture_payment` is decorated with `@https_fn.on_call()` which expects Flask Request, not CallableRequest.
**Fix:** Extract undecorated `_capture_payment_impl(req)` and call that from `confirm_order_receipt`.

### P1 — `payment_method_types: ['card']` hardcoded
**Bug:** Blocked Apple Pay, Google Pay, Interac (important in Canada)
**Fix:** Removed — Stripe auto-selects based on Dashboard settings. This was also the root cause of Stripe's `return_url` email warning.

### P2 — Refund failure silently ate money
**Bug:** In `_restore_stock_and_cancel_order`, if `stripe.Refund.create()` failed, order was still marked CANCELLED → buyer lost money
**Fix:** Log CRITICAL security alert + flag `requires_manual_review` if refund fails

---

## Key Business Rules

| Rule | Value | Constant |
|------|-------|----------|
| Platform fee | 2.5% | `BusinessRules.PLATFORM_FEE_RATIO = 0.025` |
| Auto-confirm days | 5 | `BusinessRules.AUTO_CONFIRM_DAYS = 5` |
| Auth expiry | 6 days | `BusinessRules.AUTHORIZATION_EXPIRY_DAYS = 6` |
| Max capture attempts | 3 | `BusinessRules.MAX_CAPTURE_ATTEMPTS = 3` |
| Currency | CAD | `BusinessRules.DEFAULT_CURRENCY = "cad"` |
| Max order amount | $100,000 CAD | `BusinessRules.MAX_ORDER_AMOUNT_CAD = 100000` |
| Checkout rate limit | 5/min/user | `BusinessRules.CHECKOUT_RATE_LIMIT = 5` |
| Webhook rate limit | 100/min/IP | `BusinessRules.WEBHOOK_RATE_LIMIT_PER_MINUTE = 100` |
| Webhook max age | 5 min (300s) | `BusinessRules.WEBHOOK_MAX_AGE_SECONDS = 300` |
| Order dedup window | 60s | `BusinessRules.ORDER_DEDUP_WINDOW_SECONDS = 60` |
| Network retries | 2 | `BusinessRules.STRIPE_MAX_NETWORK_RETRIES = 2` |
| Delivery instructions max | 500 chars | `BusinessRules.MAX_DELIVERY_INSTRUCTIONS_LENGTH = 500` |
| Item quantity max | 100 | `ValidationLimits.MAX_ITEM_QUANTITY = 100` |

---

## Order Status State Machine

```
PENDING → CONFIRMED → PROCESSING → SHIPPED → IN_TRANSIT → DELIVERED
   ↓         ↓            ↓           ↓
EXPIRED   CANCELLED     CANCELLED   (cannot cancel after shipped)
                                        ↓
                                    REFUNDED / PARTIALLY_REFUNDED
                                        ↓
                                    DISPUTED (from any post-payment state)
```

## Payment Status State Machine

```
AWAITING_PAYMENT → CAPTURED (auto-capture at checkout)
                 → AUTHORIZED → CAPTURING → CAPTURED (manual capture)
                                          → CANCELLED
                 → PAYMENT_FAILED
                 → SESSION_EXPIRED
CAPTURED → REFUNDED / PARTIALLY_REFUNDED
AUTHORIZED → AUTHORIZATION_EXPIRED (7-day cron)
```

---

## Cross-Stack Sync Checklist

When changing payment fields, update ALL of these:

1. `functions/schema_constants.py` — `Fields`, `OrderStatusValues`, `PaymentStatusValues`, `ApiKeys`
2. `origna_gta/lib/core/schema/schema_constants.dart` — Mirror of above
3. `origna_gta/lib/utils/constants.dart` — `OrderStatus`, `PaymentStatus` enums
4. `origna_gta/lib/models/generated/order_models.dart` — Freezed models
5. `docs/database_schema.json` — Firestore schema
6. Backend tests in `functions/tests/`
7. E2E tests in `e2e/`

---

## E2E Payment Test Suites (Playwright)

### `payment-workflow-e2e.spec.ts` — 54 tests in 10 suites

| Suite | Tests | What |
|-------|-------|------|
| A. Checkout Validation | 12 | Auth, empty items, missing address, invalid postal, out-of-stock, price mismatch, seller ID tamper, self-purchase, subtotal mismatch, qty > 100, suspended buyer, suspended seller |
| B. Single-Seller Checkout | 5 | Create session, verify order doc, pay via Stripe, webhook updates, stock decremented |
| C. Multi-Seller Checkout | 5 | 2 sellers in 1 order, multiple sellerIds, pay, webhook confirms, item sellerId retained |
| D. Order Status Lifecycle | 5 | Processing → shipped → in_transit → delivered, invalid transition rejected |
| E. Cancellation & Refund | 5 | Cancel confirmed order, stock restored, no double-cancel, cannot cancel shipped |
| F. Concurrent Checkouts | 4 | 5 simultaneous buyers, stock race condition (3 units), rate limiting, 10 provinces |
| G. Price Tiers & Tax | 5 | Budget ($1.99), high-value ($4999.99), multi-quantity, tax non-zero, total equation |
| H. Digital & Free Shipping | 3 | Digital = $0 shipping, free-shipping physical = $0, non-free > $0 |
| I. Security & Permissions | 6 | Buyer can't update status, can't cancel others' orders, not-found, un-onboarded seller, admin overrides |
| J. Email Notifications | 3 | Email delivery verification |

### Running E2E Payment Tests
```bash
# Full payment suite
cd e2e && npx playwright test payment-workflow-e2e.spec.ts

# Specific suite
cd e2e && npx playwright test payment-workflow-e2e.spec.ts -g "A. Checkout Validation"

# With headed browser (see Stripe Checkout)
cd e2e && npx playwright test payment-workflow-e2e.spec.ts --headed

# Shipping lifecycle (includes capture_payment)
cd e2e && npx playwright test shipping-lifecycle-e2e.spec.ts

# Logic attack vectors
cd e2e && npx playwright test logic-failures-e2e.spec.ts
```

### Running Backend Payment Tests
```bash
cd functions && source venv/bin/activate

# All payment tests
pytest tests/test_handlers_payment_stripe.py tests/test_payment_integration.py tests/test_payment_security.py -v

# Specific test
pytest tests/test_handlers_payment_stripe.py -k "test_checkout_creates_order" -v

# With coverage
pytest tests/test_handlers_payment_stripe.py --cov=handlers/payment_stripe --cov-report=term-missing
```

---

## Gotchas & Anti-Patterns

### NEVER DO
- ❌ `payment_method_types=['card']` — blocks Apple Pay, Google Pay, Interac
- ❌ `source_transaction=payment_intent_id` — must be `charge_id` (ch_xxx)
- ❌ Hardcode rate limits, timeouts — use `BusinessRules.*` constants
- ❌ Ignore refund failures — ALWAYS flag for manual review
- ❌ Trust client-sent prices — backend re-fetches from Firestore
- ❌ Skip stock restoration on any cancellation/failure path
- ❌ Use `stripe.PaymentIntent.create()` directly — use Checkout Session
- ❌ Log payment amounts or card details in error messages

### ALWAYS DO
- ✅ Use `idempotency_key` on all Stripe API calls
- ✅ Check `Fields.STOCK_RESTORED` before restoring (idempotent)
- ✅ Verify webhook signature before processing
- ✅ Check terminal states before updating (prevent overwrite)
- ✅ Create PENDING payout record BEFORE `Transfer.create()`
- ✅ Use `BusinessRules.PLATFORM_FEE_RATIO` (not hardcoded `0.025`)
- ✅ Store `seller_stripe_accounts` snapshot at checkout time
- ✅ Re-validate seller suspension at capture time

---

## Emulator Mode Behavior

When `IS_EMULATOR = True` (detected via `FUNCTIONS_EMULATOR` env var):
- Email verification check is **skipped** (tokens may not carry `email_verified`)
- Webhook rate limiting is **skipped** (avoids Firestore transaction issues)
- Stale webhook rejection is **skipped**
- `capture_payment` returns mock success for non-real PI IDs
- Stripe API still uses **real test keys** (`sk_test_*`) — it's micro-staging, not fully mocked

### Emulator Ports
| Service | Port |
|---------|------|
| Functions | 5001 |
| Firestore | 8080 |
| Auth | 9099 |
| Storage | 9199 |
| Emulator UI | 4000 |

### Webhook Endpoint (Local)
```
http://127.0.0.1:5001/orignagta/us-central1/stripe_webhook
```

### Production Webhook Endpoint
```
https://us-central1-orignagta.cloudfunctions.net/stripe_webhook
```

---

## Payment Audit Checklist

Run before any release:

- [ ] `./scripts/audit-stripe-webhooks.sh` — Code vs Dashboard in sync
- [ ] `pytest tests/test_handlers_payment_stripe.py tests/test_payment_integration.py -v` — All pass
- [ ] `npx playwright test payment-workflow-e2e.spec.ts` — All 54 pass
- [ ] Verify `source_transaction` uses charge_id (ch_xxx), NOT payment_intent_id
- [ ] Verify NO `payment_method_types` hardcoded in Session.create
- [ ] All rate limits use `BusinessRules.*` constants
- [ ] All refund/cancel paths have error handling + manual review flags
- [ ] Idempotency keys on all Stripe API calls
- [ ] No sensitive data in log messages
- [ ] `schema_constants.py` and `schema_constants.dart` status values match
- [ ] `constants.dart` enums include ALL statuses (including `disputed`, `capturing`, etc.)
