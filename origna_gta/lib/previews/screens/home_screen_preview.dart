// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/home_screen.dart';

import '../_preview_theme.dart';

// Logged-out (default): previewScope — authStateProvider returns null
Widget _home() => previewScope(child: HomeScreen());

// Logged-in: previewScopeLoggedIn — userIdProvider returns a uid
Widget _homeLoggedIn() => previewScopeLoggedIn(child: HomeScreen());

// ── Dark (default) ──────────────────────────────────────────────────────────
@Preview(name: 'Home Screen Dark — Mobile', group: 'Home Screens', size: Size(390, 844))
Widget previewHomeScreenMobile() => previewMobile(child: _home());

@Preview(name: 'Home Screen Dark — Tablet', group: 'Home Screens', size: Size(768, 1024))
Widget previewHomeScreenTablet() => previewTablet(child: _home());

@Preview(name: 'Home Screen Dark — Desktop', group: 'Home Screens', size: Size(1280, 800))
Widget previewHomeScreenDesktop() => previewDesktop(child: _home());

@Preview(name: 'Home Screen Dark — Web', group: 'Home Screens', size: Size(1440, 900))
Widget previewHomeScreenWeb() => previewWeb(child: _home());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Home Screen Light — Mobile', group: 'Home Screens', size: Size(390, 844))
Widget previewHomeScreenLightMobile() => previewMobile(theme: previewLightTheme, child: _home());

@Preview(name: 'Home Screen Light — Tablet', group: 'Home Screens', size: Size(768, 1024))
Widget previewHomeScreenLightTablet() => previewTablet(theme: previewLightTheme, child: _home());

@Preview(name: 'Home Screen Light — Desktop', group: 'Home Screens', size: Size(1280, 800))
Widget previewHomeScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: _home());

@Preview(name: 'Home Screen Light — Web', group: 'Home Screens', size: Size(1440, 900))
Widget previewHomeScreenLightWeb() => previewWeb(theme: previewLightTheme, child: _home());

// ── Logged-In Dark ────────────────────────────────────────────────────────────
@Preview(name: 'Home Screen Logged-In Dark — Mobile', group: 'Home Screens', size: Size(390, 844))
Widget previewHomeScreenLoggedInMobile() => previewMobile(child: _homeLoggedIn());

@Preview(name: 'Home Screen Logged-In Dark — Tablet', group: 'Home Screens', size: Size(768, 1024))
Widget previewHomeScreenLoggedInTablet() => previewTablet(child: _homeLoggedIn());

@Preview(name: 'Home Screen Logged-In Dark — Desktop', group: 'Home Screens', size: Size(1280, 800))
Widget previewHomeScreenLoggedInDesktop() => previewDesktop(child: _homeLoggedIn());

@Preview(name: 'Home Screen Logged-In Dark — Web', group: 'Home Screens', size: Size(1440, 900))
Widget previewHomeScreenLoggedInWeb() => previewWeb(child: _homeLoggedIn());

// ── Logged-In Light ───────────────────────────────────────────────────────────
@Preview(name: 'Home Screen Logged-In Light — Mobile', group: 'Home Screens', size: Size(390, 844))
Widget previewHomeScreenLoggedInLightMobile() => previewMobile(theme: previewLightTheme, child: _homeLoggedIn());

@Preview(name: 'Home Screen Logged-In Light — Tablet', group: 'Home Screens', size: Size(768, 1024))
Widget previewHomeScreenLoggedInLightTablet() => previewTablet(theme: previewLightTheme, child: _homeLoggedIn());

@Preview(name: 'Home Screen Logged-In Light — Desktop', group: 'Home Screens', size: Size(1280, 800))
Widget previewHomeScreenLoggedInLightDesktop() => previewDesktop(theme: previewLightTheme, child: _homeLoggedIn());

@Preview(name: 'Home Screen Logged-In Light — Web', group: 'Home Screens', size: Size(1440, 900))
Widget previewHomeScreenLoggedInLightWeb() => previewWeb(theme: previewLightTheme, child: _homeLoggedIn());
