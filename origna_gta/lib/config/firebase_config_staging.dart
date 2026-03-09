// File: lib/config/firebase_config_staging.dart
import 'package:firebase_core/firebase_core.dart';

/// Documentation for FirebaseConfigStaging
class FirebaseConfigStaging {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REDACTED_SECRET',
    appId: '1:440582189942:web:3aa177f875ee0e26ba4057',
    messagingSenderId: '440582189942',
    projectId: 'orignagta-staging',
    authDomain: 'orignagta-staging.firebaseapp.com',
    storageBucket: 'orignagta-staging.firebasestorage.app',
  );

  // For now, we only have web config for staging.
  static FirebaseOptions get currentPlatform {
    return web;
  }
}
