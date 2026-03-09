// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/productaddimages_screen.dart';

import '../_preview_theme.dart';

Widget _productAddImagesContent() => previewScope(
  child: Scaffold(body: Center(child: ProductAddImages(imageModels: []))),
);

@Preview(name: 'Product Add Images — Mobile', group: 'Product Screens', size: Size(390, 844))
Widget previewProductAddImagesMobile() => previewMobile(child: _productAddImagesContent());

@Preview(name: 'Product Add Images — Tablet', group: 'Product Screens', size: Size(768, 1024))
Widget previewProductAddImagesTablet() => previewTablet(child: _productAddImagesContent());

@Preview(name: 'Product Add Images — Desktop', group: 'Product Screens', size: Size(1280, 800))
Widget previewProductAddImagesDesktop() => previewDesktop(child: _productAddImagesContent());

@Preview(name: 'Product Add Images — Web', group: 'Product Screens', size: Size(1440, 900))
Widget previewProductAddImagesWeb() => previewWeb(child: _productAddImagesContent());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Product Add Images Light — Mobile', group: 'Product Screens', size: Size(390, 844))
Widget previewProductAddImagesLightMobile() => previewMobile(theme: previewLightTheme, child: _productAddImagesContent());

@Preview(name: 'Product Add Images Light — Tablet', group: 'Product Screens', size: Size(768, 1024))
Widget previewProductAddImagesLightTablet() => previewTablet(theme: previewLightTheme, child: _productAddImagesContent());

@Preview(name: 'Product Add Images Light — Desktop', group: 'Product Screens', size: Size(1280, 800))
Widget previewProductAddImagesLightDesktop() => previewDesktop(theme: previewLightTheme, child: _productAddImagesContent());

@Preview(name: 'Product Add Images Light — Web', group: 'Product Screens', size: Size(1440, 900))
Widget previewProductAddImagesLightWeb() => previewWeb(theme: previewLightTheme, child: _productAddImagesContent());
