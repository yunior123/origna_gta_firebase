import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/checkout/checkout_provider.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/core/repositories/auth_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/models.dart';

@GenerateNiceMocks([
  MockSpec<OrderRepository>(),
  MockSpec<UserRepository>(),
  MockSpec<AuthRepository>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
])
import 'checkout_notifier_test.mocks.dart';

void main() {
  late MockOrderRepository mockOrderRepo;
  late MockUserRepository mockUserRepo;
  late MockAuthRepository mockAuthRepo;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult;
  late ProviderContainer container;

  setUp(() {
    mockOrderRepo = MockOrderRepository();
    mockUserRepo = MockUserRepository();
    mockAuthRepo = MockAuthRepository();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult();
    
    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
    
    container = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(mockOrderRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
        userIdProvider.overrideWithValue('user_123'),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CheckoutNotifier Unit Tests', () {
    test('initial state is correct', () {
      final state = container.read(checkoutStateProvider);
      expect(state.isCalculatingShipping, isFalse);
      expect(state.isProcessing, isFalse);
      expect(state.address, isNull);
    });

    test('updateAddress updates state', () {
      final address = Address(street: '123 St', city: 'City', state: 'ON', postalCode: 'M1M 1M1', country: 'CA');
      container.read(checkoutStateProvider.notifier).updateAddress(address);
      
      expect(container.read(checkoutStateProvider).address, address);
    });

    test('applyCoupon calls backend and updates state', () async {
      when(mockResult.data).thenReturn({Fields.discountAmountCents: 500});
      
      await container.read(checkoutStateProvider.notifier).applyCoupon('SAVE5', 2000);
      
      final state = container.read(checkoutStateProvider);
      expect(state.couponCode, 'SAVE5');
      expect(state.couponDiscountCents, 500);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.applyCoupon)).called(1);
    });

    test('removeCoupon clears coupon state', () async {
      when(mockResult.data).thenReturn({Fields.discountAmountCents: 500});
      final notifier = container.read(checkoutStateProvider.notifier);
      
      await notifier.applyCoupon('SAVE5', 2000);
      expect(container.read(checkoutStateProvider).couponCode, 'SAVE5');
      
      notifier.removeCoupon();
      expect(container.read(checkoutStateProvider).couponCode, isNull);
      expect(container.read(checkoutStateProvider).couponDiscountCents, 0);
    });

    test('reset restores initial state', () {
      final notifier = container.read(checkoutStateProvider.notifier);
      notifier.updateAddress(Address(street: '123', city: 'C', state: 'S', postalCode: 'P', country: 'C'));
      
      notifier.reset();
      expect(container.read(checkoutStateProvider).address, isNull);
    });
  });
}
