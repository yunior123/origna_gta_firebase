---
paths:
  - "firestore.*"
  - "**/schema_constants*"
  - "docs/database_schema.json"
  - "docs/json_schemas/**"
  - "**/repositories/**"
---

# Firestore & Schema Rules

Sync chain: `database_schema.json` → `schema_constants.py` → `schema_constants.dart` → Pydantic/Freezed models → `firestore.rules` → `firestore.indexes.json`

Change a field → update ALL layers + run `./scripts/validate_schema_consistency.sh`.
Minimize reads (expensive). Avoid collection group queries. Cache when safe.
