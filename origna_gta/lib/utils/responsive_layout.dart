/// Responsive layout utilities for OrignaGta
/// Multi-platform: Mobile · Tablet · Desktop · Web · Large Display
/// Breakpoints: 320px → 480px → 768px → 1024px → 1280px → 1440px
library;

import 'package:flutter/material.dart';

/// Documentation for ResponsiveBreakpoints
class ResponsiveBreakpoints {
  // Standard breakpoints (matching common device sizes)
  static const double mobile = 320; // 320px (small phones)
  static const double mobilePlus = 480; // 480px (medium phones)
  static const double tablet = 768; // 768px (tablets, large phones)
  static const double desktop = 1024; // 1024px (desktops, large tablets)
  static const double desktopLg = 1280; // 1280px (large desktop monitors)
  static const double desktopXl = 1440; // 1440px (wide/ultrawide displays)
  static const double contentMaxWidth = 1200; // max content width on web/desktop
  static const double sidebarWidth = 280; // sidebar for desktop layouts

  // Product card aspect ratios (width ÷ height). Lower value = taller card.
  // Content area (Expanded flex:4) must fit: 2-line title + optional trending
  // view-count row + rating row + price + delivery chip.
  // Ratios sized for worst case (all optional rows visible: trending + delivery).
  // Empirically verified via Gemini visual audit 2026-03-04 — 20dp safety margin:
  //   mobile 2-col ~165px wide → height ≥ 266px → 0.62
  //   mobilePlus 2-col ~215px wide → height ≥ 320px → 0.67
  //   tablet 3-col ~235px wide → height ≥ 336px → 0.70
  //   desktop 6-col ~224px wide → height ≥ 361px → 0.62
  static const double cardAspectMobile = 0.62;
  static const double cardAspectMobilePlus = 0.67;
  static const double cardAspectTablet = 0.70;
  static const double cardAspectDesktop = 0.62;

  // Aspect ratios for seller/admin cards — management action row adds ~32–48 dp.
  static const double cardAspectMobileManage = 0.53;
  static const double cardAspectMobilePlusManage = 0.58;
  static const double cardAspectTabletManage = 0.60;
  static const double cardAspectDesktopManage = 0.53;

  /// Maximum height for dropdown/popup menus — 40 % of the viewport height.
  /// Using a viewport fraction avoids magic pixel values and adapts across
  /// screen sizes (phones, tablets, desktops) automatically.
  static double dropdownMaxHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height * 0.40;

  /// Get font scale factor for responsive text
  static double getFontScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < mobilePlus) return 0.9; // 10% smaller on tiny phones
    if (width < tablet) return 1.0; // Normal on phones
    if (width < desktop) return 1.1; // 10% larger on tablets
    if (width < desktopLg) return 1.2; // 20% larger on desktop
    return 1.25; // 25% larger on large/ultra-wide displays
  }

  /// Get grid column count based on screen size
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 340) return 1; // Single column only on very small phones
    if (width < tablet) return 2; // 2 columns on most phones (iPhone SE -> Max)
    if (width < desktop) return 3; // 3 columns on tablets
    if (width < desktopLg) return 4; // 4 columns on standard desktop
    if (width < desktopXl) return 5; // 5 columns on large monitors
    return 6; // 6 columns on ultra-wide displays
  }

  /// Returns true when the screen is in desktop/web mode (≥1024px)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  /// Returns true when the screen is tablet-sized (768–1023px)
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= tablet && w < desktop;
  }

  /// Returns true when running on a mobile-sized screen (<768px)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tablet;

  /// Get safe padding for edges (avoids notches, safe areas)
  static EdgeInsets getSafePadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;

    // Reduce padding on small devices
    if (width < mobilePlus) {
      return EdgeInsets.fromLTRB(mediaQuery.padding.left + 8, mediaQuery.padding.top + 8, mediaQuery.padding.right + 8, mediaQuery.padding.bottom + 8);
    }

    return EdgeInsets.fromLTRB(mediaQuery.padding.left + 16, mediaQuery.padding.top + 16, mediaQuery.padding.right + 16, mediaQuery.padding.bottom + 16);
  }

  /// Get spacing value based on screen size
  static double getSpacing(BuildContext context, SpacingSize size) {
    final width = MediaQuery.of(context).size.width;

    if (width < mobilePlus) {
      // Tighter spacing on small phones
      return _getTinySpacing(size);
    }
    if (width < tablet) {
      // Normal spacing on medium phones
      return _getNormalSpacing(size);
    }
    if (width < desktop) {
      // Loose spacing on tablets
      return _getLooseSpacing(size);
    }
    // Extra loose spacing on desktop
    return _getExtraLooseSpacing(size);
  }

  /// Get responsive value based on screen width.
  /// [desktopLg] and [desktopXl] are optional — falls back to [desktop] if omitted.
  static T getValue<T>({
    required BuildContext context,
    required T mobile,
    required T mobilePlus,
    required T tablet,
    required T desktop,
    T? desktopLg,
    T? desktopXl,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width < ResponsiveBreakpoints.mobilePlus) return mobile;
    if (width < ResponsiveBreakpoints.tablet) return mobilePlus;
    if (width < ResponsiveBreakpoints.desktop) return tablet;
    if (desktopXl != null && width >= ResponsiveBreakpoints.desktopXl) return desktopXl;
    if (desktopLg != null && width >= ResponsiveBreakpoints.desktopLg) return desktopLg;
    return desktop;
  }

  static double _getExtraLooseSpacing(SpacingSize size) {
    switch (size) {
      case SpacingSize.xs:
        return 12;
      case SpacingSize.sm:
        return 16;
      case SpacingSize.md:
        return 20;
      case SpacingSize.lg:
        return 24;
      case SpacingSize.xl:
        return 32;
    }
  }

  static double _getLooseSpacing(SpacingSize size) {
    switch (size) {
      case SpacingSize.xs:
        return 8;
      case SpacingSize.sm:
        return 12;
      case SpacingSize.md:
        return 16;
      case SpacingSize.lg:
        return 20;
      case SpacingSize.xl:
        return 28;
    }
  }

  static double _getNormalSpacing(SpacingSize size) {
    switch (size) {
      case SpacingSize.xs:
        return 6;
      case SpacingSize.sm:
        return 8;
      case SpacingSize.md:
        return 12;
      case SpacingSize.lg:
        return 16;
      case SpacingSize.xl:
        return 24;
    }
  }

  static double _getTinySpacing(SpacingSize size) {
    switch (size) {
      case SpacingSize.xs:
        return 4;
      case SpacingSize.sm:
        return 6;
      case SpacingSize.md:
        return 8;
      case SpacingSize.lg:
        return 12;
      case SpacingSize.xl:
        return 16;
    }
  }
}

/// No-collapse responsive container
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const ResponsiveContainer({super.key, required this.child, this.maxWidth = 1200, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final constraints = BoxConstraints(maxWidth: width < maxWidth ? width : maxWidth);

    return Center(
      child: Padding(
        padding: padding,
        child: ConstrainedBox(constraints: constraints, child: child),
      ),
    );
  }
}

/// Responsive grid view
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final double spacing;

  const ResponsiveGridView({super.key, required this.children, this.padding = const EdgeInsets.all(16), this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveBreakpoints.getGridColumns(context);

    return Padding(
      padding: padding,
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: spacing, crossAxisSpacing: spacing),
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

/// Responsive layout builder — Mobile · Tablet · Desktop · Web
///
/// Breakpoints (based on [ResponsiveBreakpoints]):
/// - [mobilePlus] covers ALL phones (< 768px, including < 320px). There is no
///   separate `mobile` layout — sub-480px devices use the same layout as larger
///   phones. This is intentional: screens narrower than 320px are negligible
///   in practice and the same layout adapts well enough.
/// - [tablet] covers 768–1023px.
/// - [desktop] covers 1024px+ (web, desktop browsers, large displays).
class ResponsiveLayout extends StatelessWidget {
  final Widget mobilePlus; // all phones < 768px
  final Widget tablet; // 768–1023px
  final Widget desktop; // 1024px+ (web, desktop, large displays)

  const ResponsiveLayout({super.key, required this.mobilePlus, required this.tablet, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < ResponsiveBreakpoints.tablet) {
      return mobilePlus;
    }
    if (width < ResponsiveBreakpoints.desktop) {
      return tablet;
    }
    return desktop;
  }
}

/// Responsive text styles
class ResponsiveText {
  static TextStyle body(BuildContext context) {
    final scale = ResponsiveBreakpoints.getFontScale(context);
    return TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.normal, height: 1.5);
  }

  static TextStyle caption(BuildContext context) {
    final scale = ResponsiveBreakpoints.getFontScale(context);
    return TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.normal, height: 1.4);
  }

  static TextStyle heading1(BuildContext context) {
    final scale = ResponsiveBreakpoints.getFontScale(context);
    return TextStyle(fontSize: 28 * scale, fontWeight: FontWeight.bold, height: 1.2);
  }

  static TextStyle heading2(BuildContext context) {
    final scale = ResponsiveBreakpoints.getFontScale(context);
    return TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold, height: 1.3);
  }

  static TextStyle heading3(BuildContext context) {
    final scale = ResponsiveBreakpoints.getFontScale(context);
    return TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w600, height: 1.4);
  }
}

enum SpacingSize {
  xs, // Extra small (4-12px)
  sm, // Small (6-16px)
  md, // Medium (8-20px)
  lg, // Large (12-24px)
  xl, // Extra large (16-32px)
}
