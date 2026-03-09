import 'package:image_picker/image_picker.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/utils.dart';

import 'variant_models.dart';

/// Sentinel to explicitly clear nullable fields in copyWith.
const _sentinel = Object();

/// Documentation for AddProductState
class AddProductState {
  final bool isLoading;
  // PROD-C4: true only during the R2 video upload step inside addProduct()
  final bool isUploadingVideo;
  final bool isLocalDeliveryOnly;
  final String selectedProvince;
  final double? latitude;
  final double? longitude;
  final List<ImageModel> imageModels;
  final XFile? videoFile;
  final int? videoDurationSeconds;
  final List<Map<String, dynamic>> addressSuggestions;
  final bool showSuggestions;
  final bool addressVerified; // true when address selected from Geoapify
  final bool isPerishable;
  final bool isDigital;
  final bool isAgeRestricted;
  final String? digitalType; // 'software' | 'book' | null
  final String? macosDownloadUrl;
  final String? windowsDownloadUrl;
  final String? linuxDownloadUrl;
  final String? bookSourceUrl;
  final int? deviceLimit;
  final bool standardEnabled;
  final bool expressEnabled;
  final bool sameDayEnabled;
  final int minimumOrderQuantity;
  final bool freeShipping;
  // H-03: freeShippingAt10Plus removed - never stored/used on backend
  final bool savedExpressEnabled; // Saved state when free shipping toggled on
  final bool savedSameDayEnabled; // Saved state when free shipping toggled on
  final bool savedStandardEnabled; // Saved state when digital mode toggled on
  final String? errorMessage;
  final String? skuError; // PROD-H2: Inline error for SKU collisions
  final bool isSuccess;

  // C-03: Business logic state moved from Screen to ViewModel/State
  final String selectedSupplierType;
  final String selectedSupplierCurrency;
  final bool hasTracking;
  final bool inventoryManaged;
  final bool trackQuantity;
  final bool allowBackorder;
  final bool lowStockAlertEnabled;
  final int activeStep;
  final String? selectedCategoryId;
  final String? selectedSubcategory;
  final bool hasAttemptedSubmit;
  final bool discountTierError;

  // Multi-warehouse fields
  final String? sellerSku;
  final List<String> selectedWarehouseIds;
  final Map<String, int> warehouseStockMap; // warehouseId → stock qty

  // N-09: Variant builder fields
  final bool hasVariants;
  final List<VariantOption> variantOptions;
  final List<ProductVariantEntry> variants;
  final String? condition; // ProductConditionValues: new|like_new|good|fair|for_parts

  // Bill 96: French translation fields (optional, recommended for Quebec market)
  final String? nameF;
  final String? descriptionF;

  AddProductState({
    this.isLoading = false,
    this.isUploadingVideo = false,
    this.isLocalDeliveryOnly = false,
    this.selectedProvince = ProvinceCodeValues.ontario,
    this.latitude,
    this.longitude,
    this.imageModels = const [],
    this.videoFile,
    this.videoDurationSeconds,
    this.addressSuggestions = const [],
    this.showSuggestions = false,
    this.addressVerified = false,
    this.isPerishable = false,
    this.isDigital = false,
    this.isAgeRestricted = false,
    this.digitalType,
    this.macosDownloadUrl,
    this.windowsDownloadUrl,
    this.linuxDownloadUrl,
    this.bookSourceUrl,
    this.deviceLimit,
    this.standardEnabled = true,
    this.expressEnabled = false,
    this.sameDayEnabled = false,
    this.minimumOrderQuantity = 1,
    this.freeShipping = false,
    this.savedExpressEnabled = false,
    this.savedSameDayEnabled = false,
    this.savedStandardEnabled = true,
    this.errorMessage,
    this.skuError,
    this.isSuccess = false,

    // C-03 defaults
    this.selectedSupplierType = SupplierTypeValues.aliexpress,
    this.selectedSupplierCurrency = SupplierCurrencyValues.usd,
    this.hasTracking = false,
    this.inventoryManaged = true,
    this.trackQuantity = true,
    this.allowBackorder = false,
    this.lowStockAlertEnabled = false,
    this.activeStep = 0,
    this.selectedCategoryId,
    this.selectedSubcategory,
    this.hasAttemptedSubmit = false,
    this.discountTierError = false,

    this.sellerSku,
    this.selectedWarehouseIds = const [],
    this.warehouseStockMap = const {},
    this.hasVariants = false,
    this.variantOptions = const [],
    this.variants = const [],
    this.condition,
    this.nameF,
    this.descriptionF,
  });

  /// Use `clearError()` to explicitly set errorMessage to null.
  /// Without it, `copyWith()` preserves the current errorMessage.
  AddProductState copyWith({
    bool? isLoading,
    bool? isUploadingVideo,
    bool? isLocalDeliveryOnly,
    String? selectedProvince,
    Object? latitude = _sentinel,
    Object? longitude = _sentinel,
    List<ImageModel>? imageModels,
    Object? videoFile = _sentinel,
    Object? videoDurationSeconds = _sentinel,
    List<Map<String, dynamic>>? addressSuggestions,
    bool? showSuggestions,
    bool? addressVerified,
    bool? isPerishable,
    bool? isDigital,
    bool? isAgeRestricted,
    Object? digitalType = _sentinel,
    Object? macosDownloadUrl = _sentinel,
    Object? windowsDownloadUrl = _sentinel,
    Object? linuxDownloadUrl = _sentinel,
    Object? bookSourceUrl = _sentinel,
    Object? deviceLimit = _sentinel,
    bool? standardEnabled,
    bool? expressEnabled,
    bool? sameDayEnabled,
    int? minimumOrderQuantity,
    bool? freeShipping,
    bool? savedExpressEnabled,
    bool? savedSameDayEnabled,
    bool? savedStandardEnabled,
    Object? errorMessage = _sentinel,
    Object? skuError = _sentinel,
    bool? isSuccess,

    // C-03 fields
    String? selectedSupplierType,
    String? selectedSupplierCurrency,
    bool? hasTracking,
    bool? inventoryManaged,
    bool? trackQuantity,
    bool? allowBackorder,
    bool? lowStockAlertEnabled,
    int? activeStep,
    Object? selectedCategoryId = _sentinel,
    Object? selectedSubcategory = _sentinel,
    bool? hasAttemptedSubmit,
    bool? discountTierError,

    Object? sellerSku = _sentinel,
    List<String>? selectedWarehouseIds,
    Map<String, int>? warehouseStockMap,
    bool? hasVariants,
    List<VariantOption>? variantOptions,
    List<ProductVariantEntry>? variants,
    Object? condition = _sentinel,
    Object? nameF = _sentinel,
    Object? descriptionF = _sentinel,
  }) {
    return AddProductState(
      isLoading: isLoading ?? this.isLoading,
      isUploadingVideo: isUploadingVideo ?? this.isUploadingVideo,
      isLocalDeliveryOnly: isLocalDeliveryOnly ?? this.isLocalDeliveryOnly,
      selectedProvince: selectedProvince ?? this.selectedProvince,
      latitude: latitude == _sentinel ? this.latitude : latitude as double?,
      longitude: longitude == _sentinel ? this.longitude : longitude as double?,
      imageModels: imageModels ?? this.imageModels,
      videoFile: videoFile == _sentinel ? this.videoFile : videoFile as XFile?,
      videoDurationSeconds: videoDurationSeconds == _sentinel ? this.videoDurationSeconds : videoDurationSeconds as int?,
      addressSuggestions: addressSuggestions ?? this.addressSuggestions,
      showSuggestions: showSuggestions ?? this.showSuggestions,
      addressVerified: addressVerified ?? this.addressVerified,
      isPerishable: isPerishable ?? this.isPerishable,
      isDigital: isDigital ?? this.isDigital,
      isAgeRestricted: isAgeRestricted ?? this.isAgeRestricted,
      digitalType: digitalType == _sentinel ? this.digitalType : digitalType as String?,
      macosDownloadUrl: macosDownloadUrl == _sentinel ? this.macosDownloadUrl : macosDownloadUrl as String?,
      windowsDownloadUrl: windowsDownloadUrl == _sentinel ? this.windowsDownloadUrl : windowsDownloadUrl as String?,
      linuxDownloadUrl: linuxDownloadUrl == _sentinel ? this.linuxDownloadUrl : linuxDownloadUrl as String?,
      bookSourceUrl: bookSourceUrl == _sentinel ? this.bookSourceUrl : bookSourceUrl as String?,
      deviceLimit: deviceLimit == _sentinel ? this.deviceLimit : deviceLimit as int?,
      standardEnabled: standardEnabled ?? this.standardEnabled,
      expressEnabled: expressEnabled ?? this.expressEnabled,
      sameDayEnabled: sameDayEnabled ?? this.sameDayEnabled,
      minimumOrderQuantity: minimumOrderQuantity ?? this.minimumOrderQuantity,
      freeShipping: freeShipping ?? this.freeShipping,
      savedExpressEnabled: savedExpressEnabled ?? this.savedExpressEnabled,
      savedSameDayEnabled: savedSameDayEnabled ?? this.savedSameDayEnabled,
      savedStandardEnabled: savedStandardEnabled ?? this.savedStandardEnabled,
      errorMessage: errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      skuError: skuError == _sentinel ? this.skuError : skuError as String?,
      isSuccess: isSuccess ?? this.isSuccess,

      // C-03
      selectedSupplierType: selectedSupplierType ?? this.selectedSupplierType,
      selectedSupplierCurrency: selectedSupplierCurrency ?? this.selectedSupplierCurrency,
      hasTracking: hasTracking ?? this.hasTracking,
      inventoryManaged: inventoryManaged ?? this.inventoryManaged,
      trackQuantity: trackQuantity ?? this.trackQuantity,
      allowBackorder: allowBackorder ?? this.allowBackorder,
      lowStockAlertEnabled: lowStockAlertEnabled ?? this.lowStockAlertEnabled,
      activeStep: activeStep ?? this.activeStep,
      selectedCategoryId: selectedCategoryId == _sentinel ? this.selectedCategoryId : selectedCategoryId as String?,
      selectedSubcategory: selectedSubcategory == _sentinel ? this.selectedSubcategory : selectedSubcategory as String?,
      hasAttemptedSubmit: hasAttemptedSubmit ?? this.hasAttemptedSubmit,
      discountTierError: discountTierError ?? this.discountTierError,

      sellerSku: sellerSku == _sentinel ? this.sellerSku : sellerSku as String?,
      selectedWarehouseIds: selectedWarehouseIds ?? this.selectedWarehouseIds,
      warehouseStockMap: warehouseStockMap ?? this.warehouseStockMap,
      hasVariants: hasVariants ?? this.hasVariants,
      variantOptions: variantOptions ?? this.variantOptions,
      variants: variants ?? this.variants,
      condition: condition == _sentinel ? this.condition : condition as String?,
      nameF: nameF == _sentinel ? this.nameF : nameF as String?,
      descriptionF: descriptionF == _sentinel ? this.descriptionF : descriptionF as String?,
    );
  }
}
