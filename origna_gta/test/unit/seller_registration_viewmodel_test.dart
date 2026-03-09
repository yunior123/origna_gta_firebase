import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/seller/seller_registration_view_model.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
])
import 'seller_registration_viewmodel_test.mocks.dart';

void main() {
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult;
  late ProviderContainer container;

  setUp(() {
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult();
    
    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
    when(mockResult.data).thenReturn({});
    
    container = ProviderContainer(
      overrides: [
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SellerRegistrationViewModel Unit Tests', () {
    test('initial state is correct', () {
      final state = container.read(sellerRegistrationViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      // Default payment provider is stripe
      expect(state.paymentProvider, PaymentProviderValues.stripe);
    });

    test('setPaymentProvider updates state and calls backend', () async {
      final viewModel = container.read(sellerRegistrationViewModelProvider.notifier);
      
      await viewModel.setPaymentProvider('stripe_connect');
      
      expect(container.read(sellerRegistrationViewModelProvider).paymentProvider, 'stripe_connect');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.updatePaymentProvider)).called(1);
      verify(mockCallable.call({ApiKeys.provider: 'stripe_connect'})).called(1);
    });

    test('refreshAccountStatus calls backend', () async {
      final viewModel = container.read(sellerRegistrationViewModelProvider.notifier);
      
      await viewModel.refreshAccountStatus();
      
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.getConnectAccountStatus)).called(1);
      verify(mockCallable.call()).called(1);
    });

    test('startRegistration follows step 1 and step 2', () async {
      final viewModel = container.read(sellerRegistrationViewModelProvider.notifier);
      
      when(mockResult.data).thenReturn({ApiKeys.url: 'https://onboarding.url'});
      
      await viewModel.startRegistration();
      
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.createConnectAccount)).called(1);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.createAccountLink)).called(1);
    });

    test('rate limiting prevents rapid calls', () async {
      final viewModel = container.read(sellerRegistrationViewModelProvider.notifier);
      
      when(mockResult.data).thenReturn({ApiKeys.url: 'https://url'});
      
      // Step 1: Start registration
      await viewModel.startRegistration();
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.createConnectAccount)).called(1);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.createAccountLink)).called(1);
      
      clearInteractions(mockFunctions);
      
      // Step 2: Immediate second call should be blocked by _canProceed
      await viewModel.startRegistration(); 
      verifyNoMoreInteractions(mockFunctions);
    });
  });
}
