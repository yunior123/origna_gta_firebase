// coverage:ignore-file
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

/// Documentation for ConfigService
class ConfigService {
  // 1. Create a private static instance
  static final ConfigService _instance = ConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // 2. Factory constructor returns the same instance every time
  factory ConfigService() {
    return _instance;
  }

  // 3. Private named constructor
  ConfigService._internal();

  String get algoliaAppId => _remoteConfig.getString(RemoteConfigKeys.algoliaAppId);

  String get algoliaSearchApiKey => _remoteConfig.getString(RemoteConfigKeys.algoliaSearchApiKey);
  // Getters for your keys
  String get geoapifyKey {
    // Allow integration/dev to override Remote Config via --dart-define.
    // Key name matches RemoteConfigKeys.geoapifyApiKey ('geoapify_api_key').
    final override = const String.fromEnvironment(
      RemoteConfigKeys.geoapifyApiKey,
      defaultValue: '',
    );
    if (override.trim().isNotEmpty) return override.trim();

    return _remoteConfig.getString(RemoteConfigKeys.geoapifyApiKey);
  }

  // Inside ConfigService
  String get imageBaseUrl => _remoteConfig.getString(RemoteConfigKeys.imageBaseUrl);

  String get sentryDnsKey => _remoteConfig.getString(RemoteConfigKeys.sentryDnsKey);
  Future<void> initialize({bool skipFetch = false}) async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: skipFetch ? const Duration(seconds: 1) : const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 12),
      ),
    );

    // Defaults should be safe: no placeholder keys that can hide misconfiguration.
    await _remoteConfig.setDefaults({
      RemoteConfigKeys.geoapifyApiKey: '',
      RemoteConfigKeys.imageBaseUrl: '',
      RemoteConfigKeys.sentryDnsKey: '',
      RemoteConfigKeys.algoliaAppId: '',
      RemoteConfigKeys.algoliaSearchApiKey: '',
    });

    if (skipFetch) {
      return;
    }

    try {
      await _remoteConfig.fetchAndActivate();
      debugPrint(
        '🗺️ RemoteConfig geoapify_api_key loaded: ${geoapifyKey.trim().isNotEmpty}',
      );
    } catch (_) {
      // Remote Config fetch is best-effort. Defaults remain in place.
      debugPrint('🗺️ RemoteConfig fetch failed (geoapify_api_key may be empty)');
    }
  }
}
