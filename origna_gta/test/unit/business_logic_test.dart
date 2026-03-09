import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/utils/utils.dart' hide Address, UserModel, ProductModel, CartModel, CartItemModel, SellerPayout;
import 'package:origna_gta/models/models.dart';

void main() {
  group('Tax Calculations', () {
    test('getTaxRate returns correct rate for Ontario', () {
      expect(getTaxRate('ON'), 0.13);
    });

    test('getTaxRate returns correct rate for Alberta', () {
      expect(getTaxRate('AB'), 0.05);
    });

    test('getTaxRate returns correct rate for Quebec', () {
      expect(getTaxRate('QC'), 0.14975);
    });

    test('getTaxRate returns correct rate for British Columbia', () {
      expect(getTaxRate('BC'), 0.12);
    });

    test('getTaxRate returns correct rate for Atlantic provinces (HST)', () {
      expect(getTaxRate('NS'), 0.14);  // Changed from 15% to 14% on April 1, 2025 (CRA)
      expect(getTaxRate('NB'), 0.15);
      expect(getTaxRate('NL'), 0.15);
      expect(getTaxRate('PE'), 0.15);
    });

    test('getTaxRate returns default for unknown province', () {
      expect(getTaxRate('XX'), 0.13);
    });

    test('calculateDetailedTaxes returns empty map when address is null', () {
      final result = calculateDetailedTaxes(null, 100.0);
      expect(result, isEmpty);
    });

    test('calculateDetailedTaxes returns correct breakdown for Ontario', () {
      final address = Address(
        street: '123 Main St',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5V 1A1',
        country: 'Canada',
      );

      final result = calculateDetailedTaxes(address, 100.0);

      expect(result.containsKey('HST'), true);
      expect(result['HST'], closeTo(13.0, 0.01));
    });

    test('calculateDetailedTaxes returns correct breakdown for BC with GST+PST', () {
      final address = Address(
        street: '456 Oak Ave',
        city: 'Vancouver',
        state: 'BC',
        postalCode: 'V6B 1A1',
        country: 'Canada',
      );

      final result = calculateDetailedTaxes(address, 100.0);

      expect(result.containsKey('GST'), true);
      expect(result.containsKey('PST'), true);
      expect(result['GST'], closeTo(5.0, 0.01));
      expect(result['PST'], closeTo(7.0, 0.01));
    });

    test('calculateDetailedTaxes returns correct breakdown for Quebec with GST+QST', () {
      final address = Address(
        street: '789 Rue St',
        city: 'Montreal',
        state: 'QC',
        postalCode: 'H2X 1A1',
        country: 'Canada',
      );

      final result = calculateDetailedTaxes(address, 100.0);

      expect(result.containsKey('GST'), true);
      expect(result.containsKey('QST'), true);
      expect(result['GST'], closeTo(5.0, 0.01));
      expect(result['QST'], closeTo(9.975, 0.01));
    });

    test('calculateDetailedTaxes returns correct breakdown for Alberta (GST only)', () {
      final address = Address(
        street: '100 Centre St',
        city: 'Calgary',
        state: 'AB',
        postalCode: 'T2P 1A1',
        country: 'Canada',
      );

      final result = calculateDetailedTaxes(address, 100.0);

      expect(result.length, 1);
      expect(result.containsKey('GST'), true);
      expect(result['GST'], closeTo(5.0, 0.01));
    });
  });

  group('Search Keywords Generation', () {
    test('generateSearchKeywords creates prefix keywords for single word', () {
      final keywords = generateSearchKeywords('Nike');

      expect(keywords.contains('n'), true);
      expect(keywords.contains('ni'), true);
      expect(keywords.contains('nik'), true);
      expect(keywords.contains('nike'), true);
    });

    test('generateSearchKeywords creates prefix keywords for multiple words', () {
      final keywords = generateSearchKeywords('Nike Shoe');

      // Nike prefixes
      expect(keywords.contains('n'), true);
      expect(keywords.contains('ni'), true);
      expect(keywords.contains('nik'), true);
      expect(keywords.contains('nike'), true);

      // Shoe prefixes
      expect(keywords.contains('s'), true);
      expect(keywords.contains('sh'), true);
      expect(keywords.contains('sho'), true);
      expect(keywords.contains('shoe'), true);

      // Full name
      expect(keywords.contains('nike shoe'), true);
    });

    test('generateSearchKeywords converts to lowercase', () {
      final keywords = generateSearchKeywords('NIKE SHOE');

      expect(keywords.contains('nike'), true);
      expect(keywords.contains('shoe'), true);
      expect(keywords.contains('NIKE'), false);
    });

    test('generateSearchKeywords removes duplicates', () {
      final keywords = generateSearchKeywords('Test Test');

      // Should not have duplicate 'test'
      final testCount = keywords.where((k) => k == 'test').length;
      expect(testCount, 1);
    });

    test('generateSearchKeywords handles empty string', () {
      final keywords = generateSearchKeywords('');

      // Only the full name (empty) should be present
      expect(keywords.length, 1);
      expect(keywords.contains(''), true);
    });
  });

  group('Address Parsing', () {
    test('parseAddressSuggestion extracts correct fields', () {
      final suggestion = {
        'properties': {
          'housenumber': '123',
          'street': 'Main Street',
          'formatted': '123 Main Street, Toronto, ON M5V 1A1, Canada',
          'city': 'Toronto',
          'state_code': 'ON',
          'postcode': 'M5V 1A1',
        },
        'geometry': {
          'coordinates': [-79.3832, 43.6532],
        },
      };

      final result = parseAddressSuggestion(suggestion);

      expect(result.city, 'Toronto');
      expect(result.state, 'ON');
      expect(result.postalCode, 'M5V 1A1');
      expect(result.latitude, 43.6532);
      expect(result.longitude, -79.3832);
    });

    test('parseAddressSuggestion handles missing house number', () {
      final suggestion = {
        'properties': {
          'street': 'Main Street',
          'formatted': 'Main Street, Toronto, ON',
          'city': 'Toronto',
          'state_code': 'ON',
          'postcode': 'M5V 1A1',
        },
        'geometry': {
          'coordinates': [-79.3832, 43.6532],
        },
      };

      final result = parseAddressSuggestion(suggestion);

      expect(result.street, 'Main Street, Toronto, ON');
    });

    test('parseAddressSuggestion handles missing fields with defaults', () {
      final suggestion = {
        'properties': {},
        'geometry': {
          'coordinates': [0, 0],
        },
      };

      final result = parseAddressSuggestion(suggestion);

      expect(result.city, '');
      expect(result.state, 'ON'); // Default
      expect(result.postalCode, '');
    });
  });
}
