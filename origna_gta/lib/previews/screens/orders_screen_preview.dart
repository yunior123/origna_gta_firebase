// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/features/orders/orders_provider.dart';
import 'package:origna_gta/screens/orders_screen.dart';

import '../_preview_theme.dart';

Widget _orders() => previewScopeLoggedIn(child: OrdersScreen());

Widget _ordersEmpty() => previewScopeLoggedIn(
  extraOverrides: [
    buyerOrdersProvider.overrideWith((ref) => Stream.value([])),
  ],
  child: OrdersScreen(),
);

Widget _ordersLoading() => previewScopeLoggedIn(
  extraOverrides: [
    buyerOrdersProvider.overrideWith((ref) => const Stream.empty()),
  ],
  child: OrdersScreen(),
);

// ── Dark (default) ──────────────────────────────────────────────────────────
@Preview(name: 'Orders Screen Dark — Mobile', group: 'Order Screens', size: Size(390, 844))
Widget previewOrdersScreenMobile() => previewMobile(child: _orders());

@Preview(name: 'Orders Screen Dark — Tablet', group: 'Order Screens', size: Size(768, 1024))
Widget previewOrdersScreenTablet() => previewTablet(child: _orders());

@Preview(name: 'Orders Screen Dark — Desktop', group: 'Order Screens', size: Size(1280, 800))
Widget previewOrdersScreenDesktop() => previewDesktop(child: _orders());

@Preview(name: 'Orders Screen Dark — Web', group: 'Order Screens', size: Size(1440, 900))
Widget previewOrdersScreenWeb() => previewWeb(child: _orders());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Orders Screen Light — Mobile', group: 'Order Screens', size: Size(390, 844))
Widget previewOrdersScreenLightMobile() => previewMobile(theme: previewLightTheme, child: _orders());

@Preview(name: 'Orders Screen Light — Tablet', group: 'Order Screens', size: Size(768, 1024))
Widget previewOrdersScreenLightTablet() => previewTablet(theme: previewLightTheme, child: _orders());

@Preview(name: 'Orders Screen Light — Desktop', group: 'Order Screens', size: Size(1280, 800))
Widget previewOrdersScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: _orders());

@Preview(name: 'Orders Screen Light — Web', group: 'Order Screens', size: Size(1440, 900))
Widget previewOrdersScreenLightWeb() => previewWeb(theme: previewLightTheme, child: _orders());

// ── Empty State Dark ──────────────────────────────────────────────────────────
@Preview(name: 'Orders Empty Dark — Mobile', group: 'Order Screens', size: Size(390, 844))
Widget previewOrdersEmptyMobile() => previewMobile(child: _ordersEmpty());

@Preview(name: 'Orders Empty Dark — Tablet', group: 'Order Screens', size: Size(768, 1024))
Widget previewOrdersEmptyTablet() => previewTablet(child: _ordersEmpty());

@Preview(name: 'Orders Empty Dark — Desktop', group: 'Order Screens', size: Size(1280, 800))
Widget previewOrdersEmptyDesktop() => previewDesktop(child: _ordersEmpty());

@Preview(name: 'Orders Empty Dark — Web', group: 'Order Screens', size: Size(1440, 900))
Widget previewOrdersEmptyWeb() => previewWeb(child: _ordersEmpty());

// ── Empty State Light ─────────────────────────────────────────────────────────
@Preview(name: 'Orders Empty Light — Mobile', group: 'Order Screens', size: Size(390, 844))
Widget previewOrdersEmptyLightMobile() => previewMobile(theme: previewLightTheme, child: _ordersEmpty());

@Preview(name: 'Orders Empty Light — Tablet', group: 'Order Screens', size: Size(768, 1024))
Widget previewOrdersEmptyLightTablet() => previewTablet(theme: previewLightTheme, child: _ordersEmpty());

@Preview(name: 'Orders Empty Light — Desktop', group: 'Order Screens', size: Size(1280, 800))
Widget previewOrdersEmptyLightDesktop() => previewDesktop(theme: previewLightTheme, child: _ordersEmpty());

@Preview(name: 'Orders Empty Light — Web', group: 'Order Screens', size: Size(1440, 900))
Widget previewOrdersEmptyLightWeb() => previewWeb(theme: previewLightTheme, child: _ordersEmpty());

// ── Loading State ─────────────────────────────────────────────────────────────
@Preview(name: 'Orders Loading Dark — Mobile', group: 'Order Screens', size: Size(390, 844))
Widget previewOrdersLoadingMobile() => previewMobile(child: _ordersLoading());

@Preview(name: 'Orders Loading Dark — Desktop', group: 'Order Screens', size: Size(1280, 800))
Widget previewOrdersLoadingDesktop() => previewDesktop(child: _ordersLoading());
