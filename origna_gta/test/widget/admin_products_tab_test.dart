import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:origna_gta/features/admin/tabs/admin_products_tab.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/features/admin/admin_actions_viewmodel.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<AdminActionsViewModel>(),
])
import 'admin_products_tab_test.mocks.dart';

void main() {
  late MockAdminActionsViewModel mockActions;

  setUp(() {
    mockActions = MockAdminActionsViewModel();
    initTestMocks();
  });

  final testAddress = Address(
    street: '123 Main St',
    city: 'Toronto',
    state: 'ON',
    postalCode: 'M5V 3A8',
    country: 'Canada',
  );

  final testProduct = ProductModel(
    id: 'p1',
    name: 'Honey',
    price: 10.0,
    imageUrls: [],
    sellerAddress: testAddress,
    description: 'Sweet honey',
    sellerId: 's1',
    stockQuantity: 10,
    categoryId: 1,
    keywords: ['honey'],
    lifecycleStatus: ProductLifecycleStatusValues.active,
  );

  Widget createTestWidget({
    List<ProductModel> products = const [],
    AdminActionsState actionsState = const AdminActionsState(),
  }) {
    when(mockActions.state).thenReturn(actionsState);

    return TestWrapper(
      overrides: [
        adminProductsProvider(null).overrideWith((ref) => Stream.value(products)),
        adminActionsViewModelProvider.overrideWith((ref) => mockActions),
      ],
      child: const Scaffold(body: AdminProductsTab()),
    );
  }

  group('AdminProductsTab Widget Tests', () {
    testWidgets('renders search and filter chips', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('admin.sellers.filter_all_products'.tr()), findsOneWidget);
    });

    testWidgets('renders list of products', (tester) async {
      await tester.pumpWidget(createTestWidget(products: [testProduct]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Honey'), findsOneWidget);
      expect(find.text('\$10.00'), findsOneWidget);
    });

    testWidgets('can filter by stock status', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final outOfStockProduct = ProductModel(
        id: 'p2',
        name: 'Sold Out',
        price: 10.0,
        imageUrls: [],
        sellerAddress: testAddress,
        description: 'None',
        sellerId: 's1',
        stockQuantity: 0,
        categoryId: 1,
        keywords: [],
        lifecycleStatus: ProductLifecycleStatusValues.active,
      );
      
      await tester.pumpWidget(createTestWidget(products: [testProduct, outOfStockProduct]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Honey'), findsOneWidget);
      expect(find.text('Sold Out'), findsOneWidget);

      final filterChip = find.text('admin.sellers.filter_out_of_stock'.tr());
      await tester.ensureVisible(filterChip);
      await tester.tap(filterChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Honey'), findsNothing);
      expect(find.text('Sold Out'), findsOneWidget);
    });

    testWidgets('can search for products', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final otherProduct = ProductModel(
        id: 'p2',
        name: 'Maple Syrup',
        price: 10.0,
        imageUrls: [],
        sellerAddress: testAddress,
        description: 'None',
        sellerId: 's1',
        stockQuantity: 10,
        categoryId: 1,
        keywords: [],
        lifecycleStatus: ProductLifecycleStatusValues.active,
      );
      
      await tester.pumpWidget(createTestWidget(products: [testProduct, otherProduct]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'maple');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Honey'), findsNothing);
      expect(find.text('Maple Syrup'), findsOneWidget);
    });
  });
}
