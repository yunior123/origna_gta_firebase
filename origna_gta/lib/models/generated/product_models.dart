// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from Pydantic models - Single source of truth
// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/schema/schema_constants.dart';
import 'base_models.dart';

part 'product_models.freezed.dart';
part 'product_models.g.dart';

/// International supplier platform types
const _internationalSupplierTypes = SupplierTypeValues.international;

/// Default delivery ranges by supplier type
({int minDays, int maxDays}) _getDeliveryRangeForSupplier(String? supplierType) {
  return switch (supplierType) {
    SupplierTypeValues.aliexpress => (minDays: 15, maxDays: 30),
    SupplierTypeValues.dhgate => (minDays: 20, maxDays: 40),
    SupplierTypeValues.alibaba => (minDays: 25, maxDays: 45),
    SupplierTypeValues.s1688 => (minDays: 25, maxDays: 45),
    SupplierTypeValues.temu => (minDays: 7, maxDays: 15),
    SupplierTypeValues.cjdropshipping => (minDays: 10, maxDays: 20),
    SupplierTypeValues.local => (minDays: 1, maxDays: 5),
    _ => (minDays: 3, maxDays: 7), // Default for local/other
  };
}

/// Get supplier region for display
String? _getSupplierRegion(String? supplierType) {
  return switch (supplierType) {
    SupplierTypeValues.aliexpress || SupplierTypeValues.alibaba || SupplierTypeValues.s1688 || SupplierTypeValues.temu => 'China',
    SupplierTypeValues.dhgate => 'China/Asia',
    SupplierTypeValues.cjdropshipping => 'Various (dropship)',
    SupplierTypeValues.local => 'Canada',
    _ => null,
  };
}

/// Delivery information for product detail display
class DeliveryInfo {
  final int minDays;
  final int maxDays;
  final bool isInternational;
  final bool hasTracking;
  final String estimateText;
  final String? supplierRegion;

  const DeliveryInfo({
    required this.minDays,
    required this.maxDays,
    required this.isInternational,
    required this.hasTracking,
    required this.estimateText,
    this.supplierRegion,
  });
}

// ============================================================================
// INVENTORY CONFIG MODEL - For flexible inventory management
// ============================================================================

@freezed
abstract class InventoryConfig with _$InventoryConfig {
  const factory InventoryConfig({
    /// Whether inventory is actively managed (false for dropship products)
    @Default(true) bool managed,

    /// Track stock quantity (false = unlimited)
    @Default(true) bool trackQuantity,

    /// Allow orders when out of stock
    @Default(false) bool allowBackorder,

    /// Alert threshold for low stock
    @Default(5) int lowStockThreshold,

    /// When the last low-stock alert was sent
    DateTime? lastLowStockAlertAt,

    /// How long to hold inventory during checkout (minutes)
    @Default(30) int reservationHoldMinutes,
  }) = _InventoryConfig;

  factory InventoryConfig.fromJson(Map<String, dynamic> json) => _$InventoryConfigFromJson(json);
}

// ============================================================================
// PRODUCT MODEL
// ============================================================================

@Freezed(toJson: true, fromJson: true)
abstract class Product with _$Product {
  const factory Product({
    required String productId,
    required String name,
    String? nameF,
    required double price,
    int? priceCents,

    /// Original/crossed-out price for discount display (null = no sale, must be > price)
    double? compareAtPrice,
    required String description,
    String? descriptionF,
    required List<String> imageUrls,
    String? videoUrl,
    int? videoDurationSeconds,
    required String sellerId,
    String? madeInCountry,
    // sellerAddress is optional — products with warehouses use warehouseIds instead
    Address? sellerAddress,
    required int categoryId,
    required int stockQuantity,
    @Default(0.0) double rating,
    @Default(0) int ratingCount,
    required DateTime createdAt,
    // Single lifecycle state replacing isActive + status + approvalStatus
    @Default(ProductLifecycleStatusValues.draft) String lifecycleStatus,
    // Optional shipping metadata
    double? weightKg,
    String? weightUnit,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    String? dimensionUnit,
    // Delivery options
    @Default(false) bool isLocalDeliveryOnly,
    @Default(false) bool isPerishable,
    @Default(3) int estimatedShipDays,
    @Default([]) List<SellerDeliveryOption> deliveryOptions,
    @Default(1) int minimumOrderQuantity,
    @Default(false) bool freeShipping,
    // Digital product flag
    @Default(false) bool isDigital,
    // Age restriction flag — requires buyer age confirmation at checkout
    @Default(false) bool isAgeRestricted,
    String? digitalType,
    String? slug,
    Map<String, String>? digitalBuilds,
    // bookSourceUrl intentionally NOT included — buyer-protected: written by seller, never returned to client
    int? deviceLimit,
    // Tax and metadata
    String? taxCode,
    @Default([]) List<String> keywords,
    // Admin rejection reason
    String? approvalRejectionReason,
    // Flat supplier fields (used when supplier object is not provided)
    double? cost,
    String? supplierSku,
    String? supplierUrl,
    // Structured objects for scalability
    /// Supplier information for dropshipping/marketplace products
    SupplierInfo? supplier,

    /// Inventory management configuration
    InventoryConfig? inventory,

    // Multi-warehouse support
    /// Seller's unique product identifier — enforced unique per seller at write time
    String? sellerSku,

    /// IDs of seller warehouses this product ships from
    List<String>? warehouseIds,

    /// City of primary shipping warehouse (denormalized for O(1) card rendering)
    String? shipFromCity,

    /// Province code of primary warehouse (denormalized for O(1) card rendering)
    String? shipFromProvince,

    /// Country of primary warehouse (denormalized for O(1) card rendering)
    String? shipFromCountry,

    List<String>? shipFromCountries,

    // === TRENDING & ENGAGEMENT ===
    @Default(0) int trendingScore,
    @Default(0) int viewCount,
    @Default(0) int purchaseCount,
    @Default(false) bool isTrending,
    DateTime? trendingAt,

    // === N-09: Product Variants ===
    /// Whether this product has variants (size, color, etc.)
    @Default(false) bool hasVariants,

    /// List of variant objects
    @Default([]) List<ProductVariant> variants,

    /// Variant option definitions
    @Default([]) List<VariantOption> variantOptions,

    // === N-11: Subcategories ===
    /// Optional subcategory within the main category
    String? subcategory,

    /// Product condition: new, like_new, good, fair, for_parts
    String? condition,

    /// Per-warehouse stock allocation map: {warehouseId: stockQty}
    /// Sum of values equals stockQuantity. Used for multi-warehouse inventory routing.
    Map<String, int>? warehouseStockMap,

    /// Server-controlled last-updated timestamp
    DateTime? updatedAt,
  }) = _Product;

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final rawCreatedAt = data[Fields.createdAt];
    final DateTime parsedCreatedAt = switch (rawCreatedAt) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      String s => DateTime.tryParse(s) ?? DateTime.now(),
      _ => DateTime.now(),
    };

    final rawUpdatedAt = data[Fields.updatedAt];
    final DateTime? parsedUpdatedAt = switch (rawUpdatedAt) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      String s => DateTime.tryParse(s),
      _ => null,
    };

    final jsonMap = <String, dynamic>{
      ...data,
      'productId': doc.id,
      'createdAt': parsedCreatedAt.toIso8601String(),
      if (parsedUpdatedAt != null) 'updatedAt': parsedUpdatedAt.toIso8601String(),
    };
    return Product.fromJson(jsonMap);
  }

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
}

// ============================================================================
// PRODUCT CREATE MODEL
// ============================================================================

@freezed
abstract class ProductCreate with _$ProductCreate {
  const factory ProductCreate({
    required String name,
    String? nameF,
    required double price,

    /// Original/crossed-out price for discount display (null = no sale, must be > price)
    double? compareAtPrice,
    required String description,
    String? descriptionF,
    required List<String> imageUrls,
    String? videoUrl,
    required String sellerId,
    // sellerAddress is optional — required only when warehouseIds is not provided
    Address? sellerAddress,
    required int categoryId,
    required int stockQuantity,
    @Default(0.0) double rating,
    @Default(ProductLifecycleStatusValues.draft) String lifecycleStatus,
    double? weightKg,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    @Default(false) bool isLocalDeliveryOnly,
    @Default(false) bool isPerishable,
    @Default(3) int estimatedShipDays,
    @Default([]) List<SellerDeliveryOption> deliveryOptions,
    @Default(1) int minimumOrderQuantity,
    @Default(false) bool freeShipping,
    @Default(false) bool isDigital,
    String? digitalType,
    String? slug,
    Map<String, String>? digitalBuilds,
    // bookSourceUrl intentionally NOT included — buyer-protected: written by seller, never returned to client
    int? deviceLimit,
    String? taxCode,
    @Default([]) List<String> keywords,
    // lifecycleStatus intentionally defaults to draft — backend sets under_review on creation
    // Flat supplier fields (used when supplier object is not provided)
    double? cost,
    String? supplierSku,
    String? supplierUrl,
    // Structured objects
    SupplierInfo? supplier,
    InventoryConfig? inventory,
    // Multi-warehouse support
    String? sellerSku,
    List<String>? warehouseIds,
    String? shipFromCity,
    String? shipFromProvince,
    String? shipFromCountry,
    List<String>? shipFromCountries,

    // === N-09: Product Variants ===
    @Default(false) bool hasVariants,
    @Default([]) List<ProductVariant> variants,
    @Default([]) List<VariantOption> variantOptions,
    // === N-11: Subcategories ===
    String? subcategory,
    }) = _ProductCreate;

  factory ProductCreate.fromJson(Map<String, dynamic> json) => _$ProductCreateFromJson(json);
}

// ============================================================================
// VARIANT OPTION MODEL
// ============================================================================

@freezed
abstract class VariantOption with _$VariantOption {
  const factory VariantOption({
    required String name,
    required List<String> values,
  }) = _VariantOption;

  factory VariantOption.fromJson(Map<String, dynamic> json) => _$VariantOptionFromJson(json);
}

// ============================================================================
// PRODUCT VARIANT MODEL
// ============================================================================

@freezed
abstract class ProductVariant with _$ProductVariant {
  const factory ProductVariant({
    @Default('') String variantId,
    required Map<String, String> optionValues,
    int? priceCents,
    required int stockQuantity,
    String? sku,
    @Default(true) bool isActive,
  }) = _ProductVariant;

  factory ProductVariant.fromJson(Map<String, dynamic> json) => _$ProductVariantFromJson(json);
}

// ============================================================================
// DELIVERY INFO - Structured delivery information for UI display
// ============================================================================

// ============================================================================
// PRODUCT QUESTION MODEL — TASK 09 Q&A
// ============================================================================

@freezed
abstract class ProductQuestion with _$ProductQuestion {
  const factory ProductQuestion({
    required String questionId,
    required String productId,
    required String sellerId,
    required String askerId,
    required String question,
    String? answer,
    DateTime? answeredAt,
    String? answeredBy,
    @Default(false) bool isAnswered,
    @Default(0) int upvotes,
    required DateTime createdAt,
  }) = _ProductQuestion;

  factory ProductQuestion.fromJson(Map<String, dynamic> json) => _$ProductQuestionFromJson(json);
}

// ============================================================================
// SELLER DELIVERY OPTION
// ============================================================================

@freezed
abstract class SellerDeliveryOption with _$SellerDeliveryOption {
  const factory SellerDeliveryOption({
    /// Delivery type: 'standard', 'express', 'same_day', etc.
    @Default(DeliveryTypeValues.standard) String type,

    /// Human-readable description
    @Default('') String description,

    /// Shipping cost in dollars
    @Default(0) int costCents,

    /// Estimated delivery days
    @Default(3) int estimatedDays,

    /// Optional quantity-based discounts for this delivery option
    @Default([]) List<ShippingQuantityDiscount> quantityDiscounts,

    /// Maximum items before shipping cost increases (0 = no limit)
    @Default(0) int maxItemsPerShipment,

    /// Additional cost per item after maxItemsPerShipment (0 = free per-item)
    @Default(0) int additionalItemCostCents,

    /// Whether this option is available for international orders
    @Default(true) bool availableNationwide,
  }) = _SellerDeliveryOption;

  factory SellerDeliveryOption.fromJson(Map<String, dynamic> json) => _$SellerDeliveryOptionFromJson(json);
}

// ============================================================================
// SELLER WAREHOUSE MODEL
// ============================================================================

@Freezed(toJson: true, fromJson: true)
abstract class SellerWarehouse with _$SellerWarehouse {
  const factory SellerWarehouse({
    required String warehouseId,

    /// Display name, e.g. 'Toronto Warehouse' or 'Home Office'
    required String label,

    /// Location type: 'warehouse' | 'personal'
    @Default('warehouse') String type,

    /// Physical address of this location
    required Address address,

    /// Whether this is the seller's default shipping origin
    @Default(false) bool isDefault,

    DateTime? createdAt,
  }) = _SellerWarehouse;

  factory SellerWarehouse.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawCreatedAt = data['createdAt'];
    final String? parsedCreatedAt = switch (rawCreatedAt) {
      Timestamp t => t.toDate().toIso8601String(),
      DateTime d => d.toIso8601String(),
      String s => s,
      _ => null,
    };
    return SellerWarehouse.fromJson({
      ...data,
      'warehouseId': doc.id,
      // ignore: use_null_aware_elements — key is a string literal so ?key: value is invalid
      if (parsedCreatedAt != null) 'createdAt': parsedCreatedAt,
    });
  }

  factory SellerWarehouse.fromJson(Map<String, dynamic> json) => _$SellerWarehouseFromJson(json);
}

// ============================================================================
// SHIPPING QUANTITY DISCOUNT - Volume-based shipping discounts
// ============================================================================

@freezed
abstract class ShippingQuantityDiscount with _$ShippingQuantityDiscount {
  const factory ShippingQuantityDiscount({
    /// Minimum quantity to qualify for this discount
    required int minQuantity,

    /// Discount type: 'percent' (e.g., 10% off), 'fixed' (e.g., $2 off), 'flat_rate' (e.g., $5 flat)
    @Default(DiscountTypeValues.percent) String discountType,

    /// Discount value (interpretation depends on discountType)
    required double discountValue,

    /// Optional label for display (e.g., "Bulk Shipping Discount")
    String? label,
  }) = _ShippingQuantityDiscount;

  factory ShippingQuantityDiscount.fromJson(Map<String, dynamic> json) => _$ShippingQuantityDiscountFromJson(json);
}

// ============================================================================
// SUPPLIER INFO MODEL - For dropshipping/marketplace products
// ============================================================================

@freezed
abstract class SupplierInfo with _$SupplierInfo {
  const factory SupplierInfo({
    /// Supplier platform type: aliexpress, dhgate, alibaba, 1688, temu, cjdropshipping, other
    required String type,

    /// Supplier's SKU/Product ID
    String? supplierSku,

    /// Direct URL to supplier product page
    String? supplierUrl,

    /// Cost price from supplier
    double? cost,

    /// Currency of supplier cost price (supplier's currency, NOT selling currency).
    /// Selling price is always CAD. This tracks the supplier's original currency.
    @Default('USD') String currency,

    /// Estimated shipping days range (e.g., '7-15')
    String? shippingDays,

    /// Whether supplier provides tracking
    @Default(false) bool hasTracking,

    /// Internal notes about this supplier/product
    String? notes,
  }) = _SupplierInfo;

  factory SupplierInfo.fromJson(Map<String, dynamic> json) => _$SupplierInfoFromJson(json);
}

// ============================================================================
// PRODUCT EXTENSION - Helper getters
// ============================================================================

extension ProductExtension on Product {
  /// Check if product allows backorders
  bool get allowsBackorder => inventory?.allowBackorder ?? false;

  /// Get human-readable delivery estimate string
  String get deliveryEstimateText {
    final range = estimatedDeliveryDays;
    if (isDigital) return 'Instant delivery';
    if (isLocalDeliveryOnly) return '1-3 business days (local)';
    return '${range.minDays}-${range.maxDays} business days';
  }

  /// Get delivery info for buyers
  DeliveryInfo get deliveryInfo {
    return DeliveryInfo(
      minDays: estimatedDeliveryDays.minDays,
      maxDays: estimatedDeliveryDays.maxDays,
      isInternational: isInternationalSupplier,
      hasTracking: supplier?.hasTracking ?? !isInternationalSupplier,
      estimateText: deliveryEstimateText,
      supplierRegion: isInternationalSupplier
          ? _getSupplierRegion(supplier?.type)
          : '${sellerAddress?.city ?? shipFromCity ?? 'Unknown'}, ${sellerAddress?.state ?? shipFromProvince ?? ''}',
    );
  }

  /// Get effective cost (from supplier object or flat field)
  double? get effectiveCost => supplier?.cost ?? cost;

  /// Get effective supplier SKU (from supplier object or flat field)
  String? get effectiveSupplierSku => supplier?.supplierSku ?? supplierSku;

  /// Get effective supplier URL (from supplier object or flat field)
  String? get effectiveSupplierUrl => supplier?.supplierUrl ?? supplierUrl;

  /// Get estimated delivery days range for buyers
  /// Returns a record (minDays, maxDays) based on supplier type
  ({int minDays, int maxDays}) get estimatedDeliveryDays {
    final supplierType = supplier?.type;

    // If supplier has explicit shipping days, parse that
    final shippingDays = supplier?.shippingDays;
    if (shippingDays != null && shippingDays.contains('-')) {
      final parts = shippingDays.split('-');
      if (parts.length >= 2) {
        final min = int.tryParse(parts[0].trim()) ?? 7;
        final max = int.tryParse(parts[1].trim()) ?? 21;
        return (minDays: min, maxDays: max);
      }
    }

    // Otherwise use supplier type defaults
    return _getDeliveryRangeForSupplier(supplierType);
  }

  /// Check if product is from international supplier
  bool get isInternationalSupplier {
    final type = supplier?.type;
    return type != null && _internationalSupplierTypes.contains(type);
  }

  /// Check if inventory tracking is active
  bool get isInventoryManaged => inventory?.managed ?? true;

  /// Check if stock is low
  bool get isLowStock {
    final threshold = inventory?.lowStockThreshold ?? 5;
    return stockQuantity <= threshold && stockQuantity > 0;
  }

  /// Calculate profit margin percentage
  double? get marginPercent {
    final c = effectiveCost;
    if (c == null || c <= 0) return null;
    return ((price - c) / price) * 100;
  }

  /// Calculate profit amount
  double? get profit {
    final c = effectiveCost;
    if (c == null) return null;
    return price - c;
  }
}

/// Extension for calculating shipping cost with quantity discounts
extension SellerDeliveryOptionExtension on SellerDeliveryOption {
  /// Calculate the effective shipping cost for a given quantity
  double calculateCostForQuantity(int quantity) {
    if (quantity <= 0) return costCents / 100.0;

    // Find the best applicable discount
    ShippingQuantityDiscount? bestDiscount;
    for (final discount in quantityDiscounts) {
      if (quantity >= discount.minQuantity) {
        if (bestDiscount == null || discount.minQuantity > bestDiscount.minQuantity) {
          bestDiscount = discount;
        }
      }
    }

    double baseCost = costCents / 100.0;

    // Apply per-item costs if applicable
    if (maxItemsPerShipment > 0 && quantity > maxItemsPerShipment) {
      final extraItems = quantity - maxItemsPerShipment;
      baseCost += extraItems * (additionalItemCostCents / 100.0);
    }

    // Apply quantity discount
    if (bestDiscount != null) {
      switch (bestDiscount.discountType) {
        case DiscountTypeValues.percent:
          return baseCost * (1 - bestDiscount.discountValue / 100);
        case DiscountTypeValues.fixed:
          return (baseCost - bestDiscount.discountValue).clamp(0, double.infinity);
        case DiscountTypeValues.flatRate:
          return bestDiscount.discountValue;
        default:
          return baseCost;
      }
    }

    return baseCost;
  }

  /// Get discount description for a given quantity
  String? getDiscountDescriptionForQuantity(int quantity) {
    for (final discount in quantityDiscounts) {
      if (quantity >= discount.minQuantity) {
        if (discount.label != null) return discount.label;
        switch (discount.discountType) {
          case DiscountTypeValues.percent:
            return '${discount.discountValue.toStringAsFixed(0)}% off shipping for ${discount.minQuantity}+ items';
          case DiscountTypeValues.fixed:
            return '\$${discount.discountValue.toStringAsFixed(2)} off shipping for ${discount.minQuantity}+ items';
          case DiscountTypeValues.flatRate:
            return 'Flat \$${discount.discountValue.toStringAsFixed(2)} shipping for ${discount.minQuantity}+ items';
        }
      }
    }
    return null;
  }
}

extension SellerWarehouseExtension on SellerWarehouse {
  String get cityProvince => '${address.city}, ${address.state}';
  bool get isPersonal => type == WarehouseTypeValues.personal;
  bool get isWarehouse => type == WarehouseTypeValues.warehouse;
  String get typeLabel => isWarehouse ? 'Warehouse' : 'Personal Address';
}
