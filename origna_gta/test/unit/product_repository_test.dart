import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/services/conf_services.dart';

@GenerateNiceMocks([MockSpec<FirebaseFunctions>(), MockSpec<HttpsCallable>(), MockSpec<HttpsCallableResult>(), MockSpec<ConfigService>()])
import 'product_repository_test.mocks.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockConfigService mockConfig;
  late FirebaseProductRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockConfig = MockConfigService();
    repository = FirebaseProductRepository(fakeFirestore, mockFunctions, configService: mockConfig);

    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
  });

  group('FirebaseProductRepository Comprehensive Tests', () {
    test('sanitizeProductForFirestore strips server-controlled fields', () {
      final raw = {Fields.productId: 'p1', Fields.rating: 5.0, Fields.sellerId: 's1', 'name': 'Test'};

      final sanitized = sanitizeProductForFirestore(raw);
      expect(sanitized.containsKey(Fields.productId), isFalse);
      expect(sanitized.containsKey(Fields.rating), isFalse);
      expect(sanitized.containsKey(Fields.sellerId), isFalse);
      expect(sanitized['name'], 'Test');
    });

    test('fetchProductById returns active product', () async {
      await fakeFirestore.collection(Collections.products).doc('p1').set({
        'name': 'Test',
        'price': 10.0,
        'description': 'Desc',
        'imageUrls': [],
        'sellerId': 's1',
        'categoryId': 1,
        'stockQuantity': 10,
        'createdAt': DateTime.now().toIso8601String(),
        Fields.lifecycleStatus: ProductLifecycleStatusValues.active,
      });

      final product = await repository.fetchProductById('p1');
      expect(product, isNotNull);
      expect(product!.name, 'Test');
    });

    test('watchFavorites returns set of IDs', () async {
      await fakeFirestore.collection(Collections.users).doc('u1').set({});
      await fakeFirestore.collection(Collections.users).doc('u1').collection(Collections.favorites).doc('p1').set({});

      final stream = repository.watchFavorites('u1');
      final first = await stream.first;
      expect(first, contains('p1'));
    });

    test('watchUnansweredQuestionsCount returns count', () async {
      final col = fakeFirestore.collection(Collections.productQuestions);
      await col.doc('q1').set({Fields.sellerId: 's1', Fields.answerText: null, Fields.isAnswered: false});
      await col.doc('q2').set({Fields.sellerId: 's1', Fields.answerText: 'Done', Fields.isAnswered: true});

      final stream = repository.watchUnansweredQuestionsCount('s1');
      final count = await stream.first;
      expect(count, 1);
    });
  });
}
