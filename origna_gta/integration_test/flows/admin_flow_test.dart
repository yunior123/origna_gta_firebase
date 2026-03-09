import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets(
    'Admin Flow — panel + privileged menu',
    (tester) async {
      debugPrint('🔑🔑🔑 ========== ADMIN FLOW TEST START ========== 🔑🔑🔑');
      debugPrint('🔍 Checking STRICT_INTEGRATION env var...');
      const strictIntegration = bool.fromEnvironment(
        'STRICT_INTEGRATION',
        defaultValue: true,
      );
      debugPrint('  strictIntegration=$strictIntegration');

      debugPrint('🛠️  Initializing integration test...');
      final tracker = await initializeIntegrationTest(
        tester,
        strictIntegration: strictIntegration,
      );
      debugPrint('✅ Integration test initialized');

      debugStep('D01', 'Admin Extended Flow — panel + privileged menu');

      debugPrint('  Calling establishSession...');
      final adminCredential = await establishSession(
        tester,
        adminCredentialCandidates,
        'D01',
        tracker,
        'S001',
        'Admin session could not be established. Provide --dart-define=TEST_ADMIN_EMAIL/TEST_ADMIN_PASSWORD for the DEV Firebase account.',
      );
      if (adminCredential == null) {
        return;
      }
      debugPrint('  ✅ establishSession completed');

      final adminAddProduct = find.byKey(const Key('home_add_product_button'));
      tracker.check(
        'C063',
        adminAddProduct.evaluate().isNotEmpty,
        '[buyer,seller,admin] add product visible',
      );

      if (await openSettings(tester)) {
        final adminPanelButton = find.byKey(
          const Key('profile_admin_panel_button'),
        );
        final adminSellerOrdersButton = find.byKey(
          const Key('profile_seller_orders_button'),
        );

        tracker.check(
          'C042',
          adminPanelButton.evaluate().isNotEmpty,
          '[buyer,seller,admin] admin panel visible',
        );

        if (adminSellerOrdersButton.evaluate().isNotEmpty) {
          await tester.tap(adminSellerOrdersButton.first);
          await pumpWait(tester, seconds: 2);
          tracker.check(
            'C043',
            find.byType(Scaffold).evaluate().isNotEmpty,
            '[admin] seller orders quick open',
          );
          await goBack(tester);
        }

        final adminBuyerOrdersButton = find.byKey(
          const Key('profile_my_orders_button'),
        );
        tracker.check(
          'C064',
          adminBuyerOrdersButton.evaluate().isNotEmpty,
          '[admin] garde aussi acces buyer orders',
        );

        if (adminPanelButton.evaluate().isNotEmpty) {
          await tester.tap(adminPanelButton.first);
          await pumpWait(tester, seconds: 3);
          tracker.check(
            'C044',
            find.byType(Scaffold).evaluate().isNotEmpty,
            '[admin] scaffold panel',
          );
          tracker.check(
            'C045',
            find.byKey(const Key('admin_screen_title')).evaluate().isNotEmpty,
            '[admin] title panel',
          );
          tracker.check(
            'C046',
            find.byKey(const Key('admin_tab_sellers')).evaluate().isNotEmpty,
            '[admin] tab sellers',
          );
          tracker.check(
            'C047',
            find.byKey(const Key('admin_tab_users')).evaluate().isNotEmpty,
            '[admin] tab users',
          );
          tracker.check(
            'C048',
            find.byKey(const Key('admin_tab_orders')).evaluate().isNotEmpty,
            '[admin] tab orders',
          );
          tracker.check(
            'C049',
            find.byKey(const Key('admin_tab_products')).evaluate().isNotEmpty,
            '[admin] tab products',
          );
          tracker.check(
            'C050',
            find.byKey(const Key('admin_tab_payments')).evaluate().isNotEmpty,
            '[admin] tab payments',
          );
          tracker.check(
            'C051',
            find.byKey(const Key('admin_tab_security')).evaluate().isNotEmpty,
            '[admin] tab security',
          );

          for (final tabKey in const [
            'admin_tab_sellers',
            'admin_tab_users',
            'admin_tab_orders',
            'admin_tab_products',
            'admin_tab_payments',
            'admin_tab_security',
          ]) {
            final tabFinder = find.byKey(Key(tabKey));
            if (tabFinder.evaluate().isNotEmpty) {
              await tester.tap(tabFinder.first);
              await pumpWait(tester, seconds: 1);
              tracker.check(
                'C052',
                find.byType(Scaffold).evaluate().isNotEmpty,
                '[admin] navigation onglet $tabKey stable',
              );
            }
          }

          tracker.check(
            'C065',
            find.byKey(const Key('admin_tab_orders')).evaluate().isNotEmpty &&
                find
                    .byKey(const Key('admin_tab_payments'))
                    .evaluate()
                    .isNotEmpty,
            '[admin] tabs order/payment persistent after navigation',
          );
          await goBack(tester);
        }

        final didTapPrivacy = await tapByKey(tester, 'profile_privacy_button');
        if (didTapPrivacy) {
          await pumpWait(tester, seconds: 2);
          tracker.check(
            'C053',
            find.byType(Scaffold).evaluate().isNotEmpty,
            '[admin] privacy screen open',
          );
          await goBack(tester);
        }

        await goBack(tester);
        await pumpWait(tester, seconds: 2);

        tracker.check(
          'C066',
          find.byKey(const Key('home_settings_button')).evaluate().isNotEmpty,
          '[admin] retour home/profile stable',
        );
      }

      await ensureHomeReady(tester, timeoutSeconds: 15);
      final globalCart = find.byKey(const Key('home_cart_button'));
      final globalSettings = find.byKey(const Key('home_settings_button'));
      tracker.check(
        'C067',
        globalCart.evaluate().isNotEmpty,
        'home cart remains available after role switching',
      );
      tracker.check(
        'C068',
        globalSettings.evaluate().isNotEmpty,
        'home settings remains available after role switching',
      );

      if (globalSettings.evaluate().isNotEmpty) {
        await tester.tap(globalSettings.first, warnIfMissed: false);
        await pumpWait(tester, seconds: 2);
        tracker.check(
          'C069',
          find.byType(Scaffold).evaluate().isNotEmpty,
          'profile/settings still opens at end of run',
        );
        await goBack(tester);
      } else {
        tracker.stopOnSkip(
          'S201',
          'Global settings missing at final edge-hardening',
        );
      }

      tracker.check(
        'C070',
        find.byType(Scaffold).evaluate().isNotEmpty,
        'app remains interactive at end of suite',
      );

      await ensureHomeReady(tester, timeoutSeconds: 8);

      debugPrint('🚪 ========== SIGN OUT FLOW START ========== 🚪');
      var settingsForSignOut = find.byKey(const Key('home_settings_button'));
      if (settingsForSignOut.evaluate().isEmpty) {
        await ensureHomeReady(tester, timeoutSeconds: 8);
        settingsForSignOut = find.byKey(const Key('home_settings_button'));
      }
      if (settingsForSignOut.evaluate().isNotEmpty) {
        await tester.tap(settingsForSignOut.first, warnIfMissed: false);
        await pumpWait(tester, seconds: 2);

        final signOutButton = find.byKey(const Key('profile_sign_out_button'));
        tracker.check(
          'C080',
          signOutButton.evaluate().isNotEmpty,
          'Sign out button visible in profile',
        );

        if (signOutButton.evaluate().isNotEmpty) {
          // Ensure sign out button is scrolled into view before tapping
          await ensureFinderOnScreen(tester, signOutButton);
          await tester.tap(signOutButton.first, warnIfMissed: false);
          await pumpWait(tester, seconds: 4);

          final signedOut = await verifySignedOutState(tester);
          tracker.check(
            'C099',
            signedOut,
            'Signed out state confirmed (popup/login visible)',
          );
        } else {
          tracker.stopOnSkip('S005', 'Sign out button not found in profile');
        }
      } else {
        tracker.stopOnSkip('S006', 'Settings button missing before sign out');
      }

      debugPrint('🧪 Running final tracker validation...');
      debugPrint('📊 Test Statistics:');
      debugPrint('  Total checks performed: ${tracker.caseCount}');
      debugPrint('  ✅ Passed: ${tracker.caseCount - tracker.failedCases.length}');
      debugPrint('  ❌ Failed: ${tracker.failedCases.length}');
      if (tracker.failedCases.isNotEmpty) {
        debugPrint('  ⚠️  Failed cases:');
        for (final failure in tracker.failedCases) {
          debugPrint('    - $failure');
        }
      }
      tracker.throwIfFailed();
      debugPrint('🎉🎉🎉 ========== ADMIN FLOW TEST COMPLETE ========== 🎉🎉🎉');
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
