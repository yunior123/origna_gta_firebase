// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/payment_screens.dart';

import '../_preview_theme.dart';

@Preview(name: 'Payment Canceled — Mobile', group: 'Screens — Checkout Flows', size: Size(390, 844))
Widget previewPaymentCanceledScreenMobile() => previewMobile(child: const PaymentCanceledScreen());

@Preview(name: 'Payment Canceled — Tablet', group: 'Screens — Checkout Flows', size: Size(768, 1024))
Widget previewPaymentCanceledScreenTablet() => previewTablet(child: const PaymentCanceledScreen());

@Preview(name: 'Payment Canceled — Desktop', group: 'Screens — Checkout Flows', size: Size(1280, 800))
Widget previewPaymentCanceledScreenDesktop() => previewDesktop(child: const PaymentCanceledScreen());

@Preview(name: 'Payment Canceled — Web', group: 'Screens — Checkout Flows', size: Size(1440, 900))
Widget previewPaymentCanceledScreenWeb() => previewWeb(child: const PaymentCanceledScreen());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Payment Canceled Light — Mobile', group: 'Screens — Checkout Flows', size: Size(390, 844))
Widget previewPaymentCanceledLightMobile() => previewMobile(theme: previewLightTheme, child: const PaymentCanceledScreen());

@Preview(name: 'Payment Canceled Light — Tablet', group: 'Screens — Checkout Flows', size: Size(768, 1024))
Widget previewPaymentCanceledLightTablet() => previewTablet(theme: previewLightTheme, child: const PaymentCanceledScreen());

@Preview(name: 'Payment Canceled Light — Desktop', group: 'Screens — Checkout Flows', size: Size(1280, 800))
Widget previewPaymentCanceledLightDesktop() => previewDesktop(theme: previewLightTheme, child: const PaymentCanceledScreen());

@Preview(name: 'Payment Canceled Light — Web', group: 'Screens — Checkout Flows', size: Size(1440, 900))
Widget previewPaymentCanceledLightWeb() => previewWeb(theme: previewLightTheme, child: const PaymentCanceledScreen());
