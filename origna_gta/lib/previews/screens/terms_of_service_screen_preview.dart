// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/terms_of_service_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Terms of Service — Mobile', group: 'Screens — Legal', size: Size(390, 844))
Widget previewTermsOfServiceScreenMobile() => previewMobile(child: const TermsOfServiceScreen());

@Preview(name: 'Terms of Service — Tablet', group: 'Screens — Legal', size: Size(768, 1024))
Widget previewTermsOfServiceScreenTablet() => previewTablet(child: const TermsOfServiceScreen());

@Preview(name: 'Terms of Service — Desktop', group: 'Screens — Legal', size: Size(1280, 800))
Widget previewTermsOfServiceScreenDesktop() => previewDesktop(child: const TermsOfServiceScreen());

@Preview(name: 'Terms of Service — Web', group: 'Screens — Legal', size: Size(1440, 900))
Widget previewTermsOfServiceScreenWeb() => previewWeb(child: const TermsOfServiceScreen());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Terms of Service Light — Mobile', group: 'Screens — Legal', size: Size(390, 844))
Widget previewTermsOfServiceLightMobile() => previewMobile(theme: previewLightTheme, child: const TermsOfServiceScreen());

@Preview(name: 'Terms of Service Light — Tablet', group: 'Screens — Legal', size: Size(768, 1024))
Widget previewTermsOfServiceLightTablet() => previewTablet(theme: previewLightTheme, child: const TermsOfServiceScreen());

@Preview(name: 'Terms of Service Light — Desktop', group: 'Screens — Legal', size: Size(1280, 800))
Widget previewTermsOfServiceLightDesktop() => previewDesktop(theme: previewLightTheme, child: const TermsOfServiceScreen());

@Preview(name: 'Terms of Service Light — Web', group: 'Screens — Legal', size: Size(1440, 900))
Widget previewTermsOfServiceLightWeb() => previewWeb(theme: previewLightTheme, child: const TermsOfServiceScreen());
