// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/shipping_approval_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Verify Shipping — Mobile', group: 'Screens — Seller Management', size: Size(390, 844))
Widget previewShippingApprovalScreenMobile() => previewMobile(child: previewScopeLoggedIn(child: ShippingApprovalScreen()));

@Preview(name: 'Verify Shipping — Tablet', group: 'Screens — Seller Management', size: Size(768, 1024))
Widget previewShippingApprovalScreenTablet() => previewTablet(child: previewScopeLoggedIn(child: ShippingApprovalScreen()));

@Preview(name: 'Verify Shipping — Desktop', group: 'Screens — Seller Management', size: Size(1280, 800))
Widget previewShippingApprovalScreenDesktop() => previewDesktop(child: previewScopeLoggedIn(child: ShippingApprovalScreen()));

@Preview(name: 'Verify Shipping — Web', group: 'Screens — Seller Management', size: Size(1440, 900))
Widget previewShippingApprovalScreenWeb() => previewWeb(child: previewScopeLoggedIn(child: ShippingApprovalScreen()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Verify Shipping Light — Mobile', group: 'Screens — Seller Management', size: Size(390, 844))
Widget previewShippingApprovalLightMobile() => previewMobile(theme: previewLightTheme, child: previewScopeLoggedIn(child: ShippingApprovalScreen()));

@Preview(name: 'Verify Shipping Light — Desktop', group: 'Screens — Seller Management', size: Size(1280, 800))
Widget previewShippingApprovalLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScopeLoggedIn(child: ShippingApprovalScreen()));

@Preview(name: 'Verify Shipping Light — Tablet', group: 'Screens — Seller Management', size: Size(768, 1024))
Widget previewShippingApprovalLightTablet() => previewTablet(theme: previewLightTheme, child: previewScopeLoggedIn(child: ShippingApprovalScreen()));

@Preview(name: 'Verify Shipping Light — Web', group: 'Screens — Seller Management', size: Size(1440, 900))
Widget previewShippingApprovalLightWeb() => previewWeb(theme: previewLightTheme, child: previewScopeLoggedIn(child: ShippingApprovalScreen()));
