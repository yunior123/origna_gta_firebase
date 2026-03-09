// coverage:ignore-file
import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/services/analytics_service.dart';
import 'package:origna_gta/utils/circuit_breaker.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:uuid/uuid.dart';

import 'checkout_state.dart';

export 'checkout_state.dart';

/// StateNotifierProvider for checkout
final checkoutStateProvider = StateNotifierProvider.autoDispose<CheckoutNotifier, CheckoutState>((ref) {
  return CheckoutNotifier(ref);
});

/// Computed provider for tax rate based on address
final checkoutTaxRateProvider = Provider.autoDispose<double>((ref) {
  final checkoutState = ref.watch(checkoutStateProvider);
  if (checkoutState.address == null) return getTaxRate(ProvinceCodeValues.ontario); // Default Ontario HST
  return getTaxRate(checkoutState.address!.state);
});

/// Computed provider for checkout total.
/// Formula: (subtotal - coupon) + tax + shipping.
/// NOTE: The platform fee is deducted from the SELLER's payout — it is NOT added to the buyer's
/// charge. Stripe PaymentIntent amount = discounted_subtotal + shipping + tax only.
/// The checkout_screen.dart displays a separate informational "service fee" row but the
/// actual Stripe charge does NOT include this fee on top of the buyer's total.
/// This provider reflects what the buyer actually pays (matches total_amount_cents on backend).
final checkoutTotalProvider = Provider.autoDispose<double>((ref) {
  final checkoutState = ref.watch(checkoutStateProvider);
  final subtotal = ref.watch(cartSubtotalProvider);
  final couponDiscount = checkoutState.couponDiscountCents / 100.0;
  return (subtotal - couponDiscount).clamp(0.0, double.infinity) + checkoutState.taxAmount + checkoutState.shippingCost;
});

final _shippingCircuitBreaker = CircuitBreakerRegistry.get('shipping_calc', config: CircuitBreakerConfig.searchDefault);

/// Circuit breakers for external service calls
final _stripeCircuitBreaker = CircuitBreakerRegistry.get('stripe_checkout', config: CircuitBreakerConfig.paymentDefault);

// ============================================================================
// CHECKOUT NOTIFIER
// ============================================================================

/// Documentation for CheckoutNotifier
class CheckoutNotifier extends StateNotifier<CheckoutState> {
  /// Max distance for local delivery option
  static const double _localDeliveryRadiusKm = BusinessRules.localDeliveryRadiusKm;

  final Ref _ref;

  CheckoutNotifier(this._ref) : super(const CheckoutState());
  OrderRepository get _orderRepository => _ref.read(orderRepositoryProvider);
  String? get _userId => _ref.read(userIdProvider);

  UserRepository get _userRepository => _ref.read(userRepositoryProvider);

  /// Apply a coupon code — validates server-side and stores discount in state.
  /// [sellerIds] must be passed so seller-scoped coupons can be validated.
  Future<void> applyCoupon(String code, int subtotalCents, {List<String>? sellerIds}) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return;
    state = state.copyWith(isCouponLoading: true, clearCouponError: true);
    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      // AUDIT FIX (HIGH-C4): Include sellerIds so the server can validate
      // seller-scoped coupons (e.g., coupon only valid for SellerA's products).
      final result = await functions.httpsCallable(CloudFunctionEndpoints.applyCoupon).call({
        Fields.couponCode: trimmed,
        ApiKeys.cartSubtotalCents: subtotalCents,
        Fields.sellerIds: sellerIds ?? [],
      });
      final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
      final discountCents = (data[Fields.discountAmountCents] as num?)?.toInt() ?? 0;
      state = state.copyWith(couponCode: trimmed, couponDiscountCents: discountCents, isCouponLoading: false);
      // AUDIT FIX (MEDIUM-C7): Recalculate client-side tax estimate using post-discount subtotal.
      // Server is authoritative; this keeps the UI summary consistent.
      final postDiscountSubtotal = (subtotalCents - discountCents) / 100.0;
      calculateTaxes(postDiscountSubtotal, shippingCost: state.shippingCost);
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(isCouponLoading: false, couponError: e.message ?? 'checkout.coupon_invalid_code'.tr());
    } catch (e, st) {
      state = state.copyWith(isCouponLoading: false, couponError: 'checkout.coupon_apply_failed'.tr());
      AppError.log(e, stackTrace: st, context: 'checkout_applyCoupon');
    }
  }

  /// Calculate shipping cost for cart items and determine available delivery options
  ///
  /// Uses circuit breaker pattern to handle Algolia/service outages gracefully
  Future<void> calculateShipping(List<CartItemDetailModel> items) async {
    if (items.isEmpty) {
      state = state.copyWith(shippingError: 'checkout.errors.no_items'.tr());
      return;
    }

    final hasPhysicalItems = items.any((item) => !item.isDigital);
    if (state.address == null) {
      if (!hasPhysicalItems) {
        state = state.copyWith(
          baseShippingCost: 0,
          isLocalDelivery: false,
          availableDeliverySpeeds: const [],
          deliverySpeed: DeliverySpeed.standard,
          isCalculatingShipping: false,
          clearShippingError: true,
        );
        return;
      }
      state = state.copyWith(shippingError: 'checkout.errors.no_address'.tr());
      return;
    }
    if (!hasPhysicalItems) {
      state = state.copyWith(
        baseShippingCost: 0,
        isLocalDelivery: false,
        availableDeliverySpeeds: const [],
        deliverySpeed: DeliverySpeed.standard,
        isCalculatingShipping: false,
        clearShippingError: true,
      );
      return;
    }

    state = state.copyWith(isCalculatingShipping: true, clearShippingError: true);

    try {
      // Capture subtotal once to avoid race condition between reads
      final subtotal = _ref.read(cartSubtotalProvider);

      // Use circuit breaker for external service calls
      final sellerCosts = await _shippingCircuitBreaker.execute(() => calculateShippingCost(items, state.address, chosenSpeed: state.deliverySpeed));

      // Calculate total raw cost
      final double rawCost = sellerCosts.values.fold(0.0, (sum, cost) => sum + cost);

      // Apply free shipping threshold — orders at or above $75 CAD get free standard shipping
      // If free shipping applies, we zero out the total but keep the breakdown for reference (optionally)
      // Actually, if it's free, it's free for everyone.
      final isFree = (subtotal * 100).round() >= BusinessRules.freeShippingThresholdCents;
      final cost = isFree ? 0.0 : rawCost;

      // Adjusted breakdown if free shipping applies
      final adjustedSellerCosts = isFree ? sellerCosts.map((k, v) => MapEntry(k, 0.0)) : sellerCosts;

      // Extract seller names for display
      final Map<String, String> sellerNames = {};
      for (var item in items) {
        if (item.sellerId.isNotEmpty) {
          sellerNames[item.sellerId] = item.sellerName;
        }
      }

      // Determine if local delivery (check if any seller is within ~50km)
      final isLocal = await _checkLocalDelivery(items, state.address!);

      // Build delivery item checks from cart items
      final itemChecks = items
          .map(
            (item) => DeliveryItemCheck(
              estimatedShipDays: item.estimatedShipDays,
              isPerishable: item.isPerishable,
              isLocalOnly: item.isLocalDeliveryOnly,
              isInternational:
                  item.madeInCountry != null &&
                  item.madeInCountry!.isNotEmpty &&
                  item.madeInCountry != CountryValues.canada &&
                  item.madeInCountry != CountryValues.canadaCode,
            ),
          )
          .toList();

      // Determine available delivery speeds
      final availableSpeeds = DeliverySpeed.values.where((speed) => speed.isAvailableForItems(itemChecks, isLocal)).toList();

      // F-74: Check for international items to trigger brokerage warning
      final hasIntl = itemChecks.any((item) => item.isInternational);

      state = state.copyWith(
        baseShippingCost: cost,
        sellerShippingCosts: adjustedSellerCosts,
        sellerNames: sellerNames,
        isLocalDelivery: isLocal,
        availableDeliverySpeeds: availableSpeeds,
        deliverySpeed: availableSpeeds.contains(state.deliverySpeed)
            ? state.deliverySpeed
            : (availableSpeeds.isNotEmpty ? availableSpeeds.first : DeliverySpeed.standard),
        isCalculatingShipping: false,
        hasInternationalItems: hasIntl,
      );

      unawaited(AnalyticsService.logAddShippingInfo(valueCad: subtotal, shippingCostCad: cost, shippingTier: state.deliverySpeed.name));

      // Recalculate taxes — GST/HST applies to shipping costs in Canada
      calculateTaxes(subtotal, shippingCost: cost);
    } on CircuitBreakerOpenException catch (_) {
      // Algolia/service is temporarily unavailable
      state = state.copyWith(shippingError: 'checkout.errors.shipping_unavailable'.tr(), isCalculatingShipping: false);
    } catch (e) {
      state = state.copyWith(shippingError: 'checkout.errors.shipping_calc_failed'.tr(), isCalculatingShipping: false);
    }
  }

  /// Calculate taxes based on address
  /// In Canada, GST/HST applies to both goods and shipping.
  void calculateTaxes(double subtotal, {double shippingCost = 0.0}) {
    if (state.address == null) return;

    final taxableAmount = subtotal + shippingCost;
    final taxes = calculateDetailedTaxes(state.address, taxableAmount);
    state = state.copyWith(taxBreakdown: taxes);
  }

  /// Initialize checkout with user's address
  Future<void> initialize() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final addresses = await _ref.read(userAddressesProvider.future);
      if (addresses.isNotEmpty) {
        final defaultAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
        state = state.copyWith(address: defaultAddress);
      } else {
        // Fallback: read address from user profile (addresses subcollection was empty)
        final user = await _userRepository.getUserProfile(userId);
        if (user?.address != null) {
          state = state.copyWith(address: user!.address);
        }
      }
    } catch (e, st) {
      // Initialization error - non-critical, continue without address
      AppError.log(e, stackTrace: st, context: 'checkout_initialize');
    }
  }

  /// Clears the applied coupon code, discount, and any coupon error from state.
  void removeCoupon() => state = state.copyWith(clearCoupon: true, clearCouponError: true);

  /// Reset checkout state
  void reset() {
    state = const CheckoutState();
  }

  /// Update selected delivery speed
  void setDeliverySpeed(DeliverySpeed speed) {
    if (state.availableDeliverySpeeds.contains(speed)) {
      state = state.copyWith(deliverySpeed: speed);

      // F-74: Recalculate shipping whenever speed changes to update international costs
      _ref.read(cartWithDetailsProvider).whenData((items) {
        calculateShipping(items);
      });
    }
  }

  /// Sets the active payment provider if [provider] is a recognised value.
  ///
  /// [provider] Currently only [PaymentProviderValues.stripe] is accepted;
  /// any other value is silently ignored.
  void setPaymentProvider(String provider) {
    if (provider == PaymentProviderValues.stripe) {
      state = state.copyWith(paymentProvider: provider);
    }
  }

  /// Start Stripe checkout with idempotency
  Future<CheckoutResult> startCheckout({
    required List<CartItemDetailModel> items,
    required UserModel user,
    required double subtotal,
    bool eulaAccepted = false,
    bool ageVerificationAccepted = false,
  }) async {
    if (items.isEmpty) {
      return CheckoutError(message: 'checkout.errors.cart_empty'.tr());
    }

    final hasPhysicalItems = items.any((item) => !item.isDigital);
    if (hasPhysicalItems && !hasValidAddress(state.address)) {
      return CheckoutError(message: 'checkout.errors.address_required'.tr());
    }

    if (subtotal <= 0) {
      return CheckoutError(message: 'checkout.errors.invalid_total'.tr());
    }

    if (user.email.trim().isEmpty) {
      return CheckoutError(message: 'checkout.errors.missing_email'.tr());
    }

    // EMAIL VERIFICATION CHECK - CRITICAL BUSINESS LOGIC
    // Prevent checkout if email is not verified
    try {
      final authRepository = _ref.read(authRepositoryProvider);
      final isEmailVerified = await authRepository.isEmailVerified();

      if (!isEmailVerified) {
        return CheckoutError(message: 'checkout.errors.email_not_verified'.tr(), code: 'email-not-verified');
      }
    } catch (e) {
      // SECURITY: Block checkout if we can't verify email status
      return CheckoutError(message: 'checkout.errors.email_verify_failed'.tr(), code: 'verification-check-failed');
    }

    if (state.isProcessing) {
      return CheckoutError(message: 'checkout.errors.already_processing'.tr());
    }

    state = state.copyWith(isProcessing: true, clearCheckoutError: true);
    unawaited(AnalyticsService.logBeginCheckout(valueCad: subtotal, itemCount: items.length));

    try {
      // F-108: Biometric Guard for high-value transactions (> $100 CAD)
      if (subtotal >= 100.0) {
        final localAuth = LocalAuthentication();
        final canAuthenticateWithBiometrics = await localAuth.canCheckBiometrics;
        final canAuthenticate = canAuthenticateWithBiometrics || await localAuth.isDeviceSupported();

        if (canAuthenticate) {
          try {
            final didAuthenticate = await localAuth.authenticate(
              localizedReason: 'auth_biometric_required_higher_value'.tr(), // "Please authenticate to confirm this high-value transaction"
              biometricOnly: false,
            );

            if (!didAuthenticate) {
              state = state.copyWith(isProcessing: false);
              return CheckoutError(message: 'checkout.errors.biometric_failed'.tr());
            }
          } catch (e) {
            // If biometric auth fails due to system error, we might want to allow PIN fallback or block.
            // Requirement says "biometric confirmation", so we block if it fails but exists.
            state = state.copyWith(isProcessing: false);
            return CheckoutError(message: 'checkout.errors.biometric_error'.tr());
          }
        }
      }

      final userId = _userId;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Generate a per-attempt key (random). Reuse on retry after a failure.
      final idempotencyKey = state.idempotencyKey ?? _generateIdempotencyKey(userId);
      state = state.copyWith(idempotencyKey: idempotencyKey);

      // Backend expects: items, shippingAddress, subtotal, userId, deliverySpeed
      // Backend handles: tax calculation, shipping calculation, total calculation server-side

      // Get delivery instructions from cart provider
      final deliveryInstructions = _ref.read(deliveryInstructionsProvider);

      final orderData = {
        Fields.userId: userId,
        Fields.items: items
            .map(
              (item) => {
                Fields.productId: item.productId,
                Fields.name: item.name,
                Fields.price: item.price,
                Fields.quantity: item.quantity,
                Fields.sellerId: item.sellerId,
                Fields.imageUrls: item.imageUrls,
                Fields.isDigital: item.isDigital,
                if (item.buyerNote != null && item.buyerNote!.isNotEmpty) Fields.buyerNote: item.buyerNote,
                if (item.variantId != null) Fields.variantId: item.variantId,
                if (item.variantTitle != null) Fields.variantTitle: item.variantTitle,
                if (item.variantOptions != null) Fields.variantOptions: item.variantOptions,
              },
            )
            .toList(),
        ApiKeys.subtotalCents: (subtotal * 100).round(),
        Fields.shippingAddress: state.address?.toMap() ?? {},
        // Send delivery speed so backend applies correct multiplier
        Fields.deliverySpeed: state.deliverySpeed.value,
        // Delivery instructions for sellers
        Fields.deliveryInstructions: deliveryInstructions,
        // Coupon code — backend validates and applies discount
        if (state.couponCode != null) Fields.couponCode: state.couponCode,
        // Idempotency key — prevents duplicate orders on double-tap / network retry
        ApiKeys.idempotencyKey: idempotencyKey,
        // EULA acceptance for digital products (compliance requirement)
        if (items.any((i) => i.isDigital)) ApiKeys.eulaAccepted: eulaAccepted,
        // Age gate confirmation for age-restricted products (Canadian provincial law)
        if (items.any((i) => i.isAgeRestricted)) ApiKeys.ageVerificationAccepted: ageVerificationAccepted,
      };

      // F-007: Verify cart prices before hitting Stripe — detect stale prices and stock changes early.
      // Fail-open: if this call itself errors (network blip), we proceed to checkout and let the backend
      // catch any drift server-side. We never block checkout on a non-critical pre-flight.
      try {
        final functions = _ref.read(firebaseFunctionsProvider);
        final verifyResult = await functions.httpsCallable(CloudFunctionEndpoints.verifyCartPrices).call({
          Fields.items: items.map((item) => {Fields.productId: item.productId, Fields.price: item.price, Fields.quantity: item.quantity}).toList(),
        });
        final verifyData = (verifyResult.data as Map<Object?, Object?>).cast<String, dynamic>();
        if (verifyData[ApiKeys.hasChanges] == true) {
          state = state.copyWith(isProcessing: false);
          final priceChanges = verifyData[ApiKeys.priceChanges] as List? ?? [];
          final stockChanges = verifyData[ApiKeys.stockChanges] as List? ?? [];
          final removedProducts = verifyData[ApiKeys.removedProducts] as List? ?? [];
          // Build a human-readable summary of what changed
          final reasons = <String>[
            if (priceChanges.isNotEmpty) 'checkout.errors.price_changed'.tr(namedArgs: {'count': priceChanges.length.toString()}),
            if (stockChanges.isNotEmpty) 'checkout.errors.stock_changed'.tr(namedArgs: {'count': stockChanges.length.toString()}),
            if (removedProducts.isNotEmpty) 'checkout.errors.items_removed'.tr(namedArgs: {'count': removedProducts.length.toString()}),
          ];
          return CheckoutError(message: reasons.isEmpty ? 'checkout.errors.cart_changed'.tr() : reasons.join(' '), code: 'price-drift');
        }
      } on FirebaseFunctionsException catch (e) {
        // Non-critical — log and proceed. Backend will catch any drift server-side.
        AppError.log(e, stackTrace: null, context: 'checkout_verifyCartPrices');
      } catch (e, st) {
        // Fail-open on unexpected errors too
        AppError.log(e, stackTrace: st, context: 'checkout_verifyCartPrices');
      }

      // Use circuit breaker for Stripe checkout calls
      final result = await _stripeCircuitBreaker.execute(() => _orderRepository.createCheckoutSession(orderData));

      // Check if widget is still mounted after async operation
      if (!mounted) {
        return CheckoutError(message: 'Operation cancelled');
      }

      // Backend returns: {success, sessionId, orderId, checkoutUrl, taxAmountCents}
      // Handle duplicate order (idempotency) — backend may return existing session
      if (result[ApiKeys.duplicate] == true) {
        final checkoutUrl = result[ApiKeys.checkoutUrl] as String?;
        final orderId = result[Fields.orderId] as String;
        if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
          state = state.copyWith(isProcessing: false, clearIdempotencyKey: true);
          _ref.invalidate(cartItemsProvider);
          return CheckoutSuccess(checkoutUrl: checkoutUrl, orderId: orderId, sessionId: result[ApiKeys.sessionId] as String? ?? '');
        }
        // Duplicate but no valid URL — return as already processed
        state = state.copyWith(isProcessing: false, clearIdempotencyKey: true);
        return CheckoutAlreadyProcessed(existingOrderId: orderId);
      }

      final checkoutUrl = result[ApiKeys.checkoutUrl] as String;
      final orderId = result[Fields.orderId] as String;
      final sessionId = result[ApiKeys.sessionId] as String;
      // F-77: server-calculated tax amount — use this in UI instead of client-side estimate
      final serverTaxAmountCents = (result[Fields.taxAmountCents] as num?)?.toInt() ?? 0;

      await _orderRepository.updateLastSession(userId, sessionId, orderId);

      if (!mounted) {
        return CheckoutError(message: 'Operation cancelled');
      }

      state = state.copyWith(isProcessing: false, clearIdempotencyKey: true, serverTaxAmountCents: serverTaxAmountCents);

      // Invalidate cart so stale data doesn't persist after checkout
      _ref.invalidate(cartItemsProvider);

      return CheckoutSuccess(checkoutUrl: checkoutUrl, orderId: orderId, sessionId: sessionId);
    } on CircuitBreakerOpenException {
      // Service is temporarily unavailable (circuit breaker open)
      if (!mounted) {
        return CheckoutError(message: 'Operation cancelled');
      }
      state = state.copyWith(isProcessing: false, checkoutError: 'Payment service is temporarily unavailable. Please try again in a moment.');
      return CheckoutError(message: 'Payment service is temporarily unavailable. Please try again in a moment.', code: 'service-unavailable');
    } on FirebaseFunctionsException catch (e) {
      // Handle known backend validation errors (e.g., "Distance > 50km")
      if (!mounted) {
        return CheckoutError(message: 'Operation cancelled');
      }

      final message = e.message ?? 'An error occurred';
      state = state.copyWith(isProcessing: false, checkoutError: message);

      return CheckoutError(message: message, code: e.code);
    } catch (e, st) {
      if (!mounted) {
        return CheckoutError(message: 'Operation cancelled');
      }
      AppError.log(e, stackTrace: st, context: 'checkout_startCheckout');
      state = state.copyWith(isProcessing: false, checkoutError: AppError.getMessage(e));
      return CheckoutError(message: AppError.getMessage(e));
    }
  }

  /// Update address and recalculate shipping
  void updateAddress(Address address) {
    // New address = new checkout attempt context
    state = state.copyWith(address: address, clearIdempotencyKey: true);
  }

  /// Calculate distance between two coordinates in km (Haversine formula)
  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) + cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Check if buyer is within local delivery range (~50km) of sellers
  Future<bool> _checkLocalDelivery(List<CartItemDetailModel> items, Address buyerAddress) async {
    if (buyerAddress.latitude == null || buyerAddress.longitude == null) {
      return false;
    }

    // Check if all sellers are within local range
    for (final item in items) {
      final sellerAddr = item.sellerAddress;
      if (sellerAddr.latitude == null || sellerAddr.longitude == null) {
        return false; // Unknown distance = not local delivery
      }

      // Simple distance check using Haversine approximation
      final distance = _calculateDistanceKm(buyerAddress.latitude!, buyerAddress.longitude!, sellerAddr.latitude!, sellerAddr.longitude!);

      if (distance > _localDeliveryRadiusKm) {
        return false; // Not local if any seller is beyond local delivery radius
      }
    }
    return true;
  }

  /// Generate per-attempt idempotency key for payment safety.
  ///
  /// - Random per attempt (prevents blocking legitimate repeat purchases)
  /// - Stored in state so immediate retries reuse the same key
  String _generateIdempotencyKey(String userId) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'chk_${userId}_${ts}_${const Uuid().v4()}';
  }

  double _toRadians(double deg) => deg * pi / 180;
}
