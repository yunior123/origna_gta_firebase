// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/subscription_success_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Premium Upgrade Success — Mobile', group: 'Screens — Premium Flow', size: Size(390, 844))
Widget previewSubscriptionSuccessScreenMobile() => previewMobile(child: previewScopeLoggedIn(child: SubscriptionSuccessScreen()));

@Preview(name: 'Premium Upgrade Success — Tablet', group: 'Screens — Premium Flow', size: Size(768, 1024))
Widget previewSubscriptionSuccessScreenTablet() => previewTablet(child: previewScopeLoggedIn(child: SubscriptionSuccessScreen()));

@Preview(name: 'Premium Upgrade Success — Desktop', group: 'Screens — Premium Flow', size: Size(1280, 800))
Widget previewSubscriptionSuccessScreenDesktop() => previewDesktop(child: previewScopeLoggedIn(child: SubscriptionSuccessScreen()));

@Preview(name: 'Premium Upgrade Success — Web', group: 'Screens — Premium Flow', size: Size(1440, 900))
Widget previewSubscriptionSuccessScreenWeb() => previewWeb(child: previewScopeLoggedIn(child: SubscriptionSuccessScreen()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Premium Upgrade Success Light — Mobile', group: 'Screens — Premium Flow', size: Size(390, 844))
Widget previewSubscriptionSuccessLightMobile() => previewMobile(theme: previewLightTheme, child: previewScopeLoggedIn(child: SubscriptionSuccessScreen()));

@Preview(name: 'Premium Upgrade Success Light — Tablet', group: 'Screens — Premium Flow', size: Size(768, 1024))
Widget previewSubscriptionSuccessLightTablet() => previewTablet(theme: previewLightTheme, child: previewScopeLoggedIn(child: SubscriptionSuccessScreen()));

@Preview(name: 'Premium Upgrade Success Light — Desktop', group: 'Screens — Premium Flow', size: Size(1280, 800))
Widget previewSubscriptionSuccessLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScopeLoggedIn(child: SubscriptionSuccessScreen()));

@Preview(name: 'Premium Upgrade Success Light — Web', group: 'Screens — Premium Flow', size: Size(1440, 900))
Widget previewSubscriptionSuccessLightWeb() => previewWeb(theme: previewLightTheme, child: previewScopeLoggedIn(child: SubscriptionSuccessScreen()));
