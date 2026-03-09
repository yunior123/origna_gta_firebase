// coverage:ignore-file
/// Flutter Widget Previewer — CustomAppBar variants.
/// Run: flutter widget-preview start
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';

import 'package:origna_gta/previews/_preview_theme.dart';

// ─── Standard app bar (title + back button via custom leading) ────────────────
// Note: showBackButton triggers easy_localization .tr() for the tooltip.
// We supply a custom leading icon to stay locale-independent in previews.

@Preview(name: 'Standard — back button', group: 'AppBar')
Widget previewAppBarStandard() => previewWrapper(
  padding: EdgeInsets.zero,
  child: SizedBox(
    height: 80,
    child: CustomAppBar(
      title: 'Product Details',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {},
        tooltip: 'Back',
      ),
      showBackButton: false,
    ),
  ),
);

// ─── App bar with subtitle ────────────────────────────────────────────────────

@Preview(name: 'With subtitle', group: 'AppBar')
Widget previewAppBarWithSubtitle() => previewWrapper(
  padding: EdgeInsets.zero,
  child: SizedBox(
    height: 80,
    child: CustomAppBar(
      title: 'Order #ORD-4821',
      subtitle: 'Placed on March 3, 2026',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {},
        tooltip: 'Back',
      ),
      showBackButton: false,
    ),
  ),
);

// ─── App bar with actions (search + notification) ─────────────────────────────

@Preview(name: 'With actions', group: 'AppBar')
Widget previewAppBarWithActions() => previewWrapper(
  padding: EdgeInsets.zero,
  child: SizedBox(
    height: 80,
    child: CustomAppBar(
      title: 'Marketplace',
      showBackButton: false,
      actions: [
        AppBarIconButton(
          icon: Icons.search,
          onPressed: () {},
          tooltip: 'Search',
        ),
        AppBarIconButton(
          icon: Icons.notifications_outlined,
          onPressed: () {},
          tooltip: 'Notifications',
        ),
      ],
    ),
  ),
);

// ─── Main screen app bar (no back button, no leading) ─────────────────────────

@Preview(name: 'Main screen — no back', group: 'AppBar')
Widget previewAppBarMain() => previewWrapper(
  padding: EdgeInsets.zero,
  child: SizedBox(
    height: 80,
    child: AppBarFactory.main(
      title: 'Home',
      actions: [
        AppBarIconButton(
          icon: Icons.search,
          onPressed: () {},
          tooltip: 'Search',
        ),
      ],
    ),
  ),
);

// ─── Light theme variant ──────────────────────────────────────────────────────

@Preview(name: 'Light theme', group: 'AppBar', brightness: Brightness.light)
Widget previewAppBarLight() => previewWrapper(
  theme: previewLightTheme,
  background: DesignTokens.surface,
  padding: EdgeInsets.zero,
  child: SizedBox(
    height: 80,
    child: CustomAppBar(
      title: 'Settings',
      subtitle: 'Account preferences',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {},
        tooltip: 'Back',
      ),
      showBackButton: false,
    ),
  ),
);

// ─── All variants stacked ─────────────────────────────────────────────────────

@Preview(name: 'All variants', group: 'AppBar')
Widget previewAppBarAllVariants() => previewGrid(
  children: [
    SizedBox(
      height: 80,
      child: CustomAppBar(
        title: 'Product Details',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {},
          tooltip: 'Back',
        ),
        showBackButton: false,
      ),
    ),
    SizedBox(
      height: 80,
      child: CustomAppBar(
        title: 'Order #ORD-4821',
        subtitle: 'Placed on March 3, 2026',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {},
          tooltip: 'Back',
        ),
        showBackButton: false,
      ),
    ),
    SizedBox(
      height: 80,
      child: AppBarFactory.main(
        title: 'Marketplace',
        actions: [
          AppBarIconButton(
            icon: Icons.search,
            onPressed: () {},
            tooltip: 'Search',
          ),
          AppBarIconButton(
            icon: Icons.notifications_outlined,
            onPressed: () {},
            tooltip: 'Notifications',
          ),
        ],
      ),
    ),
  ],
);
