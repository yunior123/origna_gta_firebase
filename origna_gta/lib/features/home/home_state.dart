import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart';

/// Sentinel used to distinguish "not passed" from "explicitly set to null".
class _Sentinel {
  const _Sentinel();
}

/// Documentation for HomeState
class HomeState {
  final List<Product> products;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final String searchQuery;
  final int? selectedCategoryId;
  final String? selectedSubcategory;
  final String? errorMessage;

  // GAP #1 — Sort
  final SortOption selectedSort;

  // GAP #2 — Price range filter (null = no filter applied)
  final int? minPriceCents;
  final int? maxPriceCents;

  // GAP #7 — Recent searches (persisted in SharedPreferences)
  final List<String> recentSearches;

  // GAP #7 — Search autocomplete suggestions (transient, not persisted)
  final List<String> searchSuggestions;

  // GAP #7 — Whether the search overlay is visible
  final bool showSearchOverlay;

  // Canada-only toggle: client-side filter for products shipping from Canada
  final bool canadaOnly;

  HomeState({
    this.products = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDocument,
    this.searchQuery = '',
    this.selectedCategoryId,
    this.selectedSubcategory,
    this.errorMessage,
    this.selectedSort = SortOption.relevance,
    this.minPriceCents,
    this.maxPriceCents,
    this.recentSearches = const [],
    this.searchSuggestions = const [],
    this.showSearchOverlay = false,
    this.canadaOnly = false,
  });

  /// Whether a price range filter is currently active.
  bool get hasPriceFilter => minPriceCents != null || maxPriceCents != null;

  /// Returns products filtered by the Canada-only toggle (client-side).
  List<Product> get displayedProducts {
    if (!canadaOnly) return products;
    return products
        .where((p) =>
            p.shipFromCountry?.toUpperCase() == 'CA' ||
            (p.shipFromCountries?.any((c) => c.toUpperCase() == 'CA') ?? false))
        .toList();
  }

  HomeState copyWith({
    List<Product>? products,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? lastDocument = const _Sentinel(),
    String? searchQuery,
    Object? selectedCategoryId = const _Sentinel(),
    Object? selectedSubcategory = const _Sentinel(),
    Object? errorMessage = const _Sentinel(),
    SortOption? selectedSort,
    Object? minPriceCents = const _Sentinel(),
    Object? maxPriceCents = const _Sentinel(),
    List<String>? recentSearches,
    List<String>? searchSuggestions,
    bool? showSearchOverlay,
    bool? canadaOnly,
  }) {
    return HomeState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: lastDocument is _Sentinel
          ? this.lastDocument
          : lastDocument as DocumentSnapshot?,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: selectedCategoryId is _Sentinel
          ? this.selectedCategoryId
          : selectedCategoryId as int?,
      selectedSubcategory: selectedSubcategory is _Sentinel
          ? this.selectedSubcategory
          : selectedSubcategory as String?,
      errorMessage: errorMessage is _Sentinel
          ? this.errorMessage
          : errorMessage as String?,
      selectedSort: selectedSort ?? this.selectedSort,
      minPriceCents: minPriceCents is _Sentinel
          ? this.minPriceCents
          : minPriceCents as int?,
      maxPriceCents: maxPriceCents is _Sentinel
          ? this.maxPriceCents
          : maxPriceCents as int?,
      recentSearches: recentSearches ?? this.recentSearches,
      searchSuggestions: searchSuggestions ?? this.searchSuggestions,
      showSearchOverlay: showSearchOverlay ?? this.showSearchOverlay,
      canadaOnly: canadaOnly ?? this.canadaOnly,
    );
  }
}
