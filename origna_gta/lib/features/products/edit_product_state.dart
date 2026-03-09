import 'package:image_picker/image_picker.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/products/variant_models.dart';
import 'package:origna_gta/utils/utils.dart';

/// Sentinel value used to distinguish "not provided" from "explicitly set to null".
const _sentinel = Object();

/// Documentation for EditProductState
class EditProductState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final bool isSoldOut;
  final bool isLocalDeliveryOnly;
  final bool isPerishable;
  final bool isDigital;
  final bool isAgeRestricted;
  final String? digitalType;
  final String? macosDownloadUrl;
  final String? windowsDownloadUrl;
  final String? linuxDownloadUrl;
  final String? bookSourceUrl;
  final int? deviceLimit;
  final List<String> existingImageUrls;
  final List<ImageModel> newImages;
  final String? existingVideoUrl;
  final XFile? videoFile;
  final int? videoDurationSeconds;
  final List<Map<String, dynamic>> addressSuggestions;
  final bool showSuggestions;
  final String selectedProvince;
  final double? latitude;
  final double? longitude;
  final bool standardEnabled;
  final bool savedStandardEnabled; // Saved state when digital mode toggled on
  final bool expressEnabled;
  final bool sameDayEnabled;
  final int minimumOrderQuantity;
  final bool freeShipping;
  final String? taxCode;
  // Variant fields — parity with AddProductState
  final bool hasVariants;
  final List<VariantOption> variantOptions;
  final List<ProductVariantEntry> variants;
  final String? condition;
  // Warehouse fields — parity with AddProductState
  final List<String> selectedWarehouseIds;
  final Map<String, int> warehouseStockMap;

  EditProductState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.isSoldOut = false,
    this.isLocalDeliveryOnly = false,
    this.isPerishable = false,
    this.isDigital = false,
    this.isAgeRestricted = false,
    this.digitalType,
    this.macosDownloadUrl,
    this.windowsDownloadUrl,
    this.linuxDownloadUrl,
    this.bookSourceUrl,
    this.deviceLimit,
    this.existingImageUrls = const [],
    this.newImages = const [],
    this.existingVideoUrl,
    this.videoFile,
    this.videoDurationSeconds,
    this.addressSuggestions = const [],
    this.showSuggestions = false,
    this.selectedProvince = ProvinceCodeValues.ontario,
    this.latitude,
    this.longitude,
    this.standardEnabled = true,
    this.savedStandardEnabled = true,
    this.expressEnabled = false,
    this.sameDayEnabled = false,
    this.minimumOrderQuantity = 1,
    this.freeShipping = false,
    this.taxCode,
    this.hasVariants = false,
    this.variantOptions = const [],
    this.variants = const [],
    this.condition,
    this.selectedWarehouseIds = const [],
    this.warehouseStockMap = const {},
  });

  EditProductState copyWith({
    bool? isLoading,
    Object? errorMessage = _sentinel,
    bool? isSuccess,
    bool? isSoldOut,
    bool? isLocalDeliveryOnly,
    bool? isPerishable,
    bool? isDigital,
    bool? isAgeRestricted,
    Object? digitalType = _sentinel,
    Object? macosDownloadUrl = _sentinel,
    Object? windowsDownloadUrl = _sentinel,
    Object? linuxDownloadUrl = _sentinel,
    Object? bookSourceUrl = _sentinel,
    Object? deviceLimit = _sentinel,
    List<String>? existingImageUrls,
    List<ImageModel>? newImages,
    Object? existingVideoUrl = _sentinel,
    Object? videoFile = _sentinel,
    Object? videoDurationSeconds = _sentinel,
    List<Map<String, dynamic>>? addressSuggestions,
    bool? showSuggestions,
    String? selectedProvince,
    Object? latitude = _sentinel,
    Object? longitude = _sentinel,
    bool? standardEnabled,
    bool? savedStandardEnabled,
    bool? expressEnabled,
    bool? sameDayEnabled,
    int? minimumOrderQuantity,
    bool? freeShipping,
    Object? taxCode = _sentinel,
    bool? hasVariants,
    List<VariantOption>? variantOptions,
    List<ProductVariantEntry>? variants,
    Object? condition = _sentinel,
    List<String>? selectedWarehouseIds,
    Map<String, int>? warehouseStockMap,
  }) {
    return EditProductState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      isSuccess: isSuccess ?? this.isSuccess,
      isSoldOut: isSoldOut ?? this.isSoldOut,
      isLocalDeliveryOnly: isLocalDeliveryOnly ?? this.isLocalDeliveryOnly,
      isPerishable: isPerishable ?? this.isPerishable,
      isDigital: isDigital ?? this.isDigital,
      isAgeRestricted: isAgeRestricted ?? this.isAgeRestricted,
      digitalType: digitalType == _sentinel ? this.digitalType : digitalType as String?,
      macosDownloadUrl: macosDownloadUrl == _sentinel ? this.macosDownloadUrl : macosDownloadUrl as String?,
      windowsDownloadUrl: windowsDownloadUrl == _sentinel ? this.windowsDownloadUrl : windowsDownloadUrl as String?,
      linuxDownloadUrl: linuxDownloadUrl == _sentinel ? this.linuxDownloadUrl : linuxDownloadUrl as String?,
      bookSourceUrl: bookSourceUrl == _sentinel ? this.bookSourceUrl : bookSourceUrl as String?,
      deviceLimit: deviceLimit == _sentinel ? this.deviceLimit : deviceLimit as int?,
      existingImageUrls: existingImageUrls ?? this.existingImageUrls,
      newImages: newImages ?? this.newImages,
      existingVideoUrl: existingVideoUrl == _sentinel ? this.existingVideoUrl : existingVideoUrl as String?,
      videoFile: videoFile == _sentinel ? this.videoFile : videoFile as XFile?,
      videoDurationSeconds: videoDurationSeconds == _sentinel ? this.videoDurationSeconds : videoDurationSeconds as int?,
      addressSuggestions: addressSuggestions ?? this.addressSuggestions,
      showSuggestions: showSuggestions ?? this.showSuggestions,
      selectedProvince: selectedProvince ?? this.selectedProvince,
      latitude: latitude == _sentinel ? this.latitude : latitude as double?,
      longitude: longitude == _sentinel ? this.longitude : longitude as double?,
      standardEnabled: standardEnabled ?? this.standardEnabled,
      savedStandardEnabled: savedStandardEnabled ?? this.savedStandardEnabled,
      expressEnabled: expressEnabled ?? this.expressEnabled,
      sameDayEnabled: sameDayEnabled ?? this.sameDayEnabled,
      minimumOrderQuantity: minimumOrderQuantity ?? this.minimumOrderQuantity,
      freeShipping: freeShipping ?? this.freeShipping,
      taxCode: taxCode == _sentinel ? this.taxCode : taxCode as String?,
      hasVariants: hasVariants ?? this.hasVariants,
      variantOptions: variantOptions ?? this.variantOptions,
      variants: variants ?? this.variants,
      condition: condition == _sentinel ? this.condition : condition as String?,
      selectedWarehouseIds: selectedWarehouseIds ?? this.selectedWarehouseIds,
      warehouseStockMap: warehouseStockMap ?? this.warehouseStockMap,
    );
  }
}
