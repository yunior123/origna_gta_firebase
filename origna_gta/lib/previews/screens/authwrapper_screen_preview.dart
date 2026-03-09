// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/authwrapper_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Auth Wrapper — Mobile', group: 'Auth Screens', size: Size(390, 844))
Widget previewAuthWrapperScreenMobile() => previewMobile(child: previewScope(child: AuthWrapper()));

@Preview(name: 'Auth Wrapper — Tablet', group: 'Auth Screens', size: Size(768, 1024))
Widget previewAuthWrapperScreenTablet() => previewTablet(child: previewScope(child: AuthWrapper()));

@Preview(name: 'Auth Wrapper — Desktop', group: 'Auth Screens', size: Size(1280, 800))
Widget previewAuthWrapperScreenDesktop() => previewDesktop(child: previewScope(child: AuthWrapper()));

@Preview(name: 'Auth Wrapper — Web', group: 'Auth Screens', size: Size(1440, 900))
Widget previewAuthWrapperScreenWeb() => previewWeb(child: previewScope(child: AuthWrapper()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Auth Wrapper Light — Mobile', group: 'Auth Screens', size: Size(390, 844))
Widget previewAuthWrapperLightMobile() => previewMobile(theme: previewLightTheme, child: previewScope(child: AuthWrapper()));

@Preview(name: 'Auth Wrapper Light — Tablet', group: 'Auth Screens', size: Size(768, 1024))
Widget previewAuthWrapperLightTablet() => previewTablet(theme: previewLightTheme, child: previewScope(child: AuthWrapper()));

@Preview(name: 'Auth Wrapper Light — Desktop', group: 'Auth Screens', size: Size(1280, 800))
Widget previewAuthWrapperLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScope(child: AuthWrapper()));

@Preview(name: 'Auth Wrapper Light — Web', group: 'Auth Screens', size: Size(1440, 900))
Widget previewAuthWrapperLightWeb() => previewWeb(theme: previewLightTheme, child: previewScope(child: AuthWrapper()));
