import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

/// Service to automatically logout users after 15 minutes of inactivity.
///
/// SECURITY: Phase 3 - Session timeout implementation
/// Tracks user interactions and signs out after 15 minutes of inactivity.
class SessionTimeoutService {
  // BOOT-L1: sourced from BusinessRules constant instead of hardcoded
  static final Duration _inactivityTimeout = Duration(minutes: BusinessRules.sessionTimeoutMinutes);

  /// Singleton instance
  static final SessionTimeoutService _instance = SessionTimeoutService._internal();
  Timer? _timeoutTimer;
  DateTime _lastActivityTime = DateTime.now();
  GlobalKey<NavigatorState>? _navigatorKey;
  // BOOT-H2: Track which user started the timer to prevent signing out a different user
  String? _watchedUserId;

  FirebaseAuth? _authOverride;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  
  factory SessionTimeoutService() => _instance;
  SessionTimeoutService._internal();

  /// For testing purposes only: set a mock FirebaseAuth instance
  @visibleForTesting
  void setAuth(FirebaseAuth auth) {
    _authOverride = auth;
  }

  /// Get remaining time before timeout
  Duration getRemainingTime() {
    final elapsed = DateTime.now().difference(_lastActivityTime);
    final remaining = _inactivityTimeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Check if session is about to expire (< 5 minutes remaining)
  bool isAboutToExpire() {
    return getRemainingTime().inMinutes < 5;
  }

  /// Call this whenever user interacts with the app (no context needed)
  void recordActivity() {
    _lastActivityTime = DateTime.now();
    _resetTimer();
  }

  /// Start monitoring user activity. Pass the app's [GlobalKey] of [NavigatorState].
  void startMonitoring(GlobalKey<NavigatorState> navigatorKey) {
    _timeoutTimer?.cancel(); // Prevent timer leak on repeated calls
    if (_auth.currentUser == null) return;
    _navigatorKey = navigatorKey;
    _watchedUserId = _auth.currentUser?.uid; // BOOT-H2: bind timer to this user
    _resetTimer();
  }

  /// Stop monitoring (when user logs out manually)
  void stopMonitoring() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _navigatorKey = null;
    _watchedUserId = null; // BOOT-H2: clear binding
  }

  /// Handle timeout event - sign out user
  Future<void> _handleTimeout() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // BOOT-H2: only sign out the exact user whose session started this timer
    if (_watchedUserId != null && user.uid != _watchedUserId) return;

    try {
      await _auth.signOut();

      // Best-effort: wait for auth state propagation (esp. Web)
      try {
        await _auth
            .authStateChanges()
            .firstWhere((u) => u == null)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}

      // Show snackbar using the NavigatorState's context (never stale)
      final ctx = _navigatorKey?.currentContext;
      if (ctx != null) {
        // ignore: use_build_context_synchronously — context is obtained fresh at call time
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(UIMessages.sessionExpired),
            duration: const Duration(seconds: 5),
            backgroundColor: DesignTokens.warning,
          ),
        );
      }
    } catch (e) {
      // Auto-logout failed — user will need to re-authenticate manually
    }
  }

  /// Reset the inactivity timer
  void _resetTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_inactivityTimeout, _handleTimeout);
  }
}
