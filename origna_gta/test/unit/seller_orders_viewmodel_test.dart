import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/orders/seller_orders_viewmodel.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

@GenerateNiceMocks([
  MockSpec<OrderRepository>(),
])
import 'seller_orders_viewmodel_test.mocks.dart';

void main() {
  late MockOrderRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockOrderRepository();
    container = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SellerOrdersViewModel Unit Tests', () {
    test('initial state is correct', () {
      final state = container.read(sellerOrdersViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('updateShippingAndCapture calls repository and updates state', () async {
      when(mockRepo.updateShippingCost(any, any, any)).thenAnswer((_) async => Future.value());
      when(mockRepo.updateItemStatus(any, any, any, trackingNumber: anyNamed('trackingNumber'), carrier: anyNamed('carrier'), carrierNote: anyNamed('carrierNote')))
          .thenAnswer((_) async => Future.value());

      final viewModel = container.read(sellerOrdersViewModelProvider.notifier);
      await viewModel.updateShippingAndCapture('order_123', 15.0, 'TRK123', carrier: 'FedEx');

      final state = container.read(sellerOrdersViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isTrue);
      
      verify(mockRepo.updateShippingCost('order_123', 15.0, any)).called(1);
      verify(mockRepo.updateItemStatus('order_123', OrderItemIdValues.all, DeliveryStatusValues.shipped, trackingNumber: 'TRK123', carrier: 'FedEx', carrierNote: anyNamed('carrierNote'))).called(1);
    });

    test('updateItemStatus calls repository and updates state', () async {
      when(mockRepo.updateItemStatus(any, any, any, trackingNumber: anyNamed('trackingNumber'), carrier: anyNamed('carrier'), carrierNote: anyNamed('carrierNote')))
          .thenAnswer((_) async => Future.value());

      final viewModel = container.read(sellerOrdersViewModelProvider.notifier);
      await viewModel.updateItemStatus('order_123', 'item_456', DeliveryStatusValues.delivered);

      final state = container.read(sellerOrdersViewModelProvider);
      expect(state.isSuccess, isTrue);
      verify(mockRepo.updateItemStatus('order_123', 'item_456', DeliveryStatusValues.delivered, trackingNumber: anyNamed('trackingNumber'), carrier: anyNamed('carrier'), carrierNote: anyNamed('carrierNote'))).called(1);
    });

    test('handles error in updateShippingAndCapture', () async {
      when(mockRepo.updateShippingCost(any, any, any)).thenThrow(Exception('Failed'));

      final viewModel = container.read(sellerOrdersViewModelProvider.notifier);
      await viewModel.updateShippingAndCapture('order_123', 15.0, 'TRK123');

      final state = container.read(sellerOrdersViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.errorMessage, contains('Failed'));
    });
  });
}
