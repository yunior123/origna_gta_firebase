#!/usr/bin/env python3
"""
🪝 Audit Hooks CLI — Claude-powered, composable code audit system.

Usage:
  python audit/run_hooks.py                           # Run all hooks (full codebase)
  python audit/run_hooks.py --changed                 # Run only on git-changed files
  python audit/run_hooks.py --hook payment            # Run specific hook
  python audit/run_hooks.py --hook payment,auth       # Run multiple hooks
  python audit/run_hooks.py --pre-commit              # Pre-commit mode (fast)
  python audit/run_hooks.py --list                    # List all available hooks
  python audit/run_hooks.py --sequential              # Disable parallel execution
  python audit/run_hooks.py --hook schema-sync --no-llm  # Fast local-only check

  # AUTO-FIX MODE (new!)
  python audit/run_hooks.py --fix                     # Audit all → auto-fix findings
  python audit/run_hooks.py --hook payment --fix      # Audit payment → auto-fix
  python audit/run_hooks.py --fix --dry-run           # Preview fixes without writing
  python audit/run_hooks.py --fix --min-severity HIGH # Only fix HIGH+ findings

Examples:
  # Quick pre-commit check on staged files
  python audit/run_hooks.py --pre-commit

  # Deep payment audit with Claude
  python audit/run_hooks.py --hook payment

  # Full audit on all changed files since last commit
  python audit/run_hooks.py --changed

  # Audit & auto-fix all payment issues
  python audit/run_hooks.py --hook payment --fix

  # Preview what would be fixed without changing files
  python audit/run_hooks.py --changed --fix --dry-run

  # Schema sync check (fast, no API call for basic mismatches)
  python audit/run_hooks.py --hook schema-sync
"""
import argparse
import sys
from pathlib import Path

# Add audit directory to path
sys.path.insert(0, str(Path(__file__).resolve().parent))

# Import hooks — this triggers registration via @register_hook
from hooks.base import get_all_hooks
from hooks.runner import HookRunner


def main():
    """Function main."""
    parser = argparse.ArgumentParser(
        description="🪝 OrignaGta Audit Hooks — Claude-powered code auditing",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Available hooks:
  payment       💳 Payment system (Stripe Connect, checkout, webhooks)
  auth          🔐 Authentication & authorization (MFA, roles, rules)
  product       📦 Product lifecycle (creation, cart, stock, Algolia)
  schema-sync   🔄 Cross-stack schema consistency (Python ↔ Dart ↔ JSON)
  security      🛡️  API security (Firestore rules, injection, IDOR)
  performance   ⚡ Performance & scaling (N+1, indexes, cold starts)
  state-mgmt    🧠 State management (Riverpod, providers, race conditions)
  orders        📋 Order lifecycle (status machine, shipping, cancellation)
  errors        🛡️  Error handling (retries, graceful degradation, Sentry)
  seller        🏪 Seller onboarding (Stripe Connect, verification, payouts)
  tax           🧾 Tax compliance (GST/HST/PST/QST, Stripe Tax, CRA compliance)
  infra         🏗️  Infrastructure verification (Functions, Rules, Indexes, Stripe, Secrets)
  qa            🧪 QA Engineer (test coverage, gap detection, framework recommendations)
  code-quality  🧹 Code Quality: Comments, Refactoring, Organization & Cleanup
        """,
    )

    parser.add_argument(
        "--hook", "-H",
        help="Comma-separated list of hooks to run (default: all)",
    )
    parser.add_argument(
        "--changed", "-c",
        action="store_true",
        help="Only audit git-changed files",
    )
    parser.add_argument(
        "--pre-commit",
        action="store_true",
        help="Pre-commit mode: audit staged files, block on CRITICAL findings",
    )
    parser.add_argument(
        "--staged",
        action="store_true",
        help="Only audit git-staged files",
    )
    parser.add_argument(
        "--list", "-l",
        action="store_true",
        help="List all available hooks and exit",
    )
    parser.add_argument(
        "--no-validate",
        action="store_true",
        help="Skip validation after applying fixes",
    )
    parser.add_argument(
        "--sequential",
        action="store_true",
        help="Disable parallel execution",
    )
    parser.add_argument(
        "--no-report",
        action="store_true",
        help="Do not save reports to disk",
    )
    parser.add_argument(
        "--fix",
        action="store_true",
        help="Automatically apply fixes for findings",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview fixes without writing to files",
    )
    parser.add_argument(
        "--min-severity",
        choices=["LOW", "MEDIUM", "HIGH", "CRITICAL"],
        default="LOW",
        help="Minimum severity level to fix",
    )

    args = parser.parse_args()

    # List hooks
    if args.list:
        print("\n🪝 Available Audit Hooks:\n")
        for name, cls in sorted(get_all_hooks().items()):
            inst = cls()
            print(f"  {inst.emoji} {name:<18} {inst.description}")
            print(f"     Watch: {', '.join(inst.watch_patterns[:3])}")
            print()
        return

    # Parse hooks
    hooks = None
    if args.hook:
        hooks = [h.strip() for h in args.hook.split(",")]

    # Pre-commit mode
    if args.pre_commit:
        args.changed = True
        args.staged = True
        # In pre-commit, only run fast hooks by default
        if not hooks:
            hooks = ["schema-sync", "security", "payment", "code-quality"]

    runner = HookRunner(
        hooks=hooks,
        changed_only=args.changed or args.staged,
        staged_only=args.staged,
        parallel=not args.sequential,
    )

    results = runner.run()

    # Save reports
    if not args.no_report and results:
        runner.save_reports()

    # Auto-fix mode
    if args.fix and results:
        fix_report = runner.fix_findings(
            min_severity=args.min_severity,
            dry_run=args.dry_run,
            validate=not args.no_validate,
        )
        if fix_report.files_fixed > 0:
            print(f"\n🔧 {fix_report.files_fixed} file(s) fixed automatically.")
            print("   Review changes with: git diff")
            print("   Undo all with:       git checkout -- .")

    # Pre-commit check
    if args.pre_commit:
        if not runner.check_pre_commit():
            sys.exit(1)
        print("\n✅ Pre-commit check passed!")

    # Exit with error if any CRITICAL findings
    total_critical = sum(r.critical_count for r in results)
    if total_critical > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
