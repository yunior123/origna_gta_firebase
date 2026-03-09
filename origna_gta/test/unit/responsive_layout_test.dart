import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/utils/responsive_layout.dart';

void main() {
  Widget buildFrame({required Size size, required Widget child, EdgeInsets padding = EdgeInsets.zero}) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: size, padding: padding),
          child: child,
        ),
      ),
    );
  }

  group('ResponsiveBreakpoints', () {
    testWidgets('dropdownMaxHeight returns 40% of viewport height', (tester) async {
      double? height;
      await tester.pumpWidget(
        buildFrame(
          size: const Size(800, 1000),
          child: Builder(
            builder: (context) {
              height = ResponsiveBreakpoints.dropdownMaxHeight(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(height, 400.0);
    });

    testWidgets('getFontScale returns correct scale for screen widths', (tester) async {
      final testCases = {
        300.0: 0.9,
        500.0: 1.0,
        800.0: 1.1,
        1100.0: 1.2,
        1300.0: 1.25,
        1500.0: 1.25,
      };

      for (final entry in testCases.entries) {
        double? scale;
        await tester.pumpWidget(
          buildFrame(
            size: Size(entry.key, 800),
            child: Builder(
              builder: (context) {
                scale = ResponsiveBreakpoints.getFontScale(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(scale, entry.value, reason: 'Failed for width ${entry.key}');
      }
    });

    testWidgets('getGridColumns returns correct columns for screen widths', (tester) async {
      final testCases = {
        300.0: 1,
        400.0: 2,
        800.0: 3,
        1100.0: 4,
        1300.0: 5,
        1500.0: 6,
      };

      for (final entry in testCases.entries) {
        int? columns;
        await tester.pumpWidget(
          buildFrame(
            size: Size(entry.key, 800),
            child: Builder(
              builder: (context) {
                columns = ResponsiveBreakpoints.getGridColumns(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(columns, entry.value, reason: 'Failed for width ${entry.key}');
      }
    });

    testWidgets('isDesktop, isTablet, isMobile correctly identify screen types', (tester) async {
      final testCases = [
        {'width': 400.0, 'mobile': true, 'tablet': false, 'desktop': false},
        {'width': 800.0, 'mobile': false, 'tablet': true, 'desktop': false},
        {'width': 1200.0, 'mobile': false, 'tablet': false, 'desktop': true},
      ];

      for (final tc in testCases) {
        bool? mobile, tablet, desktop;
        await tester.pumpWidget(
          buildFrame(
            size: Size(tc['width'] as double, 800),
            child: Builder(
              builder: (context) {
                mobile = ResponsiveBreakpoints.isMobile(context);
                tablet = ResponsiveBreakpoints.isTablet(context);
                desktop = ResponsiveBreakpoints.isDesktop(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(mobile, tc['mobile'], reason: 'isMobile failed for ${tc['width']}');
        expect(tablet, tc['tablet'], reason: 'isTablet failed for ${tc['width']}');
        expect(desktop, tc['desktop'], reason: 'isDesktop failed for ${tc['width']}');
      }
    });

    testWidgets('getSafePadding adds correct padding based on width', (tester) async {
      const padding = EdgeInsets.all(10);
      
      // Width < 480: padding + 8
      EdgeInsets? smallPadding;
      await tester.pumpWidget(
        buildFrame(
          size: const Size(400, 800),
          padding: padding,
          child: Builder(
            builder: (context) {
              smallPadding = ResponsiveBreakpoints.getSafePadding(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(smallPadding, const EdgeInsets.all(18));

      // Width >= 480: padding + 16
      EdgeInsets? largePadding;
      await tester.pumpWidget(
        buildFrame(
          size: const Size(800, 800),
          padding: padding,
          child: Builder(
            builder: (context) {
              largePadding = ResponsiveBreakpoints.getSafePadding(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(largePadding, const EdgeInsets.all(26));
    });

    testWidgets('getSpacing returns correct spacing sizes for screen widths', (tester) async {
      final testCases = {
        // < mobilePlus (480) -> tiny spacing
        400.0: {
          SpacingSize.xs: 4.0,
          SpacingSize.sm: 6.0,
          SpacingSize.md: 8.0,
          SpacingSize.lg: 12.0,
          SpacingSize.xl: 16.0,
        },
        // < tablet (768) -> normal spacing
        600.0: {
          SpacingSize.xs: 6.0,
          SpacingSize.sm: 8.0,
          SpacingSize.md: 12.0,
          SpacingSize.lg: 16.0,
          SpacingSize.xl: 24.0,
        },
        // < desktop (1024) -> loose spacing
        800.0: {
          SpacingSize.xs: 8.0,
          SpacingSize.sm: 12.0,
          SpacingSize.md: 16.0,
          SpacingSize.lg: 20.0,
          SpacingSize.xl: 28.0,
        },
        // >= desktop -> extra loose spacing
        1200.0: {
          SpacingSize.xs: 12.0,
          SpacingSize.sm: 16.0,
          SpacingSize.md: 20.0,
          SpacingSize.lg: 24.0,
          SpacingSize.xl: 32.0,
        },
      };

      for (final entry in testCases.entries) {
        for (final sizeEntry in entry.value.entries) {
          double? spacing;
          await tester.pumpWidget(
            buildFrame(
              size: Size(entry.key, 800),
              child: Builder(
                builder: (context) {
                  spacing = ResponsiveBreakpoints.getSpacing(context, sizeEntry.key);
                  return const SizedBox();
                },
              ),
            ),
          );
          expect(spacing, sizeEntry.value, reason: 'Failed for width ${entry.key}, size ${sizeEntry.key}');
        }
      }
    });

    testWidgets('getValue returns correct generic values based on width', (tester) async {
      String? result;

      // Mobile
      await tester.pumpWidget(
        buildFrame(
          size: const Size(400, 800),
          child: Builder(
            builder: (context) {
              result = ResponsiveBreakpoints.getValue<String>(
                context: context,
                mobile: 'mobile',
                mobilePlus: 'mobilePlus',
                tablet: 'tablet',
                desktop: 'desktop',
                desktopLg: 'desktopLg',
                desktopXl: 'desktopXl',
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, 'mobile');

      // MobilePlus
      await tester.pumpWidget(
        buildFrame(
          size: const Size(600, 800),
          child: Builder(
            builder: (context) {
              result = ResponsiveBreakpoints.getValue<String>(
                context: context,
                mobile: 'mobile',
                mobilePlus: 'mobilePlus',
                tablet: 'tablet',
                desktop: 'desktop',
                desktopLg: 'desktopLg',
                desktopXl: 'desktopXl',
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, 'mobilePlus');

      // Tablet
      await tester.pumpWidget(
        buildFrame(
          size: const Size(800, 800),
          child: Builder(
            builder: (context) {
              result = ResponsiveBreakpoints.getValue<String>(
                context: context,
                mobile: 'mobile',
                mobilePlus: 'mobilePlus',
                tablet: 'tablet',
                desktop: 'desktop',
                desktopLg: 'desktopLg',
                desktopXl: 'desktopXl',
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, 'tablet');

      // Desktop
      await tester.pumpWidget(
        buildFrame(
          size: const Size(1100, 800),
          child: Builder(
            builder: (context) {
              result = ResponsiveBreakpoints.getValue<String>(
                context: context,
                mobile: 'mobile',
                mobilePlus: 'mobilePlus',
                tablet: 'tablet',
                desktop: 'desktop',
                desktopLg: 'desktopLg',
                desktopXl: 'desktopXl',
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, 'desktop');

      // DesktopLg
      await tester.pumpWidget(
        buildFrame(
          size: const Size(1300, 800),
          child: Builder(
            builder: (context) {
              result = ResponsiveBreakpoints.getValue<String>(
                context: context,
                mobile: 'mobile',
                mobilePlus: 'mobilePlus',
                tablet: 'tablet',
                desktop: 'desktop',
                desktopLg: 'desktopLg',
                desktopXl: 'desktopXl',
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, 'desktopLg');

      // DesktopXl
      await tester.pumpWidget(
        buildFrame(
          size: const Size(1500, 800),
          child: Builder(
            builder: (context) {
              result = ResponsiveBreakpoints.getValue<String>(
                context: context,
                mobile: 'mobile',
                mobilePlus: 'mobilePlus',
                tablet: 'tablet',
                desktop: 'desktop',
                desktopLg: 'desktopLg',
                desktopXl: 'desktopXl',
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, 'desktopXl');

      // Fallback to desktop when optional values omitted
      await tester.pumpWidget(
        buildFrame(
          size: const Size(1500, 800),
          child: Builder(
            builder: (context) {
              result = ResponsiveBreakpoints.getValue<String>(
                context: context,
                mobile: 'mobile',
                mobilePlus: 'mobilePlus',
                tablet: 'tablet',
                desktop: 'desktop',
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, 'desktop');
    });
  });

  group('ResponsiveContainer', () {
    testWidgets('constrains child width properly', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        buildFrame(
          size: const Size(1500, 800),
          child: ResponsiveContainer(
            key: key,
            maxWidth: 1000,
            padding: EdgeInsets.zero,
            child: const SizedBox(width: double.infinity, height: 100),
          ),
        ),
      );
      
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(of: find.byKey(key), matching: find.byType(ConstrainedBox)).first
      );
      expect(constrainedBox.constraints.maxWidth, 1000);
      
      // When width < maxWidth
      final smallKey = GlobalKey();
      await tester.pumpWidget(
        buildFrame(
          size: const Size(800, 800),
          child: ResponsiveContainer(
            key: smallKey,
            maxWidth: 1000,
            padding: EdgeInsets.zero,
            child: const SizedBox(width: double.infinity, height: 100),
          ),
        ),
      );
      
      final constrainedBoxSmall = tester.widget<ConstrainedBox>(
        find.descendant(of: find.byKey(smallKey), matching: find.byType(ConstrainedBox)).first
      );
      expect(constrainedBoxSmall.constraints.maxWidth, 800);
    });
  });

  group('ResponsiveGridView', () {
    testWidgets('builds a GridView with correct crossAxisCount', (tester) async {
      await tester.pumpWidget(
        buildFrame(
          size: const Size(800, 800), // tablet width, expect 3 columns
          child: const ResponsiveGridView(
            children: [Text('1'), Text('2')],
          ),
        ),
      );

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
    });
  });

  group('ResponsiveLayout', () {
    testWidgets('renders correct layout based on screen width', (tester) async {
      const mobileWidget = Text('MobileLayout');
      const tabletWidget = Text('TabletLayout');
      const desktopWidget = Text('DesktopLayout');

      // Mobile
      await tester.pumpWidget(
        buildFrame(
          size: const Size(400, 800),
          child: const ResponsiveLayout(
            mobilePlus: mobileWidget,
            tablet: tabletWidget,
            desktop: desktopWidget,
          ),
        ),
      );
      expect(find.text('MobileLayout'), findsOneWidget);

      // Tablet
      await tester.pumpWidget(
        buildFrame(
          size: const Size(800, 800),
          child: const ResponsiveLayout(
            mobilePlus: mobileWidget,
            tablet: tabletWidget,
            desktop: desktopWidget,
          ),
        ),
      );
      expect(find.text('TabletLayout'), findsOneWidget);

      // Desktop
      await tester.pumpWidget(
        buildFrame(
          size: const Size(1200, 800),
          child: const ResponsiveLayout(
            mobilePlus: mobileWidget,
            tablet: tabletWidget,
            desktop: desktopWidget,
          ),
        ),
      );
      expect(find.text('DesktopLayout'), findsOneWidget);
    });
  });

  group('ResponsiveText', () {
    testWidgets('returns TextStyle with correct scale for body, caption, headings', (tester) async {
      TextStyle? bodyStyle, captionStyle, h1Style, h2Style, h3Style;
      
      await tester.pumpWidget(
        buildFrame(
          size: const Size(1200, 800), // font scale should be 1.2
          child: Builder(
            builder: (context) {
              bodyStyle = ResponsiveText.body(context);
              captionStyle = ResponsiveText.caption(context);
              h1Style = ResponsiveText.heading1(context);
              h2Style = ResponsiveText.heading2(context);
              h3Style = ResponsiveText.heading3(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(bodyStyle?.fontSize, 14 * 1.2);
      expect(captionStyle?.fontSize, 12 * 1.2);
      expect(h1Style?.fontSize, 28 * 1.2);
      expect(h2Style?.fontSize, 24 * 1.2);
      expect(h3Style?.fontSize, 20 * 1.2);
    });
  });
}
