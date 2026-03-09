// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'return_request_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReturnRequest _$ReturnRequestFromJson(Map<String, dynamic> json) =>
    _ReturnRequest(
      returnId: json['returnId'] as String,
      orderId: json['orderId'] as String,
      orderItemId: json['orderItemId'] as String,
      buyerId: json['buyerId'] as String,
      sellerId: json['sellerId'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      returnStatus: json['returnStatus'] as String? ?? 'requested',
      returnReason: json['returnReason'] as String,
      returnAdminNote: json['returnAdminNote'] as String?,
      returnTrackingNumber: json['returnTrackingNumber'] as String?,
      returnRefundAmountCents: (json['returnRefundAmountCents'] as num?)
          ?.toInt(),
      requestedAt: json['requestedAt'] == null
          ? null
          : DateTime.parse(json['requestedAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse(json['resolvedAt'] as String),
      escalatedAt: json['escalatedAt'] == null
          ? null
          : DateTime.parse(json['escalatedAt'] as String),
      escalationReason: json['escalationReason'] as String?,
    );

Map<String, dynamic> _$ReturnRequestToJson(_ReturnRequest instance) =>
    <String, dynamic>{
      'returnId': instance.returnId,
      'orderId': instance.orderId,
      'orderItemId': instance.orderItemId,
      'buyerId': instance.buyerId,
      'sellerId': instance.sellerId,
      'productId': instance.productId,
      'productName': instance.productName,
      'quantity': instance.quantity,
      'returnStatus': instance.returnStatus,
      'returnReason': instance.returnReason,
      'returnAdminNote': instance.returnAdminNote,
      'returnTrackingNumber': instance.returnTrackingNumber,
      'returnRefundAmountCents': instance.returnRefundAmountCents,
      'requestedAt': instance.requestedAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'resolvedAt': instance.resolvedAt?.toIso8601String(),
      'escalatedAt': instance.escalatedAt?.toIso8601String(),
      'escalationReason': instance.escalationReason,
    };
