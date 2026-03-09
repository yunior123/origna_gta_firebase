import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:origna_gta/config/firebase_config_dev.dart';
import 'package:origna_gta/config/firebase_config_prod.dart';
import 'package:origna_gta/config/firebase_config_staging.dart';
import 'package:origna_gta/origna_app.dart';
import 'package:origna_gta/services/conf_services.dart';
import 'package:origna_gta/services/notification_service.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Keep the semantics handle alive so it doesn't get GC'd in release mode.
/// Without this, ensureSemantics() has no lasting effect.
SemanticsHandle? _semanticsHandle;

void main() {
  // Use path URL strategy (no # in URLs) for cleaner web URLs
  usePathUrlStrategy();

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize easy_localization — required before runApp
      // Supports EN (default) + FR (Quebec Bill 96 / Loi 96 compliance)
      // FLUTTER-Y: Safari may throw on localStorage access (private browsing).
      // Fall through gracefully — EasyLocalization will use in-memory fallback.
      try {
        await EasyLocalization.ensureInitialized();
      } catch (e, st) {
        debugPrint('⚠️ EasyLocalization init failed (non-fatal): $e');
        if (!kDebugMode) await Sentry.captureException(e, stackTrace: st);
      }

      // Force semantic tree on web for accessibility + E2E Playwright testing.
      // Flutter Web renders to <canvas> — this generates a parallel <flt-semantics>
      // DOM tree with ARIA attributes that Playwright can target.
      // IMPORTANT: Store the handle — if it's GC'd, semantics gets disabled.
      // debug always on, profile only if FORCE_SEMANTICS=true, release never
      if (kIsWeb && (kDebugMode || const bool.fromEnvironment('FORCE_SEMANTICS'))) {
        _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
        if (kDebugMode) {
          debugPrint('♿ Semantics enabled: ${_semanticsHandle != null}');
        }
      }

      FirebaseOptions firebaseOptions;

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

      // F-284: Phase 1 Parallel Initialization (Keep launch time < 2s)
      await Firebase.initializeApp(options: firebaseOptions);

      // EMULATOR CONFIGURATION
      if (envConfig.shouldUseEmulators) {
        try {
          await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
          FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
          FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
          await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
        } catch (e) {
          // BOOT-C1: Never silently fall back to dev Firebase when emulators are
          // unavailable — this would cause data contamination in dev.
          throw Exception(
            'EMULATOR mode is enabled but emulators are unavailable: $e\n'
            'Start emulators with `firebase emulators:start` before running the app.',
          );
        }
      }

      // App Check — attestation layer protecting Cloud Functions from abuse.
      // Web: reCAPTCHA Enterprise (SCORE type) with site key injected at build time.
      //   Staging key: RECAPTCHA_SITE_KEY_STAGING (orignagta-staging project)
      //   Prod key:    RECAPTCHA_SITE_KEY_PROD    (orignagta project)
      //   Dev: uses Google test key (always passes) + UNENFORCED mode — never blocks E2E.
      // Mobile: DeviceCheck (iOS/macOS) + Play Integrity (Android).
      const recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY', defaultValue: '');
      try {
        await FirebaseAppCheck.instance.activate(
          providerWeb: recaptchaSiteKey.isNotEmpty
              ? ReCaptchaEnterpriseProvider(recaptchaSiteKey)
              : ReCaptchaV3Provider('6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI'), // Google test key (dev only)
          providerAndroid: const AndroidPlayIntegrityProvider(),
          providerApple: const AppleDeviceCheckProvider(),
        );
      } catch (e) {
        // App Check failures must never crash the app — attestation is a soft guard.
        // The server enforces tokens for staging/prod; dev is monitoring-only.
        debugPrint('⚠️ App Check activation failed (non-fatal): $e');
      }

      // F-284: Phase 2 Parallel Initialization
      await Future.wait([
        ConfigService().initialize(),
        if (kIsWeb)
          FirebaseAuth.instance.setPersistence(Persistence.LOCAL)
        else
          Future.value(null),
      ]);

      // F-285: Enable Firestore web persistence (survive refreshes)
      if (kIsWeb) {
        try {
          FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
        } catch (e) {
          debugPrint('⚠️ Firestore persistence error: $e');
        }
      }

      // Register FCM background handler before runApp — FCM requires this to be
      // called at app startup before any other Firebase Messaging calls.
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }

      await SentryFlutter.init((options) {
        options.dsn = ConfigService().sentryDnsKey;
        // Use env_config for environment naming (dev/staging must not be labeled 'emulator')
        options.environment = envConfig.isProduction
            ? 'production'
            : envConfig.isStaging
                ? 'staging'
                : envConfig.isDev
                    ? 'dev'
                    : 'emulator';
        options.tracesSampleRate = 0.1; // 10% of transactions
        options.beforeSend = (event, hint) {
          // Filter sensitive data - strip emails before sending
          if (event.user != null) {
            final user = event.user!;
            event.user = SentryUser(
              id: user.id,
              username: user.username,
              ipAddress: null, // F-286: IP is PII under PIPEDA — never forward to Sentry
              data: user.data,
            );
          }
          return event;
        };
        // On web, disable frame tracking & auto performance
        if (kIsWeb) {
          options.enableAutoPerformanceTracing = false;
          options.enableFramesTracking = false;
          options.enableAutoSessionTracking = false;
        } else {
          // Mobile: 100% only in production; 10% in dev/staging to avoid noise + quota burn
          options.tracesSampleRate = envConfig.isProduction ? 1.0 : 0.1;
        }
      });

      // Set global Flutter error handler
      FlutterError.onError = (FlutterErrorDetails details) {
        final message = details.exceptionAsString();
        // Ignore the disposed Web engine view error
        if (kIsWeb && message.contains('disposed EngineFlutterView')) {
          return;
        }
        // Log to Sentry
        Sentry.captureException(details.exception, stackTrace: details.stack);
        // Let Flutter still show errors in debug
        FlutterError.presentError(details);
      };

      runApp(
        EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('fr')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          child: const ProviderScope(child: OrignaApp()),
        ),
      );
    },
    (exception, stackTrace) async {
      // Capture unhandled errors to Sentry
      await Sentry.captureException(exception, stackTrace: stackTrace);
    },
  );
}
