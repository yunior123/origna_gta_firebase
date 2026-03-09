# Backend Context: Python Cloud Functions

## Tech Stack
- **Language:** Python 3.12+
- **Framework:** Firebase Cloud Functions (v2)
- **Validation:** Pydantic (v2)
- **Database:** Firestore (Google Cloud SDK)
- **Testing:** Pytest, Mockito
- **Linting:** Ruff, Mypy

## Architecture & Conventions
- **Feature-Based Handlers:** Logic organized in `functions/handlers/`.
- **Schema-First:** Always update `functions/schema_constants.py` for global constants.
- **Strict Typing:** Every function MUST have type hints for parameters and return values.
- **Idempotency:** Payment and order updates MUST be idempotent.
- **Adversarial Logic:** Predict and handle race conditions (e.g., concurrent order updates).

## Critical Workflows
- **Install Dependencies:** `pip install -r functions/requirements.txt`
- **Linting:** `ruff check functions`
- **Type Checking:** `mypy functions`
- **Test Suite:** `pytest functions/tests`
- **Single Test:** `pytest functions/tests/test_file.py::test_name`
- **Deploy:** `firebase deploy --only functions --project <env>`

## Verification Checklist
1. Ensure `Pydantic` models match `schema_constants`.
2. Run `ruff` and `mypy` before any code changes.
3. Verify changes with at least one new unit test in `functions/tests`.
4. Check Firestore security rules in `firestore.rules` if schema changes.

## Avoid These Pitfalls
- Never use magic strings for order statuses; use `OrderStatusValues`.
- Do not perform expensive DB reads inside loops; use batching.
- Avoid large function payloads; keep data structures minimal.
