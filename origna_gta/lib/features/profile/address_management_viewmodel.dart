// coverage:ignore-file
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';

final addressManagementViewModelProvider =
    StateNotifierProvider.autoDispose<AddressManagementViewModel, AsyncValue<void>>((ref) {
  return AddressManagementViewModel(ref);
});

/// Documentation for AddressManagementViewModel
class AddressManagementViewModel extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  AddressManagementViewModel(this.ref) : super(const AsyncValue.data(null));

  Future<void> deleteAddress(String addressId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(userRepositoryProvider).deleteBuyerAddress(addressId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setDefaultAddress(String addressId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(userRepositoryProvider).setDefaultBuyerAddress(addressId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
