## FAVORITES FINDINGS

### MEDIUM
1. Orphaned favorites from hard-deleted products never cleaned up client-side — user sees "0 favorites" with 1 orphan in stream (favorites_screen.dart:74)
2. Seller product list hard-capped at 200 with no pagination — sellers with 201+ products can't see older ones (seller_products_viewmodel.dart:17)
3. Missing Firestore composite index for seller products query: (sellerId ASC, createdAt DESC) — potential deploy-time error

### LOW
4. Loading state gap: favorites product detail fetch shows blank before rendering (favorites_screen.dart:19)
5. Empty `_shipFromLabel` causes "Ships from: " text with no location (modern_product_card.dart:161)

### VERIFIED OK
- Owner-only access enforced in Firestore rules
- Product deletion cleanup covers both soft and hard delete
- No cross-user favorites access
