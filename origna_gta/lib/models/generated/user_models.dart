// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from Pydantic models - Single source of truth
// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'base_models.dart';
import '../../core/schema/schema_constants.dart';

part 'user_models.freezed.dart';
part 'user_models.g.dart';

/// Safely parse a dynamic value (Timestamp, String, DateTime) to DateTime?
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Safely convert dynamic value to `Map<String, dynamic>`
Map<String, dynamic> _safeMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

// ============================================================================
// USER MODEL
// ============================================================================

@freezed
abstract class User with _$User {
  const factory User({
    required String uid,
    required String email,
    required String name,
    required List<UserRole> roles,
    Address? address,
    required DateTime createdAt,
    // Stripe buyer information
    String? customerId,
    String? lastCheckoutSession,
    String? lastOrderId,
    DateTime? lastCheckoutTimestamp,
    // Seller flag (details in seller_profiles/{uid})
    @Default(false) bool isSeller,
    // Account status
    @Default(false) bool suspended,
    DateTime? suspendedAt,
    DateTime? updatedAt,
    // Payment provider
    String? paymentProvider,
    // Suspension details
    DateTime? unsuspendedAt,
    String? suspendedBy,
    String? suspensionReason,
    // Tax exemption for businesses
    Map<String, dynamic>? taxExemption,
    // MFA status (secrets live in user_security — backend only)
    @Default(false) bool mfaEnabled,
    DateTime? mfaEnrolledAt,
    DateTime? lastMfaVerify,
    // === CONSENT & COMPLIANCE (CASL + PIPEDA + Quebec Law 25) ===
    @Default(true) bool emailConsent,
    @Default(false) bool marketingOptIn,
    DateTime? consentTimestamp,
    String? consentMethod,
    DateTime? privacyAcceptedAt,
    DateTime? termsAcceptedAt,
    String? privacyPolicyVersion,
    String? termsVersion,
    @Default('en') String preferredLanguage,
    DateTime? unsubscribedAt,
    @Default(false) bool dataProcessingConsent,
    // === PREMIUM SUBSCRIPTION ===
    @Default(false) bool isPremium,
    DateTime? premiumSince,
    DateTime? premiumExpiresAt,
    String? stripeSubscriptionId,
    @Default(false) bool notifyNewProducts,
    @Default(false) bool notifyTrending,
    @Default(true) bool pushEnabled,
    // === FCM (push notifications) ===
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
  }) = _User;

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse roles
    final rolesData = data[Fields.roles] as List<dynamic>? ?? [UserRoleValues.buyer];
    final roles = rolesData.map((r) => UserRole.values.firstWhere((e) => e.name == r.toString(), orElse: () => UserRole.buyer)).toList();

    return User(
      uid: data[Fields.uid] ?? doc.id,
      email: data[Fields.email] ?? '',
      name: data[Fields.name] ?? '',
      roles: roles,
      address: data[Fields.address] != null ? Address.fromJson(data[Fields.address] as Map<String, dynamic>) : null,
      createdAt: _parseDateTime(data[Fields.createdAt]) ?? DateTime.now(),
      customerId: data[Fields.customerId],
      lastCheckoutSession: data[Fields.lastCheckoutSession],
      lastOrderId: data[Fields.lastOrderId],
      lastCheckoutTimestamp: _parseDateTime(data[Fields.lastCheckoutTimestamp]),
      isSeller: (data[Fields.roles] as List<dynamic>? ?? []).contains(UserRoleValues.seller),
      suspended: data[Fields.suspended] ?? false,
      suspendedAt: _parseDateTime(data[Fields.suspendedAt]),
      updatedAt: _parseDateTime(data[Fields.updatedAt]),
      paymentProvider: data[Fields.paymentProvider] as String?,
      unsuspendedAt: _parseDateTime(data[Fields.unsuspendedAt]),
      suspendedBy: data[Fields.suspendedBy] as String?,
      suspensionReason: data[Fields.suspensionReason] as String?,
      taxExemption: data[Fields.taxExemption] != null ? _safeMap(data[Fields.taxExemption]) : null,
      // MFA status (secrets live in user_security — backend only)
      mfaEnabled: data[Fields.mfaEnabled] ?? false,
      mfaEnrolledAt: _parseDateTime(data[Fields.mfaEnrolledAt]),
      lastMfaVerify: _parseDateTime(data[Fields.lastMfaVerify]),
      // === CONSENT & COMPLIANCE ===
      emailConsent: data[Fields.emailConsent] ?? true,
      marketingOptIn: data[Fields.marketingOptIn] ?? false,
      consentTimestamp: _parseDateTime(data[Fields.consentTimestamp]),
      consentMethod: data[Fields.consentMethod] as String?,
      privacyAcceptedAt: _parseDateTime(data[Fields.privacyAcceptedAt]),
      termsAcceptedAt: _parseDateTime(data[Fields.termsAcceptedAt]),
      privacyPolicyVersion: data[Fields.privacyPolicyVersion] as String?,
      termsVersion: data[Fields.termsVersion] as String?,
      preferredLanguage: data[Fields.preferredLanguage] as String? ?? LanguageValues.english,
      unsubscribedAt: _parseDateTime(data[Fields.unsubscribedAt]),
      dataProcessingConsent: data[Fields.dataProcessingConsent] ?? false,
      // === PREMIUM SUBSCRIPTION ===
      isPremium: data[Fields.isPremium] ?? false,
      premiumSince: _parseDateTime(data[Fields.premiumSince]),
      premiumExpiresAt: _parseDateTime(data[Fields.premiumExpiresAt]),
      stripeSubscriptionId: data[Fields.stripeSubscriptionId] as String?,
      notifyNewProducts: data[Fields.notifyNewProducts] ?? false,
      notifyTrending: data[Fields.notifyTrending] ?? false,
      pushEnabled: data[Fields.pushEnabled] ?? true,
      fcmToken: data[Fields.fcmToken] as String?,
      fcmTokenUpdatedAt: _parseDateTime(data[Fields.fcmTokenUpdatedAt]),
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  const User._();

  /// Check if user can sell products (seller/admin + not suspended). Full check requires seller_profiles doc.
  bool get canSell => (isAdmin || isSeller) && !suspended;

  /// Check if user has admin role
  bool get isAdmin => roles.contains(UserRole.admin);
}

// ============================================================================
// USER CREATE MODEL
// ============================================================================

@freezed
abstract class UserCreate with _$UserCreate {
  const factory UserCreate({required String email, required String name, @Default([UserRole.buyer]) List<UserRole> roles, Address? address}) = _UserCreate;

  factory UserCreate.fromJson(Map<String, dynamic> json) => _$UserCreateFromJson(json);
}
