---
paths:
  - "origna_gta/lib/**"
  - "origna_gta/test/**"
  - "origna_gta/integration_test/**"
---

# Flutter Rules

- MVVM: ViewModels in `features/`, Screens in `screens/` (0 logic)
- Riverpod only. Repositories in `core/repositories/`
- No `BuildContext` in async — resolve before await. Check `mounted` after.
- `withOpacity` DEPRECATED → `Color.withValues`. Fix all warnings.
- Models: `lib/models/generated/*.dart` (Freezed). Older `models.dart` has `Address` collision — use `hide`.
- `EnvConfig()` NOT `EnvConfig.instance`
- Cross-stack: verify field names match `schema_constants.dart` ↔ `schema_constants.py`
