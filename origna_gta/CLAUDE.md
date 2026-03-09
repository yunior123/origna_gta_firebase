# Frontend Context: Flutter Application

## Tech Stack
- **Framework:** Flutter (Latest Stable)
- **State Management:** Riverpod (MVVM pattern)
- **Networking:** Dio (with interceptors)
- **Forms:** Reactive Forms (or custom Riverpod-based)
- **Testing:** flutter_test, mockito, integration_test
- **Linting:** analysis_options.yaml (strict)

## Architecture & Conventions
- **MVVM:** No logic in Screens. ViewModels (Providers) handle all state and side effects.
- **Feature Slices:** Code organized by feature in `lib/features/`.
- **Generated Models:** Use `lib/models/generated/` for data structures.
- **Constants:** Use `lib/core/schema/schema_constants.dart` for all enums and keys.
- **Error Handling:** Centralized error handling via `AsyncValue` and `Sentry`.

## Critical Workflows
- **Install Dependencies:** `flutter pub get`
- **Generate Code:** `flutter pub run build_runner build --delete-conflicting-outputs`
- **Linting:** `flutter analyze`
- **Test Suite:** `flutter test`
- **Single Test:** `flutter test test/feature_test.dart`
- **Run App:** `flutter run --dart-define=ENVIRONMENT=dev`

## Verification Checklist
1. Ensure all new UI strings have French (Quebec) translations.
2. Run `flutter analyze` to check for style violations.
3. Verify logic with at least one new unit/widget test.
4. Check `origna_flows/SEMANTICS.md` for ARIA keys in new screens.

## Avoid These Pitfalls
- Do not use `SetState` in complex screens; use Riverpod.
- Never hardcode API keys or URLs; use `--dart-define`.
- Avoid "fat" ViewModels; decompose into smaller providers if needed.
