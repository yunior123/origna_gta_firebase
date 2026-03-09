import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/core/repositories/cart_repository.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/models/models.dart';

@GenerateNiceMocks([
  MockSpec<CartRepository>(),
])
import 'cart_provider_test.mocks.dart';

void main() {
  late MockCartRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockCartRepository();
    container = ProviderContainer(
      overrides: [
        cartRepositoryProvider.overrideWithValue(mockRepo),
        userIdProvider.overrideWith((ref) => 'user_123'),
      ],
    );
  });

  group('CartController Tests', () {
    test('addToCart calls repository', () async {
      when(mockRepo.getProductSellerId('p1')).thenAnswer((_) async => 'seller_456');
      when(mockRepo.addToCart(any, any, any, variantId: anyNamed('variantId'))).thenAnswer((_) async => {});
      
      final controller = container.read(cartControllerProvider);
      final success = await controller.addToCart('p1', 2);
      
      expect(success, isTrue);
      verify(mockRepo.addToCart('user_123', 'p1', 2)).called(1);
    });

    test('addToCart fails if own product', () async {
      when(mockRepo.getProductSellerId('p1')).thenAnswer((_) async => 'user_123');
      
      final controller = container.read(cartControllerProvider);
      final success = await controller.addToCart('p1', 2);
      
      expect(success, isFalse);
      verifyNever(mockRepo.addToCart(any, any, any));
    });

    test('updateQuantity calls repository', () async {
      final controller = container.read(cartControllerProvider);
      await controller.updateQuantity('item_1', 5);
      
      verify(mockRepo.updateQuantity('user_123', 'item_1', 5)).called(1);
    });

    test('removeFromCart calls repository', () async {
      final controller = container.read(cartControllerProvider);
      await controller.removeFromCart('item_1');
      
      verify(mockRepo.removeFromCart('user_123', 'item_1')).called(1);
    });
  });

  group('Cart Providers Tests', () {
    test('cartItemCountProvider computes total', () async {
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider.overrideWith((ref) => Stream.value([
            CartItemModel(cartItemId: 'i1', productId: 'p1', quantity: 2, createdAt: Timestamp.now()),
            CartItemModel(cartItemId: 'i2', productId: 'p2', quantity: 3, createdAt: Timestamp.now()),
          ])),
        ],
      );
      
      // Wait for the stream to emit
      await container.read(cartItemsProvider.future);
      
      final count = container.read(cartItemCountProvider);
      expect(count, 5);
    });
  });
}
