## SEARCH & DISCOVERY FINDINGS

### CRITICAL
1. Inactive products NOT filtered from Algolia search — if Algolia deletion fails, stale inactive products appear in results (algolia_service.dart:28)

### HIGH
2. No Canada-only buyer filtering in search — products not shippable to Canada still appear (algolia_service.dart:28)
3. No Algolia sync retry mechanism — dead letter queue (`algolia_sync_failures`) exists but never retried → products invisible after transient outage
4. Admin API key could be accidentally pushed to Remote Config — no validation guard in update_remote_config.py

### MEDIUM
5. Out-of-stock products not visually marked in search results
6. Trending score calculation not audited — logic in cron_jobs.py:1942 unverified

### VERIFIED OK
- Environment isolation (dev/staging/prod/emulator indexes)
- Algolia sync on create/update/delete all working
- Search API key read-only
