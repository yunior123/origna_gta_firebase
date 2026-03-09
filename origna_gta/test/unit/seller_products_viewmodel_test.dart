import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/features/seller/seller_products_viewmodel.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:cloud_functions/cloud_functions.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
])
import 'seller_products_viewmodel_test.mocks.dart';

void main() {
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late ProviderContainer container;

  setUp(() {
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    
    container = ProviderContainer(
      overrides: [
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
      ],
    );
    
    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
  });

  group('SellerProductsViewModel Tests', () {
    test('initial state is empty', () {
      final state = container.read(sellerProductsViewModelProvider);
      expect(state.selectedIds, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('toggleSelection adds and removes ids', () {
      final notifier = container.read(sellerProductsViewModelProvider.notifier);
      
      notifier.toggleSelection('p1');
      expect(container.read(sellerProductsViewModelProvider).selectedIds, {'p1'});
      
      notifier.toggleSelection('p2');
      expect(container.read(sellerProductsViewModelProvider).selectedIds, {'p1', 'p2'});
      
      notifier.toggleSelection('p1');
      expect(container.read(sellerProductsViewModelProvider).selectedIds, {'p2'});
    });

    test('bulkAction calls function and clears selection', () async {
      final notifier = container.read(sellerProductsViewModelProvider.notifier);
      notifier.toggleSelection('p1');
      
      final mockResult = MockHttpsCallableResult();
      when(mockResult.data).thenReturn({'updated': 1, 'skipped': 0});
      when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
      
      await notifier.bulkAction('archive');
      
      final state = container.read(sellerProductsViewModelProvider);
      expect(state.selectedIds, isEmpty);
      expect(state.successMessage, contains('1 product archived'));
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.bulkUpdateProducts)).called(1);
    });
  });
}
