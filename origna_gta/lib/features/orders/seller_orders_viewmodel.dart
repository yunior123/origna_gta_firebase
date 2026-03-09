import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/utils.dart';
import 'seller_orders_state.dart';

final sellerOrdersViewModelProvider = StateNotifierProvider.autoDispose<SellerOrdersViewModel, SellerOrdersState>((ref) {
  return SellerOrdersViewModel(ref);
});

/// Documentation for SellerOrdersViewModel
class SellerOrdersViewModel extends StateNotifier<SellerOrdersState> {
  final Ref _ref;

  SellerOrdersViewModel(this._ref) : super(SellerOrdersState());

  Future<void> updateShippingAndCapture(
    String orderId,
    double actualShipping,
    String trackingNumber, {
    String? carrier,
    String? carrierNote,
  }) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);

    final repository = _ref.read(orderRepositoryProvider);

    try {
      // Step 1: Update shipping cost
      await repository.updateShippingCost(orderId, actualShipping, 'Actual carrier cost');

      // Step 2: Store tracking number if provided
      if (trackingNumber.isNotEmpty) {
        try {
          // Update ALL items with tracking info — seller ships the entire order as one shipment
          await repository.updateItemStatus(
            orderId,
            OrderItemIdValues.all,
            DeliveryStatusValues.shipped,
            trackingNumber: trackingNumber,
            carrier: carrier,
            carrierNote: carrierNote,
          );
        } catch (e) {
          // Non-critical tracking write failed — log for visibility
          AppError.log(e, context: 'sellerOrders.trackingUpdate');
        }
      }

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to update shipping cost'));
    }
  }

  Future<void> updateItemStatus(
    String orderId,
    String itemId,
    String status, {
    String? trackingNumber,
    String? carrier,
    String? carrierNote,
  }) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);

    final repository = _ref.read(orderRepositoryProvider);

    try {
      await repository.updateItemStatus(
        orderId,
        itemId,
        status,
        trackingNumber: trackingNumber,
        carrier: carrier,
        carrierNote: carrierNote,
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to update item status'));
    }
  }
}
