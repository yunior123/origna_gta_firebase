/// 2100 Design System — OrignaGTA
/// Multi-platform: Mobile · Tablet · Desktop · Web
/// Futuristic, modern aesthetic with glassmorphism and fluid animations
library;

import 'dart:ui';

import 'package:flutter/material.dart';

/// Documentation for DesignTokens
class DesignTokens {
  // Primary Palette (Matched to Ecommerce Splash)
  static const Color primary = Color(0xFF667EEA); // Soft Cornflower Blue
  static const Color secondary = Color(0xFF764BA2); // Deep Violet
  static const Color tertiary = Color(0xFFFF6B6B); // Coral
  static const Color accent = Color(0xFF5CE1E6); // Cyan (Matches web splash)
  static const Color digital = Color(0xFF7C3AED); // Digital product badge purple

  // Gradient Definition (Matches index.html splash)
  static const Color gradientStart = Color(0xFF1F235A);
  static const Color gradientMiddle = Color(0xFF2F3B8F);
  static const Color gradientEnd = Color(0xFF764BA2);

  // Neutral Palette
  static const Color surface = Color(0xFFF8F9FA); // Off-white background
  static const Color surfaceSubtle = Color(0xFFF8F9FF); // Slightly blue-tinted off-white
  static const Color infoSubtle = Color(0xFFF0F7FF); // Faint info/blue tint for section backgrounds
  static const Color surfaceVariant = Color(0xFFF3F4F9);
  static const Color outline = Color(0xFFD0D5E0);
  static const Color outlineVariant = Color(0xFFE8EBF0);

  // Dark Mode
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkSurfaceVariant = Color(0xFF16213E);
  static const Color darkOutline = Color(0xFF444B63);
  static const Color darkCard = Color(0xFF1E1E32);
  static const Color darkBackground = Color(0xFF0F0F1E);

  // Text Colors (WCAG 2.1 AA: ≥4.5:1 for normal text, ≥3:1 for large text)
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF6B7280); // Was #9CA3AF (~2.8:1) → #6B7280 (~5.3:1 on white)
  static const Color textDisabled = Color(0xFF9CA3AF); // Was #BDBDBD (~1.7:1) → #9CA3AF (~3.7:1 - decorative only)
  static const Color textOnPrimary = Colors.white;
  static const Color textOnDark = Colors.white;
  static const Color textOnDarkSecondary = Color(0xFFBDBDBD);

  // Semantic
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber (backgrounds/icons only)
  static const Color warningText = Color(0xFF92400E); // WCAG AA: ~7:1 on white (for text)
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color statusShipped = Color(0xFF06B6D4); // Cyan — shipped status
  static const Color statusInTransit = Color(0xFF14B8A6); // Teal — in-transit status
  static const Color canadaRed = Color(0xFFD80027); // Canadian flag red — Canada-only badge

  // Payment provider brand colors (used in seller registration screen)
  static const Color stripeViolet = Color(0xFF635BFF);
  static const Color stripeCyan = Color(0xFF00D4AA);
  static const Color paypalNavy = Color(0xFF003087);
  static const Color paypalBlue = Color(0xFF009CDE);
  static const Color wiseGreen = Color(0xFF9FE870);
  static const Color wiseSky = Color(0xFF00B9FF);

  // Timeline inactive step colors
  static const Color timelineInactiveDark = Color(0xFF3A3A50);
  static const Color timelineInactiveLight = Color(0xFFE0E4EE);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary, secondary]);

  static const LinearGradient secondaryGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [secondary, primary]);

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFF667EEA)],
  );

  // Spacing
  static const double spacing0 = 0;
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing40 = 40;
  static const double spacing48 = 48;
  static const double spacing64 = 64;
  static const double spacing80 = 80;

  // Typography Sizes
  static const double fontSizeXs = 11;
  static const double fontSizeSm = 13;
  static const double fontSizeMd = 15;
  static const double fontSizeLg = 18;
  static const double fontSizeXl = 22;
  static const double fontSizeDisplay = 28;

  // Border Radius
  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius20 = 20;
  static const double radius24 = 24;
  static const double radius32 = 32;

  // Elevation / Shadow
  static const List<BoxShadow> shadowSm = [BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1))];

  static const List<BoxShadow> shadowMd = [BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 2))];

  static const List<BoxShadow> shadowLg = [BoxShadow(color: Color(0x15000000), blurRadius: 12, offset: Offset(0, 4))];

  static const List<BoxShadow> shadowXl = [BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 8))];

  // Glassmorphism
  static const double glassOpacity = 0.8;
  static const double gloopBlur = 15;

  // Typography
  static const String fontFamily = 'Inter';

  // Animation Durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 600);

  // Curves
  static const Curve easeOutCubic = Cubic(0.33, 1, 0.68, 1);
  static const Curve easeInOutCubic = Cubic(0.65, 0, 0.35, 1);

  // ── Gradient Helpers ────────────────────────────────────────────────
  /// Background gradient that adapts to light/dark theme.
  static LinearGradient backgroundGradient({required bool isDark}) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [darkBackground, darkSurface]
          : [const Color(0xFFF0F2FF), Colors.white],
    );
  }

  /// Surface gradient for screen bodies.
  static LinearGradient surfaceGradient({required bool isDark}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [darkSurface, darkSurfaceVariant]
          : [surface, Colors.white],
    );
  }
}

/// Glassmorphism Container Helper
class GlassContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final double opacity;
  final double blur;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadows;
  final EdgeInsets padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.color = const Color(0xFFFFFFFF),
    this.opacity = DesignTokens.glassOpacity,
    this.blur = DesignTokens.gloopBlur,
    this.borderRadius = const BorderRadius.all(Radius.circular(DesignTokens.radius16)),
    this.shadows = DesignTokens.shadowMd,
    this.padding = const EdgeInsets.all(DesignTokens.spacing16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            boxShadow: shadows,
          ),
          child: child,
        ),
      ),
    );
  }
}
