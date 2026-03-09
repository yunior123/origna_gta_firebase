/// Web implementation — JS interop to read the Cloudflare Turnstile token
/// that was rendered by the invisible widget in web/index.html.
library;

import 'dart:async';
import 'dart:js_interop';

@JS('window._getTurnstileToken')
external JSPromise<JSString?> _getTurnstileToken();

@JS('window._resetTurnstile')
external void _resetTurnstile();

/// Returns the Turnstile challenge token from JS, or null if not yet ready.
Future<String?> getTurnstileTokenFromJs() async {
  try {
    final result = await _getTurnstileToken().toDart;
    return result?.toDart;
  } catch (_) {
    return null;
  }
}

/// Resets the Turnstile widget so a fresh token can be obtained.
void resetTurnstileWidget() {
  _resetTurnstile();
}
