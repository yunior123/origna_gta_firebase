---
applyTo: "origna_gta/lib/**/*.dart,origna_gta/test/**/*.dart"
---

# Flutter/Dart Context

## Architecture (MVVM — Non-Negotiable)
- Screens (`screens/`) = UI only, ZERO business logic
- ViewModels (`features/`) = business logic via Riverpod StateNotifier
- Repositories (`core/repositories/`) = Firestore/API data access
- State management: **Riverpod ONLY** (never Provider, Bloc, Redux)

## Models
- Primary: `lib/models/generated/*.dart` (Freezed + json_serializable)
- Older: `lib/models/models.dart` — `Address` collision risk, use `hide Address`
- Factory constructors: `Order.fromFirestore(doc)`, `User.fromFirestore(doc)`

## Critical Patterns
- Schema constants: `lib/core/schema/schema_constants.dart` — Dart mirror of `functions/schema_constants.py`
- Design tokens: `lib/utils/design_tokens.dart` — NEVER hardcode colors
- No `withOpacity()` → use `Color.fromRGBO` or design tokens
- No `MaterialPageRoute` → named routes
- No `CircularProgressIndicator` → `ModernLoadingIndicator`
- No `IconButton` without tooltip
- No `BuildContext` passed to async methods — resolve before await
- All Modern* widgets use glassmorphism toolkit (`utils/glassmorphism.dart`)

## Cross-Stack Sync (when changing Dart models)
Update ALL: `schema_constants.dart` → `schema_constants.py` → `database_schema.json` → Freezed models → Pydantic models → tests

## Testing
```bash
cd origna_gta && flutter test && flutter analyze
```
