import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/mascot/shop_mascot.dart';
import 'package:origna_gta/widgets/mascot/canadian_moose.dart';

void main() {
  group('Mascot Widget Tests', () {
    testWidgets('ShopMascot renders without errors', (WidgetTester tester) async {
      final controller = MascotController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopMascot(
              controller: controller,
              size: 80,
              showSpeechBubble: false, // Disable to avoid pending timers
            ),
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('CanadianMoose renders without errors', (WidgetTester tester) async {
      final controller = MooseController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanadianMoose(
              controller: controller,
              size: 90,
              showSpeechBubble: false, // Disable to avoid pending timers
            ),
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Mascots can be tapped to jump', (WidgetTester tester) async {
      final controller = MascotController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopMascot(
              controller: controller,
              size: 80,
              showSpeechBubble: false,
            ),
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 100));
      
      // Tap the mascot
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      
      expect(controller.isJumping, true);

      // Wait for the jump timer to finish
      await tester.pump(const Duration(milliseconds: 601));
      expect(controller.isJumping, false);
      
      // Final pump to ensure all microtasks are done
      await tester.pump();
    });
  });
}
