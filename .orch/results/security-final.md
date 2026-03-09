## SECURITY AUDIT FINDINGS

### CRITICAL
1. 7 Firestore collections missing rules → attacker can read/write via client SDK:
   - seller_ratings, _cron_locks, seller_skus, pending_redemptions, platform_debt, order_events, chat_messages subcollection name mismatch

### HIGH
2. Webhook secret cached module-level — rotation needs cold start (payment_stripe.py:105)
3. Rate limiting bypassed in emulator mode entirely (payment_stripe.py:1760) — dev only

### MEDIUM
4. product questions (ask_product_question) stored without sanitized_text() call (products.py:3700)
5. Seller self-purchase via second account — only uid check, not address/payment fingerprint
6. Auth failures not logged to security_alerts collection

### LOW
7. Seller profiles writable by admin client SDK (firestore.rules:724) — should be Admin SDK only
8. Debug error messages leak internal seller IDs (payment_stripe.py:784)
9. Weak GST number validation format
10. Unlimited cart size (no total item limit)
11. Webhook replay window 300s — should be 60s
