"""
audit.hooks - Composable Audit Hook System for OrignaGta
=========================================================

Uses Anthropic API directly with Claude Opus 4 (claude-opus-4-20250514).

Usage:
  python audit/run_hooks.py --list                   # List all hooks
  python audit/run_hooks.py --hook schema-sync       # Run one hook
  python audit/run_hooks.py --all                    # Run all hooks
  python audit/run_hooks.py --hook payment --fix     # Auto-fix findings
  python audit/run_hooks.py --hook payment --fix --dry-run  # Preview fixes

Architecture:
  config.py        -> Anthropic model config + API key loading
  base.py          -> BaseHook, Finding, HookResult, registry
  prompts.py       -> Shared prompt fragments
  hook_domains.py  -> Payment, Auth, Product hooks
  hook_schema_sync.py -> Schema sync validation
  hook_extended.py -> Security, Perf, State, Orders, Errors, Seller hooks
  fixer.py         -> AutoFixer (generates code patches via Opus 4)
  runner.py        -> HookRunner (orchestration + reports)
"""

