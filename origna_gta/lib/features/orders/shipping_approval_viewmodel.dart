import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/utils/utils.dart';

/// Documentation for ShippingApprovalState
class ShippingApprovalState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;

  ShippingApprovalState({this.isLoading = false, this.isSuccess = false, this.errorMessage});

  ShippingApprovalState copyWith({bool? isLoading, bool? isSuccess, String? errorMessage}) {
    return ShippingApprovalState(isLoading: isLoading ?? this.isLoading, isSuccess: isSuccess ?? this.isSuccess, errorMessage: errorMessage);
  }
}

final shippingApprovalViewModelProvider = StateNotifierProvider.autoDispose<ShippingApprovalViewModel, ShippingApprovalState>((ref) {
  return ShippingApprovalViewModel(ref);
});

/// Documentation for ShippingApprovalViewModel
class ShippingApprovalViewModel extends StateNotifier<ShippingApprovalState> {
  final Ref _ref;

  ShippingApprovalViewModel(this._ref) : super(ShippingApprovalState());

  Future<bool> approveShippingCost(String orderId, bool approved) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _ref.read(orderRepositoryProvider).approveShippingCost(orderId, approved);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to process shipping approval'));
      return false;
    }
  }
}
