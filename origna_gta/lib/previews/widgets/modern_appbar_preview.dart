// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/widgets/modern_appbar.dart';


final _navItems = [
  BottomNavItem(icon: Icons.home_rounded, label: 'Home'),
  BottomNavItem(icon: Icons.search_rounded, label: 'Search'),
  BottomNavItem(icon: Icons.favorite_border_rounded, label: 'Favorites'),
  BottomNavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
];

@Preview(name: 'AppBar — Variants', group: 'ModernAppBar')
Widget previewAppBarVariants() => previewGrid(
  children: [
    ModernAppBar(title: 'OrignaGTA', showBackButton: false),
    ModernAppBar(title: 'Product Details'),
    ModernAppBar(
      title: 'My Orders',
      showBackButton: false,
      actions: [IconButton(icon: const Icon(Icons.filter_list_rounded), onPressed: () {}, tooltip: 'Filter')],
    ),
  ],
);

@Preview(name: 'BottomNavBar — Variants', group: 'ModernAppBar')
Widget previewBottomNavVariants() => previewGrid(
  children: [
    ModernBottomNavBar(currentIndex: 0, onIndexChanged: (_) {}, items: _navItems),
    ModernBottomNavBar(currentIndex: 1, onIndexChanged: (_) {}, items: _navItems),
  ],
);

@Preview(name: 'AppBar Light — Variants', group: 'ModernAppBar')
Widget previewAppBarVariantsLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    ModernAppBar(title: 'OrignaGTA', showBackButton: false),
    ModernAppBar(title: 'Product Details'),
    ModernAppBar(
      title: 'My Orders',
      showBackButton: false,
      actions: [IconButton(icon: const Icon(Icons.filter_list_rounded), onPressed: () {}, tooltip: 'Filter')],
    ),
  ],
);

@Preview(name: 'BottomNavBar Light — Variants', group: 'ModernAppBar')
Widget previewBottomNavVariantsLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    ModernBottomNavBar(currentIndex: 0, onIndexChanged: (_) {}, items: _navItems),
    ModernBottomNavBar(currentIndex: 1, onIndexChanged: (_) {}, items: _navItems),
  ],
);
