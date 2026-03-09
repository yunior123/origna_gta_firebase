# App Bootstrap Auditor — Memory

## Audit Run: 2026-03-01

### Key Findings Summary
- 5 functions imported in main.py but absent from __all__ (orphaned): `submit_product_rating_atomic`, `toggle_favorite`, `admin_delete_product_question`, `admin_delete_product_rating`, `admin_update_warehouse_commission`
- AuthWrapper loading state renders MainScreen (not a spinner), relying on HTML splash cover — this is intentional but fragile
- CORS localhost only covers port 5005, but VS Code launch.json uses port 3000 for "Full Stack Dev" configs
- EnvConfig() default value is 'production' — a missing --dart-define silently targets prod Firebase
- auth_repository.dart isEmailVerified() bypass is NOT gated on kDebugMode (unlike the utils.dart version) — emulator-only but slightly wider scope
- Analytics disabled in emulator/dev/staging (correct), PII scrubbing present (correct)
- Session timeout correctly tied to BusinessRules.sessionTimeoutMinutes (15 min)
- Sentry IP scrubbed (PIPEDA), PII disabled in backend Sentry (send_default_pii=False)
- CORS covers all hosting domains: dev.orignagta.ca, staging.orignagta.ca, www.orignagta.ca, .web.app, .firebaseapp.com

### Stable Patterns
- Environment detection: Dart uses --dart-define=ENVIRONMENT, Python uses GCP_PROJECT env var + FUNCTIONS_EMULATOR flag
- Secrets: emulator/local reads individual env vars; deployed reads APP_SECRETS Secret Manager JSON blob
- R2 and Algolia: both environment-aware via switch/if-else, no prod hardcoding
- AuthWrapper auth state loading → returns MainScreen() (not spinner) — HTML splash covers gap by design

See `findings.md` for full details.
