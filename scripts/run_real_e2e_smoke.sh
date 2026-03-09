#!/usr/bin/env bash

# Runs a real Playwright browser smoke test against the configured target URL.
# Defaults to the dev hosted environment from playwright.config.dev.ts.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="${1:-playwright_ui/smoke-home-profile.spec.ts}"
CONFIG="${E2E_CONFIG:-playwright.config.dev.ts}"
PROJECT="${E2E_PROJECT:-chromium}"
WORKERS="${E2E_WORKERS:-1}"
FAIL_ON_FLAKY="${E2E_FAIL_ON_FLAKY:-true}"

cd "$ROOT_DIR/e2e"
CMD=(
  npx playwright test "$SPEC"
  --config="$CONFIG"
  --project="$PROJECT"
  --workers="$WORKERS"
)
if [[ "$FAIL_ON_FLAKY" == "true" ]]; then
  CMD+=(--fail-on-flaky-tests)
fi
"${CMD[@]}"
