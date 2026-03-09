---
applyTo: "**/payment*,**/checkout*,**/stripe*"
---

# Payment System Context

## Stripe Connect Model
- **Direct Charges** with Connect Express accounts
- Platform fee: **2.5%** (`BusinessRules.PLATFORM_FEE_RATIO`)
- Flow: Checkout → Authorization → Ship → Capture (7-day window) → Transfer to seller
- Currency: **CAD only**

## Critical Invariants
- **Price verification**: Backend re-fetches from Firestore, validates ±$0.01
- **Idempotency**: ALL operations use event_id or idempotency keys
- **Self-purchase blocked**: `sellerId != buyerId` enforced in backend
- **Webhook dedup**: `webhook_events` collection with event_id
- **Dispute auto-reversal**: `handle_dispute_created()` reverses transfers
- **`source_transaction`**: MUST be charge ID (`ch_xxx`), NOT PaymentIntent (`pi_xxx`)
- **Refund failures**: Create SECURITY_ALERTS + flag `requires_manual_review`
- Do NOT hardcode `payment_method_types` — Stripe Dashboard controls methods

## Files to Cross-Check (always read together)
- `functions/handlers/payment_stripe.py` ↔ `lib/features/checkout/checkout_provider.dart`
- `functions/handlers/orders.py` ↔ `lib/features/orders/*.dart`
- `functions/handlers/cron_jobs.py` (auto-confirm, expired auth)
