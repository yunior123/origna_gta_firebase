// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/editaddress_screen.dart';

import '../_preview_theme.dart';

Widget _addEditAddress() => previewScopeLoggedIn(child: AddEditAddressScreen());

// ── Dark (default) ──────────────────────────────────────────────────────────
@Preview(name: 'Manage Address Dark — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewAddEditAddressScreenMobile() => previewMobile(child: _addEditAddress());

@Preview(name: 'Manage Address Dark — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewAddEditAddressScreenTablet() => previewTablet(child: _addEditAddress());

@Preview(name: 'Manage Address Dark — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewAddEditAddressScreenDesktop() => previewDesktop(child: _addEditAddress());

@Preview(name: 'Manage Address Dark — Web', group: 'Screens', size: Size(1440, 900))
Widget previewAddEditAddressScreenWeb() => previewWeb(child: _addEditAddress());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Manage Address Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewAddEditAddressLightMobile() => previewMobile(theme: previewLightTheme, child: _addEditAddress());

@Preview(name: 'Manage Address Light — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewAddEditAddressLightTablet() => previewTablet(theme: previewLightTheme, child: _addEditAddress());

@Preview(name: 'Manage Address Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewAddEditAddressLightDesktop() => previewDesktop(theme: previewLightTheme, child: _addEditAddress());

@Preview(name: 'Manage Address Light — Web', group: 'Screens', size: Size(1440, 900))
Widget previewAddEditAddressLightWeb() => previewWeb(theme: previewLightTheme, child: _addEditAddress());
