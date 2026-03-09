import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'return_request_models.freezed.dart';
part 'return_request_models.g.dart';

@Freezed(toJson: true, fromJson: true)
abstract class ReturnRequest with _$ReturnRequest {
  const factory ReturnRequest({
    required String returnId,
    required String orderId,
    required String orderItemId,
    required String buyerId,
    required String sellerId,
    required String productId,
    required String productName,
    @Default(1) int quantity,
    @Default('requested') String returnStatus,
    required String returnReason,
    String? returnAdminNote,
    String? returnTrackingNumber,
    int? returnRefundAmountCents,
    DateTime? requestedAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    DateTime? escalatedAt,
    String? escalationReason,
  }) = _ReturnRequest;

  factory ReturnRequest.fromJson(Map<String, dynamic> json) =>
      _$ReturnRequestFromJson(json);

  factory ReturnRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReturnRequest(
      returnId: doc.id,
      orderId: data['orderId'] as String? ?? '',
      // Backend writes 'cartItemId' (Fields.CART_ITEM_ID); fall back to 'orderItemId' for compat
      orderItemId: (data['cartItemId'] ?? data['orderItemId']) as String? ?? '',
      buyerId: data['buyerId'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      returnStatus: data['returnStatus'] as String? ?? 'requested',
      returnReason: data['returnReason'] as String? ?? '',
      returnAdminNote: data['returnAdminNote'] as String?,
      returnTrackingNumber: data['returnTrackingNumber'] as String?,
      returnRefundAmountCents:
          (data['returnRefundAmountCents'] as num?)?.toInt(),
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      escalatedAt: (data['escalatedAt'] as Timestamp?)?.toDate(),
      escalationReason: data['escalationReason'] as String?,
    );
  }
}
