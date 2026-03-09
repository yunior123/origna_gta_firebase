// coverage:ignore-file
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/features/home/home_viewmodel.dart';
import 'package:origna_gta/features/seller/seller_account_status_viewmodel.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/screens/product_card_screen.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/mascot/canadian_moose.dart';
import 'package:origna_gta/widgets/mascot/mascot_provider.dart';
import 'package:origna_gta/widgets/mascot/moose_provider.dart';
import 'package:origna_gta/widgets/mascot/shop_mascot.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

/// Documentation for HomeScreen
class HomeScreen extends ConsumerStatefulWidget {
  final UserModel? userModel;
  const HomeScreen({super.key, this.userModel});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Add product button - only rebuilds when user profile changes
class _AddProductButton extends ConsumerWidget {
  const _AddProductButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final sellerStatus = ref.watch(sellerAccountStatusProvider);

    // If provider is loading, hide button temporarily (will rebuild when loaded)
    if (userProfileAsync.isLoading) {
      return const SizedBox.shrink();
    }

    final userProfile = userProfileAsync.valueOrNull;

    // Only show for sellers or admins
    final isSeller = userProfile?.roles.contains(UserRoles.seller) ?? false;
    final isAdmin = userProfile?.roles.contains(UserRoles.admin) ?? false;
    final isSuspended = userProfile?.suspended ?? false;

    final userCanAccess = isSeller || isAdmin;

    if (kDebugMode) {
      debugPrint(
        '🔍 _AddProductButton.build() → isSeller=$isSeller, isAdmin=$isAdmin, userCanAccess=$userCanAccess',
      );
    }

    // Show only for sellers/admins to match Firestore rules.
    if (!userCanAccess) {
      if (kDebugMode) debugPrint('🔍 User cannot access → returning shrink()');
      return const SizedBox.shrink();
    }

    // Check if seller account is fully verified (charges AND payouts enabled)
    final isVerified =
        sellerStatus.whenOrNull(data: (status) => status.isComplete) ?? false;

    // Must match Firestore rules: admin OR verified seller.
    final canAddProducts = isAdmin || isVerified;
    if (kDebugMode) {
      debugPrint('🔍 isVerified=$isVerified, canAddProducts=$canAddProducts');
    }

    return IconButton(
      key: const Key('home_add_product_button'),
      tooltip: 'home.add_product'.tr(),
      icon: const Icon(Icons.add_box_outlined, color: Colors.white),
      onPressed: () {
        if (isSuspended) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('auth.seller_suspended'.tr()),
              backgroundColor: DesignTokens.primary,
            ),
          );
          return;
        }
        if (!canAddProducts) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('auth.complete_stripe_verification'.tr()),
              backgroundColor: DesignTokens.primary,
            ),
          );
          return;
        }
        Navigator.pushNamed(context, AppRoutes.addProduct);
      },
    );
  }
}

// ============================================================================
// EXTRACTED WIDGETS - Each only rebuilds when its specific data changes
// ============================================================================

/// Cart badge - only rebuilds when cart count or auth state changes
class _CartBadge extends ConsumerStatefulWidget {
  const _CartBadge();

  @override
  ConsumerState<_CartBadge> createState() => _CartBadgeState();
}

class _CartBadgeState extends ConsumerState<_CartBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final cartCount = ref.watch(cartItemCountProvider);

    return MouseRegion(
      onEnter: (_) => _triggerAnimation(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: IconButton(
                  key: const Key('home_cart_button'),
                  tooltip: 'home.shopping_cart'.tr(),
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () async {
                    _triggerAnimation();
                    if (user == null) {
                      showLoginPrompt(context);
                      return;
                    }
                    if (!context.mounted) return;
                    final verified = await checkEmailVerifiedOrPrompt(context);
                    if (!verified) return;
                    if (!context.mounted) return;
                    Navigator.pushNamed(context, AppRoutes.cart);
                  },
                ),
              );
            },
          ),
          if (cartCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DesignTokens.primary,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: DesignTokens.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        cartCount > 99 ? '99+' : '$cartCount',
                        style: const TextStyle(
                          color: DesignTokens.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _triggerAnimation() {
    _controller.forward().then((_) => _controller.reverse());
  }
}

class _CategoryChips extends ConsumerWidget {
  final HomeViewModel homeNotifier;

  const _CategoryChips({required this.homeNotifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategoryId = ref.watch(
      homeViewModelProvider.select((state) => state.selectedCategoryId),
    );
    // All breakpoints: horizontal scroll — consistent UI across mobile/tablet/desktop
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: productCategories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : productCategories[index - 1];
          final isSelected = isAll
              ? selectedCategoryId == null
              : selectedCategoryId == category?.categoryId;
          return _buildChip(context, isAll, category, isSelected);
        },
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    bool isAll,
    ProductCategories? category,
    bool isSelected,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark
        ? DesignTokens.darkSurface
        : DesignTokens.surface;
    final unselectedText = isDark ? Colors.white : DesignTokens.textPrimary;
    final unselectedBorder = isDark
        ? DesignTokens.primary.withValues(alpha: 0.25)
        : DesignTokens.textSecondary.withValues(alpha: 0.3);
    return Semantics(
      label: isAll
          ? 'category-chip-all'
          : 'category-chip-${category!.categoryId}',
      child: Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 4),
        child: AnimatedContainer(
          duration: DesignTokens.durationNormal,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      DesignTokens.primary.withValues(alpha: 0.9),
                      DesignTokens.secondary.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: !isSelected ? unselectedBg : null,
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
            border: Border.all(
              color: isSelected ? DesignTokens.primary : unselectedBorder,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: DesignTokens.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                homeNotifier.onCategorySelected(
                  isAll ? null : category!.categoryId,
                );
              },
              borderRadius: BorderRadius.circular(DesignTokens.radius12),
              splashColor: Colors.white.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  isAll ? 'home.category_all'.tr() : category!.name.tr(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : unselectedText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isPaginating = false;

  @override
  Widget build(BuildContext context) {
    final homeNotifier = ref.read(homeViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine whether the management action row will be shown on product cards
    // so the grid aspect ratio can accommodate the extra row height.
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final canManageProducts =
        (userProfile?.roles.contains(UserRoles.admin) ?? false) ||
        (userProfile?.roles.contains(UserRoles.seller) ?? false);

    // Choix de la mascotte selon la parité du jour
    final day = DateTime.now().day;
    final showSparky = day % 2 == 0;
    final mascotController = showSparky
        ? ref.watch(mascotControllerProvider)
        : null;
    final mooseController = !showSparky
        ? ref.watch(mooseControllerProvider)
        : null;

    return Scaffold(
      appBar: _buildModernAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: DesignTokens.backgroundGradient(isDark: isDark),
        ),
        child: Stack(
          children: [
            // Main scrollable content — centered with max-width on desktop/web
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ResponsiveBreakpoints.contentMaxWidth,
                ),
                child: RefreshIndicator(
                  color: DesignTokens.primary,
                  onRefresh: () =>
                      ref.read(homeViewModelProvider.notifier).refresh(),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      // App Purpose Tagline
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text(
                            'home.tagline'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? DesignTokens.textDisabled
                                  : DesignTokens.textSecondary,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),

                      // Animated Search Bar + autocomplete overlay
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(
                            ResponsiveBreakpoints.getSpacing(
                              context,
                              SpacingSize.md,
                            ),
                          ),
                          child: _buildSearchBarWithOverlay(homeNotifier),
                        ),
                      ),

                      // Sort + Price filter row (GAP #1, GAP #2)
                      SliverToBoxAdapter(
                        child: _SortAndFilterRow(homeNotifier: homeNotifier),
                      ),

                      // Category Chips
                      SliverToBoxAdapter(
                        child: _CategoryChips(homeNotifier: homeNotifier),
                      ),

                      // Subcategory Chips (shown when a category is selected)
                      SliverToBoxAdapter(
                        child: _SubcategoryChips(homeNotifier: homeNotifier),
                      ),

                      // GAP #6 — Recently Viewed horizontal section
                      const SliverToBoxAdapter(child: _RecentlyViewedSection()),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: DesignTokens.spacing20),
                      ),

                      // Product Grid
                      _ProductGrid(
                        cardAspectRatio: _getCardAspectRatio(
                          context,
                          canManageProduct: canManageProducts,
                        ),
                        fallbackUserModel: widget.userModel,
                      ),

                      // Pagination Loader
                      const _PaginationLoader(),

                      // Footer with legal links
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 16,
                          ),
                          child: Column(
                            children: [
                              Divider(
                                color: DesignTokens.textSecondary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: [
                                  Semantics(
                                    label: 'btn-home-privacy-policy',
                                    button: true,
                                    child: TextButton(
                                      onPressed: () {
                                        // Navigate to privacy policy URL
                                        // On web: goes to /privacy-policy (OAuth compliance)
                                        // On mobile: shows in-app screen
                                        openPrivacyPolicy(context);
                                      },
                                      child: Text(
                                        'home.privacy_policy'.tr(),
                                        style: TextStyle(
                                          color: DesignTokens.primary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '|',
                                    style: TextStyle(
                                      color: DesignTokens.textSecondary
                                          .withValues(alpha: 0.4),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Semantics(
                                    label: 'btn-home-terms-of-service',
                                    button: true,
                                    child: TextButton(
                                      onPressed: () {
                                        // Navigate to terms URL
                                        // On web: goes to /terms-of-service (OAuth compliance)
                                        // On mobile: shows in-app screen
                                        openTermsOfService(context);
                                      },
                                      child: Text(
                                        'home.terms_of_service'.tr(),
                                        style: TextStyle(
                                          color: DesignTokens.primary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'home.copyright'.tr(
                                  namedArgs: {
                                    'year': DateTime.now().year.toString(),
                                  },
                                ),
                                style: TextStyle(
                                  color: DesignTokens.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ), // RefreshIndicator
              ), // ConstrainedBox
            ), // Align
            // --- MASCOTTE CANADIENNE --- (mobile + tablet only)
            if (!ResponsiveBreakpoints.isDesktop(context))
              Positioned(
                bottom: 12,
                right: 8,
                child: showSparky
                    ? ShopMascot(
                        controller: mascotController!,
                        size: 80,
                        showSpeechBubble: true,
                      )
                    : CanadianMoose(
                        controller: mooseController!,
                        size: 90,
                        showSpeechBubble: true,
                      ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // No root setState listener — suffix icon uses ValueListenableBuilder below
    _searchFocusNode.addListener(() {
      final homeNotifier = ref.read(homeViewModelProvider.notifier);
      homeNotifier.onSearchFocusChanged(_searchFocusNode.hasFocus);
    });
  }

  PreferredSizeWidget _buildModernAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              DesignTokens.gradientStart,
              DesignTokens.gradientMiddle,
              DesignTokens.gradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: DesignTokens.gradientStart.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ResponsiveBreakpoints.contentMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(
                                    DesignTokens.radius16,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.shopping_bag,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Semantics(
                          header: true,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Text(
                              key: Key('home_screen_title'),
                              'Origna GTA',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontSize: 24,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        _SettingsButton(),
                        _AddProductButton(),
                        _CartBadge(),
                      ],
                    ),
                  ],
                ),
              ),
            ), // ConstrainedBox
          ), // Align
        ),
      ),
    );
  }

  /// Search bar wrapped in an overlay-capable column for autocomplete (GAP #7).
  Widget _buildSearchBarWithOverlay(HomeViewModel homeNotifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showOverlay = ref.watch(
      homeViewModelProvider.select((s) => s.showSearchOverlay),
    );
    final recentSearches = ref.watch(
      homeViewModelProvider.select((s) => s.recentSearches),
    );
    final suggestions = ref.watch(
      homeViewModelProvider.select((s) => s.searchSuggestions),
    );
    final query = _searchController.text;

    // Decide what to show in the overlay
    final showRecent =
        showOverlay && query.isEmpty && recentSearches.isNotEmpty;
    final showSuggestions =
        showOverlay && query.length >= 2 && suggestions.isNotEmpty;
    final overlayVisible = showRecent || showSuggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cap search bar width on desktop to avoid stretching across full 1200px
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: GlassContainer(
              child: Semantics(
                label: 'input-home-search',
                child: TextField(
                  key: const Key('home_search_field'),
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: homeNotifier.onSearchChanged,
                  onSubmitted: (v) {
                    homeNotifier.onSearchSubmitted(v);
                    _searchFocusNode.unfocus();
                  },
                  style: TextStyle(
                    color: isDark ? Colors.white : DesignTokens.textPrimary,
                  ),
                  cursorColor: DesignTokens.primary,
                  decoration: InputDecoration(
                    hintText: 'home.search_products'.tr(),
                    hintStyle: TextStyle(color: DesignTokens.textSecondary),
                    prefixIcon: Icon(Icons.search, color: DesignTokens.primary),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return Semantics(
                          label: 'btn-clear-search',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: DesignTokens.textSecondary,
                              size: 20,
                            ),
                            tooltip: 'common.clear'.tr(),
                            onPressed: () {
                              _searchController.clear();
                              homeNotifier.onSearchChanged('');
                            },
                          ),
                        );
                      },
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radius12,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radius12,
                      ),
                      borderSide: BorderSide(
                        color: DesignTokens.textSecondary.withValues(
                          alpha: 0.2,
                        ),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radius12,
                      ),
                      borderSide: BorderSide(
                        color: DesignTokens.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ), // ConstrainedBox
        ), // Center
        // GAP #7 — Autocomplete dropdown
        if (overlayVisible)
          _SearchOverlay(
            isDark: isDark,
            showRecent: showRecent,
            recentSearches: recentSearches,
            suggestions: showSuggestions ? suggestions : [],
            onTap: (value) {
              _searchController.text = value;
              _searchController.selection = TextSelection.fromPosition(
                TextPosition(offset: value.length),
              );
              homeNotifier.onSearchSubmitted(value);
              _searchFocusNode.unfocus();
            },
            onClearRecent: homeNotifier.clearRecentSearches,
          ),
      ],
    );
  }

  /// Get responsive aspect ratio for product cards.
  /// [canManageProduct] = true when the management action row is visible
  /// (seller/admin), which adds ~32–48 dp and requires taller cards.
  double _getCardAspectRatio(
    BuildContext context, {
    bool canManageProduct = false,
  }) {
    if (canManageProduct) {
      return ResponsiveBreakpoints.getValue(
        context: context,
        mobile: ResponsiveBreakpoints.cardAspectMobileManage,
        mobilePlus: ResponsiveBreakpoints.cardAspectMobilePlusManage,
        tablet: ResponsiveBreakpoints.cardAspectTabletManage,
        desktop: ResponsiveBreakpoints.cardAspectDesktopManage,
      );
    }
    return ResponsiveBreakpoints.getValue(
      context: context,
      mobile: ResponsiveBreakpoints.cardAspectMobile,
      mobilePlus: ResponsiveBreakpoints.cardAspectMobilePlus,
      tablet: ResponsiveBreakpoints.cardAspectTablet,
      desktop: ResponsiveBreakpoints.cardAspectDesktop,
    );
  }

  void _onScroll() {
    // Guard: controller must be attached and not already paginating
    if (_isPaginating) return;
    if (!_scrollController.hasClients) return;

    try {
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 300) {
        final state = ref.read(homeViewModelProvider);
        if (state.products.isNotEmpty &&
            !state.isLoadingMore &&
            state.hasMore) {
          _isPaginating = true;
          ref.read(homeViewModelProvider.notifier).loadProducts().whenComplete(
            () {
              _isPaginating = false;
            },
          );
        }
      }
    } catch (_) {
      // Scroll position can throw during rapid layout changes — ignore
    }
  }
}

class _PaginationLoader extends ConsumerWidget {
  const _PaginationLoader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoadingMore = ref.watch(
      homeViewModelProvider.select((state) => state.isLoadingMore),
    );

    if (!isLoadingMore) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Semantics(
            label: 'common.loading_more'.tr(),
            liveRegion: true,
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [DesignTokens.primary, DesignTokens.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const ModernLoadingIndicator(
                strokeWidth: 3,
                color: Colors.white,
                centered: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductGrid extends ConsumerWidget {
  final double cardAspectRatio;
  final UserModel? fallbackUserModel;

  const _ProductGrid({
    required this.cardAspectRatio,
    required this.fallbackUserModel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      homeViewModelProvider.select((state) => state.isLoading),
    );
    final products = ref.watch(
      homeViewModelProvider.select((state) => state.displayedProducts),
    );
    final errorMessage = ref.watch(
      homeViewModelProvider.select((state) => state.errorMessage),
    );
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Error state with retry
    if (errorMessage != null && products.isEmpty && !isLoading) {
      return SliverToBoxAdapter(
        child: AnimatedEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'home.error_loading_products'.tr(),
          subtitle: errorMessage,
          action: TextButton.icon(
            onPressed: () =>
                ref.read(homeViewModelProvider.notifier).loadProducts(),
            icon: const Icon(Icons.refresh),
            label: Text('common.retry'.tr()),
          ),
        ),
      );
    }

    if (products.isEmpty && !isLoading) {
      return SliverToBoxAdapter(
        child: AnimatedEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'home.no_products_found'.tr(),
          subtitle: 'home.try_adjusting'.tr(),
          showMascot: true,
        ),
      );
    }

    if (isLoading) {
      final spacing = ResponsiveBreakpoints.getSpacing(context, SpacingSize.sm);
      final columns = ResponsiveBreakpoints.getGridColumns(context);
      return SliverPadding(
        padding: EdgeInsets.all(spacing),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cardAspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _ShimmerCard(isDark: isDark),
            childCount: columns * 2,
          ),
        ),
      );
    }

    final spacing = ResponsiveBreakpoints.getSpacing(context, SpacingSize.sm);

    // Build rank map: sort trending products by score desc, assign rank 1–3
    final rankMap = <String, int>{};
    final trendingProducts = products.where((p) => p.isTrending).toList()
      ..sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
    for (var i = 0; i < trendingProducts.length && i < 3; i++) {
      rankMap[trendingProducts[i].productId] = i + 1;
    }

    return SliverPadding(
      padding: EdgeInsets.all(spacing),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveBreakpoints.getGridColumns(context),
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: cardAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            return ProductCard(
              key: Key('product_card_${product.name}'),
              productId: product.productId,
              product: product,
              userModel: userProfile ?? fallbackUserModel,
              trendingRank: rankMap[product.productId],
            );
          },
          childCount: products.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
        ),
      ),
    );
  }
}

// ============================================================================
// GAP #6 — Recently Viewed horizontal section
// ============================================================================

class _RecentlyViewedSection extends ConsumerStatefulWidget {
  const _RecentlyViewedSection();

  @override
  ConsumerState<_RecentlyViewedSection> createState() =>
      _RecentlyViewedSectionState();
}

class _RecentlyViewedSectionState
    extends ConsumerState<_RecentlyViewedSection> {
  List<Product> _products = [];
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _products.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'home.recently_viewed'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : DesignTokens.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = _products[index];
              return SizedBox(
                width: 150,
                child: ProductCard(
                  key: Key('recently_viewed_${product.productId}'),
                  productId: product.productId,
                  product: product,
                  userModel: null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadRecentlyViewed();
  }

  Future<void> _loadRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(LocalStorageKeys.recentlyViewed);
      if (raw == null) {
        if (mounted) setState(() => _loaded = true);
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        if (mounted) setState(() => _loaded = true);
        return;
      }
      final ids = decoded.cast<String>().take(10).toList();
      if (ids.isEmpty) {
        if (mounted) setState(() => _loaded = true);
        return;
      }

      // Fetch products by IDs using the repository
      final repository = ref.read(productRepositoryProvider);
      final products = await repository.fetchProductsByIds(ids);

      // Keep the same order as the stored IDs
      final productMap = {for (final p in products) p.productId: p};
      final ordered = ids
          .where((id) => productMap.containsKey(id))
          .map((id) => productMap[id]!)
          .toList();

      if (mounted) {
        setState(() {
          _products = ordered;
          _loaded = true;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️  Failed to load recently viewed: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }
}

// ============================================================================
// GAP #7 — Search autocomplete overlay
// ============================================================================

class _SearchOverlay extends StatelessWidget {
  final bool isDark;
  final bool showRecent;
  final List<String> recentSearches;
  final List<String> suggestions;
  final ValueChanged<String> onTap;
  final VoidCallback onClearRecent;

  const _SearchOverlay({
    required this.isDark,
    required this.showRecent,
    required this.recentSearches,
    required this.suggestions,
    required this.onTap,
    required this.onClearRecent,
  });

  @override
  Widget build(BuildContext context) {
    final items = showRecent ? recentSearches : suggestions;
    final label = showRecent
        ? 'home.recent_searches'.tr()
        : 'home.suggestions'.tr();

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(DesignTokens.radius12),
      color: isDark ? DesignTokens.darkSurface : DesignTokens.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (showRecent)
                    TextButton(
                      onPressed: onClearRecent,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'home.clear_recent'.tr(),
                        style: TextStyle(
                          fontSize: 11,
                          color: DesignTokens.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final item in items)
              InkWell(
                onTap: () => onTap(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        showRecent
                            ? Icons.history_rounded
                            : Icons.search_rounded,
                        size: 16,
                        color: DesignTokens.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white
                                : DesignTokens.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Settings button - only rebuilds when auth state changes
class _SettingsButton extends ConsumerStatefulWidget {
  const _SettingsButton();

  @override
  ConsumerState<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends ConsumerState<_SettingsButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return MouseRegion(
      onEnter: (_) => _triggerAnimation(),
      child: AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value * 3.14159,
            child: Semantics(
              label: 'btn-home-settings',
              button: true,
              child: IconButton(
                key: const Key('home_settings_button'),
                tooltip: 'home.settings'.tr(),
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {
                  _triggerAnimation();
                  if (user == null) {
                    showLoginPrompt(
                      context,
                      text: "auth.sign_in_settings_required",
                    );
                    return;
                  }
                  Navigator.pushNamed(context, AppRoutes.profile);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _triggerAnimation() {
    _controller.forward().then((_) => _controller.reverse());
  }
}

class _ShimmerCard extends StatelessWidget {
  final bool isDark;
  const _ShimmerCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? DesignTokens.darkOutline : DesignTokens.outline,
      highlightColor: isDark
          ? DesignTokens.darkSurfaceVariant
          : DesignTokens.outlineVariant,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(DesignTokens.radius16),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 14,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 14,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GAP #1 + GAP #2 — Sort & Filter row
// ============================================================================

class _SortAndFilterRow extends ConsumerWidget {
  final HomeViewModel homeNotifier;

  const _SortAndFilterRow({required this.homeNotifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSort = ref.watch(
      homeViewModelProvider.select((s) => s.selectedSort),
    );
    final hasPriceFilter = ref.watch(
      homeViewModelProvider.select((s) => s.hasPriceFilter),
    );
    final minCents = ref.watch(
      homeViewModelProvider.select((s) => s.minPriceCents),
    );
    final maxCents = ref.watch(
      homeViewModelProvider.select((s) => s.maxPriceCents),
    );
    final canadaOnly = ref.watch(
      homeViewModelProvider.select((s) => s.canadaOnly),
    );

    final isSortActive = selectedSort != SortOption.relevance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          // Sort chip (GAP #1)
          Semantics(
            label: 'btn-home-sort',
            button: true,
            child: GestureDetector(
              onTap: () => _showSortSheet(context, selectedSort),
              child: AnimatedContainer(
                duration: DesignTokens.durationFast,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSortActive
                      ? DesignTokens.primary.withValues(alpha: 0.12)
                      : DesignTokens.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(DesignTokens.radius8),
                  border: Border.all(
                    color: isSortActive
                        ? DesignTokens.primary
                        : DesignTokens.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sort_rounded,
                      size: 14,
                      color: isSortActive
                          ? DesignTokens.primary
                          : DesignTokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSortActive
                          ? _sortLabel(selectedSort)
                          : 'home.sort_by'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSortActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSortActive
                            ? DesignTokens.primary
                            : DesignTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: isSortActive
                          ? DesignTokens.primary
                          : DesignTokens.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Price filter chip (GAP #2)
          Semantics(
            label: 'btn-home-price-filter',
            button: true,
            child: GestureDetector(
              onTap: () => _showPriceSheet(context, minCents, maxCents),
              child: AnimatedContainer(
                duration: DesignTokens.durationFast,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasPriceFilter
                      ? DesignTokens.secondary.withValues(alpha: 0.12)
                      : DesignTokens.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(DesignTokens.radius8),
                  border: Border.all(
                    color: hasPriceFilter
                        ? DesignTokens.secondary
                        : DesignTokens.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attach_money_rounded,
                      size: 14,
                      color: hasPriceFilter
                          ? DesignTokens.secondary
                          : DesignTokens.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      hasPriceFilter
                          ? 'home.filter_price_range'.tr(
                              namedArgs: {
                                'min': '\$${(minCents ?? 0) ~/ 100}',
                                'max': '\$${(maxCents ?? 50000) ~/ 100}',
                              },
                            )
                          : 'home.filter_price'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: hasPriceFilter
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: hasPriceFilter
                            ? DesignTokens.secondary
                            : DesignTokens.textSecondary,
                      ),
                    ),
                    if (hasPriceFilter) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: homeNotifier.clearPriceFilter,
                        child: Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: DesignTokens.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Canada Only toggle chip
          Semantics(
            label: 'btn-home-canada-only',
            button: true,
            toggled: canadaOnly,
            child: GestureDetector(
              onTap: homeNotifier.onToggleCanadaOnly,
              child: AnimatedContainer(
                duration: DesignTokens.durationFast,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: canadaOnly
                      ? DesignTokens.canadaRed.withValues(alpha: 0.12)
                      : DesignTokens.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(DesignTokens.radius8),
                  border: Border.all(
                    color: canadaOnly
                        ? DesignTokens.canadaRed
                        : DesignTokens.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🍁', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      'home.canada_only'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: canadaOnly
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: canadaOnly
                            ? DesignTokens.canadaRed
                            : DesignTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPriceSheet(BuildContext context, int? currentMin, int? currentMax) {
    // RangeSlider values in dollars (0–500), step handled by divisions
    double rangeMin = (currentMin ?? 0) / 100.0;
    double rangeMax = (currentMax ?? 50000) / 100.0;
    const double sliderMin = 0;
    const double sliderMax = 500;
    const int divisions = 100; // $5 steps

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radius16),
        ),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'home.filter_price'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        homeNotifier.clearPriceFilter();
                      },
                      child: Text(
                        'home.filter_price_any'.tr(),
                        style: TextStyle(
                          color: DesignTokens.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${rangeMin.toInt()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '\$${rangeMax.toInt()}${rangeMax >= sliderMax ? "+" : ""}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(
                    rangeMin.clamp(sliderMin, sliderMax),
                    rangeMax.clamp(sliderMin, sliderMax),
                  ),
                  min: sliderMin,
                  max: sliderMax,
                  divisions: divisions,
                  activeColor: DesignTokens.primary,
                  inactiveColor: DesignTokens.outline.withValues(alpha: 0.3),
                  onChanged: (values) {
                    setSheetState(() {
                      rangeMin = values.start;
                      rangeMax = values.end;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    label: 'btn-price-filter-apply',
                    button: true,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.primary,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final minC = (rangeMin * 100).round();
                        final maxC = (rangeMax * 100).round();
                        homeNotifier.onPriceFilterChanged(
                          minC > 0 ? minC : null,
                          maxC < sliderMax * 100 ? maxC : null,
                        );
                      },
                      child: Text('home.filter_apply'.tr()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context, SortOption current) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radius16),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  'home.sort_by'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Divider(height: 1),
              for (final option in SortOption.values)
                ListTile(
                  dense: true,
                  title: Text(
                    _sortLabel(option),
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: current == option
                      ? Icon(
                          Icons.check_rounded,
                          color: DesignTokens.primary,
                          size: 18,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    homeNotifier.onSortChanged(option);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _sortLabel(SortOption sort) {
    return switch (sort) {
      SortOption.relevance => 'home.sort_relevance'.tr(),
      SortOption.priceLowToHigh => 'home.sort_price_low'.tr(),
      SortOption.priceHighToLow => 'home.sort_price_high'.tr(),
      SortOption.newest => 'home.sort_newest'.tr(),
    };
  }
}

class _SubcategoryChips extends ConsumerWidget {
  final HomeViewModel homeNotifier;

  const _SubcategoryChips({required this.homeNotifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategoryId = ref.watch(
      homeViewModelProvider.select((state) => state.selectedCategoryId),
    );
    final selectedSubcategory = ref.watch(
      homeViewModelProvider.select((state) => state.selectedSubcategory),
    );

    if (selectedCategoryId == null) return const SizedBox.shrink();

    final subcategories = SubcategoryConstants.forCategoryId(
      selectedCategoryId,
    );
    if (subcategories.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          physics: const ClampingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: subcategories.length + 1, // +1 for "All"
          itemBuilder: (context, index) {
            final isAll = index == 0;
            final subcategory = isAll ? null : subcategories[index - 1];
            final isSelected = isAll
                ? selectedSubcategory == null
                : selectedSubcategory == subcategory;

            return Semantics(
              label: isAll
                  ? 'subcategory-chip-all'
                  : 'subcategory-chip-$subcategory',
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: AnimatedContainer(
                  duration: DesignTokens.durationFast,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DesignTokens.secondary.withValues(alpha: 0.15)
                        : DesignTokens.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(DesignTokens.radius8),
                    border: Border.all(
                      color: isSelected
                          ? DesignTokens.secondary
                          : DesignTokens.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(DesignTokens.radius8),
                      onTap: () => homeNotifier.onSubcategorySelected(
                        isAll ? null : subcategory,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          isAll ? 'home.category_all'.tr() : subcategory!,
                          style: TextStyle(
                            color: isSelected
                                ? DesignTokens.secondary
                                : DesignTokens.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
