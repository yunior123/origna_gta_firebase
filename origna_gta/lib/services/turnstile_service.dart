import 'dart:async';

import 'package:flutter/foundation.dart';

// JS interop — only compiled on web.
// On mobile/desktop this entire block is dead code (kIsWeb guard prevents calls).
import 'turnstile_service_web.dart' if (dart.library.io) 'turnstile_service_stub.dart';

/// Cloudflare Turnstile bot-protection service.
///
/// Web: renders an invisible Turnstile widget injected in [web/index.html] and
/// returns the challenge token via JS interop.
///
/// Mobile/Desktop: always returns null — App Check handles attestation there.
class TurnstileService {
  TurnstileService._();

  /// Returns a Turnstile challenge token, or null if not on web / not configured.
  ///
  /// The token is consumed once — call [reset] before retrying on error.
  static Future<String?> getToken() async {
    if (!kIsWeb) return null;
    return getTurnstileTokenFromJs();
  }

  /// Resets the Turnstile widget so a fresh token can be obtained.
  static void reset() {
    if (!kIsWeb) return;
    resetTurnstileWidget();
  }
}
