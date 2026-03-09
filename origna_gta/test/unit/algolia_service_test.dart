import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/services/algolia_service.dart';

void main() {
  group('AlgoliaService', () {
    test('create returns unavailable instance when keys are empty', () {
      final service = AlgoliaService.create(appId: '', searchApiKey: '');
      expect(service.isAvailable, isFalse);
    });

    test('hitToProductMap parses correctly', () {
      final hit = {'objectID': 'p1', Fields.name: 'Product 1', Fields.price: 10.0};
      final result = AlgoliaService.hitToProductMap(hit);
      expect(result[Fields.productId], 'p1');
      expect(result[Fields.name], 'Product 1');
      expect(result[Fields.price], 10.0);
    });

    test('search does nothing if unavailable', () {
      final service = AlgoliaService.create(appId: '', searchApiKey: '');
      // Should not crash
      service.search('test');
    });
  });
}
