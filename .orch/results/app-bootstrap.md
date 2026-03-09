## APP BOOTSTRAP FINDINGS

### CRITICAL
1. Emulator mode falls back to dev Firebase silently when emulators unavailable — data contamination (main.dart:64)

### HIGH
2. Email verification bypassed in emulator mode — behavior divergence (authwrapper_screen.dart:18-20)
3. Session timeout race condition — no user ID binding, stale timer can sign out wrong user (session_timeout_service.dart:46)
4. Riverpod providers accessed before auth state resolves — "provider not initialized" on cold start (origna_app.dart:663)

### MEDIUM
5. CORS missing dev.orignagta.ca / staging.orignagta.ca if custom domains used (schema_constants.py:166)
6. Algolia index name defined in two places (Dart + Python) — drift risk
7. Analytics NOT disabled in staging — pollutes production analytics (analytics_service.dart:9)
8. R2 folder ternary chain error-prone — use switch/factory pattern (env_config.dart:99)

### LOW
9. Provider initialization order not documented
10. Session timeout constant hardcoded (15min) — not in schema_constants
11. Orphaned route `/seller/setup` registered but not implemented (routes.dart:28)
