import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/screens/home_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/features/home/home_viewmodel.dart';
import 'package:origna_gta/features/home/home_state.dart';
import 'package:origna_gta/models/models.dart' as models;
import 'package:origna_gta/models/generated/models.dart' hide User;
import 'package:origna_gta/widgets/mascot/mascot_provider.dart';
import 'package:origna_gta/widgets/mascot/moose_provider.dart';
import 'package:origna_gta/widgets/mascot/shop_mascot.dart';
import 'package:origna_gta/widgets/mascot/canadian_moose.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../test_utils.dart';

@GenerateNiceMocks([MockSpec<User>(), MockSpec<ProductRepository>()])
import 'home_screen_test.mocks.dart';

/// Helper to create a test Product instance with minimal required fields.
Product _makeProduct({
  String productId = 'prod_1',
  String name = 'Test Product',
  double price = 29.99,
  int priceCents = 2999,
  String sellerId = 'seller_1',
  int categoryId = 1,
  int stockQuantity = 10,
  bool isTrending = false,
  int trendingScore = 0,
  String? shipFromCountry,
  List<String>? shipFromCountries,
}) {
  return Product(
    productId: productId,
    name: name,
    price: price,
    priceCents: priceCents,
    description: 'A test product',
    imageUrls: const ['https://example.com/img.jpg'],
    sellerId: sellerId,
    categoryId: categoryId,
    stockQuantity: stockQuantity,
    createdAt: DateTime(2026, 1, 1),
    isTrending: isTrending,
    trendingScore: trendingScore,
    shipFromCountry: shipFromCountry,
    shipFromCountries: shipFromCountries,
  );
}

/// Shared overrides used by most tests.
List<Override> _baseOverrides({
  required MockUser mockUser,
  required FakeFirebaseFirestore fakeFirestore,
  required MockProductRepository mockProductRepo,
  required MascotController mascotController,
  required MooseController mooseController,
  User? currentUser,
  models.UserModel? userProfile,
  int cartCount = 0,
  HomeState? homeState,
}) {
  final user = currentUser ?? mockUser;
  final profile = userProfile ??
      models.UserModel(
        uid: 'test_user_123',
        name: 'Test',
        email: 'test@example.com',
        roles: const ['buyer'],
        createdAt: DateTime.now(),
      );

  return [
    currentUserProvider.overrideWithValue(user),
    userProfileProvider.overrideWith(
      (ref) => Stream.value(profile),
    ),
    firestoreProvider.overrideWithValue(fakeFirestore),
    productRepositoryProvider.overrideWithValue(mockProductRepo),
    cartItemCountProvider.overrideWithValue(cartCount),
    mascotControllerProvider.overrideWithValue(mascotController),
    mooseControllerProvider.overrideWithValue(mooseController),
    if (homeState != null)
      homeViewModelProvider.overrideWith((ref) {
        return _FakeHomeViewModel(ref, homeState);
      }),
  ];
}

/// A fake HomeViewModel that starts with a given state and does not
/// call loadProducts on construction (avoids needing Algolia/Firestore).
class _FakeHomeViewModel extends HomeViewModel {
  _FakeHomeViewModel(super.ref, HomeState initial) {
    state = initial;
  }

  @override
  Future<void> loadProducts() async {}
}

void main() {
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;
  late MockProductRepository mockProductRepo;
  late MascotController mascotController;
  late MooseController mooseController;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
    mockProductRepo = MockProductRepository();
    mascotController = MascotController();
    mooseController = MooseController();
    when(mockUser.uid).thenReturn('test_user_123');
    when(mockUser.email).thenReturn('test@example.com');

    // Default stub so fetchProducts never throws
    when(mockProductRepo.fetchProducts(
      searchQuery: anyNamed('searchQuery'),
      categoryId: anyNamed('categoryId'),
      subcategory: anyNamed('subcategory'),
      lastDocument: anyNamed('lastDocument'),
      pageSize: anyNamed('pageSize'),
      sortOption: anyNamed('sortOption'),
      minPriceCents: anyNamed('minPriceCents'),
      maxPriceCents: anyNamed('maxPriceCents'),
    )).thenAnswer((_) async =>
        ProductQueryResult(products: [], lastDocument: null, hasMore: false));

    // Default stub for fetchProductsByIds (recently viewed)
    when(mockProductRepo.fetchProductsByIds(any))
        .thenAnswer((_) async => []);
  });

  tearDown(() {
    mascotController.dispose();
    mooseController.dispose();
  });

  // --------------------------------------------------------------------------
  // Helper to set a standard mobile viewport
  // --------------------------------------------------------------------------
  void setMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetViewport(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  // --------------------------------------------------------------------------
  // 1. SMOKE / BASIC RENDERING
  // --------------------------------------------------------------------------
  group('HomeScreen - Basic Rendering', () {
    testWidgets('renders HomeScreen widget', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('shows app title "Origna GTA"', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('home_screen_title')), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('shows search field', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('home_search_field')), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('shows tagline text', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 'home.tagline' resolves to 'Marketplace' in MockAssetLoader
      expect(find.text('Marketplace'), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('shows settings button', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('home_settings_button')), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('shows cart button', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('home_cart_button')), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('shows footer with privacy and terms links', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 'home.privacy_policy' = 'Privacy Policy', 'home.terms_of_service' = 'Terms of Service'
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 2. LOADING STATE
  // --------------------------------------------------------------------------
  group('HomeScreen - Loading State', () {
    testWidgets('shows shimmer loading cards when isLoading is true',
        (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(isLoading: true, hasMore: true),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Shimmer cards should be visible during loading
      expect(find.byType(HomeScreen), findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 3. EMPTY STATE
  // --------------------------------------------------------------------------
  group('HomeScreen - Empty State', () {
    testWidgets('shows empty state when no products and not loading',
        (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(
              isLoading: false,
              hasMore: false,
              products: [],
            ),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 'home.no_products_found' = 'No products found'
      expect(find.text('No products found'), findsOneWidget);
      // 'home.try_adjusting' = 'Try adjusting filters'
      expect(find.text('Try adjusting filters'), findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 4. ERROR STATE
  // --------------------------------------------------------------------------
  group('HomeScreen - Error State', () {
    testWidgets('shows error with retry button when error and no products',
        (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(
              isLoading: false,
              hasMore: false,
              products: [],
              errorMessage: 'Network error',
            ),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 'home.error_loading_products' = 'Error loading products'
      expect(find.text('Error loading products'), findsOneWidget);
      expect(find.text('Network error'), findsOneWidget);
      // 'common.retry' = 'Retry'
      expect(find.text('Retry'), findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 5. DATA POPULATED — PRODUCT GRID
  // --------------------------------------------------------------------------
  group('HomeScreen - Product Grid', () {
    testWidgets('renders product cards when products are loaded',
        (tester) async {
      setMobileViewport(tester);

      final products = [
        _makeProduct(productId: 'p1', name: 'Widget A', price: 10.0),
        _makeProduct(productId: 'p2', name: 'Widget B', price: 20.0),
      ];

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(
              isLoading: false,
              hasMore: false,
              products: products,
            ),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('product_card_Widget A')), findsOneWidget);
      expect(find.byKey(const Key('product_card_Widget B')), findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 6. CATEGORY CHIPS
  // --------------------------------------------------------------------------
  group('HomeScreen - Category Chips', () {
    testWidgets('shows "All" category chip', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 'home.category_all' = 'All'
      expect(find.text('All'), findsWidgets);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 7. SORT & FILTER ROW
  // --------------------------------------------------------------------------
  group('HomeScreen - Sort & Filter', () {
    testWidgets('shows sort chip with default label', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 'home.sort_by' = 'Sort by'
      expect(find.text('Sort by'), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('shows price filter chip', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 'home.filter_price' = 'Price Filter'
      expect(find.text('Price Filter'), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('shows canada only chip', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 'home.canada_only' = 'Canada Only'
      expect(find.text('Canada Only'), findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 8. CART BADGE
  // --------------------------------------------------------------------------
  group('HomeScreen - Cart Badge', () {
    testWidgets('shows cart badge count when items in cart', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            cartCount: 3,
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('3'), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('does not show badge when cart is empty', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            cartCount: 0,
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // No badge count text should appear
      expect(find.text('0'), findsNothing);
      resetViewport(tester);
    });

    testWidgets('shows 99+ when cart has more than 99 items', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            cartCount: 150,
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('99+'), findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 9. ADD PRODUCT BUTTON VISIBILITY
  // --------------------------------------------------------------------------
  group('HomeScreen - Add Product Button', () {
    testWidgets('hides add product button for buyer-only users',
        (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            userProfile: models.UserModel(
              uid: 'test_user_123',
              name: 'Buyer',
              email: 'buyer@example.com',
              roles: const ['buyer'],
              createdAt: DateTime.now(),
            ),
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('home_add_product_button')), findsNothing);
      resetViewport(tester);
    });

    testWidgets('shows add product button for seller users', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            userProfile: models.UserModel(
              uid: 'test_user_123',
              name: 'Seller',
              email: 'seller@example.com',
              roles: const ['seller'],
              createdAt: DateTime.now(),
            ),
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
          find.byKey(const Key('home_add_product_button')), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('shows add product button for admin users', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            userProfile: models.UserModel(
              uid: 'test_user_123',
              name: 'Admin',
              email: 'admin@example.com',
              roles: const ['admin'],
              createdAt: DateTime.now(),
            ),
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
          find.byKey(const Key('home_add_product_button')), findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 10. UNAUTHENTICATED USER
  // --------------------------------------------------------------------------
  group('HomeScreen - Unauthenticated User', () {
    testWidgets('renders home screen for unauthenticated user',
        (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            userProfileProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            firestoreProvider.overrideWithValue(fakeFirestore),
            productRepositoryProvider.overrideWithValue(mockProductRepo),
            cartItemCountProvider.overrideWithValue(0),
            mascotControllerProvider.overrideWithValue(mascotController),
            mooseControllerProvider.overrideWithValue(mooseController),
            homeViewModelProvider.overrideWith((ref) {
              return _FakeHomeViewModel(
                ref,
                HomeState(isLoading: false, hasMore: false),
              );
            }),
          ],
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      // No add product button for unauthenticated user
      expect(find.byKey(const Key('home_add_product_button')), findsNothing);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 11. PAGINATION LOADER
  // --------------------------------------------------------------------------
  group('HomeScreen - Pagination', () {
    testWidgets('shows pagination loader when isLoadingMore', (tester) async {
      setMobileViewport(tester);

      final products = List.generate(
        4,
        (i) => _makeProduct(productId: 'p_$i', name: 'Product $i'),
      );

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(
              isLoading: false,
              isLoadingMore: true,
              hasMore: true,
              products: products,
            ),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The pagination loader should be present somewhere in the tree
      expect(find.byType(HomeScreen), findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 12. TRENDING PRODUCTS
  // --------------------------------------------------------------------------
  group('HomeScreen - Trending Products', () {
    testWidgets('renders trending products in grid', (tester) async {
      setMobileViewport(tester);

      final products = [
        _makeProduct(
          productId: 'trend1',
          name: 'Trending Item',
          isTrending: true,
          trendingScore: 100,
        ),
        _makeProduct(
          productId: 'normal1',
          name: 'Normal Item',
        ),
      ];

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(
              isLoading: false,
              hasMore: false,
              products: products,
            ),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('product_card_Trending Item')), findsOneWidget);
      expect(find.byKey(const Key('product_card_Normal Item')), findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 13. CANADA-ONLY FILTER (displayedProducts logic)
  // --------------------------------------------------------------------------
  group('HomeScreen - Canada Only Filter', () {
    testWidgets('displays all products when canadaOnly is false',
        (tester) async {
      setMobileViewport(tester);

      final products = [
        _makeProduct(
          productId: 'ca1',
          name: 'Canadian Product',
          shipFromCountry: 'CA',
        ),
        _makeProduct(
          productId: 'us1',
          name: 'US Product',
          shipFromCountry: 'US',
        ),
      ];

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(
              isLoading: false,
              hasMore: false,
              products: products,
              canadaOnly: false,
            ),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('product_card_Canadian Product')),
          findsOneWidget);
      expect(
          find.byKey(const Key('product_card_US Product')), findsOneWidget);
      resetViewport(tester);
    });

    testWidgets('filters to Canadian products when canadaOnly is true',
        (tester) async {
      setMobileViewport(tester);

      final products = [
        _makeProduct(
          productId: 'ca1',
          name: 'Canadian Product',
          shipFromCountry: 'CA',
        ),
        _makeProduct(
          productId: 'us1',
          name: 'US Product',
          shipFromCountry: 'US',
        ),
      ];

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(
              isLoading: false,
              hasMore: false,
              products: products,
              canadaOnly: true,
            ),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('product_card_Canadian Product')),
          findsOneWidget);
      // US Product should be filtered out
      expect(find.byKey(const Key('product_card_US Product')), findsNothing);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 14. SELLER/ADMIN CARD ASPECT RATIO
  // --------------------------------------------------------------------------
  group('HomeScreen - Seller/Admin Features', () {
    testWidgets('renders grid for seller with manage products capability',
        (tester) async {
      setMobileViewport(tester);

      final products = [
        _makeProduct(productId: 'sp1', name: 'Seller Product'),
      ];

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            userProfile: models.UserModel(
              uid: 'test_user_123',
              name: 'Seller',
              email: 'seller@example.com',
              roles: const ['seller'],
              createdAt: DateTime.now(),
            ),
            homeState: HomeState(
              isLoading: false,
              hasMore: false,
              products: products,
            ),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('product_card_Seller Product')),
          findsOneWidget);
      resetViewport(tester);
    });
  });

  // --------------------------------------------------------------------------
  // 15. SEARCH INTERACTION
  // --------------------------------------------------------------------------
  group('HomeScreen - Search', () {
    testWidgets('search field accepts text input', (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(
        TestWrapper(
          overrides: _baseOverrides(
            mockUser: mockUser,
            fakeFirestore: fakeFirestore,
            mockProductRepo: mockProductRepo,
            mascotController: mascotController,
            mooseController: mooseController,
            homeState: HomeState(isLoading: false, hasMore: false),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final searchField = find.byKey(const Key('home_search_field'));
      expect(searchField, findsOneWidget);

      await tester.tap(searchField);
      await tester.pump();

      await tester.enterText(searchField, 'laptop');
      await tester.pump();

      expect(find.text('laptop'), findsOneWidget);
      resetViewport(tester);
    });
  });
}
