// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$User {

 String get uid; String get email; String get name; List<UserRole> get roles; Address? get address; DateTime get createdAt;// Stripe buyer information
 String? get customerId; String? get lastCheckoutSession; String? get lastOrderId; DateTime? get lastCheckoutTimestamp;// Seller flag (details in seller_profiles/{uid})
 bool get isSeller;// Account status
 bool get suspended; DateTime? get suspendedAt; DateTime? get updatedAt;// Payment provider
 String? get paymentProvider;// Suspension details
 DateTime? get unsuspendedAt; String? get suspendedBy; String? get suspensionReason;// Tax exemption for businesses
 Map<String, dynamic>? get taxExemption;// MFA status (secrets live in user_security — backend only)
 bool get mfaEnabled; DateTime? get mfaEnrolledAt; DateTime? get lastMfaVerify;// === CONSENT & COMPLIANCE (CASL + PIPEDA + Quebec Law 25) ===
 bool get emailConsent; bool get marketingOptIn; DateTime? get consentTimestamp; String? get consentMethod; DateTime? get privacyAcceptedAt; DateTime? get termsAcceptedAt; String? get privacyPolicyVersion; String? get termsVersion; String get preferredLanguage; DateTime? get unsubscribedAt; bool get dataProcessingConsent;// === PREMIUM SUBSCRIPTION ===
 bool get isPremium; DateTime? get premiumSince; DateTime? get premiumExpiresAt; String? get stripeSubscriptionId; bool get notifyNewProducts; bool get notifyTrending; bool get pushEnabled;// === FCM (push notifications) ===
 String? get fcmToken; DateTime? get fcmTokenUpdatedAt;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.email, email) || other.email == email)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.roles, roles)&&(identical(other.address, address) || other.address == address)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.lastCheckoutSession, lastCheckoutSession) || other.lastCheckoutSession == lastCheckoutSession)&&(identical(other.lastOrderId, lastOrderId) || other.lastOrderId == lastOrderId)&&(identical(other.lastCheckoutTimestamp, lastCheckoutTimestamp) || other.lastCheckoutTimestamp == lastCheckoutTimestamp)&&(identical(other.isSeller, isSeller) || other.isSeller == isSeller)&&(identical(other.suspended, suspended) || other.suspended == suspended)&&(identical(other.suspendedAt, suspendedAt) || other.suspendedAt == suspendedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.paymentProvider, paymentProvider) || other.paymentProvider == paymentProvider)&&(identical(other.unsuspendedAt, unsuspendedAt) || other.unsuspendedAt == unsuspendedAt)&&(identical(other.suspendedBy, suspendedBy) || other.suspendedBy == suspendedBy)&&(identical(other.suspensionReason, suspensionReason) || other.suspensionReason == suspensionReason)&&const DeepCollectionEquality().equals(other.taxExemption, taxExemption)&&(identical(other.mfaEnabled, mfaEnabled) || other.mfaEnabled == mfaEnabled)&&(identical(other.mfaEnrolledAt, mfaEnrolledAt) || other.mfaEnrolledAt == mfaEnrolledAt)&&(identical(other.lastMfaVerify, lastMfaVerify) || other.lastMfaVerify == lastMfaVerify)&&(identical(other.emailConsent, emailConsent) || other.emailConsent == emailConsent)&&(identical(other.marketingOptIn, marketingOptIn) || other.marketingOptIn == marketingOptIn)&&(identical(other.consentTimestamp, consentTimestamp) || other.consentTimestamp == consentTimestamp)&&(identical(other.consentMethod, consentMethod) || other.consentMethod == consentMethod)&&(identical(other.privacyAcceptedAt, privacyAcceptedAt) || other.privacyAcceptedAt == privacyAcceptedAt)&&(identical(other.termsAcceptedAt, termsAcceptedAt) || other.termsAcceptedAt == termsAcceptedAt)&&(identical(other.privacyPolicyVersion, privacyPolicyVersion) || other.privacyPolicyVersion == privacyPolicyVersion)&&(identical(other.termsVersion, termsVersion) || other.termsVersion == termsVersion)&&(identical(other.preferredLanguage, preferredLanguage) || other.preferredLanguage == preferredLanguage)&&(identical(other.unsubscribedAt, unsubscribedAt) || other.unsubscribedAt == unsubscribedAt)&&(identical(other.dataProcessingConsent, dataProcessingConsent) || other.dataProcessingConsent == dataProcessingConsent)&&(identical(other.isPremium, isPremium) || other.isPremium == isPremium)&&(identical(other.premiumSince, premiumSince) || other.premiumSince == premiumSince)&&(identical(other.premiumExpiresAt, premiumExpiresAt) || other.premiumExpiresAt == premiumExpiresAt)&&(identical(other.stripeSubscriptionId, stripeSubscriptionId) || other.stripeSubscriptionId == stripeSubscriptionId)&&(identical(other.notifyNewProducts, notifyNewProducts) || other.notifyNewProducts == notifyNewProducts)&&(identical(other.notifyTrending, notifyTrending) || other.notifyTrending == notifyTrending)&&(identical(other.pushEnabled, pushEnabled) || other.pushEnabled == pushEnabled)&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken)&&(identical(other.fcmTokenUpdatedAt, fcmTokenUpdatedAt) || other.fcmTokenUpdatedAt == fcmTokenUpdatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,uid,email,name,const DeepCollectionEquality().hash(roles),address,createdAt,customerId,lastCheckoutSession,lastOrderId,lastCheckoutTimestamp,isSeller,suspended,suspendedAt,updatedAt,paymentProvider,unsuspendedAt,suspendedBy,suspensionReason,const DeepCollectionEquality().hash(taxExemption),mfaEnabled,mfaEnrolledAt,lastMfaVerify,emailConsent,marketingOptIn,consentTimestamp,consentMethod,privacyAcceptedAt,termsAcceptedAt,privacyPolicyVersion,termsVersion,preferredLanguage,unsubscribedAt,dataProcessingConsent,isPremium,premiumSince,premiumExpiresAt,stripeSubscriptionId,notifyNewProducts,notifyTrending,pushEnabled,fcmToken,fcmTokenUpdatedAt]);

@override
String toString() {
  return 'User(uid: $uid, email: $email, name: $name, roles: $roles, address: $address, createdAt: $createdAt, customerId: $customerId, lastCheckoutSession: $lastCheckoutSession, lastOrderId: $lastOrderId, lastCheckoutTimestamp: $lastCheckoutTimestamp, isSeller: $isSeller, suspended: $suspended, suspendedAt: $suspendedAt, updatedAt: $updatedAt, paymentProvider: $paymentProvider, unsuspendedAt: $unsuspendedAt, suspendedBy: $suspendedBy, suspensionReason: $suspensionReason, taxExemption: $taxExemption, mfaEnabled: $mfaEnabled, mfaEnrolledAt: $mfaEnrolledAt, lastMfaVerify: $lastMfaVerify, emailConsent: $emailConsent, marketingOptIn: $marketingOptIn, consentTimestamp: $consentTimestamp, consentMethod: $consentMethod, privacyAcceptedAt: $privacyAcceptedAt, termsAcceptedAt: $termsAcceptedAt, privacyPolicyVersion: $privacyPolicyVersion, termsVersion: $termsVersion, preferredLanguage: $preferredLanguage, unsubscribedAt: $unsubscribedAt, dataProcessingConsent: $dataProcessingConsent, isPremium: $isPremium, premiumSince: $premiumSince, premiumExpiresAt: $premiumExpiresAt, stripeSubscriptionId: $stripeSubscriptionId, notifyNewProducts: $notifyNewProducts, notifyTrending: $notifyTrending, pushEnabled: $pushEnabled, fcmToken: $fcmToken, fcmTokenUpdatedAt: $fcmTokenUpdatedAt)';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
 String uid, String email, String name, List<UserRole> roles, Address? address, DateTime createdAt, String? customerId, String? lastCheckoutSession, String? lastOrderId, DateTime? lastCheckoutTimestamp, bool isSeller, bool suspended, DateTime? suspendedAt, DateTime? updatedAt, String? paymentProvider, DateTime? unsuspendedAt, String? suspendedBy, String? suspensionReason, Map<String, dynamic>? taxExemption, bool mfaEnabled, DateTime? mfaEnrolledAt, DateTime? lastMfaVerify, bool emailConsent, bool marketingOptIn, DateTime? consentTimestamp, String? consentMethod, DateTime? privacyAcceptedAt, DateTime? termsAcceptedAt, String? privacyPolicyVersion, String? termsVersion, String preferredLanguage, DateTime? unsubscribedAt, bool dataProcessingConsent, bool isPremium, DateTime? premiumSince, DateTime? premiumExpiresAt, String? stripeSubscriptionId, bool notifyNewProducts, bool notifyTrending, bool pushEnabled, String? fcmToken, DateTime? fcmTokenUpdatedAt
});


$AddressCopyWith<$Res>? get address;

}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? email = null,Object? name = null,Object? roles = null,Object? address = freezed,Object? createdAt = null,Object? customerId = freezed,Object? lastCheckoutSession = freezed,Object? lastOrderId = freezed,Object? lastCheckoutTimestamp = freezed,Object? isSeller = null,Object? suspended = null,Object? suspendedAt = freezed,Object? updatedAt = freezed,Object? paymentProvider = freezed,Object? unsuspendedAt = freezed,Object? suspendedBy = freezed,Object? suspensionReason = freezed,Object? taxExemption = freezed,Object? mfaEnabled = null,Object? mfaEnrolledAt = freezed,Object? lastMfaVerify = freezed,Object? emailConsent = null,Object? marketingOptIn = null,Object? consentTimestamp = freezed,Object? consentMethod = freezed,Object? privacyAcceptedAt = freezed,Object? termsAcceptedAt = freezed,Object? privacyPolicyVersion = freezed,Object? termsVersion = freezed,Object? preferredLanguage = null,Object? unsubscribedAt = freezed,Object? dataProcessingConsent = null,Object? isPremium = null,Object? premiumSince = freezed,Object? premiumExpiresAt = freezed,Object? stripeSubscriptionId = freezed,Object? notifyNewProducts = null,Object? notifyTrending = null,Object? pushEnabled = null,Object? fcmToken = freezed,Object? fcmTokenUpdatedAt = freezed,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self.roles : roles // ignore: cast_nullable_to_non_nullable
as List<UserRole>,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,lastCheckoutSession: freezed == lastCheckoutSession ? _self.lastCheckoutSession : lastCheckoutSession // ignore: cast_nullable_to_non_nullable
as String?,lastOrderId: freezed == lastOrderId ? _self.lastOrderId : lastOrderId // ignore: cast_nullable_to_non_nullable
as String?,lastCheckoutTimestamp: freezed == lastCheckoutTimestamp ? _self.lastCheckoutTimestamp : lastCheckoutTimestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,isSeller: null == isSeller ? _self.isSeller : isSeller // ignore: cast_nullable_to_non_nullable
as bool,suspended: null == suspended ? _self.suspended : suspended // ignore: cast_nullable_to_non_nullable
as bool,suspendedAt: freezed == suspendedAt ? _self.suspendedAt : suspendedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,paymentProvider: freezed == paymentProvider ? _self.paymentProvider : paymentProvider // ignore: cast_nullable_to_non_nullable
as String?,unsuspendedAt: freezed == unsuspendedAt ? _self.unsuspendedAt : unsuspendedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,suspendedBy: freezed == suspendedBy ? _self.suspendedBy : suspendedBy // ignore: cast_nullable_to_non_nullable
as String?,suspensionReason: freezed == suspensionReason ? _self.suspensionReason : suspensionReason // ignore: cast_nullable_to_non_nullable
as String?,taxExemption: freezed == taxExemption ? _self.taxExemption : taxExemption // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,mfaEnabled: null == mfaEnabled ? _self.mfaEnabled : mfaEnabled // ignore: cast_nullable_to_non_nullable
as bool,mfaEnrolledAt: freezed == mfaEnrolledAt ? _self.mfaEnrolledAt : mfaEnrolledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMfaVerify: freezed == lastMfaVerify ? _self.lastMfaVerify : lastMfaVerify // ignore: cast_nullable_to_non_nullable
as DateTime?,emailConsent: null == emailConsent ? _self.emailConsent : emailConsent // ignore: cast_nullable_to_non_nullable
as bool,marketingOptIn: null == marketingOptIn ? _self.marketingOptIn : marketingOptIn // ignore: cast_nullable_to_non_nullable
as bool,consentTimestamp: freezed == consentTimestamp ? _self.consentTimestamp : consentTimestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,consentMethod: freezed == consentMethod ? _self.consentMethod : consentMethod // ignore: cast_nullable_to_non_nullable
as String?,privacyAcceptedAt: freezed == privacyAcceptedAt ? _self.privacyAcceptedAt : privacyAcceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,termsAcceptedAt: freezed == termsAcceptedAt ? _self.termsAcceptedAt : termsAcceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,privacyPolicyVersion: freezed == privacyPolicyVersion ? _self.privacyPolicyVersion : privacyPolicyVersion // ignore: cast_nullable_to_non_nullable
as String?,termsVersion: freezed == termsVersion ? _self.termsVersion : termsVersion // ignore: cast_nullable_to_non_nullable
as String?,preferredLanguage: null == preferredLanguage ? _self.preferredLanguage : preferredLanguage // ignore: cast_nullable_to_non_nullable
as String,unsubscribedAt: freezed == unsubscribedAt ? _self.unsubscribedAt : unsubscribedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dataProcessingConsent: null == dataProcessingConsent ? _self.dataProcessingConsent : dataProcessingConsent // ignore: cast_nullable_to_non_nullable
as bool,isPremium: null == isPremium ? _self.isPremium : isPremium // ignore: cast_nullable_to_non_nullable
as bool,premiumSince: freezed == premiumSince ? _self.premiumSince : premiumSince // ignore: cast_nullable_to_non_nullable
as DateTime?,premiumExpiresAt: freezed == premiumExpiresAt ? _self.premiumExpiresAt : premiumExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,stripeSubscriptionId: freezed == stripeSubscriptionId ? _self.stripeSubscriptionId : stripeSubscriptionId // ignore: cast_nullable_to_non_nullable
as String?,notifyNewProducts: null == notifyNewProducts ? _self.notifyNewProducts : notifyNewProducts // ignore: cast_nullable_to_non_nullable
as bool,notifyTrending: null == notifyTrending ? _self.notifyTrending : notifyTrending // ignore: cast_nullable_to_non_nullable
as bool,pushEnabled: null == pushEnabled ? _self.pushEnabled : pushEnabled // ignore: cast_nullable_to_non_nullable
as bool,fcmToken: freezed == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String?,fcmTokenUpdatedAt: freezed == fcmTokenUpdatedAt ? _self.fcmTokenUpdatedAt : fcmTokenUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get address {
    if (_self.address == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.address!, (value) {
    return _then(_self.copyWith(address: value));
  });
}
}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uid,  String email,  String name,  List<UserRole> roles,  Address? address,  DateTime createdAt,  String? customerId,  String? lastCheckoutSession,  String? lastOrderId,  DateTime? lastCheckoutTimestamp,  bool isSeller,  bool suspended,  DateTime? suspendedAt,  DateTime? updatedAt,  String? paymentProvider,  DateTime? unsuspendedAt,  String? suspendedBy,  String? suspensionReason,  Map<String, dynamic>? taxExemption,  bool mfaEnabled,  DateTime? mfaEnrolledAt,  DateTime? lastMfaVerify,  bool emailConsent,  bool marketingOptIn,  DateTime? consentTimestamp,  String? consentMethod,  DateTime? privacyAcceptedAt,  DateTime? termsAcceptedAt,  String? privacyPolicyVersion,  String? termsVersion,  String preferredLanguage,  DateTime? unsubscribedAt,  bool dataProcessingConsent,  bool isPremium,  DateTime? premiumSince,  DateTime? premiumExpiresAt,  String? stripeSubscriptionId,  bool notifyNewProducts,  bool notifyTrending,  bool pushEnabled,  String? fcmToken,  DateTime? fcmTokenUpdatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.uid,_that.email,_that.name,_that.roles,_that.address,_that.createdAt,_that.customerId,_that.lastCheckoutSession,_that.lastOrderId,_that.lastCheckoutTimestamp,_that.isSeller,_that.suspended,_that.suspendedAt,_that.updatedAt,_that.paymentProvider,_that.unsuspendedAt,_that.suspendedBy,_that.suspensionReason,_that.taxExemption,_that.mfaEnabled,_that.mfaEnrolledAt,_that.lastMfaVerify,_that.emailConsent,_that.marketingOptIn,_that.consentTimestamp,_that.consentMethod,_that.privacyAcceptedAt,_that.termsAcceptedAt,_that.privacyPolicyVersion,_that.termsVersion,_that.preferredLanguage,_that.unsubscribedAt,_that.dataProcessingConsent,_that.isPremium,_that.premiumSince,_that.premiumExpiresAt,_that.stripeSubscriptionId,_that.notifyNewProducts,_that.notifyTrending,_that.pushEnabled,_that.fcmToken,_that.fcmTokenUpdatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uid,  String email,  String name,  List<UserRole> roles,  Address? address,  DateTime createdAt,  String? customerId,  String? lastCheckoutSession,  String? lastOrderId,  DateTime? lastCheckoutTimestamp,  bool isSeller,  bool suspended,  DateTime? suspendedAt,  DateTime? updatedAt,  String? paymentProvider,  DateTime? unsuspendedAt,  String? suspendedBy,  String? suspensionReason,  Map<String, dynamic>? taxExemption,  bool mfaEnabled,  DateTime? mfaEnrolledAt,  DateTime? lastMfaVerify,  bool emailConsent,  bool marketingOptIn,  DateTime? consentTimestamp,  String? consentMethod,  DateTime? privacyAcceptedAt,  DateTime? termsAcceptedAt,  String? privacyPolicyVersion,  String? termsVersion,  String preferredLanguage,  DateTime? unsubscribedAt,  bool dataProcessingConsent,  bool isPremium,  DateTime? premiumSince,  DateTime? premiumExpiresAt,  String? stripeSubscriptionId,  bool notifyNewProducts,  bool notifyTrending,  bool pushEnabled,  String? fcmToken,  DateTime? fcmTokenUpdatedAt)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.uid,_that.email,_that.name,_that.roles,_that.address,_that.createdAt,_that.customerId,_that.lastCheckoutSession,_that.lastOrderId,_that.lastCheckoutTimestamp,_that.isSeller,_that.suspended,_that.suspendedAt,_that.updatedAt,_that.paymentProvider,_that.unsuspendedAt,_that.suspendedBy,_that.suspensionReason,_that.taxExemption,_that.mfaEnabled,_that.mfaEnrolledAt,_that.lastMfaVerify,_that.emailConsent,_that.marketingOptIn,_that.consentTimestamp,_that.consentMethod,_that.privacyAcceptedAt,_that.termsAcceptedAt,_that.privacyPolicyVersion,_that.termsVersion,_that.preferredLanguage,_that.unsubscribedAt,_that.dataProcessingConsent,_that.isPremium,_that.premiumSince,_that.premiumExpiresAt,_that.stripeSubscriptionId,_that.notifyNewProducts,_that.notifyTrending,_that.pushEnabled,_that.fcmToken,_that.fcmTokenUpdatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uid,  String email,  String name,  List<UserRole> roles,  Address? address,  DateTime createdAt,  String? customerId,  String? lastCheckoutSession,  String? lastOrderId,  DateTime? lastCheckoutTimestamp,  bool isSeller,  bool suspended,  DateTime? suspendedAt,  DateTime? updatedAt,  String? paymentProvider,  DateTime? unsuspendedAt,  String? suspendedBy,  String? suspensionReason,  Map<String, dynamic>? taxExemption,  bool mfaEnabled,  DateTime? mfaEnrolledAt,  DateTime? lastMfaVerify,  bool emailConsent,  bool marketingOptIn,  DateTime? consentTimestamp,  String? consentMethod,  DateTime? privacyAcceptedAt,  DateTime? termsAcceptedAt,  String? privacyPolicyVersion,  String? termsVersion,  String preferredLanguage,  DateTime? unsubscribedAt,  bool dataProcessingConsent,  bool isPremium,  DateTime? premiumSince,  DateTime? premiumExpiresAt,  String? stripeSubscriptionId,  bool notifyNewProducts,  bool notifyTrending,  bool pushEnabled,  String? fcmToken,  DateTime? fcmTokenUpdatedAt)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.uid,_that.email,_that.name,_that.roles,_that.address,_that.createdAt,_that.customerId,_that.lastCheckoutSession,_that.lastOrderId,_that.lastCheckoutTimestamp,_that.isSeller,_that.suspended,_that.suspendedAt,_that.updatedAt,_that.paymentProvider,_that.unsuspendedAt,_that.suspendedBy,_that.suspensionReason,_that.taxExemption,_that.mfaEnabled,_that.mfaEnrolledAt,_that.lastMfaVerify,_that.emailConsent,_that.marketingOptIn,_that.consentTimestamp,_that.consentMethod,_that.privacyAcceptedAt,_that.termsAcceptedAt,_that.privacyPolicyVersion,_that.termsVersion,_that.preferredLanguage,_that.unsubscribedAt,_that.dataProcessingConsent,_that.isPremium,_that.premiumSince,_that.premiumExpiresAt,_that.stripeSubscriptionId,_that.notifyNewProducts,_that.notifyTrending,_that.pushEnabled,_that.fcmToken,_that.fcmTokenUpdatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _User extends User {
  const _User({required this.uid, required this.email, required this.name, required final  List<UserRole> roles, this.address, required this.createdAt, this.customerId, this.lastCheckoutSession, this.lastOrderId, this.lastCheckoutTimestamp, this.isSeller = false, this.suspended = false, this.suspendedAt, this.updatedAt, this.paymentProvider, this.unsuspendedAt, this.suspendedBy, this.suspensionReason, final  Map<String, dynamic>? taxExemption, this.mfaEnabled = false, this.mfaEnrolledAt, this.lastMfaVerify, this.emailConsent = true, this.marketingOptIn = false, this.consentTimestamp, this.consentMethod, this.privacyAcceptedAt, this.termsAcceptedAt, this.privacyPolicyVersion, this.termsVersion, this.preferredLanguage = 'en', this.unsubscribedAt, this.dataProcessingConsent = false, this.isPremium = false, this.premiumSince, this.premiumExpiresAt, this.stripeSubscriptionId, this.notifyNewProducts = false, this.notifyTrending = false, this.pushEnabled = true, this.fcmToken, this.fcmTokenUpdatedAt}): _roles = roles,_taxExemption = taxExemption,super._();
  factory _User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

@override final  String uid;
@override final  String email;
@override final  String name;
 final  List<UserRole> _roles;
@override List<UserRole> get roles {
  if (_roles is EqualUnmodifiableListView) return _roles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roles);
}

@override final  Address? address;
@override final  DateTime createdAt;
// Stripe buyer information
@override final  String? customerId;
@override final  String? lastCheckoutSession;
@override final  String? lastOrderId;
@override final  DateTime? lastCheckoutTimestamp;
// Seller flag (details in seller_profiles/{uid})
@override@JsonKey() final  bool isSeller;
// Account status
@override@JsonKey() final  bool suspended;
@override final  DateTime? suspendedAt;
@override final  DateTime? updatedAt;
// Payment provider
@override final  String? paymentProvider;
// Suspension details
@override final  DateTime? unsuspendedAt;
@override final  String? suspendedBy;
@override final  String? suspensionReason;
// Tax exemption for businesses
 final  Map<String, dynamic>? _taxExemption;
// Tax exemption for businesses
@override Map<String, dynamic>? get taxExemption {
  final value = _taxExemption;
  if (value == null) return null;
  if (_taxExemption is EqualUnmodifiableMapView) return _taxExemption;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

// MFA status (secrets live in user_security — backend only)
@override@JsonKey() final  bool mfaEnabled;
@override final  DateTime? mfaEnrolledAt;
@override final  DateTime? lastMfaVerify;
// === CONSENT & COMPLIANCE (CASL + PIPEDA + Quebec Law 25) ===
@override@JsonKey() final  bool emailConsent;
@override@JsonKey() final  bool marketingOptIn;
@override final  DateTime? consentTimestamp;
@override final  String? consentMethod;
@override final  DateTime? privacyAcceptedAt;
@override final  DateTime? termsAcceptedAt;
@override final  String? privacyPolicyVersion;
@override final  String? termsVersion;
@override@JsonKey() final  String preferredLanguage;
@override final  DateTime? unsubscribedAt;
@override@JsonKey() final  bool dataProcessingConsent;
// === PREMIUM SUBSCRIPTION ===
@override@JsonKey() final  bool isPremium;
@override final  DateTime? premiumSince;
@override final  DateTime? premiumExpiresAt;
@override final  String? stripeSubscriptionId;
@override@JsonKey() final  bool notifyNewProducts;
@override@JsonKey() final  bool notifyTrending;
@override@JsonKey() final  bool pushEnabled;
// === FCM (push notifications) ===
@override final  String? fcmToken;
@override final  DateTime? fcmTokenUpdatedAt;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.email, email) || other.email == email)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._roles, _roles)&&(identical(other.address, address) || other.address == address)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.lastCheckoutSession, lastCheckoutSession) || other.lastCheckoutSession == lastCheckoutSession)&&(identical(other.lastOrderId, lastOrderId) || other.lastOrderId == lastOrderId)&&(identical(other.lastCheckoutTimestamp, lastCheckoutTimestamp) || other.lastCheckoutTimestamp == lastCheckoutTimestamp)&&(identical(other.isSeller, isSeller) || other.isSeller == isSeller)&&(identical(other.suspended, suspended) || other.suspended == suspended)&&(identical(other.suspendedAt, suspendedAt) || other.suspendedAt == suspendedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.paymentProvider, paymentProvider) || other.paymentProvider == paymentProvider)&&(identical(other.unsuspendedAt, unsuspendedAt) || other.unsuspendedAt == unsuspendedAt)&&(identical(other.suspendedBy, suspendedBy) || other.suspendedBy == suspendedBy)&&(identical(other.suspensionReason, suspensionReason) || other.suspensionReason == suspensionReason)&&const DeepCollectionEquality().equals(other._taxExemption, _taxExemption)&&(identical(other.mfaEnabled, mfaEnabled) || other.mfaEnabled == mfaEnabled)&&(identical(other.mfaEnrolledAt, mfaEnrolledAt) || other.mfaEnrolledAt == mfaEnrolledAt)&&(identical(other.lastMfaVerify, lastMfaVerify) || other.lastMfaVerify == lastMfaVerify)&&(identical(other.emailConsent, emailConsent) || other.emailConsent == emailConsent)&&(identical(other.marketingOptIn, marketingOptIn) || other.marketingOptIn == marketingOptIn)&&(identical(other.consentTimestamp, consentTimestamp) || other.consentTimestamp == consentTimestamp)&&(identical(other.consentMethod, consentMethod) || other.consentMethod == consentMethod)&&(identical(other.privacyAcceptedAt, privacyAcceptedAt) || other.privacyAcceptedAt == privacyAcceptedAt)&&(identical(other.termsAcceptedAt, termsAcceptedAt) || other.termsAcceptedAt == termsAcceptedAt)&&(identical(other.privacyPolicyVersion, privacyPolicyVersion) || other.privacyPolicyVersion == privacyPolicyVersion)&&(identical(other.termsVersion, termsVersion) || other.termsVersion == termsVersion)&&(identical(other.preferredLanguage, preferredLanguage) || other.preferredLanguage == preferredLanguage)&&(identical(other.unsubscribedAt, unsubscribedAt) || other.unsubscribedAt == unsubscribedAt)&&(identical(other.dataProcessingConsent, dataProcessingConsent) || other.dataProcessingConsent == dataProcessingConsent)&&(identical(other.isPremium, isPremium) || other.isPremium == isPremium)&&(identical(other.premiumSince, premiumSince) || other.premiumSince == premiumSince)&&(identical(other.premiumExpiresAt, premiumExpiresAt) || other.premiumExpiresAt == premiumExpiresAt)&&(identical(other.stripeSubscriptionId, stripeSubscriptionId) || other.stripeSubscriptionId == stripeSubscriptionId)&&(identical(other.notifyNewProducts, notifyNewProducts) || other.notifyNewProducts == notifyNewProducts)&&(identical(other.notifyTrending, notifyTrending) || other.notifyTrending == notifyTrending)&&(identical(other.pushEnabled, pushEnabled) || other.pushEnabled == pushEnabled)&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken)&&(identical(other.fcmTokenUpdatedAt, fcmTokenUpdatedAt) || other.fcmTokenUpdatedAt == fcmTokenUpdatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,uid,email,name,const DeepCollectionEquality().hash(_roles),address,createdAt,customerId,lastCheckoutSession,lastOrderId,lastCheckoutTimestamp,isSeller,suspended,suspendedAt,updatedAt,paymentProvider,unsuspendedAt,suspendedBy,suspensionReason,const DeepCollectionEquality().hash(_taxExemption),mfaEnabled,mfaEnrolledAt,lastMfaVerify,emailConsent,marketingOptIn,consentTimestamp,consentMethod,privacyAcceptedAt,termsAcceptedAt,privacyPolicyVersion,termsVersion,preferredLanguage,unsubscribedAt,dataProcessingConsent,isPremium,premiumSince,premiumExpiresAt,stripeSubscriptionId,notifyNewProducts,notifyTrending,pushEnabled,fcmToken,fcmTokenUpdatedAt]);

@override
String toString() {
  return 'User(uid: $uid, email: $email, name: $name, roles: $roles, address: $address, createdAt: $createdAt, customerId: $customerId, lastCheckoutSession: $lastCheckoutSession, lastOrderId: $lastOrderId, lastCheckoutTimestamp: $lastCheckoutTimestamp, isSeller: $isSeller, suspended: $suspended, suspendedAt: $suspendedAt, updatedAt: $updatedAt, paymentProvider: $paymentProvider, unsuspendedAt: $unsuspendedAt, suspendedBy: $suspendedBy, suspensionReason: $suspensionReason, taxExemption: $taxExemption, mfaEnabled: $mfaEnabled, mfaEnrolledAt: $mfaEnrolledAt, lastMfaVerify: $lastMfaVerify, emailConsent: $emailConsent, marketingOptIn: $marketingOptIn, consentTimestamp: $consentTimestamp, consentMethod: $consentMethod, privacyAcceptedAt: $privacyAcceptedAt, termsAcceptedAt: $termsAcceptedAt, privacyPolicyVersion: $privacyPolicyVersion, termsVersion: $termsVersion, preferredLanguage: $preferredLanguage, unsubscribedAt: $unsubscribedAt, dataProcessingConsent: $dataProcessingConsent, isPremium: $isPremium, premiumSince: $premiumSince, premiumExpiresAt: $premiumExpiresAt, stripeSubscriptionId: $stripeSubscriptionId, notifyNewProducts: $notifyNewProducts, notifyTrending: $notifyTrending, pushEnabled: $pushEnabled, fcmToken: $fcmToken, fcmTokenUpdatedAt: $fcmTokenUpdatedAt)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
 String uid, String email, String name, List<UserRole> roles, Address? address, DateTime createdAt, String? customerId, String? lastCheckoutSession, String? lastOrderId, DateTime? lastCheckoutTimestamp, bool isSeller, bool suspended, DateTime? suspendedAt, DateTime? updatedAt, String? paymentProvider, DateTime? unsuspendedAt, String? suspendedBy, String? suspensionReason, Map<String, dynamic>? taxExemption, bool mfaEnabled, DateTime? mfaEnrolledAt, DateTime? lastMfaVerify, bool emailConsent, bool marketingOptIn, DateTime? consentTimestamp, String? consentMethod, DateTime? privacyAcceptedAt, DateTime? termsAcceptedAt, String? privacyPolicyVersion, String? termsVersion, String preferredLanguage, DateTime? unsubscribedAt, bool dataProcessingConsent, bool isPremium, DateTime? premiumSince, DateTime? premiumExpiresAt, String? stripeSubscriptionId, bool notifyNewProducts, bool notifyTrending, bool pushEnabled, String? fcmToken, DateTime? fcmTokenUpdatedAt
});


@override $AddressCopyWith<$Res>? get address;

}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? email = null,Object? name = null,Object? roles = null,Object? address = freezed,Object? createdAt = null,Object? customerId = freezed,Object? lastCheckoutSession = freezed,Object? lastOrderId = freezed,Object? lastCheckoutTimestamp = freezed,Object? isSeller = null,Object? suspended = null,Object? suspendedAt = freezed,Object? updatedAt = freezed,Object? paymentProvider = freezed,Object? unsuspendedAt = freezed,Object? suspendedBy = freezed,Object? suspensionReason = freezed,Object? taxExemption = freezed,Object? mfaEnabled = null,Object? mfaEnrolledAt = freezed,Object? lastMfaVerify = freezed,Object? emailConsent = null,Object? marketingOptIn = null,Object? consentTimestamp = freezed,Object? consentMethod = freezed,Object? privacyAcceptedAt = freezed,Object? termsAcceptedAt = freezed,Object? privacyPolicyVersion = freezed,Object? termsVersion = freezed,Object? preferredLanguage = null,Object? unsubscribedAt = freezed,Object? dataProcessingConsent = null,Object? isPremium = null,Object? premiumSince = freezed,Object? premiumExpiresAt = freezed,Object? stripeSubscriptionId = freezed,Object? notifyNewProducts = null,Object? notifyTrending = null,Object? pushEnabled = null,Object? fcmToken = freezed,Object? fcmTokenUpdatedAt = freezed,}) {
  return _then(_User(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self._roles : roles // ignore: cast_nullable_to_non_nullable
as List<UserRole>,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,lastCheckoutSession: freezed == lastCheckoutSession ? _self.lastCheckoutSession : lastCheckoutSession // ignore: cast_nullable_to_non_nullable
as String?,lastOrderId: freezed == lastOrderId ? _self.lastOrderId : lastOrderId // ignore: cast_nullable_to_non_nullable
as String?,lastCheckoutTimestamp: freezed == lastCheckoutTimestamp ? _self.lastCheckoutTimestamp : lastCheckoutTimestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,isSeller: null == isSeller ? _self.isSeller : isSeller // ignore: cast_nullable_to_non_nullable
as bool,suspended: null == suspended ? _self.suspended : suspended // ignore: cast_nullable_to_non_nullable
as bool,suspendedAt: freezed == suspendedAt ? _self.suspendedAt : suspendedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,paymentProvider: freezed == paymentProvider ? _self.paymentProvider : paymentProvider // ignore: cast_nullable_to_non_nullable
as String?,unsuspendedAt: freezed == unsuspendedAt ? _self.unsuspendedAt : unsuspendedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,suspendedBy: freezed == suspendedBy ? _self.suspendedBy : suspendedBy // ignore: cast_nullable_to_non_nullable
as String?,suspensionReason: freezed == suspensionReason ? _self.suspensionReason : suspensionReason // ignore: cast_nullable_to_non_nullable
as String?,taxExemption: freezed == taxExemption ? _self._taxExemption : taxExemption // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,mfaEnabled: null == mfaEnabled ? _self.mfaEnabled : mfaEnabled // ignore: cast_nullable_to_non_nullable
as bool,mfaEnrolledAt: freezed == mfaEnrolledAt ? _self.mfaEnrolledAt : mfaEnrolledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMfaVerify: freezed == lastMfaVerify ? _self.lastMfaVerify : lastMfaVerify // ignore: cast_nullable_to_non_nullable
as DateTime?,emailConsent: null == emailConsent ? _self.emailConsent : emailConsent // ignore: cast_nullable_to_non_nullable
as bool,marketingOptIn: null == marketingOptIn ? _self.marketingOptIn : marketingOptIn // ignore: cast_nullable_to_non_nullable
as bool,consentTimestamp: freezed == consentTimestamp ? _self.consentTimestamp : consentTimestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,consentMethod: freezed == consentMethod ? _self.consentMethod : consentMethod // ignore: cast_nullable_to_non_nullable
as String?,privacyAcceptedAt: freezed == privacyAcceptedAt ? _self.privacyAcceptedAt : privacyAcceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,termsAcceptedAt: freezed == termsAcceptedAt ? _self.termsAcceptedAt : termsAcceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,privacyPolicyVersion: freezed == privacyPolicyVersion ? _self.privacyPolicyVersion : privacyPolicyVersion // ignore: cast_nullable_to_non_nullable
as String?,termsVersion: freezed == termsVersion ? _self.termsVersion : termsVersion // ignore: cast_nullable_to_non_nullable
as String?,preferredLanguage: null == preferredLanguage ? _self.preferredLanguage : preferredLanguage // ignore: cast_nullable_to_non_nullable
as String,unsubscribedAt: freezed == unsubscribedAt ? _self.unsubscribedAt : unsubscribedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dataProcessingConsent: null == dataProcessingConsent ? _self.dataProcessingConsent : dataProcessingConsent // ignore: cast_nullable_to_non_nullable
as bool,isPremium: null == isPremium ? _self.isPremium : isPremium // ignore: cast_nullable_to_non_nullable
as bool,premiumSince: freezed == premiumSince ? _self.premiumSince : premiumSince // ignore: cast_nullable_to_non_nullable
as DateTime?,premiumExpiresAt: freezed == premiumExpiresAt ? _self.premiumExpiresAt : premiumExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,stripeSubscriptionId: freezed == stripeSubscriptionId ? _self.stripeSubscriptionId : stripeSubscriptionId // ignore: cast_nullable_to_non_nullable
as String?,notifyNewProducts: null == notifyNewProducts ? _self.notifyNewProducts : notifyNewProducts // ignore: cast_nullable_to_non_nullable
as bool,notifyTrending: null == notifyTrending ? _self.notifyTrending : notifyTrending // ignore: cast_nullable_to_non_nullable
as bool,pushEnabled: null == pushEnabled ? _self.pushEnabled : pushEnabled // ignore: cast_nullable_to_non_nullable
as bool,fcmToken: freezed == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String?,fcmTokenUpdatedAt: freezed == fcmTokenUpdatedAt ? _self.fcmTokenUpdatedAt : fcmTokenUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get address {
    if (_self.address == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.address!, (value) {
    return _then(_self.copyWith(address: value));
  });
}
}


/// @nodoc
mixin _$UserCreate {

 String get email; String get name; List<UserRole> get roles; Address? get address;
/// Create a copy of UserCreate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCreateCopyWith<UserCreate> get copyWith => _$UserCreateCopyWithImpl<UserCreate>(this as UserCreate, _$identity);

  /// Serializes this UserCreate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserCreate&&(identical(other.email, email) || other.email == email)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.roles, roles)&&(identical(other.address, address) || other.address == address));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,email,name,const DeepCollectionEquality().hash(roles),address);

@override
String toString() {
  return 'UserCreate(email: $email, name: $name, roles: $roles, address: $address)';
}


}

/// @nodoc
abstract mixin class $UserCreateCopyWith<$Res>  {
  factory $UserCreateCopyWith(UserCreate value, $Res Function(UserCreate) _then) = _$UserCreateCopyWithImpl;
@useResult
$Res call({
 String email, String name, List<UserRole> roles, Address? address
});


$AddressCopyWith<$Res>? get address;

}
/// @nodoc
class _$UserCreateCopyWithImpl<$Res>
    implements $UserCreateCopyWith<$Res> {
  _$UserCreateCopyWithImpl(this._self, this._then);

  final UserCreate _self;
  final $Res Function(UserCreate) _then;

/// Create a copy of UserCreate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? email = null,Object? name = null,Object? roles = null,Object? address = freezed,}) {
  return _then(_self.copyWith(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self.roles : roles // ignore: cast_nullable_to_non_nullable
as List<UserRole>,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,
  ));
}
/// Create a copy of UserCreate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get address {
    if (_self.address == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.address!, (value) {
    return _then(_self.copyWith(address: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserCreate].
extension UserCreatePatterns on UserCreate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserCreate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserCreate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserCreate value)  $default,){
final _that = this;
switch (_that) {
case _UserCreate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserCreate value)?  $default,){
final _that = this;
switch (_that) {
case _UserCreate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String email,  String name,  List<UserRole> roles,  Address? address)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserCreate() when $default != null:
return $default(_that.email,_that.name,_that.roles,_that.address);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String email,  String name,  List<UserRole> roles,  Address? address)  $default,) {final _that = this;
switch (_that) {
case _UserCreate():
return $default(_that.email,_that.name,_that.roles,_that.address);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String email,  String name,  List<UserRole> roles,  Address? address)?  $default,) {final _that = this;
switch (_that) {
case _UserCreate() when $default != null:
return $default(_that.email,_that.name,_that.roles,_that.address);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserCreate implements UserCreate {
  const _UserCreate({required this.email, required this.name, final  List<UserRole> roles = const [UserRole.buyer], this.address}): _roles = roles;
  factory _UserCreate.fromJson(Map<String, dynamic> json) => _$UserCreateFromJson(json);

@override final  String email;
@override final  String name;
 final  List<UserRole> _roles;
@override@JsonKey() List<UserRole> get roles {
  if (_roles is EqualUnmodifiableListView) return _roles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roles);
}

@override final  Address? address;

/// Create a copy of UserCreate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCreateCopyWith<_UserCreate> get copyWith => __$UserCreateCopyWithImpl<_UserCreate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserCreateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserCreate&&(identical(other.email, email) || other.email == email)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._roles, _roles)&&(identical(other.address, address) || other.address == address));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,email,name,const DeepCollectionEquality().hash(_roles),address);

@override
String toString() {
  return 'UserCreate(email: $email, name: $name, roles: $roles, address: $address)';
}


}

/// @nodoc
abstract mixin class _$UserCreateCopyWith<$Res> implements $UserCreateCopyWith<$Res> {
  factory _$UserCreateCopyWith(_UserCreate value, $Res Function(_UserCreate) _then) = __$UserCreateCopyWithImpl;
@override @useResult
$Res call({
 String email, String name, List<UserRole> roles, Address? address
});


@override $AddressCopyWith<$Res>? get address;

}
/// @nodoc
class __$UserCreateCopyWithImpl<$Res>
    implements _$UserCreateCopyWith<$Res> {
  __$UserCreateCopyWithImpl(this._self, this._then);

  final _UserCreate _self;
  final $Res Function(_UserCreate) _then;

/// Create a copy of UserCreate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? email = null,Object? name = null,Object? roles = null,Object? address = freezed,}) {
  return _then(_UserCreate(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self._roles : roles // ignore: cast_nullable_to_non_nullable
as List<UserRole>,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,
  ));
}

/// Create a copy of UserCreate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get address {
    if (_self.address == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.address!, (value) {
    return _then(_self.copyWith(address: value));
  });
}
}

// dart format on
