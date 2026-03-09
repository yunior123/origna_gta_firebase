// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/seller_setup_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Seller Onboarding Success — Mobile', group: 'Screens — Seller Management', size: Size(390, 844))
Widget previewSellerSetupCompleteScreenMobile() => previewMobile(child: previewScope(child: SellerSetupCompleteScreen()));

@Preview(name: 'Seller Onboarding Success — Tablet', group: 'Screens — Seller Management', size: Size(768, 1024))
Widget previewSellerSetupCompleteScreenTablet() => previewTablet(child: previewScope(child: SellerSetupCompleteScreen()));

@Preview(name: 'Seller Onboarding Success — Desktop', group: 'Screens — Seller Management', size: Size(1280, 800))
Widget previewSellerSetupCompleteScreenDesktop() => previewDesktop(child: previewScope(child: SellerSetupCompleteScreen()));

@Preview(name: 'Seller Onboarding Success — Web', group: 'Screens — Seller Management', size: Size(1440, 900))
Widget previewSellerSetupCompleteScreenWeb() => previewWeb(child: previewScope(child: SellerSetupCompleteScreen()));

@Preview(name: 'Seller Onboarding Refresh — Mobile', group: 'Screens — Seller Management', size: Size(390, 844))
Widget previewSellerSetupRefreshScreenMobile() => previewMobile(child: previewScope(child: SellerSetupRefreshScreen()));

@Preview(name: 'Seller Onboarding Refresh — Tablet', group: 'Screens — Seller Management', size: Size(768, 1024))
Widget previewSellerSetupRefreshScreenTablet() => previewTablet(child: previewScope(child: SellerSetupRefreshScreen()));

@Preview(name: 'Seller Onboarding Refresh — Desktop', group: 'Screens — Seller Management', size: Size(1280, 800))
Widget previewSellerSetupRefreshScreenDesktop() => previewDesktop(child: previewScope(child: SellerSetupRefreshScreen()));

@Preview(name: 'Seller Onboarding Refresh — Web', group: 'Screens — Seller Management', size: Size(1440, 900))
Widget previewSellerSetupRefreshScreenWeb() => previewWeb(child: previewScope(child: SellerSetupRefreshScreen()));
