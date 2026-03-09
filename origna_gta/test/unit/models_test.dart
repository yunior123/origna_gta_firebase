import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/utils/constants.dart';

void main() {
  group('Address', () {
    test('fromMap creates correct Address', () {
      final map = {
        Fields.street: '123 Main St',
        Fields.apartment: 'Unit 4B',
        Fields.city: 'Toronto',
        Fields.state: 'ON',
        Fields.postalCode: 'M5V 1A1',
        Fields.country: 'Canada',
        Fields.phoneNumber: '416-555-1234',
        Fields.isDefault: true,
        Fields.label: 'Home',
        Fields.latitude: 43.6532,
        Fields.longitude: -79.3832,
      };

      final address = Address.fromMap(map);

      expect(address.street, '123 Main St');
      expect(address.apartment, 'Unit 4B');
      expect(address.city, 'Toronto');
      expect(address.state, 'ON');
      expect(address.postalCode, 'M5V 1A1');
      expect(address.country, 'Canada');
      expect(address.phoneNumber, '416-555-1234');
      expect(address.isDefault, true);
      expect(address.label, 'Home');
      expect(address.latitude, 43.6532);
      expect(address.longitude, -79.3832);
    });

    test('fromMap handles missing fields with defaults', () {
      final map = <String, dynamic>{};
      final address = Address.fromMap(map);

      expect(address.street, '');
      expect(address.apartment, '');
      expect(address.city, '');
      expect(address.state, '');
      expect(address.postalCode, '');
      expect(address.country, '');
      expect(address.phoneNumber, null);
      expect(address.isDefault, false);
      expect(address.label, null);
    });

    test('fromMap with docId overrides addressId', () {
      final map = {Fields.addressId: 'map_id', Fields.street: 'X', Fields.city: 'Y', Fields.state: 'Z', Fields.postalCode: '0', Fields.country: 'CA'};
      final addr = Address.fromMap(map, docId: 'doc_id');
      expect(addr.addressId, 'doc_id');
    });

    test('fromMap without docId uses map addressId', () {
      final map = {Fields.addressId: 'map_id', Fields.street: 'X', Fields.city: 'Y', Fields.state: 'Z', Fields.postalCode: '0', Fields.country: 'CA'};
      final addr = Address.fromMap(map);
      expect(addr.addressId, 'map_id');
    });

    test('toMap returns correct map', () {
      final address = Address(
        street: '456 Oak Ave',
        apartment: 'Suite 100',
        city: 'Vancouver',
        state: 'BC',
        postalCode: 'V6B 1A1',
        country: 'Canada',
        phoneNumber: '604-555-5678',
        isDefault: true,
        label: 'Work',
        latitude: 49.2827,
        longitude: -123.1207,
      );

      final map = address.toMap();

      expect(map[Fields.street], '456 Oak Ave');
      expect(map[Fields.apartment], 'Suite 100');
      expect(map[Fields.city], 'Vancouver');
      expect(map[Fields.state], 'BC');
      expect(map[Fields.postalCode], 'V6B 1A1');
      expect(map[Fields.country], 'Canada');
      expect(map[Fields.phoneNumber], '604-555-5678');
      expect(map[Fields.isDefault], true);
      expect(map[Fields.label], 'Work');
      expect(map[Fields.latitude], 49.2827);
      expect(map[Fields.longitude], -123.1207);
    });

    test('toMap includes addressId when present', () {
      final address = Address(addressId: 'addr1', street: 'X', city: 'Y', state: 'Z', postalCode: '0', country: 'CA');
      final map = address.toMap();
      expect(map[Fields.addressId], 'addr1');
    });

    test('toMap omits addressId when null', () {
      final address = Address(street: 'X', city: 'Y', state: 'Z', postalCode: '0', country: 'CA');
      final map = address.toMap();
      expect(map.containsKey(Fields.addressId), false);
    });

    test('fullAddress returns formatted string', () {
      final address = Address(street: '123 Main St', apartment: 'Unit 4B', city: 'Toronto', state: 'ON', postalCode: 'M5V 1A1', country: 'Canada');

      expect(address.fullAddress, '123 Main St, Unit 4B, Toronto, ON, M5V 1A1, Canada');
    });

    test('fullAddress without apartment omits it', () {
      final address = Address(street: '123 Main St', city: 'Toronto', state: 'ON', postalCode: 'M5V 1A1', country: 'Canada');
      expect(address.fullAddress, '123 Main St, Toronto, ON, M5V 1A1, Canada');
    });

    test('formattedAddress with apartment', () {
      final address = Address(street: '123 Main St', apartment: 'Unit 4B', city: 'Toronto', state: 'ON', postalCode: 'M5V 1A1', country: 'Canada');
      expect(address.formattedAddress, '123 Main St\nUnit 4B\nToronto, ON M5V 1A1\nCanada');
    });

    test('formattedAddress without apartment', () {
      final address = Address(street: '123 Main St', city: 'Toronto', state: 'ON', postalCode: 'M5V 1A1', country: 'Canada');
      expect(address.formattedAddress, '123 Main St\nToronto, ON M5V 1A1\nCanada');
    });

    test('empty factory creates empty address', () {
      final address = Address.empty();
      expect(address.street, '');
      expect(address.city, '');
      expect(address.state, '');
      expect(address.postalCode, '');
      expect(address.country, 'Canada');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = Address(street: '123 Main St', city: 'Toronto', state: 'ON', postalCode: 'M5V 1A1', country: 'Canada');

      final updated = original.copyWith(city: 'Vancouver', state: 'BC');

      expect(updated.street, '123 Main St');
      expect(updated.city, 'Vancouver');
      expect(updated.state, 'BC');
      expect(original.city, 'Toronto'); // Original unchanged
    });

    test('copyWith preserves all fields when no overrides', () {
      final original = Address(
        addressId: 'a1', street: '123 Main', apartment: 'Apt 1', city: 'Toronto', state: 'ON',
        postalCode: 'M5V', country: 'CA', phoneNumber: '555-1234', isDefault: true,
        label: 'Home', latitude: 43.0, longitude: -79.0,
      );
      final copy = original.copyWith();
      expect(copy.addressId, 'a1');
      expect(copy.phoneNumber, '555-1234');
      expect(copy.isDefault, true);
      expect(copy.label, 'Home');
      expect(copy.latitude, 43.0);
      expect(copy.longitude, -79.0);
    });
  });

  group('UserModel', () {
    test('fromMap creates correct UserModel', () {
      final map = {
        Fields.uid: 'user123',
        Fields.email: 'test@example.com',
        Fields.name: 'John Doe',
        Fields.roles: ['buyer', 'seller'],
        Fields.address: {Fields.street: '123 Main St', Fields.city: 'Toronto', Fields.state: 'ON', Fields.postalCode: 'M5V 1A1', Fields.country: 'Canada'},
        Fields.createdAt: Timestamp.fromDate(DateTime(2024, 1, 15)),
        Fields.customerId: 'cus_123',
        // Stripe fields are mastered in seller_profiles/{uid}, NOT users/{uid} (C-6 fix)
        // Including them in the map is ignored by fromMap intentionally.
        Fields.stripeAccountId: 'acct_456',
        Fields.payoutsEnabled: true,
        Fields.chargesEnabled: true,
        Fields.onboardingCompleted: true,
      };

      final user = UserModel.fromMap(map);

      expect(user.uid, 'user123');
      expect(user.email, 'test@example.com');
      expect(user.name, 'John Doe');
      expect(user.roles, ['buyer', 'seller']);
      expect(user.address?.city, 'Toronto');
      expect(user.customerId, 'cus_123');
      // Stripe fields are always null/false from fromMap — loaded separately from seller_profiles
      expect(user.stripeAccountId, null);
      expect(user.payoutsEnabled, false);
      expect(user.chargesEnabled, false);
      expect(user.onboardingCompleted, false);
    });

    test('fromMap handles missing optional fields', () {
      final map = {
        Fields.uid: 'user123',
        Fields.email: 'test@example.com',
        Fields.name: 'John Doe',
        Fields.roles: ['buyer'],
        Fields.createdAt: Timestamp.fromDate(DateTime(2024, 1, 15)),
      };

      final user = UserModel.fromMap(map);

      expect(user.uid, 'user123');
      expect(user.address, null);
      expect(user.customerId, null);
      expect(user.stripeAccountId, null);
      expect(user.payoutsEnabled, false);
    });

    test('toMap returns correct map', () {
      final user = UserModel(
        uid: 'user123',
        email: 'test@example.com',
        name: 'John Doe',
        roles: ['buyer', 'seller'],
        createdAt: DateTime(2024, 1, 15),
        customerId: 'cus_123',
        stripeAccountId: 'acct_456',
        payoutsEnabled: true,
        chargesEnabled: true,
        onboardingCompleted: true,
      );

      final map = user.toMap();

      expect(map[Fields.uid], 'user123');
      expect(map[Fields.email], 'test@example.com');
      expect(map[Fields.name], 'John Doe');
      expect(map[Fields.roles], ['buyer', 'seller']);
      expect(map[Fields.customerId], 'cus_123');
      expect(map[Fields.stripeAccountId], 'acct_456');
      expect(map[Fields.payoutsEnabled], true);
    });

    test('canReceivePayouts returns true when conditions met', () {
      final seller = UserModel(
        uid: 'seller123',
        email: 'seller@example.com',
        name: 'Seller',
        roles: ['seller'],
        createdAt: DateTime.now(),
        payoutsEnabled: true,
        onboardingCompleted: true,
      );

      expect(seller.canReceivePayouts, true);
    });

    test('canReceivePayouts returns false when not onboarded', () {
      final seller = UserModel(
        uid: 'seller123',
        email: 'seller@example.com',
        name: 'Seller',
        roles: ['seller'],
        createdAt: DateTime.now(),
        payoutsEnabled: true,
        onboardingCompleted: false,
      );

      expect(seller.canReceivePayouts, false);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = UserModel(uid: 'user123', email: 'test@example.com', name: 'John Doe', roles: ['buyer'], createdAt: DateTime(2024, 1, 15));

      final updated = original.copyWith(name: 'Jane Doe', roles: ['buyer', 'seller']);

      expect(updated.name, 'Jane Doe');
      expect(updated.roles, ['buyer', 'seller']);
      expect(updated.email, 'test@example.com'); // Unchanged
      expect(original.name, 'John Doe'); // Original unchanged
    });
  });

  group('ProductModel', () {
    test('fromMap creates correct ProductModel', () {
      final map = {
        Fields.productId: 'prod123',
        Fields.name: 'Test Product',
        Fields.price: 29.99,
        Fields.imageUrls: ['https://example.com/image1.jpg', 'https://example.com/image2.jpg'],
        Fields.sellerAddress: {
          Fields.street: '123 Main St',
          Fields.city: 'Toronto',
          Fields.state: 'ON',
          Fields.postalCode: 'M5V 1A1',
          Fields.country: 'Canada',
        },
        Fields.description: 'A great product',
        Fields.sellerId: 'seller123',
        Fields.stockQuantity: 50,
        Fields.categoryId: 1,
        Fields.rating: 4.5,
        Fields.ratingCount: 100,
        Fields.keywords: ['test', 'product'],
        Fields.weightKg: 0.5,
        Fields.isLocalDeliveryOnly: false,
        Fields.estimatedShipDays: 3,
        Fields.lifecycleStatus: 'active',
      };

      final product = ProductModel.fromMap(map);

      expect(product.id, 'prod123');
      expect(product.name, 'Test Product');
      expect(product.price, 29.99);
      expect(product.imageUrls.length, 2);
      expect(product.sellerAddress.city, 'Toronto');
      expect(product.description, 'A great product');
      expect(product.sellerId, 'seller123');
      expect(product.stockQuantity, 50);
      expect(product.categoryId, 1);
      expect(product.rating, 4.5);
      expect(product.ratingCount, 100);
      expect(product.weightKg, 0.5);
      expect(product.isLocalDeliveryOnly, false);
      expect(product.estimatedShipDays, 3);
      expect(product.lifecycleStatus, 'active');
    });

    test('fromMap handles missing optional fields', () {
      final map = {Fields.productId: 'prod123', Fields.name: 'Test Product', Fields.price: 29.99, Fields.categoryId: 1};

      final product = ProductModel.fromMap(map);

      expect(product.id, 'prod123');
      expect(product.name, 'Test Product');
      expect(product.imageUrls, isEmpty);
      expect(product.rating, 0.0);
      expect(product.ratingCount, 0);
      expect(product.stockQuantity, 0);
      expect(product.weightKg, null);
      expect(product.lifecycleStatus, 'draft');
    });

    test('toMap returns correct map', () {
      final product = ProductModel(
        id: 'prod123',
        name: 'Test Product',
        price: 29.99,
        imageUrls: ['https://example.com/image.jpg'],
        sellerAddress: Address(street: '123 Main St', city: 'Toronto', state: 'ON', postalCode: 'M5V 1A1', country: 'Canada'),
        description: 'A great product',
        sellerId: 'seller123',
        stockQuantity: 50,
        categoryId: 1,
        keywords: ['test'],
        rating: 4.5,
        ratingCount: 100,
        lifecycleStatus: 'active',
      );

      final map = product.toMap();

      expect(map[Fields.productId], 'prod123');
      expect(map[Fields.name], 'Test Product');
      expect(map[Fields.price], 29.99);
      expect(map[Fields.stockQuantity], 50);
      expect(map[Fields.rating], 4.5);
      expect(map[Fields.lifecycleStatus], 'active');
    });

    test('price parsing handles various numeric types', () {
      // Integer
      var product = ProductModel.fromMap({Fields.price: 30, Fields.categoryId: 1});
      expect(product.price, 30.0);

      // String
      product = ProductModel.fromMap({Fields.price: '25.50', Fields.categoryId: 1});
      expect(product.price, 25.50);

      // Null
      product = ProductModel.fromMap({Fields.price: null, Fields.categoryId: 1});
      expect(product.price, 0.0);
    });
  });

  group('CartModel', () {
    test('fromMap creates correct CartModel', () {
      final now = DateTime(2024, 1, 15, 10, 30);
      final map = {Fields.productId: 'prod123', Fields.quantity: 3, Fields.createdAt: Timestamp.fromDate(now)};

      final cart = CartModel.fromMap(map);

      expect(cart.productId, 'prod123');
      expect(cart.quantity, 3);
      expect(cart.createdAt, now);
    });

    test('toMap returns correct map', () {
      final now = DateTime(2024, 1, 15, 10, 30);
      final cart = CartModel(productId: 'prod123', quantity: 2, createdAt: now);

      final map = cart.toMap();

      expect(map[Fields.productId], 'prod123');
      expect(map[Fields.quantity], 2);
      expect((map[Fields.createdAt] as Timestamp).toDate(), now);
    });

    test('default quantity is 1', () {
      final cart = CartModel(productId: 'prod123', createdAt: DateTime.now());

      expect(cart.quantity, 1);
    });
  });

  group('CartItemModel', () {
    test('fromMap creates correct CartItemModel', () {
      final map = {
        Fields.productId: 'prod123',
        Fields.quantity: 5,
        Fields.createdAt: Timestamp.fromDate(DateTime(2024, 1, 15)),
        Fields.buyerNote: 'Gift for friend',
      };

      final item = CartItemModel.fromMap(map);

      expect(item.productId, 'prod123');
      expect(item.quantity, 5);
      expect(item.buyerNote, 'Gift for friend');
    });

    test('toMap returns correct map', () {
      final now = Timestamp.fromDate(DateTime(2024, 1, 15));
      final item = CartItemModel(cartItemId: 'cart_1', productId: 'prod123', quantity: 3, createdAt: now, buyerNote: 'Gift wrapped please');

      final map = item.toMap();

      expect(map[Fields.productId], 'prod123');
      expect(map[Fields.quantity], 3);
      expect(map[Fields.createdAt], now);
      expect(map[Fields.buyerNote], 'Gift wrapped please');
    });
  });

  group('CartItemDetailModel', () {
    test('fromMap full parsing', () {
      final ts = Timestamp.fromDate(DateTime(2024, 6, 15));
      final map = {
        Fields.productId: 'p1',
        Fields.name: 'Widget',
        Fields.description: 'A fine widget',
        Fields.price: 25.5,
        Fields.imageUrls: ['img1.jpg', 'img2.jpg'],
        Fields.quantity: 3,
        Fields.createdAt: ts,
        Fields.sellerAddress: {Fields.street: '1 St', Fields.city: 'Toronto', Fields.state: 'ON', Fields.postalCode: 'M5V', Fields.country: 'CA'},
        Fields.sellerId: 's1',
        Fields.sellerName: 'SellerOne',
        Fields.status: DeliveryStatusValues.shipped,
        Fields.trackingNumber: 'TRK123',
        Fields.confirmedByBuyer: true,
        Fields.madeInCountry: 'CN',
        Fields.weightKg: 1.5,
        Fields.weightUnit: 'kg',
        Fields.lengthCm: 30.0,
        Fields.widthCm: 20.0,
        Fields.heightCm: 10.0,
        Fields.dimensionUnit: 'cm',
        Fields.isLocalDeliveryOnly: true,
        Fields.isPerishable: true,
        Fields.estimatedShipDays: 5,
        Fields.deliveryOptions: [
          {'type': 'standard', 'costCents': 999, 'estimatedDays': 5},
        ],
        Fields.minimumOrderQuantity: 2,
        Fields.freeShipping: true,
        Fields.isDigital: false,
        Fields.isAgeRestricted: true,
        Fields.buyerNote: 'Gift please',
        Fields.isSmallSupplier: true,
        Fields.variantId: 'v1',
        Fields.variantTitle: 'Large / Red',
        Fields.variantOptions: {'size': 'L', 'color': 'Red'},
      };

      final item = CartItemDetailModel.fromMap(map);

      expect(item.productId, 'p1');
      expect(item.name, 'Widget');
      expect(item.price, 25.5);
      expect(item.imageUrls.length, 2);
      expect(item.quantity, 3);
      expect(item.sellerAddress.city, 'Toronto');
      expect(item.sellerId, 's1');
      expect(item.sellerName, 'SellerOne');
      expect(item.status, DeliveryStatusValues.shipped);
      expect(item.trackingNumber, 'TRK123');
      expect(item.confirmedByBuyer, true);
      expect(item.madeInCountry, 'CN');
      expect(item.weightKg, 1.5);
      expect(item.weightUnit, 'kg');
      expect(item.lengthCm, 30.0);
      expect(item.widthCm, 20.0);
      expect(item.heightCm, 10.0);
      expect(item.dimensionUnit, 'cm');
      expect(item.isLocalDeliveryOnly, true);
      expect(item.isPerishable, true);
      expect(item.estimatedShipDays, 5);
      expect(item.deliveryOptions.length, 1);
      expect(item.minimumOrderQuantity, 2);
      expect(item.freeShipping, true);
      expect(item.isAgeRestricted, true);
      expect(item.buyerNote, 'Gift please');
      expect(item.isSmallSupplier, true);
      expect(item.variantId, 'v1');
      expect(item.variantTitle, 'Large / Red');
      expect(item.variantOptions, {'size': 'L', 'color': 'Red'});
    });

    test('fromMap defaults for missing fields', () {
      final item = CartItemDetailModel.fromMap(<String, dynamic>{});

      expect(item.productId, '');
      expect(item.name, '');
      expect(item.price, 0.0);
      expect(item.imageUrls, isEmpty);
      expect(item.quantity, 0);
      expect(item.sellerId, '');
      expect(item.status, DeliveryStatus.pending.value);
      expect(item.confirmedByBuyer, false);
      expect(item.weightKg, null);
      expect(item.isLocalDeliveryOnly, false);
      expect(item.isPerishable, false);
      expect(item.estimatedShipDays, 3);
      expect(item.deliveryOptions, isEmpty);
      expect(item.minimumOrderQuantity, 1);
      expect(item.freeShipping, false);
      expect(item.isDigital, false);
      expect(item.isAgeRestricted, false);
      expect(item.buyerNote, null);
      expect(item.isSmallSupplier, false);
      expect(item.variantId, null);
      expect(item.variantOptions, null);
    });

    test('fromMap with null sellerAddress uses empty address', () {
      final item = CartItemDetailModel.fromMap({Fields.sellerAddress: null});
      expect(item.sellerAddress.country, 'Canada');
    });

    test('toMap roundtrip preserves data', () {
      final ts = Timestamp.fromDate(DateTime(2024, 1, 1));
      final original = CartItemDetailModel(
        productId: 'p1', name: 'Test', description: 'desc', price: 10.0,
        imageUrls: ['img.jpg'], quantity: 2, createdAt: ts,
        sellerAddress: Address(street: '1 St', city: 'T', state: 'ON', postalCode: 'M5V', country: 'CA'),
        sellerId: 's1', sellerName: 'Seller',
        madeInCountry: 'CA', weightKg: 0.5, weightUnit: 'kg',
        lengthCm: 10.0, widthCm: 5.0, heightCm: 3.0, dimensionUnit: 'cm',
        buyerNote: 'Note', variantId: 'v1', variantTitle: 'Size L',
        variantOptions: {'size': 'L'},
      );
      final map = original.toMap();

      expect(map[Fields.productId], 'p1');
      expect(map[Fields.name], 'Test');
      expect(map[Fields.price], 10.0);
      expect(map[Fields.madeInCountry], 'CA');
      expect(map[Fields.weightUnit], 'kg');
      expect(map[Fields.dimensionUnit], 'cm');
      expect(map[Fields.buyerNote], 'Note');
      expect(map[Fields.variantId], 'v1');
      expect(map[Fields.variantOptions], {'size': 'L'});
      expect(map[Fields.sellerAddress], isA<Map>());
    });

    test('toMap omits null optional fields', () {
      final ts = Timestamp.fromDate(DateTime(2024, 1, 1));
      final item = CartItemDetailModel(
        productId: 'p1', name: 'Test', description: 'desc', price: 10.0,
        imageUrls: [], quantity: 1, createdAt: ts,
        sellerAddress: Address(street: '', city: '', state: '', postalCode: '', country: ''),
        sellerId: 's1', sellerName: 'S',
      );
      final map = item.toMap();
      expect(map.containsKey(Fields.madeInCountry), false);
      expect(map.containsKey(Fields.weightUnit), false);
      expect(map.containsKey(Fields.dimensionUnit), false);
      expect(map.containsKey(Fields.buyerNote), false);
      expect(map.containsKey(Fields.variantId), false);
      expect(map.containsKey(Fields.variantTitle), false);
      expect(map.containsKey(Fields.variantOptions), false);
    });
  });

  group('CartItemModel extended', () {
    test('fromMap with String timestamp', () {
      final map = {
        Fields.productId: 'p1',
        Fields.quantity: 2,
        Fields.createdAt: '2024-06-15T10:30:00.000',
      };
      final item = CartItemModel.fromMap(map);
      expect(item.createdAt.toDate().year, 2024);
      expect(item.createdAt.toDate().month, 6);
    });

    test('fromMap with DateTime timestamp', () {
      final dt = DateTime(2024, 3, 10);
      final map = {Fields.productId: 'p1', Fields.quantity: 1, Fields.createdAt: dt};
      final item = CartItemModel.fromMap(map);
      expect(item.createdAt.toDate(), dt);
    });

    test('fromMap with null timestamp falls back to now', () {
      final map = {Fields.productId: 'p1', Fields.quantity: 1, Fields.createdAt: null};
      final item = CartItemModel.fromMap(map);
      expect(item.createdAt, isA<Timestamp>());
    });

    test('fromMap with docId overrides cartItemId', () {
      final map = {Fields.cartItemId: 'old', Fields.productId: 'p1', Fields.quantity: 1, Fields.createdAt: Timestamp.now()};
      final item = CartItemModel.fromMap(map, docId: 'new_id');
      expect(item.cartItemId, 'new_id');
    });

    test('fromMap with variant fields', () {
      final map = {
        Fields.productId: 'p1', Fields.quantity: 1, Fields.createdAt: Timestamp.now(),
        Fields.variantId: 'v1', Fields.variantTitle: 'Size M',
        Fields.variantOptions: {'size': 'M'},
        Fields.buyerNote: 'Wrap it',
      };
      final item = CartItemModel.fromMap(map);
      expect(item.variantId, 'v1');
      expect(item.variantTitle, 'Size M');
      expect(item.variantOptions, {'size': 'M'});
      expect(item.buyerNote, 'Wrap it');
    });

    test('toMap includes variant fields when present', () {
      final item = CartItemModel(
        cartItemId: 'c1', productId: 'p1', quantity: 1, createdAt: Timestamp.now(),
        variantId: 'v1', variantTitle: 'Red', variantOptions: {'color': 'Red'}, buyerNote: 'Note',
      );
      final map = item.toMap();
      expect(map[Fields.variantId], 'v1');
      expect(map[Fields.variantTitle], 'Red');
      expect(map[Fields.variantOptions], {'color': 'Red'});
      expect(map[Fields.buyerNote], 'Note');
    });

    test('toMap omits null variant fields', () {
      final item = CartItemModel(cartItemId: 'c1', productId: 'p1', quantity: 1, createdAt: Timestamp.now());
      final map = item.toMap();
      expect(map.containsKey(Fields.variantId), false);
      expect(map.containsKey(Fields.variantTitle), false);
      expect(map.containsKey(Fields.variantOptions), false);
      expect(map.containsKey(Fields.buyerNote), false);
    });
  });

  group('CartModel extended', () {
    test('fromMap with DateTime instead of Timestamp', () {
      final dt = DateTime(2024, 5, 1);
      final map = {Fields.productId: 'p1', Fields.quantity: 2, Fields.createdAt: dt};
      final cart = CartModel.fromMap(map);
      expect(cart.createdAt, dt);
    });

    test('fromMap with null createdAt falls back to now', () {
      final map = {Fields.productId: 'p1', Fields.quantity: 2};
      final cart = CartModel.fromMap(map);
      expect(cart.createdAt.year, DateTime.now().year);
    });

    test('fromMap with docId overrides cartItemId', () {
      final map = {Fields.cartItemId: 'old', Fields.productId: 'p1', Fields.createdAt: Timestamp.now()};
      final cart = CartModel.fromMap(map, docId: 'doc_id');
      expect(cart.cartItemId, 'doc_id');
    });

    test('fromMap with variant and price snapshot fields', () {
      final map = {
        Fields.productId: 'p1', Fields.createdAt: Timestamp.now(),
        Fields.variantId: 'v1', Fields.variantTitle: 'Blue', Fields.variantSku: 'SKU-BLUE',
        Fields.variantOptions: {'color': 'Blue'}, Fields.priceSnapshot: 2999,
      };
      final cart = CartModel.fromMap(map);
      expect(cart.variantId, 'v1');
      expect(cart.variantTitle, 'Blue');
      expect(cart.variantSku, 'SKU-BLUE');
      expect(cart.variantOptions, {'color': 'Blue'});
      expect(cart.priceSnapshot, 2999);
    });

    test('toMap includes optional fields when present', () {
      final cart = CartModel(
        productId: 'p1', createdAt: DateTime(2024, 1, 1),
        variantId: 'v1', variantTitle: 'Red', variantSku: 'SKU-R',
        variantOptions: {'color': 'Red'}, priceSnapshot: 1500,
      );
      final map = cart.toMap();
      expect(map[Fields.variantId], 'v1');
      expect(map[Fields.variantSku], 'SKU-R');
      expect(map[Fields.priceSnapshot], 1500);
    });

    test('toMap omits null optional fields', () {
      final cart = CartModel(productId: 'p1', createdAt: DateTime(2024, 1, 1));
      final map = cart.toMap();
      expect(map.containsKey(Fields.variantId), false);
      expect(map.containsKey(Fields.variantSku), false);
      expect(map.containsKey(Fields.priceSnapshot), false);
    });
  });

  group('OrderModel', () {
    test('fromMap full parsing', () {
      final ts = Timestamp.fromDate(DateTime(2024, 6, 15));
      final data = {
        Fields.orderId: 'ord1',
        Fields.userId: 'u1',
        Fields.items: [
          {
            Fields.productId: 'p1', Fields.name: 'Item', Fields.description: 'Desc',
            Fields.price: 50.0, Fields.imageUrls: ['img.jpg'], Fields.quantity: 2,
            Fields.createdAt: ts, Fields.sellerId: 's1', Fields.sellerName: 'Seller',
            Fields.status: DeliveryStatusValues.delivered,
            Fields.confirmedByBuyer: true, Fields.isDigital: false, Fields.isAgeRestricted: true,
            Fields.trackingNumber: 'TRK1',
          },
        ],
        Fields.totalAmountCents: 12500,
        Fields.subtotalCents: 10000,
        Fields.shippingCostCents: 1500,
        Fields.taxAmountCents: 1000,
        Fields.orderStatus: OrderStatusValues.confirmed,
        Fields.paymentStatus: PaymentStatusValues.paid,
        Fields.shippingAddress: {Fields.street: '1 St', Fields.city: 'Toronto'},
        Fields.createdAt: ts,
        Fields.customerId: 'cus_1',
        Fields.customerEmail: 'test@test.com',
        Fields.taxes: {'GST': 5.0, 'PST': 0.0},
        Fields.currency: 'CAD',
        Fields.sellerIds: ['s1'],
        Fields.stripeSessionId: 'sess_1',
        Fields.shippingApprovalStatus: ShippingApprovalStatusValues.approved,
        Fields.shippingApprovalRequired: true,
        Fields.actualShippingCents: 1200,
        Fields.pendingTotalCents: 0,
        Fields.sellerPayouts: [
          {Fields.sellerId: 's1', Fields.amountCents: 10000, Fields.platformFeeCents: 250, Fields.netAmountCents: 9750, Fields.status: PayoutStatusValues.completed},
        ],
        Fields.confirmedByClient: true,
        Fields.confirmedAt: ts,
        Fields.platformFeeTotalCents: 250,
        Fields.payoutStatus: PayoutStatusValues.completed,
        Fields.ratings: {'s1': 5},
      };

      final order = OrderModel.fromMap(data);

      expect(order.orderId, 'ord1');
      expect(order.userId, 'u1');
      expect(order.items.length, 1);
      expect(order.items.first.productId, 'p1');
      expect(order.items.first.confirmedByBuyer, true);
      expect(order.items.first.isAgeRestricted, true);
      expect(order.items.first.trackingNumber, 'TRK1');
      expect(order.totalAmountCents, 12500);
      expect(order.total, 125.0);
      expect(order.subtotalCents, 10000);
      expect(order.subtotal, 100.0);
      expect(order.shippingCostCents, 1500);
      expect(order.shippingCost, 15.0);
      expect(order.taxAmountCents, 1000);
      expect(order.taxAmount, 10.0);
      expect(order.orderStatus, OrderStatusValues.confirmed);
      expect(order.paymentStatus, PaymentStatusValues.paid);
      expect(order.currency, 'CAD');
      expect(order.sellerIds, ['s1']);
      expect(order.stripeSessionId, 'sess_1');
      expect(order.shippingApprovalRequired, true);
      expect(order.actualShippingCents, 1200);
      expect(order.sellerPayouts.length, 1);
      expect(order.confirmedByClient, true);
      expect(order.confirmedAt, isNotNull);
      expect(order.platformFeeTotalCents, 250);
      expect(order.payoutStatus, PayoutStatusValues.completed);
      expect(order.ratings, {'s1': 5});
    });

    test('fromMap with empty/missing fields uses defaults', () {
      final order = OrderModel.fromMap(<String, dynamic>{});

      expect(order.orderId, '');
      expect(order.userId, '');
      expect(order.items, isEmpty);
      expect(order.totalAmountCents, 0);
      expect(order.subtotalCents, 0);
      expect(order.shippingCostCents, 0);
      expect(order.taxAmountCents, 0);
      expect(order.orderStatus, OrderStatusValues.pending);
      expect(order.paymentStatus, PaymentStatusValues.awaitingPayment);
      expect(order.sellerIds, isEmpty);
      expect(order.stripeSessionId, '');
      expect(order.sellerPayouts, isEmpty);
      expect(order.confirmedByClient, false);
      expect(order.confirmedAt, null);
      expect(order.platformFeeTotalCents, 0);
      expect(order.payoutStatus, PayoutStatusValues.pending);
    });

    test('fromMap with DateTime createdAt', () {
      final dt = DateTime(2024, 3, 10);
      final order = OrderModel.fromMap({Fields.createdAt: dt});
      expect(order.createdAt, dt);
    });

    test('fromMap skips malformed seller payouts', () {
      final data = {
        Fields.sellerPayouts: ['not a map', 123, {Fields.sellerId: 'valid', Fields.amountCents: 100, Fields.platformFeeCents: 10, Fields.netAmountCents: 90}],
      };
      final order = OrderModel.fromMap(data);
      expect(order.sellerPayouts.length, 1);
      expect(order.sellerPayouts.first.sellerId, 'valid');
    });

    test('allItemsConfirmed true when all delivered items confirmed', () {
      final ts = Timestamp.now();
      final order = OrderModel(
        orderId: 'o1', userId: 'u1', totalAmountCents: 1000, subtotalCents: 1000,
        orderStatus: OrderStatusValues.delivered,
        shippingAddress: {}, createdAt: DateTime.now(), customerId: 'c1',
        customerEmail: 'e@e.com', taxes: {}, currency: 'CAD', sellerIds: ['s1'],
        stripeSessionId: 'sess',
        items: [
          CartItemDetailModel(
            productId: 'p1', name: 'A', description: '', price: 10, imageUrls: [],
            quantity: 1, createdAt: ts,
            sellerAddress: Address(street: '', city: '', state: '', postalCode: '', country: ''),
            sellerId: 's1', sellerName: 'S', status: DeliveryStatusValues.delivered, confirmedByBuyer: true,
          ),
          CartItemDetailModel(
            productId: 'p2', name: 'B', description: '', price: 10, imageUrls: [],
            quantity: 1, createdAt: ts,
            sellerAddress: Address(street: '', city: '', state: '', postalCode: '', country: ''),
            sellerId: 's1', sellerName: 'S', status: DeliveryStatusValues.delivered, confirmedByBuyer: true,
          ),
        ],
      );
      expect(order.allItemsConfirmed, true);
    });

    test('allItemsConfirmed false when some delivered not confirmed', () {
      final ts = Timestamp.now();
      final order = OrderModel(
        orderId: 'o1', userId: 'u1', totalAmountCents: 1000, subtotalCents: 1000,
        orderStatus: OrderStatusValues.delivered,
        shippingAddress: {}, createdAt: DateTime.now(), customerId: 'c1',
        customerEmail: 'e@e.com', taxes: {}, currency: 'CAD', sellerIds: ['s1'],
        stripeSessionId: 'sess',
        items: [
          CartItemDetailModel(
            productId: 'p1', name: 'A', description: '', price: 10, imageUrls: [],
            quantity: 1, createdAt: ts,
            sellerAddress: Address(street: '', city: '', state: '', postalCode: '', country: ''),
            sellerId: 's1', sellerName: 'S', status: DeliveryStatusValues.delivered, confirmedByBuyer: false,
          ),
        ],
      );
      expect(order.allItemsConfirmed, false);
    });

    test('allItemsConfirmed false when no delivered items', () {
      final ts = Timestamp.now();
      final order = OrderModel(
        orderId: 'o1', userId: 'u1', totalAmountCents: 1000, subtotalCents: 1000,
        orderStatus: OrderStatusValues.pending,
        shippingAddress: {}, createdAt: DateTime.now(), customerId: 'c1',
        customerEmail: 'e@e.com', taxes: {}, currency: 'CAD', sellerIds: ['s1'],
        stripeSessionId: 'sess',
        items: [
          CartItemDetailModel(
            productId: 'p1', name: 'A', description: '', price: 10, imageUrls: [],
            quantity: 1, createdAt: ts,
            sellerAddress: Address(street: '', city: '', state: '', postalCode: '', country: ''),
            sellerId: 's1', sellerName: 'S', status: DeliveryStatusValues.pending,
          ),
        ],
      );
      expect(order.allItemsConfirmed, false);
    });

    test('allSellersPaid true when all payouts completed', () {
      final order = OrderModel(
        orderId: 'o1', userId: 'u1', totalAmountCents: 1000, subtotalCents: 1000,
        orderStatus: OrderStatusValues.delivered,
        shippingAddress: {}, createdAt: DateTime.now(), customerId: 'c1',
        customerEmail: 'e@e.com', taxes: {}, currency: 'CAD', sellerIds: ['s1'],
        stripeSessionId: 'sess', items: [],
        sellerPayouts: [
          SellerPayout(sellerId: 's1', amountCents: 1000, platformFeeCents: 25, netAmountCents: 975, status: PayoutStatusValues.completed),
        ],
      );
      expect(order.allSellersPaid, true);
    });

    test('allSellersPaid false when payouts empty', () {
      final order = OrderModel(
        orderId: 'o1', userId: 'u1', totalAmountCents: 1000, subtotalCents: 1000,
        orderStatus: 'pending', shippingAddress: {}, createdAt: DateTime.now(),
        customerId: 'c1', customerEmail: 'e@e.com', taxes: {}, currency: 'CAD',
        sellerIds: ['s1'], stripeSessionId: 'sess', items: [],
      );
      expect(order.allSellersPaid, false);
    });

    test('allSellersPaid false when some payouts pending', () {
      final order = OrderModel(
        orderId: 'o1', userId: 'u1', totalAmountCents: 1000, subtotalCents: 1000,
        orderStatus: 'delivered', shippingAddress: {}, createdAt: DateTime.now(),
        customerId: 'c1', customerEmail: 'e@e.com', taxes: {}, currency: 'CAD',
        sellerIds: ['s1', 's2'], stripeSessionId: 'sess', items: [],
        sellerPayouts: [
          SellerPayout(sellerId: 's1', amountCents: 500, platformFeeCents: 10, netAmountCents: 490, status: PayoutStatusValues.completed),
          SellerPayout(sellerId: 's2', amountCents: 500, platformFeeCents: 10, netAmountCents: 490, status: PayoutStatusValues.pending),
        ],
      );
      expect(order.allSellersPaid, false);
    });

    test('toMap roundtrip', () {
      final order = OrderModel(
        orderId: 'o1', userId: 'u1', totalAmountCents: 12500, subtotalCents: 10000,
        shippingCostCents: 1500, taxAmountCents: 1000,
        orderStatus: OrderStatusValues.confirmed,
        shippingAddress: {'street': '1 St'}, createdAt: DateTime(2024, 1, 1),
        customerId: 'c1', customerEmail: 'e@e.com',
        taxes: {'GST': 5.0}, currency: 'CAD', sellerIds: ['s1'],
        stripeSessionId: 'sess', items: [],
        confirmedByClient: true, confirmedAt: DateTime(2024, 2, 1),
        platformFeeTotalCents: 250, payoutStatus: PayoutStatusValues.completed,
        ratings: {'s1': 5},
      );
      final map = order.toMap();

      expect(map[Fields.userId], 'u1');
      expect(map[Fields.totalAmountCents], 12500);
      expect(map[Fields.subtotalCents], 10000);
      expect(map[Fields.shippingCostCents], 1500);
      expect(map[Fields.taxAmountCents], 1000);
      expect(map[Fields.orderStatus], OrderStatusValues.confirmed);
      expect(map[Fields.confirmedByClient], true);
      expect(map[Fields.confirmedAt], isA<Timestamp>());
      expect(map[Fields.platformFeeTotalCents], 250);
      expect(map[Fields.payoutStatus], PayoutStatusValues.completed);
      expect(map[Fields.ratings], {'s1': 5});
    });

    test('toMap omits confirmedAt when null', () {
      final order = OrderModel(
        orderId: 'o1', userId: 'u1', totalAmountCents: 0, subtotalCents: 0,
        orderStatus: 'pending', shippingAddress: {}, createdAt: DateTime.now(),
        customerId: 'c1', customerEmail: 'e@e.com', taxes: {}, currency: 'CAD',
        sellerIds: [], stripeSessionId: 'sess', items: [],
      );
      final map = order.toMap();
      expect(map.containsKey(Fields.confirmedAt), false);
    });

    test('paymentStatus defaults to awaiting_payment when null', () {
      final order = OrderModel(
        orderId: 'o1', userId: 'u1', totalAmountCents: 0, subtotalCents: 0,
        orderStatus: 'pending', shippingAddress: {}, createdAt: DateTime.now(),
        customerId: 'c1', customerEmail: 'e@e.com', taxes: {}, currency: 'CAD',
        sellerIds: [], stripeSessionId: 'sess', items: [],
      );
      expect(order.paymentStatus, PaymentStatus.awaitingPayment.value);
    });
  });

  group('SellerPayout', () {
    test('fromMap creates correct SellerPayout', () {
      final map = {
        Fields.sellerId: 'seller123',
        Fields.stripeAccountId: 'acct_456',
        Fields.amountCents: 10000,
        Fields.platformFeeCents: 250,
        Fields.netAmountCents: 9750,
        Fields.status: 'completed',
        Fields.stripeTransferId: 'tr_789',
        Fields.payoutDate: Timestamp.fromDate(DateTime(2024, 1, 20)),
      };

      final payout = SellerPayout.fromMap(map);

      expect(payout.sellerId, 'seller123');
      expect(payout.stripeAccountId, 'acct_456');
      expect(payout.amountCents, 10000);
      expect(payout.platformFeeCents, 250);
      expect(payout.netAmountCents, 9750);
      expect(payout.amount, 100.0);
      expect(payout.platformFee, 2.5);
      expect(payout.netAmount, 97.5);
      expect(payout.paid, true);
      expect(payout.stripeTransferId, 'tr_789');
      expect(payout.payoutDate, DateTime(2024, 1, 20));
    });

    test('toMap returns correct map', () {
      final payout = SellerPayout(
        sellerId: 'seller123',
        stripeAccountId: 'acct_456',
        amountCents: 10000,
        platformFeeCents: 250,
        netAmountCents: 9750,
        status: 'pending',
      );

      final map = payout.toMap();

      expect(map[Fields.sellerId], 'seller123');
      expect(map[Fields.stripeAccountId], 'acct_456');
      expect(map[Fields.amountCents], 10000);
      expect(map[Fields.platformFeeCents], 250);
      expect(map[Fields.netAmountCents], 9750);
      expect(map[Fields.status], 'pending');
    });

    test('dollar getters compute correctly from cents', () {
      final payout = SellerPayout(sellerId: 'seller123', amountCents: 10000, platformFeeCents: 250, netAmountCents: 9750);

      expect(payout.amount, 100.0);
      expect(payout.platformFee, 2.5);
      expect(payout.netAmount, 97.5);
      expect(payout.paid, false); // status defaults to 'pending'
    });

    test('fromMap handles missing optional fields', () {
      final payout = SellerPayout.fromMap({Fields.sellerId: 's1', Fields.amountCents: 100, Fields.platformFeeCents: 5, Fields.netAmountCents: 95});
      expect(payout.stripeAccountId, null);
      expect(payout.stripeTransferId, null);
      expect(payout.payoutDate, null);
      expect(payout.failureReason, null);
      expect(payout.status, PayoutStatusValues.pending);
    });

    test('toMap includes payoutDate when present', () {
      final payout = SellerPayout(
        sellerId: 's1', amountCents: 100, platformFeeCents: 5, netAmountCents: 95,
        payoutDate: DateTime(2024, 6, 15),
      );
      final map = payout.toMap();
      expect(map[Fields.payoutDate], isA<Timestamp>());
    });

    test('toMap omits payoutDate when null', () {
      final payout = SellerPayout(sellerId: 's1', amountCents: 100, platformFeeCents: 5, netAmountCents: 95);
      final map = payout.toMap();
      expect(map.containsKey(Fields.payoutDate), false);
    });

    test('fromMap parses payoutDate from Timestamp', () {
      final ts = Timestamp.fromDate(DateTime(2024, 6, 15));
      final payout = SellerPayout.fromMap({
        Fields.sellerId: 's1', Fields.amountCents: 100, Fields.platformFeeCents: 5,
        Fields.netAmountCents: 95, Fields.payoutDate: ts,
      });
      expect(payout.payoutDate, DateTime(2024, 6, 15));
    });

    test('fromMap parses failureReason', () {
      final payout = SellerPayout.fromMap({
        Fields.sellerId: 's1', Fields.amountCents: 100, Fields.platformFeeCents: 5,
        Fields.netAmountCents: 95, Fields.failureReason: 'insufficient_funds',
      });
      expect(payout.failureReason, 'insufficient_funds');
    });
  });

  group('UserModel extended', () {
    test('canSell returns true when all conditions met', () {
      final user = UserModel(
        uid: 'u1', email: 'e@e.com', name: 'User', roles: ['seller'],
        createdAt: DateTime.now(), onboardingCompleted: true,
        chargesEnabled: true, payoutsEnabled: true, suspended: false,
      );
      expect(user.canSell, true);
    });

    test('canSell false when suspended', () {
      final user = UserModel(
        uid: 'u1', email: 'e@e.com', name: 'User', roles: ['seller'],
        createdAt: DateTime.now(), onboardingCompleted: true,
        chargesEnabled: true, payoutsEnabled: true, suspended: true,
      );
      expect(user.canSell, false);
    });

    test('canSell false when not onboarded', () {
      final user = UserModel(
        uid: 'u1', email: 'e@e.com', name: 'User', roles: ['seller'],
        createdAt: DateTime.now(), onboardingCompleted: false,
        chargesEnabled: true, payoutsEnabled: true,
      );
      expect(user.canSell, false);
    });

    test('canSell false for buyer role', () {
      final user = UserModel(
        uid: 'u1', email: 'e@e.com', name: 'User', roles: ['buyer'],
        createdAt: DateTime.now(), onboardingCompleted: true,
        chargesEnabled: true, payoutsEnabled: true,
      );
      expect(user.canSell, false);
    });

    test('canSell true for admin role', () {
      final user = UserModel(
        uid: 'u1', email: 'e@e.com', name: 'User', roles: ['admin'],
        createdAt: DateTime.now(), onboardingCompleted: true,
        chargesEnabled: true, payoutsEnabled: true,
      );
      expect(user.canSell, true);
    });

    test('canReceivePayouts true for admin with payouts enabled', () {
      final user = UserModel(
        uid: 'u1', email: 'e@e.com', name: 'Admin', roles: ['admin'],
        createdAt: DateTime.now(), payoutsEnabled: true, onboardingCompleted: true,
      );
      expect(user.canReceivePayouts, true);
    });

    test('hasPendingRequirements', () {
      final withReqs = UserModel(
        uid: 'u1', email: 'e@e.com', name: 'User', roles: ['seller'],
        createdAt: DateTime.now(), pendingRequirements: ['individual.id_number'],
      );
      expect(withReqs.hasPendingRequirements, true);

      final withoutReqs = UserModel(
        uid: 'u1', email: 'e@e.com', name: 'User', roles: ['seller'],
        createdAt: DateTime.now(),
      );
      expect(withoutReqs.hasPendingRequirements, false);
    });

    test('fromMap parses seller-specific fields', () {
      final map = {
        Fields.uid: 'u1', Fields.email: 'e@e.com', Fields.name: 'Seller',
        Fields.roles: ['seller'], Fields.createdAt: Timestamp.fromDate(DateTime(2024, 1, 1)),
        Fields.verified: true, Fields.verificationStatus: 'approved',
        Fields.platform: 'alibaba', Fields.country: 'CN',
        Fields.businessName: 'TestCo', Fields.payoutHoldDays: 14,
        Fields.pendingRequirements: ['document_upload'],
        Fields.suspended: true, Fields.suspendedAt: Timestamp.fromDate(DateTime(2024, 6, 1)),
        Fields.mfaEnabled: true, Fields.termsVersion: '2.0',
      };
      final user = UserModel.fromMap(map);

      expect(user.verified, true);
      expect(user.verificationStatus, 'approved');
      expect(user.platform, 'alibaba');
      expect(user.country, 'CN');
      expect(user.businessName, 'TestCo');
      expect(user.payoutHoldDays, 14);
      expect(user.pendingRequirements, ['document_upload']);
      expect(user.suspended, true);
      expect(user.suspendedAt, DateTime(2024, 6, 1));
      expect(user.mfaEnabled, true);
      expect(user.termsVersion, '2.0');
    });

    test('fromMap parses premium fields', () {
      final map = {
        Fields.uid: 'u1', Fields.email: 'e@e.com', Fields.name: 'Premium User',
        Fields.roles: ['buyer'], Fields.createdAt: Timestamp.fromDate(DateTime(2024, 1, 1)),
        Fields.isPremium: true,
        Fields.premiumSince: Timestamp.fromDate(DateTime(2024, 3, 1)),
        Fields.premiumExpiresAt: Timestamp.fromDate(DateTime(2025, 3, 1)),
        Fields.stripeSubscriptionId: 'sub_123',
        Fields.notifyNewProducts: true, Fields.notifyTrending: true,
      };
      final user = UserModel.fromMap(map);

      expect(user.isPremium, true);
      expect(user.premiumSince, DateTime(2024, 3, 1));
      expect(user.premiumExpiresAt, DateTime(2025, 3, 1));
      expect(user.stripeSubscriptionId, 'sub_123');
      expect(user.notifyNewProducts, true);
      expect(user.notifyTrending, true);
    });

    test('fromMap parses lastCheckoutTimestamp', () {
      final map = {
        Fields.uid: 'u1', Fields.email: 'e@e.com', Fields.name: 'User',
        Fields.roles: ['buyer'], Fields.createdAt: Timestamp.fromDate(DateTime(2024, 1, 1)),
        Fields.lastCheckoutSession: 'sess_1', Fields.lastOrderId: 'ord_1',
        Fields.lastCheckoutTimestamp: Timestamp.fromDate(DateTime(2024, 5, 1)),
      };
      final user = UserModel.fromMap(map);
      expect(user.lastCheckoutSession, 'sess_1');
      expect(user.lastOrderId, 'ord_1');
      expect(user.lastCheckoutTimestamp, DateTime(2024, 5, 1));
    });

    test('toMap includes seller-specific optional fields', () {
      final user = UserModel(
        uid: 'u1', email: 'e@e.com', name: 'Seller', roles: ['seller'],
        createdAt: DateTime(2024, 1, 1),
        stripeAccountId: 'acct_1', verified: true,
        verificationStatus: 'approved', platform: 'alibaba',
        country: 'CN', businessName: 'Co',
        pendingRequirements: ['req1'],
        lastCheckoutSession: 'sess_1', lastOrderId: 'ord_1',
        lastCheckoutTimestamp: DateTime(2024, 5, 1),
        suspendedAt: DateTime(2024, 6, 1),
      );
      final map = user.toMap();
      expect(map[Fields.stripeAccountId], 'acct_1');
      expect(map[Fields.verified], true);
      expect(map[Fields.verificationStatus], 'approved');
      expect(map[Fields.platform], 'alibaba');
      expect(map[Fields.country], 'CN');
      expect(map[Fields.businessName], 'Co');
      expect(map[Fields.pendingRequirements], ['req1']);
      expect(map[Fields.lastCheckoutSession], 'sess_1');
      expect(map[Fields.lastOrderId], 'ord_1');
      expect(map[Fields.lastCheckoutTimestamp], isA<Timestamp>());
      expect(map[Fields.suspendedAt], isA<Timestamp>());
    });

    test('toMap omits null optional fields', () {
      final user = UserModel(
        uid: 'u1', email: 'e@e.com', name: 'User', roles: ['buyer'],
        createdAt: DateTime(2024, 1, 1),
      );
      final map = user.toMap();
      expect(map.containsKey(Fields.stripeAccountId), false);
      expect(map.containsKey(Fields.verificationStatus), false);
      expect(map.containsKey(Fields.platform), false);
      expect(map.containsKey(Fields.country), false);
      expect(map.containsKey(Fields.businessName), false);
      expect(map.containsKey(Fields.lastCheckoutSession), false);
      expect(map.containsKey(Fields.lastOrderId), false);
      expect(map.containsKey(Fields.lastCheckoutTimestamp), false);
      expect(map.containsKey(Fields.suspendedAt), false);
      expect(map.containsKey(Fields.pendingRequirements), false);
    });

    test('copyWith updates premium fields', () {
      final user = UserModel(uid: 'u1', email: 'e@e.com', name: 'User', roles: ['buyer'], createdAt: DateTime.now());
      final updated = user.copyWith(isPremium: true, premiumSince: DateTime(2024, 1, 1), stripeSubscriptionId: 'sub_1');
      expect(updated.isPremium, true);
      expect(updated.premiumSince, DateTime(2024, 1, 1));
      expect(updated.stripeSubscriptionId, 'sub_1');
      expect(updated.email, 'e@e.com');
    });
  });

  group('ProductModel extended', () {
    test('fromMap with delivery options', () {
      final map = {
        Fields.productId: 'p1', Fields.name: 'Product', Fields.price: 50.0,
        Fields.categoryId: 1, Fields.sellerId: 's1',
        Fields.deliveryOptions: [
          {'type': 'standard', 'costCents': 999, 'estimatedDays': 5},
          {'type': 'express', 'costCents': 1999, 'estimatedDays': 2},
        ],
      };
      final product = ProductModel.fromMap(map);
      expect(product.deliveryOptions.length, 2);
      expect(product.deliveryOptions.first.type, 'standard');
    });

    test('fromMap without delivery options uses defaults', () {
      final map = {Fields.productId: 'p1', Fields.name: 'Product', Fields.price: 50.0, Fields.categoryId: 1};
      final product = ProductModel.fromMap(map);
      expect(product.deliveryOptions, isNotEmpty);
    });

    test('fromMap with digital product fields', () {
      final map = {
        Fields.productId: 'p1', Fields.name: 'Software', Fields.price: 99.0,
        Fields.categoryId: 1, Fields.isDigital: true, Fields.digitalType: 'software',
        Fields.digitalBuilds: {'windows': 'https://dl.com/win', 'mac': 'https://dl.com/mac'},
        Fields.isAgeRestricted: true,
      };
      final product = ProductModel.fromMap(map);
      expect(product.isDigital, true);
      expect(product.digitalType, 'software');
      expect(product.digitalBuilds, {'windows': 'https://dl.com/win', 'mac': 'https://dl.com/mac'});
      expect(product.isAgeRestricted, true);
    });

    test('fromMap with perishable and local delivery', () {
      final map = {
        Fields.productId: 'p1', Fields.name: 'Fresh Bread', Fields.price: 5.0,
        Fields.categoryId: 1, Fields.isPerishable: true,
        Fields.isLocalDeliveryOnly: true, Fields.minimumOrderQuantity: 3,
        Fields.freeShipping: true,
      };
      final product = ProductModel.fromMap(map);
      expect(product.isPerishable, true);
      expect(product.isLocalDeliveryOnly, true);
      expect(product.minimumOrderQuantity, 3);
      expect(product.freeShipping, true);
    });

    test('fromMap with dimensions', () {
      final map = {
        Fields.productId: 'p1', Fields.name: 'Box', Fields.price: 25.0, Fields.categoryId: 1,
        Fields.weightKg: 2.5, Fields.lengthCm: 30.0, Fields.widthCm: 20.0, Fields.heightCm: 15.0,
        Fields.taxCode: 'txcd_10000000',
      };
      final product = ProductModel.fromMap(map);
      expect(product.weightKg, 2.5);
      expect(product.lengthCm, 30.0);
      expect(product.widthCm, 20.0);
      expect(product.heightCm, 15.0);
      expect(product.taxCode, 'txcd_10000000');
    });

    test('getDeliveryOption returns matching option', () {
      final product = ProductModel(
        id: 'p1', name: 'Test', price: 10.0, imageUrls: [],
        sellerAddress: Address(street: '', city: '', state: '', postalCode: '', country: ''),
        description: '', sellerId: 's1', stockQuantity: 10, categoryId: 1, keywords: [],
        deliveryOptions: [
          SellerDeliveryOption.fromMap({'type': 'standard', 'costCents': 999, 'estimatedDays': 5})!,
          SellerDeliveryOption.fromMap({'type': 'express', 'costCents': 1999, 'estimatedDays': 2})!,
        ],
      );
      expect(product.getDeliveryOption(DeliverySpeed.standard)?.type, 'standard');
      expect(product.getDeliveryOption(DeliverySpeed.express)?.type, 'express');
      expect(product.getDeliveryOption(DeliverySpeed.sameDay), null);
    });

    test('enabledDeliveryOptions returns all options', () {
      final product = ProductModel(
        id: 'p1', name: 'Test', price: 10.0, imageUrls: [],
        sellerAddress: Address(street: '', city: '', state: '', postalCode: '', country: ''),
        description: '', sellerId: 's1', stockQuantity: 10, categoryId: 1, keywords: [],
        deliveryOptions: [
          SellerDeliveryOption.fromMap({'type': 'standard', 'costCents': 999, 'estimatedDays': 5})!,
        ],
      );
      expect(product.enabledDeliveryOptions.length, 1);
    });

    test('toMap includes all fields', () {
      final product = ProductModel(
        id: 'p1', name: 'Test', price: 10.0, imageUrls: ['img.jpg'],
        sellerAddress: Address(street: '1 St', city: 'T', state: 'ON', postalCode: 'M5V', country: 'CA'),
        description: 'Desc', sellerId: 's1', stockQuantity: 50, categoryId: 1,
        keywords: ['test'], weightKg: 1.0, lengthCm: 10.0, widthCm: 5.0, heightCm: 3.0,
        taxCode: 'txcd_1', isPerishable: true, isDigital: true, isAgeRestricted: true,
        lifecycleStatus: 'active', deletedAt: Timestamp.fromDate(DateTime(2024, 12, 1)),
      );
      final map = product.toMap();
      expect(map[Fields.weightKg], 1.0);
      expect(map[Fields.lengthCm], 10.0);
      expect(map[Fields.widthCm], 5.0);
      expect(map[Fields.heightCm], 3.0);
      expect(map[Fields.taxCode], 'txcd_1');
      expect(map[Fields.isPerishable], true);
      expect(map[Fields.isDigital], true);
      expect(map[Fields.isAgeRestricted], true);
      expect(map[Fields.lifecycleStatus], 'active');
      expect(map[Fields.deletedAt], isA<Timestamp>());
    });

    test('toMap omits null dimension and optional fields', () {
      final product = ProductModel(
        id: 'p1', name: 'Test', price: 10.0, imageUrls: [],
        sellerAddress: Address(street: '', city: '', state: '', postalCode: '', country: ''),
        description: '', sellerId: 's1', stockQuantity: 10, categoryId: 1, keywords: [],
      );
      final map = product.toMap();
      expect(map.containsKey(Fields.weightKg), false);
      expect(map.containsKey(Fields.lengthCm), false);
      expect(map.containsKey(Fields.widthCm), false);
      expect(map.containsKey(Fields.heightCm), false);
      expect(map.containsKey(Fields.taxCode), false);
      expect(map.containsKey(Fields.deletedAt), false);
    });

    test('fromMap with approvalRejectionReason', () {
      final map = {
        Fields.productId: 'p1', Fields.name: 'Rejected', Fields.price: 10.0, Fields.categoryId: 1,
        Fields.approvalRejectionReason: 'Inappropriate content',
        Fields.lifecycleStatus: ProductLifecycleStatusValues.rejected,
      };
      final product = ProductModel.fromMap(map);
      expect(product.approvalRejectionReason, 'Inappropriate content');
      expect(product.lifecycleStatus, ProductLifecycleStatusValues.rejected);
    });

    test('_parseAddress handles non-map value', () {
      final map = {Fields.productId: 'p1', Fields.name: 'Test', Fields.price: 10.0, Fields.categoryId: 1, Fields.sellerAddress: 'not a map'};
      final product = ProductModel.fromMap(map);
      expect(product.sellerAddress.street, '');
    });

    test('_parseStringList handles non-list value', () {
      final map = {Fields.productId: 'p1', Fields.name: 'Test', Fields.price: 10.0, Fields.categoryId: 1, Fields.imageUrls: 'not a list'};
      final product = ProductModel.fromMap(map);
      expect(product.imageUrls, isEmpty);
    });
  });

  group('FavoriteItem', () {
    test('toMap roundtrip', () {
      final now = DateTime(2024, 6, 15);
      final item = FavoriteItem(productId: 'p1', dateFavorited: now);
      final map = item.toMap();
      expect(map[Fields.productId], 'p1');
      expect((map[Fields.dateFavorited] as Timestamp).toDate(), now);
    });
  });
}
