// File: lib/config/firebase_config_prod.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Documentation for FirebaseConfigProd
class FirebaseConfigProd {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REDACTED_SECRET',
    appId: '1:935641055788:web:69354d01c1d91222cac789',
    messagingSenderId: '935641055788',
    projectId: 'orignagta',
    authDomain: 'orignagta.firebaseapp.com',
    storageBucket: 'orignagta.firebasestorage.app',
    measurementId: 'G-T96JD739QL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REDACTED_SECRET',
    appId: '1:935641055788:android:49fee17104670746cac789',
    messagingSenderId: '935641055788',
    projectId: 'orignagta',
    storageBucket: 'orignagta.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REDACTED_SECRET',
    appId: '1:935641055788:ios:44dad9d69f7659adcac789',
    messagingSenderId: '935641055788',
    projectId: 'orignagta',
    storageBucket: 'orignagta.firebasestorage.app',
    iosBundleId: 'ca.orignagta.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REDACTED_SECRET',
    appId: '1:935641055788:ios:44dad9d69f7659adcac789',
    messagingSenderId: '935641055788',
    projectId: 'orignagta',
    storageBucket: 'orignagta.firebasestorage.app',
    iosBundleId: 'ca.orignagta.app',
  );
  
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'FirebaseConfigProd have not been configured for windows',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseConfigProd have not been configured for linux',
        );
      default:
        throw UnsupportedError(
          'FirebaseConfigProd are not supported for this platform.',
        );
    }
  }
}
