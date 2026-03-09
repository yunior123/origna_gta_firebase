import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/models.dart';

void main() {
  group('OrderModel', () {
    test('fromMap creates correct OrderModel', () {
      final now = DateTime.now();
      final map = {
        Fields.orderId: 'order123',
        Fields.userId: 'buyer123',
        Fields.sellerIds: ['seller123'],
        Fields.orderStatus: 'pending',
        Fields.paymentStatus: 'authorized',
        Fields.totalAmountCents: 10000,
        Fields.subtotalCents: 10000,
        Fields.createdAt: Timestamp.fromDate(now),
        Fields.customerId: 'cus_123',
        Fields.customerEmail: 'test@example.com',
        Fields.taxes: {},
        Fields.currency: 'cad',
        Fields.stripeSessionId: 'sess_123',
        Fields.items: [
          {
            Fields.productId: 'p1',
            Fields.quantity: 2,
            Fields.price: 50.0,
          }
        ],
        Fields.shippingAddress: {
          Fields.street: '123 Main St',
          Fields.city: 'Toronto',
        },
      };

      final order = OrderModel.fromMap(map);

      expect(order.orderId, 'order123');
      expect(order.userId, 'buyer123');
      expect(order.orderStatus, 'pending');
      expect(order.totalAmountCents, 10000);
      expect(order.items.length, 1);
      expect(order.items.first.productId, 'p1');
      expect(order.shippingAddress[Fields.city], 'Toronto');
    });
  });
}
