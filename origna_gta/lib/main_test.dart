// Test-only main entry point that skips URL strategy configuration
// This file is used exclusively for integration tests to avoid the
// "Cannot set URL strategy a second time" error

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/origna_app.dart';
import 'package:origna_gta/services/conf_services.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:origna_gta/config/firebase_config_dev.dart';
import 'package:origna_gta/config/firebase_config_prod.dart';
import 'package:origna_gta/config/firebase_config_staging.dart';

// Use a conditional import-like check if needed or just avoid dart:io
import 'package:universal_io/io.dart' show Platform;

/// Emulator host: localhost for simulators/web, LAN IP for physical devices.
String get _emulatorHost {
  const host = String.fromEnvironment('EMULATOR_HOST');
  if (host.isNotEmpty) return host;
  
  if (kIsWeb) return 'localhost';
  
  // Only access Platform if not on Web
  if (Platform.isIOS || Platform.isAndroid) return '192.168.2.42';
  return 'localhost';
}

/// Flag to track if app has been initialized
bool _appInitialized = false;

/// Helper: run a future with a timeout, log success or failure.
Future<void> _timedStep(String name, Future<void> Function() action,
    {Duration timeout = const Duration(seconds: 10)}) async {
  debugPrint('▶ $name ...');
  try {
    await action().timeout(timeout);
    debugPrint('▶ $name ✓');
  } on TimeoutException {
    debugPrint('▶ $name TIMED OUT after ${timeout.inSeconds}s — skipping');
  } catch (e) {
    debugPrint('▶ $name ERROR: $e');
  }
}

/// Initialize app for a single test (doesn't re-run if already initialized)
Future<void> initAppForTest() async {
  if (!_appInitialized) {
    WidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();
    // Always use dev project for test helper — never prod
    await Firebase.initializeApp(options: FirebaseConfigDev.currentPlatform);

    // EMULATOR CONFIGURATION
    final host = _emulatorHost;
    try {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      debugPrint('Connected to Firebase Emulators at $host');
    } catch (e) {
      debugPrint('Emulator connection: $e');
    }

    await ConfigService().initialize(skipFetch: true);
    _appInitialized = true;
  }
}

/// Main entry point for tests - skips URL strategy
Future<void> mainTest() async {
  debugPrint('▶ mainTest() called (initialized=$_appInitialized)');

  const isTest = bool.fromEnvironment('IS_TEST', defaultValue: false);
  const env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
  if (isTest && env != 'dev') {
    throw StateError(
      'Integration tests must run against DEV Firebase only. '
      'Re-run with --dart-define=ENVIRONMENT=dev (current ENVIRONMENT=$env).',
    );
  }

  if (_appInitialized) {
    debugPrint('▶ Re-running app (already initialized)');
    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('fr')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const ProviderScope(child: OrignaApp()),
      ),
    );
    return;
  }

  debugPrint('▶ Step 1: WidgetsFlutterBinding');
  WidgetsFlutterBinding.ensureInitialized();

  await _timedStep('Step 2: EasyLocalization', () async {
    await EasyLocalization.ensureInitialized();
  });



  await _timedStep('Step 3: Firebase.initializeApp', () async {
      FirebaseOptions firebaseOptions;
      if (isTest) {
        // Integration tests are DEV-only and must never connect to emulators.
        firebaseOptions = FirebaseConfigDev.currentPlatform;
      } else {
        switch (envConfig.environment) {
          case AppEnvironment.dev:
            firebaseOptions = FirebaseConfigDev.currentPlatform;
            break;
          case AppEnvironment.staging:
            firebaseOptions = FirebaseConfigStaging.currentPlatform;
            break;
          case AppEnvironment.production:
            firebaseOptions = FirebaseConfigProd.currentPlatform;
            break;
          case AppEnvironment.emulator:
            firebaseOptions = FirebaseConfigDev.currentPlatform;
            break;
        }
      }
    await Firebase.initializeApp(options: firebaseOptions);
  });

  // EMULATOR CONFIGURATION - Only if requested
  if (!isTest && envConfig.shouldUseEmulators) {
    final host = _emulatorHost;
    await _timedStep('Step 4: Emulator setup at $host', () async {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    });
  } else {
    debugPrint('▶ Step 4: Using Real Services (${envConfig.displayName})');
  }

  await _timedStep('Step 5: ConfigService', () async {
    // Web integration tests rely on Remote Config for keys like geoapify_api_key.
    // Keep skipFetch for non-web to reduce flakiness and speed up local runs.
    await ConfigService().initialize(skipFetch: !kIsWeb);
  });

  // Web + headless Chrome can emit an invalid lifecycle transition (hidden -> resumed)
  // that triggers a Flutter framework assertion inside AppLifecycleListener.
  // Ignore it in web test runs without touching FlutterError.onError (flutter_test is sensitive to that).
  final isTestRun = const bool.fromEnvironment('IS_TEST', defaultValue: false);
  if (kIsWeb && isTestRun) {
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      final message = error.toString();
      if (message.contains(
        'Invalid state transition from AppLifecycleState.hidden to AppLifecycleState.resumed',
      )) {
        // ignore: avoid_print
        print('⚠️ Ignored web lifecycle assertion in test run');
        return true;
      }
      return false;
    };
  }

  _appInitialized = true;

  debugPrint('▶ Step 6: runApp()');
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(child: OrignaApp()),
    ),
  );
  debugPrint('▶ mainTest() complete');
}

/// Reset app state (for test isolation)
void resetAppState() {
  _appInitialized = false;
}
