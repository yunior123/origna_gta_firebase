import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/orders/orders_provider.dart';
import 'package:origna_gta/features/orders/seller_orders_state.dart' as seller_orders_state;
import 'package:origna_gta/features/orders/seller_orders_viewmodel.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/models/generated/models.dart' as models;
import 'package:origna_gta/models/models.dart' as core_models;
import 'package:origna_gta/screens/seller_orders_screen.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

import '../test_utils.dart';
@GenerateNiceMocks([MockSpec<auth.User>(), MockSpec<SellerOrdersViewModel>(), MockSpec<NavigatorObserver>()])
import 'seller_orders_screen_test.mocks.dart';

void main() {
  setUpAll(() {
    initTestMocks();
  });

  late MockUser mockUser;
  late MockSellerOrdersViewModel mockViewModel;
  late MockNavigatorObserver mockNavigatorObserver;

  final testAddress = core_models.Address(street: '123 Main St', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada');
  final testAddressGenerated = models.Address(street: '123 Main St', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada');

  final testUser = UserModel(
    uid: 'seller_123',
    email: 'seller@example.com',
    name: 'Test Seller',
    roles: ['seller'],
    createdAt: DateTime.now(),
    address: testAddress,
  );

  final testOrderItem = models.OrderItem(
    productId: 'prod_1',
    name: 'Test Product',
    description: '',
    price: 50.0,
    quantity: 2,
    sellerId: 'seller_123',
    status: 'pending',
    imageUrls: ['https://example.com/image.png'],
  );

  final testOrder = models.Order(
    orderId: 'order_123456789',
    userId: 'buyer_123',
    items: [testOrderItem],
    totalAmountCents: 11300,
    subtotalCents: 10000,
    taxAmountCents: 1300,
    platformFeeTotalCents: 500,
    taxes: const models.Taxes(),
    createdAt: DateTime.now(),
    orderStatus: models.OrderStatus.pending,
    paymentStatus: models.PaymentStatus.paid,
    shippingAddress: testAddressGenerated,
  );

  setUp(() {
    mockUser = MockUser();
    mockViewModel = MockSellerOrdersViewModel();
    mockNavigatorObserver = MockNavigatorObserver();
    when(mockUser.uid).thenReturn('seller_123');
    when(mockUser.email).thenReturn('seller@example.com');
    when(mockUser.displayName).thenReturn('Test Seller');

    // Default viewmodel state
    when(mockViewModel.state).thenReturn(const seller_orders_state.SellerOrdersState());
  });

  Widget createSellerOrdersScreen({List<Override> overrides = const []}) {
    return TestWrapper(
      overrides: [
        currentUserProvider.overrideWithValue(mockUser),
        userProfileProvider.overrideWith((ref) => Stream.value(testUser)),
        // Remove overriding the view model to let it use the real one, which properly initializes state
        ...overrides,
      ],
      navigatorObservers: [mockNavigatorObserver],
      child: const SellerOrdersScreen(),
    );
  }

  void setupScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
  }

  group('SellerOrdersScreen Tests', () {
    testWidgets('renders empty state correctly', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(
        createSellerOrdersScreen(
          overrides: [
            sellerOrdersProvider.overrideWith((ref) => Stream.value([])),
            sellerUnansweredQaProvider('seller_123').overrideWith((ref) => Stream.value(0)),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Manage Orders'), findsWidgets);
      expect(find.textContaining('No orders yet'), findsOneWidget);
    });

    testWidgets('renders loading state', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(
        createSellerOrdersScreen(
          overrides: [
            sellerOrdersProvider.overrideWith((ref) => const Stream.empty()),
            sellerUnansweredQaProvider('seller_123').overrideWith((ref) => Stream.value(0)),
          ],
        ),
      );

      await tester.pump();
      expect(find.byType(ModernLoadingIndicator), findsOneWidget);
    });

    testWidgets('renders orders correctly', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(
        createSellerOrdersScreen(
          overrides: [
            sellerOrdersProvider.overrideWith((ref) => Stream.value([testOrder])),
            sellerUnansweredQaProvider('seller_123').overrideWith((ref) => Stream.value(0)),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('ORDER_12'), findsOneWidget);
      expect(find.text('Test Product'), findsOneWidget);
      expect(find.textContaining('\$97.50'), findsOneWidget); // Net: 100 - 2.5% fee
      expect(find.textContaining('Total Earnings'), findsOneWidget);
    });

    testWidgets('shows unanswered Q&A badge when count > 0', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(
        createSellerOrdersScreen(
          overrides: [
            sellerOrdersProvider.overrideWith((ref) => Stream.value([])),
            sellerUnansweredQaProvider('seller_123').overrideWith((ref) => Stream.value(5)),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows authorization banner when payment status is awaitingPayment', (WidgetTester tester) async {
      final authOrder = testOrder.copyWith(paymentStatus: models.PaymentStatus.awaitingPayment, actualShippingCents: 0);

      setupScreenSize(tester);
      await tester.pumpWidget(
        createSellerOrdersScreen(
          overrides: [
            sellerOrdersProvider.overrideWith((ref) => Stream.value([authOrder])),
            sellerUnansweredQaProvider('seller_123').overrideWith((ref) => Stream.value(0)),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Payment Authorized'), findsOneWidget);
      expect(find.textContaining('Confirm Shipping & Ship'), findsOneWidget);
    });

    testWidgets('can open mark as shipped dialog', (WidgetTester tester) async {
      setupScreenSize(tester);
      await tester.pumpWidget(
        createSellerOrdersScreen(
          overrides: [
            sellerOrdersProvider.overrideWith((ref) => Stream.value([testOrder])),
            sellerUnansweredQaProvider('seller_123').overrideWith((ref) => Stream.value(0)),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final shipBtn = find.byTooltip('Mark Shipped');
      expect(shipBtn, findsOneWidget);
      await tester.tap(shipBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Mark Shipped'), findsWidgets);
      expect(find.textContaining('Carrier'), findsWidgets);
      expect(find.textContaining('Tracking Number'), findsWidgets);
    });

    testWidgets('shows account suspended message when user is suspended', (WidgetTester tester) async {
      final suspendedUser = testUser.copyWith(suspended: true);

      setupScreenSize(tester);
      await tester.pumpWidget(
        createSellerOrdersScreen(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(suspendedUser)),
            sellerOrdersProvider.overrideWith((ref) => Stream.value([])),
            sellerUnansweredQaProvider('seller_123').overrideWith((ref) => Stream.value(0)),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Account Suspended'), findsOneWidget);
    });

    testWidgets('renders digital product badge', (WidgetTester tester) async {
      final digitalItem = testOrderItem.copyWith(isDigital: true);
      final digitalOrder = testOrder.copyWith(items: [digitalItem]);

      setupScreenSize(tester);
      await tester.pumpWidget(
        createSellerOrdersScreen(
          overrides: [
            sellerOrdersProvider.overrideWith((ref) => Stream.value([digitalOrder])),
            sellerUnansweredQaProvider('seller_123').overrideWith((ref) => Stream.value(0)),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Digital'), findsOneWidget);
      // Mark as shipped button should NOT be present for digital items
      expect(find.byTooltip('Mark as Shipped'), findsNothing);
    });
  });
}
