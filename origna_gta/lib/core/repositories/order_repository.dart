// coverage:ignore-file
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:origna_gta/models/generated/models.dart' as models;
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/constants.dart' as constants;

/// Documentation for FirebaseOrderRepository
class FirebaseOrderRepository implements OrderRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirebaseOrderRepository(this._firestore, this._functions);

  @override
  Future<void> approveShippingCost(String orderId, bool approved) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.approveShippingCost).call({
      Fields.orderId: orderId,
      ApiKeys.approved: approved,
    });
  }

  @override
  Future<void> capturePayment(String orderId) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.capturePayment).call({Fields.orderId: orderId});
  }

  @override
  Future<void> confirmReceipt(String orderId, {String? productId}) async {
    if (productId != null && productId.isNotEmpty) {
      // Per-item receipt confirmation — triggers partial payout for that seller
      await _functions.httpsCallable(CloudFunctionEndpoints.confirmItemReceipt).call({
        Fields.orderId: orderId,
        Fields.productId: productId,
      });
    } else {
      // Whole-order payment capture (single-seller path)
      await _functions.httpsCallable(CloudFunctionEndpoints.capturePayment).call({
        Fields.orderId: orderId,
      });
    }
  }

  @override
  Future<Map<String, dynamic>> createCheckoutSession(Map<String, dynamic> orderData) async {
    final callable = _functions.httpsCallable(CloudFunctionEndpoints.createCheckoutSession);
    final response = await callable.call(orderData);
    return Map<String, dynamic>.from(response.data);
  }

  @override
  Future<models.Order?> fetchOrderById(String orderId) async {
    final doc = await _firestore.collection(Collections.orders).doc(orderId).get();
    if (!doc.exists) return null;
    return models.Order.fromFirestore(doc);
  }

  @override
  Future<void> updateItemStatus(String orderId, String itemId, String status, {String? trackingNumber, String? carrier, String? carrierNote}) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.updateItemStatus).call({
      Fields.orderId: orderId,
      Fields.productId: itemId,
      ApiKeys.newStatus: status,
      ...(trackingNumber != null ? {Fields.trackingNumber: trackingNumber} : {}),
      ...(carrier != null ? {Fields.carrier: carrier} : {}),
      ...(carrierNote != null ? {Fields.carrierNote: carrierNote} : {}),
    });
  }

  @override
  Future<void> updateLastSession(String userId, String sessionId, String orderId) async {
    await _firestore.collection(Collections.users).doc(userId).update({
      Fields.lastCheckoutSession: sessionId,
      Fields.lastOrderId: orderId,
      Fields.lastCheckoutTimestamp: FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateShippingCost(String orderId, double newShippingCost, String reason) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.updateShippingCost).call({
      Fields.orderId: orderId,
      ApiKeys.newShippingCost: newShippingCost,
      ApiKeys.reason: reason,
    });
  }

  @override
  Stream<List<models.Order>> watchBuyerOrders(String userId) {
    return _firestore
        .collection(Collections.orders)
        .where(Fields.userId, isEqualTo: userId)
        .where(Fields.paymentStatus, whereIn: [
          constants.PaymentStatus.authorized.value,
          constants.PaymentStatus.captured.value,
          constants.PaymentStatus.disputed.value,
          constants.PaymentStatus.refunded.value,
          constants.PaymentStatus.cancelled.value,
          constants.PaymentStatus.authorizationExpired.value,
        ])
        .orderBy(Fields.createdAt, descending: true)
        .limit(BusinessRules.ordersPageSize) // Pagination: limit initial load for scalability (100M+ users)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => models.Order.fromFirestore(doc)).toList());
  }

  @override
  Stream<models.Order?> watchPaidOrderBySession(String sessionId) {
    return _firestore
        .collection(Collections.orders)
        .where(Fields.stripeSessionId, isEqualTo: sessionId)
        .where(Fields.paymentStatus, isEqualTo: constants.PaymentStatus.captured.value)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return models.Order.fromFirestore(snapshot.docs.first);
        });
  }

  @override
  Stream<List<models.Order>> watchSellerOrders(String userId) {
    return _firestore
        .collection(Collections.orders)
        .where(Fields.sellerIds, arrayContains: userId)
        .where(Fields.paymentStatus, whereIn: [
          constants.PaymentStatus.authorized.value,
          constants.PaymentStatus.captured.value,
          constants.PaymentStatus.disputed.value,
          constants.PaymentStatus.refunded.value,
          constants.PaymentStatus.cancelled.value,
          constants.PaymentStatus.authorizationExpired.value,
        ])
        // NOTE: .orderBy(createdAt) is intentionally omitted — Firestore does not support
        // arrayContains + whereIn + orderBy on a different field. Sort client-side instead.
        .limit(BusinessRules.ordersPageSize)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs.map((doc) => models.Order.fromFirestore(doc)).toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }
}

abstract class OrderRepository {
  /// Approves or rejects a seller-submitted shipping cost update for [orderId].
  Future<void> approveShippingCost(String orderId, bool approved);

  /// Captures the pre-authorized Stripe payment for [orderId].
  /// Must be called after buyer confirms delivery (or auto-capture cron fires).
  Future<void> capturePayment(String orderId);

  /// Buyer confirms receipt of [orderId]; triggers capture if not yet done.
  Future<void> confirmReceipt(String orderId, {String? productId});

  /// Creates a Stripe Checkout session for the given [orderData] payload.
  /// Returns a map containing at least `{sessionId, checkoutUrl}`.
  Future<Map<String, dynamic>> createCheckoutSession(Map<String, dynamic> orderData);

  /// Fetches a single order by Firestore document ID.
  /// Returns null if the document does not exist.
  Future<models.Order?> fetchOrderById(String orderId);

  /// Updates the shipping status of a specific item within an order.
  ///
  /// [itemId] is the product ID of the item to update.
  /// [trackingNumber], [carrier], and [carrierNote] are optional and only relevant for the `shipped` status.
  Future<void> updateItemStatus(String orderId, String itemId, String status, {String? trackingNumber, String? carrier, String? carrierNote});

  /// Persists the last Stripe session and order IDs on the user document for
  /// post-payment recovery (e.g., polling the success screen).
  Future<void> updateLastSession(String userId, String sessionId, String orderId);

  /// Submits a revised shipping cost for [orderId] with an audit [reason].
  Future<void> updateShippingCost(String orderId, double newShippingCost, String reason);

  /// Real-time stream of all orders placed by [userId] in terminal or active payment states.
  Stream<List<models.Order>> watchBuyerOrders(String userId);

  /// Watches a single order matched by Stripe session ID, resolving only once it is captured.
  /// Returns null if no matching captured order exists yet.
  Stream<models.Order?> watchPaidOrderBySession(String sessionId);

  /// Real-time stream of orders containing items sold by [userId].
  /// Results are sorted client-side by createdAt descending because Firestore
  /// does not support arrayContains + whereIn + orderBy on a different field.
  Stream<List<models.Order>> watchSellerOrders(String userId);
}
