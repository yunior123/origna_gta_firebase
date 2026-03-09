import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

@GenerateNiceMocks([MockSpec<ProductRepository>()])
import 'products_provider_test.mocks.dart';

void main() {
  late MockProductRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockProductRepository();
    container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(mockRepo),
        userIdProvider.overrideWith((ref) => 'test_user'),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Favorites Providers', () {
    test('favoritesProvider returns stream from repository', () async {
      when(mockRepo.watchFavorites('test_user')).thenAnswer((_) => Stream.value({'p1', 'p2'}));
      
      final result = await container.read(favoritesProvider.future);
      expect(result, {'p1', 'p2'});
    });

    test('favoritedProductsProvider fetches in chunks', () async {
      final ids = List.generate(35, (i) => 'id_$i').toSet();
      when(mockRepo.watchFavorites('test_user')).thenAnswer((_) => Stream.value(ids));
      
      final chunk1 = List.generate(30, (i) => 'id_$i');
      final chunk2 = List.generate(5, (i) => 'id_${i + 30}');
      
      when(mockRepo.fetchProductsByIds(chunk1)).thenAnswer((_) async => List.generate(30, (i) => Product(productId: 'id_$i', name: 'P$i', price: 10, description: '', imageUrls: [], sellerId: 's', categoryId: 1, stockQuantity: 1, createdAt: DateTime.now())));
      when(mockRepo.fetchProductsByIds(chunk2)).thenAnswer((_) async => List.generate(5, (i) => Product(productId: 'id_${i + 30}', name: 'P${i + 30}', price: 10, description: '', imageUrls: [], sellerId: 's', categoryId: 1, stockQuantity: 1, createdAt: DateTime.now())));

      final sub = container.listen(favoritedProductsProvider, (prev, next) {});
      final result = await container.read(favoritedProductsProvider.future);
      expect(result.length, 35);
      verify(mockRepo.fetchProductsByIds(any)).called(2);
      sub.close();
    });
  });

  group('Filtered Products Providers', () {
    test('filteredProductsProvider reacts to category and search', () async {
      when(mockRepo.fetchProducts(
        searchQuery: anyNamed('searchQuery'),
        categoryId: anyNamed('categoryId'),
        subcategory: anyNamed('subcategory'),
        lastDocument: anyNamed('lastDocument'),
        pageSize: anyNamed('pageSize'),
        sortOption: anyNamed('sortOption'),
        minPriceCents: anyNamed('minPriceCents'),
        maxPriceCents: anyNamed('maxPriceCents'),
      )).thenAnswer((_) async => ProductQueryResult(products: [], lastDocument: null, hasMore: false));

      final sub = container.listen(filteredProductsProvider, (prev, next) {});
      await container.read(filteredProductsProvider.future);
      
      // Update category
      container.read(selectedCategoryProvider.notifier).state = 1;
      await container.read(filteredProductsProvider.future);

      // Update search
      container.read(searchQueryProvider.notifier).state = 'honey';
      await container.read(filteredProductsProvider.future);
      
      verify(mockRepo.fetchProducts(
        searchQuery: anyNamed('searchQuery'),
        categoryId: anyNamed('categoryId'),
        pageSize: anyNamed('pageSize'),
        subcategory: anyNamed('subcategory'),
        lastDocument: anyNamed('lastDocument'),
        sortOption: anyNamed('sortOption'),
        minPriceCents: anyNamed('minPriceCents'),
        maxPriceCents: anyNamed('maxPriceCents'),
      )).called(3);
      sub.close();
    });
  });

  group('Family Providers', () {
    test('productByIdProvider fetches correctly', () async {
      when(mockRepo.fetchProductById('p1')).thenAnswer((_) async => null);
      await container.read(productByIdProvider('p1').future);
      verify(mockRepo.fetchProductById('p1')).called(1);
    });

    test('productBySlugProvider fetches correctly', () async {
      when(mockRepo.getProductBySlug('slug-1')).thenAnswer((_) async => null);
      await container.read(productBySlugProvider('slug-1').future);
      verify(mockRepo.getProductBySlug('slug-1')).called(1);
    });

    test('similarProductsProvider fetches correctly', () async {
      when(mockRepo.fetchProducts(
        categoryId: 1, 
        pageSize: 12,
        searchQuery: anyNamed('searchQuery'),
        subcategory: anyNamed('subcategory'),
        lastDocument: anyNamed('lastDocument'),
        sortOption: anyNamed('sortOption'),
        minPriceCents: anyNamed('minPriceCents'),
        maxPriceCents: anyNamed('maxPriceCents'),
      )).thenAnswer((_) async => ProductQueryResult(
        products: [
          Product(productId: 'p1', name: 'P1', price: 10, description: '', imageUrls: [], sellerId: 's', categoryId: 1, stockQuantity: 1, createdAt: DateTime.now()),
          Product(productId: 'p2', name: 'P2', price: 10, description: '', imageUrls: [], sellerId: 's', categoryId: 1, stockQuantity: 1, createdAt: DateTime.now()),
        ],
        lastDocument: null,
        hasMore: false,
      ));

      final result = await container.read(similarProductsProvider((excludeProductId: 'p1', categoryId: 1)).future);
      expect(result.length, 1);
      expect(result.first.productId, 'p2');
    });
  });

  group('FavoritesController', () {
    test('toggleFavorite calls repository', () async {
      when(mockRepo.watchFavorites('test_user')).thenAnswer((_) => Stream.value({'p1'}));
      final controller = container.read(favoritesControllerProvider);
      
      // Wait for data
      await container.read(favoritesProvider.future);
      
      // p1 is favorited, should unfavorite
      await controller.toggleFavorite('p1', productName: 'Honey');
      verify(mockRepo.toggleFavorite('test_user', 'p1')).called(1);
      
      // p2 is not favorited, should favorite
      await controller.toggleFavorite('p2', productName: 'Milk', priceCad: 5.0);
      verify(mockRepo.toggleFavorite('test_user', 'p2')).called(1);
    });
  });
}
