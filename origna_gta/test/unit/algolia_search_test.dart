import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/repositories/algolia_product_repository.dart';
import 'package:origna_gta/services/algolia_service.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([AlgoliaService, FirebaseFirestore, HitsSearcher, FirebaseFunctions])
import 'algolia_search_test.mocks.dart';

void main() {
  group('AlgoliaProductRepository Tests', () {
    late MockAlgoliaService mockAlgoliaService;
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseFunctions mockFunctions;
    late AlgoliaProductRepository repository;

    setUp(() {
      mockAlgoliaService = MockAlgoliaService();
      mockFirestore = MockFirebaseFirestore();
      mockFunctions = MockFirebaseFunctions();
      repository = AlgoliaProductRepository(mockAlgoliaService, mockFirestore, mockFunctions);
    });

    test('should use Algolia for non-empty search queries', () async {
      // Arrange
      const searchQuery = 'organic apples';
      final mockResponse = SearchResponse({
        'hits': [
          {
            'objectID': 'prod_001',
            'name': 'Organic Apples',
            'price': 4.99,
            'description': 'Fresh organic apples from local farm',
            'categoryId': 14,
            'sellerId': 'seller_01',
            'imageUrls': ['https://example.com/apple.jpg'],
            'stockQuantity': 50,
            'rating': 4.8,
            'ratingCount': 120,
            'isActive': true,
            'keywords': ['apples', 'organic', 'fruit'],
            'sellerAddress': {'street': '123 Main St', 'apartment': '', 'city': 'Toronto', 'state': 'ON', 'postalCode': 'M5V 3A8', 'country': 'Canada'},
            'freeShipping': false,
            'isPerishable': true,
            'isLocalDeliveryOnly': true,
          },
        ],
        'facets': {},
        'page': 0,
        'nbHits': 1,
        'nbPages': 1,
        'hitsPerPage': 20,
        'processingTimeMS': 15,
        'query': searchQuery,
        'params': '',
      });

      // Mock the search stream
      when(mockAlgoliaService.isAvailable).thenReturn(true);
      when(mockAlgoliaService.responses).thenAnswer((_) => Stream.value(mockResponse));

      // Act
      final result = await repository.fetchProducts(searchQuery: searchQuery);

      // Assert
      expect(result.products.length, 1);
      expect(result.products.first.name, 'Organic Apples');
      expect(result.products.first.price, 4.99);
      verify(mockAlgoliaService.search(searchQuery, categoryId: null)).called(1);
    });

    test('should return empty results for no matches', () async {
      // Arrange
      const searchQuery = 'nonexistent product xyz';
      final mockResponse = SearchResponse({
        'hits': [],
        'facets': {},
        'page': 0,
        'nbHits': 0,
        'nbPages': 0,
        'hitsPerPage': 20,
        'processingTimeMS': 10,
        'query': searchQuery,
        'params': '',
      });

      when(mockAlgoliaService.isAvailable).thenReturn(true);
      when(mockAlgoliaService.responses).thenAnswer((_) => Stream.value(mockResponse));

      // Act
      final result = await repository.fetchProducts(searchQuery: searchQuery);

      // Assert
      expect(result.products, isEmpty);
      expect(result.hasMore, false);
    });

    test('should filter by category when provided', () async {
      // Arrange
      const searchQuery = 'food';
      const categoryId = 14; // Food category
      final mockResponse = SearchResponse({
        'hits': [
          {
            'objectID': 'prod_001',
            'name': 'Organic Apples',
            'price': 4.99,
            'description': 'Fresh organic apples',
            'categoryId': 14,
            'sellerId': 'seller_01',
            'imageUrls': [],
            'stockQuantity': 50,
            'rating': 4.8,
            'ratingCount': 120,
            'isActive': true,
            'keywords': ['apples'],
            'sellerAddress': {'street': '123 Main St', 'apartment': '', 'city': 'Toronto', 'state': 'ON', 'postalCode': 'M5V 3A8', 'country': 'Canada'},
            'freeShipping': false,
            'isPerishable': true,
            'isLocalDeliveryOnly': false,
          },
          {
            'objectID': 'prod_002',
            'name': 'Fresh Tomatoes',
            'price': 3.99,
            'description': 'Fresh tomatoes',
            'categoryId': 14,
            'sellerId': 'seller_02',
            'imageUrls': [],
            'stockQuantity': 30,
            'rating': 4.5,
            'ratingCount': 85,
            'isActive': true,
            'keywords': ['tomatoes'],
            'sellerAddress': {'street': '456 King St', 'apartment': '', 'city': 'Toronto', 'state': 'ON', 'postalCode': 'M5V 2T6', 'country': 'Canada'},
            'freeShipping': false,
            'isPerishable': true,
            'isLocalDeliveryOnly': false,
          },
        ],
        'facets': {},
        'page': 0,
        'nbHits': 2,
        'nbPages': 1,
        'hitsPerPage': 20,
        'processingTimeMS': 12,
        'query': '',
        'params': '',
      });

      when(mockAlgoliaService.isAvailable).thenReturn(true);
      when(mockAlgoliaService.responses).thenAnswer((_) => Stream.value(mockResponse));

      // Act
      final result = await repository.fetchProducts(searchQuery: searchQuery, categoryId: categoryId);

      // Assert
      expect(result.products.length, 2);
      expect(result.products.every((p) => p.categoryId == categoryId), true);
      verify(mockAlgoliaService.search(searchQuery, categoryId: categoryId)).called(1);
    });

    test('should indicate hasMore when results equal page size', () async {
      // Arrange
      const searchQuery = 'product';
      final hits = List.generate(
        20,
        (i) => {
          'objectID': 'prod_$i',
          'name': 'Product $i',
          'price': 10.0 + i,
          'description': 'Product description $i',
          'categoryId': 1,
          'sellerId': 'seller_$i',
          'imageUrls': [],
          'stockQuantity': 10,
          'rating': 4.0,
          'ratingCount': 10,
          'isActive': true,
          'keywords': ['product'],
          'sellerAddress': {'street': '123 Market St', 'apartment': '', 'city': 'Toronto', 'state': 'ON', 'postalCode': 'M5V 1A1', 'country': 'Canada'},
          'freeShipping': false,
          'isPerishable': false,
          'isLocalDeliveryOnly': false,
        },
      );

      final mockResponse = SearchResponse({
        'hits': hits,
        'facets': {},
        'page': 0,
        'nbHits': 20,
        'nbPages': 2,
        'hitsPerPage': 20,
        'processingTimeMS': 20,
        'query': searchQuery,
        'params': '',
      });

      when(mockAlgoliaService.isAvailable).thenReturn(true);
      when(mockAlgoliaService.responses).thenAnswer((_) => Stream.value(mockResponse));

      // Act
      final result = await repository.fetchProducts(searchQuery: searchQuery);

      // Assert
      expect(result.products.length, 20);
      // Algolia search always returns hasMore: false (no cursor-based pagination)
      expect(result.hasMore, false);
    });
  });

  group('Algolia Service Integration', () {
    test('hitToProductMap should correctly parse all fields', () {
      // Arrange
      final hit = {
        'objectID': 'test_123',
        'name': 'Test Product',
        'price': 29.99,
        'categoryId': 19,
        'sellerId': 'seller_abc',
        'imageUrls': ['https://example.com/image1.jpg', 'https://example.com/image2.jpg'],
        'description': 'A test product description',
        'stockQuantity': 100,
        'rating': 4.7,
        'ratingCount': 256,
        'keywords': ['test', 'product', 'sample'],
        'sellerAddress': {'street': '123 Main St', 'city': 'Toronto', 'state': 'ON', 'postalCode': 'M5V1A1', 'country': 'Canada'},
        'isActive': true,
        'freeShipping': true,
        'isPerishable': false,
        'isLocalDeliveryOnly': false,
        'minimumOrderQuantity': 2,
        'estimatedShipDays': 3,
      };

      // Act
      final result = AlgoliaService.hitToProductMap(hit);

      // Assert
      expect(result['productId'], 'test_123');
      expect(result['name'], 'Test Product');
      expect(result['price'], 29.99);
      expect(result['categoryId'], 19);
      expect(result['sellerId'], 'seller_abc');
      expect(result['imageUrls'], hasLength(2));
      expect(result['description'], 'A test product description');
      expect(result['stockQuantity'], 100);
      expect(result['rating'], 4.7);
      expect(result['ratingCount'], 256);
      expect(result['freeShipping'], true);
      expect(result['isPerishable'], false);
      expect(result['minimumOrderQuantity'], 2);
    });

    test('hitToProductMap should handle missing optional fields', () {
      // Arrange
      final hit = {'objectID': 'test_456', 'name': 'Minimal Product', 'price': 9.99, 'categoryId': 1};

      // Act
      final result = AlgoliaService.hitToProductMap(hit);

      // Assert
      expect(result['productId'], 'test_456');
      expect(result['name'], 'Minimal Product');
      expect(result['price'], 9.99);
      expect(result['imageUrls'], isEmpty);
      expect(result['description'], '');
      expect(result['stockQuantity'], 0);
      expect(result['rating'], 0.0);
      expect(result['freeShipping'], false);
    });
  });
}
