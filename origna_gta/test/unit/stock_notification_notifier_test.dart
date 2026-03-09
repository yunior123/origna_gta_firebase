import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/products/stock_notification_provider.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFirestore>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
  MockSpec<CollectionReference<Map<String, dynamic>>>(),
  MockSpec<Query<Map<String, dynamic>>>(),
  MockSpec<QuerySnapshot<Map<String, dynamic>>>(),
  MockSpec<QueryDocumentSnapshot<Map<String, dynamic>>>(),
])
import 'stock_notification_notifier_test.mocks.dart';

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockCollectionReference mockCollection;
  late MockQuery mockQuery;
  late MockQuerySnapshot mockSnapshots;
  late ProviderContainer container;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockSnapshots = MockQuerySnapshot();
    
    when(mockFirestore.collection(any)).thenReturn(mockCollection);
    
    // Recursive mock for where() to support multiple calls
    MockQuery whereMock(Invocation invocation) => mockQuery;
    when(mockCollection.where(any, 
      isEqualTo: anyNamed('isEqualTo'), 
      isNotEqualTo: anyNamed('isNotEqualTo'),
      isLessThan: anyNamed('isLessThan'),
      isLessThanOrEqualTo: anyNamed('isLessThanOrEqualTo'),
      isGreaterThan: anyNamed('isGreaterThan'),
      isGreaterThanOrEqualTo: anyNamed('isGreaterThanOrEqualTo'),
      arrayContains: anyNamed('arrayContains'),
      arrayContainsAny: anyNamed('arrayContainsAny'),
      whereIn: anyNamed('whereIn'),
      whereNotIn: anyNamed('whereNotIn'),
      isNull: anyNamed('isNull')
    )).thenAnswer(whereMock);
    
    when(mockQuery.where(any, 
      isEqualTo: anyNamed('isEqualTo'),
      isNotEqualTo: anyNamed('isNotEqualTo'),
      isLessThan: anyNamed('isLessThan'),
      isLessThanOrEqualTo: anyNamed('isLessThanOrEqualTo'),
      isGreaterThan: anyNamed('isGreaterThan'),
      isGreaterThanOrEqualTo: anyNamed('isGreaterThanOrEqualTo'),
      arrayContains: anyNamed('arrayContains'),
      arrayContainsAny: anyNamed('arrayContainsAny'),
      whereIn: anyNamed('whereIn'),
      whereNotIn: anyNamed('whereNotIn'),
      isNull: anyNamed('isNull')
    )).thenAnswer(whereMock);
    
    when(mockQuery.limit(any)).thenReturn(mockQuery);
    when(mockQuery.get()).thenAnswer((_) async => mockSnapshots);
    
    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call(any)).thenAnswer((_) async => MockHttpsCallableResult());
    
    container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(mockFirestore),
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
        userIdProvider.overrideWithValue('user_123'),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('StockNotificationNotifier Unit Tests', () {
    test('init sets state based on Firestore', () async {
      when(mockSnapshots.docs).thenReturn([MockQueryDocumentSnapshot()]);
      
      final provider = stockNotificationNotifierProvider((productId: 'prod_123', variantKey: null));
      
      // Use a listener to keep the provider alive (it's autoDispose)
      final sub = container.listen(provider, (_, _) {});
      
      // Wait for async init() to complete
      int count = 0;
      while (container.read(provider).isLoading && count < 20) {
        await Future.delayed(const Duration(milliseconds: 50));
        count++;
      }
      
      final state = container.read(provider);
      expect(state.value, isTrue);
      sub.close();
    });

    test('subscribe calls backend and updates state', () async {
      when(mockSnapshots.docs).thenReturn([]); // Initially not subscribed
      final provider = stockNotificationNotifierProvider((productId: 'prod_123', variantKey: 'red'));
      final sub = container.listen(provider, (_, _) {});
      
      // Wait for init
      while (container.read(provider).isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final notifier = container.read(provider.notifier);
      await notifier.subscribe();
      
      final state = container.read(provider);
      expect(state.value, isTrue);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.subscribeStockNotification)).called(1);
      sub.close();
    });

    test('unsubscribe calls backend and updates state', () async {
      when(mockSnapshots.docs).thenReturn([MockQueryDocumentSnapshot()]); // Initially subscribed
      final provider = stockNotificationNotifierProvider((productId: 'prod_123', variantKey: null));
      final sub = container.listen(provider, (_, _) {});
      
      // Wait for init
      while (container.read(provider).isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      final notifier = container.read(provider.notifier);
      await notifier.unsubscribe();
      
      final state = container.read(provider);
      expect(state.value, isFalse);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.unsubscribeStockNotification)).called(1);
      sub.close();
    });
  });
}
