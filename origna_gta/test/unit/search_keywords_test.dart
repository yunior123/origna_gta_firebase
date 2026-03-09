import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/utils/utils.dart';

void main() {
  group('generateSearchKeywords', () {
    test('limits keyword count to 30 for long names', () {
      const longName =
          'Produit Test Integration 12345678901234567890 09876543210987654321';

      final keywords = generateSearchKeywords(longName);

      expect(keywords.length, lessThanOrEqualTo(30));
    });

    test('always includes cleaned full name', () {
      const name = '  Chaise Ergonomique Pro  ';

      final keywords = generateSearchKeywords(name);

      expect(keywords, contains('chaise ergonomique pro'));
    });
  });
}
