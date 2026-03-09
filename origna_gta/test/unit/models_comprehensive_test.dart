import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

void main() {
  group('Generated Models Comprehensive Tests', () {
    
    test('Address fromJson/toJson', () {
      final json = {
        'street': '123 Main St',
        'apartment': 'Apt 4B',
        'city': 'Toronto',
        'state': 'ON',
        'postalCode': 'M5V 3A8',
        'country': 'Canada',
        'isDefault': true,
        'label': 'Home',
        'latitude': 43.6532,
        'longitude': -79.3832,
      };
      
      final model = Address.fromJson(json);
      expect(model.street, '123 Main St');
      expect(model.city, 'Toronto');
      expect(model.isDefault, true);
      
      final backToJson = model.toJson();
      expect(backToJson['street'], json['street']);
      expect(backToJson['city'], json['city']);
    });

    test('User fromJson/toJson', () {
      final now = DateTime.now();
      final json = {
        'uid': 'u1',
        'email': 'test@example.com',
        'name': 'Test User',
        'roles': ['buyer'],
        'createdAt': now.toIso8601String(),
        'isPremium': true,
        'preferredLanguage': 'en',
      };
      
      final model = User.fromJson(json);
      expect(model.uid, 'u1');
      expect(model.isPremium, true);
      expect(model.roles.first, UserRole.buyer);
      
      final backToJson = model.toJson();
      expect(backToJson['uid'], json['uid']);
      // DateTime might lose some precision in ISO string roundtrip depending on implementation, 
      // but usually it works fine for tests.
    });

    test('Product fromJson/toJson', () {
      final now = DateTime.now();
      final json = {
        'productId': 'p1',
        'name': 'Test Product',
        'price': 99.99,
        'description': 'A great product',
        'imageUrls': ['img1.jpg'],
        'sellerId': 's1',
        'categoryId': 1,
        'stockQuantity': 10,
        'createdAt': now.toIso8601String(),
        'hasVariants': true,
        'variants': [
          {
            'variantId': 'v1',
            'optionValues': {'size': 'M'},
            'priceCents': 9999,
            'stockQuantity': 5,
          }
        ],
        'variantOptions': [
          {
            'name': 'size',
            'values': ['S', 'M', 'L'],
          }
        ],
      };
      
      final model = Product.fromJson(json);
      expect(model.productId, 'p1');
      expect(model.hasVariants, true);
      expect(model.variants.first.variantId, 'v1');
      expect(model.variantOptions.first.name, 'size');
      
      final backToJson = model.toJson();
      expect(backToJson['productId'], json['productId']);
      expect(backToJson['price'], json['price']);
    });

    test('Order fromJson/toJson', () {
      final now = DateTime.now();
      final json = {
        'orderId': 'o1',
        'userId': 'u1',
        'items': [
          {
            'productId': 'p1',
            'name': 'Item 1',
            'description': 'Desc',
            'price': 50.0,
            'quantity': 2,
            'imageUrls': [],
            'sellerId': 's1',
            'status': 'pending',
          }
        ],
        'totalAmountCents': 10000,
        'subtotalCents': 10000,
        'taxes': {'GST': 5.0, 'PST': 0.0, 'HST': 0.0, 'QST': 0.0},
        'createdAt': now.toIso8601String(),
        'orderStatus': 'pending',
        'paymentStatus': 'awaiting_payment',
      };
      
      final model = Order.fromJson(json);
      expect(model.orderId, 'o1');
      expect(model.items.length, 1);
      expect(model.items.first.price, 50.0);
      expect(model.taxes.gst, 5.0);
      
      final backToJson = model.toJson();
      expect(backToJson['orderId'], json['orderId']);
    });

    test('Taxes fromJson/toJson', () {
      final json = {
        Fields.GST: 5.0,
        Fields.PST: 8.0,
        Fields.HST: 13.0,
        Fields.QST: 9.975,
      };
      
      final model = Taxes.fromJson(json);
      expect(model.gst, 5.0);
      expect(model.qst, 9.975);
      expect(model.total, 5.0 + 8.0 + 13.0 + 9.975);
      
      final backToJson = model.toJson();
      expect(backToJson[Fields.GST], json[Fields.GST]);
    });

    test('SellerPayout fromMap', () {
      final map = {
        Fields.sellerId: 's1',
        'amountCents': 1000,
        'platformFeeCents': 25,
        'netAmountCents': 975,
        'status': 'pending',
      };
      
      final model = SellerPayout.fromMap(map);
      expect(model.sellerId, 's1');
      expect(model.amount, 10.0);
      expect(model.platformFee, 0.25);
      expect(model.netAmount, 9.75);
    });

    test('VariantOption fromJson', () {
      final json = {
        'name': 'Color',
        'values': ['Red', 'Blue'],
      };
      final model = VariantOption.fromJson(json);
      expect(model.name, 'Color');
      expect(model.values, ['Red', 'Blue']);
    });

    test('InventoryConfig fromJson', () {
      final json = {
        'managed': true,
        'trackQuantity': true,
        'lowStockThreshold': 3,
      };
      final model = InventoryConfig.fromJson(json);
      expect(model.managed, true);
      expect(model.lowStockThreshold, 3);
    });

    test('SupplierInfo fromJson', () {
      final json = {
        'type': 'aliexpress',
        'cost': 5.5,
        'currency': 'USD',
      };
      final model = SupplierInfo.fromJson(json);
      expect(model.type, 'aliexpress');
      expect(model.cost, 5.5);
    });
  });
}
