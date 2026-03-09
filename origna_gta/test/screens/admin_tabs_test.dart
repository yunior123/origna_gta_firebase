import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/features/admin/admin_repository.dart';
import 'package:origna_gta/features/admin/tabs/admin_orders_tab.dart';
import 'package:origna_gta/features/admin/tabs/admin_payment_providers_tab.dart';
import 'package:origna_gta/features/admin/tabs/admin_products_tab.dart';
import 'package:origna_gta/features/admin/tabs/admin_reviews_tab.dart';
import 'package:origna_gta/features/admin/tabs/admin_security_tab.dart';
import 'package:origna_gta/features/admin/tabs/admin_sellers_tab.dart';
import 'package:origna_gta/features/admin/tabs/admin_users_tab.dart';

import '../test_utils.dart';
@GenerateNiceMocks([MockSpec<AdminRepository>()])
import 'admin_tabs_test.mocks.dart';

void main() {
  late MockAdminRepository mockAdminRepo;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockAdminRepo = MockAdminRepository();

    // Default stubs for streams
    when(mockAdminRepo.watchUsers()).thenAnswer((_) => Stream.value([]));
    when(mockAdminRepo.watchOrders(status: anyNamed('status'))).thenAnswer((_) => Stream.value([]));
    when(mockAdminRepo.watchProducts(sellerId: anyNamed('sellerId'))).thenAnswer((_) => Stream.value([]));
    when(mockAdminRepo.watchSellers()).thenAnswer((_) => Stream.value([]));
    when(mockAdminRepo.watchReviews(flaggedOnly: anyNamed('flaggedOnly'), hasPhotosOnly: anyNamed('hasPhotosOnly'))).thenAnswer((_) => Stream.value([]));
  });

  group('Admin Tabs Smoke Tests', () {
    testWidgets('pumps AdminUsersTab', (tester) async {
      tester.view.physicalSize = const Size(3000, 3000);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        TestWrapper(
          overrides: [adminRepositoryProvider.overrideWithValue(mockAdminRepo)],
          child: const Scaffold(body: AdminUsersTab()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminUsersTab), findsOneWidget);
      tester.view.resetPhysicalSize();
    });

    testWidgets('pumps AdminOrdersTab', (tester) async {
      tester.view.physicalSize = const Size(3000, 3000);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        TestWrapper(
          overrides: [adminRepositoryProvider.overrideWithValue(mockAdminRepo)],
          child: const Scaffold(body: AdminOrdersTab()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminOrdersTab), findsOneWidget);
      tester.view.resetPhysicalSize();
    });

    testWidgets('pumps AdminProductsTab', (tester) async {
      tester.view.physicalSize = const Size(3000, 3000);
      tester.view.devicePixelRatio = 1.0;
      when(mockAdminRepo.watchPendingReviewProducts()).thenAnswer((_) => Stream.value([]));
      await tester.pumpWidget(
        TestWrapper(
          overrides: [adminRepositoryProvider.overrideWithValue(mockAdminRepo)],
          child: const Scaffold(body: AdminProductsTab()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminProductsTab), findsOneWidget);
      tester.view.resetPhysicalSize();
    });

    testWidgets('pumps AdminSellersTab', (tester) async {
      tester.view.physicalSize = const Size(3000, 3000);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        TestWrapper(
          overrides: [adminRepositoryProvider.overrideWithValue(mockAdminRepo)],
          child: const Scaffold(body: AdminSellersTab()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminSellersTab), findsOneWidget);
      tester.view.resetPhysicalSize();
    });

    testWidgets('pumps AdminReviewsTab', (tester) async {
      tester.view.physicalSize = const Size(3000, 3000);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        TestWrapper(
          overrides: [adminRepositoryProvider.overrideWithValue(mockAdminRepo)],
          child: const Scaffold(body: AdminReviewsTab()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminReviewsTab), findsOneWidget);
      tester.view.resetPhysicalSize();
    });

    testWidgets('pumps AdminSecurityTab', (tester) async {
      tester.view.physicalSize = const Size(3000, 3000);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        TestWrapper(
          overrides: [adminRepositoryProvider.overrideWithValue(mockAdminRepo)],
          child: const Scaffold(body: AdminSecurityTab()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminSecurityTab), findsOneWidget);
      tester.view.resetPhysicalSize();
    });

    testWidgets('pumps AdminPaymentProvidersTab', (tester) async {
      tester.view.physicalSize = const Size(3000, 3000);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        TestWrapper(
          overrides: [adminRepositoryProvider.overrideWithValue(mockAdminRepo)],
          child: const Scaffold(body: AdminPaymentProvidersTab()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminPaymentProvidersTab), findsOneWidget);
      tester.view.resetPhysicalSize();
    });
  });
}
