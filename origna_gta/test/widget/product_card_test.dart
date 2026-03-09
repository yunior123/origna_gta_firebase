import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:origna_gta/screens/product_card_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/features/qa/qa_provider.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/models/models.dart' as manual_models;
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/constants.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<CartController>(),
  MockSpec<FavoritesController>(),
  MockSpec<firebase_auth.User>(),
  MockSpec<ProductRepository>(),
])
import 'product_card_test.mocks.dart';

void main() {
  late MockCartController mockCart;
  late MockFavoritesController mockFavController;
  late MockUser mockFirebaseUser;
  late MockProductRepository mockRepo;

  setUp(() {
    mockCart = MockCartController();
    mockFavController = MockFavoritesController();
    mockFirebaseUser = MockUser();
    mockRepo = MockProductRepository();
    
    when(mockFirebaseUser.uid).thenReturn('user_123');
    
    initTestMocks();
  });

  final testProduct = Product(
    productId: 'prod_123',
    name: 'Test Product',
    description: 'Description',
    price: 99.99,
    sellerId: 'seller_123',
    imageUrls: ['https://example.com/image.jpg'],
    stockQuantity: 10,
    rating: 4.5,
    ratingCount: 20,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    isDigital: false,
    estimatedShipDays: 3,
    categoryId: 1,
  );

  final testUserModel = manual_models.UserModel(
    uid: 'user_123',
    email: 'test@example.com',
    name: 'Test User',
    roles: [UserRoles.buyer],
    createdAt: DateTime.now(),
  );

  Widget createTestWidget({
    required Product product,
    manual_models.UserModel? userModel,
    firebase_auth.User? firebaseUser,
    int? trendingRank,
  }) {
    return TestWrapper(
      overrides: [
        productRepositoryProvider.overrideWithValue(mockRepo),
        cartControllerProvider.overrideWithValue(mockCart),
        favoritesControllerProvider.overrideWithValue(mockFavController),
        currentUserProvider.overrideWithValue(firebaseUser),
        favoritesProvider.overrideWith((ref) => Stream.value({'other_prod'})),
        unansweredQaCountProvider(product.productId).overrideWith((ref) => Stream.value(0)),
      ],
      child: Scaffold(
        body: ProductCard(
          productId: product.productId,
          product: product,
          userModel: userModel,
          trendingRank: trendingRank,
        ),
      ),
    );
  }

  group('ProductCard Widget Tests', () {
    testWidgets('renders basic product info', (tester) async {
      await tester.pumpWidget(createTestWidget(product: testProduct));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('\$99.99'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('(20)'), findsOneWidget);
    });

    testWidgets('shows out of stock label', (tester) async {
      final outOfStockProduct = testProduct.copyWith(stockQuantity: 0);
      await tester.pumpWidget(createTestWidget(product: outOfStockProduct));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('product.out_of_stock_label'.tr()), findsOneWidget);
    });

    testWidgets('shows trending rank badge', (tester) async {
      await tester.pumpWidget(createTestWidget(product: testProduct, trendingRank: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('🥇 #1'), findsOneWidget);
    });

    testWidgets('shows digital type label', (tester) async {
      final digitalProduct = testProduct.copyWith(isDigital: true, digitalType: DigitalTypeValues.software);
      await tester.pumpWidget(createTestWidget(product: digitalProduct));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('product.digital_type_software'.tr()), findsOneWidget);
    });

    testWidgets('toggling favorite requires login', (tester) async {
      await tester.pumpWidget(createTestWidget(product: testProduct, firebaseUser: null));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final favBtn = find.bySemanticsLabel('btn-favorite-prod_123');
      await tester.tap(favBtn, warnIfMissed: true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('can toggle favorite when logged in', (tester) async {
      await tester.pumpWidget(createTestWidget(product: testProduct, firebaseUser: mockFirebaseUser));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final favBtn = find.bySemanticsLabel('btn-favorite-prod_123');
      await tester.tap(favBtn, warnIfMissed: true);
      
      // Pump long enough for animations and microtasks
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      
      verify(mockFavController.toggleFavorite('prod_123')).called(1);
    });

    testWidgets('can add to cart when logged in', (tester) async {
      when(mockCart.addToCart(any, any)).thenAnswer((_) async => true);
      
      await tester.pumpWidget(createTestWidget(product: testProduct, firebaseUser: mockFirebaseUser));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final addBtn = find.bySemanticsLabel('btn-add-to-cart-prod_123');
      await tester.tap(addBtn, warnIfMissed: true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(mockCart.addToCart('prod_123', 1)).called(1);
      expect(find.text('cart.added_to_cart'.tr()), findsOneWidget);
    });

    testWidgets('shows admin actions for admin user', (tester) async {
      final adminUserModel = testUserModel.copyWith(roles: [UserRoles.admin]);
      await tester.pumpWidget(createTestWidget(product: testProduct, userModel: adminUserModel));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('shows owner actions for seller owner', (tester) async {
      final ownerUserModel = testUserModel.copyWith(uid: 'seller_123');
      await tester.pumpWidget(createTestWidget(product: testProduct, userModel: ownerUserModel));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('can delete product after confirmation', (tester) async {
      final adminUserModel = testUserModel.copyWith(roles: [UserRoles.admin]);
      when(mockRepo.deleteProduct(any)).thenAnswer((_) async => Future.value());
      
      await tester.pumpWidget(createTestWidget(product: testProduct, userModel: adminUserModel));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.delete), warnIfMissed: true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('product.delete_product'.tr()), findsOneWidget);
      await tester.tap(find.text('common.delete'.tr()), warnIfMissed: true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(mockRepo.deleteProduct('prod_123')).called(1);
    });
  });
}
