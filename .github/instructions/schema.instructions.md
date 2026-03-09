---
applyTo: "**/schema_constants*,docs/database_schema.json,**/models/**,docs/json_schemas/**"
---

# Schema & Models Context

## 6-Layer Schema Sync (ALL must match)
1. `docs/database_schema.json` — overall source of truth
2. `functions/schema_constants.py` — Python field names, enums, collections
3. `origna_gta/lib/core/schema/schema_constants.dart` — Dart mirror
4. `functions/models/*.py` — Pydantic models
5. `origna_gta/lib/models/generated/*.dart` — Freezed models
6. `docs/json_schemas/individual/*.json` — individual collection schemas

## Cross-Stack Model Map
| Concept | Frontend (Dart) | Backend (Python) |
|---------|----------------|-------------------|
| Order | `lib/models/generated/order_models.dart` | `functions/models/order.py` |
| Product | `lib/models/generated/product_models.dart` | `functions/models/product.py` |
| User | `lib/models/generated/user_models.dart` | `functions/models/user.py` |
| Enums | `lib/models/generated/base_models.dart` | `functions/models/base.py` |

## Rules
- Changing ONE field → update ALL 6 layers + all tests
- Run `./scripts/validate_schema_consistency.sh` after ANY schema change
- No magic strings — always use constants from schema_constants
