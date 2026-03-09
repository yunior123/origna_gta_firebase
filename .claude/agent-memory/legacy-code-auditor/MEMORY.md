# Legacy Code Auditor — Project Memory

## Flutter/Dart Banned API Status (last scanned 2026-02-27)
- `withOpacity` — CLEAN (zero hits in lib/)
- `MaterialPageRoute` — CLEAN
- `CircularProgressIndicator` — CLEAN (only appears in the `modern_loading_indicator.dart` doccomment)
- `Consumer(` — used deliberately for scoped rebuilds in cart; not a violation when used as a Riverpod `Consumer` widget (not the provider package)
- `context.read<>` / `context.watch<>` / `Provider.of` — CLEAN

## Riverpod Pattern Status
- All ViewModels use `StateNotifierProvider.autoDispose` — correct
- Two providers WITHOUT autoDispose that are intentional singletons:
  - `notificationPermissionProvider` (notifications/notification_provider.dart:12) — app-lifetime, intentional
  - `qaControllerProvider` (features/qa/qa_provider.dart:7) — missing autoDispose, FLAGGED
- `StateProvider` without autoDispose: `searchQueryProvider` and `selectedCategoryProvider` in `products_provider.dart` — app-level state, potentially intentional but flagged
- Riverpod v2 migration (StateNotifier → Notifier/AsyncNotifier) NOT yet done — entire codebase is on StateNotifier; this is a large migration, not a single-file fix

## "legacy" Word Occurrences
- `origna_gta/lib/screens/seller/seller_warehouses_screen.dart:102` — comment says "FIX L-01: This legacy callback..."
- `origna_gta/lib/core/repositories/order_repository.dart:35` — comment says "Whole-order payment capture (legacy / single-seller path)"
- `functions/handlers/payment_stripe.py:655` — comment says "# Legacy fallback"
- All three are comments, none in user-facing text

## Python f-string in logger
- Pervasive across all handlers and services (hundreds of occurrences)
- Python logging docs recommend `logger.info("msg %s", var)` over f-strings to avoid format cost when log level is disabled
- Not a crash risk; LOW severity but widespread

## Dead onSave callback
- `seller_warehouses_screen.dart:102-105` — callback with `assert(false, ...)` body is dead code kept as a guard

## Hardcoded Firestore collection string
- `functions/handlers/subscriptions.py:36` — `.collection("users")` instead of `Collections.USERS`
