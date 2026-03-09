// ─────────────────────────────────────────────────────────────────────────────
// Shared Test Helpers — All integration tests import this.
// Centralizes credentials, pump helpers, login, and navigation.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/main_test.dart' as app;

bool _appBootstrapped = false;
bool _devSeedEnsured = false;

Future<void> ensureDevSeedData(
  WidgetTester tester, {
  Credential? signedInCredential,
}) async {
  if (_devSeedEnsured) return;
  _devSeedEnsured = true;

  await tester.runAsync(() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠ ensureDevSeedData: no FirebaseAuth user; skipping');
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      final products = await firestore
          .collection(Collections.products)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (products.docs.isNotEmpty) {
        // ok
      } else {
        debugPrint(
          '⚠ ensureDevSeedData: no products found in DEV. Admin/Buyer demos may look empty.',
        );
      }
    } catch (e) {
      debugPrint('⚠ ensureDevSeedData: products query failed: $e');
    }

    // Read-only checks: client writes to orders are typically blocked by rules.
    // For demos (non-emulator DEV), seed via Admin SDK script if needed.
    try {
      final favoritesRef = firestore
          .collection(Collections.users)
          .doc(user.uid)
          .collection(Collections.favorites);
      final existingFavs = await favoritesRef
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (existingFavs.docs.isEmpty) {
        debugPrint(
          'ℹ️ ensureDevSeedData: favorites empty for ${signedInCredential?.email ?? user.uid} (ok, but demo may look empty).',
        );
      }
    } catch (e) {
      debugPrint('⚠ ensureDevSeedData: favorites read failed: $e');
    }

    try {
      final ordersRef = firestore.collection(Collections.orders);
      final existingOrders = await ordersRef
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (existingOrders.docs.isEmpty) {
        debugPrint(
          'ℹ️ ensureDevSeedData: orders collection appears empty (ok for tests, but Admin Orders tab may look empty).',
        );
      }
    } catch (e) {
      debugPrint('⚠ ensureDevSeedData: orders read failed: $e');
    }
  });

  await tester.pump(const Duration(milliseconds: 250));
}

void debugStep(String id, String message) {
  // Integration tests often run in profile mode on web; `debugPrint` output can
  // be suppressed/throttled. Use `print` so PASS/FAIL case logs are always
  // visible in `flutter drive` output.
  // ignore: avoid_print
  print('[$id] $message');
}

/// Documentation for CaseTracker
class CaseTracker {
  final bool strictIntegration;
  int caseCount = 0;
  final List<String> failedCases = [];

  CaseTracker({required this.strictIntegration});

  void check(String id, bool condition, String label) {
    caseCount++;
    if (!condition) {
      debugStep(id, 'FAIL — $label');
      if (strictIntegration) {
        failedCases.add('$id: $label');
      }
      return;
    }
    debugStep(id, 'PASS — $label');
  }

  void stopOnSkip(String id, String reason) {
    caseCount++;
    debugStep(id, 'SKIP => STOP — $reason');
    if (strictIntegration) {
      failedCases.add('$id: SKIP => STOP — $reason');
    }
  }

  void throwIfFailed() {
    _publishReportData();
    if (strictIntegration && failedCases.isNotEmpty) {
      final preview = failedCases.take(20).join(' | ');
      fail(
        'Integration run completed with ${failedCases.length} failed checks. First failures: $preview',
      );
    } else if (!strictIntegration && failedCases.isNotEmpty) {
      debugStep(
        'Z03',
        'Non-strict mode: ${failedCases.length} failed checks recorded but not fatal',
      );
    }
  }

  void _publishReportData() {
    // When running Flutter web integration tests via `-d web-server`, stdout
    // from the browser isn't streamed to the terminal. The driver *does* receive
    // `reportData`, so we publish our checklist summary there.
    try {
      final binding = IntegrationTestWidgetsFlutterBinding.instance;
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['caseCount'] = caseCount;
      binding.reportData!['strictIntegration'] = strictIntegration;
      binding.reportData!['failedCases'] = List<String>.from(failedCases);
    } catch (_) {
      // ignore: avoid_print
      print('[Z99] WARN — unable to publish reportData to driver');
    }
  }
}

// ─── CREDENTIALS ─────────────────────────────────────────────────────────────

// Integration tests run against DEV Firebase (no emulators).
// Credentials MUST be provided via `--dart-define` or `--dart-define-from-file`.
// Defaults are intentionally empty to avoid accidentally using real accounts.

const buyerEmail = String.fromEnvironment('TEST_BUYER_EMAIL', defaultValue: '');
const buyerPassword = String.fromEnvironment(
  'TEST_BUYER_PASSWORD',
  defaultValue: '',
);

const sellerEmail = String.fromEnvironment(
  'TEST_SELLER_EMAIL',
  defaultValue: '',
);
const sellerPassword = String.fromEnvironment(
  'TEST_SELLER_PASSWORD',
  defaultValue: '',
);

const adminEmail = String.fromEnvironment('TEST_ADMIN_EMAIL', defaultValue: '');
const adminPassword = String.fromEnvironment(
  'TEST_ADMIN_PASSWORD',
  defaultValue: '',
);

void _assertDevIntegrationConfig() {
  const env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
  if (env != 'dev') {
    fail(
      'Integration tests must run against DEV Firebase only. '
      'Provide --dart-define=ENVIRONMENT=dev (current ENVIRONMENT=$env).',
    );
  }

  // Fail fast: integration tests must not rely on hardcoded credentials.
  // Required for the all-tests aggregator (random suite selection).
  final missing = <String>[];
  if (buyerEmail.trim().isEmpty) missing.add('TEST_BUYER_EMAIL');
  if (buyerPassword.isEmpty) missing.add('TEST_BUYER_PASSWORD');
  if (adminEmail.trim().isEmpty) missing.add('TEST_ADMIN_EMAIL');
  if (adminPassword.isEmpty) missing.add('TEST_ADMIN_PASSWORD');

  if (missing.isNotEmpty) {
    fail(
      'Missing integration credentials: ${missing.join(', ')}.\n'
      'Run with e.g.:\n'
      'flutter drive --driver=test_driver/integration_test.dart '
      '--target=integration_test/all_tests.dart -d chrome '
      '--dart-define=ENVIRONMENT=dev --dart-define=IS_TEST=true '
      '--dart-define-from-file=../logs/integration_dart_defines.dev.json',
    );
  }
}

String _resolvedSellerEmail() {
  // DEV Firebase can legitimately have only an admin + buyer account.
  // Allow seller flows to reuse the admin account when seller creds aren't set.
  return sellerEmail.isNotEmpty ? sellerEmail : adminEmail;
}

String _resolvedSellerPassword() {
  return sellerPassword.isNotEmpty ? sellerPassword : adminPassword;
}

/// Documentation for Credential
class Credential {
  final String label;
  final String email;
  final String password;

  const Credential({
    required this.label,
    required this.email,
    required this.password,
  });
}

final buyerCredentialCandidates = <Credential>[
  const Credential(
    label: '[buyer]',
    email: buyerEmail,
    password: buyerPassword,
  ),
];

final sellerCredentialCandidates = <Credential>[
  Credential(
    label: '[buyer,seller]',
    email: _resolvedSellerEmail(),
    password: _resolvedSellerPassword(),
  ),
];

final adminCredentialCandidates = <Credential>[
  const Credential(
    label: '[buyer,seller,admin]',
    email: adminEmail,
    password: adminPassword,
  ),
];

Future<bool> _waitForFirebaseAuthSignedIn(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (FirebaseAuth.instance.currentUser != null) return true;

  bool signedIn = false;
  await tester.runAsync(() async {
    try {
      await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(timeout);
      signedIn = true;
    } catch (_) {
      signedIn = FirebaseAuth.instance.currentUser != null;
    }
  });

  // One more pump to let providers/UI react.
  await tester.pump(const Duration(milliseconds: 250));
  return signedIn || FirebaseAuth.instance.currentUser != null;
}

// ─── PUMP HELPERS ────────────────────────────────────────────────────────────

/// Pump N frames with a short delay.
Future<void> pumpFor(
  WidgetTester tester, {
  int frames = 5,
  int ms = 100,
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// Wait for network / Firebase operations.
Future<void> pumpWait(WidgetTester tester, {int seconds = 3}) async {
  debugPrint('⏱️  pumpWait START: ${seconds}s');
  final iterations = seconds * 2;
  for (var i = 0; i < iterations; i++) {
    debugPrint('  ⏱️  Pump ${i + 1}/$iterations (500ms)');
    await tester.pump(const Duration(milliseconds: 500));
  }
  debugPrint('✅ pumpWait COMPLETE: ${seconds}s elapsed');
}

Future<bool> waitForAppBootstrap(
  WidgetTester tester, {
  int timeoutSeconds = 180,
}) async {
  debugPrint('🚀 waitForAppBootstrap START: timeout=${timeoutSeconds}s');
  final materialApp = find.byType(MaterialApp);
  final scaffold = find.byType(Scaffold);
  final homeSettings = find.byKey(const Key('home_settings_button'));

  final maxTicks = timeoutSeconds * 2;
  for (var i = 0; i < maxTicks; i++) {
    final hasMaterialApp = materialApp.evaluate().isNotEmpty;
    final hasScaffold = scaffold.evaluate().isNotEmpty;
    final hasHomeSettings = homeSettings.evaluate().isNotEmpty;

    if (i % 10 == 0) {
      debugPrint(
        '  [$i/$maxTicks] MaterialApp=$hasMaterialApp Scaffold=$hasScaffold HomeSettings=$hasHomeSettings',
      );
    }

    if (hasMaterialApp && (hasScaffold || hasHomeSettings)) {
      debugPrint(
        '✅ waitForAppBootstrap COMPLETE: app ready after ${i * 500}ms',
      );
      return true;
    }

    await tester.pump(const Duration(milliseconds: 500));
  }

  debugPrint('❌ waitForAppBootstrap TIMEOUT: ${timeoutSeconds}s exceeded');
  return false;
}

// ─── APP LIFECYCLE ───────────────────────────────────────────────────────────

/// Launch app and wait for it to settle.
Future<void> launchApp(WidgetTester tester, {int pumpSeconds = 6}) async {
  debugPrint('🚀🚀 launchApp START: pumpSeconds=$pumpSeconds');
  debugPrint('  📱 Calling app.mainTest()...');
  await app.mainTest();
  debugPrint('  ✅ app.mainTest() complete');

  debugPrint('  ⏱️  pumpWait for ${pumpSeconds}s...');
  await pumpWait(tester, seconds: pumpSeconds);

  debugPrint('  🔍 Checking bootstrap status...');
  final bootstrapped = await waitForAppBootstrap(tester);
  if (!bootstrapped) {
    debugPrint('❌❌ launchApp FAILED: bootstrap timeout');
    fail(
      'launchApp: bootstrap timeout (MaterialApp=${find.byType(MaterialApp).evaluate().isNotEmpty}, '
      'Scaffold=${find.byType(Scaffold).evaluate().isNotEmpty}, '
      'home_settings_button=${find.byKey(const Key('home_settings_button')).evaluate().isNotEmpty})',
    );
  }
  debugPrint('✅✅ launchApp COMPLETE: app running');
}

Future<void> ensureAppStarted(
  WidgetTester tester, {
  int pumpSeconds = 6,
}) async {
  if (!_appBootstrapped) {
    await app.mainTest();
    await pumpWait(tester, seconds: pumpSeconds);
    _appBootstrapped = true;
  }

  final bootstrapped = await waitForAppBootstrap(tester);
  if (!bootstrapped) {
    fail(
      'ensureAppStarted: bootstrap timeout (MaterialApp=${find.byType(MaterialApp).evaluate().isNotEmpty}, '
      'Scaffold=${find.byType(Scaffold).evaluate().isNotEmpty}, '
      'home_settings_button=${find.byKey(const Key('home_settings_button')).evaluate().isNotEmpty})',
    );
  }
}

Future<bool> ensureHomeReady(
  WidgetTester tester, {
  int timeoutSeconds = 15,
}) async {
  // Some builds/screens do not have a bottom navigation tab with a Home icon.
  // Avoid noisy logs and rely on stable home anchors (keys) instead.
  await navigateToTab(tester, Icons.home);
  final maxTicks = timeoutSeconds * 2;
  for (var i = 0; i < maxTicks; i++) {
    final hasSettings = find
        .byKey(const Key('home_settings_button'))
        .evaluate()
        .isNotEmpty;
    final hasCart = find
        .byKey(const Key('home_cart_button'))
        .evaluate()
        .isNotEmpty;
    final hasScaffold = find.byType(Scaffold).evaluate().isNotEmpty;
    if (hasSettings && hasScaffold) {
      return true;
    }
    if (!hasScaffold) {
      await tester.pump(const Duration(milliseconds: 350));
      continue;
    }
    if (!hasSettings && hasCart) {
      await navigateToTab(tester, Icons.home);
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  return find.byKey(const Key('home_settings_button')).evaluate().isNotEmpty;
}

// ─── LOGIN HELPERS ───────────────────────────────────────────────────────────

Future<bool> loginWith(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  debugPrint('🔐 loginWith START: email=$email');

  if (email.trim().isEmpty || password.isEmpty) {
    debugPrint(
      '❌ loginWith: missing TEST_* credentials. '
      'Provide --dart-define (or --dart-define-from-file) for TEST_*.',
    );
    return false;
  }

  // Wait for login fields
  debugPrint('  ⏳ Waiting for login fields...');
  for (var i = 0; i < 12; i++) {
    if (find.byKey(const Key('login_email_field')).evaluate().isNotEmpty) {
      debugPrint('  ✅ Login fields found after ${i + 1} attempts');
      break;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }

  final emailField = find.byKey(const Key('login_email_field'));
  final passwordField = find.byKey(const Key('login_password_field'));

  if (emailField.evaluate().isEmpty || passwordField.evaluate().isEmpty) {
    debugPrint('⚠️ Login fields not found — may already be logged in');
    return false;
  }
  debugPrint('  📧 Email field: present');
  debugPrint('  🔑 Password field: present');

  // Toggle to Sign In mode if in Register mode
  if (find.byKey(const Key('login_name_field')).evaluate().isNotEmpty) {
    debugPrint('  ℹ️  In Register mode, toggling to Sign In...');
    final toggle = find.byKey(const Key('login_toggle_mode_button'));
    if (toggle.evaluate().isNotEmpty) {
      await tester.tap(toggle.first, warnIfMissed: false);
      await pumpFor(tester);
      debugPrint('  ✅ Toggled to Sign In mode');
    }
  }

  debugPrint('  ⌨️  Entering email...');
  await tester.enterText(emailField, email);
  await pumpFor(tester, frames: 3, ms: 100);
  debugPrint('  ✅ Email entered');

  debugPrint('  ⌨️  Entering password...');
  await tester.enterText(passwordField, password);
  await pumpFor(tester, frames: 3, ms: 100);
  debugPrint('  ✅ Password entered');

  // Dismiss keyboard
  debugPrint('  ⌨️  Dismissing keyboard...');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await pumpFor(tester, frames: 3, ms: 200);
  debugPrint('  ✅ Keyboard dismissed');

  final loginButton = find.byKey(const Key('login_submit_button'));
  if (loginButton.evaluate().isEmpty) {
    debugPrint('  ❌ Login button not found');
    return false;
  }
  debugPrint('  🔘 Login button found, tapping...');

  await tester.tap(loginButton.first, warnIfMissed: false);
  debugPrint('  ⏳ Waiting for FirebaseAuth signed-in...');
  await pumpWait(tester, seconds: 2);

  final signedIn = await _waitForFirebaseAuthSignedIn(tester);
  if (signedIn) {
    debugPrint('✅ loginWith COMPLETE (signed in)');
    return true;
  }

  debugPrint('❌ loginWith: still signed out after submit');
  return false;
}

bool isAdminAccountEmail(String email) {
  final lower = email.toLowerCase();
  return adminCredentialCandidates
      .map((credential) => credential.email.toLowerCase())
      .contains(lower);
}

Future<Credential?> switchToAnyCredential(
  WidgetTester tester,
  List<Credential> credentials,
) async {
  if (credentials.isEmpty) return null;

  final credential = credentials.first;
  debugPrint('🔄 switchToAnyCredential: ${credential.email}');

  debugPrint('  ⚙️  Looking for settings button...');
  final settingsButton = find.byKey(const Key('home_settings_button'));
  if (settingsButton.evaluate().isEmpty) {
    debugPrint('  ❌ Settings button not found');
    return null;
  }
  debugPrint('  ✅ Settings button found, tapping...');

  await tester.tap(settingsButton.first, warnIfMissed: false);

  debugPrint('  ⏳ Waiting 4s for popup/profile to appear...');
  await pumpWait(tester, seconds: 4);

  debugPrint('  💬 Checking for sign-in popup...');
  await handleSignInPopup(
    tester,
    email: credential.email,
    password: credential.password,
  );

  final signedIn = await _waitForFirebaseAuthSignedIn(tester);
  if (!signedIn) {
    debugPrint(
      '❌ switchToAnyCredential: failed to establish auth session for ${credential.email}',
    );
    return null;
  }

  // Close the profile/settings screen that was opened by tapping settings button
  debugPrint('  🔙 Closing profile screen...');
  await goBack(tester);
  await pumpWait(tester, seconds: 1);

  debugPrint('  ✅ switchToAnyCredential completed');
  return credential;
}

Future<Credential?> switchCredentialWithRecovery(
  WidgetTester tester,
  List<Credential> candidates,
  String scope,
) async {
  final credential = await switchToAnyCredential(tester, candidates);
  if (credential != null) {
    await ensureHomeReady(tester, timeoutSeconds: 3);
    return credential;
  }
  return null;
}

Future<bool> ensureAddProductCreationContext(WidgetTester tester) async {
  final credential = await switchCredentialWithRecovery(tester, <Credential>[
    ...adminCredentialCandidates,
    ...sellerCredentialCandidates,
  ], 'P00');
  if (credential == null) {
    return false;
  }

  await ensureHomeReady(tester, timeoutSeconds: 12);
  
  // Tap outside menu overlay to dismiss it (settings menu stays open after credential switch)
  debugPrint('  🔒 Dismissing any open menus by tapping outside...');
  await tester.tapAt(const Offset(50, 100));
  await pumpWait(tester, seconds: 1);
  
  // Navigate to home tab to force menu closure
  await navigateToTab(tester, Icons.home, logIfMissing: false);
  await pumpWait(tester, seconds: 2);
  
  // Force rebuilds to ensure add product button appears
  await pumpSettle(tester, iterations: 3, ms: 500);
  
  final canNavigate = await navigateToAddProduct(tester);
  if (!canNavigate) {
    debugStep(
      'P00',
      'Role session established but add-product entry is still unavailable',
    );
    return false;
  }

  return true;
}

// ─── NAVIGATION ──────────────────────────────────────────────────────────────

/// Navigate to a tab by icon.
Future<bool> navigateToTab(
  WidgetTester tester,
  IconData icon, {
  bool logIfMissing = false,
}) async {
  final tabIcon = find.byIcon(icon);
  if (tabIcon.evaluate().isNotEmpty) {
    debugPrint('🔀 navigateToTab: icon=$icon');
    debugPrint('  ✅ Tab icon found, tapping...');
    await tester.tap(tabIcon.first, warnIfMissed: false);
    debugPrint('  ⏳ Waiting 2s...');
    await pumpWait(tester, seconds: 2);
    debugPrint('✅ navigateToTab COMPLETE');
    return true;
  } else {
    if (logIfMissing) {
      debugPrint('🔀 navigateToTab: icon=$icon');
      debugPrint('  ❌ Tab icon not found');
    }
    return false;
  }
}

/// Verify we are signed out by checking for the "Sign In Required" popup
/// or the presence of the login form.
///
/// This does NOT tap the sign-in button; it only asserts state.
Future<bool> verifySignedOutState(WidgetTester tester) async {
  // Try to navigate home, but do NOT rely on the settings button being present
  // (it may legitimately disappear for signed-out users).
  await navigateToTab(tester, Icons.home);
  await tester.pump(const Duration(milliseconds: 250));

  // Best-effort: wait for the Firebase auth state to actually flip to signed-out.
  // On Flutter Web, propagation can be delayed.
  await tester.runAsync(() async {
    try {
      await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((user) => user == null)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // Don't fail here — we'll fall back to UI + currentUser polling below.
    }
  });

  bool hasSignInPopupOrLoginForm() {
    final signInDialogButton = find.byKey(
      const Key('login_dialog_sign_in_button'),
    );
    final loginEmailField = find.byKey(const Key('login_email_field'));
    final loginPasswordField = find.byKey(const Key('login_password_field'));
    return signInDialogButton.evaluate().isNotEmpty ||
        loginEmailField.evaluate().isNotEmpty ||
        loginPasswordField.evaluate().isNotEmpty;
  }

  // Give auth/UI time to settle after sign-out.
  // On Web/Chrome, Firebase Auth state propagation can take several seconds.
  const maxPolls = 80; // 80 * 250ms ~= 20s
  for (var i = 0; i < maxPolls; i++) {
    if (hasSignInPopupOrLoginForm()) {
      debugPrint('✅ verifySignedOutState: popup/login UI detected');
      return true;
    }

    final user = FirebaseAuth.instance.currentUser;
    final signOutButton = find.byKey(const Key('profile_sign_out_button'));
    if (user == null && signOutButton.evaluate().isEmpty) {
      debugPrint('✅ verifySignedOutState: FirebaseAuth currentUser is null');
      return true;
    }

    if (i == 0 || (i + 1) % 16 == 0) {
      debugPrint(
        '⏳ verifySignedOutState: waiting... poll=${i + 1}/$maxPolls '
        '(currentUser=${user != null}, signOutBtn=${signOutButton.evaluate().isNotEmpty})',
      );
    }

    await tester.pump(const Duration(milliseconds: 250));
  }

  // If we still have a settings button, tapping it should trigger the
  // "Sign In Required" popup for signed-out users.
  final settingsButton = find.byKey(const Key('home_settings_button'));
  if (settingsButton.evaluate().isNotEmpty) {
    await tester.tap(settingsButton.first, warnIfMissed: false);
    await pumpWait(tester, seconds: 2);
    if (hasSignInPopupOrLoginForm()) {
      debugPrint('✅ verifySignedOutState: settings tap triggered login UI');
      return true;
    }
  } else {
    debugPrint(
      'ℹ️ verifySignedOutState: home_settings_button not found (may be expected when signed out)',
    );
  }

  final stillSignedIn = FirebaseAuth.instance.currentUser != null;
  final signOutButton = find.byKey(const Key('profile_sign_out_button'));
  if (!stillSignedIn && signOutButton.evaluate().isEmpty) {
    debugPrint(
      '✅ verifySignedOutState: signed-out inferred (no user + no sign-out button)',
    );
    return true;
  }

  if (signOutButton.evaluate().isNotEmpty) {
    debugPrint('❌ verifySignedOutState: still seeing sign out button');
  }
  debugPrint('⚠️ verifySignedOutState: could not confirm signed-out state');
  return false;
}

/// Public wrapper around the internal ensure-visible helper.
/// Use this in flows to avoid flaky taps on widgets that exist but are offscreen.
Future<bool> ensureFinderOnScreen(
  WidgetTester tester,
  Finder finder, {
  int maxAttempts = 16,
}) async {
  return _ensureFinderOnScreen(tester, finder, maxAttempts: maxAttempts);
}

Future<bool> _ensureFinderOnScreen(
  WidgetTester tester,
  Finder finder, {
  int maxAttempts = 16,
}) async {
  debugPrint('📐 _ensureFinderOnScreen: maxAttempts=$maxAttempts');
  if (finder.evaluate().isEmpty) {
    debugPrint('  ❌ Finder is empty');
    return false;
  }

  try {
    debugPrint('  📄 Attempting ensureVisible...');
    await tester.ensureVisible(finder.first);
    await tester.pump(const Duration(milliseconds: 150));
    debugPrint('  ✅ ensureVisible succeeded');
  } catch (e) {
    debugPrint('  ⚠️  ensureVisible failed: $e');
  }

  bool isOnScreen() {
    if (finder.evaluate().isEmpty) return false;
    final center = tester.getCenter(finder.first, warnIfMissed: false);
    final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    final onScreen =
        center.dx >= 0 &&
        center.dy >= 0 &&
        center.dx <= logicalSize.width &&
        center.dy <= logicalSize.height;
    debugPrint(
      '    isOnScreen: center=$center, size=$logicalSize, result=$onScreen',
    );
    return onScreen;
  }

  if (isOnScreen()) {
    debugPrint('✅ _ensureFinderOnScreen: widget already on screen');
    return true;
  }

  debugPrint('  🔍 Looking for scrollable...');
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) {
    debugPrint('  ❌ No scrollable found');
    return false;
  }
  debugPrint('  ✅ Scrollable found, starting scroll attempts...');

  for (var i = 0; i < maxAttempts; i++) {
    final direction = i < (maxAttempts ~/ 2) ? -280.0 : 280.0;
    debugPrint('  [${i + 1}/$maxAttempts] Dragging direction=$direction');
    await tester.drag(scrollable.first, Offset(0, direction));
    await tester.pump(const Duration(milliseconds: 220));
    if (finder.evaluate().isNotEmpty) {
      try {
        await tester.ensureVisible(finder.first);
        await tester.pump(const Duration(milliseconds: 120));
      } catch (_) {}
    }
    if (isOnScreen()) {
      debugPrint(
        '✅✅ _ensureFinderOnScreen SUCCESS: widget on screen after ${i + 1} attempts',
      );
      return true;
    }
  }

  debugPrint(
    '❌ _ensureFinderOnScreen FAILED: widget not on screen after $maxAttempts attempts',
  );
  return false;
}

/// Tap a widget by Key name. Returns true if found and tapped.
Future<bool> tapByKey(WidgetTester tester, String keyName) async {
  debugPrint('🔘 tapByKey: key="$keyName"');
  final finder = find.byKey(Key(keyName));
  if (finder.evaluate().isNotEmpty) {
    debugPrint('  ✅ Widget found');
    final ready = await _ensureFinderOnScreen(tester, finder);
    if (!ready) {
      debugPrint('  ❌ Widget off-screen');
      fail('tapByKey: widget "$keyName" is present but off-screen');
    }

    // The widget can be visible but temporarily not receiving pointer events
    // (e.g., during animations or under IgnorePointer). Wait briefly for a
    // hit-testable target.
    Finder? hitTarget;
    for (var i = 0; i < 20; i++) {
      final candidate = finder.hitTestable();
      if (candidate.evaluate().isNotEmpty) {
        hitTarget = candidate;
        break;
      }
      await tester.pump(const Duration(milliseconds: 150));
    }

    if (hitTarget == null) {
      debugPrint('  ❌ Widget not hit-testable after waiting');
      fail(
        'tapByKey: widget "$keyName" is visible but not hit-testable (pointer events blocked)',
      );
    }

    debugPrint('  🔘 Tapping...');
    await tester.tap(hitTarget.first, warnIfMissed: false);
    await pumpFor(tester, frames: 5, ms: 100);
    debugPrint('✅ tapByKey SUCCESS');
    return true;
  }
  debugPrint('  ❌ Widget not found');
  return false;
}

/// Enter text into a field found by Key.
Future<void> enterTextByKey(
  WidgetTester tester,
  String key,
  String text,
) async {
  debugPrint(
    '⌨️  enterTextByKey: key="$key", text=${text.substring(0, min(text.length, 20))}...',
  );
  final field = find.byKey(Key(key));
  if (field.evaluate().isNotEmpty) {
    debugPrint('  ✅ Field found');
    final ready = await _ensureFinderOnScreen(tester, field);
    if (!ready) {
      debugPrint('  ❌ Field off-screen/non-hit-testable');
      fail(
        'enterTextByKey: field "$key" is present but off-screen/non-hit-testable',
      );
    }
    debugPrint('  🔘 Tapping field...');
    await tester.tap(field.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    debugPrint('  ⌨️  Entering text...');
    await tester.enterText(field, text);
    await pumpFor(tester, frames: 3, ms: 100);
    debugPrint('✅ enterTextByKey SUCCESS');
  } else {
    debugPrint('  ❌ Field not found');
  }
}

/// Go back to previous screen (tries multiple back button variants).
Future<void> goBack(WidgetTester tester) async {
  for (final icon in [Icons.arrow_back, Icons.arrow_back_rounded]) {
    final btn = find.byIcon(icon);
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn.first, warnIfMissed: false);
      await pumpWait(tester);
      return;
    }
  }
  final materialBackButton = find.byType(BackButton);
  if (materialBackButton.evaluate().isNotEmpty) {
    await tester.tap(materialBackButton.first, warnIfMissed: false);
    await pumpWait(tester);
    return;
  }

  final closeButton = find.byType(CloseButton);
  if (closeButton.evaluate().isNotEmpty) {
    await tester.tap(closeButton.first, warnIfMissed: false);
    await pumpWait(tester);
    return;
  }

  for (final k in [
    'addproduct_back_button',
    'back_button',
    'profile_back_button',
  ]) {
    final btn = find.byKey(Key(k));
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn.first, warnIfMissed: false);
      await pumpWait(tester);
      return;
    }
  }

  try {
    await tester.pageBack();
    await pumpWait(tester, seconds: 2);
    return;
  } catch (_) {}

  debugPrint('⚠ No back button found');
}

/// Scroll until [finder] is visible in the first Scrollable.
Future<void> scrollUntilVisible(
  WidgetTester tester,
  Finder finder, {
  double delta = -300,
  int maxScrolls = 20,
}) async {
  final scrollables = find.byType(Scrollable).evaluate().toList();
  if (scrollables.isEmpty) return;

  Finder? activeScrollable;
  for (final element in scrollables) {
    final candidate = find.byElementPredicate((e) => e == element);
    final onScreen = await _ensureFinderOnScreen(
      tester,
      candidate,
      maxAttempts: 1,
    );
    if (onScreen) {
      activeScrollable = candidate;
      break;
    }
  }

  activeScrollable ??= find.byElementPredicate((e) => e == scrollables.first);

  if (finder.evaluate().isNotEmpty) {
    final ready = await _ensureFinderOnScreen(tester, finder, maxAttempts: 6);
    if (ready) return;
  }

  for (var i = 0; i < maxScrolls; i++) {
    if (finder.evaluate().isNotEmpty) {
      final ready = await _ensureFinderOnScreen(tester, finder, maxAttempts: 3);
      if (ready) return;
    }
    await tester.drag(
      activeScrollable.first,
      Offset(0, delta),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  if (finder.evaluate().isNotEmpty) {
    final ready = await _ensureFinderOnScreen(tester, finder, maxAttempts: 12);
    if (!ready) {
      fail(
        'scrollUntilVisible: target is present but still off-screen/non-hit-testable',
      );
    }
  }
}

/// Navigate to profile sub-screen, verify loaded, go back.
Future<void> checkProfileSubPage(
  WidgetTester tester,
  String buttonKey,
  String label,
) async {
  if (buttonKey == 'profile_terms_button' || buttonKey.contains('terms')) {
    debugPrint(
      '$label SKIP: External terms/policy page intentionally not tapped in E2E',
    );
    return;
  }

  final btn = find.byKey(Key(buttonKey));
  if (btn.evaluate().isEmpty) {
    debugPrint('$label SKIP: Button not found');
    return;
  }
  await scrollUntilVisible(tester, btn, delta: -220, maxScrolls: 12);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(btn.first, warnIfMissed: false);
  await pumpWait(tester, seconds: 2);
  expect(find.byType(Scaffold), findsWidgets);
  debugPrint('$label ✓ Screen loaded');
  await goBack(tester);
  await pumpWait(tester);

  final profileAnchor = find.byKey(const Key('profile_my_orders_button'));
  final homeSettings = find.byKey(const Key('home_settings_button'));
  if (profileAnchor.evaluate().isEmpty && homeSettings.evaluate().isEmpty) {
    try {
      await tester.pageBack();
      await pumpWait(tester, seconds: 2);
    } catch (_) {}
  }
}

Future<bool> handleSignInPopup(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  debugPrint('🔍 handleSignInPopup: checking for dialog...');
  debugPrint('  Looking for key: login_dialog_sign_in_button');
  final dialogKey = find.byKey(const Key('login_dialog_sign_in_button'));
  debugPrint('  Dialog button found: ${dialogKey.evaluate().isNotEmpty}');

  if (dialogKey.evaluate().isEmpty) {
    debugPrint('  ❌ No popup found');
    debugPrint('  DEBUG: Listing all visible Text widgets...');
    final allTexts = find.byType(Text);
    final textCount = allTexts.evaluate().length;
    debugPrint('    Total Text widgets: $textCount');
    if (textCount > 0 && textCount < 50) {
      // Only show if reasonable number
      for (var i = 0; i < min(10, textCount); i++) {
        final widget = tester.widget<Text>(allTexts.at(i));
        final data = widget.data?.toString() ?? '';
        if (data.length < 100) {
          debugPrint(
            '      Text[$i]: ${data.substring(0, min(50, data.length))}',
          );
        }
      }
    }
    return false;
  }
  debugPrint('  ✅ Popup detected');
  debugPrint('ℹ️ Sign In Required popup detected — navigating to login...');
  debugPrint('  🔘 Tapping Sign In button in dialog...');
  debugPrint('    Dialog button widget count: ${dialogKey.evaluate().length}');
  debugPrint(
    '    Attempting to tap dialogKey.first with warnIfMissed=false...',
  );

  // Wait longer for dialog to be fully rendered and clickable
  debugPrint('    Waiting for dialog to stabilize...');
  await pumpWait(tester, seconds: 2);

  debugPrint('    Executing tap...');
  await tester.tap(dialogKey.first, warnIfMissed: false);
  debugPrint('  ✅ Tap completed');
  debugPrint('  ⏳ Waiting 3s after dialog dismiss...');
  await pumpWait(tester, seconds: 3);
  debugPrint('  📝 Calling loginWith...');
  final ok = await loginWith(tester, email: email, password: password);
  debugPrint('  ⏳ Waiting 2s after login...');
  await pumpWait(tester, seconds: 2);
  if (ok) {
    debugPrint('✅ handleSignInPopup COMPLETE — Login completed after popup');
    return true;
  }
  debugPrint('❌ handleSignInPopup: login failed after popup');
  return false;
}

Future<bool> navigateToAddProduct(WidgetTester tester) async {
  final addBtn = find.byKey(const Key('home_add_product_button'));

  // Retry loop to absorb auth/profile provider timing on web integration runs
  for (int attempt = 0; attempt < 4; attempt++) {
    if (addBtn.evaluate().isNotEmpty) break;
    await navigateToTab(tester, Icons.home);
    await pumpWait(tester, seconds: 2);
    await pumpSettle(tester, iterations: 4);
  }

  if (addBtn.evaluate().isEmpty) {
    debugPrint(
      '⚠ Add Product button not found after retries — user may not have seller/admin role or profile not loaded',
    );
    return false;
  }

  final ready = await _ensureFinderOnScreen(tester, addBtn);
  if (!ready) {
    fail(
      'navigateToAddProduct: add product button is present but off-screen/non-hit-testable',
    );
  }
  await tester.tap(addBtn.first, warnIfMissed: false);
  await pumpSettle(tester, iterations: 5);
  debugPrint('✓ Navigated to Add Product screen');
  return true;
}

Future<void> pumpSettle(
  WidgetTester tester, {
  int iterations = 3,
  int ms = 1000,
}) async {
  for (int i = 0; i < iterations; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

// ─── TEST INITIALIZATION HELPERS ─────────────────────────────────────────────

/// Initialize integration test with standard setup.
Future<CaseTracker> initializeIntegrationTest(
  WidgetTester tester, {
  bool strictIntegration = true,
}) async {
  _assertDevIntegrationConfig();
  await ensureAppStarted(tester);
  return CaseTracker(strictIntegration: strictIntegration);
}

/// Establish user session with credential recovery and home verification.
Future<Credential?> establishSession(
  WidgetTester tester,
  List<Credential> candidates,
  String scope,
  CaseTracker tracker,
  String skipCode,
  String skipMessage,
) async {
  final credential = await switchCredentialWithRecovery(
    tester,
    candidates,
    scope,
  );
  if (credential == null) {
    tracker.stopOnSkip(skipCode, skipMessage);
    tracker.throwIfFailed();
    return null;
  }
  await ensureHomeReady(tester, timeoutSeconds: 2);
  await ensureDevSeedData(tester, signedInCredential: credential);
  return credential;
}

/// Open settings panel from home.
Future<bool> openSettings(WidgetTester tester) async {
  final settingsButton = find.byKey(const Key('home_settings_button'));
  if (settingsButton.evaluate().isEmpty) return false;

  await tester.tap(settingsButton.first, warnIfMissed: false);

  await pumpWait(tester, seconds: 3);
  return true;
}

// ─── PRODUCT TEST HELPERS ────────────────────────────────────────────────────

/// Publish product and verify success with tracker.
Future<bool> publishAndVerify(
  WidgetTester tester,
  CaseTracker tracker,
  String testId,
  String checkCode,
  String skipCode,
) async {
  await tapPublishProduct(tester);
  final hasSuccess = await didPublishSucceed(tester);
  tracker.check(checkCode, hasSuccess, '$testId publication reussie');
  if (!hasSuccess) {
    tracker.stopOnSkip(
      skipCode,
      '$testId publish failed (validation/images/backend)',
    );
  }
  return hasSuccess;
}

/// Clean up after product publish and verify in marketplace.
Future<bool> cleanupAndVerifyProduct(
  WidgetTester tester,
  String productName,
  CaseTracker tracker,
  String checkCode,
  String testId,
) async {
  if (find.byKey(const Key('addproduct_screen_title')).evaluate().isNotEmpty) {
    await goBack(tester);
    await pumpSettle(tester, iterations: 3);
  }
  await pumpSettle(tester, iterations: 3);
  final exist = await verifyProductInMarketplace(tester, productName);
  tracker.check(checkCode, exist, '$testId trouve dans marketplace');
  return exist;
}

Future<void> fillBasicProductFields(
  WidgetTester tester, {
  required String name,
  required String price,
  String description = 'Integration test product',
  String stock = '10',
  String categoryItemKey = 'category_item_categories.electronics',
}) async {
  await enterTextByKey(tester, 'product_name_field', name);
  await enterTextByKey(tester, 'product_description_field', description);
  await enterTextByKey(tester, 'product_price_field', price);
  await enterTextByKey(tester, 'product_stock_field', stock);

  final categorySelector = find.byKey(
    const Key('addproduct_category_selector'),
  );
  if (categorySelector.evaluate().isNotEmpty) {
    final categoryReady = await _ensureFinderOnScreen(
      tester,
      categorySelector,
      maxAttempts: 14,
    );
    if (!categoryReady) {
      fail(
        'fillBasicProductFields: category selector is present but off-screen/non-hit-testable',
      );
    }

    await tester.tap(categorySelector.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));

    final categoryItem = find.byKey(Key(categoryItemKey));
    if (categoryItem.evaluate().isNotEmpty) {
      await tester.tap(categoryItem.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      final fallbackOption = find.textContaining('Elect');
      if (fallbackOption.evaluate().isNotEmpty) {
        await tester.tap(fallbackOption.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));
      } else {
        fail(
          'fillBasicProductFields: no selectable category option found in dropdown',
        );
      }
    }
  } else {
    fail('fillBasicProductFields: addproduct_category_selector not found');
  }

  debugPrint('✓ Filled basic fields: $name / \$$price / stock=$stock');
}

Future<void> tapGlassToggle(WidgetTester tester, String identifier) async {
  final keyFinder = find.byKey(Key(identifier));
  expect(keyFinder, findsWidgets, reason: 'Toggle Key "$identifier" not found');
  final ready = await _ensureFinderOnScreen(tester, keyFinder);
  if (!ready) {
    fail(
      'tapGlassToggle: toggle "$identifier" is present but off-screen/non-hit-testable',
    );
  }
  await tester.tap(keyFinder.first);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> fillAddress(
  WidgetTester tester, {
  bool requireGeoapify = true,
}) async {
  // Scroll down to make address fields visible
  await scrollUntilVisible(
    tester,
    find.byKey(const Key('addproduct_section_package')),
  );
  await tester.pump(const Duration(milliseconds: 500));

  // Type a PARTIAL real address so Geoapify autocomplete returns quickly.
  // (Avoid full manual address filling; prefer tapping a real suggestion.)
  await enterTextByKey(tester, 'addproduct_street_field', '350 King');

  final suggestionsContainer = find.byKey(
    const Key('addproduct_address_suggestions'),
  );

  // Wait up to ~10s for Geoapify suggestions to render.
  var suggestionSelected = false;
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 400));

    if (suggestionsContainer.evaluate().isEmpty) {
      continue;
    }

    final tiles = find.descendant(
      of: suggestionsContainer,
      matching: find.byType(ListTile),
    );

    if (tiles.evaluate().isEmpty) {
      continue;
    }

    final ready = await _ensureFinderOnScreen(
      tester,
      tiles,
      maxAttempts: 8,
    );
    if (!ready) {
      continue;
    }

    await tester.tap(tiles.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 800));
    suggestionSelected = true;
    debugPrint('✓ fillAddress: selected first Geoapify suggestion');
    break;
  }

  if (suggestionSelected) {
    debugPrint('✓ Filled address fields via Geoapify suggestion');
    return;
  }

  if (requireGeoapify) {
    fail(
      'fillAddress: Geoapify suggestions did not appear / were not tappable. '
      'Check geoapifyKey, network, or suggestion UI rendering.',
    );
  }

  // Manual fallback when suggestions are unavailable (kept for local debugging).
  debugPrint('⚠ fillAddress: no Geoapify suggestions, using manual fallback');
  await enterTextByKey(tester, 'addproduct_city_field', 'Toronto');

  final provinceDropdown = find.byKey(
    const Key('addproduct_province_dropdown'),
  );
  if (provinceDropdown.evaluate().isNotEmpty) {
    final provinceReady = await _ensureFinderOnScreen(
      tester,
      provinceDropdown,
      maxAttempts: 14,
    );
    if (!provinceReady) {
      fail(
        'fillAddress: province dropdown is present but off-screen/non-hit-testable',
      );
    }

    await tester.tap(provinceDropdown.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));

    final ontarioOption = find.text('ON');
    if (ontarioOption.evaluate().isNotEmpty) {
      await tester.tap(ontarioOption.last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
    }
  } else {
    fail('fillAddress: addproduct_province_dropdown not found');
  }

  await enterTextByKey(tester, 'addproduct_postal_code_field', 'M5V 3L9');
  debugPrint('✓ Filled address fields via manual fallback');
}

/// Attempt to submit the product form.
Future<String?> tapPublishProduct(WidgetTester tester) async {
  final submitBtn = find.byKey(const Key('addproduct_submit_button'));
  final ready = await _ensureFinderOnScreen(tester, submitBtn, maxAttempts: 20);
  if (!ready) {
    fail(
      'tapPublishProduct: submit button is present but off-screen/non-hit-testable',
    );
  }

  final currentUser = FirebaseAuth.instance.currentUser;
  debugPrint(
    'ℹ️ Publish auth context: uid=${currentUser?.uid} email=${currentUser?.email}',
  );

  // DEBUG: Dump all TextFormField error states before publish
  debugPrint('🔍 PRE-PUBLISH: scanning TextFormField values...');
  final allFields = find.byType(TextFormField);
  for (var idx = 0; idx < allFields.evaluate().length; idx++) {
    final element = allFields.evaluate().elementAt(idx);
    final w = element.widget;
    final keyStr = w.key?.toString() ?? 'no-key';
    if (w is TextFormField) {
      final controller = (w as dynamic).controller as TextEditingController?;
      final text = controller?.text ?? '(no ctrl)';
      debugPrint('  📝 field[$idx] key=$keyStr text="${text.substring(0, text.length > 40 ? 40 : text.length)}"');
    }
  }
  // Also check DropdownButtonFormField state
  final allDropdowns = find.byType(DropdownButtonFormField<String>);
  for (var idx = 0; idx < allDropdowns.evaluate().length; idx++) {
    final element = allDropdowns.evaluate().elementAt(idx);
    final keyStr = element.widget.key?.toString() ?? 'no-key';
    debugPrint('  🔽 dropdown[$idx] key=$keyStr');
  }

  await tester.tap(submitBtn.first);

  String? latestSnack;
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 500));

    // DEBUG: After first pump, check for field-level error decorations
    if (i == 1) {
      debugPrint('🔍 POST-SUBMIT: scanning for validation errors...');
      final errorTexts = find.byType(Text);
      for (var idx = 0; idx < errorTexts.evaluate().length; idx++) {
        final w = tester.widget<Text>(errorTexts.at(idx));
        final t = w.data ?? w.textSpan?.toPlainText() ?? '';
        if (t.contains('required') || t.contains('Required') ||
            t.contains('requis') || t.contains('invalid') ||
            t.contains('too_short') || t.contains('trop court') ||
            t.contains('Veuillez') || t.contains('erreur') ||
            t.contains('error') || t.contains('Obligatoire')) {
          debugPrint('  ❌ error-text[$idx]: "$t"');
        }
      }
    }

    final errorSnackText = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Text),
    );
    if (errorSnackText.evaluate().isNotEmpty) {
      final textWidget = tester.widget<Text>(errorSnackText.first);
      latestSnack =
          textWidget.data ??
          textWidget.textSpan?.toPlainText() ??
          'unknown error';
    }

    final hasSuccessSnack = find
        .byKey(const Key('addproduct_success_snackbar'))
        .evaluate()
        .isNotEmpty;
    final leftAddProductScreen = find
        .byKey(const Key('addproduct_screen_title'))
        .evaluate()
        .isEmpty;

    if (hasSuccessSnack || leftAddProductScreen) {
      break;
    }
  }

  if (latestSnack != null && latestSnack.trim().isNotEmpty) {
    debugPrint('⚠ Publish snackbar: $latestSnack');
  }

  return latestSnack;
}

Future<bool> didPublishSucceed(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    final hasSuccessSnack = find
        .byKey(const Key('addproduct_success_snackbar'))
        .evaluate()
        .isNotEmpty;
    final hasLeftAddProductScreen = find
        .byKey(const Key('addproduct_screen_title'))
        .evaluate()
        .isEmpty;
    if (hasSuccessSnack || hasLeftAddProductScreen) {
      return true;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  return false;
}

List<double> extractDollarAmounts(Finder finder) {
  final amounts = <double>[];
  final dollarRegex = RegExp(r'\$\s*([0-9]+(?:\.[0-9]{1,2})?)');

  for (final element in finder.evaluate()) {
    final widget = element.widget;
    if (widget is! Text) continue;

    final content = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    for (final match in dollarRegex.allMatches(content)) {
      final raw = match.group(1);
      final value = raw == null ? null : double.tryParse(raw);
      if (value != null) {
        amounts.add(value);
      }
    }
  }

  return amounts;
}

/// Verify product appears in marketplace
Future<bool> verifyProductInMarketplace(
  WidgetTester tester,
  String productName,
) async {
  debugPrint('🔍 Verifying product in marketplace: $productName');

  // Navigate to home/browse
  await navigateToTab(tester, Icons.home);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }

  // Search for product
  final searchIcon = find.byIcon(Icons.search);
  if (searchIcon.evaluate().isNotEmpty) {
    await tester.tap(searchIcon.first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final searchField = find.byType(TextField);
    if (searchField.evaluate().isNotEmpty) {
      await tester.enterText(searchField.first, productName);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }
  }
  // Check if product appears
  final productFound = find.textContaining(productName);

  if (productFound.evaluate().isNotEmpty) {
    debugPrint('✓ Product found in marketplace');
    return true;
  }
  return false;
}
