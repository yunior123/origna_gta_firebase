import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/modern_button.dart';

void main() {
  group('ModernButton Widget Tests', () {
    testWidgets('renders primary button correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernButton(
              label: 'Test Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
      expect(find.byType(ModernButton), findsOneWidget);
      // Ensure it is not loading
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('triggers onPressed callback', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernButton(
              label: 'Click Me',
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ModernButton));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });

    testWidgets('renders loading state correctly and disables interaction', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernButton(
              label: 'Loading Button',
              isLoading: true,
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      // Label should still be in semantics or hidden by indicator (ModernLoadingIndicator is shown instead of Text)
      expect(find.text('Loading Button'), findsNothing); // Text is replaced by loading indicator in the actual widget

      // Tap should not trigger onPressed
      await tester.tap(find.byType(ModernButton));
      await tester.pump();

      expect(pressed, isFalse);
    });

    testWidgets('disabled state when onPressed is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernButton(
              label: 'Disabled',
              onPressed: null,
            ),
          ),
        ),
      );

      // Verify the button renders with the disabled label
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('renders outlined button correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernButton(
              label: 'Outlined',
              isOutlined: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Outlined'), findsOneWidget);
      final container = tester.widget<Container>(find.descendant(
        of: find.byType(ModernButton),
        matching: find.byType(Container),
      ).first);

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('renders button with icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernButton(
              label: 'Icon Button',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Icon Button'), findsOneWidget);
    });

    testWidgets('handles tap gestures for animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernButton(
              label: 'Anim Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      final gestureDetector = find.descendant(
        of: find.byType(ModernButton),
        matching: find.byType(GestureDetector),
      ).first;

      // Simulate pointer down
      final TestGesture gesture = await tester.startGesture(tester.getCenter(gestureDetector));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 50)); // Advance animation

      // Simulate pointer up
      await gesture.up();
      await tester.pumpAndSettle();
    });

     testWidgets('handles tap cancel gesture for animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernButton(
              label: 'Anim Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      final gestureDetector = find.descendant(
        of: find.byType(ModernButton),
        matching: find.byType(GestureDetector),
      ).first;

      // Simulate pointer down
      final TestGesture gesture = await tester.startGesture(tester.getCenter(gestureDetector));
      await tester.pump();
      
      // Cancel gesture
      await gesture.cancel();
      await tester.pumpAndSettle();
    });
  });
}
