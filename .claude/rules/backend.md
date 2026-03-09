---
paths:
  - "functions/**"
---

# Backend Rules

- Entry: `main.py`. Handlers in `handlers/`, models in `models/` (Pydantic)
- Idempotency required (event_id dedup). Validate ALL inputs server-side.
- Re-fetch prices from Firestore — never use client-sent amounts
- Atomic transactions for stock. Webhook HMAC verification.
- `schema_constants.py` must sync with `schema_constants.dart` + `database_schema.json`
- When editing handler → check corresponding Dart provider + update response format consumers
