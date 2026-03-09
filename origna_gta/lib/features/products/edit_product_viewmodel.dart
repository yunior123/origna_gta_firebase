// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/products/variant_models.dart';
import 'package:origna_gta/models/generated/models.dart' as models;
import 'package:origna_gta/utils/utils.dart';

import 'edit_product_state.dart';

final editProductViewModelProvider = StateNotifierProvider.autoDispose.family<EditProductViewModel, EditProductState, models.Product>((ref, product) {
  return EditProductViewModel(ref, product);
});

/// Top-level isolate function for image compression — runs in a separate thread.
Uint8List? _compressImageEditIsolate(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  const int maxDimension = 2048;
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  img.Image resized = image;
  if (image.width > maxDimension || image.height > maxDimension) {
    resized = img.copyResize(image, width: image.width > image.height ? maxDimension : null, height: image.height > image.width ? maxDimension : null);
  }
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

/// Documentation for EditProductViewModel
class EditProductViewModel extends StateNotifier<EditProductState> {
  final Ref _ref;
  final models.Product _product;

  EditProductViewModel(this._ref, this._product)
    : super(
        EditProductState(
          isSoldOut: _product.stockQuantity == 0,
          isLocalDeliveryOnly: _product.isLocalDeliveryOnly,
          isPerishable: _product.isPerishable,
          isDigital: _product.isDigital,
          isAgeRestricted: _product.isAgeRestricted,
          digitalType: _product.digitalType,
          macosDownloadUrl: _product.digitalBuilds?[DigitalPlatformValues.macos],
          windowsDownloadUrl: _product.digitalBuilds?[DigitalPlatformValues.windows],
          linuxDownloadUrl: _product.digitalBuilds?[DigitalPlatformValues.linux],
          bookSourceUrl: null, // server-side only, seller must re-enter
          deviceLimit: _product.deviceLimit,
          existingImageUrls: List.from(_product.imageUrls),
          existingVideoUrl: _product.videoUrl,
          selectedProvince: _product.sellerAddress?.state.isNotEmpty == true ? _product.sellerAddress!.state : ProvinceCodeValues.ontario,
          latitude: _product.sellerAddress?.latitude,
          longitude: _product.sellerAddress?.longitude,
          standardEnabled: _product.deliveryOptions.any((o) => o.type == DeliveryTypeValues.standard),
          savedStandardEnabled: _product.deliveryOptions.any((o) => o.type == DeliveryTypeValues.standard),
          expressEnabled: _product.deliveryOptions.any((o) => o.type == DeliveryTypeValues.express),
          sameDayEnabled: _product.deliveryOptions.any((o) => o.type == DeliveryTypeValues.sameDay),
          minimumOrderQuantity: _product.minimumOrderQuantity,
          freeShipping: _product.freeShipping,
          taxCode: _product.taxCode,
          // Variant/condition fields — parity with AddProductState
          hasVariants: _product.hasVariants,
          variantOptions: _product.variantOptions.map((v) => VariantOption.fromMap(v.toJson())).toList(),
          variants: _product.variants.map((v) => ProductVariantEntry.fromMap(v.toJson())).toList(),
          condition: _product.condition,
          // Warehouse fields
          selectedWarehouseIds: _product.warehouseIds ?? const [],
          warehouseStockMap: _product.warehouseStockMap ?? const {},
        ),
      );

  ProductRepository get _repository => _ref.read(productRepositoryProvider);

  Future<void> addImage(XFile file) async {
    final bytes = await file.readAsBytes();
    state = state.copyWith(
      newImages: [
        ...state.newImages,
        ImageModel(url: file.path, bytes: bytes),
      ],
    );
  }

  Future<void> onStreetChanged(String value) async {
    if (value.length < 3) {
      state = state.copyWith(showSuggestions: false, addressSuggestions: []);
      return;
    }
    try {
      final suggestions = await _repository.getAutocompleteSuggestions(value);
      state = state.copyWith(addressSuggestions: suggestions, showSuggestions: true);
    } catch (e) {
      AppError.log(e, context: 'EditProductViewModel.onStreetChanged');
    }
  }

  void removeExistingImage(int index) {
    final newList = List<String>.from(state.existingImageUrls)..removeAt(index);
    state = state.copyWith(existingImageUrls: newList);
  }

  void removeVideo() {
    state = state.copyWith(videoFile: null, videoDurationSeconds: null, existingVideoUrl: null);
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

  void setBookSourceUrl(String? url) => state = state.copyWith(bookSourceUrl: url);

  void setDeviceLimit(int? limit) => state = state.copyWith(deviceLimit: limit);

  void setDigitalType(String? type) => state = state.copyWith(digitalType: type);

  /// Move the image at [index] in existingImageUrls to position 0 (cover slot).
  void setExistingImageAsCover(int index) {
    final urls = List<String>.from(state.existingImageUrls);
    if (index <= 0 || index >= urls.length) return;
    final cover = urls.removeAt(index);
    urls.insert(0, cover);
    state = state.copyWith(existingImageUrls: urls);
  }

  void setExpressEnabled(bool value) => state = state.copyWith(expressEnabled: value, isLocalDeliveryOnly: value ? false : state.isLocalDeliveryOnly);

  void setLinuxDownloadUrl(String? url) => state = state.copyWith(linuxDownloadUrl: url);

  void setMacosDownloadUrl(String? url) => state = state.copyWith(macosDownloadUrl: url);

  void setMinimumOrderQuantity(int value) => state = state.copyWith(minimumOrderQuantity: value);
  void setProvince(String province) => state = state.copyWith(selectedProvince: province);
  void setSameDayEnabled(bool value) => state = state.copyWith(sameDayEnabled: value, isLocalDeliveryOnly: value ? false : state.isLocalDeliveryOnly);
  void setStandardEnabled(bool value) => state = state.copyWith(standardEnabled: value, isLocalDeliveryOnly: value ? false : state.isLocalDeliveryOnly);
  void setVideo(XFile file, int durationSeconds) {
    state = state.copyWith(videoFile: file, videoDurationSeconds: durationSeconds, existingVideoUrl: null);
  }

  void setWindowsDownloadUrl(String? url) => state = state.copyWith(windowsDownloadUrl: url);

  void toggleAgeRestricted(bool value) => state = state.copyWith(isAgeRestricted: value);

  void toggleDigital(bool value) => state = state.copyWith(
    isDigital: value,
    freeShipping: value ? true : state.freeShipping,
    isPerishable: value ? false : state.isPerishable,
    isLocalDeliveryOnly: value ? false : state.isLocalDeliveryOnly,
    // Save current standardEnabled before disabling, restore from saved state
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

  void toggleFreeShipping(bool value) => state = state.copyWith(freeShipping: value);

  void toggleLocalDelivery(bool value) => state = state.copyWith(isLocalDeliveryOnly: value);

  void togglePerishable(bool value) => state = state.copyWith(isPerishable: value);

  void toggleSoldOut(bool value) => state = state.copyWith(isSoldOut: value);

  Future<void> updateProduct({
    required String name,
    required String description,
    required double price,
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
    required int shipDays,
    required List<models.SellerDeliveryOption> deliveryOptions,
    models.InventoryConfig? inventory,

    /// Original/crossed-out price for discount display (null = no sale, must be > price)
    double? compareAtPrice,
    // Bill 96: French translation fields
    String? nameF,
    String? descriptionF,
  }) async {
    // Guard: prevent double-submit
    if (state.isLoading) return;

    // CRITICAL: Ownership guard — prevent editing another seller's product
    final currentUid = _ref.read(userIdProvider);
    if (currentUid == null || currentUid != _product.sellerId) {
      state = state.copyWith(errorMessage: 'Unauthorized: you do not own this product');
      return;
    }

    final normalizedTaxCode = (taxCode == null || taxCode.trim().isEmpty) ? null : taxCode.trim();

    if (name.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Product name is required');
      return;
    }
    if (description.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Description is required');
      return;
    }
    if (price <= 0) {
      state = state.copyWith(errorMessage: 'product.please_enter_price'.tr());
      return;
    }
    if (price > 100000) {
      state = state.copyWith(errorMessage: 'Price cannot exceed \$100,000');
      return;
    }
    if (compareAtPrice != null && compareAtPrice - price < 0.50) {
      state = state.copyWith(errorMessage: 'product.compare_at_price_must_be_higher'.tr());
      return;
    }
    if (stock < 0) {
      state = state.copyWith(errorMessage: 'Stock cannot be negative');
      return;
    }
    if (categoryId <= 0) {
      state = state.copyWith(errorMessage: 'Category is required');
      return;
    }
    // Address validation only for physical products
    if (!state.isDigital) {
      if (street.trim().isEmpty || city.trim().isEmpty || postalCode.trim().isEmpty || state.selectedProvince.trim().isEmpty) {
        state = state.copyWith(errorMessage: 'Complete product address is required');
        return;
      }
      if (state.latitude == null || state.longitude == null) {
        state = state.copyWith(errorMessage: 'Select a valid address from suggestions');
        return;
      }
    }
    if ((weight ?? 0) < 0 || (length ?? 0) < 0 || (width ?? 0) < 0 || (height ?? 0) < 0) {
      state = state.copyWith(errorMessage: 'Package dimensions must be positive');
      return;
    }

    // Bug #4: Physical products need at least one delivery tier (unless local-only)
    if (!state.isDigital && !state.isLocalDeliveryOnly) {
      if (!state.standardEnabled && !state.expressEnabled && !state.sameDayEnabled) {
        state = state.copyWith(errorMessage: 'Enable at least one delivery option for physical products');
        return;
      }
    }

    // Digital product validation
    if (state.isDigital) {
      if (state.digitalType == null) {
        state = state.copyWith(errorMessage: 'Select a digital product type');
        return;
      }
      if (state.digitalType == DigitalTypeValues.software) {
        final urls = [state.macosDownloadUrl, state.windowsDownloadUrl, state.linuxDownloadUrl];
        if (urls.every((u) => u == null || u.isEmpty)) {
          state = state.copyWith(errorMessage: 'Add at least one platform download URL');
          return;
        }
        if (urls.whereType<String>().where((u) => u.isNotEmpty).any((u) => !u.startsWith('https://'))) {
          state = state.copyWith(errorMessage: 'Download URLs must start with https://');
          return;
        }
      } else if (state.digitalType == DigitalTypeValues.book) {
        final url = state.bookSourceUrl?.trim();
        if (url != null && url.isNotEmpty) {
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
    }

    final totalImages = state.existingImageUrls.length + state.newImages.length;
    if (totalImages == 0) {
      state = state.copyWith(errorMessage: 'Please have at least one product image');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);

    try {
      if (state.videoFile != null) {
        if ((state.videoDurationSeconds ?? 0) > BusinessRules.maxVideoDurationSeconds) {
          state = state.copyWith(isLoading: false, errorMessage: 'product.video_too_long'.tr());
          return;
        }
        final bytes = await state.videoFile!.readAsBytes();
        if (bytes.length > BusinessRules.maxVideoBytes) {
          state = state.copyWith(isLoading: false, errorMessage: 'product.video_too_large'.tr());
          return;
        }
      }

      final keywords = generateSearchKeywords(name);
      List<String> allImageUrls = List.from(state.existingImageUrls);

      if (state.newImages.isNotEmpty) {
        final processedImages = await _processImages(state.newImages);
        final successfulUrls = await _repository.uploadImages(processedImages, _product.productId);
        allImageUrls.addAll(successfulUrls);
      }

      String? uploadedVideoUrl;
      // If a new video is selected, already validated above, now upload
      if (state.videoFile != null) {
        uploadedVideoUrl = await _repository.uploadProductVideo(state.videoFile!, _product.sellerId);
      } else if (state.existingVideoUrl != null) {
        uploadedVideoUrl = state.existingVideoUrl;
      }
      final sanitizedDeliveryOptions = state.isDigital ? <models.SellerDeliveryOption>[] : deliveryOptions;
      final updatedProduct = _product.copyWith(
        name: name,
        nameF: nameF?.trim().isEmpty == true ? null : nameF?.trim(),
        description: description,
        descriptionF: descriptionF?.trim().isEmpty == true ? null : descriptionF?.trim(),
        price: price,
        stockQuantity: state.isSoldOut ? 0 : stock,
        categoryId: categoryId,
        imageUrls: allImageUrls,
        keywords: keywords,
        sellerAddress: models.Address(
          street: street,
          apartment: apartment,
          city: city,
          state: state.selectedProvince,
          postalCode: postalCode.toUpperCase(),
          // Preserve original country from product; fall back to Canada if not set
          country: _product.sellerAddress?.country.isNotEmpty == true ? _product.sellerAddress!.country : CountryValues.canada,
          latitude: state.latitude,
          longitude: state.longitude,
        ),
        weightKg: state.isDigital ? null : weight,
        lengthCm: state.isDigital ? null : length,
        widthCm: state.isDigital ? null : width,
        heightCm: state.isDigital ? null : height,
        isLocalDeliveryOnly: state.isDigital ? false : state.isLocalDeliveryOnly,
        estimatedShipDays: state.isDigital ? 0 : shipDays,
        isPerishable: state.isDigital ? false : state.isPerishable,
        isAgeRestricted: state.isDigital ? false : state.isAgeRestricted,
        deliveryOptions: sanitizedDeliveryOptions,
        isDigital: state.isDigital,
        digitalType: state.isDigital ? state.digitalType : null,
        digitalBuilds: state.isDigital && state.digitalType == DigitalTypeValues.software
            ? {
                if (state.macosDownloadUrl?.isNotEmpty == true) DigitalPlatformValues.macos: state.macosDownloadUrl!,
                if (state.windowsDownloadUrl?.isNotEmpty == true) DigitalPlatformValues.windows: state.windowsDownloadUrl!,
                if (state.linuxDownloadUrl?.isNotEmpty == true) DigitalPlatformValues.linux: state.linuxDownloadUrl!,
              }
            : null,
        deviceLimit: state.isDigital ? state.deviceLimit : null,
        minimumOrderQuantity: state.minimumOrderQuantity,
        freeShipping: state.freeShipping,
        taxCode: normalizedTaxCode,
        inventory: inventory ?? _product.inventory,
        compareAtPrice: compareAtPrice,
      );

      // Build update map and add bookSourceUrl only if seller re-entered it
      final updateMap = updatedProduct.toJson();
      if (state.isDigital && state.digitalType == DigitalTypeValues.book && state.bookSourceUrl?.isNotEmpty == true) {
        updateMap[Fields.bookSourceUrl] = state.bookSourceUrl!;
      }

      if (uploadedVideoUrl != null) {
        updateMap[Fields.videoUrl] = uploadedVideoUrl;
      } else {
        // If neither videoFile nor existingVideoUrl is set, ensure videoUrl is cleared in firestore
        updateMap[Fields.videoUrl] = null;
      }

      await _repository.updateProduct(_product.productId, updateMap);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e));
    }
  }

  Future<List<Uint8List>> _processImages(List<ImageModel> imageModels) async {
    final processed = <Uint8List>[];
    for (var model in imageModels) {
      final validated = await _validateAndCompressImage(model.bytes);
      if (validated != null) processed.add(validated);
    }
    return processed;
  }

  Future<Uint8List?> _validateAndCompressImage(Uint8List bytes) async {
    const int maxImageSize = 10 * 1024 * 1024; // 10MB — matches backend limit
    if (bytes.length > maxImageSize) {
      throw Exception('product.image_too_large'.tr());
    }
    return compute(_compressImageEditIsolate, bytes);
  }
}
