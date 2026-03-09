---
paths:
  - "**/payment*"
  - "**/checkout*"
  - "**/stripe*"
  - "functions/handlers/payment_stripe.py"
  - "origna_gta/lib/features/checkout/**"
---

# Payment Rules

- Direct Charges + Connect Express. 2.5% fee. Auto-capture. CAD only.
- Price re-verification: backend re-fetches from Firestore (±$0.01)
- Idempotency keys required. Self-purchase blocked. Webhook dedup via `webhook_events`.
- `_capture_payment_impl` for internal calls (NOT decorated `capture_payment`)
- `source_transaction` = charge ID (`ch_xxx`), NOT PaymentIntent
- Cross-check: `payment_stripe.py` ↔ `checkout_provider.dart` ↔ `orders.py` ↔ `cron_jobs.py`
