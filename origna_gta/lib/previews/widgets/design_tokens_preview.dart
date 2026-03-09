// coverage:ignore-file
/// Flutter Widget Previewer — DesignTokens color palette & typography.
/// Useful as a living style guide within the IDE.
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/utils/design_tokens.dart';

import 'package:origna_gta/previews/_preview_theme.dart';

@Preview(name: 'Color Palette', group: 'Design Tokens')
Widget previewColorPalette() => previewWrapper(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionLabel('Primary'),
      _colorRow('primary', DesignTokens.primary),
      _colorRow('secondary', DesignTokens.secondary),
      _colorRow('tertiary', DesignTokens.tertiary),
      _colorRow('accent', DesignTokens.accent),
      _colorRow('digital', DesignTokens.digital),
      const SizedBox(height: 16),
      _sectionLabel('Semantic'),
      _colorRow('success', DesignTokens.success),
      _colorRow('warning', DesignTokens.warning),
      _colorRow('error', DesignTokens.error),
      _colorRow('info', DesignTokens.info),
      const SizedBox(height: 16),
      _sectionLabel('Dark Surface'),
      _colorRow('darkBackground', DesignTokens.darkBackground),
      _colorRow('darkSurface', DesignTokens.darkSurface),
      _colorRow('darkCard', DesignTokens.darkCard),
      _colorRow('darkSurfaceVariant', DesignTokens.darkSurfaceVariant),
      _colorRow('darkOutline', DesignTokens.darkOutline),
      const SizedBox(height: 16),
      _sectionLabel('Payment'),
      _colorRow('stripeViolet', DesignTokens.stripeViolet),
      _colorRow('stripeCyan', DesignTokens.stripeCyan),
    ],
  ),
);

Widget _sectionLabel(String label) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
);

Widget _colorRow(String name, Color color) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
      Text('#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}', style: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace')),
    ],
  ),
);

@Preview(name: 'Primary Gradient', group: 'Design Tokens')
Widget previewGradient() => previewWrapper(
  child: Column(
    children: [
      Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: DesignTokens.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('primaryGradient', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle, DesignTokens.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('App gradient (splash)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ),
    ],
  ),
);

@Preview(name: 'Typography Scale', group: 'Design Tokens')
Widget previewTypography() => previewWrapper(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: const [
      Text('Display — 32px', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
      SizedBox(height: 8),
      Text('Heading — 24px', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
      SizedBox(height: 8),
      Text('Title — 18px', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      SizedBox(height: 8),
      Text('Body — 16px Regular', style: TextStyle(color: Colors.white, fontSize: 16)),
      SizedBox(height: 8),
      Text('Body Secondary — 14px', style: TextStyle(color: Colors.white70, fontSize: 14)),
      SizedBox(height: 8),
      Text('Caption — 12px', style: TextStyle(color: Colors.white54, fontSize: 12)),
      SizedBox(height: 8),
      Text('OVERLINE — 11px', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
    ],
  ),
);

@Preview(name: 'Spacing & Radius', group: 'Design Tokens')
Widget previewSpacingRadius() => previewWrapper(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel('Border Radius'),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _radiusChip('radius8', DesignTokens.radius8),
          _radiusChip('radius12', DesignTokens.radius12),
          _radiusChip('radius16', DesignTokens.radius16),
          _radiusChip('radius24', DesignTokens.radius24),
          _radiusChip('radius32', DesignTokens.radius32),
        ],
      ),
      const SizedBox(height: 20),
      _sectionLabel('Spacing'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _spacingChip('4', DesignTokens.spacing4),
          _spacingChip('8', DesignTokens.spacing8),
          _spacingChip('12', DesignTokens.spacing12),
          _spacingChip('16', DesignTokens.spacing16),
          _spacingChip('20', DesignTokens.spacing20),
          _spacingChip('24', DesignTokens.spacing24),
          _spacingChip('32', DesignTokens.spacing32),
        ],
      ),
    ],
  ),
);

Widget _radiusChip(String label, double radius) => Column(
  children: [
    Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        color: DesignTokens.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.5)),
      ),
    ),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
  ],
);

Widget _spacingChip(String label, double size) => Column(
  children: [
    Container(
      width: size * 3,
      height: 20,
      color: DesignTokens.secondary.withValues(alpha: 0.6),
    ),
    const SizedBox(height: 4),
    Text('${label}px', style: const TextStyle(color: Colors.white54, fontSize: 11)),
  ],
);
