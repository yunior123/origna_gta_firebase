// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/login_screen.dart';

import '../_preview_theme.dart';

Widget _loginContent() => previewScope(
  child: LoginScreenLayout(
    isLogin: true,
    isLoading: false,
    obscurePassword: true,
    acceptedTerms: true,
    marketingOptIn: false,
    nameController: TextEditingController(),
    emailController: TextEditingController(text: 'preview@example.com'),
    passwordController: TextEditingController(text: 'password123'),
    formKey: GlobalKey<FormState>(),
    onAuthToggle: () {},
    onAuthSubmit: () {},
    onGoogleSignIn: () {},
    onAppleSignIn: () {},
    onForgotPassword: () {},
    onToggleObscurePassword: () {},
    onTermsChanged: (v) {},
    onMarketingOptInChanged: (v) {},
  ),
);

Widget _registerContent() => previewScope(
  child: LoginScreenLayout(
    isLogin: false,
    isLoading: false,
    obscurePassword: true,
    acceptedTerms: true,
    marketingOptIn: false,
    nameController: TextEditingController(),
    emailController: TextEditingController(text: 'preview@example.com'),
    passwordController: TextEditingController(text: 'password123'),
    formKey: GlobalKey<FormState>(),
    onAuthToggle: () {},
    onAuthSubmit: () {},
    onGoogleSignIn: () {},
    onAppleSignIn: () {},
    onForgotPassword: () {},
    onToggleObscurePassword: () {},
    onTermsChanged: (v) {},
    onMarketingOptInChanged: (v) {},
  ),
);

// ── Login Dark ───────────────────────────────────────────────────────────────
@Preview(name: 'Login Dark — Mobile', group: 'Auth Screens', size: Size(390, 844))
Widget previewLoginScreenMobile() => previewMobile(child: _loginContent());

@Preview(name: 'Login Dark — Tablet', group: 'Auth Screens', size: Size(768, 1024))
Widget previewLoginScreenTablet() => previewTablet(child: _loginContent());

@Preview(name: 'Login Dark — Desktop', group: 'Auth Screens', size: Size(1280, 800))
Widget previewLoginScreenDesktop() => previewDesktop(child: _loginContent());

@Preview(name: 'Login Dark — Web', group: 'Auth Screens', size: Size(1440, 900))
Widget previewLoginScreenWeb() => previewWeb(child: _loginContent());

// ── Login Light ──────────────────────────────────────────────────────────────
@Preview(name: 'Login Light — Mobile', group: 'Auth Screens', size: Size(390, 844))
Widget previewLoginLightMobile() => previewMobile(theme: previewLightTheme, child: _loginContent());

@Preview(name: 'Login Light — Tablet', group: 'Auth Screens', size: Size(768, 1024))
Widget previewLoginLightTablet() => previewTablet(theme: previewLightTheme, child: _loginContent());

@Preview(name: 'Login Light — Desktop', group: 'Auth Screens', size: Size(1280, 800))
Widget previewLoginLightDesktop() => previewDesktop(theme: previewLightTheme, child: _loginContent());

@Preview(name: 'Login Light — Web', group: 'Auth Screens', size: Size(1440, 900))
Widget previewLoginLightWeb() => previewWeb(theme: previewLightTheme, child: _loginContent());

// ── Register Dark ─────────────────────────────────────────────────────────────
@Preview(name: 'Register Dark — Mobile', group: 'Auth Screens', size: Size(390, 844))
Widget previewRegisterScreenMobile() => previewMobile(child: _registerContent());

@Preview(name: 'Register Dark — Tablet', group: 'Auth Screens', size: Size(768, 1024))
Widget previewRegisterScreenTablet() => previewTablet(child: _registerContent());

@Preview(name: 'Register Dark — Desktop', group: 'Auth Screens', size: Size(1280, 800))
Widget previewRegisterScreenDesktop() => previewDesktop(child: _registerContent());

@Preview(name: 'Register Dark — Web', group: 'Auth Screens', size: Size(1440, 900))
Widget previewRegisterScreenWeb() => previewWeb(child: _registerContent());

// ── Register Light ────────────────────────────────────────────────────────────
@Preview(name: 'Register Light — Mobile', group: 'Auth Screens', size: Size(390, 844))
Widget previewRegisterLightMobile() => previewMobile(theme: previewLightTheme, child: _registerContent());

@Preview(name: 'Register Light — Tablet', group: 'Auth Screens', size: Size(768, 1024))
Widget previewRegisterLightTablet() => previewTablet(theme: previewLightTheme, child: _registerContent());

@Preview(name: 'Register Light — Desktop', group: 'Auth Screens', size: Size(1280, 800))
Widget previewRegisterLightDesktop() => previewDesktop(theme: previewLightTheme, child: _registerContent());

@Preview(name: 'Register Light — Web', group: 'Auth Screens', size: Size(1440, 900))
Widget previewRegisterLightWeb() => previewWeb(theme: previewLightTheme, child: _registerContent());
