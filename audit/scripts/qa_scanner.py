#!/usr/bin/env python3
"""
🧪 Standalone QA Coverage Scanner

Runs test coverage analysis WITHOUT LLM (free, fast).
Use this for quick test health checks.

Usage:
  python audit/scripts/qa_scanner.py                    # Full scan
  python audit/scripts/qa_scanner.py --run-tests        # Scan + actually run tests
  python audit/scripts/qa_scanner.py --generate-plan    # Generate test plan for gaps
  python audit/scripts/qa_scanner.py --json             # JSON output
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from hooks.hook_qa import (
    _scan_test_coverage,
    _check_test_infrastructure,
    _identify_untested_handlers,
    _check_critical_flow_coverage,
)
from hooks.config import PROJECT_ROOT, CRITICAL, HIGH, MEDIUM, LOW


SEVERITY_EMOJI = {
    CRITICAL: "🔴",
    HIGH: "🟠",
    MEDIUM: "🟡",
    LOW: "🟢",
}


def run_python_tests() -> tuple[int, int]:
    """Run pytest and return (passed, failed)."""
    try:
        result = subprocess.run(
            ["python", "-m", "pytest", "tests/", "-q", "--tb=no"],
            capture_output=True, text=True, timeout=120,
            cwd=str(PROJECT_ROOT / "functions"),
        )
        # Parse output like "288 passed, 0 failed"
        import re
        passed = len(re.findall(r'(\d+) passed', result.stdout))
        failed = len(re.findall(r'(\d+) failed', result.stdout))
        p_match = re.search(r'(\d+) passed', result.stdout)
        f_match = re.search(r'(\d+) failed', result.stdout)
        return (
            int(p_match.group(1)) if p_match else 0,
            int(f_match.group(1)) if f_match else 0,
        )
    except Exception:
        return 0, -1


def run_playwright_tests() -> tuple[int, int]:
    """Run Playwright tests and return (passed, failed)."""
    try:
        result = subprocess.run(
            ["npx", "playwright", "test", "--reporter=list", "--workers=1"],
            capture_output=True, text=True, timeout=600,
            cwd=str(PROJECT_ROOT / "e2e"),
        )
        import re
        p_match = re.search(r'(\d+) passed', result.stdout + result.stderr)
        f_match = re.search(r'(\d+) failed', result.stdout + result.stderr)
        return (
            int(p_match.group(1)) if p_match else 0,
            int(f_match.group(1)) if f_match else 0,
        )
    except Exception:
        return 0, -1


def generate_test_plan(findings: list) -> str:
    """Generate a test plan document from findings."""
    plan = ["# 🧪 OrignaGTA — Test Plan (Auto-Generated)", ""]
    plan.append(f"Generated: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M')}")
    plan.append("")

    # Group by priority
    for severity in [CRITICAL, HIGH, MEDIUM, LOW]:
        items = [f for f in findings if f.severity == severity]
        if not items:
            continue

        emoji = SEVERITY_EMOJI[severity]
        plan.append(f"## {emoji} {severity} Priority ({len(items)} items)")
        plan.append("")

        for i, f in enumerate(items, 1):
            plan.append(f"### {i}. {f.title}")
            plan.append(f"**File:** `{f.file}`")
            plan.append(f"**Category:** {f.category}")
            plan.append(f"{f.description}")
            if f.fix_suggestion:
                plan.append(f"\n**Action:** {f.fix_suggestion}")
            plan.append("")

    return "\n".join(plan)


def main():
    """Function main."""
    parser = argparse.ArgumentParser(
        description="🧪 QA Coverage Scanner — test health analysis (no LLM cost)"
    )
    parser.add_argument(
        "--run-tests",
        action="store_true",
        help="Actually run test suites to verify they pass",
    )
    parser.add_argument(
        "--generate-plan",
        action="store_true",
        help="Generate a test plan document from findings",
    )
    parser.add_argument(
        "--json", "-j",
        action="store_true",
        help="Output as JSON",
    )

    args = parser.parse_args()

    print(f"\n{'='*60}")
    print("🧪 QA COVERAGE SCANNER")
    print(f"{'='*60}\n")

    all_findings = []

    # Phase 1: Coverage scan
    print("📊 Scanning test coverage...")
    coverage_findings = _scan_test_coverage()
    all_findings.extend(coverage_findings)

    # Phase 2: Infrastructure check
    print("🔧 Checking test infrastructure...")
    infra_findings = _check_test_infrastructure()
    all_findings.extend(infra_findings)

    # Phase 3: Untested handlers
    print("🔍 Identifying untested handlers...")
    handler_findings = _identify_untested_handlers()
    all_findings.extend(handler_findings)

    # Phase 4: Critical flow coverage
    print("🎯 Checking critical flow coverage...")
    flow_findings = _check_critical_flow_coverage()
    all_findings.extend(flow_findings)

    # Phase 5: Run actual tests (optional)
    if args.run_tests:
        print("\n⏳ Running test suites...")

        print("  🐍 Python tests...")
        py_pass, py_fail = run_python_tests()
        if py_fail > 0:
            all_findings.append(type(coverage_findings[0])(
                severity=CRITICAL,
                title=f"Python tests: {py_fail} failed, {py_pass} passed",
                description="Backend tests are failing — fix before deploy",
                file="functions/tests/", category="qa-health",
            ))
        elif py_pass > 0:
            print(f"    ✅ {py_pass} passed")

        print("  🎭 Playwright E2E tests...")
        e2e_pass, e2e_fail = run_playwright_tests()
        if e2e_fail > 0:
            all_findings.append(type(coverage_findings[0])(
                severity=CRITICAL,
                title=f"E2E tests: {e2e_fail} failed, {e2e_pass} passed",
                description="E2E tests are failing — investigate immediately",
                file="e2e/", category="qa-health",
            ))
        elif e2e_pass > 0:
            print(f"    ✅ {e2e_pass} passed")

    # Print results
    print(f"\n{'─'*60}")
    print("📋 FINDINGS")
    print(f"{'─'*60}")

    for f in sorted(all_findings, key=lambda x: {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}.get(x.severity, 99)):
        emoji = SEVERITY_EMOJI.get(f.severity, "⚪")
        print(f"  {emoji} [{f.severity}] {f.title}")

    # Summary
    total = len(all_findings)
    total_c = sum(1 for f in all_findings if f.severity == CRITICAL)
    total_h = sum(1 for f in all_findings if f.severity == HIGH)
    total_m = sum(1 for f in all_findings if f.severity == MEDIUM)
    total_l = sum(1 for f in all_findings if f.severity == LOW)

    print(f"\n{'='*60}")
    print(f"📊 SUMMARY: {total} findings")
    print(f"   🔴 {total_c} Critical | 🟠 {total_h} High | 🟡 {total_m} Medium | 🟢 {total_l} Low")
    print(f"{'='*60}")

    # Generate test plan
    if args.generate_plan:
        plan = generate_test_plan(all_findings)
        plan_path = PROJECT_ROOT / "audit" / "output" / "test_plan.md"
        plan_path.parent.mkdir(parents=True, exist_ok=True)
        plan_path.write_text(plan)
        print(f"\n📝 Test plan written to: {plan_path}")

    # JSON output
    if args.json:
        output = {
            "timestamp": __import__("datetime").datetime.now().isoformat(),
            "summary": {
                "critical": total_c, "high": total_h,
                "medium": total_m, "low": total_l, "total": total,
            },
            "findings": [
                {
                    "severity": f.severity,
                    "title": f.title,
                    "description": f.description,
                    "file": f.file,
                    "category": f.category,
                    "fix_suggestion": f.fix_suggestion,
                }
                for f in all_findings
            ],
        }
        print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
