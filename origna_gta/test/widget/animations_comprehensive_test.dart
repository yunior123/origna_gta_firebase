import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/animations.dart';

import '../test_utils.dart';

void main() {
  setUp(() => initTestMocks());

  group('FadeSlideIn', () {
    testWidgets('animates with delay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FadeSlideIn(
              delay: Duration(milliseconds: 100),
              child: Text('Delayed'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Delayed'), findsOneWidget);
    });

    testWidgets('custom duration and offset', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FadeSlideIn(
              duration: Duration(milliseconds: 200),
              beginOffset: Offset(0.5, 0),
              curve: Curves.linear,
              child: Text('Custom'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('disposes without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FadeSlideIn(
              delay: Duration(milliseconds: 500),
              child: Text('Dispose'),
            ),
          ),
        ),
      );
      // Dispose before delay fires
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });

  group('StaggeredList', () {
    testWidgets('renders many children with stagger', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaggeredList(
              itemDuration: const Duration(milliseconds: 200),
              staggerDelay: const Duration(milliseconds: 30),
              children: List.generate(12, (i) => Text('Item $i')),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 11'), findsOneWidget);
    });

    testWidgets('custom alignment settings', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredList(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              beginOffset: Offset(0.1, 0),
              children: [Text('A'), Text('B')],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('empty children list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredList(children: []),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Column), findsOneWidget);
    });
  });

  group('AnimatedEmptyState', () {
    testWidgets('renders title, subtitle, and action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(
              icon: Icons.search_off,
              title: 'Nothing found',
              subtitle: 'Try different keywords',
              action: ElevatedButton(onPressed: () {}, child: const Text('Retry')),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Nothing found'), findsOneWidget);
      expect(find.text('Try different keywords'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('renders with mascot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(
              icon: Icons.shopping_bag,
              title: 'No orders',
              showMascot: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('No orders'), findsOneWidget);
    });

    testWidgets('renders without subtitle or action', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(
              icon: Icons.inbox,
              title: 'Empty',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Empty'), findsOneWidget);
    });
  });

  group('ScaleBounce', () {
    testWidgets('tap triggers onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScaleBounce(
              onTap: () => tapped = true,
              child: const Text('Bounce'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Bounce'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tapped, isTrue);
    });

    testWidgets('renders without onTap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScaleBounce(child: Text('No tap')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('No tap'), findsOneWidget);
    });

    testWidgets('custom scale value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScaleBounce(
              scaleDown: 0.8,
              onTap: () {},
              child: const Icon(Icons.star),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });
}
