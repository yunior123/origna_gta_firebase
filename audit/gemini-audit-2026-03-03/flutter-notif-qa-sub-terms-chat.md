# Flutter Audit — features/notifications + qa + subscription + terms + chat
**Date:** 2026-03-03
**Model:** gemini-2.5-pro
---

## Files Audited

- lib/features/chat/chat_provider.dart
- lib/features/chat/chat_repository.dart
- lib/features/notifications/notification_provider.dart
- lib/features/qa/qa_provider.dart
- lib/features/qa/qa_repository.dart
- lib/features/subscription/subscription_provider.dart
- lib/features/subscription/subscription_state.dart
- lib/features/terms/terms_provider.dart

---

## Findings

SEVERITY: HIGH
FILE: lib/features/terms/terms_provider.dart
LINE: 31-40
ISSUE: Shipping rates and business logic are hardcoded into the `_defaultTermsContent` fallback string. Values like `$1.99`, `$7.99`, `$8.99`, and `$26.99` are present. This violates the single-source-of-truth principle. If the backend shipping logic changes, this legal text becomes outdated and misleading, creating a compliance risk.
FIX: Remove the specific rate values from the text. Replace them with a generic statement directing users to the checkout process for accurate shipping costs. Business logic, especially pricing, should never be hardcoded in static text blocks.
---

SEVERITY: HIGH
FILE: lib/features/chat/chat_repository.dart
LINE: 153-162
ISSUE: The `allChatsStream` uses `{...buyerThreads, ...sellerThreads}.toList()` to merge two streams of `ChatThread` objects. The intent is to create a unified, deduplicated list. However, `ChatThread` is a class without a custom `==` operator or `hashCode`, so the `Set` uses default object identity for comparison. If the same chat thread is present in both `buyerThreads` and `sellerThreads` (an edge case, like a user buying their own product), it will appear twice in the final list because the two instances are distinct objects in memory.
FIX: Use a `Map<String, ChatThread>` with the `chatId` as the key to guarantee uniqueness before converting to a list. This correctly merges the two lists and deduplicates by the chat's unique identifier.

```dart
void emit() {
  final chatMap = <String, ChatThread>{};
  for (final thread in buyerThreads) {
    chatMap[thread.chatId] = thread;
  }
  for (final thread in sellerThreads) {
    chatMap[thread.chatId] = thread;
  }
  final merged = chatMap.values.toList()
    ..sort((a, b) {
      final at = a.lastMessageAt;
      final bt = b.lastMessageAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
  controller.add(merged);
}
```
---

SEVERITY: MEDIUM
FILE: lib/features/subscription/subscription_provider.dart
LINE: 60-65
ISSUE: The `updateNotificationPreferences` method calls an async `userRepositoryProvider` method without `await` or any error handling. This "fire-and-forget" approach means that if the database update fails, the error is silently swallowed. The user might think their preference was updated when it was not, leading to a state mismatch between the UI and the backend.
FIX: The method should `await` the repository call within a `try/catch` block. On failure, update the state with an error message so the UI can inform the user that the preference change failed.

```dart
Future<void> updateNotificationPreferences({bool? notifyNewProducts, bool? notifyTrending}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  try {
    await _ref.read(userRepositoryProvider).updateNotificationPreferences(
      uid,
      notifyNewProducts: notifyNewProducts,
      notifyTrending: notifyTrending,
    );
  } catch (e) {
    state = state.copyWith(errorMessage: _parseError(e));
  }
}
```
---

SEVERITY: MEDIUM
FILE: lib/features/chat/chat_provider.dart
LINE: 112-118
ISSUE: User-facing validation error messages for message length are hardcoded as strings (e.g., 'Message is too short...'). This prevents localization, so non-English-speaking users will see English error messages.
FIX: Replace the hardcoded strings with keys to a localization file and use a translation function (e.g., `.tr()`) to display the message in the user's selected language. The dynamic length values should be passed as arguments to the translation function.
---

SEVERITY: MEDIUM
FILE: lib/features/qa/qa_provider.dart
LINE: 43-45
ISSUE: The `PremiumRequiredException` class is instantiated with a hardcoded, user-facing error message. This tightly couples the business logic layer with the presentation layer and prevents the message from being localized based on the user's device settings.
FIX: The exception should not contain the display message. Instead, the UI code that catches the `PremiumRequiredException` should be responsible for mapping this specific exception type to a localized user-friendly message key.
---

SEVERITY: MEDIUM
FILE: lib/features/chat/chat_provider.dart
LINE: 151-163
ISSUE: The `_parseError` method contains several hardcoded user-facing strings, such as 'A Premium membership is required to chat with sellers.' and 'Too many messages. Please slow down.'. These are not localized.
FIX: Abstract these strings to a localization file and retrieve them using a translation function (e.g., `.tr()`) so they can be displayed in the user's language.
---

SEVERITY: LOW
FILE: lib/features/terms/terms_provider.dart
LINE: 5-96
ISSUE: The default terms and conditions are stored in a large, multi-line string literal (`_defaultTermsContent`) directly inside the Dart file. This hurts code readability and maintainability by mixing static content with application logic.
FIX: Move the content of `_defaultTermsContent` to a separate text file within the `assets` directory (e.g., `assets/text/default_terms.txt`). Load this file using `rootBundle.loadString()` as the fallback when Remote Config is unavailable. This decouples the legal text from the code.
---

SEVERITY: LOW
FILE: lib/features/subscription/subscription_provider.dart
LINE: 88-92
ISSUE: The `_parseError` method in `SubscriptionViewModel` is much simpler than the one in `ChatViewModel`. The chat version handles specific error codes like 'permission-denied' and 'resource-exhausted' to provide better user feedback. This inconsistency leads to a worse user experience for subscription-related errors compared to chat-related errors.
FIX: Create a single, shared error parsing utility function in a core directory (e.g., `lib/core/utils/error_parser.dart`). Both ViewModels should call this centralized function to ensure all user-facing errors are handled consistently and provide the same level of detail across the application. The implementation from `ChatViewModel` should be used as the template for the shared function.
---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 0     |
| HIGH     | 2     |
| MEDIUM   | 4     |
| LOW      | 2     |
| **Total**| **8** |

### Top Priorities
1. **[HIGH] terms_provider.dart** — Hardcoded shipping prices in legal fallback text (compliance risk)
2. **[HIGH] chat_repository.dart** — Set-based deduplication broken without custom `==`/`hashCode` on `ChatThread`
3. **[MEDIUM] subscription_provider.dart** — Fire-and-forget async call, silent failure on notification prefs update
4. **[MEDIUM] chat_provider.dart + qa_provider.dart** — Multiple hardcoded user-facing strings not localized via `.tr()`
