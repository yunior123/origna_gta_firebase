// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/screens/addressmanagement_screen.dart';

import '../_preview_theme.dart';

final _mockAddresses = [
  Address(
    street: '100 King St W',
    city: 'Toronto',
    state: 'ON',
    postalCode: 'M5X 1A9',
    country: 'Canada',
  ),
  Address(
    street: '200 Bloor St E',
    city: 'Toronto',
    state: 'ON',
    postalCode: 'M4W 1E6',
    country: 'Canada',
  ),
];

Widget _addressManagement() => previewScope(child: AddressManagementScreen());

Widget _addressManagementEmpty() => previewScopeLoggedIn(
  extraOverrides: [
    userAddressesProvider.overrideWith((ref) => Stream.value([])),
  ],
  child: AddressManagementScreen(),
);

Widget _addressManagementWithAddresses() => previewScopeLoggedIn(
  extraOverrides: [
    userAddressesProvider.overrideWith((ref) => Stream.value(_mockAddresses)),
  ],
  child: AddressManagementScreen(),
);

@Preview(name: 'Address Management — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewAddressManagementScreenMobile() => previewMobile(child: _addressManagement());

@Preview(name: 'Address Management — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewAddressManagementScreenTablet() => previewTablet(child: previewScope(child: AddressManagementScreen()));

@Preview(name: 'Address Management — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewAddressManagementScreenDesktop() => previewDesktop(child: previewScope(child: AddressManagementScreen()));

@Preview(name: 'Address Management — Web', group: 'Screens', size: Size(1440, 900))
Widget previewAddressManagementScreenWeb() => previewWeb(child: previewScope(child: AddressManagementScreen()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Address Management Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewAddressManagementLightMobile() => previewMobile(theme: previewLightTheme, child: previewScope(child: AddressManagementScreen()));

@Preview(name: 'Address Management Light — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewAddressManagementLightTablet() => previewTablet(theme: previewLightTheme, child: previewScope(child: AddressManagementScreen()));

@Preview(name: 'Address Management Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewAddressManagementLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScope(child: AddressManagementScreen()));

@Preview(name: 'Address Management Light — Web', group: 'Screens', size: Size(1440, 900))
Widget previewAddressManagementLightWeb() => previewWeb(theme: previewLightTheme, child: previewScope(child: AddressManagementScreen()));

// ── Empty State Dark ──────────────────────────────────────────────────────────
@Preview(name: 'Address Management Empty Dark — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewAddressManagementEmptyMobile() => previewMobile(child: _addressManagementEmpty());

@Preview(name: 'Address Management Empty Dark — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewAddressManagementEmptyTablet() => previewTablet(child: _addressManagementEmpty());

@Preview(name: 'Address Management Empty Dark — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewAddressManagementEmptyDesktop() => previewDesktop(child: _addressManagementEmpty());

@Preview(name: 'Address Management Empty Dark — Web', group: 'Screens', size: Size(1440, 900))
Widget previewAddressManagementEmptyWeb() => previewWeb(child: _addressManagementEmpty());

// ── With Addresses Dark ───────────────────────────────────────────────────────
@Preview(name: 'Address Management With Addresses Dark — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewAddressManagementWithAddrMobile() => previewMobile(child: _addressManagementWithAddresses());

@Preview(name: 'Address Management With Addresses Dark — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewAddressManagementWithAddrTablet() => previewTablet(child: _addressManagementWithAddresses());

@Preview(name: 'Address Management With Addresses Dark — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewAddressManagementWithAddrDesktop() => previewDesktop(child: _addressManagementWithAddresses());

@Preview(name: 'Address Management With Addresses Dark — Web', group: 'Screens', size: Size(1440, 900))
Widget previewAddressManagementWithAddrWeb() => previewWeb(child: _addressManagementWithAddresses());

// ── With Addresses Light ──────────────────────────────────────────────────────
@Preview(name: 'Address Management With Addresses Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewAddressManagementWithAddrLightMobile() => previewMobile(theme: previewLightTheme, child: _addressManagementWithAddresses());

@Preview(name: 'Address Management With Addresses Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewAddressManagementWithAddrLightDesktop() => previewDesktop(theme: previewLightTheme, child: _addressManagementWithAddresses());
