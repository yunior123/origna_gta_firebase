import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/features/orders/shipping_approval_viewmodel.dart';

@GenerateNiceMocks([
  MockSpec<OrderRepository>(),
])
import 'shipping_approval_viewmodel_test.mocks.dart';

void main() {
  late MockOrderRepository mockOrderRepo;
  late ProviderContainer container;

  setUp(() {
    mockOrderRepo = MockOrderRepository();
    container = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(mockOrderRepo),
      ],
    );
  });

  group('ShippingApprovalViewModel', () {
    test('initial state is correct', () {
      final state = container.read(shippingApprovalViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('approveShippingCost success', () async {
      final viewModel = container.read(shippingApprovalViewModelProvider.notifier);
      when(mockOrderRepo.approveShippingCost('order_123', true)).thenAnswer((_) async => {});

      final result = await viewModel.approveShippingCost('order_123', true);

      expect(result, isTrue);
      final state = container.read(shippingApprovalViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isTrue);
      verify(mockOrderRepo.approveShippingCost('order_123', true)).called(1);
    });

    test('approveShippingCost failure', () async {
      final viewModel = container.read(shippingApprovalViewModelProvider.notifier);
      when(mockOrderRepo.approveShippingCost('order_123', false)).thenThrow(Exception('Failed'));

      final result = await viewModel.approveShippingCost('order_123', false);

      expect(result, isFalse);
      final state = container.read(shippingApprovalViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, isNotNull);
    });
  });
}
