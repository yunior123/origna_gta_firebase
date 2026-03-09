import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/models/generated/product_models.dart';
import 'package:origna_gta/models/generated/order_models.dart';
import 'package:origna_gta/models/generated/base_models.dart';

void main() {
  group('Product serialization', () {
    final productJson = {
      'productId': 'p1',
      'name': 'Test Product',
      'nameF': 'Produit Test',
      'price': 29.99,
      'priceCents': 2999,
      'compareAtPrice': 39.99,
      'description': 'A test product',
      'descriptionF': 'Un produit test',
      'imageUrls': ['img1.jpg', 'img2.jpg'],
      'videoUrl': 'video.mp4',
      'videoDurationSeconds': 30,
      'sellerId': 's1',
      'madeInCountry': 'CA',
      'categoryId': 1,
      'stockQuantity': 50,
      'rating': 4.5,
      'ratingCount': 10,
      'createdAt': '2026-01-01T00:00:00.000',
      'lifecycleStatus': 'active',
      'weightKg': 1.5,
      'weightUnit': 'kg',
      'lengthCm': 30.0,
      'widthCm': 20.0,
      'heightCm': 10.0,
      'dimensionUnit': 'cm',
      'isLocalDeliveryOnly': true,
      'isPerishable': true,
      'estimatedShipDays': 2,
      'minimumOrderQuantity': 3,
      'freeShipping': true,
      'isDigital': false,
      'isAgeRestricted': true,
      'taxCode': 'TAX001',
      'keywords': ['test', 'product'],
      'approvalRejectionReason': 'Missing info',
      'cost': 15.0,
      'supplierSku': 'SUP-001',
      'supplierUrl': 'https://supplier.com/product',
      'sellerSku': 'SKU-001',
      'warehouseIds': ['wh1', 'wh2'],
      'shipFromCity': 'Toronto',
      'shipFromProvince': 'ON',
      'shipFromCountry': 'CA',
      'shipFromCountries': ['CA', 'US'],
      'trendingScore': 100,
      'viewCount': 500,
      'purchaseCount': 25,
      'isTrending': true,
      'trendingAt': '2026-02-01T00:00:00.000',
      'hasVariants': true,
      'subcategory': 'electronics',
      'condition': 'new',
      'warehouseStockMap': {'wh1': 30, 'wh2': 20},
      'updatedAt': '2026-02-15T00:00:00.000',
      'deliveryOptions': [],
      'variants': [],
      'variantOptions': [],
    };

    test('fromJson parses all fields', () {
      final product = Product.fromJson(productJson);
      expect(product.productId, 'p1');
      expect(product.name, 'Test Product');
      expect(product.nameF, 'Produit Test');
      expect(product.price, 29.99);
      expect(product.priceCents, 2999);
      expect(product.compareAtPrice, 39.99);
      expect(product.description, 'A test product');
      expect(product.imageUrls.length, 2);
      expect(product.videoUrl, 'video.mp4');
      expect(product.sellerId, 's1');
      expect(product.categoryId, 1);
      expect(product.stockQuantity, 50);
      expect(product.rating, 4.5);
      expect(product.ratingCount, 10);
      expect(product.isLocalDeliveryOnly, true);
      expect(product.isPerishable, true);
      expect(product.freeShipping, true);
      expect(product.isAgeRestricted, true);
      expect(product.trendingScore, 100);
      expect(product.isTrending, true);
      expect(product.hasVariants, true);
      expect(product.subcategory, 'electronics');
      expect(product.condition, 'new');
      expect(product.warehouseStockMap, {'wh1': 30, 'wh2': 20});
    });

    test('toJson roundtrip preserves data', () {
      final product = Product.fromJson(productJson);
      final json = product.toJson();
      expect(json['productId'], 'p1');
      expect(json['name'], 'Test Product');
      expect(json['price'], 29.99);
      expect(json['sellerId'], 's1');
      expect(json['categoryId'], 1);
      expect(json['trendingScore'], 100);
    });

    test('fromJson with minimal fields', () {
      final minimal = {
        'productId': 'p2',
        'name': 'Minimal',
        'price': 9.99,
        'description': 'Desc',
        'imageUrls': <String>[],
        'sellerId': 's2',
        'categoryId': 2,
        'stockQuantity': 0,
        'createdAt': '2026-01-01T00:00:00.000',
      };
      final product = Product.fromJson(minimal);
      expect(product.productId, 'p2');
      expect(product.rating, 0.0);
      expect(product.ratingCount, 0);
      expect(product.isDigital, false);
      expect(product.freeShipping, false);
      expect(product.estimatedShipDays, 3);
      expect(product.minimumOrderQuantity, 1);
      expect(product.trendingScore, 0);
      expect(product.viewCount, 0);
      expect(product.purchaseCount, 0);
      expect(product.isTrending, false);
      expect(product.hasVariants, false);
      expect(product.nameF, isNull);
      expect(product.videoUrl, isNull);
      expect(product.supplier, isNull);
      expect(product.inventory, isNull);
    });
  });

  group('InventoryConfig serialization', () {
    test('fromJson with all fields', () {
      final json = {
        'managed': false,
        'trackQuantity': false,
        'allowBackorder': true,
        'lowStockThreshold': 10,
        'lastLowStockAlertAt': '2026-01-15T12:00:00.000',
        'reservationHoldMinutes': 60,
      };
      final config = InventoryConfig.fromJson(json);
      expect(config.managed, false);
      expect(config.trackQuantity, false);
      expect(config.allowBackorder, true);
      expect(config.lowStockThreshold, 10);
      expect(config.lastLowStockAlertAt, isNotNull);
      expect(config.reservationHoldMinutes, 60);
    });

    test('fromJson with defaults', () {
      final config = InventoryConfig.fromJson({});
      expect(config.managed, true);
      expect(config.trackQuantity, true);
      expect(config.allowBackorder, false);
      expect(config.lowStockThreshold, 5);
      expect(config.reservationHoldMinutes, 30);
    });

    test('toJson roundtrip', () {
      final config = const InventoryConfig(
        managed: true,
        trackQuantity: false,
        allowBackorder: true,
        lowStockThreshold: 15,
        reservationHoldMinutes: 45,
      );
      final json = config.toJson();
      expect(json['managed'], true);
      expect(json['trackQuantity'], false);
      expect(json['allowBackorder'], true);
      expect(json['lowStockThreshold'], 15);
    });
  });

  group('VariantOption serialization', () {
    test('fromJson and toJson', () {
      final json = {
        'name': 'Color',
        'values': ['Red', 'Blue', 'Green'],
      };
      final option = VariantOption.fromJson(json);
      expect(option.name, 'Color');
      expect(option.values, ['Red', 'Blue', 'Green']);

      final output = option.toJson();
      expect(output['name'], 'Color');
      expect(output['values'], ['Red', 'Blue', 'Green']);
    });
  });

  group('ProductVariant serialization', () {
    test('fromJson with all fields', () {
      final json = {
        'variantId': 'v1',
        'sku': 'SKU-V1',
        'priceCents': 1999,
        'stockQuantity': 25,
        'optionValues': {'Color': 'Red', 'Size': 'L'},
        'isActive': true,
      };
      final variant = ProductVariant.fromJson(json);
      expect(variant.variantId, 'v1');
      expect(variant.sku, 'SKU-V1');
      expect(variant.priceCents, 1999);
      expect(variant.stockQuantity, 25);
      expect(variant.optionValues, {'Color': 'Red', 'Size': 'L'});
      expect(variant.isActive, true);
    });

    test('toJson roundtrip', () {
      final variant = ProductVariant.fromJson({
        'variantId': 'v2',
        'stockQuantity': 0,
        'optionValues': {'Size': 'S'},
      });
      final json = variant.toJson();
      expect(json['variantId'], 'v2');
      expect(json['stockQuantity'], 0);
    });
  });

  group('ProductQuestion serialization', () {
    test('fromJson and toJson', () {
      final json = {
        'questionId': 'q1',
        'productId': 'p1',
        'sellerId': 's1',
        'askerId': 'b1',
        'question': 'Is this waterproof?',
        'answer': 'Yes!',
        'answeredAt': '2026-02-01T00:00:00.000',
        'answeredBy': 's1',
        'isAnswered': true,
        'upvotes': 5,
        'createdAt': '2026-01-20T00:00:00.000',
      };
      final q = ProductQuestion.fromJson(json);
      expect(q.questionId, 'q1');
      expect(q.question, 'Is this waterproof?');
      expect(q.answer, 'Yes!');
      expect(q.isAnswered, true);
      expect(q.upvotes, 5);

      final output = q.toJson();
      expect(output['questionId'], 'q1');
    });

    test('fromJson without answer', () {
      final json = {
        'questionId': 'q2',
        'productId': 'p1',
        'sellerId': 's1',
        'askerId': 'b2',
        'question': 'Size guide?',
        'createdAt': '2026-01-20T00:00:00.000',
      };
      final q = ProductQuestion.fromJson(json);
      expect(q.answer, isNull);
      expect(q.answeredAt, isNull);
      expect(q.isAnswered, false);
      expect(q.upvotes, 0);
    });
  });

  group('SupplierInfo serialization', () {
    test('fromJson and toJson', () {
      final json = {
        'type': 'aliexpress',
        'supplierUrl': 'https://aliexpress.com/item/123',
        'supplierSku': 'ALI-123',
        'cost': 5.99,
        'currency': 'USD',
        'shippingDays': '7-15',
        'hasTracking': true,
        'notes': 'Good supplier',
      };
      final info = SupplierInfo.fromJson(json);
      expect(info.type, 'aliexpress');
      expect(info.supplierUrl, 'https://aliexpress.com/item/123');
      expect(info.cost, 5.99);
      expect(info.currency, 'USD');
      expect(info.hasTracking, true);

      final output = info.toJson();
      expect(output['type'], 'aliexpress');
    });
  });

  group('SellerWarehouse serialization', () {
    test('fromJson and toJson', () {
      final json = {
        'warehouseId': 'wh1',
        'label': 'Main Warehouse',
        'type': 'warehouse',
        'address': {
          'street': '123 Main',
          'city': 'Toronto',
          'state': 'ON',
          'postalCode': 'M1M 1M1',
          'country': 'CA',
        },
        'isDefault': true,
        'createdAt': '2026-01-01T00:00:00.000',
      };
      final wh = SellerWarehouse.fromJson(json);
      expect(wh.warehouseId, 'wh1');
      expect(wh.label, 'Main Warehouse');
      expect(wh.isDefault, true);
      expect(wh.type, 'warehouse');
      expect(wh.address.city, 'Toronto');

      final output = wh.toJson();
      expect(output['warehouseId'], 'wh1');
    });
  });

  group('Product with nested objects', () {
    test('fromJson with supplier and inventory', () {
      final json = {
        'productId': 'p3',
        'name': 'Dropship Product',
        'price': 49.99,
        'description': 'From AliExpress',
        'imageUrls': ['img.jpg'],
        'sellerId': 's3',
        'categoryId': 3,
        'stockQuantity': 100,
        'createdAt': '2026-01-01T00:00:00.000',
        'supplier': {
          'type': 'aliexpress',
          'supplierUrl': 'https://ali.com/item',
          'supplierSku': 'ALI-456',
          'cost': 10.0,
          'currency': 'USD',
        },
        'inventory': {
          'managed': true,
          'trackQuantity': true,
          'allowBackorder': false,
          'lowStockThreshold': 3,
        },
        'deliveryOptions': [
          {
            'type': 'standard',
            'description': 'Standard Shipping',
            'costCents': 500,
            'estimatedDays': 5,
          },
        ],
        'variants': [
          {
            'variantId': 'v1',
            'stockQuantity': 50,
            'optionValues': {'Color': 'Black'},
          },
        ],
        'variantOptions': [
          {
            'name': 'Color',
            'values': ['Black', 'White'],
          },
        ],
      };
      final product = Product.fromJson(json);
      expect(product.supplier, isNotNull);
      expect(product.supplier!.type, 'aliexpress');
      expect(product.inventory, isNotNull);
      expect(product.inventory!.managed, true);
      expect(product.deliveryOptions.length, 1);
      expect(product.variants.length, 1);
      expect(product.variantOptions.length, 1);
    });

    test('toJson preserves nested sellerAddress', () {
      final product = Product.fromJson({
        'productId': 'p4',
        'name': 'Nested',
        'price': 19.99,
        'description': 'Test',
        'imageUrls': <String>[],
        'sellerId': 's4',
        'categoryId': 1,
        'stockQuantity': 10,
        'createdAt': '2026-01-01T00:00:00.000',
        'sellerAddress': {
          'street': '123 Main St',
          'city': 'Toronto',
          'state': 'ON',
          'postalCode': 'M5V 1A1',
          'country': 'CA',
        },
      });
      final json = product.toJson();
      expect(json['sellerAddress'], isNotNull);
    });
  });

  // ── Order Models ──

  group('Order serialization', () {
    test('fromJson with all fields', () {
      final json = {
        'orderId': 'o1',
        'userId': 'u1',
        'items': [
          {
            'productId': 'p1',
            'name': 'Product 1',
            'description': 'Desc',
            'price': 20.0,
            'quantity': 2,
            'imageUrls': ['img.jpg'],
            'sellerId': 's1',
          },
        ],
        'totalAmountCents': 5000,
        'subtotalCents': 4000,
        'shippingCostCents': 500,
        'taxAmountCents': 500,
        'taxes': <String, dynamic>{'GST': 2.5, 'PST': 0.0, 'HST': 0.0, 'QST': 0.0},
        'createdAt': '2026-01-01T00:00:00.000',
        'shippingAddress': {
          'street': '456 Oak Ave',
          'city': 'Vancouver',
          'state': 'BC',
          'postalCode': 'V6B 1A1',
          'country': 'CA',
        },
        'orderStatus': 'pending',
        'paymentStatus': 'paid',
        'stripePaymentIntentId': 'pi_123',
        'deliveryInstructions': 'Leave at door',
        'sellerIds': ['s1'],
        'productIds': ['p1'],
        'couponCode': 'SAVE10',
        'discountAmountCents': 500,
        'confirmedByClient': true,
        'confirmedAt': '2026-01-05T00:00:00.000',
        'capturedAt': '2026-01-02T00:00:00.000',
        'expiresAt': '2026-01-10T00:00:00.000',
        'autoConfirmed': true,
        'autoCaptured': false,
        'refundAmountCents': 0,
        'stockRestored': false,
        'requiresManualReview': false,
        'fraudScore': 10,
      };
      final order = Order.fromJson(json);
      expect(order.orderId, 'o1');
      expect(order.userId, 'u1');
      expect(order.totalAmountCents, 5000);
      expect(order.items.length, 1);
      expect(order.items.first.productId, 'p1');
      expect(order.shippingAddress, isNotNull);
      expect(order.stripePaymentIntentId, 'pi_123');
      expect(order.deliveryInstructions, 'Leave at door');
      expect(order.couponCode, 'SAVE10');
      expect(order.discountAmountCents, 500);
      expect(order.confirmedByClient, true);
      expect(order.autoConfirmed, true);
      expect(order.fraudScore, 10);
    });

    test('toJson roundtrip', () {
      final order = Order.fromJson({
        'orderId': 'o2',
        'userId': 'u2',
        'totalAmountCents': 3000,
        'subtotalCents': 2500,
        'taxAmountCents': 250,
        'shippingCostCents': 250,
        'taxes': <String, dynamic>{'GST': 0.0, 'PST': 0.0, 'HST': 0.0, 'QST': 0.0},
        'createdAt': '2026-02-01T00:00:00.000',
        'items': <Map<String, dynamic>>[],
      });
      final json = order.toJson();
      expect(json['orderId'], 'o2');
      expect(json['totalAmountCents'], 3000);
    });

    test('fromJson with minimal fields', () {
      final order = Order.fromJson({
        'orderId': 'o3',
        'userId': 'u3',
        'totalAmountCents': 1000,
        'subtotalCents': 800,
        'taxAmountCents': 100,
        'shippingCostCents': 100,
        'taxes': <String, dynamic>{'GST': 0.0, 'PST': 0.0, 'HST': 0.0, 'QST': 0.0},
        'createdAt': '2026-01-01T00:00:00.000',
        'items': <Map<String, dynamic>>[],
      });
      expect(order.stripePaymentIntentId, isNull);
      expect(order.deliveryInstructions, isNull);
      expect(order.couponCode, isNull);
      expect(order.confirmedByClient, false);
      expect(order.autoConfirmed, false);
      expect(order.requiresManualReview, false);
      expect(order.fraudScore, 0);
      expect(order.version, 1);
      expect(order.schemaVersion, 1);
    });
  });

  group('OrderItem serialization', () {
    test('fromJson and toJson', () {
      final json = {
        'productId': 'p1',
        'name': 'Test Item',
        'description': 'A desc',
        'price': 15.0,
        'quantity': 3,
        'imageUrls': ['item.jpg'],
        'sellerId': 's1',
        'status': 'pending',
        'isPerishable': true,
        'isDigital': false,
        'variantId': 'v1',
        'variantOptions': {'Size': 'M'},
        'weightKg': 0.5,
        'estimatedShipDays': 2,
        'taxCode': 'TAX001',
        'buyerNote': 'Handle with care',
      };
      final item = OrderItem.fromJson(json);
      expect(item.productId, 'p1');
      expect(item.name, 'Test Item');
      expect(item.quantity, 3);
      expect(item.price, 15.0);
      expect(item.isPerishable, true);
      expect(item.variantId, 'v1');
      expect(item.buyerNote, 'Handle with care');

      final output = item.toJson();
      expect(output['productId'], 'p1');
      expect(output['quantity'], 3);
    });

    test('fromJson with minimal fields', () {
      final item = OrderItem.fromJson({
        'productId': 'p2',
        'name': 'Minimal',
        'description': 'D',
        'price': 5.0,
        'quantity': 1,
        'imageUrls': <String>[],
        'sellerId': 's2',
      });
      expect(item.status, 'pending');
      expect(item.isPerishable, false);
      expect(item.isDigital, false);
      expect(item.freeShipping, false);
      expect(item.confirmedByBuyer, false);
      expect(item.digitalUnlocked, false);
      expect(item.estimatedShipDays, 3);
      expect(item.minimumOrderQuantity, 1);
    });
  });

  group('Address serialization', () {
    test('fromJson and toJson', () {
      final json = {
        'street': '100 King St',
        'city': 'Toronto',
        'state': 'ON',
        'postalCode': 'M5V 2T6',
        'country': 'CA',
        'apartment': '12B',
      };
      final address = Address.fromJson(json);
      expect(address.street, '100 King St');
      expect(address.city, 'Toronto');
      expect(address.state, 'ON');
      expect(address.postalCode, 'M5V 2T6');
      expect(address.country, 'CA');
      expect(address.apartment, '12B');

      final output = address.toJson();
      expect(output['street'], '100 King St');
      expect(output['apartment'], '12B');
    });
  });

  group('ProductCreate serialization', () {
    test('fromJson with all fields', () {
      final json = {
        'name': 'New Product',
        'price': 25.0,
        'description': 'Fresh product',
        'imageUrls': ['img1.jpg'],
        'sellerId': 's1',
        'categoryId': 2,
        'stockQuantity': 100,
        'isDigital': false,
        'isPerishable': false,
        'isLocalDeliveryOnly': false,
        'estimatedShipDays': 5,
        'keywords': ['new', 'fresh'],
      };
      final create = ProductCreate.fromJson(json);
      expect(create.name, 'New Product');
      expect(create.price, 25.0);
      expect(create.sellerId, 's1');
      expect(create.stockQuantity, 100);
    });

    test('toJson roundtrip', () {
      final create = ProductCreate.fromJson({
        'name': 'Roundtrip',
        'price': 15.0,
        'description': 'Test',
        'imageUrls': <String>[],
        'sellerId': 's2',
        'categoryId': 1,
        'stockQuantity': 50,
      });
      final json = create.toJson();
      expect(json['name'], 'Roundtrip');
      expect(json['price'], 15.0);
    });
  });

  group('Product digital fields', () {
    test('product with digital type', () {
      final product = Product.fromJson({
        'productId': 'p11',
        'name': 'Ebook',
        'price': 5.0,
        'description': 'Digital book',
        'imageUrls': <String>[],
        'sellerId': 's1',
        'categoryId': 1,
        'stockQuantity': 999,
        'createdAt': '2026-01-01T00:00:00.000',
        'isDigital': true,
        'digitalType': 'ebook',
        'slug': 'my-ebook',
        'digitalBuilds': {'pdf': 'https://dl.com/book.pdf'},
        'deviceLimit': 3,
      });
      expect(product.isDigital, true);
      expect(product.digitalType, 'ebook');
      expect(product.slug, 'my-ebook');
      expect(product.deviceLimit, 3);
      expect(product.digitalBuilds!['pdf'], 'https://dl.com/book.pdf');
    });
  });
}
