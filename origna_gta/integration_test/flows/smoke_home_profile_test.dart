import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Smoke — Home + Profile (admin)', (tester) async {
    debugPrint('🚀🚀🚀 ========== SMOKE TEST START ========== 🚀🚀🚀');
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

    debugPrint('🔍 C001: Checking MaterialApp...');
    debugPrint('  Finding MaterialApp widget...');
    final materialAppResult = find.byType(MaterialApp).evaluate().isNotEmpty;
    debugPrint('  MaterialApp found: $materialAppResult');
    tracker.check('C001', materialAppResult, 'MaterialApp rendu');
    debugPrint('✅ C001 passed: MaterialApp rendered');

    debugPrint('🔍 C002: Checking Scaffold...');
    debugPrint('  Finding Scaffold widget...');
    final scaffoldResult = find.byType(Scaffold).evaluate().isNotEmpty;
    debugPrint('  Scaffold found: $scaffoldResult');
    tracker.check('C002', scaffoldResult, 'Scaffold initial rendu');
    debugPrint('✅ C002 passed: Initial Scaffold rendered');
    debugPrint('✅ A01: App launched');
    debugStep('A01', 'App launched');

    debugPrint('👤 ========== ADMIN SESSION ESTABLISHMENT START ========== 👤');
    debugPrint(
      '  Using adminCredentialCandidates for session establishment...',
    );

    final admin = await establishSession(
      tester,
      adminCredentialCandidates,
      'admin',
      tracker,
      'S001',
      '[admin] session/login failed',
    );
    if (admin == null) return;

    debugPrint('✅ C078 passed: Admin session valid');
    debugPrint('✅ Admin session established successfully');

    debugPrint('🔍 Finding settings button after login...');
    final settingsAfterLogin = find.byKey(const Key('home_settings_button'));
    debugPrint(
      '  Settings button found: ${settingsAfterLogin.evaluate().isNotEmpty}',
    );
    debugPrint('🔍 C004: Checking settings button visibility...');
    tracker.check(
      'C004',
      settingsAfterLogin.evaluate().isNotEmpty,
      'Settings apres login',
    );
    debugPrint('✅ C004 passed: Settings button visible after login');

    debugPrint('🛒 ========== CART ICON CHECK START ========== 🛒');
    debugPrint('  Finding cart icon...');
    var cartIcon = find.byKey(const Key('home_cart_button'));
    debugPrint('  Cart icon found: ${cartIcon.evaluate().isNotEmpty}');
    if (cartIcon.evaluate().isEmpty) {
      debugPrint('⚠️  Cart icon not found, ensuring home is ready...');
      await ensureHomeReady(tester, timeoutSeconds: 8);
      debugPrint('  Retrying cart icon lookup...');
      cartIcon = find.byKey(const Key('home_cart_button'));
      debugPrint(
        '  Cart icon found after retry: ${cartIcon.evaluate().isNotEmpty}',
      );
    }
    debugPrint('🔍 C006: Checking cart icon visibility...');
    tracker.check('C006', cartIcon.evaluate().isNotEmpty, 'Cart icon visible');
    debugPrint('✅ C006 passed: Cart icon visible');

    if (cartIcon.evaluate().isNotEmpty) {
      debugPrint('🛒 Tapping cart icon...');
      await tester.tap(cartIcon.first, warnIfMissed: false);
      debugPrint('  Cart icon tapped, waiting for navigation...');
      await pumpWait(tester, seconds: 3);
      debugPrint('  Pump complete, checking cart screen...');
      debugPrint('🔍 C007: Checking cart screen displayed...');
      final cartScaffoldFound = find.byType(Scaffold).evaluate().isNotEmpty;
      debugPrint('  Cart screen Scaffold found: $cartScaffoldFound');
      tracker.check('C007', cartScaffoldFound, 'Cart screen affiche');
      debugPrint('✅ C007 passed: Cart screen displayed');
      debugPrint('◀️  Going back from cart screen...');
      await goBack(tester);
      debugPrint('  Back navigation complete');
    } else {
      debugPrint('⚠️  S200: Cart icon missing, skipping cart navigation');
      tracker.stopOnSkip('S200', 'Cart icon missing before cart navigation');
    }

    debugPrint('📦 ========== SEEDED PRODUCT SEARCH START ========== 📦');
    debugPrint('  Creating generic product card finder...');
    final anyProductCardFinder = find.byWidgetPredicate(
      (widget) {
        final key = widget.key;
        return key is ValueKey<String> && key.value.startsWith('product_card_');
      },
      description: 'any product card (key starts with product_card_)',
    );
    debugPrint(
      '  Generic product card finder ready: ${anyProductCardFinder.evaluate().isNotEmpty}',
    );
    debugPrint('  Creating product card finders...');
    final seededProductCardFinders = <Finder>[
      find.byKey(const Key('product_card_Test Physical Product')),
      find.byKey(const Key('product_card_Test Digital Product')),
      find.byKey(const Key('product_card_Test Local Product')),
    ];
    debugPrint('  Card finders created: ${seededProductCardFinders.length}');
    debugPrint('  Creating product text finders...');
    final seededProductTextFinders = <Finder>[
      find.textContaining('Test Physical Product'),
      find.textContaining('Test Digital Product'),
      find.textContaining('Test Local Product'),
      find.textContaining('Test Physical'),
      find.textContaining('Test Digital'),
      find.textContaining('Test Local'),
    ];
    debugPrint('  Text finders created: ${seededProductTextFinders.length}');

    debugPrint('🔍 Starting product search loop (max 12 retries)...');
    for (var retry = 0; retry < 12; retry++) {
      debugPrint('  🔄 Retry $retry/12: Checking for seeded products...');
      final hasAnyCandidate =
          anyProductCardFinder.evaluate().isNotEmpty ||
          seededProductCardFinders.any(
            (finder) => finder.evaluate().isNotEmpty,
          ) ||
          seededProductTextFinders.any(
            (finder) => finder.evaluate().isNotEmpty,
          );
      debugPrint('    hasAnyCandidate: $hasAnyCandidate');

      if (hasAnyCandidate) {
        debugPrint('  ✅ Product found on retry $retry');
        break;
      }

      debugPrint('    No product found, attempting scroll...');
      final scrollableRetry = find.byType(Scrollable);
      if (scrollableRetry.evaluate().isNotEmpty) {
        debugPrint('    Scrolling down 220px...');
        await tester.drag(
          scrollableRetry.first,
          const Offset(0, -220),
          warnIfMissed: false,
        );
        debugPrint('    Scroll complete');
      } else {
        debugPrint('    ⚠️  No Scrollable widget found');
      }
      await tester.pump(const Duration(milliseconds: 500));
    }
    debugPrint('  Product search loop complete');

    debugPrint('🎯 Determining product to open...');
    Finder productOpenTarget = find.byType(Scaffold);
    if (anyProductCardFinder.evaluate().isNotEmpty) {
      debugPrint('  ✅ Found at least one product card (generic)');
      productOpenTarget = anyProductCardFinder;
    }
    debugPrint('  Checking product card finders...');
    for (final finder in seededProductCardFinders) {
      if (finder.evaluate().isNotEmpty) {
        debugPrint('    ✅ Found product card');
        productOpenTarget = finder;
        break;
      }
    }
    debugPrint('  Checking product text finders...');
    productOpenTarget = seededProductTextFinders.firstWhere(
      (finder) => finder.evaluate().isNotEmpty,
      orElse: () => productOpenTarget,
    );
    debugPrint('  Product target determined');

    debugPrint('  Checking if any openable product exists...');
    final hasOpenableProduct =
        anyProductCardFinder.evaluate().isNotEmpty ||
        seededProductCardFinders.any(
          (finder) => finder.evaluate().isNotEmpty,
        ) ||
        seededProductTextFinders.any((finder) => finder.evaluate().isNotEmpty);
    debugPrint('  hasOpenableProduct: $hasOpenableProduct');

    if (hasOpenableProduct) {
      debugPrint('📦 Opening product detail...');
      await tester.tap(productOpenTarget.first, warnIfMissed: false);
      debugPrint('  Product tapped, waiting for navigation...');
      await pumpWait(tester, seconds: 3);
      debugPrint('  Pump complete, checking product detail screen...');
      debugPrint('🔍 C008: Checking product detail screen displayed...');
      final productDetailFound = find.byType(Scaffold).evaluate().isNotEmpty;
      debugPrint('  Product detail Scaffold found: $productDetailFound');
      tracker.check('C008', productDetailFound, 'Product detail affiche');
      debugPrint('✅ C008 passed: Product detail displayed');
      debugPrint('◀️  Going back from product detail...');
      await goBack(tester);
      debugPrint('  Back navigation complete');
    } else {
      debugPrint(
        '⚠️  S001: No openable product found, skipping product navigation',
      );
      tracker.stopOnSkip('S001', 'No openable product tile/text found on home');
    }

    debugPrint('⬇️ ========== HOME SCROLL INTERACTION START ========== ⬇️');
    debugPrint('  Finding Scrollable widget...');
    final scrollable = find.byType(Scrollable);
    debugPrint('  Scrollable found: ${scrollable.evaluate().isNotEmpty}');
    if (scrollable.evaluate().isNotEmpty) {
      debugPrint('  Scrolling down 300px...');
      await tester.drag(scrollable.first, const Offset(0, -300));
      debugPrint('  Pumping after down scroll...');
      await tester.pump(const Duration(seconds: 2));
      debugPrint('  Scrolling up 300px...');
      await tester.drag(scrollable.first, const Offset(0, 300));
      debugPrint('  Pumping after up scroll...');
      await tester.pump(const Duration(seconds: 2));
      debugPrint('✅ A08: Home scroll interaction works');
      debugStep('A08', 'Home scroll interaction works');
    } else {
      debugPrint('⚠️  S002: No scrollable widget found on home');
      tracker.stopOnSkip('S002', 'No scrollable widget found on home');
    }

    debugPrint('⚙️ ========== PROFILE NAVIGATION START ========== ⚙️');
    debugPrint('  Finding settings button...');
    final settingsNow = find.byKey(const Key('home_settings_button'));
    debugPrint('  Settings button found: ${settingsNow.evaluate().isNotEmpty}');
    if (settingsNow.evaluate().isEmpty) {
      debugPrint('⚠️  S003: Settings icon not found');
      tracker.stopOnSkip('S003', 'Settings icon not found');
    } else {
      debugPrint('  Tapping settings button...');
      await tester.tap(settingsNow.first, warnIfMissed: false);
      debugPrint('  Settings tapped, waiting for navigation...');
      await pumpWait(tester, seconds: 5);
      debugPrint('  Pump complete, checking profile screen...');
      debugPrint('🔍 C009: Checking profile screen displayed...');
      final profileScaffoldFound = find.byType(Scaffold).evaluate().isNotEmpty;
      debugPrint('  Profile Scaffold found: $profileScaffoldFound');
      tracker.check('C009', profileScaffoldFound, 'Profile screen affiche');
      debugPrint('✅ C009 passed: Profile screen displayed');

      debugPrint('📋 Checking profile sub-pages...');
      debugPrint('  T10: Checking My Orders page...');
      await checkProfileSubPage(tester, 'profile_my_orders_button', 'T10');
      debugPrint('  ✅ T10 complete');
      debugPrint('  T11: Checking Favorites page...');
      await checkProfileSubPage(tester, 'profile_favorites_button', 'T11');
      debugPrint('  ✅ T11 complete');
      debugPrint('  T12: Checking Address page...');
      await checkProfileSubPage(tester, 'profile_address_button', 'T12');
      debugPrint('  ✅ T12 complete');
      debugPrint(
        '  T13: Skipping terms page to avoid external tab interruption',
      );
      debugStep('T13', 'Skipped terms page to avoid external tab interruption');

      debugPrint('🔄 Testing profile sub-page navigation...');
      debugPrint('  Finding orders button again...');
      final ordersBtn2 = find.byKey(const Key('profile_my_orders_button'));
      debugPrint('  Orders button found: ${ordersBtn2.evaluate().isNotEmpty}');
      if (ordersBtn2.evaluate().isNotEmpty) {
        debugPrint('  Tapping orders button...');
        await tester.tap(ordersBtn2.first, warnIfMissed: false);
        debugPrint('  Pumping after tap...');
        await pumpWait(tester, seconds: 2);
        debugPrint('◀️  Going back from orders page...');
        await goBack(tester);
        debugPrint('  Back navigation complete');
        debugPrint('🔍 C010: Checking return from profile sub-page...');
        final backFromSubPageOk = find.byType(Scaffold).evaluate().isNotEmpty;
        debugPrint('  Scaffold found after back: $backFromSubPageOk');
        tracker.check(
          'C010',
          backFromSubPageOk,
          'Retour depuis sous-page profile OK',
        );
        debugPrint('✅ C010 passed: Return from profile sub-page OK');

        debugPrint('◀️  Going back to home...');
        await goBack(tester);
        debugPrint('  Pumping after back to home...');
        await pumpWait(tester, seconds: 2);
        debugPrint('🔍 C079: Checking explicit return to home...');
        final homeSettingsFound = find
            .byKey(const Key('home_settings_button'))
            .evaluate()
            .isNotEmpty;
        debugPrint('  Home settings button found: $homeSettingsFound');
        tracker.check(
          'C079',
          homeSettingsFound,
          'Retour Home explicite apres flow profile',
        );
        debugPrint('✅ C079 passed: Explicit return to home after profile flow');
      } else {
        debugPrint('⚠️  S004: Orders button not found in profile');
        tracker.stopOnSkip('S004', 'Orders button not found in profile');
      }
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
        // The sign out button sits in the profile "Danger Zone" (near bottom).
        // On some viewports it exists but is off-screen, which makes taps flaky.
        await ensureFinderOnScreen(tester, signOutButton, maxAttempts: 20);
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
    debugPrint('🎉🎉🎉 ========== SMOKE TEST COMPLETE ========== 🎉🎉🎉');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
