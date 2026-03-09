import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

void main() {
  group('sanitizeProductForFirestore', () {
    test('normalizes empty seller apartment to null', () {
      final input = <String, dynamic>{
        Fields.name: 'Produit Test',
        Fields.sellerAddress: <String, dynamic>{
          'street': '123 Rue Test',
          'apartment': '',
          'city': 'Toronto',
          'state': 'ON',
          'postalCode': 'M5V3L9',
          'country': 'Canada',
        },
      };

      final sanitized = sanitizeProductForFirestore(input);
      final address = sanitized[Fields.sellerAddress] as Map<String, dynamic>;

      expect(address['apartment'], isNull);
    });
  });
}
