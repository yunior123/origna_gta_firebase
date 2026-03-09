// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/widgets/modern_button.dart';

@Preview(name: 'Modern Button — States', group: 'ModernButton')
Widget previewButtonStates() => previewGrid(
  children: [
    ModernButton(label: 'With Icon', icon: Icons.shopping_basket_rounded, onPressed: () {}),
    ModernButton(label: 'Loading State', isLoading: true, onPressed: () {}),
    ModernButton(label: 'Custom Height', height: 60, onPressed: () {}),
    ModernButton(label: 'Fixed Width', fullWidth: false, width: 200, onPressed: () {}),
  ],
);

@Preview(name: 'Modern Button — Types', group: 'ModernButton')
Widget previewButtonTypes() => previewGrid(
  children: [
    ModernButton(label: 'Primary Button', onPressed: () {}),
    ModernButton(label: 'Secondary Button', isPrimary: false, onPressed: () {}),
    ModernButton(label: 'Outlined Button', isOutlined: true, onPressed: () {}),
    const ModernButton(label: 'Disabled Button', onPressed: null),
  ],
);

@Preview(name: 'Modern Button Light — States', group: 'ModernButton')
Widget previewButtonStatesLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    ModernButton(label: 'With Icon', icon: Icons.shopping_basket_rounded, onPressed: () {}),
    ModernButton(label: 'Loading State', isLoading: true, onPressed: () {}),
    ModernButton(label: 'Custom Height', height: 60, onPressed: () {}),
    ModernButton(label: 'Fixed Width', fullWidth: false, width: 200, onPressed: () {}),
  ],
);

@Preview(name: 'Modern Button Light — Types', group: 'ModernButton')
Widget previewButtonTypesLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    ModernButton(label: 'Primary Button', onPressed: () {}),
    ModernButton(label: 'Secondary Button', isPrimary: false, onPressed: () {}),
    ModernButton(label: 'Outlined Button', isOutlined: true, onPressed: () {}),
    const ModernButton(label: 'Disabled Button', onPressed: null),
  ],
);
