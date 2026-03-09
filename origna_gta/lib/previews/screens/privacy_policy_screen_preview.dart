// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/privacy_policy_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Privacy Policy — Mobile', group: 'Screens — Legal', size: Size(390, 844))
Widget previewPrivacyPolicyScreenMobile() => previewMobile(child: const PrivacyPolicyScreen());

@Preview(name: 'Privacy Policy — Tablet', group: 'Screens — Legal', size: Size(768, 1024))
Widget previewPrivacyPolicyScreenTablet() => previewTablet(child: const PrivacyPolicyScreen());

@Preview(name: 'Privacy Policy — Desktop', group: 'Screens — Legal', size: Size(1280, 800))
Widget previewPrivacyPolicyScreenDesktop() => previewDesktop(child: const PrivacyPolicyScreen());

@Preview(name: 'Privacy Policy — Web', group: 'Screens — Legal', size: Size(1440, 900))
Widget previewPrivacyPolicyScreenWeb() => previewWeb(child: const PrivacyPolicyScreen());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Privacy Policy Light — Mobile', group: 'Screens — Legal', size: Size(390, 844))
Widget previewPrivacyPolicyLightMobile() => previewMobile(theme: previewLightTheme, child: const PrivacyPolicyScreen());

@Preview(name: 'Privacy Policy Light — Tablet', group: 'Screens — Legal', size: Size(768, 1024))
Widget previewPrivacyPolicyLightTablet() => previewTablet(theme: previewLightTheme, child: const PrivacyPolicyScreen());

@Preview(name: 'Privacy Policy Light — Desktop', group: 'Screens — Legal', size: Size(1280, 800))
Widget previewPrivacyPolicyLightDesktop() => previewDesktop(theme: previewLightTheme, child: const PrivacyPolicyScreen());

@Preview(name: 'Privacy Policy Light — Web', group: 'Screens — Legal', size: Size(1440, 900))
Widget previewPrivacyPolicyLightWeb() => previewWeb(theme: previewLightTheme, child: const PrivacyPolicyScreen());
