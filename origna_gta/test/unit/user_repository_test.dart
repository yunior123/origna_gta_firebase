import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/models.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
])
import 'user_repository_test.mocks.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late FirebaseUserRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    repository = FirebaseUserRepository(fakeFirestore, mockFunctions);
    
    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
  });

  group('FirebaseUserRepository Comprehensive Tests', () {
    test('getUserProfile returns user model', () async {
      await fakeFirestore.collection(Collections.users).doc('u1').set({
        Fields.uid: 'u1',
        Fields.email: 'u1@e.com',
        Fields.name: 'U1',
        Fields.roles: ['buyer'],
        Fields.createdAt: DateTime.now().toIso8601String(),
      });
      
      final profile = await repository.getUserProfile('u1');
      expect(profile, isNotNull);
      expect(profile!.uid, 'u1');
    });

    test('addBuyerAddress calls function', () async {
      final mockResult = MockHttpsCallableResult();
      when(mockResult.data).thenReturn({'success': true, Fields.addressId: 'a1'});
      when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
      
      final address = Address(street: 'S', city: 'C', state: 'P', postalCode: 'Z', country: 'CA');
      final addressId = await repository.addBuyerAddress(address);
      
      expect(addressId, 'a1');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.addBuyerAddress)).called(1);
    });

    test('updatePreferredLanguage calls function', () async {
      final mockResult = MockHttpsCallableResult();
      when(mockResult.data).thenReturn({'success': true});
      when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
      
      await repository.updatePreferredLanguage('u1', 'fr');
      
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.updateUserProfile)).called(1);
      verify(mockCallable.call({Fields.preferredLanguage: 'fr'})).called(1);
    });

    test('watchAddresses returns list', () async {
      final col = fakeFirestore.collection(Collections.users).doc('u1').collection(Collections.addresses);
      await col.doc('a1').set({'street': 'S1'});
      
      final stream = repository.watchAddresses('u1');
      final list = await stream.first;
      expect(list.length, 1);
      expect(list.first.street, 'S1');
    });
  });
}
