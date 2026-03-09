import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/utils.dart';

import 'address_state.dart';

final addressViewModelProvider = StateNotifierProvider.autoDispose<AddressViewModel, AddressState>((ref) {
  return AddressViewModel(ref);
});

/// Documentation for AddressViewModel
class AddressViewModel extends StateNotifier<AddressState> {
  final Ref _ref;
  Timer? _debounce;

  AddressViewModel(this._ref) : super(AddressState());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void onStreetChanged(String value) {
    // Reset coordinates when user types manually
    state = state.copyWith(clearCoordinates: true);

    if (value.length < 3) {
      state = state.copyWith(showSuggestions: false, addressSuggestions: []);
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final suggestions = await _ref.read(locationRepositoryProvider).getAddressSuggestions(value);
      if (mounted) state = state.copyWith(addressSuggestions: suggestions, showSuggestions: suggestions.isNotEmpty);
    });
  }

  Future<void> saveAddress({
    required String street,
    required String apartment,
    required String city,
    required String postalCode,
    required String phoneNumber,
  }) async {
    final userId = _ref.read(userIdProvider);
    if (userId == null) return;

    if (state.latitude == null || state.longitude == null) {
      state = state.copyWith(errorMessage: 'Please select a valid address from the suggestions');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final address = Address(
        street: street.trim(),
        apartment: apartment.trim(),
        city: city.trim(),
        state: state.selectedProvince!,
        postalCode: postalCode.trim().toUpperCase(),
        country: GeoValues.countryCanada,
        phoneNumber: phoneNumber.trim(),
        label: state.selectedLabel,
        isDefault: state.isDefault,
        latitude: state.latitude,
        longitude: state.longitude,
        addressId: state.addressId,
      );

      if (state.addressId != null) {
        await _ref.read(userRepositoryProvider).updateBuyerAddress(state.addressId!, address);
      } else {
        await _ref.read(userRepositoryProvider).addBuyerAddress(address);
      }

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to save address'));
    }
  }

  void selectAddress(Map<String, dynamic> suggestion) {
    final details = parseAddressSuggestion(suggestion);
    state = state.copyWith(
      selectedProvince: details.state,
      latitude: details.latitude,
      longitude: details.longitude,
      showSuggestions: false,
      addressSuggestions: [],
    );
  }

  void setInitialData(Address? address) {
    if (address != null) {
      state = state.copyWith(
        selectedProvince: address.state,
        selectedLabel: address.label ?? AddressLabelValues.home,
        latitude: address.latitude,
        longitude: address.longitude,
        addressId: address.addressId,
        isDefault: address.isDefault,
      );
    }
  }

  void setDefault(bool value) => state = state.copyWith(isDefault: value);

  void setLabel(String label) => state = state.copyWith(selectedLabel: label);

  void setProvince(String province) => state = state.copyWith(selectedProvince: province);
}
