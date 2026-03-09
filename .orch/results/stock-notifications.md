## STOCK NOTIFICATIONS FINDINGS (from MEMORY.md)

### CRITICAL
1. Notifications NEVER deleted after email sent — unbounded collection growth, 100K+ zombie docs over 12 months (products.py:3393)

### HIGH
2. Email failure after `notifiedAt` stamp = buyer never notified but marked as notified — Cloud Function retry skips them (products.py:3393)

### MEDIUM
3. Orphaned variant subscriptions when seller deletes variant — no cleanup in on_product_updated

### VERIFIED OK
- Variant scoping correct (size M restock doesn't notify size L waiters)
- Duplicate prevention working
- Purchase/deletion cleanup working
