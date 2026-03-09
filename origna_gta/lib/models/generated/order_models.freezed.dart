// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Order {

 String get orderId; String get userId; int get version; int get schemaVersion; String? get customerId; String? get customerEmail; List<OrderItem> get items;// All money in integer cents
 int get totalAmountCents; int get subtotalCents; int get shippingCostCents; int get taxAmountCents; Taxes get taxes; OrderStatus get orderStatus; PaymentStatus get paymentStatus; Address? get shippingAddress; DateTime get createdAt; String get currency; List<String> get sellerIds;// Unique product IDs in this order (computed from items — enables chat gate query)
 List<String> get productIds; String? get stripeSessionId;// Shipping approval
 ShippingApprovalStatus get shippingApprovalStatus; bool get shippingApprovalRequired; int get actualShippingCents; int get pendingTotalCents;// Payout tracking
 List<SellerPayout> get sellerPayouts; bool get confirmedByClient; DateTime? get confirmedAt; int get platformFeeTotalCents; String get payoutStatus;// Ratings
 List<Ratings> get ratings;// === AUDIT FIX: 18 missing fields synced from Python/Firestore ===
// Payment capture tracking
 String? get stripePaymentIntentId; int get captureAttempts; DateTime? get capturedAt; DateTime? get expiresAt; bool get autoConfirmed; bool get autoCaptured;// Refund tracking
 int get refundAmountCents; DateTime? get refundedAt;// Cancellation tracking
 bool get stockRestored; String? get cancelledBy; DateTime? get cancelledAt; String? get cancellationReason;// Shipping approval
 DateTime? get respondedAt;// Admin review
 bool get requiresManualReview; String? get manualReviewReason; List<String> get payoutErrors;// Timestamp
 DateTime? get updatedAt;// Tax fields (new)
 List<Map<String, dynamic>> get itemTaxes; bool get taxExempt; Map<String, dynamic>? get taxExemption;// Delivery instructions from buyer
 String? get deliveryInstructions;// Coupon / promo code (N-07)
 String? get couponCode; int get discountAmountCents;// Phase 3.5 fraud / capture tracking (schema sync fix — AUDIT)
 int get fraudScore; Map<String, dynamic>? get sellerCaptures; String? get lastCaptureError;
/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderCopyWith<Order> get copyWith => _$OrderCopyWithImpl<Order>(this as Order, _$identity);

  /// Serializes this Order to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Order&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.version, version) || other.version == version)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerEmail, customerEmail) || other.customerEmail == customerEmail)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.totalAmountCents, totalAmountCents) || other.totalAmountCents == totalAmountCents)&&(identical(other.subtotalCents, subtotalCents) || other.subtotalCents == subtotalCents)&&(identical(other.shippingCostCents, shippingCostCents) || other.shippingCostCents == shippingCostCents)&&(identical(other.taxAmountCents, taxAmountCents) || other.taxAmountCents == taxAmountCents)&&(identical(other.taxes, taxes) || other.taxes == taxes)&&(identical(other.orderStatus, orderStatus) || other.orderStatus == orderStatus)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.shippingAddress, shippingAddress) || other.shippingAddress == shippingAddress)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.currency, currency) || other.currency == currency)&&const DeepCollectionEquality().equals(other.sellerIds, sellerIds)&&const DeepCollectionEquality().equals(other.productIds, productIds)&&(identical(other.stripeSessionId, stripeSessionId) || other.stripeSessionId == stripeSessionId)&&(identical(other.shippingApprovalStatus, shippingApprovalStatus) || other.shippingApprovalStatus == shippingApprovalStatus)&&(identical(other.shippingApprovalRequired, shippingApprovalRequired) || other.shippingApprovalRequired == shippingApprovalRequired)&&(identical(other.actualShippingCents, actualShippingCents) || other.actualShippingCents == actualShippingCents)&&(identical(other.pendingTotalCents, pendingTotalCents) || other.pendingTotalCents == pendingTotalCents)&&const DeepCollectionEquality().equals(other.sellerPayouts, sellerPayouts)&&(identical(other.confirmedByClient, confirmedByClient) || other.confirmedByClient == confirmedByClient)&&(identical(other.confirmedAt, confirmedAt) || other.confirmedAt == confirmedAt)&&(identical(other.platformFeeTotalCents, platformFeeTotalCents) || other.platformFeeTotalCents == platformFeeTotalCents)&&(identical(other.payoutStatus, payoutStatus) || other.payoutStatus == payoutStatus)&&const DeepCollectionEquality().equals(other.ratings, ratings)&&(identical(other.stripePaymentIntentId, stripePaymentIntentId) || other.stripePaymentIntentId == stripePaymentIntentId)&&(identical(other.captureAttempts, captureAttempts) || other.captureAttempts == captureAttempts)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.autoConfirmed, autoConfirmed) || other.autoConfirmed == autoConfirmed)&&(identical(other.autoCaptured, autoCaptured) || other.autoCaptured == autoCaptured)&&(identical(other.refundAmountCents, refundAmountCents) || other.refundAmountCents == refundAmountCents)&&(identical(other.refundedAt, refundedAt) || other.refundedAt == refundedAt)&&(identical(other.stockRestored, stockRestored) || other.stockRestored == stockRestored)&&(identical(other.cancelledBy, cancelledBy) || other.cancelledBy == cancelledBy)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.respondedAt, respondedAt) || other.respondedAt == respondedAt)&&(identical(other.requiresManualReview, requiresManualReview) || other.requiresManualReview == requiresManualReview)&&(identical(other.manualReviewReason, manualReviewReason) || other.manualReviewReason == manualReviewReason)&&const DeepCollectionEquality().equals(other.payoutErrors, payoutErrors)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.itemTaxes, itemTaxes)&&(identical(other.taxExempt, taxExempt) || other.taxExempt == taxExempt)&&const DeepCollectionEquality().equals(other.taxExemption, taxExemption)&&(identical(other.deliveryInstructions, deliveryInstructions) || other.deliveryInstructions == deliveryInstructions)&&(identical(other.couponCode, couponCode) || other.couponCode == couponCode)&&(identical(other.discountAmountCents, discountAmountCents) || other.discountAmountCents == discountAmountCents)&&(identical(other.fraudScore, fraudScore) || other.fraudScore == fraudScore)&&const DeepCollectionEquality().equals(other.sellerCaptures, sellerCaptures)&&(identical(other.lastCaptureError, lastCaptureError) || other.lastCaptureError == lastCaptureError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,orderId,userId,version,schemaVersion,customerId,customerEmail,const DeepCollectionEquality().hash(items),totalAmountCents,subtotalCents,shippingCostCents,taxAmountCents,taxes,orderStatus,paymentStatus,shippingAddress,createdAt,currency,const DeepCollectionEquality().hash(sellerIds),const DeepCollectionEquality().hash(productIds),stripeSessionId,shippingApprovalStatus,shippingApprovalRequired,actualShippingCents,pendingTotalCents,const DeepCollectionEquality().hash(sellerPayouts),confirmedByClient,confirmedAt,platformFeeTotalCents,payoutStatus,const DeepCollectionEquality().hash(ratings),stripePaymentIntentId,captureAttempts,capturedAt,expiresAt,autoConfirmed,autoCaptured,refundAmountCents,refundedAt,stockRestored,cancelledBy,cancelledAt,cancellationReason,respondedAt,requiresManualReview,manualReviewReason,const DeepCollectionEquality().hash(payoutErrors),updatedAt,const DeepCollectionEquality().hash(itemTaxes),taxExempt,const DeepCollectionEquality().hash(taxExemption),deliveryInstructions,couponCode,discountAmountCents,fraudScore,const DeepCollectionEquality().hash(sellerCaptures),lastCaptureError]);

@override
String toString() {
  return 'Order(orderId: $orderId, userId: $userId, version: $version, schemaVersion: $schemaVersion, customerId: $customerId, customerEmail: $customerEmail, items: $items, totalAmountCents: $totalAmountCents, subtotalCents: $subtotalCents, shippingCostCents: $shippingCostCents, taxAmountCents: $taxAmountCents, taxes: $taxes, orderStatus: $orderStatus, paymentStatus: $paymentStatus, shippingAddress: $shippingAddress, createdAt: $createdAt, currency: $currency, sellerIds: $sellerIds, productIds: $productIds, stripeSessionId: $stripeSessionId, shippingApprovalStatus: $shippingApprovalStatus, shippingApprovalRequired: $shippingApprovalRequired, actualShippingCents: $actualShippingCents, pendingTotalCents: $pendingTotalCents, sellerPayouts: $sellerPayouts, confirmedByClient: $confirmedByClient, confirmedAt: $confirmedAt, platformFeeTotalCents: $platformFeeTotalCents, payoutStatus: $payoutStatus, ratings: $ratings, stripePaymentIntentId: $stripePaymentIntentId, captureAttempts: $captureAttempts, capturedAt: $capturedAt, expiresAt: $expiresAt, autoConfirmed: $autoConfirmed, autoCaptured: $autoCaptured, refundAmountCents: $refundAmountCents, refundedAt: $refundedAt, stockRestored: $stockRestored, cancelledBy: $cancelledBy, cancelledAt: $cancelledAt, cancellationReason: $cancellationReason, respondedAt: $respondedAt, requiresManualReview: $requiresManualReview, manualReviewReason: $manualReviewReason, payoutErrors: $payoutErrors, updatedAt: $updatedAt, itemTaxes: $itemTaxes, taxExempt: $taxExempt, taxExemption: $taxExemption, deliveryInstructions: $deliveryInstructions, couponCode: $couponCode, discountAmountCents: $discountAmountCents, fraudScore: $fraudScore, sellerCaptures: $sellerCaptures, lastCaptureError: $lastCaptureError)';
}


}

/// @nodoc
abstract mixin class $OrderCopyWith<$Res>  {
  factory $OrderCopyWith(Order value, $Res Function(Order) _then) = _$OrderCopyWithImpl;
@useResult
$Res call({
 String orderId, String userId, int version, int schemaVersion, String? customerId, String? customerEmail, List<OrderItem> items, int totalAmountCents, int subtotalCents, int shippingCostCents, int taxAmountCents, Taxes taxes, OrderStatus orderStatus, PaymentStatus paymentStatus, Address? shippingAddress, DateTime createdAt, String currency, List<String> sellerIds, List<String> productIds, String? stripeSessionId, ShippingApprovalStatus shippingApprovalStatus, bool shippingApprovalRequired, int actualShippingCents, int pendingTotalCents, List<SellerPayout> sellerPayouts, bool confirmedByClient, DateTime? confirmedAt, int platformFeeTotalCents, String payoutStatus, List<Ratings> ratings, String? stripePaymentIntentId, int captureAttempts, DateTime? capturedAt, DateTime? expiresAt, bool autoConfirmed, bool autoCaptured, int refundAmountCents, DateTime? refundedAt, bool stockRestored, String? cancelledBy, DateTime? cancelledAt, String? cancellationReason, DateTime? respondedAt, bool requiresManualReview, String? manualReviewReason, List<String> payoutErrors, DateTime? updatedAt, List<Map<String, dynamic>> itemTaxes, bool taxExempt, Map<String, dynamic>? taxExemption, String? deliveryInstructions, String? couponCode, int discountAmountCents, int fraudScore, Map<String, dynamic>? sellerCaptures, String? lastCaptureError
});


$TaxesCopyWith<$Res> get taxes;$AddressCopyWith<$Res>? get shippingAddress;

}
/// @nodoc
class _$OrderCopyWithImpl<$Res>
    implements $OrderCopyWith<$Res> {
  _$OrderCopyWithImpl(this._self, this._then);

  final Order _self;
  final $Res Function(Order) _then;

/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orderId = null,Object? userId = null,Object? version = null,Object? schemaVersion = null,Object? customerId = freezed,Object? customerEmail = freezed,Object? items = null,Object? totalAmountCents = null,Object? subtotalCents = null,Object? shippingCostCents = null,Object? taxAmountCents = null,Object? taxes = null,Object? orderStatus = null,Object? paymentStatus = null,Object? shippingAddress = freezed,Object? createdAt = null,Object? currency = null,Object? sellerIds = null,Object? productIds = null,Object? stripeSessionId = freezed,Object? shippingApprovalStatus = null,Object? shippingApprovalRequired = null,Object? actualShippingCents = null,Object? pendingTotalCents = null,Object? sellerPayouts = null,Object? confirmedByClient = null,Object? confirmedAt = freezed,Object? platformFeeTotalCents = null,Object? payoutStatus = null,Object? ratings = null,Object? stripePaymentIntentId = freezed,Object? captureAttempts = null,Object? capturedAt = freezed,Object? expiresAt = freezed,Object? autoConfirmed = null,Object? autoCaptured = null,Object? refundAmountCents = null,Object? refundedAt = freezed,Object? stockRestored = null,Object? cancelledBy = freezed,Object? cancelledAt = freezed,Object? cancellationReason = freezed,Object? respondedAt = freezed,Object? requiresManualReview = null,Object? manualReviewReason = freezed,Object? payoutErrors = null,Object? updatedAt = freezed,Object? itemTaxes = null,Object? taxExempt = null,Object? taxExemption = freezed,Object? deliveryInstructions = freezed,Object? couponCode = freezed,Object? discountAmountCents = null,Object? fraudScore = null,Object? sellerCaptures = freezed,Object? lastCaptureError = freezed,}) {
  return _then(_self.copyWith(
orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,customerEmail: freezed == customerEmail ? _self.customerEmail : customerEmail // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,totalAmountCents: null == totalAmountCents ? _self.totalAmountCents : totalAmountCents // ignore: cast_nullable_to_non_nullable
as int,subtotalCents: null == subtotalCents ? _self.subtotalCents : subtotalCents // ignore: cast_nullable_to_non_nullable
as int,shippingCostCents: null == shippingCostCents ? _self.shippingCostCents : shippingCostCents // ignore: cast_nullable_to_non_nullable
as int,taxAmountCents: null == taxAmountCents ? _self.taxAmountCents : taxAmountCents // ignore: cast_nullable_to_non_nullable
as int,taxes: null == taxes ? _self.taxes : taxes // ignore: cast_nullable_to_non_nullable
as Taxes,orderStatus: null == orderStatus ? _self.orderStatus : orderStatus // ignore: cast_nullable_to_non_nullable
as OrderStatus,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as PaymentStatus,shippingAddress: freezed == shippingAddress ? _self.shippingAddress : shippingAddress // ignore: cast_nullable_to_non_nullable
as Address?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,sellerIds: null == sellerIds ? _self.sellerIds : sellerIds // ignore: cast_nullable_to_non_nullable
as List<String>,productIds: null == productIds ? _self.productIds : productIds // ignore: cast_nullable_to_non_nullable
as List<String>,stripeSessionId: freezed == stripeSessionId ? _self.stripeSessionId : stripeSessionId // ignore: cast_nullable_to_non_nullable
as String?,shippingApprovalStatus: null == shippingApprovalStatus ? _self.shippingApprovalStatus : shippingApprovalStatus // ignore: cast_nullable_to_non_nullable
as ShippingApprovalStatus,shippingApprovalRequired: null == shippingApprovalRequired ? _self.shippingApprovalRequired : shippingApprovalRequired // ignore: cast_nullable_to_non_nullable
as bool,actualShippingCents: null == actualShippingCents ? _self.actualShippingCents : actualShippingCents // ignore: cast_nullable_to_non_nullable
as int,pendingTotalCents: null == pendingTotalCents ? _self.pendingTotalCents : pendingTotalCents // ignore: cast_nullable_to_non_nullable
as int,sellerPayouts: null == sellerPayouts ? _self.sellerPayouts : sellerPayouts // ignore: cast_nullable_to_non_nullable
as List<SellerPayout>,confirmedByClient: null == confirmedByClient ? _self.confirmedByClient : confirmedByClient // ignore: cast_nullable_to_non_nullable
as bool,confirmedAt: freezed == confirmedAt ? _self.confirmedAt : confirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,platformFeeTotalCents: null == platformFeeTotalCents ? _self.platformFeeTotalCents : platformFeeTotalCents // ignore: cast_nullable_to_non_nullable
as int,payoutStatus: null == payoutStatus ? _self.payoutStatus : payoutStatus // ignore: cast_nullable_to_non_nullable
as String,ratings: null == ratings ? _self.ratings : ratings // ignore: cast_nullable_to_non_nullable
as List<Ratings>,stripePaymentIntentId: freezed == stripePaymentIntentId ? _self.stripePaymentIntentId : stripePaymentIntentId // ignore: cast_nullable_to_non_nullable
as String?,captureAttempts: null == captureAttempts ? _self.captureAttempts : captureAttempts // ignore: cast_nullable_to_non_nullable
as int,capturedAt: freezed == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,autoConfirmed: null == autoConfirmed ? _self.autoConfirmed : autoConfirmed // ignore: cast_nullable_to_non_nullable
as bool,autoCaptured: null == autoCaptured ? _self.autoCaptured : autoCaptured // ignore: cast_nullable_to_non_nullable
as bool,refundAmountCents: null == refundAmountCents ? _self.refundAmountCents : refundAmountCents // ignore: cast_nullable_to_non_nullable
as int,refundedAt: freezed == refundedAt ? _self.refundedAt : refundedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,stockRestored: null == stockRestored ? _self.stockRestored : stockRestored // ignore: cast_nullable_to_non_nullable
as bool,cancelledBy: freezed == cancelledBy ? _self.cancelledBy : cancelledBy // ignore: cast_nullable_to_non_nullable
as String?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,respondedAt: freezed == respondedAt ? _self.respondedAt : respondedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,requiresManualReview: null == requiresManualReview ? _self.requiresManualReview : requiresManualReview // ignore: cast_nullable_to_non_nullable
as bool,manualReviewReason: freezed == manualReviewReason ? _self.manualReviewReason : manualReviewReason // ignore: cast_nullable_to_non_nullable
as String?,payoutErrors: null == payoutErrors ? _self.payoutErrors : payoutErrors // ignore: cast_nullable_to_non_nullable
as List<String>,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,itemTaxes: null == itemTaxes ? _self.itemTaxes : itemTaxes // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,taxExempt: null == taxExempt ? _self.taxExempt : taxExempt // ignore: cast_nullable_to_non_nullable
as bool,taxExemption: freezed == taxExemption ? _self.taxExemption : taxExemption // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,deliveryInstructions: freezed == deliveryInstructions ? _self.deliveryInstructions : deliveryInstructions // ignore: cast_nullable_to_non_nullable
as String?,couponCode: freezed == couponCode ? _self.couponCode : couponCode // ignore: cast_nullable_to_non_nullable
as String?,discountAmountCents: null == discountAmountCents ? _self.discountAmountCents : discountAmountCents // ignore: cast_nullable_to_non_nullable
as int,fraudScore: null == fraudScore ? _self.fraudScore : fraudScore // ignore: cast_nullable_to_non_nullable
as int,sellerCaptures: freezed == sellerCaptures ? _self.sellerCaptures : sellerCaptures // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,lastCaptureError: freezed == lastCaptureError ? _self.lastCaptureError : lastCaptureError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaxesCopyWith<$Res> get taxes {
  
  return $TaxesCopyWith<$Res>(_self.taxes, (value) {
    return _then(_self.copyWith(taxes: value));
  });
}/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get shippingAddress {
    if (_self.shippingAddress == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.shippingAddress!, (value) {
    return _then(_self.copyWith(shippingAddress: value));
  });
}
}


/// Adds pattern-matching-related methods to [Order].
extension OrderPatterns on Order {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Order value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Order() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Order value)  $default,){
final _that = this;
switch (_that) {
case _Order():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Order value)?  $default,){
final _that = this;
switch (_that) {
case _Order() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String orderId,  String userId,  int version,  int schemaVersion,  String? customerId,  String? customerEmail,  List<OrderItem> items,  int totalAmountCents,  int subtotalCents,  int shippingCostCents,  int taxAmountCents,  Taxes taxes,  OrderStatus orderStatus,  PaymentStatus paymentStatus,  Address? shippingAddress,  DateTime createdAt,  String currency,  List<String> sellerIds,  List<String> productIds,  String? stripeSessionId,  ShippingApprovalStatus shippingApprovalStatus,  bool shippingApprovalRequired,  int actualShippingCents,  int pendingTotalCents,  List<SellerPayout> sellerPayouts,  bool confirmedByClient,  DateTime? confirmedAt,  int platformFeeTotalCents,  String payoutStatus,  List<Ratings> ratings,  String? stripePaymentIntentId,  int captureAttempts,  DateTime? capturedAt,  DateTime? expiresAt,  bool autoConfirmed,  bool autoCaptured,  int refundAmountCents,  DateTime? refundedAt,  bool stockRestored,  String? cancelledBy,  DateTime? cancelledAt,  String? cancellationReason,  DateTime? respondedAt,  bool requiresManualReview,  String? manualReviewReason,  List<String> payoutErrors,  DateTime? updatedAt,  List<Map<String, dynamic>> itemTaxes,  bool taxExempt,  Map<String, dynamic>? taxExemption,  String? deliveryInstructions,  String? couponCode,  int discountAmountCents,  int fraudScore,  Map<String, dynamic>? sellerCaptures,  String? lastCaptureError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Order() when $default != null:
return $default(_that.orderId,_that.userId,_that.version,_that.schemaVersion,_that.customerId,_that.customerEmail,_that.items,_that.totalAmountCents,_that.subtotalCents,_that.shippingCostCents,_that.taxAmountCents,_that.taxes,_that.orderStatus,_that.paymentStatus,_that.shippingAddress,_that.createdAt,_that.currency,_that.sellerIds,_that.productIds,_that.stripeSessionId,_that.shippingApprovalStatus,_that.shippingApprovalRequired,_that.actualShippingCents,_that.pendingTotalCents,_that.sellerPayouts,_that.confirmedByClient,_that.confirmedAt,_that.platformFeeTotalCents,_that.payoutStatus,_that.ratings,_that.stripePaymentIntentId,_that.captureAttempts,_that.capturedAt,_that.expiresAt,_that.autoConfirmed,_that.autoCaptured,_that.refundAmountCents,_that.refundedAt,_that.stockRestored,_that.cancelledBy,_that.cancelledAt,_that.cancellationReason,_that.respondedAt,_that.requiresManualReview,_that.manualReviewReason,_that.payoutErrors,_that.updatedAt,_that.itemTaxes,_that.taxExempt,_that.taxExemption,_that.deliveryInstructions,_that.couponCode,_that.discountAmountCents,_that.fraudScore,_that.sellerCaptures,_that.lastCaptureError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String orderId,  String userId,  int version,  int schemaVersion,  String? customerId,  String? customerEmail,  List<OrderItem> items,  int totalAmountCents,  int subtotalCents,  int shippingCostCents,  int taxAmountCents,  Taxes taxes,  OrderStatus orderStatus,  PaymentStatus paymentStatus,  Address? shippingAddress,  DateTime createdAt,  String currency,  List<String> sellerIds,  List<String> productIds,  String? stripeSessionId,  ShippingApprovalStatus shippingApprovalStatus,  bool shippingApprovalRequired,  int actualShippingCents,  int pendingTotalCents,  List<SellerPayout> sellerPayouts,  bool confirmedByClient,  DateTime? confirmedAt,  int platformFeeTotalCents,  String payoutStatus,  List<Ratings> ratings,  String? stripePaymentIntentId,  int captureAttempts,  DateTime? capturedAt,  DateTime? expiresAt,  bool autoConfirmed,  bool autoCaptured,  int refundAmountCents,  DateTime? refundedAt,  bool stockRestored,  String? cancelledBy,  DateTime? cancelledAt,  String? cancellationReason,  DateTime? respondedAt,  bool requiresManualReview,  String? manualReviewReason,  List<String> payoutErrors,  DateTime? updatedAt,  List<Map<String, dynamic>> itemTaxes,  bool taxExempt,  Map<String, dynamic>? taxExemption,  String? deliveryInstructions,  String? couponCode,  int discountAmountCents,  int fraudScore,  Map<String, dynamic>? sellerCaptures,  String? lastCaptureError)  $default,) {final _that = this;
switch (_that) {
case _Order():
return $default(_that.orderId,_that.userId,_that.version,_that.schemaVersion,_that.customerId,_that.customerEmail,_that.items,_that.totalAmountCents,_that.subtotalCents,_that.shippingCostCents,_that.taxAmountCents,_that.taxes,_that.orderStatus,_that.paymentStatus,_that.shippingAddress,_that.createdAt,_that.currency,_that.sellerIds,_that.productIds,_that.stripeSessionId,_that.shippingApprovalStatus,_that.shippingApprovalRequired,_that.actualShippingCents,_that.pendingTotalCents,_that.sellerPayouts,_that.confirmedByClient,_that.confirmedAt,_that.platformFeeTotalCents,_that.payoutStatus,_that.ratings,_that.stripePaymentIntentId,_that.captureAttempts,_that.capturedAt,_that.expiresAt,_that.autoConfirmed,_that.autoCaptured,_that.refundAmountCents,_that.refundedAt,_that.stockRestored,_that.cancelledBy,_that.cancelledAt,_that.cancellationReason,_that.respondedAt,_that.requiresManualReview,_that.manualReviewReason,_that.payoutErrors,_that.updatedAt,_that.itemTaxes,_that.taxExempt,_that.taxExemption,_that.deliveryInstructions,_that.couponCode,_that.discountAmountCents,_that.fraudScore,_that.sellerCaptures,_that.lastCaptureError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String orderId,  String userId,  int version,  int schemaVersion,  String? customerId,  String? customerEmail,  List<OrderItem> items,  int totalAmountCents,  int subtotalCents,  int shippingCostCents,  int taxAmountCents,  Taxes taxes,  OrderStatus orderStatus,  PaymentStatus paymentStatus,  Address? shippingAddress,  DateTime createdAt,  String currency,  List<String> sellerIds,  List<String> productIds,  String? stripeSessionId,  ShippingApprovalStatus shippingApprovalStatus,  bool shippingApprovalRequired,  int actualShippingCents,  int pendingTotalCents,  List<SellerPayout> sellerPayouts,  bool confirmedByClient,  DateTime? confirmedAt,  int platformFeeTotalCents,  String payoutStatus,  List<Ratings> ratings,  String? stripePaymentIntentId,  int captureAttempts,  DateTime? capturedAt,  DateTime? expiresAt,  bool autoConfirmed,  bool autoCaptured,  int refundAmountCents,  DateTime? refundedAt,  bool stockRestored,  String? cancelledBy,  DateTime? cancelledAt,  String? cancellationReason,  DateTime? respondedAt,  bool requiresManualReview,  String? manualReviewReason,  List<String> payoutErrors,  DateTime? updatedAt,  List<Map<String, dynamic>> itemTaxes,  bool taxExempt,  Map<String, dynamic>? taxExemption,  String? deliveryInstructions,  String? couponCode,  int discountAmountCents,  int fraudScore,  Map<String, dynamic>? sellerCaptures,  String? lastCaptureError)?  $default,) {final _that = this;
switch (_that) {
case _Order() when $default != null:
return $default(_that.orderId,_that.userId,_that.version,_that.schemaVersion,_that.customerId,_that.customerEmail,_that.items,_that.totalAmountCents,_that.subtotalCents,_that.shippingCostCents,_that.taxAmountCents,_that.taxes,_that.orderStatus,_that.paymentStatus,_that.shippingAddress,_that.createdAt,_that.currency,_that.sellerIds,_that.productIds,_that.stripeSessionId,_that.shippingApprovalStatus,_that.shippingApprovalRequired,_that.actualShippingCents,_that.pendingTotalCents,_that.sellerPayouts,_that.confirmedByClient,_that.confirmedAt,_that.platformFeeTotalCents,_that.payoutStatus,_that.ratings,_that.stripePaymentIntentId,_that.captureAttempts,_that.capturedAt,_that.expiresAt,_that.autoConfirmed,_that.autoCaptured,_that.refundAmountCents,_that.refundedAt,_that.stockRestored,_that.cancelledBy,_that.cancelledAt,_that.cancellationReason,_that.respondedAt,_that.requiresManualReview,_that.manualReviewReason,_that.payoutErrors,_that.updatedAt,_that.itemTaxes,_that.taxExempt,_that.taxExemption,_that.deliveryInstructions,_that.couponCode,_that.discountAmountCents,_that.fraudScore,_that.sellerCaptures,_that.lastCaptureError);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Order extends Order {
  const _Order({required this.orderId, required this.userId, this.version = 1, this.schemaVersion = 1, this.customerId, this.customerEmail, required final  List<OrderItem> items, required this.totalAmountCents, required this.subtotalCents, this.shippingCostCents = 0, this.taxAmountCents = 0, required this.taxes, this.orderStatus = OrderStatus.pending, this.paymentStatus = PaymentStatus.awaitingPayment, this.shippingAddress, required this.createdAt, this.currency = BusinessRules.defaultCurrency, final  List<String> sellerIds = const [], final  List<String> productIds = const [], this.stripeSessionId, this.shippingApprovalStatus = ShippingApprovalStatus.notRequired, this.shippingApprovalRequired = false, this.actualShippingCents = 0, this.pendingTotalCents = 0, final  List<SellerPayout> sellerPayouts = const [], this.confirmedByClient = false, this.confirmedAt, this.platformFeeTotalCents = 0, this.payoutStatus = PayoutStatusValues.pending, final  List<Ratings> ratings = const [], this.stripePaymentIntentId, this.captureAttempts = 0, this.capturedAt, this.expiresAt, this.autoConfirmed = false, this.autoCaptured = false, this.refundAmountCents = 0, this.refundedAt, this.stockRestored = false, this.cancelledBy, this.cancelledAt, this.cancellationReason, this.respondedAt, this.requiresManualReview = false, this.manualReviewReason, final  List<String> payoutErrors = const [], this.updatedAt, final  List<Map<String, dynamic>> itemTaxes = const [], this.taxExempt = false, final  Map<String, dynamic>? taxExemption, this.deliveryInstructions, this.couponCode, this.discountAmountCents = 0, this.fraudScore = 0, final  Map<String, dynamic>? sellerCaptures, this.lastCaptureError}): _items = items,_sellerIds = sellerIds,_productIds = productIds,_sellerPayouts = sellerPayouts,_ratings = ratings,_payoutErrors = payoutErrors,_itemTaxes = itemTaxes,_taxExemption = taxExemption,_sellerCaptures = sellerCaptures,super._();
  factory _Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

@override final  String orderId;
@override final  String userId;
@override@JsonKey() final  int version;
@override@JsonKey() final  int schemaVersion;
@override final  String? customerId;
@override final  String? customerEmail;
 final  List<OrderItem> _items;
@override List<OrderItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

// All money in integer cents
@override final  int totalAmountCents;
@override final  int subtotalCents;
@override@JsonKey() final  int shippingCostCents;
@override@JsonKey() final  int taxAmountCents;
@override final  Taxes taxes;
@override@JsonKey() final  OrderStatus orderStatus;
@override@JsonKey() final  PaymentStatus paymentStatus;
@override final  Address? shippingAddress;
@override final  DateTime createdAt;
@override@JsonKey() final  String currency;
 final  List<String> _sellerIds;
@override@JsonKey() List<String> get sellerIds {
  if (_sellerIds is EqualUnmodifiableListView) return _sellerIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sellerIds);
}

// Unique product IDs in this order (computed from items — enables chat gate query)
 final  List<String> _productIds;
// Unique product IDs in this order (computed from items — enables chat gate query)
@override@JsonKey() List<String> get productIds {
  if (_productIds is EqualUnmodifiableListView) return _productIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_productIds);
}

@override final  String? stripeSessionId;
// Shipping approval
@override@JsonKey() final  ShippingApprovalStatus shippingApprovalStatus;
@override@JsonKey() final  bool shippingApprovalRequired;
@override@JsonKey() final  int actualShippingCents;
@override@JsonKey() final  int pendingTotalCents;
// Payout tracking
 final  List<SellerPayout> _sellerPayouts;
// Payout tracking
@override@JsonKey() List<SellerPayout> get sellerPayouts {
  if (_sellerPayouts is EqualUnmodifiableListView) return _sellerPayouts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sellerPayouts);
}

@override@JsonKey() final  bool confirmedByClient;
@override final  DateTime? confirmedAt;
@override@JsonKey() final  int platformFeeTotalCents;
@override@JsonKey() final  String payoutStatus;
// Ratings
 final  List<Ratings> _ratings;
// Ratings
@override@JsonKey() List<Ratings> get ratings {
  if (_ratings is EqualUnmodifiableListView) return _ratings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ratings);
}

// === AUDIT FIX: 18 missing fields synced from Python/Firestore ===
// Payment capture tracking
@override final  String? stripePaymentIntentId;
@override@JsonKey() final  int captureAttempts;
@override final  DateTime? capturedAt;
@override final  DateTime? expiresAt;
@override@JsonKey() final  bool autoConfirmed;
@override@JsonKey() final  bool autoCaptured;
// Refund tracking
@override@JsonKey() final  int refundAmountCents;
@override final  DateTime? refundedAt;
// Cancellation tracking
@override@JsonKey() final  bool stockRestored;
@override final  String? cancelledBy;
@override final  DateTime? cancelledAt;
@override final  String? cancellationReason;
// Shipping approval
@override final  DateTime? respondedAt;
// Admin review
@override@JsonKey() final  bool requiresManualReview;
@override final  String? manualReviewReason;
 final  List<String> _payoutErrors;
@override@JsonKey() List<String> get payoutErrors {
  if (_payoutErrors is EqualUnmodifiableListView) return _payoutErrors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_payoutErrors);
}

// Timestamp
@override final  DateTime? updatedAt;
// Tax fields (new)
 final  List<Map<String, dynamic>> _itemTaxes;
// Tax fields (new)
@override@JsonKey() List<Map<String, dynamic>> get itemTaxes {
  if (_itemTaxes is EqualUnmodifiableListView) return _itemTaxes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_itemTaxes);
}

@override@JsonKey() final  bool taxExempt;
 final  Map<String, dynamic>? _taxExemption;
@override Map<String, dynamic>? get taxExemption {
  final value = _taxExemption;
  if (value == null) return null;
  if (_taxExemption is EqualUnmodifiableMapView) return _taxExemption;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

// Delivery instructions from buyer
@override final  String? deliveryInstructions;
// Coupon / promo code (N-07)
@override final  String? couponCode;
@override@JsonKey() final  int discountAmountCents;
// Phase 3.5 fraud / capture tracking (schema sync fix — AUDIT)
@override@JsonKey() final  int fraudScore;
 final  Map<String, dynamic>? _sellerCaptures;
@override Map<String, dynamic>? get sellerCaptures {
  final value = _sellerCaptures;
  if (value == null) return null;
  if (_sellerCaptures is EqualUnmodifiableMapView) return _sellerCaptures;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  String? lastCaptureError;

/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderCopyWith<_Order> get copyWith => __$OrderCopyWithImpl<_Order>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Order&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.version, version) || other.version == version)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerEmail, customerEmail) || other.customerEmail == customerEmail)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.totalAmountCents, totalAmountCents) || other.totalAmountCents == totalAmountCents)&&(identical(other.subtotalCents, subtotalCents) || other.subtotalCents == subtotalCents)&&(identical(other.shippingCostCents, shippingCostCents) || other.shippingCostCents == shippingCostCents)&&(identical(other.taxAmountCents, taxAmountCents) || other.taxAmountCents == taxAmountCents)&&(identical(other.taxes, taxes) || other.taxes == taxes)&&(identical(other.orderStatus, orderStatus) || other.orderStatus == orderStatus)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.shippingAddress, shippingAddress) || other.shippingAddress == shippingAddress)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.currency, currency) || other.currency == currency)&&const DeepCollectionEquality().equals(other._sellerIds, _sellerIds)&&const DeepCollectionEquality().equals(other._productIds, _productIds)&&(identical(other.stripeSessionId, stripeSessionId) || other.stripeSessionId == stripeSessionId)&&(identical(other.shippingApprovalStatus, shippingApprovalStatus) || other.shippingApprovalStatus == shippingApprovalStatus)&&(identical(other.shippingApprovalRequired, shippingApprovalRequired) || other.shippingApprovalRequired == shippingApprovalRequired)&&(identical(other.actualShippingCents, actualShippingCents) || other.actualShippingCents == actualShippingCents)&&(identical(other.pendingTotalCents, pendingTotalCents) || other.pendingTotalCents == pendingTotalCents)&&const DeepCollectionEquality().equals(other._sellerPayouts, _sellerPayouts)&&(identical(other.confirmedByClient, confirmedByClient) || other.confirmedByClient == confirmedByClient)&&(identical(other.confirmedAt, confirmedAt) || other.confirmedAt == confirmedAt)&&(identical(other.platformFeeTotalCents, platformFeeTotalCents) || other.platformFeeTotalCents == platformFeeTotalCents)&&(identical(other.payoutStatus, payoutStatus) || other.payoutStatus == payoutStatus)&&const DeepCollectionEquality().equals(other._ratings, _ratings)&&(identical(other.stripePaymentIntentId, stripePaymentIntentId) || other.stripePaymentIntentId == stripePaymentIntentId)&&(identical(other.captureAttempts, captureAttempts) || other.captureAttempts == captureAttempts)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.autoConfirmed, autoConfirmed) || other.autoConfirmed == autoConfirmed)&&(identical(other.autoCaptured, autoCaptured) || other.autoCaptured == autoCaptured)&&(identical(other.refundAmountCents, refundAmountCents) || other.refundAmountCents == refundAmountCents)&&(identical(other.refundedAt, refundedAt) || other.refundedAt == refundedAt)&&(identical(other.stockRestored, stockRestored) || other.stockRestored == stockRestored)&&(identical(other.cancelledBy, cancelledBy) || other.cancelledBy == cancelledBy)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.respondedAt, respondedAt) || other.respondedAt == respondedAt)&&(identical(other.requiresManualReview, requiresManualReview) || other.requiresManualReview == requiresManualReview)&&(identical(other.manualReviewReason, manualReviewReason) || other.manualReviewReason == manualReviewReason)&&const DeepCollectionEquality().equals(other._payoutErrors, _payoutErrors)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._itemTaxes, _itemTaxes)&&(identical(other.taxExempt, taxExempt) || other.taxExempt == taxExempt)&&const DeepCollectionEquality().equals(other._taxExemption, _taxExemption)&&(identical(other.deliveryInstructions, deliveryInstructions) || other.deliveryInstructions == deliveryInstructions)&&(identical(other.couponCode, couponCode) || other.couponCode == couponCode)&&(identical(other.discountAmountCents, discountAmountCents) || other.discountAmountCents == discountAmountCents)&&(identical(other.fraudScore, fraudScore) || other.fraudScore == fraudScore)&&const DeepCollectionEquality().equals(other._sellerCaptures, _sellerCaptures)&&(identical(other.lastCaptureError, lastCaptureError) || other.lastCaptureError == lastCaptureError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,orderId,userId,version,schemaVersion,customerId,customerEmail,const DeepCollectionEquality().hash(_items),totalAmountCents,subtotalCents,shippingCostCents,taxAmountCents,taxes,orderStatus,paymentStatus,shippingAddress,createdAt,currency,const DeepCollectionEquality().hash(_sellerIds),const DeepCollectionEquality().hash(_productIds),stripeSessionId,shippingApprovalStatus,shippingApprovalRequired,actualShippingCents,pendingTotalCents,const DeepCollectionEquality().hash(_sellerPayouts),confirmedByClient,confirmedAt,platformFeeTotalCents,payoutStatus,const DeepCollectionEquality().hash(_ratings),stripePaymentIntentId,captureAttempts,capturedAt,expiresAt,autoConfirmed,autoCaptured,refundAmountCents,refundedAt,stockRestored,cancelledBy,cancelledAt,cancellationReason,respondedAt,requiresManualReview,manualReviewReason,const DeepCollectionEquality().hash(_payoutErrors),updatedAt,const DeepCollectionEquality().hash(_itemTaxes),taxExempt,const DeepCollectionEquality().hash(_taxExemption),deliveryInstructions,couponCode,discountAmountCents,fraudScore,const DeepCollectionEquality().hash(_sellerCaptures),lastCaptureError]);

@override
String toString() {
  return 'Order(orderId: $orderId, userId: $userId, version: $version, schemaVersion: $schemaVersion, customerId: $customerId, customerEmail: $customerEmail, items: $items, totalAmountCents: $totalAmountCents, subtotalCents: $subtotalCents, shippingCostCents: $shippingCostCents, taxAmountCents: $taxAmountCents, taxes: $taxes, orderStatus: $orderStatus, paymentStatus: $paymentStatus, shippingAddress: $shippingAddress, createdAt: $createdAt, currency: $currency, sellerIds: $sellerIds, productIds: $productIds, stripeSessionId: $stripeSessionId, shippingApprovalStatus: $shippingApprovalStatus, shippingApprovalRequired: $shippingApprovalRequired, actualShippingCents: $actualShippingCents, pendingTotalCents: $pendingTotalCents, sellerPayouts: $sellerPayouts, confirmedByClient: $confirmedByClient, confirmedAt: $confirmedAt, platformFeeTotalCents: $platformFeeTotalCents, payoutStatus: $payoutStatus, ratings: $ratings, stripePaymentIntentId: $stripePaymentIntentId, captureAttempts: $captureAttempts, capturedAt: $capturedAt, expiresAt: $expiresAt, autoConfirmed: $autoConfirmed, autoCaptured: $autoCaptured, refundAmountCents: $refundAmountCents, refundedAt: $refundedAt, stockRestored: $stockRestored, cancelledBy: $cancelledBy, cancelledAt: $cancelledAt, cancellationReason: $cancellationReason, respondedAt: $respondedAt, requiresManualReview: $requiresManualReview, manualReviewReason: $manualReviewReason, payoutErrors: $payoutErrors, updatedAt: $updatedAt, itemTaxes: $itemTaxes, taxExempt: $taxExempt, taxExemption: $taxExemption, deliveryInstructions: $deliveryInstructions, couponCode: $couponCode, discountAmountCents: $discountAmountCents, fraudScore: $fraudScore, sellerCaptures: $sellerCaptures, lastCaptureError: $lastCaptureError)';
}


}

/// @nodoc
abstract mixin class _$OrderCopyWith<$Res> implements $OrderCopyWith<$Res> {
  factory _$OrderCopyWith(_Order value, $Res Function(_Order) _then) = __$OrderCopyWithImpl;
@override @useResult
$Res call({
 String orderId, String userId, int version, int schemaVersion, String? customerId, String? customerEmail, List<OrderItem> items, int totalAmountCents, int subtotalCents, int shippingCostCents, int taxAmountCents, Taxes taxes, OrderStatus orderStatus, PaymentStatus paymentStatus, Address? shippingAddress, DateTime createdAt, String currency, List<String> sellerIds, List<String> productIds, String? stripeSessionId, ShippingApprovalStatus shippingApprovalStatus, bool shippingApprovalRequired, int actualShippingCents, int pendingTotalCents, List<SellerPayout> sellerPayouts, bool confirmedByClient, DateTime? confirmedAt, int platformFeeTotalCents, String payoutStatus, List<Ratings> ratings, String? stripePaymentIntentId, int captureAttempts, DateTime? capturedAt, DateTime? expiresAt, bool autoConfirmed, bool autoCaptured, int refundAmountCents, DateTime? refundedAt, bool stockRestored, String? cancelledBy, DateTime? cancelledAt, String? cancellationReason, DateTime? respondedAt, bool requiresManualReview, String? manualReviewReason, List<String> payoutErrors, DateTime? updatedAt, List<Map<String, dynamic>> itemTaxes, bool taxExempt, Map<String, dynamic>? taxExemption, String? deliveryInstructions, String? couponCode, int discountAmountCents, int fraudScore, Map<String, dynamic>? sellerCaptures, String? lastCaptureError
});


@override $TaxesCopyWith<$Res> get taxes;@override $AddressCopyWith<$Res>? get shippingAddress;

}
/// @nodoc
class __$OrderCopyWithImpl<$Res>
    implements _$OrderCopyWith<$Res> {
  __$OrderCopyWithImpl(this._self, this._then);

  final _Order _self;
  final $Res Function(_Order) _then;

/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orderId = null,Object? userId = null,Object? version = null,Object? schemaVersion = null,Object? customerId = freezed,Object? customerEmail = freezed,Object? items = null,Object? totalAmountCents = null,Object? subtotalCents = null,Object? shippingCostCents = null,Object? taxAmountCents = null,Object? taxes = null,Object? orderStatus = null,Object? paymentStatus = null,Object? shippingAddress = freezed,Object? createdAt = null,Object? currency = null,Object? sellerIds = null,Object? productIds = null,Object? stripeSessionId = freezed,Object? shippingApprovalStatus = null,Object? shippingApprovalRequired = null,Object? actualShippingCents = null,Object? pendingTotalCents = null,Object? sellerPayouts = null,Object? confirmedByClient = null,Object? confirmedAt = freezed,Object? platformFeeTotalCents = null,Object? payoutStatus = null,Object? ratings = null,Object? stripePaymentIntentId = freezed,Object? captureAttempts = null,Object? capturedAt = freezed,Object? expiresAt = freezed,Object? autoConfirmed = null,Object? autoCaptured = null,Object? refundAmountCents = null,Object? refundedAt = freezed,Object? stockRestored = null,Object? cancelledBy = freezed,Object? cancelledAt = freezed,Object? cancellationReason = freezed,Object? respondedAt = freezed,Object? requiresManualReview = null,Object? manualReviewReason = freezed,Object? payoutErrors = null,Object? updatedAt = freezed,Object? itemTaxes = null,Object? taxExempt = null,Object? taxExemption = freezed,Object? deliveryInstructions = freezed,Object? couponCode = freezed,Object? discountAmountCents = null,Object? fraudScore = null,Object? sellerCaptures = freezed,Object? lastCaptureError = freezed,}) {
  return _then(_Order(
orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,customerEmail: freezed == customerEmail ? _self.customerEmail : customerEmail // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,totalAmountCents: null == totalAmountCents ? _self.totalAmountCents : totalAmountCents // ignore: cast_nullable_to_non_nullable
as int,subtotalCents: null == subtotalCents ? _self.subtotalCents : subtotalCents // ignore: cast_nullable_to_non_nullable
as int,shippingCostCents: null == shippingCostCents ? _self.shippingCostCents : shippingCostCents // ignore: cast_nullable_to_non_nullable
as int,taxAmountCents: null == taxAmountCents ? _self.taxAmountCents : taxAmountCents // ignore: cast_nullable_to_non_nullable
as int,taxes: null == taxes ? _self.taxes : taxes // ignore: cast_nullable_to_non_nullable
as Taxes,orderStatus: null == orderStatus ? _self.orderStatus : orderStatus // ignore: cast_nullable_to_non_nullable
as OrderStatus,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as PaymentStatus,shippingAddress: freezed == shippingAddress ? _self.shippingAddress : shippingAddress // ignore: cast_nullable_to_non_nullable
as Address?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,sellerIds: null == sellerIds ? _self._sellerIds : sellerIds // ignore: cast_nullable_to_non_nullable
as List<String>,productIds: null == productIds ? _self._productIds : productIds // ignore: cast_nullable_to_non_nullable
as List<String>,stripeSessionId: freezed == stripeSessionId ? _self.stripeSessionId : stripeSessionId // ignore: cast_nullable_to_non_nullable
as String?,shippingApprovalStatus: null == shippingApprovalStatus ? _self.shippingApprovalStatus : shippingApprovalStatus // ignore: cast_nullable_to_non_nullable
as ShippingApprovalStatus,shippingApprovalRequired: null == shippingApprovalRequired ? _self.shippingApprovalRequired : shippingApprovalRequired // ignore: cast_nullable_to_non_nullable
as bool,actualShippingCents: null == actualShippingCents ? _self.actualShippingCents : actualShippingCents // ignore: cast_nullable_to_non_nullable
as int,pendingTotalCents: null == pendingTotalCents ? _self.pendingTotalCents : pendingTotalCents // ignore: cast_nullable_to_non_nullable
as int,sellerPayouts: null == sellerPayouts ? _self._sellerPayouts : sellerPayouts // ignore: cast_nullable_to_non_nullable
as List<SellerPayout>,confirmedByClient: null == confirmedByClient ? _self.confirmedByClient : confirmedByClient // ignore: cast_nullable_to_non_nullable
as bool,confirmedAt: freezed == confirmedAt ? _self.confirmedAt : confirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,platformFeeTotalCents: null == platformFeeTotalCents ? _self.platformFeeTotalCents : platformFeeTotalCents // ignore: cast_nullable_to_non_nullable
as int,payoutStatus: null == payoutStatus ? _self.payoutStatus : payoutStatus // ignore: cast_nullable_to_non_nullable
as String,ratings: null == ratings ? _self._ratings : ratings // ignore: cast_nullable_to_non_nullable
as List<Ratings>,stripePaymentIntentId: freezed == stripePaymentIntentId ? _self.stripePaymentIntentId : stripePaymentIntentId // ignore: cast_nullable_to_non_nullable
as String?,captureAttempts: null == captureAttempts ? _self.captureAttempts : captureAttempts // ignore: cast_nullable_to_non_nullable
as int,capturedAt: freezed == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,autoConfirmed: null == autoConfirmed ? _self.autoConfirmed : autoConfirmed // ignore: cast_nullable_to_non_nullable
as bool,autoCaptured: null == autoCaptured ? _self.autoCaptured : autoCaptured // ignore: cast_nullable_to_non_nullable
as bool,refundAmountCents: null == refundAmountCents ? _self.refundAmountCents : refundAmountCents // ignore: cast_nullable_to_non_nullable
as int,refundedAt: freezed == refundedAt ? _self.refundedAt : refundedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,stockRestored: null == stockRestored ? _self.stockRestored : stockRestored // ignore: cast_nullable_to_non_nullable
as bool,cancelledBy: freezed == cancelledBy ? _self.cancelledBy : cancelledBy // ignore: cast_nullable_to_non_nullable
as String?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,respondedAt: freezed == respondedAt ? _self.respondedAt : respondedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,requiresManualReview: null == requiresManualReview ? _self.requiresManualReview : requiresManualReview // ignore: cast_nullable_to_non_nullable
as bool,manualReviewReason: freezed == manualReviewReason ? _self.manualReviewReason : manualReviewReason // ignore: cast_nullable_to_non_nullable
as String?,payoutErrors: null == payoutErrors ? _self._payoutErrors : payoutErrors // ignore: cast_nullable_to_non_nullable
as List<String>,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,itemTaxes: null == itemTaxes ? _self._itemTaxes : itemTaxes // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,taxExempt: null == taxExempt ? _self.taxExempt : taxExempt // ignore: cast_nullable_to_non_nullable
as bool,taxExemption: freezed == taxExemption ? _self._taxExemption : taxExemption // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,deliveryInstructions: freezed == deliveryInstructions ? _self.deliveryInstructions : deliveryInstructions // ignore: cast_nullable_to_non_nullable
as String?,couponCode: freezed == couponCode ? _self.couponCode : couponCode // ignore: cast_nullable_to_non_nullable
as String?,discountAmountCents: null == discountAmountCents ? _self.discountAmountCents : discountAmountCents // ignore: cast_nullable_to_non_nullable
as int,fraudScore: null == fraudScore ? _self.fraudScore : fraudScore // ignore: cast_nullable_to_non_nullable
as int,sellerCaptures: freezed == sellerCaptures ? _self._sellerCaptures : sellerCaptures // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,lastCaptureError: freezed == lastCaptureError ? _self.lastCaptureError : lastCaptureError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaxesCopyWith<$Res> get taxes {
  
  return $TaxesCopyWith<$Res>(_self.taxes, (value) {
    return _then(_self.copyWith(taxes: value));
  });
}/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get shippingAddress {
    if (_self.shippingAddress == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.shippingAddress!, (value) {
    return _then(_self.copyWith(shippingAddress: value));
  });
}
}


/// @nodoc
mixin _$OrderCreate {

 String get userId; String get customerId; String get customerEmail; List<OrderItem> get items; Address get shippingAddress; double get shippingCost; String get currency; bool get shippingApprovalRequired;
/// Create a copy of OrderCreate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderCreateCopyWith<OrderCreate> get copyWith => _$OrderCreateCopyWithImpl<OrderCreate>(this as OrderCreate, _$identity);

  /// Serializes this OrderCreate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderCreate&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerEmail, customerEmail) || other.customerEmail == customerEmail)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.shippingAddress, shippingAddress) || other.shippingAddress == shippingAddress)&&(identical(other.shippingCost, shippingCost) || other.shippingCost == shippingCost)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.shippingApprovalRequired, shippingApprovalRequired) || other.shippingApprovalRequired == shippingApprovalRequired));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,customerId,customerEmail,const DeepCollectionEquality().hash(items),shippingAddress,shippingCost,currency,shippingApprovalRequired);

@override
String toString() {
  return 'OrderCreate(userId: $userId, customerId: $customerId, customerEmail: $customerEmail, items: $items, shippingAddress: $shippingAddress, shippingCost: $shippingCost, currency: $currency, shippingApprovalRequired: $shippingApprovalRequired)';
}


}

/// @nodoc
abstract mixin class $OrderCreateCopyWith<$Res>  {
  factory $OrderCreateCopyWith(OrderCreate value, $Res Function(OrderCreate) _then) = _$OrderCreateCopyWithImpl;
@useResult
$Res call({
 String userId, String customerId, String customerEmail, List<OrderItem> items, Address shippingAddress, double shippingCost, String currency, bool shippingApprovalRequired
});


$AddressCopyWith<$Res> get shippingAddress;

}
/// @nodoc
class _$OrderCreateCopyWithImpl<$Res>
    implements $OrderCreateCopyWith<$Res> {
  _$OrderCreateCopyWithImpl(this._self, this._then);

  final OrderCreate _self;
  final $Res Function(OrderCreate) _then;

/// Create a copy of OrderCreate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? customerId = null,Object? customerEmail = null,Object? items = null,Object? shippingAddress = null,Object? shippingCost = null,Object? currency = null,Object? shippingApprovalRequired = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerEmail: null == customerEmail ? _self.customerEmail : customerEmail // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,shippingAddress: null == shippingAddress ? _self.shippingAddress : shippingAddress // ignore: cast_nullable_to_non_nullable
as Address,shippingCost: null == shippingCost ? _self.shippingCost : shippingCost // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,shippingApprovalRequired: null == shippingApprovalRequired ? _self.shippingApprovalRequired : shippingApprovalRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of OrderCreate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res> get shippingAddress {
  
  return $AddressCopyWith<$Res>(_self.shippingAddress, (value) {
    return _then(_self.copyWith(shippingAddress: value));
  });
}
}


/// Adds pattern-matching-related methods to [OrderCreate].
extension OrderCreatePatterns on OrderCreate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderCreate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderCreate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderCreate value)  $default,){
final _that = this;
switch (_that) {
case _OrderCreate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderCreate value)?  $default,){
final _that = this;
switch (_that) {
case _OrderCreate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String customerId,  String customerEmail,  List<OrderItem> items,  Address shippingAddress,  double shippingCost,  String currency,  bool shippingApprovalRequired)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderCreate() when $default != null:
return $default(_that.userId,_that.customerId,_that.customerEmail,_that.items,_that.shippingAddress,_that.shippingCost,_that.currency,_that.shippingApprovalRequired);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String customerId,  String customerEmail,  List<OrderItem> items,  Address shippingAddress,  double shippingCost,  String currency,  bool shippingApprovalRequired)  $default,) {final _that = this;
switch (_that) {
case _OrderCreate():
return $default(_that.userId,_that.customerId,_that.customerEmail,_that.items,_that.shippingAddress,_that.shippingCost,_that.currency,_that.shippingApprovalRequired);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String customerId,  String customerEmail,  List<OrderItem> items,  Address shippingAddress,  double shippingCost,  String currency,  bool shippingApprovalRequired)?  $default,) {final _that = this;
switch (_that) {
case _OrderCreate() when $default != null:
return $default(_that.userId,_that.customerId,_that.customerEmail,_that.items,_that.shippingAddress,_that.shippingCost,_that.currency,_that.shippingApprovalRequired);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderCreate implements OrderCreate {
  const _OrderCreate({required this.userId, required this.customerId, required this.customerEmail, required final  List<OrderItem> items, required this.shippingAddress, this.shippingCost = 0.0, this.currency = BusinessRules.defaultCurrency, this.shippingApprovalRequired = false}): _items = items;
  factory _OrderCreate.fromJson(Map<String, dynamic> json) => _$OrderCreateFromJson(json);

@override final  String userId;
@override final  String customerId;
@override final  String customerEmail;
 final  List<OrderItem> _items;
@override List<OrderItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  Address shippingAddress;
@override@JsonKey() final  double shippingCost;
@override@JsonKey() final  String currency;
@override@JsonKey() final  bool shippingApprovalRequired;

/// Create a copy of OrderCreate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderCreateCopyWith<_OrderCreate> get copyWith => __$OrderCreateCopyWithImpl<_OrderCreate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderCreateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderCreate&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerEmail, customerEmail) || other.customerEmail == customerEmail)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.shippingAddress, shippingAddress) || other.shippingAddress == shippingAddress)&&(identical(other.shippingCost, shippingCost) || other.shippingCost == shippingCost)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.shippingApprovalRequired, shippingApprovalRequired) || other.shippingApprovalRequired == shippingApprovalRequired));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,customerId,customerEmail,const DeepCollectionEquality().hash(_items),shippingAddress,shippingCost,currency,shippingApprovalRequired);

@override
String toString() {
  return 'OrderCreate(userId: $userId, customerId: $customerId, customerEmail: $customerEmail, items: $items, shippingAddress: $shippingAddress, shippingCost: $shippingCost, currency: $currency, shippingApprovalRequired: $shippingApprovalRequired)';
}


}

/// @nodoc
abstract mixin class _$OrderCreateCopyWith<$Res> implements $OrderCreateCopyWith<$Res> {
  factory _$OrderCreateCopyWith(_OrderCreate value, $Res Function(_OrderCreate) _then) = __$OrderCreateCopyWithImpl;
@override @useResult
$Res call({
 String userId, String customerId, String customerEmail, List<OrderItem> items, Address shippingAddress, double shippingCost, String currency, bool shippingApprovalRequired
});


@override $AddressCopyWith<$Res> get shippingAddress;

}
/// @nodoc
class __$OrderCreateCopyWithImpl<$Res>
    implements _$OrderCreateCopyWith<$Res> {
  __$OrderCreateCopyWithImpl(this._self, this._then);

  final _OrderCreate _self;
  final $Res Function(_OrderCreate) _then;

/// Create a copy of OrderCreate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? customerId = null,Object? customerEmail = null,Object? items = null,Object? shippingAddress = null,Object? shippingCost = null,Object? currency = null,Object? shippingApprovalRequired = null,}) {
  return _then(_OrderCreate(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerEmail: null == customerEmail ? _self.customerEmail : customerEmail // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,shippingAddress: null == shippingAddress ? _self.shippingAddress : shippingAddress // ignore: cast_nullable_to_non_nullable
as Address,shippingCost: null == shippingCost ? _self.shippingCost : shippingCost // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,shippingApprovalRequired: null == shippingApprovalRequired ? _self.shippingApprovalRequired : shippingApprovalRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of OrderCreate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res> get shippingAddress {
  
  return $AddressCopyWith<$Res>(_self.shippingAddress, (value) {
    return _then(_self.copyWith(shippingAddress: value));
  });
}
}


/// @nodoc
mixin _$OrderItem {

 String get productId; String? get cartItemId;// F-001/F-003: canonical cart item ID — survives duplicate-productId carts
 String get name; String get description; double get price; int get quantity; List<String> get imageUrls; String get sellerId; Address? get sellerAddress;// Per-item status tracking
 String get status;// 'pending' | 'shipped' | 'delivered' | 'refunded'
 String? get trackingNumber; String? get carrier; String? get carrierNote;// Free-text override when carrier='other'
 String? get sellerSku;// Seller's SKU snapshotted at purchase time
 String? get sellerName;// Seller display name snapshotted at purchase time
 DateTime? get shippedAt; DateTime? get deliveredAt; DateTime? get refundedAt; String? get refundReason; int? get refundAmountCents; String? get refundId; bool get confirmedByBuyer;// Variant tracking (immutable snapshot at order creation)
 String? get variantId; String? get variantTitle; Map<String, String>? get variantOptions; String? get variantSku;// Shipping metadata
 double? get weightKg; double? get lengthCm; double? get widthCm; double? get heightCm; bool get isLocalDeliveryOnly; bool get isPerishable; int get estimatedShipDays; List<SellerDeliveryOption> get deliveryOptions; int get minimumOrderQuantity; bool get freeShipping; bool get isDigital; String? get licenseKey; bool get digitalUnlocked; String? get digitalType; Map<String, String>? get digitalBuilds;// Tax field (new)
 String? get taxCode; String? get buyerNote;// ADDED
 String? get fulfillmentWarehouseId;
/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderItemCopyWith<OrderItem> get copyWith => _$OrderItemCopyWithImpl<OrderItem>(this as OrderItem, _$identity);

  /// Serializes this OrderItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.cartItemId, cartItemId) || other.cartItemId == cartItemId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.price, price) || other.price == price)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other.imageUrls, imageUrls)&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.sellerAddress, sellerAddress) || other.sellerAddress == sellerAddress)&&(identical(other.status, status) || other.status == status)&&(identical(other.trackingNumber, trackingNumber) || other.trackingNumber == trackingNumber)&&(identical(other.carrier, carrier) || other.carrier == carrier)&&(identical(other.carrierNote, carrierNote) || other.carrierNote == carrierNote)&&(identical(other.sellerSku, sellerSku) || other.sellerSku == sellerSku)&&(identical(other.sellerName, sellerName) || other.sellerName == sellerName)&&(identical(other.shippedAt, shippedAt) || other.shippedAt == shippedAt)&&(identical(other.deliveredAt, deliveredAt) || other.deliveredAt == deliveredAt)&&(identical(other.refundedAt, refundedAt) || other.refundedAt == refundedAt)&&(identical(other.refundReason, refundReason) || other.refundReason == refundReason)&&(identical(other.refundAmountCents, refundAmountCents) || other.refundAmountCents == refundAmountCents)&&(identical(other.refundId, refundId) || other.refundId == refundId)&&(identical(other.confirmedByBuyer, confirmedByBuyer) || other.confirmedByBuyer == confirmedByBuyer)&&(identical(other.variantId, variantId) || other.variantId == variantId)&&(identical(other.variantTitle, variantTitle) || other.variantTitle == variantTitle)&&const DeepCollectionEquality().equals(other.variantOptions, variantOptions)&&(identical(other.variantSku, variantSku) || other.variantSku == variantSku)&&(identical(other.weightKg, weightKg) || other.weightKg == weightKg)&&(identical(other.lengthCm, lengthCm) || other.lengthCm == lengthCm)&&(identical(other.widthCm, widthCm) || other.widthCm == widthCm)&&(identical(other.heightCm, heightCm) || other.heightCm == heightCm)&&(identical(other.isLocalDeliveryOnly, isLocalDeliveryOnly) || other.isLocalDeliveryOnly == isLocalDeliveryOnly)&&(identical(other.isPerishable, isPerishable) || other.isPerishable == isPerishable)&&(identical(other.estimatedShipDays, estimatedShipDays) || other.estimatedShipDays == estimatedShipDays)&&const DeepCollectionEquality().equals(other.deliveryOptions, deliveryOptions)&&(identical(other.minimumOrderQuantity, minimumOrderQuantity) || other.minimumOrderQuantity == minimumOrderQuantity)&&(identical(other.freeShipping, freeShipping) || other.freeShipping == freeShipping)&&(identical(other.isDigital, isDigital) || other.isDigital == isDigital)&&(identical(other.licenseKey, licenseKey) || other.licenseKey == licenseKey)&&(identical(other.digitalUnlocked, digitalUnlocked) || other.digitalUnlocked == digitalUnlocked)&&(identical(other.digitalType, digitalType) || other.digitalType == digitalType)&&const DeepCollectionEquality().equals(other.digitalBuilds, digitalBuilds)&&(identical(other.taxCode, taxCode) || other.taxCode == taxCode)&&(identical(other.buyerNote, buyerNote) || other.buyerNote == buyerNote)&&(identical(other.fulfillmentWarehouseId, fulfillmentWarehouseId) || other.fulfillmentWarehouseId == fulfillmentWarehouseId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,productId,cartItemId,name,description,price,quantity,const DeepCollectionEquality().hash(imageUrls),sellerId,sellerAddress,status,trackingNumber,carrier,carrierNote,sellerSku,sellerName,shippedAt,deliveredAt,refundedAt,refundReason,refundAmountCents,refundId,confirmedByBuyer,variantId,variantTitle,const DeepCollectionEquality().hash(variantOptions),variantSku,weightKg,lengthCm,widthCm,heightCm,isLocalDeliveryOnly,isPerishable,estimatedShipDays,const DeepCollectionEquality().hash(deliveryOptions),minimumOrderQuantity,freeShipping,isDigital,licenseKey,digitalUnlocked,digitalType,const DeepCollectionEquality().hash(digitalBuilds),taxCode,buyerNote,fulfillmentWarehouseId]);

@override
String toString() {
  return 'OrderItem(productId: $productId, cartItemId: $cartItemId, name: $name, description: $description, price: $price, quantity: $quantity, imageUrls: $imageUrls, sellerId: $sellerId, sellerAddress: $sellerAddress, status: $status, trackingNumber: $trackingNumber, carrier: $carrier, carrierNote: $carrierNote, sellerSku: $sellerSku, sellerName: $sellerName, shippedAt: $shippedAt, deliveredAt: $deliveredAt, refundedAt: $refundedAt, refundReason: $refundReason, refundAmountCents: $refundAmountCents, refundId: $refundId, confirmedByBuyer: $confirmedByBuyer, variantId: $variantId, variantTitle: $variantTitle, variantOptions: $variantOptions, variantSku: $variantSku, weightKg: $weightKg, lengthCm: $lengthCm, widthCm: $widthCm, heightCm: $heightCm, isLocalDeliveryOnly: $isLocalDeliveryOnly, isPerishable: $isPerishable, estimatedShipDays: $estimatedShipDays, deliveryOptions: $deliveryOptions, minimumOrderQuantity: $minimumOrderQuantity, freeShipping: $freeShipping, isDigital: $isDigital, licenseKey: $licenseKey, digitalUnlocked: $digitalUnlocked, digitalType: $digitalType, digitalBuilds: $digitalBuilds, taxCode: $taxCode, buyerNote: $buyerNote, fulfillmentWarehouseId: $fulfillmentWarehouseId)';
}


}

/// @nodoc
abstract mixin class $OrderItemCopyWith<$Res>  {
  factory $OrderItemCopyWith(OrderItem value, $Res Function(OrderItem) _then) = _$OrderItemCopyWithImpl;
@useResult
$Res call({
 String productId, String? cartItemId, String name, String description, double price, int quantity, List<String> imageUrls, String sellerId, Address? sellerAddress, String status, String? trackingNumber, String? carrier, String? carrierNote, String? sellerSku, String? sellerName, DateTime? shippedAt, DateTime? deliveredAt, DateTime? refundedAt, String? refundReason, int? refundAmountCents, String? refundId, bool confirmedByBuyer, String? variantId, String? variantTitle, Map<String, String>? variantOptions, String? variantSku, double? weightKg, double? lengthCm, double? widthCm, double? heightCm, bool isLocalDeliveryOnly, bool isPerishable, int estimatedShipDays, List<SellerDeliveryOption> deliveryOptions, int minimumOrderQuantity, bool freeShipping, bool isDigital, String? licenseKey, bool digitalUnlocked, String? digitalType, Map<String, String>? digitalBuilds, String? taxCode, String? buyerNote, String? fulfillmentWarehouseId
});


$AddressCopyWith<$Res>? get sellerAddress;

}
/// @nodoc
class _$OrderItemCopyWithImpl<$Res>
    implements $OrderItemCopyWith<$Res> {
  _$OrderItemCopyWithImpl(this._self, this._then);

  final OrderItem _self;
  final $Res Function(OrderItem) _then;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? cartItemId = freezed,Object? name = null,Object? description = null,Object? price = null,Object? quantity = null,Object? imageUrls = null,Object? sellerId = null,Object? sellerAddress = freezed,Object? status = null,Object? trackingNumber = freezed,Object? carrier = freezed,Object? carrierNote = freezed,Object? sellerSku = freezed,Object? sellerName = freezed,Object? shippedAt = freezed,Object? deliveredAt = freezed,Object? refundedAt = freezed,Object? refundReason = freezed,Object? refundAmountCents = freezed,Object? refundId = freezed,Object? confirmedByBuyer = null,Object? variantId = freezed,Object? variantTitle = freezed,Object? variantOptions = freezed,Object? variantSku = freezed,Object? weightKg = freezed,Object? lengthCm = freezed,Object? widthCm = freezed,Object? heightCm = freezed,Object? isLocalDeliveryOnly = null,Object? isPerishable = null,Object? estimatedShipDays = null,Object? deliveryOptions = null,Object? minimumOrderQuantity = null,Object? freeShipping = null,Object? isDigital = null,Object? licenseKey = freezed,Object? digitalUnlocked = null,Object? digitalType = freezed,Object? digitalBuilds = freezed,Object? taxCode = freezed,Object? buyerNote = freezed,Object? fulfillmentWarehouseId = freezed,}) {
  return _then(_self.copyWith(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,cartItemId: freezed == cartItemId ? _self.cartItemId : cartItemId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,imageUrls: null == imageUrls ? _self.imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,sellerAddress: freezed == sellerAddress ? _self.sellerAddress : sellerAddress // ignore: cast_nullable_to_non_nullable
as Address?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,trackingNumber: freezed == trackingNumber ? _self.trackingNumber : trackingNumber // ignore: cast_nullable_to_non_nullable
as String?,carrier: freezed == carrier ? _self.carrier : carrier // ignore: cast_nullable_to_non_nullable
as String?,carrierNote: freezed == carrierNote ? _self.carrierNote : carrierNote // ignore: cast_nullable_to_non_nullable
as String?,sellerSku: freezed == sellerSku ? _self.sellerSku : sellerSku // ignore: cast_nullable_to_non_nullable
as String?,sellerName: freezed == sellerName ? _self.sellerName : sellerName // ignore: cast_nullable_to_non_nullable
as String?,shippedAt: freezed == shippedAt ? _self.shippedAt : shippedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deliveredAt: freezed == deliveredAt ? _self.deliveredAt : deliveredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refundedAt: freezed == refundedAt ? _self.refundedAt : refundedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refundReason: freezed == refundReason ? _self.refundReason : refundReason // ignore: cast_nullable_to_non_nullable
as String?,refundAmountCents: freezed == refundAmountCents ? _self.refundAmountCents : refundAmountCents // ignore: cast_nullable_to_non_nullable
as int?,refundId: freezed == refundId ? _self.refundId : refundId // ignore: cast_nullable_to_non_nullable
as String?,confirmedByBuyer: null == confirmedByBuyer ? _self.confirmedByBuyer : confirmedByBuyer // ignore: cast_nullable_to_non_nullable
as bool,variantId: freezed == variantId ? _self.variantId : variantId // ignore: cast_nullable_to_non_nullable
as String?,variantTitle: freezed == variantTitle ? _self.variantTitle : variantTitle // ignore: cast_nullable_to_non_nullable
as String?,variantOptions: freezed == variantOptions ? _self.variantOptions : variantOptions // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,variantSku: freezed == variantSku ? _self.variantSku : variantSku // ignore: cast_nullable_to_non_nullable
as String?,weightKg: freezed == weightKg ? _self.weightKg : weightKg // ignore: cast_nullable_to_non_nullable
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
as bool,licenseKey: freezed == licenseKey ? _self.licenseKey : licenseKey // ignore: cast_nullable_to_non_nullable
as String?,digitalUnlocked: null == digitalUnlocked ? _self.digitalUnlocked : digitalUnlocked // ignore: cast_nullable_to_non_nullable
as bool,digitalType: freezed == digitalType ? _self.digitalType : digitalType // ignore: cast_nullable_to_non_nullable
as String?,digitalBuilds: freezed == digitalBuilds ? _self.digitalBuilds : digitalBuilds // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,taxCode: freezed == taxCode ? _self.taxCode : taxCode // ignore: cast_nullable_to_non_nullable
as String?,buyerNote: freezed == buyerNote ? _self.buyerNote : buyerNote // ignore: cast_nullable_to_non_nullable
as String?,fulfillmentWarehouseId: freezed == fulfillmentWarehouseId ? _self.fulfillmentWarehouseId : fulfillmentWarehouseId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of OrderItem
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
}
}


/// Adds pattern-matching-related methods to [OrderItem].
extension OrderItemPatterns on OrderItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderItem value)  $default,){
final _that = this;
switch (_that) {
case _OrderItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderItem value)?  $default,){
final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productId,  String? cartItemId,  String name,  String description,  double price,  int quantity,  List<String> imageUrls,  String sellerId,  Address? sellerAddress,  String status,  String? trackingNumber,  String? carrier,  String? carrierNote,  String? sellerSku,  String? sellerName,  DateTime? shippedAt,  DateTime? deliveredAt,  DateTime? refundedAt,  String? refundReason,  int? refundAmountCents,  String? refundId,  bool confirmedByBuyer,  String? variantId,  String? variantTitle,  Map<String, String>? variantOptions,  String? variantSku,  double? weightKg,  double? lengthCm,  double? widthCm,  double? heightCm,  bool isLocalDeliveryOnly,  bool isPerishable,  int estimatedShipDays,  List<SellerDeliveryOption> deliveryOptions,  int minimumOrderQuantity,  bool freeShipping,  bool isDigital,  String? licenseKey,  bool digitalUnlocked,  String? digitalType,  Map<String, String>? digitalBuilds,  String? taxCode,  String? buyerNote,  String? fulfillmentWarehouseId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
return $default(_that.productId,_that.cartItemId,_that.name,_that.description,_that.price,_that.quantity,_that.imageUrls,_that.sellerId,_that.sellerAddress,_that.status,_that.trackingNumber,_that.carrier,_that.carrierNote,_that.sellerSku,_that.sellerName,_that.shippedAt,_that.deliveredAt,_that.refundedAt,_that.refundReason,_that.refundAmountCents,_that.refundId,_that.confirmedByBuyer,_that.variantId,_that.variantTitle,_that.variantOptions,_that.variantSku,_that.weightKg,_that.lengthCm,_that.widthCm,_that.heightCm,_that.isLocalDeliveryOnly,_that.isPerishable,_that.estimatedShipDays,_that.deliveryOptions,_that.minimumOrderQuantity,_that.freeShipping,_that.isDigital,_that.licenseKey,_that.digitalUnlocked,_that.digitalType,_that.digitalBuilds,_that.taxCode,_that.buyerNote,_that.fulfillmentWarehouseId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productId,  String? cartItemId,  String name,  String description,  double price,  int quantity,  List<String> imageUrls,  String sellerId,  Address? sellerAddress,  String status,  String? trackingNumber,  String? carrier,  String? carrierNote,  String? sellerSku,  String? sellerName,  DateTime? shippedAt,  DateTime? deliveredAt,  DateTime? refundedAt,  String? refundReason,  int? refundAmountCents,  String? refundId,  bool confirmedByBuyer,  String? variantId,  String? variantTitle,  Map<String, String>? variantOptions,  String? variantSku,  double? weightKg,  double? lengthCm,  double? widthCm,  double? heightCm,  bool isLocalDeliveryOnly,  bool isPerishable,  int estimatedShipDays,  List<SellerDeliveryOption> deliveryOptions,  int minimumOrderQuantity,  bool freeShipping,  bool isDigital,  String? licenseKey,  bool digitalUnlocked,  String? digitalType,  Map<String, String>? digitalBuilds,  String? taxCode,  String? buyerNote,  String? fulfillmentWarehouseId)  $default,) {final _that = this;
switch (_that) {
case _OrderItem():
return $default(_that.productId,_that.cartItemId,_that.name,_that.description,_that.price,_that.quantity,_that.imageUrls,_that.sellerId,_that.sellerAddress,_that.status,_that.trackingNumber,_that.carrier,_that.carrierNote,_that.sellerSku,_that.sellerName,_that.shippedAt,_that.deliveredAt,_that.refundedAt,_that.refundReason,_that.refundAmountCents,_that.refundId,_that.confirmedByBuyer,_that.variantId,_that.variantTitle,_that.variantOptions,_that.variantSku,_that.weightKg,_that.lengthCm,_that.widthCm,_that.heightCm,_that.isLocalDeliveryOnly,_that.isPerishable,_that.estimatedShipDays,_that.deliveryOptions,_that.minimumOrderQuantity,_that.freeShipping,_that.isDigital,_that.licenseKey,_that.digitalUnlocked,_that.digitalType,_that.digitalBuilds,_that.taxCode,_that.buyerNote,_that.fulfillmentWarehouseId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productId,  String? cartItemId,  String name,  String description,  double price,  int quantity,  List<String> imageUrls,  String sellerId,  Address? sellerAddress,  String status,  String? trackingNumber,  String? carrier,  String? carrierNote,  String? sellerSku,  String? sellerName,  DateTime? shippedAt,  DateTime? deliveredAt,  DateTime? refundedAt,  String? refundReason,  int? refundAmountCents,  String? refundId,  bool confirmedByBuyer,  String? variantId,  String? variantTitle,  Map<String, String>? variantOptions,  String? variantSku,  double? weightKg,  double? lengthCm,  double? widthCm,  double? heightCm,  bool isLocalDeliveryOnly,  bool isPerishable,  int estimatedShipDays,  List<SellerDeliveryOption> deliveryOptions,  int minimumOrderQuantity,  bool freeShipping,  bool isDigital,  String? licenseKey,  bool digitalUnlocked,  String? digitalType,  Map<String, String>? digitalBuilds,  String? taxCode,  String? buyerNote,  String? fulfillmentWarehouseId)?  $default,) {final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
return $default(_that.productId,_that.cartItemId,_that.name,_that.description,_that.price,_that.quantity,_that.imageUrls,_that.sellerId,_that.sellerAddress,_that.status,_that.trackingNumber,_that.carrier,_that.carrierNote,_that.sellerSku,_that.sellerName,_that.shippedAt,_that.deliveredAt,_that.refundedAt,_that.refundReason,_that.refundAmountCents,_that.refundId,_that.confirmedByBuyer,_that.variantId,_that.variantTitle,_that.variantOptions,_that.variantSku,_that.weightKg,_that.lengthCm,_that.widthCm,_that.heightCm,_that.isLocalDeliveryOnly,_that.isPerishable,_that.estimatedShipDays,_that.deliveryOptions,_that.minimumOrderQuantity,_that.freeShipping,_that.isDigital,_that.licenseKey,_that.digitalUnlocked,_that.digitalType,_that.digitalBuilds,_that.taxCode,_that.buyerNote,_that.fulfillmentWarehouseId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderItem extends OrderItem {
  const _OrderItem({required this.productId, this.cartItemId, required this.name, required this.description, required this.price, required this.quantity, required final  List<String> imageUrls, required this.sellerId, this.sellerAddress, this.status = DeliveryStatusValues.pending, this.trackingNumber, this.carrier, this.carrierNote, this.sellerSku, this.sellerName, this.shippedAt, this.deliveredAt, this.refundedAt, this.refundReason, this.refundAmountCents, this.refundId, this.confirmedByBuyer = false, this.variantId, this.variantTitle, final  Map<String, String>? variantOptions, this.variantSku, this.weightKg, this.lengthCm, this.widthCm, this.heightCm, this.isLocalDeliveryOnly = false, this.isPerishable = false, this.estimatedShipDays = 3, final  List<SellerDeliveryOption> deliveryOptions = const [], this.minimumOrderQuantity = 1, this.freeShipping = false, this.isDigital = false, this.licenseKey, this.digitalUnlocked = false, this.digitalType, final  Map<String, String>? digitalBuilds, this.taxCode, this.buyerNote, this.fulfillmentWarehouseId}): _imageUrls = imageUrls,_variantOptions = variantOptions,_deliveryOptions = deliveryOptions,_digitalBuilds = digitalBuilds,super._();
  factory _OrderItem.fromJson(Map<String, dynamic> json) => _$OrderItemFromJson(json);

@override final  String productId;
@override final  String? cartItemId;
// F-001/F-003: canonical cart item ID — survives duplicate-productId carts
@override final  String name;
@override final  String description;
@override final  double price;
@override final  int quantity;
 final  List<String> _imageUrls;
@override List<String> get imageUrls {
  if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_imageUrls);
}

@override final  String sellerId;
@override final  Address? sellerAddress;
// Per-item status tracking
@override@JsonKey() final  String status;
// 'pending' | 'shipped' | 'delivered' | 'refunded'
@override final  String? trackingNumber;
@override final  String? carrier;
@override final  String? carrierNote;
// Free-text override when carrier='other'
@override final  String? sellerSku;
// Seller's SKU snapshotted at purchase time
@override final  String? sellerName;
// Seller display name snapshotted at purchase time
@override final  DateTime? shippedAt;
@override final  DateTime? deliveredAt;
@override final  DateTime? refundedAt;
@override final  String? refundReason;
@override final  int? refundAmountCents;
@override final  String? refundId;
@override@JsonKey() final  bool confirmedByBuyer;
// Variant tracking (immutable snapshot at order creation)
@override final  String? variantId;
@override final  String? variantTitle;
 final  Map<String, String>? _variantOptions;
@override Map<String, String>? get variantOptions {
  final value = _variantOptions;
  if (value == null) return null;
  if (_variantOptions is EqualUnmodifiableMapView) return _variantOptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  String? variantSku;
// Shipping metadata
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
@override final  String? licenseKey;
@override@JsonKey() final  bool digitalUnlocked;
@override final  String? digitalType;
 final  Map<String, String>? _digitalBuilds;
@override Map<String, String>? get digitalBuilds {
  final value = _digitalBuilds;
  if (value == null) return null;
  if (_digitalBuilds is EqualUnmodifiableMapView) return _digitalBuilds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

// Tax field (new)
@override final  String? taxCode;
@override final  String? buyerNote;
// ADDED
@override final  String? fulfillmentWarehouseId;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderItemCopyWith<_OrderItem> get copyWith => __$OrderItemCopyWithImpl<_OrderItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.cartItemId, cartItemId) || other.cartItemId == cartItemId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.price, price) || other.price == price)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other._imageUrls, _imageUrls)&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.sellerAddress, sellerAddress) || other.sellerAddress == sellerAddress)&&(identical(other.status, status) || other.status == status)&&(identical(other.trackingNumber, trackingNumber) || other.trackingNumber == trackingNumber)&&(identical(other.carrier, carrier) || other.carrier == carrier)&&(identical(other.carrierNote, carrierNote) || other.carrierNote == carrierNote)&&(identical(other.sellerSku, sellerSku) || other.sellerSku == sellerSku)&&(identical(other.sellerName, sellerName) || other.sellerName == sellerName)&&(identical(other.shippedAt, shippedAt) || other.shippedAt == shippedAt)&&(identical(other.deliveredAt, deliveredAt) || other.deliveredAt == deliveredAt)&&(identical(other.refundedAt, refundedAt) || other.refundedAt == refundedAt)&&(identical(other.refundReason, refundReason) || other.refundReason == refundReason)&&(identical(other.refundAmountCents, refundAmountCents) || other.refundAmountCents == refundAmountCents)&&(identical(other.refundId, refundId) || other.refundId == refundId)&&(identical(other.confirmedByBuyer, confirmedByBuyer) || other.confirmedByBuyer == confirmedByBuyer)&&(identical(other.variantId, variantId) || other.variantId == variantId)&&(identical(other.variantTitle, variantTitle) || other.variantTitle == variantTitle)&&const DeepCollectionEquality().equals(other._variantOptions, _variantOptions)&&(identical(other.variantSku, variantSku) || other.variantSku == variantSku)&&(identical(other.weightKg, weightKg) || other.weightKg == weightKg)&&(identical(other.lengthCm, lengthCm) || other.lengthCm == lengthCm)&&(identical(other.widthCm, widthCm) || other.widthCm == widthCm)&&(identical(other.heightCm, heightCm) || other.heightCm == heightCm)&&(identical(other.isLocalDeliveryOnly, isLocalDeliveryOnly) || other.isLocalDeliveryOnly == isLocalDeliveryOnly)&&(identical(other.isPerishable, isPerishable) || other.isPerishable == isPerishable)&&(identical(other.estimatedShipDays, estimatedShipDays) || other.estimatedShipDays == estimatedShipDays)&&const DeepCollectionEquality().equals(other._deliveryOptions, _deliveryOptions)&&(identical(other.minimumOrderQuantity, minimumOrderQuantity) || other.minimumOrderQuantity == minimumOrderQuantity)&&(identical(other.freeShipping, freeShipping) || other.freeShipping == freeShipping)&&(identical(other.isDigital, isDigital) || other.isDigital == isDigital)&&(identical(other.licenseKey, licenseKey) || other.licenseKey == licenseKey)&&(identical(other.digitalUnlocked, digitalUnlocked) || other.digitalUnlocked == digitalUnlocked)&&(identical(other.digitalType, digitalType) || other.digitalType == digitalType)&&const DeepCollectionEquality().equals(other._digitalBuilds, _digitalBuilds)&&(identical(other.taxCode, taxCode) || other.taxCode == taxCode)&&(identical(other.buyerNote, buyerNote) || other.buyerNote == buyerNote)&&(identical(other.fulfillmentWarehouseId, fulfillmentWarehouseId) || other.fulfillmentWarehouseId == fulfillmentWarehouseId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,productId,cartItemId,name,description,price,quantity,const DeepCollectionEquality().hash(_imageUrls),sellerId,sellerAddress,status,trackingNumber,carrier,carrierNote,sellerSku,sellerName,shippedAt,deliveredAt,refundedAt,refundReason,refundAmountCents,refundId,confirmedByBuyer,variantId,variantTitle,const DeepCollectionEquality().hash(_variantOptions),variantSku,weightKg,lengthCm,widthCm,heightCm,isLocalDeliveryOnly,isPerishable,estimatedShipDays,const DeepCollectionEquality().hash(_deliveryOptions),minimumOrderQuantity,freeShipping,isDigital,licenseKey,digitalUnlocked,digitalType,const DeepCollectionEquality().hash(_digitalBuilds),taxCode,buyerNote,fulfillmentWarehouseId]);

@override
String toString() {
  return 'OrderItem(productId: $productId, cartItemId: $cartItemId, name: $name, description: $description, price: $price, quantity: $quantity, imageUrls: $imageUrls, sellerId: $sellerId, sellerAddress: $sellerAddress, status: $status, trackingNumber: $trackingNumber, carrier: $carrier, carrierNote: $carrierNote, sellerSku: $sellerSku, sellerName: $sellerName, shippedAt: $shippedAt, deliveredAt: $deliveredAt, refundedAt: $refundedAt, refundReason: $refundReason, refundAmountCents: $refundAmountCents, refundId: $refundId, confirmedByBuyer: $confirmedByBuyer, variantId: $variantId, variantTitle: $variantTitle, variantOptions: $variantOptions, variantSku: $variantSku, weightKg: $weightKg, lengthCm: $lengthCm, widthCm: $widthCm, heightCm: $heightCm, isLocalDeliveryOnly: $isLocalDeliveryOnly, isPerishable: $isPerishable, estimatedShipDays: $estimatedShipDays, deliveryOptions: $deliveryOptions, minimumOrderQuantity: $minimumOrderQuantity, freeShipping: $freeShipping, isDigital: $isDigital, licenseKey: $licenseKey, digitalUnlocked: $digitalUnlocked, digitalType: $digitalType, digitalBuilds: $digitalBuilds, taxCode: $taxCode, buyerNote: $buyerNote, fulfillmentWarehouseId: $fulfillmentWarehouseId)';
}


}

/// @nodoc
abstract mixin class _$OrderItemCopyWith<$Res> implements $OrderItemCopyWith<$Res> {
  factory _$OrderItemCopyWith(_OrderItem value, $Res Function(_OrderItem) _then) = __$OrderItemCopyWithImpl;
@override @useResult
$Res call({
 String productId, String? cartItemId, String name, String description, double price, int quantity, List<String> imageUrls, String sellerId, Address? sellerAddress, String status, String? trackingNumber, String? carrier, String? carrierNote, String? sellerSku, String? sellerName, DateTime? shippedAt, DateTime? deliveredAt, DateTime? refundedAt, String? refundReason, int? refundAmountCents, String? refundId, bool confirmedByBuyer, String? variantId, String? variantTitle, Map<String, String>? variantOptions, String? variantSku, double? weightKg, double? lengthCm, double? widthCm, double? heightCm, bool isLocalDeliveryOnly, bool isPerishable, int estimatedShipDays, List<SellerDeliveryOption> deliveryOptions, int minimumOrderQuantity, bool freeShipping, bool isDigital, String? licenseKey, bool digitalUnlocked, String? digitalType, Map<String, String>? digitalBuilds, String? taxCode, String? buyerNote, String? fulfillmentWarehouseId
});


@override $AddressCopyWith<$Res>? get sellerAddress;

}
/// @nodoc
class __$OrderItemCopyWithImpl<$Res>
    implements _$OrderItemCopyWith<$Res> {
  __$OrderItemCopyWithImpl(this._self, this._then);

  final _OrderItem _self;
  final $Res Function(_OrderItem) _then;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? cartItemId = freezed,Object? name = null,Object? description = null,Object? price = null,Object? quantity = null,Object? imageUrls = null,Object? sellerId = null,Object? sellerAddress = freezed,Object? status = null,Object? trackingNumber = freezed,Object? carrier = freezed,Object? carrierNote = freezed,Object? sellerSku = freezed,Object? sellerName = freezed,Object? shippedAt = freezed,Object? deliveredAt = freezed,Object? refundedAt = freezed,Object? refundReason = freezed,Object? refundAmountCents = freezed,Object? refundId = freezed,Object? confirmedByBuyer = null,Object? variantId = freezed,Object? variantTitle = freezed,Object? variantOptions = freezed,Object? variantSku = freezed,Object? weightKg = freezed,Object? lengthCm = freezed,Object? widthCm = freezed,Object? heightCm = freezed,Object? isLocalDeliveryOnly = null,Object? isPerishable = null,Object? estimatedShipDays = null,Object? deliveryOptions = null,Object? minimumOrderQuantity = null,Object? freeShipping = null,Object? isDigital = null,Object? licenseKey = freezed,Object? digitalUnlocked = null,Object? digitalType = freezed,Object? digitalBuilds = freezed,Object? taxCode = freezed,Object? buyerNote = freezed,Object? fulfillmentWarehouseId = freezed,}) {
  return _then(_OrderItem(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,cartItemId: freezed == cartItemId ? _self.cartItemId : cartItemId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,imageUrls: null == imageUrls ? _self._imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,sellerAddress: freezed == sellerAddress ? _self.sellerAddress : sellerAddress // ignore: cast_nullable_to_non_nullable
as Address?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,trackingNumber: freezed == trackingNumber ? _self.trackingNumber : trackingNumber // ignore: cast_nullable_to_non_nullable
as String?,carrier: freezed == carrier ? _self.carrier : carrier // ignore: cast_nullable_to_non_nullable
as String?,carrierNote: freezed == carrierNote ? _self.carrierNote : carrierNote // ignore: cast_nullable_to_non_nullable
as String?,sellerSku: freezed == sellerSku ? _self.sellerSku : sellerSku // ignore: cast_nullable_to_non_nullable
as String?,sellerName: freezed == sellerName ? _self.sellerName : sellerName // ignore: cast_nullable_to_non_nullable
as String?,shippedAt: freezed == shippedAt ? _self.shippedAt : shippedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deliveredAt: freezed == deliveredAt ? _self.deliveredAt : deliveredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refundedAt: freezed == refundedAt ? _self.refundedAt : refundedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refundReason: freezed == refundReason ? _self.refundReason : refundReason // ignore: cast_nullable_to_non_nullable
as String?,refundAmountCents: freezed == refundAmountCents ? _self.refundAmountCents : refundAmountCents // ignore: cast_nullable_to_non_nullable
as int?,refundId: freezed == refundId ? _self.refundId : refundId // ignore: cast_nullable_to_non_nullable
as String?,confirmedByBuyer: null == confirmedByBuyer ? _self.confirmedByBuyer : confirmedByBuyer // ignore: cast_nullable_to_non_nullable
as bool,variantId: freezed == variantId ? _self.variantId : variantId // ignore: cast_nullable_to_non_nullable
as String?,variantTitle: freezed == variantTitle ? _self.variantTitle : variantTitle // ignore: cast_nullable_to_non_nullable
as String?,variantOptions: freezed == variantOptions ? _self._variantOptions : variantOptions // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,variantSku: freezed == variantSku ? _self.variantSku : variantSku // ignore: cast_nullable_to_non_nullable
as String?,weightKg: freezed == weightKg ? _self.weightKg : weightKg // ignore: cast_nullable_to_non_nullable
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
as bool,licenseKey: freezed == licenseKey ? _self.licenseKey : licenseKey // ignore: cast_nullable_to_non_nullable
as String?,digitalUnlocked: null == digitalUnlocked ? _self.digitalUnlocked : digitalUnlocked // ignore: cast_nullable_to_non_nullable
as bool,digitalType: freezed == digitalType ? _self.digitalType : digitalType // ignore: cast_nullable_to_non_nullable
as String?,digitalBuilds: freezed == digitalBuilds ? _self._digitalBuilds : digitalBuilds // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,taxCode: freezed == taxCode ? _self.taxCode : taxCode // ignore: cast_nullable_to_non_nullable
as String?,buyerNote: freezed == buyerNote ? _self.buyerNote : buyerNote // ignore: cast_nullable_to_non_nullable
as String?,fulfillmentWarehouseId: freezed == fulfillmentWarehouseId ? _self.fulfillmentWarehouseId : fulfillmentWarehouseId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of OrderItem
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
}
}


/// @nodoc
mixin _$Ratings {

 String get productId; double get rating; String? get review; DateTime get createdAt;
/// Create a copy of Ratings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RatingsCopyWith<Ratings> get copyWith => _$RatingsCopyWithImpl<Ratings>(this as Ratings, _$identity);

  /// Serializes this Ratings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Ratings&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.review, review) || other.review == review)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productId,rating,review,createdAt);

@override
String toString() {
  return 'Ratings(productId: $productId, rating: $rating, review: $review, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $RatingsCopyWith<$Res>  {
  factory $RatingsCopyWith(Ratings value, $Res Function(Ratings) _then) = _$RatingsCopyWithImpl;
@useResult
$Res call({
 String productId, double rating, String? review, DateTime createdAt
});




}
/// @nodoc
class _$RatingsCopyWithImpl<$Res>
    implements $RatingsCopyWith<$Res> {
  _$RatingsCopyWithImpl(this._self, this._then);

  final Ratings _self;
  final $Res Function(Ratings) _then;

/// Create a copy of Ratings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? rating = null,Object? review = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Ratings].
extension RatingsPatterns on Ratings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Ratings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Ratings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Ratings value)  $default,){
final _that = this;
switch (_that) {
case _Ratings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Ratings value)?  $default,){
final _that = this;
switch (_that) {
case _Ratings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productId,  double rating,  String? review,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Ratings() when $default != null:
return $default(_that.productId,_that.rating,_that.review,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productId,  double rating,  String? review,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Ratings():
return $default(_that.productId,_that.rating,_that.review,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productId,  double rating,  String? review,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Ratings() when $default != null:
return $default(_that.productId,_that.rating,_that.review,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Ratings implements Ratings {
  const _Ratings({required this.productId, required this.rating, this.review, required this.createdAt});
  factory _Ratings.fromJson(Map<String, dynamic> json) => _$RatingsFromJson(json);

@override final  String productId;
@override final  double rating;
@override final  String? review;
@override final  DateTime createdAt;

/// Create a copy of Ratings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RatingsCopyWith<_Ratings> get copyWith => __$RatingsCopyWithImpl<_Ratings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RatingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Ratings&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.review, review) || other.review == review)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productId,rating,review,createdAt);

@override
String toString() {
  return 'Ratings(productId: $productId, rating: $rating, review: $review, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$RatingsCopyWith<$Res> implements $RatingsCopyWith<$Res> {
  factory _$RatingsCopyWith(_Ratings value, $Res Function(_Ratings) _then) = __$RatingsCopyWithImpl;
@override @useResult
$Res call({
 String productId, double rating, String? review, DateTime createdAt
});




}
/// @nodoc
class __$RatingsCopyWithImpl<$Res>
    implements _$RatingsCopyWith<$Res> {
  __$RatingsCopyWithImpl(this._self, this._then);

  final _Ratings _self;
  final $Res Function(_Ratings) _then;

/// Create a copy of Ratings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? rating = null,Object? review = freezed,Object? createdAt = null,}) {
  return _then(_Ratings(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$SellerPayout {

 String get sellerId; String? get stripeAccountId; int get amountCents; int get platformFeeCents; int get netAmountCents; String get status; DateTime? get payoutDate; String? get stripeTransferId; String? get failureReason;
/// Create a copy of SellerPayout
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SellerPayoutCopyWith<SellerPayout> get copyWith => _$SellerPayoutCopyWithImpl<SellerPayout>(this as SellerPayout, _$identity);

  /// Serializes this SellerPayout to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SellerPayout&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.stripeAccountId, stripeAccountId) || other.stripeAccountId == stripeAccountId)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.platformFeeCents, platformFeeCents) || other.platformFeeCents == platformFeeCents)&&(identical(other.netAmountCents, netAmountCents) || other.netAmountCents == netAmountCents)&&(identical(other.status, status) || other.status == status)&&(identical(other.payoutDate, payoutDate) || other.payoutDate == payoutDate)&&(identical(other.stripeTransferId, stripeTransferId) || other.stripeTransferId == stripeTransferId)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sellerId,stripeAccountId,amountCents,platformFeeCents,netAmountCents,status,payoutDate,stripeTransferId,failureReason);

@override
String toString() {
  return 'SellerPayout(sellerId: $sellerId, stripeAccountId: $stripeAccountId, amountCents: $amountCents, platformFeeCents: $platformFeeCents, netAmountCents: $netAmountCents, status: $status, payoutDate: $payoutDate, stripeTransferId: $stripeTransferId, failureReason: $failureReason)';
}


}

/// @nodoc
abstract mixin class $SellerPayoutCopyWith<$Res>  {
  factory $SellerPayoutCopyWith(SellerPayout value, $Res Function(SellerPayout) _then) = _$SellerPayoutCopyWithImpl;
@useResult
$Res call({
 String sellerId, String? stripeAccountId, int amountCents, int platformFeeCents, int netAmountCents, String status, DateTime? payoutDate, String? stripeTransferId, String? failureReason
});




}
/// @nodoc
class _$SellerPayoutCopyWithImpl<$Res>
    implements $SellerPayoutCopyWith<$Res> {
  _$SellerPayoutCopyWithImpl(this._self, this._then);

  final SellerPayout _self;
  final $Res Function(SellerPayout) _then;

/// Create a copy of SellerPayout
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sellerId = null,Object? stripeAccountId = freezed,Object? amountCents = null,Object? platformFeeCents = null,Object? netAmountCents = null,Object? status = null,Object? payoutDate = freezed,Object? stripeTransferId = freezed,Object? failureReason = freezed,}) {
  return _then(_self.copyWith(
sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,stripeAccountId: freezed == stripeAccountId ? _self.stripeAccountId : stripeAccountId // ignore: cast_nullable_to_non_nullable
as String?,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,platformFeeCents: null == platformFeeCents ? _self.platformFeeCents : platformFeeCents // ignore: cast_nullable_to_non_nullable
as int,netAmountCents: null == netAmountCents ? _self.netAmountCents : netAmountCents // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,payoutDate: freezed == payoutDate ? _self.payoutDate : payoutDate // ignore: cast_nullable_to_non_nullable
as DateTime?,stripeTransferId: freezed == stripeTransferId ? _self.stripeTransferId : stripeTransferId // ignore: cast_nullable_to_non_nullable
as String?,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SellerPayout].
extension SellerPayoutPatterns on SellerPayout {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SellerPayout value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SellerPayout() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SellerPayout value)  $default,){
final _that = this;
switch (_that) {
case _SellerPayout():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SellerPayout value)?  $default,){
final _that = this;
switch (_that) {
case _SellerPayout() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sellerId,  String? stripeAccountId,  int amountCents,  int platformFeeCents,  int netAmountCents,  String status,  DateTime? payoutDate,  String? stripeTransferId,  String? failureReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SellerPayout() when $default != null:
return $default(_that.sellerId,_that.stripeAccountId,_that.amountCents,_that.platformFeeCents,_that.netAmountCents,_that.status,_that.payoutDate,_that.stripeTransferId,_that.failureReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sellerId,  String? stripeAccountId,  int amountCents,  int platformFeeCents,  int netAmountCents,  String status,  DateTime? payoutDate,  String? stripeTransferId,  String? failureReason)  $default,) {final _that = this;
switch (_that) {
case _SellerPayout():
return $default(_that.sellerId,_that.stripeAccountId,_that.amountCents,_that.platformFeeCents,_that.netAmountCents,_that.status,_that.payoutDate,_that.stripeTransferId,_that.failureReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sellerId,  String? stripeAccountId,  int amountCents,  int platformFeeCents,  int netAmountCents,  String status,  DateTime? payoutDate,  String? stripeTransferId,  String? failureReason)?  $default,) {final _that = this;
switch (_that) {
case _SellerPayout() when $default != null:
return $default(_that.sellerId,_that.stripeAccountId,_that.amountCents,_that.platformFeeCents,_that.netAmountCents,_that.status,_that.payoutDate,_that.stripeTransferId,_that.failureReason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SellerPayout extends SellerPayout {
  const _SellerPayout({required this.sellerId, this.stripeAccountId, required this.amountCents, required this.platformFeeCents, required this.netAmountCents, this.status = PayoutStatusValues.pending, this.payoutDate, this.stripeTransferId, this.failureReason}): super._();
  factory _SellerPayout.fromJson(Map<String, dynamic> json) => _$SellerPayoutFromJson(json);

@override final  String sellerId;
@override final  String? stripeAccountId;
@override final  int amountCents;
@override final  int platformFeeCents;
@override final  int netAmountCents;
@override@JsonKey() final  String status;
@override final  DateTime? payoutDate;
@override final  String? stripeTransferId;
@override final  String? failureReason;

/// Create a copy of SellerPayout
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SellerPayoutCopyWith<_SellerPayout> get copyWith => __$SellerPayoutCopyWithImpl<_SellerPayout>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SellerPayoutToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SellerPayout&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.stripeAccountId, stripeAccountId) || other.stripeAccountId == stripeAccountId)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.platformFeeCents, platformFeeCents) || other.platformFeeCents == platformFeeCents)&&(identical(other.netAmountCents, netAmountCents) || other.netAmountCents == netAmountCents)&&(identical(other.status, status) || other.status == status)&&(identical(other.payoutDate, payoutDate) || other.payoutDate == payoutDate)&&(identical(other.stripeTransferId, stripeTransferId) || other.stripeTransferId == stripeTransferId)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sellerId,stripeAccountId,amountCents,platformFeeCents,netAmountCents,status,payoutDate,stripeTransferId,failureReason);

@override
String toString() {
  return 'SellerPayout(sellerId: $sellerId, stripeAccountId: $stripeAccountId, amountCents: $amountCents, platformFeeCents: $platformFeeCents, netAmountCents: $netAmountCents, status: $status, payoutDate: $payoutDate, stripeTransferId: $stripeTransferId, failureReason: $failureReason)';
}


}

/// @nodoc
abstract mixin class _$SellerPayoutCopyWith<$Res> implements $SellerPayoutCopyWith<$Res> {
  factory _$SellerPayoutCopyWith(_SellerPayout value, $Res Function(_SellerPayout) _then) = __$SellerPayoutCopyWithImpl;
@override @useResult
$Res call({
 String sellerId, String? stripeAccountId, int amountCents, int platformFeeCents, int netAmountCents, String status, DateTime? payoutDate, String? stripeTransferId, String? failureReason
});




}
/// @nodoc
class __$SellerPayoutCopyWithImpl<$Res>
    implements _$SellerPayoutCopyWith<$Res> {
  __$SellerPayoutCopyWithImpl(this._self, this._then);

  final _SellerPayout _self;
  final $Res Function(_SellerPayout) _then;

/// Create a copy of SellerPayout
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sellerId = null,Object? stripeAccountId = freezed,Object? amountCents = null,Object? platformFeeCents = null,Object? netAmountCents = null,Object? status = null,Object? payoutDate = freezed,Object? stripeTransferId = freezed,Object? failureReason = freezed,}) {
  return _then(_SellerPayout(
sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,stripeAccountId: freezed == stripeAccountId ? _self.stripeAccountId : stripeAccountId // ignore: cast_nullable_to_non_nullable
as String?,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,platformFeeCents: null == platformFeeCents ? _self.platformFeeCents : platformFeeCents // ignore: cast_nullable_to_non_nullable
as int,netAmountCents: null == netAmountCents ? _self.netAmountCents : netAmountCents // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,payoutDate: freezed == payoutDate ? _self.payoutDate : payoutDate // ignore: cast_nullable_to_non_nullable
as DateTime?,stripeTransferId: freezed == stripeTransferId ? _self.stripeTransferId : stripeTransferId // ignore: cast_nullable_to_non_nullable
as String?,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$Taxes {

 double get gst; double get pst; double get hst; double get qst;
/// Create a copy of Taxes
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaxesCopyWith<Taxes> get copyWith => _$TaxesCopyWithImpl<Taxes>(this as Taxes, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Taxes&&(identical(other.gst, gst) || other.gst == gst)&&(identical(other.pst, pst) || other.pst == pst)&&(identical(other.hst, hst) || other.hst == hst)&&(identical(other.qst, qst) || other.qst == qst));
}


@override
int get hashCode => Object.hash(runtimeType,gst,pst,hst,qst);

@override
String toString() {
  return 'Taxes(gst: $gst, pst: $pst, hst: $hst, qst: $qst)';
}


}

/// @nodoc
abstract mixin class $TaxesCopyWith<$Res>  {
  factory $TaxesCopyWith(Taxes value, $Res Function(Taxes) _then) = _$TaxesCopyWithImpl;
@useResult
$Res call({
 double gst, double pst, double hst, double qst
});




}
/// @nodoc
class _$TaxesCopyWithImpl<$Res>
    implements $TaxesCopyWith<$Res> {
  _$TaxesCopyWithImpl(this._self, this._then);

  final Taxes _self;
  final $Res Function(Taxes) _then;

/// Create a copy of Taxes
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gst = null,Object? pst = null,Object? hst = null,Object? qst = null,}) {
  return _then(_self.copyWith(
gst: null == gst ? _self.gst : gst // ignore: cast_nullable_to_non_nullable
as double,pst: null == pst ? _self.pst : pst // ignore: cast_nullable_to_non_nullable
as double,hst: null == hst ? _self.hst : hst // ignore: cast_nullable_to_non_nullable
as double,qst: null == qst ? _self.qst : qst // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [Taxes].
extension TaxesPatterns on Taxes {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Taxes value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Taxes() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Taxes value)  $default,){
final _that = this;
switch (_that) {
case _Taxes():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Taxes value)?  $default,){
final _that = this;
switch (_that) {
case _Taxes() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double gst,  double pst,  double hst,  double qst)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Taxes() when $default != null:
return $default(_that.gst,_that.pst,_that.hst,_that.qst);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double gst,  double pst,  double hst,  double qst)  $default,) {final _that = this;
switch (_that) {
case _Taxes():
return $default(_that.gst,_that.pst,_that.hst,_that.qst);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double gst,  double pst,  double hst,  double qst)?  $default,) {final _that = this;
switch (_that) {
case _Taxes() when $default != null:
return $default(_that.gst,_that.pst,_that.hst,_that.qst);case _:
  return null;

}
}

}

/// @nodoc


class _Taxes extends Taxes {
  const _Taxes({this.gst = 0.0, this.pst = 0.0, this.hst = 0.0, this.qst = 0.0}): super._();
  

@override@JsonKey() final  double gst;
@override@JsonKey() final  double pst;
@override@JsonKey() final  double hst;
@override@JsonKey() final  double qst;

/// Create a copy of Taxes
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaxesCopyWith<_Taxes> get copyWith => __$TaxesCopyWithImpl<_Taxes>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Taxes&&(identical(other.gst, gst) || other.gst == gst)&&(identical(other.pst, pst) || other.pst == pst)&&(identical(other.hst, hst) || other.hst == hst)&&(identical(other.qst, qst) || other.qst == qst));
}


@override
int get hashCode => Object.hash(runtimeType,gst,pst,hst,qst);

@override
String toString() {
  return 'Taxes(gst: $gst, pst: $pst, hst: $hst, qst: $qst)';
}


}

/// @nodoc
abstract mixin class _$TaxesCopyWith<$Res> implements $TaxesCopyWith<$Res> {
  factory _$TaxesCopyWith(_Taxes value, $Res Function(_Taxes) _then) = __$TaxesCopyWithImpl;
@override @useResult
$Res call({
 double gst, double pst, double hst, double qst
});




}
/// @nodoc
class __$TaxesCopyWithImpl<$Res>
    implements _$TaxesCopyWith<$Res> {
  __$TaxesCopyWithImpl(this._self, this._then);

  final _Taxes _self;
  final $Res Function(_Taxes) _then;

/// Create a copy of Taxes
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gst = null,Object? pst = null,Object? hst = null,Object? qst = null,}) {
  return _then(_Taxes(
gst: null == gst ? _self.gst : gst // ignore: cast_nullable_to_non_nullable
as double,pst: null == pst ? _self.pst : pst // ignore: cast_nullable_to_non_nullable
as double,hst: null == hst ? _self.hst : hst // ignore: cast_nullable_to_non_nullable
as double,qst: null == qst ? _self.qst : qst // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
