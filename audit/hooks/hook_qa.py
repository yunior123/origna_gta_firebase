"""
🧪 QA Engineer Audit Hook

AI-powered QA Engineer that:
- Audits existing test coverage and identifies gaps
- Recommends modern testing frameworks for Flutter web/mobile
- Generates test plans for uncovered features
- Identifies flaky tests and suggests fixes
- Verifies test infrastructure health

Layers:
  1. Unit Tests (pytest + flutter_test)
  2. Integration Tests (emulator-backed)
  3. E2E Tests (Playwright + Patrol)
  4. Visual Regression (Golden tests)
  5. Accessibility (Semantics audit)
  6. Performance (Lighthouse CI, load testing)
  7. Security (adversarial tests)
  8. Contract (API schema validation)
"""
from __future__ import annotations

import re
from pathlib import Path

from .base import BaseHook, Finding, HookResult, register_hook
from .config import PROJECT_ROOT, CRITICAL, HIGH, MEDIUM, LOW
from .prompts import STRUCTURED_OUTPUT_INSTRUCTION, PROJECT_CONTEXT


def _count_tests_in_file(filepath: Path) -> int:
    """Count test functions/cases in a file."""
    if not filepath.exists():
        return 0

    text = filepath.read_text(errors="ignore")
    count = 0

    if filepath.suffix == ".py":
        # Python: count def test_*
        count = len(re.findall(r'^\s*(?:def|async def)\s+test_', text, re.MULTILINE))
    elif filepath.suffix == ".ts":
        # TypeScript: count test(... and it(...
        count = len(re.findall(r'^\s*(?:test|it)\s*\(', text, re.MULTILINE))
    elif filepath.suffix == ".dart":
        # Dart: count test(... and testWidgets(...
        count = len(re.findall(r'^\s*(?:test|testWidgets|testGoldens)\s*\(', text, re.MULTILINE))

    return count


def _scan_test_coverage() -> list[Finding]:
    """Scan all test files and compute coverage metrics."""
    findings = []

    # ── Python backend tests ──
    py_test_dir = PROJECT_ROOT / "functions" / "tests"
    py_tests = 0
    py_files = []
    if py_test_dir.exists():
        for f in py_test_dir.rglob("test_*.py"):
            count = _count_tests_in_file(f)
            py_tests += count
            py_files.append((f.relative_to(PROJECT_ROOT), count))

    findings.append(Finding(
        severity=LOW,
        title=f"Backend: {py_tests} Python tests across {len(py_files)} files",
        description="\n".join(f"  {p}: {c} tests" for p, c in sorted(py_files)),
        file="functions/tests/", category="qa-coverage",
    ))

    # ── Playwright E2E tests ──
    e2e_dir = PROJECT_ROOT / "e2e"
    e2e_tests = 0
    e2e_files = []
    if e2e_dir.exists():
        for f in e2e_dir.glob("*.spec.ts"):
            count = _count_tests_in_file(f)
            e2e_tests += count
            e2e_files.append((f.relative_to(PROJECT_ROOT), count))

    findings.append(Finding(
        severity=LOW,
        title=f"E2E: {e2e_tests} Playwright tests across {len(e2e_files)} files",
        description="\n".join(f"  {p}: {c} tests" for p, c in sorted(e2e_files)),
        file="e2e/", category="qa-coverage",
    ))

    # ── Flutter unit tests ──
    flutter_test_dir = PROJECT_ROOT / "origna_gta" / "test"
    dart_tests = 0
    dart_files = []
    if flutter_test_dir.exists():
        for f in flutter_test_dir.rglob("*_test.dart"):
            count = _count_tests_in_file(f)
            dart_tests += count
            dart_files.append((f.relative_to(PROJECT_ROOT), count))

    if dart_tests < 50:
        findings.append(Finding(
            severity=HIGH,
            title=f"Flutter widget tests critically low: {dart_tests} tests",
            description=f"Only {dart_tests} tests across {len(dart_files)} files. "
                        "Need 200+ for production readiness.\n"
                        "Priority: ViewModel tests, Model serialization, Provider tests.",
            file="origna_gta/test/", category="qa-coverage",
            fix_suggestion="Create tests for: checkout_provider, auth_provider, "
                           "seller_orders_viewmodel, all Freezed models",
        ))
    else:
        findings.append(Finding(
            severity=LOW,
            title=f"Flutter: {dart_tests} widget tests across {len(dart_files)} files",
            description="\n".join(f"  {p}: {c} tests" for p, c in sorted(dart_files)),
            file="origna_gta/test/", category="qa-coverage",
        ))

    # ── Flutter integration tests ──
    integration_dir = PROJECT_ROOT / "origna_gta" / "integration_test"
    int_tests = 0
    int_files = []
    if integration_dir.exists():
        for f in integration_dir.rglob("*_test.dart"):
            count = _count_tests_in_file(f)
            int_tests += count
            int_files.append((f.relative_to(PROJECT_ROOT), count))

    if int_tests < 10:
        findings.append(Finding(
            severity=HIGH,
            title=f"Flutter integration tests very low: {int_tests} tests",
            description="Need integration tests for critical user journeys: "
                        "login → browse → add to cart → checkout → order tracking",
            file="origna_gta/integration_test/", category="qa-coverage",
        ))

    # ── Patrol tests ──
    patrol_dir = PROJECT_ROOT / "origna_gta" / "patrol_test"
    if not patrol_dir.exists() or not any(patrol_dir.rglob("*_test.dart")):
        findings.append(Finding(
            severity=HIGH,
            title="No Patrol native E2E tests found",
            description="Patrol is the best Flutter-native E2E framework for mobile. "
                        "Critical for iOS/Android testing before launch.",
            file="origna_gta/patrol_test/", category="qa-gap",
            fix_suggestion="Add patrol ^3.13.0 to dev_dependencies. Create "
                           "patrol_test/checkout_flow_test.dart",
        ))

    return findings


def _check_test_infrastructure() -> list[Finding]:
    """Verify test infrastructure health."""
    findings = []

    # Playwright config
    pw_config = PROJECT_ROOT / "e2e" / "playwright.config.ts"
    if pw_config.exists():
        config_text = pw_config.read_text()

        # Check for multiple browsers
        if "firefox" not in config_text.lower() and "webkit" not in config_text.lower():
            findings.append(Finding(
                severity=HIGH,
                title="E2E tests only run on Chromium",
                description="No Firefox/WebKit/Safari projects configured. "
                            "Cross-browser testing required for production.",
                file="e2e/playwright.config.ts", category="qa-gap",
                fix_suggestion="Add projects for Firefox and WebKit in playwright.config.ts",
            ))

        # Check for retries
        if "retries" not in config_text:
            findings.append(Finding(
                severity=MEDIUM,
                title="No retry configuration in Playwright",
                description="Flaky tests will cause CI failures without retries",
                file="e2e/playwright.config.ts", category="qa-infra",
            ))

        # Check for reporters
        if "html" not in config_text and "json" not in config_text:
            findings.append(Finding(
                severity=LOW,
                title="No HTML/JSON reporter configured",
                description="Add reporters for better test result analysis",
                file="e2e/playwright.config.ts", category="qa-infra",
            ))

    # Check for test coverage tools
    pubspec = PROJECT_ROOT / "origna_gta" / "pubspec.yaml"
    if pubspec.exists():
        pubspec_text = pubspec.read_text()

        if "patrol" not in pubspec_text:
            findings.append(Finding(
                severity=MEDIUM,
                title="Patrol not in pubspec.yaml",
                description="Add patrol for native mobile E2E testing",
                file="origna_gta/pubspec.yaml", category="qa-gap",
            ))

        if "mocktail" not in pubspec_text and "mockito" not in pubspec_text:
            findings.append(Finding(
                severity=MEDIUM,
                title="No mocking library in pubspec.yaml",
                description="Need mocktail/mockito for isolated unit tests",
                file="origna_gta/pubspec.yaml", category="qa-gap",
                fix_suggestion="Add mocktail: ^1.0.0 to dev_dependencies",
            ))

        if "golden_toolkit" not in pubspec_text:
            findings.append(Finding(
                severity=MEDIUM,
                title="No visual regression testing library",
                description="golden_toolkit enables screenshot comparison tests",
                file="origna_gta/pubspec.yaml", category="qa-gap",
            ))

    # pytest config
    py_req = PROJECT_ROOT / "functions" / "requirements.txt"
    if py_req.exists():
        req_text = py_req.read_text()
        if "pytest-cov" not in req_text:
            findings.append(Finding(
                severity=MEDIUM,
                title="No pytest-cov for Python coverage reporting",
                description="Add pytest-cov to measure backend test coverage",
                file="functions/requirements.txt", category="qa-gap",
            ))

    return findings


def _identify_untested_handlers() -> list[Finding]:
    """Find backend handlers without corresponding test coverage."""
    findings = []

    handlers_dir = PROJECT_ROOT / "functions" / "handlers"
    tests_dir = PROJECT_ROOT / "functions" / "tests"

    if not handlers_dir.exists() or not tests_dir.exists():
        return findings

    # Get all handler files
    handler_files = {f.stem for f in handlers_dir.glob("*.py") if not f.stem.startswith("_")}

    # Get all test files
    test_files_text = ""
    for f in tests_dir.rglob("*.py"):
        test_files_text += f.read_text(errors="ignore")

    # Check each handler
    for handler in sorted(handler_files):
        # Check if handler is tested
        test_patterns = [
            f"test_{handler}",
            f"test_handlers_{handler}",
            handler.replace("_", ""),
        ]
        found = any(p in test_files_text for p in test_patterns)
        if not found:
            findings.append(Finding(
                severity=HIGH,
                title=f"Handler '{handler}.py' has no dedicated tests",
                description=f"No test file found specifically testing handlers/{handler}.py",
                file=f"functions/handlers/{handler}.py", category="qa-coverage",
                fix_suggestion=f"Create functions/tests/test_handlers_{handler}.py",
            ))

    return findings


def _check_critical_flow_coverage() -> list[Finding]:
    """Check if critical business flows are E2E tested."""
    findings = []

    e2e_dir = PROJECT_ROOT / "e2e"
    if not e2e_dir.exists():
        return findings

    # Read all E2E test content
    e2e_content = ""
    for f in e2e_dir.glob("*.spec.ts"):
        e2e_content += f.read_text(errors="ignore")

    critical_flows = {
        "user registration": ["register", "signUp", "createAccount"],
        "user login": ["signIn", "login"],
        "product creation": ["createProduct", "addProduct", "upload_product"],
        "product search": ["search", "algolia", "filterProducts"],
        "add to cart": ["addToCart", "cart"],
        "checkout": ["checkout", "createCheckoutSession"],
        "order tracking": ["orderStatus", "trackOrder", "update_order"],
        "seller onboarding": ["connectAccount", "createConnectAccount", "sellerOnboard"],
        "refund": ["refund", "refundOrder"],
        "dispute": ["dispute"],
        "shipping cost": ["shippingCost", "calculateShipping"],
        "seller payout": ["transfer", "payout", "sellerTransfer"],
        "product rating": ["rating", "submitRating", "productRating"],
        "account deletion": ["deleteAccount", "delete_account"],
        "admin actions": ["updateUserRoles", "suspendSeller", "adminUpdate"],
    }

    for flow, keywords in critical_flows.items():
        found = any(kw.lower() in e2e_content.lower() for kw in keywords)
        if not found:
            findings.append(Finding(
                severity=HIGH,
                title=f"No E2E coverage for: {flow}",
                description=f"Critical business flow '{flow}' has no E2E test coverage. "
                            f"Searched keywords: {', '.join(keywords)}",
                file="e2e/", category="qa-gap",
            ))

    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# REGISTERED HOOK
# ═══════════════════════════════════════════════════════════════════════════════

@register_hook
class QAHook(BaseHook):
    """
    QA Engineer audit hook.

    Runs local analysis FIRST (test counting, gap detection), then uses LLM
    for deeper test strategy recommendations.
    """
    hook_name = "qa"
    description = "QA Engineer: test coverage analysis, gap detection, framework recommendations"
    emoji = "🧪"

    watch_patterns = [
        "e2e/*.spec.ts",
        "e2e/*.ts",
        "functions/tests/*.py",
        "origna_gta/test/**/*_test.dart",
        "origna_gta/integration_test/**/*_test.dart",
        "origna_gta/patrol_test/**/*_test.dart",
        "e2e/playwright.config.ts",
        "origna_gta/pubspec.yaml",
    ]

    target_files = [
        "e2e/playwright.config.ts",
        "e2e/api-helpers.ts",
        "e2e/flutter-helpers.ts",
        "origna_gta/pubspec.yaml",
        "functions/requirements.txt",
        # Sample test files for pattern analysis
        "e2e/fullstack-e2e.spec.ts",
        "e2e/payment-workflow-e2e.spec.ts",
        "e2e/logic-failures-e2e.spec.ts",
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are a SENIOR QA ENGINEER with 15+ years experience in test automation.
You are the ONLY QA resource for this project — the team cannot afford hiring engineers.
Your job: ensure this app is production-ready for March 2026 launch.

{PROJECT_CONTEXT}

## Your Expertise
- **Flutter testing**: flutter_test, integration_test, Patrol, Maestro, golden tests
- **Web E2E**: Playwright, Cypress, Puppeteer
- **Backend**: pytest, unittest, hypothesis (property-based)
- **Mobile native**: Appium, XCUITest, Espresso, Patrol, Maestro
- **Performance**: k6, Artillery, Locust, Lighthouse CI
- **Visual regression**: Percy, Applitools, Flutter golden tests
- **Accessibility**: axe-core, Flutter semantics audit
- **Security testing**: OWASP ZAP, Burp Suite, custom adversarial tests
- **AI testing**: Using LLMs to generate test cases, property-based testing

## Analysis Tasks

1. **COVERAGE AUDIT** — What % of code has test coverage? What critical paths are missing?
2. **TEST QUALITY** — Are tests actually testing the right things? Assertions meaningful?
3. **FLAKY TESTS** — Identify tests that might fail intermittently and why
4. **FRAMEWORK GAPS** — What modern frameworks should be added? (Patrol, Maestro, k6)
5. **TEST DATA** — Is test data management robust? Seed scripts comprehensive?
6. **CI/CD** — Are tests running in CI? What's the pipeline configuration?
7. **CROSS-BROWSER** — Web works on Chrome/Firefox/Safari?
8. **MOBILE TESTING** — iOS/Android coverage? Native-specific tests?
9. **PERFORMANCE** — Load tests? Response time benchmarks?
10. **ACCESSIBILITY** — WCAG 2.1 AA compliance testing?

## Deliverables
For each gap found, provide:
1. Specific test file to create
2. Exact test cases (describe blocks)
3. Framework/library to use
4. Priority (CRITICAL/HIGH/MEDIUM/LOW)
5. Estimated implementation effort (hours)

## Rules
- Be SPECIFIC — don't say "add more tests", say exactly WHICH tests
- Generate actual test code snippets when possible
- Prioritize by business impact (payment > search > UI)
- Consider the solo developer context — prioritize automated, self-maintaining tests
- Every recommendation must be FREE or open-source

{STRUCTURED_OUTPUT_INSTRUCTION}

Project files:
"""

    def run(self, changed_only: list[str] | None = None) -> HookResult:
        """
        Override run() to add local analysis BEFORE LLM.
        """
        import time
        start = time.time()
        result = HookResult(hook_name=self.hook_name, status="success")

        print(f"\n{self.emoji} {self.hook_name}: Running QA analysis...")

        # ── Phase 1: Local analysis (FREE) ──
        print("  📋 Phase 1: Local test coverage scan...")

        local_findings = []
        local_findings.extend(_scan_test_coverage())
        local_findings.extend(_check_test_infrastructure())
        local_findings.extend(_identify_untested_handlers())
        local_findings.extend(_check_critical_flow_coverage())

        critical = sum(1 for f in local_findings if f.severity == CRITICAL)
        high = sum(1 for f in local_findings if f.severity == HIGH)
        print(f"  ✅ Phase 1 complete: {len(local_findings)} findings "
              f"({critical} critical, {high} high)")

        result.findings.extend(local_findings)

        # ── Phase 2: LLM deep analysis ──
        files = self.resolve_files(changed_only)
        if files:
            result.files_audited = len(files)
            print(f"  🤖 Phase 2: LLM deep QA analysis of {len(files)} test files...")

            try:
                context = self.bundle_files(files)

                # Add local findings as context
                local_summary = "\n## Local Analysis Results (already found):\n"
                for f in local_findings:
                    local_summary += f"- [{f.severity}] {f.title}\n"
                context = local_summary + context

                prompt = self.get_prompt()
                raw_response = self.call_llm(prompt, context)
                llm_findings = self.parse_findings(raw_response)
                result.findings.extend(llm_findings)
                result.markdown_report = raw_response
            except Exception as e:
                print(f"  ⚠️  LLM analysis skipped: {e}")
                result.markdown_report = "LLM analysis skipped — local findings only"

        result.findings.sort(key=lambda f: f.severity_rank)
        result.duration_seconds = round(time.time() - start, 2)
        return result
