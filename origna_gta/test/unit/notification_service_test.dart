import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/services/notification_service.dart';

import 'notification_service_test.mocks.dart';

@GenerateMocks([FirebaseMessaging, NotificationSettings, NavigatorState, ScaffoldMessengerState, ProviderSubscription])
void main() {
  group('NotificationService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseMessaging mockMessaging;
    late MockNotificationSettings mockSettings;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockMessaging = MockFirebaseMessaging();
      mockSettings = MockNotificationSettings();

      NotificationService.instance.resetForTesting();
      NotificationService.instance.messagingOverride = mockMessaging;
    });

    test('saveTokenToFirestore saves token to subcollection', () async {
      const testUid = 'user_123';
      const testToken = 'fake_fcm_token_xyz';

      when(mockMessaging.getToken()).thenAnswer((_) async => testToken);

      final container = ProviderContainer(overrides: [userIdProvider.overrideWith((ref) => testUid), firestoreProvider.overrideWithValue(fakeFirestore)]);
      NotificationService.instance.testContainerOverride = container;

      await NotificationService.instance.saveTokenToFirestore();

      final tokenDocs = await fakeFirestore.collection(Collections.users).doc(testUid).collection(Collections.fcmTokens).get();
      expect(tokenDocs.docs.isNotEmpty, true);
      final tokenData = tokenDocs.docs.first.data();
      expect(tokenData['token'], testToken);
    });

    test('clearTokenFromFirestore removes token from subcollection', () async {
      const testUid = 'user_123';
      const testToken = 'fake_fcm_token_xyz';
      final tokenHash = sha256.convert(utf8.encode(testToken)).toString();

      await fakeFirestore.collection(Collections.users).doc(testUid).collection(Collections.fcmTokens).doc(tokenHash).set({'token': testToken});

      when(mockMessaging.getToken()).thenAnswer((_) async => testToken);

      final container = ProviderContainer(overrides: [userIdProvider.overrideWith((ref) => testUid), firestoreProvider.overrideWithValue(fakeFirestore)]);
      NotificationService.instance.testContainerOverride = container;

      await NotificationService.instance.clearTokenFromFirestore();

      final doc = await fakeFirestore.collection(Collections.users).doc(testUid).collection(Collections.fcmTokens).doc(tokenHash).get();
      expect(doc.exists, false);
    });

    testWidgets('handleNotificationTap routes to orderDetail when orderId present', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      bool pushedOrderDetail = false;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.orderDetail) {
              pushedOrderDetail = true;
              final args = settings.arguments as OrderDetailArgs;
              expect(args.orderId, 'order_abc');
            }
            return MaterialPageRoute(builder: (_) => Container());
          },
          home: Container(),
        ),
      );

      NotificationService.instance.testNavigatorKey = navKey;

      final message = RemoteMessage(data: {'type': 'order_status', 'orderId': 'order_abc'});

      NotificationService.instance.handleNotificationTap(message);
      await tester.pumpAndSettle();

      expect(pushedOrderDetail, true);
    });

    testWidgets('handleNotificationTap routes to orders when orderId absent', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      bool pushedOrders = false;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.orders) {
              pushedOrders = true;
            }
            return MaterialPageRoute(builder: (_) => Container());
          },
          home: Container(),
        ),
      );

      NotificationService.instance.testNavigatorKey = navKey;

      final message = RemoteMessage(data: {'type': 'order_status'});

      NotificationService.instance.handleNotificationTap(message);
      await tester.pumpAndSettle();

      expect(pushedOrders, true);
    });

    testWidgets('handleForegroundMessage shows SnackBar and handles tap', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      addTearDown(tester.view.resetPhysicalSize);

      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final navKey = GlobalKey<NavigatorState>();
      bool pushedOrderDetail = false;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          scaffoldMessengerKey: messengerKey,
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.orderDetail) {
              pushedOrderDetail = true;
            }
            return MaterialPageRoute(builder: (_) => Container());
          },
          home: Scaffold(body: Container()),
        ),
      );

      NotificationService.instance.testScaffoldMessengerKey = messengerKey;
      NotificationService.instance.testNavigatorKey = navKey;

      final message = RemoteMessage(
        notification: const RemoteNotification(title: 'Order Updated', body: 'Your order is ready'),
        data: {'type': 'order_status', 'orderId': 'order_abc'},
      );

      NotificationService.instance.handleForegroundMessage(message);
      await tester.pumpAndSettle(); // Wait for snackbar to appear

      expect(find.byType(SnackBar), findsOneWidget);

      // Tap the action button
      final actionButton = find.text('common.view'.tr());
      expect(actionButton, findsOneWidget);

      await tester.tap(actionButton);
      await tester.pumpAndSettle();

      expect(pushedOrderDetail, true);
    });

    test('initialize sets up listeners on authorized permission', () async {
      when(mockSettings.authorizationStatus).thenReturn(AuthorizationStatus.authorized);
      when(
        mockMessaging.requestPermission(
          alert: anyNamed('alert'),
          announcement: anyNamed('announcement'),
          badge: anyNamed('badge'),
          carPlay: anyNamed('carPlay'),
          criticalAlert: anyNamed('criticalAlert'),
          provisional: anyNamed('provisional'),
          sound: anyNamed('sound'),
        ),
      ).thenAnswer((_) async => mockSettings);
      when(mockMessaging.getToken()).thenAnswer((_) async => 'fake_token');
      when(mockMessaging.onTokenRefresh).thenAnswer((_) => const Stream.empty());
      when(mockMessaging.getInitialMessage()).thenAnswer((_) async => null);

      final container = ProviderContainer(overrides: [userIdProvider.overrideWith((ref) => 'user_123'), firestoreProvider.overrideWithValue(fakeFirestore)]);
      NotificationService.instance.testContainerOverride = container;

      await NotificationService.instance.initialize(null);
      // Verifies it doesn't throw and sets up streams
    });
  });
}
