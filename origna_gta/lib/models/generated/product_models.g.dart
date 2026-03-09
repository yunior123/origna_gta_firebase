// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InventoryConfig _$InventoryConfigFromJson(Map<String, dynamic> json) =>
    _InventoryConfig(
      managed: json['managed'] as bool? ?? true,
      trackQuantity: json['trackQuantity'] as bool? ?? true,
      allowBackorder: json['allowBackorder'] as bool? ?? false,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 5,
      lastLowStockAlertAt: json['lastLowStockAlertAt'] == null
          ? null
          : DateTime.parse(json['lastLowStockAlertAt'] as String),
      reservationHoldMinutes:
          (json['reservationHoldMinutes'] as num?)?.toInt() ?? 30,
    );

Map<String, dynamic> _$InventoryConfigToJson(_InventoryConfig instance) =>
    <String, dynamic>{
      'managed': instance.managed,
      'trackQuantity': instance.trackQuantity,
      'allowBackorder': instance.allowBackorder,
      'lowStockThreshold': instance.lowStockThreshold,
      'lastLowStockAlertAt': instance.lastLowStockAlertAt?.toIso8601String(),
      'reservationHoldMinutes': instance.reservationHoldMinutes,
    };

_Product _$ProductFromJson(Map<String, dynamic> json) => _Product(
  productId: json['productId'] as String,
  name: json['name'] as String,
  nameF: json['nameF'] as String?,
  price: (json['price'] as num).toDouble(),
  priceCents: (json['priceCents'] as num?)?.toInt(),
  compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
  description: json['description'] as String,
  descriptionF: json['descriptionF'] as String?,
  imageUrls: (json['imageUrls'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  videoUrl: json['videoUrl'] as String?,
  videoDurationSeconds: (json['videoDurationSeconds'] as num?)?.toInt(),
  sellerId: json['sellerId'] as String,
  madeInCountry: json['madeInCountry'] as String?,
  sellerAddress: json['sellerAddress'] == null
      ? null
      : Address.fromJson(json['sellerAddress'] as Map<String, dynamic>),
  categoryId: (json['categoryId'] as num).toInt(),
  stockQuantity: (json['stockQuantity'] as num).toInt(),
  rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
  ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['createdAt'] as String),
  lifecycleStatus:
      json['lifecycleStatus'] as String? ?? ProductLifecycleStatusValues.draft,
  weightKg: (json['weightKg'] as num?)?.toDouble(),
  weightUnit: json['weightUnit'] as String?,
  lengthCm: (json['lengthCm'] as num?)?.toDouble(),
  widthCm: (json['widthCm'] as num?)?.toDouble(),
  heightCm: (json['heightCm'] as num?)?.toDouble(),
  dimensionUnit: json['dimensionUnit'] as String?,
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
  isAgeRestricted: json['isAgeRestricted'] as bool? ?? false,
  digitalType: json['digitalType'] as String?,
  slug: json['slug'] as String?,
  digitalBuilds: (json['digitalBuilds'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  deviceLimit: (json['deviceLimit'] as num?)?.toInt(),
  taxCode: json['taxCode'] as String?,
  keywords:
      (json['keywords'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  approvalRejectionReason: json['approvalRejectionReason'] as String?,
  cost: (json['cost'] as num?)?.toDouble(),
  supplierSku: json['supplierSku'] as String?,
  supplierUrl: json['supplierUrl'] as String?,
  supplier: json['supplier'] == null
      ? null
      : SupplierInfo.fromJson(json['supplier'] as Map<String, dynamic>),
  inventory: json['inventory'] == null
      ? null
      : InventoryConfig.fromJson(json['inventory'] as Map<String, dynamic>),
  sellerSku: json['sellerSku'] as String?,
  warehouseIds: (json['warehouseIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  shipFromCity: json['shipFromCity'] as String?,
  shipFromProvince: json['shipFromProvince'] as String?,
  shipFromCountry: json['shipFromCountry'] as String?,
  shipFromCountries: (json['shipFromCountries'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  trendingScore: (json['trendingScore'] as num?)?.toInt() ?? 0,
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  purchaseCount: (json['purchaseCount'] as num?)?.toInt() ?? 0,
  isTrending: json['isTrending'] as bool? ?? false,
  trendingAt: json['trendingAt'] == null
      ? null
      : DateTime.parse(json['trendingAt'] as String),
  hasVariants: json['hasVariants'] as bool? ?? false,
  variants:
      (json['variants'] as List<dynamic>?)
          ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  variantOptions:
      (json['variantOptions'] as List<dynamic>?)
          ?.map((e) => VariantOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  subcategory: json['subcategory'] as String?,
  condition: json['condition'] as String?,
  warehouseStockMap: (json['warehouseStockMap'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, (e as num).toInt()),
  ),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$ProductToJson(_Product instance) => <String, dynamic>{
  'productId': instance.productId,
  'name': instance.name,
  'nameF': instance.nameF,
  'price': instance.price,
  'priceCents': instance.priceCents,
  'compareAtPrice': instance.compareAtPrice,
  'description': instance.description,
  'descriptionF': instance.descriptionF,
  'imageUrls': instance.imageUrls,
  'videoUrl': instance.videoUrl,
  'videoDurationSeconds': instance.videoDurationSeconds,
  'sellerId': instance.sellerId,
  'madeInCountry': instance.madeInCountry,
  'sellerAddress': instance.sellerAddress,
  'categoryId': instance.categoryId,
  'stockQuantity': instance.stockQuantity,
  'rating': instance.rating,
  'ratingCount': instance.ratingCount,
  'createdAt': instance.createdAt.toIso8601String(),
  'lifecycleStatus': instance.lifecycleStatus,
  'weightKg': instance.weightKg,
  'weightUnit': instance.weightUnit,
  'lengthCm': instance.lengthCm,
  'widthCm': instance.widthCm,
  'heightCm': instance.heightCm,
  'dimensionUnit': instance.dimensionUnit,
  'isLocalDeliveryOnly': instance.isLocalDeliveryOnly,
  'isPerishable': instance.isPerishable,
  'estimatedShipDays': instance.estimatedShipDays,
  'deliveryOptions': instance.deliveryOptions,
  'minimumOrderQuantity': instance.minimumOrderQuantity,
  'freeShipping': instance.freeShipping,
  'isDigital': instance.isDigital,
  'isAgeRestricted': instance.isAgeRestricted,
  'digitalType': instance.digitalType,
  'slug': instance.slug,
  'digitalBuilds': instance.digitalBuilds,
  'deviceLimit': instance.deviceLimit,
  'taxCode': instance.taxCode,
  'keywords': instance.keywords,
  'approvalRejectionReason': instance.approvalRejectionReason,
  'cost': instance.cost,
  'supplierSku': instance.supplierSku,
  'supplierUrl': instance.supplierUrl,
  'supplier': instance.supplier,
  'inventory': instance.inventory,
  'sellerSku': instance.sellerSku,
  'warehouseIds': instance.warehouseIds,
  'shipFromCity': instance.shipFromCity,
  'shipFromProvince': instance.shipFromProvince,
  'shipFromCountry': instance.shipFromCountry,
  'shipFromCountries': instance.shipFromCountries,
  'trendingScore': instance.trendingScore,
  'viewCount': instance.viewCount,
  'purchaseCount': instance.purchaseCount,
  'isTrending': instance.isTrending,
  'trendingAt': instance.trendingAt?.toIso8601String(),
  'hasVariants': instance.hasVariants,
  'variants': instance.variants,
  'variantOptions': instance.variantOptions,
  'subcategory': instance.subcategory,
  'condition': instance.condition,
  'warehouseStockMap': instance.warehouseStockMap,
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

_ProductCreate _$ProductCreateFromJson(
  Map<String, dynamic> json,
) => _ProductCreate(
  name: json['name'] as String,
  nameF: json['nameF'] as String?,
  price: (json['price'] as num).toDouble(),
  compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
  description: json['description'] as String,
  descriptionF: json['descriptionF'] as String?,
  imageUrls: (json['imageUrls'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  videoUrl: json['videoUrl'] as String?,
  sellerId: json['sellerId'] as String,
  sellerAddress: json['sellerAddress'] == null
      ? null
      : Address.fromJson(json['sellerAddress'] as Map<String, dynamic>),
  categoryId: (json['categoryId'] as num).toInt(),
  stockQuantity: (json['stockQuantity'] as num).toInt(),
  rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
  lifecycleStatus:
      json['lifecycleStatus'] as String? ?? ProductLifecycleStatusValues.draft,
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
  digitalType: json['digitalType'] as String?,
  slug: json['slug'] as String?,
  digitalBuilds: (json['digitalBuilds'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  deviceLimit: (json['deviceLimit'] as num?)?.toInt(),
  taxCode: json['taxCode'] as String?,
  keywords:
      (json['keywords'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  cost: (json['cost'] as num?)?.toDouble(),
  supplierSku: json['supplierSku'] as String?,
  supplierUrl: json['supplierUrl'] as String?,
  supplier: json['supplier'] == null
      ? null
      : SupplierInfo.fromJson(json['supplier'] as Map<String, dynamic>),
  inventory: json['inventory'] == null
      ? null
      : InventoryConfig.fromJson(json['inventory'] as Map<String, dynamic>),
  sellerSku: json['sellerSku'] as String?,
  warehouseIds: (json['warehouseIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  shipFromCity: json['shipFromCity'] as String?,
  shipFromProvince: json['shipFromProvince'] as String?,
  shipFromCountry: json['shipFromCountry'] as String?,
  shipFromCountries: (json['shipFromCountries'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  hasVariants: json['hasVariants'] as bool? ?? false,
  variants:
      (json['variants'] as List<dynamic>?)
          ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  variantOptions:
      (json['variantOptions'] as List<dynamic>?)
          ?.map((e) => VariantOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  subcategory: json['subcategory'] as String?,
);

Map<String, dynamic> _$ProductCreateToJson(_ProductCreate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'nameF': instance.nameF,
      'price': instance.price,
      'compareAtPrice': instance.compareAtPrice,
      'description': instance.description,
      'descriptionF': instance.descriptionF,
      'imageUrls': instance.imageUrls,
      'videoUrl': instance.videoUrl,
      'sellerId': instance.sellerId,
      'sellerAddress': instance.sellerAddress,
      'categoryId': instance.categoryId,
      'stockQuantity': instance.stockQuantity,
      'rating': instance.rating,
      'lifecycleStatus': instance.lifecycleStatus,
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
      'digitalType': instance.digitalType,
      'slug': instance.slug,
      'digitalBuilds': instance.digitalBuilds,
      'deviceLimit': instance.deviceLimit,
      'taxCode': instance.taxCode,
      'keywords': instance.keywords,
      'cost': instance.cost,
      'supplierSku': instance.supplierSku,
      'supplierUrl': instance.supplierUrl,
      'supplier': instance.supplier,
      'inventory': instance.inventory,
      'sellerSku': instance.sellerSku,
      'warehouseIds': instance.warehouseIds,
      'shipFromCity': instance.shipFromCity,
      'shipFromProvince': instance.shipFromProvince,
      'shipFromCountry': instance.shipFromCountry,
      'shipFromCountries': instance.shipFromCountries,
      'hasVariants': instance.hasVariants,
      'variants': instance.variants,
      'variantOptions': instance.variantOptions,
      'subcategory': instance.subcategory,
    };

_VariantOption _$VariantOptionFromJson(Map<String, dynamic> json) =>
    _VariantOption(
      name: json['name'] as String,
      values: (json['values'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$VariantOptionToJson(_VariantOption instance) =>
    <String, dynamic>{'name': instance.name, 'values': instance.values};

_ProductVariant _$ProductVariantFromJson(Map<String, dynamic> json) =>
    _ProductVariant(
      variantId: json['variantId'] as String? ?? '',
      optionValues: Map<String, String>.from(json['optionValues'] as Map),
      priceCents: (json['priceCents'] as num?)?.toInt(),
      stockQuantity: (json['stockQuantity'] as num).toInt(),
      sku: json['sku'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$ProductVariantToJson(_ProductVariant instance) =>
    <String, dynamic>{
      'variantId': instance.variantId,
      'optionValues': instance.optionValues,
      'priceCents': instance.priceCents,
      'stockQuantity': instance.stockQuantity,
      'sku': instance.sku,
      'isActive': instance.isActive,
    };

_ProductQuestion _$ProductQuestionFromJson(Map<String, dynamic> json) =>
    _ProductQuestion(
      questionId: json['questionId'] as String,
      productId: json['productId'] as String,
      sellerId: json['sellerId'] as String,
      askerId: json['askerId'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String?,
      answeredAt: json['answeredAt'] == null
          ? null
          : DateTime.parse(json['answeredAt'] as String),
      answeredBy: json['answeredBy'] as String?,
      isAnswered: json['isAnswered'] as bool? ?? false,
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ProductQuestionToJson(_ProductQuestion instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'productId': instance.productId,
      'sellerId': instance.sellerId,
      'askerId': instance.askerId,
      'question': instance.question,
      'answer': instance.answer,
      'answeredAt': instance.answeredAt?.toIso8601String(),
      'answeredBy': instance.answeredBy,
      'isAnswered': instance.isAnswered,
      'upvotes': instance.upvotes,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_SellerDeliveryOption _$SellerDeliveryOptionFromJson(
  Map<String, dynamic> json,
) => _SellerDeliveryOption(
  type: json['type'] as String? ?? DeliveryTypeValues.standard,
  description: json['description'] as String? ?? '',
  costCents: (json['costCents'] as num?)?.toInt() ?? 0,
  estimatedDays: (json['estimatedDays'] as num?)?.toInt() ?? 3,
  quantityDiscounts:
      (json['quantityDiscounts'] as List<dynamic>?)
          ?.map(
            (e) => ShippingQuantityDiscount.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  maxItemsPerShipment: (json['maxItemsPerShipment'] as num?)?.toInt() ?? 0,
  additionalItemCostCents:
      (json['additionalItemCostCents'] as num?)?.toInt() ?? 0,
  availableNationwide: json['availableNationwide'] as bool? ?? true,
);

Map<String, dynamic> _$SellerDeliveryOptionToJson(
  _SellerDeliveryOption instance,
) => <String, dynamic>{
  'type': instance.type,
  'description': instance.description,
  'costCents': instance.costCents,
  'estimatedDays': instance.estimatedDays,
  'quantityDiscounts': instance.quantityDiscounts,
  'maxItemsPerShipment': instance.maxItemsPerShipment,
  'additionalItemCostCents': instance.additionalItemCostCents,
  'availableNationwide': instance.availableNationwide,
};

_SellerWarehouse _$SellerWarehouseFromJson(Map<String, dynamic> json) =>
    _SellerWarehouse(
      warehouseId: json['warehouseId'] as String,
      label: json['label'] as String,
      type: json['type'] as String? ?? 'warehouse',
      address: Address.fromJson(json['address'] as Map<String, dynamic>),
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$SellerWarehouseToJson(_SellerWarehouse instance) =>
    <String, dynamic>{
      'warehouseId': instance.warehouseId,
      'label': instance.label,
      'type': instance.type,
      'address': instance.address,
      'isDefault': instance.isDefault,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_ShippingQuantityDiscount _$ShippingQuantityDiscountFromJson(
  Map<String, dynamic> json,
) => _ShippingQuantityDiscount(
  minQuantity: (json['minQuantity'] as num).toInt(),
  discountType: json['discountType'] as String? ?? DiscountTypeValues.percent,
  discountValue: (json['discountValue'] as num).toDouble(),
  label: json['label'] as String?,
);

Map<String, dynamic> _$ShippingQuantityDiscountToJson(
  _ShippingQuantityDiscount instance,
) => <String, dynamic>{
  'minQuantity': instance.minQuantity,
  'discountType': instance.discountType,
  'discountValue': instance.discountValue,
  'label': instance.label,
};

_SupplierInfo _$SupplierInfoFromJson(Map<String, dynamic> json) =>
    _SupplierInfo(
      type: json['type'] as String,
      supplierSku: json['supplierSku'] as String?,
      supplierUrl: json['supplierUrl'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      shippingDays: json['shippingDays'] as String?,
      hasTracking: json['hasTracking'] as bool? ?? false,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$SupplierInfoToJson(_SupplierInfo instance) =>
    <String, dynamic>{
      'type': instance.type,
      'supplierSku': instance.supplierSku,
      'supplierUrl': instance.supplierUrl,
      'cost': instance.cost,
      'currency': instance.currency,
      'shippingDays': instance.shippingDays,
      'hasTracking': instance.hasTracking,
      'notes': instance.notes,
    };
