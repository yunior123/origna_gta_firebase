import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/constants.dart';

/// Safely parse a dynamic value (Timestamp, String, DateTime) to DateTime?
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Safely parse a dynamic value to Timestamp (never null)
Timestamp _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  if (value is String) {
    final dt = DateTime.tryParse(value);
    if (dt != null) return Timestamp.fromDate(dt);
  }
  return Timestamp.now();
}

/// Documentation for Address
class Address {
  final String street;
  final String apartment; // Unit, Suite, Apt #
  final String city;
  final String state; // or province
  final String postalCode; // ZIP code
  final String country;
  final String? phoneNumber; // Optional contact number for delivery
  final bool isDefault; // For multiple addresses
  final String? label; // "Home", "Work", "Other"
  final double? latitude; // For mapping/delivery
  final double? longitude;
  final String? addressId; // For Address Book subcollection

  Address({
    this.addressId,
    required this.street,
    this.apartment = '',
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    this.phoneNumber,
    this.isDefault = false,
    this.label,
    this.latitude,
    this.longitude,
  });

  /// Create an empty address for fallback when data is missing
  factory Address.empty() => Address(street: '', city: '', state: '', postalCode: '', country: 'Canada');

  factory Address.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Address(
      addressId: docId ?? map[Fields.addressId],
      street: map[Fields.street] ?? '',
      apartment: map[Fields.apartment] ?? '',
      city: map[Fields.city] ?? '',
      state: map[Fields.state] ?? '',
      postalCode: map[Fields.postalCode] ?? '',
      country: map[Fields.country] ?? '',
      phoneNumber: map[Fields.phoneNumber],
      isDefault: map[Fields.isDefault] ?? false,
      label: map[Fields.label],
      latitude: map[Fields.latitude]?.toDouble(),
      longitude: map[Fields.longitude]?.toDouble(),
    );
  }

  // Helper for display with line breaks
  String get formattedAddress {
    final line1 = street;
    final line2 = apartment.isNotEmpty ? apartment : null;
    final line3 = '$city, $state $postalCode';
    final line4 = country;

    return [line1, line2, line3, line4].where((line) => line != null && line.isNotEmpty).join('\n');
  }

  // Helper method to get formatted full address
  String get fullAddress {
    final parts = <String>[street, if (apartment.isNotEmpty) apartment, city, state, postalCode, country];
    return parts.join(', ');
  }

  Address copyWith({
    String? street,
    String? apartment,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? phoneNumber,
    bool? isDefault,
    String? label,
    double? latitude,
    double? longitude,
    String? addressId,
  }) {
    return Address(
      street: street ?? this.street,
      apartment: apartment ?? this.apartment,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isDefault: isDefault ?? this.isDefault,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addressId: addressId ?? this.addressId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (addressId != null) Fields.addressId: addressId,
      Fields.street: street,
      Fields.apartment: apartment,
      Fields.city: city,
      Fields.state: state,
      Fields.postalCode: postalCode,
      Fields.country: country,
      Fields.phoneNumber: phoneNumber,
      Fields.isDefault: isDefault,
      Fields.label: label,
      Fields.latitude: latitude,
      Fields.longitude: longitude,
    };
  }
}

/// Documentation for AddressDetails
class AddressDetails {
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final double latitude;
  final double longitude;

  AddressDetails({required this.street, required this.city, required this.state, required this.postalCode, required this.latitude, required this.longitude});
}

/// Documentation for CartItemDetailModel
class CartItemDetailModel {
  final String productId;
  final String name;
  final String description;
  final double price;
  final List<String> imageUrls;
  final int quantity;
  final Timestamp createdAt;
  final Address sellerAddress;
  final String sellerId;
  final String sellerName;
  final String status;
  final String? trackingNumber;
  final bool confirmedByBuyer; // Buyer confirmed receipt of this item
  final String? madeInCountry; // F-277
  final double? weightKg;
  final String? weightUnit; // F-280
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final String? dimensionUnit; // F-280
  final bool isLocalDeliveryOnly;
  final bool isPerishable;
  final int estimatedShipDays;
  final List<SellerDeliveryOption> deliveryOptions;
  final int minimumOrderQuantity;
  final bool freeShipping;
  final bool isDigital;
  final bool isAgeRestricted;
  final String? buyerNote;
  final bool isSmallSupplier;
  final String? variantId;
  final String? variantTitle;
  final Map<String, String>? variantOptions;

  CartItemDetailModel({
    required this.productId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrls,
    required this.quantity,
    required this.createdAt,
    required this.sellerAddress,
    required this.sellerId,
    required this.sellerName,
    this.status = DeliveryStatusValues.pending,
    this.trackingNumber,
    this.confirmedByBuyer = false,
    this.madeInCountry,
    this.weightKg,
    this.weightUnit,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.dimensionUnit,
    this.isLocalDeliveryOnly = false,
    this.isPerishable = false,
    this.estimatedShipDays = 3,
    this.deliveryOptions = const [],
    this.minimumOrderQuantity = 1,
    this.freeShipping = false,
    this.isDigital = false,
    this.isAgeRestricted = false,
    this.buyerNote,
    this.isSmallSupplier = false,
    this.variantId,
    this.variantTitle,
    this.variantOptions,
  });

  // Convert Firestore Map to CartItemDetailModel
  factory CartItemDetailModel.fromMap(Map<String, dynamic> map) {
    return CartItemDetailModel(
      productId: map[Fields.productId] ?? '',
      name: map[Fields.name] ?? '',
      description: map[Fields.description] ?? '',
      price: (map[Fields.price] ?? 0).toDouble(),
      imageUrls: List<String>.from(map[Fields.imageUrls] ?? []),
      quantity: (map[Fields.quantity] as num?)?.toInt() ?? 0,
      createdAt: _parseTimestamp(map[Fields.createdAt]),
      sellerAddress: map[Fields.sellerAddress] != null ? Address.fromMap(map[Fields.sellerAddress] as Map<String, dynamic>) : Address.empty(),
      sellerId: map[Fields.sellerId] ?? '',
      sellerName: map[Fields.sellerName] ?? '',
      status: map[Fields.status] ?? DeliveryStatus.pending.value,
      trackingNumber: map[Fields.trackingNumber],
      confirmedByBuyer: map[Fields.confirmedByBuyer] ?? false,
      madeInCountry: map[Fields.madeInCountry] as String?,
      weightKg: map[Fields.weightKg] != null ? (map[Fields.weightKg] as num).toDouble() : null,
      weightUnit: map[Fields.weightUnit] as String?,
      lengthCm: map[Fields.lengthCm] != null ? (map[Fields.lengthCm] as num).toDouble() : null,
      widthCm: map[Fields.widthCm] != null ? (map[Fields.widthCm] as num).toDouble() : null,
      heightCm: map[Fields.heightCm] != null ? (map[Fields.heightCm] as num).toDouble() : null,
      dimensionUnit: map[Fields.dimensionUnit] as String?,
      isLocalDeliveryOnly: map[Fields.isLocalDeliveryOnly] ?? false,
      isPerishable: map[Fields.isPerishable] ?? false,
      estimatedShipDays: map[Fields.estimatedShipDays] ?? 3,
      deliveryOptions: map[Fields.deliveryOptions] != null
          ? (map[Fields.deliveryOptions] as List)
                .whereType<Map>()
                .map((o) => SellerDeliveryOption.fromMap(o.cast<String, dynamic>()))
                .whereType<SellerDeliveryOption>()
                .toList()
          : [],
      minimumOrderQuantity: (map[Fields.minimumOrderQuantity] as num?)?.toInt() ?? 1,
      freeShipping: map[Fields.freeShipping] ?? false,
      isDigital: map[Fields.isDigital] ?? false,
      isAgeRestricted: map[Fields.isAgeRestricted] ?? false,
      buyerNote: map[Fields.buyerNote] as String?,
      isSmallSupplier: map[Fields.isSmallSupplier] ?? false,
      variantId: map[Fields.variantId] as String?,
      variantTitle: map[Fields.variantTitle] as String?,
      variantOptions: map[Fields.variantOptions] != null ? Map<String, String>.from(map[Fields.variantOptions] as Map) : null,
    );
  }

  // Convert model to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      Fields.productId: productId,
      Fields.name: name,
      Fields.description: description,
      Fields.price: price,
      Fields.imageUrls: imageUrls,
      Fields.quantity: quantity,
      Fields.createdAt: createdAt,
      Fields.sellerAddress: sellerAddress.toMap(),
      Fields.sellerId: sellerId,
      Fields.sellerName: sellerName,
      Fields.status: status,
      Fields.trackingNumber: trackingNumber,
      Fields.confirmedByBuyer: confirmedByBuyer,
      if (madeInCountry != null) Fields.madeInCountry: madeInCountry,
      Fields.weightKg: weightKg,
      if (weightUnit != null) Fields.weightUnit: weightUnit,
      Fields.lengthCm: lengthCm,
      Fields.widthCm: widthCm,
      Fields.heightCm: heightCm,
      if (dimensionUnit != null) Fields.dimensionUnit: dimensionUnit,
      Fields.isLocalDeliveryOnly: isLocalDeliveryOnly,
      Fields.isPerishable: isPerishable,
      Fields.estimatedShipDays: estimatedShipDays,
      Fields.deliveryOptions: deliveryOptions.map((o) => o.toMap()).toList(),
      Fields.minimumOrderQuantity: minimumOrderQuantity,
      Fields.freeShipping: freeShipping,
      Fields.isDigital: isDigital,
      Fields.isAgeRestricted: isAgeRestricted,
      if (buyerNote != null) Fields.buyerNote: buyerNote,
      Fields.isSmallSupplier: isSmallSupplier,
      if (variantId != null) Fields.variantId: variantId,
      if (variantTitle != null) Fields.variantTitle: variantTitle,
      if (variantOptions != null) Fields.variantOptions: variantOptions,
    };
  }
}

/// Documentation for CartItemModel
class CartItemModel {
  final String cartItemId; // Auto-generated Firestore doc ID
  final int quantity;
  final String productId;
  final Timestamp createdAt;
  final String? buyerNote;
  final String? variantId;
  final String? variantTitle;
  final Map<String, String>? variantOptions;

  CartItemModel({
    required this.cartItemId,
    required this.quantity,
    required this.productId,
    required this.createdAt,
    this.buyerNote,
    this.variantId,
    this.variantTitle,
    this.variantOptions,
  });

  factory CartItemModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final raw = map[Fields.createdAt];
    Timestamp ts;
    if (raw is Timestamp) {
      ts = raw;
    } else if (raw is String) {
      ts = Timestamp.fromDate(DateTime.parse(raw));
    } else if (raw is DateTime) {
      ts = Timestamp.fromDate(raw);
    } else {
      ts = Timestamp.now();
    }
    return CartItemModel(
      cartItemId: docId ?? (map[Fields.cartItemId] as String? ?? ''),
      quantity: (map[Fields.quantity] as num?)?.toInt() ?? 0,
      productId: map[Fields.productId] ?? '',
      createdAt: ts,
      buyerNote: map[Fields.buyerNote] as String?,
      variantId: map[Fields.variantId] as String?,
      variantTitle: map[Fields.variantTitle] as String?,
      variantOptions: map[Fields.variantOptions] != null ? Map<String, String>.from(map[Fields.variantOptions] as Map) : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{Fields.quantity: quantity, Fields.productId: productId, Fields.createdAt: createdAt};
    if (buyerNote != null) map[Fields.buyerNote] = buyerNote;
    if (variantId != null) map[Fields.variantId] = variantId;
    if (variantTitle != null) map[Fields.variantTitle] = variantTitle;
    if (variantOptions != null) map[Fields.variantOptions] = variantOptions;
    return map;
  }
}

/// Documentation for CartModel
class CartModel {
  final String cartItemId; // Auto-generated Firestore doc ID
  final String productId;
  final int quantity;
  final DateTime createdAt;
  final String? variantId;
  final String? variantTitle;
  final Map<String, String>? variantOptions;
  final String? variantSku;
  final int? priceSnapshot; // Price in cents at time of cart addition

  CartModel({
    this.cartItemId = '',
    required this.productId,
    this.quantity = 1,
    required this.createdAt,
    this.variantId,
    this.variantTitle,
    this.variantOptions,
    this.variantSku,
    this.priceSnapshot,
  });

  factory CartModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // Handle both Timestamp and null cases safely
    DateTime parsedDate;
    final rawDate = map[Fields.createdAt];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.now();
    }

    return CartModel(
      cartItemId: docId ?? (map[Fields.cartItemId] as String? ?? ''),
      productId: map[Fields.productId] ?? '',
      quantity: (map[Fields.quantity] as num?)?.toInt() ?? 1,
      createdAt: parsedDate,
      variantId: map[Fields.variantId] as String?,
      variantTitle: map[Fields.variantTitle] as String?,
      variantOptions: map[Fields.variantOptions] != null ? Map<String, String>.from(map[Fields.variantOptions] as Map) : null,
      variantSku: map[Fields.variantSku] as String?,
      priceSnapshot: (map[Fields.priceSnapshot] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{Fields.productId: productId, Fields.quantity: quantity, Fields.createdAt: Timestamp.fromDate(createdAt)};
    if (variantId != null) map[Fields.variantId] = variantId;
    if (variantTitle != null) map[Fields.variantTitle] = variantTitle;
    if (variantOptions != null) map[Fields.variantOptions] = variantOptions;
    if (variantSku != null) map[Fields.variantSku] = variantSku;
    if (priceSnapshot != null) map[Fields.priceSnapshot] = priceSnapshot;
    return map;
  }
}

/// Documentation for FavoriteItem
class FavoriteItem {
  final String productId;
  final DateTime dateFavorited;

  FavoriteItem({required this.productId, required this.dateFavorited});

  factory FavoriteItem.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FavoriteItem(productId: data[Fields.productId] ?? doc.id, dateFavorited: (data[Fields.dateFavorited] as Timestamp?)?.toDate() ?? DateTime.now());
  }

  Map<String, dynamic> toMap() {
    return {Fields.productId: productId, Fields.dateFavorited: Timestamp.fromDate(dateFavorited)};
  }
}

/// Documentation for ImageModel
class ImageModel {
  final String url;
  final Uint8List bytes;

  ImageModel({required this.url, required this.bytes});
}

/// Documentation for OrderModel
class OrderModel {
  final String orderId;
  final String userId;
  final String customerId;
  final String customerEmail;
  final List<CartItemDetailModel> items;
  // Money stored as cents, exposed as dollars
  final int totalAmountCents;
  final int subtotalCents;
  final int shippingCostCents;
  final int taxAmountCents;
  final Map<String, double> taxes;
  final String orderStatus;
  final String paymentStatus;
  final Map<String, dynamic> shippingAddress;
  final DateTime createdAt;
  final String currency;
  final List<String> sellerIds;
  final String stripeSessionId;
  final String shippingApprovalStatus;
  final bool shippingApprovalRequired;
  final int actualShippingCents;
  final int pendingTotalCents;
  // Payout tracking fields
  final List<SellerPayout> sellerPayouts;
  final bool confirmedByClient;
  final DateTime? confirmedAt;
  final int platformFeeTotalCents;
  final String payoutStatus;
  final Map<String, dynamic> ratings;

  OrderModel({
    required this.orderId,
    required this.userId,
    required this.items,
    required this.totalAmountCents,
    required this.subtotalCents,
    this.shippingCostCents = 0,
    this.taxAmountCents = 0,
    required this.orderStatus,
    required this.shippingAddress,
    required this.createdAt,
    required this.customerId,
    required this.customerEmail,
    required this.taxes,
    required this.currency,
    required this.sellerIds,
    required this.stripeSessionId,
    this.shippingApprovalStatus = ShippingApprovalStatusValues.notRequired,
    this.shippingApprovalRequired = false,
    this.actualShippingCents = 0,
    this.pendingTotalCents = 0,
    String? paymentStatus,
    this.sellerPayouts = const [],
    this.confirmedByClient = false,
    this.confirmedAt,
    this.platformFeeTotalCents = 0,
    this.payoutStatus = PayoutStatusValues.pending,
    this.ratings = const {},
  }) : paymentStatus = paymentStatus ?? PaymentStatus.awaitingPayment.value;

  factory OrderModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convert the list of items
    final itemsData = data[Fields.items] as List<dynamic>? ?? [];
    final items = itemsData.map<CartItemDetailModel>((item) {
      final map = item as Map<String, dynamic>;
      return CartItemDetailModel(
        productId: map[Fields.productId] ?? '',
        name: map[Fields.name] ?? '',
        description: map[Fields.description] ?? '',
        price: (map[Fields.price] ?? 0).toDouble(),
        imageUrls: List<String>.from(map[Fields.imageUrls] ?? []),
        quantity: (map[Fields.quantity] as num?)?.toInt() ?? 0,
        createdAt: (map[Fields.createdAt] as Timestamp?) ?? Timestamp.now(),
        sellerAddress: map[Fields.sellerAddress] != null ? Address.fromMap(map[Fields.sellerAddress] as Map<String, dynamic>) : Address.empty(),
        sellerId: map[Fields.sellerId] ?? '',
        sellerName: map[Fields.sellerName] ?? '',
        status: map[Fields.status] ?? DeliveryStatus.pending.value,
        trackingNumber: map[Fields.trackingNumber],
        confirmedByBuyer: map[Fields.confirmedByBuyer] ?? false,
        isDigital: map[Fields.isDigital] ?? false,
        isAgeRestricted: map[Fields.isAgeRestricted] ?? false,
      );
    }).toList();

    // Parse seller payouts (safe cast — skip malformed entries)
    final payoutsData = data[Fields.sellerPayouts] as List<dynamic>? ?? [];
    final sellerPayouts = payoutsData.whereType<Map<String, dynamic>>().map((p) => SellerPayout.fromMap(p)).toList();

    // Money — all cents
    final totalAmountCents = (data[Fields.totalAmountCents] as num?)?.toInt() ?? 0;
    final subtotalCents = (data[Fields.subtotalCents] as num?)?.toInt() ?? 0;
    final shippingCostCents = (data[Fields.shippingCostCents] as num?)?.toInt() ?? 0;
    final taxAmountCents = (data[Fields.taxAmountCents] as num?)?.toInt() ?? 0;
    final platformFeeTotalCents = (data[Fields.platformFeeTotalCents] as num?)?.toInt() ?? 0;

    final createdAtRaw = data[Fields.createdAt];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : createdAtRaw is DateTime
        ? createdAtRaw
        : DateTime.now();

    return OrderModel(
      orderId: data[Fields.orderId] ?? doc.id,
      userId: data[Fields.userId] ?? '',
      items: items,
      totalAmountCents: totalAmountCents,
      subtotalCents: subtotalCents,
      shippingCostCents: shippingCostCents,
      taxAmountCents: taxAmountCents,
      orderStatus: data[Fields.orderStatus] ?? OrderStatus.pending.value,
      paymentStatus: data[Fields.paymentStatus] ?? PaymentStatus.awaitingPayment.value,
      shippingAddress: Map<String, dynamic>.from(data[Fields.shippingAddress] ?? {}),
      createdAt: createdAt,
      customerId: data[Fields.customerId] ?? '',
      customerEmail: data[Fields.customerEmail] ?? '',
      taxes: Map<String, double>.from(data[Fields.taxes] ?? {}),
      currency: data[Fields.currency] ?? BusinessRules.defaultCurrency,
      sellerIds: List<String>.from(data[Fields.sellerIds] ?? []),
      stripeSessionId: data[Fields.stripeSessionId] ?? '',
      shippingApprovalStatus: data[Fields.shippingApprovalStatus] ?? ShippingApprovalStatus.notRequired.value,
      shippingApprovalRequired: data[Fields.shippingApprovalRequired] ?? false,
      actualShippingCents: (data[Fields.actualShippingCents] as num?)?.toInt() ?? 0,
      pendingTotalCents: (data[Fields.pendingTotalCents] as num?)?.toInt() ?? 0,
      sellerPayouts: sellerPayouts,
      confirmedByClient: data[Fields.confirmedByClient] ?? false,
      confirmedAt: (data[Fields.confirmedAt] as Timestamp?)?.toDate(),
      platformFeeTotalCents: platformFeeTotalCents,
      payoutStatus: data[Fields.payoutStatus] ?? PayoutStatusValues.pending,
      ratings: Map<String, dynamic>.from(data[Fields.ratings] ?? {}),
    );
  }
  factory OrderModel.fromMap(Map<String, dynamic> data) {
    // Convert the list of items
    final itemsData = data[Fields.items] as List<dynamic>? ?? [];
    final items = itemsData.map<CartItemDetailModel>((item) {
      final map = item as Map<String, dynamic>;
      return CartItemDetailModel(
        productId: map[Fields.productId] ?? '',
        name: map[Fields.name] ?? '',
        description: map[Fields.description] ?? '',
        price: (map[Fields.price] ?? 0).toDouble(),
        imageUrls: List<String>.from(map[Fields.imageUrls] ?? []),
        quantity: (map[Fields.quantity] as num?)?.toInt() ?? 0,
        createdAt: (map[Fields.createdAt] as Timestamp?) ?? Timestamp.now(),
        sellerAddress: map[Fields.sellerAddress] != null ? Address.fromMap(map[Fields.sellerAddress] as Map<String, dynamic>) : Address.empty(),
        sellerId: map[Fields.sellerId] ?? '',
        sellerName: map[Fields.sellerName] ?? '',
        status: map[Fields.status] ?? DeliveryStatus.pending.value,
        trackingNumber: map[Fields.trackingNumber],
        confirmedByBuyer: map[Fields.confirmedByBuyer] ?? false,
        isDigital: map[Fields.isDigital] ?? false,
        isAgeRestricted: map[Fields.isAgeRestricted] ?? false,
      );
    }).toList();

    // Parse seller payouts (safe cast — skip malformed entries)
    final payoutsData = data[Fields.sellerPayouts] as List<dynamic>? ?? [];
    final sellerPayouts = payoutsData.whereType<Map<String, dynamic>>().map((p) => SellerPayout.fromMap(p)).toList();

    // Money — all cents
    final totalAmountCents = (data[Fields.totalAmountCents] as num?)?.toInt() ?? 0;
    final subtotalCents = (data[Fields.subtotalCents] as num?)?.toInt() ?? 0;
    final shippingCostCents = (data[Fields.shippingCostCents] as num?)?.toInt() ?? 0;
    final taxAmountCents = (data[Fields.taxAmountCents] as num?)?.toInt() ?? 0;
    final platformFeeTotalCents = (data[Fields.platformFeeTotalCents] as num?)?.toInt() ?? 0;

    final createdAtRaw = data[Fields.createdAt];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : createdAtRaw is DateTime
        ? createdAtRaw
        : DateTime.now();

    return OrderModel(
      orderId: data[Fields.orderId] ?? '',
      userId: data[Fields.userId] ?? '',
      items: items,
      totalAmountCents: totalAmountCents,
      subtotalCents: subtotalCents,
      shippingCostCents: shippingCostCents,
      taxAmountCents: taxAmountCents,
      orderStatus: data[Fields.orderStatus] ?? OrderStatusValues.pending,
      paymentStatus: data[Fields.paymentStatus] ?? PaymentStatusValues.awaitingPayment,
      shippingAddress: Map<String, dynamic>.from(data[Fields.shippingAddress] ?? {}),
      createdAt: createdAt,
      customerId: data[Fields.customerId] ?? '',
      customerEmail: data[Fields.customerEmail] ?? '',
      taxes: Map<String, double>.from(data[Fields.taxes] ?? {}),
      currency: data[Fields.currency] ?? BusinessRules.defaultCurrency,
      sellerIds: List<String>.from(data[Fields.sellerIds] ?? []),
      stripeSessionId: data[Fields.stripeSessionId] ?? '',
      shippingApprovalStatus: data[Fields.shippingApprovalStatus] ?? ShippingApprovalStatus.notRequired.value,
      shippingApprovalRequired: data[Fields.shippingApprovalRequired] ?? false,
      actualShippingCents: (data[Fields.actualShippingCents] as num?)?.toInt() ?? 0,
      pendingTotalCents: (data[Fields.pendingTotalCents] as num?)?.toInt() ?? 0,
      sellerPayouts: sellerPayouts,
      confirmedByClient: data[Fields.confirmedByClient] ?? false,
      confirmedAt: (data[Fields.confirmedAt] is Timestamp?) ? (data[Fields.confirmedAt] as Timestamp?)?.toDate() : null,
      platformFeeTotalCents: platformFeeTotalCents,
      payoutStatus: data[Fields.payoutStatus] ?? PayoutStatusValues.pending,
      ratings: Map<String, dynamic>.from(data[Fields.ratings] ?? {}),
    );
  }

  /// Check if all delivered items have been confirmed by buyer
  bool get allItemsConfirmed {
    final deliveredItems = items.where((i) => i.status == DeliveryStatus.delivered.value);
    return deliveredItems.isNotEmpty && deliveredItems.every((i) => i.confirmedByBuyer);
  }

  /// Check if all sellers have been paid
  bool get allSellersPaid => sellerPayouts.isNotEmpty && sellerPayouts.every((p) => p.paid);

  double get shippingCost => shippingCostCents / 100.0;

  double get subtotal => subtotalCents / 100.0;

  double get taxAmount => taxAmountCents / 100.0;

  // Dollar getters derived from cents
  double get total => totalAmountCents / 100.0;

  // Convert OrderModel to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      Fields.userId: userId,
      Fields.items: items.map((item) => item.toMap()).toList(),
      Fields.totalAmountCents: totalAmountCents,
      Fields.subtotalCents: subtotalCents,
      Fields.shippingCostCents: shippingCostCents,
      Fields.taxAmountCents: taxAmountCents,
      Fields.orderStatus: orderStatus,
      Fields.shippingAddress: shippingAddress,
      Fields.createdAt: createdAt,
      Fields.customerId: customerId,
      Fields.customerEmail: customerEmail,
      Fields.taxes: taxes,
      Fields.currency: currency,
      Fields.sellerIds: sellerIds,
      Fields.sellerPayouts: sellerPayouts.map((p) => p.toMap()).toList(),
      Fields.shippingApprovalStatus: shippingApprovalStatus,
      Fields.shippingApprovalRequired: shippingApprovalRequired,
      Fields.actualShippingCents: actualShippingCents,
      Fields.pendingTotalCents: pendingTotalCents,
      Fields.confirmedByClient: confirmedByClient,
      if (confirmedAt != null) Fields.confirmedAt: Timestamp.fromDate(confirmedAt!),
      Fields.platformFeeTotalCents: platformFeeTotalCents,
      Fields.payoutStatus: payoutStatus,
      Fields.ratings: ratings,
    };
  }
}

/// Documentation for ProductCategories
class ProductCategories {
  final int categoryId;
  final String name;
  final IconData icon;

  ProductCategories({required this.categoryId, required this.name, required this.icon});
}

/// Documentation for ProductModel
class ProductModel {
  final String id;
  final String name;
  final double price;
  final List<String> imageUrls;
  final Address sellerAddress;
  final String description;
  final String sellerId;
  final int stockQuantity;
  final int categoryId;
  final double rating;
  final int ratingCount;
  final Timestamp? createdAt;
  final List<String> searchKeywords;
  // Shipping dimensions (optional - for better shipping calculation)
  final double? weightKg; // Weight in kilograms
  final double? lengthCm; // Length in centimeters
  final double? widthCm; // Width in centimeters
  final double? heightCm; // Height in centimeters
  final bool isLocalDeliveryOnly; // Restrict to buyers within 50km for same-day/next-day delivery
  final int estimatedShipDays; // Seller's estimated shipping time in days
  final String? taxCode; // Optional Stripe Tax Code (e.g. txcd_10000000)
  // Seller-defined delivery options (standard, express, same-day with custom times/prices)
  final List<SellerDeliveryOption> deliveryOptions;
  final bool isPerishable; // Food, flowers, etc. - affects same-day delivery logic
  final int minimumOrderQuantity;
  final bool freeShipping;
  final Timestamp? deletedAt;
  final bool isDigital; // True if product is digital (no shipping required)
  final bool isAgeRestricted; // True if buyer must confirm age 18+ before purchasing
  final String? digitalType; // 'software' | 'book'
  final Map<String, String>? digitalBuilds; // platform -> download URL (software only)
  final String? approvalRejectionReason;
  final String lifecycleStatus;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrls,
    required this.sellerAddress,
    required this.description,
    required this.stockQuantity,
    required this.categoryId,
    required this.sellerId,
    required List<String> keywords,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.createdAt,
    this.weightKg,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.isLocalDeliveryOnly = false,
    this.estimatedShipDays = 3,
    this.taxCode,
    List<SellerDeliveryOption>? deliveryOptions,
    this.isPerishable = false,
    this.minimumOrderQuantity = 1,
    this.freeShipping = false,
    this.deletedAt,
    this.isDigital = false,
    this.isAgeRestricted = false,
    this.digitalType,
    this.digitalBuilds,
    this.approvalRejectionReason,
    this.lifecycleStatus = 'draft',
  }) : deliveryOptions = deliveryOptions ?? SellerDeliveryOption.defaultOptions(),
       searchKeywords = keywords;

  factory ProductModel.fromDocument(DocumentSnapshot doc) {
    assert(doc.data() != null, 'Product document data is null');
    final data = doc.data() as Map<String, dynamic>;

    assert(data.containsKey(Fields.name), 'Product missing "name"');
    assert(data.containsKey(Fields.price), 'Product missing "price"');
    assert(data.containsKey(Fields.categoryId), 'Product missing "categoryId"');

    return ProductModel.fromMap({...data, Fields.productId: doc.id});
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    // Parse delivery options from Firestore
    List<SellerDeliveryOption>? parsedDeliveryOptions;
    if (map[Fields.deliveryOptions] != null && map[Fields.deliveryOptions] is List) {
      parsedDeliveryOptions = (map[Fields.deliveryOptions] as List)
          .whereType<Map>()
          .map((o) => SellerDeliveryOption.fromMap(o.cast<String, dynamic>()))
          .whereType<SellerDeliveryOption>()
          .toList();
    }

    return ProductModel(
      id: map[Fields.productId]?.toString() ?? '',
      name: map[Fields.name]?.toString() ?? '',
      price: _parseDouble(map[Fields.price]),
      imageUrls: _parseStringList(map[Fields.imageUrls]),
      sellerAddress: _parseAddress(map[Fields.sellerAddress]),
      description: map[Fields.description]?.toString() ?? '',
      categoryId: _parseInt(map[Fields.categoryId]),
      rating: _parseDouble(map[Fields.rating]),
      ratingCount: _parseInt(map[Fields.ratingCount]),
      createdAt: map[Fields.createdAt] != null ? _parseTimestamp(map[Fields.createdAt]) : null,
      sellerId: map[Fields.sellerId]?.toString() ?? '',
      keywords: _parseStringList(map[Fields.keywords]),
      stockQuantity: _parseInt(map[Fields.stockQuantity]),
      isDigital: map[Fields.isDigital] as bool? ?? false,
      isAgeRestricted: map[Fields.isAgeRestricted] as bool? ?? false,
      digitalType: map[Fields.digitalType]?.toString(),
      digitalBuilds: map[Fields.digitalBuilds] != null ? Map<String, String>.from(map[Fields.digitalBuilds] as Map) : null,
      approvalRejectionReason: map[Fields.approvalRejectionReason]?.toString(),
      lifecycleStatus: map[Fields.lifecycleStatus]?.toString() ?? ProductLifecycleStatusValues.draft,
      weightKg: map[Fields.weightKg] != null ? _parseDouble(map[Fields.weightKg]) : null,
      lengthCm: map[Fields.lengthCm] != null ? _parseDouble(map[Fields.lengthCm]) : null,
      widthCm: map[Fields.widthCm] != null ? _parseDouble(map[Fields.widthCm]) : null,
      heightCm: map[Fields.heightCm] != null ? _parseDouble(map[Fields.heightCm]) : null,
      isLocalDeliveryOnly: map[Fields.isLocalDeliveryOnly] ?? false,
      estimatedShipDays: _parseInt(map[Fields.estimatedShipDays]),
      taxCode: map[Fields.taxCode]?.toString(),
      deliveryOptions: parsedDeliveryOptions,
      isPerishable: map[Fields.isPerishable] ?? false,
      minimumOrderQuantity: _parseIntOr(map[Fields.minimumOrderQuantity], defaultValue: 1),
      freeShipping: map[Fields.freeShipping] ?? false,
      deletedAt: map[Fields.deletedAt] != null ? _parseTimestamp(map[Fields.deletedAt]) : null,
    );
  }

  /// Get enabled delivery options only
  List<SellerDeliveryOption> get enabledDeliveryOptions => deliveryOptions;

  /// Get delivery option by speed
  SellerDeliveryOption? getDeliveryOption(DeliverySpeed speed) => deliveryOptions.where((o) => o.type == speed.value).firstOrNull;

  Map<String, dynamic> toMap() {
    return {
      Fields.productId: id,
      Fields.name: name,
      Fields.price: price,
      Fields.sellerId: sellerId,
      Fields.imageUrls: imageUrls,
      Fields.sellerAddress: sellerAddress.toMap(),
      Fields.description: description,
      Fields.stockQuantity: stockQuantity,
      Fields.categoryId: categoryId,
      Fields.rating: rating,
      Fields.ratingCount: ratingCount,
      Fields.createdAt: createdAt,
      Fields.keywords: searchKeywords,
      if (weightKg != null) Fields.weightKg: weightKg,
      if (lengthCm != null) Fields.lengthCm: lengthCm,
      if (widthCm != null) Fields.widthCm: widthCm,
      if (heightCm != null) Fields.heightCm: heightCm,
      Fields.isLocalDeliveryOnly: isLocalDeliveryOnly,
      Fields.estimatedShipDays: estimatedShipDays,
      if (taxCode != null) Fields.taxCode: taxCode,
      Fields.deliveryOptions: deliveryOptions.map((o) => o.toMap()).toList(),
      Fields.isPerishable: isPerishable,
      Fields.minimumOrderQuantity: minimumOrderQuantity,
      Fields.freeShipping: freeShipping,
      Fields.isDigital: isDigital,
      Fields.isAgeRestricted: isAgeRestricted,
      Fields.lifecycleStatus: lifecycleStatus,
      if (deletedAt != null) Fields.deletedAt: deletedAt,
    };
  }

  static Address _parseAddress(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Address.fromMap(value);
    }
    return Address.fromMap({});
  }

  // Helper methods for parsing
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static int _parseIntOr(dynamic value, {required int defaultValue}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}

/// Model for tracking seller payouts per order (cents-based)
class SellerPayout {
  final String sellerId;
  final String? stripeAccountId;
  final int amountCents;
  final int platformFeeCents;
  final int netAmountCents;
  final String status; // 'pending', 'completed', 'failed'
  final String? stripeTransferId;
  final DateTime? payoutDate;
  final String? failureReason;

  SellerPayout({
    required this.sellerId,
    this.stripeAccountId,
    required this.amountCents,
    required this.platformFeeCents,
    required this.netAmountCents,
    this.status = PayoutStatusValues.pending,
    this.stripeTransferId,
    this.payoutDate,
    this.failureReason,
  });

  factory SellerPayout.fromMap(Map<String, dynamic> map) {
    return SellerPayout(
      sellerId: map[Fields.sellerId] ?? '',
      stripeAccountId: map[Fields.stripeAccountId],
      amountCents: (map[Fields.amountCents] as num?)?.toInt() ?? 0,
      platformFeeCents: (map[Fields.platformFeeCents] as num?)?.toInt() ?? 0,
      netAmountCents: (map[Fields.netAmountCents] as num?)?.toInt() ?? 0,
      status: map[Fields.status] ?? PayoutStatusValues.pending,
      stripeTransferId: map[Fields.stripeTransferId],
      payoutDate: _parseDateTime(map[Fields.payoutDate]),
      failureReason: map[Fields.failureReason],
    );
  }
  // Dollar getters
  double get amount => amountCents / 100.0;
  double get netAmount => netAmountCents / 100.0;
  bool get paid => status == PayoutStatusValues.completed;

  double get platformFee => platformFeeCents / 100.0;

  Map<String, dynamic> toMap() {
    return {
      Fields.sellerId: sellerId,
      Fields.stripeAccountId: stripeAccountId,
      Fields.amountCents: amountCents,
      Fields.platformFeeCents: platformFeeCents,
      Fields.netAmountCents: netAmountCents,
      Fields.status: status,
      Fields.stripeTransferId: stripeTransferId,
      if (payoutDate != null) Fields.payoutDate: Timestamp.fromDate(payoutDate!),
      Fields.failureReason: failureReason,
    };
  }
}

/// Documentation for UserModel
class UserModel {
  final String uid;
  final String email;
  final String name;
  final List<String> roles;
  final Address? address; // Changed to Address object
  final DateTime createdAt;
  final String? customerId; // Stripe customer ID
  final String? lastCheckoutSession;
  final String? lastOrderId;
  final DateTime? lastCheckoutTimestamp;
  // Stripe Connect fields for sellers
  final String? stripeAccountId; // Stripe Connect account ID
  final bool payoutsEnabled; // Can receive payouts
  final bool chargesEnabled; // Can accept charges
  final bool onboardingCompleted; // Completed Stripe onboarding
  final bool suspended;
  final DateTime? suspendedAt;
  final String paymentProvider; // stripe
  // Seller-specific fields
  final bool verified; // Manual verification by admin
  final String? verificationStatus; // pending, approved, rejected
  final String? platform; // alibaba, dhgate, direct
  final String? country; // Seller's country (CN, CA, etc.)
  final String? businessName; // Company name for business sellers
  final int payoutHoldDays; // Custom hold period before payout (default 7)
  final List<String> pendingRequirements; // Stripe requirements still needed
  // Premium subscription
  final bool isPremium;
  final DateTime? premiumSince;
  final DateTime? premiumExpiresAt;
  final String? stripeSubscriptionId;
  final bool notifyNewProducts;
  final bool notifyTrending;
  final bool mfaEnabled;
  /// Version of ToS the user last accepted (e.g. '1.0'). Null = accepted before versioning was added.
  final String? termsVersion;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.roles,
    this.address, // Made optional since not all users may have an address
    required this.createdAt,
    this.customerId,
    this.lastCheckoutSession,
    this.lastOrderId,
    this.lastCheckoutTimestamp,
    this.stripeAccountId,
    this.payoutsEnabled = false,
    this.chargesEnabled = false,
    this.onboardingCompleted = false,
    this.suspended = false,
    this.suspendedAt,
    this.paymentProvider = PaymentProviderValues.stripe,
    this.verified = false,
    this.verificationStatus,
    this.platform,
    this.country,
    this.businessName,
    this.payoutHoldDays = 7,
    this.pendingRequirements = const [],
    this.isPremium = false,
    this.premiumSince,
    this.premiumExpiresAt,
    this.stripeSubscriptionId,
    this.notifyNewProducts = false,
    this.notifyTrending = false,
    this.mfaEnabled = false,
    this.termsVersion,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map[Fields.uid]?.toString() ?? '',
      email: map[Fields.email]?.toString() ?? '',
      name: map[Fields.name]?.toString() ?? '',
      roles: List<String>.from(map[Fields.roles] ?? const []),
      address: map[Fields.address] != null ? Address.fromMap(map[Fields.address] as Map<String, dynamic>) : null,
      createdAt: _parseDateTime(map[Fields.createdAt]) ?? DateTime.now(),
      customerId: map[Fields.customerId] as String?,
      lastCheckoutSession: map[Fields.lastCheckoutSession] as String?,
      lastOrderId: map[Fields.lastOrderId] as String?,
      lastCheckoutTimestamp: _parseDateTime(map[Fields.lastCheckoutTimestamp]),
      // C-6: These fields are now exclusively mastered in seller_profiles/{uid}
      stripeAccountId: null,
      payoutsEnabled: false,
      chargesEnabled: false,
      onboardingCompleted: false,
      suspended: map[Fields.suspended] ?? false,
      suspendedAt: _parseDateTime(map[Fields.suspendedAt]),
      paymentProvider: map[Fields.paymentProvider] ?? PaymentProviderValues.stripe,
      // Seller-specific fields
      verified: map[Fields.verified] ?? false,
      verificationStatus: map[Fields.verificationStatus] as String?,
      platform: map[Fields.platform] as String?,
      country: map[Fields.country] as String?,
      businessName: map[Fields.businessName] as String?,
      payoutHoldDays: map[Fields.payoutHoldDays] ?? 7,
      pendingRequirements: List<String>.from(map[Fields.pendingRequirements] ?? const []),
      isPremium: map[Fields.isPremium] ?? false,
      premiumSince: _parseDateTime(map[Fields.premiumSince]),
      premiumExpiresAt: _parseDateTime(map[Fields.premiumExpiresAt]),
      stripeSubscriptionId: map[Fields.stripeSubscriptionId] as String?,
      notifyNewProducts: map[Fields.notifyNewProducts] ?? false,
      notifyTrending: map[Fields.notifyTrending] ?? false,
      mfaEnabled: map[Fields.mfaEnabled] ?? false,
      termsVersion: map[Fields.termsVersion] as String?,
    );
  }

  /// Check if user is a seller or admin with payouts enabled
  bool get canReceivePayouts => (roles.contains(UserRoles.seller) || roles.contains(UserRoles.admin)) && payoutsEnabled && onboardingCompleted;

  /// Check if user can sell products (seller/admin + onboarding + payouts/charges enabled)
  bool get canSell =>
      (roles.contains(UserRoles.seller) || roles.contains(UserRoles.admin)) && onboardingCompleted && chargesEnabled && payoutsEnabled && !suspended;

  /// Check if user has pending Stripe requirements to complete
  bool get hasPendingRequirements => pendingRequirements.isNotEmpty;

  // copyWith method for updating specific fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    List<String>? roles,
    Address? address,
    DateTime? createdAt,
    String? customerId,
    String? lastCheckoutSession,
    String? lastOrderId,
    DateTime? lastCheckoutTimestamp,
    String? stripeAccountId,
    bool? payoutsEnabled,
    bool? chargesEnabled,
    bool? onboardingCompleted,
    bool? suspended,
    DateTime? suspendedAt,
    String? paymentProvider,
    bool? verified,
    String? verificationStatus,
    String? platform,
    String? country,
    String? businessName,
    int? payoutHoldDays,
    List<String>? pendingRequirements,
    bool? isPremium,
    DateTime? premiumSince,
    DateTime? premiumExpiresAt,
    String? stripeSubscriptionId,
    bool? notifyNewProducts,
    bool? notifyTrending,
    bool? mfaEnabled,
    String? termsVersion,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      roles: roles ?? this.roles,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      customerId: customerId ?? this.customerId,
      lastCheckoutSession: lastCheckoutSession ?? this.lastCheckoutSession,
      lastOrderId: lastOrderId ?? this.lastOrderId,
      lastCheckoutTimestamp: lastCheckoutTimestamp ?? this.lastCheckoutTimestamp,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      payoutsEnabled: payoutsEnabled ?? this.payoutsEnabled,
      chargesEnabled: chargesEnabled ?? this.chargesEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      suspended: suspended ?? this.suspended,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      paymentProvider: paymentProvider ?? this.paymentProvider,
      verified: verified ?? this.verified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      platform: platform ?? this.platform,
      country: country ?? this.country,
      businessName: businessName ?? this.businessName,
      payoutHoldDays: payoutHoldDays ?? this.payoutHoldDays,
      pendingRequirements: pendingRequirements ?? this.pendingRequirements,
      isPremium: isPremium ?? this.isPremium,
      premiumSince: premiumSince ?? this.premiumSince,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      notifyNewProducts: notifyNewProducts ?? this.notifyNewProducts,
      notifyTrending: notifyTrending ?? this.notifyTrending,
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      termsVersion: termsVersion ?? this.termsVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      Fields.uid: uid,
      Fields.email: email,
      Fields.name: name,
      Fields.roles: roles,
      Fields.address: address?.toMap(),
      Fields.createdAt: Timestamp.fromDate(createdAt),
      Fields.customerId: customerId,
      if (lastCheckoutSession != null) Fields.lastCheckoutSession: lastCheckoutSession,
      if (lastOrderId != null) Fields.lastOrderId: lastOrderId,
      if (lastCheckoutTimestamp != null) Fields.lastCheckoutTimestamp: Timestamp.fromDate(lastCheckoutTimestamp!),
      if (stripeAccountId != null) Fields.stripeAccountId: stripeAccountId,
      Fields.payoutsEnabled: payoutsEnabled,
      Fields.chargesEnabled: chargesEnabled,
      Fields.onboardingCompleted: onboardingCompleted,
      Fields.suspended: suspended,
      if (suspendedAt != null) Fields.suspendedAt: Timestamp.fromDate(suspendedAt!),
      Fields.paymentProvider: paymentProvider,
      // Seller-specific fields
      Fields.verified: verified,
      if (verificationStatus != null) Fields.verificationStatus: verificationStatus,
      if (platform != null) Fields.platform: platform,
      if (country != null) Fields.country: country,
      if (businessName != null) Fields.businessName: businessName,
      Fields.payoutHoldDays: payoutHoldDays,
      if (pendingRequirements.isNotEmpty) Fields.pendingRequirements: pendingRequirements,
      Fields.mfaEnabled: mfaEnabled,
    };
  }

  // Helper method to get cart subcollection reference
  static CollectionReference getCartCollection(String userId) {
    return FirebaseFirestore.instance.collection(Collections.users).doc(userId).collection(Collections.cart);
  }

  // Helper method to get favorites subcollection reference
  static CollectionReference getFavoritesCollection(String userId) {
    return FirebaseFirestore.instance.collection(Collections.users).doc(userId).collection(Collections.favorites);
  }
}
