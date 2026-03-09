import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/models/generated/models.dart';

void main() {
  group('ProductExtension Tests', () {
    final baseProduct = Product(
      productId: 'p1',
      name: 'Test',
      price: 100.0,
      description: 'Desc',
      imageUrls: [],
      sellerId: 's1',
      categoryId: 1,
      stockQuantity: 10,
      createdAt: DateTime.now(),
    );

    test('deliveryEstimateText', () {
      expect(baseProduct.deliveryEstimateText, contains('business days'));
      
      final digitalProduct = baseProduct.copyWith(isDigital: true);
      expect(digitalProduct.deliveryEstimateText, 'Instant delivery');
      
      final localProduct = baseProduct.copyWith(isLocalDeliveryOnly: true);
      expect(localProduct.deliveryEstimateText, contains('local'));
    });

    test('isLowStock', () {
      expect(baseProduct.isLowStock, isFalse);
      
      final lowStockProduct = baseProduct.copyWith(stockQuantity: 3);
      expect(lowStockProduct.isLowStock, isTrue);
      
      final outOfStockProduct = baseProduct.copyWith(stockQuantity: 0);
      expect(outOfStockProduct.isLowStock, isFalse); // isLowStock is stock <= threshold && stock > 0
    });

    test('profit and marginPercent', () {
      final productWithCost = baseProduct.copyWith(cost: 60.0);
      expect(productWithCost.profit, 40.0);
      expect(productWithCost.marginPercent, 40.0);
      
      final productNoCost = baseProduct.copyWith(cost: null);
      expect(productNoCost.profit, isNull);
      expect(productNoCost.marginPercent, isNull);
    });

    test('supplierRegion', () {
      final intlProduct = baseProduct.copyWith(
        supplier: const SupplierInfo(type: 'aliexpress')
      );
      expect(intlProduct.deliveryInfo.supplierRegion, 'China');
      
      final localProduct = baseProduct.copyWith(
        sellerAddress: const Address(street: '', city: 'Toronto', state: 'ON', postalCode: '', country: 'Canada')
      );
      expect(localProduct.deliveryInfo.supplierRegion, contains('Toronto'));
    });
  });
}
