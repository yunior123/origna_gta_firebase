# Email Audit Findings — 2026-03-01

## CRITICAL

### C1 — Missing i18n key `sub.new_order_seller` causes broken subject line
- File: `functions/handlers/orders.py:2361`
- `_email_t("sub.new_order_seller", _slang_c)` — this key does NOT exist in `_EMAIL_STRINGS`
- `_t()` falls back to returning the raw key `"sub.new_order_seller"` as the subject
- Both EN and FR seller notification emails on CONFIRMED status have a corrupted subject
- Fix: add `"sub.new_order_seller": {"en": "New Order Received - Origna", "fr": "Nouvelle commande reçue - Origna"}` to `_EMAIL_STRINGS` in `email_service.py`

### C2 — Duplicate buyer order-confirmation email on CONFIRMED
- Stripe webhook path (`payment_stripe.py:_run_post_payment_side_effects`) sends buyer confirmation
- Firestore trigger `on_order_status_changed` ALSO sends buyer confirmation when `new_status == CONFIRMED`
- The dedup guard (`notifications_sent` array) only covers the Firestore trigger path
- When Stripe confirms the order, it updates `orderStatus=CONFIRMED` which fires the Firestore trigger — buyer receives two identical emails
- Fix: Either check `notifications_sent` in `_run_post_payment_side_effects` before sending, or set `notifications_sent` atomically in the webhook path so the Firestore trigger dedup fires correctly

## HIGH

### H1 — `send_email()` blocks Stripe webhook for PDF invoice path
- File: `functions/handlers/payment_stripe.py:1778`
- When a PDF invoice is generated, `send_email()` is called synchronously inside the webhook handler
- If Mailjet is slow (>5-10s) this delays the webhook response and can cause Stripe to retry
- Fix: Encode PDF into Cloud Tasks payload or store in Cloud Storage and reference by URL; use `enqueue_email_task` even with attachments

### H2 — Dispute/resolution emails have no CASL-compliant footer
- Files: `functions/handlers/payment_stripe.py:3015-3030` (dispute created), `3256-3266` (dispute resolved)
- Raw inline HTML with no `_casl_compliant_footer()`, no unsubscribe link, no physical address
- These are sent to sellers — CASL requires physical address + unsubscribe in all commercial email
- Fix: Wrap dispute emails with `_email_wrapper()` or at minimum inject `_casl_compliant_footer()`

### H3 — Low-stock alert emails missing CASL-compliant footer wrapper
- File: `functions/handlers/cron_jobs.py:1516-1538`
- Plain HTML with physical address hardcoded as plain text, but no `List-Unsubscribe` header, no unsubscribe hyperlink
- The email is gated on `emailConsent=True` but the unsubscribe mechanism is only described in prose ("edit the product and uncheck..."), not as a clickable link
- CASL requires a functional unsubscribe mechanism
- Fix: Wrap with `_email_wrapper()` using `recipient_email=seller_email` for signed unsubscribe URL

### H4 — `send_authorization_expired_email` not using `enqueue_email_task`
- File: `functions/services/email_service.py:1965`, called from `functions/handlers/cron_jobs.py:809`
- Called directly (synchronous `send_email()`), inside a `ThreadPoolExecutor` thread during cron
- If Mailjet times out, the entire thread blocks and the cron run is delayed
- No deduplication — if cron re-runs or retries, the expired email fires again
- Fix: Change to `enqueue_email_task` and add dedup via order `notifications_sent`

## MEDIUM

### M1 — `send_payment_capture_failed_email` no deduplication
- File: `functions/services/email_service.py:1968`, called from payment handlers
- Synchronous `send_email()` call with no idempotency guard
- If the caller retries on error, buyer receives multiple "payment issue" emails
- Fix: Add `notifications_sent` dedup similar to other payment status emails

### M2 — Seller `SHIPPED` confirmation email uses wrong template
- File: `functions/handlers/orders.py:2459-2468`
- When order status goes to SHIPPED, sellers receive `get_seller_notification_email()` — the "New Order Received" template
- Subject is `sub.shipped_seller` ("Order Shipped Successfully") but the template body says "New Order Received!" and "Ship it fast!" — content mismatch
- Fix: Create a dedicated `get_seller_shipped_confirmation_email()` template or use a generic wrapper

### M3 — `get_order_refunded_email` missing `recipient_email` for unsubscribe URL
- File: `functions/services/email_service.py:1647`
- `_email_wrapper("Order Refunded", content, include_gst=False, lang=lang)` — no `recipient_email`
- CASL footer falls back to the generic `UNSUBSCRIBE_URL` instead of the personalized signed URL
- Fix: Pass `recipient_email=order_data.get(Fields.CUSTOMER_EMAIL, '')`

### M4 — `get_order_partially_refunded_email` missing `recipient_email`
- File: `functions/services/email_service.py:1713`
- Same as M3 — `_email_wrapper("Partial Refund", content, include_gst=False, lang=lang)` with no `recipient_email`
- Fix: Pass `recipient_email=order_data.get(Fields.CUSTOMER_EMAIL, '')`

### M5 — RETURNED status in `on_return_request_status_changed` sends no email
- File: `functions/handlers/orders.py:2837-2851`
- `ReturnStatusValues.RECEIVED` push notifications sent to both buyer and seller but `_send_return_email(...)` is NOT called
- For RECEIVED status, `_send_return_email` handles the buyer email — but it is only called from the REQUESTED/APPROVED/REJECTED/RECEIVED/REFUNDED branches in `_send_return_email` directly
- Looking again at line 2837: the trigger calls push but not `_send_return_email` for RECEIVED — buyer gets push but no email
- Fix: Add `_send_return_email(after_data, return_id, order_id, buyer_id, seller_id, ReturnStatusValues.RECEIVED)` in the RECEIVED branch

## LOW

### L1 — `sub.ready_for_pickup` i18n key defined but subject constructed inline for pickup orders
- File: `functions/handlers/orders.py:2422-2431`
- The `on_order_status_changed` SHIPPED handler skips email for pickup orders (correct), but the `on_order_item_shipped` trigger sends pickup notification using inline string, not the `sub.ready_for_pickup` key
- Minor inconsistency — not a bug but violates the "no magic strings" rule

### L2 — Seller `DELIVERED` payout-pending email body hardcoded (not in `_EMAIL_STRINGS`)
- File: `functions/handlers/orders.py:2559-2567`
- Inline EN/FR strings instead of using the `_EMAIL_STRINGS` table
- Makes future string changes harder and inconsistent with the bilingual table pattern
- Fix: Add keys to `_EMAIL_STRINGS` and use `_t()`

### L3 — `get_order_item_delivered_email` hero subtext hardcoded in English
- File: `functions/services/email_service.py:2081`
- `"Good news! Items from order #{short_oid} have arrived."` — no FR translation
- Fix: Add to `_EMAIL_STRINGS` and use `_t()`
