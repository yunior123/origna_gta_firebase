import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart' as gen;
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

@GenerateNiceMocks([
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
])
import 'order_repository_test.mocks.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late FirebaseOrderRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    repository = FirebaseOrderRepository(fakeFirestore, mockFunctions);
    
    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
  });

  group('FirebaseOrderRepository Comprehensive Tests', () {
    test('fetchOrderById returns order', () async {
      await fakeFirestore.collection(Collections.orders).doc('o1').set({
        Fields.orderId: 'o1',
        Fields.userId: 'u1',
        Fields.items: [],
        Fields.totalAmountCents: 1000,
        Fields.subtotalCents: 1000,
        Fields.taxes: {},
        Fields.createdAt: Timestamp.now(),
      });
      
      final order = await repository.fetchOrderById('o1');
      expect(order, isNotNull);
      expect(order!.orderId, 'o1');
    });

    test('watchBuyerOrders returns stream', () async {
      final stream = repository.watchBuyerOrders('u1');
      expect(stream, isA<Stream<List<gen.Order>>>());
    });
  });
}
