# Email Notifications Auditor — Memory

## Key Patterns Observed (confirmed across multiple reads)

### Deduplication mechanism
- Order status emails: `notifications_sent` ArrayUnion (transactional) in `orders/{orderId}`
- Payment status emails: `notifications_sent` keyed as `"payment_{status}"` (transactional)
- Return emails: `notifications_sent` ArrayUnion in `return_requests/{returnId}`
- auth_expired + capture_failed emails: NO dedup guard (called directly, fire-and-forget)

### CASL compliance — by email type
- All transactional order emails: exempt from consent gate, unsubscribe link always included via `_casl_compliant_footer()`
- Low-stock seller alerts: gated on `emailConsent=True` (non-transactional treatment)
- Abandoned-cart: gated on `marketingOptIn=True` AND `emailConsent=True`
- Dispute/resolution emails to sellers: NO consent gate, plain HTML, no CASL footer
- Low-stock emails: no `_casl_compliant_footer()`, plain HTML but has physical address inline

### Missing i18n key
- `sub.new_order_seller` used in `orders.py:2361` but NOT defined in `_EMAIL_STRINGS` dict
- Falls back to the raw key string as subject — broken for both EN and FR

### Language resolution
- Buyer lang: `order_data.get(Fields.PREFERRED_LANGUAGE, "en")` — correct
- Seller lang: from seller user doc `Fields.PREFERRED_LANGUAGE` — correct
- `send_authorization_expired_email`: takes `lang` from `order_data.get(Fields.PREFERRED_LANGUAGE, "en")` in cron — correct

### Recipient routing
- Buyer emails go to `Fields.CUSTOMER_EMAIL` with fallback to `users/{uid}.email`
- Seller emails fetched from `users/{seller_id}.email`
- `get_seller_notification_email` filters items by `seller_id` — multi-seller privacy correct

### Trigger paths
- Payment confirmed (Stripe webhook) → `_run_post_payment_side_effects` → buyer + seller emails
- Order status changed (Firestore trigger) → `on_order_status_changed` → emails for all statuses
- Both paths fire on CONFIRMED: potential duplicate for buyer confirmation email (see audit findings)
- Auth expired (cron) → direct `send_authorization_expired_email` call — no enqueue_email_task
- Capture failed → `send_payment_capture_failed_email` direct call — no enqueue_email_task

### Email send failure handling
- `enqueue_email_task` calls are always inside try/except — non-blocking (fire-and-forget + log)
- `send_email` (sync) for PDF attachment path in payment_stripe.py:1778 — blocks webhook handler

See: `findings.md` for the full audit findings list
