import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/utils.dart' hide Address, UserModel, ProductModel, CartModel, CartItemModel, SellerPayout;
import 'package:origna_gta/models/models.dart';

void main() {
  group('Shipping Calculation Logic', () {
    final mockAddress = Address(
      street: '123 Test St',
      city: 'Toronto',
      state: ProvinceCodeValues.ontario,
      postalCode: PlaceholderAddressValues.defaultPostalCode,
      country: CountryValues.canada,
    );

    CartItemDetailModel createMockItem({
      double? weightKg,
      double? lengthCm,
      double? widthCm,
      double? heightCm,
      int quantity = 1,
      List<SellerDeliveryOption>? deliveryOptions,
    }) {
      return CartItemDetailModel(
        productId: 'prod_123',
        name: 'Test Product',
        description: 'Test Description',
        price: 10.0,
        imageUrls: [],
        quantity: quantity,
        createdAt: Timestamp.now(),
        sellerAddress: mockAddress,
        sellerId: 'seller_123',
        sellerName: 'Test Seller',
        weightKg: weightKg,
        lengthCm: lengthCm,
        widthCm: widthCm,
        heightCm: heightCm,
        deliveryOptions: deliveryOptions ?? [],
      );
    }

    test('calculateTieredShipping applies base rate for local distance', () {
      final item = createMockItem();
      final cost = calculateTieredShipping(10.0, [item], DeliverySpeed.standard);
      // Base cost for <=15km is 1.99. Default weight 0.5kg (no surcharge)
      expect(cost, closeTo(1.99, 0.01));
    });

    test('calculateTieredShipping applies weight surcharges correctly', () {
      final heavyItem = createMockItem(weightKg: 5.0, quantity: 1);
      final cost = calculateTieredShipping(10.0, [heavyItem], DeliverySpeed.standard);

      // Base local cost: 1.99
      // Weight surcharge: (5.0 - 2.0) * 1.5 = 4.50
      // Total: 1.99 + 4.50 = 6.49
      expect(cost, closeTo(6.49, 0.01));
    });

    test('calculateTieredShipping handles volumetric weight', () {
      // Light but bulky item: 1kg, 50x50x50 cm
      // Volumetric weight: (50*50*50)/5000 = 25kg
      final bulkyItem = createMockItem(weightKg: 1.0, lengthCm: 50, widthCm: 50, heightCm: 50);
      final cost = calculateTieredShipping(10.0, [bulkyItem], DeliverySpeed.standard);

      // Base: 1.99
      // Vol weight: 25.0
      // Surcharge: (25.0 - 2.0) * 1.5 = 34.50
      // Total: 1.99 + 34.50 = 36.49
      expect(cost, closeTo(36.49, 0.01));
    });

    test('calculateTieredShipping applies speed multipliers', () {
      final item = createMockItem();

      final standardCost = calculateTieredShipping(10.0, [item], DeliverySpeed.standard);
      final expressCost = calculateTieredShipping(10.0, [item], DeliverySpeed.express);
      final sameDayCost = calculateTieredShipping(10.0, [item], DeliverySpeed.sameDay);

      expect(standardCost, closeTo(1.99, 0.01));
      expect(expressCost, closeTo(1.99 * 4.0, 0.01));
      expect(sameDayCost, closeTo(1.99 * 4.5, 0.01));
    });

    test('calculateTieredShipping handles multiple items', () {
      final item1 = createMockItem(quantity: 1);
      final item2 = createMockItem(quantity: 1);

      final cost = calculateTieredShipping(10.0, [item1, item2], DeliverySpeed.standard);

      // Base: 1.99
      // Additional items: (2 - 1) * (1.99 * 0.15) = 0.2985
      // Total: ~2.29
      expect(cost, closeTo(2.29, 0.01));
    });

    test('fallback shipping uses regional rates', () {
      final items = [createMockItem()];

      // Same province: 12.99
      final sameProv = calculateFallbackShipping(items, ProvinceCodeValues.ontario, ProvinceCodeValues.ontario);
      expect(sameProv, closeTo(12.99, 0.01));

      // Different province: 18.99+
      final diffProv = calculateFallbackShipping(items, ProvinceCodeValues.ontario, ProvinceCodeValues.britishColumbia);
      expect(diffProv, greaterThan(12.99));
    });

    test('calculateTieredShipping applies speed multipliers correctly even with surcharges', () {
      final heavyItem = createMockItem(weightKg: 10.0);
      // Base local: 1.99
      // Weight surcharge: (10 - 2) * 1.5 = 12.0
      // Subtotal: 13.99

      final expressCost = calculateTieredShipping(10.0, [heavyItem], DeliverySpeed.express);
      // Express subtotal: 13.99 * 4.0 = 55.96

      expect(expressCost, closeTo(55.96, 0.01));
    });
  });
}
