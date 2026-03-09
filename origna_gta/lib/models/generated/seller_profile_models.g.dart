// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seller_profile_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SellerProfile _$SellerProfileFromJson(Map<String, dynamic> json) =>
    _SellerProfile(
      stripeAccountId: json['stripeAccountId'] as String?,
      payoutsEnabled: json['payoutsEnabled'] as bool? ?? false,
      chargesEnabled: json['chargesEnabled'] as bool? ?? false,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      pendingRequirements: (json['pendingRequirements'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      commissionRateBps: (json['commissionRateBps'] as num?)?.toInt() ?? 250,
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      totalSales: (json['totalSales'] as num?)?.toInt() ?? 0,
      warehouseIds: (json['warehouseIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      businessName: json['businessName'] as String?,
      businessAddress: json['businessAddress'] == null
          ? null
          : Address.fromJson(json['businessAddress'] as Map<String, dynamic>),
      acceptsReturns: json['acceptsReturns'] as bool? ?? true,
      returnWindowDays: (json['returnWindowDays'] as num?)?.toInt() ?? 30,
      verified: json['verified'] as bool? ?? false,
      verificationStatus: json['verificationStatus'] as String?,
      platform: json['platform'] as String?,
      payoutHoldDays: (json['payoutHoldDays'] as num?)?.toInt(),
      bankAccountLast4: json['bankAccountLast4'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$SellerProfileToJson(_SellerProfile instance) =>
    <String, dynamic>{
      'stripeAccountId': instance.stripeAccountId,
      'payoutsEnabled': instance.payoutsEnabled,
      'chargesEnabled': instance.chargesEnabled,
      'onboardingCompleted': instance.onboardingCompleted,
      'pendingRequirements': instance.pendingRequirements,
      'commissionRateBps': instance.commissionRateBps,
      'avgRating': instance.avgRating,
      'totalReviews': instance.totalReviews,
      'totalSales': instance.totalSales,
      'warehouseIds': instance.warehouseIds,
      'businessName': instance.businessName,
      'businessAddress': instance.businessAddress,
      'acceptsReturns': instance.acceptsReturns,
      'returnWindowDays': instance.returnWindowDays,
      'verified': instance.verified,
      'verificationStatus': instance.verificationStatus,
      'platform': instance.platform,
      'payoutHoldDays': instance.payoutHoldDays,
      'bankAccountLast4': instance.bankAccountLast4,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
