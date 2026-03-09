// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/features/subscription/subscription_state.dart';
import 'package:origna_gta/screens/subscription_screen.dart';

import '../_preview_theme.dart';

// Free user (no subscription)
Widget _subscriptionFreeUser() => previewScope(child: SubscriptionScreen());

// Premium user — already subscribed
Widget _subscriptionPremiumUser() => previewScope(
  extraOverrides: [
    subscriptionStreamProvider.overrideWith(
      (ref) => Stream.value(SubscriptionInfo(status: 'active', isPremium: true)),
    ),
  ],
  child: SubscriptionScreen(),
);

@Preview(name: 'Premium Subscription Plans — Mobile', group: 'Screens — Premium Flow', size: Size(390, 844))
Widget previewSubscriptionScreenMobile() => previewMobile(child: _subscriptionFreeUser());

@Preview(name: 'Premium Subscription Plans — Tablet', group: 'Screens — Premium Flow', size: Size(768, 1024))
Widget previewSubscriptionScreenTablet() => previewTablet(child: previewScope(child: SubscriptionScreen()));

@Preview(name: 'Premium Subscription Plans — Desktop', group: 'Screens — Premium Flow', size: Size(1280, 800))
Widget previewSubscriptionScreenDesktop() => previewDesktop(child: previewScope(child: SubscriptionScreen()));

@Preview(name: 'Premium Subscription Plans — Web', group: 'Screens — Premium Flow', size: Size(1440, 900))
Widget previewSubscriptionScreenWeb() => previewWeb(child: previewScope(child: SubscriptionScreen()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Premium Subscription Plans Light — Mobile', group: 'Screens — Premium Flow', size: Size(390, 844))
Widget previewSubscriptionLightMobile() => previewMobile(theme: previewLightTheme, child: previewScope(child: SubscriptionScreen()));

@Preview(name: 'Premium Subscription Plans Light — Desktop', group: 'Screens — Premium Flow', size: Size(1280, 800))
Widget previewSubscriptionLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScope(child: SubscriptionScreen()));

@Preview(name: 'Premium Subscription Plans Light — Tablet', group: 'Screens — Premium Flow', size: Size(768, 1024))
Widget previewSubscriptionLightTablet() => previewTablet(theme: previewLightTheme, child: previewScope(child: SubscriptionScreen()));

@Preview(name: 'Premium Subscription Plans Light — Web', group: 'Screens — Premium Flow', size: Size(1440, 900))
Widget previewSubscriptionLightWeb() => previewWeb(theme: previewLightTheme, child: previewScope(child: SubscriptionScreen()));

// ── Premium User (already subscribed) ────────────────────────────────────────
@Preview(name: 'Premium Member View Dark — Mobile', group: 'Screens — Premium Flow', size: Size(390, 844))
Widget previewSubscriptionPremiumMobile() => previewMobile(child: _subscriptionPremiumUser());

@Preview(name: 'Premium Member View Dark — Tablet', group: 'Screens — Premium Flow', size: Size(768, 1024))
Widget previewSubscriptionPremiumTablet() => previewTablet(child: _subscriptionPremiumUser());

@Preview(name: 'Premium Member View Dark — Desktop', group: 'Screens — Premium Flow', size: Size(1280, 800))
Widget previewSubscriptionPremiumDesktop() => previewDesktop(child: _subscriptionPremiumUser());

@Preview(name: 'Premium Member View Dark — Web', group: 'Screens — Premium Flow', size: Size(1440, 900))
Widget previewSubscriptionPremiumWeb() => previewWeb(child: _subscriptionPremiumUser());

@Preview(name: 'Premium Member View Light — Mobile', group: 'Screens — Premium Flow', size: Size(390, 844))
Widget previewSubscriptionPremiumLightMobile() => previewMobile(theme: previewLightTheme, child: _subscriptionPremiumUser());

@Preview(name: 'Premium Member View Light — Desktop', group: 'Screens — Premium Flow', size: Size(1280, 800))
Widget previewSubscriptionPremiumLightDesktop() => previewDesktop(theme: previewLightTheme, child: _subscriptionPremiumUser());
