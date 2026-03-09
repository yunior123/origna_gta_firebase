// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/main_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Main Screen — Mobile', group: 'Home Screens', size: Size(390, 844))
Widget previewMainScreenMobile() => previewMobile(child: previewScope(child: MainScreen()));

@Preview(name: 'Main Screen — Tablet', group: 'Home Screens', size: Size(768, 1024))
Widget previewMainScreenTablet() => previewTablet(child: previewScope(child: MainScreen()));

@Preview(name: 'Main Screen — Desktop', group: 'Home Screens', size: Size(1280, 800))
Widget previewMainScreenDesktop() => previewDesktop(child: previewScope(child: MainScreen()));

@Preview(name: 'Main Screen — Web', group: 'Home Screens', size: Size(1440, 900))
Widget previewMainScreenWeb() => previewWeb(child: previewScope(child: MainScreen()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Main Screen Light — Mobile', group: 'Home Screens', size: Size(390, 844))
Widget previewMainScreenLightMobile() => previewMobile(theme: previewLightTheme, child: previewScope(child: MainScreen()));

@Preview(name: 'Main Screen Light — Tablet', group: 'Home Screens', size: Size(768, 1024))
Widget previewMainScreenLightTablet() => previewTablet(theme: previewLightTheme, child: previewScope(child: MainScreen()));

@Preview(name: 'Main Screen Light — Desktop', group: 'Home Screens', size: Size(1280, 800))
Widget previewMainScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScope(child: MainScreen()));

@Preview(name: 'Main Screen Light — Web', group: 'Home Screens', size: Size(1440, 900))
Widget previewMainScreenLightWeb() => previewWeb(theme: previewLightTheme, child: previewScope(child: MainScreen()));
