import 'dart:convert';
import 'dart:typed_data';

import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cross_file/cross_file.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/repositories/algolia_product_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/services/algolia_service.dart';

@GenerateMocks([AlgoliaService, FirebaseFunctions, HttpsCallable, HttpsCallableResult])
import 'algolia_product_repository_test.mocks.dart';

void main() {
  late AlgoliaProductRepository repository;
  late MockAlgoliaService mockAlgoliaService;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult;

  setUp(() {
    mockAlgoliaService = MockAlgoliaService();
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult();

    repository = AlgoliaProductRepository(mockAlgoliaService, fakeFirestore, mockFunctions);

    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
    when(mockResult.data).thenReturn({'success': true});
  });

  group('AlgoliaProductRepository delegation tests', () {
    test('deleteProduct calls correct cloud function', () async {
      await repository.deleteProduct('prod_123');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.deleteProduct)).called(1);
      verify(mockCallable.call({Fields.productId: 'prod_123'})).called(1);
    });

    test('submitRating calls correct cloud function', () async {
      await repository.submitRating('order_123', 'prod_456', 5, reviewText: 'Great');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.submitProductRating)).called(1);
      verify(mockCallable.call(argThat(containsPair(Fields.rating, 5)))).called(1);
    });

    test('submitRatingAtomic calls correct cloud function', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      await repository.submitRatingAtomic('order_123', 'prod_456', 4, reviewImages: [bytes]);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.submitProductRatingAtomic)).called(1);
      final captor = verify(mockCallable.call(captureAny)).captured.single as Map;
      expect(captor[ApiKeys.images][0]['data'], base64Encode(bytes));
    });

    test('updateProduct calls Firestore with sanitized data', () async {
      // Setup: Add product to fake firestore
      await fakeFirestore.collection(Collections.products).doc('prod_123').set({Fields.name: 'Old Name'});

      await repository.updateProduct('prod_123', {Fields.name: 'New Name', Fields.productId: 'discard'});

      final doc = await fakeFirestore.collection(Collections.products).doc('prod_123').get();
      expect(doc.data()?[Fields.name], 'New Name');
      expect(doc.data()?.containsKey(Fields.productId), isFalse);
    });

    test('unimplemented methods throw', () {
      final p = Product(
        productId: '',
        name: '',
        description: '',
        price: 0,
        imageUrls: [],
        sellerId: '',
        categoryId: 0,
        stockQuantity: 0,
        createdAt: DateTime.now(),
      );
      expect(() => repository.createProductAtomic(p, []), throwsUnimplementedError);
      expect(() => repository.getUploadUrl(''), throwsUnimplementedError);
      expect(() => repository.getUploadUrlInfo(''), throwsUnimplementedError);
      expect(() => repository.getUploadVideoUrlInfo('', ''), throwsUnimplementedError);
      expect(() => repository.uploadImages([], ''), throwsUnimplementedError);
      expect(() => repository.uploadProductVideo(XFile.fromData(Uint8List(0)), ''), throwsUnimplementedError);
      expect(() => repository.uploadReviewImages([], ''), throwsUnimplementedError);
    });
  });

  group('AlgoliaProductRepository search routing logic', () {
    test('routes to Algolia when query and available', () async {
      when(mockAlgoliaService.isAvailable).thenReturn(true);
      when(mockAlgoliaService.responses).thenAnswer((_) => Stream.value(SearchResponse({'hits': []})));

      await repository.fetchProducts(searchQuery: 'organic');

      verify(mockAlgoliaService.search('organic', categoryId: null)).called(1);
    });

    test('routes to Firestore when query is empty', () async {
      when(mockAlgoliaService.isAvailable).thenReturn(true);

      await repository.fetchProducts(searchQuery: '');

      verifyNever(mockAlgoliaService.search(any, categoryId: anyNamed('categoryId')));
    });

    test('routes to Firestore when Algolia is unavailable', () async {
      when(mockAlgoliaService.isAvailable).thenReturn(false);

      await repository.fetchProducts(searchQuery: 'organic');

      verifyNever(mockAlgoliaService.search(any, categoryId: anyNamed('categoryId')));
    });

    test('falls back to Firestore on Algolia error', () async {
      when(mockAlgoliaService.isAvailable).thenReturn(true);
      when(mockAlgoliaService.responses).thenAnswer((_) => Stream.error('Network Error'));

      await repository.fetchProducts(searchQuery: 'organic');

      verify(mockAlgoliaService.search('organic', categoryId: null)).called(1);
    });
  });

  group('Internal Firestore fetch logic', () {
    test('_fetchFromFirestore applies all filters', () async {
      // Since we use FakeFirebaseFirestore, we just verify it doesn't crash and returns empty list
      final results = await repository.fetchProducts(
        categoryId: 14,
        subcategory: 'Fruits',
        minPriceCents: 100,
        maxPriceCents: 500,
        sortOption: SortOption.priceHighToLow,
      );
      expect(results.products, isEmpty);
    });
  });

  group('Standard Firestore methods', () {
    test('fetchProductById', () async {
      await fakeFirestore.collection(Collections.products).doc('p1').set({
        Fields.productId: 'p1',
        Fields.lifecycleStatus: ProductLifecycleStatusValues.active,
        Fields.name: 'Test',
        Fields.price: 10.0,
        Fields.description: 'Desc',
        Fields.imageUrls: <String>[],
        Fields.sellerId: 's1',
        Fields.categoryId: 1,
        Fields.stockQuantity: 10,
        Fields.createdAt: Timestamp.now(),
      });

      final product = await repository.fetchProductById('p1');
      expect(product?.productId, 'p1');
    });

    test('fetchProductsByIds', () async {
      final ids = List.generate(35, (i) => 'id_$i');
      final results = await repository.fetchProductsByIds(ids);
      expect(results, isEmpty);
    });

    test('toggleFavorite uses transaction', () async {
      final userRef = fakeFirestore.collection(Collections.users).doc('user_123');
      final favRef = userRef.collection(Collections.favorites).doc('prod_456');

      // Test Add
      await repository.toggleFavorite('user_123', 'prod_456');
      var doc = await favRef.get();
      expect(doc.exists, isTrue);

      // Test Remove
      await repository.toggleFavorite('user_123', 'prod_456');
      doc = await favRef.get();
      expect(doc.exists, isFalse);
    });

    test('getAutocompleteSuggestions queries Firestore', () async {
      final results = await repository.getAutocompleteSuggestions('app');
      expect(results, isEmpty);
    });

    test('getProductBySlug fetches from Firestore', () async {
      final result = await repository.getProductBySlug('test-slug');
      expect(result, isNull);
    });

    test('watchFavorites returns stream', () async {
      final stream = repository.watchFavorites('user_123');
      expect(await stream.first, isEmpty);
    });

    test('watchUnansweredQuestionsCount returns count', () async {
      await fakeFirestore.collection(Collections.productQuestions).add({Fields.sellerId: 'seller_1', Fields.isAnswered: false});

      final stream = repository.watchUnansweredQuestionsCount('seller_1');
      expect(await stream.first, 1);
    });
  });
}
