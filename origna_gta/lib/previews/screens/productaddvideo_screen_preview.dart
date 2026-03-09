// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/productaddvideo_screen.dart';

import '../_preview_theme.dart';

Widget _productAddVideoContent() => previewScope(
  child: Scaffold(body: Center(child: ProductAddVideo())),
);

@Preview(name: 'Product Add Video — Mobile', group: 'Product Screens', size: Size(390, 844))
Widget previewProductAddVideoMobile() => previewMobile(child: _productAddVideoContent());

@Preview(name: 'Product Add Video — Tablet', group: 'Product Screens', size: Size(768, 1024))
Widget previewProductAddVideoTablet() => previewTablet(child: _productAddVideoContent());

@Preview(name: 'Product Add Video — Desktop', group: 'Product Screens', size: Size(1280, 800))
Widget previewProductAddVideoDesktop() => previewDesktop(child: _productAddVideoContent());

@Preview(name: 'Product Add Video — Web', group: 'Product Screens', size: Size(1440, 900))
Widget previewProductAddVideoWeb() => previewWeb(child: _productAddVideoContent());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Product Add Video Light — Mobile', group: 'Product Screens', size: Size(390, 844))
Widget previewProductAddVideoLightMobile() => previewMobile(theme: previewLightTheme, child: _productAddVideoContent());

@Preview(name: 'Product Add Video Light — Tablet', group: 'Product Screens', size: Size(768, 1024))
Widget previewProductAddVideoLightTablet() => previewTablet(theme: previewLightTheme, child: _productAddVideoContent());

@Preview(name: 'Product Add Video Light — Desktop', group: 'Product Screens', size: Size(1280, 800))
Widget previewProductAddVideoLightDesktop() => previewDesktop(theme: previewLightTheme, child: _productAddVideoContent());

@Preview(name: 'Product Add Video Light — Web', group: 'Product Screens', size: Size(1440, 900))
Widget previewProductAddVideoLightWeb() => previewWeb(theme: previewLightTheme, child: _productAddVideoContent());
