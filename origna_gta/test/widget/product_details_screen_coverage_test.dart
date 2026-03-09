import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/features/products/stock_notification_provider.dart';
import 'package:origna_gta/features/qa/qa_provider.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/features/subscription/subscription_state.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/models/models.dart' as models;
import 'package:origna_gta/models/qa_model.dart';
import 'package:origna_gta/screens/productdetails_screen.dart';
import 'package:origna_gta/widgets/premium_paywall_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_utils.dart';
@GenerateNiceMocks([
  MockSpec<auth.User>(),
  MockSpec<auth.FirebaseAuth>(),
  MockSpec<FirebaseFirestore>(),
  MockSpec<CartController>(),
  MockSpec<StockNotificationNotifier>(as: #MockStockNotificationNotifier),
])
import 'product_details_screen_coverage_test.mocks.dart';

void main() {
  late MockUser mockUser;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockUser = MockUser();
    mockAuth = MockFirebaseAuth();

    when(mockUser.uid).thenReturn('u1');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.emailVerified).thenReturn(true);

    when(mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(mockUser));
    when(mockAuth.currentUser).thenReturn(mockUser);

    SharedPreferences.setMockInitialValues({});
    initTestMocks();

    // Mock SharePlus method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'share') {
        return null;
      }
      return null;
    });
  });

  final baseProduct = Product(
    productId: 'p1',
    name: 'Honey',
    price: 10.0,
    imageUrls: const ['https://example.com/img1.jpg'],
    description: 'Sweet honey from Canada.',
    sellerId: 's1',
    stockQuantity: 10,
    categoryId: 1,
    createdAt: DateTime.now(),
    isDigital: false,
    rating: 4.5,
    ratingCount: 10,
    isLocalDeliveryOnly: false,
    sellerAddress: const Address(street: 'S', city: 'C', state: 'ON', postalCode: 'M1M 1M1', country: 'CA'),
    estimatedShipDays: 3,
    freeShipping: false,
  );

  Widget createTestApp({required Widget child, List<Override> overrides = const []}) {
    final fakeFirestore = FakeFirebaseFirestore();
    final mockCartController = MockCartController();
    
    return TestWrapper(
      overrides: [
        firestoreProvider.overrideWithValue(fakeFirestore),
        cartControllerProvider.overrideWithValue(mockCartController),
        firebaseAuthProvider.overrideWithValue(mockAuth),
        authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
        subscriptionStreamProvider.overrideWith((ref) => Stream.value(const SubscriptionInfo(status: 'active', isPremium: true))),
        qaListProvider('p1').overrideWith((ref) => Stream.value(const <QAModel>[])),
        ...overrides,
      ],
      child: child,
    );
  }

  group('ProductDetailScreen Coverage Expansion', () {
    testWidgets('renders "Own product" message for sellers', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          overrides: [
            productByIdProvider('p1').overrideWith((ref) => baseProduct.copyWith(sellerId: 'u1')),
            currentUserProvider.overrideWithValue(mockUser),
            userProfileProvider.overrideWith(
              (ref) => Stream.value(models.UserModel(uid: 'u1', email: 'test@example.com', name: 'Test User', roles: ['seller'], createdAt: DateTime.now())),
            ),
          ],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const Key('product_own_product_message')), findsOneWidget);
      expect(find.byIcon(Icons.storefront), findsOneWidget);
    });

    testWidgets('renders "Out of stock" and "Notify me" button', (tester) async {
      final outOfStockProduct = baseProduct.copyWith(stockQuantity: 0);

      await tester.pumpWidget(
        createTestApp(
          overrides: [
            productByIdProvider('p1').overrideWith((ref) => outOfStockProduct),
            currentUserProvider.overrideWithValue(mockUser),
          ],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const Key('product_notify_section')), findsOneWidget);
      expect(find.byKey(const Key('product_notify_me_button')), findsOneWidget);
    });

    testWidgets('renders digital product specific info', (tester) async {
      final digitalProduct = baseProduct.copyWith(
        isDigital: true,
        digitalType: DigitalTypeValues.software,
        digitalBuilds: {'macos': 'v1.0', 'windows': 'v1.0'},
      );

      await tester.pumpWidget(
        createTestApp(
          overrides: [productByIdProvider('p1').overrideWith((ref) => digitalProduct), currentUserProvider.overrideWithValue(mockUser)],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('product.digital_license_delivery'), findsWidgets);
      expect(find.text('macOS'), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
    });

    testWidgets('renders international delivery disclaimer', (tester) async {
      final intlProduct = baseProduct.copyWith(supplier: const SupplierInfo(type: SupplierTypeValues.aliexpress, hasTracking: true));

      await tester.pumpWidget(
        createTestApp(
          overrides: [productByIdProvider('p1').overrideWith((ref) => intlProduct), currentUserProvider.overrideWithValue(mockUser)],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
      expect(find.text('China'), findsOneWidget);
    });

    testWidgets('shows video playback button when video present', (tester) async {
      final videoProduct = baseProduct.copyWith(videoUrl: 'https://example.com/video.mp4', imageUrls: ['https://example.com/img1.jpg']);

      await tester.pumpWidget(
        createTestApp(
          overrides: [productByIdProvider('p1').overrideWith((ref) => videoProduct), currentUserProvider.overrideWithValue(mockUser)],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('renders "Sign in to ask" in QA section when unauthenticated', (tester) async {
      tester.view.physicalSize = const Size(2000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          overrides: [
            productByIdProvider('p1').overrideWith((ref) => baseProduct),
            currentUserProvider.overrideWithValue(null),
            userIdProvider.overrideWithValue(null),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            qaListProvider('p1').overrideWith((ref) => Stream.value(const <QAModel>[])),
          ],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    });

    testWidgets('shows premium paywall when asking a question as free user', (tester) async {
      tester.view.physicalSize = const Size(2000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          overrides: [
            productByIdProvider('p1').overrideWith((ref) => baseProduct),
            currentUserProvider.overrideWithValue(mockUser),
            userIdProvider.overrideWithValue('u1'),
            qaListProvider('p1').overrideWith((ref) => Stream.value(const <QAModel>[])),
            subscriptionStreamProvider.overrideWith((ref) => Stream.value(const SubscriptionInfo(status: 'inactive', isPremium: false))),
          ],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final askBtn = find.byIcon(Icons.lock_rounded);
      await tester.tap(askBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PremiumPaywallWidget), findsOneWidget);
    });

    testWidgets('share button interaction', (tester) async {
      final slugProduct = baseProduct.copyWith(slug: 'honey-p1');

      await tester.pumpWidget(
        createTestApp(
          overrides: [productByIdProvider('p1').overrideWith((ref) => slugProduct), currentUserProvider.overrideWithValue(mockUser)],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final shareBtn = find.byTooltip('Share');
      expect(shareBtn, findsOneWidget);
      await tester.tap(shareBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Verification happens via MethodChannel mock if needed, or just ensuring no crash
    });
  });
}
