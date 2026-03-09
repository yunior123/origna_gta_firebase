## PAYMENT PIPELINE FINDINGS

### CRITICAL
1. Platform fee calculated on post-discount subtotal — business logic unclear, may be wrong (payment_stripe.py:1524)
2. Tax calculations use float math: `round(taxable_total * rate, 2)` → penny rounding errors in manual fallback (payment_stripe.py:1116)
3. Payout idempotency only checks COMPLETED status — webhook retries can create duplicate PENDING payout records (payment_stripe.py:2112)

### HIGH
4. Address comparison is dead code (shipping_address_collection not enabled) — will break if enabled (payment_stripe.py:2324)
5. Charge ID extraction: if Stripe changes response format, wrong ID passed to Transfer API (payment_stripe.py:2462)
6. Coupon pre-reserve + redemption flow is correct but fragile — race condition if webhook processes before order doc update

### MEDIUM
7. Webhook secret cached module-level — secret rotation requires cold start (payment_stripe.py:104)
8. Stock reservation outside order creation transaction — stock leaked if order creation fails (payment_stripe.py:1419)
9. No seller account status check before reversing transfer on refund (payment_stripe.py:2950)

### LOW
10. Digital license generation failure only logs — buyer gets confirmation without license keys (payment_stripe.py:2172)
11. No 3DS `requires_action` handling found

### VERIFIED OK
- PaymentIntent amount validation (exact cents comparison)
- Self-purchase blocked
- Price tampering prevented (server re-fetches from Firestore)
- Multi-seller splits correct
- Webhook HMAC signature verification present
- Digital product skips stock decrement
