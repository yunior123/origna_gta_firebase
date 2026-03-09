## EMAIL NOTIFICATIONS FINDINGS

### CRITICAL
1. FAILED order status → NO email sent to buyer (orders.py:2294) — CASL violation
2. Authorization EXPIRED email function exists but NEVER called (payment_stripe.py:2807)
3. DISPUTED orders → NO buyer notification requesting evidence → platform loses chargebacks
4. Seller notification ONLY via webhook path → admin/cron-confirmed orders = seller misses order

### HIGH
5. PENDING order → no confirmation email to buyer
6. Seller receives "shipment confirmed" for orders they just shipped (self-notification bug)
7. Low stock alerts ignore `emailConsent` — Quebec Law 25 violation (cron_jobs.py:1517)
8. Abandoned cart emails missing CASL unsubscribe link + physical address (cron_jobs.py:1631)
9. Return approved email missing return address and deadline
10. Premium renewal reminders sent to CANCELLED users (cron_jobs.py:2102)
11. DELIVERED email duplicate send on retry (dedup happens AFTER send)

### SUMMARY
42% of order status transitions (5/12) send NO email — FAILED, EXPIRED, DISPUTED, PENDING, (seller on non-webhook CONFIRMED)
Low stock + abandoned cart templates hardcoded English only — Quebec Bill 96 violation
