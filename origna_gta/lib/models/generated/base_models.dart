// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from Pydantic models - Single source of truth
// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';

part 'base_models.freezed.dart';
part 'base_models.g.dart';

// ============================================================================
// ADDRESS MODELS
// ============================================================================

@freezed
abstract class Address with _$Address {
  const factory Address({
    required String street,
    @Default('') String apartment,
    required String city,
    required String state,
    required String postalCode,
    @Default('Canada') String country,
    String? phoneNumber,
    @Default(false) bool isDefault,
    String? addressId,
    String? label,
    double? latitude,
    double? longitude,
  }) = _Address;

  factory Address.fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);

  const Address._();

  /// Get formatted address with line breaks
  String get formattedAddress {
    final lines = [street, if (apartment.isNotEmpty) apartment, '$city, $state $postalCode', country];
    return lines.join('\n');
  }

  /// Get single-line address
  String get fullAddress {
    final parts = [street, if (apartment.isNotEmpty) apartment, city, state, postalCode, country];
    return parts.join(', ');
  }
}

@freezed
abstract class AddressDetails with _$AddressDetails {
  const factory AddressDetails({
    required String street,
    required String city,
    required String state,
    required String postalCode,
    required double latitude,
    required double longitude,
  }) = _AddressDetails;

  factory AddressDetails.fromJson(Map<String, dynamic> json) => _$AddressDetailsFromJson(json);
}

enum DeliveryStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('shipped')
  shipped,
  @JsonValue('delivered')
  delivered,
  @JsonValue('refunded')
  refunded,
}

// ============================================================================
// ENUMERATIONS
// ============================================================================

enum OrderStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('confirmed')
  confirmed,
  @JsonValue('processing')
  processing,
  @JsonValue('shipped')
  shipped,
  @JsonValue('in_transit')
  inTransit,
  @JsonValue('delivered')
  delivered,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('failed')
  failed,
  @JsonValue('expired')
  expired,
  @JsonValue('disputed')
  disputed,
  @JsonValue('refunded')
  refunded,
  @JsonValue('partially_refunded')
  partiallyRefunded,
}

enum PaymentStatus {
  @JsonValue('awaiting_payment')
  awaitingPayment,
  @JsonValue('processing')
  processing,
  @JsonValue('paid')
  paid,
  @JsonValue('authorized')
  authorized,
  @JsonValue('captured')
  captured,
  @JsonValue('payment_failed')
  paymentFailed,
  @JsonValue('refunded')
  refunded,
  @JsonValue('session_expired')
  sessionExpired,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('authorization_expired')
  authorizationExpired,
  @JsonValue('disputed')
  disputed,
  @JsonValue('capturing')
  capturing,
  @JsonValue('cancelling')
  cancelling,
  @JsonValue('expiring')
  expiring,
  @JsonValue('partially_refunded')
  partiallyRefunded,
  @JsonValue('voided')
  voided,
  @JsonValue('cancel_failed')
  cancelFailed,
}

enum ShippingApprovalStatus {
  @JsonValue('not_required')
  notRequired,
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}

enum UserRole {
  @JsonValue('admin')
  admin,
  @JsonValue('seller')
  seller,
  @JsonValue('buyer')
  buyer,
}
