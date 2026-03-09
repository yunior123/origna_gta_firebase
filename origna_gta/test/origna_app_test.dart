import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/origna_app.dart';
import 'package:origna_gta/screens/login_screen.dart';
import 'package:origna_gta/screens/privacy_policy_screen.dart';
import 'package:origna_gta/screens/productdetails_screen.dart';
import 'package:origna_gta/services/notification_service.dart';
import 'package:origna_gta/services/session_timeout_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_asset_loader.dart';
@GenerateNiceMocks([
  MockSpec<auth.User>(),
  MockSpec<auth.FirebaseAuth>(),
  MockSpec<FirebaseMessaging>(),
  MockSpec<NotificationSettings>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<ProductRepository>(),
])
import 'origna_app_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseMessaging mockMessaging;
  late MockNotificationSettings mockSettings;
  late MockFirebaseFunctions mockFunctions;
  late MockProductRepository mockProductRepository;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    fakeFirestore = FakeFirebaseFirestore();
    mockMessaging = MockFirebaseMessaging();
    mockSettings = MockNotificationSettings();
    mockFunctions = MockFirebaseFunctions();
    mockProductRepository = MockProductRepository();

    // Reset the singleton service and its keys
    NotificationService.instance.resetForTesting();
    NotificationService.instance.testNavigatorKey = GlobalKey<NavigatorState>();
    NotificationService.instance.testScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

    // Inject mock auth into the singleton service to prevent crash
    SessionTimeoutService().setAuth(mockAuth);
    NotificationService.instance.messagingOverride = mockMessaging;
    NotificationService.instance.onMessageOverride = const Stream.empty();
    NotificationService.instance.onMessageOpenedAppOverride = const Stream.empty();

    when(
      mockMessaging.requestPermission(
        alert: anyNamed('alert'),
        announcement: anyNamed('announcement'),
        badge: anyNamed('badge'),
        carPlay: anyNamed('carPlay'),
        criticalAlert: anyNamed('criticalAlert'),
        provisional: anyNamed('provisional'),
        sound: anyNamed('sound'),
        providesAppNotificationSettings: anyNamed('providesAppNotificationSettings'),
      ),
    ).thenAnswer((_) async => mockSettings);

    when(mockSettings.authorizationStatus).thenReturn(AuthorizationStatus.authorized);
    when(mockMessaging.getToken()).thenAnswer((_) async => 'fake-token');
    when(mockMessaging.onTokenRefresh).thenAnswer((_) => const Stream.empty());
    when(mockMessaging.getInitialMessage()).thenAnswer((_) async => null);

    when(mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(null));
    when(mockAuth.currentUser).thenReturn(null);

    when(
      mockProductRepository.fetchProducts(
        searchQuery: anyNamed('searchQuery'),
        categoryId: anyNamed('categoryId'),
        subcategory: anyNamed('subcategory'),
        lastDocument: anyNamed('lastDocument'),
        pageSize: anyNamed('pageSize'),
        sortOption: anyNamed('sortOption'),
        minPriceCents: anyNamed('minPriceCents'),
        maxPriceCents: anyNamed('maxPriceCents'),
      ),
    ).thenAnswer((_) async => ProductQueryResult(products: [], hasMore: false));

    when(mockProductRepository.getProductBySlug(any)).thenAnswer(
      (_) async => Product(
        productId: 'p1',
        name: 'Test Product',
        price: 10.0,
        imageUrls: const [],
        description: 'Desc',
        stockQuantity: 10,
        categoryId: 1,
        sellerId: 's1',
        createdAt: DateTime.now(),
      ),
    );
  });

  Widget createTestApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(mockAuth),
        firestoreProvider.overrideWithValue(fakeFirestore),
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
        productRepositoryProvider.overrideWithValue(mockProductRepository),
        ...overrides,
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('fr')],
        path: 'assets/translations',
        assetLoader: MockAssetLoader(),
        startLocale: const Locale('en'),
        child: const OrignaApp(),
      ),
    );
  }

  group('OrignaApp Tests', () {
    testWidgets('renders and navigates correctly', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(seconds: 2));
      });

      expect(find.byType(OrignaApp), findsOneWidget);

      final nav = NotificationService.navigatorKey.currentState;
      expect(nav, isNotNull, reason: 'Navigator state should not be null');

      Future<void> pumpRobust() async {
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      // 1. Login
      nav!.pushNamed('/login');
      await pumpRobust();
      expect(find.byType(LoginScreen), findsOneWidget);
      nav.pop();
      await pumpRobust();

      // 2. Privacy Policy
      nav.pushNamed('/privacy-policy');
      await pumpRobust();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      nav.pop();
      await pumpRobust();

      // 3. Cart
      nav.pushNamed('/cart');
      await pumpRobust();
      expect(find.textContaining('sign in'), findsWidgets);
      nav.pop();
      await pumpRobust();

      // 4. Product Slug
      nav.pushNamed('/p/test-product-slug');
      await pumpRobust();
      expect(find.byType(ProductDetailScreen), findsOneWidget);
    });
  });
}
