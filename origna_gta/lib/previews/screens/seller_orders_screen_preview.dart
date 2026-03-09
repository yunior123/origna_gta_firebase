// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/seller_orders_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Seller Orders — Mobile', group: 'Screens — Seller Management', size: Size(390, 844))
Widget previewSellerOrdersScreenMobile() => previewMobile(child: previewScopeLoggedIn(child: SellerOrdersScreen()));

@Preview(name: 'Seller Orders — Tablet', group: 'Screens — Seller Management', size: Size(768, 1024))
Widget previewSellerOrdersScreenTablet() => previewTablet(child: previewScopeLoggedIn(child: SellerOrdersScreen()));

@Preview(name: 'Seller Orders — Desktop', group: 'Screens — Seller Management', size: Size(1280, 800))
Widget previewSellerOrdersScreenDesktop() => previewDesktop(child: previewScopeLoggedIn(child: SellerOrdersScreen()));

@Preview(name: 'Seller Orders — Web', group: 'Screens — Seller Management', size: Size(1440, 900))
Widget previewSellerOrdersScreenWeb() => previewWeb(child: previewScopeLoggedIn(child: SellerOrdersScreen()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Seller Orders Light — Mobile', group: 'Screens — Seller Management', size: Size(390, 844))
Widget previewSellerOrdersLightMobile() => previewMobile(theme: previewLightTheme, child: previewScopeLoggedIn(child: SellerOrdersScreen()));

@Preview(name: 'Seller Orders Light — Desktop', group: 'Screens — Seller Management', size: Size(1280, 800))
Widget previewSellerOrdersLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScopeLoggedIn(child: SellerOrdersScreen()));

@Preview(name: 'Seller Orders Light — Tablet', group: 'Screens — Seller Management', size: Size(768, 1024))
Widget previewSellerOrdersLightTablet() => previewTablet(theme: previewLightTheme, child: previewScopeLoggedIn(child: SellerOrdersScreen()));

@Preview(name: 'Seller Orders Light — Web', group: 'Screens — Seller Management', size: Size(1440, 900))
Widget previewSellerOrdersLightWeb() => previewWeb(theme: previewLightTheme, child: previewScopeLoggedIn(child: SellerOrdersScreen()));
