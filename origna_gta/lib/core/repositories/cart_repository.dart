import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/utils.dart';

abstract class CartRepository {
  Future<void> addToCart(String userId, String productId, int quantity, {
    String? variantId,
    String? variantTitle,
    Map<String, String>? variantOptions,
    String? variantSku,
  });
  Future<void> clearCart(String userId);

  /// Fetch the seller ID for a product to prevent self-purchase.
  /// Returns null if the product does not exist.
  Future<String?> getProductSellerId(String productId);

  /// Returns true if [variantId] exists and is active in the product's variants array.
  /// Returns false if the product doesn't exist or the variant is not found/inactive.
  Future<bool> isVariantValid(String productId, String variantId);

  Future<void> removeFromCart(String userId, String cartItemId);
  Future<void> updateBuyerNote(String userId, String cartItemId, String? note);
  Future<void> updateQuantity(String userId, String cartItemId, int quantity);

  Stream<List<CartItemModel>> watchCart(String userId);
}

/// Documentation for FirebaseCartRepository
class FirebaseCartRepository implements CartRepository {
  static const int maxCartItemQuantity = 99;
  static const int minCartItemQuantity = 1;
  final FirebaseFirestore _firestore;

  FirebaseCartRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _cartRef(String userId) =>
      _firestore.collection(Collections.users).doc(userId).collection(Collections.cart);

  @override
  Future<void> addToCart(String userId, String productId, int quantity, {
    String? variantId,
    String? variantTitle,
    Map<String, String>? variantOptions,
    String? variantSku,
  }) async {
    if (quantity < minCartItemQuantity) return;
    final cartRef = _cartRef(userId);

    // Use deterministic doc ID (productId + variantId) so we can do an atomic
    // document read inside the transaction instead of a non-transactional query.
    final docId = variantId != null ? '${productId}_$variantId' : productId;

    await _firestore.runTransaction((transaction) async {
      final docRef = cartRef.doc(docId);
      final existing = await transaction.get(docRef);

      if (existing.exists) {
        final currentQty = (existing.data()![Fields.quantity] as num?)?.toInt() ?? 0;
        final newQty = (currentQty + quantity).clamp(minCartItemQuantity, maxCartItemQuantity);
        transaction.update(docRef, {Fields.quantity: newQty});
      } else {
        final clampedQty = quantity.clamp(minCartItemQuantity, maxCartItemQuantity);
        transaction.set(docRef, CartModel(
          productId: productId,
          quantity: clampedQty,
          createdAt: DateTime.now(),
          variantId: variantId,
          variantTitle: variantTitle,
          variantOptions: variantOptions,
          variantSku: variantSku,
        ).toMap());
      }
    });
  }

  @override
  Future<void> clearCart(String userId) async {
    final cartRef = _cartRef(userId);
    final snapshot = await cartRef.get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<String?> getProductSellerId(String productId) async {
    final productDoc = await _firestore.collection(Collections.products).doc(productId).get();
    if (!productDoc.exists) return null;
    return productDoc.data()?[Fields.sellerId] as String?;
  }

  @override
  Future<bool> isVariantValid(String productId, String variantId) async {
    final productDoc = await _firestore.collection(Collections.products).doc(productId).get();
    if (!productDoc.exists) return false;
    final variants = (productDoc.data()?[Fields.variants] as List<dynamic>?) ?? [];
    return variants.any((v) {
      final map = v as Map<String, dynamic>?;
      return map != null &&
          map[Fields.variantId] == variantId &&
          (map['isActive'] as bool? ?? true);
    });
  }

  @override
  Future<void> removeFromCart(String userId, String cartItemId) async {
    await _cartRef(userId).doc(cartItemId).delete();
  }

  @override
  Future<void> updateBuyerNote(String userId, String cartItemId, String? note) async {
    final cartItemRef = _cartRef(userId).doc(cartItemId);
    if (note == null) {
      await cartItemRef.update({Fields.buyerNote: FieldValue.delete()}).catchError((_) {});
    } else {
      await cartItemRef.set({Fields.buyerNote: note}, SetOptions(merge: true));
    }
  }

  @override
  Future<void> updateQuantity(String userId, String cartItemId, int quantity) async {
    final cartItemRef = _cartRef(userId).doc(cartItemId);
    if (quantity < minCartItemQuantity) {
      await cartItemRef.delete();
    } else {
      await cartItemRef.update({Fields.quantity: quantity.clamp(minCartItemQuantity, maxCartItemQuantity)});
    }
  }

  @override
  Stream<List<CartItemModel>> watchCart(String userId) {
    return _cartRef(userId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CartItemModel.fromMap(doc.data(), docId: doc.id))
          .where((item) => item.quantity > 0)
          .toList();
    });
  }
}
