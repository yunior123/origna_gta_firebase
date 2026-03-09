# Missing Indexes Auditor — Memory

## Last Audit: 2026-03-01

### Confirmed Index Coverage Pattern
- `firestore.indexes.json` is generally well-maintained (70+ indexes)
- The file uses `comment` fields to document which query each index serves
- All high-volume cron job queries were covered before this audit

### Missing Indexes Found (added 2026-03-01)
1. `security_alerts`: `type + sellerId + resolved` — compute_seller_metrics dedup (cron_jobs.py:1928)
2. `messages` (collection_group): `isRead + senderId` — mark_messages_read inequality query (chat.py:207)
3. `products`: `sellerId + isDigital` — update_warehouse non-digital product sync (products.py:3282)
4. `product_ratings`: `isFlagged + createdAt DESC` — admin watchReviews flaggedOnly (admin_repository.dart:185)
5. `product_ratings`: `hasPhotos + createdAt DESC` — admin watchReviews hasPhotosOnly (admin_repository.dart:186)
6. `product_ratings`: `isFlagged + hasPhotos + createdAt DESC` — combined filter (admin_repository.dart:185-186)

### Scan Strategy That Works
- Grep Python files for `.where(` with context=2 to catch multi-where chains
- Grep Dart files for `.where(` AND `.orderBy(` together
- Focus files: handlers/*.py, services/*.py, lib/features/**/*.dart, lib/core/repositories/*.dart
- `admin_repository.dart` is a common source of composite queries (admin panel)
- Dynamic query builders (get_products_paginated) need all filter+sort combos checked

### Known Non-Composite Queries (safe — no index needed)
- `rate_limits`: single field `lastRequest <= cutoff` (single-field index auto-created)
- `webhook_events`: single field `timestamp <= cutoff` (single-field)
- `algolia_sync_failures`: single field `resolved == False`
- `is_premium == True` alone: single field

### Query Patterns to Always Check
- `security_alerts` dedup queries — there are 4+ different dedup patterns with different field combos
- `messages` subcollection queries — easy to miss since they're on subcollections
- Admin panel repositories — often have conditional where+orderBy combos
- Dynamic query builders that accept sort field param need all sort-field combos indexed
