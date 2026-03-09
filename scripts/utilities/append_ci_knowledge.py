"""Module append_ci_knowledge.py."""
with open('.claude/LEARNED.md', 'a', encoding='utf-8') as f:
    f.write("""
## CI & Pre-Push Hook Learnings (Feb 2026)
- **Pre-Push Validation Script:** Always include comprehensive tests in pre-push validations (`scripts/pre_push_validation.sh`). This includes:
  1. `flutter test` for all frontend unit and widget tests.
  2. `pytest` for all Python backend tests (ensure mockito, pytest-cov, etc., are installed).
  3. Playwright E2E UI testing (against a live Dev instance or emulator) using `npx playwright test`.
- **Git Hook Path Resolution:** When executing scripts from within `.git/hooks/pre-push`, `$(dirname "$0")` may fail to correctly resolve the repository root depending on how the hook is symlinked or copied. Use `REPO_ROOT="$(git rev-parse --show-toplevel)"` to reliably get the root of the git repository.
- **Generic Environment Validation:** Rather than hardcoding validation strings (like `grep deliveredAt firestore.indexes.json`), prefer generic validation scripts like `validate_indexes.py` and `validate_rules.py` which query live environments via `firebase firestore:indexes` and `https://firebaserules.googleapis.com` to ensure local configs perfectly match deployed configs.
""")
