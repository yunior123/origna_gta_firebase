# Frontend Auditor Memory — OrignaGTA

## Architecture Facts
- State management: Riverpod (StateNotifier pattern throughout, no NotifierProvider/AsyncNotifier used)
- Premium gate canonical provider: `subscriptionStreamProvider` (StreamProvider.autoDispose in subscription_provider.dart)
- User profile canonical provider: `userProfileProvider` (StreamProvider.autoDispose in auth_provider.dart)
- All screens use ConsumerWidget or ConsumerStatefulWidget
- Router: Named routes via Navigator.pushNamed, all registered in origna_app.dart onGenerateRoute
- i18n: easy_localization with en.json / fr.json translation files

## Key Provider Locations
- `subscriptionStreamProvider` → lib/features/subscription/subscription_provider.dart:14
- `userProfileProvider` → lib/features/auth/auth_provider.dart:10
- `qaControllerProvider` → lib/features/qa/qa_provider.dart:7 (MISSING autoDispose)
- `notificationPermissionProvider` → lib/features/notifications/notification_provider.dart:11 (MISSING autoDispose)
- `sellerUnansweredQaProvider` → lib/features/products/products_provider.dart:99
- `unansweredQaCountProvider` → lib/features/qa/qa_provider.dart:17

## Known Issues (from 2026-03-01 re-audit)
1. `qaControllerProvider` missing autoDispose — leaks across product detail visits
2. `notificationPermissionProvider` missing autoDispose — lives for app lifetime (may be intentional)
3. Badge widgets use `.valueOrNull ?? 0` (silently hides errors) — acceptable tradeoff confirmed
4. edit_product_viewmodel.dart has ~10 hardcoded English error strings (not using .tr())
5. productdetails_screen.dart has hardcoded: 'Reviews', 'No reviews yet...', 'Verified Purchase', 'Seller Response', 'Helpful?', 'Yes (N)', 'Customers also bought', 'Response'/'Ships in'/'Positive'/'Reviews' metric pills, 'License key + download link...'
6. product_card_screen.dart has hardcoded: 'Trending', 'Software', 'Book', 'Added to cart', 'Failed to add to cart', Q&A tooltip strings
7. modern_product_card.dart has hardcoded: 'Ships from:' label, '..locations worldwide'
8. stockNotificationNotifierProvider error state silently ignored in _AddToCartButton — button stays enabled on init error (LOW impact — try/catch in _toggleNotification handles it)
9. _ReviewsSection 'Could not load reviews.' hardcoded error message
10. profile_screen.dart falls back to userModel.isPremium when subscriptionStreamProvider has no data — acceptable defensive pattern

## Deferred UI Status (as of 2026-03-01 re-audit)
- Photo reviews: COMPLETE — RatingDialog has photo picker for premium users (up to 3 photos)
- Product Q&A: COMPLETE — _QASection fully wired in productdetails_screen.dart
- Back-in-stock: COMPLETE — stockNotificationNotifierProvider + UI in _AddToCartButton
- Seller Q&A badge: COMPLETE — _QaBadgeButton in product_card_screen.dart (added 2026-03-01 session)
