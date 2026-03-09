/// Non-web stub — mobile/desktop use Firebase App Check for attestation.
library;

import 'dart:async';

/// Always returns null on non-web platforms.
Future<String?> getTurnstileTokenFromJs() async => null;

/// No-op on non-web platforms.
void resetTurnstileWidget() {}
