#!/usr/bin/env bash

# This script runs the Regression E2E tests (specifically password reset)
# against Dev, Staging, and Production environments.
# NOTE: The code must be deployed to these environments for the tests to pass.

set -e

cd e2e

echo "========================================"
echo "🧪 Testing DEV Environment..."
echo "========================================"
npx playwright test playwright_ui/password-reset.spec.ts --config=playwright.config.dev.ts

echo "========================================"
echo "🧪 Testing STAGING Environment..."
echo "========================================"
npx playwright test playwright_ui/password-reset.spec.ts --config=playwright.config.staging.ts

echo "========================================"
echo "🧪 Testing PROD Environment..."
echo "========================================"
npx playwright test playwright_ui/password-reset.spec.ts --config=playwright.config.ts

echo "✅ All environment regression tests passed!"
