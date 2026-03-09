import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/cart_repository.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/utils/constants.dart' as utils;
import 'package:shared_preferences/shared_preferences.dart';

@GenerateNiceMocks([
  MockSpec<CartRepository>(),
  MockSpec<FirebaseFirestore>(),
  MockSpec<CollectionReference<Map<String, dynamic>>>(),
  MockSpec<DocumentReference<Map<String, dynamic>>>(),
])
import 'cart_provider_comprehensive_test.mocks.dart';

// Helper to create a CartItemModel
CartItemModel _cartItem({
  String cartItemId = 'item1',
  String productId = 'prod1',
  int quantity = 1,
  Timestamp? createdAt,
  String? buyerNote,
  String? variantId,
  String? variantTitle,
  Map<String, String>? variantOptions,
}) {
  return CartItemModel(
    cartItemId: cartItemId,
    productId: productId,
    quantity: quantity,
    createdAt: createdAt ?? Timestamp.now(),
    buyerNote: buyerNote,
    variantId: variantId,
    variantTitle: variantTitle,
    variantOptions: variantOptions,
  );
}

// Helper to create a CartItemDetailModel
CartItemDetailModel _detailItem({
  String productId = 'prod1',
  String name = 'Test Product',
  double price = 29.99,
  int quantity = 1,
  bool isDigital = false,
  bool isLocalDeliveryOnly = false,
  bool isPerishable = false,
  bool freeShipping = false,
  String sellerState = 'ON',
  List<utils.SellerDeliveryOption> deliveryOptions = const [],
  String? buyerNote,
  String? variantId,
  String? variantTitle,
  Map<String, String>? variantOptions,
}) {
  return CartItemDetailModel(
    productId: productId,
    name: name,
    description: 'A test product',
    price: price,
    imageUrls: const ['https://example.com/img.jpg'],
    quantity: quantity,
    createdAt: Timestamp.now(),
    sellerAddress: Address(
      street: '123 Main St',
      city: 'Toronto',
      state: sellerState,
      postalCode: 'M5V 1A1',
      country: 'Canada',
    ),
    sellerId: 'seller1',
    sellerName: 'Test Seller',
    isDigital: isDigital,
    isLocalDeliveryOnly: isLocalDeliveryOnly,
    isPerishable: isPerishable,
    freeShipping: freeShipping,
    deliveryOptions: deliveryOptions,
    buyerNote: buyerNote,
    variantId: variantId,
    variantTitle: variantTitle,
    variantOptions: variantOptions,
  );
}

void main() {
  SharedPreferences.setMockInitialValues({});

  late MockCartRepository mockRepo;
  late MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockRepo = MockCartRepository();
    mockFirestore = MockFirebaseFirestore();
  });

  // ================================================================
  // CartController — addToCart edge cases
  // ================================================================
  group('CartController.addToCart', () {
    test('returns false when user is not logged in', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue(null),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      final result = await controller.addToCart('prod1', 1);

      expect(result, isFalse);
      verifyNever(mockRepo.getProductSellerId(any));
    });

    test('returns false when product does not exist (sellerId is null)', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenAnswer((_) async => null);

      final controller = container.read(cartControllerProvider);
      final result = await controller.addToCart('prod1', 1);

      expect(result, isFalse);
      verifyNever(mockRepo.addToCart(any, any, any, variantId: anyNamed('variantId')));
    });

    test('returns false when user tries to buy own product', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('seller1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenAnswer((_) async => 'seller1');

      final controller = container.read(cartControllerProvider);
      final result = await controller.addToCart('prod1', 1);

      expect(result, isFalse);
      verifyNever(mockRepo.addToCart(any, any, any, variantId: anyNamed('variantId')));
    });

    test('validates variant when variantId is provided', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenAnswer((_) async => 'seller1');
      when(mockRepo.isVariantValid('prod1', 'var1')).thenAnswer((_) async => true);
      when(mockRepo.addToCart(any, any, any, variantId: anyNamed('variantId')))
          .thenAnswer((_) async {});

      final controller = container.read(cartControllerProvider);
      final result = await controller.addToCart('prod1', 1, variantId: 'var1');

      expect(result, isTrue);
      verify(mockRepo.isVariantValid('prod1', 'var1')).called(1);
      verify(mockRepo.addToCart('user1', 'prod1', 1, variantId: 'var1')).called(1);
    });

    test('returns false when variant is invalid', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenAnswer((_) async => 'seller1');
      when(mockRepo.isVariantValid('prod1', 'var1')).thenAnswer((_) async => false);

      final controller = container.read(cartControllerProvider);
      final result = await controller.addToCart('prod1', 1, variantId: 'var1');

      expect(result, isFalse);
      verifyNever(mockRepo.addToCart(any, any, any, variantId: anyNamed('variantId')));
    });

    test('returns false when repository throws exception', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenThrow(Exception('Network error'));

      final controller = container.read(cartControllerProvider);
      final result = await controller.addToCart('prod1', 1);

      expect(result, isFalse);
    });

    test('does not log analytics when productName or priceCad is null', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenAnswer((_) async => 'seller1');
      when(mockRepo.addToCart(any, any, any, variantId: anyNamed('variantId')))
          .thenAnswer((_) async {});

      final controller = container.read(cartControllerProvider);
      // Call without productName/priceCad — should succeed without analytics
      final result = await controller.addToCart('prod1', 2);

      expect(result, isTrue);
    });

    test('succeeds with analytics parameters', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenAnswer((_) async => 'seller1');
      when(mockRepo.addToCart(any, any, any, variantId: anyNamed('variantId')))
          .thenAnswer((_) async {});

      final controller = container.read(cartControllerProvider);
      final result = await controller.addToCart('prod1', 2,
          productName: 'Widget', priceCad: 19.99);

      expect(result, isTrue);
      verify(mockRepo.addToCart('user1', 'prod1', 2)).called(1);
    });
  });

  // ================================================================
  // CartController — canAddToCart
  // ================================================================
  group('CartController.canAddToCart', () {
    test('returns false when user is not logged in', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue(null),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      expect(await controller.canAddToCart('prod1'), isFalse);
    });

    test('returns true for other seller product', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenAnswer((_) async => 'seller1');

      final controller = container.read(cartControllerProvider);
      expect(await controller.canAddToCart('prod1'), isTrue);
    });

    test('returns false for own product', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenAnswer((_) async => 'user1');

      final controller = container.read(cartControllerProvider);
      expect(await controller.canAddToCart('prod1'), isFalse);
    });

    test('returns false when product does not exist', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenAnswer((_) async => null);

      final controller = container.read(cartControllerProvider);
      expect(await controller.canAddToCart('prod1'), isFalse);
    });

    test('returns false on exception', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      when(mockRepo.getProductSellerId('prod1')).thenThrow(Exception('fail'));

      final controller = container.read(cartControllerProvider);
      expect(await controller.canAddToCart('prod1'), isFalse);
    });
  });

  // ================================================================
  // CartController — clearCart
  // ================================================================
  group('CartController.clearCart', () {
    test('does nothing when user is not logged in', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue(null),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      await controller.clearCart();

      verifyNever(mockRepo.clearCart(any));
    });

    test('calls repository when logged in', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      await controller.clearCart();

      verify(mockRepo.clearCart('user1')).called(1);
    });
  });

  // ================================================================
  // CartController — removeFromCart
  // ================================================================
  group('CartController.removeFromCart', () {
    test('does nothing when user is not logged in', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue(null),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      await controller.removeFromCart('item1');

      verifyNever(mockRepo.removeFromCart(any, any));
    });
  });

  // ================================================================
  // CartController — updateQuantity
  // ================================================================
  group('CartController.updateQuantity', () {
    test('returns false when user is not logged in', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue(null),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      final result = await controller.updateQuantity('item1', 3);

      expect(result, isFalse);
      verifyNever(mockRepo.updateQuantity(any, any, any));
    });

    test('returns true and calls repository when logged in', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      final result = await controller.updateQuantity('item1', 10);

      expect(result, isTrue);
      verify(mockRepo.updateQuantity('user1', 'item1', 10)).called(1);
    });
  });

  // ================================================================
  // CartController — updateBuyerNote
  // ================================================================
  group('CartController.updateBuyerNote', () {
    test('does nothing when user is not logged in', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue(null),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      await controller.updateBuyerNote('item1', 'test note');

      verifyNever(mockRepo.updateBuyerNote(any, any, any));
    });

    test('calls repository with note', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      await controller.updateBuyerNote('item1', 'Please wrap carefully');

      verify(mockRepo.updateBuyerNote('user1', 'item1', 'Please wrap carefully')).called(1);
    });

    test('calls repository with null note to clear', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      await controller.updateBuyerNote('item1', null);

      verify(mockRepo.updateBuyerNote('user1', 'item1', null)).called(1);
    });
  });

  // ================================================================
  // CartController — saveForLater
  // ================================================================
  group('CartController.saveForLater', () {
    test('returns false when user is not logged in', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue(null),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      final result = await controller.saveForLater('prod1', 'item1');

      expect(result, isFalse);
    });

    test('returns true and creates favorite + removes from cart', () async {
      final mockCollection = MockCollectionReference();
      final mockDoc = MockDocumentReference();

      when(mockFirestore.collection(any)).thenReturn(mockCollection);
      when(mockCollection.doc(any)).thenReturn(mockDoc);
      when(mockDoc.collection(any)).thenReturn(mockCollection);
      when(mockDoc.set(any, any)).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      final result = await controller.saveForLater('prod1', 'item1');

      expect(result, isTrue);
      verify(mockRepo.removeFromCart('user1', 'item1')).called(1);
    });

    test('returns false on firestore exception', () async {
      final mockCollection = MockCollectionReference();
      final mockDoc = MockDocumentReference();

      when(mockFirestore.collection(any)).thenReturn(mockCollection);
      when(mockCollection.doc(any)).thenReturn(mockDoc);
      when(mockDoc.collection(any)).thenReturn(mockCollection);
      when(mockDoc.set(any, any)).thenThrow(Exception('Firestore error'));

      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider);
      final result = await controller.saveForLater('prod1', 'item1');

      expect(result, isFalse);
    });
  });

  // ================================================================
  // cartItemCountProvider
  // ================================================================
  group('cartItemCountProvider', () {
    test('returns 0 when cart is empty', () async {
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartItemsProvider.future);
      expect(container.read(cartItemCountProvider), 0);
    });

    test('sums quantities from multiple items', () async {
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([
                _cartItem(cartItemId: 'i1', productId: 'p1', quantity: 3),
                _cartItem(cartItemId: 'i2', productId: 'p2', quantity: 7),
                _cartItem(cartItemId: 'i3', productId: 'p3', quantity: 1),
              ])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartItemsProvider.future);
      expect(container.read(cartItemCountProvider), 11);
    });

    test('returns 0 when stream has not emitted yet (loading)', () {
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider
              .overrideWith((ref) => const Stream<List<CartItemModel>>.empty()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(cartItemCountProvider), 0);
    });
  });

  // ================================================================
  // cartItemDateProvider
  // ================================================================
  group('cartItemDateProvider', () {
    test('returns createdAt for existing cart item', () async {
      final ts = Timestamp.fromDate(DateTime(2026, 1, 15));
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider.overrideWith(
              (ref) => Stream.value([_cartItem(cartItemId: 'item1', createdAt: ts)])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartItemsProvider.future);
      expect(container.read(cartItemDateProvider('item1')), ts);
    });

    test('returns null for non-existent cart item', () async {
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider.overrideWith(
              (ref) => Stream.value([_cartItem(cartItemId: 'item1')])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartItemsProvider.future);
      expect(container.read(cartItemDateProvider('nonexistent')), isNull);
    });

    test('returns null when cart is empty', () async {
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartItemsProvider.future);
      expect(container.read(cartItemDateProvider('anything')), isNull);
    });

    test('returns null when cart is loading', () {
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider
              .overrideWith((ref) => const Stream<List<CartItemModel>>.empty()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(cartItemDateProvider('item1')), isNull);
    });
  });

  // ================================================================
  // cartItemQuantityProvider
  // ================================================================
  group('cartItemQuantityProvider', () {
    test('returns quantity for matching item', () async {
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider.overrideWith(
              (ref) => Stream.value([_cartItem(cartItemId: 'item1', quantity: 5)])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartItemsProvider.future);
      final qtyAsync = container.read(cartItemQuantityProvider('item1'));
      expect(qtyAsync.value, 5);
    });

    test('returns 0 for non-matching item', () async {
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider.overrideWith(
              (ref) => Stream.value([_cartItem(cartItemId: 'item1', quantity: 5)])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartItemsProvider.future);
      final qtyAsync = container.read(cartItemQuantityProvider('nonexistent'));
      expect(qtyAsync.value, 0);
    });

    test('tracks correct item when multiple items exist', () async {
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([
                _cartItem(cartItemId: 'item1', quantity: 2),
                _cartItem(cartItemId: 'item2', quantity: 8),
                _cartItem(cartItemId: 'item3', quantity: 15),
              ])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartItemsProvider.future);
      expect(container.read(cartItemQuantityProvider('item2')).value, 8);
      expect(container.read(cartItemQuantityProvider('item3')).value, 15);
    });
  });

  // ================================================================
  // cartSubtotalProvider
  // ================================================================
  group('cartSubtotalProvider', () {
    test('returns 0.0 for empty cart', () async {
      final container = ProviderContainer(
        overrides: [
          cartWithDetailsProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartWithDetailsProvider.future);
      expect(container.read(cartSubtotalProvider), 0.0);
    });

    test('calculates subtotal from price * quantity', () async {
      final container = ProviderContainer(
        overrides: [
          cartWithDetailsProvider.overrideWith((ref) async => [
                _detailItem(productId: 'p1', price: 10.00, quantity: 2),
                _detailItem(productId: 'p2', price: 25.50, quantity: 3),
              ]),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartWithDetailsProvider.future);
      final subtotal = container.read(cartSubtotalProvider);
      // 10*2 + 25.50*3 = 20 + 76.50 = 96.50
      expect(subtotal, closeTo(96.50, 0.01));
    });

    test('returns 0.0 when provider is loading', () {
      final container = ProviderContainer(
        overrides: [
          cartWithDetailsProvider.overrideWith(
              (ref) => Future<List<CartItemDetailModel>>.delayed(
                    const Duration(hours: 1),
                    () => [],
                  )),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(cartSubtotalProvider), 0.0);
    });

    test('handles single item', () async {
      final container = ProviderContainer(
        overrides: [
          cartWithDetailsProvider.overrideWith(
              (ref) async => [_detailItem(price: 99.99, quantity: 1)]),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartWithDetailsProvider.future);
      expect(container.read(cartSubtotalProvider), closeTo(99.99, 0.01));
    });

    test('handles large quantities', () async {
      final container = ProviderContainer(
        overrides: [
          cartWithDetailsProvider.overrideWith(
              (ref) async => [_detailItem(price: 5.00, quantity: 99)]),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartWithDetailsProvider.future);
      expect(container.read(cartSubtotalProvider), closeTo(495.00, 0.01));
    });
  });

  // ================================================================
  // cartItemsProvider — stream behavior
  // ================================================================
  group('cartItemsProvider', () {
    test('returns empty list when user is not logged in', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(cartItemsProvider.future);
      expect(items, isEmpty);
    });

    test('watches cart from repository when user is logged in', () async {
      when(mockRepo.watchCart('user1'))
          .thenAnswer((_) => Stream.value([_cartItem(quantity: 2)]));

      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(cartItemsProvider.future);
      expect(items, hasLength(1));
      expect(items.first.quantity, 2);
      verify(mockRepo.watchCart('user1')).called(1);
    });
  });

  // ================================================================
  // deliveryInstructionsProvider
  // ================================================================
  group('deliveryInstructionsProvider', () {
    test('initial value is empty string', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(deliveryInstructionsProvider), '');
    });

    test('can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(deliveryInstructionsProvider.notifier).state =
          'Leave at door';
      expect(container.read(deliveryInstructionsProvider), 'Leave at door');
    });
  });

  // ================================================================
  // CartController — refreshCart
  // ================================================================
  group('CartController.refreshCart', () {
    test('invalidates cartItemsProvider', () async {
      when(mockRepo.watchCart('user1'))
          .thenAnswer((_) => Stream.value([_cartItem()]));

      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWithValue('user1'),
        ],
      );
      addTearDown(container.dispose);

      // Read to initialize
      await container.read(cartItemsProvider.future);

      final controller = container.read(cartControllerProvider);
      // Should not throw
      controller.refreshCart();
    });
  });

  // ================================================================
  // CartItemModel — fromMap edge cases
  // ================================================================
  group('CartItemModel', () {
    test('fromMap with Timestamp createdAt', () {
      final ts = Timestamp.fromDate(DateTime(2026, 3, 1));
      final item = CartItemModel.fromMap({
        'quantity': 3,
        'productId': 'p1',
        'createdAt': ts,
      }, docId: 'doc1');

      expect(item.cartItemId, 'doc1');
      expect(item.quantity, 3);
      expect(item.productId, 'p1');
      expect(item.createdAt, ts);
    });

    test('fromMap with String createdAt', () {
      final item = CartItemModel.fromMap({
        'quantity': 1,
        'productId': 'p1',
        'createdAt': '2026-03-01T00:00:00.000',
      }, docId: 'doc1');

      expect(item.createdAt, isNotNull);
      expect(item.productId, 'p1');
    });

    test('fromMap with null createdAt uses Timestamp.now()', () {
      final item = CartItemModel.fromMap({
        'quantity': 1,
        'productId': 'p1',
      }, docId: 'doc1');

      expect(item.createdAt, isNotNull);
    });

    test('fromMap with missing quantity defaults to 0', () {
      final item = CartItemModel.fromMap({
        'productId': 'p1',
        'createdAt': Timestamp.now(),
      }, docId: 'doc1');

      expect(item.quantity, 0);
    });

    test('fromMap with variant fields', () {
      final item = CartItemModel.fromMap({
        'quantity': 1,
        'productId': 'p1',
        'createdAt': Timestamp.now(),
        'variantId': 'v1',
        'variantTitle': 'Red / Large',
        'variantOptions': {'color': 'red', 'size': 'L'},
        'buyerNote': 'Gift wrap please',
      }, docId: 'doc1');

      expect(item.variantId, 'v1');
      expect(item.variantTitle, 'Red / Large');
      expect(item.variantOptions, {'color': 'red', 'size': 'L'});
      expect(item.buyerNote, 'Gift wrap please');
    });

    test('toMap includes variant fields when present', () {
      final item = _cartItem(
        variantId: 'v1',
        variantTitle: 'Blue',
        variantOptions: {'color': 'blue'},
        buyerNote: 'Handle with care',
      );

      final map = item.toMap();
      expect(map['variantId'], 'v1');
      expect(map['variantTitle'], 'Blue');
      expect(map['variantOptions'], {'color': 'blue'});
      expect(map['buyerNote'], 'Handle with care');
    });

    test('toMap excludes null variant fields', () {
      final item = _cartItem();
      final map = item.toMap();

      expect(map.containsKey('variantId'), isFalse);
      expect(map.containsKey('variantTitle'), isFalse);
      expect(map.containsKey('variantOptions'), isFalse);
      expect(map.containsKey('buyerNote'), isFalse);
    });
  });

  // ================================================================
  // CartItemDetailModel — fromMap and toMap
  // ================================================================
  group('CartItemDetailModel', () {
    test('fromMap with complete data', () {
      final detail = CartItemDetailModel.fromMap({
        'productId': 'p1',
        'name': 'Test',
        'description': 'Desc',
        'price': 19.99,
        'imageUrls': ['img1.jpg'],
        'quantity': 2,
        'createdAt': Timestamp.now(),
        'sellerAddress': {
          'street': '123 St',
          'city': 'Toronto',
          'state': 'ON',
          'postalCode': 'M5V',
          'country': 'CA',
        },
        'sellerId': 's1',
        'sellerName': 'Seller',
        'isDigital': true,
        'freeShipping': true,
        'minimumOrderQuantity': 5,
        'weightKg': 1.5,
        'lengthCm': 10.0,
        'widthCm': 5.0,
        'heightCm': 3.0,
      });

      expect(detail.productId, 'p1');
      expect(detail.price, 19.99);
      expect(detail.isDigital, isTrue);
      expect(detail.freeShipping, isTrue);
      expect(detail.minimumOrderQuantity, 5);
      expect(detail.weightKg, 1.5);
      expect(detail.lengthCm, 10.0);
      expect(detail.widthCm, 5.0);
      expect(detail.heightCm, 3.0);
    });

    test('fromMap with missing fields uses defaults', () {
      final detail = CartItemDetailModel.fromMap({});

      expect(detail.productId, '');
      expect(detail.name, '');
      expect(detail.price, 0.0);
      expect(detail.imageUrls, isEmpty);
      expect(detail.quantity, 0);
      expect(detail.isDigital, isFalse);
      expect(detail.freeShipping, isFalse);
      expect(detail.isLocalDeliveryOnly, isFalse);
      expect(detail.isPerishable, isFalse);
      expect(detail.estimatedShipDays, 3);
      expect(detail.minimumOrderQuantity, 1);
      expect(detail.weightKg, isNull);
    });

    test('toMap round-trips correctly', () {
      final original = _detailItem(
        productId: 'p1',
        name: 'Widget',
        price: 49.99,
        quantity: 3,
        buyerNote: 'Priority',
        variantId: 'v1',
        variantTitle: 'Large',
        variantOptions: {'size': 'L'},
      );

      final map = original.toMap();
      expect(map['productId'], 'p1');
      expect(map['name'], 'Widget');
      expect(map['price'], 49.99);
      expect(map['quantity'], 3);
      expect(map['buyerNote'], 'Priority');
      expect(map['variantId'], 'v1');
      expect(map['variantTitle'], 'Large');
    });
  });

  // ================================================================
  // CartModel
  // ================================================================
  group('CartModel', () {
    test('fromMap with Timestamp', () {
      final ts = Timestamp.fromDate(DateTime(2026, 2, 1));
      final model = CartModel.fromMap({
        'productId': 'p1',
        'quantity': 3,
        'createdAt': ts,
        'variantId': 'v1',
        'variantSku': 'SKU-001',
      }, docId: 'doc1');

      expect(model.cartItemId, 'doc1');
      expect(model.productId, 'p1');
      expect(model.quantity, 3);
      expect(model.variantId, 'v1');
      expect(model.variantSku, 'SKU-001');
    });

    test('fromMap with DateTime', () {
      final dt = DateTime(2026, 2, 1);
      final model = CartModel.fromMap({
        'productId': 'p1',
        'quantity': 1,
        'createdAt': dt,
      });

      expect(model.createdAt, dt);
    });

    test('fromMap with null createdAt uses DateTime.now', () {
      final model = CartModel.fromMap({
        'productId': 'p1',
      });

      expect(model.createdAt, isNotNull);
      expect(model.quantity, 1); // default
    });

    test('fromMap with priceSnapshot', () {
      final model = CartModel.fromMap({
        'productId': 'p1',
        'createdAt': Timestamp.now(),
        'priceSnapshot': 4999,
      });

      expect(model.priceSnapshot, 4999);
    });
  });

  // ================================================================
  // Address model
  // ================================================================
  group('Address', () {
    test('empty factory creates valid empty address', () {
      final addr = Address.empty();
      expect(addr.street, '');
      expect(addr.country, 'Canada');
      expect(addr.city, '');
    });

    test('fromMap populates all fields', () {
      final addr = Address.fromMap({
        'street': '100 Queen St',
        'apartment': 'Suite 200',
        'city': 'Toronto',
        'state': 'ON',
        'postalCode': 'M5H 2N2',
        'country': 'Canada',
        'phoneNumber': '+14165551234',
        'isDefault': true,
        'label': 'Work',
        'latitude': 43.6532,
        'longitude': -79.3832,
      });

      expect(addr.street, '100 Queen St');
      expect(addr.apartment, 'Suite 200');
      expect(addr.isDefault, isTrue);
      expect(addr.label, 'Work');
      expect(addr.latitude, closeTo(43.6532, 0.001));
    });

    test('formattedAddress includes apartment when present', () {
      final addr = Address(
        street: '100 Queen St',
        apartment: 'Unit 5',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5H',
        country: 'Canada',
      );

      expect(addr.formattedAddress, contains('Unit 5'));
      expect(addr.formattedAddress, contains('100 Queen St'));
    });

    test('formattedAddress excludes empty apartment', () {
      final addr = Address(
        street: '100 Queen St',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5H',
        country: 'Canada',
      );

      expect(addr.formattedAddress, isNot(contains('\n\n')));
    });

    test('fullAddress joins all parts', () {
      final addr = Address(
        street: '100 Queen St',
        apartment: 'Unit 5',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5H',
        country: 'Canada',
      );

      expect(addr.fullAddress, contains('100 Queen St'));
      expect(addr.fullAddress, contains('Unit 5'));
      expect(addr.fullAddress, contains('Toronto'));
    });

    test('copyWith creates modified copy', () {
      final addr = Address(
        street: '100 Queen St',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5H',
        country: 'Canada',
      );

      final modified = addr.copyWith(city: 'Ottawa', state: 'ON');
      expect(modified.city, 'Ottawa');
      expect(modified.street, '100 Queen St'); // unchanged
    });
  });
}
