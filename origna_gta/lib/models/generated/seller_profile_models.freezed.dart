// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'seller_profile_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SellerProfile {

// Stripe Connect
 String? get stripeAccountId; bool get payoutsEnabled; bool get chargesEnabled; bool get onboardingCompleted; List<String>? get pendingRequirements;// Commission (basis points — 250 = 2.50%)
 int get commissionRateBps;// Seller stats
 double get avgRating; int get totalReviews; int get totalSales;// Warehouse references
 List<String>? get warehouseIds;// Business info
 String? get businessName; Address? get businessAddress;// Returns policy
 bool get acceptsReturns; int get returnWindowDays;// Verification
 bool get verified; String? get verificationStatus; String? get platform; int? get payoutHoldDays;// Payment
 String? get bankAccountLast4;// Timestamps
 DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of SellerProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SellerProfileCopyWith<SellerProfile> get copyWith => _$SellerProfileCopyWithImpl<SellerProfile>(this as SellerProfile, _$identity);

  /// Serializes this SellerProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SellerProfile&&(identical(other.stripeAccountId, stripeAccountId) || other.stripeAccountId == stripeAccountId)&&(identical(other.payoutsEnabled, payoutsEnabled) || other.payoutsEnabled == payoutsEnabled)&&(identical(other.chargesEnabled, chargesEnabled) || other.chargesEnabled == chargesEnabled)&&(identical(other.onboardingCompleted, onboardingCompleted) || other.onboardingCompleted == onboardingCompleted)&&const DeepCollectionEquality().equals(other.pendingRequirements, pendingRequirements)&&(identical(other.commissionRateBps, commissionRateBps) || other.commissionRateBps == commissionRateBps)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.totalReviews, totalReviews) || other.totalReviews == totalReviews)&&(identical(other.totalSales, totalSales) || other.totalSales == totalSales)&&const DeepCollectionEquality().equals(other.warehouseIds, warehouseIds)&&(identical(other.businessName, businessName) || other.businessName == businessName)&&(identical(other.businessAddress, businessAddress) || other.businessAddress == businessAddress)&&(identical(other.acceptsReturns, acceptsReturns) || other.acceptsReturns == acceptsReturns)&&(identical(other.returnWindowDays, returnWindowDays) || other.returnWindowDays == returnWindowDays)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.payoutHoldDays, payoutHoldDays) || other.payoutHoldDays == payoutHoldDays)&&(identical(other.bankAccountLast4, bankAccountLast4) || other.bankAccountLast4 == bankAccountLast4)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,stripeAccountId,payoutsEnabled,chargesEnabled,onboardingCompleted,const DeepCollectionEquality().hash(pendingRequirements),commissionRateBps,avgRating,totalReviews,totalSales,const DeepCollectionEquality().hash(warehouseIds),businessName,businessAddress,acceptsReturns,returnWindowDays,verified,verificationStatus,platform,payoutHoldDays,bankAccountLast4,createdAt,updatedAt]);

@override
String toString() {
  return 'SellerProfile(stripeAccountId: $stripeAccountId, payoutsEnabled: $payoutsEnabled, chargesEnabled: $chargesEnabled, onboardingCompleted: $onboardingCompleted, pendingRequirements: $pendingRequirements, commissionRateBps: $commissionRateBps, avgRating: $avgRating, totalReviews: $totalReviews, totalSales: $totalSales, warehouseIds: $warehouseIds, businessName: $businessName, businessAddress: $businessAddress, acceptsReturns: $acceptsReturns, returnWindowDays: $returnWindowDays, verified: $verified, verificationStatus: $verificationStatus, platform: $platform, payoutHoldDays: $payoutHoldDays, bankAccountLast4: $bankAccountLast4, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SellerProfileCopyWith<$Res>  {
  factory $SellerProfileCopyWith(SellerProfile value, $Res Function(SellerProfile) _then) = _$SellerProfileCopyWithImpl;
@useResult
$Res call({
 String? stripeAccountId, bool payoutsEnabled, bool chargesEnabled, bool onboardingCompleted, List<String>? pendingRequirements, int commissionRateBps, double avgRating, int totalReviews, int totalSales, List<String>? warehouseIds, String? businessName, Address? businessAddress, bool acceptsReturns, int returnWindowDays, bool verified, String? verificationStatus, String? platform, int? payoutHoldDays, String? bankAccountLast4, DateTime? createdAt, DateTime? updatedAt
});


$AddressCopyWith<$Res>? get businessAddress;

}
/// @nodoc
class _$SellerProfileCopyWithImpl<$Res>
    implements $SellerProfileCopyWith<$Res> {
  _$SellerProfileCopyWithImpl(this._self, this._then);

  final SellerProfile _self;
  final $Res Function(SellerProfile) _then;

/// Create a copy of SellerProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stripeAccountId = freezed,Object? payoutsEnabled = null,Object? chargesEnabled = null,Object? onboardingCompleted = null,Object? pendingRequirements = freezed,Object? commissionRateBps = null,Object? avgRating = null,Object? totalReviews = null,Object? totalSales = null,Object? warehouseIds = freezed,Object? businessName = freezed,Object? businessAddress = freezed,Object? acceptsReturns = null,Object? returnWindowDays = null,Object? verified = null,Object? verificationStatus = freezed,Object? platform = freezed,Object? payoutHoldDays = freezed,Object? bankAccountLast4 = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
stripeAccountId: freezed == stripeAccountId ? _self.stripeAccountId : stripeAccountId // ignore: cast_nullable_to_non_nullable
as String?,payoutsEnabled: null == payoutsEnabled ? _self.payoutsEnabled : payoutsEnabled // ignore: cast_nullable_to_non_nullable
as bool,chargesEnabled: null == chargesEnabled ? _self.chargesEnabled : chargesEnabled // ignore: cast_nullable_to_non_nullable
as bool,onboardingCompleted: null == onboardingCompleted ? _self.onboardingCompleted : onboardingCompleted // ignore: cast_nullable_to_non_nullable
as bool,pendingRequirements: freezed == pendingRequirements ? _self.pendingRequirements : pendingRequirements // ignore: cast_nullable_to_non_nullable
as List<String>?,commissionRateBps: null == commissionRateBps ? _self.commissionRateBps : commissionRateBps // ignore: cast_nullable_to_non_nullable
as int,avgRating: null == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double,totalReviews: null == totalReviews ? _self.totalReviews : totalReviews // ignore: cast_nullable_to_non_nullable
as int,totalSales: null == totalSales ? _self.totalSales : totalSales // ignore: cast_nullable_to_non_nullable
as int,warehouseIds: freezed == warehouseIds ? _self.warehouseIds : warehouseIds // ignore: cast_nullable_to_non_nullable
as List<String>?,businessName: freezed == businessName ? _self.businessName : businessName // ignore: cast_nullable_to_non_nullable
as String?,businessAddress: freezed == businessAddress ? _self.businessAddress : businessAddress // ignore: cast_nullable_to_non_nullable
as Address?,acceptsReturns: null == acceptsReturns ? _self.acceptsReturns : acceptsReturns // ignore: cast_nullable_to_non_nullable
as bool,returnWindowDays: null == returnWindowDays ? _self.returnWindowDays : returnWindowDays // ignore: cast_nullable_to_non_nullable
as int,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,verificationStatus: freezed == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as String?,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String?,payoutHoldDays: freezed == payoutHoldDays ? _self.payoutHoldDays : payoutHoldDays // ignore: cast_nullable_to_non_nullable
as int?,bankAccountLast4: freezed == bankAccountLast4 ? _self.bankAccountLast4 : bankAccountLast4 // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of SellerProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get businessAddress {
    if (_self.businessAddress == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.businessAddress!, (value) {
    return _then(_self.copyWith(businessAddress: value));
  });
}
}


/// Adds pattern-matching-related methods to [SellerProfile].
extension SellerProfilePatterns on SellerProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SellerProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SellerProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SellerProfile value)  $default,){
final _that = this;
switch (_that) {
case _SellerProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SellerProfile value)?  $default,){
final _that = this;
switch (_that) {
case _SellerProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? stripeAccountId,  bool payoutsEnabled,  bool chargesEnabled,  bool onboardingCompleted,  List<String>? pendingRequirements,  int commissionRateBps,  double avgRating,  int totalReviews,  int totalSales,  List<String>? warehouseIds,  String? businessName,  Address? businessAddress,  bool acceptsReturns,  int returnWindowDays,  bool verified,  String? verificationStatus,  String? platform,  int? payoutHoldDays,  String? bankAccountLast4,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SellerProfile() when $default != null:
return $default(_that.stripeAccountId,_that.payoutsEnabled,_that.chargesEnabled,_that.onboardingCompleted,_that.pendingRequirements,_that.commissionRateBps,_that.avgRating,_that.totalReviews,_that.totalSales,_that.warehouseIds,_that.businessName,_that.businessAddress,_that.acceptsReturns,_that.returnWindowDays,_that.verified,_that.verificationStatus,_that.platform,_that.payoutHoldDays,_that.bankAccountLast4,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? stripeAccountId,  bool payoutsEnabled,  bool chargesEnabled,  bool onboardingCompleted,  List<String>? pendingRequirements,  int commissionRateBps,  double avgRating,  int totalReviews,  int totalSales,  List<String>? warehouseIds,  String? businessName,  Address? businessAddress,  bool acceptsReturns,  int returnWindowDays,  bool verified,  String? verificationStatus,  String? platform,  int? payoutHoldDays,  String? bankAccountLast4,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _SellerProfile():
return $default(_that.stripeAccountId,_that.payoutsEnabled,_that.chargesEnabled,_that.onboardingCompleted,_that.pendingRequirements,_that.commissionRateBps,_that.avgRating,_that.totalReviews,_that.totalSales,_that.warehouseIds,_that.businessName,_that.businessAddress,_that.acceptsReturns,_that.returnWindowDays,_that.verified,_that.verificationStatus,_that.platform,_that.payoutHoldDays,_that.bankAccountLast4,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? stripeAccountId,  bool payoutsEnabled,  bool chargesEnabled,  bool onboardingCompleted,  List<String>? pendingRequirements,  int commissionRateBps,  double avgRating,  int totalReviews,  int totalSales,  List<String>? warehouseIds,  String? businessName,  Address? businessAddress,  bool acceptsReturns,  int returnWindowDays,  bool verified,  String? verificationStatus,  String? platform,  int? payoutHoldDays,  String? bankAccountLast4,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SellerProfile() when $default != null:
return $default(_that.stripeAccountId,_that.payoutsEnabled,_that.chargesEnabled,_that.onboardingCompleted,_that.pendingRequirements,_that.commissionRateBps,_that.avgRating,_that.totalReviews,_that.totalSales,_that.warehouseIds,_that.businessName,_that.businessAddress,_that.acceptsReturns,_that.returnWindowDays,_that.verified,_that.verificationStatus,_that.platform,_that.payoutHoldDays,_that.bankAccountLast4,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SellerProfile implements SellerProfile {
  const _SellerProfile({this.stripeAccountId, this.payoutsEnabled = false, this.chargesEnabled = false, this.onboardingCompleted = false, final  List<String>? pendingRequirements, this.commissionRateBps = 250, this.avgRating = 0.0, this.totalReviews = 0, this.totalSales = 0, final  List<String>? warehouseIds, this.businessName, this.businessAddress, this.acceptsReturns = true, this.returnWindowDays = 30, this.verified = false, this.verificationStatus, this.platform, this.payoutHoldDays, this.bankAccountLast4, this.createdAt, this.updatedAt}): _pendingRequirements = pendingRequirements,_warehouseIds = warehouseIds;
  factory _SellerProfile.fromJson(Map<String, dynamic> json) => _$SellerProfileFromJson(json);

// Stripe Connect
@override final  String? stripeAccountId;
@override@JsonKey() final  bool payoutsEnabled;
@override@JsonKey() final  bool chargesEnabled;
@override@JsonKey() final  bool onboardingCompleted;
 final  List<String>? _pendingRequirements;
@override List<String>? get pendingRequirements {
  final value = _pendingRequirements;
  if (value == null) return null;
  if (_pendingRequirements is EqualUnmodifiableListView) return _pendingRequirements;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Commission (basis points — 250 = 2.50%)
@override@JsonKey() final  int commissionRateBps;
// Seller stats
@override@JsonKey() final  double avgRating;
@override@JsonKey() final  int totalReviews;
@override@JsonKey() final  int totalSales;
// Warehouse references
 final  List<String>? _warehouseIds;
// Warehouse references
@override List<String>? get warehouseIds {
  final value = _warehouseIds;
  if (value == null) return null;
  if (_warehouseIds is EqualUnmodifiableListView) return _warehouseIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Business info
@override final  String? businessName;
@override final  Address? businessAddress;
// Returns policy
@override@JsonKey() final  bool acceptsReturns;
@override@JsonKey() final  int returnWindowDays;
// Verification
@override@JsonKey() final  bool verified;
@override final  String? verificationStatus;
@override final  String? platform;
@override final  int? payoutHoldDays;
// Payment
@override final  String? bankAccountLast4;
// Timestamps
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of SellerProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SellerProfileCopyWith<_SellerProfile> get copyWith => __$SellerProfileCopyWithImpl<_SellerProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SellerProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SellerProfile&&(identical(other.stripeAccountId, stripeAccountId) || other.stripeAccountId == stripeAccountId)&&(identical(other.payoutsEnabled, payoutsEnabled) || other.payoutsEnabled == payoutsEnabled)&&(identical(other.chargesEnabled, chargesEnabled) || other.chargesEnabled == chargesEnabled)&&(identical(other.onboardingCompleted, onboardingCompleted) || other.onboardingCompleted == onboardingCompleted)&&const DeepCollectionEquality().equals(other._pendingRequirements, _pendingRequirements)&&(identical(other.commissionRateBps, commissionRateBps) || other.commissionRateBps == commissionRateBps)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.totalReviews, totalReviews) || other.totalReviews == totalReviews)&&(identical(other.totalSales, totalSales) || other.totalSales == totalSales)&&const DeepCollectionEquality().equals(other._warehouseIds, _warehouseIds)&&(identical(other.businessName, businessName) || other.businessName == businessName)&&(identical(other.businessAddress, businessAddress) || other.businessAddress == businessAddress)&&(identical(other.acceptsReturns, acceptsReturns) || other.acceptsReturns == acceptsReturns)&&(identical(other.returnWindowDays, returnWindowDays) || other.returnWindowDays == returnWindowDays)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.payoutHoldDays, payoutHoldDays) || other.payoutHoldDays == payoutHoldDays)&&(identical(other.bankAccountLast4, bankAccountLast4) || other.bankAccountLast4 == bankAccountLast4)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,stripeAccountId,payoutsEnabled,chargesEnabled,onboardingCompleted,const DeepCollectionEquality().hash(_pendingRequirements),commissionRateBps,avgRating,totalReviews,totalSales,const DeepCollectionEquality().hash(_warehouseIds),businessName,businessAddress,acceptsReturns,returnWindowDays,verified,verificationStatus,platform,payoutHoldDays,bankAccountLast4,createdAt,updatedAt]);

@override
String toString() {
  return 'SellerProfile(stripeAccountId: $stripeAccountId, payoutsEnabled: $payoutsEnabled, chargesEnabled: $chargesEnabled, onboardingCompleted: $onboardingCompleted, pendingRequirements: $pendingRequirements, commissionRateBps: $commissionRateBps, avgRating: $avgRating, totalReviews: $totalReviews, totalSales: $totalSales, warehouseIds: $warehouseIds, businessName: $businessName, businessAddress: $businessAddress, acceptsReturns: $acceptsReturns, returnWindowDays: $returnWindowDays, verified: $verified, verificationStatus: $verificationStatus, platform: $platform, payoutHoldDays: $payoutHoldDays, bankAccountLast4: $bankAccountLast4, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SellerProfileCopyWith<$Res> implements $SellerProfileCopyWith<$Res> {
  factory _$SellerProfileCopyWith(_SellerProfile value, $Res Function(_SellerProfile) _then) = __$SellerProfileCopyWithImpl;
@override @useResult
$Res call({
 String? stripeAccountId, bool payoutsEnabled, bool chargesEnabled, bool onboardingCompleted, List<String>? pendingRequirements, int commissionRateBps, double avgRating, int totalReviews, int totalSales, List<String>? warehouseIds, String? businessName, Address? businessAddress, bool acceptsReturns, int returnWindowDays, bool verified, String? verificationStatus, String? platform, int? payoutHoldDays, String? bankAccountLast4, DateTime? createdAt, DateTime? updatedAt
});


@override $AddressCopyWith<$Res>? get businessAddress;

}
/// @nodoc
class __$SellerProfileCopyWithImpl<$Res>
    implements _$SellerProfileCopyWith<$Res> {
  __$SellerProfileCopyWithImpl(this._self, this._then);

  final _SellerProfile _self;
  final $Res Function(_SellerProfile) _then;

/// Create a copy of SellerProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stripeAccountId = freezed,Object? payoutsEnabled = null,Object? chargesEnabled = null,Object? onboardingCompleted = null,Object? pendingRequirements = freezed,Object? commissionRateBps = null,Object? avgRating = null,Object? totalReviews = null,Object? totalSales = null,Object? warehouseIds = freezed,Object? businessName = freezed,Object? businessAddress = freezed,Object? acceptsReturns = null,Object? returnWindowDays = null,Object? verified = null,Object? verificationStatus = freezed,Object? platform = freezed,Object? payoutHoldDays = freezed,Object? bankAccountLast4 = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_SellerProfile(
stripeAccountId: freezed == stripeAccountId ? _self.stripeAccountId : stripeAccountId // ignore: cast_nullable_to_non_nullable
as String?,payoutsEnabled: null == payoutsEnabled ? _self.payoutsEnabled : payoutsEnabled // ignore: cast_nullable_to_non_nullable
as bool,chargesEnabled: null == chargesEnabled ? _self.chargesEnabled : chargesEnabled // ignore: cast_nullable_to_non_nullable
as bool,onboardingCompleted: null == onboardingCompleted ? _self.onboardingCompleted : onboardingCompleted // ignore: cast_nullable_to_non_nullable
as bool,pendingRequirements: freezed == pendingRequirements ? _self._pendingRequirements : pendingRequirements // ignore: cast_nullable_to_non_nullable
as List<String>?,commissionRateBps: null == commissionRateBps ? _self.commissionRateBps : commissionRateBps // ignore: cast_nullable_to_non_nullable
as int,avgRating: null == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double,totalReviews: null == totalReviews ? _self.totalReviews : totalReviews // ignore: cast_nullable_to_non_nullable
as int,totalSales: null == totalSales ? _self.totalSales : totalSales // ignore: cast_nullable_to_non_nullable
as int,warehouseIds: freezed == warehouseIds ? _self._warehouseIds : warehouseIds // ignore: cast_nullable_to_non_nullable
as List<String>?,businessName: freezed == businessName ? _self.businessName : businessName // ignore: cast_nullable_to_non_nullable
as String?,businessAddress: freezed == businessAddress ? _self.businessAddress : businessAddress // ignore: cast_nullable_to_non_nullable
as Address?,acceptsReturns: null == acceptsReturns ? _self.acceptsReturns : acceptsReturns // ignore: cast_nullable_to_non_nullable
as bool,returnWindowDays: null == returnWindowDays ? _self.returnWindowDays : returnWindowDays // ignore: cast_nullable_to_non_nullable
as int,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,verificationStatus: freezed == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as String?,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String?,payoutHoldDays: freezed == payoutHoldDays ? _self.payoutHoldDays : payoutHoldDays // ignore: cast_nullable_to_non_nullable
as int?,bankAccountLast4: freezed == bankAccountLast4 ? _self.bankAccountLast4 : bankAccountLast4 // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of SellerProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get businessAddress {
    if (_self.businessAddress == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.businessAddress!, (value) {
    return _then(_self.copyWith(businessAddress: value));
  });
}
}

// dart format on
