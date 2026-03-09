// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_card.dart';

@Preview(name: 'Modern Card — Complex Content', group: 'ModernCard')
Widget previewCardComplex() => previewGrid(
  children: [
    ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: DesignTokens.warning),
              const SizedBox(width: DesignTokens.spacing8),
              Text(
                'Premium Offer',
                style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.textOnDark),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing12),
          const Text('Get exclusive access to Canadian heritage products.'),
        ],
      ),
    ),
  ],
);

@Preview(name: 'Modern Card — Variants', group: 'ModernCard')
Widget previewCardVariants() => previewGrid(
  children: [
    const ModernCard(child: Text('Basic Card Content')),
    ModernCard(onTap: () {}, child: const Text('Interactive Card (Hover Me)')),
    ModernCard(backgroundColor: DesignTokens.primary.withValues(alpha: 0.1), child: const Text('Custom Background Color')),
    ModernCard(
      borderRadius: BorderRadius.circular(DesignTokens.radius8),
      padding: const EdgeInsets.all(DesignTokens.spacing8),
      child: const Text('Small Radius & Padding'),
    ),
  ],
);

@Preview(name: 'Modern Card Light — Complex Content', group: 'ModernCard')
Widget previewCardComplexLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: DesignTokens.warning),
              const SizedBox(width: DesignTokens.spacing8),
              Text(
                'Premium Offer',
                style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.textOnDark),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing12),
          const Text('Get exclusive access to Canadian heritage products.'),
        ],
      ),
    ),
  ],
);

@Preview(name: 'Modern Card Light — Variants', group: 'ModernCard')
Widget previewCardVariantsLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    const ModernCard(child: Text('Basic Card Content')),
    ModernCard(onTap: () {}, child: const Text('Interactive Card (Hover Me)')),
    ModernCard(backgroundColor: DesignTokens.primary.withValues(alpha: 0.1), child: const Text('Custom Background Color')),
    ModernCard(
      borderRadius: BorderRadius.circular(DesignTokens.radius8),
      padding: const EdgeInsets.all(DesignTokens.spacing8),
      child: const Text('Small Radius & Padding'),
    ),
  ],
);
