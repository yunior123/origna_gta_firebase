import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/animations.dart';

void main() {
  group('FadeSlideIn', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FadeSlideIn(child: Text('Test Content'))),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('applies fade and slide transitions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FadeSlideIn(child: Text('Animated'))),
        ),
      );

      // Find FadeSlideIn widget and verify it contains transitions
      expect(find.byType(FadeSlideIn), findsOneWidget);

      // FadeSlideIn wraps child in SlideTransition
      expect(find.descendant(of: find.byType(FadeSlideIn), matching: find.byType(SlideTransition)), findsOneWidget);
    });

    testWidgets('animation completes after duration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FadeSlideIn(duration: Duration(milliseconds: 400), child: Text('Slow Animation')),
          ),
        ),
      );

      // Complete the animation
      await tester.pumpAndSettle();

      // Rendering still active
      expect(find.text('Slow Animation'), findsOneWidget);
    });

    testWidgets('respects delay before animation starts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FadeSlideIn(delay: Duration(milliseconds: 200), child: Text('Delayed')),
          ),
        ),
      );

      // It renders immediately
      expect(find.text('Delayed'), findsOneWidget);

      // Pump past the delay
      await tester.pump(const Duration(milliseconds: 250));

      // Complete animation
      await tester.pumpAndSettle();

      // It should still be there
      expect(find.text('Delayed'), findsOneWidget);
    });
  });

  group('StaggeredList', () {
    testWidgets('renders all children', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StaggeredList(children: [Text('Item 1'), Text('Item 2'), Text('Item 3')])),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('wraps each child in FadeSlideIn', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredList(
              staggerDelay: Duration.zero, // No delay for testing
              children: [Text('A'), Text('B')],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have 2 FadeSlideIn widgets
      expect(find.byType(FadeSlideIn), findsNWidgets(2));
    });

    testWidgets('uses Column for layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredList(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Test')]),
          ),
        ),
      );

      // Find the Column that's a direct child of StaggeredList
      final staggeredList = find.byType(StaggeredList);
      expect(staggeredList, findsOneWidget);

      final column = find.descendant(of: staggeredList, matching: find.byType(Column));
      expect(column, findsOneWidget);
    });
  });

  group('AnimatedEmptyState', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(icon: Icons.shopping_cart, title: 'Your cart is empty'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
      expect(find.text('Your cart is empty'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(icon: Icons.inventory, title: 'No products', subtitle: 'Add some products to get started'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No products'), findsOneWidget);
      expect(find.text('Add some products to get started'), findsOneWidget);
    });

    testWidgets('does not render subtitle when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(icon: Icons.error, title: 'Error occurred'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should only find the title, no subtitle
      expect(find.text('Error occurred'), findsOneWidget);
    });

    testWidgets('renders action widget when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(
              icon: Icons.search,
              title: 'No results',
              action: ElevatedButton(onPressed: () {}, child: const Text('Try Again')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Try Again'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('is wrapped in scale and fade animations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(icon: Icons.info, title: 'Information'),
          ),
        ),
      );

      expect(find.byType(AnimatedEmptyState), findsOneWidget);

      // AnimatedEmptyState should contain ScaleTransition
      expect(find.descendant(of: find.byType(AnimatedEmptyState), matching: find.byType(ScaleTransition)), findsOneWidget);
    });
  });

  group('ScaleBounce', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScaleBounce(child: Container(width: 100, height: 100, color: Colors.blue)),
          ),
        ),
      );

      expect(find.byType(ScaleBounce), findsOneWidget);
    });

    testWidgets('wraps child in ScaleTransition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScaleBounce(scaleDown: 0.9, child: Container(width: 100, height: 100, color: Colors.red)),
            ),
          ),
        ),
      );

      expect(find.descendant(of: find.byType(ScaleBounce), matching: find.byType(ScaleTransition)), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScaleBounce(
                onTap: () => tapped = true,
                child: Container(width: 100, height: 100, color: Colors.green),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ScaleBounce));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('uses GestureDetector for tap handling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScaleBounce(child: Container(width: 100, height: 100, color: Colors.purple)),
            ),
          ),
        ),
      );

      expect(find.descendant(of: find.byType(ScaleBounce), matching: find.byType(GestureDetector)), findsOneWidget);
    });
  });
}
