/// Common utilities for Patrol tests in OrignaGTA.
///
/// Usage:
/// ```dart
/// import 'common.dart';
///
/// void main() {
///   patrol('my test', ($) async {
///     await createApp($);
///     // ...
///   });
/// }
/// ```
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:meta/meta.dart';
import 'package:origna_gta/firebase_options.dart';
import 'package:origna_gta/origna_app.dart';
import 'package:origna_gta/services/conf_services.dart';
import 'package:patrol/patrol.dart';

export 'package:flutter_test/flutter_test.dart';
export 'package:patrol/patrol.dart';

// ──────────────────────────────────────────────────────────────────
// Configuration
// ──────────────────────────────────────────────────────────────────

/// Emulator host: use 'localhost' for simulator, Mac's LAN IP for physical device.
const kEmulatorHost = 'localhost';

/// Admin account seeded in Firebase emulator.
const kTestAdminEmail = 'yr62813@gmail.com';

const kTestAdminPassword = 'REDACTED_TEST_PASSWORD';

// ──────────────────────────────────────────────────────────────────
// App bootstrap (one-time Firebase init + emulators)
// ──────────────────────────────────────────────────────────────────

/// Second buyer for multi-user scenarios.
const kTestBuyer2Email = 'buyer2@test.origna.ca';

// ──────────────────────────────────────────────────────────────────
// Test helper – short alias for patrolTest with project defaults
// ──────────────────────────────────────────────────────────────────

const kTestBuyer2Password = 'REDACTED_TEST_PASSWORD';

// ──────────────────────────────────────────────────────────────────
// Test data constants
// ──────────────────────────────────────────────────────────────────

/// Buyer account seeded in Firebase emulator.
const kTestBuyerEmail = 'yuniorrodriguezo460@gmail.com';
const kTestBuyerPassword = 'REDACTED_TEST_PASSWORD2026';

/// Combo account (buyer+seller) seeded in Firebase emulator.
const kTestComboEmail = 'combo1@test.origna.ca';
const kTestComboPassword = 'REDACTED_TEST_PASSWORD';

/// No-address account for address validation tests.
const kTestNoAddressEmail = 'no-address@test.origna.ca';
const kTestNoAddressPassword = 'REDACTED_TEST_PASSWORD';

/// Seller account (seller1 — Mode Montréal) seeded in Firebase emulator.
const kTestSellerEmail = 'seller1@test.origna.ca';
const kTestSellerPassword = 'REDACTED_TEST_PASSWORD';

/// Suspended account for negative tests.
const kTestSuspendedEmail = 'suspended@test.origna.ca';
const kTestSuspendedPassword = 'REDACTED_TEST_PASSWORD';

/// Flag to avoid double-initialising Firebase across tests.
bool _firebaseInitialised = false;
final _patrolTesterConfig = PatrolTesterConfig(printLogs: true);

/// Initialise Firebase and pump the OrignaGTA app.
///
/// Call this at the beginning of every `patrol()` callback.
/// Firebase is only initialised on the first invocation; subsequent
/// calls just pump the widget.
Future<void> createApp(PatrolIntegrationTester $) async {
  if (!_firebaseInitialised) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Connect to Firebase emulators for testing
    try {
      await FirebaseAuth.instance.useAuthEmulator(kEmulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(kEmulatorHost, 8080);
      FirebaseFunctions.instance.useFunctionsEmulator(kEmulatorHost, 5001);
      await FirebaseStorage.instance.useStorageEmulator(kEmulatorHost, 9199);
      debugPrint('✓ Patrol: connected to Firebase Emulators');
    } catch (e) {
      debugPrint('Patrol: emulator connection: $e');
    }

    await ConfigService().initialize(skipFetch: true);
    _firebaseInitialised = true;
  }

  await $.pumpWidgetAndSettle(const ProviderScope(child: OrignaApp()));
}

/// Ensure logged in as admin.
Future<void> ensureLoggedInAsAdmin(PatrolIntegrationTester $) async {
  if ($(const Key('login_submit_button')).exists) {
    await loginAsAdmin($);
  }
}

// ──────────────────────────────────────────────────────────────────
// Reusable interaction helpers
// ──────────────────────────────────────────────────────────────────

/// Ensure the user is logged in. If not on login screen, assume logged in.
Future<void> ensureLoggedInAsBuyer(PatrolIntegrationTester $) async {
  if ($(const Key('login_submit_button')).exists) {
    await loginAsBuyer($);
  }
}

/// Ensure logged in as seller.
Future<void> ensureLoggedInAsSeller(PatrolIntegrationTester $) async {
  if ($(const Key('login_submit_button')).exists) {
    await loginAsSeller($);
  }
}

/// Log in as admin.
Future<void> loginAsAdmin(PatrolIntegrationTester $) async {
  await _loginAs($, kTestAdminEmail, kTestAdminPassword);
}

/// Log in as the test buyer via the login screen.
Future<void> loginAsBuyer(PatrolIntegrationTester $) async {
  await _loginAs($, kTestBuyerEmail, kTestBuyerPassword);
}

/// Log in as combo user (buyer+seller).
Future<void> loginAsCombo(PatrolIntegrationTester $) async {
  await _loginAs($, kTestComboEmail, kTestComboPassword);
}

/// Log in as the test seller (seller1 — Mode Montréal).
Future<void> loginAsSeller(PatrolIntegrationTester $) async {
  await _loginAs($, kTestSellerEmail, kTestSellerPassword);
}

/// Navigate to add product screen (seller/admin only).
Future<void> navigateToAddProduct(PatrolIntegrationTester $) async {
  final addBtn = $(const Key('home_add_product_button'));
  if (addBtn.exists) {
    await addBtn.tap();
  } else {
    final addIcon = $(Icons.add_box_outlined);
    if (addIcon.exists) await addIcon.first.tap();
  }
  await $.pump(const Duration(seconds: 2));
}

/// Navigate to admin panel from profile/settings.
Future<void> navigateToAdminPanel(PatrolIntegrationTester $) async {
  await navigateToProfile($);
  final adminBtn = $('Admin Panel');
  if (adminBtn.exists) {
    await adminBtn.tap();
  } else {
    // Fallback to searching for it
    await scrollToFindText($, 'Admin Panel');
    await $('Admin Panel').tap();
  }
  await $.pump(const Duration(seconds: 2));
}

/// Navigate to a screen from home using the AppBar icon.
Future<void> navigateToCart(PatrolIntegrationTester $) async {
  final cartIcon = $(Icons.shopping_cart_outlined);
  if (cartIcon.exists) {
    await cartIcon.first.tap();
  } else {
    // Fallback to any shopping cart icon
    final altCart = $(Icons.shopping_cart);
    if (altCart.exists) await altCart.first.tap();
  }
  await $.pump(const Duration(seconds: 2));
}

/// Navigate to profile/settings screen.
Future<void> navigateToProfile(PatrolIntegrationTester $) async {
  final settingsIcon = $(Icons.settings_outlined);
  if (settingsIcon.exists) {
    await settingsIcon.first.tap();
    await $.pump(const Duration(seconds: 2));
  }
}

/// Convenience wrapper around [patrolTest] with OrignaGTA defaults.
@isTest
void patrol(String description, Future<void> Function(PatrolIntegrationTester) callback, {bool? skip, List<String> tags = const []}) {
  patrolTest(description, config: _patrolTesterConfig, skip: skip, callback, tags: tags);
}

/// Scroll down within a scrollable to find a widget with given text.
Future<bool> scrollToFindText(PatrolIntegrationTester $, String text, {int maxScrolls = 10}) async {
  for (var i = 0; i < maxScrolls; i++) {
    if ($(text).exists) return true;
    await $.pump(const Duration(milliseconds: 500));
  }
  return $(text).exists;
}

/// Sign out the current user via Profile screen.
Future<void> signOut(PatrolIntegrationTester $) async {
  // Navigate to profile
  final settingsIcon = $(Icons.settings_outlined);
  if (settingsIcon.exists) {
    await settingsIcon.first.tap();
    await $.pump(const Duration(seconds: 2));
  }

  // Scroll down to find sign out and tap
  final signOutBtn = $(Icons.logout);
  if (signOutBtn.exists) {
    await signOutBtn.first.tap();
    await $.pump(const Duration(seconds: 3));
  }
}

/// Tap the first product card on the home screen.
Future<void> tapFirstProduct(PatrolIntegrationTester $) async {
  final cards = $(Card);
  if (cards.exists) {
    await cards.first.tap();
    await $.pump(const Duration(seconds: 2));
  }
}

/// Wait for a widget with a Key to appear.
Future<bool> waitForKey(PatrolIntegrationTester $, String keyValue, {Duration timeout = const Duration(seconds: 10)}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if ($(Key(keyValue)).exists) return true;
    await $.pump(const Duration(milliseconds: 500));
  }
  return false;
}

/// Wait for text to appear (with timeout).
Future<bool> waitForText(PatrolIntegrationTester $, String text, {Duration timeout = const Duration(seconds: 10)}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if ($(text).exists) return true;
    await $.pump(const Duration(milliseconds: 500));
  }
  return false;
}

/// Log in with a given email/password via the login screen.
Future<void> _loginAs(PatrolIntegrationTester $, String email, String password) async {
  final emailField = $(#login_email_field);
  if (emailField.exists) {
    await emailField.enterText(email);
  } else {
    await $(const Key('login_email_field')).enterText(email);
  }

  final passwordField = $(#login_password_field);
  if (passwordField.exists) {
    await passwordField.enterText(password);
  } else {
    await $(const Key('login_password_field')).enterText(password);
  }

  await $(const Key('login_submit_button')).tap();
  await $.pump(const Duration(seconds: 5));
}
