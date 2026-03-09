---
paths:
  - "**/test*"
  - "e2e/**"
  - "functions/tests/**"
  - "origna_gta/test/**"
---

# Testing Rules

- Backend: `cd functions && pytest -v` (288 tests). Fixtures via `conftest.py`.
- E2E: `cd e2e && npm test` (279 tests). Requires emulators + `mega-seed.ts` seed.
- Flutter: `cd origna_gta && flutter test`. Integration: pump loops (10×1s), NOT `pumpAndSettle()`.
- `api-helpers.ts` = canonical E2E module. Never duplicate helpers.
- Every code change → corresponding test update. Adversarial scenarios required.
