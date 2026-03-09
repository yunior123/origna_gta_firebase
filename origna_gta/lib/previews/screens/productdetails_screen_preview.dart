// coverage:ignore-file
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/products/stock_notification_provider.dart';
import 'package:origna_gta/features/qa/qa_provider.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/screens/productdetails_screen.dart';

import '../_preview_theme.dart';

final _fakeFirestore = FakeFirebaseFirestore();

/// Preview stub — returns false immediately, no Firebase calls.
class _PreviewStockNotifier extends StockNotificationNotifier {
  _PreviewStockNotifier(super.ref, super.productId, super.variantKey);

  @override
  Future<void> init() async => state = const AsyncValue.data(false);
}

Widget _productDetailsContent({int stockQuantity = 5}) => previewScope(
  extraOverrides: [
    // Firestore mock — blocks _productRatingsProvider + any other direct Firestore calls
    firestoreProvider.overrideWithValue(_fakeFirestore),
    productByIdProvider('preview-id').overrideWith(
      (ref) => Future.value(
        Product(
          productId: 'preview-id',
          sellerId: 'test-seller',
          name: 'Premium Headphones',
          description: 'Experience high-quality sound with these noise-canceling headphones.',
          price: 299.99,
          stockQuantity: stockQuantity,
          imageUrls: ['https://picsum.photos/800'],
          categoryId: 1,
          createdAt: DateTime.now(),
        ),
      ),
    ),
    userProfileProvider.overrideWith((ref) => Stream.value(null)),
    subscriptionStreamProvider.overrideWith((ref) => Stream.value(null)),
    qaListProvider('preview-id').overrideWith((ref) => Stream.value([])),
    similarProductsProvider((excludeProductId: 'preview-id', categoryId: 1)).overrideWith((ref) => Future.value([])),
    stockNotificationNotifierProvider.overrideWith(
      (ref, args) => _PreviewStockNotifier(ref, args.productId, args.variantKey),
    ),
  ],
  child: const ProductDetailScreen(productId: 'preview-id'),
);

// ── Dark (default) ──────────────────────────────────────────────────────────
@Preview(name: 'Product Details Dark — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewProductDetailScreenMobile() => previewMobile(child: _productDetailsContent());

@Preview(name: 'Product Details Dark — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewProductDetailScreenTablet() => previewTablet(child: _productDetailsContent());

@Preview(name: 'Product Details Dark — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewProductDetailScreenDesktop() => previewDesktop(child: _productDetailsContent());

@Preview(name: 'Product Details Dark — Web', group: 'Screens', size: Size(1440, 900))
Widget previewProductDetailScreenWeb() => previewWeb(child: _productDetailsContent());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Product Details Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewProductDetailLightMobile() => previewMobile(theme: previewLightTheme, child: _productDetailsContent());

@Preview(name: 'Product Details Light — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewProductDetailLightTablet() => previewTablet(theme: previewLightTheme, child: _productDetailsContent());

@Preview(name: 'Product Details Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewProductDetailLightDesktop() => previewDesktop(theme: previewLightTheme, child: _productDetailsContent());

@Preview(name: 'Product Details Light — Web', group: 'Screens', size: Size(1440, 900))
Widget previewProductDetailLightWeb() => previewWeb(theme: previewLightTheme, child: _productDetailsContent());

// ── Out of Stock ─────────────────────────────────────────────────────────────
@Preview(name: 'Product Details Out of Stock — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewProductDetailOosMobile() => previewMobile(child: _productDetailsContent(stockQuantity: 0));

@Preview(name: 'Product Details Out of Stock — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewProductDetailOosTablet() => previewTablet(child: _productDetailsContent(stockQuantity: 0));

@Preview(name: 'Product Details Out of Stock — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewProductDetailOosDesktop() => previewDesktop(child: _productDetailsContent(stockQuantity: 0));

@Preview(name: 'Product Details Out of Stock — Web', group: 'Screens', size: Size(1440, 900))
Widget previewProductDetailOosWeb() => previewWeb(child: _productDetailsContent(stockQuantity: 0));

// ── Out of Stock Light ────────────────────────────────────────────────────────
@Preview(name: 'Product Details Out of Stock Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewProductDetailOosLightMobile() => previewMobile(theme: previewLightTheme, child: _productDetailsContent(stockQuantity: 0));

@Preview(name: 'Product Details Out of Stock Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewProductDetailOosLightDesktop() => previewDesktop(theme: previewLightTheme, child: _productDetailsContent(stockQuantity: 0));
