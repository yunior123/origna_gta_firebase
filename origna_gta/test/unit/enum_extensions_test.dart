import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/models/enum_extensions.dart';

void main() {
  group('DeliveryStatusExtension', () {
    test('displayText for all values', () {
      expect(DeliveryStatus.pending.displayText, 'Pending');
      expect(DeliveryStatus.shipped.displayText, 'Shipped');
      expect(DeliveryStatus.delivered.displayText, 'Delivered');
      expect(DeliveryStatus.refunded.displayText, 'Refunded');
    });

    test('value for all values', () {
      expect(DeliveryStatus.pending.value, 'pending');
      expect(DeliveryStatus.shipped.value, 'shipped');
      expect(DeliveryStatus.delivered.value, 'delivered');
      expect(DeliveryStatus.refunded.value, 'refunded');
    });

    test('fromValue parses all values', () {
      expect(DeliveryStatusExtension.fromValue('pending'), DeliveryStatus.pending);
      expect(DeliveryStatusExtension.fromValue('shipped'), DeliveryStatus.shipped);
      expect(DeliveryStatusExtension.fromValue('delivered'), DeliveryStatus.delivered);
      expect(DeliveryStatusExtension.fromValue('refunded'), DeliveryStatus.refunded);
      expect(DeliveryStatusExtension.fromValue('SHIPPED'), DeliveryStatus.shipped);
      expect(DeliveryStatusExtension.fromValue(null), DeliveryStatus.pending);
      expect(DeliveryStatusExtension.fromValue('unknown'), DeliveryStatus.pending);
    });
  });

  group('OrderStatusExtension', () {
    test('displayText for all values', () {
      expect(OrderStatus.pending.displayText, 'Pending');
      expect(OrderStatus.confirmed.displayText, 'Confirmed');
      expect(OrderStatus.processing.displayText, 'Processing');
      expect(OrderStatus.shipped.displayText, 'Shipped');
      expect(OrderStatus.inTransit.displayText, 'In Transit');
      expect(OrderStatus.delivered.displayText, 'Delivered');
      expect(OrderStatus.cancelled.displayText, 'Cancelled');
      expect(OrderStatus.failed.displayText, 'Failed');
      expect(OrderStatus.expired.displayText, 'Expired');
      expect(OrderStatus.disputed.displayText, 'Disputed');
      expect(OrderStatus.refunded.displayText, 'Refunded');
      expect(OrderStatus.partiallyRefunded.displayText, 'Partially Refunded');
    });

    test('value for all values', () {
      expect(OrderStatus.pending.value, 'pending');
      expect(OrderStatus.confirmed.value, 'confirmed');
      expect(OrderStatus.processing.value, 'processing');
      expect(OrderStatus.shipped.value, 'shipped');
      expect(OrderStatus.inTransit.value, 'in_transit');
      expect(OrderStatus.delivered.value, 'delivered');
      expect(OrderStatus.cancelled.value, 'cancelled');
      expect(OrderStatus.failed.value, 'failed');
      expect(OrderStatus.expired.value, 'expired');
      expect(OrderStatus.disputed.value, 'disputed');
      expect(OrderStatus.refunded.value, 'refunded');
      expect(OrderStatus.partiallyRefunded.value, 'partially_refunded');
    });

    test('fromValue parses all values', () {
      expect(OrderStatusExtension.fromValue('pending'), OrderStatus.pending);
      expect(OrderStatusExtension.fromValue('confirmed'), OrderStatus.confirmed);
      expect(OrderStatusExtension.fromValue('processing'), OrderStatus.processing);
      expect(OrderStatusExtension.fromValue('shipped'), OrderStatus.shipped);
      expect(OrderStatusExtension.fromValue('in_transit'), OrderStatus.inTransit);
      expect(OrderStatusExtension.fromValue('delivered'), OrderStatus.delivered);
      expect(OrderStatusExtension.fromValue('cancelled'), OrderStatus.cancelled);
      expect(OrderStatusExtension.fromValue('failed'), OrderStatus.failed);
      expect(OrderStatusExtension.fromValue('expired'), OrderStatus.expired);
      expect(OrderStatusExtension.fromValue('disputed'), OrderStatus.disputed);
      expect(OrderStatusExtension.fromValue('IN_TRANSIT'), OrderStatus.inTransit);
      expect(OrderStatusExtension.fromValue(null), OrderStatus.pending);
      expect(OrderStatusExtension.fromValue('unknown'), OrderStatus.pending);
    });
  });

  group('PaymentStatusExtension', () {
    test('displayText for all values', () {
      expect(PaymentStatus.awaitingPayment.displayText, 'Awaiting Payment');
      expect(PaymentStatus.processing.displayText, 'Processing');
      expect(PaymentStatus.paid.displayText, 'Paid');
      expect(PaymentStatus.authorized.displayText, 'Authorized');
      expect(PaymentStatus.captured.displayText, 'Captured');
      expect(PaymentStatus.paymentFailed.displayText, 'Payment Failed');
      expect(PaymentStatus.refunded.displayText, 'Refunded');
      expect(PaymentStatus.partiallyRefunded.displayText, 'Partially Refunded');
      expect(PaymentStatus.voided.displayText, 'Voided');
      expect(PaymentStatus.sessionExpired.displayText, isNotEmpty);
      expect(PaymentStatus.cancelled.displayText, 'Cancelled');
      expect(PaymentStatus.authorizationExpired.displayText, 'Authorization Expired');
      expect(PaymentStatus.disputed.displayText, 'Disputed');
      expect(PaymentStatus.capturing.displayText, 'Capturing');
      expect(PaymentStatus.cancelling.displayText, 'Cancelling');
      expect(PaymentStatus.expiring.displayText, 'Expiring');
      expect(PaymentStatus.cancelFailed.displayText, 'Cancel Failed');
    });

    test('value for all values', () {
      expect(PaymentStatus.awaitingPayment.value, 'awaiting_payment');
      expect(PaymentStatus.processing.value, 'processing');
      expect(PaymentStatus.paid.value, 'paid');
      expect(PaymentStatus.authorized.value, 'authorized');
      expect(PaymentStatus.captured.value, 'captured');
      expect(PaymentStatus.paymentFailed.value, 'payment_failed');
      expect(PaymentStatus.refunded.value, 'refunded');
      expect(PaymentStatus.partiallyRefunded.value, 'partially_refunded');
      expect(PaymentStatus.voided.value, 'voided');
      expect(PaymentStatus.sessionExpired.value, 'session_expired');
      expect(PaymentStatus.cancelled.value, 'cancelled');
      expect(PaymentStatus.authorizationExpired.value, 'authorization_expired');
      expect(PaymentStatus.disputed.value, 'disputed');
      expect(PaymentStatus.capturing.value, 'capturing');
      expect(PaymentStatus.cancelling.value, 'cancelling');
      expect(PaymentStatus.expiring.value, 'expiring');
      expect(PaymentStatus.cancelFailed.value, 'cancel_failed');
    });

    test('fromValue parses all values', () {
      expect(PaymentStatusExtension.fromValue('awaiting_payment'), PaymentStatus.awaitingPayment);
      expect(PaymentStatusExtension.fromValue('processing'), PaymentStatus.processing);
      expect(PaymentStatusExtension.fromValue('paid'), PaymentStatus.paid);
      expect(PaymentStatusExtension.fromValue('authorized'), PaymentStatus.authorized);
      expect(PaymentStatusExtension.fromValue('captured'), PaymentStatus.captured);
      expect(PaymentStatusExtension.fromValue('payment_failed'), PaymentStatus.paymentFailed);
      expect(PaymentStatusExtension.fromValue('refunded'), PaymentStatus.refunded);
      expect(PaymentStatusExtension.fromValue('session_expired'), PaymentStatus.sessionExpired);
      expect(PaymentStatusExtension.fromValue('cancelled'), PaymentStatus.cancelled);
      expect(PaymentStatusExtension.fromValue('authorization_expired'), PaymentStatus.authorizationExpired);
      expect(PaymentStatusExtension.fromValue('disputed'), PaymentStatus.disputed);
      expect(PaymentStatusExtension.fromValue('capturing'), PaymentStatus.capturing);
      expect(PaymentStatusExtension.fromValue('cancelling'), PaymentStatus.cancelling);
      expect(PaymentStatusExtension.fromValue('expiring'), PaymentStatus.expiring);
      expect(PaymentStatusExtension.fromValue('CAPTURED'), PaymentStatus.captured);
      expect(PaymentStatusExtension.fromValue(null), PaymentStatus.awaitingPayment);
      expect(PaymentStatusExtension.fromValue('invalid'), PaymentStatus.awaitingPayment);
    });
  });

  group('ShippingApprovalStatusExtension', () {
    test('displayText for all values', () {
      expect(ShippingApprovalStatus.notRequired.displayText, 'Not Required');
      expect(ShippingApprovalStatus.pending.displayText, 'Pending Approval');
      expect(ShippingApprovalStatus.approved.displayText, 'Approved');
      expect(ShippingApprovalStatus.rejected.displayText, 'Rejected');
    });

    test('value for all values', () {
      expect(ShippingApprovalStatus.notRequired.value, 'not_required');
      expect(ShippingApprovalStatus.pending.value, 'pending');
      expect(ShippingApprovalStatus.approved.value, 'approved');
      expect(ShippingApprovalStatus.rejected.value, 'rejected');
    });

    test('fromValue parses all values', () {
      expect(ShippingApprovalStatusExtension.fromValue('not_required'), ShippingApprovalStatus.notRequired);
      expect(ShippingApprovalStatusExtension.fromValue('pending'), ShippingApprovalStatus.pending);
      expect(ShippingApprovalStatusExtension.fromValue('approved'), ShippingApprovalStatus.approved);
      expect(ShippingApprovalStatusExtension.fromValue('rejected'), ShippingApprovalStatus.rejected);
      expect(ShippingApprovalStatusExtension.fromValue('REJECTED'), ShippingApprovalStatus.rejected);
      expect(ShippingApprovalStatusExtension.fromValue(null), ShippingApprovalStatus.notRequired);
      expect(ShippingApprovalStatusExtension.fromValue('bad'), ShippingApprovalStatus.notRequired);
    });
  });
}
