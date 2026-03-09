## LOGIC AUDIT FINDINGS

### CRITICAL
1. Duplicate order detection runs AFTER stock reservation → stock permanently lost on duplicate (payment_stripe.py:1172)
2. Coupon pre-reservation AFTER stock reservation → stock lost if coupon limit exceeded (payment_stripe.py:1434)
3. Cancelled orders can be re-confirmed by replayed webhooks → no transactional CAS (payment_stripe.py:2320)
4. Digital items still execute warehouse stock logic → corrupts warehouse stock maps (payment_stripe.py:1318)
5. Product deletion checks pending orders by seller_ids (wrong) → products with orders can be deleted (products.py:566)

### HIGH
6. Cancel blocked if CAPTURING state → orders stuck uncancellable (orders.py:701)
7. confirm_item_receipt allows confirming PENDING items → triggers payout before shipping (orders.py:139)
8. Stock restore outside transaction with cancel status → double restore on retry (orders.py:785)
9. Payout status check without lock → double-spend: seller payout + buyer refund (orders.py:913)
