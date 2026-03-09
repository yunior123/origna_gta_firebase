// coverage:ignore-file
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../utils/design_tokens.dart';

/// Modern 2100 Product Card with glassmorphism
class ModernProductCard extends StatefulWidget {
  final String productName;
  final double price;
  final String imageUrl;
  final String sellerName;
  final double rating;
  final int reviewCount;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final String? shipFromCity;
  final String? shipFromProvince;
  final String? shipFromCountry;
  final List<String>? shipFromCountries;

  /// Original/crossed-out price shown next to the sale price (null = no active sale)
  final double? compareAtPrice;

  /// When true, show a Trending badge on the image corner
  final bool isTrending;

  /// Trending score: ≥50 = HOT (fire), <50 = RISING (teal)
  final int trendingScore;

  /// SRCH-M1: When true, show "Out of Stock" overlay and disable CTA
  final bool isOutOfStock;

  const ModernProductCard({
    super.key,
    required this.productName,
    required this.price,
    required this.imageUrl,
    required this.sellerName,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.onTap,
    this.onAddToCart,
    this.shipFromCity,
    this.shipFromProvince,
    this.shipFromCountry,
    this.shipFromCountries,
    this.compareAtPrice,
    this.isTrending = false,
    this.trendingScore = 0,
    this.isOutOfStock = false,
  });

  @override
  State<ModernProductCard> createState() => _ModernProductCardState();
}

class _ModernProductCardState extends State<ModernProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  /// Computes the "Ships from" label:
  /// - Single country: "Ships from: Toronto, ON, Canada"
  /// - 2–3 countries:  "Ships from: Canada · Germany"
  /// - 4+ countries:   "Ships from: 4 locations worldwide"
  String get _shipFromLabel {
    final countries = widget.shipFromCountries;
    if (countries != null && countries.length > 1) {
      if (countries.length <= 3) {
        return 'product.ships_from_label'.tr(namedArgs: {'locations': countries.join(' · ')});
      }
      return 'product.ships_from_worldwide'.tr(namedArgs: {'count': countries.length.toString()});
    }
    // Single location — show full city, province, country
    // FAV-L2: also fall back to single country from list when no individual fields
    final parts = [
      if (widget.shipFromCity != null) widget.shipFromCity!,
      if (widget.shipFromProvince != null) widget.shipFromProvince!,
      if (widget.shipFromCountry != null) widget.shipFromCountry!,
      // If no individual address fields but a single country is provided in the list, use it
      if (widget.shipFromCity == null && widget.shipFromCountry == null && countries != null && countries.length == 1) countries[0],
    ];
    return parts.isEmpty ? '' : 'product.ships_from_label'.tr(namedArgs: {'locations': parts.join(', ')});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Semantics(
          label: widget.compareAtPrice != null
              ? 'product.a11y_on_sale'.tr(
                  namedArgs: {
                    'name': widget.productName,
                    'price': '\$${widget.price.toStringAsFixed(2)}',
                    'originalPrice': '\$${widget.compareAtPrice!.toStringAsFixed(2)}',
                    'rating': widget.rating.toStringAsFixed(1),
                  },
                )
              : 'product.a11y_regular'.tr(
                  namedArgs: {'name': widget.productName, 'price': '\$${widget.price.toStringAsFixed(2)}', 'rating': widget.rating.toStringAsFixed(1)},
                ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? DesignTokens.darkSurfaceVariant.withValues(alpha: 0.6) : DesignTokens.surface,
                borderRadius: BorderRadius.circular(DesignTokens.radius16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                boxShadow: DesignTokens.shadowMd,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radius16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image — 60% of card height, adapts to any grid size
                    Expanded(
                      flex: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [DesignTokens.primary.withValues(alpha: 0.1), DesignTokens.secondary.withValues(alpha: 0.1)],
                              ),
                            ),
                            child: widget.imageUrl.isNotEmpty
                                ? ColorFiltered(
                                    colorFilter: widget.isOutOfStock
                                        ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                                        : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                    child: CachedNetworkImage(
                                      imageUrl: widget.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Shimmer.fromColors(
                                        baseColor: DesignTokens.outlineVariant,
                                        highlightColor: DesignTokens.surface,
                                        child: Container(color: Colors.white),
                                      ),
                                      errorWidget: (context, url, error) => Center(
                                        child: Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: DesignTokens.primary.withValues(alpha: 0.12),
                                            border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.2), width: 1.5),
                                          ),
                                          child: const Icon(Icons.camera_alt_outlined, color: DesignTokens.primary, size: 26),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: DesignTokens.primary.withValues(alpha: 0.12),
                                        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.2), width: 1.5),
                                      ),
                                      child: const Icon(Icons.camera_alt_outlined, color: DesignTokens.primary, size: 26),
                                    ),
                                  ),
                          ),
                          // SRCH-M1: Out of Stock overlay
                          if (widget.isOutOfStock)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.3),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      'product.out_of_stock_label'.tr(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // N-10: isTrending badge (HOT / RISING)
                          if (widget.isTrending && !widget.isOutOfStock)
                            Positioned(top: 8, left: 8, child: _TrendingBadge(score: widget.trendingScore, isCompact: false)),
                        ],
                      ),
                    ),
                    // Content — 40% of card height
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(DesignTokens.spacing12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 14 * 1.4 * 2 + 2,
                              child: Text(
                                widget.productName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                              ),
                            ),
                            const SizedBox(height: DesignTokens.spacing4),
                            Text(
                              widget.sellerName,
                              style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            // FAV-L2: only render when label is non-empty (guards against single-country list
                            // with no city/province/country fields → avoids "Ships from: " with blank text)
                            if (_shipFromLabel.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on_rounded, size: 11, color: DesignTokens.textTertiary),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      _shipFromLabel,
                                      style: TextStyle(fontSize: 11, color: DesignTokens.textTertiary),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const Spacer(),
                            // Rating
                            if (widget.reviewCount > 0)
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, size: 14, color: DesignTokens.warning),
                                  const SizedBox(width: 4),
                                  Text(widget.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 4),
                                  Text('(${widget.reviewCount})', style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary)),
                                ],
                              )
                            else
                              Text('product.no_reviews_card'.tr(), style: TextStyle(fontSize: 11, color: DesignTokens.textTertiary)),
                            const SizedBox(height: DesignTokens.spacing8),
                            // Price and CTA
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '\$${widget.price.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DesignTokens.primary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (widget.compareAtPrice != null)
                                        Text(
                                          '\$${widget.compareAtPrice!.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: DesignTokens.textSecondary,
                                            decoration: TextDecoration.lineThrough,
                                            decorationColor: DesignTokens.error,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (widget.onAddToCart != null && !widget.isOutOfStock) ...[
                                  const SizedBox(width: 8),
                                  Semantics(
                                    button: true,
                                    label: 'common.add_to_cart_semantics'.tr(namedArgs: {'name': widget.productName}),
                                    child: GestureDetector(
                                      onTap: widget.onAddToCart,
                                      child: Container(
                                        padding: const EdgeInsets.all(14), // WCAG 2.5.8: ≥48dp touch target
                                        decoration: BoxDecoration(
                                          gradient: DesignTokens.primaryGradient,
                                          borderRadius: BorderRadius.circular(DesignTokens.radius8),
                                        ),
                                        child: const Icon(Icons.add, size: 20, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    _controller = AnimationController(duration: DesignTokens.durationNormal, vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: DesignTokens.easeOutCubic));
  }
}

/// HOT badge (score ≥ 50) uses fire gradient; RISING badge uses teal gradient.
class _TrendingBadge extends StatelessWidget {
  final int score;
  final bool isCompact;

  const _TrendingBadge({required this.score, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final isHot = score >= 50;
    final label = isHot ? 'product.trending_hot'.tr() : 'product.trending_rising'.tr();
    final colors = isHot ? [const Color(0xFFFF6B35), const Color(0xFFFF3D00)] : [const Color(0xFF00BFA5), const Color(0xFF1DE9B6)];
    final glowColor = isHot ? const Color(0xFFFF6B35) : const Color(0xFF00BFA5);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 5 : 7, vertical: isCompact ? 2 : 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.45), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: isCompact ? 9 : 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
      ),
    );
  }
}
