// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from Pydantic models - Single source of truth
// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/schema/schema_constants.dart';
import 'base_models.dart';
import 'product_models.dart';

part 'order_models.freezed.dart';
part 'order_models.g.dart';

/// Safely parse a dynamic value (Timestamp, String, DateTime) to DateTime?
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Parse an OrderItem from a Firestore map without relying on generated fromJson
OrderItem _parseOrderItem(dynamic raw) {
  final map = _safeMap(raw);
  return OrderItem(
    productId: _safeString(map[Fields.productId]),
    cartItemId: map[Fields.cartItemId] as String?, // F-001/F-003: canonical cart item ID
    name: _safeString(map[Fields.name]),
    description: _safeString(map[Fields.description]),
    price: _safeDouble(map[Fields.price]),
    quantity: _safeInt(map[Fields.quantity], 1),
    imageUrls: _safeStringList(map[Fields.imageUrls]),
    sellerId: _safeString(map[Fields.sellerId]),
    sellerAddress: map[Fields.sellerAddress] != null ? _safeAddress(map[Fields.sellerAddress]) : null,
    status: _safeString(map[Fields.status], DeliveryStatusValues.pending),
    trackingNumber: map[Fields.trackingNumber] != null ? _safeString(map[Fields.trackingNumber]) : null,
    carrier: map[Fields.carrier] != null ? _safeString(map[Fields.carrier]) : null,
    carrierNote: map[Fields.carrierNote] != null ? _safeString(map[Fields.carrierNote]) : null,
    sellerSku: map[Fields.sellerSku] != null ? _safeString(map[Fields.sellerSku]) : null,
    sellerName: map[Fields.sellerName] != null ? _safeString(map[Fields.sellerName]) : null,
    shippedAt: _parseDateTime(map[Fields.shippedAt]),
    deliveredAt: _parseDateTime(map[Fields.deliveredAt]),
    refundedAt: _parseDateTime(map[Fields.refundedAt]),
    refundReason: map[Fields.refundReason] != null ? _safeString(map[Fields.refundReason]) : null,
    refundAmountCents: map[Fields.refundAmountCents] != null ? _safeInt(map[Fields.refundAmountCents]) : null,
    refundId: map[Fields.refundId] != null ? _safeString(map[Fields.refundId]) : null,
    confirmedByBuyer: _safeBool(map[Fields.confirmedByBuyer]),
    variantId: map[Fields.variantId] != null ? _safeString(map[Fields.variantId]) : null,
    variantTitle: map[Fields.variantTitle] != null ? _safeString(map[Fields.variantTitle]) : null,
    variantOptions: map[Fields.variantOptions] != null ? Map<String, String>.from(map[Fields.variantOptions] as Map) : null,
    variantSku: map[Fields.variantSku] != null ? _safeString(map[Fields.variantSku]) : null,
    weightKg: map[Fields.weightKg] != null ? _safeDouble(map[Fields.weightKg]) : null,
    lengthCm: map[Fields.lengthCm] != null ? _safeDouble(map[Fields.lengthCm]) : null,
    widthCm: map[Fields.widthCm] != null ? _safeDouble(map[Fields.widthCm]) : null,
    heightCm: map[Fields.heightCm] != null ? _safeDouble(map[Fields.heightCm]) : null,
    isLocalDeliveryOnly: _safeBool(map[Fields.isLocalDeliveryOnly]),
    isPerishable: _safeBool(map[Fields.isPerishable]),
    estimatedShipDays: _safeInt(map[Fields.estimatedShipDays], 3),
    minimumOrderQuantity: _safeInt(map[Fields.minimumOrderQuantity], 1),
    freeShipping: _safeBool(map[Fields.freeShipping]),
    isDigital: _safeBool(map[Fields.isDigital]),
    licenseKey: map[Fields.licenseKey] != null ? _safeString(map[Fields.licenseKey]) : null,
    digitalUnlocked: _safeBool(map[Fields.digitalUnlocked]),
    digitalType: map[Fields.digitalType] != null ? _safeString(map[Fields.digitalType]) : null,
    digitalBuilds: map[Fields.digitalBuilds] != null ? Map<String, String>.from(map[Fields.digitalBuilds] as Map) : null,
    taxCode: map[Fields.taxCode] != null ? _safeString(map[Fields.taxCode]) : null,
    buyerNote: map[Fields.buyerNote] != null ? _safeString(map[Fields.buyerNote]) : null, // ADDED
    fulfillmentWarehouseId: map[Fields.fulfillmentWarehouseId] != null ? _safeString(map[Fields.fulfillmentWarehouseId]) : null,
  );
}

/// Parse Ratings from a Firestore map without relying on generated fromJson
Ratings _parseRating(dynamic raw) {
  final map = _safeMap(raw);
  return Ratings(
    productId: _safeString(map[Fields.productId]),
    rating: _safeDouble(map[Fields.rating]),
    review: map[Fields.review] != null ? _safeString(map[Fields.review]) : null,
    createdAt: _parseDateTime(map[Fields.createdAt]) ?? DateTime.now(),
  );
}

/// Parse an Address from any dynamic Firestore value
Address _safeAddress(dynamic value) {
  final map = _safeMap(value);
  return Address(
    street: _safeString(map[Fields.street]),
    apartment: _safeString(map[Fields.apartment]),
    city: _safeString(map[Fields.city]),
    state: _safeString(map[Fields.state]),
    postalCode: _safeString(map[Fields.postalCode]),
    country: _safeString(map[Fields.country], BusinessRules.allowedShippingCountries.first),
    phoneNumber: map[Fields.phoneNumber] != null ? _safeString(map[Fields.phoneNumber]) : null,
    isDefault: _safeBool(map[Fields.isDefault]),
    label: map[Fields.label] != null ? _safeString(map[Fields.label]) : null,
    latitude: map[Fields.latitude] != null ? _safeDouble(map[Fields.latitude]) : null,
    longitude: map[Fields.longitude] != null ? _safeDouble(map[Fields.longitude]) : null,
  );
}

/// Safely convert to bool
bool _safeBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

/// Safely convert to double
double _safeDouble(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Safely convert to int
int _safeInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Safely parse a Map from dynamic (handles Firestore internal types)
Map<String, dynamic> _safeMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

/// Safely convert any Firestore value to String (handles MiniFieldValue, int, etc.)
String _safeString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

/// Safely convert to List String
List<String> _safeStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) return value.map((e) => _safeString(e)).toList();
  return [];
}

// ============================================================================
// ORDER
// ============================================================================

@Freezed(toJson: true, fromJson: true)
abstract class Order with _$Order {
  const factory Order({
    required String orderId,
    required String userId,
    @Default(1) int version,
    @Default(1) int schemaVersion,
    String? customerId,
    String? customerEmail,
    required List<OrderItem> items,
    // All money in integer cents
    required int totalAmountCents,
    required int subtotalCents,
    @Default(0) int shippingCostCents,
    @Default(0) int taxAmountCents,
    required Taxes taxes,
    @Default(OrderStatus.pending) OrderStatus orderStatus,
    @Default(PaymentStatus.awaitingPayment) PaymentStatus paymentStatus,
    Address? shippingAddress,
    required DateTime createdAt,
    @Default(BusinessRules.defaultCurrency) String currency,
    @Default([]) List<String> sellerIds,
    // Unique product IDs in this order (computed from items — enables chat gate query)
    @Default([]) List<String> productIds,
    String? stripeSessionId,
    // Shipping approval
    @Default(ShippingApprovalStatus.notRequired) ShippingApprovalStatus shippingApprovalStatus,
    @Default(false) bool shippingApprovalRequired,
    @Default(0) int actualShippingCents,
    @Default(0) int pendingTotalCents,
    // Payout tracking
    @Default([]) List<SellerPayout> sellerPayouts,
    @Default(false) bool confirmedByClient,
    DateTime? confirmedAt,
    @Default(0) int platformFeeTotalCents,
    @Default(PayoutStatusValues.pending) String payoutStatus,
    // Ratings
    @Default([]) List<Ratings> ratings,
    // === AUDIT FIX: 18 missing fields synced from Python/Firestore ===
    // Payment capture tracking
    String? stripePaymentIntentId,
    @Default(0) int captureAttempts,
    DateTime? capturedAt,
    DateTime? expiresAt,
    @Default(false) bool autoConfirmed,
    @Default(false) bool autoCaptured,
    // Refund tracking
    @Default(0) int refundAmountCents,
    DateTime? refundedAt,
    // Cancellation tracking
    @Default(false) bool stockRestored,
    String? cancelledBy,
    DateTime? cancelledAt,
    String? cancellationReason,
    // Shipping approval
    DateTime? respondedAt,
    // Admin review
    @Default(false) bool requiresManualReview,
    String? manualReviewReason,
    @Default([]) List<String> payoutErrors,
    // Timestamp
    DateTime? updatedAt,
    // Tax fields (new)
    @Default([]) List<Map<String, dynamic>> itemTaxes,
    @Default(false) bool taxExempt,
    Map<String, dynamic>? taxExemption,
    // Delivery instructions from buyer
    String? deliveryInstructions,
    // Coupon / promo code (N-07)
    String? couponCode,
    @Default(0) int discountAmountCents,
    // Phase 3.5 fraud / capture tracking (schema sync fix — AUDIT)
    @Default(0) int fraudScore,
    Map<String, dynamic>? sellerCaptures,
    String? lastCaptureError,
  }) = _Order;

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    OrderStatus parseOrderStatus(dynamic raw) {
      final value = raw?.toString();
      switch (value) {
        case OrderStatusValues.pending:
          return OrderStatus.pending;
        case OrderStatusValues.confirmed:
          return OrderStatus.confirmed;
        case OrderStatusValues.processing:
          return OrderStatus.processing;
        case OrderStatusValues.shipped:
          return OrderStatus.shipped;
        case OrderStatusValues.inTransit:
          return OrderStatus.inTransit;
        case OrderStatusValues.delivered:
          return OrderStatus.delivered;
        case OrderStatusValues.cancelled:
          return OrderStatus.cancelled;
        case OrderStatusValues.failed:
          return OrderStatus.failed;
        case OrderStatusValues.expired:
          return OrderStatus.expired;
        case OrderStatusValues.disputed:
          return OrderStatus.disputed;
        case OrderStatusValues.refunded:
          return OrderStatus.refunded;
        case OrderStatusValues.partiallyRefunded:
          return OrderStatus.partiallyRefunded;
        default:
          return OrderStatus.pending;
      }
    }

    PaymentStatus parsePaymentStatus(dynamic raw) {
      final value = raw?.toString();
      switch (value) {
        case PaymentStatusValues.awaitingPayment:
          return PaymentStatus.awaitingPayment;
        case PaymentStatusValues.processing:
          return PaymentStatus.processing;
        case PaymentStatusValues.paid:
          return PaymentStatus.paid;
        case PaymentStatusValues.authorized:
          return PaymentStatus.authorized;
        case PaymentStatusValues.captured:
          return PaymentStatus.captured;
        case PaymentStatusValues.paymentFailed:
          return PaymentStatus.paymentFailed;
        case PaymentStatusValues.refunded:
          return PaymentStatus.refunded;
        case PaymentStatusValues.sessionExpired:
          return PaymentStatus.sessionExpired;
        case PaymentStatusValues.cancelled:
          return PaymentStatus.cancelled;
        case PaymentStatusValues.authorizationExpired:
          return PaymentStatus.authorizationExpired;
        case PaymentStatusValues.disputed:
          return PaymentStatus.disputed;
        case PaymentStatusValues.capturing:
          return PaymentStatus.capturing;
        case PaymentStatusValues.cancelling:
          return PaymentStatus.cancelling;
        case PaymentStatusValues.expiring:
          return PaymentStatus.expiring;
        case PaymentStatusValues.partiallyRefunded:
          return PaymentStatus.partiallyRefunded;
        case PaymentStatusValues.voided:
          return PaymentStatus.voided;
        case PaymentStatusValues.cancelFailed:
          return PaymentStatus.cancelFailed;
        default:
          return PaymentStatus.awaitingPayment;
      }
    }

    ShippingApprovalStatus parseShippingApprovalStatus(dynamic raw) {
      final value = raw?.toString();
      switch (value) {
        case ShippingApprovalStatusValues.notRequired:
          return ShippingApprovalStatus.notRequired;
        case ShippingApprovalStatusValues.pending:
          return ShippingApprovalStatus.pending;
        case ShippingApprovalStatusValues.approved:
          return ShippingApprovalStatus.approved;
        case ShippingApprovalStatusValues.rejected:
          return ShippingApprovalStatus.rejected;
        default:
          return ShippingApprovalStatus.notRequired;
      }
    }

    // Parse items — use safe parser, NOT generated fromJson (avoids hard casts)
    final itemsData = data[Fields.items] as List<dynamic>? ?? [];
    final items = itemsData.map(_parseOrderItem).toList();

    // Parse taxes
    final taxesData = data[Fields.taxes];
    final taxes = taxesData is Map ? Taxes.fromMap(Map<String, dynamic>.from(taxesData)) : const Taxes();

    // Parse seller payouts — use safe parser
    final payoutsData = data[Fields.sellerPayouts] as List<dynamic>? ?? [];
    final payouts = payoutsData.map((p) => SellerPayout.fromMap(_safeMap(p))).toList();

    // Parse ratings — use safe parser
    final ratingsData = data[Fields.ratings];
    final ratings = ratingsData is List ? ratingsData.map(_parseRating).toList() : <Ratings>[];

    // Money — all cents
    final totalAmountCents = _safeInt(data[Fields.totalAmountCents]);
    final subtotalCents = _safeInt(data[Fields.subtotalCents]);
    final shippingCostCents = _safeInt(data[Fields.shippingCostCents]);
    final taxAmountCents = _safeInt(data[Fields.taxAmountCents]);

    // Address
    final rawAddress = _safeMap(data[Fields.shippingAddress]);

    return Order(
      orderId: _safeString(data[Fields.orderId], doc.id),
      userId: _safeString(data[Fields.userId]),
      version: _safeInt(data[Fields.version], 1),
      schemaVersion: _safeInt(data[Fields.schemaVersion], 1),
      customerId: data[Fields.customerId] != null ? _safeString(data[Fields.customerId]) : null,
      customerEmail: data[Fields.customerEmail] != null ? _safeString(data[Fields.customerEmail]) : null,
      items: items,
      totalAmountCents: totalAmountCents,
      subtotalCents: subtotalCents,
      shippingCostCents: shippingCostCents,
      taxAmountCents: taxAmountCents,
      taxes: taxes,
      orderStatus: parseOrderStatus(data[Fields.orderStatus]),
      paymentStatus: parsePaymentStatus(data[Fields.paymentStatus]),
      shippingAddress: data[Fields.shippingAddress] != null ? _safeAddress(rawAddress) : null,
      createdAt: _parseDateTime(data[Fields.createdAt]) ?? DateTime.now(),
      currency: _safeString(data[Fields.currency], BusinessRules.defaultCurrency),
      sellerIds: _safeStringList(data[Fields.sellerIds]),
      productIds: _safeStringList(data[Fields.productIds]),
      stripeSessionId: data[Fields.stripeSessionId] != null ? _safeString(data[Fields.stripeSessionId]) : null,
      shippingApprovalStatus: parseShippingApprovalStatus(data[Fields.shippingApprovalStatus]),
      shippingApprovalRequired: _safeBool(data[Fields.shippingApprovalRequired]),
      actualShippingCents: _safeInt(data[Fields.actualShippingCents]),
      pendingTotalCents: _safeInt(data[Fields.pendingTotalCents]),
      sellerPayouts: payouts,
      confirmedByClient: _safeBool(data[Fields.confirmedByClient]),
      confirmedAt: _parseDateTime(data[Fields.confirmedAt]),
      platformFeeTotalCents: _safeInt(data[Fields.platformFeeTotalCents]),
      payoutStatus: _safeString(data[Fields.payoutStatus], PayoutStatusValues.pending),
      ratings: ratings,
      // === AUDIT FIX: Parse 18 missing fields ===
      stripePaymentIntentId: data[Fields.stripePaymentIntentId] != null ? _safeString(data[Fields.stripePaymentIntentId]) : null,
      captureAttempts: _safeInt(data[Fields.captureAttempts]),
      capturedAt: _parseDateTime(data[Fields.capturedAt]),
      expiresAt: _parseDateTime(data[Fields.expiresAt]),
      autoConfirmed: _safeBool(data[Fields.autoConfirmed]),
      autoCaptured: _safeBool(data[Fields.autoCaptured]),
      refundAmountCents: _safeInt(data[Fields.refundAmountCents]),
      refundedAt: _parseDateTime(data[Fields.refundedAt]),
      stockRestored: _safeBool(data[Fields.stockRestored]),
      cancelledBy: data[Fields.cancelledBy] != null ? _safeString(data[Fields.cancelledBy]) : null,
      cancelledAt: _parseDateTime(data[Fields.cancelledAt]),
      cancellationReason: data[Fields.cancellationReason] != null ? _safeString(data[Fields.cancellationReason]) : null,
      respondedAt: _parseDateTime(data[Fields.respondedAt]),
      requiresManualReview: _safeBool(data[Fields.requiresManualReview]),
      manualReviewReason: data[Fields.manualReviewReason] != null ? _safeString(data[Fields.manualReviewReason]) : null,
      payoutErrors: _safeStringList(data[Fields.payoutErrors]),
      updatedAt: _parseDateTime(data[Fields.updatedAt]),
      // Parse tax fields
      itemTaxes: (data[Fields.itemTaxes] as List<dynamic>?)?.map((e) => _safeMap(e)).toList() ?? [],
      taxExempt: _safeBool(data[Fields.taxExempt]),
      taxExemption: data[Fields.taxExemption] != null ? _safeMap(data[Fields.taxExemption]) : null,
      // Delivery instructions from buyer
      deliveryInstructions: data[Fields.deliveryInstructions] != null ? _safeString(data[Fields.deliveryInstructions]) : null,
      // Coupon / promo code (N-07)
      couponCode: data[Fields.couponCode] != null ? _safeString(data[Fields.couponCode]) : null,
      discountAmountCents: _safeInt(data[Fields.discountAmountCents]),
      // Phase 3.5 fraud / capture tracking (schema sync fix)
      fraudScore: _safeInt(data[Fields.fraudScore]),
      sellerCaptures: data[Fields.sellerCaptures] != null ? _safeMap(data[Fields.sellerCaptures]) : null,
      lastCaptureError: data[Fields.lastCaptureError] != null ? _safeString(data[Fields.lastCaptureError]) : null,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  const Order._();

  /// Actual shipping in dollars (derived from cents — Firestore stores cents)
  double get actualShipping => actualShippingCents / 100.0;

  /// Pending total in dollars (derived from cents)
  double get pendingTotal => pendingTotalCents / 100.0;

  /// Platform fee total in dollars (derived from cents)
  double get platformFeeTotal => platformFeeTotalCents / 100.0;

  /// Refund amount in dollars (derived from cents)
  double get refundAmount => refundAmountCents / 100.0;

  /// Shipping in dollars (derived from cents)
  double get shippingCost => shippingCostCents / 100.0;

  /// Subtotal in dollars (derived from cents)
  double get subtotal => subtotalCents / 100.0;

  /// Tax in dollars (derived from cents)
  double get taxAmount => taxAmountCents / 100.0;

  /// Total in dollars (derived from cents)
  double get total => totalAmountCents / 100.0;
}

// ============================================================================
// ORDER CREATE
// ============================================================================

@freezed
abstract class OrderCreate with _$OrderCreate {
  const factory OrderCreate({
    required String userId,
    required String customerId,
    required String customerEmail,
    required List<OrderItem> items,
    required Address shippingAddress,
    @Default(0.0) double shippingCost,
    @Default(BusinessRules.defaultCurrency) String currency,
    @Default(false) bool shippingApprovalRequired,
  }) = _OrderCreate;

  factory OrderCreate.fromJson(Map<String, dynamic> json) => _$OrderCreateFromJson(json);
}

// ============================================================================
// ORDER ITEM
// ============================================================================

@Freezed(toJson: true, fromJson: true)
abstract class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String productId,
    String? cartItemId, // F-001/F-003: canonical cart item ID — survives duplicate-productId carts
    required String name,
    required String description,
    required double price,
    required int quantity,
    required List<String> imageUrls,
    required String sellerId,
    Address? sellerAddress,
    // Per-item status tracking
    @Default(DeliveryStatusValues.pending) String status, // 'pending' | 'shipped' | 'delivered' | 'refunded'
    String? trackingNumber,
    String? carrier,
    String? carrierNote, // Free-text override when carrier='other'
    String? sellerSku, // Seller's SKU snapshotted at purchase time
    String? sellerName, // Seller display name snapshotted at purchase time
    DateTime? shippedAt,
    DateTime? deliveredAt,
    DateTime? refundedAt,
    String? refundReason,
    int? refundAmountCents,
    String? refundId,
    @Default(false) bool confirmedByBuyer,
    // Variant tracking (immutable snapshot at order creation)
    String? variantId,
    String? variantTitle,
    Map<String, String>? variantOptions,
    String? variantSku,
    // Shipping metadata
    double? weightKg,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    @Default(false) bool isLocalDeliveryOnly,
    @Default(false) bool isPerishable,
    @Default(3) int estimatedShipDays,
    @Default([]) List<SellerDeliveryOption> deliveryOptions,
    @Default(1) int minimumOrderQuantity,
    @Default(false) bool freeShipping,
    @Default(false) bool isDigital,
    String? licenseKey,
    @Default(false) bool digitalUnlocked,
    String? digitalType,
    Map<String, String>? digitalBuilds,
    // Tax field (new)
    String? taxCode,
    String? buyerNote, // ADDED
    String? fulfillmentWarehouseId, // TASK 02: warehouse from which this item was fulfilled
  }) = _OrderItem;
  factory OrderItem.fromJson(Map<String, dynamic> json) => _$OrderItemFromJson(json);

  const OrderItem._();

  /// Calculate item subtotal
  double get subtotal => price * quantity;
}

// ============================================================================
// RATINGS
// ============================================================================

@freezed
abstract class Ratings with _$Ratings {
  const factory Ratings({required String productId, required double rating, String? review, required DateTime createdAt}) = _Ratings;

  factory Ratings.fromJson(Map<String, dynamic> json) => _$RatingsFromJson(json);
}

// ============================================================================
// SELLER PAYOUT
// ============================================================================

@freezed
abstract class SellerPayout with _$SellerPayout {
  const factory SellerPayout({
    required String sellerId,
    String? stripeAccountId,
    required int amountCents,
    required int platformFeeCents,
    required int netAmountCents,
    @Default(PayoutStatusValues.pending) String status,
    DateTime? payoutDate,
    String? stripeTransferId,
    String? failureReason,
  }) = _SellerPayout;

  factory SellerPayout.fromJson(Map<String, dynamic> json) => _$SellerPayoutFromJson(json);

  factory SellerPayout.fromMap(Map<String, dynamic> map) {
    return SellerPayout(
      sellerId: _safeString(map[Fields.sellerId]),
      stripeAccountId: map[Fields.stripeAccountId] != null ? _safeString(map[Fields.stripeAccountId]) : null,
      amountCents: _safeInt(map[Fields.amountCents]),
      platformFeeCents: _safeInt(map[Fields.platformFeeCents]),
      netAmountCents: _safeInt(map[Fields.netAmountCents]),
      status: _safeString(map[Fields.status], PayoutStatusValues.pending),
      payoutDate: _parseDateTime(map[Fields.payoutDate]),
      stripeTransferId: map[Fields.stripeTransferId] != null ? _safeString(map[Fields.stripeTransferId]) : null,
      failureReason: map[Fields.failureReason] != null ? _safeString(map[Fields.failureReason]) : null,
    );
  }

  const SellerPayout._();

  /// Amount in dollars
  double get amount => amountCents / 100.0;

  /// Net amount in dollars
  double get netAmount => netAmountCents / 100.0;

  /// Platform fee in dollars
  double get platformFee => platformFeeCents / 100.0;
}

// ============================================================================
// TAXES
// ============================================================================

@freezed
abstract class Taxes with _$Taxes {
  const factory Taxes({@Default(0.0) double gst, @Default(0.0) double pst, @Default(0.0) double hst, @Default(0.0) double qst}) = _Taxes;

  factory Taxes.fromJson(Map<String, dynamic> json) {
    return Taxes(
      gst: (json[Fields.GST] ?? 0.0).toDouble(),
      pst: (json[Fields.PST] ?? 0.0).toDouble(),
      hst: (json[Fields.HST] ?? 0.0).toDouble(),
      qst: (json[Fields.QST] ?? 0.0).toDouble(),
    );
  }

  factory Taxes.fromMap(Map<String, dynamic> map) => Taxes(
    gst: (map[Fields.GST] ?? 0.0).toDouble(),
    pst: (map[Fields.PST] ?? 0.0).toDouble(),
    hst: (map[Fields.HST] ?? 0.0).toDouble(),
    qst: (map[Fields.QST] ?? 0.0).toDouble(),
  );

  const Taxes._();

  /// Calculate total tax amount
  double get total => gst + pst + hst + qst;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {Fields.GST: gst, Fields.PST: pst, Fields.HST: hst, Fields.QST: qst};

  /// Convert to Map
  Map<String, double> toMap() => {Fields.GST: gst, Fields.PST: pst, Fields.HST: hst, Fields.QST: qst};
}
