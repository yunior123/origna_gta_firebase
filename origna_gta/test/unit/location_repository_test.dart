import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/repositories/location_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult<Map>>(as: #MockHttpsCallableResultMap),
])
import 'location_repository_test.mocks.dart';

void main() {
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResultMap mockResult;
  late GeoapifyLocationRepository repository;

  setUp(() {
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResultMap();
    
    repository = GeoapifyLocationRepository(functions: mockFunctions);
    
    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
  });

  group('GeoapifyLocationRepository', () {
    test('getAddressSuggestions returns list of features on success', () async {
      final mockData = {
        'features': [
          {'properties': {'formatted': '123 Main St'}}
        ]
      };
      
      when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
      when(mockResult.data).thenReturn(mockData);

      final results = await repository.getAddressSuggestions('123 Main');

      expect(results.length, 1);
      expect(results[0]['properties']['formatted'], '123 Main St');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.getAddressSuggestions)).called(1);
    });

    test('getAddressSuggestions returns empty list on failure', () async {
      when(mockCallable.call(any)).thenThrow(Exception('Network Error'));

      final results = await repository.getAddressSuggestions('123 Main');

      expect(results, isEmpty);
    });

    test('getAddressSuggestions returns empty list when features is null', () async {
      when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
      when(mockResult.data).thenReturn({});

      final results = await repository.getAddressSuggestions('123 Main');

      expect(results, isEmpty);
    });
  });
}
