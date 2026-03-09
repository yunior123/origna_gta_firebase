// coverage:ignore-file
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cross_file/cross_file.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/services/conf_services.dart';

/// Shared sanitization for product data before writing to Firestore.
/// Used by both [FirebaseProductRepository] and [AlgoliaProductRepository].
Map<String, dynamic> sanitizeProductForFirestore(Map<String, dynamic> rawData, {bool ensureDateCreated = false}) {
  final data = Map<String, dynamic>.from(rawData);

  // productId is derived from document id; avoid storing a client-controlled field.
  data.remove(Fields.productId);
  // ratingCount and rating are server-managed via rating events; do not allow client write.
  data.remove(Fields.ratingCount);
  data.remove(Fields.rating);
  // sellerId and lifecycleStatus are server-controlled; strip to prevent client overwrite.
  data.remove(Fields.sellerId);
  data.remove(Fields.lifecycleStatus);

  // Firestore rules expect sellerAddress.apartment to be null OR non-empty string.
  // Address model defaults apartment to '', so normalize empty values to null.
  final sellerAddress = data[Fields.sellerAddress];
  if (sellerAddress is Map) {
    final address = Map<String, dynamic>.from(sellerAddress.cast<String, dynamic>());
    final apartment = address['apartment'];
    if (apartment is String && apartment.trim().isEmpty) {
      address['apartment'] = null;
    }
    data[Fields.sellerAddress] = address;
  }

  // Ensure createdAt is stored as a server timestamp (not a client-side value)
  // When ensureDateCreated is true (new products), always use FieldValue.serverTimestamp()
  // to prevent clock skew or manipulation.
  if (ensureDateCreated) {
    data[Fields.createdAt] = FieldValue.serverTimestamp();
  } else if (data.containsKey(Fields.createdAt)) {
    final createdAt = data[Fields.createdAt];
    if (createdAt is String) {
      try {
        data[Fields.createdAt] = Timestamp.fromDate(DateTime.parse(createdAt));
      } catch (_) {
        data[Fields.createdAt] = FieldValue.serverTimestamp();
      }
    } else if (createdAt is DateTime) {
      data[Fields.createdAt] = Timestamp.fromDate(createdAt);
    }
  }

  return data;
}

/// Documentation for FirebaseProductRepository
class FirebaseProductRepository implements ProductRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final http.Client _httpClient;
  final ConfigService _configService;

  FirebaseProductRepository(this._firestore, this._functions, {http.Client? httpClient, ConfigService? configService})
    : _httpClient = httpClient ?? http.Client(),
      _configService = configService ?? ConfigService();

  @override
  /// Creates a product atomically via Cloud Function, uploading images to R2 storage.
  ///
  /// [imageBytes] are compressed JPEG bytes for each image; [testImageUrls] bypasses
  /// upload in dev/emulator runs. Returns the Firestore document ID assigned server-side.
  /// Throws [Exception] if the function returns no productId.
  Future<String> createProductAtomic(
    Product product,
    List<Uint8List> imageBytes, {
    List<String>? testImageUrls,
    // bookSourceUrl is intentionally NOT on the Dart Product model (buyer-protected)
    // but must reach the backend so it can be stored server-side for book products.
    String? bookSourceUrl,
  }) async {
    final productJson = product.toJson()
      ..remove(Fields.productId)
      ..remove(Fields.imageUrls)
      ..remove(Fields.createdAt)
      ..remove(Fields.rating)
      ..remove(Fields.ratingCount);

    // Inject bookSourceUrl for digital book products — kept out of the Dart Product
    // model (buyer-protected: never read back by client) but required by Python
    // ProductCreate validation to store the download URL server-side.
    if (bookSourceUrl != null && bookSourceUrl.isNotEmpty) {
      productJson['bookSourceUrl'] = bookSourceUrl;
    }

    // Normalize apartment: empty string → null (matches sanitizeProductForFirestore)
    final sellerAddress = productJson[Fields.sellerAddress];
    if (sellerAddress is Map) {
      final addr = Map<String, dynamic>.from(sellerAddress.cast<String, dynamic>());
      if (addr['apartment'] is String && (addr['apartment'] as String).trim().isEmpty) {
        addr['apartment'] = null;
      }
      productJson[Fields.sellerAddress] = addr;
    }

    final images = imageBytes.map((bytes) => {'data': base64Encode(bytes), 'contentType': 'image/jpeg'}).toList();

    final payload = <String, dynamic>{'productData': productJson, 'images': images};
    if (testImageUrls != null && testImageUrls.isNotEmpty) {
      payload['testImageUrls'] = testImageUrls;
    }

    final result = await _functions.httpsCallable(CloudFunctionEndpoints.createProductAtomic).call(payload);

    final productId = result.data[Fields.productId] as String?;
    if (productId == null || productId.isEmpty) {
      throw Exception('create_product_atomic returned no productId');
    }
    return productId;
  }

  @override
  /// Permanently archives a product via Cloud Function, removing it from search and disabling purchases.
  ///
  /// Throws [FirebaseFunctionsException] if the caller is not the product owner or an admin.
  Future<void> deleteProduct(String productId) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.deleteProduct).call({Fields.productId: productId});
  }

  @override
  /// Fetches a single product by Firestore document ID.
  ///
  /// Returns null if the document does not exist or its [lifecycleStatus] is not `active`.
  Future<Product?> fetchProductById(String productId) async {
    final doc = await _firestore.collection(Collections.products).doc(productId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    if (data[Fields.lifecycleStatus] != ProductLifecycleStatusValues.active) return null;
    return Product.fromFirestore(doc);
  }

  @override
  /// Fetches a paginated list of active products with optional keyword and category filters.
  ///
  /// [lastDocument] is the pagination cursor returned by a previous call.
  /// [sortOption] affects the orderBy clause; price sorts require a Firestore composite index.
  /// [minPriceCents] / [maxPriceCents] add numeric range filters on [Fields.priceCents].
  /// Returns [ProductQueryResult] containing the page of products, the new cursor, and [hasMore].
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
    Query query = _firestore.collection(Collections.products);

    query = query.where(Fields.lifecycleStatus, isEqualTo: ProductLifecycleStatusValues.active);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.where(Fields.keywords, arrayContains: searchQuery.toLowerCase().trim());
    }

    if (categoryId != null) {
      query = query.where(Fields.categoryId, isEqualTo: categoryId);
    }

    if (subcategory != null && subcategory.isNotEmpty) {
      query = query.where(Fields.subcategory, isEqualTo: subcategory);
    }

    // GAP #2 — Price range filters
    if (minPriceCents != null) {
      query = query.where(Fields.priceCents, isGreaterThanOrEqualTo: minPriceCents);
    }
    if (maxPriceCents != null) {
      query = query.where(Fields.priceCents, isLessThanOrEqualTo: maxPriceCents);
    }

    // GAP #1 — Sort ordering
    switch (sortOption) {
      case SortOption.priceLowToHigh:
        query = query.orderBy(Fields.priceCents).orderBy(Fields.createdAt, descending: true);
      case SortOption.priceHighToLow:
        query = query.orderBy(Fields.priceCents, descending: true).orderBy(Fields.createdAt, descending: true);
      case SortOption.newest:
      case SortOption.relevance:
        query = query.orderBy(Fields.createdAt, descending: true);
    }

    // N+1 pattern: fetch one extra item to accurately determine if more exist
    query = query.limit(pageSize + 1);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();

    final hasMore = snapshot.docs.length > pageSize;
    final docsToMap = hasMore ? snapshot.docs.take(pageSize) : snapshot.docs;

    final products = docsToMap.map((doc) => Product.fromFirestore(doc)).toList();

    return ProductQueryResult(products: products, lastDocument: docsToMap.isNotEmpty ? docsToMap.last : null, hasMore: hasMore);
  }

  @override
  /// Batch-fetches products by ID, ignoring lifecycle status.
  ///
  /// Fetches in chunks of 30 to respect Firestore `whereIn` limits. Inactive products
  /// are intentionally included so cart items can surface an "unavailable" state rather
  /// than silently disappearing from the buyer's view (see F-79).
  Future<List<Product>> fetchProductsByIds(List<String> productIds) async {
    if (productIds.isEmpty) return [];

    final List<Product> results = [];
    // F-79: Fetch regardless of lifecycleStatus so inactive cart items show "unavailable"
    // instead of silently disappearing from the buyer's cart.
    for (int i = 0; i < productIds.length; i += 30) {
      final chunk = productIds.skip(i).take(30).toList();
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
    final String apiKey = _configService.geoapifyKey;
    final encodedQuery = Uri.encodeQueryComponent(query);
    final response = await _httpClient.get(
      Uri.parse('https://api.geoapify.com/v1/geocode/autocomplete?text=$encodedQuery&filter=countrycode:ca&apiKey=$apiKey'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['features'] ?? []);
    }
    return [];
  }

  @override
  /// Looks up an active product by its URL slug (e.g., `"organic-honey-a1b2"`).
  ///
  /// Returns null if no active product with that slug exists.
  Future<Product?> getProductBySlug(String slug) async {
    final snap = await _firestore
        .collection(Collections.products)
        .where(Fields.slug, isEqualTo: slug)
        .where(Fields.lifecycleStatus, isEqualTo: ProductLifecycleStatusValues.active)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Product.fromFirestore(snap.docs.first);
  }

  @override
  Future<String?> getUploadUrl(String fileName) async {
    final info = await getUploadUrlInfo(fileName);
    return info?['uploadUrl'];
  }

  @override
  Future<Map<String, String>?> getUploadUrlInfo(String fileName) async {
    final result = await _functions.httpsCallable(CloudFunctionEndpoints.uploadProductImages).call({
      'fileNames': [fileName],
      'contentTypes': ['image/jpeg'],
    });
    final uploadUrls = List<Map<String, dynamic>>.from(result.data['uploadUrls'] ?? []);
    if (uploadUrls.isEmpty) return null;
    return {'uploadUrl': uploadUrls[0]['uploadUrl'] as String, 'publicUrl': uploadUrls[0]['publicUrl'] as String};
  }

  @override
  Future<Map<String, String>?> getUploadVideoUrlInfo(String fileName, String contentType) async {
    final result = await _functions.httpsCallable(CloudFunctionEndpoints.uploadProductVideo).call({'fileName': fileName, 'contentType': contentType});
    final uploadUrl = result.data['uploadUrl'] as String?;
    final publicUrl = result.data['publicUrl'] as String?;
    if (uploadUrl == null || publicUrl == null) return null;
    return {'uploadUrl': uploadUrl, 'publicUrl': publicUrl};
  }

  @override
  /// Submits a product rating (1–5) and optional review via Cloud Function.
  ///
  /// [orderId] scopes the rating to a verified purchase. [reviewImageUrls] and
  /// [reviewText] are optional; omitting them submits a star-only rating.
  Future<void> submitRating(String orderId, String productId, int rating, {List<String>? reviewImageUrls, String? reviewText}) async {
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
  /// Atomic rating submission including image data (QA-H1).
  Future<void> submitRatingAtomic(String orderId, String productId, int rating, {List<Uint8List>? reviewImages, String? reviewText}) async {
    final List<Map<String, dynamic>> imagesPayload = [];
    if (reviewImages != null) {
      for (final bytes in reviewImages) {
        imagesPayload.add({'contentType': 'image/jpeg', 'data': base64Encode(bytes)});
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
  /// Toggles a product in the user's favorites list via Cloud Function.
  /// This ensures that favoriteCount on the product document is updated atomically.
  Future<void> toggleFavorite(String userId, String productId) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.toggleFavorite).call({Fields.productId: productId});
  }

  @override
  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    // F-90: Use Cloud Function for updates to ensure server-side validation.
    // Client-side denormalization is removed; the backend handles it via ProductUpdate validation.
    await _functions.httpsCallable(CloudFunctionEndpoints.updateProduct).call({Fields.productId: productId, 'productData': data});
  }

  @override
  /// Uploads product images to R2 and returns their public CDN URLs.
  ///
  /// [images] Raw JPEG bytes per image; [productId] is used to derive filenames.
  /// Performs best-effort cleanup of any already-uploaded files on partial failure to
  /// avoid R2 orphans. Throws [Exception] if any single image fails all retries.
  Future<List<String>> uploadImages(List<Uint8List> images, String productId) async {
    final uploadFutures = images.asMap().entries.map((entry) async {
      return await _uploadSingleImage(entry.value, productId, entry.key);
    });

    final results = await Future.wait(uploadFutures);
    final urls = results.whereType<String>().toList();
    if (urls.length != images.length) {
      // Partial failure — clean up successfully uploaded images to avoid R2 orphans
      if (urls.isNotEmpty) {
        try {
          await _functions.httpsCallable(CloudFunctionEndpoints.deleteProductImages).call({'publicUrls': urls});
        } catch (_) {
          // Best-effort cleanup; ignore errors so the original error is surfaced
        }
      }
      throw Exception('product.image_upload_failed'.tr());
    }
    return urls;
  }

  @override
  Future<String?> uploadProductVideo(XFile videoFile, String sellerId) async {
    final bytes = await videoFile.readAsBytes();
    final ext = videoFile.name.split('.').last.toLowerCase();
    String contentType = 'video/mp4';
    if (ext == 'mov') contentType = 'video/quicktime';
    if (ext == 'webm') contentType = 'video/webm';

    final fileName = "product_video_${sellerId}_${DateTime.now().millisecondsSinceEpoch}.$ext";
    final urlInfo = await getUploadVideoUrlInfo(fileName, contentType);

    if (urlInfo == null) throw Exception('product.video_upload_failed'.tr());

    final response = await _httpClient
        .put(Uri.parse(urlInfo['uploadUrl']!), body: bytes, headers: {"Content-Type": contentType})
        .timeout(const Duration(minutes: 5));

    if (response.statusCode == 200) {
      return urlInfo['publicUrl'];
    }
    throw Exception('Upload failed with status ${response.statusCode}');
  }

  @override
  Future<List<String>> uploadReviewImages(List<Uint8List> images, String userId) async {
    if (images.isEmpty) return [];
    final fileNames = List.generate(images.length, (i) => 'review_${userId}_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final contentTypes = List.filled(images.length, 'image/jpeg');

    final result = await _functions.httpsCallable(CloudFunctionEndpoints.uploadReviewImages).call({'fileNames': fileNames, 'contentTypes': contentTypes});

    final uploadUrls = List<Map<String, dynamic>>.from(result.data['uploadUrls'] ?? []);

    final uploadFutures = uploadUrls.asMap().entries.map((entry) async {
      final i = entry.key;
      final urlInfo = entry.value;
      try {
        final response = await _httpClient
            .put(Uri.parse(urlInfo['uploadUrl'] as String), body: images[i], headers: {'Content-Type': 'image/jpeg'})
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) return urlInfo['publicUrl'] as String;
        return null;
      } catch (_) {
        return null;
      }
    });

    final results = await Future.wait(uploadFutures);
    return results.whereType<String>().toList();
  }

  @override
  Stream<Set<String>> watchFavorites(String userId) {
    return _firestore
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.favorites)
        // FIX: orderBy must precede limit() so the 50-item cap is deterministic.
        // Without this, Firestore returns an arbitrary 50 docs — users with >50
        // favorites silently lose random favourites from the stream.
        .orderBy(Fields.dateFavorited, descending: true)
        .limit(BusinessRules.favoritesPageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  @override
  Stream<int> watchUnansweredQuestionsCount(String sellerId) {
    // FIX: cap at 500 to prevent an unbounded collection scan for high-volume
    // sellers. Badge counts above 500 are still displayed as '500+' by callers.
    return _firestore
        .collection(Collections.productQuestions)
        .where(Fields.sellerId, isEqualTo: sellerId)
        .where(Fields.isAnswered, isEqualTo: false)
        .limit(500)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // Sanitization is now handled by the shared top-level
  // sanitizeProductForFirestore() function in this file.

  Future<String?> _uploadSingleImage(Uint8List bytes, String productId, int index) async {
    const maxRetries = 3;
    // Derive MIME type and extension from magic bytes
    final mimeType = _detectImageMimeType(bytes);
    final ext = mimeType.split('/').last.replaceFirst('jpeg', 'jpg');
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final fileName = "product_${productId}_${index}_${DateTime.now().millisecondsSinceEpoch}.$ext";
        final urlInfo = await getUploadUrlInfo(fileName);

        if (urlInfo == null) throw Exception('Could not get upload URL');

        final response = await _httpClient
            .put(Uri.parse(urlInfo['uploadUrl']!), body: bytes, headers: {"Content-Type": mimeType})
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          return urlInfo['publicUrl'];
        }
        throw Exception('Upload failed with status ${response.statusCode}');
      } catch (e) {
        if (attempt == maxRetries) return null;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return null;
  }

  /// Detect image MIME type from magic bytes header.
  static String _detectImageMimeType(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg';
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'image/png';
    }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    // WebP: RIFF????WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    // GIF: GIF8
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
      return 'image/gif';
    }
    return 'image/jpeg'; // default fallback
  }
}

/// Documentation for ProductQueryResult
class ProductQueryResult {
  final List<Product> products;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  ProductQueryResult({required this.products, this.lastDocument, required this.hasMore});
}

abstract class ProductRepository {
  Future<String> createProductAtomic(Product product, List<Uint8List> imageBytes, {List<String>? testImageUrls, String? bookSourceUrl});
  Future<void> deleteProduct(String productId);
  Future<Product?> fetchProductById(String productId);
  Future<ProductQueryResult> fetchProducts({
    String? searchQuery,
    int? categoryId,
    String? subcategory,
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
    SortOption sortOption = SortOption.relevance,
    int? minPriceCents,
    int? maxPriceCents,
  });
  Future<List<Product>> fetchProductsByIds(List<String> productIds);
  String generateProductId();
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(String query);
  Future<Product?> getProductBySlug(String slug);
  Future<String?> getUploadUrl(String fileName);
  Future<Map<String, String>?> getUploadUrlInfo(String fileName);
  Future<Map<String, String>?> getUploadVideoUrlInfo(String fileName, String contentType);
  Future<void> submitRating(String orderId, String productId, int rating, {List<String>? reviewImageUrls, String? reviewText});
  Future<void> submitRatingAtomic(String orderId, String productId, int rating, {List<Uint8List>? reviewImages, String? reviewText});
  Future<void> toggleFavorite(String userId, String productId);
  Future<void> updateProduct(String productId, Map<String, dynamic> data);
  Future<List<String>> uploadImages(List<Uint8List> images, String productId);
  Future<String?> uploadProductVideo(XFile videoFile, String sellerId);
  Future<List<String>> uploadReviewImages(List<Uint8List> images, String userId);
  Stream<Set<String>> watchFavorites(String userId);
  Stream<int> watchUnansweredQuestionsCount(String sellerId);
}
