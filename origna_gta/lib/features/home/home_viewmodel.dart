import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_state.dart';

final homeViewModelProvider = StateNotifierProvider.autoDispose<HomeViewModel, HomeState>((ref) {
  return HomeViewModel(ref);
});

/// Documentation for HomeViewModel
class HomeViewModel extends StateNotifier<HomeState> {
  final Ref _ref;
  Timer? _debounce;
  Timer? _suggestionDebounce;

  HomeViewModel(this._ref) : super(HomeState()) {
    _loadRecentSearches();
    loadProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _suggestionDebounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // GAP #7 — Recent searches persistence
  // ---------------------------------------------------------------------------

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(LocalStorageKeys.recentSearches);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final searches = decoded.cast<String>();
        if (!mounted) return;
        state = state.copyWith(recentSearches: searches);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️  Failed to load recent searches: $e');
    }
  }

  Future<void> _persistRecentSearches(List<String> searches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalStorageKeys.recentSearches, jsonEncode(searches));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️  Failed to persist recent searches: $e');
    }
  }

  Future<void> addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final updated = [
      query.trim(),
      ...state.recentSearches.where((s) => s != query.trim()),
    ].take(5).toList();
    if (!mounted) return;
    state = state.copyWith(recentSearches: updated);
    await _persistRecentSearches(updated);
  }

  Future<void> clearRecentSearches() async {
    if (!mounted) return;
    state = state.copyWith(recentSearches: []);
    await _persistRecentSearches([]);
  }

  // ---------------------------------------------------------------------------
  // GAP #7 — Search overlay visibility
  // ---------------------------------------------------------------------------

  void onSearchFocusChanged(bool focused) {
    if (!mounted) return;
    state = state.copyWith(
      showSearchOverlay: focused,
      searchSuggestions: focused ? state.searchSuggestions : [],
    );
  }

  void dismissSearchOverlay() {
    if (!mounted) return;
    state = state.copyWith(showSearchOverlay: false, searchSuggestions: []);
  }

  // ---------------------------------------------------------------------------
  // GAP #7 — Autocomplete suggestions via Algolia
  // ---------------------------------------------------------------------------

  void _fetchSuggestions(String query) {
    if (_suggestionDebounce?.isActive ?? false) _suggestionDebounce!.cancel();
    if (query.length < 2) {
      if (!mounted) return;
      state = state.copyWith(searchSuggestions: []);
      return;
    }
    _suggestionDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final algoliaService = _ref.read(algoliaServiceProvider);
        if (!algoliaService.isAvailable) return;

        algoliaService.search(query);
        final response = await algoliaService.responses.first
            .timeout(const Duration(seconds: 3));

        final names = response.hits
            .map((hit) => hit[Fields.name] as String?)
            .whereType<String>()
            .where((n) => n.isNotEmpty)
            .take(5)
            .toList();

        if (!mounted) return;
        state = state.copyWith(searchSuggestions: names);
      } catch (_) {
        // Suggestions are best-effort — swallow errors silently
      }
    });
  }

  // ---------------------------------------------------------------------------
  // GAP #1 — Sort option
  // ---------------------------------------------------------------------------

  void onSortChanged(SortOption sort) {
    if (!mounted) return;
    state = state.copyWith(
      selectedSort: sort,
      products: [],
      lastDocument: null,
      hasMore: true,
      isLoading: false,
      isLoadingMore: false,
      errorMessage: null,
    );
    loadProducts();
  }

  // ---------------------------------------------------------------------------
  // GAP #2 — Price range filter
  // ---------------------------------------------------------------------------

  void onPriceFilterChanged(int? minCents, int? maxCents) {
    if (!mounted) return;
    state = state.copyWith(
      minPriceCents: minCents,
      maxPriceCents: maxCents,
      products: [],
      lastDocument: null,
      hasMore: true,
      isLoading: false,
      isLoadingMore: false,
      errorMessage: null,
    );
    loadProducts();
  }

  void clearPriceFilter() => onPriceFilterChanged(null, null);

  // ---------------------------------------------------------------------------
  // Canada-only toggle (client-side display filter)
  // ---------------------------------------------------------------------------

  void onToggleCanadaOnly() {
    if (!mounted) return;
    state = state.copyWith(canadaOnly: !state.canadaOnly);
  }

  // ---------------------------------------------------------------------------
  // Core product loading
  // ---------------------------------------------------------------------------

  Future<void> loadProducts() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final isInitialLoad = state.products.isEmpty;

    if (isInitialLoad) {
      if (!mounted) return;
      state = state.copyWith(isLoading: true, errorMessage: null);
    } else {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: true, errorMessage: null);
    }

    try {
      final repository = _ref.read(productRepositoryProvider);

      if (kDebugMode) {
        debugPrint('🔍 Using repository: ${repository.runtimeType}');
        if (state.searchQuery.isNotEmpty) debugPrint('   Search query: "${state.searchQuery}"');
        if (state.selectedCategoryId != null) debugPrint('   Category filter: ${state.selectedCategoryId}');
        if (state.selectedSort != SortOption.relevance) debugPrint('   Sort: ${state.selectedSort}');
        if (state.hasPriceFilter) debugPrint('   Price: ${state.minPriceCents}–${state.maxPriceCents} cents');
      }

      final result = await repository.fetchProducts(
        searchQuery: state.searchQuery,
        categoryId: state.selectedCategoryId,
        subcategory: state.selectedSubcategory,
        lastDocument: state.lastDocument,
        sortOption: state.selectedSort,
        minPriceCents: state.minPriceCents,
        maxPriceCents: state.maxPriceCents,
      );

      if (kDebugMode) debugPrint('✅ Loaded ${result.products.length} products');
      if (!mounted) return;

      final effectiveHasMore = (isInitialLoad && result.products.isEmpty) ? false : result.hasMore;
      final existingIds = state.products.map((p) => p.productId).toSet();
      final newProducts = result.products.where((p) => !existingIds.contains(p.productId)).toList();

      state = state.copyWith(
        products: isInitialLoad ? result.products : [...state.products, ...newProducts],
        lastDocument: result.lastDocument ?? state.lastDocument,
        hasMore: effectiveHasMore,
        isLoading: false,
        isLoadingMore: false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading products: $e');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: AppError.getMessage(e, 'home.error_loading_products'.tr()),
        hasMore: state.products.isEmpty ? false : state.hasMore,
      );
    }
  }

  void onCategorySelected(int? categoryId) {
    if (!mounted) return;
    state = state.copyWith(
      selectedCategoryId: categoryId,
      selectedSubcategory: null,
      products: [],
      lastDocument: null,
      hasMore: true,
      isLoading: false,
      isLoadingMore: false,
      errorMessage: null,
    );
    loadProducts();
  }

  void onSubcategorySelected(String? subcategory) {
    if (!mounted) return;
    state = state.copyWith(
      selectedSubcategory: subcategory,
      products: [],
      lastDocument: null,
      hasMore: true,
      isLoading: false,
      isLoadingMore: false,
      errorMessage: null,
    );
    loadProducts();
  }

  void onSearchChanged(String value) {
    // Update suggestions in parallel while debouncing the full search
    _fetchSuggestions(value);

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      state = state.copyWith(
        searchQuery: value,
        products: [],
        lastDocument: null,
        hasMore: true,
        isLoading: false,
        isLoadingMore: false,
        errorMessage: null,
      );
      loadProducts();
    });
  }

  /// Called when user confirms a search (submits or taps suggestion).
  void onSearchSubmitted(String value) {
    if (value.trim().isEmpty) return;
    dismissSearchOverlay();
    addRecentSearch(value);
    onSearchChanged(value);
  }

  Future<void> refresh() async {
    state = state.copyWith(products: [], lastDocument: null, hasMore: true, isLoading: false, isLoadingMore: false);
    await loadProducts();
  }
}
