// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/seller_integration_screen.dart';
import '../_preview_theme.dart';

@Preview(name: 'Seller Integration Dark — Mobile', group: 'SellerIntegrationScreen', size: Size(390, 844))
Widget previewSellerIntegrationDarkMobile() =>
    previewMobile(theme: previewDarkTheme, child: previewScope(child: const SellerIntegrationScreen()));

@Preview(name: 'Seller Integration Dark — Tablet', group: 'SellerIntegrationScreen', size: Size(768, 1024))
Widget previewSellerIntegrationDarkTablet() =>
    previewTablet(theme: previewDarkTheme, child: previewScope(child: const SellerIntegrationScreen()));

@Preview(name: 'Seller Integration Dark — Desktop', group: 'SellerIntegrationScreen', size: Size(1280, 800))
Widget previewSellerIntegrationDarkDesktop() =>
    previewDesktop(theme: previewDarkTheme, child: previewScope(child: const SellerIntegrationScreen()));

@Preview(name: 'Seller Integration Dark — Web', group: 'SellerIntegrationScreen', size: Size(1440, 900))
Widget previewSellerIntegrationDarkWeb() =>
    previewWeb(theme: previewDarkTheme, child: previewScope(child: const SellerIntegrationScreen()));

@Preview(name: 'Seller Integration Light — Mobile', group: 'SellerIntegrationScreen', size: Size(390, 844))
Widget previewSellerIntegrationLightMobile() =>
    previewMobile(theme: previewLightTheme, child: previewScope(child: const SellerIntegrationScreen()));

@Preview(name: 'Seller Integration Light — Tablet', group: 'SellerIntegrationScreen', size: Size(768, 1024))
Widget previewSellerIntegrationLightTablet() =>
    previewTablet(theme: previewLightTheme, child: previewScope(child: const SellerIntegrationScreen()));

@Preview(name: 'Seller Integration Light — Desktop', group: 'SellerIntegrationScreen', size: Size(1280, 800))
Widget previewSellerIntegrationLightDesktop() =>
    previewDesktop(theme: previewLightTheme, child: previewScope(child: const SellerIntegrationScreen()));

@Preview(name: 'Seller Integration Light — Web', group: 'SellerIntegrationScreen', size: Size(1440, 900))
Widget previewSellerIntegrationLightWeb() =>
    previewWeb(theme: previewLightTheme, child: previewScope(child: const SellerIntegrationScreen()));
