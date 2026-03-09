import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/utils/utils.dart';

/// Documentation for ProductRatingState
class ProductRatingState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final String? reviewText;

  const ProductRatingState({this.isLoading = false, this.isSuccess = false, this.errorMessage, this.reviewText});

  ProductRatingState copyWith({bool? isLoading, bool? isSuccess, String? errorMessage, String? reviewText}) {
    return ProductRatingState(isLoading: isLoading ?? this.isLoading, isSuccess: isSuccess ?? this.isSuccess, errorMessage: errorMessage, reviewText: reviewText ?? this.reviewText);
  }
}

final productRatingViewModelProvider = StateNotifierProvider.autoDispose<ProductRatingViewModel, ProductRatingState>((ref) {
  return ProductRatingViewModel(ref);
});

/// Documentation for ProductRatingViewModel
class ProductRatingViewModel extends StateNotifier<ProductRatingState> {
  final Ref _ref;
  KeepAliveLink? _keepAliveLink;

  ProductRatingViewModel(this._ref) : super(ProductRatingState());

  /// Updates the draft review text shown in the rating form.
  void setReviewText(String? text) => state = state.copyWith(reviewText: text);

  /// Submits a product rating with an optional review text and images.
  ///
  /// Uses atomic backend submission (QA-H1) where images and document are created together.
  ///
  /// Throws nothing — all errors are captured into [ProductRatingState.errorMessage].
  Future<bool> submitRating(String orderId, String productId, int rating, {List<Uint8List>? reviewImages, String? reviewText}) async {
    if (state.isLoading) return false;
    if (rating < 1 || rating > 5) {
      state = state.copyWith(errorMessage: 'rating.invalid_range'.tr());
      return false;
    }
    // Prevent double-submit if widget is rebuilt during submission (autoDispose)
    _keepAliveLink = _ref.keepAlive();
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _ref.read(productRepositoryProvider).submitRatingAtomic(
        orderId, 
        productId, 
        rating, 
        reviewImages: reviewImages, 
        reviewText: reviewText ?? state.reviewText
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to submit rating'));
      return false;
    } finally {
      _keepAliveLink?.close();
      _keepAliveLink = null;
    }
  }
}
