import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

/// Tracks local subscription state for back-in-stock notifications.
/// On first use, fetches the real subscription state from Firestore.
/// Uses autoDispose so state is cleared when the widget leaves the tree.
final stockNotificationNotifierProvider = StateNotifierProvider.autoDispose
    .family<StockNotificationNotifier, AsyncValue<bool>, ({String productId, String? variantKey})>(
  (ref, args) => StockNotificationNotifier(ref, args.productId, args.variantKey),
);

/// Documentation for StockNotificationNotifier
class StockNotificationNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref _ref;
  final String productId;
  final String? variantKey;

  StockNotificationNotifier(this._ref, this.productId, this.variantKey) : super(const AsyncValue.loading()) {
    // Re-initialize whenever auth state changes (login/logout).
    _ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      final prevUid = previous?.valueOrNull?.uid;
      final nextUid = next.valueOrNull?.uid;
      if (prevUid != nextUid) init();
    });
    init();
  }

  /// Checks Firestore for an existing subscription so the UI reflects the
  /// real state even if the user subscribed in a previous session.
  Future<void> init() async {
    try {
      final uid = _ref.read(userIdProvider);
      if (uid == null) {
        state = const AsyncValue.data(false);
        return;
      }
      var query = _ref
          .read(firestoreProvider)
          .collection(Collections.stockNotifications)
          .where(Fields.userId, isEqualTo: uid)
          .where(Fields.productId, isEqualTo: productId);
      if (variantKey != null) {
        query = query.where(Fields.variantKey, isEqualTo: variantKey);
      } else {
        // Filter explicitly for product-level (empty variantKey) to avoid false positive
        // from a variant-specific subscription on the same product.
        query = query.where(Fields.variantKey, isEqualTo: '');
      }
      final snap = await query.limit(1).get();
      state = AsyncValue.data(snap.docs.isNotEmpty);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> subscribe() async {
    state = const AsyncValue.loading();
    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final payload = {Fields.productId: productId};
      if (variantKey != null) payload[Fields.variantKey] = variantKey!;
      await functions
          .httpsCallable(CloudFunctionEndpoints.subscribeStockNotification)
          .call(payload);
      state = const AsyncValue.data(true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> unsubscribe() async {
    state = const AsyncValue.loading();
    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final payload = {Fields.productId: productId};
      if (variantKey != null) payload[Fields.variantKey] = variantKey!;
      await functions
          .httpsCallable(CloudFunctionEndpoints.unsubscribeStockNotification)
          .call(payload);
      state = const AsyncValue.data(false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
