import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:origna_gta/utils/env_config.dart';

/// Wraps FirebaseAnalytics with environment guards.
/// All events are no-ops in emulator and dev environments to keep production data clean.
/// Covers the full GA4 e-commerce funnel + auth + marketplace-specific events.
class AnalyticsService {
  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  // BOOT-M3: also disable in staging to avoid polluting production data
  // Also disable in debug mode to avoid errors when Firebase is not initialized
  static bool get _isEnabled => !kDebugMode && !envConfig.isEmulator && !envConfig.isDev && !envConfig.isStaging;

  // ── Auth ────────────────────────────────────────────────────────────────────

  static Future<void> logSignUp({required String method}) async {
    if (!_isEnabled) return;
    await _analytics.logSignUp(signUpMethod: method);
  }

  static Future<void> logLogin({required String method}) async {
    if (!_isEnabled) return;
    await _analytics.logLogin(loginMethod: method);
  }

  // ── Browse / Discovery ──────────────────────────────────────────────────────

  static Future<void> logViewItemList({
    required String listName,
    required List<AnalyticsEventItem> items,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logViewItemList(itemListName: listName, items: items);
  }

  static Future<void> logSelectItem({
    required String productId,
    required String productName,
    required double priceCad,
    String listName = '',
  }) async {
    if (!_isEnabled) return;
    await _analytics.logSelectItem(
      itemListName: listName,
      items: [AnalyticsEventItem(itemId: productId, itemName: productName, price: priceCad)],
    );
  }

  static Future<void> logViewItem({
    required String productId,
    required String productName,
    required double priceCad,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logViewItem(
      currency: 'CAD',
      value: priceCad,
      items: [
        AnalyticsEventItem(itemId: productId, itemName: productName, price: priceCad),
      ],
    );
  }

  static Future<void> logSearch({required String searchTerm}) async {
    if (!_isEnabled) return;
    // F-68: Redact potential PII before sending to analytics.
    final redacted = _redactSearchTerm(searchTerm);
    if (redacted == null) return;
    await _analytics.logSearch(searchTerm: redacted);
  }

  // ── Cart ────────────────────────────────────────────────────────────────────

  static Future<void> logAddToCart({
    required String productId,
    required String productName,
    required double priceCad,
    int quantity = 1,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logAddToCart(
      currency: 'CAD',
      value: priceCad * quantity,
      items: [
        AnalyticsEventItem(itemId: productId, itemName: productName, price: priceCad, quantity: quantity),
      ],
    );
  }

  static Future<void> logRemoveFromCart({
    required String productId,
    required String productName,
    required double priceCad,
    int quantity = 1,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logRemoveFromCart(
      currency: 'CAD',
      value: priceCad * quantity,
      items: [
        AnalyticsEventItem(itemId: productId, itemName: productName, price: priceCad, quantity: quantity),
      ],
    );
  }

  // ── Wishlist ─────────────────────────────────────────────────────────────────

  static Future<void> logAddToWishlist({
    required String productId,
    required String productName,
    required double priceCad,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logAddToWishlist(
      currency: 'CAD',
      value: priceCad,
      items: [AnalyticsEventItem(itemId: productId, itemName: productName, price: priceCad)],
    );
  }

  static Future<void> logRemoveFromWishlist({
    required String productId,
    required String productName,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logEvent(
      name: 'remove_from_wishlist',
      parameters: {'item_id': productId, 'item_name': productName},
    );
  }

  // ── Checkout funnel ─────────────────────────────────────────────────────────

  static Future<void> logBeginCheckout({
    required double valueCad,
    required int itemCount,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logBeginCheckout(currency: 'CAD', value: valueCad);
  }

  static Future<void> logAddShippingInfo({
    required double valueCad,
    required double shippingCostCad,
    required String shippingTier,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logAddShippingInfo(
      currency: 'CAD',
      value: valueCad,
      shippingTier: shippingTier,
    );
  }

  static Future<void> logAddPaymentInfo({
    required double valueCad,
    required String paymentType,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logAddPaymentInfo(
      currency: 'CAD',
      value: valueCad,
      paymentType: paymentType,
    );
  }

  static Future<void> logPurchase({
    required String orderId,
    required double valueCad,
    required int itemCount,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logPurchase(
      currency: 'CAD',
      value: valueCad,
      transactionId: orderId,
      items: [],
    );
  }

  static Future<void> logRefund({
    required String orderId,
    required double valueCad,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logRefund(
      currency: 'CAD',
      value: valueCad,
      transactionId: orderId,
    );
  }

  // ── Subscription ────────────────────────────────────────────────────────────

  static Future<void> logSubscriptionStarted({required double priceCad}) async {
    if (!_isEnabled) return;
    await _analytics.logEvent(
      name: 'subscription_started',
      parameters: {'currency': 'CAD', 'value': priceCad},
    );
  }

  static Future<void> logSubscriptionCancelled() async {
    if (!_isEnabled) return;
    await _analytics.logEvent(name: 'subscription_cancelled');
  }

  // ── Reviews ─────────────────────────────────────────────────────────────────

  static Future<void> logReviewSubmitted({
    required String productId,
    required double rating,
  }) async {
    if (!_isEnabled) return;
    await _analytics.logEvent(
      name: 'review_submitted',
      parameters: {'item_id': productId, 'rating': rating},
    );
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  static Future<void> logScreenView({required String screenName}) async {
    if (!_isEnabled) return;
    await _analytics.logScreenView(screenName: screenName);
  }

  // ── PII redaction ───────────────────────────────────────────────────────────

  static String? _redactSearchTerm(String term) {
    if (term.contains('@')) return null;
    if (RegExp(r'\b\d{7,}\b').hasMatch(term)) return null;
    return term;
  }
}
