import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/utils/utils.dart';

/// Streams the current seller's products (all statuses) ordered by creation date.
final sellerProductsProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return const Stream.empty();

  // FAV-M2: cap live stream to BusinessRules.sellerProductsPageSize (200).
  // Sellers with >200 products should use the paginated export flow — pagination planned.
  return ref
      .watch(firestoreProvider)
      .collection(Collections.products)
      .where(Fields.sellerId, isEqualTo: userId)
      .orderBy(Fields.createdAt, descending: true)
      .limit(BusinessRules.sellerProductsPageSize)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) {
            try {
              return Product.fromFirestore(d);
            } catch (e) {
              AppError.log(e, context: 'sellerProductsProvider: skipping malformed doc ${d.id}');
              return null;
            }
          })
          .whereType<Product>()
          .toList());
});

final sellerProductsViewModelProvider = StateNotifierProvider.autoDispose<SellerProductsViewModel, SellerProductsState>((ref) {
  return SellerProductsViewModel(ref);
});

/// Documentation for SellerProductsState
class SellerProductsState {
  final Set<String> selectedIds;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const SellerProductsState({this.selectedIds = const {}, this.isLoading = false, this.errorMessage, this.successMessage});

  SellerProductsState copyWith({Set<String>? selectedIds, bool? isLoading, String? errorMessage, String? successMessage}) {
    return SellerProductsState(
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

/// Documentation for SellerProductsViewModel
class SellerProductsViewModel extends StateNotifier<SellerProductsState> {
  final Ref _ref;

  SellerProductsViewModel(this._ref) : super(const SellerProductsState());

  /// Calls bulk_update_products Cloud Function.
  /// [action] must be one of: "pause", "activate", "archive"
  Future<void> bulkAction(String action) async {
    if (state.selectedIds.isEmpty || state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final result = await functions.httpsCallable(CloudFunctionEndpoints.bulkUpdateProducts).call({
        Fields.productIds: state.selectedIds.toList(),
        Fields.action: action,
      });

      final data = result.data as Map<String, dynamic>;
      final updated = data['data']?['updated'] ?? data['updated'] ?? 0;
      final skipped = data['data']?['skipped'] ?? data['skipped'] ?? 0;

      state = state.copyWith(
        isLoading: false,
        selectedIds: {},
        successMessage:
            '$updated product${updated == 1 ? '' : 's'} ${action}d'
            '${skipped > 0 ? ' ($skipped skipped)' : ''}',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'seller.bulk_action_failed'.tr()));
    }
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: {});
  }

  void selectAll(List<String> productIds) {
    state = state.copyWith(selectedIds: productIds.toSet());
  }

  void toggleSelection(String productId) {
    final ids = Set<String>.from(state.selectedIds);
    if (ids.contains(productId)) {
      ids.remove(productId);
    } else {
      ids.add(productId);
    }
    state = state.copyWith(selectedIds: ids);
  }
}
