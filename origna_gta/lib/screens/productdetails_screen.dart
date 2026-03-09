// coverage:ignore-file
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/features/products/product_detail_viewmodel.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/features/products/stock_notification_provider.dart';
import 'package:origna_gta/features/qa/qa_provider.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/models/generated/product_models.dart';
import 'package:origna_gta/models/qa_model.dart';
import 'package:origna_gta/screens/product_card_screen.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:origna_gta/widgets/premium_paywall_widget.dart';
import 'package:origna_gta/widgets/rating_histogram.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

/// Stream of up to 10 most recent product ratings, ordered by createdAt desc.
final _productRatingsProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, productId) => ref
      .watch(firestoreProvider)
      .collection(Collections.productRatings)
      .where(Fields.productId, isEqualTo: productId)
      .orderBy(Fields.createdAt, descending: true)
      .limit(10)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {...d.data(), Fields.ratingId: d.id}).toList()),
);

// ─── Flutter Previews ────────────────────────────────────────────────────────

/// Documentation for ProductDetailScreen
class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  final Map<String, dynamic>? product; // Optional initial data

  const ProductDetailScreen({super.key, required this.productId, this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(productId));
    final viewModel = ref.read(productDetailViewModelProvider.notifier);
    final state = ref.watch(productDetailViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final product = productAsync.valueOrNull;
    final selectedVariantId = state.selectedVariantId;
    final matchedVariant = product?.hasVariants == true && selectedVariantId != null
        ? product!.variants.where((v) => v.variantId == selectedVariantId).firstOrNull
        : null;

    final displayPrice = matchedVariant != null ? (matchedVariant.priceCents ?? 0) / 100.0 : (product?.price ?? 0.0);
    final isOutOfStock = (matchedVariant?.stockQuantity ?? (product?.stockQuantity ?? 1)) <= 0;

    final profileSnapshot = ref.watch(userProfileProvider).valueOrNull;
    final canManage = product != null && (profileSnapshot?.uid == product.sellerId || profileSnapshot?.roles.contains(UserRoles.admin) == true);

    return Scaffold(
      // Sticky bottom CTA — only visible on mobile when product is loaded, user is a buyer,
      // and the product has NO variants. Variant products use the in-body _VariantAndCartSection
      // which has full variant-aware stock state. Showing a sticky CTA for variant products
      // would use product-level stockQuantity and no variantKey, causing the wrong stock check
      // and subscribing the user to a product-level (variant-unscoped) notification.
      bottomNavigationBar: product != null && !canManage && !product.hasVariants && MediaQuery.of(context).size.width < ResponsiveBreakpoints.tablet
          ? _StickyBottomCTA(product: product, isOutOfStock: isOutOfStock, isDark: isDark)
          : null,
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return AnimatedEmptyState(icon: Icons.inventory_2_outlined, title: 'product.not_found'.tr(), subtitle: 'product.not_found_desc'.tr());
          }
          // Trigger seller-metrics fetch + record recently viewed once product is available
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(productDetailViewModelProvider.notifier).fetchSellerMetrics(product.sellerId);
            _recordRecentlyViewed(productId);
          });
          final imageUrls = product.imageUrls;
          final hasVideo = product.videoUrl != null && product.videoUrl!.isNotEmpty;
          final totalMediaCount = imageUrls.length + (hasVideo ? 1 : 0);
          final isWideScreen = MediaQuery.of(context).size.width >= ResponsiveBreakpoints.tablet;

          // --- Image gallery builder (shared between mobile/desktop) ---
          Widget buildImageGallery({required double height}) {
            return Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [DesignTokens.primary.withValues(alpha: 0.1), DesignTokens.secondary.withValues(alpha: 0.1)],
                ),
                borderRadius: isWideScreen ? BorderRadius.circular(DesignTokens.radius16) : null,
              ),
              clipBehavior: isWideScreen ? Clip.antiAlias : Clip.none,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrls.isNotEmpty || hasVideo
                      ? PageView.builder(
                          itemCount: totalMediaCount,
                          onPageChanged: viewModel.setImageIndex,
                          itemBuilder: (context, index) {
                            if (hasVideo && index == 0) {
                              return Semantics(
                                label: 'btn-play-video',
                                button: true,
                                child: GestureDetector(
                                  onTap: () => _showVideoPlayer(context, product.videoUrl!),
                                  child: Container(
                                    color: Colors.black87,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (imageUrls.isNotEmpty)
                                          Opacity(
                                            opacity: 0.5,
                                            child: CachedNetworkImage(
                                              imageUrl: imageUrls[0],
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: DesignTokens.primary.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                                          ),
                                          child: const Icon(Icons.play_arrow_rounded, size: 64, color: Colors.white),
                                        ),
                                        Positioned(
                                          bottom: 40,
                                          child: Text(
                                            'product.watch_video'.tr(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            final imgIndex = hasVideo ? index - 1 : index;
                            return Semantics(
                              label: 'product.image_semantics'.tr(namedArgs: {'n': '${imgIndex + 1}', 'total': '${imageUrls.length}'}),
                              button: true,
                              image: true,
                              child: GestureDetector(
                                onTap: () => _showImageDialog(context, imageUrls, imgIndex),
                                child: SizedBox.expand(
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrls[imgIndex],
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: DesignTokens.outlineVariant,
                                      highlightColor: DesignTokens.surface,
                                      child: Container(color: Colors.white),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle],
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 88,
                                          height: 88,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withValues(alpha: 0.12),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
                                          ),
                                          child: const Icon(Icons.camera_alt_outlined, size: 40, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle],
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_outlined, size: 40, color: Colors.white),
                            ),
                          ),
                        ),
                  Positioned(bottom: 16, left: 0, right: 0, child: _ImageDots(imageCount: totalMediaCount)),
                ],
              ),
            );
          }

          // --- Product info column (shared between mobile/desktop) ---
          Widget buildProductInfo() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [DesignTokens.primary, DesignTokens.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      product.name,
                      key: const Key('product_detail_name'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 18, color: DesignTokens.warning),
                          const SizedBox(width: 4),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: TextStyle(fontWeight: FontWeight.w600, color: DesignTokens.primary),
                          ),
                        ],
                      ),
                    ),
                    if (product.ratingCount > 0) ...[
                      const SizedBox(width: 8),
                      Text('(${product.ratingCount})', style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _SellerInfoCard(product: product),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [DesignTokens.primary.withValues(alpha: 0.95), DesignTokens.secondary.withValues(alpha: 0.95)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(DesignTokens.radius16),
                    boxShadow: [BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.compareAtPrice != null && product.compareAtPrice! > product.price) ...[
                              Text(
                                '${'product.price'.tr()}:',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400),
                              ),
                              Text(
                                '\$${product.compareAtPrice!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Colors.white70,
                                ),
                              ),
                            ] else
                              Text(
                                '${'product.price'.tr()}:',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            Text(
                              '\$${displayPrice.toStringAsFixed(2)}',
                              key: const Key('product_detail_price'),
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      if (product.compareAtPrice != null && product.compareAtPrice! > displayPrice)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            '-${((1 - displayPrice / product.compareAtPrice!) * 100).round()}%',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(padding: const EdgeInsets.only(left: 2), child: _buildDeliveryEstimate(context, product)),
                const SizedBox(height: 16),
                if (!product.isDigital) _DeliveryInfoCard(product: product),
                if (!product.isDigital) const SizedBox(height: 28),
                Text(
                  'product.description'.tr(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
                ),
                const SizedBox(height: 12),
                _ExpandableDescription(description: product.description),
                if (product.isDigital) ...[const SizedBox(height: 12), _DigitalProductInfo(product: product)],
                const SizedBox(height: 28),
                _VariantAndCartSection(product: product, viewModel: viewModel),
              ],
            );
          }

          // --- Desktop/Tablet: Two-column layout (image left, info right) ---
          if (isWideScreen) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Back button + share row
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            key: const Key('productdetail_back_button'),
                            tooltip: 'product.go_back'.tr(),
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          if (product.slug != null)
                            IconButton(
                              icon: const Icon(Icons.share_outlined),
                              tooltip: 'product.share'.tr(),
                              onPressed: () => SharePlus.instance.share(
                                ShareParams(
                                  text: '${'product.share_text'.tr(namedArgs: {'productName': product.name})}\n${envConfig.baseUrl}/p/${product.slug}',
                                  subject: product.name,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Two-column hero: image left, product info right
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: ResponsiveBreakpoints.contentMaxWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Image gallery (sticky-like with fixed height)
                            Expanded(flex: 5, child: buildImageGallery(height: 480)),
                            const SizedBox(width: 32),
                            // Right: Product info
                            Expanded(flex: 5, child: buildProductInfo()),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Full-width sections below: reviews, Q&A, similar
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: ResponsiveBreakpoints.contentMaxWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ReviewsSection(productId: productId, ratingCount: product.ratingCount, averageRating: product.rating),
                            const SizedBox(height: 32),
                            _QASection(productId: productId, sellerId: product.sellerId),
                            const SizedBox(height: 32),
                            _SimilarProductsSection(productId: productId, categoryId: product.categoryId),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // --- Mobile: Original stacked layout with SliverAppBar ---
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                pinned: true,
                floating: true,
                expandedHeight: 340,
                backgroundColor: isDark ? DesignTokens.darkSurface : Colors.white,
                actions: [
                  if (product.slug != null)
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'product.share'.tr(),
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(
                          text: '${'product.share_text'.tr(namedArgs: {'productName': product.name})}\n${envConfig.baseUrl}/p/${product.slug}',
                          subject: product.name,
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      buildImageGallery(height: 340),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                          ),
                          child: IconButton(
                            key: const Key('productdetail_back_button'),
                            tooltip: 'product.go_back'.tr(),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark ? DesignTokens.darkSurface : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: ResponsiveBreakpoints.contentMaxWidth),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildProductInfo(),
                          const SizedBox(height: 32),
                          _ReviewsSection(productId: productId, ratingCount: product.ratingCount, averageRating: product.rating),
                          const SizedBox(height: 32),
                          _QASection(productId: productId, sellerId: product.sellerId),
                          const SizedBox(height: 32),
                          _SimilarProductsSection(productId: productId, categoryId: product.categoryId),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => _ProductDetailSkeleton(),
        error: (e, s) => AnimatedEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'product.load_error'.tr(),
          subtitle: AppError.getMessage(e),
          action: SizedBox(
            width: 200,
            child: ModernButton(label: 'common.retry'.tr(), icon: Icons.refresh_rounded, onPressed: () => ref.invalidate(productByIdProvider(productId))),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryEstimate(BuildContext context, Product product) {
    if (product.isDigital) return const SizedBox.shrink();

    if (product.isPerishable) {
      return _DeliveryChip(icon: Icons.schedule_outlined, label: 'product.delivery_same_day_available'.tr(), color: DesignTokens.success);
    }

    if (product.freeShipping || product.isLocalDeliveryOnly) {
      return _DeliveryChip(
        icon: Icons.local_shipping_outlined,
        label: product.isLocalDeliveryOnly ? 'product.delivery_local_free'.tr() : 'product.delivery_free'.tr(),
        color: DesignTokens.success,
      );
    }

    final deliveryInfo = product.deliveryInfo;

    if (deliveryInfo.isInternational) {
      return _DeliveryChip(
        icon: Icons.flight_outlined,
        label: 'product.delivery_intl'.tr(namedArgs: {'min': deliveryInfo.minDays.toString(), 'max': deliveryInfo.maxDays.toString()}),
        color: DesignTokens.textSecondary,
      );
    }

    final arrivalDate = DateTime.now().add(Duration(days: deliveryInfo.minDays + 2));
    return _DeliveryChip(
      icon: Icons.local_shipping_outlined,
      label: 'product.delivery_get_by'.tr(namedArgs: {'date': DateFormat('MMM d').format(arrivalDate)}),
      color: DesignTokens.success,
    );
  }

  void _showImageDialog(BuildContext context, List<String> imageUrls, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: DesignTokens.textPrimary,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: imageUrls.length,
                controller: PageController(initialPage: initialIndex),
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: imageUrls[index],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: DesignTokens.outlineVariant,
                          highlightColor: DesignTokens.surface,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, size: 100, color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: IconButton(
                    tooltip: 'common.close'.tr(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVideoPlayer(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => _VideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  // GAP #6 — Record recently viewed product IDs (newest first, max 20).
  static Future<void> _recordRecentlyViewed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(LocalStorageKeys.recentlyViewed) ?? [];
    final updated = [id, ...raw.where((e) => e != id)].take(20).toList();
    await prefs.setStringList(LocalStorageKeys.recentlyViewed, updated);
  }
}

class _AddToCartButton extends ConsumerStatefulWidget {
  final String productId;
  final String sellerId;
  final int stockQuantity;
  final String? variantKey;

  const _AddToCartButton({required this.productId, required this.sellerId, required this.stockQuantity, this.variantKey});

  @override
  ConsumerState<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends ConsumerState<_AddToCartButton> {
  bool _isBuyingNow = false;

  @override
  Widget build(BuildContext context) {
    final quantity = ref.watch(productDetailViewModelProvider.select((state) => state.quantity));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProduct = currentUser != null && currentUser.uid == widget.sellerId;

    // If user is the seller, show disabled button with message
    if (isOwnProduct) {
      return Semantics(
        label: 'product_own_product_message',
        container: true,
        child: Column(
          key: const Key('product_own_product_message'),
          children: [
            ModernButton(label: 'product.own_product_title'.tr(), onPressed: null, fullWidth: true, icon: Icons.storefront),
            const SizedBox(height: 8),
            Text(
              'product.own_product_msg'.tr(),
              style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    // Out of stock: show "Notify me when available" button
    if (widget.stockQuantity <= 0) {
      final notifState = ref.watch(stockNotificationNotifierProvider((productId: widget.productId, variantKey: widget.variantKey)));
      final isSubscribed = notifState.value ?? false;
      final isLoading = notifState.isLoading;
      return Semantics(
        label: 'product_notify_section',
        container: true,
        child: Column(
          key: const Key('product_notify_section'),
          children: [
            ModernButton(
              key: const Key('product_notify_me_button'),
              semanticsLabel: 'product_notify_me_button',
              label: isSubscribed ? 'product.notify_cancel'.tr() : 'product.notify_me'.tr(),
              onPressed: isLoading ? null : () => _toggleNotification(context, ref.read(currentUserProvider)),
              fullWidth: true,
              icon: isSubscribed ? Icons.notifications_off_outlined : Icons.notifications_outlined,
            ),
            const SizedBox(height: 8),
            Text(
              'product.out_of_stock'.tr(),
              style: TextStyle(fontSize: 13, color: DesignTokens.error, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ModernButton(
          label: 'product.buy_now'.tr(),
          semanticsLabel: 'product_buy_now_button',
          onPressed: _isBuyingNow ? null : () => _handleBuyNow(context, quantity),
          isLoading: _isBuyingNow,
          key: const Key('product_buy_now_button'),
          fullWidth: true,
          icon: Icons.bolt_rounded,
        ),
        const SizedBox(height: 12),
        ModernButton(
          label: 'product.add_to_cart'.tr(),
          semanticsLabel: 'product_add_to_cart_button',
          isOutlined: true,
          onPressed: () async {
            final user = ref.read(currentUserProvider);
            if (user == null) {
              if (context.mounted) showLoginPrompt(context);
              return;
            }
            if (context.mounted) {
              final verified = await checkEmailVerifiedOrPrompt(context, auth: ref.read(firebaseAuthProvider));
              if (!verified) return;
            }
            if (!context.mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            final success = await ref.read(cartControllerProvider).addToCart(widget.productId, quantity, variantId: widget.variantKey);

            if (success) {
              HapticFeedback.mediumImpact();
            } else {
              HapticFeedback.vibrate();
            }

            if (context.mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(success ? 'cart.added_success'.tr() : 'cart.added_failure'.tr()),
                  backgroundColor: success ? DesignTokens.success : DesignTokens.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          },
          key: const Key('product_add_to_cart_button'),
          fullWidth: true,
          icon: Icons.shopping_cart_checkout,
        ),
      ],
    );
  }

  Future<void> _handleBuyNow(BuildContext context, int quantity) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (context.mounted) showLoginPrompt(context);
      return;
    }
    if (context.mounted) {
      final verified = await checkEmailVerifiedOrPrompt(context, auth: ref.read(firebaseAuthProvider));
      if (!verified) return;
    }
    if (!context.mounted) return;

    setState(() => _isBuyingNow = true);
    try {
      final success = await ref.read(cartControllerProvider).addToCart(widget.productId, quantity, variantId: widget.variantKey);
      if (!success || !context.mounted) return;

      final cartDetails = await ref.read(cartWithDetailsProvider.future);
      if (!context.mounted) return;
      if (cartDetails.isEmpty) return;

      final subtotal = cartDetails.fold(0.0, (total, item) => total + (item.price * item.quantity));
      Navigator.pushNamed(
        context,
        AppRoutes.checkout,
        arguments: CheckoutArgs(items: cartDetails, total: subtotal),
      );
    } finally {
      if (mounted) setState(() => _isBuyingNow = false);
    }
  }

  Future<void> _toggleNotification(BuildContext context, dynamic currentUser) async {
    if (currentUser == null) {
      showLoginPrompt(context);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(stockNotificationNotifierProvider((productId: widget.productId, variantKey: widget.variantKey)).notifier);
    final isSubscribed = ref.read(stockNotificationNotifierProvider((productId: widget.productId, variantKey: widget.variantKey))).value ?? false;
    try {
      if (isSubscribed) {
        await notifier.unsubscribe();
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(content: Text('product.notify_cancelled'.tr()), backgroundColor: DesignTokens.textSecondary));
        }
      } else {
        await notifier.subscribe();
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(content: Text('product.notify_subscribed'.tr()), backgroundColor: DesignTokens.success));
        }
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(AppError.getMessage(e, 'product.notify_error'.tr())), backgroundColor: DesignTokens.error));
      }
    }
  }
}

/// Compact delivery estimate chip shown directly below the price on product detail.
class _DeliveryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DeliveryChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ============================================================================
// DELIVERY INFO CARD - Shows estimated delivery time to buyers
// ============================================================================

class _DeliveryInfoCard extends StatelessWidget {
  final Product product;

  const _DeliveryInfoCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deliveryInfo = product.deliveryInfo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.darkCard : DesignTokens.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        border: Border.all(color: isDark ? DesignTokens.darkOutline : DesignTokens.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(product.isDigital ? Icons.download_rounded : Icons.local_shipping_outlined, color: DesignTokens.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'product.details.delivery_information'.tr(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : DesignTokens.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Estimated delivery time
          _DeliveryInfoRow(icon: Icons.access_time_rounded, label: 'checkout.estimated_delivery'.tr(), value: deliveryInfo.estimateText, isDark: isDark),
          const SizedBox(height: 10),
          if (deliveryInfo.supplierRegion != null) ...[
            _DeliveryInfoRow(
              icon: Icons.public_rounded,
              label: 'product.ships_from'.tr(),
              value: deliveryInfo.supplierRegion!,
              isDark: isDark,
              isWarning: deliveryInfo.isInternational,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          _DeliveryInfoRow(
            icon: deliveryInfo.hasTracking ? Icons.track_changes_rounded : Icons.info_outline_rounded,
            label: 'product.tracking'.tr(),
            value: deliveryInfo.hasTracking ? 'product.tracking_available'.tr() : 'product.tracking_limited'.tr(),
            isDark: isDark,
          ),
          if (product.freeShipping) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: DesignTokens.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_offer_rounded, size: 16, color: DesignTokens.success),
                  const SizedBox(width: 6),
                  Text(
                    'product.free_shipping'.tr(),
                    style: TextStyle(color: DesignTokens.success, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
          if (deliveryInfo.isInternational) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DesignTokens.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: DesignTokens.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('product.details.international_disclaimer'.tr(), style: TextStyle(fontSize: 12, color: DesignTokens.warning, height: 1.3)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool isWarning;

  const _DeliveryInfoRow({required this.icon, required this.label, required this.value, required this.isDark, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isWarning ? DesignTokens.warning : (isDark ? DesignTokens.textOnDarkSecondary : DesignTokens.textSecondary)),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontSize: 14, color: isDark ? DesignTokens.textOnDarkSecondary : DesignTokens.textSecondary)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isWarning ? DesignTokens.warning : (isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DigitalProductInfo extends StatelessWidget {
  final Product product;
  const _DigitalProductInfo({required this.product});

  @override
  Widget build(BuildContext context) {
    final builds = product.digitalBuilds ?? {};
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.digital.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesignTokens.digital.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
            children: [
              const Icon(Icons.download_outlined, size: 16, color: DesignTokens.digital),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  product.digitalType == DigitalTypeValues.software ? 'product.desktop_software'.tr() : 'product.digital_book'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.digital),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (builds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('product.available_for'.tr(), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: builds.keys.map((p) {
                final label = const {'macos': 'macOS', 'windows': 'Windows', 'linux': 'Linux'}[p] ?? p;
                return Chip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('product.digital_license_delivery'.tr(), style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXPANDABLE DESCRIPTION — "Read more / Show less" for long product descriptions
// ============================================================================

class _ExpandableDescription extends StatefulWidget {
  final String description;
  const _ExpandableDescription({required this.description});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  static const _collapseThreshold = 100; // ~3-4 lines on 390px mobile
  static const _maxLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLong = widget.description.length > _collapseThreshold;
    final textStyle = TextStyle(fontSize: 15, color: isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary, height: 1.6, fontWeight: FontWeight.w400);

    return GlassContainer(
      key: const Key('product_description_section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.description,
            style: textStyle,
            maxLines: (_expanded || !isLong) ? null : _maxLines,
            overflow: (_expanded || !isLong) ? TextOverflow.visible : TextOverflow.fade,
          ),
          if (isLong) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'common.see_less'.tr() : 'common.see_more'.tr(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageDots extends ConsumerWidget {
  final int imageCount;

  const _ImageDots({required this.imageCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (imageCount <= 1) return const SizedBox.shrink();

    final currentIndex = ref.watch(productDetailViewModelProvider.select((state) => state.currentImageIndex));

    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          imageCount,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: currentIndex == index ? Colors.white : Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _MetricPill({required this.icon, required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : DesignTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.grey.shade700 : DesignTokens.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: DesignTokens.primary),
          const SizedBox(width: 4),
          Text('$label: ', style: TextStyle(fontSize: 11, color: isDark ? DesignTokens.textOnDarkSecondary : DesignTokens.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Shimmer skeleton displayed while product data is loading.
/// Matches the layout sections of the real product detail screen.
class _ProductDetailSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? DesignTokens.darkCard : DesignTokens.outlineVariant;
    final highlightColor = isDark ? DesignTokens.darkSurfaceVariant : DesignTokens.surface;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image placeholder
            Container(height: 340, width: double.infinity, color: Colors.white),
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spacing20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name
                  Container(
                    width: double.infinity,
                    height: 28,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(height: DesignTokens.spacing8),
                  Container(
                    width: 200,
                    height: 28,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(height: DesignTokens.spacing12),
                  // Rating row
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 28,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 50,
                        height: 16,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spacing16),
                  // Price block
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(DesignTokens.radius16)),
                  ),
                  const SizedBox(height: DesignTokens.spacing20),
                  // Description header
                  Container(
                    width: 120,
                    height: 20,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  ),
                  const SizedBox(height: DesignTokens.spacing12),
                  // Description body
                  Container(
                    width: double.infinity,
                    height: 96,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(DesignTokens.radius16)),
                  ),
                  const SizedBox(height: DesignTokens.spacing20),
                  // Section header
                  Container(
                    width: 100,
                    height: 20,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  ),
                  const SizedBox(height: DesignTokens.spacing12),
                  // Reviews placeholder
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(DesignTokens.radius16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REVIEWS — Provider + Section + Card (N-02, N-03, N-04)
// ============================================================================

class _QACard extends ConsumerWidget {
  final QAModel qa;
  final String productId;
  final String sellerId;
  final String? currentUserId;

  const _QACard({required this.qa, required this.productId, required this.sellerId, this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSeller = currentUserId == sellerId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatter = DateFormat.yMMMd();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignTokens.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help_outline, size: 20, color: DesignTokens.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(qa.question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      'qa.asked_on'.tr(namedArgs: {'date': formatter.format(qa.createdAt)}),
                      style: const TextStyle(fontSize: 12, color: DesignTokens.textDisabled),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (qa.answer != null && qa.answer!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DesignTokens.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: DesignTokens.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'qa.answer_label'.tr(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DesignTokens.success),
                        ),
                        const SizedBox(height: 4),
                        Text(qa.answer!, style: const TextStyle(fontSize: 15)),
                        if (qa.answeredAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${'qa.answered'.tr()} ${formatter.format(qa.answeredAt!)}',
                            style: const TextStyle(fontSize: 11, color: DesignTokens.textDisabled),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isSeller) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showAnswerDialog(context, ref),
                icon: const Icon(Icons.reply, size: 18),
                label: Text('qa.your_answer'.tr()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAnswerDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('qa.your_answer'.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'qa.answer_hint'.tr()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(qaControllerProvider.notifier).answerQuestion(qaId: qa.id, answer: controller.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('qa.answer_submitted'.tr())));
              }
            },
            child: Text('qa.submit_answer'.tr()),
          ),
        ],
      ),
    );
  }
}

class _QASection extends ConsumerStatefulWidget {
  final String productId;
  final String sellerId;

  const _QASection({required this.productId, required this.sellerId});

  @override
  ConsumerState<_QASection> createState() => _QASectionState();
}

class _QASectionState extends ConsumerState<_QASection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final qaAsync = ref.watch(qaListProvider(widget.productId));
    final currentUserId = ref.watch(userIdProvider);
    final isSeller = currentUserId == widget.sellerId;
    final isPremium = ref.watch(subscriptionStreamProvider).whenOrNull(data: (s) => s?.isPremium) ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'qa.title'.tr(),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
        ),
        const SizedBox(height: 16),
        qaAsync.when(
          data: (qaList) {
            if (qaList.isEmpty) {
              return _emptyState(context, currentUserId, isSeller, isPremium);
            }

            final displayList = _showAll ? qaList : qaList.take(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...displayList.map((qa) => _QACard(qa: qa, productId: widget.productId, sellerId: widget.sellerId, currentUserId: currentUserId)),
                if (qaList.length > 3 && !_showAll)
                  TextButton(
                    onPressed: () => setState(() => _showAll = true),
                    child: Text('qa.see_all'.tr(namedArgs: {'count': qaList.length.toString()})),
                  ),
                const SizedBox(height: 16),
                if (!isSeller && currentUserId != null)
                  ElevatedButton.icon(
                    onPressed: () => isPremium ? _showAskDialog(context) : _showPremiumPaywall(context),
                    icon: Icon(isPremium ? Icons.help_outline : Icons.lock_rounded),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('qa.ask_question'.tr()),
                        if (!isPremium) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(gradient: DesignTokens.primaryGradient, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'subscription.premium_label'.tr(),
                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
                      foregroundColor: isPremium ? DesignTokens.primary : DesignTokens.textSecondary,
                      elevation: 0,
                      side: BorderSide(color: isPremium ? DesignTokens.primary : DesignTokens.outline),
                    ),
                  )
                else if (currentUserId == null)
                  Center(
                    child: Text('qa.sign_in_to_ask'.tr(), style: const TextStyle(color: DesignTokens.textSecondary)),
                  ),
              ],
            );
          },
          loading: () => const Center(child: ModernLoadingIndicator()),
          error: (e, _) => Text('errors.something_went_wrong'.tr(), style: const TextStyle(color: DesignTokens.error)),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, String? currentUserId, bool isSeller, bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignTokens.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 48, color: DesignTokens.textDisabled),
          const SizedBox(height: 16),
          Text(
            'qa.no_questions'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: DesignTokens.textSecondary),
          ),
          if (!isSeller && currentUserId != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => isPremium ? _showAskDialog(context) : _showPremiumPaywall(context),
              icon: Icon(isPremium ? Icons.help_outline : Icons.lock_rounded, size: 18),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('qa.ask_question'.tr()),
                  if (!isPremium) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(gradient: DesignTokens.primaryGradient, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        'subscription.premium_label'.tr(),
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (currentUserId == null) ...[
            const SizedBox(height: 16),
            Text(
              'qa.sign_in_to_ask'.tr(),
              style: const TextStyle(color: DesignTokens.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  void _showAskDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('qa.ask_question'.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'qa.question_hint'.tr()),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(qaControllerProvider.notifier).askQuestion(widget.productId, text);
              if (!mounted) return;
              final state = ref.read(qaControllerProvider);
              if (state.hasError) {
                messenger.showSnackBar(SnackBar(content: Text(state.error.toString()), backgroundColor: DesignTokens.error));
              } else {
                messenger.showSnackBar(SnackBar(content: Text('qa.question_submitted'.tr())));
              }
            },
            child: Text('qa.submit_question'.tr()),
          ),
        ],
      ),
    );
  }

  void _showPremiumPaywall(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: PremiumPaywallWidget(featureName: 'subscription.ask_questions'.tr()),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;

  const _QuantityButton({super.key, required this.icon, required this.onPressed, required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          splashColor: DesignTokens.primary.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: onPressed != null ? DesignTokens.primary : DesignTokens.textDisabled, size: 20),
          ),
        ),
      ),
    );
  }
}

class _QuantitySelector extends ConsumerWidget {
  final ProductDetailViewModel viewModel;

  const _QuantitySelector({required this.viewModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(productDetailViewModelProvider.select((state) => state.quantity));

    return Row(
      children: [
        Text(
          '${'product.quantity'.tr()}:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : DesignTokens.textPrimary,
          ),
        ),
        const SizedBox(width: 20),
        GlassContainer(
          child: Row(
            children: [
              _QuantityButton(
                key: const Key('product_qty_minus'),
                icon: Icons.remove,
                onPressed: quantity > 1 ? viewModel.decrementQuantity : null,
                semanticLabel: 'btn-product-qty-minus',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$quantity',
                  key: const Key('product_qty_value'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              _QuantityButton(
                key: const Key('product_qty_plus'),
                icon: Icons.add,
                onPressed: viewModel.incrementQuantity,
                semanticLabel: 'btn-product-qty-plus',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> review;
  final String productId;

  const _ReviewCard({required this.review, required this.productId});

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  bool _votingHelpful = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = ref.watch(subscriptionStreamProvider).whenOrNull(data: (s) => s?.isPremium) ?? false;
    final review = widget.review;
    final ratingId = review[Fields.ratingId] as String? ?? '';
    final comment = review[Fields.review] as String? ?? '';
    final starValue = (review[Fields.rating] as num?)?.toInt() ?? 0;
    final helpfulCount = (review[Fields.helpfulCount] as num?)?.toInt() ?? 0;
    final sellerReply = review[Fields.sellerReply] as String?;
    final userId = review[Fields.userId] as String? ?? '';
    final reviewer = userId.length > 8 ? userId.substring(0, 8) : userId;
    final reviewerLabel = reviewer.isNotEmpty ? 'User ${reviewer.toUpperCase()}' : 'Anonymous';
    final createdAt = (review[Fields.createdAt] as Timestamp?)?.toDate();
    final isVerified = review[Fields.verifiedPurchase] as bool? ?? false;
    final photoUrls = (review[Fields.reviewImageUrls] as List?)?.whereType<String>().toList() ?? <String>[];

    if (comment.isEmpty && sellerReply == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignTokens.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: reviewer + stars + date
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: DesignTokens.primary.withValues(alpha: 0.15),
                child: Text(
                  reviewerLabel.isNotEmpty ? reviewerLabel[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reviewerLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (createdAt != null) Text(DateFormat.yMMMd().format(createdAt), style: const TextStyle(fontSize: 11, color: DesignTokens.textDisabled)),
                  ],
                ),
              ),
              // Star display
              Row(
                children: List.generate(5, (i) => Icon(i < starValue ? Icons.star_rounded : Icons.star_border_rounded, size: 14, color: DesignTokens.warning)),
              ),
            ],
          ),

          // Verified purchase badge
          if (isVerified) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.verified_rounded, size: 14, color: DesignTokens.success),
                const SizedBox(width: 4),
                Text(
                  'product.verified_purchase'.tr(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DesignTokens.success),
                ),
              ],
            ),
          ],

          // Photo row — premium-only feature
          if (photoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photoUrls.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) => GestureDetector(
                      onTap: isPremium ? () => _showReviewPhotoDialog(context, photoUrls, idx) : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: photoUrls[idx],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Shimmer.fromColors(
                            baseColor: DesignTokens.outlineVariant,
                            highlightColor: DesignTokens.surface,
                            child: Container(width: 80, height: 80, color: Colors.white),
                          ),
                          errorWidget: (ctx, url, err) =>
                              Container(width: 80, height: 80, color: DesignTokens.outlineVariant, child: const Icon(Icons.image_not_supported, size: 32)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isPremium)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(context, AppRoutes.subscription),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    'subscription.premium_label'.tr(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Review text
          if (comment.isNotEmpty) ...[const SizedBox(height: 10), Text(comment, style: const TextStyle(fontSize: 14, height: 1.5))],

          // N-03: Seller reply
          if (sellerReply != null && sellerReply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.3) : DesignTokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DesignTokens.digital.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'product.seller_response'.tr(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.digital, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(sellerReply, style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],

          // N-04: Helpfulness voting
          if (ratingId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('product.helpful_question'.tr(), style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary)),
                const SizedBox(width: 6),
                _votingHelpful
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ModernLoadingIndicator(size: 14, strokeWidth: 2, color: DesignTokens.primary, centered: false),
                      )
                    : TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _voteHelpful(ratingId, true),
                        child: Text('product.helpful_yes_count'.tr(namedArgs: {'count': '$helpfulCount'}), style: const TextStyle(fontSize: 12)),
                      ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showReviewPhotoDialog(BuildContext context, List<String> urls, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: DesignTokens.textPrimary,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: urls.length,
              controller: PageController(initialPage: initialIndex),
              itemBuilder: (_, i) => InteractiveViewer(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: urls[i],
                    fit: BoxFit.contain,
                    placeholder: (ctx, url) => Shimmer.fromColors(
                      baseColor: DesignTokens.outlineVariant,
                      highlightColor: DesignTokens.surface,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (ctx, url, err) => const Icon(Icons.image_not_supported, size: 100, color: Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                child: IconButton(
                  tooltip: 'common.close'.tr(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _voteHelpful(String ratingId, bool helpful) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) showLoginPrompt(context);
      return;
    }
    setState(() => _votingHelpful = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // MVVM FIX (AUDIT): Delegated to ViewModel — UI no longer calls Firebase directly.
      await ref.read(productDetailViewModelProvider.notifier).voteHelpful(ratingId, widget.productId, helpful);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('product.helpful_vote_thanks'.tr()),
            backgroundColor: DesignTokens.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('product.helpful_vote_error'.tr()),
            backgroundColor: DesignTokens.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _votingHelpful = false);
    }
  }
}

class _ReviewsSection extends ConsumerWidget {
  final String productId;
  final int ratingCount;
  final double averageRating;

  const _ReviewsSection({required this.productId, required this.ratingCount, required this.averageRating});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratingsAsync = ref.watch(_productRatingsProvider(productId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'product.reviews_title'.tr(),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
        ),
        const SizedBox(height: 12),
        ratingsAsync.when(
          data: (ratings) {
            if (ratingCount == 0 && ratings.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DesignTokens.outlineVariant),
                ),
                child: Center(
                  child: Text(
                    'product.no_reviews_yet'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DesignTokens.textSecondary),
                  ),
                ),
              );
            }

            // Build star counts from loaded ratings
            final counts = List<int>.filled(5, 0);
            for (final r in ratings) {
              final star = (r[Fields.rating] as num?)?.toInt() ?? 0;
              if (star >= 1 && star <= 5) counts[5 - star]++;
            }
            final total = ratingCount > 0 ? ratingCount : ratings.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Histogram
                if (ratingCount > 0 || ratings.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RatingHistogram(counts: counts, total: total),
                  ),

                // Review cards
                ...ratings.map((review) => _ReviewCard(review: review, productId: productId)),

                if (ratings.isEmpty && ratingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      (ratingCount == 1 ? 'product.ratings_no_text_one' : 'product.ratings_no_text_other').tr(namedArgs: {'count': '$ratingCount'}),
                      style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: ModernLoadingIndicator()),
          error: (e, _) => Text('product.reviews_load_error'.tr(), style: TextStyle(color: DesignTokens.error, fontSize: 13)),
        ),
      ],
    );
  }
}

// ============================================================================
// SELLER METRICS ROW — Shows avg response time, ship days, positive rate
// ============================================================================

// ============================================================================
// SELLER INFO CARD — compact seller card with metrics + trust badges
// ============================================================================

class _SellerInfoCard extends StatelessWidget {
  final Product product;
  const _SellerInfoCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.surface.withValues(alpha: 0.8) : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(DesignTokens.radius8)),
                child: const Icon(Icons.storefront_outlined, size: 16, color: DesignTokens.primary),
              ),
              const SizedBox(width: 8),
              Text(
                'product.seller_info'.tr(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : DesignTokens.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SellerMetricsRow(sellerId: product.sellerId),
          const SizedBox(height: 8),
          _TrustBadges(product: product),
        ],
      ),
    );
  }
}

class _SellerMetricsRow extends ConsumerWidget {
  final String sellerId;

  const _SellerMetricsRow({required this.sellerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsState = ref.watch(productDetailViewModelProvider);
    if (metricsState.sellerMetricsLoading) return const SizedBox.shrink();
    final metrics = metricsState.sellerMetrics;
    if (metrics == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    String fmt(double? v, String suffix) {
      if (v == null) return '--';
      return '${v.toStringAsFixed(1)}$suffix';
    }

    String fmtPct(double? v) {
      if (v == null) return '--';
      return '${v.toStringAsFixed(0)}%';
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _MetricPill(icon: Icons.schedule_rounded, label: 'product.metric_response'.tr(), value: fmt(metrics.avgResponseHours, 'h'), isDark: isDark),
        _MetricPill(icon: Icons.local_shipping_outlined, label: 'product.metric_ships_in'.tr(), value: fmt(metrics.avgShipDays, 'd'), isDark: isDark),
        _MetricPill(icon: Icons.thumb_up_alt_outlined, label: 'product.metric_positive'.tr(), value: fmtPct(metrics.positiveRatePct), isDark: isDark),
        if (metrics.totalReviews != null && metrics.totalReviews! > 0)
          _MetricPill(icon: Icons.rate_review_outlined, label: 'product.reviews_title'.tr(), value: '${metrics.totalReviews}', isDark: isDark),
      ],
    );
  }
}

// ============================================================================
// SIMILAR PRODUCTS SECTION — Horizontal row of products in same category
// ============================================================================

class _SimilarProductsSection extends ConsumerWidget {
  final String productId;
  final int categoryId;

  const _SimilarProductsSection({required this.productId, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Skip if category is unset (0)
    if (categoryId == 0) return const SizedBox.shrink();

    final similarAsync = ref.watch(similarProductsProvider((excludeProductId: productId, categoryId: categoryId)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return similarAsync.when(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'product.customers_also_bought'.tr(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (context, i) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final p = products[idx];
                  return SizedBox(
                    width: 150,
                    child: ProductCard(productId: p.productId, product: p, userModel: null),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
    );
  }
}

// ============================================================================
// STICKY BOTTOM CTA — fixed Add-to-Cart / Buy-Now bar on mobile
// ============================================================================

class _StickyBottomCTA extends ConsumerWidget {
  final Product product;
  final bool isOutOfStock;
  final bool isDark;

  const _StickyBottomCTA({required this.product, required this.isOutOfStock, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(productDetailViewModelProvider.select((s) => s.quantity));

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkSurface.withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: DesignTokens.primary.withValues(alpha: 0.15))),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            // Price chip
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${(product.price * quantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DesignTokens.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (quantity > 1)
                    Text(
                      '\$${product.price.toStringAsFixed(2)} × $quantity',
                      style: const TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Add to Cart button
            Expanded(
              child: _AddToCartButton(productId: product.productId, sellerId: product.sellerId, stockQuantity: product.stockQuantity),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TRUST BADGES — Verified Seller · Fast Shipper · Ships CA
// ============================================================================

class _TrustBadges extends ConsumerWidget {
  final Product product;

  const _TrustBadges({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(productDetailViewModelProvider).sellerMetrics;

    final isVerifiedSeller = (metrics?.positiveRatePct ?? 0) >= 90;
    final isFastShipper = (metrics?.avgShipDays ?? double.infinity) <= 2;
    final shipsCA = product.shipFromCountry == null || product.shipFromCountry == 'CA';

    final badges = <({IconData icon, String label, Color color})>[];
    if (isVerifiedSeller) badges.add((icon: Icons.verified_rounded, label: 'product.trust_verified_seller'.tr(), color: DesignTokens.success));
    if (isFastShipper) badges.add((icon: Icons.local_shipping_rounded, label: 'product.trust_fast_shipper'.tr(), color: DesignTokens.primary));
    if (shipsCA) badges.add((icon: Icons.flag_rounded, label: 'product.trust_ships_ca'.tr(), color: DesignTokens.error));

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: badges
          .map(
            (b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: b.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: b.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(b.icon, size: 12, color: b.color),
                  const SizedBox(width: 4),
                  Text(
                    b.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: b.color),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ============================================================================
// VARIANT SELECTOR + CART SECTION (N-09)
// ============================================================================

class _VariantAndCartSection extends ConsumerWidget {
  final Product product;
  final ProductDetailViewModel viewModel;

  const _VariantAndCartSection({required this.product, required this.viewModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productDetailViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasVariants = product.hasVariants && product.variantOptions.isNotEmpty;

    final selectedOptions = state.selectedOptions;
    final selectedVariantId = state.selectedVariantId;

    bool allOptionsSelected() {
      if (!hasVariants) return true;
      return product.variantOptions.every((opt) => selectedOptions.containsKey(opt.name));
    }

    ProductVariant? matchedVariant() {
      if (!hasVariants || selectedOptions.isEmpty) return null;
      for (final v in product.variants) {
        bool match = true;
        for (final entry in selectedOptions.entries) {
          final optName = entry.key.toLowerCase();
          final optVal = entry.value;
          if (v.optionValues[optName] != optVal && v.optionValues[entry.key] != optVal) {
            match = false;
            break;
          }
        }
        if (match) return v;
      }
      return null;
    }

    final effectiveStock = product.hasVariants ? (matchedVariant()?.stockQuantity ?? 0) : product.stockQuantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasVariants) ...[
          ...product.variantOptions.map((opt) {
            final optName = opt.name;
            final values = opt.values;
            final selected = selectedOptions[optName];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    optName,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : DesignTokens.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: values.map((val) {
                      final isSelected = selected == val;
                      return GestureDetector(
                        onTap: () {
                          final newOptions = {...selectedOptions, optName: val};
                          String? newVariantId;
                          // Find matched variant for the new selection
                          for (final v in product.variants) {
                            bool match = true;
                            for (final entry in newOptions.entries) {
                              final name = entry.key.toLowerCase();
                              final value = entry.value;
                              if (v.optionValues[name] != value && v.optionValues[entry.key] != value) {
                                match = false;
                                break;
                              }
                            }
                            if (match) {
                              newVariantId = v.variantId;
                              break;
                            }
                          }
                          viewModel.setSelectedOption(optName, val, variantId: newVariantId);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? DesignTokens.primary : (isDark ? DesignTokens.darkCard : Colors.white),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? DesignTokens.primary : DesignTokens.outline.withValues(alpha: 0.4),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            val,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : (isDark ? Colors.white : DesignTokens.textPrimary),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
          if (!allOptionsSelected())
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'product.select_all_options'.tr(),
                style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary, fontStyle: FontStyle.italic),
              ),
            ),
        ],
        if (effectiveStock > 0 && effectiveStock <= 10)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 16, color: DesignTokens.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'product.low_stock'.tr(namedArgs: {'count': effectiveStock.toString()}),
                    style: TextStyle(fontSize: 13, color: DesignTokens.warning, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        _QuantitySelector(viewModel: viewModel),
        const SizedBox(height: 24),
        _AddToCartButton(
          productId: product.productId,
          sellerId: product.sellerId,
          stockQuantity: effectiveStock,
          variantKey: selectedVariantId,
        ),
      ],
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerDialog({required this.videoUrl});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: _hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      Text('product.video_not_playable'.tr(), style: const TextStyle(color: Colors.white)),
                    ],
                  )
                : (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoPlayerController.value.aspectRatio,
                          child: Chewie(controller: _chewieController!),
                        )
                      : const ModernLoadingIndicator()),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: IconButton(
                tooltip: 'common.close'.tr(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        placeholder: const Center(child: ModernLoadingIndicator()),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(errorMessage, style: const TextStyle(color: Colors.white)),
          );
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }
}
