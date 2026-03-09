## CRON JOBS FINDINGS

### CRITICAL
1. Unbounded Firestore scan in `cleanup_stale_webhook_events` — no `.limit()` clause → OOM at scale (cron_jobs.py:1141)
2. Unbounded scan in `cleanup_stale_security_alerts` — no `.limit()` (cron_jobs.py:1181)
3. No Sentry integration for batch error handlers — silent failures go unnoticed

### HIGH
4. Auto-confirm timing race: `AUTO_CONFIRM_DAYS=5` vs `AUTHORIZATION_EXPIRY_DAYS=6` — authorization expiry cron (hourly) can race with auto-capture cron
5. Rate limiter cleanup cutoff = 1hr matches rate limit window exactly → can delete active entries mid-window

### MEDIUM
6. `sync_expired_subscriptions` runs hourly → 4800 reads/day unnecessarily; change to every 6 hours
7. Stock restore double-increment risk if crash between batch.commit() and STOCK_RESTORED flag set (mitigated by status lock, but fragile)

### LOW
8. Docstring mismatch: `check_expired_authorizations` says "Daily 02:00 UTC" but runs every hour (cron_jobs.py:642)
