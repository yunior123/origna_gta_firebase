// Extensions for Freezed enums — provides displayText, value, fromValue
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

// ============================================================================
// DELIVERY STATUS EXTENSIONS
// ============================================================================

extension DeliveryStatusExtension on DeliveryStatus {
  String get displayText {
    switch (this) {
      case DeliveryStatus.pending:
        return 'Pending';
      case DeliveryStatus.shipped:
        return 'Shipped';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.refunded:
        return 'Refunded';
    }
  }

  String get value {
    switch (this) {
      case DeliveryStatus.pending:
        return 'pending';
      case DeliveryStatus.shipped:
        return 'shipped';
      case DeliveryStatus.delivered:
        return 'delivered';
      case DeliveryStatus.refunded:
        return 'refunded';
    }
  }

  static DeliveryStatus fromValue(String? value) {
    switch (value?.toLowerCase()) {
      case DeliveryStatusValues.pending:
        return DeliveryStatus.pending;
      case DeliveryStatusValues.shipped:
        return DeliveryStatus.shipped;
      case DeliveryStatusValues.delivered:
        return DeliveryStatus.delivered;
      case DeliveryStatusValues.refunded:
        return DeliveryStatus.refunded;
      default:
        return DeliveryStatus.pending;
    }
  }
}

// ============================================================================
// ORDER STATUS EXTENSIONS
// ============================================================================

extension OrderStatusExtension on OrderStatus {
  String get displayText {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.inTransit:
        return 'In Transit';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.failed:
        return 'Failed';
      case OrderStatus.expired:
        return 'Expired';
      case OrderStatus.disputed:
        return 'Disputed';
      case OrderStatus.refunded:
        return 'Refunded';
      case OrderStatus.partiallyRefunded:
        return 'Partially Refunded';
    }
  }

  String get value {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.processing:
        return 'processing';
      case OrderStatus.shipped:
        return 'shipped';
      case OrderStatus.inTransit:
        return 'in_transit';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.failed:
        return 'failed';
      case OrderStatus.expired:
        return 'expired';
      case OrderStatus.disputed:
        return 'disputed';
      case OrderStatus.refunded:
        return 'refunded';
      case OrderStatus.partiallyRefunded:
        return 'partially_refunded';
    }
  }

  static OrderStatus fromValue(String? value) {
    switch (value?.toLowerCase()) {
      case OrderStatusValues.pending:
        return OrderStatus.pending;
      case OrderStatusValues.confirmed:
        return OrderStatus.confirmed;
      case OrderStatusValues.processing:
        return OrderStatus.processing;
      case OrderStatusValues.shipped:
        return OrderStatus.shipped;
      case OrderStatusValues.inTransit:
        return OrderStatus.inTransit;
      case OrderStatusValues.delivered:
        return OrderStatus.delivered;
      case OrderStatusValues.cancelled:
        return OrderStatus.cancelled;
      case OrderStatusValues.failed:
        return OrderStatus.failed;
      case OrderStatusValues.expired:
        return OrderStatus.expired;
      case OrderStatusValues.disputed:
        return OrderStatus.disputed;
      default:
        return OrderStatus.pending;
    }
  }
}

// ============================================================================
// PAYMENT STATUS EXTENSIONS
// ============================================================================

extension PaymentStatusExtension on PaymentStatus {
  String get displayText {
    switch (this) {
      case PaymentStatus.awaitingPayment:
        return 'Awaiting Payment';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.authorized:
        return 'Authorized';
      case PaymentStatus.captured:
        return 'Captured';
      case PaymentStatus.paymentFailed:
        return 'Payment Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.partiallyRefunded:
        return 'Partially Refunded';
      case PaymentStatus.voided:
        return 'Voided';
      case PaymentStatus.sessionExpired:
        return UIMessages.sessionExpiredTitle;
      case PaymentStatus.cancelled:
        return 'Cancelled';
      case PaymentStatus.authorizationExpired:
        return 'Authorization Expired';
      case PaymentStatus.disputed:
        return 'Disputed';
      case PaymentStatus.capturing:
        return 'Capturing';
      case PaymentStatus.cancelling:
        return 'Cancelling';
      case PaymentStatus.expiring:
        return 'Expiring';
      case PaymentStatus.cancelFailed:
        return 'Cancel Failed';
    }
  }

  String get value {
    switch (this) {
      case PaymentStatus.awaitingPayment:
        return 'awaiting_payment';
      case PaymentStatus.processing:
        return 'processing';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.authorized:
        return 'authorized';
      case PaymentStatus.captured:
        return 'captured';
      case PaymentStatus.paymentFailed:
        return 'payment_failed';
      case PaymentStatus.refunded:
        return 'refunded';
      case PaymentStatus.partiallyRefunded:
        return 'partially_refunded';
      case PaymentStatus.voided:
        return 'voided';
      case PaymentStatus.sessionExpired:
        return 'session_expired';
      case PaymentStatus.cancelled:
        return 'cancelled';
      case PaymentStatus.authorizationExpired:
        return 'authorization_expired';
      case PaymentStatus.disputed:
        return 'disputed';
      case PaymentStatus.capturing:
        return 'capturing';
      case PaymentStatus.cancelling:
        return 'cancelling';
      case PaymentStatus.expiring:
        return 'expiring';
      case PaymentStatus.cancelFailed:
        return 'cancel_failed';
    }
  }

  static PaymentStatus fromValue(String? value) {
    switch (value?.toLowerCase()) {
      case PaymentStatusValues.awaitingPayment:
        return PaymentStatus.awaitingPayment;
      case PaymentStatusValues.processing:
        return PaymentStatus.processing;
      case PaymentStatusValues.paid:
        return PaymentStatus.paid;
      case PaymentStatusValues.authorized:
        return PaymentStatus.authorized;
      case PaymentStatusValues.captured:
        return PaymentStatus.captured;
      case PaymentStatusValues.paymentFailed:
        return PaymentStatus.paymentFailed;
      case PaymentStatusValues.refunded:
        return PaymentStatus.refunded;
      case PaymentStatusValues.sessionExpired:
        return PaymentStatus.sessionExpired;
      case PaymentStatusValues.cancelled:
        return PaymentStatus.cancelled;
      case PaymentStatusValues.authorizationExpired:
        return PaymentStatus.authorizationExpired;
      case PaymentStatusValues.disputed:
        return PaymentStatus.disputed;
      case PaymentStatusValues.capturing:
        return PaymentStatus.capturing;
      case PaymentStatusValues.cancelling:
        return PaymentStatus.cancelling;
      case PaymentStatusValues.expiring:
        return PaymentStatus.expiring;
      default:
        return PaymentStatus.awaitingPayment;
    }
  }
}

// ============================================================================
// SHIPPING APPROVAL STATUS EXTENSIONS
// ============================================================================

extension ShippingApprovalStatusExtension on ShippingApprovalStatus {
  String get displayText {
    switch (this) {
      case ShippingApprovalStatus.notRequired:
        return 'Not Required';
      case ShippingApprovalStatus.pending:
        return 'Pending Approval';
      case ShippingApprovalStatus.approved:
        return 'Approved';
      case ShippingApprovalStatus.rejected:
        return 'Rejected';
    }
  }

  String get value {
    switch (this) {
      case ShippingApprovalStatus.notRequired:
        return 'not_required';
      case ShippingApprovalStatus.pending:
        return 'pending';
      case ShippingApprovalStatus.approved:
        return 'approved';
      case ShippingApprovalStatus.rejected:
        return 'rejected';
    }
  }

  static ShippingApprovalStatus fromValue(String? value) {
    switch (value?.toLowerCase()) {
      case ShippingApprovalStatusValues.notRequired:
        return ShippingApprovalStatus.notRequired;
      case ShippingApprovalStatusValues.pending:
        return ShippingApprovalStatus.pending;
      case ShippingApprovalStatusValues.approved:
        return ShippingApprovalStatus.approved;
      case ShippingApprovalStatusValues.rejected:
        return ShippingApprovalStatus.rejected;
      default:
        return ShippingApprovalStatus.notRequired;
    }
  }
}
