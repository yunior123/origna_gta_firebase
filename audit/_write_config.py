#!/usr/bin/env python3
"""Temporary script to rewrite config.py and __init__.py for Anthropic API."""
from pathlib import Path

hooks_dir = Path(__file__).parent / "hooks"

# ============================================================
# 1. Write config.py
# ============================================================
config_lines = [
    '"""Configuration for the Anthropic API audit hook system.',
    "",
    "Uses Anthropic API directly with Claude Opus 4 (claude-opus-4-20250514).",
    "Budget: $5 credit - be efficient with tokens.",
    "",
    "Pricing (Opus 4):",
    "  Input:  $15 / M tokens",
    "  Output: $75 / M tokens",
    "  -> ~$0.70 per audit, ~$1.00 per fix",
    "  -> Budget allows ~5-6 audit calls",
    '"""',
    "import os",
    "from pathlib import Path",
    "",
    "PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent",
    "",
    "# --- Anthropic API Configuration ---",
    "",
    'ANTHROPIC_MODEL = "claude-opus-4-20250514"  # Opus 4',
    "",
    "# Token limits - tight to protect your $5 budget",
    "MAX_OUTPUT_TOKENS = 4096       # Audit responses (~$0.31)",
    "MAX_OUTPUT_TOKENS_FIX = 8192   # Fixer needs more room (~$0.61)",
    "",
    "# --- Audit Settings ---",
    "",
    'CRITICAL = "CRITICAL"  # Must fix before production',
    'HIGH = "HIGH"          # Should fix before launch',
    'MEDIUM = "MEDIUM"      # Should fix soon',
    'LOW = "LOW"            # Nice to fix',
    "",
    "SEVERITY_ORDER = {CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3}",
    "",
    'OUTPUT_DIR = PROJECT_ROOT / "audit" / "output" / "hooks"',
    "",
    "# --- File Targeting ---",
    "",
    "MAX_CONTEXT_CHARS = 100_000  # ~25K tokens",
    "",
    "EXCLUDE_PATTERNS = {",
    '    ".git", "node_modules", "build", ".dart_tool", "__pycache__",',
    '    "venv", ".venv", "emulator-data", "test-results", "playwright-report",',
    '    "audit/output", ".firebase", ".pub-cache",',
    "}",
    "",
    "",
    "def load_api_key() -> str:",
    '    """Load Anthropic API key from env or functions/.env."""',
    '    key_name = "ANTHROPIC_API_KEY"',
    "",
    "    key = os.getenv(key_name)",
    "    if key:",
    "        return key",
    "",
    '    env_path = PROJECT_ROOT / "functions" / ".env"',
    "    if env_path.exists():",
    "        for line in env_path.read_text().splitlines():",
    "            line = line.strip()",
    '            if line.startswith("#") or "=" not in line:',
    "                continue",
    '            k, v = line.split("=", 1)',
    "            if k.strip() == key_name:",
    "                val = v.strip()",
    '                val = val.strip(' + repr('"') + ")",
    "                val = val.strip(" + repr("'") + ")",
    "                return val",
    "",
    "    raise RuntimeError(",
    '        f"{key_name} not found. Set it as env var or add to functions/.env"',
    "    )",
    "",
]

config_path = hooks_dir / "config.py"
config_path.write_text("\n".join(config_lines) + "\n")
print(f"OK wrote {config_path} ({len(config_lines)} lines)")

# ============================================================
# 2. Write __init__.py
# ============================================================
init_lines = [
    '"""',
    "audit.hooks - Composable Audit Hook System for OrignaGta",
    "=========================================================",
    "",
    "Uses Anthropic API directly with Claude Opus 4 (claude-opus-4-20250514).",
    "",
    "Usage:",
    "  python audit/run_hooks.py --list                   # List all hooks",
    "  python audit/run_hooks.py --hook schema-sync       # Run one hook",
    "  python audit/run_hooks.py --all                    # Run all hooks",
    "  python audit/run_hooks.py --hook payment --fix     # Auto-fix findings",
    "  python audit/run_hooks.py --hook payment --fix --dry-run  # Preview fixes",
    "",
    "Architecture:",
    "  config.py        -> Anthropic model config + API key loading",
    "  base.py          -> BaseHook, Finding, HookResult, registry",
    "  prompts.py       -> Shared prompt fragments",
    "  hook_domains.py  -> Payment, Auth, Product hooks",
    "  hook_schema_sync.py -> Schema sync validation",
    "  hook_extended.py -> Security, Perf, State, Orders, Errors, Seller hooks",
    "  fixer.py         -> AutoFixer (generates code patches via Opus 4)",
    "  runner.py        -> HookRunner (orchestration + reports)",
    '"""',
    "",
]

init_path = hooks_dir / "__init__.py"
init_path.write_text("\n".join(init_lines) + "\n")
print(f"OK wrote {init_path} ({len(init_lines)} lines)")

print("DONE - both files written successfully")
