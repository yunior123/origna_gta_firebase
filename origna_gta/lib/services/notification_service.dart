// coverage:ignore-file
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/notifications/notification_provider.dart';
import 'package:origna_gta/utils/utils.dart';

/// Background message handler — top-level function required by FCM.
/// Must be outside of any class. Exported so main.dart can register it
/// before runApp (FCM requires this to happen at app startup).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the OS before this runs.
  // Log receipt; local notification display requires flutter_local_notifications (future task).
  debugPrint('Background FCM message received: ${message.messageId}');
}

/// Documentation for NotificationService
class NotificationService {
  static final NotificationService instance = NotificationService._internal();

  /// Global key to show foreground notification SnackBars without BuildContext.
  static GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// FIX-5 (HIGH): Global navigator key enabling headless deep-link routing when
  /// the user taps a push notification while the app is backgrounded or terminated.
  /// Must be wired to MaterialApp.navigatorKey in origna_app.dart.
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _initialized = false;
  bool _isInitializing = false;

  StreamSubscription? _tokenSubscription;

  ProviderSubscription? _authSubscription;

  ProviderContainer? _container; // Nullable: set during initialize(), null-guarded in saveTokenToFirestore

  @visibleForTesting
  FirebaseMessaging? messagingOverride;

  @visibleForTesting
  Stream<RemoteMessage>? onMessageOverride;

  @visibleForTesting
  Stream<RemoteMessage>? onMessageOpenedAppOverride;

  factory NotificationService() => instance;

  NotificationService._internal();

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _isInitializing = false;
    _tokenSubscription?.cancel();
    _authSubscription?.close();
    _container = null;
    messagingOverride = null;
    onMessageOverride = null;
    onMessageOpenedAppOverride = null;
  }

  @visibleForTesting
  set testContainerOverride(ProviderContainer container) {
    _container = container;
  }

  @visibleForTesting
  set testNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  @visibleForTesting
  set testScaffoldMessengerKey(GlobalKey<ScaffoldMessengerState> key) {
    scaffoldMessengerKey = key;
  }

  FirebaseMessaging get _messaging => messagingOverride ?? FirebaseMessaging.instance;

  /// Removes the device's specific FCM token from Firestore.
  /// Typically called just *before* or during sign out.
  Future<void> clearTokenFromFirestore() async {
    if (_container == null || kIsWeb) return;
    final userId = _container!.read(userIdProvider);
    if (userId == null) return;
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken != null) {
        final firestore = _container!.read(firestoreProvider);
        final tokenHash = sha256.convert(utf8.encode(fcmToken)).toString();
        await firestore.collection(Collections.users).doc(userId).collection(Collections.fcmTokens).doc(tokenHash).delete();
        debugPrint('Removed FCM token for user: $userId');
      }
    } catch (e, st) {
      AppError.log(e, stackTrace: st, context: 'NotificationService.clearTokenFromFirestore');
    }
  }

  void dispose() {
    _tokenSubscription?.cancel();
    _authSubscription?.close();
  }

  /// Initialize the notification service. Should be called only once
  /// in the app lifecycle (typically in OrignaApp's initState).
  Future<void> initialize(WidgetRef? ref) async {
    // Skip if on web (FCM requires VAPID key setup on Web, keeping this mobile-only)
    if (kIsWeb) {
      ref?.read(notificationPermissionProvider.notifier).setGranted(false);
      _initialized = true; // B3: explicitly handle web to prevent hanging
      return;
    }

    // Guard against double-initialization (e.g., hot-reload or multiple calls)
    if (_initialized || _isInitializing) return;
    _isInitializing = true;

    try {
      if (ref != null) {
        _container = ProviderScope.containerOf(ref.context);
      }

      final messaging = _messaging;

      // Restore prior-granted permission state without re-prompting.
      // The alreadyGranted check is intentionally not used to call setGranted(true) here —
      // we wait for requestPermission() below to confirm, avoiding a true→false flicker
      // if the user revoked permissions between sessions.

      // Request permissions (no-ops if already granted on iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized || settings.authorizationStatus == AuthorizationStatus.provisional;

      // Update permission state before any downstream token-save calls
      ref?.read(notificationPermissionProvider.notifier).setGranted(granted);

      if (granted) {
        debugPrint('User granted permission: ${settings.authorizationStatus}');

        // Automatically save FCM token if user is already logged in
        await saveTokenToFirestore();

        // Listen for token refreshes
        _tokenSubscription = messaging.onTokenRefresh.listen((fcmToken) {
          saveTokenToFirestore(token: fcmToken);
        });

        // Listen for auth state changes to save token when user logs in
        _authSubscription = _container!.listen(userIdProvider, (previous, next) {
          if (next != null && next != previous) {
            saveTokenToFirestore();
          }
        });
      } else {
        debugPrint('User declined or has not accepted notification permissions');
        // Write opt-out preference so backend skips push for this user
        Future<void> saveOptOut() async {
          final userId = _container!.read(userIdProvider);
          if (userId != null) {
            try {
              final firestore = _container!.read(firestoreProvider);
              // Ensure pushEnabled: false is properly awaited without blocking silently
              await firestore.collection(Collections.users).doc(userId).set({Fields.pushEnabled: false}, SetOptions(merge: true));
            } catch (e) {
              debugPrint('Failed to save pushEnabled setting: $e');
            }
          }
        }

        await saveOptOut();

        // Medium 6: If they log in later after denying permission, make sure we sync the false state
        _authSubscription = _container!.listen(userIdProvider, (previous, next) {
          if (next != null && next != previous) {
            saveOptOut();
          }
        });
      }

      // Background handler is registered in main.dart before runApp — not here.

      // FIX-5 (HIGH): Handle notification tap when app is in the BACKGROUND.
      (onMessageOpenedAppOverride ?? FirebaseMessaging.onMessageOpenedApp).listen(handleNotificationTap);

      // FIX-5 (HIGH): Handle notification tap when app was TERMINATED.
      messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          Future.delayed(const Duration(milliseconds: 300), () => handleNotificationTap(message));
        }
      });

      // Foreground messages handler — show SnackBar for real-time order updates
      (onMessageOverride ?? FirebaseMessaging.onMessage).listen(handleForegroundMessage);

      _initialized = true; // HIGH-4: Set as initialized only after successful setup
    } catch (e, st) {
      AppError.log(e, stackTrace: st, context: 'NotificationService.initialize');
    } finally {
      _isInitializing = false;
    }
  }

  /// Foreground message handler — show SnackBar for real-time order updates
  void handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground FCM: ${message.messageId}');
    final notification = message.notification;
    if (notification != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('${notification.title ?? ''}: ${notification.body ?? ''}'),
          duration: const Duration(seconds: 4),
          // HIGH-5: Add action to SnackBar
          action: SnackBarAction(label: 'common.view'.tr(), onPressed: () => handleNotificationTap(message)),
        ),
      );
    }
  }

  /// Fetches the current FCM token and saves it to the user's fcm_tokens subcollection.
  /// Each unique token is stored as a separate doc keyed by its SHA-256 hash,
  /// so multiple devices work independently.
  @visibleForTesting
  Future<void> saveTokenToFirestore({String? token}) async {
    if (_container == null) return;
    final userId = _container!.read(userIdProvider);
    if (userId == null) return;

    try {
      final fcmToken = token ?? await _messaging.getToken();
      if (fcmToken != null) {
        final firestore = _container!.read(firestoreProvider);
        final tokenHash = sha256.convert(utf8.encode(fcmToken)).toString();
        final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
        await firestore.collection(Collections.users).doc(userId).collection(Collections.fcmTokens).doc(tokenHash).set({
          'token': fcmToken,
          'platform': platform,
          Fields.userId: userId,
          Fields.fcmTokenUpdatedAt: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('FCM Token saved to fcm_tokens subcollection for user: $userId ($platform)');
      }
    } catch (e, st) {
      AppError.log(e, stackTrace: st, context: 'NotificationService.saveTokenToFirestore');
    }
  }

  /// Routes to the appropriate screen based on the FCM message payload.
  /// Called for both cold-start (getInitialMessage) and background tap (onMessageOpenedApp).
  ///
  /// Payload conventions (set by backend push_service.py):
  ///   type == "order_status"   → navigate to /orders (buyer order list)
  ///   type == "order_update"   → navigate to /orders (item-level shipped)
  ///   type == "back_in_stock"  → navigate to /product-details with productId
  ///   (default)                → no-op; app opens to its last state
  void handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (type) {
      case NotificationTypes.orderStatus:
      case NotificationTypes.orderUpdate:
      case NotificationTypes.returnStatus:
      case NotificationTypes.returnRequest:
      case NotificationTypes.refundIssued:
        // Navigate to order detail if orderId is present, otherwise to order list
        final orderId = data['orderId'] as String?;
        if (orderId != null && orderId.isNotEmpty) {
          navigator.pushNamed(AppRoutes.orderDetail, arguments: OrderDetailArgs(orderId: orderId));
        } else {
          navigator.pushNamed(AppRoutes.orders);
        }

      case NotificationTypes.backInStock:
        final productId = data['productId'] as String?;
        if (productId != null && productId.isNotEmpty) {
          navigator.pushNamed(AppRoutes.productDetails, arguments: ProductDetailsArgs(productId: productId));
        }

      default:
        debugPrint('NotificationService: unhandled notification type "$type" — ignoring tap');
    }
  }
}
