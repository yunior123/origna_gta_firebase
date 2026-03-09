# Favorites Auditor Memory

## Audit Run: 2026-03-03

### Key Confirmed Patterns

**Favorites Privacy (PASS)**
- Firestore rules: `users/{userId}/favorites/{productId}` — read/write locked to `isOwner(userId)` only.
- No cross-user favorites access is possible at the rules layer.

**Orphan Cleanup (PARTIAL PASS)**
- `delete_product` callable (soft-delete path): cleans favorites via paginated `collection_group` query.
- `on_product_deleted` Firestore trigger (hard-delete path): cleans favorites via same paginated pattern.
- `bulk_update_products` archive action: cleans favorites per product (paginated).
- GAP: `bulk_update_products` PAUSE action does NOT clean favorites. This is acceptable — paused products appear dimmed in UI, not removed.
- GAP: `toggle_favorite` callable does NOT decrement `favoriteCount` on deletion cleanup paths. `favoriteCount` on product doc can drift when batch-delete cleanup runs (cleanup deletes sub-docs but does not decrement the product counter).

**favoriteCount Magic String (FIXED 2026-03-03)**
- Added `Fields.FAVORITE_COUNT = "favoriteCount"` to `schema_constants.py` (line ~803) and `Fields.favoriteCount = 'favoriteCount'` to `schema_constants.dart` (line ~1072).
- Replaced all 3 magic string usages: `products.py` (toggle_favorite, 2 sites) + `cron_jobs.py` (trending score, 1 site).

**toggle_favorite inactive product guard (FIXED 2026-03-03)**
- Added `lifecycleStatus == ACTIVE` check inside `toggle_fav_txn` before creating new favorite doc. Unfavoriting an inactive product is still allowed (cleanup path). Only the creation branch is gated.

**Seller Product Listing (PASS)**
- `sellerProductsProvider` queries Firestore directly with `where(sellerId == userId)`. Algolia is not used.
- Hard cap: `BusinessRules.sellerProductsPageSize = 200`. No cursor pagination for >200 products.

**Product Card Data Completeness**
- `product_card_screen.dart`: `product.rating` accessed as `.toDouble()` with no null guard, but Dart model has `rating` as `double` (generated), so safe.
- `modern_product_card.dart`: `_shipFromLabel` guard (`if (_shipFromLabel.isNotEmpty)`) prevents "Ships from: " with blank text. FAV-L2 fix confirmed in place.
- Magic strings in `modern_product_card.dart` line 235: `'No reviews yet'` not localized.
- Magic strings in `product_card_screen.dart` line 252: `'Trending'` not localized.
- Magic strings in `seller_products_screen.dart` line 398: `'Approved'` not localized.

**Pagination**
- Favorites: 50-item hard cap (`BusinessRules.favoritesPageSize`), cursor-based via `orderBy + limit`. NOT full cursor pagination — it is a streaming window, not paginated list.
- Seller products: 200-item hard cap, streaming, no cursor pagination for >200.

**Fields.createdAt on Products Query**
- `sellerProductsProvider` orders by `Fields.createdAt` — product timestamp field is `createdAt` per MEMORY.md schema contract. Confirmed correct.
