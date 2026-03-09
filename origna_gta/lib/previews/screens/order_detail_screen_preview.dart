// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/screens/order_detail_screen.dart';

import '../_preview_theme.dart';

Widget _orderDetailContent() => previewScopeLoggedIn(
  child: OrderDetailScreenLayout(orderAsync: const AsyncValue.loading(), onBack: () {}, onRefresh: () {}),
);

@Preview(name: 'Order Detail — Mobile', group: 'Order Screens', size: Size(390, 844))
Widget previewOrderDetailScreenMobile() => previewMobile(child: _orderDetailContent());

@Preview(name: 'Order Detail — Tablet', group: 'Order Screens', size: Size(768, 1024))
Widget previewOrderDetailScreenTablet() => previewTablet(child: _orderDetailContent());

@Preview(name: 'Order Detail — Desktop', group: 'Order Screens', size: Size(1280, 800))
Widget previewOrderDetailScreenDesktop() => previewDesktop(child: _orderDetailContent());

@Preview(name: 'Order Detail — Web', group: 'Order Screens', size: Size(1440, 900))
Widget previewOrderDetailScreenWeb() => previewWeb(child: _orderDetailContent());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Order Detail Light — Mobile', group: 'Order Screens', size: Size(390, 844))
Widget previewOrderDetailScreenLightMobile() => previewMobile(theme: previewLightTheme, child: _orderDetailContent());

@Preview(name: 'Order Detail Light — Tablet', group: 'Order Screens', size: Size(768, 1024))
Widget previewOrderDetailScreenLightTablet() => previewTablet(theme: previewLightTheme, child: _orderDetailContent());

@Preview(name: 'Order Detail Light — Desktop', group: 'Order Screens', size: Size(1280, 800))
Widget previewOrderDetailScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: _orderDetailContent());

@Preview(name: 'Order Detail Light — Web', group: 'Order Screens', size: Size(1440, 900))
Widget previewOrderDetailScreenLightWeb() => previewWeb(theme: previewLightTheme, child: _orderDetailContent());
