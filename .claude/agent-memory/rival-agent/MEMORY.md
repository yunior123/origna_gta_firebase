# Rival Agent Memory

## Last Analysis: 2026-02-27

### P0 Findings (8 total)
1. F-33: Fake 4.5 default rating (Competition Bureau risk) - modern_product_card.dart:32
2. F-100: Variant data NOT in checkout payload - checkout_provider.dart:308-323
3. F-24: No inventory reservation at checkout (oversell risk)
4. F-303: No FSM enforcement on dispute flow (skip-state risk)
5. F-305: Idempotency window 60s too short for webhook delays
6. F-306: No escrow hold on dispute initiation (exit scam)
7. NEW-R1: CartItemDetailModel lacks variantId - models.dart:153
8. NEW-R2: No per-seller shipping breakdown in cart/checkout UI

### P1 Findings (18 items)
- No sort options, No price filter, No reorder
- No tracking URL (only number), No brand field
- No seller badge, Float money math, No free shipping badge
- No photo reviews, No review moderation, No low stock indicator
- No return window display, No variant-specific images
- Shipping picks first warehouse not closest
- No soft reservation (Medusa pattern)
- No order status timeline UI, No delivery date on cards
- No guest checkout (37% abandon rate), No recommendations

### Confirmed Corrections from Prior Analysis
- Apple Sign-In IS implemented (auth_repository.dart:219)
- Buyer protection banner EXISTS (checkout_screen.dart:1001)
- OrderEvents subcollection EXISTS (schema_constants.py:73)
- Save for later has UI button (cartitem_screen.dart:296)
- coupon_uses subcollection replaces usedByUids array (schema_constants.py:74)

### Competitor Patterns (2025-2026 verified)
- Medusa v2: ReservationItem entity + reserveQuantityStep
- Medusa v2: Variant images pivot (ProductVariantProductImage)
- Medusa v2: Cart splitting per vendor workflow
- Saleor: Stock reservation with TTL + CheckoutLine.problems
- Vendure: FSM for Order/Fulfillment/Payment state transitions
- WooCommerce: Per-vendor shipping calc + cart breakdown
- Spree 5: Returns/refunds per-vendor, unified checkout splits orders

### Key Code Locations
- modern_product_card.dart:32 - rating = 4.5 default
- checkout_provider.dart:308-323 - missing variantId in payload
- models.dart:153 - CartItemDetailModel no variantId field
- cart_provider.dart:47-74 - no variant info in detail model
- payment_stripe.py:1280-1299 - backend DOES handle variantId (mismatch!)

### What OrignaGTA Does Well
- Apple Sign-In + Google Sign-In + biometric guard >$100
- Buyer protection banner + OrderEvents audit trail
- Save for later (method + UI), Circuit breaker pattern
- Immutable order snapshots, Multi-warehouse stock
- CASL/PIPEDA/Quebec Law 25 compliance, Digital products
- Per-seller commission + seller metrics, Product Q&A
- Coupon pre-reservation + rollback, Abandoned cart cron
