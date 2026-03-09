// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/cartitem_screen.dart';

import '../_preview_theme.dart';

Widget _cartItemContent() => previewScope(
  child: Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CartItemScreen(
          productId: 'preview-id',
          cartItemId: 'preview-cart-item-id',
          item: const {'name': 'Preview Product', 'price': 9.99, 'quantity': 1},
          onRemove: () {},
        ),
      ),
    ),
  ),
);

@Preview(name: 'Cart Item — Mobile', group: 'Cart Screens', size: Size(390, 844))
Widget previewCartItemScreenMobile() => previewMobile(child: _cartItemContent());

@Preview(name: 'Cart Item — Tablet', group: 'Cart Screens', size: Size(768, 1024))
Widget previewCartItemScreenTablet() => previewTablet(child: _cartItemContent());

@Preview(name: 'Cart Item — Desktop', group: 'Cart Screens', size: Size(1280, 800))
Widget previewCartItemScreenDesktop() => previewDesktop(child: _cartItemContent());

@Preview(name: 'Cart Item — Web', group: 'Cart Screens', size: Size(1440, 900))
Widget previewCartItemScreenWeb() => previewWeb(child: _cartItemContent());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Cart Item Light — Mobile', group: 'Cart Screens', size: Size(390, 844))
Widget previewCartItemScreenLightMobile() => previewMobile(theme: previewLightTheme, child: _cartItemContent());

@Preview(name: 'Cart Item Light — Tablet', group: 'Cart Screens', size: Size(768, 1024))
Widget previewCartItemScreenLightTablet() => previewTablet(theme: previewLightTheme, child: _cartItemContent());

@Preview(name: 'Cart Item Light — Desktop', group: 'Cart Screens', size: Size(1280, 800))
Widget previewCartItemScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: _cartItemContent());

@Preview(name: 'Cart Item Light — Web', group: 'Cart Screens', size: Size(1440, 900))
Widget previewCartItemScreenLightWeb() => previewWeb(theme: previewLightTheme, child: _cartItemContent());
