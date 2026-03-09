import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/utils/constants.dart';

import '../test_utils.dart';

void main() {
  setUp(() => initTestMocks());

  group('AppConfig', () {
    test('has expected values', () {
      expect(AppConfig.appName, 'Origna GTA');
      expect(AppConfig.supportEmail, contains('@orignagta.ca'));
      expect(AppConfig.currency, 'cad');
      expect(AppConfig.currencySymbol, '\$');
      expect(AppConfig.autoConfirmDays, 5);
    });
  });

  group('CaptureMethod', () {
    test('fromValue returns correct enum', () {
      expect(CaptureMethod.fromValue('manual'), CaptureMethod.manual);
      expect(CaptureMethod.fromValue('automatic'), CaptureMethod.automatic);
      expect(CaptureMethod.fromValue('invalid'), CaptureMethod.automatic);
    });

    test('values have correct string representation', () {
      expect(CaptureMethod.manual.value, 'manual');
      expect(CaptureMethod.automatic.value, 'automatic');
    });
  });

  group('DeliverySpeed', () {
    test('fromValue returns correct enum', () {
      expect(DeliverySpeed.fromValue('standard'), DeliverySpeed.standard);
      expect(DeliverySpeed.fromValue('express'), DeliverySpeed.express);
      expect(DeliverySpeed.fromValue('same_day'), DeliverySpeed.sameDay);
      expect(DeliverySpeed.fromValue('international'), DeliverySpeed.international);
      expect(DeliverySpeed.fromValue('international_express'), DeliverySpeed.internationalExpress);
      expect(DeliverySpeed.fromValue('nonexistent'), DeliverySpeed.standard);
    });

    test('getEstimatedDeliveryDate returns future dates', () {
      final now = DateTime.now();
      for (final speed in DeliverySpeed.values) {
        final date = speed.getEstimatedDeliveryDate();
        expect(date.isAfter(now.subtract(const Duration(days: 1))), isTrue,
            reason: '${speed.name} should return a future or current date');
      }
    });

    test('sameDay returns today', () {
      final today = DateTime.now();
      final date = DeliverySpeed.sameDay.getEstimatedDeliveryDate();
      expect(date.day, today.day);
    });

    test('standard has 0.0 surcharge', () {
      expect(DeliverySpeed.standard.baseSurcharge, 0.0);
    });

    test('express has 9.99 surcharge', () {
      expect(DeliverySpeed.express.baseSurcharge, 9.99);
    });

    test('isAvailableForItems standard domestic', () {
      final items = [const DeliveryItemCheck(estimatedShipDays: 3)];
      expect(DeliverySpeed.standard.isAvailableForItems(items, false), isTrue);
    });

    test('isAvailableForItems standard blocked by international', () {
      final items = [const DeliveryItemCheck(estimatedShipDays: 3, isInternational: true)];
      expect(DeliverySpeed.standard.isAvailableForItems(items, false), isFalse);
    });

    test('isAvailableForItems express available for fast items', () {
      final items = [const DeliveryItemCheck(estimatedShipDays: 2)];
      expect(DeliverySpeed.express.isAvailableForItems(items, false), isTrue);
    });

    test('isAvailableForItems express not available for slow items', () {
      final items = [const DeliveryItemCheck(estimatedShipDays: 5)];
      expect(DeliverySpeed.express.isAvailableForItems(items, false), isFalse);
    });

    test('isAvailableForItems sameDay requires local delivery', () {
      final items = [const DeliveryItemCheck(estimatedShipDays: 1)];
      expect(DeliverySpeed.sameDay.isAvailableForItems(items, false), isFalse);
      expect(DeliverySpeed.sameDay.isAvailableForItems(items, true), isTrue);
    });

    test('isAvailableForItems sameDay perishable items ok', () {
      final items = [const DeliveryItemCheck(estimatedShipDays: 3, isPerishable: true)];
      expect(DeliverySpeed.sameDay.isAvailableForItems(items, true), isTrue);
    });

    test('isAvailableForItems international needs international items', () {
      final domestic = [const DeliveryItemCheck(estimatedShipDays: 3)];
      final intl = [const DeliveryItemCheck(estimatedShipDays: 20, isInternational: true)];
      expect(DeliverySpeed.international.isAvailableForItems(domestic, false), isFalse);
      expect(DeliverySpeed.international.isAvailableForItems(intl, false), isTrue);
    });

    test('isAvailableForItems internationalExpress needs international items', () {
      final intl = [const DeliveryItemCheck(estimatedShipDays: 10, isInternational: true)];
      expect(DeliverySpeed.internationalExpress.isAvailableForItems(intl, false), isTrue);
    });
  });

  group('DeliveryStatus', () {
    test('fromValue returns correct enum', () {
      expect(DeliveryStatus.fromValue('pending'), DeliveryStatus.pending);
      expect(DeliveryStatus.fromValue('shipped'), DeliveryStatus.shipped);
      expect(DeliveryStatus.fromValue('delivered'), DeliveryStatus.delivered);
      expect(DeliveryStatus.fromValue('refunded'), DeliveryStatus.refunded);
      expect(DeliveryStatus.fromValue('unknown'), DeliveryStatus.pending);
    });

    test('displayText returns non-empty string', () {
      for (final status in DeliveryStatus.values) {
        expect(status.displayText, isNotEmpty, reason: '${status.name} should have displayText');
      }
    });
  });

  group('OrderStatus', () {
    test('fromValue returns correct enum', () {
      expect(OrderStatus.fromValue('pending'), OrderStatus.pending);
      expect(OrderStatus.fromValue('confirmed'), OrderStatus.confirmed);
      expect(OrderStatus.fromValue('processing'), OrderStatus.processing);
      expect(OrderStatus.fromValue('shipped'), OrderStatus.shipped);
      expect(OrderStatus.fromValue('in_transit'), OrderStatus.inTransit);
      expect(OrderStatus.fromValue('delivered'), OrderStatus.delivered);
      expect(OrderStatus.fromValue('cancelled'), OrderStatus.cancelled);
      expect(OrderStatus.fromValue('failed'), OrderStatus.failed);
      expect(OrderStatus.fromValue('expired'), OrderStatus.expired);
      expect(OrderStatus.fromValue('disputed'), OrderStatus.disputed);
      expect(OrderStatus.fromValue('unknown'), OrderStatus.pending);
    });

    test('displayText returns non-empty string', () {
      for (final status in OrderStatus.values) {
        expect(status.displayText, isNotEmpty, reason: '${status.name} should have displayText');
      }
    });
  });

  group('PaymentStatus', () {
    test('fromValue returns correct enum', () {
      expect(PaymentStatus.fromValue('awaiting_payment'), PaymentStatus.awaitingPayment);
      expect(PaymentStatus.fromValue('authorized'), PaymentStatus.authorized);
      expect(PaymentStatus.fromValue('paid'), PaymentStatus.paid);
      expect(PaymentStatus.fromValue('captured'), PaymentStatus.captured);
      expect(PaymentStatus.fromValue('refunded'), PaymentStatus.refunded);
      expect(PaymentStatus.fromValue('cancelled'), PaymentStatus.cancelled);
      expect(PaymentStatus.fromValue('disputed'), PaymentStatus.disputed);
      expect(PaymentStatus.fromValue('unknown'), PaymentStatus.awaitingPayment);
    });

    test('displayText returns non-empty string', () {
      for (final status in PaymentStatus.values) {
        expect(status.displayText, isNotEmpty, reason: '${status.name} should have displayText');
      }
    });
  });

  group('PayoutStatus', () {
    test('fromValue returns correct enum', () {
      expect(PayoutStatus.fromValue('pending'), PayoutStatus.pending);
      expect(PayoutStatus.fromValue('processing'), PayoutStatus.processing);
      expect(PayoutStatus.fromValue('completed'), PayoutStatus.completed);
      expect(PayoutStatus.fromValue('partial'), PayoutStatus.partial);
      expect(PayoutStatus.fromValue('failed'), PayoutStatus.failed);
      expect(PayoutStatus.fromValue('unknown'), PayoutStatus.pending);
    });

    test('displayText returns non-empty string', () {
      for (final status in PayoutStatus.values) {
        expect(status.displayText, isNotEmpty, reason: '${status.name} should have displayText');
      }
    });
  });

  group('ShippingApprovalStatus', () {
    test('fromValue returns correct enum', () {
      expect(ShippingApprovalStatus.fromValue('not_required'), ShippingApprovalStatus.notRequired);
      expect(ShippingApprovalStatus.fromValue('pending'), ShippingApprovalStatus.pending);
      expect(ShippingApprovalStatus.fromValue('approved'), ShippingApprovalStatus.approved);
      expect(ShippingApprovalStatus.fromValue('rejected'), ShippingApprovalStatus.rejected);
      expect(ShippingApprovalStatus.fromValue('unknown'), ShippingApprovalStatus.notRequired);
    });

    test('displayText returns non-empty string', () {
      for (final status in ShippingApprovalStatus.values) {
        expect(status.displayText, isNotEmpty, reason: '${status.name} should have displayText');
      }
    });
  });

  group('ShippingQuantityDiscount', () {
    test('fromMap creates correct object', () {
      final discount = ShippingQuantityDiscount.fromMap({
        'minQuantity': 5,
        'discountType': 'percent',
        'discountValue': 10.0,
        'label': 'Bulk discount',
      });
      expect(discount.minQuantity, 5);
      expect(discount.discountType, 'percent');
      expect(discount.discountValue, 10.0);
      expect(discount.label, 'Bulk discount');
    });

    test('fromMap with defaults', () {
      final discount = ShippingQuantityDiscount.fromMap({});
      expect(discount.minQuantity, 0);
      expect(discount.discountType, 'percent');
      expect(discount.discountValue, 0.0);
      expect(discount.label, isNull);
    });

    test('toMap serializes correctly', () {
      const discount = ShippingQuantityDiscount(
        minQuantity: 3,
        discountType: 'fixed',
        discountValue: 2.5,
        label: 'Save \$2.50',
      );
      final map = discount.toMap();
      expect(map['minQuantity'], 3);
      expect(map['discountType'], 'fixed');
      expect(map['discountValue'], 2.5);
      expect(map['label'], 'Save \$2.50');
    });

    test('toMap omits null label', () {
      const discount = ShippingQuantityDiscount(minQuantity: 1, discountValue: 5.0);
      final map = discount.toMap();
      expect(map.containsKey('label'), isFalse);
    });
  });

  group('SellerDeliveryOption', () {
    test('fromMap with new schema', () {
      final option = SellerDeliveryOption.fromMap({
        'type': 'express',
        'description': 'Fast shipping',
        'costCents': 999,
        'estimatedDays': 2,
        'maxItemsPerShipment': 5,
        'additionalItemCostCents': 200,
        'availableNationwide': false,
      });
      expect(option, isNotNull);
      expect(option!.type, 'express');
      expect(option.costCents, 999);
      expect(option.estimatedDays, 2);
      expect(option.maxItemsPerShipment, 5);
      expect(option.additionalItemCostCents, 200);
      expect(option.availableNationwide, isFalse);
    });

    test('fromMap with quantity discounts', () {
      final option = SellerDeliveryOption.fromMap({
        'type': 'standard',
        'costCents': 500,
        'quantityDiscounts': [
          {'minQuantity': 3, 'discountType': 'percent', 'discountValue': 10.0},
        ],
      });
      expect(option, isNotNull);
      expect(option!.quantityDiscounts.length, 1);
      expect(option.quantityDiscounts.first.minQuantity, 3);
    });

    test('fromMap with alternate schema enabled', () {
      final option = SellerDeliveryOption.fromMap({
        'speed': 'express',
        'isEnabled': true,
        'estimatedDays': 2,
        'price': 9.99,
      });
      expect(option, isNotNull);
      expect(option!.type, 'express');
    });

    test('fromMap with alternate schema disabled returns null', () {
      final option = SellerDeliveryOption.fromMap({
        'speed': 'express',
        'isEnabled': false,
      });
      expect(option, isNull);
    });

    test('deliveryTimeText', () {
      const sameDay = SellerDeliveryOption(type: 'same_day', description: '', costCents: 0, estimatedDays: 0);
      expect(sameDay.deliveryTimeText, 'Same day');

      const oneDay = SellerDeliveryOption(type: 'express', description: '', costCents: 0, estimatedDays: 1);
      expect(oneDay.deliveryTimeText, '1 day');

      const fiveDays = SellerDeliveryOption(type: 'standard', description: '', costCents: 0, estimatedDays: 5);
      expect(fiveDays.deliveryTimeText, '5 days');
    });

    test('costDollars conversion', () {
      const option = SellerDeliveryOption(type: 'x', description: '', costCents: 999, estimatedDays: 1);
      expect(option.costDollars, 9.99);
    });

    test('priceText', () {
      const free = SellerDeliveryOption(type: 'x', description: '', costCents: 0, estimatedDays: 1);
      expect(free.priceText, 'Free');

      const paid = SellerDeliveryOption(type: 'x', description: '', costCents: 1299, estimatedDays: 1);
      expect(paid.priceText, '\$12.99');
    });

    test('calculateCostForQuantity no discount', () {
      const option = SellerDeliveryOption(type: 'x', description: '', costCents: 1000, estimatedDays: 1);
      expect(option.calculateCostForQuantity(1), 10.0);
    });

    test('calculateCostForQuantity with percent discount', () {
      const option = SellerDeliveryOption(
        type: 'x',
        description: '',
        costCents: 1000,
        estimatedDays: 1,
        quantityDiscounts: [ShippingQuantityDiscount(minQuantity: 3, discountValue: 20.0)],
      );
      expect(option.calculateCostForQuantity(3), closeTo(8.0, 0.01));
    });

    test('calculateCostForQuantity with fixed discount', () {
      const option = SellerDeliveryOption(
        type: 'x',
        description: '',
        costCents: 1000,
        estimatedDays: 1,
        quantityDiscounts: [ShippingQuantityDiscount(minQuantity: 2, discountType: 'fixed', discountValue: 3.0)],
      );
      expect(option.calculateCostForQuantity(2), closeTo(7.0, 0.01));
    });

    test('calculateCostForQuantity with flat_rate discount', () {
      const option = SellerDeliveryOption(
        type: 'x',
        description: '',
        costCents: 1000,
        estimatedDays: 1,
        quantityDiscounts: [ShippingQuantityDiscount(minQuantity: 5, discountType: 'flat_rate', discountValue: 5.0)],
      );
      expect(option.calculateCostForQuantity(5), 5.0);
    });

    test('calculateCostForQuantity with extra items', () {
      const option = SellerDeliveryOption(
        type: 'x',
        description: '',
        costCents: 1000,
        estimatedDays: 1,
        maxItemsPerShipment: 2,
        additionalItemCostCents: 300,
      );
      // base 10.0 + 2 extra items * 3.0 = 16.0
      expect(option.calculateCostForQuantity(4), closeTo(16.0, 0.01));
    });

    test('calculateCostForQuantity zero quantity returns base', () {
      const option = SellerDeliveryOption(type: 'x', description: '', costCents: 500, estimatedDays: 1);
      expect(option.calculateCostForQuantity(0), 5.0);
    });

    test('calculateCostForQuantity picks best discount', () {
      const option = SellerDeliveryOption(
        type: 'x',
        description: '',
        costCents: 1000,
        estimatedDays: 1,
        quantityDiscounts: [
          ShippingQuantityDiscount(minQuantity: 3, discountValue: 10.0),
          ShippingQuantityDiscount(minQuantity: 10, discountValue: 25.0),
        ],
      );
      // qty=5: best discount is minQuantity=3, 10% off → 9.0
      expect(option.calculateCostForQuantity(5), closeTo(9.0, 0.01));
      // qty=10: best discount is minQuantity=10, 25% off → 7.5
      expect(option.calculateCostForQuantity(10), closeTo(7.5, 0.01));
    });

    test('toMap serializes correctly', () {
      const option = SellerDeliveryOption(
        type: 'express',
        description: 'Fast',
        costCents: 999,
        estimatedDays: 2,
        maxItemsPerShipment: 3,
        additionalItemCostCents: 200,
        availableNationwide: false,
      );
      final map = option.toMap();
      expect(map['type'], 'express');
      expect(map['costCents'], 999);
      expect(map['maxItemsPerShipment'], 3);
      expect(map['additionalItemCostCents'], 200);
      expect(map['availableNationwide'], false);
    });

    test('toMap omits defaults', () {
      const option = SellerDeliveryOption(type: 'x', description: '', costCents: 0, estimatedDays: 1);
      final map = option.toMap();
      expect(map.containsKey('maxItemsPerShipment'), isFalse);
      expect(map.containsKey('additionalItemCostCents'), isFalse);
      expect(map.containsKey('availableNationwide'), isFalse);
      expect(map.containsKey('quantityDiscounts'), isFalse);
    });

    test('defaultOptions returns 3 options', () {
      final defaults = SellerDeliveryOption.defaultOptions();
      expect(defaults.length, 3);
      expect(defaults[0].type, 'standard');
      expect(defaults[1].type, 'express');
      expect(defaults[2].type, 'same_day');
    });
  });

  group('DeliveryItemCheck', () {
    test('constructs with defaults', () {
      const item = DeliveryItemCheck(estimatedShipDays: 3);
      expect(item.isPerishable, isFalse);
      expect(item.isLocalOnly, isFalse);
      expect(item.isInternational, isFalse);
      expect(item.supplierType, isNull);
    });
  });
}
