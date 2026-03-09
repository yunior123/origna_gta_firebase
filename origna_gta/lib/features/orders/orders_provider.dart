// coverage:ignore-file
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/models/generated/models.dart' as models;

// ============================================================================
// BUYER ORDERS PROVIDER
// ============================================================================

final buyerOrdersProvider = StreamProvider.autoDispose<List<models.Order>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value([]);

  return ref.watch(orderRepositoryProvider).watchBuyerOrders(userId);
});

// ============================================================================
// SINGLE ORDER PROVIDER
// ============================================================================

final orderByIdProvider = FutureProvider.autoDispose.family<models.Order?, String>((ref, orderId) async {
  return await ref.watch(orderRepositoryProvider).fetchOrderById(orderId);
});

/// Watch paid order by Stripe session ID (used for success redirect)
final paidOrderBySessionProvider = StreamProvider.autoDispose.family<models.Order?, String>((ref, sessionId) {
  return ref.watch(orderRepositoryProvider).watchPaidOrderBySession(sessionId);
});

final pendingApprovalsCountProvider = Provider.autoDispose<int>((ref) {
  final ordersAsync = ref.watch(buyerOrdersProvider);
  return ordersAsync.maybeWhen(
    data: (orders) => orders.where((o) => o.shippingApprovalStatus == models.ShippingApprovalStatus.pending).length,
    orElse: () => 0,
  );
});

final pendingShippingApprovalsProvider = Provider.autoDispose<AsyncValue<List<models.Order>>>((ref) {
  return ref.watch(buyerOrdersProvider).whenData((orders) {
    return orders.where((o) => o.shippingApprovalStatus == models.ShippingApprovalStatus.pending).toList();
  });
});

// ============================================================================
// SELLER ORDERS PROVIDER
// ============================================================================

final sellerOrdersProvider = StreamProvider.autoDispose<List<models.Order>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value([]);

  return ref.watch(orderRepositoryProvider).watchSellerOrders(userId);
});

/// Documentation for OrderError
class OrderError extends OrderResult {
  final String message;
  final String? code;
  OrderError({required this.message, this.code});
}

// ============================================================================
// ORDER RESULT TYPES
// ============================================================================

sealed class OrderResult {}

/// Documentation for OrderSuccess
class OrderSuccess extends OrderResult {
  final String message;
  OrderSuccess({required this.message});
}
