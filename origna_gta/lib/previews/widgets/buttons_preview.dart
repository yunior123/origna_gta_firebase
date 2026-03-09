// coverage:ignore-file
/// Flutter Widget Previewer — ModernButton variants.
/// Run: flutter widget-preview start
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_button.dart';

import 'package:origna_gta/previews/_preview_theme.dart';

// ─── Primary Button ──────────────────────────────────────────────────────────

@Preview(name: 'Primary — dark', group: 'Buttons')
Widget previewPrimaryButtonDark() => previewWrapper(
  child: ModernButton(
    label: 'Checkout',
    onPressed: () {},
  ),
);

@Preview(name: 'Primary — light', group: 'Buttons', brightness: Brightness.light)
Widget previewPrimaryButtonLight() => previewWrapper(
  theme: previewLightTheme,
  background: DesignTokens.surface,
  child: ModernButton(
    label: 'Checkout',
    onPressed: () {},
  ),
);

// ─── Loading State ────────────────────────────────────────────────────────────

@Preview(name: 'Loading', group: 'Buttons')
Widget previewButtonLoading() => previewWrapper(
  child: ModernButton(
    label: 'Processing…',
    isLoading: true,
    onPressed: () {},
  ),
);

// ─── Disabled State ───────────────────────────────────────────────────────────

@Preview(name: 'Disabled', group: 'Buttons')
Widget previewButtonDisabled() => previewWrapper(
  child: const ModernButton(
    label: 'Unavailable',
    onPressed: null, // null = disabled
  ),
);

// ─── Outlined Button ──────────────────────────────────────────────────────────

@Preview(name: 'Outlined', group: 'Buttons')
Widget previewButtonOutlined() => previewWrapper(
  child: ModernButton(
    label: 'Cancel Order',
    isOutlined: true,
    onPressed: () {},
  ),
);

// ─── With Icon ────────────────────────────────────────────────────────────────

@Preview(name: 'With Icon', group: 'Buttons')
Widget previewButtonWithIcon() => previewWrapper(
  child: ModernButton(
    label: 'Add to Cart',
    icon: Icons.shopping_cart_outlined,
    onPressed: () {},
  ),
);

// ─── Secondary (non-primary) ─────────────────────────────────────────────────

@Preview(name: 'Secondary', group: 'Buttons')
Widget previewButtonSecondary() => previewWrapper(
  child: ModernButton(
    label: 'View Details',
    isPrimary: false,
    onPressed: () {},
  ),
);

// ─── All States ───────────────────────────────────────────────────────────────

@Preview(name: 'All States', group: 'Buttons')
Widget previewButtonAllStates() => previewGrid(
  children: [
    ModernButton(label: 'Primary', onPressed: () {}),
    ModernButton(label: 'With Icon', icon: Icons.shopping_bag_outlined, onPressed: () {}),
    ModernButton(label: 'Outlined', isOutlined: true, onPressed: () {}),
    ModernButton(label: 'Secondary', isPrimary: false, onPressed: () {}),
    ModernButton(label: 'Loading…', isLoading: true, onPressed: () {}),
    const ModernButton(label: 'Disabled', onPressed: null),
  ],
);
