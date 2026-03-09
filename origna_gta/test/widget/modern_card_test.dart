import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/modern_card.dart';

void main() {
  group('ModernCard Widget Tests', () {
    testWidgets('renders card with child', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernCard(
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      expect(find.byType(ModernCard), findsOneWidget);
    });

    testWidgets('triggers onTap callback', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernCard(
              onTap: () {
                tapped = true;
              },
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ModernCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('handles hover effects when enabled and tap is provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernCard(
              onTap: () {},
              enableHoverScale: true,
              child: const Text('Hover Me'),
            ),
          ),
        ),
      );

      final mouseRegionFinder = find.descendant(
        of: find.byType(ModernCard),
        matching: find.byType(MouseRegion),
      );

      // Create a pointer to simulate mouse hover
      final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      // Move mouse over the card
      await gesture.moveTo(tester.getCenter(mouseRegionFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50)); // Advance animation
      
      // Move mouse away
      await gesture.moveTo(const Offset(1000, 1000));
      await tester.pump();
      await tester.pumpAndSettle(); // Finish animation
    });

    testWidgets('applies semantic label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernCard(
              semanticLabel: 'Special Card',
              child: const Text('Content'),
            ),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Special Card',
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('supports dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ModernCard(
              child: const Text('Dark Card'),
            ),
          ),
        ),
      );

      expect(find.text('Dark Card'), findsOneWidget);
      
      final container = tester.widget<Container>(find.descendant(
        of: find.byType(ModernCard),
        matching: find.byType(Container),
      ).first);
      
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
    });
  });
}
