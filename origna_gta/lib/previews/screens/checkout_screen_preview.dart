// coverage:ignore-file
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/screens/checkout_screen.dart';

import '../_preview_theme.dart';

final _mockSellerAddress = Address(
  street: '123 King St W',
  city: 'Toronto',
  state: 'ON',
  postalCode: 'M5H 1J9',
  country: 'Canada',
);

final _mockItems = [
  CartItemDetailModel(
    productId: 'prod-1',
    name: 'Handmade Maple Syrup',
    description: 'Pure Quebec amber maple syrup, 500ml',
    price: 24.99,
    imageUrls: [],
    quantity: 2,
    createdAt: Timestamp.fromDate(DateTime(2026, 3, 1)),
    sellerAddress: _mockSellerAddress,
    sellerId: 'seller-1',
    sellerName: 'Maple Artisans Co.',
    madeInCountry: 'Canada',
    estimatedShipDays: 3,
  ),
  CartItemDetailModel(
    productId: 'prod-2',
    name: 'Artisan Quebec Cheese Board',
    description: 'Selection of aged Quebec cheeses',
    price: 45.00,
    imageUrls: [],
    quantity: 1,
    createdAt: Timestamp.fromDate(DateTime(2026, 3, 1)),
    sellerAddress: _mockSellerAddress,
    sellerId: 'seller-2',
    sellerName: 'Fromagerie de Quebec',
    madeInCountry: 'Canada',
    estimatedShipDays: 2,
    freeShipping: true,
  ),
];

Widget _checkoutContent() => previewScopeLoggedIn(
  child: CheckoutScreen(items: _mockItems, total: 94.98),
);

// Single-item checkout
Widget _checkoutSingleItem() => previewScopeLoggedIn(
  child: CheckoutScreen(items: [_mockItems.first], total: 49.98),
);

// ── Dark (default) ──────────────────────────────────────────────────────────
@Preview(name: 'Checkout Dark — Mobile', group: 'Cart Screens', size: Size(390, 844))
Widget previewCheckoutScreenMobile() => previewMobile(child: _checkoutContent());

@Preview(name: 'Checkout Dark — Tablet', group: 'Cart Screens', size: Size(768, 1024))
Widget previewCheckoutScreenTablet() => previewTablet(child: _checkoutContent());

@Preview(name: 'Checkout Dark — Desktop', group: 'Cart Screens', size: Size(1280, 800))
Widget previewCheckoutScreenDesktop() => previewDesktop(child: _checkoutContent());

@Preview(name: 'Checkout Dark — Web', group: 'Cart Screens', size: Size(1440, 900))
Widget previewCheckoutScreenWeb() => previewWeb(child: _checkoutContent());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Checkout Light — Mobile', group: 'Cart Screens', size: Size(390, 844))
Widget previewCheckoutLightMobile() => previewMobile(theme: previewLightTheme, child: _checkoutContent());

@Preview(name: 'Checkout Light — Tablet', group: 'Cart Screens', size: Size(768, 1024))
Widget previewCheckoutLightTablet() => previewTablet(theme: previewLightTheme, child: _checkoutContent());

@Preview(name: 'Checkout Light — Desktop', group: 'Cart Screens', size: Size(1280, 800))
Widget previewCheckoutLightDesktop() => previewDesktop(theme: previewLightTheme, child: _checkoutContent());

@Preview(name: 'Checkout Light — Web', group: 'Cart Screens', size: Size(1440, 900))
Widget previewCheckoutLightWeb() => previewWeb(theme: previewLightTheme, child: _checkoutContent());

// ── Single Item Dark ──────────────────────────────────────────────────────────
@Preview(name: 'Checkout Single Item Dark — Mobile', group: 'Cart Screens', size: Size(390, 844))
Widget previewCheckoutSingleMobile() => previewMobile(child: _checkoutSingleItem());

@Preview(name: 'Checkout Single Item Dark — Tablet', group: 'Cart Screens', size: Size(768, 1024))
Widget previewCheckoutSingleTablet() => previewTablet(child: _checkoutSingleItem());

@Preview(name: 'Checkout Single Item Dark — Desktop', group: 'Cart Screens', size: Size(1280, 800))
Widget previewCheckoutSingleDesktop() => previewDesktop(child: _checkoutSingleItem());

@Preview(name: 'Checkout Single Item Dark — Web', group: 'Cart Screens', size: Size(1440, 900))
Widget previewCheckoutSingleWeb() => previewWeb(child: _checkoutSingleItem());

// ── Single Item Light ─────────────────────────────────────────────────────────
@Preview(name: 'Checkout Single Item Light — Mobile', group: 'Cart Screens', size: Size(390, 844))
Widget previewCheckoutSingleLightMobile() => previewMobile(theme: previewLightTheme, child: _checkoutSingleItem());

@Preview(name: 'Checkout Single Item Light — Desktop', group: 'Cart Screens', size: Size(1280, 800))
Widget previewCheckoutSingleLightDesktop() => previewDesktop(theme: previewLightTheme, child: _checkoutSingleItem());
