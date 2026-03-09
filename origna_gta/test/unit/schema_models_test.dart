import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart';

void main() {
  group('Address Model Tests', () {
    test('Address creates immutable object with all fields', () {
      final address = Address(
        street: '123 Main Street',
        apartment: 'Apt 4B',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5V 3A8',
        country: 'Canada',
        phoneNumber: '4165551234',
        isDefault: true,
        label: 'Home',
        latitude: 43.6532,
        longitude: -79.3832,
      );

      expect(address.street, '123 Main Street');
      expect(address.city, 'Toronto');
      expect(address.state, 'ON');
      expect(address.postalCode, 'M5V 3A8');
      expect(address.isDefault, true);
    });

    test('Address formatted address works correctly', () {
      final address = Address(street: '123 Main Street', apartment: 'Apt 4B', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada');

      final formatted = address.formattedAddress;
      expect(formatted.contains('123 Main Street'), true);
      expect(formatted.contains('Apt 4B'), true);
      expect(formatted.contains('Toronto, ON M5V 3A8'), true);
    });

    test('Address copyWith maintains immutability', () {
      final address = Address(street: '123 Main Street', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada');

      final updated = address.copyWith(city: 'Montreal', state: 'QC');
      expect(updated.city, 'Montreal');
      expect(updated.state, 'QC');
      expect(updated.street, address.street);
      expect(address.city, 'Toronto'); // Original unchanged
    });
  });

  group('Product Model Tests', () {
    test('Product creates immutable object with nested Address', () {
      final address = Address(street: '123 Farm Road', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada');

      final product = Product(
        productId: 'prod_123',
        name: 'Organic Apples',
        price: 4.99,
        description: 'Fresh organic apples from local farm',
        imageUrls: ['https://example.com/image1.jpg'],
        sellerId: 'seller_123',
        sellerAddress: address,
        categoryId: 1,
        stockQuantity: 100,
        rating: 4.5,
        createdAt: DateTime(2026, 2, 1),
      );

      expect(product.name, 'Organic Apples');
      expect(product.price, 4.99);
      expect(product.sellerAddress?.city, 'Toronto');
    });

    test('Product copyWith maintains immutability', () {
      final address = Address(street: '123 Farm Road', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada');

      final product = Product(
        productId: 'prod_123',
        name: 'Organic Apples',
        price: 4.99,
        description: 'Fresh apples',
        imageUrls: ['url'],
        sellerId: 'seller_123',
        sellerAddress: address,
        categoryId: 1,
        stockQuantity: 100,
        createdAt: DateTime.now(),
      );

      final updated = product.copyWith(name: 'Updated Apples', price: 5.99);
      expect(updated.name, 'Updated Apples');
      expect(updated.price, 5.99);
      expect(updated.productId, product.productId);
      expect(product.name, 'Organic Apples'); // Original unchanged
    });
  });

  group('Taxes Model Tests', () {
    test('Taxes total calculation', () {
      final taxes1 = Taxes(gst: 2.5, pst: 3.5);
      expect(taxes1.total, 6.0);

      final taxes2 = Taxes(hst: 13.0);
      expect(taxes2.total, 13.0);

      final taxes3 = Taxes(gst: 2.5, hst: 13.0);
      expect(taxes3.total, 15.5);
    });

    test('Taxes toMap/fromMap consistency', () {
      final taxes = Taxes(gst: 2.5, pst: 3.5);

      final map = taxes.toMap();
      expect(map['GST'], 2.5);
      expect(map['PST'], 3.5);

      final taxes2 = Taxes.fromMap(map);
      expect(taxes2.gst, taxes.gst);
      expect(taxes2.pst, taxes.pst);
    });
  });

  group('OrderItem Model Tests', () {
    test('OrderItem subtotal calculation', () {
      final address = Address(street: '123 Farm Road', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada');

      final item = OrderItem(
        productId: 'prod_123',
        name: 'Organic Apples',
        description: 'Fresh apples',
        price: 4.99,
        quantity: 3,
        imageUrls: ['url'],
        sellerId: 'seller_123',
        sellerAddress: address,
      );

      expect(item.subtotal, 14.97); // 4.99 * 3
    });

    test('OrderItem copyWith maintains immutability', () {
      final address = Address(street: '123 Farm Road', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada');

      final item = OrderItem(
        productId: 'prod_123',
        name: 'Organic Apples',
        description: 'Fresh apples',
        price: 4.99,
        quantity: 2,
        imageUrls: ['url'],
        sellerId: 'seller_123',
        sellerAddress: address,
        status: DeliveryStatusValues.shipped,
      );

      final updated = item.copyWith(status: DeliveryStatusValues.delivered, confirmedByBuyer: true);
      expect(updated.status, DeliveryStatusValues.delivered);
      expect(updated.confirmedByBuyer, true);
      expect(item.status, DeliveryStatusValues.shipped); // Original unchanged
    });
  });

  group('SellerPayout Model Tests', () {
    test('SellerPayout toJson/fromMap consistency', () {
      final payout = SellerPayout(
        sellerId: 'seller_123',
        amountCents: 10000,
        platformFeeCents: 250,
        netAmountCents: 9750,
        status: 'completed',
      );

      final map = payout.toJson();
      expect(map['sellerId'], 'seller_123');
      expect(map['amountCents'], 10000);

      final payout2 = SellerPayout.fromMap(map);
      expect(payout2.sellerId, payout.sellerId);
      expect(payout2.amountCents, payout.amountCents);
      expect(payout2.amount, 100.0); // Dollar getter
    });
  });

  group('Order Model Tests', () {
    test('Order dollar getters derive from cents', () {
      final address = Address(street: '123 Main St', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada');

      final item1 = OrderItem(
        productId: 'prod_1',
        name: 'Product 1',
        description: 'Description',
        price: 10.0,
        quantity: 2,
        imageUrls: ['url'],
        sellerId: 'seller_1',
        sellerAddress: address,
      );

      final item2 = OrderItem(
        productId: 'prod_2',
        name: 'Product 2',
        description: 'Description',
        price: 15.0,
        quantity: 1,
        imageUrls: ['url'],
        sellerId: 'seller_2',
        sellerAddress: address,
      );

      final order = Order(
        orderId: 'order_123',
        userId: 'user_123',
        customerId: 'cus_123',
        customerEmail: 'buyer@example.com',
        items: [item1, item2],
        totalAmountCents: 4500, // $45.00
        subtotalCents: 3500, // $35.00
        shippingCostCents: 500, // $5.00
        taxAmountCents: 500, // $5.00
        taxes: Taxes(gst: 2.0, pst: 3.0),
        shippingAddress: address,
        createdAt: DateTime.now(),
        stripeSessionId: 'session_123',
      );

      expect(order.subtotal, 35.0);
      expect(order.shippingCost, 5.0);
      expect(order.taxAmount, 5.0);
      expect(order.total, 45.0);
    });

    test('Order copyWith maintains immutability', () {
      final address = Address(street: '123 Main St', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada');

      final item = OrderItem(
        productId: 'prod_1',
        name: 'Product 1',
        description: 'Description',
        price: 10.0,
        quantity: 1,
        imageUrls: ['url'],
        sellerId: 'seller_1',
        sellerAddress: address,
      );

      final order = Order(
        orderId: 'order_123',
        userId: 'user_123',
        customerId: 'cus_123',
        customerEmail: 'buyer@example.com',
        items: [item],
        totalAmountCents: 1500,
        subtotalCents: 1000,
        shippingCostCents: 500,
        taxes: Taxes(gst: 0.5),
        shippingAddress: address,
        createdAt: DateTime(2026, 2, 1),
        stripeSessionId: 'session_123',
      );

      final updated = order.copyWith(orderStatus: OrderStatus.delivered, confirmedByClient: true);
      expect(updated.orderStatus, OrderStatus.delivered);
      expect(updated.confirmedByClient, true);
      expect(order.orderStatus, OrderStatus.pending); // Original unchanged
    });
  });

  group('User Model Tests', () {
    test('User helper methods', () {
      final buyer = User(uid: 'user_1', email: 'buyer@example.com', name: 'Jane Buyer', roles: [UserRole.buyer], createdAt: DateTime.now());
      expect(buyer.isSeller, false);
      expect(buyer.isAdmin, false);
      expect(buyer.canSell, false);

      final sellerComplete = User(
        uid: 'user_2',
        email: 'seller@example.com',
        name: 'John Seller',
        roles: [UserRole.seller],
        createdAt: DateTime.now(),
        isSeller: true,
      );
      expect(sellerComplete.isSeller, true);
      expect(sellerComplete.canSell, true);

      final sellerIncomplete = User(
        uid: 'user_3',
        email: 'seller2@example.com',
        name: 'Jane Seller',
        roles: [UserRole.seller],
        createdAt: DateTime.now(),
      );
      expect(sellerIncomplete.isSeller, false);
      expect(sellerIncomplete.canSell, false);

      final admin = User(uid: 'user_4', email: 'admin@example.com', name: 'Admin User', roles: [UserRole.admin], createdAt: DateTime.now());
      expect(admin.isAdmin, true);
    });

    test('User copyWith maintains immutability', () {
      final user = User(uid: 'user_123', email: 'user@example.com', name: 'John Doe', roles: [UserRole.buyer], createdAt: DateTime.now());

      final updated = user.copyWith(name: 'Jane Doe', isSeller: true);
      expect(updated.name, 'Jane Doe');
      expect(updated.isSeller, true);
      expect(user.name, 'John Doe'); // Original unchanged
    });
  });

  group('Enum Tests', () {
    test('OrderStatus values', () {
      expect(OrderStatus.pending.name, 'pending');
      expect(OrderStatus.delivered.name, 'delivered');
      expect(OrderStatus.values.length, 12);
    });

    test('PaymentStatus values', () {
      expect(PaymentStatus.awaitingPayment.name, 'awaitingPayment');
      expect(PaymentStatus.paid.name, 'paid');
      expect(PaymentStatus.disputed.name, 'disputed');
      expect(PaymentStatus.values.length, 17); // cancelFailed added
    });

    test('DeliveryStatus values', () {
      expect(DeliveryStatus.pending.name, 'pending');
      expect(DeliveryStatus.shipped.name, 'shipped');
      expect(DeliveryStatus.delivered.name, 'delivered');
      expect(DeliveryStatus.refunded.name, 'refunded');
      expect(DeliveryStatus.values.length, 4);
    });

    test('UserRole values', () {
      expect(UserRole.buyer.name, 'buyer');
      expect(UserRole.seller.name, 'seller');
      expect(UserRole.admin.name, 'admin');
      expect(UserRole.values.length, 3);
    });
  });
}
