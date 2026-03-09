// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'return_request_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReturnRequest {

 String get returnId; String get orderId; String get orderItemId; String get buyerId; String get sellerId; String get productId; String get productName; int get quantity; String get returnStatus; String get returnReason; String? get returnAdminNote; String? get returnTrackingNumber; int? get returnRefundAmountCents; DateTime? get requestedAt; DateTime? get updatedAt; DateTime? get resolvedAt; DateTime? get escalatedAt; String? get escalationReason;
/// Create a copy of ReturnRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReturnRequestCopyWith<ReturnRequest> get copyWith => _$ReturnRequestCopyWithImpl<ReturnRequest>(this as ReturnRequest, _$identity);

  /// Serializes this ReturnRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReturnRequest&&(identical(other.returnId, returnId) || other.returnId == returnId)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.orderItemId, orderItemId) || other.orderItemId == orderItemId)&&(identical(other.buyerId, buyerId) || other.buyerId == buyerId)&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.returnStatus, returnStatus) || other.returnStatus == returnStatus)&&(identical(other.returnReason, returnReason) || other.returnReason == returnReason)&&(identical(other.returnAdminNote, returnAdminNote) || other.returnAdminNote == returnAdminNote)&&(identical(other.returnTrackingNumber, returnTrackingNumber) || other.returnTrackingNumber == returnTrackingNumber)&&(identical(other.returnRefundAmountCents, returnRefundAmountCents) || other.returnRefundAmountCents == returnRefundAmountCents)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.escalatedAt, escalatedAt) || other.escalatedAt == escalatedAt)&&(identical(other.escalationReason, escalationReason) || other.escalationReason == escalationReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,returnId,orderId,orderItemId,buyerId,sellerId,productId,productName,quantity,returnStatus,returnReason,returnAdminNote,returnTrackingNumber,returnRefundAmountCents,requestedAt,updatedAt,resolvedAt,escalatedAt,escalationReason);

@override
String toString() {
  return 'ReturnRequest(returnId: $returnId, orderId: $orderId, orderItemId: $orderItemId, buyerId: $buyerId, sellerId: $sellerId, productId: $productId, productName: $productName, quantity: $quantity, returnStatus: $returnStatus, returnReason: $returnReason, returnAdminNote: $returnAdminNote, returnTrackingNumber: $returnTrackingNumber, returnRefundAmountCents: $returnRefundAmountCents, requestedAt: $requestedAt, updatedAt: $updatedAt, resolvedAt: $resolvedAt, escalatedAt: $escalatedAt, escalationReason: $escalationReason)';
}


}

/// @nodoc
abstract mixin class $ReturnRequestCopyWith<$Res>  {
  factory $ReturnRequestCopyWith(ReturnRequest value, $Res Function(ReturnRequest) _then) = _$ReturnRequestCopyWithImpl;
@useResult
$Res call({
 String returnId, String orderId, String orderItemId, String buyerId, String sellerId, String productId, String productName, int quantity, String returnStatus, String returnReason, String? returnAdminNote, String? returnTrackingNumber, int? returnRefundAmountCents, DateTime? requestedAt, DateTime? updatedAt, DateTime? resolvedAt, DateTime? escalatedAt, String? escalationReason
});




}
/// @nodoc
class _$ReturnRequestCopyWithImpl<$Res>
    implements $ReturnRequestCopyWith<$Res> {
  _$ReturnRequestCopyWithImpl(this._self, this._then);

  final ReturnRequest _self;
  final $Res Function(ReturnRequest) _then;

/// Create a copy of ReturnRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? returnId = null,Object? orderId = null,Object? orderItemId = null,Object? buyerId = null,Object? sellerId = null,Object? productId = null,Object? productName = null,Object? quantity = null,Object? returnStatus = null,Object? returnReason = null,Object? returnAdminNote = freezed,Object? returnTrackingNumber = freezed,Object? returnRefundAmountCents = freezed,Object? requestedAt = freezed,Object? updatedAt = freezed,Object? resolvedAt = freezed,Object? escalatedAt = freezed,Object? escalationReason = freezed,}) {
  return _then(_self.copyWith(
returnId: null == returnId ? _self.returnId : returnId // ignore: cast_nullable_to_non_nullable
as String,orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,orderItemId: null == orderItemId ? _self.orderItemId : orderItemId // ignore: cast_nullable_to_non_nullable
as String,buyerId: null == buyerId ? _self.buyerId : buyerId // ignore: cast_nullable_to_non_nullable
as String,sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,productName: null == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,returnStatus: null == returnStatus ? _self.returnStatus : returnStatus // ignore: cast_nullable_to_non_nullable
as String,returnReason: null == returnReason ? _self.returnReason : returnReason // ignore: cast_nullable_to_non_nullable
as String,returnAdminNote: freezed == returnAdminNote ? _self.returnAdminNote : returnAdminNote // ignore: cast_nullable_to_non_nullable
as String?,returnTrackingNumber: freezed == returnTrackingNumber ? _self.returnTrackingNumber : returnTrackingNumber // ignore: cast_nullable_to_non_nullable
as String?,returnRefundAmountCents: freezed == returnRefundAmountCents ? _self.returnRefundAmountCents : returnRefundAmountCents // ignore: cast_nullable_to_non_nullable
as int?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,escalatedAt: freezed == escalatedAt ? _self.escalatedAt : escalatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,escalationReason: freezed == escalationReason ? _self.escalationReason : escalationReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReturnRequest].
extension ReturnRequestPatterns on ReturnRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReturnRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReturnRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReturnRequest value)  $default,){
final _that = this;
switch (_that) {
case _ReturnRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReturnRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ReturnRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String returnId,  String orderId,  String orderItemId,  String buyerId,  String sellerId,  String productId,  String productName,  int quantity,  String returnStatus,  String returnReason,  String? returnAdminNote,  String? returnTrackingNumber,  int? returnRefundAmountCents,  DateTime? requestedAt,  DateTime? updatedAt,  DateTime? resolvedAt,  DateTime? escalatedAt,  String? escalationReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReturnRequest() when $default != null:
return $default(_that.returnId,_that.orderId,_that.orderItemId,_that.buyerId,_that.sellerId,_that.productId,_that.productName,_that.quantity,_that.returnStatus,_that.returnReason,_that.returnAdminNote,_that.returnTrackingNumber,_that.returnRefundAmountCents,_that.requestedAt,_that.updatedAt,_that.resolvedAt,_that.escalatedAt,_that.escalationReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String returnId,  String orderId,  String orderItemId,  String buyerId,  String sellerId,  String productId,  String productName,  int quantity,  String returnStatus,  String returnReason,  String? returnAdminNote,  String? returnTrackingNumber,  int? returnRefundAmountCents,  DateTime? requestedAt,  DateTime? updatedAt,  DateTime? resolvedAt,  DateTime? escalatedAt,  String? escalationReason)  $default,) {final _that = this;
switch (_that) {
case _ReturnRequest():
return $default(_that.returnId,_that.orderId,_that.orderItemId,_that.buyerId,_that.sellerId,_that.productId,_that.productName,_that.quantity,_that.returnStatus,_that.returnReason,_that.returnAdminNote,_that.returnTrackingNumber,_that.returnRefundAmountCents,_that.requestedAt,_that.updatedAt,_that.resolvedAt,_that.escalatedAt,_that.escalationReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String returnId,  String orderId,  String orderItemId,  String buyerId,  String sellerId,  String productId,  String productName,  int quantity,  String returnStatus,  String returnReason,  String? returnAdminNote,  String? returnTrackingNumber,  int? returnRefundAmountCents,  DateTime? requestedAt,  DateTime? updatedAt,  DateTime? resolvedAt,  DateTime? escalatedAt,  String? escalationReason)?  $default,) {final _that = this;
switch (_that) {
case _ReturnRequest() when $default != null:
return $default(_that.returnId,_that.orderId,_that.orderItemId,_that.buyerId,_that.sellerId,_that.productId,_that.productName,_that.quantity,_that.returnStatus,_that.returnReason,_that.returnAdminNote,_that.returnTrackingNumber,_that.returnRefundAmountCents,_that.requestedAt,_that.updatedAt,_that.resolvedAt,_that.escalatedAt,_that.escalationReason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReturnRequest implements ReturnRequest {
  const _ReturnRequest({required this.returnId, required this.orderId, required this.orderItemId, required this.buyerId, required this.sellerId, required this.productId, required this.productName, this.quantity = 1, this.returnStatus = 'requested', required this.returnReason, this.returnAdminNote, this.returnTrackingNumber, this.returnRefundAmountCents, this.requestedAt, this.updatedAt, this.resolvedAt, this.escalatedAt, this.escalationReason});
  factory _ReturnRequest.fromJson(Map<String, dynamic> json) => _$ReturnRequestFromJson(json);

@override final  String returnId;
@override final  String orderId;
@override final  String orderItemId;
@override final  String buyerId;
@override final  String sellerId;
@override final  String productId;
@override final  String productName;
@override@JsonKey() final  int quantity;
@override@JsonKey() final  String returnStatus;
@override final  String returnReason;
@override final  String? returnAdminNote;
@override final  String? returnTrackingNumber;
@override final  int? returnRefundAmountCents;
@override final  DateTime? requestedAt;
@override final  DateTime? updatedAt;
@override final  DateTime? resolvedAt;
@override final  DateTime? escalatedAt;
@override final  String? escalationReason;

/// Create a copy of ReturnRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReturnRequestCopyWith<_ReturnRequest> get copyWith => __$ReturnRequestCopyWithImpl<_ReturnRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReturnRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReturnRequest&&(identical(other.returnId, returnId) || other.returnId == returnId)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.orderItemId, orderItemId) || other.orderItemId == orderItemId)&&(identical(other.buyerId, buyerId) || other.buyerId == buyerId)&&(identical(other.sellerId, sellerId) || other.sellerId == sellerId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.returnStatus, returnStatus) || other.returnStatus == returnStatus)&&(identical(other.returnReason, returnReason) || other.returnReason == returnReason)&&(identical(other.returnAdminNote, returnAdminNote) || other.returnAdminNote == returnAdminNote)&&(identical(other.returnTrackingNumber, returnTrackingNumber) || other.returnTrackingNumber == returnTrackingNumber)&&(identical(other.returnRefundAmountCents, returnRefundAmountCents) || other.returnRefundAmountCents == returnRefundAmountCents)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.escalatedAt, escalatedAt) || other.escalatedAt == escalatedAt)&&(identical(other.escalationReason, escalationReason) || other.escalationReason == escalationReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,returnId,orderId,orderItemId,buyerId,sellerId,productId,productName,quantity,returnStatus,returnReason,returnAdminNote,returnTrackingNumber,returnRefundAmountCents,requestedAt,updatedAt,resolvedAt,escalatedAt,escalationReason);

@override
String toString() {
  return 'ReturnRequest(returnId: $returnId, orderId: $orderId, orderItemId: $orderItemId, buyerId: $buyerId, sellerId: $sellerId, productId: $productId, productName: $productName, quantity: $quantity, returnStatus: $returnStatus, returnReason: $returnReason, returnAdminNote: $returnAdminNote, returnTrackingNumber: $returnTrackingNumber, returnRefundAmountCents: $returnRefundAmountCents, requestedAt: $requestedAt, updatedAt: $updatedAt, resolvedAt: $resolvedAt, escalatedAt: $escalatedAt, escalationReason: $escalationReason)';
}


}

/// @nodoc
abstract mixin class _$ReturnRequestCopyWith<$Res> implements $ReturnRequestCopyWith<$Res> {
  factory _$ReturnRequestCopyWith(_ReturnRequest value, $Res Function(_ReturnRequest) _then) = __$ReturnRequestCopyWithImpl;
@override @useResult
$Res call({
 String returnId, String orderId, String orderItemId, String buyerId, String sellerId, String productId, String productName, int quantity, String returnStatus, String returnReason, String? returnAdminNote, String? returnTrackingNumber, int? returnRefundAmountCents, DateTime? requestedAt, DateTime? updatedAt, DateTime? resolvedAt, DateTime? escalatedAt, String? escalationReason
});




}
/// @nodoc
class __$ReturnRequestCopyWithImpl<$Res>
    implements _$ReturnRequestCopyWith<$Res> {
  __$ReturnRequestCopyWithImpl(this._self, this._then);

  final _ReturnRequest _self;
  final $Res Function(_ReturnRequest) _then;

/// Create a copy of ReturnRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? returnId = null,Object? orderId = null,Object? orderItemId = null,Object? buyerId = null,Object? sellerId = null,Object? productId = null,Object? productName = null,Object? quantity = null,Object? returnStatus = null,Object? returnReason = null,Object? returnAdminNote = freezed,Object? returnTrackingNumber = freezed,Object? returnRefundAmountCents = freezed,Object? requestedAt = freezed,Object? updatedAt = freezed,Object? resolvedAt = freezed,Object? escalatedAt = freezed,Object? escalationReason = freezed,}) {
  return _then(_ReturnRequest(
returnId: null == returnId ? _self.returnId : returnId // ignore: cast_nullable_to_non_nullable
as String,orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,orderItemId: null == orderItemId ? _self.orderItemId : orderItemId // ignore: cast_nullable_to_non_nullable
as String,buyerId: null == buyerId ? _self.buyerId : buyerId // ignore: cast_nullable_to_non_nullable
as String,sellerId: null == sellerId ? _self.sellerId : sellerId // ignore: cast_nullable_to_non_nullable
as String,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,productName: null == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,returnStatus: null == returnStatus ? _self.returnStatus : returnStatus // ignore: cast_nullable_to_non_nullable
as String,returnReason: null == returnReason ? _self.returnReason : returnReason // ignore: cast_nullable_to_non_nullable
as String,returnAdminNote: freezed == returnAdminNote ? _self.returnAdminNote : returnAdminNote // ignore: cast_nullable_to_non_nullable
as String?,returnTrackingNumber: freezed == returnTrackingNumber ? _self.returnTrackingNumber : returnTrackingNumber // ignore: cast_nullable_to_non_nullable
as String?,returnRefundAmountCents: freezed == returnRefundAmountCents ? _self.returnRefundAmountCents : returnRefundAmountCents // ignore: cast_nullable_to_non_nullable
as int?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,escalatedAt: freezed == escalatedAt ? _self.escalatedAt : escalatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,escalationReason: freezed == escalationReason ? _self.escalationReason : escalationReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
