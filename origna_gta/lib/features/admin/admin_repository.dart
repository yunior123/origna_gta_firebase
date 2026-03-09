import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/utils.dart';

abstract class AdminRepository {
  Future<void> approveProduct(String productId);
  Future<void> deleteProduct(String productId);
  Future<void> deleteReview(String reviewId);
  Future<void> disableAdminMfa(String code);
  Future<Map<String, dynamic>> enableAdminMfa();
  Future<UserModel?> fetchUserById(String userId);
  Future<Map<String, dynamic>> getPaymentProviders();
  Future<void> flagReview(String reviewId, {required bool flagged});
  Future<void> refundOrder(String orderId, {String reason = 'Admin refund'});
  Future<void> rejectProduct(String productId, String reason);
  Future<void> setUserSuspended(String userId, bool suspended);
  Future<void> updatePaymentProvider(String provider, bool enabled, {String? reason});
  Future<void> updateProductStock(String productId, int quantity);
  Future<void> updateUserRoles(String userId, {List<String> add, List<String> remove, String? reason});
  Future<Map<String, dynamic>> verifyAdminMfa(String code);
  Stream<List<OrderModel>> watchOrders({String? status, int limit});
  Stream<List<ProductModel>> watchProducts({int limit, String? sellerId});
  Stream<List<ProductModel>> watchPendingReviewProducts({int limit});
  Stream<List<Map<String, dynamic>>> watchReviews({bool flaggedOnly, bool hasPhotosOnly, int limit});
  Stream<List<UserModel>> watchSellers({int limit});
  Stream<List<UserModel>> watchUsers({int limit});
}

/// Documentation for FirebaseAdminRepository
class FirebaseAdminRepository implements AdminRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirebaseAdminRepository(this._firestore, this._functions);

  @override
  Future<void> approveProduct(String productId) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.adminApproveProduct).call({Fields.productId: productId});
  }

  @override
  Future<void> deleteProduct(String productId) async {
    // SECURITY FIX: Call Cloud Function instead of direct Firestore write
    // Backend enforces ownership, pending order checks, Algolia cleanup
    await _functions.httpsCallable(CloudFunctionEndpoints.deleteProduct).call({Fields.productId: productId});
  }

  @override
  Future<void> disableAdminMfa(String code) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.adminMfaDisable).call({ApiKeys.code: code});
  }

  @override
  Future<Map<String, dynamic>> enableAdminMfa() async {
    final result = await _functions.httpsCallable(CloudFunctionEndpoints.adminMfaEnroll).call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<UserModel?> fetchUserById(String userId) async {
    final doc = await _firestore.collection(Collections.users).doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromMap({Fields.uid: doc.id, ...doc.data()!});
  }

  @override
  Future<Map<String, dynamic>> getPaymentProviders() async {
    final result = await _functions.httpsCallable(CloudFunctionEndpoints.getPaymentProviders).call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<void> setUserSuspended(String userId, bool suspended) async {
    if (suspended) {
      await _functions.httpsCallable(CloudFunctionEndpoints.suspendSeller).call({Fields.sellerId: userId, ApiKeys.reason: 'Suspended by admin'});
    } else {
      // SECURITY FIX: Call Cloud Function instead of direct Firestore write
      // Backend enforces admin+MFA, reactivates products, logs audit
      await _functions.httpsCallable(CloudFunctionEndpoints.unsuspendSeller).call({Fields.sellerId: userId, ApiKeys.reason: 'Unsuspended by admin'});
    }
  }

  @override
  Future<void> updatePaymentProvider(String provider, bool enabled, {String? reason}) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.updatePaymentProvider).call({
      ApiKeys.provider: provider,
      ApiKeys.enabled: enabled,
      ApiKeys.reason: reason ?? '',
    });
  }

  @override
  Future<void> updateProductStock(String productId, int quantity) async {
    // SECURITY FIX: Call Cloud Function instead of direct Firestore write
    // Backend enforces admin+MFA, validates quantity, logs audit
    await _functions.httpsCallable(CloudFunctionEndpoints.adminUpdateProductStock).call({
      Fields.productId: productId,
      Fields.stockQuantity: quantity,
    });
  }

  @override
  Future<void> rejectProduct(String productId, String reason) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.adminRejectProduct).call({
      Fields.productId: productId,
      Fields.reason: reason,
    });
  }

  @override
  Future<void> updateUserRoles(String userId, {List<String> add = const [], List<String> remove = const [], String? reason}) async {
    // SECURITY FIX H-1: Call Cloud Function with server-side validation
    await _functions.httpsCallable(CloudFunctionEndpoints.updateUserRoles).call({Fields.targetUserId: userId, ApiKeys.add: add, ApiKeys.remove: remove, ApiKeys.reason: reason ?? 'No reason provided'});
  }

  @override
  Future<Map<String, dynamic>> verifyAdminMfa(String code) async {
    final result = await _functions.httpsCallable(CloudFunctionEndpoints.adminMfaVerify).call({ApiKeys.code: code});
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Stream<List<OrderModel>> watchOrders({String? status, int limit = 50}) {
    Query query = _firestore.collection(Collections.orders).orderBy(Fields.createdAt, descending: true).limit(limit);
    if (status != null && status != FilterValues.all) {
      query = query.where(Fields.orderStatus, isEqualTo: status);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OrderModel.fromMap({Fields.orderId: doc.id, ...data});
      }).toList();
    });
  }

  @override
  Stream<List<ProductModel>> watchProducts({int limit = 100, String? sellerId}) {
    Query query = _firestore.collection(Collections.products);
    if (sellerId != null && sellerId.isNotEmpty) {
      query = query.where(Fields.sellerId, isEqualTo: sellerId);
    }
    query = query.orderBy(Fields.createdAt, descending: true).limit(limit);
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ProductModel.fromMap({Fields.productId: doc.id, ...data});
      }).toList();
    });
  }

  @override
  Stream<List<ProductModel>> watchPendingReviewProducts({int limit = 200}) {
    return _firestore
        .collection(Collections.products)
        .where(Fields.lifecycleStatus, isEqualTo: ProductLifecycleStatusValues.underReview)
        .orderBy(Fields.createdAt, descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return ProductModel.fromMap({Fields.productId: doc.id, ...data});
            }).toList());
  }

  @override
  Stream<List<UserModel>> watchSellers({int limit = 100}) {
    return _firestore.collection(Collections.users).where(Fields.roles, arrayContains: UserRoles.seller).orderBy(Fields.createdAt, descending: true).limit(limit).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => UserModel.fromMap({Fields.uid: doc.id, ...doc.data()})).toList();
    });
  }

  @override
  Stream<List<UserModel>> watchUsers({int limit = 100}) {
    return _firestore.collection(Collections.users).orderBy(Fields.createdAt, descending: true).limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap({Fields.uid: doc.id, ...doc.data()})).toList();
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> watchReviews({bool flaggedOnly = false, bool hasPhotosOnly = false, int limit = 100}) {
    // FIX 2026-03-03: where() must precede orderBy() to avoid FailedPrecondition.
    // Composite indexes for (isFlagged+createdAt), (hasPhotos+createdAt), and
    // (isFlagged+hasPhotos+createdAt) are declared in firestore.indexes.json.
    Query query = _firestore.collection(Collections.productRatings);
    if (flaggedOnly) query = query.where(Fields.isFlagged, isEqualTo: true);
    if (hasPhotosOnly) query = query.where(Fields.hasPhotos, isEqualTo: true);
    query = query.orderBy(Fields.createdAt, descending: true).limit(limit);
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => <String, dynamic>{'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
    });
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.adminDeleteReview).call({Fields.reviewId: reviewId});
  }

  @override
  Future<void> flagReview(String reviewId, {required bool flagged}) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.adminFlagReview).call({Fields.reviewId: reviewId, Fields.flagged: flagged});
  }

  @override
  Future<void> refundOrder(String orderId, {String reason = 'Admin refund'}) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.adminRefundOrder).call({Fields.orderId: orderId, Fields.reason: reason});
  }
}
