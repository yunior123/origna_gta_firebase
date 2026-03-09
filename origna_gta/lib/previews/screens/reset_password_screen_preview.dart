// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/reset_password_screen.dart';

import '../_preview_theme.dart';

Widget _resetPasswordContent() =>
    previewScope(child: ResetPasswordScreen(oobCode: 'preview-oob-code'));

@Preview(name: 'Reset Password — Mobile', group: 'Auth Screens', size: Size(390, 844))
Widget previewResetPasswordScreenMobile() => previewMobile(child: _resetPasswordContent());

@Preview(name: 'Reset Password — Tablet', group: 'Auth Screens', size: Size(768, 1024))
Widget previewResetPasswordScreenTablet() => previewTablet(child: _resetPasswordContent());

@Preview(name: 'Reset Password — Desktop', group: 'Auth Screens', size: Size(1280, 800))
Widget previewResetPasswordScreenDesktop() => previewDesktop(child: _resetPasswordContent());

@Preview(name: 'Reset Password — Web', group: 'Auth Screens', size: Size(1440, 900))
Widget previewResetPasswordScreenWeb() => previewWeb(child: _resetPasswordContent());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Reset Password Light — Mobile', group: 'Auth Screens', size: Size(390, 844))
Widget previewResetPasswordScreenLightMobile() => previewMobile(theme: previewLightTheme, child: _resetPasswordContent());

@Preview(name: 'Reset Password Light — Tablet', group: 'Auth Screens', size: Size(768, 1024))
Widget previewResetPasswordScreenLightTablet() => previewTablet(theme: previewLightTheme, child: _resetPasswordContent());

@Preview(name: 'Reset Password Light — Desktop', group: 'Auth Screens', size: Size(1280, 800))
Widget previewResetPasswordScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: _resetPasswordContent());

@Preview(name: 'Reset Password Light — Web', group: 'Auth Screens', size: Size(1440, 900))
Widget previewResetPasswordScreenLightWeb() => previewWeb(theme: previewLightTheme, child: _resetPasswordContent());
