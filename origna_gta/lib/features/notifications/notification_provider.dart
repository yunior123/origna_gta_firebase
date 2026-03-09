import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether notification permission has been granted.
/// Uses StateNotifier per CLAUDE.md architecture rules (no raw StateProvider for logic).
class NotificationPermissionNotifier extends StateNotifier<bool> {
  NotificationPermissionNotifier() : super(false);

  void setGranted(bool granted) => state = granted;
}

// FE-M2: No .autoDispose intentionally — permission state must persist for the
// entire app session. NotificationService.initialize() is called once at app
// startup and writes the result here; losing it on screen disposal would
// cause stale "denied" state after navigation.
final notificationPermissionProvider =
    StateNotifierProvider<NotificationPermissionNotifier, bool>(
  (ref) => NotificationPermissionNotifier(),
);
