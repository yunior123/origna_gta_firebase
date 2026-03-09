// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/terms_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Specific Legal Terms — Mobile', group: 'Screens — Legal', size: Size(390, 844))
Widget previewTermsScreenMobile() => previewMobile(child: previewScope(child: TermsScreen()));

@Preview(name: 'Specific Legal Terms — Tablet', group: 'Screens — Legal', size: Size(768, 1024))
Widget previewTermsScreenTablet() => previewTablet(child: previewScope(child: TermsScreen()));

@Preview(name: 'Specific Legal Terms — Desktop', group: 'Screens — Legal', size: Size(1280, 800))
Widget previewTermsScreenDesktop() => previewDesktop(child: previewScope(child: TermsScreen()));

@Preview(name: 'Specific Legal Terms — Web', group: 'Screens — Legal', size: Size(1440, 900))
Widget previewTermsScreenWeb() => previewWeb(child: previewScope(child: TermsScreen()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Specific Legal Terms Light — Mobile', group: 'Screens — Legal', size: Size(390, 844))
Widget previewTermsScreenLightMobile() => previewMobile(theme: previewLightTheme, child: previewScope(child: TermsScreen()));

@Preview(name: 'Specific Legal Terms Light — Tablet', group: 'Screens — Legal', size: Size(768, 1024))
Widget previewTermsScreenLightTablet() => previewTablet(theme: previewLightTheme, child: previewScope(child: TermsScreen()));

@Preview(name: 'Specific Legal Terms Light — Desktop', group: 'Screens — Legal', size: Size(1280, 800))
Widget previewTermsScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScope(child: TermsScreen()));

@Preview(name: 'Specific Legal Terms Light — Web', group: 'Screens — Legal', size: Size(1440, 900))
Widget previewTermsScreenLightWeb() => previewWeb(theme: previewLightTheme, child: previewScope(child: TermsScreen()));
