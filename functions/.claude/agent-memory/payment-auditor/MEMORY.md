# Payment Auditor Memory

## Architecture Overview (as of 2026-02-18)
- **Capture mode**: Automatic capture at checkout (NOT manual capture). Payment is charged immediately.
- **Seller payouts**: Via `stripe.Transfer.create()` with `source_transaction=charge_id` after buyer confirms delivery or auto-confirm cron (5 days).
- **Platform fee**: 2.5% stored at checkout in `platformFeeCents`, applied at payout time.
- **Config**: `PLATFORM_FEE_PERCENT` in config.py is actually RATIO (0.025), not percent. Aliased correctly.
- **Fee base**: Platform fee calculated on product subtotal only (not tax/shipping).

## Key Security Controls Already in Place
- Webhook HMAC signature verification via `stripe.Webhook.construct_event()`
- Webhook idempotency via `webhook_events` collection with atomic `create()`
- Stale webhook rejection (5-minute max age)
- Rate limiting on all endpoints
- Self-purchase prevention (seller_id == user_id blocked)
- Price re-fetch from Firestore (never trust client prices)
- Seller Stripe account snapshot at checkout (prevents account swap attack)
- Transaction-based capture lock (AUTHORIZED -> CAPTURING) to prevent double capture
- Cancel/capture race protection via CANCELLING/CAPTURING transitional states

## Known Finding: Partial Refund Price Float
- `refund_order_item` at line 834: `item_price_cents = round(item_data[Fields.PRICE] * 100)` uses float price from order item
- Since `Fields.PRICE` is stored as dollars (float), rounding can introduce 1-cent errors on large quantities

## Audit Completed: 2026-02-18
See `audit-findings.md` for full results.
