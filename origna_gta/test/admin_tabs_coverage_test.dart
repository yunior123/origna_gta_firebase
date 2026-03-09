import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/features/admin/admin_repository.dart';
import 'package:origna_gta/features/admin/tabs/admin_orders_tab.dart';
import 'package:origna_gta/features/admin/tabs/admin_payment_providers_tab.dart';
import 'package:origna_gta/features/admin/tabs/admin_products_tab.dart';
import 'package:origna_gta/features/admin/tabs/admin_sellers_tab.dart';
import 'package:origna_gta/features/admin/tabs/admin_users_tab.dart';
import 'package:origna_gta/models/models.dart';

@GenerateNiceMocks([MockSpec<AdminRepository>()])
import 'admin_tabs_coverage_test.mocks.dart';
import 'test_utils.dart';

void main() {
  late MockAdminRepository mockAdminRepo;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockAdminRepo = MockAdminRepository();
  });

  Widget testWrapper(Widget child, {List<Override> overrides = const []}) {
    return TestWrapper(
      overrides: [adminRepositoryProvider.overrideWithValue(mockAdminRepo), ...overrides],
      child: Scaffold(body: child),
    );
  }

  group('AdminSellersTab', () {
    testWidgets('renders sellers list', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sellers = [
        UserModel(uid: 's1', name: 'Seller 1', email: 's1@e.com', roles: ['seller'], createdAt: DateTime.now()),
      ];
      when(mockAdminRepo.watchSellers()).thenAnswer((_) => Stream.value(sellers));

      await tester.pumpWidget(testWrapper(const AdminSellersTab()));
      await tester.pumpAndSettle();

      expect(find.text('Seller 1'), findsOneWidget);
    });
  });

  group('AdminUsersTab', () {
    testWidgets('renders users list', (tester) async {
      final users = [
        UserModel(uid: 'u1', name: 'User 1', email: 'u1@e.com', roles: ['buyer'], createdAt: DateTime.now()),
      ];
      when(mockAdminRepo.watchUsers()).thenAnswer((_) => Stream.value(users));

      await tester.pumpWidget(testWrapper(const AdminUsersTab()));
      await tester.pumpAndSettle();

      expect(find.text('User 1'), findsOneWidget);
    });
  });

  group('AdminOrdersTab', () {
    testWidgets('renders orders list', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final orders = [
        OrderModel(
          orderId: 'order_id_12345678',
          userId: 'u1',
          items: [],
          totalAmountCents: 10000,
          subtotalCents: 9000,
          orderStatus: 'confirmed',
          shippingAddress: {},
          createdAt: DateTime.now(),
          customerId: 'c1',
          customerEmail: 'u1@e.com',
          taxes: {},
          currency: 'cad',
          sellerIds: ['s1'],
          stripeSessionId: 'ss1',
        ),
      ];
      when(mockAdminRepo.watchOrders(status: anyNamed('status'))).thenAnswer((_) => Stream.value(<OrderModel>[...orders]));

      await tester.pumpWidget(testWrapper(const AdminOrdersTab()));
      await tester.pumpAndSettle();

      expect(find.textContaining('ORDER_ID'), findsWidgets);
    });
  });

  group('AdminProductsTab', () {
    testWidgets('renders products list', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final products = [
        ProductModel(
          id: 'p1',
          name: 'Product 1',
          price: 10.0,
          imageUrls: [],
          sellerAddress: Address.empty(),
          description: 'Desc',
          stockQuantity: 10,
          categoryId: 1,
          sellerId: 's1',
          keywords: ['k1'],
        ),
      ];
      when(mockAdminRepo.watchProducts(sellerId: anyNamed('sellerId'))).thenAnswer((_) => Stream.value(<ProductModel>[...products]));

      await tester.pumpWidget(testWrapper(const AdminProductsTab()));
      await tester.pumpAndSettle();

      expect(find.text('Product 1'), findsOneWidget);
    });
  });

  group('AdminPaymentProvidersTab', () {
    testWidgets('renders payment providers', (tester) async {
      final providersData = {
        'providers': {
          'stripe': {'enabled': true, 'configured': true, 'missingKeys': []},
        },
        'enabledProviders': ['stripe'],
      };
      when(mockAdminRepo.getPaymentProviders()).thenAnswer((_) async => providersData);

      await tester.pumpWidget(testWrapper(const AdminPaymentProvidersTab()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Stripe'), findsWidgets);
    });
  });
}
