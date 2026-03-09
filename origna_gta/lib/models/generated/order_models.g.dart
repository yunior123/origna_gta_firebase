// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Order _$OrderFromJson(Map<String, dynamic> json) => _Order(
  orderId: json['orderId'] as String,
  userId: json['userId'] as String,
  version: (json['version'] as num?)?.toInt() ?? 1,
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
  customerId: json['customerId'] as String?,
  customerEmail: json['customerEmail'] as String?,
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalAmountCents: (json['totalAmountCents'] as num).toInt(),
  subtotalCents: (json['subtotalCents'] as num).toInt(),
  shippingCostCents: (json['shippingCostCents'] as num?)?.toInt() ?? 0,
  taxAmountCents: (json['taxAmountCents'] as num?)?.toInt() ?? 0,
  taxes: Taxes.fromJson(json['taxes'] as Map<String, dynamic>),
  orderStatus:
      $enumDecodeNullable(_$OrderStatusEnumMap, json['orderStatus']) ??
      OrderStatus.pending,
  paymentStatus:
      $enumDecodeNullable(_$PaymentStatusEnumMap, json['paymentStatus']) ??
      PaymentStatus.awaitingPayment,
  shippingAddress: json['shippingAddress'] == null
      ? null
      : Address.fromJson(json['shippingAddress'] as Map<String, dynamic>),
  createdAt: DateTime.parse(json['createdAt'] as String),
  currency: json['currency'] as String? ?? BusinessRules.defaultCurrency,
  sellerIds:
      (json['sellerIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  productIds:
      (json['productIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  stripeSessionId: json['stripeSessionId'] as String?,
  shippingApprovalStatus:
      $enumDecodeNullable(
        _$ShippingApprovalStatusEnumMap,
        json['shippingApprovalStatus'],
      ) ??
      ShippingApprovalStatus.notRequired,
  shippingApprovalRequired: json['shippingApprovalRequired'] as bool? ?? false,
  actualShippingCents: (json['actualShippingCents'] as num?)?.toInt() ?? 0,
  pendingTotalCents: (json['pendingTotalCents'] as num?)?.toInt() ?? 0,
  sellerPayouts:
      (json['sellerPayouts'] as List<dynamic>?)
          ?.map((e) => SellerPayout.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  confirmedByClient: json['confirmedByClient'] as bool? ?? false,
  confirmedAt: json['confirmedAt'] == null
      ? null
      : DateTime.parse(json['confirmedAt'] as String),
  platformFeeTotalCents: (json['platformFeeTotalCents'] as num?)?.toInt() ?? 0,
  payoutStatus: json['payoutStatus'] as String? ?? PayoutStatusValues.pending,
  ratings:
      (json['ratings'] as List<dynamic>?)
          ?.map((e) => Ratings.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  stripePaymentIntentId: json['stripePaymentIntentId'] as String?,
  captureAttempts: (json['captureAttempts'] as num?)?.toInt() ?? 0,
  capturedAt: json['capturedAt'] == null
      ? null
      : DateTime.parse(json['capturedAt'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  autoConfirmed: json['autoConfirmed'] as bool? ?? false,
  autoCaptured: json['autoCaptured'] as bool? ?? false,
  refundAmountCents: (json['refundAmountCents'] as num?)?.toInt() ?? 0,
  refundedAt: json['refundedAt'] == null
      ? null
      : DateTime.parse(json['refundedAt'] as String),
  stockRestored: json['stockRestored'] as bool? ?? false,
  cancelledBy: json['cancelledBy'] as String?,
  cancelledAt: json['cancelledAt'] == null
      ? null
      : DateTime.parse(json['cancelledAt'] as String),
  cancellationReason: json['cancellationReason'] as String?,
  respondedAt: json['respondedAt'] == null
      ? null
      : DateTime.parse(json['respondedAt'] as String),
  requiresManualReview: json['requiresManualReview'] as bool? ?? false,
  manualReviewReason: json['manualReviewReason'] as String?,
  payoutErrors:
      (json['payoutErrors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  itemTaxes:
      (json['itemTaxes'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  taxExempt: json['taxExempt'] as bool? ?? false,
  taxExemption: json['taxExemption'] as Map<String, dynamic>?,
  deliveryInstructions: json['deliveryInstructions'] as String?,
  couponCode: json['couponCode'] as String?,
  discountAmountCents: (json['discountAmountCents'] as num?)?.toInt() ?? 0,
  fraudScore: (json['fraudScore'] as num?)?.toInt() ?? 0,
  sellerCaptures: json['sellerCaptures'] as Map<String, dynamic>?,
  lastCaptureError: json['lastCaptureError'] as String?,
);

Map<String, dynamic> _$OrderToJson(_Order instance) => <String, dynamic>{
  'orderId': instance.orderId,
  'userId': instance.userId,
  'version': instance.version,
  'schemaVersion': instance.schemaVersion,
  'customerId': instance.customerId,
  'customerEmail': instance.customerEmail,
  'items': instance.items,
  'totalAmountCents': instance.totalAmountCents,
  'subtotalCents': instance.subtotalCents,
  'shippingCostCents': instance.shippingCostCents,
  'taxAmountCents': instance.taxAmountCents,
  'taxes': instance.taxes,
  'orderStatus': _$OrderStatusEnumMap[instance.orderStatus]!,
  'paymentStatus': _$PaymentStatusEnumMap[instance.paymentStatus]!,
  'shippingAddress': instance.shippingAddress,
  'createdAt': instance.createdAt.toIso8601String(),
  'currency': instance.currency,
  'sellerIds': instance.sellerIds,
  'productIds': instance.productIds,
  'stripeSessionId': instance.stripeSessionId,
  'shippingApprovalStatus':
      _$ShippingApprovalStatusEnumMap[instance.shippingApprovalStatus]!,
  'shippingApprovalRequired': instance.shippingApprovalRequired,
  'actualShippingCents': instance.actualShippingCents,
  'pendingTotalCents': instance.pendingTotalCents,
  'sellerPayouts': instance.sellerPayouts,
  'confirmedByClient': instance.confirmedByClient,
  'confirmedAt': instance.confirmedAt?.toIso8601String(),
  'platformFeeTotalCents': instance.platformFeeTotalCents,
  'payoutStatus': instance.payoutStatus,
  'ratings': instance.ratings,
  'stripePaymentIntentId': instance.stripePaymentIntentId,
  'captureAttempts': instance.captureAttempts,
  'capturedAt': instance.capturedAt?.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'autoConfirmed': instance.autoConfirmed,
  'autoCaptured': instance.autoCaptured,
  'refundAmountCents': instance.refundAmountCents,
  'refundedAt': instance.refundedAt?.toIso8601String(),
  'stockRestored': instance.stockRestored,
  'cancelledBy': instance.cancelledBy,
  'cancelledAt': instance.cancelledAt?.toIso8601String(),
  'cancellationReason': instance.cancellationReason,
  'respondedAt': instance.respondedAt?.toIso8601String(),
  'requiresManualReview': instance.requiresManualReview,
  'manualReviewReason': instance.manualReviewReason,
  'payoutErrors': instance.payoutErrors,
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'itemTaxes': instance.itemTaxes,
  'taxExempt': instance.taxExempt,
  'taxExemption': instance.taxExemption,
  'deliveryInstructions': instance.deliveryInstructions,
  'couponCode': instance.couponCode,
  'discountAmountCents': instance.discountAmountCents,
  'fraudScore': instance.fraudScore,
  'sellerCaptures': instance.sellerCaptures,
  'lastCaptureError': instance.lastCaptureError,
};

const _$OrderStatusEnumMap = {
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

const _$PaymentStatusEnumMap = {
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

const _$ShippingApprovalStatusEnumMap = {
  ShippingApprovalStatus.notRequired: 'not_required',
  ShippingApprovalStatus.pending: 'pending',
  ShippingApprovalStatus.approved: 'approved',
  ShippingApprovalStatus.rejected: 'rejected',
};

_OrderCreate _$OrderCreateFromJson(Map<String, dynamic> json) => _OrderCreate(
  userId: json['userId'] as String,
  customerId: json['customerId'] as String,
  customerEmail: json['customerEmail'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  shippingAddress: Address.fromJson(
    json['shippingAddress'] as Map<String, dynamic>,
  ),
  shippingCost: (json['shippingCost'] as num?)?.toDouble() ?? 0.0,
  currency: json['currency'] as String? ?? BusinessRules.defaultCurrency,
  shippingApprovalRequired: json['shippingApprovalRequired'] as bool? ?? false,
);

Map<String, dynamic> _$OrderCreateToJson(_OrderCreate instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'customerId': instance.customerId,
      'customerEmail': instance.customerEmail,
      'items': instance.items,
      'shippingAddress': instance.shippingAddress,
      'shippingCost': instance.shippingCost,
      'currency': instance.currency,
      'shippingApprovalRequired': instance.shippingApprovalRequired,
    };

_OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => _OrderItem(
  productId: json['productId'] as String,
  cartItemId: json['cartItemId'] as String?,
  name: json['name'] as String,
  description: json['description'] as String,
  price: (json['price'] as num).toDouble(),
  quantity: (json['quantity'] as num).toInt(),
  imageUrls: (json['imageUrls'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  sellerId: json['sellerId'] as String,
  sellerAddress: json['sellerAddress'] == null
      ? null
      : Address.fromJson(json['sellerAddress'] as Map<String, dynamic>),
  status: json['status'] as String? ?? DeliveryStatusValues.pending,
  trackingNumber: json['trackingNumber'] as String?,
  carrier: json['carrier'] as String?,
  carrierNote: json['carrierNote'] as String?,
  sellerSku: json['sellerSku'] as String?,
  sellerName: json['sellerName'] as String?,
  shippedAt: json['shippedAt'] == null
      ? null
      : DateTime.parse(json['shippedAt'] as String),
  deliveredAt: json['deliveredAt'] == null
      ? null
      : DateTime.parse(json['deliveredAt'] as String),
  refundedAt: json['refundedAt'] == null
      ? null
      : DateTime.parse(json['refundedAt'] as String),
  refundReason: json['refundReason'] as String?,
  refundAmountCents: (json['refundAmountCents'] as num?)?.toInt(),
  refundId: json['refundId'] as String?,
  confirmedByBuyer: json['confirmedByBuyer'] as bool? ?? false,
  variantId: json['variantId'] as String?,
  variantTitle: json['variantTitle'] as String?,
  variantOptions: (json['variantOptions'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  variantSku: json['variantSku'] as String?,
  weightKg: (json['weightKg'] as num?)?.toDouble(),
  lengthCm: (json['lengthCm'] as num?)?.toDouble(),
  widthCm: (json['widthCm'] as num?)?.toDouble(),
  heightCm: (json['heightCm'] as num?)?.toDouble(),
  isLocalDeliveryOnly: json['isLocalDeliveryOnly'] as bool? ?? false,
  isPerishable: json['isPerishable'] as bool? ?? false,
  estimatedShipDays: (json['estimatedShipDays'] as num?)?.toInt() ?? 3,
  deliveryOptions:
      (json['deliveryOptions'] as List<dynamic>?)
          ?.map((e) => SellerDeliveryOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  minimumOrderQuantity: (json['minimumOrderQuantity'] as num?)?.toInt() ?? 1,
  freeShipping: json['freeShipping'] as bool? ?? false,
  isDigital: json['isDigital'] as bool? ?? false,
  licenseKey: json['licenseKey'] as String?,
  digitalUnlocked: json['digitalUnlocked'] as bool? ?? false,
  digitalType: json['digitalType'] as String?,
  digitalBuilds: (json['digitalBuilds'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  taxCode: json['taxCode'] as String?,
  buyerNote: json['buyerNote'] as String?,
  fulfillmentWarehouseId: json['fulfillmentWarehouseId'] as String?,
);

Map<String, dynamic> _$OrderItemToJson(_OrderItem instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'cartItemId': instance.cartItemId,
      'name': instance.name,
      'description': instance.description,
      'price': instance.price,
      'quantity': instance.quantity,
      'imageUrls': instance.imageUrls,
      'sellerId': instance.sellerId,
      'sellerAddress': instance.sellerAddress,
      'status': instance.status,
      'trackingNumber': instance.trackingNumber,
      'carrier': instance.carrier,
      'carrierNote': instance.carrierNote,
      'sellerSku': instance.sellerSku,
      'sellerName': instance.sellerName,
      'shippedAt': instance.shippedAt?.toIso8601String(),
      'deliveredAt': instance.deliveredAt?.toIso8601String(),
      'refundedAt': instance.refundedAt?.toIso8601String(),
      'refundReason': instance.refundReason,
      'refundAmountCents': instance.refundAmountCents,
      'refundId': instance.refundId,
      'confirmedByBuyer': instance.confirmedByBuyer,
      'variantId': instance.variantId,
      'variantTitle': instance.variantTitle,
      'variantOptions': instance.variantOptions,
      'variantSku': instance.variantSku,
      'weightKg': instance.weightKg,
      'lengthCm': instance.lengthCm,
      'widthCm': instance.widthCm,
      'heightCm': instance.heightCm,
      'isLocalDeliveryOnly': instance.isLocalDeliveryOnly,
      'isPerishable': instance.isPerishable,
      'estimatedShipDays': instance.estimatedShipDays,
      'deliveryOptions': instance.deliveryOptions,
      'minimumOrderQuantity': instance.minimumOrderQuantity,
      'freeShipping': instance.freeShipping,
      'isDigital': instance.isDigital,
      'licenseKey': instance.licenseKey,
      'digitalUnlocked': instance.digitalUnlocked,
      'digitalType': instance.digitalType,
      'digitalBuilds': instance.digitalBuilds,
      'taxCode': instance.taxCode,
      'buyerNote': instance.buyerNote,
      'fulfillmentWarehouseId': instance.fulfillmentWarehouseId,
    };

_Ratings _$RatingsFromJson(Map<String, dynamic> json) => _Ratings(
  productId: json['productId'] as String,
  rating: (json['rating'] as num).toDouble(),
  review: json['review'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$RatingsToJson(_Ratings instance) => <String, dynamic>{
  'productId': instance.productId,
  'rating': instance.rating,
  'review': instance.review,
  'createdAt': instance.createdAt.toIso8601String(),
};

_SellerPayout _$SellerPayoutFromJson(Map<String, dynamic> json) =>
    _SellerPayout(
      sellerId: json['sellerId'] as String,
      stripeAccountId: json['stripeAccountId'] as String?,
      amountCents: (json['amountCents'] as num).toInt(),
      platformFeeCents: (json['platformFeeCents'] as num).toInt(),
      netAmountCents: (json['netAmountCents'] as num).toInt(),
      status: json['status'] as String? ?? PayoutStatusValues.pending,
      payoutDate: json['payoutDate'] == null
          ? null
          : DateTime.parse(json['payoutDate'] as String),
      stripeTransferId: json['stripeTransferId'] as String?,
      failureReason: json['failureReason'] as String?,
    );

Map<String, dynamic> _$SellerPayoutToJson(_SellerPayout instance) =>
    <String, dynamic>{
      'sellerId': instance.sellerId,
      'stripeAccountId': instance.stripeAccountId,
      'amountCents': instance.amountCents,
      'platformFeeCents': instance.platformFeeCents,
      'netAmountCents': instance.netAmountCents,
      'status': instance.status,
      'payoutDate': instance.payoutDate?.toIso8601String(),
      'stripeTransferId': instance.stripeTransferId,
      'failureReason': instance.failureReason,
    };
