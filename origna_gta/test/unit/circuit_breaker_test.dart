// Circuit Breaker Pattern Unit Tests
// Tests for origna_gta/lib/utils/circuit_breaker.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/utils/circuit_breaker.dart';

void main() {
  group('CircuitBreaker', () {
    // Reset registry before each test
    setUp(() {
      CircuitBreakerRegistry.clear();
    });

    tearDown(() {
      CircuitBreakerRegistry.clear();
    });

    group('Basic Operation', () {
      test('should execute operation successfully when closed', () async {
        final breaker = CircuitBreaker(
          name: 'test',
          config: const CircuitBreakerConfig(
            failureThreshold: 3,
            resetTimeout: Duration(seconds: 1),
          ),
        );

        var executed = false;
        final result = await breaker.execute(() async {
          executed = true;
          return 'success';
        });

        expect(result, equals('success'));
        expect(executed, isTrue);
        expect(breaker.state, equals(CircuitState.closed));
      });

      test('should rethrow exception on failure', () async {
        final breaker = CircuitBreaker(name: 'test');

        expect(
          () => breaker.execute(() async {
            throw Exception('test error');
          }),
          throwsException,
        );
      });
    });

    group('State Transitions', () {
      test('should transition to OPEN after failure threshold', () async {
        final breaker = CircuitBreaker(
          name: 'test',
          config: const CircuitBreakerConfig(
            failureThreshold: 3,
            resetTimeout: Duration(seconds: 30),
          ),
        );

        // First 2 failures - should stay closed
        for (var i = 0; i < 2; i++) {
          try {
            await breaker.execute(() async => throw Exception('fail'));
          } catch (_) {}
        }
        expect(breaker.state, equals(CircuitState.closed));

        // 3rd failure - should open circuit
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
        expect(breaker.state, equals(CircuitState.open));
      });

      test('should block requests when OPEN', () async {
        final breaker = CircuitBreaker(
          name: 'test',
          config: const CircuitBreakerConfig(
            failureThreshold: 1,
            resetTimeout: Duration(seconds: 30),
          ),
        );

        // Trigger open state
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}

        expect(breaker.isOpen, isTrue);
        expect(
          () => breaker.execute(() async => 'should not run'),
          throwsA(isA<CircuitBreakerOpenException>()),
        );
      });

      test('should include retry-after info in exception', () async {
        final breaker = CircuitBreaker(
          name: 'test',
          config: const CircuitBreakerConfig(
            failureThreshold: 1,
            resetTimeout: Duration(seconds: 60),
          ),
        );

        // Open the circuit
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}

        CircuitBreakerOpenException? capturedError;
        try {
          await breaker.execute(() async => 'test');
        } on CircuitBreakerOpenException catch (e) {
          capturedError = e;
        }

        expect(capturedError, isNotNull);
        expect(capturedError!.serviceName, equals('test'));
        expect(capturedError.retryAfter.inSeconds, greaterThan(0));
      });
    });

    group('Recovery', () {
      test('should transition to HALF_OPEN after reset timeout', () async {
        final breaker = CircuitBreaker(
          name: 'test',
          config: const CircuitBreakerConfig(
            failureThreshold: 1,
            resetTimeout: Duration(milliseconds: 50),
            halfOpenTimeout: Duration.zero,
            successThreshold: 1,
          ),
        );

        // Open the circuit
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
        expect(breaker.state, equals(CircuitState.open));

        // Wait for reset timeout (longer than resetTimeout)
        await Future.delayed(const Duration(milliseconds: 100));

        // After timeout + successful execution, circuit should close
        await breaker.execute(() async => 'success');

        // Circuit should be closed now
        expect(breaker.isClosed, isTrue);
      });

      test('should close circuit after success threshold in half-open', () async {
        final breaker = CircuitBreaker(
          name: 'test',
          config: const CircuitBreakerConfig(
            failureThreshold: 1,
            resetTimeout: Duration(milliseconds: 50),
            halfOpenTimeout: Duration.zero,
            successThreshold: 2,
          ),
        );

        // Open the circuit
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}

        // Wait for reset
        await Future.delayed(const Duration(milliseconds: 100));

        // First success in half-open
        await breaker.execute(() async => 'success1');

        // Second success should close the circuit
        await breaker.execute(() async => 'success2');

        expect(breaker.state, equals(CircuitState.closed));
      });

      test('should reopen on failure in half-open state', () async {
        final breaker = CircuitBreaker(
          name: 'test',
          config: const CircuitBreakerConfig(
            failureThreshold: 1,
            resetTimeout: Duration(milliseconds: 50),
            halfOpenTimeout: Duration.zero,
            successThreshold: 3,
          ),
        );

        // Open the circuit
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}

        // Wait for reset
        await Future.delayed(const Duration(milliseconds: 100));

        // First success
        await breaker.execute(() async => 'success');

        // Failure in half-open should reopen
        try {
          await breaker.execute(() async => throw Exception('fail again'));
        } catch (_) {}

        expect(breaker.state, equals(CircuitState.open));
      });
    });

    group('Metrics', () {
      test('should track failure count', () async {
        final breaker = CircuitBreaker(
          name: 'test',
          config: const CircuitBreakerConfig(failureThreshold: 5),
        );

        var metrics = breaker.getMetrics();
        expect(metrics.failureCount, equals(0));

        for (var i = 0; i < 3; i++) {
          try {
            await breaker.execute(() async => throw Exception('fail'));
          } catch (_) {}
        }

        metrics = breaker.getMetrics();
        expect(metrics.failureCount, equals(3));
        expect(metrics.state, equals(CircuitState.closed));
      });

      test('should reset failure count on success', () async {
        final breaker = CircuitBreaker(name: 'test');

        // Add some failures
        for (var i = 0; i < 2; i++) {
          try {
            await breaker.execute(() async => throw Exception('fail'));
          } catch (_) {}
        }

        // Success should reset
        await breaker.execute(() async => 'success');

        final metrics = breaker.getMetrics();
        expect(metrics.failureCount, equals(0));
      });

      test('should expose state in metrics', () async {
        final breaker = CircuitBreaker(
          name: 'test',
          config: const CircuitBreakerConfig(failureThreshold: 1),
        );

        var metrics = breaker.getMetrics();
        expect(metrics.state, equals(CircuitState.closed));

        // Open circuit
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}

        metrics = breaker.getMetrics();
        expect(metrics.state, equals(CircuitState.open));
      });
    });

    group('Registry', () {
      test('should return same instance for same name', () {
        final breaker1 = CircuitBreakerRegistry.get('shared');
        final breaker2 = CircuitBreakerRegistry.get('shared');

        expect(identical(breaker1, breaker2), isTrue);
      });

      test('should return different instances for different names', () {
        final breaker1 = CircuitBreakerRegistry.get('breaker1');
        final breaker2 = CircuitBreakerRegistry.get('breaker2');

        expect(identical(breaker1, breaker2), isFalse);
      });

      test('should allow custom config on first get', () {
        final customConfig = const CircuitBreakerConfig(
          failureThreshold: 10,
          resetTimeout: Duration(seconds: 120),
        );

        final breaker = CircuitBreakerRegistry.get(
          'custom',
          config: customConfig,
        );

        // Verify by checking metrics behavior
        expect(breaker.isClosed, isTrue);
      });

      test('should return metrics for all breakers', () {
        CircuitBreakerRegistry.get('b1');
        CircuitBreakerRegistry.get('b2');
        CircuitBreakerRegistry.get('b3');

        final allMetrics = CircuitBreakerRegistry.getAllMetrics();
        expect(allMetrics.length, equals(3));
        expect(allMetrics.keys, containsAll(['b1', 'b2', 'b3']));
      });

      test('should reset all breakers', () async {
        final breaker = CircuitBreakerRegistry.get(
          'reset-test',
          config: const CircuitBreakerConfig(failureThreshold: 1),
        );

        // Open circuit
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
        expect(breaker.isOpen, isTrue);

        // Reset all
        CircuitBreakerRegistry.resetAll();

        expect(breaker.isClosed, isTrue);
      });
    });

    group('Predefined Configs', () {
      test('paymentDefault should have appropriate thresholds', () {
        const config = CircuitBreakerConfig.paymentDefault;
        expect(config.failureThreshold, equals(3));
        expect(config.resetTimeout, equals(const Duration(seconds: 30)));
        expect(config.successThreshold, equals(2));
      });

      test('searchDefault should have lenient thresholds', () {
        const config = CircuitBreakerConfig.searchDefault;
        expect(config.failureThreshold, equals(5));
        expect(config.resetTimeout, equals(const Duration(seconds: 60)));
      });

      test('lenientDefault should have high thresholds', () {
        const config = CircuitBreakerConfig.lenientDefault;
        expect(config.failureThreshold, equals(10));
        expect(config.resetTimeout, equals(const Duration(minutes: 2)));
      });
    });
  });
}
