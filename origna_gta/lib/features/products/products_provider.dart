import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/services/analytics_service.dart';

// ============================================================================
// FILTER STATE PROVIDERS
// ============================================================================

/// Full product details for all favorites — chunked into 30-ID batches and
/// fetched in parallel to avoid Firestore's whereIn limit.
final favoritedProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final favoriteIds = ref.watch(favoritesProvider).valueOrNull ?? {};
  if (favoriteIds.isEmpty) return [];

  final repository = ref.watch(productRepositoryProvider);
  final ids = favoriteIds.toList();

  // Chunk into 30-ID batches (Firestore whereIn limit)
  final chunks = [
    for (var i = 0; i < ids.length; i += 30) ids.sublist(i, min(i + 30, ids.length)),
  ];
  // Fetch chunks in parallel
  final results = await Future.wait(chunks.map((c) => repository.fetchProductsByIds(c)));
  return results.expand((x) => x).toList();
});

/// Favorites controller
final favoritesControllerProvider = Provider.autoDispose<FavoritesController>((ref) {
  return FavoritesController(ref);
});

// ============================================================================
// PRODUCTS PROVIDER
// ============================================================================

/// Stream of favorite product IDs for current user.
/// Uses [keepAlive] when a user is logged in to prevent the stream from being
/// disposed during transient rebuilds (e.g. category switches clear the product
/// grid which briefly removes all ProductCard watchers). Without this, the
/// stream restarts in AsyncLoading and the heart icon blinks.
final favoritesProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value({});

  // Keep the stream alive while a user is logged in so it survives
  // product-grid rebuilds (category change, search, etc.).
  // Store the link so we can close it on logout to prevent keepAlive leaks.
  final link = ref.keepAlive();
  ref.onDispose(link.close);

  final repository = ref.watch(productRepositoryProvider);
  return repository.watchFavorites(userId);
});

/// Convenience provider that uses current filter state
final filteredProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final categoryId = ref.watch(selectedCategoryProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  final query = ProductQuery(categoryId: categoryId, searchQuery: searchQuery);

  return ref.watch(productsProvider(query).future);
});

/// Fetches a single product by ID
final productByIdProvider = FutureProvider.autoDispose.family<Product?, String>((ref, productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.fetchProductById(productId);
});

/// Fetches a single product by slug
final productBySlugProvider = FutureProvider.autoDispose.family<Product?, String>((ref, slug) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductBySlug(slug);
});

/// Fetches products based on query parameters
final productsProvider = FutureProvider.autoDispose.family<List<Product>, ProductQuery>((ref, query) async {
  final repository = ref.watch(productRepositoryProvider);
  final result = await repository.fetchProducts(categoryId: query.categoryId, searchQuery: query.searchQuery, pageSize: query.limit);
  return result.products;
});

/// ({@macro similarProductsParams}) — fetches up to 8 active products in the
/// same category, excluding the current product. Used by the "Customers also
/// bought" row on the product detail screen.
final similarProductsProvider = FutureProvider.autoDispose.family<List<Product>, ({String excludeProductId, int categoryId})>(
  (ref, params) async {
    final repository = ref.watch(productRepositoryProvider);
    final result = await repository.fetchProducts(categoryId: params.categoryId, pageSize: 12);
    return result.products.where((p) => p.productId != params.excludeProductId).take(8).toList();
  },
);

/// Streams the count of unanswered product questions for a seller
final sellerUnansweredQaProvider = StreamProvider.autoDispose.family<int, String>((ref, sellerId) {
  final repository = ref.watch(productRepositoryProvider);
  return repository.watchUnansweredQuestionsCount(sellerId);
});

// ============================================================================
// FAVORITES PROVIDER
// ============================================================================

/// Current search query
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Currently selected category ID (null = all categories)
final selectedCategoryProvider = StateProvider.autoDispose<int?>((ref) => null);

/// Documentation for FavoritesController
class FavoritesController {
  final Ref _ref;

  FavoritesController(this._ref);

  ProductRepository get _repository => _ref.read(productRepositoryProvider);
  String? get _userId => _ref.read(userIdProvider);

  /// Check if product is favorited
  bool isFavorite(String productId) {
    final favorites = _ref.read(favoritesProvider).valueOrNull ?? {};
    return favorites.contains(productId);
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String productId, {String? productName, double? priceCad}) async {
    final userId = _userId;
    if (userId == null) return;
    final wasFavorited = isFavorite(productId);
    await _repository.toggleFavorite(userId, productId);
    if (productName != null && priceCad != null && !wasFavorited) {
      unawaited(AnalyticsService.logAddToWishlist(productId: productId, productName: productName, priceCad: priceCad));
    } else if (productName != null && wasFavorited) {
      unawaited(AnalyticsService.logRemoveFromWishlist(productId: productId, productName: productName));
    }
  }
}

/// Query parameters for products
class ProductQuery {
  final int? categoryId;
  final String searchQuery;
  final int limit;

  const ProductQuery({this.categoryId, this.searchQuery = '', this.limit = 20});

  @override
  int get hashCode => Object.hash(categoryId, searchQuery, limit);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductQuery && runtimeType == other.runtimeType && categoryId == other.categoryId && searchQuery == other.searchQuery && limit == other.limit;
}
