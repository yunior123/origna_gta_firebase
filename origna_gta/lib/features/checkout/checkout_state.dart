import 'package:flutter/foundation.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/utils.dart';

// ============================================================================
// CHECKOUT RESULT
// ============================================================================

sealed class CheckoutResult {}

/// Documentation for CheckoutSuccess
class CheckoutSuccess extends CheckoutResult {
  final String checkoutUrl;
  final String orderId;
  final String sessionId;

  CheckoutSuccess({required this.checkoutUrl, required this.orderId, required this.sessionId});
}

/// Documentation for CheckoutError
class CheckoutError extends CheckoutResult {
  final String message;
  final String? code;

  CheckoutError({required this.message, this.code});
}

/// Documentation for CheckoutAlreadyProcessed
class CheckoutAlreadyProcessed extends CheckoutResult {
  final String existingOrderId;

  CheckoutAlreadyProcessed({required this.existingOrderId});
}

// ============================================================================
// CHECKOUT STATE
// ============================================================================

@immutable
/// Documentation for CheckoutState
class CheckoutState {
  final Address? address;
  final double baseShippingCost; // Base shipping before delivery speed surcharge
  final Map<String, double> sellerShippingCosts; // Breakdown per seller
  final Map<String, String> sellerNames; // Seller names for display
  final DeliverySpeed deliverySpeed;
  final List<DeliverySpeed> availableDeliverySpeeds;
  final bool isLocalDelivery; // Within ~50km of seller
  final Map<String, double> taxBreakdown;
  final bool isCalculatingShipping;
  final String? shippingError;
  final bool isProcessing;
  final String? idempotencyKey;
  final String? checkoutError;
  final String paymentProvider;
  final String? couponCode;
  final int couponDiscountCents;
  final bool isCouponLoading;
  final String? couponError;
  /// F-77: Server-calculated tax amount in cents returned from create_checkout_session.
  /// Use this for display in the review screen instead of client-side estimates.
  final int serverTaxAmountCents;
  /// F-74: Indicates if any item in the cart is shipped from outside Canada.
  final bool hasInternationalItems;

  const CheckoutState({
    this.address,
    this.baseShippingCost = 0.0,
    this.sellerShippingCosts = const {},
    this.sellerNames = const {},
    this.deliverySpeed = DeliverySpeed.standard,
    this.availableDeliverySpeeds = const [DeliverySpeed.standard],
    this.isLocalDelivery = false,
    this.taxBreakdown = const {},
    this.isCalculatingShipping = false,
    this.shippingError,
    this.isProcessing = false,
    this.idempotencyKey,
    this.checkoutError,
    this.paymentProvider = PaymentProviderValues.stripe,
    this.couponCode,
    this.couponDiscountCents = 0,
    this.isCouponLoading = false,
    this.couponError,
    this.serverTaxAmountCents = 0,
    this.hasInternationalItems = false,
  });

  /// Total shipping cost including delivery speed surcharge
  /// Standard (free) uses base cost, express/same-day add surcharge
  double get shippingCost {
    if (deliverySpeed == DeliverySpeed.standard) {
      return baseShippingCost;
    }
    return baseShippingCost + deliverySpeed.baseSurcharge;
  }

  double get taxAmount => taxBreakdown.values.fold(0.0, (total, v) => total + v);

  CheckoutState copyWith({
    Address? address,
    double? baseShippingCost,
    Map<String, double>? sellerShippingCosts,
    Map<String, String>? sellerNames,
    DeliverySpeed? deliverySpeed,
    List<DeliverySpeed>? availableDeliverySpeeds,
    bool? isLocalDelivery,
    Map<String, double>? taxBreakdown,
    bool? isCalculatingShipping,
    String? shippingError,
    bool? isProcessing,
    String? idempotencyKey,
    String? checkoutError,
    String? paymentProvider,
    String? couponCode,
    int? couponDiscountCents,
    bool? isCouponLoading,
    String? couponError,
    int? serverTaxAmountCents,
    bool? hasInternationalItems,
    bool clearShippingError = false,
    bool clearCheckoutError = false,
    bool clearIdempotencyKey = false,
    bool clearCoupon = false,
    bool clearCouponError = false,
  }) {
    return CheckoutState(
      address: address ?? this.address,
      baseShippingCost: baseShippingCost ?? this.baseShippingCost,
      sellerShippingCosts: sellerShippingCosts ?? this.sellerShippingCosts,
      sellerNames: sellerNames ?? this.sellerNames,
      deliverySpeed: deliverySpeed ?? this.deliverySpeed,
      availableDeliverySpeeds: availableDeliverySpeeds ?? this.availableDeliverySpeeds,
      isLocalDelivery: isLocalDelivery ?? this.isLocalDelivery,
      taxBreakdown: taxBreakdown ?? this.taxBreakdown,
      isCalculatingShipping: isCalculatingShipping ?? this.isCalculatingShipping,
      shippingError: clearShippingError ? null : (shippingError ?? this.shippingError),
      isProcessing: isProcessing ?? this.isProcessing,
      idempotencyKey: clearIdempotencyKey ? null : (idempotencyKey ?? this.idempotencyKey),
      checkoutError: clearCheckoutError ? null : (checkoutError ?? this.checkoutError),
      paymentProvider: paymentProvider ?? this.paymentProvider,
      couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
      couponDiscountCents: clearCoupon ? 0 : (couponDiscountCents ?? this.couponDiscountCents),
      isCouponLoading: isCouponLoading ?? this.isCouponLoading,
      couponError: clearCouponError ? null : (couponError ?? this.couponError),
      serverTaxAmountCents: serverTaxAmountCents ?? this.serverTaxAmountCents,
      hasInternationalItems: hasInternationalItems ?? this.hasInternationalItems,
    );
  }
}
