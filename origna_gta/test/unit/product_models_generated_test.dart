import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

void main() {
  // =========================================================================
  // InventoryConfig
  // =========================================================================
  group('InventoryConfig fromJson/toJson', () {
    test('roundtrip with all fields', () {
      final alertTime = DateTime(2026, 3, 1, 10, 30);
      final json = <String, dynamic>{
        'managed': false,
        'trackQuantity': false,
        'allowBackorder': true,
        'lowStockThreshold': 10,
        'lastLowStockAlertAt': alertTime.toIso8601String(),
        'reservationHoldMinutes': 60,
      };
      final model = InventoryConfig.fromJson(json);
      expect(model.managed, false);
      expect(model.trackQuantity, false);
      expect(model.allowBackorder, true);
      expect(model.lowStockThreshold, 10);
      expect(model.lastLowStockAlertAt, alertTime);
      expect(model.reservationHoldMinutes, 60);

      final out = model.toJson();
      expect(out['managed'], false);
      expect(out['trackQuantity'], false);
      expect(out['allowBackorder'], true);
      expect(out['lowStockThreshold'], 10);
      expect(out['lastLowStockAlertAt'], alertTime.toIso8601String());
      expect(out['reservationHoldMinutes'], 60);
    });

    test('defaults when fields missing', () {
      final model = InventoryConfig.fromJson(<String, dynamic>{});
      expect(model.managed, true);
      expect(model.trackQuantity, true);
      expect(model.allowBackorder, false);
      expect(model.lowStockThreshold, 5);
      expect(model.lastLowStockAlertAt, isNull);
      expect(model.reservationHoldMinutes, 30);
    });

    test('null lastLowStockAlertAt serializes to null', () {
      const model = InventoryConfig();
      final out = model.toJson();
      expect(out['lastLowStockAlertAt'], isNull);
    });
  });

  // =========================================================================
  // SupplierInfo
  // =========================================================================
  group('SupplierInfo fromJson/toJson', () {
    test('roundtrip with all fields', () {
      final json = <String, dynamic>{
        'type': SupplierTypeValues.aliexpress,
        'supplierSku': 'SKU-123',
        'supplierUrl': 'https://aliexpress.com/item/123',
        'cost': 12.50,
        'currency': 'CNY',
        'shippingDays': '7-15',
        'hasTracking': true,
        'notes': 'Fast seller',
      };
      final model = SupplierInfo.fromJson(json);
      expect(model.type, SupplierTypeValues.aliexpress);
      expect(model.supplierSku, 'SKU-123');
      expect(model.supplierUrl, 'https://aliexpress.com/item/123');
      expect(model.cost, 12.50);
      expect(model.currency, 'CNY');
      expect(model.shippingDays, '7-15');
      expect(model.hasTracking, true);
      expect(model.notes, 'Fast seller');

      final out = model.toJson();
      expect(out['type'], SupplierTypeValues.aliexpress);
      expect(out['supplierSku'], 'SKU-123');
      expect(out['cost'], 12.50);
      expect(out['currency'], 'CNY');
      expect(out['hasTracking'], true);
    });

    test('defaults when optional fields missing', () {
      final json = <String, dynamic>{'type': 'other'};
      final model = SupplierInfo.fromJson(json);
      expect(model.supplierSku, isNull);
      expect(model.supplierUrl, isNull);
      expect(model.cost, isNull);
      expect(model.currency, 'USD');
      expect(model.shippingDays, isNull);
      expect(model.hasTracking, false);
      expect(model.notes, isNull);
    });
  });

  // =========================================================================
  // ShippingQuantityDiscount
  // =========================================================================
  group('ShippingQuantityDiscount fromJson/toJson', () {
    test('roundtrip with all fields', () {
      final json = <String, dynamic>{
        'minQuantity': 10,
        'discountType': DiscountTypeValues.flatRate,
        'discountValue': 5.0,
        'label': 'Bulk deal',
      };
      final model = ShippingQuantityDiscount.fromJson(json);
      expect(model.minQuantity, 10);
      expect(model.discountType, DiscountTypeValues.flatRate);
      expect(model.discountValue, 5.0);
      expect(model.label, 'Bulk deal');

      final out = model.toJson();
      expect(out['minQuantity'], 10);
      expect(out['discountType'], DiscountTypeValues.flatRate);
      expect(out['discountValue'], 5.0);
      expect(out['label'], 'Bulk deal');
    });

    test('defaults discountType to percent', () {
      final json = <String, dynamic>{
        'minQuantity': 5,
        'discountValue': 15.0,
      };
      final model = ShippingQuantityDiscount.fromJson(json);
      expect(model.discountType, DiscountTypeValues.percent);
      expect(model.label, isNull);
    });
  });

  // =========================================================================
  // SellerDeliveryOption
  // =========================================================================
  group('SellerDeliveryOption fromJson/toJson', () {
    test('roundtrip with all fields including nested quantityDiscounts', () {
      final json = <String, dynamic>{
        'type': DeliveryTypeValues.express,
        'description': 'Express 2-day',
        'costCents': 1500,
        'estimatedDays': 2,
        'quantityDiscounts': [
          {
            'minQuantity': 3,
            'discountType': DiscountTypeValues.percent,
            'discountValue': 10.0,
          },
        ],
        'maxItemsPerShipment': 5,
        'additionalItemCostCents': 200,
        'availableNationwide': false,
      };
      final model = SellerDeliveryOption.fromJson(json);
      expect(model.type, DeliveryTypeValues.express);
      expect(model.description, 'Express 2-day');
      expect(model.costCents, 1500);
      expect(model.estimatedDays, 2);
      expect(model.quantityDiscounts.length, 1);
      expect(model.quantityDiscounts.first.minQuantity, 3);
      expect(model.maxItemsPerShipment, 5);
      expect(model.additionalItemCostCents, 200);
      expect(model.availableNationwide, false);

      final out = model.toJson();
      expect(out['type'], DeliveryTypeValues.express);
      expect(out['costCents'], 1500);
    });

    test('defaults when all optional fields missing', () {
      final model = SellerDeliveryOption.fromJson(<String, dynamic>{});
      expect(model.type, DeliveryTypeValues.standard);
      expect(model.description, '');
      expect(model.costCents, 0);
      expect(model.estimatedDays, 3);
      expect(model.quantityDiscounts, isEmpty);
      expect(model.maxItemsPerShipment, 0);
      expect(model.additionalItemCostCents, 0);
      expect(model.availableNationwide, true);
    });
  });

  // =========================================================================
  // VariantOption
  // =========================================================================
  group('VariantOption fromJson/toJson', () {
    test('roundtrip', () {
      final json = <String, dynamic>{
        'name': 'Color',
        'values': ['Red', 'Blue', 'Green'],
      };
      final model = VariantOption.fromJson(json);
      expect(model.name, 'Color');
      expect(model.values, ['Red', 'Blue', 'Green']);

      final out = model.toJson();
      expect(out['name'], 'Color');
      expect(out['values'], ['Red', 'Blue', 'Green']);
    });

    test('empty values list', () {
      final json = <String, dynamic>{
        'name': 'Material',
        'values': <String>[],
      };
      final model = VariantOption.fromJson(json);
      expect(model.values, isEmpty);
    });
  });

  // =========================================================================
  // ProductVariant
  // =========================================================================
  group('ProductVariant fromJson/toJson', () {
    test('roundtrip with all fields', () {
      final json = <String, dynamic>{
        'variantId': 'var-001',
        'optionValues': {'size': 'L', 'color': 'Red'},
        'priceCents': 4999,
        'stockQuantity': 25,
        'sku': 'SKU-VAR-001',
        'isActive': false,
      };
      final model = ProductVariant.fromJson(json);
      expect(model.variantId, 'var-001');
      expect(model.optionValues, {'size': 'L', 'color': 'Red'});
      expect(model.priceCents, 4999);
      expect(model.stockQuantity, 25);
      expect(model.sku, 'SKU-VAR-001');
      expect(model.isActive, false);

      final out = model.toJson();
      expect(out['variantId'], 'var-001');
      expect(out['optionValues'], {'size': 'L', 'color': 'Red'});
      expect(out['priceCents'], 4999);
      expect(out['stockQuantity'], 25);
      expect(out['sku'], 'SKU-VAR-001');
      expect(out['isActive'], false);
    });

    test('defaults: variantId empty, isActive true, nullable fields null', () {
      final json = <String, dynamic>{
        'optionValues': {'size': 'S'},
        'stockQuantity': 0,
      };
      final model = ProductVariant.fromJson(json);
      expect(model.variantId, '');
      expect(model.isActive, true);
      expect(model.priceCents, isNull);
      expect(model.sku, isNull);
    });
  });

  // =========================================================================
  // ProductQuestion
  // =========================================================================
  group('ProductQuestion fromJson/toJson', () {
    test('roundtrip with all fields', () {
      final created = DateTime(2026, 1, 15, 9, 0);
      final answered = DateTime(2026, 1, 16, 14, 30);
      final json = <String, dynamic>{
        'questionId': 'q1',
        'productId': 'p1',
        'sellerId': 's1',
        'askerId': 'u1',
        'question': 'Is this waterproof?',
        'answer': 'Yes, IPX7 rated.',
        'answeredAt': answered.toIso8601String(),
        'answeredBy': 's1',
        'isAnswered': true,
        'upvotes': 5,
        'createdAt': created.toIso8601String(),
      };
      final model = ProductQuestion.fromJson(json);
      expect(model.questionId, 'q1');
      expect(model.productId, 'p1');
      expect(model.answer, 'Yes, IPX7 rated.');
      expect(model.answeredAt, answered);
      expect(model.isAnswered, true);
      expect(model.upvotes, 5);
      expect(model.createdAt, created);

      final out = model.toJson();
      expect(out['questionId'], 'q1');
      expect(out['answer'], 'Yes, IPX7 rated.');
      expect(out['answeredAt'], answered.toIso8601String());
      expect(out['createdAt'], created.toIso8601String());
    });

    test('unanswered question defaults', () {
      final created = DateTime(2026, 2, 1);
      final json = <String, dynamic>{
        'questionId': 'q2',
        'productId': 'p2',
        'sellerId': 's2',
        'askerId': 'u2',
        'question': 'Does it come with batteries?',
        'createdAt': created.toIso8601String(),
      };
      final model = ProductQuestion.fromJson(json);
      expect(model.answer, isNull);
      expect(model.answeredAt, isNull);
      expect(model.answeredBy, isNull);
      expect(model.isAnswered, false);
      expect(model.upvotes, 0);
    });

    test('toJson null answer fields serialize as null', () {
      final model = ProductQuestion(
        questionId: 'q3',
        productId: 'p3',
        sellerId: 's3',
        askerId: 'u3',
        question: 'Test?',
        createdAt: DateTime(2026, 3, 1),
      );
      final out = model.toJson();
      expect(out['answer'], isNull);
      expect(out['answeredAt'], isNull);
      expect(out['answeredBy'], isNull);
      expect(out['isAnswered'], false);
      expect(out['upvotes'], 0);
    });
  });

  // =========================================================================
  // SellerWarehouse
  // =========================================================================
  group('SellerWarehouse fromJson/toJson', () {
    test('roundtrip with all fields', () {
      final created = DateTime(2026, 1, 1);
      final json = <String, dynamic>{
        'warehouseId': 'wh-01',
        'label': 'Toronto Main',
        'type': WarehouseTypeValues.warehouse,
        'address': {
          'street': '100 King St W',
          'city': 'Toronto',
          'state': 'ON',
          'postalCode': 'M5X 1A9',
          'country': 'Canada',
        },
        'isDefault': true,
        'createdAt': created.toIso8601String(),
      };
      final model = SellerWarehouse.fromJson(json);
      expect(model.warehouseId, 'wh-01');
      expect(model.label, 'Toronto Main');
      expect(model.type, WarehouseTypeValues.warehouse);
      expect(model.address.city, 'Toronto');
      expect(model.isDefault, true);
      expect(model.createdAt, created);

      final out = model.toJson();
      expect(out['warehouseId'], 'wh-01');
      expect(out['label'], 'Toronto Main');
      expect(out['isDefault'], true);
      expect(out['createdAt'], created.toIso8601String());
    });

    test('defaults: type warehouse, isDefault false, createdAt null', () {
      final json = <String, dynamic>{
        'warehouseId': 'wh-02',
        'label': 'Home',
        'address': {
          'street': '1 Yonge St',
          'city': 'Toronto',
          'state': 'ON',
          'postalCode': 'M5E 1W7',
        },
      };
      final model = SellerWarehouse.fromJson(json);
      expect(model.type, 'warehouse');
      expect(model.isDefault, false);
      expect(model.createdAt, isNull);
    });
  });

  // =========================================================================
  // Product — full model
  // =========================================================================
  group('Product fromJson/toJson', () {
    final now = DateTime(2026, 3, 9, 12, 0);

    Map<String, dynamic> _minimalProductJson() => {
          'productId': 'prod-001',
          'name': 'Maple Syrup',
          'price': 24.99,
          'description': 'Pure Canadian maple syrup',
          'imageUrls': ['https://img.example.com/maple.jpg'],
          'sellerId': 'seller-001',
          'categoryId': 5,
          'stockQuantity': 100,
          'createdAt': now.toIso8601String(),
        };

    test('roundtrip with minimal required fields + defaults', () {
      final json = _minimalProductJson();
      final model = Product.fromJson(json);

      expect(model.productId, 'prod-001');
      expect(model.name, 'Maple Syrup');
      expect(model.price, 24.99);
      expect(model.description, 'Pure Canadian maple syrup');
      expect(model.imageUrls, ['https://img.example.com/maple.jpg']);
      expect(model.sellerId, 'seller-001');
      expect(model.categoryId, 5);
      expect(model.stockQuantity, 100);
      expect(model.createdAt, now);

      // Verify defaults
      expect(model.rating, 0.0);
      expect(model.ratingCount, 0);
      expect(model.lifecycleStatus, ProductLifecycleStatusValues.draft);
      expect(model.isLocalDeliveryOnly, false);
      expect(model.isPerishable, false);
      expect(model.estimatedShipDays, 3);
      expect(model.deliveryOptions, isEmpty);
      expect(model.minimumOrderQuantity, 1);
      expect(model.freeShipping, false);
      expect(model.isDigital, false);
      expect(model.isAgeRestricted, false);
      expect(model.keywords, isEmpty);
      expect(model.trendingScore, 0);
      expect(model.viewCount, 0);
      expect(model.purchaseCount, 0);
      expect(model.isTrending, false);
      expect(model.hasVariants, false);
      expect(model.variants, isEmpty);
      expect(model.variantOptions, isEmpty);

      // Nullable fields should be null
      expect(model.nameF, isNull);
      expect(model.priceCents, isNull);
      expect(model.compareAtPrice, isNull);
      expect(model.descriptionF, isNull);
      expect(model.videoUrl, isNull);
      expect(model.videoDurationSeconds, isNull);
      expect(model.madeInCountry, isNull);
      expect(model.sellerAddress, isNull);
      expect(model.weightKg, isNull);
      expect(model.weightUnit, isNull);
      expect(model.lengthCm, isNull);
      expect(model.widthCm, isNull);
      expect(model.heightCm, isNull);
      expect(model.dimensionUnit, isNull);
      expect(model.digitalType, isNull);
      expect(model.slug, isNull);
      expect(model.digitalBuilds, isNull);
      expect(model.deviceLimit, isNull);
      expect(model.taxCode, isNull);
      expect(model.approvalRejectionReason, isNull);
      expect(model.cost, isNull);
      expect(model.supplierSku, isNull);
      expect(model.supplierUrl, isNull);
      expect(model.supplier, isNull);
      expect(model.inventory, isNull);
      expect(model.sellerSku, isNull);
      expect(model.warehouseIds, isNull);
      expect(model.shipFromCity, isNull);
      expect(model.shipFromProvince, isNull);
      expect(model.shipFromCountry, isNull);
      expect(model.shipFromCountries, isNull);
      expect(model.trendingAt, isNull);
      expect(model.subcategory, isNull);
      expect(model.condition, isNull);
      expect(model.warehouseStockMap, isNull);
      expect(model.updatedAt, isNull);

      final out = model.toJson();
      expect(out['productId'], 'prod-001');
      expect(out['name'], 'Maple Syrup');
      expect(out['price'], 24.99);
      expect(out['createdAt'], now.toIso8601String());
    });

    test('roundtrip with ALL optional fields populated', () {
      final updatedAt = DateTime(2026, 3, 9, 15, 0);
      final trendingAt = DateTime(2026, 3, 8);
      final json = <String, dynamic>{
        ..._minimalProductJson(),
        'nameF': 'Sirop d\'erable',
        'priceCents': 2499,
        'compareAtPrice': 34.99,
        'descriptionF': 'Sirop d\'erable pur du Canada',
        'videoUrl': 'https://vid.example.com/maple.mp4',
        'videoDurationSeconds': 30,
        'madeInCountry': 'Canada',
        'sellerAddress': {
          'street': '123 Rue Principale',
          'city': 'Montreal',
          'state': 'QC',
          'postalCode': 'H2X 1Y4',
        },
        'rating': 4.5,
        'ratingCount': 120,
        'lifecycleStatus': ProductLifecycleStatusValues.active,
        'weightKg': 0.5,
        'weightUnit': 'kg',
        'lengthCm': 10.0,
        'widthCm': 5.0,
        'heightCm': 15.0,
        'dimensionUnit': 'cm',
        'isLocalDeliveryOnly': true,
        'isPerishable': true,
        'estimatedShipDays': 1,
        'deliveryOptions': [
          {
            'type': DeliveryTypeValues.sameDay,
            'description': 'Same-day delivery',
            'costCents': 500,
            'estimatedDays': 0,
          },
        ],
        'minimumOrderQuantity': 2,
        'freeShipping': true,
        'isDigital': false,
        'isAgeRestricted': true,
        'digitalType': 'ebook',
        'slug': 'maple-syrup-500ml',
        'digitalBuilds': {'ios': 'v1.0', 'android': 'v1.0'},
        'deviceLimit': 3,
        'taxCode': 'food_basic',
        'keywords': ['maple', 'syrup', 'canadian'],
        'approvalRejectionReason': null,
        'cost': 8.50,
        'supplierSku': 'SUPP-MAPLE-001',
        'supplierUrl': 'https://supplier.example.com/maple',
        'supplier': {
          'type': SupplierTypeValues.local,
          'cost': 8.50,
          'currency': 'CAD',
          'hasTracking': true,
        },
        'inventory': {
          'managed': true,
          'trackQuantity': true,
          'allowBackorder': false,
          'lowStockThreshold': 10,
          'reservationHoldMinutes': 15,
        },
        'sellerSku': 'MY-MAPLE-001',
        'warehouseIds': ['wh-01', 'wh-02'],
        'shipFromCity': 'Montreal',
        'shipFromProvince': 'QC',
        'shipFromCountry': 'Canada',
        'shipFromCountries': ['Canada'],
        'trendingScore': 85,
        'viewCount': 1200,
        'purchaseCount': 340,
        'isTrending': true,
        'trendingAt': trendingAt.toIso8601String(),
        'hasVariants': true,
        'variants': [
          {
            'variantId': 'v-250ml',
            'optionValues': {'size': '250ml'},
            'priceCents': 1499,
            'stockQuantity': 50,
            'sku': 'MAPLE-250',
            'isActive': true,
          },
          {
            'variantId': 'v-500ml',
            'optionValues': {'size': '500ml'},
            'priceCents': 2499,
            'stockQuantity': 50,
            'sku': 'MAPLE-500',
            'isActive': true,
          },
        ],
        'variantOptions': [
          {
            'name': 'size',
            'values': ['250ml', '500ml'],
          },
        ],
        'subcategory': 'condiments',
        'condition': 'new',
        'warehouseStockMap': {'wh-01': 60, 'wh-02': 40},
        'updatedAt': updatedAt.toIso8601String(),
      };

      final model = Product.fromJson(json);
      expect(model.nameF, 'Sirop d\'erable');
      expect(model.priceCents, 2499);
      expect(model.compareAtPrice, 34.99);
      expect(model.sellerAddress?.city, 'Montreal');
      expect(model.rating, 4.5);
      expect(model.ratingCount, 120);
      expect(model.lifecycleStatus, ProductLifecycleStatusValues.active);
      expect(model.weightKg, 0.5);
      expect(model.isLocalDeliveryOnly, true);
      expect(model.isPerishable, true);
      expect(model.deliveryOptions.length, 1);
      expect(model.deliveryOptions.first.type, DeliveryTypeValues.sameDay);
      expect(model.deliveryOptions.first.costCents, 500);
      expect(model.freeShipping, true);
      expect(model.isAgeRestricted, true);
      expect(model.digitalBuilds, {'ios': 'v1.0', 'android': 'v1.0'});
      expect(model.deviceLimit, 3);
      expect(model.keywords, ['maple', 'syrup', 'canadian']);
      expect(model.supplier?.type, SupplierTypeValues.local);
      expect(model.supplier?.currency, 'CAD');
      expect(model.inventory?.lowStockThreshold, 10);
      expect(model.warehouseIds, ['wh-01', 'wh-02']);
      expect(model.shipFromCity, 'Montreal');
      expect(model.trendingScore, 85);
      expect(model.isTrending, true);
      expect(model.trendingAt, trendingAt);
      expect(model.hasVariants, true);
      expect(model.variants.length, 2);
      expect(model.variants[0].variantId, 'v-250ml');
      expect(model.variants[1].optionValues['size'], '500ml');
      expect(model.variantOptions.first.values, ['250ml', '500ml']);
      expect(model.subcategory, 'condiments');
      expect(model.condition, 'new');
      expect(model.warehouseStockMap, {'wh-01': 60, 'wh-02': 40});
      expect(model.updatedAt, updatedAt);

      // toJson roundtrip check on key fields
      final out = model.toJson();
      expect(out['nameF'], 'Sirop d\'erable');
      expect(out['priceCents'], 2499);
      expect(out['compareAtPrice'], 34.99);
      expect(out['lifecycleStatus'], ProductLifecycleStatusValues.active);
      expect(out['trendingScore'], 85);
      expect(out['isTrending'], true);
      expect(out['trendingAt'], trendingAt.toIso8601String());
      expect(out['updatedAt'], updatedAt.toIso8601String());
      expect(out['keywords'], ['maple', 'syrup', 'canadian']);
      expect(out['hasVariants'], true);
      expect(out['subcategory'], 'condiments');
      expect(out['warehouseStockMap'], {'wh-01': 60, 'wh-02': 40});
    });

    test('empty imageUrls list accepted', () {
      final json = <String, dynamic>{
        ..._minimalProductJson(),
        'imageUrls': <String>[],
      };
      final model = Product.fromJson(json);
      expect(model.imageUrls, isEmpty);
    });

    test('empty keywords list from missing key', () {
      final json = _minimalProductJson();
      // keywords not in json => defaults to []
      final model = Product.fromJson(json);
      expect(model.keywords, isEmpty);
    });

    test('empty deliveryOptions list from missing key', () {
      final model = Product.fromJson(_minimalProductJson());
      expect(model.deliveryOptions, isEmpty);
    });

    test('empty variants and variantOptions from missing keys', () {
      final model = Product.fromJson(_minimalProductJson());
      expect(model.variants, isEmpty);
      expect(model.variantOptions, isEmpty);
    });

    test('numeric fields accept int and double via num coercion', () {
      final json = <String, dynamic>{
        ..._minimalProductJson(),
        'price': 10, // int instead of double
        'stockQuantity': 50.0, // double instead of int (num.toInt())
        'rating': 4, // int instead of double
        'ratingCount': 10.0,
      };
      final model = Product.fromJson(json);
      expect(model.price, 10.0);
      expect(model.stockQuantity, 50);
      expect(model.rating, 4.0);
      expect(model.ratingCount, 10);
    });

    test('nested sellerAddress roundtrips correctly', () {
      final json = <String, dynamic>{
        ..._minimalProductJson(),
        'sellerAddress': {
          'street': '456 Oak Ave',
          'apartment': 'Suite 200',
          'city': 'Vancouver',
          'state': 'BC',
          'postalCode': 'V6B 1A1',
          'country': 'Canada',
          'isDefault': true,
          'label': 'Office',
          'latitude': 49.2827,
          'longitude': -123.1207,
        },
      };
      final model = Product.fromJson(json);
      expect(model.sellerAddress, isNotNull);
      expect(model.sellerAddress!.street, '456 Oak Ave');
      expect(model.sellerAddress!.apartment, 'Suite 200');
      expect(model.sellerAddress!.city, 'Vancouver');
      expect(model.sellerAddress!.latitude, 49.2827);
    });

    test('nested supplier object roundtrips correctly', () {
      final json = <String, dynamic>{
        ..._minimalProductJson(),
        'supplier': {
          'type': SupplierTypeValues.temu,
          'supplierSku': 'TEMU-999',
          'cost': 3.99,
          'currency': 'USD',
          'shippingDays': '7-15',
          'hasTracking': false,
        },
      };
      final model = Product.fromJson(json);
      expect(model.supplier, isNotNull);
      expect(model.supplier!.type, SupplierTypeValues.temu);
      expect(model.supplier!.supplierSku, 'TEMU-999');
      expect(model.supplier!.cost, 3.99);
      expect(model.supplier!.shippingDays, '7-15');
    });

    test('nested inventory object roundtrips correctly', () {
      final json = <String, dynamic>{
        ..._minimalProductJson(),
        'inventory': {
          'managed': false,
          'trackQuantity': false,
          'allowBackorder': true,
          'lowStockThreshold': 20,
          'reservationHoldMinutes': 45,
        },
      };
      final model = Product.fromJson(json);
      expect(model.inventory, isNotNull);
      expect(model.inventory!.managed, false);
      expect(model.inventory!.allowBackorder, true);
      expect(model.inventory!.lowStockThreshold, 20);
    });

    test('warehouseStockMap with int values from num', () {
      final json = <String, dynamic>{
        ..._minimalProductJson(),
        'warehouseStockMap': {'wh-a': 100, 'wh-b': 200},
      };
      final model = Product.fromJson(json);
      expect(model.warehouseStockMap, {'wh-a': 100, 'wh-b': 200});
    });

    test('digitalBuilds map roundtrip', () {
      final json = <String, dynamic>{
        ..._minimalProductJson(),
        'digitalBuilds': {'windows': 'v2.1', 'mac': 'v2.1', 'linux': 'v2.0'},
      };
      final model = Product.fromJson(json);
      expect(model.digitalBuilds!.length, 3);
      expect(model.digitalBuilds!['linux'], 'v2.0');

      final out = model.toJson();
      expect(out['digitalBuilds'], {'windows': 'v2.1', 'mac': 'v2.1', 'linux': 'v2.0'});
    });

    test('shipFromCountries list roundtrip', () {
      final json = <String, dynamic>{
        ..._minimalProductJson(),
        'shipFromCountries': ['Canada', 'USA', 'Mexico'],
      };
      final model = Product.fromJson(json);
      expect(model.shipFromCountries, ['Canada', 'USA', 'Mexico']);
    });
  });

  // =========================================================================
  // ProductCreate
  // =========================================================================
  group('ProductCreate fromJson/toJson', () {
    Map<String, dynamic> _minimalCreateJson() => {
          'name': 'New Product',
          'price': 19.99,
          'description': 'A new product',
          'imageUrls': ['img.jpg'],
          'sellerId': 'seller-002',
          'categoryId': 3,
          'stockQuantity': 50,
        };

    test('roundtrip with minimal fields + defaults', () {
      final json = _minimalCreateJson();
      final model = ProductCreate.fromJson(json);

      expect(model.name, 'New Product');
      expect(model.price, 19.99);
      expect(model.sellerId, 'seller-002');
      expect(model.categoryId, 3);
      expect(model.stockQuantity, 50);

      // Defaults
      expect(model.rating, 0.0);
      expect(model.lifecycleStatus, ProductLifecycleStatusValues.draft);
      expect(model.isLocalDeliveryOnly, false);
      expect(model.isPerishable, false);
      expect(model.estimatedShipDays, 3);
      expect(model.deliveryOptions, isEmpty);
      expect(model.minimumOrderQuantity, 1);
      expect(model.freeShipping, false);
      expect(model.isDigital, false);
      expect(model.keywords, isEmpty);
      expect(model.hasVariants, false);
      expect(model.variants, isEmpty);
      expect(model.variantOptions, isEmpty);

      // Nullable fields
      expect(model.nameF, isNull);
      expect(model.compareAtPrice, isNull);
      expect(model.descriptionF, isNull);
      expect(model.videoUrl, isNull);
      expect(model.sellerAddress, isNull);
      expect(model.supplier, isNull);
      expect(model.inventory, isNull);
      expect(model.subcategory, isNull);

      final out = model.toJson();
      expect(out['name'], 'New Product');
      expect(out['price'], 19.99);
      expect(out['lifecycleStatus'], ProductLifecycleStatusValues.draft);
    });

    test('roundtrip with variants and delivery options', () {
      final json = <String, dynamic>{
        ..._minimalCreateJson(),
        'hasVariants': true,
        'variants': [
          {
            'variantId': 'cv1',
            'optionValues': {'color': 'Black'},
            'priceCents': 1999,
            'stockQuantity': 25,
          },
        ],
        'variantOptions': [
          {
            'name': 'color',
            'values': ['Black', 'White'],
          },
        ],
        'deliveryOptions': [
          {
            'type': DeliveryTypeValues.standard,
            'costCents': 799,
            'estimatedDays': 5,
          },
        ],
        'subcategory': 'electronics',
      };

      final model = ProductCreate.fromJson(json);
      expect(model.hasVariants, true);
      expect(model.variants.length, 1);
      expect(model.variants.first.optionValues['color'], 'Black');
      expect(model.variantOptions.first.values, ['Black', 'White']);
      expect(model.deliveryOptions.first.costCents, 799);
      expect(model.subcategory, 'electronics');
    });

    test('with supplier and inventory nested objects', () {
      final json = <String, dynamic>{
        ..._minimalCreateJson(),
        'supplier': {
          'type': SupplierTypeValues.cjdropshipping,
          'cost': 5.0,
        },
        'inventory': {
          'managed': false,
          'allowBackorder': true,
        },
        'warehouseIds': ['wh-x'],
        'shipFromCity': 'Shenzhen',
        'shipFromCountry': 'China',
        'shipFromCountries': ['China'],
      };

      final model = ProductCreate.fromJson(json);
      expect(model.supplier?.type, SupplierTypeValues.cjdropshipping);
      expect(model.supplier?.cost, 5.0);
      expect(model.inventory?.managed, false);
      expect(model.inventory?.allowBackorder, true);
      expect(model.warehouseIds, ['wh-x']);
      expect(model.shipFromCity, 'Shenzhen');
      expect(model.shipFromCountries, ['China']);
    });

    test('toJson includes all fields', () {
      final model = ProductCreate(
        name: 'Test',
        price: 9.99,
        description: 'Desc',
        imageUrls: ['a.jpg'],
        sellerId: 's1',
        categoryId: 1,
        stockQuantity: 10,
        nameF: 'TestFR',
        compareAtPrice: 14.99,
        digitalType: 'software',
        slug: 'test-product',
        digitalBuilds: {'web': 'v1'},
        deviceLimit: 5,
        taxCode: 'digital_standard',
        cost: 3.0,
        supplierSku: 'S-001',
        supplierUrl: 'https://example.com',
        sellerSku: 'MY-001',
      );

      final out = model.toJson();
      expect(out['nameF'], 'TestFR');
      expect(out['compareAtPrice'], 14.99);
      expect(out['digitalType'], 'software');
      expect(out['slug'], 'test-product');
      expect(out['digitalBuilds'], {'web': 'v1'});
      expect(out['deviceLimit'], 5);
      expect(out['taxCode'], 'digital_standard');
      expect(out['cost'], 3.0);
      expect(out['supplierSku'], 'S-001');
      expect(out['supplierUrl'], 'https://example.com');
      expect(out['sellerSku'], 'MY-001');
    });
  });

  // =========================================================================
  // SellerDeliveryOptionExtension — calculateCostForQuantity
  // =========================================================================
  group('SellerDeliveryOptionExtension calculateCostForQuantity', () {
    test('base cost without discounts', () {
      const option = SellerDeliveryOption(costCents: 1000);
      expect(option.calculateCostForQuantity(1), 10.0);
    });

    test('additional item cost after maxItemsPerShipment', () {
      const option = SellerDeliveryOption(
        costCents: 1000,
        maxItemsPerShipment: 2,
        additionalItemCostCents: 300,
      );
      // 2 base + 3 extra * $3 = $10 + $9 = $19
      expect(option.calculateCostForQuantity(5), 19.0);
    });

    test('percent discount applied', () {
      final option = SellerDeliveryOption(
        costCents: 1000,
        quantityDiscounts: [
          ShippingQuantityDiscount(
            minQuantity: 3,
            discountType: DiscountTypeValues.percent,
            discountValue: 20.0,
          ),
        ],
      );
      // $10 * (1 - 0.20) = $8
      expect(option.calculateCostForQuantity(5), 8.0);
    });

    test('fixed discount applied', () {
      final option = SellerDeliveryOption(
        costCents: 1000,
        quantityDiscounts: [
          ShippingQuantityDiscount(
            minQuantity: 2,
            discountType: DiscountTypeValues.fixed,
            discountValue: 3.0,
          ),
        ],
      );
      // $10 - $3 = $7
      expect(option.calculateCostForQuantity(2), 7.0);
    });

    test('flat rate discount replaces base cost', () {
      final option = SellerDeliveryOption(
        costCents: 1000,
        quantityDiscounts: [
          ShippingQuantityDiscount(
            minQuantity: 5,
            discountType: DiscountTypeValues.flatRate,
            discountValue: 4.99,
          ),
        ],
      );
      expect(option.calculateCostForQuantity(10), 4.99);
    });

    test('best discount selected from multiple', () {
      final option = SellerDeliveryOption(
        costCents: 2000,
        quantityDiscounts: [
          ShippingQuantityDiscount(
            minQuantity: 2,
            discountType: DiscountTypeValues.percent,
            discountValue: 10.0,
          ),
          ShippingQuantityDiscount(
            minQuantity: 5,
            discountType: DiscountTypeValues.percent,
            discountValue: 25.0,
          ),
        ],
      );
      // qty=3 => only minQty=2 applies => $20 * 0.90 = $18
      expect(option.calculateCostForQuantity(3), 18.0);
      // qty=5 => minQty=5 applies (higher minQuantity wins) => $20 * 0.75 = $15
      expect(option.calculateCostForQuantity(5), 15.0);
    });

    test('quantity 0 returns base cost', () {
      const option = SellerDeliveryOption(costCents: 500);
      expect(option.calculateCostForQuantity(0), 5.0);
    });

    test('fixed discount clamped to 0', () {
      final option = SellerDeliveryOption(
        costCents: 200,
        quantityDiscounts: [
          ShippingQuantityDiscount(
            minQuantity: 1,
            discountType: DiscountTypeValues.fixed,
            discountValue: 50.0,
          ),
        ],
      );
      // $2 - $50 clamped to $0
      expect(option.calculateCostForQuantity(1), 0.0);
    });
  });

  // =========================================================================
  // SellerDeliveryOptionExtension — getDiscountDescriptionForQuantity
  // =========================================================================
  group('SellerDeliveryOptionExtension getDiscountDescriptionForQuantity', () {
    test('returns custom label when present', () {
      final option = SellerDeliveryOption(
        quantityDiscounts: [
          ShippingQuantityDiscount(
            minQuantity: 2,
            discountValue: 10.0,
            label: 'Save on shipping!',
          ),
        ],
      );
      expect(option.getDiscountDescriptionForQuantity(5), 'Save on shipping!');
    });

    test('returns null when no discount applies', () {
      final option = SellerDeliveryOption(
        quantityDiscounts: [
          ShippingQuantityDiscount(minQuantity: 10, discountValue: 20.0),
        ],
      );
      expect(option.getDiscountDescriptionForQuantity(5), isNull);
    });

    test('returns null for empty discounts', () {
      const option = SellerDeliveryOption();
      expect(option.getDiscountDescriptionForQuantity(5), isNull);
    });

    test('generates percent description', () {
      final option = SellerDeliveryOption(
        quantityDiscounts: [
          ShippingQuantityDiscount(
            minQuantity: 3,
            discountType: DiscountTypeValues.percent,
            discountValue: 15.0,
          ),
        ],
      );
      final desc = option.getDiscountDescriptionForQuantity(3);
      expect(desc, contains('15%'));
      expect(desc, contains('3+'));
    });

    test('generates fixed description', () {
      final option = SellerDeliveryOption(
        quantityDiscounts: [
          ShippingQuantityDiscount(
            minQuantity: 2,
            discountType: DiscountTypeValues.fixed,
            discountValue: 2.50,
          ),
        ],
      );
      final desc = option.getDiscountDescriptionForQuantity(2);
      expect(desc, contains('\$2.50'));
    });

    test('generates flat rate description', () {
      final option = SellerDeliveryOption(
        quantityDiscounts: [
          ShippingQuantityDiscount(
            minQuantity: 4,
            discountType: DiscountTypeValues.flatRate,
            discountValue: 5.00,
          ),
        ],
      );
      final desc = option.getDiscountDescriptionForQuantity(4);
      expect(desc, contains('Flat'));
      expect(desc, contains('\$5.00'));
    });
  });

  // =========================================================================
  // ProductExtension helpers
  // =========================================================================
  group('ProductExtension', () {
    final now = DateTime(2026, 3, 9);

    Product _makeProduct({
      SupplierInfo? supplier,
      InventoryConfig? inventory,
      double? cost,
      String? supplierSku,
      String? supplierUrl,
      bool isDigital = false,
      bool isLocalDeliveryOnly = false,
      int stockQuantity = 100,
      double price = 25.0,
    }) =>
        Product(
          productId: 'p1',
          name: 'Test',
          price: price,
          description: 'Desc',
          imageUrls: ['img.jpg'],
          sellerId: 's1',
          categoryId: 1,
          stockQuantity: stockQuantity,
          createdAt: now,
          supplier: supplier,
          inventory: inventory,
          cost: cost,
          supplierSku: supplierSku,
          supplierUrl: supplierUrl,
          isDigital: isDigital,
          isLocalDeliveryOnly: isLocalDeliveryOnly,
        );

    test('allowsBackorder from inventory', () {
      expect(_makeProduct().allowsBackorder, false);
      expect(
        _makeProduct(inventory: const InventoryConfig(allowBackorder: true)).allowsBackorder,
        true,
      );
    });

    test('isInventoryManaged defaults to true', () {
      expect(_makeProduct().isInventoryManaged, true);
      expect(
        _makeProduct(inventory: const InventoryConfig(managed: false)).isInventoryManaged,
        false,
      );
    });

    test('isLowStock based on threshold', () {
      // stockQuantity=100 > threshold=5 => not low
      expect(_makeProduct(stockQuantity: 100).isLowStock, false);
      // stockQuantity=3 <= threshold=5 and > 0 => low
      expect(_makeProduct(stockQuantity: 3).isLowStock, true);
      // stockQuantity=0 => not low (out of stock, not low stock)
      expect(_makeProduct(stockQuantity: 0).isLowStock, false);
      // custom threshold
      expect(
        _makeProduct(
          stockQuantity: 15,
          inventory: const InventoryConfig(lowStockThreshold: 20),
        ).isLowStock,
        true,
      );
    });

    test('effectiveCost prefers supplier.cost over flat cost', () {
      expect(_makeProduct(cost: 5.0).effectiveCost, 5.0);
      expect(
        _makeProduct(
          cost: 5.0,
          supplier: const SupplierInfo(type: 'local', cost: 3.0),
        ).effectiveCost,
        3.0,
      );
      expect(_makeProduct().effectiveCost, isNull);
    });

    test('effectiveSupplierSku prefers supplier object', () {
      expect(_makeProduct(supplierSku: 'FLAT').effectiveSupplierSku, 'FLAT');
      expect(
        _makeProduct(
          supplierSku: 'FLAT',
          supplier: const SupplierInfo(type: 'local', supplierSku: 'OBJ'),
        ).effectiveSupplierSku,
        'OBJ',
      );
    });

    test('effectiveSupplierUrl prefers supplier object', () {
      expect(_makeProduct(supplierUrl: 'http://flat').effectiveSupplierUrl, 'http://flat');
      expect(
        _makeProduct(
          supplierUrl: 'http://flat',
          supplier: const SupplierInfo(type: 'local', supplierUrl: 'http://obj'),
        ).effectiveSupplierUrl,
        'http://obj',
      );
    });

    test('profit and marginPercent', () {
      expect(_makeProduct(price: 25.0, cost: 10.0).profit, 15.0);
      expect(_makeProduct(price: 25.0, cost: 10.0).marginPercent, 60.0);
      expect(_makeProduct(price: 25.0).profit, isNull);
      expect(_makeProduct(price: 25.0).marginPercent, isNull);
      // cost=0 => marginPercent null (division guard)
      expect(_makeProduct(price: 25.0, cost: 0.0).marginPercent, isNull);
    });

    test('isInternationalSupplier', () {
      expect(_makeProduct().isInternationalSupplier, false);
      expect(
        _makeProduct(supplier: const SupplierInfo(type: 'local')).isInternationalSupplier,
        false,
      );
      expect(
        _makeProduct(
          supplier: const SupplierInfo(type: SupplierTypeValues.aliexpress),
        ).isInternationalSupplier,
        true,
      );
    });

    test('deliveryEstimateText for digital', () {
      expect(_makeProduct(isDigital: true).deliveryEstimateText, 'Instant delivery');
    });

    test('deliveryEstimateText for local only', () {
      expect(
        _makeProduct(isLocalDeliveryOnly: true).deliveryEstimateText,
        '1-3 business days (local)',
      );
    });

    test('deliveryEstimateText with supplier shippingDays', () {
      final p = _makeProduct(
        supplier: const SupplierInfo(type: 'aliexpress', shippingDays: '10-20'),
      );
      expect(p.deliveryEstimateText, '10-20 business days');
    });

    test('estimatedDeliveryDays uses supplier type defaults', () {
      final p = _makeProduct(
        supplier: const SupplierInfo(type: SupplierTypeValues.temu),
      );
      final range = p.estimatedDeliveryDays;
      expect(range.minDays, 7);
      expect(range.maxDays, 15);
    });

    test('estimatedDeliveryDays falls back to default range', () {
      final range = _makeProduct().estimatedDeliveryDays;
      expect(range.minDays, 3);
      expect(range.maxDays, 7);
    });
  });

  // =========================================================================
  // SellerWarehouseExtension
  // =========================================================================
  group('SellerWarehouseExtension', () {
    test('cityProvince', () {
      const wh = SellerWarehouse(
        warehouseId: 'wh1',
        label: 'Main',
        address: Address(
          street: '1 Main St',
          city: 'Toronto',
          state: 'ON',
          postalCode: 'M5V 3A8',
        ),
      );
      expect(wh.cityProvince, 'Toronto, ON');
    });

    test('isPersonal and isWarehouse', () {
      const personal = SellerWarehouse(
        warehouseId: 'wh2',
        label: 'Home',
        type: WarehouseTypeValues.personal,
        address: Address(
          street: '2 Elm St',
          city: 'Ottawa',
          state: 'ON',
          postalCode: 'K1A 0A6',
        ),
      );
      expect(personal.isPersonal, true);
      expect(personal.isWarehouse, false);
      expect(personal.typeLabel, 'Personal Address');

      const warehouse = SellerWarehouse(
        warehouseId: 'wh3',
        label: 'Depot',
        type: WarehouseTypeValues.warehouse,
        address: Address(
          street: '3 Bay St',
          city: 'Toronto',
          state: 'ON',
          postalCode: 'M5J 2T3',
        ),
      );
      expect(warehouse.isWarehouse, true);
      expect(warehouse.isPersonal, false);
      expect(warehouse.typeLabel, 'Warehouse');
    });
  });
}
