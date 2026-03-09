"""Configuration for the Anthropic API audit hook system.

Uses Anthropic API directly with Claude Opus 4 (claude-opus-4-20250514).
Budget: $5 credit - be efficient with tokens.

Pricing (Opus 4):
  Input:  $15 / M tokens
  Output: $75 / M tokens
  -> ~$0.70 per audit, ~$1.00 per fix
  -> Budget allows ~5-6 audit calls
"""
import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent

# --- Anthropic API Configuration ---

ANTHROPIC_MODEL = "claude-opus-4-20250514"  # Opus 4



# --- Token limits ---
MAX_OUTPUT_TOKENS = 16384      # Audit responses (enough for full JSON findings)
MAX_OUTPUT_TOKENS_FIX = 8192   # Fixer needs more room (~$0.61)

# --- Audit Settings ---

CRITICAL = "CRITICAL"  # Must fix before production
HIGH = "HIGH"          # Should fix before launch
MEDIUM = "MEDIUM"      # Should fix soon
LOW = "LOW"            # Nice to fix

SEVERITY_ORDER = {CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3}

OUTPUT_DIR = PROJECT_ROOT / "audit" / "output" / "hooks"

# --- File Targeting ---

MAX_CONTEXT_CHARS = 100_000  # ~25K tokens

EXCLUDE_PATTERNS = {
    ".git", "node_modules", "build", ".dart_tool", "__pycache__",
    "venv", ".venv", "emulator-data", "test-results", "playwright-report",
    "audit/output", ".firebase", ".pub-cache",
}


def load_api_key(provider: str = "anthropic") -> str:
    """Load API key from env or functions/.env."""
    key_name = "ANTHROPIC_API_KEY"

    key = os.getenv(key_name)
    if key:
        return key

    env_path = PROJECT_ROOT / "functions" / ".env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            if k.strip() == key_name:
                val = v.strip()
                val = val.strip('"')
                val = val.strip("'")
                return val

    raise RuntimeError(
        f"{key_name} not found. Set it as env var or add to functions/.env"
    )

