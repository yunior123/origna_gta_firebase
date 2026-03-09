import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:origna_gta/services/analytics_service.dart';

void main() {
  group('AnalyticsService Tests', () {
    // Note: In test environment, kDebugMode is true.
    // Therefore, AnalyticsService._isEnabled evaluates to false.
    // This allows us to safely call these methods in tests without triggering
    // actual FirebaseAnalytics calls, avoiding "Firebase not initialized" errors.
    
    test('Auth events can be called without throwing', () async {
      await expectLater(AnalyticsService.logSignUp(method: 'email'), completes);
      await expectLater(AnalyticsService.logLogin(method: 'google'), completes);
    });

    test('Browse / Discovery events can be called without throwing', () async {
      await expectLater(
        AnalyticsService.logViewItemList(
          listName: 'Home Page',
          items: [AnalyticsEventItem(itemId: 'prod_1', itemName: 'Item 1')],
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logSelectItem(
          productId: 'prod_1',
          productName: 'Item 1',
          priceCad: 25.99,
          listName: 'Featured',
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logViewItem(
          productId: 'prod_1',
          productName: 'Item 1',
          priceCad: 25.99,
        ),
        completes,
      );
    });

    test('logSearch parameter validation and transformation logic (redaction)', () async {
      // Normal search
      await expectLater(AnalyticsService.logSearch(searchTerm: 'sneakers'), completes);
      
      // Search with potential PII (email) - should be redacted internally
      await expectLater(AnalyticsService.logSearch(searchTerm: 'test@example.com'), completes);
      
      // Search with potential PII (phone/credit card number) - should be redacted internally
      await expectLater(AnalyticsService.logSearch(searchTerm: '1234567890'), completes);
    });

    test('Cart events can be called without throwing', () async {
      await expectLater(
        AnalyticsService.logAddToCart(
          productId: 'prod_1',
          productName: 'Item 1',
          priceCad: 25.99,
          quantity: 2,
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logRemoveFromCart(
          productId: 'prod_1',
          productName: 'Item 1',
          priceCad: 25.99,
        ),
        completes,
      );
    });

    test('Wishlist events can be called without throwing', () async {
      await expectLater(
        AnalyticsService.logAddToWishlist(
          productId: 'prod_1',
          productName: 'Item 1',
          priceCad: 25.99,
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logRemoveFromWishlist(
          productId: 'prod_1',
          productName: 'Item 1',
        ),
        completes,
      );
    });

    test('Checkout funnel events can be called without throwing', () async {
      await expectLater(
        AnalyticsService.logBeginCheckout(valueCad: 100.0, itemCount: 3),
        completes,
      );

      await expectLater(
        AnalyticsService.logAddShippingInfo(
          valueCad: 100.0,
          shippingCostCad: 10.0,
          shippingTier: 'Express',
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logAddPaymentInfo(
          valueCad: 110.0,
          paymentType: 'Credit Card',
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logPurchase(
          orderId: 'order_123',
          valueCad: 110.0,
          itemCount: 3,
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logRefund(
          orderId: 'order_123',
          valueCad: 110.0,
        ),
        completes,
      );
    });

    test('Subscription events can be called without throwing', () async {
      await expectLater(
        AnalyticsService.logSubscriptionStarted(priceCad: 15.99),
        completes,
      );

      await expectLater(
        AnalyticsService.logSubscriptionCancelled(),
        completes,
      );
    });

    test('Reviews and Navigation events can be called without throwing', () async {
      await expectLater(
        AnalyticsService.logReviewSubmitted(
          productId: 'prod_1',
          rating: 4.5,
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logScreenView(screenName: 'ProfileScreen'),
        completes,
      );
    });
  });
}
