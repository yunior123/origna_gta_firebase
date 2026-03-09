// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/models/generated/product_models.dart';
import 'package:origna_gta/screens/editproduct_screen.dart';

import '../_preview_theme.dart';

Widget _editProductContent() => previewScope(
  child: EditProductScreen(
    product: Product(
      productId: 'mock-id',
      name: 'Mock Product',
      price: 100.0,
      description: 'Mock Description',
      imageUrls: ['https://via.placeholder.com/150'],
      sellerId: 'mock-seller',
      categoryId: 1,
      stockQuantity: 10,
      createdAt: DateTime.now(),
    ),
  ),
);

@Preview(name: 'Edit Product — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewEditProductScreenMobile() => previewMobile(child: _editProductContent());

@Preview(name: 'Edit Product — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewEditProductScreenTablet() => previewTablet(child: _editProductContent());

@Preview(name: 'Edit Product — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewEditProductScreenDesktop() => previewDesktop(child: _editProductContent());

@Preview(name: 'Edit Product — Web', group: 'Screens', size: Size(1440, 900))
Widget previewEditProductScreenWeb() => previewWeb(child: _editProductContent());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Edit Product Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewEditProductScreenLightMobile() => previewMobile(theme: previewLightTheme, child: _editProductContent());

@Preview(name: 'Edit Product Light — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewEditProductScreenLightTablet() => previewTablet(theme: previewLightTheme, child: _editProductContent());

@Preview(name: 'Edit Product Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewEditProductScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: _editProductContent());

@Preview(name: 'Edit Product Light — Web', group: 'Screens', size: Size(1440, 900))
Widget previewEditProductScreenLightWeb() => previewWeb(theme: previewLightTheme, child: _editProductContent());
