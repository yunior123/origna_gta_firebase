// coverage:ignore-file
/// Flutter Widget Previewer — ModernLoadingIndicator variants.
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

import 'package:origna_gta/previews/_preview_theme.dart';

@Preview(name: 'Default spinner', group: 'Loading')
Widget previewLoadingDefault() => previewWrapper(
  child: const ModernLoadingIndicator(),
);

@Preview(name: 'Small spinner', group: 'Loading')
Widget previewLoadingSmall() => previewWrapper(
  child: const ModernLoadingIndicator.small(),
);

@Preview(name: 'Full screen overlay', group: 'Loading')
Widget previewLoadingFullScreen() => previewWrapper(
  child: const ModernLoadingIndicator.fullScreen(message: 'Processing payment…'),
);

@Preview(name: 'Inline (in button context)', group: 'Loading')
Widget previewLoadingInline() => previewWrapper(
  child: Container(
    height: 52,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: DesignTokens.primaryGradient,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(
      child: SizedBox(
        height: 24,
        width: 24,
        child: ModernLoadingIndicator(color: Colors.white),
      ),
    ),
  ),
);

@Preview(name: 'All sizes', group: 'Loading')
Widget previewLoadingAllSizes() => previewGrid(
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        ModernLoadingIndicator.small(),
        ModernLoadingIndicator(),
        ModernLoadingIndicator(size: 64),
      ],
    ),
  ],
);
