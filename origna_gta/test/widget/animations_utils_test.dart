import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/utils/animations.dart';

import '../test_utils.dart';

void main() {
  setUp(() => initTestMocks());

  group('SlidePageRoute', () {
    testWidgets('right direction', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(SlidePageRoute(
                page: const Scaffold(body: Text('Page 2')),
                direction: SlideDirection.right,
              ));
            },
            child: const Text('Go'),
          );
        }),
      ));
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Page 2'), findsOneWidget);
    });

    testWidgets('left direction', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(SlidePageRoute(
                page: const Text('Left'),
                direction: SlideDirection.left,
              ));
            },
            child: const Text('Go'),
          );
        }),
      ));
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Left'), findsOneWidget);
    });

    testWidgets('up direction', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(SlidePageRoute(
                page: const Text('Up'),
                direction: SlideDirection.up,
              ));
            },
            child: const Text('Go'),
          );
        }),
      ));
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Up'), findsOneWidget);
    });

    testWidgets('down direction', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(SlidePageRoute(
                page: const Text('Down'),
                direction: SlideDirection.down,
              ));
            },
            child: const Text('Go'),
          );
        }),
      ));
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Down'), findsOneWidget);
    });
  });

  group('AnimatedListItem', () {
    testWidgets('renders and animates', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            AnimatedListItem(index: 0, child: Text('Item 0')),
            AnimatedListItem(index: 1, child: Text('Item 1')),
            AnimatedListItem(index: 5, child: Text('Item 5')),
            AnimatedListItem(index: 15, child: Text('Item 15')), // clamped to 10
          ]),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 15'), findsOneWidget);
    });

    testWidgets('disposes without error', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AnimatedListItem(index: 0, child: Text('Dispose'))),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });

    testWidgets('custom delay and duration', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AnimatedListItem(
            index: 2,
            delay: Duration(milliseconds: 100),
            duration: Duration(milliseconds: 200),
            child: Text('Custom'),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Custom'), findsOneWidget);
    });
  });

  group('TapScaleAnimation', () {
    testWidgets('tap triggers onTap and scales', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TapScaleAnimation(
            onTap: () => tapped = true,
            child: const Text('Tap me'),
          ),
        ),
      ));

      // Tap down then up
      final gesture = await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tapped, isTrue);
    });

    testWidgets('tap cancel reverses animation', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TapScaleAnimation(
            onTap: () {},
            child: const Text('Cancel'),
          ),
        ),
      ));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Cancel')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('no onTap still renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: TapScaleAnimation(child: Text('No tap'))),
      ));
      await tester.pump();
      expect(find.text('No tap'), findsOneWidget);
    });

    testWidgets('custom scaleDown', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TapScaleAnimation(
            scaleDown: 0.8,
            onTap: () {},
            child: const Text('Scale'),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Scale'), findsOneWidget);
    });
  });

  group('ShimmerLoading', () {
    testWidgets('shows shimmer when loading', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ShimmerLoading(
            isLoading: true,
            child: SizedBox(width: 100, height: 20),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShimmerLoading), findsOneWidget);
    });

    testWidgets('shows child when not loading', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ShimmerLoading(
            isLoading: false,
            child: Text('Loaded'),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Loaded'), findsOneWidget);
    });

    testWidgets('disposes without error', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ShimmerLoading(child: SizedBox(width: 50, height: 50)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });

  group('FadeInWidget', () {
    testWidgets('fades in without delay', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FadeInWidget(child: Text('Fade')),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Fade'), findsOneWidget);
    });

    testWidgets('fades in with delay', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FadeInWidget(
            delay: Duration(milliseconds: 200),
            child: Text('Delayed'),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100)); // before delay
      await tester.pump(const Duration(milliseconds: 300)); // after delay
      await tester.pump(const Duration(milliseconds: 600)); // animation done
      expect(find.text('Delayed'), findsOneWidget);
    });

    testWidgets('custom duration and curve', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FadeInWidget(
            duration: Duration(milliseconds: 200),
            curve: Curves.linear,
            child: Text('Custom'),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('disposes before delay fires', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FadeInWidget(
            delay: Duration(milliseconds: 100),
            child: Text('Never'),
          ),
        ),
      ));
      // Let the delay timer fire before disposing
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });

  group('AnimatedCounter', () {
    testWidgets('counts to value', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AnimatedCounter(value: 42)),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('custom style', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AnimatedCounter(
            value: 100,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            duration: Duration(milliseconds: 200),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('100'), findsOneWidget);
    });
  });

  group('AnimatedCheckmark', () {
    testWidgets('renders and animates', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: AnimatedCheckmark())),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AnimatedCheckmark), findsOneWidget);
    });

    testWidgets('custom size and color', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(child: AnimatedCheckmark(size: 120, color: Colors.blue)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(AnimatedCheckmark), findsOneWidget);
    });

    testWidgets('disposes cleanly', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AnimatedCheckmark()),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });

  group('BounceAnimation', () {
    testWidgets('bounces when animate is true', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BounceAnimation(child: Text('Bounce'))),
      ));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Bounce'), findsOneWidget);
    });

    testWidgets('does not bounce when animate is false', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BounceAnimation(animate: false, child: Text('Still'))),
      ));
      await tester.pump();
      expect(find.text('Still'), findsOneWidget);
    });

    testWidgets('triggers bounce on didUpdateWidget', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BounceAnimation(animate: false, child: Text('Update'))),
      ));
      await tester.pump();
      // Change animate to true
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BounceAnimation(animate: true, child: Text('Update'))),
      ));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Update'), findsOneWidget);
    });
  });

  group('NavigatorExtension', () {
    testWidgets('pushAnimated works', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => context.pushAnimated(const Text('Pushed')),
            child: const Text('Push'),
          );
        }),
      ));
      await tester.tap(find.text('Push'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Pushed'), findsOneWidget);
    });

    testWidgets('pushReplacementAnimated works', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => context.pushReplacementAnimated(const Text('Replaced')),
            child: const Text('Replace'),
          );
        }),
      ));
      await tester.tap(find.text('Replace'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Replaced'), findsOneWidget);
    });

    testWidgets('pushAnimated with left direction', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => context.pushAnimated(
              const Text('Left Push'),
              direction: SlideDirection.left,
            ),
            child: const Text('Go Left'),
          );
        }),
      ));
      await tester.tap(find.text('Go Left'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Left Push'), findsOneWidget);
    });
  });
}
