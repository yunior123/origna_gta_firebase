import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets(
    'Add Product — standard/digital/free/local/perishable/validation',
    (tester) async {
      debugPrint('🛍️🛍️🛍️ ========== ADD PRODUCT TEST START ========== 🛍️🛍️🛍️');
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

      debugStep('P00', 'Add Product Flow — Login as seller');

      final seller = await establishSession(
        tester,
        sellerCredentialCandidates,
        'seller',
        tracker,
        'S001',
        '[seller] session/login failed',
      );
      if (seller == null) return;

      final runStamp = DateTime.now().millisecondsSinceEpoch.toString();
      final p01Name = 'T01 Standard Ship $runStamp';
      final p02Name = 'T02 Digital Item $runStamp';
      final p03Name = 'T03 Free Ship $runStamp';
      final p04Name = 'T04 Local Only $runStamp';
      final p05Name = 'T05 Perishable $runStamp';
      final p09Name = 'T09 Express Test $runStamp';
      final p10Name = 'T10 Digital Full $runStamp';
      final p12Name = 'T12 Bad Price $runStamp';

      final canAddProducts = await ensureAddProductCreationContext(tester);
      if (!canAddProducts) {
        tracker.stopOnSkip(
          'S006',
          'Unable to navigate to add product screen after seller login',
        );
        tracker.throwIfFailed();
        return;
      }

      var exist = false;

      debugStep('P01', 'T01 — Physical Product + Standard Delivery');
      tracker.check(
        'C011',
        find.byKey(const Key('addproduct_screen_title')).evaluate().isNotEmpty,
        'Add product screen visible',
      );
      await fillBasicProductFields(tester, name: p01Name, price: '29.99');
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_section_delivery')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      tracker.check(
        'C012',
        find
            .byKey(const Key('addproduct_standard_delivery_card'))
            .evaluate()
            .isNotEmpty,
        'Standard delivery visible',
      );
      await fillAddress(tester);
      await publishAndVerify(tester, tracker, 'T01', 'C081p', 'S020');
      await cleanupAndVerifyProduct(tester, p01Name, tracker, 'C081', 'T01');

      debugStep('P02', 'T02 — Digital Product (No Shipping)');
      await navigateToAddProduct(tester);
      await fillBasicProductFields(tester, name: p02Name, price: '9.99');
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_section_delivery')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tapGlassToggle(tester, 'addproduct_digital_toggle');
      await tester.pump(const Duration(milliseconds: 500));
      final digitalBanner = find.byKey(
        const Key('addproduct_digital_info_banner'),
      );
      if (digitalBanner.evaluate().isEmpty) {
        await tapGlassToggle(tester, 'addproduct_digital_toggle');
        await tester.pump(const Duration(milliseconds: 500));
      }
      tracker.check(
        'C013',
        digitalBanner.evaluate().isNotEmpty,
        'Digital info banner visible',
      );
      await publishAndVerify(tester, tracker, 'T02', 'C082', 'S021');
      await cleanupAndVerifyProduct(tester, p02Name, tracker, 'C083', 'T02');

      debugStep('P03', 'T03 — Free Shipping Toggle');
      await navigateToAddProduct(tester);
      await fillBasicProductFields(tester, name: p03Name, price: '49.99');
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_free_shipping_toggle')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tapGlassToggle(tester, 'addproduct_free_shipping_toggle');
      await tester.pump(const Duration(milliseconds: 500));
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_section_delivery')),
      );
      tracker.check(
        'C014',
        find
            .byKey(const Key('addproduct_standard_delivery_card'))
            .evaluate()
            .isNotEmpty,
        'Free shipping ne cache pas standard delivery',
      );
      await fillAddress(tester);
      await publishAndVerify(tester, tracker, 'T03', 'C084', 'S022');
      await cleanupAndVerifyProduct(tester, p03Name, tracker, 'C085', 'T03');

      debugStep('P04', 'T04 — Local Pickup Only');
      await navigateToAddProduct(tester);
      await fillBasicProductFields(tester, name: p04Name, price: '15.00');
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_local_pickup_toggle')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tapGlassToggle(tester, 'addproduct_local_pickup_toggle');
      await tester.pump(const Duration(milliseconds: 500));
      await fillAddress(tester);
      await publishAndVerify(tester, tracker, 'T04', 'C086', 'S023');
      await cleanupAndVerifyProduct(tester, p04Name, tracker, 'C087', 'T04');

      debugStep('P05', 'T05 — Perishable + Same-Day Delivery');
      await navigateToAddProduct(tester);
      await fillBasicProductFields(tester, name: p05Name, price: '12.50');
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_section_delivery')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tapGlassToggle(tester, 'addproduct_perishable_toggle');
      await tester.pump(const Duration(milliseconds: 500));
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_same_day_delivery_card')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final sameDaySwitch = find.byKey(
        const Key('addproduct_same_day_delivery_card'),
      );
      if (sameDaySwitch.evaluate().isNotEmpty) {
        await tester.tap(sameDaySwitch.first);
        await tester.pump(const Duration(milliseconds: 500));
      } else {
        tracker.stopOnSkip('S006', 'Could not find Same-Day delivery switch');
      }
      await fillAddress(tester);
      await publishAndVerify(tester, tracker, 'T05', 'C088', 'S024');
      await cleanupAndVerifyProduct(tester, p05Name, tracker, 'C089', 'T05');

      debugStep('P09', 'T09 — Express Delivery Tier Toggle');
      final navT09 = await navigateToAddProduct(tester);
      if (navT09) {
        await fillBasicProductFields(tester, name: p09Name, price: '35.00');
        await scrollUntilVisible(
          tester,
          find.byKey(const Key('addproduct_express_delivery_card')),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final expressSwitch = find.byKey(
          const Key('addproduct_express_delivery_card'),
        );
        if (expressSwitch.evaluate().isNotEmpty) {
          final tappedExpress = await tapByKey(
            tester,
            'addproduct_express_delivery_card',
          );
          if (!tappedExpress) {
            tracker.stopOnSkip(
              'S018',
              'Express delivery card not tappable/visible',
            );
          }
        }

        await scrollUntilVisible(
          tester,
          find.byKey(const Key('addproduct_same_day_delivery_card')),
        );
        final sameDaySwitch2 = find.byKey(
          const Key('addproduct_same_day_delivery_card'),
        );
        if (sameDaySwitch2.evaluate().isNotEmpty) {
          final tappedSameDay = await tapByKey(
            tester,
            'addproduct_same_day_delivery_card',
          );
          if (!tappedSameDay) {
            tracker.stopOnSkip(
              'S019',
              'Same-day delivery card not tappable/visible',
            );
          }
        }

        await fillAddress(tester);

        final publishMessageT09 = await tapPublishProduct(tester);
        final hasSuccessT09 = await didPublishSucceed(tester);
        tracker.check('C095', hasSuccessT09, 'T09 publication reussie');
        if (!hasSuccessT09) {
          tracker.stopOnSkip(
            'S025',
            'T09 publish failed (validation/images/backend): ${publishMessageT09 ?? 'no snackbar message captured'}',
          );
        }

        if (find
            .byKey(const Key('addproduct_screen_title'))
            .evaluate()
            .isNotEmpty) {
          await goBack(tester);
          await pumpSettle(tester, iterations: 3);
        }

        await pumpSettle(tester, iterations: 3);
        exist = await verifyProductInMarketplace(tester, p09Name);
        tracker.check('C096', exist, 'T09 trouve dans marketplace');
      }

      debugStep('P10', 'T10 — Digital Product Hides Physical Sections');
      final navT10 = await navigateToAddProduct(tester);
      if (navT10) {
        await fillBasicProductFields(tester, name: p10Name, price: '5.99');
        await scrollUntilVisible(
          tester,
          find.byKey(const Key('addproduct_digital_toggle')),
        );
        await tapGlassToggle(tester, 'addproduct_digital_toggle');
        await tester.pump(const Duration(milliseconds: 800));

        final perishableHidden = find
            .byKey(const Key('addproduct_perishable_toggle'))
            .evaluate()
            .isEmpty;
        final standardHidden = find
            .byKey(const Key('addproduct_standard_delivery_card'))
            .evaluate()
            .isEmpty;
        final packageHidden = find
            .byKey(const Key('addproduct_section_package'))
            .evaluate()
            .isEmpty;

        tracker.check('C015', perishableHidden, 'Digital cache perishable');
        tracker.check('C016', standardHidden, 'Digital cache standard');
        tracker.check('C017', packageHidden, 'Digital cache package section');

        await goBack(tester);
        await pumpSettle(tester, iterations: 3);
      }

      debugStep('P11', 'T11 — Validation Empty Name');
      final navT11 = await navigateToAddProduct(tester);
      if (navT11) {
        await enterTextByKey(tester, 'product_price_field', '10.00');
        await enterTextByKey(tester, 'product_stock_field', '5');
        await tapPublishProduct(tester);

        final stillOnAddProduct = find.byKey(
          const Key('addproduct_screen_title'),
        );
        tracker.check(
          'C018',
          stillOnAddProduct.evaluate().isNotEmpty,
          'Validation bloque submit sans nom',
        );

        await goBack(tester);
        await pumpSettle(tester, iterations: 3);
      }

      debugStep('P12', 'T12 — Validation Negative/Zero Price');
      final navT12 = await navigateToAddProduct(tester);
      if (navT12) {
        await fillBasicProductFields(tester, name: p12Name, price: '0');
        await tapPublishProduct(tester);

        final stillOnAddProduct2 = find.byKey(
          const Key('addproduct_screen_title'),
        );
        tracker.check(
          'C019',
          stillOnAddProduct2.evaluate().isNotEmpty,
          'Validation bloque prix zero',
        );

        await goBack(tester);
        await pumpSettle(tester, iterations: 3);
      }

      await ensureHomeReady(tester, timeoutSeconds: 8);

      debugPrint('🚪 ========== SIGN OUT FLOW START ========== 🚪');
      final settingsForSignOut = find.byKey(const Key('home_settings_button'));
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
          await ensureFinderOnScreen(tester, signOutButton);
          await tester.tap(signOutButton.first, warnIfMissed: false);
          await pumpWait(tester, seconds: 2);

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
      debugPrint('🎉🎉🎉 ========== ADD PRODUCT TEST COMPLETE ========== 🎉🎉🎉');
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );

  // P10b: Software sub-type selector appears after digital toggle
  testWidgets(
    'P10b: Software sub-type selector visible after digital toggle',
    (tester) async {
      debugPrint('🛍️ ========== P10b START ========== 🛍️');
      const strictIntegration = bool.fromEnvironment(
        'STRICT_INTEGRATION',
        defaultValue: true,
      );
      final tracker = await initializeIntegrationTest(
        tester,
        strictIntegration: strictIntegration,
      );

      final seller = await establishSession(
        tester,
        sellerCredentialCandidates,
        'seller',
        tracker,
        'S001',
        '[P10b] seller session/login failed',
      );
      if (seller == null) return;

      final navOk = await navigateToAddProduct(tester);
      if (!navOk) {
        tracker.stopOnSkip('S006', '[P10b] Unable to navigate to add product screen');
        tracker.throwIfFailed();
        return;
      }

      // Toggle digital ON
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_digital_toggle')),
      );
      await tapGlassToggle(tester, 'addproduct_digital_toggle');
      await tester.pump(const Duration(milliseconds: 800));

      // Digital section should appear
      tracker.check(
        'C10b1',
        find.byKey(const Key('addproduct_digital_section')).evaluate().isNotEmpty,
        'P10b: digital section visible after toggle',
      );

      // Scroll to Software chip and tap it
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_digital_type_software')),
      );
      await tapByKey(tester, 'addproduct_digital_type_software');
      await tester.pump(const Duration(milliseconds: 500));

      // macOS URL field should appear after selecting Software
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_macos_url')),
      );
      tracker.check(
        'C10b2',
        find.byKey(const Key('addproduct_macos_url')).evaluate().isNotEmpty,
        'P10b: macOS URL field visible after Software chip',
      );
      tracker.check(
        'C10b3',
        find.byKey(const Key('addproduct_windows_url')).evaluate().isNotEmpty,
        'P10b: Windows URL field visible after Software chip',
      );

      await goBack(tester);
      await pumpSettle(tester, iterations: 3);
      tracker.throwIfFailed();
      debugPrint('🎉 ========== P10b COMPLETE ========== 🎉');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  // P10c: Book sub-type — shows book URL field, hides platform fields
  testWidgets(
    'P10c: Book sub-type shows book URL field',
    (tester) async {
      debugPrint('🛍️ ========== P10c START ========== 🛍️');
      const strictIntegration = bool.fromEnvironment(
        'STRICT_INTEGRATION',
        defaultValue: true,
      );
      final tracker = await initializeIntegrationTest(
        tester,
        strictIntegration: strictIntegration,
      );

      final seller = await establishSession(
        tester,
        sellerCredentialCandidates,
        'seller',
        tracker,
        'S001',
        '[P10c] seller session/login failed',
      );
      if (seller == null) return;

      final navOk = await navigateToAddProduct(tester);
      if (!navOk) {
        tracker.stopOnSkip('S006', '[P10c] Unable to navigate to add product screen');
        tracker.throwIfFailed();
        return;
      }

      // Toggle digital ON
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_digital_toggle')),
      );
      await tapGlassToggle(tester, 'addproduct_digital_toggle');
      await tester.pump(const Duration(milliseconds: 800));

      // Scroll to Book chip and tap it
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_digital_type_book')),
      );
      await tapByKey(tester, 'addproduct_digital_type_book');
      await tester.pump(const Duration(milliseconds: 500));

      // Book URL field should appear
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('addproduct_book_url')),
      );
      tracker.check(
        'C10c1',
        find.byKey(const Key('addproduct_book_url')).evaluate().isNotEmpty,
        'P10c: book URL field visible after Book chip',
      );

      // macOS URL field must NOT be present (software-only)
      tracker.check(
        'C10c2',
        find.byKey(const Key('addproduct_macos_url')).evaluate().isEmpty,
        'P10c: macOS URL field hidden after Book chip',
      );

      await goBack(tester);
      await pumpSettle(tester, iterations: 3);
      tracker.throwIfFailed();
      debugPrint('🎉 ========== P10c COMPLETE ========== 🎉');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
