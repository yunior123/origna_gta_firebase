"""
Hook Runner — Discovers, orchestrates, and reports on audit hooks.

Features:
  • Parallel execution of independent hooks
  • Git-diff aware (audit only changed files)
  • JSON + Markdown reports
  • Aggregated dashboard view
  • Pre-commit mode (fail-fast on CRITICAL/HIGH)
"""
from __future__ import annotations

import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

from .config import (
    OUTPUT_DIR, PROJECT_ROOT, CRITICAL, MEDIUM, ANTHROPIC_MODEL
)
from .base import (
    BaseHook, HookResult, get_all_hooks, get_git_changed_files,
)
from .fixer import AutoFixer, AutoFixReport


class HookRunner:
    """Discovers and runs audit hooks, produces reports."""

    def __init__(
        self,
        hooks: list[str] | None = None,
        changed_only: bool = False,
        staged_only: bool = False,
        parallel: bool = True,
        max_workers: int = 3,
    ):
        """Function __init__."""
        self.changed_only = changed_only
        self.staged_only = staged_only
        self.parallel = parallel
        self.max_workers = max_workers
        self.max_workers = max_workers
        self.results: list[HookResult] = []

        # Resolve which hooks to run
        all_hooks = get_all_hooks()
        if hooks:
            self.hook_classes = []
            for name in hooks:
                name = name.strip()
                if name in all_hooks:
                    self.hook_classes.append(all_hooks[name])
                else:
                    available = ", ".join(sorted(all_hooks.keys()))
                    print(f"⚠️  Unknown hook: '{name}'. Available: {available}")
        else:
            self.hook_classes = list(all_hooks.values())

    def run(self) -> list[HookResult]:
        """Execute all configured hooks and return results."""
        # Get changed files if needed
        changed_files: list[str] | None = None
        if self.changed_only:
            changed_files = get_git_changed_files(staged_only=self.staged_only)
            if not changed_files:
                print("✅ No changed files detected — nothing to audit.")
                return []
            print(f"📂 {len(changed_files)} changed files detected")
            for f in changed_files[:20]:
                print(f"   • {f}")
            if len(changed_files) > 20:
                print(f"   ... and {len(changed_files) - 20} more")

        # Instantiate hooks
        hook_instances = [cls() for cls in self.hook_classes]

        model_name = ANTHROPIC_MODEL
        print(f"\n{'='*60}")
        print(f"🪝 Running {len(hook_instances)} audit hook(s)")
        print(f"   Model: {model_name}")
        print(f"   Mode: {'changed files only' if self.changed_only else 'full codebase'}")
        print(f"{'='*60}")

        start = time.time()

        if self.parallel and len(hook_instances) > 1:
            self.results = self._run_parallel(hook_instances, changed_files)
        else:
            self.results = self._run_sequential(hook_instances, changed_files)

        elapsed = round(time.time() - start, 1)
        print(f"\n{'='*60}")
        print(f"⏱️  Total time: {elapsed}s")
        self._print_dashboard()

        return self.results

    def _run_sequential(
        self, hooks: list[BaseHook], changed_files: list[str] | None,
    ) -> list[HookResult]:
        results = []
        for hook in hooks:
            result = hook.run(changed_only=changed_files)
            results.append(result)
        return results

    def _run_parallel(
        self, hooks: list[BaseHook], changed_files: list[str] | None,
    ) -> list[HookResult]:
        results = []
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = {
                executor.submit(hook.run, changed_files): hook
                for hook in hooks
            }
            for future in as_completed(futures):
                hook = futures[future]
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    results.append(HookResult(
                        hook_name=hook.hook_name,
                        status="error",
                        error=str(e),
                    ))
        return results

    # ── Dashboard ─────────────────────────────────────────────────────────

    def _print_dashboard(self):
        """Print a summary dashboard of all hook results."""
        total_findings = 0
        total_critical = 0
        total_high = 0

        print(f"\n{'─'*60}")
        print("📊 AUDIT DASHBOARD")
        print(f"{'─'*60}")
        print(f"{'Hook':<25} {'Status':<10} {'🔴':<4} {'🟠':<4} {'🟡':<4} {'🟢':<4} {'Time':<8}")
        print(f"{'─'*60}")

        for r in sorted(self.results, key=lambda x: x.hook_name):
            if r.status == "skipped":
                print(f"{r.hook_name:<25} {'SKIP':<10} {'—':<4} {'—':<4} {'—':<4} {'—':<4} {'—':<8}")
                continue
            if r.status == "error":
                print(f"{r.hook_name:<25} {'ERROR':<10} {'—':<4} {'—':<4} {'—':<4} {'—':<4} {'—':<8}")
                continue

            c = sum(1 for f in r.findings if f.severity == "CRITICAL")
            h = sum(1 for f in r.findings if f.severity == "HIGH")
            m = sum(1 for f in r.findings if f.severity == "MEDIUM")
            lo = sum(1 for f in r.findings if f.severity == "LOW")
            total_findings += len(r.findings)
            total_critical += c
            total_high += h

            print(
                f"{r.hook_name:<25} {'OK':<10} "
                f"{c:<4} {h:<4} {m:<4} {lo:<4} "
                f"{r.duration_seconds:<8.1f}s"
            )

        print(f"{'─'*60}")
        print(
            f"{'TOTAL':<25} {'':10} "
            f"{total_critical:<4} {total_high:<4} "
            f"{'':4} {'':4} "
        )

        if total_critical > 0:
            print(f"\n🚨 {total_critical} CRITICAL finding(s) — FIX BEFORE PRODUCTION!")
        if total_high > 0:
            print(f"⚠️  {total_high} HIGH finding(s) — should fix before launch")

    # ── Reports ───────────────────────────────────────────────────────────

    def save_reports(self) -> Path:
        """Save JSON + Markdown reports to output directory."""
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # JSON report (machine-readable)
        json_path = OUTPUT_DIR / f"hooks_report_{timestamp}.json"
        json_data = {
            "timestamp": datetime.now().isoformat(),
            "mode": "changed_only" if self.changed_only else "full",
            "results": [r.to_dict() for r in self.results],
        }
        json_path.write_text(json.dumps(json_data, indent=2))

        # Markdown report (human-readable)
        md_path = OUTPUT_DIR / f"hooks_report_{timestamp}.md"
        md_latest = OUTPUT_DIR / "hooks_report.md"
        md_content = self._generate_markdown_report()
        md_path.write_text(md_content)
        md_latest.write_text(md_content)

        # Also save latest JSON
        json_latest = OUTPUT_DIR / "hooks_report.json"
        json_latest.write_text(json.dumps(json_data, indent=2))

        print("\n📄 Reports saved:")
        print(f"   JSON: {json_path.relative_to(PROJECT_ROOT)}")
        print(f"   MD:   {md_path.relative_to(PROJECT_ROOT)}")

        return md_path

    def _generate_markdown_report(self) -> str:
        """Generate a combined Markdown report from all hook results."""
        lines = [
            "# 🪝 Audit Hooks Report\n",
            f"**Generated:** {datetime.now().isoformat()}",
            f"**Mode:** {'Changed files only' if self.changed_only else 'Full codebase'}\n",
            "---\n",
        ]

        # Summary table
        lines.append("## 📊 Summary\n")
        lines.append("| Hook | Status | 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low | Time |")
        lines.append("|------|--------|-------------|---------|-----------|--------|------|")
        for r in self.results:
            if r.status != "success":
                lines.append(f"| {r.hook_name} | {r.status} | — | — | — | — | — |")
                continue
            c = sum(1 for f in r.findings if f.severity == "CRITICAL")
            h = sum(1 for f in r.findings if f.severity == "HIGH")
            m = sum(1 for f in r.findings if f.severity == "MEDIUM")
            lo = sum(1 for f in r.findings if f.severity == "LOW")
            lines.append(
                f"| {r.hook_name} | ✅ | {c} | {h} | {m} | {lo} | {r.duration_seconds}s |"
            )
        lines.append("")

        # Detailed findings per hook
        for r in self.results:
            if r.status != "success" or not r.markdown_report:
                continue
            lines.append(f"\n---\n\n## {r.hook_name}\n")
            lines.append(r.markdown_report)

        return "\n".join(lines)

    # ── Pre-commit Mode ───────────────────────────────────────────────────

    def fix_findings(
        self,
        min_severity: str = MEDIUM,
        dry_run: bool = False,
        validate: bool = True,
    ) -> AutoFixReport:
        """
        Auto-fix findings using Claude CLI.

        Call this AFTER run() — uses the stored results.
        """
        if not self.results:
            print("⚠️  No audit results to fix. Run audit first.")
            return AutoFixReport()

        fixer = AutoFixer(
            min_severity=min_severity,
            dry_run=dry_run,
            validate=validate,
        )
        return fixer.fix_results(self.results)

    def check_pre_commit(self) -> bool:
        """
        Check if findings should block a commit.

        Returns True if commit is OK, False if it should be blocked.
        """
        for r in self.results:
            if r.critical_count > 0:
                print(f"\n🚫 COMMIT BLOCKED — {r.critical_count} CRITICAL finding(s) in {r.hook_name}")
                for f in r.findings:
                    if f.severity == CRITICAL:
                        print(f"   🔴 {f.title}: {f.file}")
                return False
        return True
