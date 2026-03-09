import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/cart_screen.dart';
import 'package:origna_gta/screens/cartitem_screen.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<User>(),
  MockSpec<CartController>(),
  MockSpec<NavigatorObserver>(),
])
import 'cart_screen_test.mocks.dart';

void main() {
  setUpAll(() {
    initTestMocks();
  });

  late MockUser mockUser;
  late MockCartController mockCartController;
  late MockNavigatorObserver mockNavigatorObserver;

  final testAddress = Address(
    street: '123 Main St',
    city: 'Toronto',
    state: 'ON',
    postalCode: 'M5V 3A8',
    country: 'Canada',
  );

  final testUser = UserModel(
    uid: 'user_123',
    email: 'test@example.com',
    name: 'Test User',
    roles: ['buyer'],
    createdAt: DateTime.now(),
    address: testAddress,
  );

  final testCartItem = CartItemModel(
    cartItemId: 'item_1',
    productId: 'prod_1',
    quantity: 2,
    createdAt: Timestamp.now(),
  );

  final testProduct = CartItemDetailModel(
    productId: 'prod_1',
    name: 'Test Product',
    description: 'Description',
    price: 50.0,
    imageUrls: ['https://example.com/image.png'],
    quantity: 2,
    createdAt: Timestamp.now(),
    sellerAddress: testAddress,
    sellerId: 'seller_1',
    sellerName: 'Test Seller',
  );

  setUp(() {
    mockUser = MockUser();
    mockCartController = MockCartController();
    mockNavigatorObserver = MockNavigatorObserver();
    when(mockUser.uid).thenReturn('user_123');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn('Test User');
  });

  Widget createCartScreen({
    List<Override> overrides = const [],
  }) {
    return TestWrapper(
      overrides: [
        currentUserProvider.overrideWithValue(mockUser),
        userProfileProvider.overrideWith((ref) => Stream.value(testUser)),
        cartControllerProvider.overrideWithValue(mockCartController),
        ...overrides,
      ],
      navigatorObservers: [mockNavigatorObserver],
      child: const CartScreen(),
    );
  }

  void setupScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
  }

  group('CartScreen Tests', () {
    testWidgets('renders empty cart message when no items', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value(<CartItemModel>[])),
          unavailableCartItemsProvider.overrideWith((ref) => Future.value(<String>[])),
          cartWithDetailsProvider.overrideWith((ref) => Future.value(<CartItemDetailModel>[])),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('cart_empty_message')), findsOneWidget);
      expect(find.textContaining('Empty cart'), findsOneWidget);
    });

    testWidgets('renders loading state', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => const Stream.empty()),
        ],
      ));

      await tester.pump();
      expect(find.textContaining('Loading cart'), findsOneWidget);
    });

    testWidgets('renders error state', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.error('Error')),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Unable to load'), findsOneWidget);
    });

    testWidgets('renders items in cart correctly', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([testCartItem])),
          cartItemDetailProvider('item_1').overrideWith((ref) async => testProduct),
          cartWithDetailsProvider.overrideWith((ref) => Future.value([testProduct])),
          unavailableCartItemsProvider.overrideWith((ref) => Future.value(<String>[])),
          cartItemQuantityProvider('item_1').overrideWith((ref) => const AsyncValue.data(2)),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CartItemScreen), findsOneWidget);
      expect(find.text('Test Product'), findsWidgets);
    });

    testWidgets('shows free shipping progress when below threshold', (WidgetTester tester) async {
      setupScreenSize(tester);
      final cheapProduct = testProduct.copyWith(price: 10.0, quantity: 1);
      final cheapItem = CartItemModel(
        cartItemId: 'item_1',
        productId: 'prod_1',
        quantity: 1,
        createdAt: Timestamp.now(),
      );

      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([cheapItem])),
          cartItemDetailProvider('item_1').overrideWith((ref) async => cheapProduct),
          cartWithDetailsProvider.overrideWith((ref) => Future.value([cheapProduct])),
          unavailableCartItemsProvider.overrideWith((ref) => Future.value(<String>[])),
          cartItemQuantityProvider('item_1').overrideWith((ref) => const AsyncValue.data(1)),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('more for free shipping'), findsOneWidget);
    });

    testWidgets('shows free shipping qualified when above threshold', (WidgetTester tester) async {
      setupScreenSize(tester);
      final expensiveProduct = testProduct.copyWith(price: 1000.0, quantity: 1);
      final expensiveItem = CartItemModel(
        cartItemId: 'item_1',
        productId: 'prod_1',
        quantity: 1,
        createdAt: Timestamp.now(),
      );

      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([expensiveItem])),
          cartItemDetailProvider('item_1').overrideWith((ref) async => expensiveProduct),
          cartWithDetailsProvider.overrideWith((ref) => Future.value([expensiveProduct])),
          unavailableCartItemsProvider.overrideWith((ref) => Future.value(<String>[])),
          cartItemQuantityProvider('item_1').overrideWith((ref) => const AsyncValue.data(1)),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Free shipping qualified'), findsOneWidget);
    });

    testWidgets('can open delivery instructions dialog', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([testCartItem])),
          cartItemDetailProvider('item_1').overrideWith((ref) async => testProduct),
          cartWithDetailsProvider.overrideWith((ref) => Future.value([testProduct])),
          unavailableCartItemsProvider.overrideWith((ref) => Future.value(<String>[])),
          cartItemQuantityProvider('item_1').overrideWith((ref) => const AsyncValue.data(2)),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Try finding by text instead of semantics label
      final instrBtn = find.textContaining('Delivery Instructions');
      expect(instrBtn, findsWidgets);
      await tester.tap(instrBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Delivery Instructions'), findsWidgets);
      
      await tester.enterText(find.byType(TextField), 'Leave at the door');
      await tester.tap(find.textContaining('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Leave at the door'), findsOneWidget);
    });

    testWidgets('shows unavailable items warning', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([testCartItem])),
          cartItemDetailProvider('item_1').overrideWith((ref) async => testProduct),
          cartWithDetailsProvider.overrideWith((ref) => Future.value([testProduct])),
          unavailableCartItemsProvider.overrideWith((ref) => Future.value(['prod_1'])),
          cartItemQuantityProvider('item_1').overrideWith((ref) => const AsyncValue.data(2)),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('1 items unavailable'), findsOneWidget);
    });

    testWidgets('renders fallback UI for deleted products', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([testCartItem])),
          cartItemDetailProvider('item_1').overrideWith((ref) async => null),
          cartWithDetailsProvider.overrideWith((ref) => Future.value(<CartItemDetailModel>[])),
          unavailableCartItemsProvider.overrideWith((ref) => Future.value(<String>[])),
          cartItemQuantityProvider('item_1').overrideWith((ref) => const AsyncValue.data(2)),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Item no longer available'), findsOneWidget);
      expect(find.textContaining('Remove'), findsWidgets);

      await tester.tap(find.textContaining('Remove').first);
      verify(mockCartController.removeFromCart('item_1')).called(1);
    });

    testWidgets('can proceed to checkout', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([testCartItem])),
          cartItemDetailProvider('item_1').overrideWith((ref) async => testProduct),
          cartWithDetailsProvider.overrideWith((ref) => Future.value([testProduct])),
          unavailableCartItemsProvider.overrideWith((ref) => Future.value(<String>[])),
          cartItemQuantityProvider('item_1').overrideWith((ref) => const AsyncValue.data(2)),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final checkoutBtn = find.byKey(CartScreen.checkoutButtonKey);
      expect(checkoutBtn, findsOneWidget);
      await tester.tap(checkoutBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(mockNavigatorObserver.didPush(any, any));
    });

    testWidgets('shows info sheets for fees and taxes', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(createCartScreen(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([testCartItem])),
          cartItemDetailProvider('item_1').overrideWith((ref) async => testProduct),
          cartWithDetailsProvider.overrideWith((ref) => Future.value([testProduct])),
          unavailableCartItemsProvider.overrideWith((ref) => Future.value(<String>[])),
          cartItemQuantityProvider('item_1').overrideWith((ref) => const AsyncValue.data(2)),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final feeBtn = find.bySemanticsLabel('btn-info-service-fee');
      expect(feeBtn, findsOneWidget);
      await tester.tap(feeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Service Fees'), findsWidgets);
      await tester.tap(find.textContaining('Understood').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final taxBtn = find.bySemanticsLabel('btn-info-tax-estimate');
      expect(taxBtn, findsOneWidget);
      await tester.tap(taxBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Tax Estimate'), findsWidgets);
      await tester.tap(find.textContaining('Understood').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
