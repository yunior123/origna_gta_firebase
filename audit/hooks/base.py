"""
Base hook class — all audit hooks inherit from this.

Each hook declares:
  - name & description
  - which files it watches (glob patterns)
  - the audit prompt
  - severity thresholds

Uses Anthropic API directly with Claude Opus 4.
"""
from __future__ import annotations

import json
import re
import subprocess
import anthropic
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from .config import (
    PROJECT_ROOT, ANTHROPIC_MODEL, MAX_OUTPUT_TOKENS,
    CRITICAL, HIGH, MEDIUM, LOW, SEVERITY_ORDER,
    MAX_CONTEXT_CHARS, load_api_key,
)

# ─── Registry ─────────────────────────────────────────────────────────────────

_HOOK_REGISTRY: dict[str, type[BaseHook]] = {}


def register_hook(cls):
    """Class decorator to register a hook in the global registry."""
    _HOOK_REGISTRY[cls.hook_name] = cls
    return cls


def get_all_hooks() -> dict[str, type[BaseHook]]:
    """Function get_all_hooks."""
    return dict(_HOOK_REGISTRY)


def get_hook(name: str) -> type[BaseHook]:
    """Function get_hook."""
    if name not in _HOOK_REGISTRY:
        available = ", ".join(sorted(_HOOK_REGISTRY.keys()))
        raise KeyError(f"Unknown hook '{name}'. Available: {available}")
    return _HOOK_REGISTRY[name]


# ─── Data Classes ─────────────────────────────────────────────────────────────

@dataclass
class Finding:
    """A single audit finding."""
    severity: str           # CRITICAL, HIGH, MEDIUM, LOW
    title: str              # Short summary
    description: str        # Detailed explanation
    file: str               # Affected file (relative path)
    line: Optional[int] = None      # Line number if applicable
    fix_suggestion: str = ""        # Suggested code fix
    category: str = ""              # e.g. "security", "logic", "performance"

    def to_dict(self) -> dict:
        """Function to_dict."""
        return {
            "severity": self.severity,
            "title": self.title,
            "description": self.description,
            "file": self.file,
            "line": self.line,
            "fix_suggestion": self.fix_suggestion,
            "category": self.category,
        }

    @property
    def severity_rank(self) -> int:
        """Function severity_rank."""
        return SEVERITY_ORDER.get(self.severity, 99)


@dataclass
class HookResult:
    """Result from running a single hook."""
    hook_name: str
    status: str             # "success", "error", "skipped"
    findings: list[Finding] = field(default_factory=list)
    markdown_report: str = ""
    error: str = ""
    duration_seconds: float = 0.0
    files_audited: int = 0

    @property
    def critical_count(self) -> int:
        """Function critical_count."""
        return sum(1 for f in self.findings if f.severity == CRITICAL)

    @property
    def high_count(self) -> int:
        """Function high_count."""
        return sum(1 for f in self.findings if f.severity == HIGH)

    def to_dict(self) -> dict:
        """Function to_dict."""
        return {
            "hook_name": self.hook_name,
            "status": self.status,
            "findings": [f.to_dict() for f in self.findings],
            "error": self.error,
            "duration_seconds": self.duration_seconds,
            "files_audited": self.files_audited,
            "summary": {
                "critical": self.critical_count,
                "high": self.high_count,
                "medium": sum(1 for f in self.findings if f.severity == MEDIUM),
                "low": sum(1 for f in self.findings if f.severity == LOW),
                "total": len(self.findings),
            },
        }


# ─── Base Hook ────────────────────────────────────────────────────────────────

class BaseHook(ABC):
    """
    Abstract base for all audit hooks.

    Subclass and override:
      - hook_name: unique identifier
      - description: human-readable description
      - watch_patterns: list of file glob patterns this hook cares about
      - target_files: list of specific files to always include
      - get_prompt(): return the audit prompt
    """
    hook_name: str = "base"
    description: str = "Base audit hook"
    emoji: str = "🔍"

    # Files this hook monitors (glob patterns relative to PROJECT_ROOT)
    watch_patterns: list[str] = []

    # Specific files to always include in this audit
    target_files: list[str] = []

    def __init__(self, provider: str = "anthropic"):
        """Function __init__."""
        self.provider = provider
        self._client: anthropic.Anthropic | None = None

    def _get_client(self) -> anthropic.Anthropic:
        """Lazy-init Anthropic client."""
        if self._client is None:
            self._client = anthropic.Anthropic(api_key=load_api_key(self.provider))
        return self._client

    # ── Abstract ──────────────────────────────────────────────────────────

    @abstractmethod
    def get_prompt(self) -> str:
        """Return the audit system prompt for this hook."""
        ...

    # ── File Targeting ────────────────────────────────────────────────────

    def matches_file(self, filepath: str) -> bool:
        """Check if a file path matches this hook's watch patterns."""
        from fnmatch import fnmatch
        rel = filepath
        for pattern in self.watch_patterns:
            if fnmatch(rel, pattern):
                return True
        return False

    def resolve_files(self, changed_only: list[str] | None = None) -> list[Path]:
        """
        Get the list of files to audit.

        If changed_only is provided, intersect with watch_patterns.
        Otherwise, use target_files.
        """
        files = []

        if changed_only is not None:
            # Git-diff mode: only audit changed files that match our patterns
            for f in changed_only:
                if self.matches_file(f):
                    path = PROJECT_ROOT / f
                    if path.exists():
                        files.append(path)
            # Always include critical context files even in changed-only mode
            for f in self.target_files[:5]:  # First 5 are considered "core context"
                path = PROJECT_ROOT / f
                if path.exists() and path not in files:
                    files.append(path)
        else:
            # Full mode: use all target files
            for f in self.target_files:
                path = PROJECT_ROOT / f
                if path.exists():
                    files.append(path)

        return files

    def bundle_files(self, files: list[Path]) -> str:
        """Bundle file contents into a single string."""
        content = []
        total = 0

        for path in files:
            try:
                text = path.read_text(errors="ignore")
            except Exception:
                continue

            try:
                rel = path.relative_to(PROJECT_ROOT)
            except ValueError:
                rel = path

            block = f"\n\n### FILE: {rel}\n```\n{text}\n```"
            if total + len(block) > MAX_CONTEXT_CHARS:
                remaining = len(files) - len(content)
                content.append(
                    f"\n\n[TRUNCATED — {remaining} files omitted due to size limit]"
                )
                break
            content.append(block)
            total += len(block)

        return "".join(content)

    # ── LLM Call ──────────────────────────────────────────────────────────
    # Anthropic API with Claude Opus 4 — direct, no fallback needed

    def call_llm(self, prompt: str, context: str) -> str:
        """
        Call LLM via Anthropic API.
        """
        return self._call_anthropic(prompt, context)

    def _call_anthropic(self, prompt: str, context: str) -> str:
        """Call Claude via Anthropic API with system/user message split.

        The audit prompt goes into `system` (cached, instruction-focused) and
        the bundled code files go into the `user` message. This gives better
        instruction-following than concatenating both into a single user turn.
        """
        client = self._get_client()

        # Estimate tokens (~4 chars/token) and cost
        est_input_tokens = (len(prompt) + len(context)) // 4
        est_cost = (est_input_tokens / 1_000_000) * 15 + (MAX_OUTPUT_TOKENS / 1_000_000) * 75

        print(f"  📡 Calling {ANTHROPIC_MODEL}...")
        print(f"  📦 System: {len(prompt):,} chars | Context: {len(context):,} chars (~{est_input_tokens:,} tokens)")
        print(f"  💰 Est. cost: ~${est_cost:.3f}")

        stream = client.messages.create(
            model=ANTHROPIC_MODEL,
            max_tokens=MAX_OUTPUT_TOKENS,
            temperature=0.3,
            system=prompt,
            messages=[{"role": "user", "content": context}],
            stream=True,
        )

        output = ""
        used_in = 0
        used_out = 0
        
        for event in stream:
            if event.type == "content_block_delta":
                output += event.delta.text
            elif event.type == "message_start":
                used_in = event.message.usage.input_tokens
            elif event.type == "message_delta":
                used_out = event.usage.output_tokens
        actual_cost = (used_in / 1_000_000) * 15 + (used_out / 1_000_000) * 75

        print(f"  ✅ {len(output):,} chars | {used_in:,} in + {used_out:,} out tokens")
        print(f"  💰 Actual cost: ${actual_cost:.4f}")
        return output


    # ── Parsing ───────────────────────────────────────────────────────────

    def parse_findings(self, raw_response: str) -> list[Finding]:
        """
        Parse structured findings from the LLM response.

        Handles truncated JSON (when max_tokens cuts off the response).
        Falls back to individual JSON object extraction, then regex.
        """
        findings = []

        def _parse_item(item: dict) -> Finding:
            return Finding(
                severity=item.get("severity", MEDIUM),
                title=item.get("title", "Untitled"),
                description=item.get("description", ""),
                file=item.get("file", "unknown"),
                line=item.get("line"),
                fix_suggestion=item.get("fix_suggestion", ""),
                category=item.get("category", ""),
            )

        # Strategy 1: Look for ```json ... ``` block (complete or truncated)
        json_match = re.search(
            r'```json\s*\n(\[.*?)(?:\]\s*\n```|$)',
            raw_response,
            re.DOTALL,
        )
        if json_match:
            json_text = json_match.group(1)
            # Ensure the array is properly closed
            if not json_text.rstrip().endswith(']'):
                # Truncated JSON — repair by closing open objects/array
                json_text = json_text.rstrip().rstrip(',')
                if json_text.count('"') % 2 != 0:
                    json_text += '"'
                open_braces = json_text.count('{') - json_text.count('}')
                json_text += '}' * max(0, open_braces)
                json_text += ']'
            else:
                json_text += ']'  # We captured without the ]

            try:
                items = json.loads(json_text)
                for item in items:
                    findings.append(_parse_item(item))
                if findings:
                    return findings
            except json.JSONDecodeError:
                pass

        # Strategy 2: Extract individual JSON objects {...} with severity field
        obj_pattern = re.compile(
            r'\{[^{}]*"severity"\s*:\s*"(CRITICAL|HIGH|MEDIUM|LOW)"[^{}]*\}',
            re.DOTALL | re.IGNORECASE,
        )
        for match in obj_pattern.finditer(raw_response):
            try:
                item = json.loads(match.group(0))
                findings.append(_parse_item(item))
            except json.JSONDecodeError:
                continue

        if findings:
            return findings

        # Strategy 3: Regex extraction from markdown
        pattern = re.compile(
            r'\*\*?(CRITICAL|HIGH|MEDIUM|LOW)\*?\*?\s*[|:\u2014\u2013-]\s*'
            r'[`"]?([^`"\n|]+?)[`"]?\s*[|:\u2014\u2013-]\s*'
            r'(.+?)(?=\n\*\*?(?:CRITICAL|HIGH|MEDIUM|LOW)|\n#{1,3}\s|\Z)',
            re.DOTALL | re.IGNORECASE,
        )
        for match in pattern.finditer(raw_response):
            severity = match.group(1).upper()
            file_ref = match.group(2).strip()
            desc = match.group(3).strip()
            findings.append(Finding(
                severity=severity,
                title=desc[:80],
                description=desc,
                file=file_ref,
                category="general",
            ))

        return findings

    # ── Main Run ──────────────────────────────────────────────────────────

    def run(self, changed_only: list[str] | None = None) -> HookResult:
        """
        Execute this audit hook.

        Args:
            changed_only: If provided, list of changed file paths (relative to PROJECT_ROOT).
                         Only files matching this hook's watch_patterns will be audited.

        Returns:
            HookResult with findings and report.
        """
        import time
        start = time.time()

        result = HookResult(hook_name=self.hook_name, status="success")

        try:
            # 1. Resolve files
            files = self.resolve_files(changed_only)
            if not files:
                result.status = "skipped"
                result.error = "No matching files to audit"
                return result

            result.files_audited = len(files)
            print(f"\n{self.emoji} {self.hook_name}: Auditing {len(files)} files...")

            # 2. Bundle files
            context = self.bundle_files(files)
            print(f"  📦 Context: {len(context):,} chars")

            # 3. Get prompt
            prompt = self.get_prompt()

            # 4. Call LLM
            raw_response = self.call_llm(prompt, context)

            # 5. Parse findings
            result.findings = self.parse_findings(raw_response)
            result.markdown_report = raw_response

            # Sort by severity
            result.findings.sort(key=lambda f: f.severity_rank)

        except Exception as e:
            result.status = "error"
            result.error = str(e)
            print(f"  ❌ Error: {e}")

        result.duration_seconds = round(time.time() - start, 2)
        return result


# ─── Utility: Get Changed Files ──────────────────────────────────────────────

def get_git_changed_files(staged_only: bool = False) -> list[str]:
    """Get list of changed files from git (relative to PROJECT_ROOT)."""
    try:
        if staged_only:
            cmd = ["git", "diff", "--cached", "--name-only"]
        else:
            cmd = ["git", "diff", "--name-only", "HEAD"]
        result = subprocess.run(
            cmd, capture_output=True, text=True, cwd=str(PROJECT_ROOT),
        )
        if result.returncode != 0:
            # Fallback: unstaged changes
            result = subprocess.run(
                ["git", "diff", "--name-only"],
                capture_output=True, text=True, cwd=str(PROJECT_ROOT),
            )
        files = [f.strip() for f in result.stdout.strip().split("\n") if f.strip()]

        # Also include untracked files
        untracked = subprocess.run(
            ["git", "ls-files", "--others", "--exclude-standard"],
            capture_output=True, text=True, cwd=str(PROJECT_ROOT),
        )
        if untracked.returncode == 0:
            files += [f.strip() for f in untracked.stdout.strip().split("\n") if f.strip()]

        # Deduplicate
        return list(dict.fromkeys(files))
    except Exception:
        return []
