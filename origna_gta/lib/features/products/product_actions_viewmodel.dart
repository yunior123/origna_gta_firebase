import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/utils/utils.dart';

/// Documentation for ProductActionsState
class ProductActionsState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;

  ProductActionsState({this.isLoading = false, this.isSuccess = false, this.errorMessage});

  ProductActionsState copyWith({bool? isLoading, bool? isSuccess, String? errorMessage}) {
    return ProductActionsState(isLoading: isLoading ?? this.isLoading, isSuccess: isSuccess ?? this.isSuccess, errorMessage: errorMessage);
  }
}

final productActionsViewModelProvider = StateNotifierProvider.autoDispose<ProductActionsViewModel, ProductActionsState>((ref) {
  return ProductActionsViewModel(ref);
});

/// Documentation for ProductActionsViewModel
class ProductActionsViewModel extends StateNotifier<ProductActionsState> {
  final Ref _ref;

  ProductActionsViewModel(this._ref) : super(ProductActionsState());

  Future<bool> deleteProduct(String productId) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _ref.read(productRepositoryProvider).deleteProduct(productId);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to perform action'));
      return false;
    }
  }
}
