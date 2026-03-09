# Testing Guide

> **Source of truth for enforced gates:** `scripts/run_quality_gate.sh` and `.github/workflows/strict-quality-audit.yml`

## E2E Tests (Playwright)
- **Config:** `e2e/playwright.config.dev.ts`
- **Specs:** `e2e/playwright_ui/*.spec.ts`
- **Helpers:** `e2e/playwright_ui/api-helpers.ts`, `flutter-helpers.ts`
- **Base URL:** `https://orignagta-dev.web.app`
- **Run all:** `npx playwright test --config=e2e/playwright.config.dev.ts`
- **Run one:** `npx playwright test e2e/playwright_ui/<spec>.spec.ts --config=e2e/playwright.config.dev.ts`
- **Dedicated coverage gate:** `e2e/playwright_ui/coverage-gate.spec.ts`

## Backend Tests (pytest)
- **Run:** `cd functions && pytest`
- **Config:** `functions/pytest.ini`

## Flutter tests
- **Run all local Flutter tests:** `cd origna_gta && flutter test`
- **Dedicated unit coverage target:** `cd origna_gta && flutter test test/coverage_gate_test.dart --coverage --coverage-path=coverage_unit.info`
- **Dedicated integration coverage target:** `cd origna_gta && flutter test integration_test/coverage_gate_integration_test.dart`
- **Dedicated integration binding:** `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`

## Strict quality gate
- **Script:** `./scripts/run_quality_gate.sh`
- **Remote workflow:** `.github/workflows/strict-quality-audit.yml`
- **Remote Codemagic workflow:** `origna_gta/codemagic.yaml` → `quality-gate-remote`
- **Default local behavior:** backend-only safe mode
- **Force local heavy mode:** `./scripts/run_quality_gate.sh --allow-local-heavy --backend-gate-mode strict`
- **Installed git pre-push hook:** lightweight local checks by default
- **Force heavy local pre-push:** `ALLOW_LOCAL_HEAVY_PRE_PUSH=1 git push`
- **Force deploy from pre-push hook:** `RUN_PRE_PUSH_DEPLOY=1 git push`
- **Remote enforced thresholds:**
  - Backend coverage: `100`
  - Flutter unit coverage: `100`
  - Flutter integration coverage: `100`
  - Playwright coverage: `100`

## Why heavy gates are remote-first
- This repo is maintained on an 8GB development machine.
- Firebase emulators plus full browser/device E2E cause avoidable RAM and disk pressure locally.
- GitHub Actions and Codemagic are the default path for full strict validation.

## Non-Negotiable Rules
- Never `fill()` — always `pressSequentially()`
- Never `page.goto()` after login — use `page.goBack()`
- No dynamic product creation in `beforeAll` — use stable product IDs from MEMORY.md
- Tests run against dev Firebase only — emulators forbidden (8GB RAM)
- `DELIVERED` status = admin-only — sign in as admin for that transition
