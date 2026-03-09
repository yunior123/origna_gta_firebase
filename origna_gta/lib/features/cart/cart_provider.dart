// coverage:ignore-file
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/cart_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/services/analytics_service.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final cartControllerProvider = Provider.autoDispose<CartController>((ref) {
  return CartController(ref);
});

final cartItemCountProvider = Provider.autoDispose<int>((ref) {
  final cartItems = ref.watch(cartItemsProvider);
  return cartItems.maybeWhen(data: (items) => items.fold(0, (total, item) => total + item.quantity), orElse: () => 0);
});

/// Provider for cart item creation date (used to avoid rebuilding item UI on quantity changes)
/// Keyed by cartItemDocId (format: productId or productId_variantId) to correctly
/// distinguish items with the same product but different variants.
final cartItemDateProvider = Provider.autoDispose.family<Timestamp?, String>((ref, cartItemDocId) {
  return ref.watch(
    cartItemsProvider.select((async) {
      return async.maybeWhen(data: (items) => items.where((i) => i.cartItemId == cartItemDocId).firstOrNull?.createdAt, orElse: () => null);
    }),
  );
});

/// Family provider for individual cart item details - cached by Riverpod
/// AUDIT FIX: Reads from batch-fetched cache instead of making individual
/// Firestore reads per item (N+1 query elimination).
/// Keyed by cartItemDocId (format: productId or productId_variantId) to correctly
/// distinguish items with the same product but different variants.
final cartItemDetailProvider = FutureProvider.autoDispose.family<CartItemDetailModel?, String>((ref, cartItemDocId) async {
  final createdAt = ref.watch(cartItemDateProvider(cartItemDocId));
  if (createdAt == null) return null;

  // Extract productId: doc ID is "productId" or "productId_variantId"
  // Firestore auto-IDs use Base62 (no underscores), so the first segment is always productId.
  final productId = cartItemDocId.split('_').first;

  // Pull from batch-fetched product cache (single whereIn query for all cart items)
  final productCache = await ref.watch(_cartProductsBatchProvider.future);
  final productData = productCache[productId];
  if (productData == null) return null;

  // Find the exact cart item to get variant info
  final cartItems = ref.read(cartItemsProvider).valueOrNull ?? [];
  final cartItem = cartItems.where((i) => i.cartItemId == cartItemDocId).firstOrNull;

  return CartItemDetailModel(
    productId: productId,
    name: productData[Fields.name] ?? '',
    description: productData[Fields.description] ?? '',
    price: (productData[Fields.price] ?? 0).toDouble(),
    imageUrls: List<String>.from(productData[Fields.imageUrls] ?? []),
    quantity: cartItem?.quantity ?? 1,
    createdAt: createdAt,
    sellerAddress: Address.fromMap(productData[Fields.sellerAddress] ?? {}),
    sellerId: productData[Fields.sellerId] ?? '',
    sellerName: productData[Fields.sellerName] ?? '',
    weightKg: productData[Fields.weightKg] != null ? (productData[Fields.weightKg] as num).toDouble() : null,
    lengthCm: productData[Fields.lengthCm] != null ? (productData[Fields.lengthCm] as num).toDouble() : null,
    widthCm: productData[Fields.widthCm] != null ? (productData[Fields.widthCm] as num).toDouble() : null,
    heightCm: productData[Fields.heightCm] != null ? (productData[Fields.heightCm] as num).toDouble() : null,
    isLocalDeliveryOnly: productData[Fields.isLocalDeliveryOnly] ?? false,
    isPerishable: productData[Fields.isPerishable] ?? false,
    estimatedShipDays: productData[Fields.estimatedShipDays] ?? 3,
    deliveryOptions: productData[Fields.deliveryOptions] != null
        ? (productData[Fields.deliveryOptions] as List)
              .whereType<Map>()
              .map((o) => SellerDeliveryOption.fromMap(o.cast<String, dynamic>()))
              .whereType<SellerDeliveryOption>()
              .toList()
        : [],
    minimumOrderQuantity: (productData[Fields.minimumOrderQuantity] as num?)?.toInt() ?? 1,
    freeShipping: productData[Fields.freeShipping] ?? false,
    isDigital: productData[Fields.isDigital] ?? false,
    variantId: cartItem?.variantId,
    variantTitle: cartItem?.variantTitle,
    variantOptions: cartItem?.variantOptions,
  );
});

// ============================================================================
// BATCH PRODUCT CACHE — fetches all cart product docs in one whereIn query
// ============================================================================

/// Provider that returns the current quantity for a specific cart item.
/// Keyed by [cartItemId] (not productId) so duplicate-product entries are tracked independently.
/// F-004 fix: using productId caused merged quantities when the same product appeared twice.
final cartItemQuantityProvider = Provider.autoDispose.family<AsyncValue<int>, String>((ref, cartItemId) {
  final itemsAsync = ref.watch(cartItemsProvider);
  return itemsAsync.whenData((items) {
    final matches = items.where((item) => item.cartItemId == cartItemId);
    return matches.isEmpty ? 0 : matches.first.quantity;
  });
});

// ============================================================================
// AUDIT FIX (C4): Unavailable cart items provider
// ============================================================================

// ============================================================================
// CART PROVIDERS
// ============================================================================

final cartItemsProvider = StreamProvider.autoDispose<List<CartItemModel>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value([]);

  return ref.watch(cartRepositoryProvider).watchCart(userId);
});

// ============================================================================
// CART DETAILS PROVIDER (with product info) - BATCH FETCH
// ============================================================================

/// Validates that all cart items can be shipped to the buyer's default address.
/// Returns a list of product IDs that are UN-SHIPPABLE to the current destination.
final cartShippingValidationProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final cartItems = await ref.watch(cartWithDetailsProvider.future);
  if (cartItems.isEmpty) return [];

  final userProfile = await ref.watch(userProfileProvider.future);
  final destinationState = userProfile?.address?.state;

  // Digital items always shippable.
  // Physical items: check deliveryOptions. If any option is availableNationwide or matches the state, it's shippable.
  final unshippable = <String>[];

  for (final item in cartItems) {
    if (item.isDigital) continue;

    final isLocalOnly = item.isLocalDeliveryOnly || item.isPerishable;
    final sellerState = item.sellerAddress.state;

    // If local-only and different province, it's un-shippable unless there's a nationwide option
    bool canShip = false;
    if (item.deliveryOptions.isEmpty) {
      // Fallback: if no delivery options defined, assume standard nationwide unless explicitly restricted
      canShip = !isLocalOnly || (sellerState == destinationState);
    } else {
      canShip = item.deliveryOptions.any(
        (opt) => opt.availableNationwide || (opt.type == DeliveryTypeValues.standard && !isLocalOnly) || (isLocalOnly && sellerState == destinationState),
      );
    }

    if (!canShip) {
      unshippable.add(item.productId);
    }
  }

  return unshippable;
});

/// Cart subtotal - computed from cartWithDetailsProvider
final cartSubtotalProvider = Provider.autoDispose<double>((ref) {
  final cartDetails = ref.watch(cartWithDetailsProvider);
  return cartDetails.maybeWhen(data: (items) => items.fold(0.0, (total, item) => total + (item.price * item.quantity)), orElse: () => 0.0);
});

/// Fetches cart items with full product details using the shared batch-fetch cache.
/// Reuses [_cartProductsBatchProvider] to avoid a duplicate Firestore whereIn query.
final cartWithDetailsProvider = FutureProvider.autoDispose<List<CartItemDetailModel>>((ref) async {
  final cartItems = ref.watch(cartItemsProvider);
  final productCache = await ref.watch(_cartProductsBatchProvider.future);

  return cartItems.when(
    data: (items) async {
      if (items.isEmpty) return [];

      final List<CartItemDetailModel> results = [];
      for (final cartItem in items) {
        final productData = productCache[cartItem.productId];
        if (productData != null && productData[Fields.lifecycleStatus] == ProductLifecycleStatusValues.active) {
          results.add(
            CartItemDetailModel(
              productId: cartItem.productId,
              name: productData[Fields.name] ?? '',
              description: productData[Fields.description] ?? '',
              price: (productData[Fields.price] ?? 0).toDouble(),
              imageUrls: List<String>.from(productData[Fields.imageUrls] ?? []),
              quantity: cartItem.quantity,
              createdAt: cartItem.createdAt,
              sellerAddress: Address.fromMap(productData[Fields.sellerAddress] ?? {}),
              sellerId: productData[Fields.sellerId] ?? '',
              sellerName: productData[Fields.sellerName] ?? 'Unknown Seller',
              weightKg: productData[Fields.weightKg] != null ? (productData[Fields.weightKg] as num).toDouble() : null,
              lengthCm: productData[Fields.lengthCm] != null ? (productData[Fields.lengthCm] as num).toDouble() : null,
              widthCm: productData[Fields.widthCm] != null ? (productData[Fields.widthCm] as num).toDouble() : null,
              heightCm: productData[Fields.heightCm] != null ? (productData[Fields.heightCm] as num).toDouble() : null,
              isLocalDeliveryOnly: productData[Fields.isLocalDeliveryOnly] ?? false,
              isPerishable: productData[Fields.isPerishable] ?? false,
              estimatedShipDays: productData[Fields.estimatedShipDays] ?? 3,
              deliveryOptions: productData[Fields.deliveryOptions] != null
                  ? (productData[Fields.deliveryOptions] as List)
                        .whereType<Map>()
                        .map((o) => SellerDeliveryOption.fromMap(o.cast<String, dynamic>()))
                        .whereType<SellerDeliveryOption>()
                        .toList()
                  : [],
              minimumOrderQuantity: (productData[Fields.minimumOrderQuantity] as num?)?.toInt() ?? 1,
              freeShipping: productData[Fields.freeShipping] ?? false,
              isDigital: productData[Fields.isDigital] ?? false,
              buyerNote: cartItem.buyerNote,
              variantId: cartItem.variantId,
              variantTitle: cartItem.variantTitle,
              variantOptions: cartItem.variantOptions,
            ),
          );
        }
      }

      return results;
    },
    loading: () => [],
    error: (e, st) => throw e, // Rethrow so cart screen can show retry banner
  );
});

// Provider for delivery instructions (stored during cart/checkout flow)
final deliveryInstructionsProvider = StateProvider.autoDispose<String>((ref) => '');

// ============================================================================
// SINGLE CART ITEM DETAIL PROVIDER (Family)
// ============================================================================

/// Exposes product IDs that are in the cart but no longer available in the catalog.
/// UI should use this to display "X items are no longer available" banners.
final unavailableCartItemsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final cartItems = ref.watch(cartItemsProvider);
  final productCache = await ref.watch(_cartProductsBatchProvider.future);

  return cartItems.maybeWhen(
    data: (items) {
      return items.where((item) => !productCache.containsKey(item.productId)).map((item) => item.productId).toList();
    },
    orElse: () => <String>[],
  );
});

/// Internal provider that batch-fetches product documents for all cart items.
/// Returns a `Map<productId, productData>` for O(1) lookup by [cartItemDetailProvider].
final _cartProductsBatchProvider = FutureProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final cartItems = ref.watch(cartItemsProvider);

  final productIds = cartItems.maybeWhen(data: (items) => items.map((i) => i.productId).toList(), orElse: () => <String>[]);

  if (productIds.isEmpty) return {};

  final Map<String, Map<String, dynamic>> cache = {};

  // Firestore whereIn limit is 30 — batch accordingly
  for (int i = 0; i < productIds.length; i += 30) {
    final chunk = productIds.skip(i).take(30).toList();
    try {
      final snapshot = await firestore.collection(Collections.products).where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snapshot.docs) {
        if (doc.exists) cache[doc.id] = doc.data();
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      // Continue with partial cache — better than empty cart
    }
  }

  return cache;
});

/// Documentation for CartController
class CartController {
  final Ref _ref;

  CartController(this._ref);

  CartRepository get _repository => _ref.read(cartRepositoryProvider);
  String? get _userId => _ref.read(userIdProvider);

  Future<bool> addToCart(String productId, int quantity, {String? variantId, String? productName, double? priceCad}) async {
    final userId = _userId;
    if (userId == null) return false;

    try {
      // Check if user is trying to buy their own product
      final sellerId = await _repository.getProductSellerId(productId);
      if (sellerId == null) return false;
      if (sellerId == userId) return false;

      // Validate variantId exists and is active in the product's variants array
      if (variantId != null) {
        final valid = await _repository.isVariantValid(productId, variantId);
        if (!valid) return false;
      }

      await _repository.addToCart(userId, productId, quantity, variantId: variantId);
      if (productName != null && priceCad != null) {
        unawaited(AnalyticsService.logAddToCart(productId: productId, productName: productName, priceCad: priceCad, quantity: quantity));
      }
      return true;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return false;
    }
  }

  /// Check if user can add this product (not their own)
  Future<bool> canAddToCart(String productId) async {
    final userId = _userId;
    if (userId == null) return false;

    try {
      final sellerId = await _repository.getProductSellerId(productId);
      if (sellerId == null) return false;
      return sellerId != userId;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return false;
    }
  }

  Future<void> clearCart() async {
    final userId = _userId;
    if (userId == null) return;
    await _repository.clearCart(userId);
  }

  void refreshCart() {
    _ref.invalidate(cartItemsProvider);
  }

  Future<void> removeFromCart(String cartItemId) async {
    final userId = _userId;
    if (userId == null) return;
    await _repository.removeFromCart(userId, cartItemId);
  }

  /// Saves a cart item to the user's favorites and removes it from the cart.
  /// Returns true on success, false on failure.
  Future<bool> saveForLater(String productId, String cartItemId) async {
    final userId = _userId;
    if (userId == null) return false;

    try {
      final firestore = _ref.read(firestoreProvider);
      await firestore.collection(Collections.users).doc(userId).collection(Collections.favorites).doc(productId).set({
        Fields.productId: productId,
        Fields.dateFavorited: FieldValue.serverTimestamp(),
      });
      await removeFromCart(cartItemId);
      return true;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return false;
    }
  }

  Future<void> updateBuyerNote(String cartItemId, String? note) async {
    final userId = _userId;
    if (userId == null) return;
    await _repository.updateBuyerNote(userId, cartItemId, note);
  }

  /// Updates the quantity of a cart item.
  /// Returns false if the update fails (e.g., item not found).
  Future<bool> updateQuantity(String cartItemId, int newQuantity) async {
    final userId = _userId;
    if (userId == null) return false;

    // Client-side stock check removed — it's non-transactional (race condition).
    // Server-side validation at checkout is properly transactional and authoritative.

    await _repository.updateQuantity(userId, cartItemId, newQuantity);
    return true;
  }
}
