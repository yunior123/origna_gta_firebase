import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/services/algolia_service.dart';

import 'product_repository.dart';

// Export SortOption so callers importing algolia_product_repository can use it.
export 'package:origna_gta/core/schema/schema_constants.dart' show SortOption;

/// Algolia-based product repository with Firestore fallback
/// Provides fast search with automatic fallback to reliable Firestore queries
class AlgoliaProductRepository implements ProductRepository {
  final AlgoliaService _algoliaService;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  AlgoliaProductRepository(this._algoliaService, this._firestore, this._functions);

  @override
  Future<String> createProductAtomic(Product product, List<Uint8List> imageBytes, {List<String>? testImageUrls, String? bookSourceUrl}) async {
    throw UnimplementedError('createProductAtomic should be handled by FirebaseProductRepository');
  }

  @override
  Future<void> deleteProduct(String productId) async {
    // AUDIT FIX: Use Cloud Function for deletion — validates pending orders, syncs Algolia, etc.
    await _functions.httpsCallable(CloudFunctionEndpoints.deleteProduct).call({Fields.productId: productId});
  }

  @override
  Future<Product?> fetchProductById(String productId) async {
    try {
      final doc = await _firestore.collection(Collections.products).doc(productId).get();
      if (!doc.exists) return null;
      return Product.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching product: $e');
      return null;
    }
  }

  @override
  Future<ProductQueryResult> fetchProducts({
    String? searchQuery,
    int? categoryId,
    String? subcategory,
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
    SortOption sortOption = SortOption.relevance,
    int? minPriceCents,
    int? maxPriceCents,
  }) async {
    final hasTextSearch = searchQuery != null && searchQuery.isNotEmpty;

    // Route: text search + Algolia available → Algolia (with Firestore fallback)
    // Algolia handles sort via replica indexes; price filters via numericFilters.
    if (hasTextSearch && _algoliaService.isAvailable) {
      try {
        return await _searchWithAlgolia(
          searchQuery,
          categoryId,
          subcategory,
          pageSize,
          sortOption: sortOption,
          minPriceCents: minPriceCents,
          maxPriceCents: maxPriceCents,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  Algolia error, falling back to Firestore: $e');
        }
        // Fall through to Firestore
      }
    }

    // Route: everything else → Firestore (categories, browse, text when Algolia down)
    return await _fetchFromFirestore(
      searchQuery: searchQuery,
      categoryId: categoryId,
      subcategory: subcategory,
      lastDocument: lastDocument,
      pageSize: pageSize,
      sortOption: sortOption,
      minPriceCents: minPriceCents,
      maxPriceCents: maxPriceCents,
    );
  }

  @override
  Future<List<Product>> fetchProductsByIds(List<String> productIds) async {
    if (productIds.isEmpty) return [];

    final List<Product> results = [];
    for (int i = 0; i < productIds.length; i += 30) {
      final chunk = productIds.skip(i).take(30).toList();
      // F-79: No lifecycleStatus filter — inactive items show "unavailable" in cart.
      final snapshot = await _firestore.collection(Collections.products).where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snapshot.docs.map((doc) => Product.fromFirestore(doc)));
    }
    return results;
  }

  @override
  String generateProductId() {
    return _firestore.collection(Collections.products).doc().id;
  }

  @override
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(String query) async {
    // Could be enhanced with Algolia autocomplete in the future
    if (query.isEmpty) return [];

    final snapshot = await _firestore
        .collection(Collections.products)
        .where(Fields.keywords, arrayContains: query.toLowerCase())
        .where(Fields.lifecycleStatus, isEqualTo: ProductLifecycleStatusValues.active)
        .limit(5)
        .get();

    return snapshot.docs.map((doc) => {Fields.name: doc.data()[Fields.name], Fields.productId: doc.id}).toList();
  }

  @override
  Future<Product?> getProductBySlug(String slug) async {
    final snap = await _firestore.collection(Collections.products).where(Fields.slug, isEqualTo: slug).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return Product.fromFirestore(snap.docs.first);
  }

  @override
  Future<String?> getUploadUrl(String fileName) async {
    throw UnimplementedError('Image upload URLs should be handled by FirebaseProductRepository');
  }

  @override
  Future<Map<String, String>?> getUploadUrlInfo(String fileName) async {
    throw UnimplementedError('Image upload URLs should be handled by FirebaseProductRepository');
  }

  @override
  Future<Map<String, String>?> getUploadVideoUrlInfo(String fileName, String contentType) async {
    throw UnimplementedError('Video upload URLs should be handled by FirebaseProductRepository');
  }

  @override
  Future<void> submitRating(String orderId, String productId, int rating, {List<String>? reviewImageUrls, String? reviewText}) async {
    // Call backend Cloud Function for secure rating submission
    // Backend validates: auth, ownership, delivery status, duplicate check
    final payload = {Fields.orderId: orderId, Fields.productId: productId, Fields.rating: rating};
    if (reviewImageUrls != null && reviewImageUrls.isNotEmpty) {
      payload[Fields.reviewImageUrls] = reviewImageUrls;
    }
    if (reviewText != null && reviewText.isNotEmpty) {
      payload[Fields.reviewText] = reviewText;
    }
    await _functions.httpsCallable(CloudFunctionEndpoints.submitProductRating).call(payload);
  }

  @override
  Future<void> submitRatingAtomic(String orderId, String productId, int rating, {List<Uint8List>? reviewImages, String? reviewText}) async {
    final List<Map<String, dynamic>> imagesPayload = [];
    if (reviewImages != null) {
      for (final bytes in reviewImages) {
        imagesPayload.add({
          'contentType': 'image/jpeg',
          'data': base64Encode(bytes),
        });
      }
    }

    final payload = {
      Fields.orderId: orderId,
      Fields.productId: productId,
      Fields.rating: rating,
      Fields.review: reviewText ?? '',
      ApiKeys.images: imagesPayload,
    };

    await _functions.httpsCallable(CloudFunctionEndpoints.submitProductRatingAtomic).call(payload);
  }

  @override
  Future<void> toggleFavorite(String userId, String productId) async {
    final favRef = _firestore.collection(Collections.users).doc(userId).collection(Collections.favorites).doc(productId);

    // RACE CONDITION FIX: Use transaction to prevent duplicate writes from rapid taps
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(favRef);
      if (doc.exists) {
        transaction.delete(favRef);
      } else {
        transaction.set(favRef, {Fields.productId: productId, Fields.dateFavorited: FieldValue.serverTimestamp()});
      }
    });
  }

  @override
  Future<void> updateProduct(String productId, Map<String, dynamic> updates) async {
    // AUDIT FIX: Sanitize updates before Firestore write
    final sanitized = sanitizeProductForFirestore(updates);
    await _firestore.collection(Collections.products).doc(productId).update(sanitized);
  }

  @override
  Future<List<String>> uploadImages(List<Uint8List> images, String productId) async {
    throw UnimplementedError('Image upload should be handled by FirebaseProductRepository');
  }

  @override
  Future<String?> uploadProductVideo(XFile videoFile, String sellerId) async {
    throw UnimplementedError('Video upload should be handled by FirebaseProductRepository');
  }

  @override
  Future<List<String>> uploadReviewImages(List<Uint8List> images, String userId) async {
    throw UnimplementedError('Review image upload should be handled by FirebaseProductRepository');
  }

  @override
  Stream<Set<String>> watchFavorites(String userId) {
    return _firestore
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.favorites)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  @override
  Stream<int> watchUnansweredQuestionsCount(String sellerId) {
    return _firestore
        .collection(Collections.productQuestions)
        .where(Fields.sellerId, isEqualTo: sellerId)
        .where(Fields.isAnswered, isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<ProductQueryResult> _fetchFromFirestore({
    String? searchQuery,
    int? categoryId,
    String? subcategory,
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
    SortOption sortOption = SortOption.relevance,
    int? minPriceCents,
    int? maxPriceCents,
  }) async {
    if (kDebugMode) debugPrint('📍 Using Firestore fallback');

    Query<Map<String, dynamic>> query = _firestore.collection(Collections.products);

    // Apply filters
    query = query.where(Fields.lifecycleStatus, isEqualTo: ProductLifecycleStatusValues.active);

    if (categoryId != null) {
      query = query.where(Fields.categoryId, isEqualTo: categoryId);
    }

    if (subcategory != null && subcategory.isNotEmpty) {
      query = query.where(Fields.subcategory, isEqualTo: subcategory);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Firestore array-contains search on keywords
      final keywords = searchQuery.toLowerCase().split(' ');
      if (keywords.isNotEmpty) {
        query = query.where(Fields.keywords, arrayContains: keywords.first);
      }
    }

    if (minPriceCents != null) {
      query = query.where(Fields.priceCents, isGreaterThanOrEqualTo: minPriceCents);
    }
    if (maxPriceCents != null) {
      query = query.where(Fields.priceCents, isLessThanOrEqualTo: maxPriceCents);
    }

    switch (sortOption) {
      case SortOption.priceLowToHigh:
        query = query.orderBy(Fields.priceCents).orderBy(Fields.createdAt, descending: true);
      case SortOption.priceHighToLow:
        query = query.orderBy(Fields.priceCents, descending: true).orderBy(Fields.createdAt, descending: true);
      case SortOption.newest:
      case SortOption.relevance:
        query = query.orderBy(Fields.createdAt, descending: true);
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    // N+1 pattern: fetch one extra item to accurately determine if more exist
    query = query.limit(pageSize + 1);

    if (kDebugMode) {
      String projectId = 'unknown';
      try {
        projectId = _firestore.app.options.projectId;
      } catch (_) {}
      debugPrint('[AlgoliaProductRepository] Firestore Project ID: $projectId');
      debugPrint('[AlgoliaProductRepository] Querying products collection...');
    }

    final snapshot = await query.get(const GetOptions(source: Source.server));
    if (kDebugMode) debugPrint('[AlgoliaProductRepository] Fallback Snapshot length: ${snapshot.docs.length}');

    final hasMore = snapshot.docs.length > pageSize;
    final docsToMap = hasMore ? snapshot.docs.take(pageSize) : snapshot.docs;

    final products = docsToMap.map((doc) {
      if (kDebugMode) debugPrint('[AlgoliaProductRepository] Doc ${doc.id} name: ${doc.data()[Fields.name]}');
      return Product.fromFirestore(doc);
    }).toList();

    return ProductQueryResult(products: products, hasMore: hasMore, lastDocument: docsToMap.isNotEmpty ? docsToMap.last : null);
  }

  Future<ProductQueryResult> _searchWithAlgolia(
    String query,
    int? categoryId,
    String? subcategory,
    int pageSize, {
    SortOption sortOption = SortOption.relevance,
    int? minPriceCents,
    int? maxPriceCents,
  }) async {
    try {
      _algoliaService.search(
        query,
        categoryId: categoryId,
        subcategory: subcategory,
        sortOption: sortOption,
        minPriceCents: minPriceCents,
        maxPriceCents: maxPriceCents,
      );

      // Wait for response with timeout to prevent infinite hang
      // when Algolia is unreachable (e.g. emulator environment)
      final response = await _algoliaService.responses.first.timeout(const Duration(seconds: 5));

      // Convert Algolia hits to Product
      final products = response.hits.map((hit) {
        final data = AlgoliaService.hitToProductMap(hit);
        return Product.fromJson({...data, Fields.productId: data[Fields.productId] ?? ''});
      }).toList();

      if (kDebugMode) {
        debugPrint('✅ Algolia search returned ${products.length} products');
      }

      return ProductQueryResult(
        products: products,
        // Algolia doesn't support cursor-based pagination with Firestore
        // DocumentSnapshots, so signal no more pages to prevent infinite loops.
        hasMore: false,
        lastDocument: null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Algolia search failed: $e');
      rethrow;
    }
  }
}
