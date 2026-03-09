#!/usr/bin/env bash

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "============================================"
echo "  Pre-Push Validation Suite"
echo "============================================"

ALLOW_LOCAL_HEAVY_PRE_PUSH="${ALLOW_LOCAL_HEAVY_PRE_PUSH:-0}"

if [ "$ALLOW_LOCAL_HEAVY_PRE_PUSH" = "1" ]; then
    echo ""
    echo "Heavy local pre-push validation enabled (ALLOW_LOCAL_HEAVY_PRE_PUSH=1)."
else
    echo ""
    echo "Heavy local pre-push validation skipped by default."
    echo "Remote strict validation runs in GitHub Actions/Codemagic."
    echo "Set ALLOW_LOCAL_HEAVY_PRE_PUSH=1 to force local Flutter builds/tests and Playwright."
fi

# 0a. Flutter unit/widget tests — run FIRST while RAM is fresh (before heavy builds)
if [ "$ALLOW_LOCAL_HEAVY_PRE_PUSH" = "1" ]; then
    echo ""
    echo "--- [0a] Flutter Tests (pre-build, RAM-fresh) ---"
    cd origna_gta
    if ! flutter test --reporter compact --concurrency=2; then
        echo "❌ ERROR: Flutter tests failed."
        exit 1
    fi
    cd "$REPO_ROOT"
    echo "✅ Flutter tests passed."
else
    echo ""
    echo "--- [0a] Flutter Tests (pre-build, RAM-fresh) ---"
    echo "⏭️  Skipped locally. Remote strict gate enforces Flutter coverage/tests."
fi

# 0b. Python backend tests — run before builds too
echo ""
echo "--- [0b] Python Backend Tests (pre-build) ---"
cd functions
pip install -q pytest pytest-mock mockito sentry_sdk > /dev/null 2>&1
if ! python3 -m pytest tests/ -q --tb=short; then
    echo "❌ ERROR: Backend Python tests failed."
    exit 1
fi
cd "$REPO_ROOT"
echo "✅ Backend tests passed."

# 0. Validate Flutter builds for all 3 environments
echo ""
echo "--- [0/10] Multi-Env Build Validation ---"
if [ "$ALLOW_LOCAL_HEAVY_PRE_PUSH" = "1" ]; then
    BUILD_DIR="$REPO_ROOT/origna_gta/build/web"
    cd "$REPO_ROOT/origna_gta"

    echo "  Building DEV..."
    flutter build web --debug --dart-define=ENVIRONMENT=dev --dart-define=FORCE_SEMANTICS=true > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: Flutter DEV build failed."
        exit 1
    fi
    echo "  ✅ DEV build OK"

    echo "  Building STAGING..."
    flutter build web --profile --dart-define=ENVIRONMENT=staging --dart-define=FORCE_SEMANTICS=true > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: Flutter STAGING build failed."
        exit 1
    fi
    echo "  ✅ STAGING build OK"

    echo "  Building PROD..."
    flutter build web --release --dart-define=ENVIRONMENT=production > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: Flutter PROD build failed."
        exit 1
    fi
    # Guardrail: prod build must NOT contain FORCE_SEMANTICS
    if grep -q "FORCE_SEMANTICS" "$BUILD_DIR/main.dart.js" 2>/dev/null; then
        echo "❌ ERROR: FORCE_SEMANTICS found in PROD build — dev/staging artifacts leaked into release!"
        exit 1
    fi
    echo "  ✅ PROD build OK (no dev/staging artifacts)"

    cd "$REPO_ROOT"
    echo "✅ All 3 environment builds validated."
else
    echo "⏭️  Skipped locally. Remote CI/Codemagic own multi-env Flutter validation."
fi

# 1. Check for credential leaks
echo ""
echo "--- [1/10] Credential Leak Check ---"
if grep -r "960227Y#y" e2e/ origna_gta/lib/ origna_gta/test/ origna_gta/patrol_test/ 2>/dev/null; then
    echo "❌ ERROR: Old admin password found in source code."
    exit 1
fi
echo "✅ No credential leaks found."

# 2. Schema sync: Python ↔ Dart constants
echo ""
echo "--- [2/10] Schema Constants Sync (Python ↔ Dart) ---"
if ! python3 scripts/validate_schema_sync.py; then
    echo "❌ ERROR: Schema constants are out of sync."
    exit 1
fi
echo "✅ Schema constants in sync."

# 3. Algolia config validation
echo ""
echo "--- [3/10] Algolia Configuration Sync ---"
if ! python3 scripts/validate_algolia_sync.py; then
    echo "❌ ERROR: Algolia configuration mismatch."
    exit 1
fi
echo "✅ Algolia config validated."

# 4. Magic string detection on changed files
echo ""
echo "--- [4/10] Magic String Detection ---"
if ! python3 scripts/validate_no_magic_strings.py --ci; then
    echo "⚠️  WARNING: Magic strings detected (see above). Consider fixing before push."
    # Non-blocking for now — switch to exit 1 after cleanup
fi

# 5. API endpoint cross-reference (static analysis only — no HTTP)
echo ""
echo "--- [5/10] API Endpoint Sync (Frontend ↔ Backend) ---"
if ! python3 scripts/validate_api_endpoints.py --skip-http; then
    echo "❌ ERROR: API endpoint mismatch between frontend and backend."
    exit 1
fi
echo "✅ API endpoints in sync."

# 6. Validate Firestore indexes, rules, storage across environments
echo ""
echo "--- [6/10] Firestore Rules & Indexes ---"
python3 scripts/validate_indexes.py
python3 scripts/validate_rules.py
python3 scripts/validate_storage_rules.py

# 7. Cloud Functions sync + deploy version parity
echo ""
echo "--- [7/10] Cloud Functions & Deploy Parity ---"
python3 scripts/verify_functions_sync.py
python3 scripts/check_deploy_versions.py

# 8. (Flutter tests already ran in step 0a)
# 9. (Python tests already ran in step 0b)

# 10. Playwright E2E tests against dev
echo ""
echo "--- [10/10] Playwright E2E Tests (dev) ---"
if [ "$ALLOW_LOCAL_HEAVY_PRE_PUSH" = "1" ]; then
    cd e2e
    if ! npx playwright test --config=playwright.config.dev.ts --retries=1 --workers=2; then
        echo "❌ ERROR: Playwright E2E tests failed on dev."
        exit 1
    fi
    cd "$REPO_ROOT"
    echo "✅ Playwright E2E tests passed."
else
    echo "⏭️  Skipped locally. Remote strict gate enforces Playwright flows and coverage."
fi

echo ""
echo "============================================"
echo "  All pre-push validations passed!"
echo "============================================"
