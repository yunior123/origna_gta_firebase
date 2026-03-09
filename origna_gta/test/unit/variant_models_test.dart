import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/features/products/variant_models.dart';

void main() {
  group('ProductVariantEntry', () {
    final testMap = {
      'variantId': 'v1',
      'optionValues': {'Size': 'M', 'Color': 'Red'},
      'priceCents': 999,
      'stockQuantity': 10,
      'sku': 'SKU123',
      'isActive': true,
    };

    test('fromMap handles priceCents', () {
      final entry = ProductVariantEntry.fromMap(testMap);
      expect(entry.variantId, 'v1');
      expect(entry.priceCents, 999);
      expect(entry.priceDollars, 9.99);
      expect(entry.optionValues['Size'], 'M');
    });

    test('fromMap handles old price format', () {
      final oldMap = {
        'optionValues': {},
        'price': 10.5,
      };
      final entry = ProductVariantEntry.fromMap(oldMap);
      expect(entry.priceCents, 1050);
    });

    test('toMap returns correct map', () {
      final entry = ProductVariantEntry.fromMap(testMap);
      final map = entry.toMap();
      expect(map['variantId'], 'v1');
      expect(map['priceCents'], 999);
    });

    test('copyWith works', () {
      final entry = ProductVariantEntry.fromMap(testMap);
      final entry2 = entry.copyWith(priceCents: 1500, stockQuantity: 5);
      expect(entry2.priceCents, 1500);
      expect(entry2.stockQuantity, 5);
      expect(entry2.variantId, 'v1'); // unchanged
    });

    test('equality and hashCode works', () {
      final entry1 = ProductVariantEntry.fromMap(testMap);
      final entry2 = ProductVariantEntry.fromMap(testMap);
      expect(entry1, entry2);
      expect(entry1.hashCode, entry2.hashCode);
    });
  });

  group('VariantOption', () {
    final testMap = {
      'name': 'Size',
      'values': ['S', 'M', 'L'],
    };

    test('fromMap works', () {
      final option = VariantOption.fromMap(testMap);
      expect(option.name, 'Size');
      expect(option.values, ['S', 'M', 'L']);
    });

    test('toMap works', () {
      final option = VariantOption.fromMap(testMap);
      final map = option.toMap();
      expect(map['name'], 'Size');
      expect(map['values'], ['S', 'M', 'L']);
    });

    test('copyWith works', () {
      final option = VariantOption.fromMap(testMap);
      final option2 = option.copyWith(name: 'Color');
      expect(option2.name, 'Color');
      expect(option2.values, ['S', 'M', 'L']);
    });

    test('equality and hashCode works', () {
      final option1 = VariantOption.fromMap(testMap);
      final option2 = VariantOption.fromMap(testMap);
      expect(option1, option2);
      expect(option1.hashCode, option2.hashCode);
    });
  });
}
