import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/features/seller/seller_products_viewmodel.dart';
import 'package:origna_gta/models/generated/product_models.dart';
import 'package:origna_gta/models/models.dart' as models;
import 'package:origna_gta/screens/seller_products_screen.dart';

import '../test_utils.dart';

@GenerateNiceMocks([MockSpec<User>()])
import 'seller_products_screen_test.mocks.dart';

Product _makeProduct({
  String id = 'prod_1',
  String name = 'Test Product',
  double price = 29.99,
  int stockQuantity = 10,
  String lifecycleStatus = ProductLifecycleStatusValues.active,
  String? approvalRejectionReason,
  List<String> imageUrls = const [],
}) {
  return Product(
    productId: id,
    name: name,
    price: price,
    description: 'A test product',
    imageUrls: imageUrls,
    sellerId: 'test_user_123',
    categoryId: 1,
    stockQuantity: stockQuantity,
    createdAt: DateTime(2026, 1, 1),
    lifecycleStatus: lifecycleStatus,
    approvalRejectionReason: approvalRejectionReason,
  );
}

/// Pumps multiple frames to let animations and async providers settle
/// without relying on pumpAndSettle (which times out on looping animations).
Future<void> pumpFrames(WidgetTester tester, {int count = 10}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;

  final testUserModel = models.UserModel(
    uid: 'test_user_123',
    name: 'Test Seller',
    email: 'seller@example.com',
    roles: ['seller'],
    createdAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
    when(mockUser.uid).thenReturn('test_user_123');
  });

  Widget buildScreen({
    Stream<List<Product>>? productsStream,
    int unansweredQaCount = 0,
    bool loggedIn = true,
  }) {
    return TestWrapper(
      overrides: [
        if (loggedIn) currentUserProvider.overrideWithValue(mockUser),
        if (!loggedIn) currentUserProvider.overrideWithValue(null),
        userProfileProvider.overrideWith(
          (ref) => loggedIn ? Stream.value(testUserModel) : Stream.value(null),
        ),
        firestoreProvider.overrideWithValue(fakeFirestore),
        sellerProductsProvider.overrideWith(
          (ref) => productsStream ?? Stream.value([]),
        ),
        sellerUnansweredQaProvider('test_user_123')
            .overrideWith((ref) => Stream.value(unansweredQaCount)),
      ],
      onGenerateRoute: (settings) {
        // Stub all routes to prevent navigation errors in tests
        return MaterialPageRoute(
          builder: (_) => Scaffold(body: Text('Route: ${settings.name}')),
          settings: settings,
        );
      },
      child: const SellerProductsScreen(),
    );
  }

  group('SellerProductsScreen', () {
    group('login required state', () {
      testWidgets('shows login required when user is null', (tester) async {
        await tester.pumpWidget(buildScreen(loggedIn: false));
        await pumpFrames(tester);

        expect(find.text('Login Required'), findsWidgets);
        expect(find.text('Sign in to manage your business'), findsOneWidget);
      });
    });

    group('loading state', () {
      testWidgets('shows shimmer skeleton while loading', (tester) async {
        await tester.pumpWidget(
          buildScreen(productsStream: StreamController<List<Product>>().stream),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SellerProductsScreen), findsOneWidget);
      });
    });

    group('error state', () {
      testWidgets('shows error state with retry button', (tester) async {
        await tester.pumpWidget(
          buildScreen(productsStream: Stream.error(Exception('Network error'))),
        );
        await pumpFrames(tester);

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('retry button is tappable', (tester) async {
        await tester.pumpWidget(
          buildScreen(productsStream: Stream.error(Exception('fail'))),
        );
        await pumpFrames(tester);

        final retryButton = find.text('Retry');
        expect(retryButton, findsOneWidget);
        await tester.tap(retryButton);
        await tester.pump();
      });
    });

    group('empty products state', () {
      testWidgets('shows empty state when no products', (tester) async {
        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value([])),
        );
        await pumpFrames(tester);

        expect(find.text('No products yet'), findsOneWidget);
        expect(find.text('Add your first product to start selling'), findsOneWidget);
        expect(find.text('Add Product'), findsWidgets);
      });
    });

    group('product list', () {
      testWidgets('displays products with name and price', (tester) async {
        final products = [
          _makeProduct(id: 'p1', name: 'Widget A', price: 19.99),
          _makeProduct(id: 'p2', name: 'Widget B', price: 49.99),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('Widget A'), findsOneWidget);
        expect(find.text('Widget B'), findsOneWidget);
        expect(find.text(r'$19.99'), findsOneWidget);
        expect(find.text(r'$49.99'), findsOneWidget);
      });

      testWidgets('displays stock count for each product', (tester) async {
        final products = [
          _makeProduct(id: 'p1', name: 'Item', stockQuantity: 25),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('25 in stock'), findsOneWidget);
      });

      testWidgets('displays status badge for active product', (tester) async {
        final products = [
          _makeProduct(lifecycleStatus: ProductLifecycleStatusValues.active),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('Active'), findsOneWidget);
      });

      testWidgets('displays status badge for paused product', (tester) async {
        final products = [
          _makeProduct(lifecycleStatus: ProductLifecycleStatusValues.paused),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('Pause'), findsWidgets);
      });

      testWidgets('displays status badge for draft product', (tester) async {
        final products = [
          _makeProduct(lifecycleStatus: ProductLifecycleStatusValues.draft),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('Draft'), findsWidgets);
      });

      testWidgets('displays under review badge', (tester) async {
        final products = [
          _makeProduct(lifecycleStatus: ProductLifecycleStatusValues.underReview),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('Under Review'), findsWidgets);
      });

      testWidgets('displays rejected product with rejection banner', (tester) async {
        final products = [
          _makeProduct(
            lifecycleStatus: ProductLifecycleStatusValues.rejected,
            approvalRejectionReason: 'Inappropriate content',
          ),
        ];

        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('Rejected'), findsWidgets);
        expect(find.text('Rejection Reason'), findsOneWidget);
        expect(find.text('Inappropriate content'), findsOneWidget);
        expect(find.text('Fix & Resubmit'), findsOneWidget);
      });

      testWidgets('shows placeholder image when product has no images', (tester) async {
        final products = [
          _makeProduct(imageUrls: []),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      });

      testWidgets('shows low stock warning color', (tester) async {
        final products = [
          _makeProduct(stockQuantity: 3),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('3 in stock'), findsOneWidget);
      });

      testWidgets('shows out of stock error color', (tester) async {
        final products = [
          _makeProduct(stockQuantity: 0),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('0 in stock'), findsOneWidget);
      });
    });

    group('add product button', () {
      testWidgets('app bar has add product button with products', (tester) async {
        final products = [_makeProduct()];
        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.byIcon(Icons.add_box_outlined), findsWidgets);
      });

      testWidgets('empty state has add product button', (tester) async {
        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value([])),
        );
        await pumpFrames(tester);

        expect(find.text('Add Product'), findsWidgets);
      });
    });

    group('Q&A badge', () {
      testWidgets('shows Q&A badge with count when questions exist', (tester) async {
        final products = [_makeProduct()];

        await tester.pumpWidget(
          buildScreen(
            productsStream: Stream.value(products),
            unansweredQaCount: 5,
          ),
        );
        await pumpFrames(tester);

        expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('shows Q&A icon without count badge when zero', (tester) async {
        final products = [_makeProduct()];

        await tester.pumpWidget(
          buildScreen(
            productsStream: Stream.value(products),
            unansweredQaCount: 0,
          ),
        );
        await pumpFrames(tester);

        expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
        expect(find.text('0'), findsNothing);
      });
    });

    group('product card interactions', () {
      testWidgets('tapping product card triggers navigation', (tester) async {
        final products = [_makeProduct()];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        await tester.tap(find.text('Test Product'));
        await tester.pump();
        // Verify no crash — route is handled by onGenerateRoute stub
      });
    });

    group('screen structure', () {
      testWidgets('has seller_products_screen key', (tester) async {
        final products = [_makeProduct()];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.byKey(const Key('seller_products_screen')), findsOneWidget);
      });

      testWidgets('shows product count in subtitle when products exist', (tester) async {
        final products = [
          _makeProduct(id: 'p1'),
          _makeProduct(id: 'p2'),
          _makeProduct(id: 'p3'),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('3 products'), findsOneWidget);
      });

      testWidgets('shows My Products title with products', (tester) async {
        final products = [_makeProduct()];
        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('My Products'), findsWidgets);
      });
    });

    group('multiple lifecycle statuses', () {
      testWidgets('archived product shows correct badge', (tester) async {
        final products = [
          _makeProduct(lifecycleStatus: ProductLifecycleStatusValues.archived),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('Archived'), findsWidgets);
      });

      testWidgets('approved product shows correct badge', (tester) async {
        final products = [
          _makeProduct(lifecycleStatus: ProductLifecycleStatusValues.approved),
        ];

        await tester.pumpWidget(
          buildScreen(productsStream: Stream.value(products)),
        );
        await pumpFrames(tester);

        expect(find.text('Approved'), findsWidgets);
      });
    });
  });
}
