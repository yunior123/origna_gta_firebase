// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/seller_products_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Seller Inventory — Mobile', group: 'Screens — Seller Management', size: Size(390, 844))
Widget previewSellerProductsScreenMobile() => previewMobile(child: previewScope(child: SellerProductsScreen()));

@Preview(name: 'Seller Inventory — Tablet', group: 'Screens — Seller Management', size: Size(768, 1024))
Widget previewSellerProductsScreenTablet() => previewTablet(child: previewScope(child: SellerProductsScreen()));

@Preview(name: 'Seller Inventory — Desktop', group: 'Screens — Seller Management', size: Size(1280, 800))
Widget previewSellerProductsScreenDesktop() => previewDesktop(child: previewScope(child: SellerProductsScreen()));

@Preview(name: 'Seller Inventory — Web', group: 'Screens — Seller Management', size: Size(1440, 900))
Widget previewSellerProductsScreenWeb() => previewWeb(child: previewScope(child: SellerProductsScreen()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Seller Inventory Light — Mobile', group: 'Screens — Seller Management', size: Size(390, 844))
Widget previewSellerProductsLightMobile() => previewMobile(theme: previewLightTheme, child: previewScope(child: SellerProductsScreen()));

@Preview(name: 'Seller Inventory Light — Tablet', group: 'Screens — Seller Management', size: Size(768, 1024))
Widget previewSellerProductsLightTablet() => previewTablet(theme: previewLightTheme, child: previewScope(child: SellerProductsScreen()));

@Preview(name: 'Seller Inventory Light — Desktop', group: 'Screens — Seller Management', size: Size(1280, 800))
Widget previewSellerProductsLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScope(child: SellerProductsScreen()));

@Preview(name: 'Seller Inventory Light — Web', group: 'Screens — Seller Management', size: Size(1440, 900))
Widget previewSellerProductsLightWeb() => previewWeb(theme: previewLightTheme, child: previewScope(child: SellerProductsScreen()));
