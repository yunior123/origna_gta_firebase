// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/screens/cart_screen.dart';

import '../_preview_theme.dart';

Widget _cartDark() => previewScopeLoggedIn(child: CartScreen());
Widget _cartLight() => previewScopeLoggedIn(child: CartScreen());
Widget _cartEmpty() => previewScope(
  extraOverrides: [
    cartItemsProvider.overrideWith((ref) => Stream.value([])),
  ],
  child: CartScreen(),
);

// ── Dark (default) ──────────────────────────────────────────────────────────
@Preview(name: 'Shopping Cart Dark — Mobile', group: 'Cart Screens', size: Size(390, 844))
Widget previewCartScreenMobile() => previewMobile(child: _cartDark());

@Preview(name: 'Shopping Cart Dark — Tablet', group: 'Cart Screens', size: Size(768, 1024))
Widget previewCartScreenTablet() => previewTablet(child: _cartDark());

@Preview(name: 'Shopping Cart Dark — Desktop', group: 'Cart Screens', size: Size(1280, 800))
Widget previewCartScreenDesktop() => previewDesktop(child: _cartDark());

@Preview(name: 'Shopping Cart Dark — Web', group: 'Cart Screens', size: Size(1440, 900))
Widget previewCartScreenWeb() => previewWeb(child: _cartDark());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Shopping Cart Light — Mobile', group: 'Cart Screens', size: Size(390, 844))
Widget previewCartScreenLightMobile() => previewMobile(theme: previewLightTheme, child: _cartLight());

@Preview(name: 'Shopping Cart Light — Tablet', group: 'Cart Screens', size: Size(768, 1024))
Widget previewCartScreenLightTablet() => previewTablet(theme: previewLightTheme, child: _cartLight());

@Preview(name: 'Shopping Cart Light — Desktop', group: 'Cart Screens', size: Size(1280, 800))
Widget previewCartScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: _cartLight());

@Preview(name: 'Shopping Cart Light — Web', group: 'Cart Screens', size: Size(1440, 900))
Widget previewCartScreenLightWeb() => previewWeb(theme: previewLightTheme, child: _cartLight());

// ── Empty State ───────────────────────────────────────────────────────────────
@Preview(name: 'Shopping Cart Empty — Mobile', group: 'Cart Screens', size: Size(390, 844))
Widget previewCartScreenEmptyMobile() => previewMobile(child: _cartEmpty());

@Preview(name: 'Shopping Cart Empty — Tablet', group: 'Cart Screens', size: Size(768, 1024))
Widget previewCartScreenEmptyTablet() => previewTablet(child: _cartEmpty());

@Preview(name: 'Shopping Cart Empty — Desktop', group: 'Cart Screens', size: Size(1280, 800))
Widget previewCartScreenEmptyDesktop() => previewDesktop(child: _cartEmpty());

@Preview(name: 'Shopping Cart Empty — Web', group: 'Cart Screens', size: Size(1440, 900))
Widget previewCartScreenEmptyWeb() => previewWeb(child: _cartEmpty());
