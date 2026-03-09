// File: lib/config/firebase_config_dev.dart
import 'package:firebase_core/firebase_core.dart';

/// Documentation for FirebaseConfigDev
class FirebaseConfigDev {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REDACTED_SECRET',
    appId: '1:245187519087:web:06bfb8f90b4ad7e4fee39a',
    messagingSenderId: '245187519087',
    projectId: 'orignagta-dev',
    authDomain: 'orignagta-dev.firebaseapp.com',
    storageBucket: 'orignagta-dev.firebasestorage.app',
  );

  // For now, we only have web config for dev. 
  // If you add Android/iOS for dev, allow them here.
  static FirebaseOptions get currentPlatform {
    return web;
  }
}
