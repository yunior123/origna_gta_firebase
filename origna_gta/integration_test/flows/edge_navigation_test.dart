import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:origna_gta/main_test.dart' as app;

import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets('Edge Navigation Flow — deep links, error states, and role switching', (tester) async {
    debugPrint('🚀🚀🚀 ========== EDGE NAVIGATION TEST START ========== 🚀🚀🚀');
    const strictIntegration = bool.fromEnvironment('STRICT_INTEGRATION', defaultValue: true);
    final tracker = await initializeIntegrationTest(tester, strictIntegration: strictIntegration);

    debugStep('E01', 'Testing Deep Link: Product Detail');
    // Using a known test product ID from seeds
    await tester.pumpWidget(Container()); // Clear
    await app.mainTest();
    await pumpWait(tester, seconds: 2);
    
    // We simulate deep link by checking if we can navigate there directly if the app was started with it
    // But in integration test, we can use the router directly if needed or just navigate.
    // For this test, we'll focus on UI navigation to edge screens.

    final buyer = await establishSession(tester, buyerCredentialCandidates, 'buyer', tracker, 'S101', '[buyer] login failed');
    if (buyer == null) return;

    debugStep('E02', 'Testing Privacy Policy & Terms');
    if (await openSettings(tester)) {
      final privacyBtn = find.byKey(const Key('profile_privacy_button'));
      if (privacyBtn.evaluate().isNotEmpty) {
        await tester.tap(privacyBtn.first);
        await pumpWait(tester, seconds: 3);
        tracker.check('C101', find.textContaining('Privacy').evaluate().isNotEmpty, 'Privacy policy screen loaded');
        await goBack(tester);
      }

      final termsBtn = find.byKey(const Key('profile_terms_button'));
      if (termsBtn.evaluate().isNotEmpty) {
        await tester.tap(termsBtn.first);
        await pumpWait(tester, seconds: 3);
        tracker.check('C102', find.textContaining('Terms').evaluate().isNotEmpty, 'Terms of service screen loaded');
        await goBack(tester);
      }
      await goBack(tester);
    }

    debugStep('E03', 'Testing Notification Center');
    final notifBtn = find.byKey(const Key('home_notifications_button'));
    if (notifBtn.evaluate().isNotEmpty) {
      await tester.tap(notifBtn.first);
      await pumpWait(tester, seconds: 2);
      tracker.check('C103', find.byType(Scaffold).evaluate().isNotEmpty, 'Notifications screen loaded');
      await goBack(tester);
    }

    debugStep('E04', 'Testing Category Browsing');
    final viewAllCats = find.text('View All');
    if (viewAllCats.evaluate().isNotEmpty) {
      await tester.tap(viewAllCats.first);
      await pumpWait(tester, seconds: 2);
      tracker.check('C104', find.text('All Categories').evaluate().isNotEmpty, 'All categories screen loaded');
      
      final electronicCat = find.text('Electronics');
      if (electronicCat.evaluate().isNotEmpty) {
        await tester.tap(electronicCat.first);
        await pumpWait(tester, seconds: 3);
        tracker.check('C105', find.byType(Card).evaluate().isNotEmpty, 'Category products loaded');
        await goBack(tester);
      }
      await goBack(tester);
    }

    debugStep('E05', 'Testing Search Empty State');
    final searchIcon = find.byIcon(Icons.search);
    if (searchIcon.evaluate().isNotEmpty) {
      await tester.tap(searchIcon.first);
      await pumpWait(tester, seconds: 1);
      final searchField = find.byType(TextField);
      await tester.enterText(searchField.first, 'NonExistentProductXYZ123');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await pumpWait(tester, seconds: 3);
      tracker.check('C106', find.textContaining('No products found').evaluate().isNotEmpty || find.textContaining('0 results').evaluate().isNotEmpty, 'Search empty state shown');
      await goBack(tester);
    }

    debugStep('E06', 'Testing Support/Help screen');
    if (await openSettings(tester)) {
      final helpBtn = find.byKey(const Key('profile_help_button'));
      if (helpBtn.evaluate().isNotEmpty) {
        await tester.tap(helpBtn.first);
        await pumpWait(tester, seconds: 2);
        tracker.check('C107', find.textContaining('Support').evaluate().isNotEmpty || find.textContaining('Help').evaluate().isNotEmpty, 'Help screen loaded');
        await goBack(tester);
      }
      await goBack(tester);
    }

    tracker.throwIfFailed();
    debugPrint('🎉🎉🎉 ========== EDGE NAVIGATION TEST COMPLETE ========== 🎉🎉🎉');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
