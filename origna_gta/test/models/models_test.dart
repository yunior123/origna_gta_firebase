import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/models.dart';

void main() {
  group('Address Tests', () {
    test('Empty address creation', () {
      final address = Address.empty();
      expect(address.street, '');
      expect(address.country, 'Canada');
    });

    test('fromMap and toMap', () {
      final map = {
        Fields.addressId: 'addr_1',
        Fields.street: '123 Main St',
        Fields.apartment: 'Apt 4',
        Fields.city: 'Toronto',
        Fields.state: 'ON',
        Fields.postalCode: 'M5V',
        Fields.country: 'Canada',
        Fields.phoneNumber: '1234567890',
        Fields.isDefault: true,
        Fields.label: 'Home',
        Fields.latitude: 43.0,
        Fields.longitude: -79.0,
      };

      final address = Address.fromMap(map);
      expect(address.street, '123 Main St');
      expect(address.isDefault, true);

      final toMapMap = address.toMap();
      expect(toMapMap[Fields.street], '123 Main St');
      expect(toMapMap[Fields.isDefault], true);
    });

    test('formattedAddress and fullAddress', () {
      final address = Address(street: '123 Main St', apartment: 'Apt 4', city: 'Toronto', state: 'ON', postalCode: 'M5V', country: 'Canada');

      final formatted = address.formattedAddress;
      expect(formatted.contains('123 Main St'), true);
      expect(formatted.contains('Apt 4'), true);

      final full = address.fullAddress;
      expect(full, '123 Main St, Apt 4, Toronto, ON, M5V, Canada');
    });

    test('copyWith', () {
      final address = Address.empty();
      final copied = address.copyWith(street: 'New Street', city: 'New City');
      expect(copied.street, 'New Street');
      expect(copied.city, 'New City');
      expect(copied.country, 'Canada');
    });
  });

  group('CartItemDetailModel Tests', () {
    test('fromMap and toMap', () {
      final ts = Timestamp.now();
      final map = {
        Fields.productId: 'prod_1',
        Fields.name: 'Product 1',
        Fields.description: 'Desc',
        Fields.price: 15.0,
        Fields.imageUrls: ['url1'],
        Fields.quantity: 2,
        Fields.createdAt: ts,
        Fields.sellerAddress: Address.empty().toMap(),
        Fields.sellerId: 'sell_1',
        Fields.sellerName: 'Seller 1',
        Fields.status: DeliveryStatusValues.pending,
        Fields.confirmedByBuyer: false,
        Fields.isLocalDeliveryOnly: true,
        Fields.isPerishable: false,
        Fields.estimatedShipDays: 3,
        Fields.minimumOrderQuantity: 1,
        Fields.freeShipping: false,
        Fields.isDigital: false,
        Fields.isAgeRestricted: false,
        Fields.isSmallSupplier: false,
      };

      final item = CartItemDetailModel.fromMap(map);
      expect(item.productId, 'prod_1');
      expect(item.name, 'Product 1');
      expect(item.quantity, 2);
      expect(item.isLocalDeliveryOnly, true);

      final toMap = item.toMap();
      expect(toMap[Fields.productId], 'prod_1');
      expect(toMap[Fields.price], 15.0);
    });
  });

  group('CartItemModel Tests', () {
    test('fromMap and toMap', () {
      final ts = Timestamp.now();
      final map = {Fields.cartItemId: 'cart_1', Fields.quantity: 3, Fields.productId: 'prod_1', Fields.createdAt: ts, Fields.buyerNote: 'Note'};

      final item = CartItemModel.fromMap(map, docId: 'cart_1');
      expect(item.cartItemId, 'cart_1');
      expect(item.quantity, 3);
      expect(item.buyerNote, 'Note');

      final toMap = item.toMap();
      expect(toMap[Fields.quantity], 3);
      expect(toMap[Fields.buyerNote], 'Note');
    });
  });

  group('CartModel Tests', () {
    test('fromMap and toMap', () {
      final ts = Timestamp.now();
      final map = {Fields.cartItemId: 'cart_item_1', Fields.productId: 'prod_1', Fields.quantity: 5, Fields.createdAt: ts, Fields.priceSnapshot: 1500};

      final model = CartModel.fromMap(map);
      expect(model.quantity, 5);
      expect(model.priceSnapshot, 1500);

      final toMap = model.toMap();
      expect(toMap[Fields.quantity], 5);
      expect(toMap[Fields.priceSnapshot], 1500);
    });
  });

  group('FavoriteItem Tests', () {
    test('toMap', () {
      final fav = FavoriteItem(productId: 'prod_1', dateFavorited: DateTime.now());
      final map = fav.toMap();
      expect(map[Fields.productId], 'prod_1');
      expect(map[Fields.dateFavorited] is Timestamp, true);
    });
  });

  group('OrderModel Tests', () {
    test('fromMap and toMap', () {
      final map = {
        Fields.orderId: 'order_1',
        Fields.userId: 'user_1',
        Fields.items: [],
        Fields.totalAmountCents: 1000,
        Fields.subtotalCents: 800,
        Fields.shippingCostCents: 100,
        Fields.taxAmountCents: 100,
        Fields.orderStatus: OrderStatusValues.pending,
        Fields.paymentStatus: PaymentStatusValues.awaitingPayment,
        Fields.shippingAddress: {},
        Fields.createdAt: Timestamp.now(),
        Fields.customerId: 'cust_1',
        Fields.customerEmail: 'cust@test.com',
        Fields.taxes: {},
        Fields.currency: 'CAD',
        Fields.sellerIds: ['seller_1'],
        Fields.stripeSessionId: 'sess_1',
        Fields.shippingApprovalStatus: ShippingApprovalStatusValues.notRequired,
        Fields.shippingApprovalRequired: false,
        Fields.actualShippingCents: 100,
        Fields.pendingTotalCents: 0,
        Fields.sellerPayouts: [],
        Fields.confirmedByClient: false,
        Fields.platformFeeTotalCents: 50,
        Fields.payoutStatus: PayoutStatusValues.pending,
        Fields.ratings: {},
      };

      final order = OrderModel.fromMap(map);
      expect(order.orderId, 'order_1');
      expect(order.totalAmountCents, 1000);
      expect(order.shippingCost, 1.0);
      expect(order.total, 10.0);
      expect(order.allItemsConfirmed, false);
      expect(order.allSellersPaid, false);

      final toMap = order.toMap();
      expect(toMap[Fields.orderId], null); // Order ID is usually not in toMap directly if it's the doc key, but let's check totalAmountCents
      expect(toMap[Fields.totalAmountCents], 1000);
    });
  });

  group('ProductModel Tests', () {
    test('fromMap and toMap', () {
      final map = {
        Fields.productId: 'prod_1',
        Fields.name: 'Product 1',
        Fields.price: 49.99,
        Fields.imageUrls: ['url1', 'url2'],
        Fields.sellerAddress: {},
        Fields.description: 'Description',
        Fields.stockQuantity: 10,
        Fields.categoryId: 1,
        Fields.rating: 4.5,
        Fields.ratingCount: 100,
        Fields.sellerId: 'seller_1',
        Fields.keywords: ['keyword1'],
        Fields.isLocalDeliveryOnly: false,
        Fields.estimatedShipDays: 2,
        Fields.isPerishable: false,
        Fields.minimumOrderQuantity: 1,
        Fields.freeShipping: false,
        Fields.isDigital: false,
        Fields.isAgeRestricted: false,
        Fields.lifecycleStatus: ProductLifecycleStatusValues.active,
      };

      final product = ProductModel.fromMap(map);
      expect(product.id, 'prod_1');
      expect(product.name, 'Product 1');
      expect(product.price, 49.99);
      expect(product.stockQuantity, 10);
      expect(product.lifecycleStatus, ProductLifecycleStatusValues.active);

      final toMapMap = product.toMap();
      expect(toMapMap[Fields.name], 'Product 1');
      expect(toMapMap[Fields.price], 49.99);
    });
  });

  group('SellerPayout Tests', () {
    test('fromMap and toMap', () {
      final map = {
        Fields.sellerId: 'sell_1',
        Fields.stripeAccountId: 'acct_1',
        Fields.amountCents: 1000,
        Fields.platformFeeCents: 100,
        Fields.netAmountCents: 900,
        Fields.status: PayoutStatusValues.completed,
      };

      final payout = SellerPayout.fromMap(map);
      expect(payout.sellerId, 'sell_1');
      expect(payout.amount, 10.0);
      expect(payout.netAmount, 9.0);
      expect(payout.platformFee, 1.0);
      expect(payout.paid, true);

      final toMapMap = payout.toMap();
      expect(toMapMap[Fields.amountCents], 1000);
      expect(toMapMap[Fields.status], PayoutStatusValues.completed);
    });
  });

  group('UserModel Tests', () {
    test('fromMap and toMap', () {
      final map = {
        Fields.uid: 'user_1',
        Fields.email: 'user@test.com',
        Fields.name: 'User 1',
        Fields.roles: [UserRoleValues.buyer, UserRoleValues.seller],
        Fields.createdAt: Timestamp.now(),
        Fields.suspended: false,
        Fields.paymentProvider: PaymentProviderValues.stripe,
        Fields.verified: true,
        Fields.payoutHoldDays: 7,
        Fields.isPremium: true,
        Fields.mfaEnabled: true,
      };

      final user = UserModel.fromMap(map);
      expect(user.uid, 'user_1');
      expect(user.email, 'user@test.com');
      expect(user.isPremium, true);
      expect(user.canReceivePayouts, false); // because payoutsEnabled is hardcoded false locally
      expect(user.canSell, false);

      final toMapMap = user.toMap();
      expect(toMapMap[Fields.email], 'user@test.com');
      expect(toMapMap[Fields.uid], 'user_1');
    });

    test('copyWith', () {
      final user = UserModel(uid: 'user_1', email: 'user@test.com', name: 'User', roles: [], createdAt: DateTime.now());

      final copied = user.copyWith(name: 'New Name', isPremium: true);
      expect(copied.name, 'New Name');
      expect(copied.isPremium, true);
      expect(copied.uid, 'user_1');
    });
  });
}
