## LEGACY/DEAD CODE FINDINGS

### CRITICAL
1. `subscriptions.py:36` — hardcoded `"users"` string instead of `Collections.USERS` constant

### HIGH
2. `CircularProgressIndicator` used instead of `ModernLoadingIndicator` (productaddvideo_screen.dart:270)
3. Direct `FirebaseAuth.instance.currentUser` in screen — violates MVVM (profile_screen.dart:832)
4. Word "legacy" in 4 locations (order_repository.dart:35, seller_warehouses_screen.dart:102, payment_stripe.py:656, payment_stripe.py:3607)

### MEDIUM
5. `StateNotifierProvider` without `.autoDispose` → memory leak (qa_provider.dart:7)
6. Raw `TextField` / `TextButton` / `ElevatedButton` / `AppBar` instead of Modern* components (13 occurrences)
7. `warehouseStock` field — exists in schema, tested, but possibly unused in production handlers
8. `TestWarehouseStockSync` tests orphan field (test_handlers_payment_stripe.py:1286)
9. Bare `except Exception` swallowing all errors (config.py:420, crypto_utils.py:47)

### LOW
10. `Colors.white` hardcoded instead of DesignTokens (admin_products_tab.dart:214)
11. 26 total findings across 23 files
