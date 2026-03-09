// coverage:ignore-file
/// Flutter Widget Previewer — ModernProductCard variants.
/// Run: flutter widget-preview start
///
/// NOTE: easy_localization is NOT initialised in preview mode.
/// `.tr()` keys will render as-is (e.g. "product.add_to_cart") — acceptable for preview.
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_product_card.dart';

import 'package:origna_gta/previews/_preview_theme.dart';

// ─── Shared dummy data ────────────────────────────────────────────────────────

const _kProductName = 'Vintage Leather Jacket';
const _kPrice = 89.99;
const _kCompareAtPrice = 129.99;
const _kImageUrl = 'https://picsum.photos/seed/jacket/200/300';
const _kSellerName = 'Toronto Vintage';
const _kRating = 4.5;
const _kReviewCount = 42;
const _kShipFromCity = 'Toronto';
const _kShipFromProvince = 'ON';

/// Wrap a [ModernProductCard] in a fixed-size box so the Expanded flex inside
/// the card has a bounded constraint during preview rendering.
/// [Align] escapes tight width constraints from [previewGrid]'s Column so the
/// card stays at 220 px instead of stretching to the full panel width.
Widget _cardBox(Widget card) => Align(child: SizedBox(width: 220, height: 460, child: card));

// ─── Standard card ────────────────────────────────────────────────────────────

@Preview(name: 'Standard — dark', group: 'ProductCard')
Widget previewProductCardStandard() => previewWrapper(
  child: _cardBox(
    ModernProductCard(
      productName: _kProductName,
      price: _kPrice,
      imageUrl: _kImageUrl,
      sellerName: _kSellerName,
      rating: _kRating,
      reviewCount: _kReviewCount,
      shipFromCity: _kShipFromCity,
      shipFromProvince: _kShipFromProvince,
      onTap: () {},
      onAddToCart: () {},
    ),
  ),
);

@Preview(name: 'Standard — light', group: 'ProductCard', brightness: Brightness.light)
Widget previewProductCardStandardLight() => previewWrapper(
  theme: previewLightTheme,
  background: DesignTokens.surface,
  child: _cardBox(
    ModernProductCard(
      productName: _kProductName,
      price: _kPrice,
      imageUrl: _kImageUrl,
      sellerName: _kSellerName,
      rating: _kRating,
      reviewCount: _kReviewCount,
      shipFromCity: _kShipFromCity,
      shipFromProvince: _kShipFromProvince,
      onTap: () {},
      onAddToCart: () {},
    ),
  ),
);

// ─── Trending HOT card ────────────────────────────────────────────────────────

@Preview(name: 'Trending HOT (score 80)', group: 'ProductCard')
Widget previewProductCardTrendingHot() => previewWrapper(
  child: _cardBox(
    ModernProductCard(
      productName: _kProductName,
      price: _kPrice,
      imageUrl: _kImageUrl,
      sellerName: _kSellerName,
      rating: _kRating,
      reviewCount: _kReviewCount,
      shipFromCity: _kShipFromCity,
      shipFromProvince: _kShipFromProvince,
      isTrending: true,
      trendingScore: 80,
      onTap: () {},
      onAddToCart: () {},
    ),
  ),
);

// ─── Trending RISING card ─────────────────────────────────────────────────────

@Preview(name: 'Trending RISING (score 30)', group: 'ProductCard')
Widget previewProductCardTrendingRising() => previewWrapper(
  child: _cardBox(
    ModernProductCard(
      productName: _kProductName,
      price: _kPrice,
      imageUrl: _kImageUrl,
      sellerName: _kSellerName,
      rating: _kRating,
      reviewCount: _kReviewCount,
      shipFromCity: _kShipFromCity,
      shipFromProvince: _kShipFromProvince,
      isTrending: true,
      trendingScore: 30,
      onTap: () {},
      onAddToCart: () {},
    ),
  ),
);

// ─── Sale / compare-at price card ─────────────────────────────────────────────

@Preview(name: 'On Sale (compare-at price)', group: 'ProductCard')
Widget previewProductCardOnSale() => previewWrapper(
  child: _cardBox(
    ModernProductCard(
      productName: _kProductName,
      price: _kPrice,
      compareAtPrice: _kCompareAtPrice,
      imageUrl: _kImageUrl,
      sellerName: _kSellerName,
      rating: _kRating,
      reviewCount: _kReviewCount,
      shipFromCity: _kShipFromCity,
      shipFromProvince: _kShipFromProvince,
      onTap: () {},
      onAddToCart: () {},
    ),
  ),
);

// ─── Out of stock card ────────────────────────────────────────────────────────

@Preview(name: 'Out of Stock', group: 'ProductCard')
Widget previewProductCardOutOfStock() => previewWrapper(
  child: _cardBox(
    ModernProductCard(
      productName: _kProductName,
      price: _kPrice,
      imageUrl: _kImageUrl,
      sellerName: _kSellerName,
      rating: _kRating,
      reviewCount: _kReviewCount,
      shipFromCity: _kShipFromCity,
      shipFromProvince: _kShipFromProvince,
      isOutOfStock: true,
      onTap: () {},
      onAddToCart: () {},
    ),
  ),
);

// ─── No reviews (new product) ─────────────────────────────────────────────────

@Preview(name: 'No Reviews (new product)', group: 'ProductCard')
Widget previewProductCardNoReviews() => previewWrapper(
  child: _cardBox(
    ModernProductCard(
      productName: 'New Arrival Jacket',
      price: _kPrice,
      imageUrl: _kImageUrl,
      sellerName: _kSellerName,
      shipFromCity: _kShipFromCity,
      shipFromProvince: _kShipFromProvince,
      onTap: () {},
      onAddToCart: () {},
    ),
  ),
);

// ─── Multi-country shipping card ──────────────────────────────────────────────

@Preview(name: 'Ships from Multiple Countries', group: 'ProductCard')
Widget previewProductCardMultiCountry() => previewWrapper(
  child: _cardBox(
    ModernProductCard(
      productName: _kProductName,
      price: _kPrice,
      imageUrl: _kImageUrl,
      sellerName: _kSellerName,
      rating: _kRating,
      reviewCount: _kReviewCount,
      shipFromCountries: const ['Canada', 'Germany', 'Japan'],
      onTap: () {},
      onAddToCart: () {},
    ),
  ),
);

// ─── All variants grid ────────────────────────────────────────────────────────

@Preview(name: 'All Variants', group: 'ProductCard')
Widget previewProductCardAllVariants() => previewGrid(
  children: [
    _cardBox(
      ModernProductCard(
        productName: _kProductName,
        price: _kPrice,
        imageUrl: _kImageUrl,
        sellerName: _kSellerName,
        rating: _kRating,
        reviewCount: _kReviewCount,
        shipFromCity: _kShipFromCity,
        shipFromProvince: _kShipFromProvince,
        onTap: () {},
        onAddToCart: () {},
      ),
    ),
    _cardBox(
      ModernProductCard(
        productName: _kProductName,
        price: _kPrice,
        imageUrl: _kImageUrl,
        sellerName: _kSellerName,
        rating: _kRating,
        reviewCount: _kReviewCount,
        shipFromCity: _kShipFromCity,
        shipFromProvince: _kShipFromProvince,
        isTrending: true,
        trendingScore: 80,
        onTap: () {},
        onAddToCart: () {},
      ),
    ),
    _cardBox(
      ModernProductCard(
        productName: _kProductName,
        price: _kPrice,
        compareAtPrice: _kCompareAtPrice,
        imageUrl: _kImageUrl,
        sellerName: _kSellerName,
        rating: _kRating,
        reviewCount: _kReviewCount,
        shipFromCity: _kShipFromCity,
        shipFromProvince: _kShipFromProvince,
        onTap: () {},
        onAddToCart: () {},
      ),
    ),
    _cardBox(
      ModernProductCard(
        productName: _kProductName,
        price: _kPrice,
        imageUrl: _kImageUrl,
        sellerName: _kSellerName,
        rating: _kRating,
        reviewCount: _kReviewCount,
        shipFromCity: _kShipFromCity,
        shipFromProvince: _kShipFromProvince,
        isOutOfStock: true,
        onTap: () {},
        onAddToCart: () {},
      ),
    ),
    _cardBox(
      ModernProductCard(
        productName: 'New Arrival Jacket',
        price: _kPrice,
        imageUrl: _kImageUrl,
        sellerName: _kSellerName,
        shipFromCity: _kShipFromCity,
        shipFromProvince: _kShipFromProvince,
        onTap: () {},
        onAddToCart: () {},
      ),
    ),
    _cardBox(
      ModernProductCard(
        productName: _kProductName,
        price: _kPrice,
        imageUrl: _kImageUrl,
        sellerName: _kSellerName,
        rating: _kRating,
        reviewCount: _kReviewCount,
        shipFromCountries: const ['Canada', 'Germany', 'Japan'],
        onTap: () {},
        onAddToCart: () {},
      ),
    ),
  ],
);
