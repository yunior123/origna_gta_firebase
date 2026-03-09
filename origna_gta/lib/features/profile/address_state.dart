import 'package:origna_gta/core/schema/schema_constants.dart';

/// Documentation for AddressState
class AddressState {
  final bool isLoading;
  final String? selectedProvince;
  final String? selectedLabel;
  final List<Map<String, dynamic>> addressSuggestions;
  final bool showSuggestions;
  final double? latitude;
  final double? longitude;
  final String? addressId;
  final String? errorMessage;
  final bool isSuccess;
  final bool isDefault;

  AddressState({
    this.isLoading = false,
    this.selectedProvince = ProvinceCodeValues.ontario,
    this.selectedLabel = AddressLabelValues.home,
    this.addressSuggestions = const [],
    this.showSuggestions = false,
    this.latitude,
    this.longitude,
    this.addressId,
    this.errorMessage,
    this.isSuccess = false,
    this.isDefault = false,
  });

  AddressState copyWith({
    bool? isLoading,
    String? selectedProvince,
    String? selectedLabel,
    List<Map<String, dynamic>>? addressSuggestions,
    bool? showSuggestions,
    double? latitude,
    double? longitude,
    String? addressId,
    String? errorMessage,
    bool? isSuccess,
    bool? isDefault,
    bool clearCoordinates = false,
  }) {
    return AddressState(
      isLoading: isLoading ?? this.isLoading,
      selectedProvince: selectedProvince ?? this.selectedProvince,
      selectedLabel: selectedLabel ?? this.selectedLabel,
      addressSuggestions: addressSuggestions ?? this.addressSuggestions,
      showSuggestions: showSuggestions ?? this.showSuggestions,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      addressId: addressId ?? this.addressId,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
