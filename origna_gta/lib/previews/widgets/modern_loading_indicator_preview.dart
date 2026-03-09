// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

@Preview(name: 'Modern Loading — Inline', group: 'ModernLoadingIndicator')
Widget previewLoadingInline() => previewGrid(
  children: [
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.darkSurface,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ModernLoadingIndicator.small(),
          SizedBox(width: 12),
          Text('Processing...', style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
  ],
);

@Preview(name: 'Modern Loading — Variants', group: 'ModernLoadingIndicator')
Widget previewLoadingVariants() => previewGrid(
  children: [
    const ModernLoadingIndicator(message: 'Loading content...'),
    const ModernLoadingIndicator.small(),
    const ModernLoadingIndicator.fullScreen(message: 'Preparing your experience...'),
    ModernLoadingIndicator(color: DesignTokens.secondary, message: 'Custom Color'),
  ],
);

@Preview(name: 'Modern Loading Light — Inline', group: 'ModernLoadingIndicator')
Widget previewLoadingInlineLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.darkSurface,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ModernLoadingIndicator.small(),
          SizedBox(width: 12),
          Text('Processing...', style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
  ],
);

@Preview(name: 'Modern Loading Light — Variants', group: 'ModernLoadingIndicator')
Widget previewLoadingVariantsLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    const ModernLoadingIndicator(message: 'Loading content...'),
    const ModernLoadingIndicator.small(),
    const ModernLoadingIndicator.fullScreen(message: 'Preparing your experience...'),
    ModernLoadingIndicator(color: DesignTokens.secondary, message: 'Custom Color'),
  ],
);
