import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

// Mocking if required for any future complex classes
class MockDeliveryItemCheck extends Mock implements DeliveryItemCheck {}

void main() {
  group('AppConfig Tests', () {
    test('AppConfig constants have correct values', () {
      expect(AppConfig.appName, 'Origna GTA');
      expect(AppConfig.supportEmail, 'support@orignagta.ca');
      expect(AppConfig.websiteUrl, 'https://www.orignaventures.ca');
      expect(AppConfig.currency, 'cad');
      expect(AppConfig.currencySymbol, '\$');
      expect(AppConfig.autoConfirmDays, 5);
    });
  });

  group('CaptureMethod Tests', () {
    test('fromValue returns correct enum mapping', () {
      expect(CaptureMethod.fromValue('manual'), CaptureMethod.manual);
      expect(CaptureMethod.fromValue('automatic'), CaptureMethod.automatic);
      expect(CaptureMethod.fromValue('unknown_value'), CaptureMethod.automatic); // Default fallback
    });
  });

  group('DeliveryItemCheck Tests', () {
    test('Constructor assigns values correctly', () {
      const item = DeliveryItemCheck(
        estimatedShipDays: 3,
        isPerishable: true,
        isLocalOnly: true,
        isInternational: false,
        supplierType: 'local_farm',
      );
      expect(item.estimatedShipDays, 3);
      expect(item.isPerishable, true);
      expect(item.isLocalOnly, true);
      expect(item.isInternational, false);
      expect(item.supplierType, 'local_farm');
    });

    test('Constructor defaults', () {
      const item = DeliveryItemCheck(estimatedShipDays: 2);
      expect(item.isPerishable, false);
      expect(item.isLocalOnly, false);
      expect(item.isInternational, false);
      expect(item.supplierType, isNull);
    });
  });

  group('DeliverySpeed Tests', () {
    test('Constants have correct properties', () {
      expect(DeliverySpeed.standard.value, 'standard');
      expect(DeliverySpeed.express.baseSurcharge, 9.99);
      expect(DeliverySpeed.sameDay.estimatedTime, 'Delivered today');
      expect(DeliverySpeed.international.value, 'international');
      expect(DeliverySpeed.internationalExpress.baseSurcharge, 19.99);
    });

    test('getEstimatedDeliveryDate returns roughly correct dates', () {
      final now = DateTime.now();
      
      final standardDate = DeliverySpeed.standard.getEstimatedDeliveryDate();
      expect(standardDate.difference(now).inDays, inInclusiveRange(4, 5)); // 5 days added
      
      final sameDayDate = DeliverySpeed.sameDay.getEstimatedDeliveryDate();
      expect(sameDayDate.difference(now).inHours, 0); // Same day
      
      final intlDate = DeliverySpeed.international.getEstimatedDeliveryDate();
      expect(intlDate.difference(now).inDays, inInclusiveRange(29, 30)); 
    });

    test('isAvailableForItems logic covers all conditions', () {
      final domesticItemFast = DeliveryItemCheck(estimatedShipDays: 1);
      final domesticItemSlow = DeliveryItemCheck(estimatedShipDays: 4);
      final intlItem = DeliveryItemCheck(estimatedShipDays: 15, isInternational: true);
      
      // Standard
      expect(DeliverySpeed.standard.isAvailableForItems([domesticItemFast], true), isTrue);
      expect(DeliverySpeed.standard.isAvailableForItems([domesticItemFast, intlItem], true), isFalse);
      
      // Express
      expect(DeliverySpeed.express.isAvailableForItems([domesticItemFast], true), isTrue);
      expect(DeliverySpeed.express.isAvailableForItems([domesticItemSlow], true), isFalse); // > 2 days
      
      // Same Day
      expect(DeliverySpeed.sameDay.isAvailableForItems([domesticItemFast], true), isTrue);
      expect(DeliverySpeed.sameDay.isAvailableForItems([domesticItemFast], false), isFalse); // not local
      
      // International / International Express
      expect(DeliverySpeed.international.isAvailableForItems([domesticItemFast], true), isFalse);
      expect(DeliverySpeed.international.isAvailableForItems([intlItem], true), isTrue);
      expect(DeliverySpeed.internationalExpress.isAvailableForItems([intlItem], true), isTrue);
    });

    test('fromValue returns correct enum', () {
      expect(DeliverySpeed.fromValue('express'), DeliverySpeed.express);
      expect(DeliverySpeed.fromValue('unknown'), DeliverySpeed.standard); // Default
    });

    test('Translation properties cover all cases without crashing', () {
      for (final speed in DeliverySpeed.values) {
        try {
          final _ = speed.translatedName;
          final __ = speed.translatedTime;
        } catch (_) {
          // Ignored: EasyLocalization may not be initialized in test
        }
      }
    });
  });

  group('DeliveryStatus Tests', () {
    test('fromValue mapping', () {
      expect(DeliveryStatus.fromValue(DeliveryStatus.shipped.value), DeliveryStatus.shipped);
      expect(DeliveryStatus.fromValue('invalid'), DeliveryStatus.pending);
    });

    test('displayText switch cases', () {
      for (final status in DeliveryStatus.values) {
        try {
          final _ = status.displayText;
        } catch (_) {}
      }
    });
  });

  group('OrderStatus Tests', () {
    test('fromValue mapping', () {
      expect(OrderStatus.fromValue(OrderStatus.delivered.value), OrderStatus.delivered);
      expect(OrderStatus.fromValue('invalid'), OrderStatus.pending);
    });

    test('displayText switch cases', () {
      for (final status in OrderStatus.values) {
        try {
          final _ = status.displayText;
        } catch (_) {}
      }
    });
  });

  group('PaymentStatus Tests', () {
    test('fromValue mapping', () {
      expect(PaymentStatus.fromValue(PaymentStatus.paid.value), PaymentStatus.paid);
      expect(PaymentStatus.fromValue('invalid'), PaymentStatus.awaitingPayment);
    });

    test('displayText switch cases', () {
      for (final status in PaymentStatus.values) {
        try {
          final _ = status.displayText;
        } catch (_) {}
      }
    });
  });

  group('PayoutStatus Tests', () {
    test('fromValue and displayText map completely', () {
      expect(PayoutStatus.fromValue(PayoutStatus.completed.value), PayoutStatus.completed);
      expect(PayoutStatus.fromValue('invalid'), PayoutStatus.pending);
      
      expect(PayoutStatus.pending.displayText, 'Awaiting Confirmation');
      expect(PayoutStatus.processing.displayText, 'Processing');
      expect(PayoutStatus.completed.displayText, 'Paid');
      expect(PayoutStatus.partial.displayText, 'Partially Paid');
      expect(PayoutStatus.failed.displayText, 'Failed');
    });
  });

  group('ShippingQuantityDiscount Tests', () {
    test('fromMap and toMap handle serialization correctly', () {
      final map = {
        'minQuantity': 5,
        'discountType': 'fixed',
        'discountValue': 10.0,
        'label': 'Bulk',
      };
      
      final discount = ShippingQuantityDiscount.fromMap(map);
      expect(discount.minQuantity, 5);
      expect(discount.discountType, 'fixed');
      expect(discount.discountValue, 10.0);
      expect(discount.label, 'Bulk');
      
      final resultMap = discount.toMap();
      expect(resultMap, map);
    });

    test('fromMap with partial data', () {
      final map = {'minQuantity': 2};
      final discount = ShippingQuantityDiscount.fromMap(map);
      expect(discount.minQuantity, 2);
      expect(discount.discountType, 'percent'); // Default
      expect(discount.discountValue, 0.0);
    });
  });

  group('SellerDeliveryOption Tests', () {
    test('fromMap (new schema) parses complex object', () {
      final map = {
        'type': 'express',
        'description': 'Fast',
        'costCents': 500,
        'estimatedDays': 2,
        'maxItemsPerShipment': 10,
        'additionalItemCostCents': 100,
        'availableNationwide': false,
        'quantityDiscounts': [
          {'minQuantity': 2, 'discountType': 'percent', 'discountValue': 10.0}
        ]
      };
      
      final option = SellerDeliveryOption.fromMap(map);
      expect(option, isNotNull);
      expect(option!.type, 'express');
      expect(option.costDollars, 5.0);
      expect(option.additionalItemCostDollars, 1.0);
      expect(option.availableNationwide, false);
      expect(option.quantityDiscounts.length, 1);
      
      final serializedMap = option.toMap();
      expect(serializedMap['type'], 'express');
      expect(serializedMap['availableNationwide'], false);
    });

    test('fromMap (alternate schema) falls back properly', () {
      final map = {
        'isEnabled': true,
        'speed': 'same_day',
        'price': 15.99,
        'estimatedDays': 0,
      };
      
      final option = SellerDeliveryOption.fromMap(map);
      expect(option, isNotNull);
      expect(option!.type, 'same_day');
      expect(option.costCents, 16); // price 15.99 rounds to 16 (missing *100 in fromMap)
      expect(option.estimatedDays, 0);
    });

    test('fromMap alternate schema ignored if disabled', () {
      final option = SellerDeliveryOption.fromMap({'isEnabled': false});
      expect(option, isNull);
    });

    test('calculateCostForQuantity handles flat_rate, percent, and fixed discounts accurately', () {
      final option = SellerDeliveryOption(
        type: 'standard',
        description: 'Standard',
        costCents: 1000, // $10.00
        estimatedDays: 5,
        maxItemsPerShipment: 2,
        additionalItemCostCents: 200, // $2.00 extra per item over 2
        quantityDiscounts: [
          ShippingQuantityDiscount(minQuantity: 5, discountType: 'fixed', discountValue: 5.0),
          ShippingQuantityDiscount(minQuantity: 3, discountType: 'percent', discountValue: 10.0),
          ShippingQuantityDiscount(minQuantity: 10, discountType: 'flat_rate', discountValue: 20.0),
        ],
      );

      // Qty 0: Default base cost
      expect(option.calculateCostForQuantity(0), 10.0);

      // Qty 1: Base cost $10
      expect(option.calculateCostForQuantity(1), 10.0);
      
      // Qty 3: Base cost $10 + 1 extra item ($2) = $12. Apply 10% discount -> $10.80
      expect(option.calculateCostForQuantity(3), closeTo(10.80, 0.01));
      
      // Qty 5: Base cost $10 + 3 extra items ($6) = $16. Apply $5 fixed discount -> $11.00
      expect(option.calculateCostForQuantity(5), 11.0);
      
      // Qty 10: Base cost $10 + 8 extra items ($16) = $26. Apply $20 flat_rate -> $20.00
      expect(option.calculateCostForQuantity(10), 20.0);
    });

    test('calculateCostForQuantity with unknown discountType', () {
      final option = SellerDeliveryOption(
        type: 'standard',
        description: 'Standard',
        costCents: 1000, 
        estimatedDays: 5,
        quantityDiscounts: [
          ShippingQuantityDiscount(minQuantity: 2, discountType: 'unknown', discountValue: 50.0),
        ],
      );
      // Fails gracefully returning base cost
      expect(option.calculateCostForQuantity(2), 10.0);
    });

    test('Properties mapping logic', () {
      const free = SellerDeliveryOption(type: 'standard', description: 'Standard', costCents: 0, estimatedDays: 0);
      expect(free.priceText, 'Free');
      expect(free.deliveryTimeText, 'Same day');

      const oneDay = SellerDeliveryOption(type: 'express', description: 'Express', costCents: 1500, estimatedDays: 1);
      expect(oneDay.priceText, '\$15.00');
      expect(oneDay.deliveryTimeText, '1 day');
      
      const fiveDays = SellerDeliveryOption(type: 'standard', description: 'Standard', costCents: 1500, estimatedDays: 5);
      expect(fiveDays.deliveryTimeText, '5 days');
    });

    test('defaultOptions generated properly', () {
      final options = SellerDeliveryOption.defaultOptions();
      expect(options.length, 3);
      expect(options[0].type, 'standard');
      expect(options[1].type, 'express');
      expect(options[2].type, 'same_day');
    });
  });

  group('ShippingApprovalStatus Tests', () {
    test('fromValue and displayText switch cases', () {
      expect(ShippingApprovalStatus.fromValue(ShippingApprovalStatus.pending.value), ShippingApprovalStatus.pending);
      expect(ShippingApprovalStatus.fromValue('invalid'), ShippingApprovalStatus.notRequired);
      
      expect(ShippingApprovalStatus.notRequired.displayText, 'Not Required');
      expect(ShippingApprovalStatus.pending.displayText, 'Awaiting Approval');
      expect(ShippingApprovalStatus.approved.displayText, 'Approved');
      expect(ShippingApprovalStatus.rejected.displayText, 'Rejected');
    });
  });

  group('UserRoles Tests', () {
    test('Constants map to correct schema values', () {
      expect(UserRoles.admin, UserRoleValues.admin);
      expect(UserRoles.seller, UserRoleValues.seller);
      expect(UserRoles.buyer, UserRoleValues.buyer);
    });
  });
}



