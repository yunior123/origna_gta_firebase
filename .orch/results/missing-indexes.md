## MISSING FIRESTORE INDEXES — 17 CRITICAL

Indexes already ADDED to firestore.indexes.json by agent. Needs deploy.

### What would break in production without these:
1. Checkout idempotency checks — duplicate orders (payment_stripe.py:1177)
2. Admin suspend_seller — cannot suspend bad actors (admin.py:390)
3. Expired authorization cron — payment holds never expire (cron_jobs.py:675)
4. Payout webhooks — sellers never receive money (payment_stripe.py:3732)
5. Stock notifications — duplicate subscription emails (products.py:3548)
6. Account deletion guards — data corruption (admin.py:1225)
7. Duplicate rating prevention — integrity violations (products.py:795)
8. Renewal reminder emails — missed notifications (cron_jobs.py:2097)

### Deploy command:
firebase deploy --only firestore:indexes --project orignagta-dev
firebase deploy --only firestore:indexes --project orignagta-staging
firebase deploy --only firestore:indexes --project orignagta

### Collections:
- orders (9 indexes), payouts (4), security_alerts (3), subscriptions (1), stock_notifications (1), product_ratings (1)
