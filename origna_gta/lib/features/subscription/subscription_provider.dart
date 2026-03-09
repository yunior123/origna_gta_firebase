// coverage:ignore-file
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/services/analytics_service.dart';

import 'subscription_state.dart';

final subscriptionViewModelProvider =
    StateNotifierProvider.autoDispose<SubscriptionViewModel, SubscriptionState>((ref) {
  return SubscriptionViewModel(ref);
});

/// Streams the current user's subscription doc from Firestore for real-time updates.
final subscriptionStreamProvider = StreamProvider.autoDispose<SubscriptionInfo?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);

  return ref
      .watch(firestoreProvider)
      .collection(Collections.subscriptions)
      .doc(uid)
      .snapshots()
      .map((snap) {
    if (!snap.exists) return null;
    final data = snap.data() ?? {};
    return SubscriptionInfo.fromMap(data);
  });
});

/// Documentation for SubscriptionViewModel
class SubscriptionViewModel extends StateNotifier<SubscriptionState> {
  final Ref _ref;

  SubscriptionViewModel(this._ref) : super(const SubscriptionState());

  Future<void> createSubscription() async {
    state = state.copyWith(isLoading: true, clearError: true, clearCheckoutUrl: true);
    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final result = await functions
          .httpsCallable(CloudFunctionEndpoints.createSubscription)
          .call<Map<String, dynamic>>();
      final url = result.data['checkoutUrl'] as String?;
      unawaited(AnalyticsService.logSubscriptionStarted(priceCad: BusinessRules.premiumSubscriptionPriceCad));
      state = state.copyWith(isLoading: false, checkoutUrl: url);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _parseError(e));
    }
  }

  Future<void> cancelSubscription() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      await functions.httpsCallable(CloudFunctionEndpoints.cancelSubscription).call();
      unawaited(AnalyticsService.logSubscriptionCancelled());
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _parseError(e));
    }
  }

  Future<void> updateNotificationPreferences({bool? notifyNewProducts, bool? notifyTrending}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _ref.read(userRepositoryProvider).updateNotificationPreferences(
      uid,
      notifyNewProducts: notifyNewProducts,
      notifyTrending: notifyTrending,
    );
  }

  Future<void> reactivateSubscription() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      await functions.httpsCallable(CloudFunctionEndpoints.reactivateSubscription).call();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _parseError(e));
    }
  }

  void clearCheckoutUrl() => state = state.copyWith(clearCheckoutUrl: true);

  String _parseError(Object e) {
    final str = e.toString();
    if (str.contains('] ')) return str.split('] ').last;
    return str;
  }
}
