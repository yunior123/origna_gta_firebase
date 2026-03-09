// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/seller/seller_warehouses_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Seller Warehouses — Mobile', group: 'Screens — Seller Management', size: Size(390, 844))
Widget previewSellerWarehousesScreenMobile() => previewMobile(child: previewScopeLoggedIn(child: SellerWarehousesScreen()));

@Preview(name: 'Seller Warehouses — Tablet', group: 'Screens — Seller Management', size: Size(768, 1024))
Widget previewSellerWarehousesScreenTablet() => previewTablet(child: previewScopeLoggedIn(child: SellerWarehousesScreen()));

@Preview(name: 'Seller Warehouses — Desktop', group: 'Screens — Seller Management', size: Size(1280, 800))
Widget previewSellerWarehousesScreenDesktop() => previewDesktop(child: previewScopeLoggedIn(child: SellerWarehousesScreen()));

@Preview(name: 'Seller Warehouses — Web', group: 'Screens — Seller Management', size: Size(1440, 900))
Widget previewSellerWarehousesScreenWeb() => previewWeb(child: previewScopeLoggedIn(child: SellerWarehousesScreen()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Seller Warehouses Light — Mobile', group: 'Screens — Seller Management', size: Size(390, 844))
Widget previewSellerWarehousesLightMobile() => previewMobile(theme: previewLightTheme, child: previewScopeLoggedIn(child: SellerWarehousesScreen()));

@Preview(name: 'Seller Warehouses Light — Tablet', group: 'Screens — Seller Management', size: Size(768, 1024))
Widget previewSellerWarehousesLightTablet() => previewTablet(theme: previewLightTheme, child: previewScopeLoggedIn(child: SellerWarehousesScreen()));

@Preview(name: 'Seller Warehouses Light — Desktop', group: 'Screens — Seller Management', size: Size(1280, 800))
Widget previewSellerWarehousesLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScopeLoggedIn(child: SellerWarehousesScreen()));

@Preview(name: 'Seller Warehouses Light — Web', group: 'Screens — Seller Management', size: Size(1440, 900))
Widget previewSellerWarehousesLightWeb() => previewWeb(theme: previewLightTheme, child: previewScopeLoggedIn(child: SellerWarehousesScreen()));
