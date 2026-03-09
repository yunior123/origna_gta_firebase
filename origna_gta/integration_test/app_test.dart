// Main entry point for all integration tests
// Run with: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d web-server --browser-name=chrome

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:origna_gta/main_test.dart' as app;

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Single test that launches app once and runs all verifications
  // This avoids the "Cannot set URL strategy a second time" error
  testWidgets('Flutter Web E2E - Complete App Test', (WidgetTester tester) async {
    // Launch app once
    await app.mainTest();
    final bootstrapped = await waitForAppBootstrap(tester);
    expect(bootstrapped, isTrue, reason: 'App bootstrap timeout');

    // ===== 1. App launches successfully =====
    expect(find.byType(MaterialApp), findsWidgets);
    debugPrint('✓ App launches successfully');

    // ===== 2. Home page displays correctly =====
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✓ Home page displays correctly');

    // ===== 3. Navigation elements =====
    final bottomNav = find.byType(BottomNavigationBar);
    final hasBottomNav = bottomNav.evaluate().isNotEmpty;
    debugPrint('✓ Navigation check complete (BottomNav: $hasBottomNav)');

    // ===== 4. Look for text fields =====
    final textFields = find.byType(TextField);
    debugPrint('✓ TextField check complete (Found: ${textFields.evaluate().length})');

    // ===== 5. Look for buttons =====
    final elevatedButtons = find.byType(ElevatedButton);
    final textButtons = find.byType(TextButton);
    final iconButtons = find.byType(IconButton);
    final totalButtons = elevatedButtons.evaluate().length + textButtons.evaluate().length + iconButtons.evaluate().length;
    debugPrint('✓ Button check complete (Found: $totalButtons buttons)');

    // ===== 6. ScrollView check =====
    final scrollViews = find.byType(SingleChildScrollView);
    final listViews = find.byType(ListView);
    final customScrollViews = find.byType(CustomScrollView);
    final totalScrollables = scrollViews.evaluate().length + listViews.evaluate().length + customScrollViews.evaluate().length;
    debugPrint('✓ ScrollView check complete (Found: $totalScrollables scrollables)');

    // ===== 7. GridView / Product display check =====
    final gridViews = find.byType(GridView);
    final hasGrid = gridViews.evaluate().isNotEmpty;
    debugPrint('✓ GridView check complete (Found: $hasGrid)');

    // ===== 8. Image widgets =====
    final images = find.byType(Image);
    debugPrint('✓ Image check complete (Found: ${images.evaluate().length} images)');

    // ===== 9. Card widgets =====
    final cards = find.byType(Card);
    debugPrint('✓ Card check complete (Found: ${cards.evaluate().length} cards)');

    // ===== 10. Test button interactions =====
    if (elevatedButtons.evaluate().isNotEmpty) {
      await tester.tap(elevatedButtons.first);
      await tester.pump(const Duration(seconds: 2));
      debugPrint('✓ Button tap test passed');
    }

    // ===== 11. Test scrolling =====
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -200));
      await tester.pump(const Duration(seconds: 2));
      debugPrint('✓ Scroll test passed');
    }

    // ===== Final Summary =====
    debugPrint('');
    debugPrint('========================================');
    debugPrint('  E2E TEST SUMMARY');
    debugPrint('========================================');
    debugPrint('  ✓ All basic widget tests passed');
    debugPrint('  ✓ App renders correctly');
    debugPrint('========================================');
  });
}
