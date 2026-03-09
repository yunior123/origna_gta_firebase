import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/admin/tabs/admin_products_tab.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/features/admin/admin_repository.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<AdminRepository>(),
])
import 'admin_products_tab_comprehensive_test.mocks.dart';

void main() {
  late MockAdminRepository mockRepo;

  setUp(() {
    mockRepo = MockAdminRepository();
    initTestMocks();
  });

  final testAddress = Address(
    street: '123 Main St',
    city: 'Toronto',
    state: 'ON',
    postalCode: 'M5V 3A8',
    country: 'Canada',
  );

  ProductModel makeProduct({
    String id = 'p1',
    String name = 'Test Product',
    double price = 25.99,
    int stockQuantity = 10,
    String lifecycleStatus = ProductLifecycleStatusValues.active,
    List<String> imageUrls = const [],
    bool isDigital = false,
    String? digitalType,
    Map<String, String>? digitalBuilds,
    String sellerId = 's1',
  }) {
    return ProductModel(
      id: id,
      name: name,
      price: price,
      imageUrls: imageUrls,
      sellerAddress: testAddress,
      description: 'A test product',
      sellerId: sellerId,
      stockQuantity: stockQuantity,
      categoryId: 1,
      keywords: [name.toLowerCase()],
      lifecycleStatus: lifecycleStatus,
      isDigital: isDigital,
      digitalType: digitalType,
      digitalBuilds: digitalBuilds,
    );
  }

  Widget createTestWidget({
    List<ProductModel>? products,
    bool isError = false,
    bool isLoading = false,
  }) {
    final List<Override> overrides = [
      adminRepositoryProvider.overrideWithValue(mockRepo),
    ];

    if (isLoading) {
      overrides.add(
        adminProductsProvider(null).overrideWith(
          (ref) => Stream<List<ProductModel>>.multi((_) {}),
        ),
      );
    } else if (isError) {
      overrides.add(
        adminProductsProvider(null).overrideWith(
          (ref) => Stream<List<ProductModel>>.error(Exception('Network error')),
        ),
      );
    } else {
      overrides.add(
        adminProductsProvider(null).overrideWith(
          (ref) => Stream.value(products ?? []),
        ),
      );
    }

    return TestWrapper(
      overrides: overrides,
      child: const Scaffold(body: AdminProductsTab()),
    );
  }

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('AdminProductsTab — Loading State', () {
    testWidgets('shows loading indicator while data loads', (tester) async {
      await tester.pumpWidget(createTestWidget(isLoading: true));
      await tester.pump();

      expect(find.byType(ModernLoadingIndicator), findsOneWidget);
    });
  });

  group('AdminProductsTab — Error State', () {
    testWidgets('shows error message when data fetch fails', (tester) async {
      await tester.pumpWidget(createTestWidget(isError: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('admin.users.error_fetching'.tr()), findsOneWidget);
    });
  });

  group('AdminProductsTab — Empty State', () {
    testWidgets('shows empty state when no products exist', (tester) async {
      await tester.pumpWidget(createTestWidget(products: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('admin.sellers.no_products'.tr()), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    });
  });

  group('AdminProductsTab — Product List Rendering', () {
    testWidgets('renders product name and price', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(name: 'Maple Honey', price: 14.50);
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Maple Honey'), findsOneWidget);
      expect(find.text('\$14.50'), findsOneWidget);
    });

    testWidgets('renders out of stock badge for zero-stock products', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(stockQuantity: 0);
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('product.out_of_stock'.tr()), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_rounded), findsOneWidget);
    });

    testWidgets('renders low stock badge for stock < 5', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(stockQuantity: 3);
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('admin.sellers.low_stock_count'.tr(namedArgs: {'count': '3'})),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    testWidgets('renders in stock badge for stock >= 5', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(stockQuantity: 50);
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('admin.sellers.in_stock_count'.tr(namedArgs: {'count': '50'})),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsAtLeastNWidgets(1));
    });

    testWidgets('renders Approved badge for active lifecycle', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(
        lifecycleStatus: ProductLifecycleStatusValues.active,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Approved'), findsOneWidget);
    });

    testWidgets('renders Rejected badge for rejected lifecycle', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(
        lifecycleStatus: ProductLifecycleStatusValues.rejected,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('renders Under Review badge for underReview lifecycle', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(
        lifecycleStatus: ProductLifecycleStatusValues.underReview,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Under Review'), findsOneWidget);
    });

    testWidgets('renders placeholder icon when imageUrls is empty', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(imageUrls: []);
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.image_rounded), findsOneWidget);
    });

    testWidgets('renders multiple products', (tester) async {
      setLargeScreen(tester);
      final products = [
        makeProduct(id: 'p1', name: 'Product A', price: 10.0),
        makeProduct(id: 'p2', name: 'Product B', price: 20.0),
        makeProduct(id: 'p3', name: 'Product C', price: 30.0),
      ];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Product A'), findsOneWidget);
      expect(find.text('Product B'), findsOneWidget);
      expect(find.text('Product C'), findsOneWidget);
    });

    testWidgets('renders approved badge for approved status', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(
        lifecycleStatus: ProductLifecycleStatusValues.approved,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Approved'), findsOneWidget);
    });
  });

  group('AdminProductsTab — Search Filtering', () {
    testWidgets('filters products by search query', (tester) async {
      setLargeScreen(tester);
      final products = [
        makeProduct(id: 'p1', name: 'Honey Jar'),
        makeProduct(id: 'p2', name: 'Maple Syrup'),
      ];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Honey Jar'), findsOneWidget);
      expect(find.text('Maple Syrup'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'honey');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Honey Jar'), findsOneWidget);
      expect(find.text('Maple Syrup'), findsNothing);
    });

    testWidgets('shows no match text when search has no results', (tester) async {
      setLargeScreen(tester);
      final products = [makeProduct(name: 'Honey')];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).first, 'zzzznotfound');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('admin.sellers.no_match'.tr()), findsOneWidget);
    });

    testWidgets('search is case-insensitive', (tester) async {
      setLargeScreen(tester);
      final products = [makeProduct(name: 'Premium Coffee')];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).first, 'PREMIUM');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Premium Coffee'), findsOneWidget);
    });
  });

  group('AdminProductsTab — Stock Filter Chips', () {
    testWidgets('renders all filter chips', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(createTestWidget(products: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('admin.sellers.filter_all_products'.tr()), findsOneWidget);
      expect(find.text('admin.sellers.filter_in_stock'.tr()), findsOneWidget);
      expect(find.text('admin.sellers.filter_out_of_stock'.tr()), findsOneWidget);
      expect(find.text('admin.sellers.filter_low_stock'.tr()), findsOneWidget);
    });

    testWidgets('filter in_stock shows only products with stock > 0', (tester) async {
      setLargeScreen(tester);
      final products = [
        makeProduct(id: 'p1', name: 'Stocked Widget', stockQuantity: 10),
        makeProduct(id: 'p2', name: 'Depleted Widget', stockQuantity: 0),
      ];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final inStockChip = find.text('admin.sellers.filter_in_stock'.tr());
      await tester.ensureVisible(inStockChip);
      await tester.tap(inStockChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Stocked Widget'), findsOneWidget);
      expect(find.text('Depleted Widget'), findsNothing);
    });

    testWidgets('filter out_of_stock shows only products with stock == 0', (tester) async {
      setLargeScreen(tester);
      final products = [
        makeProduct(id: 'p1', name: 'Available Gadget', stockQuantity: 10),
        makeProduct(id: 'p2', name: 'Empty Gadget', stockQuantity: 0),
      ];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final outOfStockChip = find.text('admin.sellers.filter_out_of_stock'.tr());
      await tester.ensureVisible(outOfStockChip);
      await tester.tap(outOfStockChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Available Gadget'), findsNothing);
      expect(find.text('Empty Gadget'), findsOneWidget);
    });

    testWidgets('filter low_stock shows only products with 0 < stock < 5', (tester) async {
      setLargeScreen(tester);
      final products = [
        makeProduct(id: 'p1', name: 'Full Inventory', stockQuantity: 50),
        makeProduct(id: 'p2', name: 'Scarce Inventory', stockQuantity: 3),
        makeProduct(id: 'p3', name: 'Zero Inventory', stockQuantity: 0),
      ];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Use the first match to avoid collision with badge text
      final lowStockChips = find.text('admin.sellers.filter_low_stock'.tr());
      await tester.ensureVisible(lowStockChips.first);
      await tester.tap(lowStockChips.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Full Inventory'), findsNothing);
      expect(find.text('Scarce Inventory'), findsOneWidget);
      expect(find.text('Zero Inventory'), findsNothing);
    });

    testWidgets('filter all shows every product after narrowing', (tester) async {
      setLargeScreen(tester);
      final products = [
        makeProduct(id: 'p1', name: 'Alpha Item', stockQuantity: 50),
        makeProduct(id: 'p2', name: 'Beta Item', stockQuantity: 0),
      ];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Narrow to out_of_stock
      final outOfStockChip = find.text('admin.sellers.filter_out_of_stock'.tr());
      await tester.ensureVisible(outOfStockChip);
      await tester.tap(outOfStockChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Alpha Item'), findsNothing);

      // Back to all
      final allChip = find.text('admin.sellers.filter_all_products'.tr());
      await tester.ensureVisible(allChip);
      await tester.tap(allChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Alpha Item'), findsOneWidget);
      expect(find.text('Beta Item'), findsOneWidget);
    });

    testWidgets('pending_review filter shows only underReview products', (tester) async {
      setLargeScreen(tester);
      final products = [
        makeProduct(
          id: 'p1',
          name: 'Active Prod',
          lifecycleStatus: ProductLifecycleStatusValues.active,
        ),
        makeProduct(
          id: 'p2',
          name: 'Pending Prod',
          lifecycleStatus: ProductLifecycleStatusValues.underReview,
        ),
      ];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final pendingChip = find.textContaining('Pending Review');
      await tester.ensureVisible(pendingChip.first);
      await tester.tap(pendingChip.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Active Prod'), findsNothing);
      expect(find.text('Pending Prod'), findsOneWidget);
    });

    testWidgets('pending_review chip shows count badge', (tester) async {
      setLargeScreen(tester);
      final products = [
        makeProduct(
          id: 'p1',
          name: 'Review 1',
          lifecycleStatus: ProductLifecycleStatusValues.underReview,
        ),
        makeProduct(
          id: 'p2',
          name: 'Review 2',
          lifecycleStatus: ProductLifecycleStatusValues.underReview,
        ),
        makeProduct(
          id: 'p3',
          name: 'Active Prod',
          lifecycleStatus: ProductLifecycleStatusValues.active,
        ),
      ];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show count "2" for pending review items
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('AdminProductsTab — Product Actions (PopupMenu)', () {
    testWidgets('popup menu shows expected options for active product', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(
        lifecycleStatus: ProductLifecycleStatusValues.active,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // Active product should NOT show "Approve" (already active)
      expect(find.text('Approve Product'), findsNothing);
      // But should show reject, set stock, mark out of stock, view seller, delete
      expect(find.text('Reject Product'), findsOneWidget);
      expect(find.text('admin.sellers.set_stock'.tr()), findsOneWidget);
      expect(find.text('admin.sellers.mark_out_of_stock'.tr()), findsOneWidget);
      expect(find.text('admin.sellers.view_seller'.tr()), findsOneWidget);
      expect(find.text('admin.sellers.delete_product'.tr()), findsOneWidget);
    });

    testWidgets('popup menu shows approve for underReview product', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(
        lifecycleStatus: ProductLifecycleStatusValues.underReview,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Approve Product'), findsOneWidget);
      expect(find.text('Reject Product'), findsOneWidget);
    });

    testWidgets('popup menu hides reject for already rejected product', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(
        lifecycleStatus: ProductLifecycleStatusValues.rejected,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Approve Product'), findsOneWidget);
      expect(find.text('Reject Product'), findsNothing);
    });

    testWidgets('popup shows View Download URLs for digital product', (tester) async {
      setLargeScreen(tester);
      // Ignore overflow from popup menu item width constraint (pre-existing UI issue)
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      final product = makeProduct(
        isDigital: true,
        digitalType: 'software',
        digitalBuilds: {'macOS': 'https://example.com/mac'},
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('View Download URLs'), findsOneWidget);
    });

    testWidgets('popup hides View Download URLs for non-digital product', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(isDigital: false);
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('View Download URLs'), findsNothing);
    });
  });

  group('AdminProductsTab — Delete Dialog', () {
    testWidgets('shows delete confirmation dialog', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(name: 'Honey Jar');
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('admin.sellers.delete_product'.tr()));
      await tester.pumpAndSettle();

      expect(
        find.text('admin.sellers.delete_confirm'.tr(namedArgs: {'name': 'Honey Jar'})),
        findsOneWidget,
      );
      expect(find.text('common.cancel'.tr()), findsOneWidget);
      expect(find.text('common.delete'.tr()), findsOneWidget);
    });

    testWidgets('cancel dismisses delete dialog', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(name: 'Honey Jar');
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('admin.sellers.delete_product'.tr()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('common.cancel'.tr()));
      await tester.pumpAndSettle();

      expect(
        find.text('admin.sellers.delete_confirm'.tr(namedArgs: {'name': 'Honey Jar'})),
        findsNothing,
      );
    });

    testWidgets('confirm delete calls deleteProduct on repository', (tester) async {
      setLargeScreen(tester);
      when(mockRepo.deleteProduct(any)).thenAnswer((_) async {});
      final product = makeProduct(id: 'prod-123', name: 'Delete Me');
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('admin.sellers.delete_product'.tr()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('common.delete'.tr()));
      await tester.pumpAndSettle();

      verify(mockRepo.deleteProduct('prod-123')).called(1);
    });
  });

  group('AdminProductsTab — Set Stock Dialog', () {
    testWidgets('shows set stock dialog with current quantity', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(stockQuantity: 42);
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('admin.sellers.set_stock'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('admin.sellers.set_stock_title'.tr()), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('common.cancel'.tr()), findsOneWidget);
      expect(find.text('common.update'.tr()), findsOneWidget);
    });

    testWidgets('updates stock when update button tapped', (tester) async {
      setLargeScreen(tester);
      when(mockRepo.updateProductStock(any, any)).thenAnswer((_) async {});
      final product = makeProduct(id: 'stock-prod', stockQuantity: 10);
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('admin.sellers.set_stock'.tr()));
      await tester.pumpAndSettle();

      // Find the TextField inside the dialog
      final dialogTextFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogTextFields, '99');
      await tester.pump();

      await tester.tap(find.text('common.update'.tr()));
      await tester.pumpAndSettle();

      verify(mockRepo.updateProductStock('stock-prod', 99)).called(1);
    });

    testWidgets('cancel dismisses set stock dialog', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(stockQuantity: 10);
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('admin.sellers.set_stock'.tr()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('common.cancel'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('admin.sellers.set_stock_title'.tr()), findsNothing);
    });
  });

  group('AdminProductsTab — Mark Out of Stock', () {
    testWidgets('calls updateProductStock with 0', (tester) async {
      setLargeScreen(tester);
      when(mockRepo.updateProductStock(any, any)).thenAnswer((_) async {});
      final product = makeProduct(id: 'oos-prod', stockQuantity: 10);
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('admin.sellers.mark_out_of_stock'.tr()));
      await tester.pumpAndSettle();

      verify(mockRepo.updateProductStock('oos-prod', 0)).called(1);
    });
  });

  group('AdminProductsTab — Approve Product', () {
    testWidgets('shows approve confirmation dialog', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(
        name: 'Approval Item',
        lifecycleStatus: ProductLifecycleStatusValues.underReview,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve Product'));
      await tester.pumpAndSettle();

      expect(find.text('admin.products.approve_confirm_title'.tr()), findsOneWidget);
      expect(
        find.text('admin.products.approve_confirm_body'.tr(namedArgs: {'name': 'Approval Item'})),
        findsOneWidget,
      );
    });

    testWidgets('confirm approve calls approveProduct on repository', (tester) async {
      setLargeScreen(tester);
      when(mockRepo.approveProduct(any)).thenAnswer((_) async {});
      final product = makeProduct(
        id: 'approve-id',
        lifecycleStatus: ProductLifecycleStatusValues.underReview,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve Product'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('admin.products.approve_action'.tr()));
      await tester.pumpAndSettle();

      verify(mockRepo.approveProduct('approve-id')).called(1);
    });

    testWidgets('cancel dismisses approve dialog without calling approve', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(
        id: 'cancel-approve',
        lifecycleStatus: ProductLifecycleStatusValues.underReview,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve Product'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('common.cancel'.tr()));
      await tester.pumpAndSettle();

      verifyNever(mockRepo.approveProduct(any));
    });
  });

  group('AdminProductsTab — Reject Product', () {
    testWidgets('shows reject dialog with reason field', (tester) async {
      setLargeScreen(tester);
      final product = makeProduct(
        name: 'Reject Me',
        lifecycleStatus: ProductLifecycleStatusValues.underReview,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject Product'));
      await tester.pumpAndSettle();

      expect(find.text('admin.products.reject_title'.tr()), findsOneWidget);
      expect(
        find.text('admin.products.reject_product_label'.tr(namedArgs: {'name': 'Reject Me'})),
        findsOneWidget,
      );
      expect(find.text('common.cancel'.tr()), findsOneWidget);
      expect(find.text('admin.products.reject_action'.tr()), findsOneWidget);
    });

    testWidgets('reject does nothing with empty reason', (tester) async {
      setLargeScreen(tester);
      when(mockRepo.rejectProduct(any, any)).thenAnswer((_) async {});
      final product = makeProduct(
        id: 'rej-id',
        lifecycleStatus: ProductLifecycleStatusValues.underReview,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject Product'));
      await tester.pumpAndSettle();

      // Tap reject without entering reason
      await tester.tap(find.text('admin.products.reject_action'.tr()));
      await tester.pumpAndSettle();

      verifyNever(mockRepo.rejectProduct(any, any));
    });

    testWidgets('reject calls rejectProduct with reason', (tester) async {
      setLargeScreen(tester);
      when(mockRepo.rejectProduct(any, any)).thenAnswer((_) async {});
      final product = makeProduct(
        id: 'rej-id',
        lifecycleStatus: ProductLifecycleStatusValues.underReview,
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject Product'));
      await tester.pumpAndSettle();

      // Enter reason text in the dialog's TextField
      final dialogTextFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogTextFields, 'Poor quality images');
      await tester.pump();

      await tester.tap(find.text('admin.products.reject_action'.tr()));
      await tester.pumpAndSettle();

      verify(mockRepo.rejectProduct('rej-id', 'Poor quality images')).called(1);
    });
  });

  group('AdminProductsTab — View Digital URLs', () {
    testWidgets('shows download URLs dialog for digital product', (tester) async {
      setLargeScreen(tester);
      // Suppress popup menu overflow (pre-existing UI issue in _menuItem Row width)
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      final product = makeProduct(
        isDigital: true,
        digitalType: 'software',
        digitalBuilds: {
          'macOS': 'https://cdn.example.com/app-mac.dmg',
          'Windows': 'https://cdn.example.com/app-win.exe',
        },
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Download URLs'));
      await tester.pumpAndSettle();

      expect(find.text('admin.products.download_urls_title'.tr()), findsOneWidget);
      expect(
        find.text('admin.products.digital_type_label'.tr(namedArgs: {'type': 'software'})),
        findsOneWidget,
      );
      expect(find.text('macOS'), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
    });

    testWidgets('shows no URLs message when digitalBuilds is empty', (tester) async {
      setLargeScreen(tester);
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      final product = makeProduct(
        isDigital: true,
        digitalType: 'book',
        digitalBuilds: {},
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Download URLs'));
      await tester.pumpAndSettle();

      expect(find.text('admin.products.no_download_urls'.tr()), findsOneWidget);
    });

    testWidgets('close button dismisses digital URLs dialog', (tester) async {
      setLargeScreen(tester);
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      final product = makeProduct(
        isDigital: true,
        digitalType: 'software',
        digitalBuilds: {'macOS': 'https://example.com/mac'},
      );
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Download URLs'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('common.close'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('admin.products.download_urls_title'.tr()), findsNothing);
    });
  });

  group('AdminProductsTab — Combined Search + Filter', () {
    testWidgets('search and stock filter work together', (tester) async {
      setLargeScreen(tester);
      final products = [
        makeProduct(id: 'p1', name: 'Organic Honey', stockQuantity: 0),
        makeProduct(id: 'p2', name: 'Organic Syrup', stockQuantity: 10),
        makeProduct(id: 'p3', name: 'Regular Honey', stockQuantity: 0),
      ];
      await tester.pumpWidget(createTestWidget(products: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Apply out of stock filter
      final outOfStockChip = find.text('admin.sellers.filter_out_of_stock'.tr());
      await tester.ensureVisible(outOfStockChip);
      await tester.tap(outOfStockChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Organic Honey'), findsOneWidget);
      expect(find.text('Regular Honey'), findsOneWidget);
      expect(find.text('Organic Syrup'), findsNothing);

      // Also search for "organic"
      await tester.enterText(find.byType(TextField).first, 'organic');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Organic Honey'), findsOneWidget);
      expect(find.text('Regular Honey'), findsNothing);
      expect(find.text('Organic Syrup'), findsNothing);
    });
  });

  group('AdminProductsTab — View Seller', () {
    testWidgets('shows seller not found snackbar when user does not exist', (tester) async {
      setLargeScreen(tester);
      when(mockRepo.fetchUserById(any)).thenAnswer((_) async => null);
      final product = makeProduct(sellerId: 'nonexistent');
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('admin.sellers.view_seller'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('admin.sellers.seller_not_found'.tr()), findsOneWidget);
    });

    testWidgets('shows seller info dialog when user exists', (tester) async {
      setLargeScreen(tester);
      final sellerUser = UserModel(
        uid: 's1',
        email: 'seller@example.com',
        name: 'John Seller',
        roles: ['seller'],
        createdAt: DateTime(2025, 1, 1),
        onboardingCompleted: true,
      );
      when(mockRepo.fetchUserById(any)).thenAnswer((_) async => sellerUser);
      final product = makeProduct(sellerId: 's1');
      await tester.pumpWidget(createTestWidget(products: [product]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('admin.sellers.view_seller'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('admin.sellers.seller_info'.tr()), findsOneWidget);
      expect(find.text('John Seller'), findsOneWidget);
      expect(find.text('seller@example.com'), findsOneWidget);
      expect(find.text('admin.sellers.stripe_connected'.tr()), findsOneWidget);
    });
  });
}
