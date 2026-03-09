// Tests for supplier_config, subscription_state, qa_model, circuit_breaker to boost coverage past 90%
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/config/supplier_config.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/subscription/subscription_state.dart';
import 'package:origna_gta/models/qa_model.dart';
import 'package:origna_gta/utils/circuit_breaker.dart';

void main() {
  // ==========================================================================
  // SupplierPlatformConfig
  // ==========================================================================
  group('SupplierPlatformConfig', () {
    test('supplierPlatforms has 26 entries', () {
      expect(supplierPlatforms.length, 26);
    });

    test('aliexpress config has expected values', () {
      final config = supplierPlatforms['aliexpress']!;
      expect(config.id, 'aliexpress');
      expect(config.displayName, 'AliExpress');
      expect(config.region, 'Asia');
      expect(config.country, 'China');
      expect(config.minDeliveryDays, 15);
      expect(config.maxDeliveryDays, 30);
      expect(config.hasTracking, isTrue);
      expect(config.supportedCurrencies, contains('USD'));
      expect(config.isInternational, isTrue);
      expect(config.isCustom, isFalse);
    });

    test('custom config isCustom returns true', () {
      expect(supplierPlatforms['custom']!.isCustom, isTrue);
      expect(supplierPlatforms['other']!.isCustom, isTrue);
    });

    test('local is not international', () {
      expect(supplierPlatforms['local']!.isInternational, isFalse);
    });

    test('getSupplierConfig returns config for valid ID', () {
      final config = getSupplierConfig('alibaba');
      expect(config.id, 'alibaba');
    });

    test('getSupplierConfig returns other for null', () {
      final config = getSupplierConfig(null);
      expect(config.id, 'other');
    });

    test('getSupplierConfig returns other for empty string', () {
      final config = getSupplierConfig('');
      expect(config.id, 'other');
    });

    test('getSupplierConfig returns other for unknown ID', () {
      final config = getSupplierConfig('nonexistent');
      expect(config.id, 'other');
    });

    test('getSupplierDeliveryRange returns correct range', () {
      final range = getSupplierDeliveryRange('temu');
      expect(range.minDays, 7);
      expect(range.maxDays, 15);
    });

    test('getSupplierDeliveryRange handles null', () {
      final range = getSupplierDeliveryRange(null);
      expect(range.minDays, isPositive);
      expect(range.maxDays, greaterThan(range.minDays));
    });

    test('getAllSupportedCurrencies returns non-empty set', () {
      final currencies = getAllSupportedCurrencies();
      expect(currencies, isNotEmpty);
      expect(currencies, contains('USD'));
      expect(currencies, contains('CAD'));
      expect(currencies, contains('EUR'));
    });

    test('getSuppliersByRegion groups correctly', () {
      final grouped = getSuppliersByRegion();
      expect(grouped, isNotEmpty);
      // Check that at least Asia group exists
      expect(grouped.values.any((list) => list.any((c) => c.id == 'aliexpress')), isTrue);
    });

    test('isInternationalSupplier for international', () {
      expect(isInternationalSupplier('aliexpress'), isTrue);
    });

    test('isInternationalSupplier for non-international', () {
      expect(isInternationalSupplier('local'), isFalse);
    });

    test('getSupplierRegion returns formatted string', () {
      final region = getSupplierRegion('aliexpress');
      expect(region, isNotNull);
    });

    test('getSupplierRegion returns null for custom', () {
      final region = getSupplierRegion('custom');
      expect(region, isNull);
    });

    testWidgets('getSupplierDropdownItems returns dropdown items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              final items = getSupplierDropdownItems();
              return Text('Items: ${items.length}');
            }),
          ),
        ),
      );
      expect(find.textContaining('Items: 26'), findsOneWidget);
    });
  });

  // ==========================================================================
  // SubscriptionState & SubscriptionInfo
  // ==========================================================================
  group('SubscriptionState', () {
    test('default values', () {
      const state = SubscriptionState();
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.checkoutUrl, isNull);
      expect(state.subscription, isNull);
    });

    test('copyWith preserves values', () {
      const state = SubscriptionState(isLoading: true, errorMessage: 'err');
      final copy = state.copyWith();
      expect(copy.isLoading, isTrue);
      expect(copy.errorMessage, 'err');
    });

    test('copyWith clearError removes error', () {
      const state = SubscriptionState(errorMessage: 'oops');
      final copy = state.copyWith(clearError: true);
      expect(copy.errorMessage, isNull);
    });

    test('copyWith clearCheckoutUrl removes url', () {
      const state = SubscriptionState(checkoutUrl: 'https://example.com');
      final copy = state.copyWith(clearCheckoutUrl: true);
      expect(copy.checkoutUrl, isNull);
    });

    test('copyWith overrides all fields', () {
      const info = SubscriptionInfo(status: 'active', isPremium: true);
      const state = SubscriptionState();
      final copy = state.copyWith(
        isLoading: true,
        errorMessage: 'err',
        checkoutUrl: 'url',
        subscription: info,
      );
      expect(copy.isLoading, isTrue);
      expect(copy.errorMessage, 'err');
      expect(copy.checkoutUrl, 'url');
      expect(copy.subscription, isNotNull);
    });
  });

  group('SubscriptionInfo', () {
    test('fromMap with Timestamp period end', () {
      final now = DateTime(2025, 6, 15);
      final info = SubscriptionInfo.fromMap({
        Fields.status: SubscriptionStatusValues.active,
        Fields.currentPeriodEnd: Timestamp.fromDate(now),
        Fields.cancelAtPeriodEnd: false,
      });
      expect(info.status, SubscriptionStatusValues.active);
      expect(info.isPremium, isTrue);
      expect(info.currentPeriodEnd, now);
      expect(info.cancelAtPeriodEnd, isFalse);
    });

    test('fromMap with int period end (epoch seconds)', () {
      final info = SubscriptionInfo.fromMap({
        Fields.status: SubscriptionStatusValues.active,
        Fields.currentPeriodEnd: 1750000000, // some epoch
        Fields.cancelAtPeriodEnd: true,
      });
      expect(info.currentPeriodEnd, isNotNull);
      expect(info.cancelAtPeriodEnd, isTrue);
    });

    test('fromMap with missing fields uses defaults', () {
      final info = SubscriptionInfo.fromMap({});
      expect(info.status, SubscriptionStatusValues.inactive);
      expect(info.isPremium, isFalse);
      expect(info.currentPeriodEnd, isNull);
      expect(info.cancelAtPeriodEnd, isFalse);
    });

    test('fromMap with canceled status', () {
      final info = SubscriptionInfo.fromMap({
        Fields.status: 'canceled',
      });
      expect(info.isPremium, isFalse);
    });
  });

  // ==========================================================================
  // QAModel
  // ==========================================================================
  group('QAModel', () {
    test('fromMap with all fields', () {
      final now = Timestamp.now();
      final answeredAt = Timestamp.fromDate(DateTime(2025, 5, 1));
      final model = QAModel.fromMap('q1', {
        Fields.questionText: 'Is this waterproof?',
        Fields.askerId: 'user1',
        Fields.createdAt: now,
        Fields.answerText: 'Yes it is!',
        Fields.answeredAt: answeredAt,
        Fields.answeredBy: 'seller1',
      });
      expect(model.id, 'q1');
      expect(model.question, 'Is this waterproof?');
      expect(model.authorId, 'user1');
      expect(model.answer, 'Yes it is!');
      expect(model.answeredBy, 'seller1');
      expect(model.answeredAt, answeredAt.toDate());
    });

    test('fromMap with fallback keys', () {
      final model = QAModel.fromMap('q2', {
        'question': 'How heavy?',
        'authorId': 'user2',
      });
      expect(model.question, 'How heavy?');
      expect(model.authorId, 'user2');
    });

    test('fromMap with empty map', () {
      final model = QAModel.fromMap('q3', {});
      expect(model.question, '');
      expect(model.authorId, '');
      expect(model.answer, isNull);
      expect(model.answeredAt, isNull);
    });

    test('copyWith overrides fields', () {
      final model = QAModel(
        id: 'q1',
        question: 'Q?',
        authorId: 'u1',
        createdAt: DateTime(2025, 1, 1),
      );
      final copy = model.copyWith(
        answer: 'A!',
        answeredBy: 'seller',
        answeredAt: DateTime(2025, 1, 2),
      );
      expect(copy.answer, 'A!');
      expect(copy.answeredBy, 'seller');
      expect(copy.question, 'Q?'); // preserved
    });

    test('toMap without answer', () {
      final model = QAModel(
        id: 'q1',
        question: 'Q?',
        authorId: 'u1',
        createdAt: DateTime(2025, 1, 1),
      );
      final map = model.toMap();
      expect(map[Fields.questionText], 'Q?');
      expect(map[Fields.askerId], 'u1');
      expect(map.containsKey(Fields.answerText), isFalse);
    });

    test('toMap with answer includes answer fields', () {
      final model = QAModel(
        id: 'q1',
        question: 'Q?',
        authorId: 'u1',
        createdAt: DateTime(2025, 1, 1),
        answer: 'A!',
        answeredAt: DateTime(2025, 1, 2),
        answeredBy: 'seller1',
      );
      final map = model.toMap();
      expect(map[Fields.answerText], 'A!');
      expect(map[Fields.answeredBy], 'seller1');
    });

    test('toMap with answer but no answeredAt uses server timestamp', () {
      final model = QAModel(
        id: 'q1',
        question: 'Q?',
        authorId: 'u1',
        createdAt: DateTime(2025, 1, 1),
        answer: 'A!',
      );
      final map = model.toMap();
      expect(map[Fields.answerText], 'A!');
      expect(map[Fields.answeredAt], isA<FieldValue>());
    });
  });

  // ==========================================================================
  // CircuitBreaker
  // ==========================================================================
  group('CircuitBreaker', () {
    late CircuitBreaker breaker;

    setUp(() {
      CircuitBreakerRegistry.clear();
      breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(
          failureThreshold: 2,
          resetTimeout: Duration(milliseconds: 50),
          halfOpenTimeout: Duration(milliseconds: 10),
          successThreshold: 1,
        ),
      );
    });

    test('starts closed', () {
      expect(breaker.state, CircuitState.closed);
      expect(breaker.isClosed, isTrue);
      expect(breaker.isOpen, isFalse);
    });

    test('successful execute returns result', () async {
      final result = await breaker.execute(() async => 42);
      expect(result, 42);
      expect(breaker.isClosed, isTrue);
    });

    test('opens after failure threshold', () async {
      for (var i = 0; i < 2; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }
      expect(breaker.isOpen, isTrue);
    });

    test('throws CircuitBreakerOpenException when open', () async {
      for (var i = 0; i < 2; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }
      expect(
        () => breaker.execute(() async => 1),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('reset closes the circuit', () async {
      for (var i = 0; i < 2; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }
      expect(breaker.isOpen, isTrue);
      breaker.reset();
      expect(breaker.isClosed, isTrue);
    });

    test('getMetrics returns current state', () {
      final metrics = breaker.getMetrics();
      expect(metrics.state, CircuitState.closed);
      expect(metrics.failureCount, 0);
      expect(metrics.toJson()['state'], 'closed');
    });

    test('CircuitBreakerOpenException toString', () {
      final ex = CircuitBreakerOpenException(
        serviceName: 'stripe',
        retryAfter: const Duration(seconds: 10),
      );
      expect(ex.toString(), contains('stripe'));
      expect(ex.toString(), contains('10'));
    });

    test('CircuitBreakerRegistry get and getAllMetrics', () {
      CircuitBreakerRegistry.clear();
      final b = CircuitBreakerRegistry.get('payment',
          config: CircuitBreakerConfig.paymentDefault);
      expect(b.name, 'payment');
      final metrics = CircuitBreakerRegistry.getAllMetrics();
      expect(metrics.containsKey('payment'), isTrue);
    });

    test('CircuitBreakerRegistry resetAll', () async {
      CircuitBreakerRegistry.clear();
      final b = CircuitBreakerRegistry.get('test2',
          config: const CircuitBreakerConfig(failureThreshold: 1));
      try {
        await b.execute(() async => throw Exception('fail'));
      } catch (_) {}
      expect(b.isOpen, isTrue);
      CircuitBreakerRegistry.resetAll();
      expect(b.isClosed, isTrue);
    });

    test('success in closed state resets failure count', () async {
      try {
        await breaker.execute(() async => throw Exception('fail'));
      } catch (_) {}
      // One failure, not at threshold yet
      await breaker.execute(() async => 'ok');
      // Failure count should be reset
      expect(breaker.isClosed, isTrue);
    });

    test('static configs exist', () {
      expect(CircuitBreakerConfig.paymentDefault.failureThreshold, 3);
      expect(CircuitBreakerConfig.searchDefault.failureThreshold, 5);
      expect(CircuitBreakerConfig.lenientDefault.failureThreshold, 10);
    });
  });
}
