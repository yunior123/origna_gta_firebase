// OrignaGta App Smoke Test
//
// Basic test to verify the app can be instantiated without errors.
// More comprehensive tests are in the unit/ and widget/ subdirectories.

import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/utils/utils.dart';

void main() {
  group('App Smoke Tests', () {
    test('Address model can be instantiated', () {
      final address = Address(street: '123 Test St', city: 'Toronto', state: 'ON', postalCode: 'M5V 1A1', country: 'Canada');

      expect(address.city, 'Toronto');
      expect(address.state, 'ON');
    });

    test('UserModel can be instantiated', () {
      final user = UserModel(uid: 'test_user', email: 'test@example.com', name: 'Test User', roles: ['buyer'], createdAt: DateTime.now());

      expect(user.uid, 'test_user');
      expect(user.roles.contains('buyer'), true);
    });

    test('ProductModel can be instantiated', () {
      final product = ProductModel(
        id: 'prod_123',
        name: 'Test Product',
        price: 29.99,
        imageUrls: [],
        sellerAddress: Address(street: '123 Test St', city: 'Toronto', state: 'ON', postalCode: 'M5V 1A1', country: 'Canada'),
        description: 'A test product',
        sellerId: 'seller_123',
        stockQuantity: 10,
        categoryId: 1,
        keywords: ['test'],
      );

      expect(product.name, 'Test Product');
      expect(product.price, 29.99);
    });

    test('Tax calculation works for all provinces', () {
      // Verify all provinces have tax rates
      final provinces = ['ON', 'BC', 'AB', 'QC', 'MB', 'SK', 'NS', 'NB', 'NL', 'PE', 'NT', 'YT', 'NU'];

      for (final province in provinces) {
        final rate = getTaxRate(province);
        expect(rate, greaterThan(0), reason: '$province should have a positive tax rate');
      }
    });
  });
}
