// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/screens/product_card_screen.dart';

import '../_preview_theme.dart';

Widget _productCardContent() {
  final product = Product(
    productId: 'preview-id',
    sellerId: 'test-seller',
    name: 'Standard Product Instance',
    description: 'A fantastic product for preview purposes with some descriptive text here.',
    price: 19.99,
    stockQuantity: 10,
    imageUrls: ['https://picsum.photos/400'],
    categoryId: 1,
    createdAt: DateTime.now(),
  );
  return previewScope(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: 200,
          height: 300,
          child: ProductCard(productId: 'preview-id', product: product, userModel: null),
        ),
      ),
    ),
  );
}

@Preview(name: 'Product Card Component — Mobile', group: 'Components', size: Size(390, 844))
Widget previewProductCardScreenMobile() => previewMobile(child: _productCardContent());

@Preview(name: 'Product Card Component — Tablet', group: 'Components', size: Size(768, 1024))
Widget previewProductCardScreenTablet() => previewTablet(child: _productCardContent());

@Preview(name: 'Product Card Component — Desktop', group: 'Components', size: Size(1280, 800))
Widget previewProductCardScreenDesktop() => previewDesktop(child: _productCardContent());

@Preview(name: 'Product Card Component — Web', group: 'Components', size: Size(1440, 900))
Widget previewProductCardScreenWeb() => previewWeb(child: _productCardContent());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Product Card Component Light — Mobile', group: 'Components', size: Size(390, 844))
Widget previewProductCardScreenLightMobile() => previewMobile(theme: previewLightTheme, child: _productCardContent());

@Preview(name: 'Product Card Component Light — Tablet', group: 'Components', size: Size(768, 1024))
Widget previewProductCardScreenLightTablet() => previewTablet(theme: previewLightTheme, child: _productCardContent());

@Preview(name: 'Product Card Component Light — Desktop', group: 'Components', size: Size(1280, 800))
Widget previewProductCardScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: _productCardContent());

@Preview(name: 'Product Card Component Light — Web', group: 'Components', size: Size(1440, 900))
Widget previewProductCardScreenLightWeb() => previewWeb(theme: previewLightTheme, child: _productCardContent());
