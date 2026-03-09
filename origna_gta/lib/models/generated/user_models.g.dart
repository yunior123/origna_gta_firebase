// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  uid: json['uid'] as String,
  email: json['email'] as String,
  name: json['name'] as String,
  roles: (json['roles'] as List<dynamic>)
      .map((e) => $enumDecode(_$UserRoleEnumMap, e))
      .toList(),
  address: json['address'] == null
      ? null
      : Address.fromJson(json['address'] as Map<String, dynamic>),
  createdAt: DateTime.parse(json['createdAt'] as String),
  customerId: json['customerId'] as String?,
  lastCheckoutSession: json['lastCheckoutSession'] as String?,
  lastOrderId: json['lastOrderId'] as String?,
  lastCheckoutTimestamp: json['lastCheckoutTimestamp'] == null
      ? null
      : DateTime.parse(json['lastCheckoutTimestamp'] as String),
  isSeller: json['isSeller'] as bool? ?? false,
  suspended: json['suspended'] as bool? ?? false,
  suspendedAt: json['suspendedAt'] == null
      ? null
      : DateTime.parse(json['suspendedAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  paymentProvider: json['paymentProvider'] as String?,
  unsuspendedAt: json['unsuspendedAt'] == null
      ? null
      : DateTime.parse(json['unsuspendedAt'] as String),
  suspendedBy: json['suspendedBy'] as String?,
  suspensionReason: json['suspensionReason'] as String?,
  taxExemption: json['taxExemption'] as Map<String, dynamic>?,
  mfaEnabled: json['mfaEnabled'] as bool? ?? false,
  mfaEnrolledAt: json['mfaEnrolledAt'] == null
      ? null
      : DateTime.parse(json['mfaEnrolledAt'] as String),
  lastMfaVerify: json['lastMfaVerify'] == null
      ? null
      : DateTime.parse(json['lastMfaVerify'] as String),
  emailConsent: json['emailConsent'] as bool? ?? true,
  marketingOptIn: json['marketingOptIn'] as bool? ?? false,
  consentTimestamp: json['consentTimestamp'] == null
      ? null
      : DateTime.parse(json['consentTimestamp'] as String),
  consentMethod: json['consentMethod'] as String?,
  privacyAcceptedAt: json['privacyAcceptedAt'] == null
      ? null
      : DateTime.parse(json['privacyAcceptedAt'] as String),
  termsAcceptedAt: json['termsAcceptedAt'] == null
      ? null
      : DateTime.parse(json['termsAcceptedAt'] as String),
  privacyPolicyVersion: json['privacyPolicyVersion'] as String?,
  termsVersion: json['termsVersion'] as String?,
  preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
  unsubscribedAt: json['unsubscribedAt'] == null
      ? null
      : DateTime.parse(json['unsubscribedAt'] as String),
  dataProcessingConsent: json['dataProcessingConsent'] as bool? ?? false,
  isPremium: json['isPremium'] as bool? ?? false,
  premiumSince: json['premiumSince'] == null
      ? null
      : DateTime.parse(json['premiumSince'] as String),
  premiumExpiresAt: json['premiumExpiresAt'] == null
      ? null
      : DateTime.parse(json['premiumExpiresAt'] as String),
  stripeSubscriptionId: json['stripeSubscriptionId'] as String?,
  notifyNewProducts: json['notifyNewProducts'] as bool? ?? false,
  notifyTrending: json['notifyTrending'] as bool? ?? false,
  pushEnabled: json['pushEnabled'] as bool? ?? true,
  fcmToken: json['fcmToken'] as String?,
  fcmTokenUpdatedAt: json['fcmTokenUpdatedAt'] == null
      ? null
      : DateTime.parse(json['fcmTokenUpdatedAt'] as String),
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'uid': instance.uid,
  'email': instance.email,
  'name': instance.name,
  'roles': instance.roles.map((e) => _$UserRoleEnumMap[e]!).toList(),
  'address': instance.address,
  'createdAt': instance.createdAt.toIso8601String(),
  'customerId': instance.customerId,
  'lastCheckoutSession': instance.lastCheckoutSession,
  'lastOrderId': instance.lastOrderId,
  'lastCheckoutTimestamp': instance.lastCheckoutTimestamp?.toIso8601String(),
  'isSeller': instance.isSeller,
  'suspended': instance.suspended,
  'suspendedAt': instance.suspendedAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'paymentProvider': instance.paymentProvider,
  'unsuspendedAt': instance.unsuspendedAt?.toIso8601String(),
  'suspendedBy': instance.suspendedBy,
  'suspensionReason': instance.suspensionReason,
  'taxExemption': instance.taxExemption,
  'mfaEnabled': instance.mfaEnabled,
  'mfaEnrolledAt': instance.mfaEnrolledAt?.toIso8601String(),
  'lastMfaVerify': instance.lastMfaVerify?.toIso8601String(),
  'emailConsent': instance.emailConsent,
  'marketingOptIn': instance.marketingOptIn,
  'consentTimestamp': instance.consentTimestamp?.toIso8601String(),
  'consentMethod': instance.consentMethod,
  'privacyAcceptedAt': instance.privacyAcceptedAt?.toIso8601String(),
  'termsAcceptedAt': instance.termsAcceptedAt?.toIso8601String(),
  'privacyPolicyVersion': instance.privacyPolicyVersion,
  'termsVersion': instance.termsVersion,
  'preferredLanguage': instance.preferredLanguage,
  'unsubscribedAt': instance.unsubscribedAt?.toIso8601String(),
  'dataProcessingConsent': instance.dataProcessingConsent,
  'isPremium': instance.isPremium,
  'premiumSince': instance.premiumSince?.toIso8601String(),
  'premiumExpiresAt': instance.premiumExpiresAt?.toIso8601String(),
  'stripeSubscriptionId': instance.stripeSubscriptionId,
  'notifyNewProducts': instance.notifyNewProducts,
  'notifyTrending': instance.notifyTrending,
  'pushEnabled': instance.pushEnabled,
  'fcmToken': instance.fcmToken,
  'fcmTokenUpdatedAt': instance.fcmTokenUpdatedAt?.toIso8601String(),
};

const _$UserRoleEnumMap = {
  UserRole.admin: 'admin',
  UserRole.seller: 'seller',
  UserRole.buyer: 'buyer',
};

_UserCreate _$UserCreateFromJson(Map<String, dynamic> json) => _UserCreate(
  email: json['email'] as String,
  name: json['name'] as String,
  roles:
      (json['roles'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$UserRoleEnumMap, e))
          .toList() ??
      const [UserRole.buyer],
  address: json['address'] == null
      ? null
      : Address.fromJson(json['address'] as Map<String, dynamic>),
);

Map<String, dynamic> _$UserCreateToJson(_UserCreate instance) =>
    <String, dynamic>{
      'email': instance.email,
      'name': instance.name,
      'roles': instance.roles.map((e) => _$UserRoleEnumMap[e]!).toList(),
      'address': instance.address,
    };
