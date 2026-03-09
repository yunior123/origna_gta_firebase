import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/features/checkout/checkout_provider.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:cloud_functions/cloud_functions.dart';

@GenerateNiceMocks([
  MockSpec<OrderRepository>(),
  MockSpec<UserRepository>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
])
import 'checkout_provider_test.mocks.dart';

void main() {
  late MockOrderRepository mockOrderRepo;
  late MockUserRepository mockUserRepo;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late ProviderContainer container;

  setUp(() {
    mockOrderRepo = MockOrderRepository();
    mockUserRepo = MockUserRepository();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    
    container = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(mockOrderRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
        userIdProvider.overrideWith((ref) => 'user_123'),
      ],
    );
    
    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
  });

  group('CheckoutNotifier Tests', () {
    test('initial state is correct', () {
      final state = container.read(checkoutStateProvider);
      expect(state.isProcessing, isFalse);
      expect(state.address, isNull);
    });

    test('updateAddress updates state', () {
      final address = Address(street: 'S', city: 'C', state: 'P', postalCode: 'Z', country: 'CA');
      container.read(checkoutStateProvider.notifier).updateAddress(address);
      
      final state = container.read(checkoutStateProvider);
      expect(state.address, address);
    });

    test('applyCoupon calls function', () async {
      final mockResult = MockHttpsCallableResult();
      when(mockResult.data).thenReturn({Fields.discountAmountCents: 500});
      when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
      
      await container.read(checkoutStateProvider.notifier).applyCoupon('SAVE5', 10000);
      
      final state = container.read(checkoutStateProvider);
      expect(state.couponCode, 'SAVE5');
      expect(state.couponDiscountCents, 500);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.applyCoupon)).called(1);
    });
  });
}
