# Payment Auditor Memory

## Key Architecture Facts

### Payment Mode: Auto-Capture (NOT Manual Capture)
- `create_checkout_session` uses `mode="payment"` WITHOUT `capture_method="manual"` (line 1055)
- PaymentIntent goes directly to `succeeded` state after checkout
- Seller payouts done via `stripe.Transfer.create()` after delivery, not via capture
- `paymentStatus` is always `'captured'` per LEARNED.md
- Authorization expiry (7-day limit) is NOT relevant in auto-capture mode

### Shipping Address Flow
- Address is collected in Flutter UI BEFORE checkout, NOT by Stripe
- `shipping_address_collection` is NOT set on the checkout session (line 1053)
- Therefore `session.shipping_details` in webhooks is always null/empty
- The address comparison block (lines 1352-1383) is currently dead code by design
- Amount verification (lines 1342-1350) is the primary financial integrity check

### Webhook Security Stack (in order)
1. Rate limiting by IP (line 1160-1175)
2. HMAC signature verification via `stripe.Webhook.construct_event` (line 1187)
3. Replay attack prevention - reject events >5min old (lines 1202-1212)
4. Idempotency via Firestore `create()` (lines 1214-1249)
5. Order state verification - only process PENDING orders (line 1338)
6. Amount verification - session total must match order total (lines 1342-1350)
7. Product/seller re-validation (lines 1385-1413)

### Country Code Format Issue
- Stripe uses ISO codes: "CA"
- Order documents store full names: "Canada"
- If `shipping_address_collection` is ever enabled, the country comparison (line 1370) will always mismatch
- Noted as dormant bug for future reference

### Stock Restoration Pattern
- `Fields.STOCK_RESTORED` flag prevents double-restore (idempotency)
- `_add_stock_restore_to_batch` uses `firestore.Increment` for atomic updates
- `_restore_stock_and_cancel_order` does batch write (stock + order cancel) then Stripe refund
- If refund fails: security alert created + manual review flag set on order

## Audit History
- 2026-02-18: Audited address mismatch check fix (lines 1352-1383). SAFE. No vulnerabilities introduced.
