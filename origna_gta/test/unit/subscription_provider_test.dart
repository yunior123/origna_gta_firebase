import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

@GenerateNiceMocks([MockSpec<FirebaseFunctions>(), MockSpec<HttpsCallable>(), MockSpec<UserRepository>()])
import 'subscription_provider_test.mocks.dart';

class FakeHttpsCallableResult<T> implements HttpsCallableResult<T> {
  @override
  final T data;
  FakeHttpsCallableResult(this.data);
}

void main() {
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockUserRepository mockUserRepo;
  late ProviderContainer container;

  setUp(() {
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockUserRepo = MockUserRepository();
    
    container = ProviderContainer(
      overrides: [
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
      ],
    );
  });

  group('SubscriptionViewModel', () {
    test('createSubscription success', () async {
      when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
      when(mockCallable.call<Map<String, dynamic>>()).thenAnswer(
        (_) async => FakeHttpsCallableResult({'checkoutUrl': 'https://checkout.com'})
      );

      final viewModel = container.read(subscriptionViewModelProvider.notifier);
      await viewModel.createSubscription();

      final state = container.read(subscriptionViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.checkoutUrl, 'https://checkout.com');
      expect(state.errorMessage, isNull);
    });

    test('createSubscription error', () async {
      when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
      when(mockCallable.call<Map<String, dynamic>>()).thenThrow(Exception('test error'));

      final viewModel = container.read(subscriptionViewModelProvider.notifier);
      await viewModel.createSubscription();

      final state = container.read(subscriptionViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, contains('test error'));
    });

    test('cancelSubscription success', () async {
      when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
      when(mockCallable.call()).thenAnswer((_) async => FakeHttpsCallableResult(null));

      final viewModel = container.read(subscriptionViewModelProvider.notifier);
      await viewModel.cancelSubscription();

      final state = container.read(subscriptionViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('reactivateSubscription success', () async {
      when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
      when(mockCallable.call()).thenAnswer((_) async => FakeHttpsCallableResult(null));

      final viewModel = container.read(subscriptionViewModelProvider.notifier);
      await viewModel.reactivateSubscription();

      final state = container.read(subscriptionViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('clearCheckoutUrl works', () {
      final viewModel = container.read(subscriptionViewModelProvider.notifier);
      viewModel.clearCheckoutUrl();
      expect(container.read(subscriptionViewModelProvider).checkoutUrl, isNull);
    });
  });
}
