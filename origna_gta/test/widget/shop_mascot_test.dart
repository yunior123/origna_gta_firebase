import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/mascot/shop_mascot.dart';

import '../test_utils.dart';

void main() {
  setUp(() => initTestMocks());

  group('MascotController', () {
    test('initial state', () {
      final controller = MascotController();
      expect(controller.isJumping, false);
      expect(controller.lookTarget, Offset.zero);
      expect(controller.excitementLevel, 0.0);
      controller.dispose();
    });

    test('jump sets and resets isJumping', () async {
      final controller = MascotController();
      var notified = 0;
      controller.addListener(() => notified++);

      final jumpFuture = controller.jump();
      expect(controller.isJumping, true);
      expect(notified, 1);

      await jumpFuture;
      expect(controller.isJumping, false);
      expect(notified, 2);
      controller.dispose();
    });

    test('jump is no-op when already jumping', () async {
      final controller = MascotController();
      final jump1 = controller.jump();
      expect(controller.isJumping, true);

      final jump2 = controller.jump();
      await Future.wait([jump1, jump2]);
      expect(controller.isJumping, false);
      controller.dispose();
    });

    test('lookAt updates target', () {
      final controller = MascotController();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.lookAt(const Offset(10, 20));
      expect(controller.lookTarget, const Offset(10, 20));
      expect(notified, true);
      controller.dispose();
    });

    test('setExcitement clamps value', () {
      final controller = MascotController();
      controller.setExcitement(0.5);
      expect(controller.excitementLevel, 0.5);

      controller.setExcitement(2.0);
      expect(controller.excitementLevel, 1.0);

      controller.setExcitement(-1.0);
      expect(controller.excitementLevel, 0.0);
      controller.dispose();
    });
  });

  group('MascotPainter', () {
    test('creates without error', () {
      final painter = MascotPainter(
        idleValue: 0.0,
        jumpValue: 0.0,
        blinkValue: 0.0,
        breathingValue: 0.0,
        lookTarget: Offset.zero,
        excitement: 0.5,
      );
      expect(painter, isNotNull);
    });

    test('shouldRepaint returns true for different values', () {
      final p1 = MascotPainter(
        idleValue: 0.0,
        jumpValue: 0.0,
        blinkValue: 0.0,
        breathingValue: 0.0,
        lookTarget: Offset.zero,
        excitement: 0.0,
      );
      final p2 = MascotPainter(
        idleValue: 0.5,
        jumpValue: 0.5,
        blinkValue: 0.5,
        breathingValue: 0.5,
        lookTarget: const Offset(1, 1),
        excitement: 1.0,
      );
      expect(p1.shouldRepaint(p2), true);
    });

    testWidgets('paints without crash via CustomPaint', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomPaint(
            size: const Size(100, 100),
            painter: MascotPainter(
              idleValue: 0.3,
              jumpValue: 0.0,
              blinkValue: 0.5,
              breathingValue: 0.2,
              lookTarget: const Offset(10, 10),
              excitement: 0.7,
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('ShopMascot widget', () {
    testWidgets('renders with speech bubble', (tester) async {
      final controller = MascotController();
      await tester.pumpWidget(TestWrapper(
        child: ShopMascot(controller: controller, showSpeechBubble: true),
      ));
      // Don't use pumpAndSettle - mascot has continuous animations
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShopMascot), findsOneWidget);
      controller.dispose();
    });

    testWidgets('renders without speech bubble', (tester) async {
      final controller = MascotController();
      await tester.pumpWidget(TestWrapper(
        child: ShopMascot(controller: controller, showSpeechBubble: false),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShopMascot), findsOneWidget);
      controller.dispose();
    });

    testWidgets('custom size', (tester) async {
      final controller = MascotController();
      await tester.pumpWidget(TestWrapper(
        child: ShopMascot(controller: controller, size: 120),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShopMascot), findsOneWidget);
      controller.dispose();
    });

    testWidgets('responds to excitement changes', (tester) async {
      final controller = MascotController();
      await tester.pumpWidget(TestWrapper(
        child: ShopMascot(controller: controller),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      controller.setExcitement(0.8);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShopMascot), findsOneWidget);
      controller.dispose();
    });

    testWidgets('responds to lookAt', (tester) async {
      final controller = MascotController();
      await tester.pumpWidget(TestWrapper(
        child: ShopMascot(controller: controller),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      controller.lookAt(const Offset(50, 50));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ShopMascot), findsOneWidget);
      controller.dispose();
    });

    testWidgets('jump animation', (tester) async {
      final controller = MascotController();
      await tester.pumpWidget(TestWrapper(
        child: ShopMascot(controller: controller),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      controller.jump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ShopMascot), findsOneWidget);
      controller.dispose();
    });
  });
}
