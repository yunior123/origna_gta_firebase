// coverage:ignore-file
import 'package:cross_file/cross_file.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart' as models;
import 'package:origna_gta/utils/utils.dart';

import 'add_product_state.dart';
import 'variant_models.dart';

final addProductViewModelProvider = StateNotifierProvider.autoDispose<AddProductViewModel, AddProductState>((ref) {
  return AddProductViewModel(ref);
});

/// Top-level isolate function for image compression — runs in a separate thread.
Uint8List? _compressImageAddIsolate(Uint8List bytes) {
  const int maxDimension = 2048;
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  img.Image resized = image;
  if (image.width > maxDimension || image.height > maxDimension) {
    resized = img.copyResize(image, width: image.width > image.height ? maxDimension : null, height: image.height > image.width ? maxDimension : null);
  }
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

/// Documentation for AddProductViewModel
class AddProductViewModel extends StateNotifier<AddProductState> {
  final Ref _ref;

  AddProductViewModel(this._ref) : super(AddProductState());

  void addImage(ImageModel image) => state = state.copyWith(imageModels: [...state.imageModels, image]);

  /// Validates all inputs, compresses images, and creates the product via [createProductAtomic].
  ///
  /// Handles physical/digital products, warehouse stock, and variant configurations.
  /// Updates [AddProductState.isLoading] during the operation and sets [isSuccess] on completion.
  /// Errors are written to [AddProductState.errorMessage] rather than thrown.
  Future<void> addProduct({
    required String name,
    required String description,
    required double price,

    /// Original/crossed-out price for discount display (null = no sale, must be > price)
    double? compareAtPrice,
    required int stock,
    required int categoryId,
    required String street,
    required String apartment,
    required String city,
    required String postalCode,
    double? weight,
    double? length,
    double? width,
    double? height,
    String? taxCode,
    required List<models.SellerDeliveryOption> deliveryOptions,
    int? minimumOrderQuantity,
    bool? freeShipping,
    // Flat supplier fields (when supplier object is not used)
    double? cost,
    String? supplierSku,
    String? supplierUrl,
    // Structured supplier info
    models.SupplierInfo? supplier,
    // Inventory configuration
    models.InventoryConfig? inventory,
    // Subcategory (N-11)
    String? subcategory,
    // PROD-C2: true when the seller has warehouses registered — enforces warehouse selection
    bool sellerHasWarehouses = false,
    // Bill 96: French translation fields
    String? nameF,
    String? descriptionF,
  }) async {
    // Bug #27: Prevent double-submit
    if (state.isLoading) return;

    final config = _ref.read(envConfigProvider);
    final isDevOrTestRun = config.isDev || config.isEmulator;

    if (name.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'product.please_enter_name'.tr());
      return;
    }
    if (name.trim().length > 120) {
      state = state.copyWith(errorMessage: 'product.name_too_long'.tr());
      return;
    }
    if (description.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'product.please_enter_description'.tr());
      return;
    }
    if (description.trim().length < 10) {
      state = state.copyWith(errorMessage: 'product.description_too_short'.tr());
      return;
    }
    if (description.trim().length > 4000) {
      state = state.copyWith(errorMessage: 'product.description_too_long'.tr());
      return;
    }
    if (price <= 0.99) {
      state = state.copyWith(errorMessage: 'product.please_enter_price'.tr());
      return;
    }
    if (price > 100000) {
      state = state.copyWith(errorMessage: 'product.price_limit_exceeded'.tr());
      return;
    }
    if (compareAtPrice != null && compareAtPrice - price < 0.50) {
      state = state.copyWith(errorMessage: 'product.compare_at_price_must_be_higher'.tr());
      return;
    }
    if (stock < 0) {
      state = state.copyWith(errorMessage: 'product.stock_negative'.tr());
      return;
    }
    final minOrderQty = minimumOrderQuantity ?? state.minimumOrderQuantity;
    if (minOrderQty < 1) {
      state = state.copyWith(errorMessage: 'product.min_order_at_least_one'.tr());
      return;
    }
    if (categoryId <= 0) {
      state = state.copyWith(errorMessage: 'product.select_category'.tr());
      return;
    }
    // PROD-C2: If seller has warehouses, they must select at least one — manual address bypass not allowed.
    if (!state.isDigital && sellerHasWarehouses && state.selectedWarehouseIds.isEmpty) {
      state = state.copyWith(errorMessage: 'product.warehouse_selection_required'.tr());
      return;
    }
    // Bug #4: Skip address validation for digital products or when warehouses are selected
    if (!state.isDigital && state.selectedWarehouseIds.isEmpty) {
      if (street.trim().isEmpty || city.trim().isEmpty || postalCode.trim().isEmpty || state.selectedProvince.trim().isEmpty) {
        state = state.copyWith(errorMessage: 'product.address_required'.tr());
        return;
      }
      // FIX: Validate address field lengths to match Firestore Rules
      if (street.trim().length < 3) {
        state = state.copyWith(errorMessage: 'product.street_too_short'.tr());
        return;
      }
      if (street.trim().length > 100) {
        state = state.copyWith(errorMessage: 'product.street_too_long'.tr());
        return;
      }
      if (city.trim().length < 2) {
        state = state.copyWith(errorMessage: 'product.city_too_short'.tr());
        return;
      }
      if (city.trim().length > 50) {
        state = state.copyWith(errorMessage: 'product.city_too_long'.tr());
        return;
      }
      // FIX: Validate postal code format in ViewModel (not just Form UI)
      final normalizedPostal = postalCode.trim().toUpperCase().replaceAll(' ', '');
      final postalRegex = RegExp(r'^[A-Z]\d[A-Z]\d[A-Z]\d$');
      if (!postalRegex.hasMatch(normalizedPostal)) {
        state = state.copyWith(errorMessage: 'product.invalid_postal'.tr());
        return;
      }

      // SECURITY: Require address to be verified via Geoapify autocomplete
      // In dev/test mode, allow bypass for integration tests
      if (!state.addressVerified && !isDevOrTestRun) {
        if (state.latitude == null || state.longitude == null) {
          state = state.copyWith(errorMessage: 'product.address_not_verified'.tr());
          return;
        }
      }
    }

    if (!isValidTaxCode(taxCode)) {
      state = state.copyWith(errorMessage: 'product.invalid_tax_code_format'.tr());
      return;
    }
    if ((weight ?? 0) < 0 || (length ?? 0) < 0 || (width ?? 0) < 0 || (height ?? 0) < 0) {
      state = state.copyWith(errorMessage: 'product.dimensions_positive'.tr());
      return;
    }

    if (state.imageModels.isEmpty && !isDevOrTestRun) {
      state = state.copyWith(errorMessage: 'product.image_required'.tr());
      return;
    }

    // Bug #4: Physical products need at least one delivery tier (unless local-only)
    if (!state.isDigital && !state.isLocalDeliveryOnly) {
      if (!state.standardEnabled && !state.expressEnabled && !state.sameDayEnabled) {
        state = state.copyWith(errorMessage: 'product.delivery_tier_required'.tr());
        return;
      }
    }

    // Digital product validation
    if (state.isDigital) {
      if (state.digitalType == null) {
        state = state.copyWith(errorMessage: 'product.digital_type_required'.tr());
        return;
      }
      if (state.digitalType == DigitalTypeValues.software) {
        final urls = [state.macosDownloadUrl, state.windowsDownloadUrl, state.linuxDownloadUrl];
        if (urls.every((u) => u == null || u.trim().isEmpty)) {
          state = state.copyWith(errorMessage: 'product.digital_platform_url_required'.tr());
          return;
        }
        final nonEmptyUrls = urls.whereType<String>().where((u) => u.trim().isNotEmpty);
        if (nonEmptyUrls.any((u) => !u.startsWith('https://'))) {
          state = state.copyWith(errorMessage: 'product.digital_url_https_required'.tr());
          return;
        }
      } else if (state.digitalType == DigitalTypeValues.book) {
        final url = state.bookSourceUrl?.trim();
        if (url == null || url.isEmpty) {
          state = state.copyWith(errorMessage: 'product.book_url_required'.tr());
          return;
        }
        if (url.length > 500) {
          state = state.copyWith(errorMessage: 'product.url_too_long'.tr());
          return;
        }
        if (!url.startsWith('https://')) {
          state = state.copyWith(errorMessage: 'product.book_url_https_required'.tr());
          return;
        }
      }
    }

    // Variant validation: all variants must have a price > 0
    if (state.hasVariants) {
      if (state.variantOptions.isEmpty) {
        state = state.copyWith(errorMessage: 'product.variants_required'.tr());
        return;
      }
      final invalidVariants = state.variants.where((v) {
        return v.priceCents == null || v.priceCents! < 99;
      });
      if (invalidVariants.isNotEmpty) {
        state = state.copyWith(errorMessage: 'product.variant_price_required'.tr());
        return;
      }
    }

    if (state.videoFile != null) {
      final size = await state.videoFile!.length();
      if (size > BusinessRules.maxVideoBytes) {
        state = state.copyWith(errorMessage: 'product.video_too_large'.tr());
        return;
      }
      final duration = state.videoDurationSeconds ?? 0;
      if (duration > BusinessRules.maxVideoDurationSeconds) {
        state = state.copyWith(errorMessage: 'product.video_too_long'.tr());
        return;
      }
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final productRepository = _ref.read(productRepositoryProvider);

      final sanitizedDeliveryOptions = state.isDigital ? <models.SellerDeliveryOption>[] : deliveryOptions;

      final streetTrimmed = street.trim();
      final apartmentTrimmed = apartment.trim();
      final cityTrimmed = city.trim();
      final provinceTrimmed = state.selectedProvince.trim();
      final postalTrimmed = postalCode.trim().toUpperCase();

      // Atomic: compress images then delegate both upload + Firestore write to backend.
      // On any failure the backend cleans up R2 automatically — no orphan images.
      List<Uint8List> compressedImages = [];
      List<String>? testImageUrls;

      if (state.imageModels.isEmpty && isDevOrTestRun) {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        testImageUrls = ['https://picsum.photos/seed/origna-$stamp/800/800'];
      } else {
        compressedImages = await _compressImages(state.imageModels);
        if (compressedImages.isEmpty) {
          throw Exception('Failed to compress images. Please try different images.');
        }
      }

      final useWarehouses = state.selectedWarehouseIds.isNotEmpty;
      if (useWarehouses) {
        if (state.warehouseStockMap.isEmpty) {
          state = state.copyWith(isLoading: false, errorMessage: 'product.warehouse_stock_required'.tr());
          return;
        }
        final allHaveStock = state.selectedWarehouseIds.every((id) => state.warehouseStockMap.containsKey(id));
        if (!allHaveStock) {
          state = state.copyWith(isLoading: false, errorMessage: 'product.warehouse_stock_all_required'.tr());
          return;
        }
        final totalStock = state.warehouseStockMap.values.fold(0, (a, b) => a + b);
        if (totalStock == 0) {
          state = state.copyWith(isLoading: false, errorMessage: 'product.warehouse_total_stock_zero'.tr());
          return;
        }
        // F-82: Reject negative per-warehouse stock
        if (state.warehouseStockMap.values.any((qty) => qty < 0)) {
          state = state.copyWith(isLoading: false, errorMessage: 'product.warehouse_stock_negative'.tr());
          return;
        }
      }
      // F-53: When hasVariants, derive effective stock from variant quantities sum.
      // When using warehouses, stock = sum of all warehouseStockMap values.
      final effectiveStock = state.hasVariants
          ? state.variants.fold(0, (int sum, v) => sum + (v.stockQuantity))
          : useWarehouses
          ? state.warehouseStockMap.values.fold(0, (a, b) => a + b)
          : stock;

      final uid = _ref.read(userIdProvider);
      if (uid == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'errors.auth_expired'.tr());
        return;
      }

      // Build the product model — imageUrls and productId are set server-side
      var product = models.Product(
        productId: '',
        sellerId: uid,
        name: name,
        nameF: nameF?.trim().isEmpty == true ? null : nameF?.trim(),
        keywords: generateSearchKeywords(name),
        stockQuantity: effectiveStock,
        price: price,
        compareAtPrice: compareAtPrice,
        imageUrls: const [],
        sellerAddress: useWarehouses
            ? null
            : models.Address(
                street: streetTrimmed,
                apartment: apartmentTrimmed,
                city: cityTrimmed,
                state: provinceTrimmed,
                postalCode: postalTrimmed,
                country: CountryValues.canada,
                latitude: state.latitude,
                longitude: state.longitude,
              ),
        description: description,
        descriptionF: descriptionF?.trim().isEmpty == true ? null : descriptionF?.trim(),
        categoryId: categoryId,
        createdAt: DateTime.now(),
        rating: 0.0,
        // PROD-C3: lifecycleStatus omitted — defaults to 'draft' in model; backend sets 'under_review' on creation.
        weightKg: state.isDigital ? null : weight,
        lengthCm: state.isDigital ? null : length,
        widthCm: state.isDigital ? null : width,
        heightCm: state.isDigital ? null : height,
        isLocalDeliveryOnly: state.isDigital ? false : state.isLocalDeliveryOnly,
        estimatedShipDays: () {
          // Use the 'standard' option's estimatedDays as the canonical shipping time.
          // Fall back to first available, then 0 if none exist.
          if (sanitizedDeliveryOptions.isEmpty) return 0;
          final standard = sanitizedDeliveryOptions.where((o) => o.type == DeliveryTypeValues.standard).firstOrNull;
          return standard?.estimatedDays ?? sanitizedDeliveryOptions.first.estimatedDays;
        }(),
        taxCode: taxCode,
        deliveryOptions: sanitizedDeliveryOptions,
        isPerishable: state.isDigital ? false : state.isPerishable,
        isDigital: state.isDigital,
        isAgeRestricted: state.isAgeRestricted,
        digitalType: state.isDigital && state.digitalType != null ? state.digitalType : null,
        digitalBuilds: state.isDigital && state.digitalType == DigitalTypeValues.software
            ? {
                if (state.macosDownloadUrl?.isNotEmpty == true) DigitalPlatformValues.macos: state.macosDownloadUrl!,
                if (state.windowsDownloadUrl?.isNotEmpty == true) DigitalPlatformValues.windows: state.windowsDownloadUrl!,
                if (state.linuxDownloadUrl?.isNotEmpty == true) DigitalPlatformValues.linux: state.linuxDownloadUrl!,
              }
            : null,
        deviceLimit: state.isDigital ? state.deviceLimit : null,
        minimumOrderQuantity: minOrderQty,
        freeShipping: freeShipping ?? state.freeShipping,
        cost: cost,
        supplierSku: supplierSku,
        supplierUrl: supplierUrl,
        supplier: supplier,
        inventory: inventory,
        sellerSku: state.sellerSku,
        subcategory: subcategory,
        warehouseIds: useWarehouses ? state.selectedWarehouseIds : null,
        warehouseStockMap: useWarehouses ? state.warehouseStockMap : null,
        hasVariants: state.hasVariants,
        variants: state.hasVariants ? state.variants.map((v) => models.ProductVariant.fromJson(v.toMap())).toList() : const [],
        variantOptions: state.hasVariants ? state.variantOptions.map((o) => models.VariantOption.fromJson(o.toMap())).toList() : const [],
        condition: state.isDigital ? null : state.condition,
        videoUrl: null, // Will be set after upload
      );

      // PROD-C4: Show dedicated uploading state so submit button reflects video upload progress.
      String? uploadedVideoUrl;
      if (state.videoFile != null) {
        state = state.copyWith(isUploadingVideo: true);
        try {
          uploadedVideoUrl = await productRepository.uploadProductVideo(state.videoFile!, uid);
          product = product.copyWith(videoUrl: uploadedVideoUrl);
        } finally {
          state = state.copyWith(isUploadingVideo: false);
        }
      }

      await productRepository.createProductAtomic(
        product,
        compressedImages,
        testImageUrls: testImageUrls,
        // Pass bookSourceUrl for digital book products — excluded from Dart Product model
        // (buyer-protected: never read back by client) but required by Python backend
        // to store the download URL server-side.
        bookSourceUrl: (state.isDigital && state.digitalType == DigitalTypeValues.book) ? state.bookSourceUrl : null,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e, st) {
      AppError.log(e, stackTrace: st, context: 'AddProductViewModel.addProduct');
      final msg = AppError.getMessage(e, 'product.add_product_failed'.tr());

      // PROD-H2: Detect SKU already exists error from backend
      if (msg.toLowerCase().contains('sku') && (msg.toLowerCase().contains('exists') || msg.toLowerCase().contains('déjà'))) {
        state = state.copyWith(isLoading: false, skuError: 'product.sku_already_exists'.tr(), errorMessage: null);
      } else {
        state = state.copyWith(isLoading: false, errorMessage: msg);
      }
    }
  }

  /// Adds a new variant option axis and regenerates all variant combinations.
  ///
  /// [name] The option axis label (e.g., "Color"). [values] The selectable values (e.g., ["Red", "Blue"]).
  /// Existing variant price/stock/sku data is preserved where option values match.
  void addVariantOption(String name, List<String> values) {
    final options = List<VariantOption>.from(state.variantOptions);
    options.add(VariantOption(name: name, values: values));
    state = state.copyWith(variantOptions: options);
    _regenerateVariants();
  }

  /// Bug #16: Invalidate lat/lng when user manually edits address fields
  /// Also resets addressVerified — user must re-select from Geoapify
  void clearCoordinates() => state = state.copyWith(latitude: null, longitude: null, addressVerified: false);

  /// Clear error message to allow re-triggering SnackBar on next error
  void clearError() => state = state.copyWith(errorMessage: null, skuError: null);

  /// PROD-H2: Clear SKU-specific error
  void clearSkuError() => state = state.copyWith(skuError: null);

  /// Handles street input changes — triggers Geoapify address autocomplete.
  ///
  /// [value] The current street input string. Coordinates are invalidated on every
  /// keystroke to prevent stale geolocation data from a prior suggestion (Bug #16).
  Future<void> onStreetChanged(String value) async {
    // Bug #16: Invalidate stale coordinates when user manually edits address
    clearCoordinates();
    if (value.length < 3) {
      state = state.copyWith(showSuggestions: false, addressSuggestions: []);
      return;
    }
    try {
      final suggestions = await _ref.read(locationRepositoryProvider).getAddressSuggestions(value);
      state = state.copyWith(addressSuggestions: suggestions, showSuggestions: suggestions.isNotEmpty);
    } catch (e, st) {
      AppError.log(e, stackTrace: st, context: 'AddProductViewModel.onStreetChanged');
      state = state.copyWith(addressSuggestions: [], showSuggestions: false, errorMessage: 'product.location_error'.tr());
    }
  }

  void removeImage(int index) => state = state.copyWith(imageModels: List<ImageModel>.from(state.imageModels)..removeAt(index));
  void removeVariantOption(int index) {
    final options = List<VariantOption>.from(state.variantOptions);
    options.removeAt(index);
    state = state.copyWith(variantOptions: options);
    _regenerateVariants();
  }

  void removeVideo() => state = state.copyWith(videoFile: null, videoDurationSeconds: null);

  /// F-58: Reset form state when re-entering the screen after a previous success.
  /// Call from screen's initState if state.isSuccess == true.
  void resetIfSuccess() {
    if (state.isSuccess) {
      state = AddProductState();
    }
  }

  /// Populates state with the parsed province, latitude, and longitude from a Geoapify suggestion.
  ///
  /// [suggestion] Raw feature map from the Geoapify autocomplete API response.
  /// Sets [addressVerified] to true, which unblocks product form submission.
  void selectAddress(Map<String, dynamic> suggestion) {
    final details = parseAddressSuggestion(suggestion);
    state = state.copyWith(
      selectedProvince: details.state,
      latitude: details.latitude,
      longitude: details.longitude,
      addressVerified: true,
      showSuggestions: false,
      addressSuggestions: [],
    );
  }

  void setActiveStep(int step) => state = state.copyWith(activeStep: step);
  void setAllowBackorder(bool value) => state = state.copyWith(allowBackorder: value);

  void setBookSourceUrl(String? url) => state = state.copyWith(bookSourceUrl: url);

  void setCategoryId(String? id) => state = state.copyWith(selectedCategoryId: id, selectedSubcategory: null);
  void setCondition(String? condition) => state = state.copyWith(condition: condition);

  void setDeviceLimit(int? limit) => state = state.copyWith(deviceLimit: limit);

  void setDigitalType(String? type) => state = state.copyWith(digitalType: type);

  void setDiscountTierError(bool value) => state = state.copyWith(discountTierError: value);

  void setExpressEnabled(bool value) => state = state.copyWith(expressEnabled: value, isLocalDeliveryOnly: value ? false : state.isLocalDeliveryOnly);

  void setHasAttemptedSubmit(bool value) => state = state.copyWith(hasAttemptedSubmit: value);

  void setHasTracking(bool value) => state = state.copyWith(hasTracking: value);
  void setInventoryManaged(bool value) => state = state.copyWith(inventoryManaged: value);

  void setLinuxDownloadUrl(String? url) => state = state.copyWith(linuxDownloadUrl: url);

  void setLocalDeliveryOnly(bool value) => state = state.copyWith(
    isLocalDeliveryOnly: value,
    standardEnabled: value ? false : state.standardEnabled,
    expressEnabled: value ? false : state.expressEnabled,
    sameDayEnabled: value ? false : state.sameDayEnabled,
  );

  void setLowStockAlertEnabled(bool value) => state = state.copyWith(lowStockAlertEnabled: value);

  void setMacosDownloadUrl(String? url) => state = state.copyWith(macosDownloadUrl: url);

  void setMinimumOrderQuantity(int value) => state = state.copyWith(minimumOrderQuantity: value);

  void setProvince(String province) => state = state.copyWith(selectedProvince: province);
  void setSameDayEnabled(bool value) => state = state.copyWith(sameDayEnabled: value, isLocalDeliveryOnly: value ? false : state.isLocalDeliveryOnly);
  void setSellerSku(String? sku) => state = state.copyWith(sellerSku: sku?.trim().isEmpty == true ? null : sku?.trim());
  void setStandardEnabled(bool value) => state = state.copyWith(standardEnabled: value, isLocalDeliveryOnly: value ? false : state.isLocalDeliveryOnly);
  void setSubcategory(String? sub) => state = state.copyWith(selectedSubcategory: sub);
  void setSupplierCurrency(String currency) => state = state.copyWith(selectedSupplierCurrency: currency);

  // C-03: Setters for business logic state
  void setSupplierType(String type) => state = state.copyWith(selectedSupplierType: type);

  void setTrackQuantity(bool value) => state = state.copyWith(trackQuantity: value);

  void setVideo(XFile? file, int? durationSeconds) => state = state.copyWith(videoFile: file, videoDurationSeconds: durationSeconds);

  void setWarehouseStock(String warehouseId, int qty) {
    final stockMap = Map<String, int>.from(state.warehouseStockMap);
    stockMap[warehouseId] = qty;
    state = state.copyWith(warehouseStockMap: stockMap);
  }

  void setWindowsDownloadUrl(String? url) => state = state.copyWith(windowsDownloadUrl: url);

  void toggleAgeRestricted(bool value) => state = state.copyWith(isAgeRestricted: value);

  /// Toggles digital product mode, resetting delivery and perishable fields accordingly.
  ///
  /// [value] When true, delivery options are cleared and free shipping is forced on.
  /// The current standard-delivery state is saved so it can be restored if digital mode is disabled.
  void toggleDigital(bool value) => state = state.copyWith(
    isDigital: value,
    freeShipping: value ? true : state.freeShipping,
    isPerishable: value ? false : state.isPerishable,
    isLocalDeliveryOnly: value ? false : state.isLocalDeliveryOnly,
    // Save standard delivery state when enabling digital; restore when disabling
    savedStandardEnabled: value ? state.standardEnabled : state.savedStandardEnabled,
    standardEnabled: value ? false : state.savedStandardEnabled,
    expressEnabled: value ? false : state.expressEnabled,
    sameDayEnabled: value ? false : state.sameDayEnabled,
    // Clear digital sub-fields when turning off
    digitalType: value ? state.digitalType : null,
    macosDownloadUrl: value ? state.macosDownloadUrl : null,
    windowsDownloadUrl: value ? state.windowsDownloadUrl : null,
    linuxDownloadUrl: value ? state.linuxDownloadUrl : null,
    bookSourceUrl: value ? state.bookSourceUrl : null,
    deviceLimit: value ? state.deviceLimit : null,
  );

  /// Enables or disables free shipping, saving and restoring express/same-day state.
  ///
  /// [value] When true, express and same-day options are disabled (free = standard-only).
  /// When false, previously saved express/same-day selections are restored.
  void toggleFreeShipping(bool value) {
    final effectiveValue = state.isDigital ? true : value;
    if (effectiveValue) {
      // Save current express/same-day state before disabling them
      state = state.copyWith(
        freeShipping: true,
        savedExpressEnabled: state.expressEnabled,
        savedSameDayEnabled: state.sameDayEnabled,
        expressEnabled: false,
        sameDayEnabled: false,
        // freeShippingAt10Plus: false,
      );
    } else {
      // Restore previously saved express/same-day state
      state = state.copyWith(freeShipping: false, expressEnabled: state.savedExpressEnabled, sameDayEnabled: state.savedSameDayEnabled);
    }
  }

  /// Enables or disables variant mode, clearing all options and variants when disabled.
  ///
  /// [value] When false, [variantOptions] and [variants] are reset to empty lists.
  void toggleHasVariants(bool value) {
    if (value) {
      state = state.copyWith(hasVariants: true);
    } else {
      state = state.copyWith(hasVariants: false, variantOptions: [], variants: []);
    }
  }

  void togglePerishable(bool value) => state = state.copyWith(isPerishable: value);

  void toggleWarehouseSelection(String warehouseId) {
    final current = List<String>.from(state.selectedWarehouseIds);
    if (current.contains(warehouseId)) {
      current.remove(warehouseId);
      // Remove stock entry too
      final stockMap = Map<String, int>.from(state.warehouseStockMap)..remove(warehouseId);
      state = state.copyWith(selectedWarehouseIds: current, warehouseStockMap: stockMap);
    } else {
      current.add(warehouseId);
      state = state.copyWith(selectedWarehouseIds: current);
    }
  }

  /// Bug #1: Allow ProductAddImages widget to sync images back to ViewModel
  void updateImages(List<ImageModel> images) => state = state.copyWith(imageModels: images);

  void updateVariantOption(int index, String name, List<String> values) {
    final options = List<VariantOption>.from(state.variantOptions);
    options[index] = VariantOption(name: name, values: values);
    state = state.copyWith(variantOptions: options);
    _regenerateVariants();
  }

  void updateVariantPrice(int index, double? price) {
    final variants = List<ProductVariantEntry>.from(state.variants);
    final priceCents = price != null ? (price * 100).round() : null;
    variants[index] = variants[index].copyWith(priceCents: priceCents);
    state = state.copyWith(variants: variants);
  }

  void updateVariantSku(int index, String? sku) {
    final variants = List<ProductVariantEntry>.from(state.variants);
    variants[index] = variants[index].copyWith(sku: sku);
    state = state.copyWith(variants: variants);
  }

  void updateVariantStock(int index, int stockQuantity) {
    final variants = List<ProductVariantEntry>.from(state.variants);
    variants[index] = variants[index].copyWith(stockQuantity: stockQuantity);
    state = state.copyWith(variants: variants);
  }

  Future<List<Uint8List>> _compressImages(List<ImageModel> imageModels) async {
    final results = await Future.wait(imageModels.map((m) => _validateAndCompressImage(m.bytes)));
    return results.whereType<Uint8List>().toList();
  }

  /// Auto-generates all variant combinations from variantOptions.
  /// Preserves price/stock/sku from existing variants where optionValues match.
  void _regenerateVariants() {
    final options = state.variantOptions;
    if (options.isEmpty) {
      state = state.copyWith(variants: []);
      return;
    }
    // Generate cartesian product of all option values
    List<Map<String, String>> combos = [{}];
    for (final opt in options) {
      final newCombos = <Map<String, String>>[];
      for (final combo in combos) {
        for (final val in opt.values) {
          newCombos.add({...combo, opt.name: val});
        }
      }
      combos = newCombos;
    }

    // Map existing variants by their optionValues for preservation
    final existingByKey = <String, ProductVariantEntry>{};
    for (final v in state.variants) {
      final key = v.optionValues.entries.map((e) => '${e.key}=${e.value}').join('|');
      existingByKey[key] = v;
    }

    final newVariants = combos.map((combo) {
      final key = combo.entries.map((e) => '${e.key}=${e.value}').join('|');
      final existing = existingByKey[key];
      return ProductVariantEntry(
        optionValues: combo,
        priceCents: existing?.priceCents,
        stockQuantity: existing?.stockQuantity ?? 0,
        sku: existing?.sku,
        isActive: existing?.isActive ?? true,
      );
    }).toList();

    state = state.copyWith(variants: newVariants);
  }

  Future<Uint8List?> _validateAndCompressImage(Uint8List bytes) async {
    const int maxImageSize = 10 * 1024 * 1024; // 10MB — matches backend limit
    if (bytes.length > maxImageSize) {
      throw Exception('product.image_too_large'.tr());
    }
    // Validate image format by attempting decode
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('product.image_invalid_format'.tr());
    }
    return compute(_compressImageAddIsolate, bytes);
  }
}
