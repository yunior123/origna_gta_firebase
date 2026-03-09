// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/widgets/modern_product_card.dart';

/// [Align] escapes tight width constraints from [previewGrid]'s Column so the
/// card stays at 220 px instead of stretching to the full panel width.
Widget _card(Widget w) => Align(child: SizedBox(width: 220, height: 460, child: w));

@Preview(name: 'Modern Product Card — States', group: 'ModernProductCard')
Widget previewProductCardStates() => previewGrid(
  children: [
    _card(ModernProductCard(
      productName: 'Limited Edition Winter Parka',
      price: 299.00,
      imageUrl: 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?q=80&w=3087&auto=format&fit=crop',
      sellerName: 'Northern Gear',
      onTap: () {},
      isOutOfStock: true,
    )),
    _card(ModernProductCard(
      productName: 'Pacific Salmon Fillets (Fresh)',
      price: 18.50,
      imageUrl: '', // Empty URL to trigger placeholder
      sellerName: 'Ocean Harvest',
      rating: 4.5,
      reviewCount: 22,
      onTap: () {},
      onAddToCart: () {},
      shipFromCountries: const ['Canada', 'USA'],
      isTrending: true,
      trendingScore: 40,
    )),
  ],
);

@Preview(name: 'Modern Product Card — Variants', group: 'ModernProductCard')
Widget previewProductCardVariants() => previewGrid(
  children: [
    _card(ModernProductCard(
      productName: 'Handmade Canadian Maple Syrup',
      price: 24.99,
      imageUrl: 'https://images.unsplash.com/photo-1589182373726-e4f658ab50f0?q=80&w=3087&auto=format&fit=crop',
      sellerName: 'Maple Artisans Co.',
      rating: 4.8,
      reviewCount: 154,
      onTap: () {},
      onAddToCart: () {},
      shipFromCity: 'Toronto',
      shipFromProvince: 'ON',
      shipFromCountry: 'Canada',
    )),
    _card(ModernProductCard(
      productName: 'Artisan Quebec Cheese Board',
      price: 45.00,
      compareAtPrice: 55.00,
      imageUrl: 'https://images.unsplash.com/photo-1631451095765-2c91616fc9e6?q=80&w=3087&auto=format&fit=crop',
      sellerName: 'Fromagerie de Quebec',
      rating: 4.9,
      reviewCount: 89,
      onTap: () {},
      onAddToCart: () {},
      shipFromCity: 'Quebec City',
      shipFromProvince: 'QC',
      shipFromCountry: 'Canada',
      isTrending: true,
      trendingScore: 85,
    )),
  ],
);

@Preview(name: 'Modern Product Card Light — States', group: 'ModernProductCard')
Widget previewProductCardStatesLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    _card(ModernProductCard(
      productName: 'Limited Edition Winter Parka',
      price: 299.00,
      imageUrl: 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?q=80&w=3087&auto=format&fit=crop',
      sellerName: 'Northern Gear',
      onTap: () {},
      isOutOfStock: true,
    )),
    _card(ModernProductCard(
      productName: 'Pacific Salmon Fillets (Fresh)',
      price: 18.50,
      imageUrl: '',
      sellerName: 'Ocean Harvest',
      rating: 4.5,
      reviewCount: 22,
      onTap: () {},
      onAddToCart: () {},
      shipFromCountries: const ['Canada', 'USA'],
      isTrending: true,
      trendingScore: 40,
    )),
  ],
);

@Preview(name: 'Modern Product Card Light — Variants', group: 'ModernProductCard')
Widget previewProductCardVariantsLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    _card(ModernProductCard(
      productName: 'Handmade Canadian Maple Syrup',
      price: 24.99,
      imageUrl: 'https://images.unsplash.com/photo-1589182373726-e4f658ab50f0?q=80&w=3087&auto=format&fit=crop',
      sellerName: 'Maple Artisans Co.',
      rating: 4.8,
      reviewCount: 154,
      onTap: () {},
      onAddToCart: () {},
      shipFromCity: 'Toronto',
      shipFromProvince: 'ON',
      shipFromCountry: 'Canada',
    )),
    _card(ModernProductCard(
      productName: 'Artisan Quebec Cheese Board',
      price: 45.00,
      compareAtPrice: 55.00,
      imageUrl: 'https://images.unsplash.com/photo-1631451095765-2c91616fc9e6?q=80&w=3087&auto=format&fit=crop',
      sellerName: 'Fromagerie de Quebec',
      rating: 4.9,
      reviewCount: 89,
      onTap: () {},
      onAddToCart: () {},
      shipFromCity: 'Quebec City',
      shipFromProvince: 'QC',
      shipFromCountry: 'Canada',
      isTrending: true,
      trendingScore: 85,
    )),
  ],
);
