// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InventoryConfig {

/// Whether inventory is actively managed (false for dropship products)
 bool get managed;/// Track stock quantity (false = unlimited)
 bool get trackQuantity;/// Allow orders when out of stock
 bool get allowBackorder;/// Alert threshold for low stock
 int get lowStockThreshold;/// When the last low-stock alert was sent
 DateTime? get lastLowStockAlertAt;/// How long to hold inventory during checkout (minutes)
 int get reservationHoldMinutes;
/// Create a copy of InventoryConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryConfigCopyWith<InventoryConfig> get copyWith => _$InventoryConfigCopyWithImpl<InventoryConfig>(this as InventoryConfig, _$identity);

  /// Serializes this InventoryConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryConfig&&(identical(other.managed, managed) || other.managed == managed)&&(identical(other.trackQuantity, trackQuantity) || other.trackQuantity == trackQuantity)&&(identical(other.allowBackorder, allowBackorder) || other.allowBackorder == allowBackorder)&&(identical(other.lowStockThreshold, lowStockThreshold) || other.lowStockThreshold == lowStockThreshold)&&(identical(other.lastLowStockAlertAt, lastLowStockAlertAt) || other.lastLowStockAlertAt == lastLowStockAlertAt)&&(identical(other.reservationHoldMinutes, reservationHoldMinutes) || other.reservationHoldMinutes == reservationHoldMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,managed,trackQuantity,allowBackorder,lowStockThreshold,lastLowStockAlertAt,reservationHoldMinutes);

@override
String toString() {
  return 'InventoryConfig(managed: $managed, trackQuantity: $trackQuantity, allowBackorder: $allowBackorder, lowStockThreshold: $lowStockThreshold, lastLowStockAlertAt: $lastLowStockAlertAt, reservationHoldMinutes: $reservationHoldMinutes)';
}


}

/// @nodoc
abstract mixin class $InventoryConfigCopyWith<$Res>  {
  factory $InventoryConfigCopyWith(InventoryConfig value, $Res Function(InventoryConfig) _then) = _$InventoryConfigCopyWithImpl;
@useResult
$Res call({
 bool managed, bool trackQuantity, bool allowBackorder, int lowStockThreshold, DateTime? lastLowStockAlertAt, int reservationHoldMinutes
});




}
/// @nodoc
class _$InventoryConfigCopyWithImpl<$Res>
    implements $InventoryConfigCopyWith<$Res> {
  _$InventoryConfigCopyWithImpl(this._self, this._then);

  final InventoryConfig _self;
  final $Res Function(InventoryConfig) _then;

/// Create a copy of InventoryConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? managed = null,Object? trackQuantity = null,Object? allowBackorder = null,Object? lowStockThreshold = null,Object? lastLowStockAlertAt = freezed,Object? reservationHoldMinutes = null,}) {
  return _then(_self.copyWith(
managed: null == managed ? _self.managed : managed // ignore: cast_nullable_to_non_nullable
as bool,trackQuantity: null == trackQuantity ? _self.trackQuantity : trackQuantity // ignore: cast_nullable_to_non_nullable
as bool,allowBackorder: null == allowBackorder ? _self.allowBackorder : allowBackorder // ignore: cast_nullable_to_non_nullable
as bool,lowStockThreshold: null == lowStockThreshold ? _self.lowStockThreshold : lowStockThreshold // ignore: cast_nullable_to_non_nullable
as int,lastLowStockAlertAt: freezed == lastLowStockAlertAt ? _self.lastLowStockAlertAt : lastLowStockAlertAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reservationHoldMinutes: null == reservationHoldMinutes ? _self.reservationHoldMinutes : reservationHoldMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InventoryConfig].
extension InventoryConfigPatterns on InventoryConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventoryConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventoryConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventoryConfig value)  $default,){
final _that = this;
switch (_that) {
case _InventoryConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventoryConfig value)?  $default,){
final _that = this;
switch (_that) {
case _InventoryConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool managed,  bool trackQuantity,  bool allowBackorder,  int lowStockThreshold,  DateTime? lastLowStockAlertAt,  int reservationHoldMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryConfig() when $default != null:
return $default(_that.managed,_that.trackQuantity,_that.allowBackorder,_that.lowStockThreshold,_that.lastLowStockAlertAt,_that.reservationHoldMinutes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool managed,  bool trackQuantity,  bool allowBackorder,  int lowStockThreshold,  DateTime? lastLowStockAlertAt,  int reservationHoldMinutes)  $default,) {final _that = this;
switch (_that) {
case _InventoryConfig():
return $default(_that.managed,_that.trackQuantity,_that.allowBackorder,_that.lowStockThreshold,_that.lastLowStockAlertAt,_that.reservationHoldMinutes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool managed,  bool trackQuantity,  bool allowBackorder,  int lowStockThreshold,  DateTime? lastLowStockAlertAt,  int reservationHoldMinutes)?  $default,) {final _that = this;
switch (_that) {
case _InventoryConfig() when $default != null:
return $default(_that.managed,_that.trackQuantity,_that.allowBackorder,_that.lowStockThreshold,_that.lastLowStockAlertAt,_that.reservationHoldMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventoryConfig implements InventoryConfig {
  const _InventoryConfig({this.managed = true, this.trackQuantity = true, this.allowBackorder = false, this.lowStockThreshold = 5, this.lastLowStockAlertAt, this.reservationHoldMinutes = 30});
  factory _InventoryConfig.fromJson(Map<String, dynamic> json) => _$InventoryConfigFromJson(json);

/// Whether inventory is actively managed (false for dropship products)
@override@JsonKey() final  bool managed;
/// Track stock quantity (false = unlimited)
@override@JsonKey() final  bool trackQuantity;
/// Allow orders when out of stock
@override@JsonKey() final  bool allowBackorder;
/// Alert threshold for low stock
@override@JsonKey() final  int lowStockThreshold;
/// When the last low-stock alert was sent
@override final  DateTime? lastLowStockAlertAt;
/// How long to hold inventory during checkout (minutes)
@override@JsonKey() final  int reservationHoldMinutes;

/// Create a copy of InventoryConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventoryConfigCopyWith<_InventoryConfig> get copyWith => __$InventoryConfigCopyWithImpl<_InventoryConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InventoryConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryConfig&&(identical(other.managed, managed) || other.managed == managed)&&(identical(other.trackQuantity, trackQuantity) || other.trackQuantity == trackQuantity)&&(identical(other.allowBackorder, allowBackorder) || other.allowBackorder == allowBackorder)&&(identical(other.lowStockThreshold, lowStockThreshold) || other.lowStockThreshold == lowStockThreshold)&&(identical(other.lastLowStockAlertAt, lastLowStockAlertAt) || other.lastLowStockAlertAt == lastLowStockAlertAt)&&(identical(other.reservationHoldMinutes, reservationHoldMinutes) || other.reservationHoldMinutes == reservationHoldMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,managed,trackQuantity,allowBackorder,lowStockThreshold,lastLowStockAlertAt,reservationHoldMinutes);

@override
String toString() {
  return 'InventoryConfig(managed: $managed, trackQuantity: $trackQuantity, allowBackorder: $allowBackorder, lowStockThreshold: $lowStockThreshold, lastLowStockAlertAt: $lastLowStockAlertAt, reservationHoldMinutes: $reservationHoldMinutes)';
}


}

/// @nodoc
abstract mixin class _$InventoryConfigCopyWith<$Res> implements $InventoryConfigCopyWith<$Res> {
  factory _$InventoryConfigCopyWith(_InventoryConfig value, $Res Function(_InventoryConfig) _then) = __$InventoryConfigCopyWithImpl;
@override @useResult
$Res call({
 bool managed, bool trackQuantity, bool allowBackorder, int lowStockThreshold, DateTime? lastLowStockAlertAt, int reservationHoldMinutes
});




}
/// @nodoc
class __$InventoryConfigCopyWithImpl<$Res>
    implements _$InventoryConfigCopyWith<$Res> {
  __$InventoryConfigCopyWithImpl(this._self, this._then);

  final _InventoryConfig _self;
  final $Res Function(_InventoryConfig) _then;

/// Create a copy of InventoryConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? managed = null,Object? trackQuantity = null,Object? allowBackorder = null,Object? lowStockThreshold = null,Object? lastLowStockAlertAt = freezed,Object? reservationHoldMinutes = null,}) {
  return _then(_InventoryConfig(
managed: null == managed ? _self.managed : managed // ignore: cast_nullable_to_non_nullable
as bool,trackQuantity: null == trackQuantity ? _self.trackQuantity : trackQuantity // ignore: cast_nullable_to_non_nullable
as bool,allowBackorder: null == allowBackorder ? _self.allowBackorder : allowBackorder // ignore: cast_nullable_to_non_nullable
as bool,lowStockThreshold: null == lowStockThreshold ? _self.lowStockThreshold : lowStockThreshold // ignore: cast_nullable_to_non_nullable
as int,lastLowStockAlertAt: freezed == lastLowStockAlertAt ? _self.lastLowStockAlertAt : lastLowStockAlertAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reservationHoldMinutes: null == reservationHoldMinutes ? _self.reservationHoldMinutes : reservationHoldMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Product {

 String get productId; String get name; String? get nameF; double get price; int? get priceCents;/// Original/crossed-out price for discount display (null = no sale, must be > price)
 double? get compareAtPrice; String get description; String? get descriptionF; List<String> get imageUrls; String? get videoUrl; int? get videoDurationSeconds; String get sellerId; String? get madeInCountry;// sellerAddress is optional — products with warehouses use warehouseIds instead
 Address? get sellerAddress; int get categoryId; int get stockQuantity; double get rating; int get ratingCount; DateTime get createdAt;// Single lifecycle state replacing isActive + status + approvalStatus
 String get lifecycleStatus;// Optional shipping metadata
 double? get weightKg; String? get weightUnit; double? get lengthCm; double? get widthCm; double? get heightCm; String? get dimensionUnit;// Delivery options
 bool get isLocalDeliveryOnly; bool get isPerishable; int get estimatedShipDays; List<SellerDeliveryOption> get deliveryOptions; int get minimumOrderQuantity; bool get freeShipping;// Digital product flag
 bool get isDigital;// Age restriction flag — requires buyer age confirmation at checkout
 bool get isAgeRestricted; String? get digitalType; String? get slug; Map<String, String>? get digitalBuilds;// bookSourceUrl intentionally NOT included — buyer-protected: written by seller, never returned to client
 int? get deviceLimit;// Tax and metadata
 String? get taxCode; List<String> get keywords;// Admin rejection reason
 String? get approvalRejectionReason;// Flat supplier fields (used when supplier object is not provided)
 double? get cost; String? get supplierSku; String? get supplierUrl;// Structured objects for scalability
/// Supplier information for dropshipping/marketplace products
 SupplierInfo? get supplier;/// Inventory management configuration
 InventoryConfig? get inventory;// Multi-warehouse support
/// Seller's unique product identifier — enforced unique per seller at write time
 String? get sellerSku;/// IDs of seller warehouses this product ships from
 List<String>? get warehouseIds;/// City of primary shipping warehouse (denormalized for O(1) card rendering)
 String? get shipFromCity;/// Province code of primary warehouse (denormalized for O(1) card rendering)
 String? get shipFromProvince;/// Country of primary warehouse (denormalized for O(1) card rendering)
 String? get shipFromCountry; List<String>? get shipFromCountries;// === TRENDING & ENGAGEMENT ===
 int get trendingScore; int get viewCount; int get purchaseCount; bool get isTrending; DateTime? get trendingAt;// === N-09: Product Variants ===
/// Whether this product has variants (size, color, etc.)
 bool get hasVariants;/// List of variant objects
 List<ProductVariant> get variants;/// Variant option definitions
 List<VariantOption> get variantOptions;// === N-11: Subcategories ===
/// Optional subcategory within the main category
 String? get subcategory;/// Product condition: new, like_new, good, fair, for_parts
 String? get condition;/// Per-warehouse stock allocation map: {warehouseId: stockQty}
/// Sum of values equals stockQuantity. Used for multi-warehouse inventory routing.
 Map<String, int>? get warehouseStockMap;/// Server-controlled last-updated timestamp
 DateTime? get updatedAt;
/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductCopyWith<Product> get copyWith => _$ProductCopyWithImpl<Product>(this as Product, _$identity);

  /// Serializes this Product to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Product&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.name, name) || other.name == name)&&(identical(other.nameF, nameF) || other.nameF == nameF)&&(identical(other.price, price) || other.price == price)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.compareAtPrice, compareAtPrice) || other.compareAtPrice == compareAtPrice)&&(identical(other.description, description) || other.description == description)&&(identical(other.descriptionF, descriptionF) || other.descriptionF == descriptionF)&&const DeepCollectionEquality().equals(other.imageUrls, imageUrls)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.videoDurationSeconds, videoDurationSeconds) || other.videoDurationSeconds == videoDurationSeconds)&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.madeInCountry, madeInCountry) || other.madeInCountry == madeInCountry)&&(identical(other.sellerAddress, sellerAddress) || other.sellerAddress == sellerAddress)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.ratingCount, ratingCount) || other.ratingCount == ratingCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lifecycleStatus, lifecycleStatus) || other.lifecycleStatus == lifecycleStatus)&&(identical(other.weightKg, weightKg) || other.weightKg == weightKg)&&(identical(other.weightUnit, weightUnit) || other.weightUnit == weightUnit)&&(identical(other.lengthCm, lengthCm) || other.lengthCm == lengthCm)&&(identical(other.widthCm, widthCm) || other.widthCm == widthCm)&&(identical(other.heightCm, heightCm) || other.heightCm == heightCm)&&(identical(other.dimensionUnit, dimensionUnit) || other.dimensionUnit == dimensionUnit)&&(identical(other.isLocalDeliveryOnly, isLocalDeliveryOnly) || other.isLocalDeliveryOnly == isLocalDeliveryOnly)&&(identical(other.isPerishable, isPerishable) || other.isPerishable == isPerishable)&&(identical(other.estimatedShipDays, estimatedShipDays) || other.estimatedShipDays == estimatedShipDays)&&const DeepCollectionEquality().equals(other.deliveryOptions, deliveryOptions)&&(identical(other.minimumOrderQuantity, minimumOrderQuantity) || other.minimumOrderQuantity == minimumOrderQuantity)&&(identical(other.freeShipping, freeShipping) || other.freeShipping == freeShipping)&&(identical(other.isDigital, isDigital) || other.isDigital == isDigital)&&(identical(other.isAgeRestricted, isAgeRestricted) || other.isAgeRestricted == isAgeRestricted)&&(identical(other.digitalType, digitalType) || other.digitalType == digitalType)&&(identical(other.slug, slug) || other.slug == slug)&&const DeepCollectionEquality().equals(other.digitalBuilds, digitalBuilds)&&(identical(other.deviceLimit, deviceLimit) || other.deviceLimit == deviceLimit)&&(identical(other.taxCode, taxCode) || other.taxCode == taxCode)&&const DeepCollectionEquality().equals(other.keywords, keywords)&&(identical(other.approvalRejectionReason, approvalRejectionReason) || other.approvalRejectionReason == approvalRejectionReason)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.supplierSku, supplierSku) || other.supplierSku == supplierSku)&&(identical(other.supplierUrl, supplierUrl) || other.supplierUrl == supplierUrl)&&(identical(other.supplier, supplier) || other.supplier == supplier)&&(identical(other.inventory, inventory) || other.inventory == inventory)&&(identical(other.sellerSku, sellerSku) || other.sellerSku == sellerSku)&&const DeepCollectionEquality().equals(other.warehouseIds, warehouseIds)&&(identical(other.shipFromCity, shipFromCity) || other.shipFromCity == shipFromCity)&&(identical(other.shipFromProvince, shipFromProvince) || other.shipFromProvince == shipFromProvince)&&(identical(other.shipFromCountry, shipFromCountry) || other.shipFromCountry == shipFromCountry)&&const DeepCollectionEquality().equals(other.shipFromCountries, shipFromCountries)&&(identical(other.trendingScore, trendingScore) || other.trendingScore == trendingScore)&&(identical(other.viewCount, viewCount) || other.viewCount == viewCount)&&(identical(other.purchaseCount, purchaseCount) || other.purchaseCount == purchaseCount)&&(identical(other.isTrending, isTrending) || other.isTrending == isTrending)&&(identical(other.trendingAt, trendingAt) || other.trendingAt == trendingAt)&&(identical(other.hasVariants, hasVariants) || other.hasVariants == hasVariants)&&const DeepCollectionEquality().equals(other.variants, variants)&&const DeepCollectionEquality().equals(other.variantOptions, variantOptions)&&(identical(other.subcategory, subcategory) || other.subcategory == subcategory)&&(identical(other.condition, condition) || other.condition == condition)&&const DeepCollectionEquality().equals(other.warehouseStockMap, warehouseStockMap)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,productId,name,nameF,price,priceCents,compareAtPrice,description,descriptionF,const DeepCollectionEquality().hash(imageUrls),videoUrl,videoDurationSeconds,sellerId,madeInCountry,sellerAddress,categoryId,stockQuantity,rating,ratingCount,createdAt,lifecycleStatus,weightKg,weightUnit,lengthCm,widthCm,heightCm,dimensionUnit,isLocalDeliveryOnly,isPerishable,estimatedShipDays,const DeepCollectionEquality().hash(deliveryOptions),minimumOrderQuantity,freeShipping,isDigital,isAgeRestricted,digitalType,slug,const DeepCollectionEquality().hash(digitalBuilds),deviceLimit,taxCode,const DeepCollectionEquality().hash(keywords),approvalRejectionReason,cost,supplierSku,supplierUrl,supplier,inventory,sellerSku,const DeepCollectionEquality().hash(warehouseIds),shipFromCity,shipFromProvince,shipFromCountry,const DeepCollectionEquality().hash(shipFromCountries),trendingScore,viewCount,purchaseCount,isTrending,trendingAt,hasVariants,const DeepCollectionEquality().hash(variants),const DeepCollectionEquality().hash(variantOptions),subcategory,condition,const DeepCollectionEquality().hash(warehouseStockMap),updatedAt]);

@override
String toString() {
  return 'Product(productId: $productId, name: $name, nameF: $nameF, price: $price, priceCents: $priceCents, compareAtPrice: $compareAtPrice, description: $description, descriptionF: $descriptionF, imageUrls: $imageUrls, videoUrl: $videoUrl, videoDurationSeconds: $videoDurationSeconds, sellerId: $sellerId, madeInCountry: $madeInCountry, sellerAddress: $sellerAddress, categoryId: $categoryId, stockQuantity: $stockQuantity, rating: $rating, ratingCount: $ratingCount, createdAt: $createdAt, lifecycleStatus: $lifecycleStatus, weightKg: $weightKg, weightUnit: $weightUnit, lengthCm: $lengthCm, widthCm: $widthCm, heightCm: $heightCm, dimensionUnit: $dimensionUnit, isLocalDeliveryOnly: $isLocalDeliveryOnly, isPerishable: $isPerishable, estimatedShipDays: $estimatedShipDays, deliveryOptions: $deliveryOptions, minimumOrderQuantity: $minimumOrderQuantity, freeShipping: $freeShipping, isDigital: $isDigital, isAgeRestricted: $isAgeRestricted, digitalType: $digitalType, slug: $slug, digitalBuilds: $digitalBuilds, deviceLimit: $deviceLimit, taxCode: $taxCode, keywords: $keywords, approvalRejectionReason: $approvalRejectionReason, cost: $cost, supplierSku: $supplierSku, supplierUrl: $supplierUrl, supplier: $supplier, inventory: $inventory, sellerSku: $sellerSku, warehouseIds: $warehouseIds, shipFromCity: $shipFromCity, shipFromProvince: $shipFromProvince, shipFromCountry: $shipFromCountry, shipFromCountries: $shipFromCountries, trendingScore: $trendingScore, viewCount: $viewCount, purchaseCount: $purchaseCount, isTrending: $isTrending, trendingAt: $trendingAt, hasVariants: $hasVariants, variants: $variants, variantOptions: $variantOptions, subcategory: $subcategory, condition: $condition, warehouseStockMap: $warehouseStockMap, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ProductCopyWith<$Res>  {
  factory $ProductCopyWith(Product value, $Res Function(Product) _then) = _$ProductCopyWithImpl;
@useResult
$Res call({
 String productId, String name, String? nameF, double price, int? priceCents, double? compareAtPrice, String description, String? descriptionF, List<String> imageUrls, String? videoUrl, int? videoDurationSeconds, String sellerId, String? madeInCountry, Address? sellerAddress, int categoryId, int stockQuantity, double rating, int ratingCount, DateTime createdAt, String lifecycleStatus, double? weightKg, String? weightUnit, double? lengthCm, double? widthCm, double? heightCm, String? dimensionUnit, bool isLocalDeliveryOnly, bool isPerishable, int estimatedShipDays, List<SellerDeliveryOption> deliveryOptions, int minimumOrderQuantity, bool freeShipping, bool isDigital, bool isAgeRestricted, String? digitalType, String? slug, Map<String, String>? digitalBuilds, int? deviceLimit, String? taxCode, List<String> keywords, String? approvalRejectionReason, double? cost, String? supplierSku, String? supplierUrl, SupplierInfo? supplier, InventoryConfig? inventory, String? sellerSku, List<String>? warehouseIds, String? shipFromCity, String? shipFromProvince, String? shipFromCountry, List<String>? shipFromCountries, int trendingScore, int viewCount, int purchaseCount, bool isTrending, DateTime? trendingAt, bool hasVariants, List<ProductVariant> variants, List<VariantOption> variantOptions, String? subcategory, String? condition, Map<String, int>? warehouseStockMap, DateTime? updatedAt
});


$AddressCopyWith<$Res>? get sellerAddress;$SupplierInfoCopyWith<$Res>? get supplier;$InventoryConfigCopyWith<$Res>? get inventory;

}
/// @nodoc
class _$ProductCopyWithImpl<$Res>
    implements $ProductCopyWith<$Res> {
  _$ProductCopyWithImpl(this._self, this._then);

  final Product _self;
  final $Res Function(Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? name = null,Object? nameF = freezed,Object? price = null,Object? priceCents = freezed,Object? compareAtPrice = freezed,Object? description = null,Object? descriptionF = freezed,Object? imageUrls = null,Object? videoUrl = freezed,Object? videoDurationSeconds = freezed,Object? sellerId = null,Object? madeInCountry = freezed,Object? sellerAddress = freezed,Object? categoryId = null,Object? stockQuantity = null,Object? rating = null,Object? ratingCount = null,Object? createdAt = null,Object? lifecycleStatus = null,Object? weightKg = freezed,Object? weightUnit = freezed,Object? lengthCm = freezed,Object? widthCm = freezed,Object? heightCm = freezed,Object? dimensionUnit = freezed,Object? isLocalDeliveryOnly = null,Object? isPerishable = null,Object? estimatedShipDays = null,Object? deliveryOptions = null,Object? minimumOrderQuantity = null,Object? freeShipping = null,Object? isDigital = null,Object? isAgeRestricted = null,Object? digitalType = freezed,Object? slug = freezed,Object? digitalBuilds = freezed,Object? deviceLimit = freezed,Object? taxCode = freezed,Object? keywords = null,Object? approvalRejectionReason = freezed,Object? cost = freezed,Object? supplierSku = freezed,Object? supplierUrl = freezed,Object? supplier = freezed,Object? inventory = freezed,Object? sellerSku = freezed,Object? warehouseIds = freezed,Object? shipFromCity = freezed,Object? shipFromProvince = freezed,Object? shipFromCountry = freezed,Object? shipFromCountries = freezed,Object? trendingScore = null,Object? viewCount = null,Object? purchaseCount = null,Object? isTrending = null,Object? trendingAt = freezed,Object? hasVariants = null,Object? variants = null,Object? variantOptions = null,Object? subcategory = freezed,Object? condition = freezed,Object? warehouseStockMap = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameF: freezed == nameF ? _self.nameF : nameF // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,priceCents: freezed == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int?,compareAtPrice: freezed == compareAtPrice ? _self.compareAtPrice : compareAtPrice // ignore: cast_nullable_to_non_nullable
as double?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,descriptionF: freezed == descriptionF ? _self.descriptionF : descriptionF // ignore: cast_nullable_to_non_nullable
as String?,imageUrls: null == imageUrls ? _self.imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,videoUrl: freezed == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String?,videoDurationSeconds: freezed == videoDurationSeconds ? _self.videoDurationSeconds : videoDurationSeconds // ignore: cast_nullable_to_non_nullable
as int?,sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,madeInCountry: freezed == madeInCountry ? _self.madeInCountry : madeInCountry // ignore: cast_nullable_to_non_nullable
as String?,sellerAddress: freezed == sellerAddress ? _self.sellerAddress : sellerAddress // ignore: cast_nullable_to_non_nullable
as Address?,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,ratingCount: null == ratingCount ? _self.ratingCount : ratingCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lifecycleStatus: null == lifecycleStatus ? _self.lifecycleStatus : lifecycleStatus // ignore: cast_nullable_to_non_nullable
as String,weightKg: freezed == weightKg ? _self.weightKg : weightKg // ignore: cast_nullable_to_non_nullable
as double?,weightUnit: freezed == weightUnit ? _self.weightUnit : weightUnit // ignore: cast_nullable_to_non_nullable
as String?,lengthCm: freezed == lengthCm ? _self.lengthCm : lengthCm // ignore: cast_nullable_to_non_nullable
as double?,widthCm: freezed == widthCm ? _self.widthCm : widthCm // ignore: cast_nullable_to_non_nullable
as double?,heightCm: freezed == heightCm ? _self.heightCm : heightCm // ignore: cast_nullable_to_non_nullable
as double?,dimensionUnit: freezed == dimensionUnit ? _self.dimensionUnit : dimensionUnit // ignore: cast_nullable_to_non_nullable
as String?,isLocalDeliveryOnly: null == isLocalDeliveryOnly ? _self.isLocalDeliveryOnly : isLocalDeliveryOnly // ignore: cast_nullable_to_non_nullable
as bool,isPerishable: null == isPerishable ? _self.isPerishable : isPerishable // ignore: cast_nullable_to_non_nullable
as bool,estimatedShipDays: null == estimatedShipDays ? _self.estimatedShipDays : estimatedShipDays // ignore: cast_nullable_to_non_nullable
as int,deliveryOptions: null == deliveryOptions ? _self.deliveryOptions : deliveryOptions // ignore: cast_nullable_to_non_nullable
as List<SellerDeliveryOption>,minimumOrderQuantity: null == minimumOrderQuantity ? _self.minimumOrderQuantity : minimumOrderQuantity // ignore: cast_nullable_to_non_nullable
as int,freeShipping: null == freeShipping ? _self.freeShipping : freeShipping // ignore: cast_nullable_to_non_nullable
as bool,isDigital: null == isDigital ? _self.isDigital : isDigital // ignore: cast_nullable_to_non_nullable
as bool,isAgeRestricted: null == isAgeRestricted ? _self.isAgeRestricted : isAgeRestricted // ignore: cast_nullable_to_non_nullable
as bool,digitalType: freezed == digitalType ? _self.digitalType : digitalType // ignore: cast_nullable_to_non_nullable
as String?,slug: freezed == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String?,digitalBuilds: freezed == digitalBuilds ? _self.digitalBuilds : digitalBuilds // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,deviceLimit: freezed == deviceLimit ? _self.deviceLimit : deviceLimit // ignore: cast_nullable_to_non_nullable
as int?,taxCode: freezed == taxCode ? _self.taxCode : taxCode // ignore: cast_nullable_to_non_nullable
as String?,keywords: null == keywords ? _self.keywords : keywords // ignore: cast_nullable_to_non_nullable
as List<String>,approvalRejectionReason: freezed == approvalRejectionReason ? _self.approvalRejectionReason : approvalRejectionReason // ignore: cast_nullable_to_non_nullable
as String?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,supplierSku: freezed == supplierSku ? _self.supplierSku : supplierSku // ignore: cast_nullable_to_non_nullable
as String?,supplierUrl: freezed == supplierUrl ? _self.supplierUrl : supplierUrl // ignore: cast_nullable_to_non_nullable
as String?,supplier: freezed == supplier ? _self.supplier : supplier // ignore: cast_nullable_to_non_nullable
as SupplierInfo?,inventory: freezed == inventory ? _self.inventory : inventory // ignore: cast_nullable_to_non_nullable
as InventoryConfig?,sellerSku: freezed == sellerSku ? _self.sellerSku : sellerSku // ignore: cast_nullable_to_non_nullable
as String?,warehouseIds: freezed == warehouseIds ? _self.warehouseIds : warehouseIds // ignore: cast_nullable_to_non_nullable
as List<String>?,shipFromCity: freezed == shipFromCity ? _self.shipFromCity : shipFromCity // ignore: cast_nullable_to_non_nullable
as String?,shipFromProvince: freezed == shipFromProvince ? _self.shipFromProvince : shipFromProvince // ignore: cast_nullable_to_non_nullable
as String?,shipFromCountry: freezed == shipFromCountry ? _self.shipFromCountry : shipFromCountry // ignore: cast_nullable_to_non_nullable
as String?,shipFromCountries: freezed == shipFromCountries ? _self.shipFromCountries : shipFromCountries // ignore: cast_nullable_to_non_nullable
as List<String>?,trendingScore: null == trendingScore ? _self.trendingScore : trendingScore // ignore: cast_nullable_to_non_nullable
as int,viewCount: null == viewCount ? _self.viewCount : viewCount // ignore: cast_nullable_to_non_nullable
as int,purchaseCount: null == purchaseCount ? _self.purchaseCount : purchaseCount // ignore: cast_nullable_to_non_nullable
as int,isTrending: null == isTrending ? _self.isTrending : isTrending // ignore: cast_nullable_to_non_nullable
as bool,trendingAt: freezed == trendingAt ? _self.trendingAt : trendingAt // ignore: cast_nullable_to_non_nullable
as DateTime?,hasVariants: null == hasVariants ? _self.hasVariants : hasVariants // ignore: cast_nullable_to_non_nullable
as bool,variants: null == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as List<ProductVariant>,variantOptions: null == variantOptions ? _self.variantOptions : variantOptions // ignore: cast_nullable_to_non_nullable
as List<VariantOption>,subcategory: freezed == subcategory ? _self.subcategory : subcategory // ignore: cast_nullable_to_non_nullable
as String?,condition: freezed == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String?,warehouseStockMap: freezed == warehouseStockMap ? _self.warehouseStockMap : warehouseStockMap // ignore: cast_nullable_to_non_nullable
as Map<String, int>?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get sellerAddress {
    if (_self.sellerAddress == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.sellerAddress!, (value) {
    return _then(_self.copyWith(sellerAddress: value));
  });
}/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupplierInfoCopyWith<$Res>? get supplier {
    if (_self.supplier == null) {
    return null;
  }

  return $SupplierInfoCopyWith<$Res>(_self.supplier!, (value) {
    return _then(_self.copyWith(supplier: value));
  });
}/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InventoryConfigCopyWith<$Res>? get inventory {
    if (_self.inventory == null) {
    return null;
  }

  return $InventoryConfigCopyWith<$Res>(_self.inventory!, (value) {
    return _then(_self.copyWith(inventory: value));
  });
}
}


/// Adds pattern-matching-related methods to [Product].
extension ProductPatterns on Product {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Product value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Product value)  $default,){
final _that = this;
switch (_that) {
case _Product():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Product value)?  $default,){
final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productId,  String name,  String? nameF,  double price,  int? priceCents,  double? compareAtPrice,  String description,  String? descriptionF,  List<String> imageUrls,  String? videoUrl,  int? videoDurationSeconds,  String sellerId,  String? madeInCountry,  Address? sellerAddress,  int categoryId,  int stockQuantity,  double rating,  int ratingCount,  DateTime createdAt,  String lifecycleStatus,  double? weightKg,  String? weightUnit,  double? lengthCm,  double? widthCm,  double? heightCm,  String? dimensionUnit,  bool isLocalDeliveryOnly,  bool isPerishable,  int estimatedShipDays,  List<SellerDeliveryOption> deliveryOptions,  int minimumOrderQuantity,  bool freeShipping,  bool isDigital,  bool isAgeRestricted,  String? digitalType,  String? slug,  Map<String, String>? digitalBuilds,  int? deviceLimit,  String? taxCode,  List<String> keywords,  String? approvalRejectionReason,  double? cost,  String? supplierSku,  String? supplierUrl,  SupplierInfo? supplier,  InventoryConfig? inventory,  String? sellerSku,  List<String>? warehouseIds,  String? shipFromCity,  String? shipFromProvince,  String? shipFromCountry,  List<String>? shipFromCountries,  int trendingScore,  int viewCount,  int purchaseCount,  bool isTrending,  DateTime? trendingAt,  bool hasVariants,  List<ProductVariant> variants,  List<VariantOption> variantOptions,  String? subcategory,  String? condition,  Map<String, int>? warehouseStockMap,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.productId,_that.name,_that.nameF,_that.price,_that.priceCents,_that.compareAtPrice,_that.description,_that.descriptionF,_that.imageUrls,_that.videoUrl,_that.videoDurationSeconds,_that.sellerId,_that.madeInCountry,_that.sellerAddress,_that.categoryId,_that.stockQuantity,_that.rating,_that.ratingCount,_that.createdAt,_that.lifecycleStatus,_that.weightKg,_that.weightUnit,_that.lengthCm,_that.widthCm,_that.heightCm,_that.dimensionUnit,_that.isLocalDeliveryOnly,_that.isPerishable,_that.estimatedShipDays,_that.deliveryOptions,_that.minimumOrderQuantity,_that.freeShipping,_that.isDigital,_that.isAgeRestricted,_that.digitalType,_that.slug,_that.digitalBuilds,_that.deviceLimit,_that.taxCode,_that.keywords,_that.approvalRejectionReason,_that.cost,_that.supplierSku,_that.supplierUrl,_that.supplier,_that.inventory,_that.sellerSku,_that.warehouseIds,_that.shipFromCity,_that.shipFromProvince,_that.shipFromCountry,_that.shipFromCountries,_that.trendingScore,_that.viewCount,_that.purchaseCount,_that.isTrending,_that.trendingAt,_that.hasVariants,_that.variants,_that.variantOptions,_that.subcategory,_that.condition,_that.warehouseStockMap,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productId,  String name,  String? nameF,  double price,  int? priceCents,  double? compareAtPrice,  String description,  String? descriptionF,  List<String> imageUrls,  String? videoUrl,  int? videoDurationSeconds,  String sellerId,  String? madeInCountry,  Address? sellerAddress,  int categoryId,  int stockQuantity,  double rating,  int ratingCount,  DateTime createdAt,  String lifecycleStatus,  double? weightKg,  String? weightUnit,  double? lengthCm,  double? widthCm,  double? heightCm,  String? dimensionUnit,  bool isLocalDeliveryOnly,  bool isPerishable,  int estimatedShipDays,  List<SellerDeliveryOption> deliveryOptions,  int minimumOrderQuantity,  bool freeShipping,  bool isDigital,  bool isAgeRestricted,  String? digitalType,  String? slug,  Map<String, String>? digitalBuilds,  int? deviceLimit,  String? taxCode,  List<String> keywords,  String? approvalRejectionReason,  double? cost,  String? supplierSku,  String? supplierUrl,  SupplierInfo? supplier,  InventoryConfig? inventory,  String? sellerSku,  List<String>? warehouseIds,  String? shipFromCity,  String? shipFromProvince,  String? shipFromCountry,  List<String>? shipFromCountries,  int trendingScore,  int viewCount,  int purchaseCount,  bool isTrending,  DateTime? trendingAt,  bool hasVariants,  List<ProductVariant> variants,  List<VariantOption> variantOptions,  String? subcategory,  String? condition,  Map<String, int>? warehouseStockMap,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Product():
return $default(_that.productId,_that.name,_that.nameF,_that.price,_that.priceCents,_that.compareAtPrice,_that.description,_that.descriptionF,_that.imageUrls,_that.videoUrl,_that.videoDurationSeconds,_that.sellerId,_that.madeInCountry,_that.sellerAddress,_that.categoryId,_that.stockQuantity,_that.rating,_that.ratingCount,_that.createdAt,_that.lifecycleStatus,_that.weightKg,_that.weightUnit,_that.lengthCm,_that.widthCm,_that.heightCm,_that.dimensionUnit,_that.isLocalDeliveryOnly,_that.isPerishable,_that.estimatedShipDays,_that.deliveryOptions,_that.minimumOrderQuantity,_that.freeShipping,_that.isDigital,_that.isAgeRestricted,_that.digitalType,_that.slug,_that.digitalBuilds,_that.deviceLimit,_that.taxCode,_that.keywords,_that.approvalRejectionReason,_that.cost,_that.supplierSku,_that.supplierUrl,_that.supplier,_that.inventory,_that.sellerSku,_that.warehouseIds,_that.shipFromCity,_that.shipFromProvince,_that.shipFromCountry,_that.shipFromCountries,_that.trendingScore,_that.viewCount,_that.purchaseCount,_that.isTrending,_that.trendingAt,_that.hasVariants,_that.variants,_that.variantOptions,_that.subcategory,_that.condition,_that.warehouseStockMap,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productId,  String name,  String? nameF,  double price,  int? priceCents,  double? compareAtPrice,  String description,  String? descriptionF,  List<String> imageUrls,  String? videoUrl,  int? videoDurationSeconds,  String sellerId,  String? madeInCountry,  Address? sellerAddress,  int categoryId,  int stockQuantity,  double rating,  int ratingCount,  DateTime createdAt,  String lifecycleStatus,  double? weightKg,  String? weightUnit,  double? lengthCm,  double? widthCm,  double? heightCm,  String? dimensionUnit,  bool isLocalDeliveryOnly,  bool isPerishable,  int estimatedShipDays,  List<SellerDeliveryOption> deliveryOptions,  int minimumOrderQuantity,  bool freeShipping,  bool isDigital,  bool isAgeRestricted,  String? digitalType,  String? slug,  Map<String, String>? digitalBuilds,  int? deviceLimit,  String? taxCode,  List<String> keywords,  String? approvalRejectionReason,  double? cost,  String? supplierSku,  String? supplierUrl,  SupplierInfo? supplier,  InventoryConfig? inventory,  String? sellerSku,  List<String>? warehouseIds,  String? shipFromCity,  String? shipFromProvince,  String? shipFromCountry,  List<String>? shipFromCountries,  int trendingScore,  int viewCount,  int purchaseCount,  bool isTrending,  DateTime? trendingAt,  bool hasVariants,  List<ProductVariant> variants,  List<VariantOption> variantOptions,  String? subcategory,  String? condition,  Map<String, int>? warehouseStockMap,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.productId,_that.name,_that.nameF,_that.price,_that.priceCents,_that.compareAtPrice,_that.description,_that.descriptionF,_that.imageUrls,_that.videoUrl,_that.videoDurationSeconds,_that.sellerId,_that.madeInCountry,_that.sellerAddress,_that.categoryId,_that.stockQuantity,_that.rating,_that.ratingCount,_that.createdAt,_that.lifecycleStatus,_that.weightKg,_that.weightUnit,_that.lengthCm,_that.widthCm,_that.heightCm,_that.dimensionUnit,_that.isLocalDeliveryOnly,_that.isPerishable,_that.estimatedShipDays,_that.deliveryOptions,_that.minimumOrderQuantity,_that.freeShipping,_that.isDigital,_that.isAgeRestricted,_that.digitalType,_that.slug,_that.digitalBuilds,_that.deviceLimit,_that.taxCode,_that.keywords,_that.approvalRejectionReason,_that.cost,_that.supplierSku,_that.supplierUrl,_that.supplier,_that.inventory,_that.sellerSku,_that.warehouseIds,_that.shipFromCity,_that.shipFromProvince,_that.shipFromCountry,_that.shipFromCountries,_that.trendingScore,_that.viewCount,_that.purchaseCount,_that.isTrending,_that.trendingAt,_that.hasVariants,_that.variants,_that.variantOptions,_that.subcategory,_that.condition,_that.warehouseStockMap,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Product implements Product {
  const _Product({required this.productId, required this.name, this.nameF, required this.price, this.priceCents, this.compareAtPrice, required this.description, this.descriptionF, required final  List<String> imageUrls, this.videoUrl, this.videoDurationSeconds, required this.sellerId, this.madeInCountry, this.sellerAddress, required this.categoryId, required this.stockQuantity, this.rating = 0.0, this.ratingCount = 0, required this.createdAt, this.lifecycleStatus = ProductLifecycleStatusValues.draft, this.weightKg, this.weightUnit, this.lengthCm, this.widthCm, this.heightCm, this.dimensionUnit, this.isLocalDeliveryOnly = false, this.isPerishable = false, this.estimatedShipDays = 3, final  List<SellerDeliveryOption> deliveryOptions = const [], this.minimumOrderQuantity = 1, this.freeShipping = false, this.isDigital = false, this.isAgeRestricted = false, this.digitalType, this.slug, final  Map<String, String>? digitalBuilds, this.deviceLimit, this.taxCode, final  List<String> keywords = const [], this.approvalRejectionReason, this.cost, this.supplierSku, this.supplierUrl, this.supplier, this.inventory, this.sellerSku, final  List<String>? warehouseIds, this.shipFromCity, this.shipFromProvince, this.shipFromCountry, final  List<String>? shipFromCountries, this.trendingScore = 0, this.viewCount = 0, this.purchaseCount = 0, this.isTrending = false, this.trendingAt, this.hasVariants = false, final  List<ProductVariant> variants = const [], final  List<VariantOption> variantOptions = const [], this.subcategory, this.condition, final  Map<String, int>? warehouseStockMap, this.updatedAt}): _imageUrls = imageUrls,_deliveryOptions = deliveryOptions,_digitalBuilds = digitalBuilds,_keywords = keywords,_warehouseIds = warehouseIds,_shipFromCountries = shipFromCountries,_variants = variants,_variantOptions = variantOptions,_warehouseStockMap = warehouseStockMap;
  factory _Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);

@override final  String productId;
@override final  String name;
@override final  String? nameF;
@override final  double price;
@override final  int? priceCents;
/// Original/crossed-out price for discount display (null = no sale, must be > price)
@override final  double? compareAtPrice;
@override final  String description;
@override final  String? descriptionF;
 final  List<String> _imageUrls;
@override List<String> get imageUrls {
  if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_imageUrls);
}

@override final  String? videoUrl;
@override final  int? videoDurationSeconds;
@override final  String sellerId;
@override final  String? madeInCountry;
// sellerAddress is optional — products with warehouses use warehouseIds instead
@override final  Address? sellerAddress;
@override final  int categoryId;
@override final  int stockQuantity;
@override@JsonKey() final  double rating;
@override@JsonKey() final  int ratingCount;
@override final  DateTime createdAt;
// Single lifecycle state replacing isActive + status + approvalStatus
@override@JsonKey() final  String lifecycleStatus;
// Optional shipping metadata
@override final  double? weightKg;
@override final  String? weightUnit;
@override final  double? lengthCm;
@override final  double? widthCm;
@override final  double? heightCm;
@override final  String? dimensionUnit;
// Delivery options
@override@JsonKey() final  bool isLocalDeliveryOnly;
@override@JsonKey() final  bool isPerishable;
@override@JsonKey() final  int estimatedShipDays;
 final  List<SellerDeliveryOption> _deliveryOptions;
@override@JsonKey() List<SellerDeliveryOption> get deliveryOptions {
  if (_deliveryOptions is EqualUnmodifiableListView) return _deliveryOptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deliveryOptions);
}

@override@JsonKey() final  int minimumOrderQuantity;
@override@JsonKey() final  bool freeShipping;
// Digital product flag
@override@JsonKey() final  bool isDigital;
// Age restriction flag — requires buyer age confirmation at checkout
@override@JsonKey() final  bool isAgeRestricted;
@override final  String? digitalType;
@override final  String? slug;
 final  Map<String, String>? _digitalBuilds;
@override Map<String, String>? get digitalBuilds {
  final value = _digitalBuilds;
  if (value == null) return null;
  if (_digitalBuilds is EqualUnmodifiableMapView) return _digitalBuilds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

// bookSourceUrl intentionally NOT included — buyer-protected: written by seller, never returned to client
@override final  int? deviceLimit;
// Tax and metadata
@override final  String? taxCode;
 final  List<String> _keywords;
@override@JsonKey() List<String> get keywords {
  if (_keywords is EqualUnmodifiableListView) return _keywords;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_keywords);
}

// Admin rejection reason
@override final  String? approvalRejectionReason;
// Flat supplier fields (used when supplier object is not provided)
@override final  double? cost;
@override final  String? supplierSku;
@override final  String? supplierUrl;
// Structured objects for scalability
/// Supplier information for dropshipping/marketplace products
@override final  SupplierInfo? supplier;
/// Inventory management configuration
@override final  InventoryConfig? inventory;
// Multi-warehouse support
/// Seller's unique product identifier — enforced unique per seller at write time
@override final  String? sellerSku;
/// IDs of seller warehouses this product ships from
 final  List<String>? _warehouseIds;
/// IDs of seller warehouses this product ships from
@override List<String>? get warehouseIds {
  final value = _warehouseIds;
  if (value == null) return null;
  if (_warehouseIds is EqualUnmodifiableListView) return _warehouseIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// City of primary shipping warehouse (denormalized for O(1) card rendering)
@override final  String? shipFromCity;
/// Province code of primary warehouse (denormalized for O(1) card rendering)
@override final  String? shipFromProvince;
/// Country of primary warehouse (denormalized for O(1) card rendering)
@override final  String? shipFromCountry;
 final  List<String>? _shipFromCountries;
@override List<String>? get shipFromCountries {
  final value = _shipFromCountries;
  if (value == null) return null;
  if (_shipFromCountries is EqualUnmodifiableListView) return _shipFromCountries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// === TRENDING & ENGAGEMENT ===
@override@JsonKey() final  int trendingScore;
@override@JsonKey() final  int viewCount;
@override@JsonKey() final  int purchaseCount;
@override@JsonKey() final  bool isTrending;
@override final  DateTime? trendingAt;
// === N-09: Product Variants ===
/// Whether this product has variants (size, color, etc.)
@override@JsonKey() final  bool hasVariants;
/// List of variant objects
 final  List<ProductVariant> _variants;
/// List of variant objects
@override@JsonKey() List<ProductVariant> get variants {
  if (_variants is EqualUnmodifiableListView) return _variants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_variants);
}

/// Variant option definitions
 final  List<VariantOption> _variantOptions;
/// Variant option definitions
@override@JsonKey() List<VariantOption> get variantOptions {
  if (_variantOptions is EqualUnmodifiableListView) return _variantOptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_variantOptions);
}

// === N-11: Subcategories ===
/// Optional subcategory within the main category
@override final  String? subcategory;
/// Product condition: new, like_new, good, fair, for_parts
@override final  String? condition;
/// Per-warehouse stock allocation map: {warehouseId: stockQty}
/// Sum of values equals stockQuantity. Used for multi-warehouse inventory routing.
 final  Map<String, int>? _warehouseStockMap;
/// Per-warehouse stock allocation map: {warehouseId: stockQty}
/// Sum of values equals stockQuantity. Used for multi-warehouse inventory routing.
@override Map<String, int>? get warehouseStockMap {
  final value = _warehouseStockMap;
  if (value == null) return null;
  if (_warehouseStockMap is EqualUnmodifiableMapView) return _warehouseStockMap;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// Server-controlled last-updated timestamp
@override final  DateTime? updatedAt;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductCopyWith<_Product> get copyWith => __$ProductCopyWithImpl<_Product>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Product&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.name, name) || other.name == name)&&(identical(other.nameF, nameF) || other.nameF == nameF)&&(identical(other.price, price) || other.price == price)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.compareAtPrice, compareAtPrice) || other.compareAtPrice == compareAtPrice)&&(identical(other.description, description) || other.description == description)&&(identical(other.descriptionF, descriptionF) || other.descriptionF == descriptionF)&&const DeepCollectionEquality().equals(other._imageUrls, _imageUrls)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.videoDurationSeconds, videoDurationSeconds) || other.videoDurationSeconds == videoDurationSeconds)&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.madeInCountry, madeInCountry) || other.madeInCountry == madeInCountry)&&(identical(other.sellerAddress, sellerAddress) || other.sellerAddress == sellerAddress)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.ratingCount, ratingCount) || other.ratingCount == ratingCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lifecycleStatus, lifecycleStatus) || other.lifecycleStatus == lifecycleStatus)&&(identical(other.weightKg, weightKg) || other.weightKg == weightKg)&&(identical(other.weightUnit, weightUnit) || other.weightUnit == weightUnit)&&(identical(other.lengthCm, lengthCm) || other.lengthCm == lengthCm)&&(identical(other.widthCm, widthCm) || other.widthCm == widthCm)&&(identical(other.heightCm, heightCm) || other.heightCm == heightCm)&&(identical(other.dimensionUnit, dimensionUnit) || other.dimensionUnit == dimensionUnit)&&(identical(other.isLocalDeliveryOnly, isLocalDeliveryOnly) || other.isLocalDeliveryOnly == isLocalDeliveryOnly)&&(identical(other.isPerishable, isPerishable) || other.isPerishable == isPerishable)&&(identical(other.estimatedShipDays, estimatedShipDays) || other.estimatedShipDays == estimatedShipDays)&&const DeepCollectionEquality().equals(other._deliveryOptions, _deliveryOptions)&&(identical(other.minimumOrderQuantity, minimumOrderQuantity) || other.minimumOrderQuantity == minimumOrderQuantity)&&(identical(other.freeShipping, freeShipping) || other.freeShipping == freeShipping)&&(identical(other.isDigital, isDigital) || other.isDigital == isDigital)&&(identical(other.isAgeRestricted, isAgeRestricted) || other.isAgeRestricted == isAgeRestricted)&&(identical(other.digitalType, digitalType) || other.digitalType == digitalType)&&(identical(other.slug, slug) || other.slug == slug)&&const DeepCollectionEquality().equals(other._digitalBuilds, _digitalBuilds)&&(identical(other.deviceLimit, deviceLimit) || other.deviceLimit == deviceLimit)&&(identical(other.taxCode, taxCode) || other.taxCode == taxCode)&&const DeepCollectionEquality().equals(other._keywords, _keywords)&&(identical(other.approvalRejectionReason, approvalRejectionReason) || other.approvalRejectionReason == approvalRejectionReason)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.supplierSku, supplierSku) || other.supplierSku == supplierSku)&&(identical(other.supplierUrl, supplierUrl) || other.supplierUrl == supplierUrl)&&(identical(other.supplier, supplier) || other.supplier == supplier)&&(identical(other.inventory, inventory) || other.inventory == inventory)&&(identical(other.sellerSku, sellerSku) || other.sellerSku == sellerSku)&&const DeepCollectionEquality().equals(other._warehouseIds, _warehouseIds)&&(identical(other.shipFromCity, shipFromCity) || other.shipFromCity == shipFromCity)&&(identical(other.shipFromProvince, shipFromProvince) || other.shipFromProvince == shipFromProvince)&&(identical(other.shipFromCountry, shipFromCountry) || other.shipFromCountry == shipFromCountry)&&const DeepCollectionEquality().equals(other._shipFromCountries, _shipFromCountries)&&(identical(other.trendingScore, trendingScore) || other.trendingScore == trendingScore)&&(identical(other.viewCount, viewCount) || other.viewCount == viewCount)&&(identical(other.purchaseCount, purchaseCount) || other.purchaseCount == purchaseCount)&&(identical(other.isTrending, isTrending) || other.isTrending == isTrending)&&(identical(other.trendingAt, trendingAt) || other.trendingAt == trendingAt)&&(identical(other.hasVariants, hasVariants) || other.hasVariants == hasVariants)&&const DeepCollectionEquality().equals(other._variants, _variants)&&const DeepCollectionEquality().equals(other._variantOptions, _variantOptions)&&(identical(other.subcategory, subcategory) || other.subcategory == subcategory)&&(identical(other.condition, condition) || other.condition == condition)&&const DeepCollectionEquality().equals(other._warehouseStockMap, _warehouseStockMap)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,productId,name,nameF,price,priceCents,compareAtPrice,description,descriptionF,const DeepCollectionEquality().hash(_imageUrls),videoUrl,videoDurationSeconds,sellerId,madeInCountry,sellerAddress,categoryId,stockQuantity,rating,ratingCount,createdAt,lifecycleStatus,weightKg,weightUnit,lengthCm,widthCm,heightCm,dimensionUnit,isLocalDeliveryOnly,isPerishable,estimatedShipDays,const DeepCollectionEquality().hash(_deliveryOptions),minimumOrderQuantity,freeShipping,isDigital,isAgeRestricted,digitalType,slug,const DeepCollectionEquality().hash(_digitalBuilds),deviceLimit,taxCode,const DeepCollectionEquality().hash(_keywords),approvalRejectionReason,cost,supplierSku,supplierUrl,supplier,inventory,sellerSku,const DeepCollectionEquality().hash(_warehouseIds),shipFromCity,shipFromProvince,shipFromCountry,const DeepCollectionEquality().hash(_shipFromCountries),trendingScore,viewCount,purchaseCount,isTrending,trendingAt,hasVariants,const DeepCollectionEquality().hash(_variants),const DeepCollectionEquality().hash(_variantOptions),subcategory,condition,const DeepCollectionEquality().hash(_warehouseStockMap),updatedAt]);

@override
String toString() {
  return 'Product(productId: $productId, name: $name, nameF: $nameF, price: $price, priceCents: $priceCents, compareAtPrice: $compareAtPrice, description: $description, descriptionF: $descriptionF, imageUrls: $imageUrls, videoUrl: $videoUrl, videoDurationSeconds: $videoDurationSeconds, sellerId: $sellerId, madeInCountry: $madeInCountry, sellerAddress: $sellerAddress, categoryId: $categoryId, stockQuantity: $stockQuantity, rating: $rating, ratingCount: $ratingCount, createdAt: $createdAt, lifecycleStatus: $lifecycleStatus, weightKg: $weightKg, weightUnit: $weightUnit, lengthCm: $lengthCm, widthCm: $widthCm, heightCm: $heightCm, dimensionUnit: $dimensionUnit, isLocalDeliveryOnly: $isLocalDeliveryOnly, isPerishable: $isPerishable, estimatedShipDays: $estimatedShipDays, deliveryOptions: $deliveryOptions, minimumOrderQuantity: $minimumOrderQuantity, freeShipping: $freeShipping, isDigital: $isDigital, isAgeRestricted: $isAgeRestricted, digitalType: $digitalType, slug: $slug, digitalBuilds: $digitalBuilds, deviceLimit: $deviceLimit, taxCode: $taxCode, keywords: $keywords, approvalRejectionReason: $approvalRejectionReason, cost: $cost, supplierSku: $supplierSku, supplierUrl: $supplierUrl, supplier: $supplier, inventory: $inventory, sellerSku: $sellerSku, warehouseIds: $warehouseIds, shipFromCity: $shipFromCity, shipFromProvince: $shipFromProvince, shipFromCountry: $shipFromCountry, shipFromCountries: $shipFromCountries, trendingScore: $trendingScore, viewCount: $viewCount, purchaseCount: $purchaseCount, isTrending: $isTrending, trendingAt: $trendingAt, hasVariants: $hasVariants, variants: $variants, variantOptions: $variantOptions, subcategory: $subcategory, condition: $condition, warehouseStockMap: $warehouseStockMap, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ProductCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$ProductCopyWith(_Product value, $Res Function(_Product) _then) = __$ProductCopyWithImpl;
@override @useResult
$Res call({
 String productId, String name, String? nameF, double price, int? priceCents, double? compareAtPrice, String description, String? descriptionF, List<String> imageUrls, String? videoUrl, int? videoDurationSeconds, String sellerId, String? madeInCountry, Address? sellerAddress, int categoryId, int stockQuantity, double rating, int ratingCount, DateTime createdAt, String lifecycleStatus, double? weightKg, String? weightUnit, double? lengthCm, double? widthCm, double? heightCm, String? dimensionUnit, bool isLocalDeliveryOnly, bool isPerishable, int estimatedShipDays, List<SellerDeliveryOption> deliveryOptions, int minimumOrderQuantity, bool freeShipping, bool isDigital, bool isAgeRestricted, String? digitalType, String? slug, Map<String, String>? digitalBuilds, int? deviceLimit, String? taxCode, List<String> keywords, String? approvalRejectionReason, double? cost, String? supplierSku, String? supplierUrl, SupplierInfo? supplier, InventoryConfig? inventory, String? sellerSku, List<String>? warehouseIds, String? shipFromCity, String? shipFromProvince, String? shipFromCountry, List<String>? shipFromCountries, int trendingScore, int viewCount, int purchaseCount, bool isTrending, DateTime? trendingAt, bool hasVariants, List<ProductVariant> variants, List<VariantOption> variantOptions, String? subcategory, String? condition, Map<String, int>? warehouseStockMap, DateTime? updatedAt
});


@override $AddressCopyWith<$Res>? get sellerAddress;@override $SupplierInfoCopyWith<$Res>? get supplier;@override $InventoryConfigCopyWith<$Res>? get inventory;

}
/// @nodoc
class __$ProductCopyWithImpl<$Res>
    implements _$ProductCopyWith<$Res> {
  __$ProductCopyWithImpl(this._self, this._then);

  final _Product _self;
  final $Res Function(_Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? name = null,Object? nameF = freezed,Object? price = null,Object? priceCents = freezed,Object? compareAtPrice = freezed,Object? description = null,Object? descriptionF = freezed,Object? imageUrls = null,Object? videoUrl = freezed,Object? videoDurationSeconds = freezed,Object? sellerId = null,Object? madeInCountry = freezed,Object? sellerAddress = freezed,Object? categoryId = null,Object? stockQuantity = null,Object? rating = null,Object? ratingCount = null,Object? createdAt = null,Object? lifecycleStatus = null,Object? weightKg = freezed,Object? weightUnit = freezed,Object? lengthCm = freezed,Object? widthCm = freezed,Object? heightCm = freezed,Object? dimensionUnit = freezed,Object? isLocalDeliveryOnly = null,Object? isPerishable = null,Object? estimatedShipDays = null,Object? deliveryOptions = null,Object? minimumOrderQuantity = null,Object? freeShipping = null,Object? isDigital = null,Object? isAgeRestricted = null,Object? digitalType = freezed,Object? slug = freezed,Object? digitalBuilds = freezed,Object? deviceLimit = freezed,Object? taxCode = freezed,Object? keywords = null,Object? approvalRejectionReason = freezed,Object? cost = freezed,Object? supplierSku = freezed,Object? supplierUrl = freezed,Object? supplier = freezed,Object? inventory = freezed,Object? sellerSku = freezed,Object? warehouseIds = freezed,Object? shipFromCity = freezed,Object? shipFromProvince = freezed,Object? shipFromCountry = freezed,Object? shipFromCountries = freezed,Object? trendingScore = null,Object? viewCount = null,Object? purchaseCount = null,Object? isTrending = null,Object? trendingAt = freezed,Object? hasVariants = null,Object? variants = null,Object? variantOptions = null,Object? subcategory = freezed,Object? condition = freezed,Object? warehouseStockMap = freezed,Object? updatedAt = freezed,}) {
  return _then(_Product(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameF: freezed == nameF ? _self.nameF : nameF // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,priceCents: freezed == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int?,compareAtPrice: freezed == compareAtPrice ? _self.compareAtPrice : compareAtPrice // ignore: cast_nullable_to_non_nullable
as double?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,descriptionF: freezed == descriptionF ? _self.descriptionF : descriptionF // ignore: cast_nullable_to_non_nullable
as String?,imageUrls: null == imageUrls ? _self._imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,videoUrl: freezed == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String?,videoDurationSeconds: freezed == videoDurationSeconds ? _self.videoDurationSeconds : videoDurationSeconds // ignore: cast_nullable_to_non_nullable
as int?,sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,madeInCountry: freezed == madeInCountry ? _self.madeInCountry : madeInCountry // ignore: cast_nullable_to_non_nullable
as String?,sellerAddress: freezed == sellerAddress ? _self.sellerAddress : sellerAddress // ignore: cast_nullable_to_non_nullable
as Address?,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,ratingCount: null == ratingCount ? _self.ratingCount : ratingCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lifecycleStatus: null == lifecycleStatus ? _self.lifecycleStatus : lifecycleStatus // ignore: cast_nullable_to_non_nullable
as String,weightKg: freezed == weightKg ? _self.weightKg : weightKg // ignore: cast_nullable_to_non_nullable
as double?,weightUnit: freezed == weightUnit ? _self.weightUnit : weightUnit // ignore: cast_nullable_to_non_nullable
as String?,lengthCm: freezed == lengthCm ? _self.lengthCm : lengthCm // ignore: cast_nullable_to_non_nullable
as double?,widthCm: freezed == widthCm ? _self.widthCm : widthCm // ignore: cast_nullable_to_non_nullable
as double?,heightCm: freezed == heightCm ? _self.heightCm : heightCm // ignore: cast_nullable_to_non_nullable
as double?,dimensionUnit: freezed == dimensionUnit ? _self.dimensionUnit : dimensionUnit // ignore: cast_nullable_to_non_nullable
as String?,isLocalDeliveryOnly: null == isLocalDeliveryOnly ? _self.isLocalDeliveryOnly : isLocalDeliveryOnly // ignore: cast_nullable_to_non_nullable
as bool,isPerishable: null == isPerishable ? _self.isPerishable : isPerishable // ignore: cast_nullable_to_non_nullable
as bool,estimatedShipDays: null == estimatedShipDays ? _self.estimatedShipDays : estimatedShipDays // ignore: cast_nullable_to_non_nullable
as int,deliveryOptions: null == deliveryOptions ? _self._deliveryOptions : deliveryOptions // ignore: cast_nullable_to_non_nullable
as List<SellerDeliveryOption>,minimumOrderQuantity: null == minimumOrderQuantity ? _self.minimumOrderQuantity : minimumOrderQuantity // ignore: cast_nullable_to_non_nullable
as int,freeShipping: null == freeShipping ? _self.freeShipping : freeShipping // ignore: cast_nullable_to_non_nullable
as bool,isDigital: null == isDigital ? _self.isDigital : isDigital // ignore: cast_nullable_to_non_nullable
as bool,isAgeRestricted: null == isAgeRestricted ? _self.isAgeRestricted : isAgeRestricted // ignore: cast_nullable_to_non_nullable
as bool,digitalType: freezed == digitalType ? _self.digitalType : digitalType // ignore: cast_nullable_to_non_nullable
as String?,slug: freezed == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String?,digitalBuilds: freezed == digitalBuilds ? _self._digitalBuilds : digitalBuilds // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,deviceLimit: freezed == deviceLimit ? _self.deviceLimit : deviceLimit // ignore: cast_nullable_to_non_nullable
as int?,taxCode: freezed == taxCode ? _self.taxCode : taxCode // ignore: cast_nullable_to_non_nullable
as String?,keywords: null == keywords ? _self._keywords : keywords // ignore: cast_nullable_to_non_nullable
as List<String>,approvalRejectionReason: freezed == approvalRejectionReason ? _self.approvalRejectionReason : approvalRejectionReason // ignore: cast_nullable_to_non_nullable
as String?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,supplierSku: freezed == supplierSku ? _self.supplierSku : supplierSku // ignore: cast_nullable_to_non_nullable
as String?,supplierUrl: freezed == supplierUrl ? _self.supplierUrl : supplierUrl // ignore: cast_nullable_to_non_nullable
as String?,supplier: freezed == supplier ? _self.supplier : supplier // ignore: cast_nullable_to_non_nullable
as SupplierInfo?,inventory: freezed == inventory ? _self.inventory : inventory // ignore: cast_nullable_to_non_nullable
as InventoryConfig?,sellerSku: freezed == sellerSku ? _self.sellerSku : sellerSku // ignore: cast_nullable_to_non_nullable
as String?,warehouseIds: freezed == warehouseIds ? _self._warehouseIds : warehouseIds // ignore: cast_nullable_to_non_nullable
as List<String>?,shipFromCity: freezed == shipFromCity ? _self.shipFromCity : shipFromCity // ignore: cast_nullable_to_non_nullable
as String?,shipFromProvince: freezed == shipFromProvince ? _self.shipFromProvince : shipFromProvince // ignore: cast_nullable_to_non_nullable
as String?,shipFromCountry: freezed == shipFromCountry ? _self.shipFromCountry : shipFromCountry // ignore: cast_nullable_to_non_nullable
as String?,shipFromCountries: freezed == shipFromCountries ? _self._shipFromCountries : shipFromCountries // ignore: cast_nullable_to_non_nullable
as List<String>?,trendingScore: null == trendingScore ? _self.trendingScore : trendingScore // ignore: cast_nullable_to_non_nullable
as int,viewCount: null == viewCount ? _self.viewCount : viewCount // ignore: cast_nullable_to_non_nullable
as int,purchaseCount: null == purchaseCount ? _self.purchaseCount : purchaseCount // ignore: cast_nullable_to_non_nullable
as int,isTrending: null == isTrending ? _self.isTrending : isTrending // ignore: cast_nullable_to_non_nullable
as bool,trendingAt: freezed == trendingAt ? _self.trendingAt : trendingAt // ignore: cast_nullable_to_non_nullable
as DateTime?,hasVariants: null == hasVariants ? _self.hasVariants : hasVariants // ignore: cast_nullable_to_non_nullable
as bool,variants: null == variants ? _self._variants : variants // ignore: cast_nullable_to_non_nullable
as List<ProductVariant>,variantOptions: null == variantOptions ? _self._variantOptions : variantOptions // ignore: cast_nullable_to_non_nullable
as List<VariantOption>,subcategory: freezed == subcategory ? _self.subcategory : subcategory // ignore: cast_nullable_to_non_nullable
as String?,condition: freezed == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String?,warehouseStockMap: freezed == warehouseStockMap ? _self._warehouseStockMap : warehouseStockMap // ignore: cast_nullable_to_non_nullable
as Map<String, int>?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get sellerAddress {
    if (_self.sellerAddress == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.sellerAddress!, (value) {
    return _then(_self.copyWith(sellerAddress: value));
  });
}/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupplierInfoCopyWith<$Res>? get supplier {
    if (_self.supplier == null) {
    return null;
  }

  return $SupplierInfoCopyWith<$Res>(_self.supplier!, (value) {
    return _then(_self.copyWith(supplier: value));
  });
}/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InventoryConfigCopyWith<$Res>? get inventory {
    if (_self.inventory == null) {
    return null;
  }

  return $InventoryConfigCopyWith<$Res>(_self.inventory!, (value) {
    return _then(_self.copyWith(inventory: value));
  });
}
}


/// @nodoc
mixin _$ProductCreate {

 String get name; String? get nameF; double get price;/// Original/crossed-out price for discount display (null = no sale, must be > price)
 double? get compareAtPrice; String get description; String? get descriptionF; List<String> get imageUrls; String? get videoUrl; String get sellerId;// sellerAddress is optional — required only when warehouseIds is not provided
 Address? get sellerAddress; int get categoryId; int get stockQuantity; double get rating; String get lifecycleStatus; double? get weightKg; double? get lengthCm; double? get widthCm; double? get heightCm; bool get isLocalDeliveryOnly; bool get isPerishable; int get estimatedShipDays; List<SellerDeliveryOption> get deliveryOptions; int get minimumOrderQuantity; bool get freeShipping; bool get isDigital; String? get digitalType; String? get slug; Map<String, String>? get digitalBuilds;// bookSourceUrl intentionally NOT included — buyer-protected: written by seller, never returned to client
 int? get deviceLimit; String? get taxCode; List<String> get keywords;// lifecycleStatus intentionally defaults to draft — backend sets under_review on creation
// Flat supplier fields (used when supplier object is not provided)
 double? get cost; String? get supplierSku; String? get supplierUrl;// Structured objects
 SupplierInfo? get supplier; InventoryConfig? get inventory;// Multi-warehouse support
 String? get sellerSku; List<String>? get warehouseIds; String? get shipFromCity; String? get shipFromProvince; String? get shipFromCountry; List<String>? get shipFromCountries;// === N-09: Product Variants ===
 bool get hasVariants; List<ProductVariant> get variants; List<VariantOption> get variantOptions;// === N-11: Subcategories ===
 String? get subcategory;
/// Create a copy of ProductCreate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductCreateCopyWith<ProductCreate> get copyWith => _$ProductCreateCopyWithImpl<ProductCreate>(this as ProductCreate, _$identity);

  /// Serializes this ProductCreate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductCreate&&(identical(other.name, name) || other.name == name)&&(identical(other.nameF, nameF) || other.nameF == nameF)&&(identical(other.price, price) || other.price == price)&&(identical(other.compareAtPrice, compareAtPrice) || other.compareAtPrice == compareAtPrice)&&(identical(other.description, description) || other.description == description)&&(identical(other.descriptionF, descriptionF) || other.descriptionF == descriptionF)&&const DeepCollectionEquality().equals(other.imageUrls, imageUrls)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.sellerAddress, sellerAddress) || other.sellerAddress == sellerAddress)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.lifecycleStatus, lifecycleStatus) || other.lifecycleStatus == lifecycleStatus)&&(identical(other.weightKg, weightKg) || other.weightKg == weightKg)&&(identical(other.lengthCm, lengthCm) || other.lengthCm == lengthCm)&&(identical(other.widthCm, widthCm) || other.widthCm == widthCm)&&(identical(other.heightCm, heightCm) || other.heightCm == heightCm)&&(identical(other.isLocalDeliveryOnly, isLocalDeliveryOnly) || other.isLocalDeliveryOnly == isLocalDeliveryOnly)&&(identical(other.isPerishable, isPerishable) || other.isPerishable == isPerishable)&&(identical(other.estimatedShipDays, estimatedShipDays) || other.estimatedShipDays == estimatedShipDays)&&const DeepCollectionEquality().equals(other.deliveryOptions, deliveryOptions)&&(identical(other.minimumOrderQuantity, minimumOrderQuantity) || other.minimumOrderQuantity == minimumOrderQuantity)&&(identical(other.freeShipping, freeShipping) || other.freeShipping == freeShipping)&&(identical(other.isDigital, isDigital) || other.isDigital == isDigital)&&(identical(other.digitalType, digitalType) || other.digitalType == digitalType)&&(identical(other.slug, slug) || other.slug == slug)&&const DeepCollectionEquality().equals(other.digitalBuilds, digitalBuilds)&&(identical(other.deviceLimit, deviceLimit) || other.deviceLimit == deviceLimit)&&(identical(other.taxCode, taxCode) || other.taxCode == taxCode)&&const DeepCollectionEquality().equals(other.keywords, keywords)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.supplierSku, supplierSku) || other.supplierSku == supplierSku)&&(identical(other.supplierUrl, supplierUrl) || other.supplierUrl == supplierUrl)&&(identical(other.supplier, supplier) || other.supplier == supplier)&&(identical(other.inventory, inventory) || other.inventory == inventory)&&(identical(other.sellerSku, sellerSku) || other.sellerSku == sellerSku)&&const DeepCollectionEquality().equals(other.warehouseIds, warehouseIds)&&(identical(other.shipFromCity, shipFromCity) || other.shipFromCity == shipFromCity)&&(identical(other.shipFromProvince, shipFromProvince) || other.shipFromProvince == shipFromProvince)&&(identical(other.shipFromCountry, shipFromCountry) || other.shipFromCountry == shipFromCountry)&&const DeepCollectionEquality().equals(other.shipFromCountries, shipFromCountries)&&(identical(other.hasVariants, hasVariants) || other.hasVariants == hasVariants)&&const DeepCollectionEquality().equals(other.variants, variants)&&const DeepCollectionEquality().equals(other.variantOptions, variantOptions)&&(identical(other.subcategory, subcategory) || other.subcategory == subcategory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,name,nameF,price,compareAtPrice,description,descriptionF,const DeepCollectionEquality().hash(imageUrls),videoUrl,sellerId,sellerAddress,categoryId,stockQuantity,rating,lifecycleStatus,weightKg,lengthCm,widthCm,heightCm,isLocalDeliveryOnly,isPerishable,estimatedShipDays,const DeepCollectionEquality().hash(deliveryOptions),minimumOrderQuantity,freeShipping,isDigital,digitalType,slug,const DeepCollectionEquality().hash(digitalBuilds),deviceLimit,taxCode,const DeepCollectionEquality().hash(keywords),cost,supplierSku,supplierUrl,supplier,inventory,sellerSku,const DeepCollectionEquality().hash(warehouseIds),shipFromCity,shipFromProvince,shipFromCountry,const DeepCollectionEquality().hash(shipFromCountries),hasVariants,const DeepCollectionEquality().hash(variants),const DeepCollectionEquality().hash(variantOptions),subcategory]);

@override
String toString() {
  return 'ProductCreate(name: $name, nameF: $nameF, price: $price, compareAtPrice: $compareAtPrice, description: $description, descriptionF: $descriptionF, imageUrls: $imageUrls, videoUrl: $videoUrl, sellerId: $sellerId, sellerAddress: $sellerAddress, categoryId: $categoryId, stockQuantity: $stockQuantity, rating: $rating, lifecycleStatus: $lifecycleStatus, weightKg: $weightKg, lengthCm: $lengthCm, widthCm: $widthCm, heightCm: $heightCm, isLocalDeliveryOnly: $isLocalDeliveryOnly, isPerishable: $isPerishable, estimatedShipDays: $estimatedShipDays, deliveryOptions: $deliveryOptions, minimumOrderQuantity: $minimumOrderQuantity, freeShipping: $freeShipping, isDigital: $isDigital, digitalType: $digitalType, slug: $slug, digitalBuilds: $digitalBuilds, deviceLimit: $deviceLimit, taxCode: $taxCode, keywords: $keywords, cost: $cost, supplierSku: $supplierSku, supplierUrl: $supplierUrl, supplier: $supplier, inventory: $inventory, sellerSku: $sellerSku, warehouseIds: $warehouseIds, shipFromCity: $shipFromCity, shipFromProvince: $shipFromProvince, shipFromCountry: $shipFromCountry, shipFromCountries: $shipFromCountries, hasVariants: $hasVariants, variants: $variants, variantOptions: $variantOptions, subcategory: $subcategory)';
}


}

/// @nodoc
abstract mixin class $ProductCreateCopyWith<$Res>  {
  factory $ProductCreateCopyWith(ProductCreate value, $Res Function(ProductCreate) _then) = _$ProductCreateCopyWithImpl;
@useResult
$Res call({
 String name, String? nameF, double price, double? compareAtPrice, String description, String? descriptionF, List<String> imageUrls, String? videoUrl, String sellerId, Address? sellerAddress, int categoryId, int stockQuantity, double rating, String lifecycleStatus, double? weightKg, double? lengthCm, double? widthCm, double? heightCm, bool isLocalDeliveryOnly, bool isPerishable, int estimatedShipDays, List<SellerDeliveryOption> deliveryOptions, int minimumOrderQuantity, bool freeShipping, bool isDigital, String? digitalType, String? slug, Map<String, String>? digitalBuilds, int? deviceLimit, String? taxCode, List<String> keywords, double? cost, String? supplierSku, String? supplierUrl, SupplierInfo? supplier, InventoryConfig? inventory, String? sellerSku, List<String>? warehouseIds, String? shipFromCity, String? shipFromProvince, String? shipFromCountry, List<String>? shipFromCountries, bool hasVariants, List<ProductVariant> variants, List<VariantOption> variantOptions, String? subcategory
});


$AddressCopyWith<$Res>? get sellerAddress;$SupplierInfoCopyWith<$Res>? get supplier;$InventoryConfigCopyWith<$Res>? get inventory;

}
/// @nodoc
class _$ProductCreateCopyWithImpl<$Res>
    implements $ProductCreateCopyWith<$Res> {
  _$ProductCreateCopyWithImpl(this._self, this._then);

  final ProductCreate _self;
  final $Res Function(ProductCreate) _then;

/// Create a copy of ProductCreate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? nameF = freezed,Object? price = null,Object? compareAtPrice = freezed,Object? description = null,Object? descriptionF = freezed,Object? imageUrls = null,Object? videoUrl = freezed,Object? sellerId = null,Object? sellerAddress = freezed,Object? categoryId = null,Object? stockQuantity = null,Object? rating = null,Object? lifecycleStatus = null,Object? weightKg = freezed,Object? lengthCm = freezed,Object? widthCm = freezed,Object? heightCm = freezed,Object? isLocalDeliveryOnly = null,Object? isPerishable = null,Object? estimatedShipDays = null,Object? deliveryOptions = null,Object? minimumOrderQuantity = null,Object? freeShipping = null,Object? isDigital = null,Object? digitalType = freezed,Object? slug = freezed,Object? digitalBuilds = freezed,Object? deviceLimit = freezed,Object? taxCode = freezed,Object? keywords = null,Object? cost = freezed,Object? supplierSku = freezed,Object? supplierUrl = freezed,Object? supplier = freezed,Object? inventory = freezed,Object? sellerSku = freezed,Object? warehouseIds = freezed,Object? shipFromCity = freezed,Object? shipFromProvince = freezed,Object? shipFromCountry = freezed,Object? shipFromCountries = freezed,Object? hasVariants = null,Object? variants = null,Object? variantOptions = null,Object? subcategory = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameF: freezed == nameF ? _self.nameF : nameF // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,compareAtPrice: freezed == compareAtPrice ? _self.compareAtPrice : compareAtPrice // ignore: cast_nullable_to_non_nullable
as double?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,descriptionF: freezed == descriptionF ? _self.descriptionF : descriptionF // ignore: cast_nullable_to_non_nullable
as String?,imageUrls: null == imageUrls ? _self.imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,videoUrl: freezed == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String?,sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,sellerAddress: freezed == sellerAddress ? _self.sellerAddress : sellerAddress // ignore: cast_nullable_to_non_nullable
as Address?,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,lifecycleStatus: null == lifecycleStatus ? _self.lifecycleStatus : lifecycleStatus // ignore: cast_nullable_to_non_nullable
as String,weightKg: freezed == weightKg ? _self.weightKg : weightKg // ignore: cast_nullable_to_non_nullable
as double?,lengthCm: freezed == lengthCm ? _self.lengthCm : lengthCm // ignore: cast_nullable_to_non_nullable
as double?,widthCm: freezed == widthCm ? _self.widthCm : widthCm // ignore: cast_nullable_to_non_nullable
as double?,heightCm: freezed == heightCm ? _self.heightCm : heightCm // ignore: cast_nullable_to_non_nullable
as double?,isLocalDeliveryOnly: null == isLocalDeliveryOnly ? _self.isLocalDeliveryOnly : isLocalDeliveryOnly // ignore: cast_nullable_to_non_nullable
as bool,isPerishable: null == isPerishable ? _self.isPerishable : isPerishable // ignore: cast_nullable_to_non_nullable
as bool,estimatedShipDays: null == estimatedShipDays ? _self.estimatedShipDays : estimatedShipDays // ignore: cast_nullable_to_non_nullable
as int,deliveryOptions: null == deliveryOptions ? _self.deliveryOptions : deliveryOptions // ignore: cast_nullable_to_non_nullable
as List<SellerDeliveryOption>,minimumOrderQuantity: null == minimumOrderQuantity ? _self.minimumOrderQuantity : minimumOrderQuantity // ignore: cast_nullable_to_non_nullable
as int,freeShipping: null == freeShipping ? _self.freeShipping : freeShipping // ignore: cast_nullable_to_non_nullable
as bool,isDigital: null == isDigital ? _self.isDigital : isDigital // ignore: cast_nullable_to_non_nullable
as bool,digitalType: freezed == digitalType ? _self.digitalType : digitalType // ignore: cast_nullable_to_non_nullable
as String?,slug: freezed == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String?,digitalBuilds: freezed == digitalBuilds ? _self.digitalBuilds : digitalBuilds // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,deviceLimit: freezed == deviceLimit ? _self.deviceLimit : deviceLimit // ignore: cast_nullable_to_non_nullable
as int?,taxCode: freezed == taxCode ? _self.taxCode : taxCode // ignore: cast_nullable_to_non_nullable
as String?,keywords: null == keywords ? _self.keywords : keywords // ignore: cast_nullable_to_non_nullable
as List<String>,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,supplierSku: freezed == supplierSku ? _self.supplierSku : supplierSku // ignore: cast_nullable_to_non_nullable
as String?,supplierUrl: freezed == supplierUrl ? _self.supplierUrl : supplierUrl // ignore: cast_nullable_to_non_nullable
as String?,supplier: freezed == supplier ? _self.supplier : supplier // ignore: cast_nullable_to_non_nullable
as SupplierInfo?,inventory: freezed == inventory ? _self.inventory : inventory // ignore: cast_nullable_to_non_nullable
as InventoryConfig?,sellerSku: freezed == sellerSku ? _self.sellerSku : sellerSku // ignore: cast_nullable_to_non_nullable
as String?,warehouseIds: freezed == warehouseIds ? _self.warehouseIds : warehouseIds // ignore: cast_nullable_to_non_nullable
as List<String>?,shipFromCity: freezed == shipFromCity ? _self.shipFromCity : shipFromCity // ignore: cast_nullable_to_non_nullable
as String?,shipFromProvince: freezed == shipFromProvince ? _self.shipFromProvince : shipFromProvince // ignore: cast_nullable_to_non_nullable
as String?,shipFromCountry: freezed == shipFromCountry ? _self.shipFromCountry : shipFromCountry // ignore: cast_nullable_to_non_nullable
as String?,shipFromCountries: freezed == shipFromCountries ? _self.shipFromCountries : shipFromCountries // ignore: cast_nullable_to_non_nullable
as List<String>?,hasVariants: null == hasVariants ? _self.hasVariants : hasVariants // ignore: cast_nullable_to_non_nullable
as bool,variants: null == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as List<ProductVariant>,variantOptions: null == variantOptions ? _self.variantOptions : variantOptions // ignore: cast_nullable_to_non_nullable
as List<VariantOption>,subcategory: freezed == subcategory ? _self.subcategory : subcategory // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ProductCreate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get sellerAddress {
    if (_self.sellerAddress == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.sellerAddress!, (value) {
    return _then(_self.copyWith(sellerAddress: value));
  });
}/// Create a copy of ProductCreate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupplierInfoCopyWith<$Res>? get supplier {
    if (_self.supplier == null) {
    return null;
  }

  return $SupplierInfoCopyWith<$Res>(_self.supplier!, (value) {
    return _then(_self.copyWith(supplier: value));
  });
}/// Create a copy of ProductCreate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InventoryConfigCopyWith<$Res>? get inventory {
    if (_self.inventory == null) {
    return null;
  }

  return $InventoryConfigCopyWith<$Res>(_self.inventory!, (value) {
    return _then(_self.copyWith(inventory: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProductCreate].
extension ProductCreatePatterns on ProductCreate {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductCreate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductCreate() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductCreate value)  $default,){
final _that = this;
switch (_that) {
case _ProductCreate():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductCreate value)?  $default,){
final _that = this;
switch (_that) {
case _ProductCreate() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? nameF,  double price,  double? compareAtPrice,  String description,  String? descriptionF,  List<String> imageUrls,  String? videoUrl,  String sellerId,  Address? sellerAddress,  int categoryId,  int stockQuantity,  double rating,  String lifecycleStatus,  double? weightKg,  double? lengthCm,  double? widthCm,  double? heightCm,  bool isLocalDeliveryOnly,  bool isPerishable,  int estimatedShipDays,  List<SellerDeliveryOption> deliveryOptions,  int minimumOrderQuantity,  bool freeShipping,  bool isDigital,  String? digitalType,  String? slug,  Map<String, String>? digitalBuilds,  int? deviceLimit,  String? taxCode,  List<String> keywords,  double? cost,  String? supplierSku,  String? supplierUrl,  SupplierInfo? supplier,  InventoryConfig? inventory,  String? sellerSku,  List<String>? warehouseIds,  String? shipFromCity,  String? shipFromProvince,  String? shipFromCountry,  List<String>? shipFromCountries,  bool hasVariants,  List<ProductVariant> variants,  List<VariantOption> variantOptions,  String? subcategory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductCreate() when $default != null:
return $default(_that.name,_that.nameF,_that.price,_that.compareAtPrice,_that.description,_that.descriptionF,_that.imageUrls,_that.videoUrl,_that.sellerId,_that.sellerAddress,_that.categoryId,_that.stockQuantity,_that.rating,_that.lifecycleStatus,_that.weightKg,_that.lengthCm,_that.widthCm,_that.heightCm,_that.isLocalDeliveryOnly,_that.isPerishable,_that.estimatedShipDays,_that.deliveryOptions,_that.minimumOrderQuantity,_that.freeShipping,_that.isDigital,_that.digitalType,_that.slug,_that.digitalBuilds,_that.deviceLimit,_that.taxCode,_that.keywords,_that.cost,_that.supplierSku,_that.supplierUrl,_that.supplier,_that.inventory,_that.sellerSku,_that.warehouseIds,_that.shipFromCity,_that.shipFromProvince,_that.shipFromCountry,_that.shipFromCountries,_that.hasVariants,_that.variants,_that.variantOptions,_that.subcategory);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? nameF,  double price,  double? compareAtPrice,  String description,  String? descriptionF,  List<String> imageUrls,  String? videoUrl,  String sellerId,  Address? sellerAddress,  int categoryId,  int stockQuantity,  double rating,  String lifecycleStatus,  double? weightKg,  double? lengthCm,  double? widthCm,  double? heightCm,  bool isLocalDeliveryOnly,  bool isPerishable,  int estimatedShipDays,  List<SellerDeliveryOption> deliveryOptions,  int minimumOrderQuantity,  bool freeShipping,  bool isDigital,  String? digitalType,  String? slug,  Map<String, String>? digitalBuilds,  int? deviceLimit,  String? taxCode,  List<String> keywords,  double? cost,  String? supplierSku,  String? supplierUrl,  SupplierInfo? supplier,  InventoryConfig? inventory,  String? sellerSku,  List<String>? warehouseIds,  String? shipFromCity,  String? shipFromProvince,  String? shipFromCountry,  List<String>? shipFromCountries,  bool hasVariants,  List<ProductVariant> variants,  List<VariantOption> variantOptions,  String? subcategory)  $default,) {final _that = this;
switch (_that) {
case _ProductCreate():
return $default(_that.name,_that.nameF,_that.price,_that.compareAtPrice,_that.description,_that.descriptionF,_that.imageUrls,_that.videoUrl,_that.sellerId,_that.sellerAddress,_that.categoryId,_that.stockQuantity,_that.rating,_that.lifecycleStatus,_that.weightKg,_that.lengthCm,_that.widthCm,_that.heightCm,_that.isLocalDeliveryOnly,_that.isPerishable,_that.estimatedShipDays,_that.deliveryOptions,_that.minimumOrderQuantity,_that.freeShipping,_that.isDigital,_that.digitalType,_that.slug,_that.digitalBuilds,_that.deviceLimit,_that.taxCode,_that.keywords,_that.cost,_that.supplierSku,_that.supplierUrl,_that.supplier,_that.inventory,_that.sellerSku,_that.warehouseIds,_that.shipFromCity,_that.shipFromProvince,_that.shipFromCountry,_that.shipFromCountries,_that.hasVariants,_that.variants,_that.variantOptions,_that.subcategory);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? nameF,  double price,  double? compareAtPrice,  String description,  String? descriptionF,  List<String> imageUrls,  String? videoUrl,  String sellerId,  Address? sellerAddress,  int categoryId,  int stockQuantity,  double rating,  String lifecycleStatus,  double? weightKg,  double? lengthCm,  double? widthCm,  double? heightCm,  bool isLocalDeliveryOnly,  bool isPerishable,  int estimatedShipDays,  List<SellerDeliveryOption> deliveryOptions,  int minimumOrderQuantity,  bool freeShipping,  bool isDigital,  String? digitalType,  String? slug,  Map<String, String>? digitalBuilds,  int? deviceLimit,  String? taxCode,  List<String> keywords,  double? cost,  String? supplierSku,  String? supplierUrl,  SupplierInfo? supplier,  InventoryConfig? inventory,  String? sellerSku,  List<String>? warehouseIds,  String? shipFromCity,  String? shipFromProvince,  String? shipFromCountry,  List<String>? shipFromCountries,  bool hasVariants,  List<ProductVariant> variants,  List<VariantOption> variantOptions,  String? subcategory)?  $default,) {final _that = this;
switch (_that) {
case _ProductCreate() when $default != null:
return $default(_that.name,_that.nameF,_that.price,_that.compareAtPrice,_that.description,_that.descriptionF,_that.imageUrls,_that.videoUrl,_that.sellerId,_that.sellerAddress,_that.categoryId,_that.stockQuantity,_that.rating,_that.lifecycleStatus,_that.weightKg,_that.lengthCm,_that.widthCm,_that.heightCm,_that.isLocalDeliveryOnly,_that.isPerishable,_that.estimatedShipDays,_that.deliveryOptions,_that.minimumOrderQuantity,_that.freeShipping,_that.isDigital,_that.digitalType,_that.slug,_that.digitalBuilds,_that.deviceLimit,_that.taxCode,_that.keywords,_that.cost,_that.supplierSku,_that.supplierUrl,_that.supplier,_that.inventory,_that.sellerSku,_that.warehouseIds,_that.shipFromCity,_that.shipFromProvince,_that.shipFromCountry,_that.shipFromCountries,_that.hasVariants,_that.variants,_that.variantOptions,_that.subcategory);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductCreate implements ProductCreate {
  const _ProductCreate({required this.name, this.nameF, required this.price, this.compareAtPrice, required this.description, this.descriptionF, required final  List<String> imageUrls, this.videoUrl, required this.sellerId, this.sellerAddress, required this.categoryId, required this.stockQuantity, this.rating = 0.0, this.lifecycleStatus = ProductLifecycleStatusValues.draft, this.weightKg, this.lengthCm, this.widthCm, this.heightCm, this.isLocalDeliveryOnly = false, this.isPerishable = false, this.estimatedShipDays = 3, final  List<SellerDeliveryOption> deliveryOptions = const [], this.minimumOrderQuantity = 1, this.freeShipping = false, this.isDigital = false, this.digitalType, this.slug, final  Map<String, String>? digitalBuilds, this.deviceLimit, this.taxCode, final  List<String> keywords = const [], this.cost, this.supplierSku, this.supplierUrl, this.supplier, this.inventory, this.sellerSku, final  List<String>? warehouseIds, this.shipFromCity, this.shipFromProvince, this.shipFromCountry, final  List<String>? shipFromCountries, this.hasVariants = false, final  List<ProductVariant> variants = const [], final  List<VariantOption> variantOptions = const [], this.subcategory}): _imageUrls = imageUrls,_deliveryOptions = deliveryOptions,_digitalBuilds = digitalBuilds,_keywords = keywords,_warehouseIds = warehouseIds,_shipFromCountries = shipFromCountries,_variants = variants,_variantOptions = variantOptions;
  factory _ProductCreate.fromJson(Map<String, dynamic> json) => _$ProductCreateFromJson(json);

@override final  String name;
@override final  String? nameF;
@override final  double price;
/// Original/crossed-out price for discount display (null = no sale, must be > price)
@override final  double? compareAtPrice;
@override final  String description;
@override final  String? descriptionF;
 final  List<String> _imageUrls;
@override List<String> get imageUrls {
  if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_imageUrls);
}

@override final  String? videoUrl;
@override final  String sellerId;
// sellerAddress is optional — required only when warehouseIds is not provided
@override final  Address? sellerAddress;
@override final  int categoryId;
@override final  int stockQuantity;
@override@JsonKey() final  double rating;
@override@JsonKey() final  String lifecycleStatus;
@override final  double? weightKg;
@override final  double? lengthCm;
@override final  double? widthCm;
@override final  double? heightCm;
@override@JsonKey() final  bool isLocalDeliveryOnly;
@override@JsonKey() final  bool isPerishable;
@override@JsonKey() final  int estimatedShipDays;
 final  List<SellerDeliveryOption> _deliveryOptions;
@override@JsonKey() List<SellerDeliveryOption> get deliveryOptions {
  if (_deliveryOptions is EqualUnmodifiableListView) return _deliveryOptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deliveryOptions);
}

@override@JsonKey() final  int minimumOrderQuantity;
@override@JsonKey() final  bool freeShipping;
@override@JsonKey() final  bool isDigital;
@override final  String? digitalType;
@override final  String? slug;
 final  Map<String, String>? _digitalBuilds;
@override Map<String, String>? get digitalBuilds {
  final value = _digitalBuilds;
  if (value == null) return null;
  if (_digitalBuilds is EqualUnmodifiableMapView) return _digitalBuilds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

// bookSourceUrl intentionally NOT included — buyer-protected: written by seller, never returned to client
@override final  int? deviceLimit;
@override final  String? taxCode;
 final  List<String> _keywords;
@override@JsonKey() List<String> get keywords {
  if (_keywords is EqualUnmodifiableListView) return _keywords;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_keywords);
}

// lifecycleStatus intentionally defaults to draft — backend sets under_review on creation
// Flat supplier fields (used when supplier object is not provided)
@override final  double? cost;
@override final  String? supplierSku;
@override final  String? supplierUrl;
// Structured objects
@override final  SupplierInfo? supplier;
@override final  InventoryConfig? inventory;
// Multi-warehouse support
@override final  String? sellerSku;
 final  List<String>? _warehouseIds;
@override List<String>? get warehouseIds {
  final value = _warehouseIds;
  if (value == null) return null;
  if (_warehouseIds is EqualUnmodifiableListView) return _warehouseIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? shipFromCity;
@override final  String? shipFromProvince;
@override final  String? shipFromCountry;
 final  List<String>? _shipFromCountries;
@override List<String>? get shipFromCountries {
  final value = _shipFromCountries;
  if (value == null) return null;
  if (_shipFromCountries is EqualUnmodifiableListView) return _shipFromCountries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// === N-09: Product Variants ===
@override@JsonKey() final  bool hasVariants;
 final  List<ProductVariant> _variants;
@override@JsonKey() List<ProductVariant> get variants {
  if (_variants is EqualUnmodifiableListView) return _variants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_variants);
}

 final  List<VariantOption> _variantOptions;
@override@JsonKey() List<VariantOption> get variantOptions {
  if (_variantOptions is EqualUnmodifiableListView) return _variantOptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_variantOptions);
}

// === N-11: Subcategories ===
@override final  String? subcategory;

/// Create a copy of ProductCreate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductCreateCopyWith<_ProductCreate> get copyWith => __$ProductCreateCopyWithImpl<_ProductCreate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductCreateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductCreate&&(identical(other.name, name) || other.name == name)&&(identical(other.nameF, nameF) || other.nameF == nameF)&&(identical(other.price, price) || other.price == price)&&(identical(other.compareAtPrice, compareAtPrice) || other.compareAtPrice == compareAtPrice)&&(identical(other.description, description) || other.description == description)&&(identical(other.descriptionF, descriptionF) || other.descriptionF == descriptionF)&&const DeepCollectionEquality().equals(other._imageUrls, _imageUrls)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.sellerAddress, sellerAddress) || other.sellerAddress == sellerAddress)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.lifecycleStatus, lifecycleStatus) || other.lifecycleStatus == lifecycleStatus)&&(identical(other.weightKg, weightKg) || other.weightKg == weightKg)&&(identical(other.lengthCm, lengthCm) || other.lengthCm == lengthCm)&&(identical(other.widthCm, widthCm) || other.widthCm == widthCm)&&(identical(other.heightCm, heightCm) || other.heightCm == heightCm)&&(identical(other.isLocalDeliveryOnly, isLocalDeliveryOnly) || other.isLocalDeliveryOnly == isLocalDeliveryOnly)&&(identical(other.isPerishable, isPerishable) || other.isPerishable == isPerishable)&&(identical(other.estimatedShipDays, estimatedShipDays) || other.estimatedShipDays == estimatedShipDays)&&const DeepCollectionEquality().equals(other._deliveryOptions, _deliveryOptions)&&(identical(other.minimumOrderQuantity, minimumOrderQuantity) || other.minimumOrderQuantity == minimumOrderQuantity)&&(identical(other.freeShipping, freeShipping) || other.freeShipping == freeShipping)&&(identical(other.isDigital, isDigital) || other.isDigital == isDigital)&&(identical(other.digitalType, digitalType) || other.digitalType == digitalType)&&(identical(other.slug, slug) || other.slug == slug)&&const DeepCollectionEquality().equals(other._digitalBuilds, _digitalBuilds)&&(identical(other.deviceLimit, deviceLimit) || other.deviceLimit == deviceLimit)&&(identical(other.taxCode, taxCode) || other.taxCode == taxCode)&&const DeepCollectionEquality().equals(other._keywords, _keywords)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.supplierSku, supplierSku) || other.supplierSku == supplierSku)&&(identical(other.supplierUrl, supplierUrl) || other.supplierUrl == supplierUrl)&&(identical(other.supplier, supplier) || other.supplier == supplier)&&(identical(other.inventory, inventory) || other.inventory == inventory)&&(identical(other.sellerSku, sellerSku) || other.sellerSku == sellerSku)&&const DeepCollectionEquality().equals(other._warehouseIds, _warehouseIds)&&(identical(other.shipFromCity, shipFromCity) || other.shipFromCity == shipFromCity)&&(identical(other.shipFromProvince, shipFromProvince) || other.shipFromProvince == shipFromProvince)&&(identical(other.shipFromCountry, shipFromCountry) || other.shipFromCountry == shipFromCountry)&&const DeepCollectionEquality().equals(other._shipFromCountries, _shipFromCountries)&&(identical(other.hasVariants, hasVariants) || other.hasVariants == hasVariants)&&const DeepCollectionEquality().equals(other._variants, _variants)&&const DeepCollectionEquality().equals(other._variantOptions, _variantOptions)&&(identical(other.subcategory, subcategory) || other.subcategory == subcategory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,name,nameF,price,compareAtPrice,description,descriptionF,const DeepCollectionEquality().hash(_imageUrls),videoUrl,sellerId,sellerAddress,categoryId,stockQuantity,rating,lifecycleStatus,weightKg,lengthCm,widthCm,heightCm,isLocalDeliveryOnly,isPerishable,estimatedShipDays,const DeepCollectionEquality().hash(_deliveryOptions),minimumOrderQuantity,freeShipping,isDigital,digitalType,slug,const DeepCollectionEquality().hash(_digitalBuilds),deviceLimit,taxCode,const DeepCollectionEquality().hash(_keywords),cost,supplierSku,supplierUrl,supplier,inventory,sellerSku,const DeepCollectionEquality().hash(_warehouseIds),shipFromCity,shipFromProvince,shipFromCountry,const DeepCollectionEquality().hash(_shipFromCountries),hasVariants,const DeepCollectionEquality().hash(_variants),const DeepCollectionEquality().hash(_variantOptions),subcategory]);

@override
String toString() {
  return 'ProductCreate(name: $name, nameF: $nameF, price: $price, compareAtPrice: $compareAtPrice, description: $description, descriptionF: $descriptionF, imageUrls: $imageUrls, videoUrl: $videoUrl, sellerId: $sellerId, sellerAddress: $sellerAddress, categoryId: $categoryId, stockQuantity: $stockQuantity, rating: $rating, lifecycleStatus: $lifecycleStatus, weightKg: $weightKg, lengthCm: $lengthCm, widthCm: $widthCm, heightCm: $heightCm, isLocalDeliveryOnly: $isLocalDeliveryOnly, isPerishable: $isPerishable, estimatedShipDays: $estimatedShipDays, deliveryOptions: $deliveryOptions, minimumOrderQuantity: $minimumOrderQuantity, freeShipping: $freeShipping, isDigital: $isDigital, digitalType: $digitalType, slug: $slug, digitalBuilds: $digitalBuilds, deviceLimit: $deviceLimit, taxCode: $taxCode, keywords: $keywords, cost: $cost, supplierSku: $supplierSku, supplierUrl: $supplierUrl, supplier: $supplier, inventory: $inventory, sellerSku: $sellerSku, warehouseIds: $warehouseIds, shipFromCity: $shipFromCity, shipFromProvince: $shipFromProvince, shipFromCountry: $shipFromCountry, shipFromCountries: $shipFromCountries, hasVariants: $hasVariants, variants: $variants, variantOptions: $variantOptions, subcategory: $subcategory)';
}


}

/// @nodoc
abstract mixin class _$ProductCreateCopyWith<$Res> implements $ProductCreateCopyWith<$Res> {
  factory _$ProductCreateCopyWith(_ProductCreate value, $Res Function(_ProductCreate) _then) = __$ProductCreateCopyWithImpl;
@override @useResult
$Res call({
 String name, String? nameF, double price, double? compareAtPrice, String description, String? descriptionF, List<String> imageUrls, String? videoUrl, String sellerId, Address? sellerAddress, int categoryId, int stockQuantity, double rating, String lifecycleStatus, double? weightKg, double? lengthCm, double? widthCm, double? heightCm, bool isLocalDeliveryOnly, bool isPerishable, int estimatedShipDays, List<SellerDeliveryOption> deliveryOptions, int minimumOrderQuantity, bool freeShipping, bool isDigital, String? digitalType, String? slug, Map<String, String>? digitalBuilds, int? deviceLimit, String? taxCode, List<String> keywords, double? cost, String? supplierSku, String? supplierUrl, SupplierInfo? supplier, InventoryConfig? inventory, String? sellerSku, List<String>? warehouseIds, String? shipFromCity, String? shipFromProvince, String? shipFromCountry, List<String>? shipFromCountries, bool hasVariants, List<ProductVariant> variants, List<VariantOption> variantOptions, String? subcategory
});


@override $AddressCopyWith<$Res>? get sellerAddress;@override $SupplierInfoCopyWith<$Res>? get supplier;@override $InventoryConfigCopyWith<$Res>? get inventory;

}
/// @nodoc
class __$ProductCreateCopyWithImpl<$Res>
    implements _$ProductCreateCopyWith<$Res> {
  __$ProductCreateCopyWithImpl(this._self, this._then);

  final _ProductCreate _self;
  final $Res Function(_ProductCreate) _then;

/// Create a copy of ProductCreate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? nameF = freezed,Object? price = null,Object? compareAtPrice = freezed,Object? description = null,Object? descriptionF = freezed,Object? imageUrls = null,Object? videoUrl = freezed,Object? sellerId = null,Object? sellerAddress = freezed,Object? categoryId = null,Object? stockQuantity = null,Object? rating = null,Object? lifecycleStatus = null,Object? weightKg = freezed,Object? lengthCm = freezed,Object? widthCm = freezed,Object? heightCm = freezed,Object? isLocalDeliveryOnly = null,Object? isPerishable = null,Object? estimatedShipDays = null,Object? deliveryOptions = null,Object? minimumOrderQuantity = null,Object? freeShipping = null,Object? isDigital = null,Object? digitalType = freezed,Object? slug = freezed,Object? digitalBuilds = freezed,Object? deviceLimit = freezed,Object? taxCode = freezed,Object? keywords = null,Object? cost = freezed,Object? supplierSku = freezed,Object? supplierUrl = freezed,Object? supplier = freezed,Object? inventory = freezed,Object? sellerSku = freezed,Object? warehouseIds = freezed,Object? shipFromCity = freezed,Object? shipFromProvince = freezed,Object? shipFromCountry = freezed,Object? shipFromCountries = freezed,Object? hasVariants = null,Object? variants = null,Object? variantOptions = null,Object? subcategory = freezed,}) {
  return _then(_ProductCreate(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameF: freezed == nameF ? _self.nameF : nameF // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,compareAtPrice: freezed == compareAtPrice ? _self.compareAtPrice : compareAtPrice // ignore: cast_nullable_to_non_nullable
as double?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,descriptionF: freezed == descriptionF ? _self.descriptionF : descriptionF // ignore: cast_nullable_to_non_nullable
as String?,imageUrls: null == imageUrls ? _self._imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,videoUrl: freezed == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String?,sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,sellerAddress: freezed == sellerAddress ? _self.sellerAddress : sellerAddress // ignore: cast_nullable_to_non_nullable
as Address?,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,lifecycleStatus: null == lifecycleStatus ? _self.lifecycleStatus : lifecycleStatus // ignore: cast_nullable_to_non_nullable
as String,weightKg: freezed == weightKg ? _self.weightKg : weightKg // ignore: cast_nullable_to_non_nullable
as double?,lengthCm: freezed == lengthCm ? _self.lengthCm : lengthCm // ignore: cast_nullable_to_non_nullable
as double?,widthCm: freezed == widthCm ? _self.widthCm : widthCm // ignore: cast_nullable_to_non_nullable
as double?,heightCm: freezed == heightCm ? _self.heightCm : heightCm // ignore: cast_nullable_to_non_nullable
as double?,isLocalDeliveryOnly: null == isLocalDeliveryOnly ? _self.isLocalDeliveryOnly : isLocalDeliveryOnly // ignore: cast_nullable_to_non_nullable
as bool,isPerishable: null == isPerishable ? _self.isPerishable : isPerishable // ignore: cast_nullable_to_non_nullable
as bool,estimatedShipDays: null == estimatedShipDays ? _self.estimatedShipDays : estimatedShipDays // ignore: cast_nullable_to_non_nullable
as int,deliveryOptions: null == deliveryOptions ? _self._deliveryOptions : deliveryOptions // ignore: cast_nullable_to_non_nullable
as List<SellerDeliveryOption>,minimumOrderQuantity: null == minimumOrderQuantity ? _self.minimumOrderQuantity : minimumOrderQuantity // ignore: cast_nullable_to_non_nullable
as int,freeShipping: null == freeShipping ? _self.freeShipping : freeShipping // ignore: cast_nullable_to_non_nullable
as bool,isDigital: null == isDigital ? _self.isDigital : isDigital // ignore: cast_nullable_to_non_nullable
as bool,digitalType: freezed == digitalType ? _self.digitalType : digitalType // ignore: cast_nullable_to_non_nullable
as String?,slug: freezed == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String?,digitalBuilds: freezed == digitalBuilds ? _self._digitalBuilds : digitalBuilds // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,deviceLimit: freezed == deviceLimit ? _self.deviceLimit : deviceLimit // ignore: cast_nullable_to_non_nullable
as int?,taxCode: freezed == taxCode ? _self.taxCode : taxCode // ignore: cast_nullable_to_non_nullable
as String?,keywords: null == keywords ? _self._keywords : keywords // ignore: cast_nullable_to_non_nullable
as List<String>,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,supplierSku: freezed == supplierSku ? _self.supplierSku : supplierSku // ignore: cast_nullable_to_non_nullable
as String?,supplierUrl: freezed == supplierUrl ? _self.supplierUrl : supplierUrl // ignore: cast_nullable_to_non_nullable
as String?,supplier: freezed == supplier ? _self.supplier : supplier // ignore: cast_nullable_to_non_nullable
as SupplierInfo?,inventory: freezed == inventory ? _self.inventory : inventory // ignore: cast_nullable_to_non_nullable
as InventoryConfig?,sellerSku: freezed == sellerSku ? _self.sellerSku : sellerSku // ignore: cast_nullable_to_non_nullable
as String?,warehouseIds: freezed == warehouseIds ? _self._warehouseIds : warehouseIds // ignore: cast_nullable_to_non_nullable
as List<String>?,shipFromCity: freezed == shipFromCity ? _self.shipFromCity : shipFromCity // ignore: cast_nullable_to_non_nullable
as String?,shipFromProvince: freezed == shipFromProvince ? _self.shipFromProvince : shipFromProvince // ignore: cast_nullable_to_non_nullable
as String?,shipFromCountry: freezed == shipFromCountry ? _self.shipFromCountry : shipFromCountry // ignore: cast_nullable_to_non_nullable
as String?,shipFromCountries: freezed == shipFromCountries ? _self._shipFromCountries : shipFromCountries // ignore: cast_nullable_to_non_nullable
as List<String>?,hasVariants: null == hasVariants ? _self.hasVariants : hasVariants // ignore: cast_nullable_to_non_nullable
as bool,variants: null == variants ? _self._variants : variants // ignore: cast_nullable_to_non_nullable
as List<ProductVariant>,variantOptions: null == variantOptions ? _self._variantOptions : variantOptions // ignore: cast_nullable_to_non_nullable
as List<VariantOption>,subcategory: freezed == subcategory ? _self.subcategory : subcategory // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ProductCreate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get sellerAddress {
    if (_self.sellerAddress == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.sellerAddress!, (value) {
    return _then(_self.copyWith(sellerAddress: value));
  });
}/// Create a copy of ProductCreate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupplierInfoCopyWith<$Res>? get supplier {
    if (_self.supplier == null) {
    return null;
  }

  return $SupplierInfoCopyWith<$Res>(_self.supplier!, (value) {
    return _then(_self.copyWith(supplier: value));
  });
}/// Create a copy of ProductCreate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InventoryConfigCopyWith<$Res>? get inventory {
    if (_self.inventory == null) {
    return null;
  }

  return $InventoryConfigCopyWith<$Res>(_self.inventory!, (value) {
    return _then(_self.copyWith(inventory: value));
  });
}
}


/// @nodoc
mixin _$VariantOption {

 String get name; List<String> get values;
/// Create a copy of VariantOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VariantOptionCopyWith<VariantOption> get copyWith => _$VariantOptionCopyWithImpl<VariantOption>(this as VariantOption, _$identity);

  /// Serializes this VariantOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VariantOption&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.values, values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(values));

@override
String toString() {
  return 'VariantOption(name: $name, values: $values)';
}


}

/// @nodoc
abstract mixin class $VariantOptionCopyWith<$Res>  {
  factory $VariantOptionCopyWith(VariantOption value, $Res Function(VariantOption) _then) = _$VariantOptionCopyWithImpl;
@useResult
$Res call({
 String name, List<String> values
});




}
/// @nodoc
class _$VariantOptionCopyWithImpl<$Res>
    implements $VariantOptionCopyWith<$Res> {
  _$VariantOptionCopyWithImpl(this._self, this._then);

  final VariantOption _self;
  final $Res Function(VariantOption) _then;

/// Create a copy of VariantOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? values = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [VariantOption].
extension VariantOptionPatterns on VariantOption {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VariantOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VariantOption() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VariantOption value)  $default,){
final _that = this;
switch (_that) {
case _VariantOption():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VariantOption value)?  $default,){
final _that = this;
switch (_that) {
case _VariantOption() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  List<String> values)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VariantOption() when $default != null:
return $default(_that.name,_that.values);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  List<String> values)  $default,) {final _that = this;
switch (_that) {
case _VariantOption():
return $default(_that.name,_that.values);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  List<String> values)?  $default,) {final _that = this;
switch (_that) {
case _VariantOption() when $default != null:
return $default(_that.name,_that.values);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VariantOption implements VariantOption {
  const _VariantOption({required this.name, required final  List<String> values}): _values = values;
  factory _VariantOption.fromJson(Map<String, dynamic> json) => _$VariantOptionFromJson(json);

@override final  String name;
 final  List<String> _values;
@override List<String> get values {
  if (_values is EqualUnmodifiableListView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_values);
}


/// Create a copy of VariantOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VariantOptionCopyWith<_VariantOption> get copyWith => __$VariantOptionCopyWithImpl<_VariantOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VariantOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VariantOption&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._values, _values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(_values));

@override
String toString() {
  return 'VariantOption(name: $name, values: $values)';
}


}

/// @nodoc
abstract mixin class _$VariantOptionCopyWith<$Res> implements $VariantOptionCopyWith<$Res> {
  factory _$VariantOptionCopyWith(_VariantOption value, $Res Function(_VariantOption) _then) = __$VariantOptionCopyWithImpl;
@override @useResult
$Res call({
 String name, List<String> values
});




}
/// @nodoc
class __$VariantOptionCopyWithImpl<$Res>
    implements _$VariantOptionCopyWith<$Res> {
  __$VariantOptionCopyWithImpl(this._self, this._then);

  final _VariantOption _self;
  final $Res Function(_VariantOption) _then;

/// Create a copy of VariantOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? values = null,}) {
  return _then(_VariantOption(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$ProductVariant {

 String get variantId; Map<String, String> get optionValues; int? get priceCents; int get stockQuantity; String? get sku; bool get isActive;
/// Create a copy of ProductVariant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductVariantCopyWith<ProductVariant> get copyWith => _$ProductVariantCopyWithImpl<ProductVariant>(this as ProductVariant, _$identity);

  /// Serializes this ProductVariant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductVariant&&(identical(other.variantId, variantId) || other.variantId == variantId)&&const DeepCollectionEquality().equals(other.optionValues, optionValues)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,variantId,const DeepCollectionEquality().hash(optionValues),priceCents,stockQuantity,sku,isActive);

@override
String toString() {
  return 'ProductVariant(variantId: $variantId, optionValues: $optionValues, priceCents: $priceCents, stockQuantity: $stockQuantity, sku: $sku, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class $ProductVariantCopyWith<$Res>  {
  factory $ProductVariantCopyWith(ProductVariant value, $Res Function(ProductVariant) _then) = _$ProductVariantCopyWithImpl;
@useResult
$Res call({
 String variantId, Map<String, String> optionValues, int? priceCents, int stockQuantity, String? sku, bool isActive
});




}
/// @nodoc
class _$ProductVariantCopyWithImpl<$Res>
    implements $ProductVariantCopyWith<$Res> {
  _$ProductVariantCopyWithImpl(this._self, this._then);

  final ProductVariant _self;
  final $Res Function(ProductVariant) _then;

/// Create a copy of ProductVariant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? variantId = null,Object? optionValues = null,Object? priceCents = freezed,Object? stockQuantity = null,Object? sku = freezed,Object? isActive = null,}) {
  return _then(_self.copyWith(
variantId: null == variantId ? _self.variantId : variantId // ignore: cast_nullable_to_non_nullable
as String,optionValues: null == optionValues ? _self.optionValues : optionValues // ignore: cast_nullable_to_non_nullable
as Map<String, String>,priceCents: freezed == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int?,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductVariant].
extension ProductVariantPatterns on ProductVariant {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductVariant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductVariant() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductVariant value)  $default,){
final _that = this;
switch (_that) {
case _ProductVariant():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductVariant value)?  $default,){
final _that = this;
switch (_that) {
case _ProductVariant() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String variantId,  Map<String, String> optionValues,  int? priceCents,  int stockQuantity,  String? sku,  bool isActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductVariant() when $default != null:
return $default(_that.variantId,_that.optionValues,_that.priceCents,_that.stockQuantity,_that.sku,_that.isActive);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String variantId,  Map<String, String> optionValues,  int? priceCents,  int stockQuantity,  String? sku,  bool isActive)  $default,) {final _that = this;
switch (_that) {
case _ProductVariant():
return $default(_that.variantId,_that.optionValues,_that.priceCents,_that.stockQuantity,_that.sku,_that.isActive);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String variantId,  Map<String, String> optionValues,  int? priceCents,  int stockQuantity,  String? sku,  bool isActive)?  $default,) {final _that = this;
switch (_that) {
case _ProductVariant() when $default != null:
return $default(_that.variantId,_that.optionValues,_that.priceCents,_that.stockQuantity,_that.sku,_that.isActive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductVariant implements ProductVariant {
  const _ProductVariant({this.variantId = '', required final  Map<String, String> optionValues, this.priceCents, required this.stockQuantity, this.sku, this.isActive = true}): _optionValues = optionValues;
  factory _ProductVariant.fromJson(Map<String, dynamic> json) => _$ProductVariantFromJson(json);

@override@JsonKey() final  String variantId;
 final  Map<String, String> _optionValues;
@override Map<String, String> get optionValues {
  if (_optionValues is EqualUnmodifiableMapView) return _optionValues;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_optionValues);
}

@override final  int? priceCents;
@override final  int stockQuantity;
@override final  String? sku;
@override@JsonKey() final  bool isActive;

/// Create a copy of ProductVariant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductVariantCopyWith<_ProductVariant> get copyWith => __$ProductVariantCopyWithImpl<_ProductVariant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductVariantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductVariant&&(identical(other.variantId, variantId) || other.variantId == variantId)&&const DeepCollectionEquality().equals(other._optionValues, _optionValues)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,variantId,const DeepCollectionEquality().hash(_optionValues),priceCents,stockQuantity,sku,isActive);

@override
String toString() {
  return 'ProductVariant(variantId: $variantId, optionValues: $optionValues, priceCents: $priceCents, stockQuantity: $stockQuantity, sku: $sku, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class _$ProductVariantCopyWith<$Res> implements $ProductVariantCopyWith<$Res> {
  factory _$ProductVariantCopyWith(_ProductVariant value, $Res Function(_ProductVariant) _then) = __$ProductVariantCopyWithImpl;
@override @useResult
$Res call({
 String variantId, Map<String, String> optionValues, int? priceCents, int stockQuantity, String? sku, bool isActive
});




}
/// @nodoc
class __$ProductVariantCopyWithImpl<$Res>
    implements _$ProductVariantCopyWith<$Res> {
  __$ProductVariantCopyWithImpl(this._self, this._then);

  final _ProductVariant _self;
  final $Res Function(_ProductVariant) _then;

/// Create a copy of ProductVariant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? variantId = null,Object? optionValues = null,Object? priceCents = freezed,Object? stockQuantity = null,Object? sku = freezed,Object? isActive = null,}) {
  return _then(_ProductVariant(
variantId: null == variantId ? _self.variantId : variantId // ignore: cast_nullable_to_non_nullable
as String,optionValues: null == optionValues ? _self._optionValues : optionValues // ignore: cast_nullable_to_non_nullable
as Map<String, String>,priceCents: freezed == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int?,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ProductQuestion {

 String get questionId; String get productId; String get sellerId; String get askerId; String get question; String? get answer; DateTime? get answeredAt; String? get answeredBy; bool get isAnswered; int get upvotes; DateTime get createdAt;
/// Create a copy of ProductQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductQuestionCopyWith<ProductQuestion> get copyWith => _$ProductQuestionCopyWithImpl<ProductQuestion>(this as ProductQuestion, _$identity);

  /// Serializes this ProductQuestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductQuestion&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.askerId, askerId) || other.askerId == askerId)&&(identical(other.question, question) || other.question == question)&&(identical(other.answer, answer) || other.answer == answer)&&(identical(other.answeredAt, answeredAt) || other.answeredAt == answeredAt)&&(identical(other.answeredBy, answeredBy) || other.answeredBy == answeredBy)&&(identical(other.isAnswered, isAnswered) || other.isAnswered == isAnswered)&&(identical(other.upvotes, upvotes) || other.upvotes == upvotes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionId,productId,sellerId,askerId,question,answer,answeredAt,answeredBy,isAnswered,upvotes,createdAt);

@override
String toString() {
  return 'ProductQuestion(questionId: $questionId, productId: $productId, sellerId: $sellerId, askerId: $askerId, question: $question, answer: $answer, answeredAt: $answeredAt, answeredBy: $answeredBy, isAnswered: $isAnswered, upvotes: $upvotes, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ProductQuestionCopyWith<$Res>  {
  factory $ProductQuestionCopyWith(ProductQuestion value, $Res Function(ProductQuestion) _then) = _$ProductQuestionCopyWithImpl;
@useResult
$Res call({
 String questionId, String productId, String sellerId, String askerId, String question, String? answer, DateTime? answeredAt, String? answeredBy, bool isAnswered, int upvotes, DateTime createdAt
});




}
/// @nodoc
class _$ProductQuestionCopyWithImpl<$Res>
    implements $ProductQuestionCopyWith<$Res> {
  _$ProductQuestionCopyWithImpl(this._self, this._then);

  final ProductQuestion _self;
  final $Res Function(ProductQuestion) _then;

/// Create a copy of ProductQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? questionId = null,Object? productId = null,Object? sellerId = null,Object? askerId = null,Object? question = null,Object? answer = freezed,Object? answeredAt = freezed,Object? answeredBy = freezed,Object? isAnswered = null,Object? upvotes = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,askerId: null == askerId ? _self.askerId : askerId // ignore: cast_nullable_to_non_nullable
as String,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,answer: freezed == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as String?,answeredAt: freezed == answeredAt ? _self.answeredAt : answeredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,answeredBy: freezed == answeredBy ? _self.answeredBy : answeredBy // ignore: cast_nullable_to_non_nullable
as String?,isAnswered: null == isAnswered ? _self.isAnswered : isAnswered // ignore: cast_nullable_to_non_nullable
as bool,upvotes: null == upvotes ? _self.upvotes : upvotes // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductQuestion].
extension ProductQuestionPatterns on ProductQuestion {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductQuestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductQuestion() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductQuestion value)  $default,){
final _that = this;
switch (_that) {
case _ProductQuestion():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductQuestion value)?  $default,){
final _that = this;
switch (_that) {
case _ProductQuestion() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String questionId,  String productId,  String sellerId,  String askerId,  String question,  String? answer,  DateTime? answeredAt,  String? answeredBy,  bool isAnswered,  int upvotes,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductQuestion() when $default != null:
return $default(_that.questionId,_that.productId,_that.sellerId,_that.askerId,_that.question,_that.answer,_that.answeredAt,_that.answeredBy,_that.isAnswered,_that.upvotes,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String questionId,  String productId,  String sellerId,  String askerId,  String question,  String? answer,  DateTime? answeredAt,  String? answeredBy,  bool isAnswered,  int upvotes,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _ProductQuestion():
return $default(_that.questionId,_that.productId,_that.sellerId,_that.askerId,_that.question,_that.answer,_that.answeredAt,_that.answeredBy,_that.isAnswered,_that.upvotes,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String questionId,  String productId,  String sellerId,  String askerId,  String question,  String? answer,  DateTime? answeredAt,  String? answeredBy,  bool isAnswered,  int upvotes,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ProductQuestion() when $default != null:
return $default(_that.questionId,_that.productId,_that.sellerId,_that.askerId,_that.question,_that.answer,_that.answeredAt,_that.answeredBy,_that.isAnswered,_that.upvotes,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductQuestion implements ProductQuestion {
  const _ProductQuestion({required this.questionId, required this.productId, required this.sellerId, required this.askerId, required this.question, this.answer, this.answeredAt, this.answeredBy, this.isAnswered = false, this.upvotes = 0, required this.createdAt});
  factory _ProductQuestion.fromJson(Map<String, dynamic> json) => _$ProductQuestionFromJson(json);

@override final  String questionId;
@override final  String productId;
@override final  String sellerId;
@override final  String askerId;
@override final  String question;
@override final  String? answer;
@override final  DateTime? answeredAt;
@override final  String? answeredBy;
@override@JsonKey() final  bool isAnswered;
@override@JsonKey() final  int upvotes;
@override final  DateTime createdAt;

/// Create a copy of ProductQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductQuestionCopyWith<_ProductQuestion> get copyWith => __$ProductQuestionCopyWithImpl<_ProductQuestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductQuestion&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.askerId, askerId) || other.askerId == askerId)&&(identical(other.question, question) || other.question == question)&&(identical(other.answer, answer) || other.answer == answer)&&(identical(other.answeredAt, answeredAt) || other.answeredAt == answeredAt)&&(identical(other.answeredBy, answeredBy) || other.answeredBy == answeredBy)&&(identical(other.isAnswered, isAnswered) || other.isAnswered == isAnswered)&&(identical(other.upvotes, upvotes) || other.upvotes == upvotes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionId,productId,sellerId,askerId,question,answer,answeredAt,answeredBy,isAnswered,upvotes,createdAt);

@override
String toString() {
  return 'ProductQuestion(questionId: $questionId, productId: $productId, sellerId: $sellerId, askerId: $askerId, question: $question, answer: $answer, answeredAt: $answeredAt, answeredBy: $answeredBy, isAnswered: $isAnswered, upvotes: $upvotes, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ProductQuestionCopyWith<$Res> implements $ProductQuestionCopyWith<$Res> {
  factory _$ProductQuestionCopyWith(_ProductQuestion value, $Res Function(_ProductQuestion) _then) = __$ProductQuestionCopyWithImpl;
@override @useResult
$Res call({
 String questionId, String productId, String sellerId, String askerId, String question, String? answer, DateTime? answeredAt, String? answeredBy, bool isAnswered, int upvotes, DateTime createdAt
});




}
/// @nodoc
class __$ProductQuestionCopyWithImpl<$Res>
    implements _$ProductQuestionCopyWith<$Res> {
  __$ProductQuestionCopyWithImpl(this._self, this._then);

  final _ProductQuestion _self;
  final $Res Function(_ProductQuestion) _then;

/// Create a copy of ProductQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? questionId = null,Object? productId = null,Object? sellerId = null,Object? askerId = null,Object? question = null,Object? answer = freezed,Object? answeredAt = freezed,Object? answeredBy = freezed,Object? isAnswered = null,Object? upvotes = null,Object? createdAt = null,}) {
  return _then(_ProductQuestion(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,askerId: null == askerId ? _self.askerId : askerId // ignore: cast_nullable_to_non_nullable
as String,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,answer: freezed == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as String?,answeredAt: freezed == answeredAt ? _self.answeredAt : answeredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,answeredBy: freezed == answeredBy ? _self.answeredBy : answeredBy // ignore: cast_nullable_to_non_nullable
as String?,isAnswered: null == isAnswered ? _self.isAnswered : isAnswered // ignore: cast_nullable_to_non_nullable
as bool,upvotes: null == upvotes ? _self.upvotes : upvotes // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$SellerDeliveryOption {

/// Delivery type: 'standard', 'express', 'same_day', etc.
 String get type;/// Human-readable description
 String get description;/// Shipping cost in dollars
 int get costCents;/// Estimated delivery days
 int get estimatedDays;/// Optional quantity-based discounts for this delivery option
 List<ShippingQuantityDiscount> get quantityDiscounts;/// Maximum items before shipping cost increases (0 = no limit)
 int get maxItemsPerShipment;/// Additional cost per item after maxItemsPerShipment (0 = free per-item)
 int get additionalItemCostCents;/// Whether this option is available for international orders
 bool get availableNationwide;
/// Create a copy of SellerDeliveryOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SellerDeliveryOptionCopyWith<SellerDeliveryOption> get copyWith => _$SellerDeliveryOptionCopyWithImpl<SellerDeliveryOption>(this as SellerDeliveryOption, _$identity);

  /// Serializes this SellerDeliveryOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SellerDeliveryOption&&(identical(other.type, type) || other.type == type)&&(identical(other.description, description) || other.description == description)&&(identical(other.costCents, costCents) || other.costCents == costCents)&&(identical(other.estimatedDays, estimatedDays) || other.estimatedDays == estimatedDays)&&const DeepCollectionEquality().equals(other.quantityDiscounts, quantityDiscounts)&&(identical(other.maxItemsPerShipment, maxItemsPerShipment) || other.maxItemsPerShipment == maxItemsPerShipment)&&(identical(other.additionalItemCostCents, additionalItemCostCents) || other.additionalItemCostCents == additionalItemCostCents)&&(identical(other.availableNationwide, availableNationwide) || other.availableNationwide == availableNationwide));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,description,costCents,estimatedDays,const DeepCollectionEquality().hash(quantityDiscounts),maxItemsPerShipment,additionalItemCostCents,availableNationwide);

@override
String toString() {
  return 'SellerDeliveryOption(type: $type, description: $description, costCents: $costCents, estimatedDays: $estimatedDays, quantityDiscounts: $quantityDiscounts, maxItemsPerShipment: $maxItemsPerShipment, additionalItemCostCents: $additionalItemCostCents, availableNationwide: $availableNationwide)';
}


}

/// @nodoc
abstract mixin class $SellerDeliveryOptionCopyWith<$Res>  {
  factory $SellerDeliveryOptionCopyWith(SellerDeliveryOption value, $Res Function(SellerDeliveryOption) _then) = _$SellerDeliveryOptionCopyWithImpl;
@useResult
$Res call({
 String type, String description, int costCents, int estimatedDays, List<ShippingQuantityDiscount> quantityDiscounts, int maxItemsPerShipment, int additionalItemCostCents, bool availableNationwide
});




}
/// @nodoc
class _$SellerDeliveryOptionCopyWithImpl<$Res>
    implements $SellerDeliveryOptionCopyWith<$Res> {
  _$SellerDeliveryOptionCopyWithImpl(this._self, this._then);

  final SellerDeliveryOption _self;
  final $Res Function(SellerDeliveryOption) _then;

/// Create a copy of SellerDeliveryOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? description = null,Object? costCents = null,Object? estimatedDays = null,Object? quantityDiscounts = null,Object? maxItemsPerShipment = null,Object? additionalItemCostCents = null,Object? availableNationwide = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,costCents: null == costCents ? _self.costCents : costCents // ignore: cast_nullable_to_non_nullable
as int,estimatedDays: null == estimatedDays ? _self.estimatedDays : estimatedDays // ignore: cast_nullable_to_non_nullable
as int,quantityDiscounts: null == quantityDiscounts ? _self.quantityDiscounts : quantityDiscounts // ignore: cast_nullable_to_non_nullable
as List<ShippingQuantityDiscount>,maxItemsPerShipment: null == maxItemsPerShipment ? _self.maxItemsPerShipment : maxItemsPerShipment // ignore: cast_nullable_to_non_nullable
as int,additionalItemCostCents: null == additionalItemCostCents ? _self.additionalItemCostCents : additionalItemCostCents // ignore: cast_nullable_to_non_nullable
as int,availableNationwide: null == availableNationwide ? _self.availableNationwide : availableNationwide // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SellerDeliveryOption].
extension SellerDeliveryOptionPatterns on SellerDeliveryOption {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SellerDeliveryOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SellerDeliveryOption() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SellerDeliveryOption value)  $default,){
final _that = this;
switch (_that) {
case _SellerDeliveryOption():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SellerDeliveryOption value)?  $default,){
final _that = this;
switch (_that) {
case _SellerDeliveryOption() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String description,  int costCents,  int estimatedDays,  List<ShippingQuantityDiscount> quantityDiscounts,  int maxItemsPerShipment,  int additionalItemCostCents,  bool availableNationwide)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SellerDeliveryOption() when $default != null:
return $default(_that.type,_that.description,_that.costCents,_that.estimatedDays,_that.quantityDiscounts,_that.maxItemsPerShipment,_that.additionalItemCostCents,_that.availableNationwide);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String description,  int costCents,  int estimatedDays,  List<ShippingQuantityDiscount> quantityDiscounts,  int maxItemsPerShipment,  int additionalItemCostCents,  bool availableNationwide)  $default,) {final _that = this;
switch (_that) {
case _SellerDeliveryOption():
return $default(_that.type,_that.description,_that.costCents,_that.estimatedDays,_that.quantityDiscounts,_that.maxItemsPerShipment,_that.additionalItemCostCents,_that.availableNationwide);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String description,  int costCents,  int estimatedDays,  List<ShippingQuantityDiscount> quantityDiscounts,  int maxItemsPerShipment,  int additionalItemCostCents,  bool availableNationwide)?  $default,) {final _that = this;
switch (_that) {
case _SellerDeliveryOption() when $default != null:
return $default(_that.type,_that.description,_that.costCents,_that.estimatedDays,_that.quantityDiscounts,_that.maxItemsPerShipment,_that.additionalItemCostCents,_that.availableNationwide);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SellerDeliveryOption implements SellerDeliveryOption {
  const _SellerDeliveryOption({this.type = DeliveryTypeValues.standard, this.description = '', this.costCents = 0, this.estimatedDays = 3, final  List<ShippingQuantityDiscount> quantityDiscounts = const [], this.maxItemsPerShipment = 0, this.additionalItemCostCents = 0, this.availableNationwide = true}): _quantityDiscounts = quantityDiscounts;
  factory _SellerDeliveryOption.fromJson(Map<String, dynamic> json) => _$SellerDeliveryOptionFromJson(json);

/// Delivery type: 'standard', 'express', 'same_day', etc.
@override@JsonKey() final  String type;
/// Human-readable description
@override@JsonKey() final  String description;
/// Shipping cost in dollars
@override@JsonKey() final  int costCents;
/// Estimated delivery days
@override@JsonKey() final  int estimatedDays;
/// Optional quantity-based discounts for this delivery option
 final  List<ShippingQuantityDiscount> _quantityDiscounts;
/// Optional quantity-based discounts for this delivery option
@override@JsonKey() List<ShippingQuantityDiscount> get quantityDiscounts {
  if (_quantityDiscounts is EqualUnmodifiableListView) return _quantityDiscounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_quantityDiscounts);
}

/// Maximum items before shipping cost increases (0 = no limit)
@override@JsonKey() final  int maxItemsPerShipment;
/// Additional cost per item after maxItemsPerShipment (0 = free per-item)
@override@JsonKey() final  int additionalItemCostCents;
/// Whether this option is available for international orders
@override@JsonKey() final  bool availableNationwide;

/// Create a copy of SellerDeliveryOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SellerDeliveryOptionCopyWith<_SellerDeliveryOption> get copyWith => __$SellerDeliveryOptionCopyWithImpl<_SellerDeliveryOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SellerDeliveryOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SellerDeliveryOption&&(identical(other.type, type) || other.type == type)&&(identical(other.description, description) || other.description == description)&&(identical(other.costCents, costCents) || other.costCents == costCents)&&(identical(other.estimatedDays, estimatedDays) || other.estimatedDays == estimatedDays)&&const DeepCollectionEquality().equals(other._quantityDiscounts, _quantityDiscounts)&&(identical(other.maxItemsPerShipment, maxItemsPerShipment) || other.maxItemsPerShipment == maxItemsPerShipment)&&(identical(other.additionalItemCostCents, additionalItemCostCents) || other.additionalItemCostCents == additionalItemCostCents)&&(identical(other.availableNationwide, availableNationwide) || other.availableNationwide == availableNationwide));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,description,costCents,estimatedDays,const DeepCollectionEquality().hash(_quantityDiscounts),maxItemsPerShipment,additionalItemCostCents,availableNationwide);

@override
String toString() {
  return 'SellerDeliveryOption(type: $type, description: $description, costCents: $costCents, estimatedDays: $estimatedDays, quantityDiscounts: $quantityDiscounts, maxItemsPerShipment: $maxItemsPerShipment, additionalItemCostCents: $additionalItemCostCents, availableNationwide: $availableNationwide)';
}


}

/// @nodoc
abstract mixin class _$SellerDeliveryOptionCopyWith<$Res> implements $SellerDeliveryOptionCopyWith<$Res> {
  factory _$SellerDeliveryOptionCopyWith(_SellerDeliveryOption value, $Res Function(_SellerDeliveryOption) _then) = __$SellerDeliveryOptionCopyWithImpl;
@override @useResult
$Res call({
 String type, String description, int costCents, int estimatedDays, List<ShippingQuantityDiscount> quantityDiscounts, int maxItemsPerShipment, int additionalItemCostCents, bool availableNationwide
});




}
/// @nodoc
class __$SellerDeliveryOptionCopyWithImpl<$Res>
    implements _$SellerDeliveryOptionCopyWith<$Res> {
  __$SellerDeliveryOptionCopyWithImpl(this._self, this._then);

  final _SellerDeliveryOption _self;
  final $Res Function(_SellerDeliveryOption) _then;

/// Create a copy of SellerDeliveryOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? description = null,Object? costCents = null,Object? estimatedDays = null,Object? quantityDiscounts = null,Object? maxItemsPerShipment = null,Object? additionalItemCostCents = null,Object? availableNationwide = null,}) {
  return _then(_SellerDeliveryOption(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,costCents: null == costCents ? _self.costCents : costCents // ignore: cast_nullable_to_non_nullable
as int,estimatedDays: null == estimatedDays ? _self.estimatedDays : estimatedDays // ignore: cast_nullable_to_non_nullable
as int,quantityDiscounts: null == quantityDiscounts ? _self._quantityDiscounts : quantityDiscounts // ignore: cast_nullable_to_non_nullable
as List<ShippingQuantityDiscount>,maxItemsPerShipment: null == maxItemsPerShipment ? _self.maxItemsPerShipment : maxItemsPerShipment // ignore: cast_nullable_to_non_nullable
as int,additionalItemCostCents: null == additionalItemCostCents ? _self.additionalItemCostCents : additionalItemCostCents // ignore: cast_nullable_to_non_nullable
as int,availableNationwide: null == availableNationwide ? _self.availableNationwide : availableNationwide // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SellerWarehouse {

 String get warehouseId;/// Display name, e.g. 'Toronto Warehouse' or 'Home Office'
 String get label;/// Location type: 'warehouse' | 'personal'
 String get type;/// Physical address of this location
 Address get address;/// Whether this is the seller's default shipping origin
 bool get isDefault; DateTime? get createdAt;
/// Create a copy of SellerWarehouse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SellerWarehouseCopyWith<SellerWarehouse> get copyWith => _$SellerWarehouseCopyWithImpl<SellerWarehouse>(this as SellerWarehouse, _$identity);

  /// Serializes this SellerWarehouse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SellerWarehouse&&(identical(other.warehouseId, warehouseId) || other.warehouseId == warehouseId)&&(identical(other.label, label) || other.label == label)&&(identical(other.type, type) || other.type == type)&&(identical(other.address, address) || other.address == address)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,warehouseId,label,type,address,isDefault,createdAt);

@override
String toString() {
  return 'SellerWarehouse(warehouseId: $warehouseId, label: $label, type: $type, address: $address, isDefault: $isDefault, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SellerWarehouseCopyWith<$Res>  {
  factory $SellerWarehouseCopyWith(SellerWarehouse value, $Res Function(SellerWarehouse) _then) = _$SellerWarehouseCopyWithImpl;
@useResult
$Res call({
 String warehouseId, String label, String type, Address address, bool isDefault, DateTime? createdAt
});


$AddressCopyWith<$Res> get address;

}
/// @nodoc
class _$SellerWarehouseCopyWithImpl<$Res>
    implements $SellerWarehouseCopyWith<$Res> {
  _$SellerWarehouseCopyWithImpl(this._self, this._then);

  final SellerWarehouse _self;
  final $Res Function(SellerWarehouse) _then;

/// Create a copy of SellerWarehouse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? warehouseId = null,Object? label = null,Object? type = null,Object? address = null,Object? isDefault = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
warehouseId: null == warehouseId ? _self.warehouseId : warehouseId // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of SellerWarehouse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res> get address {
  
  return $AddressCopyWith<$Res>(_self.address, (value) {
    return _then(_self.copyWith(address: value));
  });
}
}


/// Adds pattern-matching-related methods to [SellerWarehouse].
extension SellerWarehousePatterns on SellerWarehouse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SellerWarehouse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SellerWarehouse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SellerWarehouse value)  $default,){
final _that = this;
switch (_that) {
case _SellerWarehouse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SellerWarehouse value)?  $default,){
final _that = this;
switch (_that) {
case _SellerWarehouse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String warehouseId,  String label,  String type,  Address address,  bool isDefault,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SellerWarehouse() when $default != null:
return $default(_that.warehouseId,_that.label,_that.type,_that.address,_that.isDefault,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String warehouseId,  String label,  String type,  Address address,  bool isDefault,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _SellerWarehouse():
return $default(_that.warehouseId,_that.label,_that.type,_that.address,_that.isDefault,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String warehouseId,  String label,  String type,  Address address,  bool isDefault,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SellerWarehouse() when $default != null:
return $default(_that.warehouseId,_that.label,_that.type,_that.address,_that.isDefault,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SellerWarehouse implements SellerWarehouse {
  const _SellerWarehouse({required this.warehouseId, required this.label, this.type = 'warehouse', required this.address, this.isDefault = false, this.createdAt});
  factory _SellerWarehouse.fromJson(Map<String, dynamic> json) => _$SellerWarehouseFromJson(json);

@override final  String warehouseId;
/// Display name, e.g. 'Toronto Warehouse' or 'Home Office'
@override final  String label;
/// Location type: 'warehouse' | 'personal'
@override@JsonKey() final  String type;
/// Physical address of this location
@override final  Address address;
/// Whether this is the seller's default shipping origin
@override@JsonKey() final  bool isDefault;
@override final  DateTime? createdAt;

/// Create a copy of SellerWarehouse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SellerWarehouseCopyWith<_SellerWarehouse> get copyWith => __$SellerWarehouseCopyWithImpl<_SellerWarehouse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SellerWarehouseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SellerWarehouse&&(identical(other.warehouseId, warehouseId) || other.warehouseId == warehouseId)&&(identical(other.label, label) || other.label == label)&&(identical(other.type, type) || other.type == type)&&(identical(other.address, address) || other.address == address)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,warehouseId,label,type,address,isDefault,createdAt);

@override
String toString() {
  return 'SellerWarehouse(warehouseId: $warehouseId, label: $label, type: $type, address: $address, isDefault: $isDefault, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SellerWarehouseCopyWith<$Res> implements $SellerWarehouseCopyWith<$Res> {
  factory _$SellerWarehouseCopyWith(_SellerWarehouse value, $Res Function(_SellerWarehouse) _then) = __$SellerWarehouseCopyWithImpl;
@override @useResult
$Res call({
 String warehouseId, String label, String type, Address address, bool isDefault, DateTime? createdAt
});


@override $AddressCopyWith<$Res> get address;

}
/// @nodoc
class __$SellerWarehouseCopyWithImpl<$Res>
    implements _$SellerWarehouseCopyWith<$Res> {
  __$SellerWarehouseCopyWithImpl(this._self, this._then);

  final _SellerWarehouse _self;
  final $Res Function(_SellerWarehouse) _then;

/// Create a copy of SellerWarehouse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? warehouseId = null,Object? label = null,Object? type = null,Object? address = null,Object? isDefault = null,Object? createdAt = freezed,}) {
  return _then(_SellerWarehouse(
warehouseId: null == warehouseId ? _self.warehouseId : warehouseId // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of SellerWarehouse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res> get address {
  
  return $AddressCopyWith<$Res>(_self.address, (value) {
    return _then(_self.copyWith(address: value));
  });
}
}


/// @nodoc
mixin _$ShippingQuantityDiscount {

/// Minimum quantity to qualify for this discount
 int get minQuantity;/// Discount type: 'percent' (e.g., 10% off), 'fixed' (e.g., $2 off), 'flat_rate' (e.g., $5 flat)
 String get discountType;/// Discount value (interpretation depends on discountType)
 double get discountValue;/// Optional label for display (e.g., "Bulk Shipping Discount")
 String? get label;
/// Create a copy of ShippingQuantityDiscount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShippingQuantityDiscountCopyWith<ShippingQuantityDiscount> get copyWith => _$ShippingQuantityDiscountCopyWithImpl<ShippingQuantityDiscount>(this as ShippingQuantityDiscount, _$identity);

  /// Serializes this ShippingQuantityDiscount to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShippingQuantityDiscount&&(identical(other.minQuantity, minQuantity) || other.minQuantity == minQuantity)&&(identical(other.discountType, discountType) || other.discountType == discountType)&&(identical(other.discountValue, discountValue) || other.discountValue == discountValue)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minQuantity,discountType,discountValue,label);

@override
String toString() {
  return 'ShippingQuantityDiscount(minQuantity: $minQuantity, discountType: $discountType, discountValue: $discountValue, label: $label)';
}


}

/// @nodoc
abstract mixin class $ShippingQuantityDiscountCopyWith<$Res>  {
  factory $ShippingQuantityDiscountCopyWith(ShippingQuantityDiscount value, $Res Function(ShippingQuantityDiscount) _then) = _$ShippingQuantityDiscountCopyWithImpl;
@useResult
$Res call({
 int minQuantity, String discountType, double discountValue, String? label
});




}
/// @nodoc
class _$ShippingQuantityDiscountCopyWithImpl<$Res>
    implements $ShippingQuantityDiscountCopyWith<$Res> {
  _$ShippingQuantityDiscountCopyWithImpl(this._self, this._then);

  final ShippingQuantityDiscount _self;
  final $Res Function(ShippingQuantityDiscount) _then;

/// Create a copy of ShippingQuantityDiscount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minQuantity = null,Object? discountType = null,Object? discountValue = null,Object? label = freezed,}) {
  return _then(_self.copyWith(
minQuantity: null == minQuantity ? _self.minQuantity : minQuantity // ignore: cast_nullable_to_non_nullable
as int,discountType: null == discountType ? _self.discountType : discountType // ignore: cast_nullable_to_non_nullable
as String,discountValue: null == discountValue ? _self.discountValue : discountValue // ignore: cast_nullable_to_non_nullable
as double,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ShippingQuantityDiscount].
extension ShippingQuantityDiscountPatterns on ShippingQuantityDiscount {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShippingQuantityDiscount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShippingQuantityDiscount() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShippingQuantityDiscount value)  $default,){
final _that = this;
switch (_that) {
case _ShippingQuantityDiscount():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShippingQuantityDiscount value)?  $default,){
final _that = this;
switch (_that) {
case _ShippingQuantityDiscount() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int minQuantity,  String discountType,  double discountValue,  String? label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShippingQuantityDiscount() when $default != null:
return $default(_that.minQuantity,_that.discountType,_that.discountValue,_that.label);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int minQuantity,  String discountType,  double discountValue,  String? label)  $default,) {final _that = this;
switch (_that) {
case _ShippingQuantityDiscount():
return $default(_that.minQuantity,_that.discountType,_that.discountValue,_that.label);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int minQuantity,  String discountType,  double discountValue,  String? label)?  $default,) {final _that = this;
switch (_that) {
case _ShippingQuantityDiscount() when $default != null:
return $default(_that.minQuantity,_that.discountType,_that.discountValue,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ShippingQuantityDiscount implements ShippingQuantityDiscount {
  const _ShippingQuantityDiscount({required this.minQuantity, this.discountType = DiscountTypeValues.percent, required this.discountValue, this.label});
  factory _ShippingQuantityDiscount.fromJson(Map<String, dynamic> json) => _$ShippingQuantityDiscountFromJson(json);

/// Minimum quantity to qualify for this discount
@override final  int minQuantity;
/// Discount type: 'percent' (e.g., 10% off), 'fixed' (e.g., $2 off), 'flat_rate' (e.g., $5 flat)
@override@JsonKey() final  String discountType;
/// Discount value (interpretation depends on discountType)
@override final  double discountValue;
/// Optional label for display (e.g., "Bulk Shipping Discount")
@override final  String? label;

/// Create a copy of ShippingQuantityDiscount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShippingQuantityDiscountCopyWith<_ShippingQuantityDiscount> get copyWith => __$ShippingQuantityDiscountCopyWithImpl<_ShippingQuantityDiscount>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShippingQuantityDiscountToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShippingQuantityDiscount&&(identical(other.minQuantity, minQuantity) || other.minQuantity == minQuantity)&&(identical(other.discountType, discountType) || other.discountType == discountType)&&(identical(other.discountValue, discountValue) || other.discountValue == discountValue)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minQuantity,discountType,discountValue,label);

@override
String toString() {
  return 'ShippingQuantityDiscount(minQuantity: $minQuantity, discountType: $discountType, discountValue: $discountValue, label: $label)';
}


}

/// @nodoc
abstract mixin class _$ShippingQuantityDiscountCopyWith<$Res> implements $ShippingQuantityDiscountCopyWith<$Res> {
  factory _$ShippingQuantityDiscountCopyWith(_ShippingQuantityDiscount value, $Res Function(_ShippingQuantityDiscount) _then) = __$ShippingQuantityDiscountCopyWithImpl;
@override @useResult
$Res call({
 int minQuantity, String discountType, double discountValue, String? label
});




}
/// @nodoc
class __$ShippingQuantityDiscountCopyWithImpl<$Res>
    implements _$ShippingQuantityDiscountCopyWith<$Res> {
  __$ShippingQuantityDiscountCopyWithImpl(this._self, this._then);

  final _ShippingQuantityDiscount _self;
  final $Res Function(_ShippingQuantityDiscount) _then;

/// Create a copy of ShippingQuantityDiscount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minQuantity = null,Object? discountType = null,Object? discountValue = null,Object? label = freezed,}) {
  return _then(_ShippingQuantityDiscount(
minQuantity: null == minQuantity ? _self.minQuantity : minQuantity // ignore: cast_nullable_to_non_nullable
as int,discountType: null == discountType ? _self.discountType : discountType // ignore: cast_nullable_to_non_nullable
as String,discountValue: null == discountValue ? _self.discountValue : discountValue // ignore: cast_nullable_to_non_nullable
as double,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SupplierInfo {

/// Supplier platform type: aliexpress, dhgate, alibaba, 1688, temu, cjdropshipping, other
 String get type;/// Supplier's SKU/Product ID
 String? get supplierSku;/// Direct URL to supplier product page
 String? get supplierUrl;/// Cost price from supplier
 double? get cost;/// Currency of supplier cost price (supplier's currency, NOT selling currency).
/// Selling price is always CAD. This tracks the supplier's original currency.
 String get currency;/// Estimated shipping days range (e.g., '7-15')
 String? get shippingDays;/// Whether supplier provides tracking
 bool get hasTracking;/// Internal notes about this supplier/product
 String? get notes;
/// Create a copy of SupplierInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupplierInfoCopyWith<SupplierInfo> get copyWith => _$SupplierInfoCopyWithImpl<SupplierInfo>(this as SupplierInfo, _$identity);

  /// Serializes this SupplierInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupplierInfo&&(identical(other.type, type) || other.type == type)&&(identical(other.supplierSku, supplierSku) || other.supplierSku == supplierSku)&&(identical(other.supplierUrl, supplierUrl) || other.supplierUrl == supplierUrl)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.shippingDays, shippingDays) || other.shippingDays == shippingDays)&&(identical(other.hasTracking, hasTracking) || other.hasTracking == hasTracking)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,supplierSku,supplierUrl,cost,currency,shippingDays,hasTracking,notes);

@override
String toString() {
  return 'SupplierInfo(type: $type, supplierSku: $supplierSku, supplierUrl: $supplierUrl, cost: $cost, currency: $currency, shippingDays: $shippingDays, hasTracking: $hasTracking, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $SupplierInfoCopyWith<$Res>  {
  factory $SupplierInfoCopyWith(SupplierInfo value, $Res Function(SupplierInfo) _then) = _$SupplierInfoCopyWithImpl;
@useResult
$Res call({
 String type, String? supplierSku, String? supplierUrl, double? cost, String currency, String? shippingDays, bool hasTracking, String? notes
});




}
/// @nodoc
class _$SupplierInfoCopyWithImpl<$Res>
    implements $SupplierInfoCopyWith<$Res> {
  _$SupplierInfoCopyWithImpl(this._self, this._then);

  final SupplierInfo _self;
  final $Res Function(SupplierInfo) _then;

/// Create a copy of SupplierInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? supplierSku = freezed,Object? supplierUrl = freezed,Object? cost = freezed,Object? currency = null,Object? shippingDays = freezed,Object? hasTracking = null,Object? notes = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,supplierSku: freezed == supplierSku ? _self.supplierSku : supplierSku // ignore: cast_nullable_to_non_nullable
as String?,supplierUrl: freezed == supplierUrl ? _self.supplierUrl : supplierUrl // ignore: cast_nullable_to_non_nullable
as String?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,shippingDays: freezed == shippingDays ? _self.shippingDays : shippingDays // ignore: cast_nullable_to_non_nullable
as String?,hasTracking: null == hasTracking ? _self.hasTracking : hasTracking // ignore: cast_nullable_to_non_nullable
as bool,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SupplierInfo].
extension SupplierInfoPatterns on SupplierInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupplierInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupplierInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupplierInfo value)  $default,){
final _that = this;
switch (_that) {
case _SupplierInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupplierInfo value)?  $default,){
final _that = this;
switch (_that) {
case _SupplierInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String? supplierSku,  String? supplierUrl,  double? cost,  String currency,  String? shippingDays,  bool hasTracking,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupplierInfo() when $default != null:
return $default(_that.type,_that.supplierSku,_that.supplierUrl,_that.cost,_that.currency,_that.shippingDays,_that.hasTracking,_that.notes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String? supplierSku,  String? supplierUrl,  double? cost,  String currency,  String? shippingDays,  bool hasTracking,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _SupplierInfo():
return $default(_that.type,_that.supplierSku,_that.supplierUrl,_that.cost,_that.currency,_that.shippingDays,_that.hasTracking,_that.notes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String? supplierSku,  String? supplierUrl,  double? cost,  String currency,  String? shippingDays,  bool hasTracking,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _SupplierInfo() when $default != null:
return $default(_that.type,_that.supplierSku,_that.supplierUrl,_that.cost,_that.currency,_that.shippingDays,_that.hasTracking,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SupplierInfo implements SupplierInfo {
  const _SupplierInfo({required this.type, this.supplierSku, this.supplierUrl, this.cost, this.currency = 'USD', this.shippingDays, this.hasTracking = false, this.notes});
  factory _SupplierInfo.fromJson(Map<String, dynamic> json) => _$SupplierInfoFromJson(json);

/// Supplier platform type: aliexpress, dhgate, alibaba, 1688, temu, cjdropshipping, other
@override final  String type;
/// Supplier's SKU/Product ID
@override final  String? supplierSku;
/// Direct URL to supplier product page
@override final  String? supplierUrl;
/// Cost price from supplier
@override final  double? cost;
/// Currency of supplier cost price (supplier's currency, NOT selling currency).
/// Selling price is always CAD. This tracks the supplier's original currency.
@override@JsonKey() final  String currency;
/// Estimated shipping days range (e.g., '7-15')
@override final  String? shippingDays;
/// Whether supplier provides tracking
@override@JsonKey() final  bool hasTracking;
/// Internal notes about this supplier/product
@override final  String? notes;

/// Create a copy of SupplierInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupplierInfoCopyWith<_SupplierInfo> get copyWith => __$SupplierInfoCopyWithImpl<_SupplierInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupplierInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupplierInfo&&(identical(other.type, type) || other.type == type)&&(identical(other.supplierSku, supplierSku) || other.supplierSku == supplierSku)&&(identical(other.supplierUrl, supplierUrl) || other.supplierUrl == supplierUrl)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.shippingDays, shippingDays) || other.shippingDays == shippingDays)&&(identical(other.hasTracking, hasTracking) || other.hasTracking == hasTracking)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,supplierSku,supplierUrl,cost,currency,shippingDays,hasTracking,notes);

@override
String toString() {
  return 'SupplierInfo(type: $type, supplierSku: $supplierSku, supplierUrl: $supplierUrl, cost: $cost, currency: $currency, shippingDays: $shippingDays, hasTracking: $hasTracking, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$SupplierInfoCopyWith<$Res> implements $SupplierInfoCopyWith<$Res> {
  factory _$SupplierInfoCopyWith(_SupplierInfo value, $Res Function(_SupplierInfo) _then) = __$SupplierInfoCopyWithImpl;
@override @useResult
$Res call({
 String type, String? supplierSku, String? supplierUrl, double? cost, String currency, String? shippingDays, bool hasTracking, String? notes
});




}
/// @nodoc
class __$SupplierInfoCopyWithImpl<$Res>
    implements _$SupplierInfoCopyWith<$Res> {
  __$SupplierInfoCopyWithImpl(this._self, this._then);

  final _SupplierInfo _self;
  final $Res Function(_SupplierInfo) _then;

/// Create a copy of SupplierInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? supplierSku = freezed,Object? supplierUrl = freezed,Object? cost = freezed,Object? currency = null,Object? shippingDays = freezed,Object? hasTracking = null,Object? notes = freezed,}) {
  return _then(_SupplierInfo(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,supplierSku: freezed == supplierSku ? _self.supplierSku : supplierSku // ignore: cast_nullable_to_non_nullable
as String?,supplierUrl: freezed == supplierUrl ? _self.supplierUrl : supplierUrl // ignore: cast_nullable_to_non_nullable
as String?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,shippingDays: freezed == shippingDays ? _self.shippingDays : shippingDays // ignore: cast_nullable_to_non_nullable
as String?,hasTracking: null == hasTracking ? _self.hasTracking : hasTracking // ignore: cast_nullable_to_non_nullable
as bool,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
