import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart';

void main() {
  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _minimalOrderItemJson() => {
        'productId': 'prod_1',
        'name': 'Widget',
        'description': 'A fine widget',
        'price': 25.50,
        'quantity': 2,
        'imageUrls': ['https://img.example.com/a.jpg'],
        'sellerId': 'seller_1',
      };

  Map<String, dynamic> _fullOrderItemJson() => {
        ..._minimalOrderItemJson(),
        'cartItemId': 'cart_item_99',
        'sellerAddress': {
          'street': '456 Oak Ave',
          'apartment': '',
          'city': 'Montreal',
          'state': 'QC',
          'postalCode': 'H2X 1Y4',
          'country': 'Canada',
          'isDefault': false,
        },
        'status': DeliveryStatusValues.shipped,
        'trackingNumber': 'TRK123456',
        'carrier': 'Canada Post',
        'carrierNote': 'Leave at door',
        'sellerSku': 'SKU-001',
        'sellerName': 'Acme Inc.',
        'shippedAt': '2026-03-01T10:00:00.000',
        'deliveredAt': '2026-03-05T14:00:00.000',
        'refundedAt': null,
        'refundReason': null,
        'refundAmountCents': null,
        'refundId': null,
        'confirmedByBuyer': true,
        'variantId': 'var_1',
        'variantTitle': 'Large / Blue',
        'variantOptions': {'size': 'L', 'color': 'Blue'},
        'variantSku': 'SKU-001-L-BL',
        'weightKg': 1.5,
        'lengthCm': 30.0,
        'widthCm': 20.0,
        'heightCm': 10.0,
        'isLocalDeliveryOnly': true,
        'isPerishable': true,
        'estimatedShipDays': 5,
        'deliveryOptions': <Map<String, dynamic>>[],
        'minimumOrderQuantity': 2,
        'freeShipping': true,
        'isDigital': false,
        'licenseKey': null,
        'digitalUnlocked': false,
        'digitalType': null,
        'digitalBuilds': null,
        'taxCode': 'GST_EXEMPT',
        'buyerNote': 'Please gift-wrap',
        'fulfillmentWarehouseId': 'wh_01',
      };

  Map<String, dynamic> _minimalTaxesJson() => {
        Fields.GST: 0.0,
        Fields.PST: 0.0,
        Fields.HST: 0.0,
        Fields.QST: 0.0,
      };

  Map<String, dynamic> _minimalOrderJson({DateTime? createdAt}) => {
        'orderId': 'ord_1',
        'userId': 'user_1',
        'items': [_minimalOrderItemJson()],
        'totalAmountCents': 5100,
        'subtotalCents': 5100,
        'taxes': _minimalTaxesJson(),
        'createdAt': (createdAt ?? DateTime(2026, 3, 1)).toIso8601String(),
      };

  Map<String, dynamic> _sellerPayoutJson({
    DateTime? payoutDate,
  }) =>
      {
        'sellerId': 'seller_1',
        'stripeAccountId': 'acct_abc',
        'amountCents': 5000,
        'platformFeeCents': 250,
        'netAmountCents': 4750,
        'status': PayoutStatusValues.completed,
        'payoutDate': payoutDate?.toIso8601String(),
        'stripeTransferId': 'tr_xyz',
        'failureReason': null,
      };

  Map<String, dynamic> _ratingsJson({DateTime? createdAt}) => {
        'productId': 'prod_1',
        'rating': 4.5,
        'review': 'Great product!',
        'createdAt': (createdAt ?? DateTime(2026, 3, 5)).toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // ORDER ITEM
  // ---------------------------------------------------------------------------

  group('OrderItem fromJson/toJson', () {
    test('roundtrip with minimal required fields', () {
      final json = _minimalOrderItemJson();
      final model = OrderItem.fromJson(json);

      expect(model.productId, 'prod_1');
      expect(model.name, 'Widget');
      expect(model.description, 'A fine widget');
      expect(model.price, 25.50);
      expect(model.quantity, 2);
      expect(model.imageUrls, ['https://img.example.com/a.jpg']);
      expect(model.sellerId, 'seller_1');
      expect(model.subtotal, 51.0);

      // Defaults
      expect(model.cartItemId, isNull);
      expect(model.sellerAddress, isNull);
      expect(model.status, DeliveryStatusValues.pending);
      expect(model.trackingNumber, isNull);
      expect(model.confirmedByBuyer, false);
      expect(model.isLocalDeliveryOnly, false);
      expect(model.isPerishable, false);
      expect(model.estimatedShipDays, 3);
      expect(model.minimumOrderQuantity, 1);
      expect(model.freeShipping, false);
      expect(model.isDigital, false);
      expect(model.digitalUnlocked, false);
      expect(model.deliveryOptions, isEmpty);

      final out = model.toJson();
      expect(out['productId'], 'prod_1');
      expect(out['price'], 25.50);
      expect(out['quantity'], 2);
    });

    test('roundtrip with all optional fields populated', () {
      final json = _fullOrderItemJson();
      final model = OrderItem.fromJson(json);

      expect(model.cartItemId, 'cart_item_99');
      expect(model.sellerAddress, isNotNull);
      expect(model.sellerAddress!.city, 'Montreal');
      expect(model.status, DeliveryStatusValues.shipped);
      expect(model.trackingNumber, 'TRK123456');
      expect(model.carrier, 'Canada Post');
      expect(model.carrierNote, 'Leave at door');
      expect(model.sellerSku, 'SKU-001');
      expect(model.sellerName, 'Acme Inc.');
      expect(model.shippedAt, isNotNull);
      expect(model.deliveredAt, isNotNull);
      expect(model.confirmedByBuyer, true);
      expect(model.variantId, 'var_1');
      expect(model.variantTitle, 'Large / Blue');
      expect(model.variantOptions, {'size': 'L', 'color': 'Blue'});
      expect(model.variantSku, 'SKU-001-L-BL');
      expect(model.weightKg, 1.5);
      expect(model.lengthCm, 30.0);
      expect(model.widthCm, 20.0);
      expect(model.heightCm, 10.0);
      expect(model.isLocalDeliveryOnly, true);
      expect(model.isPerishable, true);
      expect(model.estimatedShipDays, 5);
      expect(model.minimumOrderQuantity, 2);
      expect(model.freeShipping, true);
      expect(model.taxCode, 'GST_EXEMPT');
      expect(model.buyerNote, 'Please gift-wrap');
      expect(model.fulfillmentWarehouseId, 'wh_01');

      final out = model.toJson();
      expect(out['cartItemId'], 'cart_item_99');
      expect(out['trackingNumber'], 'TRK123456');
      expect(out['variantOptions'], {'size': 'L', 'color': 'Blue'});
      expect(out['buyerNote'], 'Please gift-wrap');
      expect(out['fulfillmentWarehouseId'], 'wh_01');
    });

    test('digital item fields', () {
      final json = {
        ..._minimalOrderItemJson(),
        'isDigital': true,
        'licenseKey': 'LIC-ABCD-1234',
        'digitalUnlocked': true,
        'digitalType': 'software',
        'digitalBuilds': {'windows': 'https://dl.example.com/win', 'mac': 'https://dl.example.com/mac'},
      };
      final model = OrderItem.fromJson(json);

      expect(model.isDigital, true);
      expect(model.licenseKey, 'LIC-ABCD-1234');
      expect(model.digitalUnlocked, true);
      expect(model.digitalType, 'software');
      expect(model.digitalBuilds, {'windows': 'https://dl.example.com/win', 'mac': 'https://dl.example.com/mac'});

      final out = model.toJson();
      expect(out['isDigital'], true);
      expect(out['digitalBuilds'], hasLength(2));
    });

    test('refund fields', () {
      final refundedAt = DateTime(2026, 3, 7);
      final json = {
        ..._minimalOrderItemJson(),
        'status': DeliveryStatusValues.refunded,
        'refundedAt': refundedAt.toIso8601String(),
        'refundReason': 'Damaged in transit',
        'refundAmountCents': 2550,
        'refundId': 're_abc',
      };
      final model = OrderItem.fromJson(json);

      expect(model.status, DeliveryStatusValues.refunded);
      expect(model.refundedAt, refundedAt);
      expect(model.refundReason, 'Damaged in transit');
      expect(model.refundAmountCents, 2550);
      expect(model.refundId, 're_abc');
    });

    test('empty imageUrls list', () {
      final json = {
        ..._minimalOrderItemJson(),
        'imageUrls': <String>[],
      };
      final model = OrderItem.fromJson(json);
      expect(model.imageUrls, isEmpty);

      final out = model.toJson();
      expect(out['imageUrls'], isEmpty);
    });

    test('toJson DateTime fields serialize to ISO 8601', () {
      final shipped = DateTime(2026, 3, 2, 8, 30);
      final delivered = DateTime(2026, 3, 4, 16, 45);
      final json = {
        ..._minimalOrderItemJson(),
        'shippedAt': shipped.toIso8601String(),
        'deliveredAt': delivered.toIso8601String(),
      };
      final out = OrderItem.fromJson(json).toJson();
      expect(out['shippedAt'], shipped.toIso8601String());
      expect(out['deliveredAt'], delivered.toIso8601String());
    });

    test('deliveryOptions with nested SellerDeliveryOption', () {
      final json = {
        ..._minimalOrderItemJson(),
        'deliveryOptions': [
          {
            'type': DeliveryTypeValues.express,
            'description': 'Next day',
            'costCents': 1500,
            'estimatedDays': 1,
            'quantityDiscounts': <Map<String, dynamic>>[],
          },
        ],
      };
      final model = OrderItem.fromJson(json);
      expect(model.deliveryOptions, hasLength(1));
      expect(model.deliveryOptions.first.type, DeliveryTypeValues.express);
      expect(model.deliveryOptions.first.costCents, 1500);
      expect(model.deliveryOptions.first.estimatedDays, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // RATINGS
  // ---------------------------------------------------------------------------

  group('Ratings fromJson/toJson', () {
    test('roundtrip with all fields', () {
      final created = DateTime(2026, 3, 5, 12, 0);
      final json = {
        'productId': 'prod_1',
        'rating': 4.5,
        'review': 'Excellent!',
        'createdAt': created.toIso8601String(),
      };
      final model = Ratings.fromJson(json);
      expect(model.productId, 'prod_1');
      expect(model.rating, 4.5);
      expect(model.review, 'Excellent!');
      expect(model.createdAt, created);

      final out = model.toJson();
      expect(out['productId'], 'prod_1');
      expect(out['rating'], 4.5);
      expect(out['review'], 'Excellent!');
      expect(out['createdAt'], created.toIso8601String());
    });

    test('null review field', () {
      final json = {
        'productId': 'prod_2',
        'rating': 3.0,
        'review': null,
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      };
      final model = Ratings.fromJson(json);
      expect(model.review, isNull);

      final out = model.toJson();
      expect(out['review'], isNull);
    });

    test('boundary rating values', () {
      for (final r in [0.0, 1.0, 2.5, 5.0]) {
        final model = Ratings.fromJson({
          'productId': 'p',
          'rating': r,
          'createdAt': DateTime(2026).toIso8601String(),
        });
        expect(model.rating, r);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // SELLER PAYOUT
  // ---------------------------------------------------------------------------

  group('SellerPayout fromJson/toJson', () {
    test('roundtrip with all fields', () {
      final payDate = DateTime(2026, 3, 8);
      final json = _sellerPayoutJson(payoutDate: payDate);
      final model = SellerPayout.fromJson(json);

      expect(model.sellerId, 'seller_1');
      expect(model.stripeAccountId, 'acct_abc');
      expect(model.amountCents, 5000);
      expect(model.platformFeeCents, 250);
      expect(model.netAmountCents, 4750);
      expect(model.status, PayoutStatusValues.completed);
      expect(model.payoutDate, payDate);
      expect(model.stripeTransferId, 'tr_xyz');
      expect(model.failureReason, isNull);

      // Computed getters
      expect(model.amount, 50.0);
      expect(model.platformFee, 2.50);
      expect(model.netAmount, 47.50);

      final out = model.toJson();
      expect(out['sellerId'], 'seller_1');
      expect(out['amountCents'], 5000);
      expect(out['payoutDate'], payDate.toIso8601String());
    });

    test('defaults when optional fields omitted', () {
      final json = {
        'sellerId': 's2',
        'amountCents': 1000,
        'platformFeeCents': 50,
        'netAmountCents': 950,
      };
      final model = SellerPayout.fromJson(json);

      expect(model.status, PayoutStatusValues.pending);
      expect(model.payoutDate, isNull);
      expect(model.stripeAccountId, isNull);
      expect(model.stripeTransferId, isNull);
      expect(model.failureReason, isNull);
    });

    test('failed payout with failureReason', () {
      final json = {
        'sellerId': 's3',
        'amountCents': 2000,
        'platformFeeCents': 100,
        'netAmountCents': 1900,
        'status': PayoutStatusValues.failed,
        'failureReason': 'Stripe account disabled',
      };
      final model = SellerPayout.fromJson(json);
      expect(model.status, PayoutStatusValues.failed);
      expect(model.failureReason, 'Stripe account disabled');
    });
  });

  // ---------------------------------------------------------------------------
  // TAXES
  // ---------------------------------------------------------------------------

  group('Taxes fromJson/toJson', () {
    test('roundtrip', () {
      final json = {Fields.GST: 5.0, Fields.PST: 7.0, Fields.HST: 13.0, Fields.QST: 9.975};
      final model = Taxes.fromJson(json);
      expect(model.gst, 5.0);
      expect(model.pst, 7.0);
      expect(model.hst, 13.0);
      expect(model.qst, 9.975);
      expect(model.total, 5.0 + 7.0 + 13.0 + 9.975);

      final out = model.toJson();
      expect(out[Fields.GST], 5.0);
      expect(out[Fields.PST], 7.0);
    });

    test('defaults to zero', () {
      final model = Taxes.fromJson({});
      expect(model.gst, 0.0);
      expect(model.pst, 0.0);
      expect(model.hst, 0.0);
      expect(model.qst, 0.0);
      expect(model.total, 0.0);
    });

    test('fromMap identical to fromJson', () {
      final map = {Fields.GST: 1.0, Fields.PST: 2.0, Fields.HST: 3.0, Fields.QST: 4.0};
      final a = Taxes.fromJson(map);
      final b = Taxes.fromMap(map);
      expect(a, b);
    });

    test('toMap returns double values', () {
      final model = Taxes(gst: 1.0, pst: 2.0, hst: 3.0, qst: 4.0);
      final m = model.toMap();
      expect(m[Fields.GST], isA<double>());
      expect(m, hasLength(4));
    });
  });

  // ---------------------------------------------------------------------------
  // ORDER (full model)
  // ---------------------------------------------------------------------------

  group('Order fromJson/toJson', () {
    test('roundtrip with minimal fields', () {
      final created = DateTime(2026, 3, 1);
      final json = _minimalOrderJson(createdAt: created);
      final model = Order.fromJson(json);

      expect(model.orderId, 'ord_1');
      expect(model.userId, 'user_1');
      expect(model.items, hasLength(1));
      expect(model.totalAmountCents, 5100);
      expect(model.subtotalCents, 5100);
      expect(model.createdAt, created);

      // Defaults
      expect(model.version, 1);
      expect(model.schemaVersion, 1);
      expect(model.orderStatus, OrderStatus.pending);
      expect(model.paymentStatus, PaymentStatus.awaitingPayment);
      expect(model.shippingCostCents, 0);
      expect(model.taxAmountCents, 0);
      expect(model.currency, BusinessRules.defaultCurrency);
      expect(model.sellerIds, isEmpty);
      expect(model.productIds, isEmpty);
      expect(model.shippingApprovalStatus, ShippingApprovalStatus.notRequired);
      expect(model.shippingApprovalRequired, false);
      expect(model.actualShippingCents, 0);
      expect(model.pendingTotalCents, 0);
      expect(model.sellerPayouts, isEmpty);
      expect(model.confirmedByClient, false);
      expect(model.platformFeeTotalCents, 0);
      expect(model.payoutStatus, PayoutStatusValues.pending);
      expect(model.ratings, isEmpty);
      expect(model.captureAttempts, 0);
      expect(model.autoConfirmed, false);
      expect(model.autoCaptured, false);
      expect(model.refundAmountCents, 0);
      expect(model.stockRestored, false);
      expect(model.requiresManualReview, false);
      expect(model.payoutErrors, isEmpty);
      expect(model.itemTaxes, isEmpty);
      expect(model.taxExempt, false);
      expect(model.discountAmountCents, 0);
      expect(model.fraudScore, 0);

      // Computed getters
      expect(model.total, 51.0);
      expect(model.subtotal, 51.0);
      expect(model.shippingCost, 0.0);
      expect(model.taxAmount, 0.0);

      final out = model.toJson();
      expect(out['orderId'], 'ord_1');
      expect(out['totalAmountCents'], 5100);
    });

    test('roundtrip with all optional fields populated', () {
      final created = DateTime(2026, 3, 1);
      final confirmed = DateTime(2026, 3, 2);
      final captured = DateTime(2026, 3, 2, 1);
      final expires = DateTime(2026, 3, 8);
      final refunded = DateTime(2026, 3, 7);
      final cancelled = DateTime(2026, 3, 6);
      final responded = DateTime(2026, 3, 3);
      final updated = DateTime(2026, 3, 9);

      final json = {
        'orderId': 'ord_full',
        'userId': 'user_2',
        'version': 3,
        'schemaVersion': 2,
        'customerId': 'cus_stripe',
        'customerEmail': 'buyer@example.com',
        'items': [_fullOrderItemJson()],
        'totalAmountCents': 12000,
        'subtotalCents': 10000,
        'shippingCostCents': 1500,
        'taxAmountCents': 500,
        'taxes': {Fields.GST: 2.5, Fields.PST: 0.0, Fields.HST: 0.0, Fields.QST: 2.5},
        'orderStatus': 'delivered',
        'paymentStatus': 'captured',
        'shippingAddress': {
          'street': '789 Pine Rd',
          'apartment': 'Unit 12',
          'city': 'Vancouver',
          'state': 'BC',
          'postalCode': 'V6B 1A1',
          'country': 'Canada',
          'phoneNumber': '+14165551234',
          'isDefault': true,
          'label': 'Office',
          'latitude': 49.2827,
          'longitude': -123.1207,
        },
        'createdAt': created.toIso8601String(),
        'currency': 'CAD',
        'sellerIds': ['seller_1', 'seller_2'],
        'productIds': ['prod_1', 'prod_2'],
        'stripeSessionId': 'cs_live_abc',
        'shippingApprovalStatus': 'approved',
        'shippingApprovalRequired': true,
        'actualShippingCents': 1200,
        'pendingTotalCents': 0,
        'sellerPayouts': [_sellerPayoutJson(payoutDate: DateTime(2026, 3, 8))],
        'confirmedByClient': true,
        'confirmedAt': confirmed.toIso8601String(),
        'platformFeeTotalCents': 600,
        'payoutStatus': PayoutStatusValues.completed,
        'ratings': [_ratingsJson()],
        'stripePaymentIntentId': 'pi_xyz',
        'captureAttempts': 2,
        'capturedAt': captured.toIso8601String(),
        'expiresAt': expires.toIso8601String(),
        'autoConfirmed': true,
        'autoCaptured': true,
        'refundAmountCents': 3000,
        'refundedAt': refunded.toIso8601String(),
        'stockRestored': true,
        'cancelledBy': 'admin',
        'cancelledAt': cancelled.toIso8601String(),
        'cancellationReason': 'Fraud detected',
        'respondedAt': responded.toIso8601String(),
        'requiresManualReview': true,
        'manualReviewReason': 'High fraud score',
        'payoutErrors': ['transfer_failed', 'retry_limit'],
        'updatedAt': updated.toIso8601String(),
        'itemTaxes': [
          {'productId': 'prod_1', 'gst': 1.25}
        ],
        'taxExempt': true,
        'taxExemption': {'type': 'first_nations', 'certificateId': 'FN-123'},
        'deliveryInstructions': 'Ring doorbell twice',
        'couponCode': 'SAVE10',
        'discountAmountCents': 1000,
        'fraudScore': 75,
        'sellerCaptures': {'seller_1': 'captured'},
        'lastCaptureError': 'card_declined',
      };

      final model = Order.fromJson(json);

      expect(model.orderId, 'ord_full');
      expect(model.version, 3);
      expect(model.schemaVersion, 2);
      expect(model.customerId, 'cus_stripe');
      expect(model.customerEmail, 'buyer@example.com');
      expect(model.shippingCostCents, 1500);
      expect(model.taxAmountCents, 500);
      expect(model.orderStatus, OrderStatus.delivered);
      expect(model.paymentStatus, PaymentStatus.captured);
      expect(model.shippingAddress, isNotNull);
      expect(model.shippingAddress!.city, 'Vancouver');
      expect(model.shippingAddress!.phoneNumber, '+14165551234');
      expect(model.currency, 'CAD');
      expect(model.sellerIds, ['seller_1', 'seller_2']);
      expect(model.productIds, ['prod_1', 'prod_2']);
      expect(model.stripeSessionId, 'cs_live_abc');
      expect(model.shippingApprovalStatus, ShippingApprovalStatus.approved);
      expect(model.shippingApprovalRequired, true);
      expect(model.actualShippingCents, 1200);
      expect(model.sellerPayouts, hasLength(1));
      expect(model.confirmedByClient, true);
      expect(model.confirmedAt, confirmed);
      expect(model.platformFeeTotalCents, 600);
      expect(model.payoutStatus, PayoutStatusValues.completed);
      expect(model.ratings, hasLength(1));
      expect(model.ratings.first.rating, 4.5);
      expect(model.stripePaymentIntentId, 'pi_xyz');
      expect(model.captureAttempts, 2);
      expect(model.capturedAt, captured);
      expect(model.expiresAt, expires);
      expect(model.autoConfirmed, true);
      expect(model.autoCaptured, true);
      expect(model.refundAmountCents, 3000);
      expect(model.refundedAt, refunded);
      expect(model.stockRestored, true);
      expect(model.cancelledBy, 'admin');
      expect(model.cancelledAt, cancelled);
      expect(model.cancellationReason, 'Fraud detected');
      expect(model.respondedAt, responded);
      expect(model.requiresManualReview, true);
      expect(model.manualReviewReason, 'High fraud score');
      expect(model.payoutErrors, ['transfer_failed', 'retry_limit']);
      expect(model.updatedAt, updated);
      expect(model.itemTaxes, hasLength(1));
      expect(model.taxExempt, true);
      expect(model.taxExemption, isNotNull);
      expect(model.taxExemption!['type'], 'first_nations');
      expect(model.deliveryInstructions, 'Ring doorbell twice');
      expect(model.couponCode, 'SAVE10');
      expect(model.discountAmountCents, 1000);
      expect(model.fraudScore, 75);
      expect(model.sellerCaptures, {'seller_1': 'captured'});
      expect(model.lastCaptureError, 'card_declined');

      // Computed getters
      expect(model.total, 120.0);
      expect(model.subtotal, 100.0);
      expect(model.shippingCost, 15.0);
      expect(model.taxAmount, 5.0);
      expect(model.actualShipping, 12.0);
      expect(model.platformFeeTotal, 6.0);
      expect(model.refundAmount, 30.0);

      // toJson roundtrip check
      final out = model.toJson();
      expect(out['orderId'], 'ord_full');
      expect(out['version'], 3);
      expect(out['customerEmail'], 'buyer@example.com');
      expect(out['shippingCostCents'], 1500);
      expect(out['orderStatus'], 'delivered');
      expect(out['paymentStatus'], 'captured');
      expect(out['shippingApprovalStatus'], 'approved');
      expect(out['confirmedAt'], confirmed.toIso8601String());
      expect(out['capturedAt'], captured.toIso8601String());
      expect(out['expiresAt'], expires.toIso8601String());
      expect(out['refundedAt'], refunded.toIso8601String());
      expect(out['cancelledAt'], cancelled.toIso8601String());
      expect(out['respondedAt'], responded.toIso8601String());
      expect(out['updatedAt'], updated.toIso8601String());
      expect(out['payoutErrors'], hasLength(2));
      expect(out['couponCode'], 'SAVE10');
      expect(out['fraudScore'], 75);
      expect(out['lastCaptureError'], 'card_declined');
    });

    test('null optional DateTime fields serialize to null', () {
      final json = _minimalOrderJson();
      final out = Order.fromJson(json).toJson();

      expect(out['confirmedAt'], isNull);
      expect(out['capturedAt'], isNull);
      expect(out['expiresAt'], isNull);
      expect(out['refundedAt'], isNull);
      expect(out['cancelledAt'], isNull);
      expect(out['respondedAt'], isNull);
      expect(out['updatedAt'], isNull);
    });

    test('null optional string fields', () {
      final json = _minimalOrderJson();
      final out = Order.fromJson(json).toJson();

      expect(out['customerId'], isNull);
      expect(out['customerEmail'], isNull);
      expect(out['stripeSessionId'], isNull);
      expect(out['stripePaymentIntentId'], isNull);
      expect(out['cancelledBy'], isNull);
      expect(out['cancellationReason'], isNull);
      expect(out['manualReviewReason'], isNull);
      expect(out['deliveryInstructions'], isNull);
      expect(out['couponCode'], isNull);
      expect(out['lastCaptureError'], isNull);
      expect(out['taxExemption'], isNull);
      expect(out['sellerCaptures'], isNull);
    });

    test('empty lists serialize correctly', () {
      final json = _minimalOrderJson();
      final out = Order.fromJson(json).toJson();

      expect(out['sellerIds'], isEmpty);
      expect(out['productIds'], isEmpty);
      expect(out['sellerPayouts'], isEmpty);
      expect(out['ratings'], isEmpty);
      expect(out['payoutErrors'], isEmpty);
      expect(out['itemTaxes'], isEmpty);
    });

    test('multiple items with nested OrderItem', () {
      final json = {
        ..._minimalOrderJson(),
        'items': [
          _minimalOrderItemJson(),
          {
            ..._minimalOrderItemJson(),
            'productId': 'prod_2',
            'name': 'Gadget',
            'price': 99.99,
            'quantity': 1,
            'sellerId': 'seller_2',
          },
        ],
      };
      final model = Order.fromJson(json);
      expect(model.items, hasLength(2));
      expect(model.items[0].productId, 'prod_1');
      expect(model.items[1].productId, 'prod_2');
      expect(model.items[1].name, 'Gadget');
    });

    test('nested SellerPayout serialization', () {
      final payDate = DateTime(2026, 3, 10);
      final json = {
        ..._minimalOrderJson(),
        'sellerPayouts': [
          _sellerPayoutJson(payoutDate: payDate),
          {
            'sellerId': 'seller_2',
            'amountCents': 3000,
            'platformFeeCents': 150,
            'netAmountCents': 2850,
          },
        ],
      };
      final model = Order.fromJson(json);
      expect(model.sellerPayouts, hasLength(2));
      expect(model.sellerPayouts[0].stripeAccountId, 'acct_abc');
      expect(model.sellerPayouts[0].payoutDate, payDate);
      expect(model.sellerPayouts[1].status, PayoutStatusValues.pending);
      expect(model.sellerPayouts[1].payoutDate, isNull);
    });

    test('nested Ratings serialization', () {
      final json = {
        ..._minimalOrderJson(),
        'ratings': [
          _ratingsJson(),
          {
            'productId': 'prod_2',
            'rating': 2.0,
            'createdAt': DateTime(2026, 3, 6).toIso8601String(),
          },
        ],
      };
      final model = Order.fromJson(json);
      expect(model.ratings, hasLength(2));
      expect(model.ratings[0].review, 'Great product!');
      expect(model.ratings[1].review, isNull);
      expect(model.ratings[1].rating, 2.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ORDER STATUS ENUM SERIALIZATION
  // ---------------------------------------------------------------------------

  group('OrderStatus enum serialization', () {
    final statusMap = {
      OrderStatus.pending: 'pending',
      OrderStatus.confirmed: 'confirmed',
      OrderStatus.processing: 'processing',
      OrderStatus.shipped: 'shipped',
      OrderStatus.inTransit: 'in_transit',
      OrderStatus.delivered: 'delivered',
      OrderStatus.cancelled: 'cancelled',
      OrderStatus.failed: 'failed',
      OrderStatus.expired: 'expired',
      OrderStatus.disputed: 'disputed',
      OrderStatus.refunded: 'refunded',
      OrderStatus.partiallyRefunded: 'partially_refunded',
    };

    for (final entry in statusMap.entries) {
      test('${entry.key} serializes to "${entry.value}"', () {
        final json = {
          ..._minimalOrderJson(),
          'orderStatus': entry.value,
        };
        final model = Order.fromJson(json);
        expect(model.orderStatus, entry.key);

        final out = model.toJson();
        expect(out['orderStatus'], entry.value);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // PAYMENT STATUS ENUM SERIALIZATION
  // ---------------------------------------------------------------------------

  group('PaymentStatus enum serialization', () {
    final statusMap = {
      PaymentStatus.awaitingPayment: 'awaiting_payment',
      PaymentStatus.processing: 'processing',
      PaymentStatus.paid: 'paid',
      PaymentStatus.authorized: 'authorized',
      PaymentStatus.captured: 'captured',
      PaymentStatus.paymentFailed: 'payment_failed',
      PaymentStatus.refunded: 'refunded',
      PaymentStatus.sessionExpired: 'session_expired',
      PaymentStatus.cancelled: 'cancelled',
      PaymentStatus.authorizationExpired: 'authorization_expired',
      PaymentStatus.disputed: 'disputed',
      PaymentStatus.capturing: 'capturing',
      PaymentStatus.cancelling: 'cancelling',
      PaymentStatus.expiring: 'expiring',
      PaymentStatus.partiallyRefunded: 'partially_refunded',
      PaymentStatus.voided: 'voided',
      PaymentStatus.cancelFailed: 'cancel_failed',
    };

    for (final entry in statusMap.entries) {
      test('${entry.key} serializes to "${entry.value}"', () {
        final json = {
          ..._minimalOrderJson(),
          'paymentStatus': entry.value,
        };
        final model = Order.fromJson(json);
        expect(model.paymentStatus, entry.key);

        final out = model.toJson();
        expect(out['paymentStatus'], entry.value);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // SHIPPING APPROVAL STATUS ENUM SERIALIZATION
  // ---------------------------------------------------------------------------

  group('ShippingApprovalStatus enum serialization', () {
    final statusMap = {
      ShippingApprovalStatus.notRequired: 'not_required',
      ShippingApprovalStatus.pending: 'pending',
      ShippingApprovalStatus.approved: 'approved',
      ShippingApprovalStatus.rejected: 'rejected',
    };

    for (final entry in statusMap.entries) {
      test('${entry.key} serializes to "${entry.value}"', () {
        final json = {
          ..._minimalOrderJson(),
          'shippingApprovalStatus': entry.value,
        };
        final model = Order.fromJson(json);
        expect(model.shippingApprovalStatus, entry.key);

        final out = model.toJson();
        expect(out['shippingApprovalStatus'], entry.value);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // ORDER CREATE
  // ---------------------------------------------------------------------------

  group('OrderCreate fromJson/toJson', () {
    test('roundtrip with all fields', () {
      final json = {
        'userId': 'user_1',
        'customerId': 'cus_1',
        'customerEmail': 'test@example.com',
        'items': [_minimalOrderItemJson()],
        'shippingAddress': {
          'street': '100 Queen St W',
          'apartment': '',
          'city': 'Toronto',
          'state': 'ON',
          'postalCode': 'M5H 2N2',
          'country': 'Canada',
          'isDefault': false,
        },
        'shippingCost': 12.99,
        'currency': 'CAD',
        'shippingApprovalRequired': true,
      };

      final model = OrderCreate.fromJson(json);
      expect(model.userId, 'user_1');
      expect(model.customerId, 'cus_1');
      expect(model.customerEmail, 'test@example.com');
      expect(model.items, hasLength(1));
      expect(model.shippingAddress.street, '100 Queen St W');
      expect(model.shippingCost, 12.99);
      expect(model.currency, 'CAD');
      expect(model.shippingApprovalRequired, true);

      final out = model.toJson();
      expect(out['userId'], 'user_1');
      expect(out['shippingCost'], 12.99);
      expect(out['shippingApprovalRequired'], true);
    });

    test('defaults when optional fields omitted', () {
      final json = {
        'userId': 'u1',
        'customerId': 'c1',
        'customerEmail': 'e@e.com',
        'items': [_minimalOrderItemJson()],
        'shippingAddress': {
          'street': '1 St',
          'city': 'T',
          'state': 'ON',
          'postalCode': 'A1A',
          'country': 'Canada',
        },
      };
      final model = OrderCreate.fromJson(json);
      expect(model.shippingCost, 0.0);
      expect(model.currency, BusinessRules.defaultCurrency);
      expect(model.shippingApprovalRequired, false);
    });
  });

  // ---------------------------------------------------------------------------
  // EDGE CASES
  // ---------------------------------------------------------------------------

  group('Edge cases', () {
    test('Order with zero-cent amounts', () {
      final json = {
        ..._minimalOrderJson(),
        'totalAmountCents': 0,
        'subtotalCents': 0,
      };
      final model = Order.fromJson(json);
      expect(model.total, 0.0);
      expect(model.subtotal, 0.0);
    });

    test('Order with large cent amounts', () {
      final json = {
        ..._minimalOrderJson(),
        'totalAmountCents': 99999999,
        'subtotalCents': 99999999,
      };
      final model = Order.fromJson(json);
      expect(model.total, 999999.99);
    });

    test('OrderItem with zero quantity', () {
      final json = {
        ..._minimalOrderItemJson(),
        'quantity': 0,
      };
      final model = OrderItem.fromJson(json);
      expect(model.quantity, 0);
      expect(model.subtotal, 0.0);
    });

    test('OrderItem with zero price', () {
      final json = {
        ..._minimalOrderItemJson(),
        'price': 0.0,
      };
      final model = OrderItem.fromJson(json);
      expect(model.price, 0.0);
      expect(model.subtotal, 0.0);
    });

    test('Order toJson then fromJson produces equivalent model', () {
      final created = DateTime(2026, 3, 1);
      final json = _minimalOrderJson(createdAt: created);
      final model1 = Order.fromJson(json);
      // Encode to JSON string and decode back to get plain maps
      final roundtripped = jsonDecode(jsonEncode(model1.toJson())) as Map<String, dynamic>;
      final model2 = Order.fromJson(roundtripped);

      expect(model2.orderId, model1.orderId);
      expect(model2.userId, model1.userId);
      expect(model2.totalAmountCents, model1.totalAmountCents);
      expect(model2.items.length, model1.items.length);
      expect(model2.createdAt, model1.createdAt);
      expect(model2.orderStatus, model1.orderStatus);
      expect(model2.paymentStatus, model1.paymentStatus);
    });

    test('OrderItem toJson then fromJson produces equivalent model', () {
      final json = _fullOrderItemJson();
      final model1 = OrderItem.fromJson(json);
      // Encode to JSON string and decode back to get plain maps
      final roundtripped = jsonDecode(jsonEncode(model1.toJson())) as Map<String, dynamic>;
      final model2 = OrderItem.fromJson(roundtripped);

      expect(model2.productId, model1.productId);
      expect(model2.cartItemId, model1.cartItemId);
      expect(model2.price, model1.price);
      expect(model2.quantity, model1.quantity);
      expect(model2.status, model1.status);
      expect(model2.variantOptions, model1.variantOptions);
      expect(model2.buyerNote, model1.buyerNote);
      expect(model2.fulfillmentWarehouseId, model1.fulfillmentWarehouseId);
    });

    test('SellerPayout toJson then fromJson produces equivalent model', () {
      final payDate = DateTime(2026, 3, 10);
      final json = _sellerPayoutJson(payoutDate: payDate);
      final model1 = SellerPayout.fromJson(json);
      final model2 = SellerPayout.fromJson(model1.toJson());

      expect(model2.sellerId, model1.sellerId);
      expect(model2.amountCents, model1.amountCents);
      expect(model2.status, model1.status);
      expect(model2.payoutDate, model1.payoutDate);
    });

    test('Ratings toJson then fromJson produces equivalent model', () {
      final json = _ratingsJson();
      final model1 = Ratings.fromJson(json);
      final model2 = Ratings.fromJson(model1.toJson());

      expect(model2.productId, model1.productId);
      expect(model2.rating, model1.rating);
      expect(model2.review, model1.review);
      expect(model2.createdAt, model1.createdAt);
    });

    test('Order with shippingAddress null', () {
      final json = {
        ..._minimalOrderJson(),
        'shippingAddress': null,
      };
      final model = Order.fromJson(json);
      expect(model.shippingAddress, isNull);

      final out = model.toJson();
      expect(out['shippingAddress'], isNull);
    });

    test('Order itemTaxes with complex maps', () {
      final json = {
        ..._minimalOrderJson(),
        'itemTaxes': [
          {'productId': 'p1', 'gst': 1.25, 'pst': 0.0},
          {'productId': 'p2', 'hst': 3.50},
        ],
      };
      final model = Order.fromJson(json);
      expect(model.itemTaxes, hasLength(2));
      expect(model.itemTaxes[0]['productId'], 'p1');
      expect(model.itemTaxes[1]['hst'], 3.50);
    });
  });
}
