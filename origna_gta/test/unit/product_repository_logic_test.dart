import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';

import 'product_repository_logic_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFunctions>(),
])

void main() {
  group('sanitizeProductForFirestore', () {
    test('removes server-controlled fields', () {
      final raw = {
        Fields.productId: 'should-be-removed',
        Fields.ratingCount: 5,
        Fields.rating: 4.5,
        Fields.sellerId: 'seller1',
        Fields.lifecycleStatus: 'active',
        'name': 'Test Product',
      };

      final result = sanitizeProductForFirestore(raw);

      expect(result.containsKey(Fields.productId), isFalse);
      expect(result.containsKey(Fields.ratingCount), isFalse);
      expect(result.containsKey(Fields.rating), isFalse);
      expect(result.containsKey(Fields.sellerId), isFalse);
      expect(result.containsKey(Fields.lifecycleStatus), isFalse);
      expect(result['name'], 'Test Product');
    });

    test('normalizes empty apartment to null in sellerAddress', () {
      final raw = {
        Fields.sellerAddress: {
          'street': '123 Main St',
          'apartment': '',
          'city': 'Toronto',
        },
      };

      final result = sanitizeProductForFirestore(raw);
      final addr = result[Fields.sellerAddress] as Map;
      expect(addr['apartment'], isNull);
    });

    test('preserves non-empty apartment in sellerAddress', () {
      final raw = {
        Fields.sellerAddress: {
          'street': '123 Main St',
          'apartment': 'Unit 5',
          'city': 'Toronto',
        },
      };

      final result = sanitizeProductForFirestore(raw);
      final addr = result[Fields.sellerAddress] as Map;
      expect(addr['apartment'], 'Unit 5');
    });

    test('normalizes whitespace-only apartment to null', () {
      final raw = {
        Fields.sellerAddress: {
          'apartment': '   ',
        },
      };

      final result = sanitizeProductForFirestore(raw);
      final addr = result[Fields.sellerAddress] as Map;
      expect(addr['apartment'], isNull);
    });

    test('adds serverTimestamp when ensureDateCreated is true', () {
      final raw = {'name': 'Test'};
      final result = sanitizeProductForFirestore(raw, ensureDateCreated: true);
      expect(result[Fields.createdAt], isA<FieldValue>());
    });

    test('converts string createdAt to Timestamp', () {
      final raw = {Fields.createdAt: '2024-01-01T00:00:00.000Z'};
      final result = sanitizeProductForFirestore(raw);
      expect(result[Fields.createdAt], isA<Timestamp>());
    });

    test('converts invalid string createdAt to serverTimestamp', () {
      final raw = {Fields.createdAt: 'not-a-date'};
      final result = sanitizeProductForFirestore(raw);
      expect(result[Fields.createdAt], isA<FieldValue>());
    });

    test('converts DateTime createdAt to Timestamp', () {
      final dt = DateTime(2024, 6, 15);
      final raw = {Fields.createdAt: dt};
      final result = sanitizeProductForFirestore(raw);
      final ts = result[Fields.createdAt] as Timestamp;
      expect(ts.toDate(), dt);
    });

    test('does not modify original map', () {
      final raw = {
        Fields.productId: 'p1',
        'name': 'Test',
      };
      sanitizeProductForFirestore(raw);
      expect(raw.containsKey(Fields.productId), isTrue);
    });
  });

  group('ProductQueryResult', () {
    test('construction with defaults', () {
      final result = ProductQueryResult(products: [], hasMore: false);
      expect(result.products, isEmpty);
      expect(result.hasMore, isFalse);
      expect(result.lastDocument, isNull);
    });
  });
}

