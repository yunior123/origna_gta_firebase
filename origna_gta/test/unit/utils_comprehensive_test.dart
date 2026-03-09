import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:origna_gta/core/errors/error_codes.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/utils.dart';

import '../test_utils.dart';
import 'utils_comprehensive_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<User>(),
  MockSpec<NavigatorObserver>(),
  MockSpec<http.Client>(),
])
void main() {
  setUp(() {
    initTestMocks();
  });

  group('Tax Utilities', () {
    test('calculateDetailedTaxes should return correct breakdown for ON', () {
      final addressON = Address(street: '123 Main', city: 'Toronto', state: 'ON', postalCode: 'M1M1M1', country: 'CA');
      final breakdownON = calculateDetailedTaxes(addressON, 100);
      expect(breakdownON['HST'], 13.0);
    });

    test('calculateDetailedTaxes should return correct breakdown for QC', () {
      final addressQC = Address(street: '123 Main', city: 'Montreal', state: 'QC', postalCode: 'H1H1H1', country: 'CA');
      final breakdownQC = calculateDetailedTaxes(addressQC, 100);
      expect(breakdownQC['GST'], 5.0);
      expect(breakdownQC['QST'], closeTo(9.975, 0.001));
    });

    test('calculateDetailedTaxes with null address returns empty map', () {
      final nullAddress = calculateDetailedTaxes(null, 100);
      expect(nullAddress, isEmpty);
    });

    test('getTaxRate should return correct combined rates', () {
      expect(getTaxRate('ON'), 0.13);
      expect(getTaxRate('QC'), 0.14975);
      expect(getTaxRate('AB'), 0.05);
      expect(getTaxRate('UNKNOWN_PROVINCE'), 0.13);
    });
  });

  group('Validation Utilities', () {
    test('isValidTaxCode', () {
      expect(isValidTaxCode(null), isTrue);
      expect(isValidTaxCode(''), isTrue);
      expect(isValidTaxCode('txcd_12345678'), isTrue);
      expect(isValidTaxCode('txcd_1234'), isFalse);
      expect(isValidTaxCode('invalid'), isFalse);
    });

    test('validateVideoFile', () {
      final valid = validateVideoFile(sizeInBytes: 100, durationInSeconds: 10);
      expect(valid, VideoValidationError.none);

      final tooLarge = validateVideoFile(sizeInBytes: 999999999999, durationInSeconds: 10);
      expect(tooLarge, VideoValidationError.tooLarge);

      final tooLong = validateVideoFile(sizeInBytes: 100, durationInSeconds: 999999);
      expect(tooLong, VideoValidationError.tooLong);
    });
  });

  group('Data Transformation Utilities', () {
    test('dynamicToTimestamp', () {
      final ts = Timestamp(100, 100);
      expect(dynamicToTimestamp(ts), ts);

      final dt = DateTime(2020, 1, 1);
      final converted = dynamicToTimestamp(dt);
      expect(converted.toDate(), dt);

      final fallback = dynamicToTimestamp('invalid');
      expect(fallback, isA<Timestamp>());
    });

    test('generateSearchKeywords', () {
      final empty = generateSearchKeywords('');
      expect(empty, ['']);

      final keywords = generateSearchKeywords('Hello World');
      expect(keywords, contains('hello world'));
      expect(keywords, contains('h'));
      expect(keywords, contains('hel'));
      expect(keywords, contains('w'));
      expect(keywords, contains('wor'));
      expect(keywords.length, lessThanOrEqualTo(30));
    });
  });

  group('UI Utilities', () {
    testWidgets('getCrossAxisCount returns expected column count', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          final count = getCrossAxisCount(context);
          expect(count, isNotNull);
          return const SizedBox();
        }),
      ));
    });

    testWidgets('showLoginPrompt can be called without crashing', (tester) async {
      await tester.pumpWidget(TestWrapper(
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('route')),
        ),
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showLoginPrompt(context),
            child: const Text('Show'),
          );
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Dialog should have appeared with some content
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('showEmailVerificationDialog displays and allows resending email', (tester) async {
      final mockAuth = MockFirebaseAuth();
      final mockUser = MockUser();
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.email).thenReturn('test@example.com');

      await tester.pumpWidget(TestWrapper(
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showEmailVerificationDialog(context, auth: mockAuth, onResend: () {}),
            child: const Text('Show'),
          );
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('email_verification.title'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
    });
  });

  group('Address Validation', () {
    test('hasValidAddress returns false for null', () {
      expect(hasValidAddress(null), isFalse);
    });

    test('hasValidAddress returns true for valid ON address', () {
      final address = Address(
        street: '123 Main St',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5V 1A1',
        country: 'Canada',
      );
      expect(hasValidAddress(address), isTrue);
    });

    test('hasValidAddress returns false for empty street', () {
      final address = Address(street: '', city: 'Toronto', state: 'ON', postalCode: 'M5V', country: 'Canada');
      expect(hasValidAddress(address), isFalse);
    });

    test('hasValidAddress returns false for invalid province', () {
      final address = Address(street: '123 Main', city: 'City', state: 'XX', postalCode: 'M5V', country: 'Canada');
      expect(hasValidAddress(address), isFalse);
    });

    test('hasValidAddress returns false for empty city', () {
      final address = Address(street: '123 Main', city: '', state: 'ON', postalCode: 'M5V', country: 'Canada');
      expect(hasValidAddress(address), isFalse);
    });

    test('hasValidAddress returns false for empty postalCode', () {
      final address = Address(street: '123 Main', city: 'Toronto', state: 'ON', postalCode: '', country: 'Canada');
      expect(hasValidAddress(address), isFalse);
    });

    test('hasValidAddress returns false for empty country', () {
      final address = Address(street: '123 Main', city: 'Toronto', state: 'ON', postalCode: 'M5V', country: '');
      expect(hasValidAddress(address), isFalse);
    });
  });

  group('parseAddressSuggestion', () {
    test('parses full geoapify suggestion', () {
      final suggestion = {
        'properties': {
          'housenumber': '123',
          'street': 'Main St',
          'formatted': '123 Main St, Toronto, ON',
          'city': 'Toronto',
          'state_code': 'ON',
          'postcode': 'M5V 1A1',
        },
        'geometry': {
          'coordinates': [-79.383, 43.653],
        },
      };
      final result = parseAddressSuggestion(suggestion);
      expect(result.street, '123 Main St, Toronto, ON');
      expect(result.city, 'Toronto');
      expect(result.state, 'ON');
      expect(result.postalCode, 'M5V 1A1');
      expect(result.latitude, closeTo(43.653, 0.001));
      expect(result.longitude, closeTo(-79.383, 0.001));
    });

    test('parses suggestion with missing fields', () {
      final suggestion = <String, dynamic>{
        'properties': <String, dynamic>{},
        'geometry': null,
      };
      final result = parseAddressSuggestion(suggestion);
      expect(result.city, '');
      expect(result.state, 'ON');
      expect(result.latitude, 0.0);
    });
  });

  group('Shipping Calculations', () {
    test('calculateFallbackShipping same province', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateFallbackShipping(items, 'ON', 'ON');
      expect(cost, 12.99);
    });

    test('calculateFallbackShipping adjacent provinces', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateFallbackShipping(items, 'ON', 'QC');
      expect(cost, 18.99);
    });

    test('calculateFallbackShipping same region', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateFallbackShipping(items, 'ON', 'QC');
      // ON and QC are adjacent AND same region (Central)
      expect(cost, 18.99); // adjacent takes priority
    });

    test('calculateFallbackShipping far provinces', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateFallbackShipping(items, 'BC', 'NS');
      expect(cost, 26.99);
    });

    test('calculateFallbackShipping multiple items adds surcharge', () {
      final items = [_makeCartItem(quantity: 3)];
      final cost = calculateFallbackShipping(items, 'ON', 'ON');
      // 12.99 + (3-1) * (12.99 * 0.15)
      expect(cost, closeTo(12.99 + 2 * 1.9485, 0.01));
    });

    test('calculateTieredShipping short distance standard', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(10.0, items, DeliverySpeed.standard);
      expect(cost, closeTo(1.99, 0.01));
    });

    test('calculateTieredShipping medium distance standard', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(100.0, items, DeliverySpeed.standard);
      expect(cost, closeTo(9.99, 0.01));
    });

    test('calculateTieredShipping long distance standard', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(3000.0, items, DeliverySpeed.standard);
      expect(cost, closeTo(26.99, 0.01));
    });

    test('calculateTieredShipping express multiplier short distance', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(10.0, items, DeliverySpeed.express);
      expect(cost, closeTo(1.99 * 4.0, 0.01));
    });

    test('calculateTieredShipping sameDay multiplier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(10.0, items, DeliverySpeed.sameDay);
      expect(cost, closeTo(1.99 * 4.5, 0.01));
    });

    test('calculateTieredShipping with heavy item adds weight surcharge', () {
      final items = [_makeCartItem(quantity: 1, weightKg: 5.0)];
      final cost = calculateTieredShipping(10.0, items, DeliverySpeed.standard);
      // baseCost 1.99 + weightSurcharge (5-2)*1.5 = 4.5
      expect(cost, closeTo(1.99 + 4.5, 0.01));
    });

    test('calculateTieredShipping with volumetric weight', () {
      final items = [_makeCartItem(quantity: 1, weightKg: 0.5, lengthCm: 50, widthCm: 50, heightCm: 50)];
      final cost = calculateTieredShipping(10.0, items, DeliverySpeed.standard);
      // volWeight = 50*50*50/5000 = 25kg, effectiveWeight = 25 (> 0.5)
      // surcharge = (25-2)*1.5 = 34.5
      expect(cost, closeTo(1.99 + 34.5, 0.01));
    });

    test('calculateTieredShipping 50km tier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(30.0, items, DeliverySpeed.standard);
      expect(cost, closeTo(4.99, 0.01));
    });

    test('calculateTieredShipping 500km tier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(300.0, items, DeliverySpeed.standard);
      expect(cost, closeTo(14.99, 0.01));
    });

    test('calculateTieredShipping 1200km tier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(800.0, items, DeliverySpeed.standard);
      expect(cost, closeTo(18.99, 0.01));
    });

    test('calculateTieredShipping 2500km tier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(2000.0, items, DeliverySpeed.standard);
      expect(cost, closeTo(22.99, 0.01));
    });

    test('calculateTieredShipping express 50km tier multiplier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(30.0, items, DeliverySpeed.express);
      expect(cost, closeTo(4.99 * 1.6, 0.01));
    });

    test('calculateTieredShipping express 150km tier multiplier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(100.0, items, DeliverySpeed.express);
      expect(cost, closeTo(9.99 * 1.5, 0.01));
    });

    test('calculateTieredShipping express long distance multiplier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(3000.0, items, DeliverySpeed.express);
      expect(cost, closeTo(26.99 * 1.6, 0.01));
    });

    test('calculateTieredShipping sameDay 50km multiplier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(30.0, items, DeliverySpeed.sameDay);
      expect(cost, closeTo(4.99 * 1.8, 0.01));
    });

    test('calculateTieredShipping sameDay 150km multiplier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(100.0, items, DeliverySpeed.sameDay);
      expect(cost, closeTo(9.99 * 1.8, 0.01));
    });

    test('calculateTieredShipping sameDay long distance multiplier', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(3000.0, items, DeliverySpeed.sameDay);
      expect(cost, closeTo(26.99 * 2.5, 0.01));
    });

    test('calculateTieredShipping multiple items adds per-item surcharge', () {
      final items = [_makeCartItem(quantity: 3)];
      final cost = calculateTieredShipping(10.0, items, DeliverySpeed.standard);
      // baseCost 1.99 + additional items (3-1)*1.99*0.15
      expect(cost, closeTo(1.99 + 2 * 1.99 * 0.15, 0.01));
    });
  });

  group('AppError', () {
    test('getMessage returns fallback for generic error', () {
      final msg = AppError.getMessage(Exception('test'));
      expect(msg, isNotEmpty);
    });

    test('getMessage returns backend message for FirebaseFunctionsException', () {
      final error = FirebaseFunctionsException(code: 'internal', message: 'Custom error');
      final msg = AppError.getMessage(error);
      expect(msg, contains('Custom error'));
    });

    test('getMessage filters leaked Firebase errors', () {
      final error = FirebaseFunctionsException(code: 'internal', message: 'FailedPrecondition: something');
      final msg = AppError.getMessage(error);
      expect(msg, isNot(contains('FailedPrecondition')));
    });

    test('getMessage does not duplicate embedded codes', () {
      final error = FirebaseFunctionsException(code: 'internal', message: 'Order not found [ORIGNA-ORD-001]');
      final msg = AppError.getMessage(error);
      expect(msg, 'Order not found [ORIGNA-ORD-001]');
    });

    test('getMessage for FirebaseException returns safe message', () {
      final error = FirebaseException(plugin: 'firestore', code: 'unavailable', message: 'Internal details');
      final msg = AppError.getMessage(error);
      expect(msg, isNot(contains('Internal details')));
    });

    test('log does not throw', () {
      expect(() => AppError.log(Exception('test'), context: 'unit-test'), returnsNormally);
    });

    test('log with stackTrace does not throw', () {
      try {
        throw Exception('trace');
      } catch (e, s) {
        expect(() => AppError.log(e, stackTrace: s, context: 'test', extras: {'key': 'val'}), returnsNormally);
      }
    });
  });

  group('productCategories', () {
    test('has expected count', () {
      expect(productCategories.length, 21);
    });

    test('each category has unique id', () {
      final ids = productCategories.map((c) => c.categoryId).toSet();
      expect(ids.length, productCategories.length);
    });
  });

  group('provinceTaxRates', () {
    test('covers all 13 provinces/territories', () {
      expect(provinceTaxRates.length, 13);
    });

    test('all provinces have at least GST or HST', () {
      for (final entry in provinceTaxRates.entries) {
        expect(entry.value.containsKey('GST') || entry.value.containsKey('HST'), isTrue,
            reason: '${entry.key} missing GST or HST');
      }
    });
  });

  group('Authentication Flow Utilities', () {
    testWidgets('checkEmailVerifiedOrPrompt with null user returns false', (tester) async {
      final mockAuth = MockFirebaseAuth();
      when(mockAuth.currentUser).thenReturn(null);

      await tester.pumpWidget(TestWrapper(
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              final result = await checkEmailVerifiedOrPrompt(context, auth: mockAuth);
              expect(result, isFalse);
            },
            child: const Text('Check'),
          );
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    });

    testWidgets('checkEmailVerifiedOrPrompt with verified user returns true', (tester) async {
      final mockAuth = MockFirebaseAuth();
      final mockUser = MockUser();
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.emailVerified).thenReturn(true);
      when(mockUser.reload()).thenAnswer((_) async {});

      await tester.pumpWidget(TestWrapper(
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              final result = await checkEmailVerifiedOrPrompt(context, auth: mockAuth);
              expect(result, isTrue);
            },
            child: const Text('Check'),
          );
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    });

    testWidgets('checkEmailVerifiedOrPrompt with unverified user shows dialog', (tester) async {
      final mockAuth = MockFirebaseAuth();
      final mockUser = MockUser();
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.emailVerified).thenReturn(false);
      when(mockUser.reload()).thenAnswer((_) async {});

      await tester.pumpWidget(TestWrapper(
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              final result = await checkEmailVerifiedOrPrompt(context, auth: mockAuth);
              expect(result, isFalse);
            },
            child: const Text('Check'),
          );
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.text('email_verification.title'), findsOneWidget);
    });
  });

  // =========================================================================
  // NEW COVERAGE: generateSearchKeywords edge cases
  // =========================================================================
  group('generateSearchKeywords - edge cases', () {
    test('whitespace-only input returns [""]', () {
      expect(generateSearchKeywords('   '), ['']);
    });

    test('single character word', () {
      final kw = generateSearchKeywords('a');
      expect(kw, contains('a'));
      expect(kw.length, lessThanOrEqualTo(30));
    });

    test('very long single word truncates prefixes at 20 chars', () {
      final longWord = 'a' * 50;
      final kw = generateSearchKeywords(longWord);
      // Should contain the full cleaned name
      expect(kw, contains(longWord));
      // Prefixes up to 20 chars
      expect(kw, contains('a' * 20));
    });

    test('multiple words generate prefixes for each', () {
      final kw = generateSearchKeywords('foo bar baz');
      expect(kw, contains('f'));
      expect(kw, contains('fo'));
      expect(kw, contains('foo'));
      expect(kw, contains('b'));
      expect(kw, contains('ba'));
      expect(kw, contains('bar'));
      expect(kw, contains('baz'));
      expect(kw, contains('foo bar baz'));
    });

    test('respects max 30 keyword limit', () {
      // Many long words to exceed limit
      final input = List.generate(10, (i) => 'word${i}abcdefghij').join(' ');
      final kw = generateSearchKeywords(input);
      expect(kw.length, lessThanOrEqualTo(30));
    });

    test('handles extra whitespace between words', () {
      final kw = generateSearchKeywords('  hello   world  ');
      // trim() preserves internal whitespace, so full name is 'hello   world'
      expect(kw, contains('hello   world'));
      expect(kw, contains('h'));
      expect(kw, contains('w'));
    });
  });

  // =========================================================================
  // NEW COVERAGE: getTaxRate - all provinces
  // =========================================================================
  group('getTaxRate - all provinces', () {
    test('BC returns GST + PST = 0.12', () {
      expect(getTaxRate('BC'), 0.12);
    });

    test('MB returns GST + PST = 0.12', () {
      expect(getTaxRate('MB'), 0.12);
    });

    test('NB returns HST = 0.15', () {
      expect(getTaxRate('NB'), 0.15);
    });

    test('NL returns HST = 0.15', () {
      expect(getTaxRate('NL'), 0.15);
    });

    test('NS returns HST = 0.14', () {
      expect(getTaxRate('NS'), 0.14);
    });

    test('NT returns GST = 0.05', () {
      expect(getTaxRate('NT'), 0.05);
    });

    test('NU returns GST = 0.05', () {
      expect(getTaxRate('NU'), 0.05);
    });

    test('PE returns HST = 0.15', () {
      expect(getTaxRate('PE'), 0.15);
    });

    test('SK returns GST + PST = 0.11', () {
      expect(getTaxRate('SK'), 0.11);
    });

    test('YT returns GST = 0.05', () {
      expect(getTaxRate('YT'), 0.05);
    });
  });

  // =========================================================================
  // NEW COVERAGE: calculateDetailedTaxes - more provinces
  // =========================================================================
  group('calculateDetailedTaxes - extended', () {
    test('BC returns GST and PST breakdown', () {
      final addr = Address(street: '1 St', city: 'Vancouver', state: 'BC', postalCode: 'V5V', country: 'CA');
      final b = calculateDetailedTaxes(addr, 200.0);
      expect(b['GST'], 10.0);
      expect(b['PST'], closeTo(14.0, 0.001));
    });

    test('unknown province defaults to GST 5%', () {
      final addr = Address(street: '1 St', city: 'X', state: 'ZZ', postalCode: '000', country: 'CA');
      final b = calculateDetailedTaxes(addr, 100.0);
      expect(b['GST'], 5.0);
      expect(b.length, 1);
    });

    test('AB returns only GST', () {
      final addr = Address(street: '1 St', city: 'Calgary', state: 'AB', postalCode: 'T2T', country: 'CA');
      final b = calculateDetailedTaxes(addr, 100.0);
      expect(b['GST'], 5.0);
      expect(b.length, 1);
    });

    test('zero total returns zero taxes', () {
      final addr = Address(street: '1 St', city: 'Toronto', state: 'ON', postalCode: 'M5V', country: 'CA');
      final b = calculateDetailedTaxes(addr, 0.0);
      expect(b['HST'], 0.0);
    });
  });

  // =========================================================================
  // NEW COVERAGE: isValidTaxCode edge cases
  // =========================================================================
  group('isValidTaxCode - edge cases', () {
    test('whitespace-only returns true (treated as empty)', () {
      expect(isValidTaxCode('   '), isTrue);
    });

    test('valid code with leading/trailing spaces', () {
      expect(isValidTaxCode('  txcd_12345678  '), isTrue);
    });

    test('too many digits', () {
      expect(isValidTaxCode('txcd_123456789'), isFalse);
    });

    test('too few digits', () {
      expect(isValidTaxCode('txcd_1234567'), isFalse);
    });

    test('wrong prefix', () {
      expect(isValidTaxCode('code_12345678'), isFalse);
    });

    test('letters in digit section', () {
      expect(isValidTaxCode('txcd_1234abcd'), isFalse);
    });
  });

  // =========================================================================
  // NEW COVERAGE: validateVideoFile boundary values
  // =========================================================================
  group('validateVideoFile - boundary values', () {
    test('exactly at max size returns none', () {
      final result = validateVideoFile(
        sizeInBytes: BusinessRules.maxVideoBytes,
        durationInSeconds: 10,
      );
      expect(result, VideoValidationError.none);
    });

    test('one byte over max size returns tooLarge', () {
      final result = validateVideoFile(
        sizeInBytes: BusinessRules.maxVideoBytes + 1,
        durationInSeconds: 10,
      );
      expect(result, VideoValidationError.tooLarge);
    });

    test('exactly at max duration returns none', () {
      final result = validateVideoFile(
        sizeInBytes: 100,
        durationInSeconds: BusinessRules.maxVideoDurationSeconds,
      );
      expect(result, VideoValidationError.none);
    });

    test('one second over max duration returns tooLong', () {
      final result = validateVideoFile(
        sizeInBytes: 100,
        durationInSeconds: BusinessRules.maxVideoDurationSeconds + 1,
      );
      expect(result, VideoValidationError.tooLong);
    });

    test('size check happens before duration check', () {
      // Both too large AND too long — should return tooLarge (checked first)
      final result = validateVideoFile(
        sizeInBytes: BusinessRules.maxVideoBytes + 1,
        durationInSeconds: BusinessRules.maxVideoDurationSeconds + 1,
      );
      expect(result, VideoValidationError.tooLarge);
    });

    test('zero size and zero duration returns none', () {
      final result = validateVideoFile(sizeInBytes: 0, durationInSeconds: 0);
      expect(result, VideoValidationError.none);
    });
  });

  // =========================================================================
  // NEW COVERAGE: dynamicToTimestamp edge cases
  // =========================================================================
  group('dynamicToTimestamp - edge cases', () {
    test('null returns Timestamp.now()', () {
      final before = Timestamp.now();
      final result = dynamicToTimestamp(null);
      final after = Timestamp.now();
      expect(result.seconds, greaterThanOrEqualTo(before.seconds));
      expect(result.seconds, lessThanOrEqualTo(after.seconds));
    });

    test('integer returns Timestamp.now() fallback', () {
      final result = dynamicToTimestamp(42);
      expect(result, isA<Timestamp>());
    });

    test('empty string returns Timestamp.now() fallback', () {
      final result = dynamicToTimestamp('');
      expect(result, isA<Timestamp>());
    });

    test('DateTime preserves date exactly', () {
      final dt = DateTime(2025, 6, 15, 10, 30, 0);
      final ts = dynamicToTimestamp(dt);
      expect(ts.toDate(), dt);
    });
  });

  // =========================================================================
  // NEW COVERAGE: hasValidAddress - case insensitivity
  // =========================================================================
  group('hasValidAddress - case handling', () {
    test('lowercase province code is accepted', () {
      final addr = Address(street: '1 St', city: 'Toronto', state: 'on', postalCode: 'M5V', country: 'CA');
      expect(hasValidAddress(addr), isTrue);
    });

    test('mixed case province code is accepted', () {
      final addr = Address(street: '1 St', city: 'Toronto', state: 'On', postalCode: 'M5V', country: 'CA');
      expect(hasValidAddress(addr), isTrue);
    });

    test('whitespace-only street returns false', () {
      final addr = Address(street: '   ', city: 'Toronto', state: 'ON', postalCode: 'M5V', country: 'CA');
      expect(hasValidAddress(addr), isFalse);
    });

    test('whitespace-only state returns false', () {
      final addr = Address(street: '1 St', city: 'Toronto', state: '  ', postalCode: 'M5V', country: 'CA');
      expect(hasValidAddress(addr), isFalse);
    });
  });

  // =========================================================================
  // NEW COVERAGE: AppError.getMessage - extended
  // =========================================================================
  group('AppError.getMessage - extended', () {
    test('getMessage with explicit code appends it', () {
      final msg = AppError.getMessage(Exception('test'), null, 'ORIGNA-TEST-001');
      expect(msg, contains('[ORIGNA-TEST-001]'));
    });

    test('getMessage for FirebaseFunctionsException with query index leak', () {
      final error = FirebaseFunctionsException(
        code: 'internal',
        message: 'The query requires an index you can find at...',
      );
      final msg = AppError.getMessage(error);
      expect(msg, isNot(contains('query requires an index')));
    });

    test('getMessage for FirebaseFunctionsException with empty message uses fallback', () {
      final error = FirebaseFunctionsException(code: 'internal', message: '');
      final msg = AppError.getMessage(error);
      expect(msg, isNotEmpty);
    });

    test('getMessage for FirebaseFunctionsException with whitespace message uses fallback', () {
      final error = FirebaseFunctionsException(code: 'internal', message: '   ');
      final msg = AppError.getMessage(error);
      // Whitespace message is not empty after trim in FirebaseFunctionsException,
      // but the msg.isNotEmpty check in getMessage sees it as non-empty
      expect(msg, isNotEmpty);
    });

    test('getMessage with custom fallback string', () {
      final msg = AppError.getMessage(Exception('x'), 'Custom fallback');
      expect(msg, contains('Custom fallback'));
    });
  });

  // =========================================================================
  // NEW COVERAGE: calculateFallbackShipping - region-only (not adjacent)
  // =========================================================================
  group('calculateFallbackShipping - region-only', () {
    test('same region but not adjacent uses region rate', () {
      // AB and SK: AB is West, SK is Prairies — NOT same region
      // Actually need: BC and AB are West AND adjacent.
      // Let's use NB and NL: NB is Atlantic, NL is Atlantic. NB adjacent to QC,NS,PE. NL adjacent to QC.
      // NB and NL are NOT adjacent but ARE same region (Atlantic)
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateFallbackShipping(items, 'NB', 'NL');
      expect(cost, 22.99); // same region rate
    });

    test('single item no extra surcharge', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateFallbackShipping(items, 'ON', 'ON');
      expect(cost, 12.99); // just base, no additional
    });

    test('zero additional items when quantity is 1', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateFallbackShipping(items, 'BC', 'NS');
      // (1-1).clamp(0,999) = 0, so no surcharge
      expect(cost, 26.99);
    });
  });

  // =========================================================================
  // NEW COVERAGE: calculateTieredShipping - boundary distances
  // =========================================================================
  group('calculateTieredShipping - boundary distances', () {
    test('exactly 15km uses 1.99 tier', () {
      final items = [_makeCartItem(quantity: 1)];
      expect(calculateTieredShipping(15.0, items, DeliverySpeed.standard), closeTo(1.99, 0.01));
    });

    test('15.01km uses 4.99 tier', () {
      final items = [_makeCartItem(quantity: 1)];
      expect(calculateTieredShipping(15.01, items, DeliverySpeed.standard), closeTo(4.99, 0.01));
    });

    test('exactly 50km uses 4.99 tier', () {
      final items = [_makeCartItem(quantity: 1)];
      expect(calculateTieredShipping(50.0, items, DeliverySpeed.standard), closeTo(4.99, 0.01));
    });

    test('50.01km uses 9.99 tier', () {
      final items = [_makeCartItem(quantity: 1)];
      expect(calculateTieredShipping(50.01, items, DeliverySpeed.standard), closeTo(9.99, 0.01));
    });

    test('exactly 150km uses 9.99 tier', () {
      final items = [_makeCartItem(quantity: 1)];
      expect(calculateTieredShipping(150.0, items, DeliverySpeed.standard), closeTo(9.99, 0.01));
    });

    test('exactly 500km uses 14.99 tier', () {
      final items = [_makeCartItem(quantity: 1)];
      expect(calculateTieredShipping(500.0, items, DeliverySpeed.standard), closeTo(14.99, 0.01));
    });

    test('exactly 1200km uses 18.99 tier', () {
      final items = [_makeCartItem(quantity: 1)];
      expect(calculateTieredShipping(1200.0, items, DeliverySpeed.standard), closeTo(18.99, 0.01));
    });

    test('exactly 2500km uses 22.99 tier', () {
      final items = [_makeCartItem(quantity: 1)];
      expect(calculateTieredShipping(2500.0, items, DeliverySpeed.standard), closeTo(22.99, 0.01));
    });

    test('2500.01km uses 26.99 tier', () {
      final items = [_makeCartItem(quantity: 1)];
      expect(calculateTieredShipping(2500.01, items, DeliverySpeed.standard), closeTo(26.99, 0.01));
    });
  });

  // =========================================================================
  // NEW COVERAGE: calculateTieredShipping - weight surcharge edge cases
  // =========================================================================
  group('calculateTieredShipping - weight edge cases', () {
    test('exactly 2kg has no weight surcharge', () {
      final items = [_makeCartItem(quantity: 1, weightKg: 2.0)];
      final cost = calculateTieredShipping(10.0, items, DeliverySpeed.standard);
      expect(cost, closeTo(1.99, 0.01)); // no surcharge
    });

    test('2.1kg has small weight surcharge', () {
      final items = [_makeCartItem(quantity: 1, weightKg: 2.1)];
      final cost = calculateTieredShipping(10.0, items, DeliverySpeed.standard);
      // surcharge = (2.1 - 2.0) * 1.5 = 0.15
      expect(cost, closeTo(1.99 + 0.15, 0.01));
    });

    test('weight surcharge multiplied by quantity', () {
      final items = [_makeCartItem(quantity: 3, weightKg: 5.0)];
      final cost = calculateTieredShipping(10.0, items, DeliverySpeed.standard);
      // surcharge = (5-2)*1.5*3 = 13.5, additional items = (3-1)*1.99*0.15 = 0.597
      expect(cost, closeTo(1.99 + 13.5 + 0.597, 0.01));
    });

    test('null weight defaults to 0.5kg (no surcharge)', () {
      final items = [_makeCartItem(quantity: 1)];
      final cost = calculateTieredShipping(10.0, items, DeliverySpeed.standard);
      expect(cost, closeTo(1.99, 0.01));
    });
  });

  // =========================================================================
  // NEW COVERAGE: VideoValidationError enum values
  // =========================================================================
  group('VideoValidationError enum', () {
    test('has exactly 4 values', () {
      expect(VideoValidationError.values.length, 4);
    });

    test('contains expected values', () {
      expect(VideoValidationError.values, contains(VideoValidationError.none));
      expect(VideoValidationError.values, contains(VideoValidationError.tooLarge));
      expect(VideoValidationError.values, contains(VideoValidationError.tooLong));
      expect(VideoValidationError.values, contains(VideoValidationError.invalidFormat));
    });
  });

  // =========================================================================
  // NEW COVERAGE: parseAddressSuggestion edge cases
  // =========================================================================
  group('parseAddressSuggestion - edge cases', () {
    test('completely empty suggestion', () {
      final result = parseAddressSuggestion(<String, dynamic>{});
      expect(result.city, '');
      expect(result.state, 'ON'); // default
      expect(result.postalCode, '');
      expect(result.latitude, 0.0);
      expect(result.longitude, 0.0);
    });

    test('uses formatted over housenumber+street when available', () {
      final suggestion = {
        'properties': {
          'housenumber': '99',
          'street': 'Oak Ave',
          'formatted': 'Full Formatted Address',
          'city': 'Ottawa',
          'state_code': 'ON',
          'postcode': 'K1A',
        },
        'geometry': {
          'coordinates': [-75.7, 45.4],
        },
      };
      final result = parseAddressSuggestion(suggestion);
      expect(result.street, 'Full Formatted Address');
    });

    test('falls back to housenumber+street when formatted is missing', () {
      final suggestion = {
        'properties': {
          'housenumber': '42',
          'street': 'Elm St',
          'city': 'Hamilton',
          'state_code': 'ON',
          'postcode': 'L8L',
        },
        'geometry': {
          'coordinates': [-79.8, 43.2],
        },
      };
      final result = parseAddressSuggestion(suggestion);
      expect(result.street, '42 Elm St');
    });
  });

  // =========================================================================
  // NEW COVERAGE: provinceTaxRates data integrity
  // =========================================================================
  group('provinceTaxRates - data integrity', () {
    test('no province has negative tax rate', () {
      for (final entry in provinceTaxRates.entries) {
        for (final rate in entry.value.values) {
          expect(rate, greaterThan(0), reason: '${entry.key} has non-positive rate');
        }
      }
    });

    test('all rates are less than 1.0 (100%)', () {
      for (final entry in provinceTaxRates.entries) {
        for (final rate in entry.value.values) {
          expect(rate, lessThan(1.0), reason: '${entry.key} has rate >= 100%');
        }
      }
    });

    test('ON has exactly one tax (HST)', () {
      expect(provinceTaxRates['ON']!.length, 1);
      expect(provinceTaxRates['ON']!.containsKey('HST'), isTrue);
    });

    test('QC has exactly two taxes (GST + QST)', () {
      expect(provinceTaxRates['QC']!.length, 2);
      expect(provinceTaxRates['QC']!.containsKey('GST'), isTrue);
      expect(provinceTaxRates['QC']!.containsKey('QST'), isTrue);
    });
  });
}

CartItemDetailModel _makeCartItem({
  int quantity = 1,
  double? weightKg,
  double? lengthCm,
  double? widthCm,
  double? heightCm,
}) {
  return CartItemDetailModel(
    productId: 'p1',
    name: 'Test Product',
    description: 'desc',
    price: 10.0,
    imageUrls: [],
    quantity: quantity,
    createdAt: Timestamp.now(),
    sellerAddress: Address(street: '1 St', city: 'Toronto', state: 'ON', postalCode: 'M5V', country: 'CA'),
    sellerId: 's1',
    sellerName: 'Seller',
    weightKg: weightKg,
    lengthCm: lengthCm,
    widthCm: widthCm,
    heightCm: heightCm,
  );
}
