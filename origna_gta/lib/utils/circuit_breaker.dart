// Circuit Breaker Pattern Implementation
// Prevents cascade failures when external services (Stripe, Algolia) are down

import 'package:flutter/foundation.dart';

/// Circuit breaker states
enum CircuitState {
  /// Normal operation - requests pass through
  closed,

  /// Failure threshold reached - requests blocked
  open,

  /// Testing if service recovered
  halfOpen,
}

/// Configuration for circuit breaker
class CircuitBreakerConfig {
  /// Number of failures before opening circuit
  final int failureThreshold;

  /// Duration to wait before attempting reset (half-open)
  final Duration resetTimeout;

  /// Duration to wait between requests in half-open state
  final Duration halfOpenTimeout;

  /// Maximum consecutive successes in half-open to close circuit
  final int successThreshold;

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
    this.halfOpenTimeout = const Duration(seconds: 5),
    this.successThreshold = 3,
  });

  /// Default configuration for payment services
  static const paymentDefault = CircuitBreakerConfig(
    failureThreshold: 3,
    resetTimeout: Duration(seconds: 30),
    halfOpenTimeout: Duration(seconds: 5),
    successThreshold: 2,
  );

  /// Default configuration for search services (Algolia)
  static const searchDefault = CircuitBreakerConfig(
    failureThreshold: 5,
    resetTimeout: Duration(seconds: 60),
    halfOpenTimeout: Duration(seconds: 10),
    successThreshold: 3,
  );

  /// Lenient configuration for non-critical services
  static const lenientDefault = CircuitBreakerConfig(
    failureThreshold: 10,
    resetTimeout: Duration(minutes: 2),
    halfOpenTimeout: Duration(seconds: 15),
    successThreshold: 2,
  );
}

/// Represents a circuit breaker for external service calls
///
/// Usage:
/// ```dart
/// final stripeBreaker = CircuitBreaker(
///   name: 'stripe',
///   config: CircuitBreakerConfig.paymentDefault,
/// );
///
/// try {
///   final result = await stripeBreaker.execute(
///     () => stripeApi.createPaymentIntent(...),
///   );
/// } on CircuitBreakerOpenException catch (e) {
///   // Show degraded mode UI
/// }
/// ```
class CircuitBreaker {
  final String name;
  final CircuitBreakerConfig config;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  DateTime? _lastFailureTime;

  CircuitBreaker({
    required this.name,
    this.config = const CircuitBreakerConfig(),
  });

  /// Current state of the circuit
  CircuitState get state => _state;

  /// Whether the circuit is open (blocking requests)
  bool get isOpen => _state == CircuitState.open;

  /// Whether the circuit is closed (allowing requests)
  bool get isClosed => _state == CircuitState.closed;

  /// Execute an operation with circuit breaker protection
  ///
  /// Returns the result of [operation] if successful
  /// Throws [CircuitBreakerOpenException] if circuit is open
  /// Re-throws any exception from [operation]
  Future<T> execute<T>(Future<T> Function() operation) async {
    // Check if we should transition from open to half-open
    if (_state == CircuitState.open) {
      final lastFailure = _lastFailureTime;
      if (lastFailure != null &&
          DateTime.now().difference(lastFailure) > config.resetTimeout) {
        _transitionTo(CircuitState.halfOpen);
        if (kDebugMode) debugPrint('CircuitBreaker[$name]: OPEN → HALF_OPEN');
      } else {
        throw CircuitBreakerOpenException(
          serviceName: name,
          retryAfter: _calculateRetryAfter(),
        );
      }
    }

    // In half-open state, throttle requests
    if (_state == CircuitState.halfOpen) {
      await Future.delayed(config.halfOpenTimeout);
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    if (_state == CircuitState.halfOpen) {
      _successCount++;
      if (_successCount >= config.successThreshold) {
        _transitionTo(CircuitState.closed);
        if (kDebugMode) debugPrint('CircuitBreaker[$name]: HALF_OPEN → CLOSED');
      }
    } else {
      // In closed state, reset failure count on success
      if (_failureCount > 0) {
        _failureCount = 0;
      }
    }
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitState.halfOpen) {
      // Any failure in half-open goes back to open
      _transitionTo(CircuitState.open);
        if (kDebugMode) debugPrint('CircuitBreaker[$name]: HALF_OPEN → OPEN');
    } else if (_failureCount >= config.failureThreshold) {
      _transitionTo(CircuitState.open);
        if (kDebugMode) debugPrint('CircuitBreaker[$name]: CLOSED → OPEN ($_failureCount failures)');
    }
  }

  void _transitionTo(CircuitState newState) {
    _state = newState;
    if (newState == CircuitState.closed) {
      _failureCount = 0;
      _successCount = 0;
    } else if (newState == CircuitState.halfOpen) {
      _successCount = 0;
    }
  }

  Duration _calculateRetryAfter() {
    if (_lastFailureTime == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_lastFailureTime!);
    final remaining = config.resetTimeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Manually reset the circuit breaker (for testing or admin override)
  void reset() {
    _transitionTo(CircuitState.closed);
    _lastFailureTime = null;
  }

  /// Get current metrics for monitoring
  CircuitBreakerMetrics getMetrics() {
    return CircuitBreakerMetrics(
      state: _state,
      failureCount: _failureCount,
      successCount: _successCount,
      lastFailureTime: _lastFailureTime,
      secondsUntilRetry: _calculateRetryAfter().inSeconds,
    );
  }
}

/// Metrics for monitoring circuit breaker health
class CircuitBreakerMetrics {
  final CircuitState state;
  final int failureCount;
  final int successCount;
  final DateTime? lastFailureTime;
  final int secondsUntilRetry;

  CircuitBreakerMetrics({
    required this.state,
    required this.failureCount,
    required this.successCount,
    required this.lastFailureTime,
    required this.secondsUntilRetry,
  });

  Map<String, dynamic> toJson() => {
        'state': state.name,
        'failureCount': failureCount,
        'successCount': successCount,
        'lastFailureTime': lastFailureTime?.toIso8601String(),
        'secondsUntilRetry': secondsUntilRetry,
      };
}

/// Exception thrown when circuit breaker is open
class CircuitBreakerOpenException implements Exception {
  final String serviceName;
  final Duration retryAfter;

  CircuitBreakerOpenException({
    required this.serviceName,
    required this.retryAfter,
  });

  @override
  String toString() =>
      'CircuitBreakerOpenException: $serviceName is unavailable. '
      'Retry after ${retryAfter.inSeconds}s';
}

/// Registry to manage multiple circuit breakers
class CircuitBreakerRegistry {
  static final Map<String, CircuitBreaker> _breakers = {};

  /// Get or create a circuit breaker
  static CircuitBreaker get(
    String name, {
    CircuitBreakerConfig? config,
  }) {
    return _breakers.putIfAbsent(
      name,
      () => CircuitBreaker(
        name: name,
        config: config ?? const CircuitBreakerConfig(),
      ),
    );
  }

  /// Get metrics for all circuit breakers
  static Map<String, CircuitBreakerMetrics> getAllMetrics() {
    return _breakers.map(
      (name, breaker) => MapEntry(name, breaker.getMetrics()),
    );
  }

  /// Reset all circuit breakers
  static void resetAll() {
    for (final breaker in _breakers.values) {
      breaker.reset();
    }
  }

  /// Clear all circuit breakers (mainly for testing)
  static void clear() {
    _breakers.clear();
  }
}
