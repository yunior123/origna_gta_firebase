## FRONTEND/RIVERPOD FINDINGS

### HIGH
1. Unsafe `.value!` access in chat_screen.dart:177 — crash risk if AsyncValue race condition

### MEDIUM
2. `qaControllerProvider` missing `.autoDispose` → memory leak on product detail page (qa_provider.dart:7)
3. `notificationPermissionProvider` missing `.autoDispose` — possibly intentional, needs doc comment
4. Seller Q&A badge missing on seller_products_screen.dart — only on seller_orders_screen.dart

### LOW
5. Hardcoded subscription price `CAD $7.86/month` in productdetails_screen.dart:939 — not i18n
6. Hardcoded paywall description in English only — violates Quebec Bill 96 French requirement

### VERIFIED OK
- No ref.watch() in event handlers
- Premium gate consistency — all use subscriptionStreamProvider
- 65+ providers use autoDispose correctly
- All routes registered, no orphan screens
