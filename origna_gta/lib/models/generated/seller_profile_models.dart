// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from Pydantic models - Single source of truth
// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/schema/schema_constants.dart';
import 'base_models.dart';

part 'seller_profile_models.freezed.dart';
part 'seller_profile_models.g.dart';

/// Safely parse a dynamic value (Timestamp, String, DateTime) to DateTime?
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

// ============================================================================
// SELLER PROFILE MODEL — lives in seller_profiles/{uid}
// Split from users doc so buyers don't load null seller fields.
// ============================================================================

@Freezed(toJson: true, fromJson: true)
abstract class SellerProfile with _$SellerProfile {
  const factory SellerProfile({
    // Stripe Connect
    String? stripeAccountId,
    @Default(false) bool payoutsEnabled,
    @Default(false) bool chargesEnabled,
    @Default(false) bool onboardingCompleted,
    List<String>? pendingRequirements,

    // Commission (basis points — 250 = 2.50%)
    @Default(250) int commissionRateBps,

    // Seller stats
    @Default(0.0) double avgRating,
    @Default(0) int totalReviews,
    @Default(0) int totalSales,

    // Warehouse references
    List<String>? warehouseIds,

    // Business info
    String? businessName,
    Address? businessAddress,

    // Returns policy
    @Default(true) bool acceptsReturns,
    @Default(30) int returnWindowDays,

    // Verification
    @Default(false) bool verified,
    String? verificationStatus,
    String? platform,
    int? payoutHoldDays,

    // Payment
    String? bankAccountLast4,

    // Timestamps
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _SellerProfile;

  factory SellerProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    Address? businessAddr;
    final rawAddr = data[Fields.businessAddress];
    if (rawAddr is Map<String, dynamic>) {
      businessAddr = Address.fromJson(rawAddr);
    }
    return SellerProfile(
      stripeAccountId: data[Fields.stripeAccountId] as String?,
      payoutsEnabled: data[Fields.payoutsEnabled] ?? false,
      chargesEnabled: data[Fields.chargesEnabled] ?? false,
      onboardingCompleted: data[Fields.onboardingCompleted] ?? false,
      pendingRequirements: (data[Fields.pendingRequirements] as List?)?.cast<String>(),
      commissionRateBps: (data[Fields.commissionRateBps] as num?)?.toInt() ?? 250,
      avgRating: (data[Fields.avgRating] as num?)?.toDouble() ?? 0.0,
      totalReviews: (data[Fields.totalReviews] as num?)?.toInt() ?? 0,
      totalSales: (data[Fields.totalSales] as num?)?.toInt() ?? 0,
      warehouseIds: (data[Fields.warehouseIds] as List?)?.cast<String>(),
      businessName: data[Fields.businessName] as String?,
      businessAddress: businessAddr,
      acceptsReturns: data[Fields.acceptsReturns] ?? true,
      returnWindowDays: (data[Fields.returnWindowDaysField] as num?)?.toInt() ?? 30,
      verified: data[Fields.verified] ?? false,
      verificationStatus: data[Fields.verificationStatus] as String?,
      platform: data[Fields.platform] as String?,
      payoutHoldDays: (data[Fields.payoutHoldDays] as num?)?.toInt(),
      bankAccountLast4: data[Fields.bankAccountLast4] as String?,
      createdAt: _parseDateTime(data[Fields.createdAt]),
      updatedAt: _parseDateTime(data[Fields.updatedAt]),
    );
  }

  factory SellerProfile.fromJson(Map<String, dynamic> json) =>
      _$SellerProfileFromJson(json);
}
