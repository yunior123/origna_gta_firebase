import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/models/generated/models.dart' as gen;
import 'package:origna_gta/widgets/order_widgets.dart';

import '../test_utils.dart';
@GenerateNiceMocks([
  MockSpec<OrderRepository>(),
  MockSpec<CartController>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
])
import 'order_widgets_test.mocks.dart';

void main() {
  late MockOrderRepository mockOrderRepo;
  late MockCartController mockCartController;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockOrderRepo = MockOrderRepository();
    mockCartController = MockCartController();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult();

    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
  });

  Widget buildTestWidget(Widget child, WidgetTester tester) {
    tester.view.physicalSize = const Size(2000, 3000);
    tester.view.devicePixelRatio = 1.0;
    return TestWrapper(
      overrides: [
        orderRepositoryProvider.overrideWithValue(mockOrderRepo),
        cartControllerProvider.overrideWithValue(mockCartController),
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Dummy Route'))),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('OrderWidgets Exhaustive Helpers', () {
    test('getItemDeliveryStep maps correctly', () {
      expect(getItemDeliveryStep(DeliveryStatusValues.pending), 0);
      expect(getItemDeliveryStep(DeliveryStatusValues.shipped), 1);
      expect(getItemDeliveryStep(DeliveryStatusValues.delivered), 2);
      expect(getItemDeliveryStep('unknown'), -1);
    });

    test('getItemStatusConfig covers all branches', () {
      final statuses = [
        OrderStatusValues.confirmed,
        OrderStatusValues.processing,
        OrderStatusValues.shipped,
        OrderStatusValues.delivered,
        DeliveryStatusValues.refunded,
        OrderStatusValues.cancelled,
        OrderStatusValues.disputed,
        OrderStatusValues.inTransit,
        OrderStatusValues.failed,
        OrderStatusValues.expired,
        OrderStatusValues.partiallyRefunded,
        'other',
      ];
      for (final s in statuses) {
        final config = getItemStatusConfig(s);
        expect(config.label, isNotEmpty);
      }
    });

    test('getOrderStatusConfig covers all enum values', () {
      for (final s in gen.OrderStatus.values) {
        final config = getOrderStatusConfig(s);
        expect(config.label, isNotEmpty);
      }
    });

    test('getTimelineStep maps correctly', () {
      expect(getTimelineStep(gen.OrderStatus.confirmed), 0);
      expect(getTimelineStep(gen.OrderStatus.delivered), 4);
      expect(getTimelineStep(gen.OrderStatus.cancelled), -1);
    });
  });

  group('OrderWidgets Component Smoke Tests', () {
    final mockItem = gen.OrderItem(
      productId: 'p1',
      name: 'Item 1',
      description: 'D1',
      price: 10.0,
      quantity: 1,
      status: DeliveryStatusValues.pending,
      sellerId: 's1',
      sellerName: 'Seller 1',
      imageUrls: const [],
      estimatedShipDays: 3,
      sellerAddress: const gen.Address(street: 'S', city: 'C', state: 'ON', postalCode: 'M1M 1M1', country: 'CA'),
    );

    testWidgets('renders DigitalItemActions with license key', (tester) async {
      final digitalItem = mockItem.copyWith(
        isDigital: true,
        digitalUnlocked: true,
        licenseKey: 'LICENSE-123',
      );
      await tester.pumpWidget(buildTestWidget(DigitalItemActions(item: digitalItem), tester));
      await tester.pump();
      expect(find.text('LICENSE-123'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('renders OrderStatusTimeline', (tester) async {
      await tester.pumpWidget(buildTestWidget(const OrderStatusTimeline(currentStep: 2), tester));
      await tester.pump();
      expect(find.byType(OrderStatusTimeline), findsOneWidget);
    });

    testWidgets('renders PendingApprovalsBanner', (tester) async {
      await tester.pumpWidget(buildTestWidget(const PendingApprovalsBanner(count: 5), tester));
      await tester.pump();
      expect(find.textContaining('5'), findsOneWidget);
    });

    testWidgets('renders SellerPackageTimeline', (tester) async {
      await tester.pumpWidget(buildTestWidget(const SellerPackageTimeline(currentStep: 1), tester));
      await tester.pump();
      expect(find.byType(SellerPackageTimeline), findsOneWidget);
    });

    testWidgets('renders SoftwareDownloadLinks', (tester) async {
      final softwareItem = mockItem.copyWith(
        digitalType: DigitalTypeValues.software,
        digitalBuilds: {'macos': 'url1', 'windows': 'url2'},
      );
      await tester.pumpWidget(buildTestWidget(SoftwareDownloadLinks(item: softwareItem), tester));
      await tester.pump();
      expect(find.text('macOS'), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
    });
  });

  group('BuyerOrderCard Integration', () {
    final mockOrder = gen.Order(
      orderId: 'order_123',
      userId: 'user_123',
      customerId: 'c1',
      customerEmail: 'e@e.com',
      items: [
        gen.OrderItem(
          productId: 'p1',
          name: 'Product 1',
          description: 'D1',
          price: 10.0,
          quantity: 1,
          status: DeliveryStatusValues.pending,
          sellerId: 's1',
          sellerName: 'Seller 1',
          imageUrls: const [],
          estimatedShipDays: 3,
          sellerAddress: const gen.Address(street: 'S', city: 'C', state: 'ON', postalCode: 'M1M 1M1', country: 'CA'),
        ),
      ],
      totalAmountCents: 1000,
      subtotalCents: 1000,
      shippingCostCents: 0,
      taxAmountCents: 0,
      taxes: const gen.Taxes(),
      orderStatus: gen.OrderStatus.confirmed,
      paymentStatus: gen.PaymentStatus.authorized,
      shippingApprovalStatus: gen.ShippingApprovalStatus.notRequired,
      createdAt: DateTime.now(),
      shippingAddress: const gen.Address(street: 'B', city: 'BC', state: 'BC', postalCode: 'V1V 1V1', country: 'CA'),
      currency: 'cad',
      sellerIds: const ['s1'],
      stripeSessionId: 'sess_123',
    );

    testWidgets('renders detailed order view', (tester) async {
      await tester.pumpWidget(buildTestWidget(BuyerOrderCard(order: mockOrder, isDetailView: true), tester));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('BC'), findsWidgets); // shipping address
    });

    testWidgets('reorder items interaction', (tester) async {
      final deliveredOrder = mockOrder.copyWith(orderStatus: gen.OrderStatus.delivered);
      when(mockCartController.addToCart(any, any, variantId: anyNamed('variantId'))).thenAnswer((_) async => true);
      
      await tester.pumpWidget(buildTestWidget(BuyerOrderCard(order: deliveredOrder), tester));
      await tester.pump(const Duration(seconds: 1));
      
      final buyAgainBtn = find.text('orders.buy_again'.tr());
      await tester.ensureVisible(buyAgainBtn);
      await tester.tap(buyAgainBtn);
      await tester.pumpAndSettle();
      
      verify(mockCartController.addToCart('p1', 1, variantId: null)).called(1);
    });
  });
}
