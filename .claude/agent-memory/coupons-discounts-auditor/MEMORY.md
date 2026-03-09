# Coupon & Discount Auditor Memory

## Critical Architecture Decisions

### Pre-reservation Pattern (payment_stripe.py lines 1109-1112)
- Coupons atomically pre-reserved in checkout transaction BEFORE Stripe session creation
- Increments global `usedCount` (Increment(1)) and per-user `useCount` in same transaction
- If Stripe fails, rollback via `_rollback_checkout()` decrements the counts
- Order doc has `couponPrereserved: true` flag to prevent double-redemption in webhook

### Seller-Scoped Coupon Discount Calculation (payment_stripe.py lines 1616-1670)
- Platform-wide coupons: discount applies to full cart subtotal
- Seller-scoped coupons: discount only applies to that seller's items
- Payout logic correctly handles both cases with separate ratio computation

### Validation Flow
1. `apply_coupon` (client preview) - non-binding, returns discount estimate
2. `create_checkout_session` SHOULD re-validate at checkout time but **currently does NOT**
3. `redeem_coupon` only called if `couponPrereserved` is false (fallback path)

## CRITICAL Finding: Coupon Code Never Read in Checkout (2026-03-01)
- `coupon_code` initialized to `None` at payment_stripe.py line 838
- Client sends `Fields.couponCode` in checkout payload (checkout_provider.dart line 370)
- Backend `create_checkout_session` NEVER reads it from `data.get(Fields.COUPON_CODE)`
- Result: all coupons silently ignored at checkout; no discount applied; no pre-reservation
- All coupon helpers (`_coupon_not_expired`, `_coupon_within_limits`, etc.) are dead code
- The entire order always records `couponCode: null, discountAmountCents: 0`

## Rollback Bug: Wrong Field Name (payment_stripe.py line 227)
- Uses `Fields.COUNT` ("count") instead of `"useCount"` when decrementing
- Means rollback silently fails to properly decrement per-user usage

## Magic Strings Found
- `"isActive"` in coupons.py lines 142, 369, 398 (not in Fields)
- `"couponPrereserved"` in payment_stripe.py line 1832 (should use Fields.COUPON_PRERESERVED)

## Platform Fee Bug (payment_stripe.py line 1009)
- Uses `actual_subtotal_cents * PLATFORM_FEE_RATIO` (pre-discount)
- If coupons were working, this would be correct (sellers should pay fee on full amount)
- But payout logic (line 1670) computes fee on post-discount amount
- This creates an inconsistency between order's stored fee and actual payout fees

## No Retry Job for pending_redemptions
- `redeem_coupon` writes to `pending_redemptions` on failure (coupons.py line 277)
- No cron job exists to retry these pending redemptions
