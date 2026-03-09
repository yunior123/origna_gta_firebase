## COUPONS & DISCOUNTS FINDINGS

### CRITICAL
1. `_coupon_within_limits()` doesn't re-check expiry — coupon validated at 23:59:59 can expire between validation and pre-reservation (payment_stripe.py:524)

### HIGH
2. `apply_coupon` per-user usage check outside transaction — race condition allows multiple concurrent passes (coupons.py:164)
3. `_rollback_checkout()` rolls back usedCount but NOT per-user useCount subcollection (payment_stripe.py:213)

### MEDIUM
4. `pending_redemptions` retry mechanism exists but retry job not implemented — lost redemptions possible (coupons.py:273)

### LOW
5. Failed coupon attempts not stored for fraud detection
6. No explicit stacking prevention documentation

### VERIFIED OK
- Multi-seller discount allocation correct (seller-scoped coupons)
- Rate limiting on create_checkout_session (5/min) sufficient
- Client-computed discount is UI-only; server revalidates
