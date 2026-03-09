## PRODUCT Q&A & RATINGS FINDINGS

### CRITICAL
1. Rating transaction reads `product_doc` OUTSIDE transaction scope → stale data race condition → incorrect average rating calculations (products.py:804)

### HIGH
2. Review content length enforced by backend truncation but NO Firestore rules validation — defense in depth gap (products.py:689)
3. Q&A seller-only answer check backend-only — no Firestore rules defense in depth

### MEDIUM
4. Photo review images uploaded before rating doc created — orphaned R2 images if write fails (product_rating_viewmodel.dart:52)
5. No admin callable function for deleting abusive Q&A — manual Firebase Console only (no audit trail)

### LOW
6. Algolia rating update outside transaction — stale ratings in search until next product update (products.py:856)

### VERIFIED OK
- One rating per buyer per product (dual checks)
- Seller cannot rate own product
- Duplicate rejection works
- Premium gate for Q&A correct
