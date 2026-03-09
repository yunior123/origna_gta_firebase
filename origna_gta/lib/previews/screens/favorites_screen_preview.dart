// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/screens/favorites_screen.dart';

import '../_preview_theme.dart';

Widget _favorites() => previewScopeLoggedIn(child: FavoritesScreen());

Widget _favoritesEmpty() => previewScopeLoggedIn(
  extraOverrides: [
    favoritedProductsProvider.overrideWith((ref) => Future.value([])),
  ],
  child: FavoritesScreen(),
);

// ── Dark (default) ──────────────────────────────────────────────────────────
@Preview(name: 'Favorites / Wishlist Dark — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewFavoritesScreenMobile() => previewMobile(child: _favorites());

@Preview(name: 'Favorites / Wishlist Dark — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewFavoritesScreenTablet() => previewTablet(child: _favorites());

@Preview(name: 'Favorites / Wishlist Dark — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewFavoritesScreenDesktop() => previewDesktop(child: _favorites());

@Preview(name: 'Favorites / Wishlist Dark — Web', group: 'Screens', size: Size(1440, 900))
Widget previewFavoritesScreenWeb() => previewWeb(child: _favorites());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Favorites / Wishlist Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewFavoritesLightMobile() => previewMobile(theme: previewLightTheme, child: _favorites());

@Preview(name: 'Favorites / Wishlist Light — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewFavoritesLightTablet() => previewTablet(theme: previewLightTheme, child: _favorites());

@Preview(name: 'Favorites / Wishlist Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewFavoritesLightDesktop() => previewDesktop(theme: previewLightTheme, child: _favorites());

@Preview(name: 'Favorites / Wishlist Light — Web', group: 'Screens', size: Size(1440, 900))
Widget previewFavoritesLightWeb() => previewWeb(theme: previewLightTheme, child: _favorites());

// ── Empty State Dark ──────────────────────────────────────────────────────────
@Preview(name: 'Favorites Empty Dark — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewFavoritesEmptyMobile() => previewMobile(child: _favoritesEmpty());

@Preview(name: 'Favorites Empty Dark — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewFavoritesEmptyTablet() => previewTablet(child: _favoritesEmpty());

@Preview(name: 'Favorites Empty Dark — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewFavoritesEmptyDesktop() => previewDesktop(child: _favoritesEmpty());

@Preview(name: 'Favorites Empty Dark — Web', group: 'Screens', size: Size(1440, 900))
Widget previewFavoritesEmptyWeb() => previewWeb(child: _favoritesEmpty());

// ── Empty State Light ─────────────────────────────────────────────────────────
@Preview(name: 'Favorites Empty Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewFavoritesEmptyLightMobile() => previewMobile(theme: previewLightTheme, child: _favoritesEmpty());

@Preview(name: 'Favorites Empty Light — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewFavoritesEmptyLightTablet() => previewTablet(theme: previewLightTheme, child: _favoritesEmpty());

@Preview(name: 'Favorites Empty Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewFavoritesEmptyLightDesktop() => previewDesktop(theme: previewLightTheme, child: _favoritesEmpty());

@Preview(name: 'Favorites Empty Light — Web', group: 'Screens', size: Size(1440, 900))
Widget previewFavoritesEmptyLightWeb() => previewWeb(theme: previewLightTheme, child: _favoritesEmpty());
