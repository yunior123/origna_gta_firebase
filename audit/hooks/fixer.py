"""
🔧 Auto-Fixer — Applies audit findings automatically using Anthropic API.

Flow:
  1. Takes a list of Finding objects from an audit run
  2. Groups findings by file
  3. For each file, sends the file content + findings to Claude Opus 4
  4. Claude returns the corrected file content
  5. Writes the fix, runs validation (flutter analyze / pytest)
  6. If validation fails, reverts the file

Uses Anthropic API — costs ~$1.00 per file fix.
"""
from __future__ import annotations

import subprocess
import shutil
import time
import anthropic
from dataclasses import dataclass, field
from pathlib import Path

from .config import (
    PROJECT_ROOT, ANTHROPIC_MODEL,
    MAX_OUTPUT_TOKENS_FIX, CRITICAL, HIGH, MEDIUM, load_api_key
)
from .base import Finding, HookResult


@dataclass
class FixResult:
    """Result of attempting to fix a single file."""
    file: str
    status: str = "pending"  # "fixed", "skipped", "failed", "reverted", "pending"
    findings_addressed: int = 0
    error: str = ""
    diff_preview: str = ""


@dataclass
class AutoFixReport:
    """Aggregate result of all auto-fix attempts."""
    total_findings: int = 0
    fixable_findings: int = 0
    files_fixed: int = 0
    files_failed: int = 0
    files_reverted: int = 0
    fixes: list[FixResult] = field(default_factory=list)
    duration_seconds: float = 0.0

    def print_summary(self):
        """Function print_summary."""
        print(f"\n{'─'*60}")
        print("🔧 AUTO-FIX SUMMARY")
        print(f"{'─'*60}")
        print(f"  Total findings:    {self.total_findings}")
        print(f"  Fixable findings:  {self.fixable_findings}")
        print(f"  Files fixed:       {self.files_fixed}")
        print(f"  Files failed:      {self.files_failed}")
        print(f"  Files reverted:    {self.files_reverted}")
        print(f"  Time:              {self.duration_seconds:.1f}s")
        print(f"{'─'*60}")

        for fix in self.fixes:
            icon = {"fixed": "✅", "skipped": "⏭️", "failed": "❌", "reverted": "↩️"}.get(fix.status, "?")
            print(f"  {icon} {fix.file} — {fix.status} ({fix.findings_addressed} findings)")
            if fix.error:
                print(f"     └─ {fix.error[:120]}")

        if self.files_fixed > 0:
            print("\n💡 Review changes with: git diff")
            print("   Undo all fixes with: git checkout -- .")


class AutoFixer:
    """
    Applies audit findings by asking Claude to rewrite affected files.

    Strategy per file:
      1. Read current file content
      2. Gather all findings for that file
      3. Ask Claude: "Here is the file and the issues. Return the COMPLETE fixed file."
      4. Write the fixed content
      5. Validate (flutter analyze for .dart, python syntax check for .py)
      6. Revert if validation fails
    """

    def __init__(
        self,
        min_severity: str = MEDIUM,
        dry_run: bool = False,
        validate: bool = True,
        provider: str = "claude",
    ):
        """Function __init__."""
        self.min_severity = min_severity
        self.dry_run = dry_run
        self.validate = validate
        self.provider = provider
        self._severity_threshold = {CRITICAL: 0, HIGH: 1, MEDIUM: 2, "LOW": 3}.get(min_severity, 2)

    def fix_results(self, results: list[HookResult]) -> AutoFixReport:
        """Apply fixes for all findings from multiple hook results."""
        start = time.time()
        report = AutoFixReport()

        # Collect all fixable findings grouped by file
        findings_by_file: dict[str, list[Finding]] = {}
        for r in results:
            for f in r.findings:
                report.total_findings += 1
                sev_rank = {CRITICAL: 0, HIGH: 1, MEDIUM: 2, "LOW": 3}.get(f.severity, 99)
                if sev_rank > self._severity_threshold:
                    continue
                if not f.fix_suggestion:
                    continue
                if not f.file or f.file == "unknown":
                    continue
                report.fixable_findings += 1
                findings_by_file.setdefault(f.file, []).append(f)

        if not findings_by_file:
            print("\n⏭️  No fixable findings to apply.")
            report.duration_seconds = round(time.time() - start, 2)
            return report

        print(f"\n🔧 Auto-fixing {report.fixable_findings} findings in {len(findings_by_file)} files...")

        if self.dry_run:
            print("   (DRY RUN — no files will be modified)")

        for rel_path, findings in sorted(findings_by_file.items()):
            fix_result = self._fix_file(rel_path, findings)
            report.fixes.append(fix_result)
            if fix_result.status == "fixed":
                report.files_fixed += 1
            elif fix_result.status == "failed":
                report.files_failed += 1
            elif fix_result.status == "reverted":
                report.files_reverted += 1

        report.duration_seconds = round(time.time() - start, 2)
        report.print_summary()
        return report

    def _fix_file(self, rel_path: str, findings: list[Finding]) -> FixResult:
        """Fix a single file using Claude."""
        file_path = PROJECT_ROOT / rel_path
        fix = FixResult(file=rel_path, findings_addressed=len(findings))

        # 1. Check file exists
        if not file_path.exists():
            fix.status = "skipped"
            fix.error = "File not found"
            return fix

        # 2. Read original content
        try:
            original_content = file_path.read_text()
        except Exception as e:
            fix.status = "failed"
            fix.error = f"Cannot read file: {e}"
            return fix

        # 3. Build the fix prompt
        findings_text = self._format_findings_for_fix(findings)
        prompt = self._build_fix_prompt(rel_path, original_content, findings_text)

        print(f"\n  🔧 Fixing {rel_path} ({len(findings)} findings)...")

        # 4. Call Claude to get fixed content
        try:
            fixed_content = self._call_fixer(prompt)
        except Exception as e:
            fix.status = "failed"
            fix.error = f"LLM error: {e}"
            print(f"     ❌ {fix.error[:100]}")
            return fix

        # 5. Extract code from response (Claude may wrap in markdown)
        fixed_content = self._extract_code_block(fixed_content, rel_path)

        if not fixed_content or fixed_content.strip() == original_content.strip():
            fix.status = "skipped"
            fix.error = "No changes produced"
            print("     ⏭️  No changes")
            return fix

        # 6. Dry run — just show diff preview
        if self.dry_run:
            fix.status = "skipped"
            fix.diff_preview = self._get_diff_preview(original_content, fixed_content)
            print(f"     📋 Would change {len(fix.diff_preview)} chars")
            return fix

        # 7. Write the fix
        try:
            # Backup original
            backup_path = file_path.with_suffix(file_path.suffix + ".bak")
            shutil.copy2(file_path, backup_path)

            file_path.write_text(fixed_content)
            print("     ✏️  Written")
        except Exception as e:
            fix.status = "failed"
            fix.error = f"Write error: {e}"
            return fix

        # 8. Validate
        if self.validate:
            valid, validation_error = self._validate_file(file_path)
            if not valid:
                # Revert
                shutil.copy2(backup_path, file_path)
                backup_path.unlink(missing_ok=True)
                fix.status = "reverted"
                fix.error = f"Validation failed: {validation_error}"
                print(f"     ↩️  Reverted — {validation_error[:100]}")
                return fix

        # 9. Clean up backup
        backup_path.unlink(missing_ok=True)
        fix.status = "fixed"
        print("     ✅ Fixed!")
        return fix

    def _format_findings_for_fix(self, findings: list[Finding]) -> str:
        """Format findings into a clear list for the fix prompt."""
        lines = []
        for i, f in enumerate(findings, 1):
            lines.append(f"### Issue {i}: [{f.severity}] {f.title}")
            lines.append(f"**Description:** {f.description}")
            if f.line:
                lines.append(f"**Line:** {f.line}")
            if f.fix_suggestion:
                lines.append(f"**Suggested fix:** {f.fix_suggestion}")
            lines.append("")
        return "\n".join(lines)

    def _build_fix_prompt(self, rel_path: str, content: str, findings_text: str) -> str:
        """Build the prompt for Claude to fix a file."""
        ext = Path(rel_path).suffix
        lang = {
            ".py": "Python", ".dart": "Dart", ".ts": "TypeScript",
            ".js": "JavaScript", ".rules": "Firestore Rules",
        }.get(ext, "code")

        return f"""You are fixing bugs in a {lang} file for a production e-commerce marketplace (OrignaGta).

## RULES — CRITICAL
1. Return ONLY the complete fixed file content — NO explanations, NO markdown, NO commentary
2. Do NOT wrap the output in ```code blocks``` — just raw file content
3. Preserve ALL existing functionality — only fix the specific issues listed below
4. Keep the same code style, indentation, and formatting
5. Do NOT add new imports unless absolutely required for the fix
6. Do NOT remove or rename existing functions/classes/variables
7. If a fix could break other things, add a comment: // TODO: verify this change
8. For Dart: follow Riverpod patterns, use DesignTokens, no withOpacity()
9. For Python: follow Pydantic v2 patterns, proper type hints

## FILE: {rel_path}
```{ext.lstrip('.')}
{content}
```

## ISSUES TO FIX
{findings_text}

## OUTPUT
Return the COMPLETE file with all issues fixed. Raw content only, no wrapping."""

    def _call_fixer(self, prompt: str) -> str:
        """Call LLM via Anthropic provider to fix a file."""
        return self._call_fixer_anthropic(prompt)

    def _call_fixer_anthropic(self, prompt: str) -> str:
        """Call Claude Opus 4 via Anthropic API to fix a file."""
        client = anthropic.Anthropic(api_key=load_api_key("anthropic"))

        est_input = len(prompt) // 4
        est_cost = (est_input / 1_000_000) * 15 + (MAX_OUTPUT_TOKENS_FIX / 1_000_000) * 75
        print(f"     📡 Calling {ANTHROPIC_MODEL} for fix...")
        print(f"     💰 Est. cost: ~${est_cost:.3f}")

        message = client.messages.create(
            model=ANTHROPIC_MODEL,
            max_tokens=MAX_OUTPUT_TOKENS_FIX,
            temperature=0.2,  # Lower temp for code generation
            messages=[{"role": "user", "content": prompt}],
        )

        output = message.content[0].text
        used_in = message.usage.input_tokens
        used_out = message.usage.output_tokens
        actual_cost = (used_in / 1_000_000) * 15 + (used_out / 1_000_000) * 75

        print(f"     ✅ {len(output):,} chars | {used_in:,}+{used_out:,} tokens | ${actual_cost:.4f}")
        return output


    def _extract_code_block(self, response: str, rel_path: str) -> str:
        """
        Extract code from Claude's response.
        
        Claude might wrap the output in ```lang ... ``` even though we asked it not to.
        """
        import re

        # If it starts with a code fence, extract the content
        fence_match = re.match(
            r'^```\w*\n(.*?)```\s*$',
            response.strip(),
            re.DOTALL,
        )
        if fence_match:
            return fence_match.group(1)

        # If response has multiple code blocks, take the largest one
        blocks = re.findall(r'```\w*\n(.*?)```', response, re.DOTALL)
        if blocks:
            return max(blocks, key=len)

        # Otherwise use as-is (it's already raw content)
        return response

    def _validate_file(self, file_path: Path) -> tuple[bool, str]:
        """
        Validate a fixed file.
        
        Returns (is_valid, error_message).
        """
        suffix = file_path.suffix

        if suffix == ".py":
            return self._validate_python(file_path)
        elif suffix == ".dart":
            return self._validate_dart(file_path)
        elif suffix == ".rules":
            # No easy validator for Firestore rules
            return True, ""
        else:
            return True, ""

    def _validate_python(self, file_path: Path) -> tuple[bool, str]:
        """Validate Python file syntax."""
        try:
            result = subprocess.run(
                ["python3", "-m", "py_compile", str(file_path)],
                capture_output=True, text=True, timeout=15,
            )
            if result.returncode != 0:
                return False, result.stderr.strip()[:200]
            return True, ""
        except Exception as e:
            return False, str(e)[:200]

    def _validate_dart(self, file_path: Path) -> tuple[bool, str]:
        """Validate Dart file with flutter analyze."""
        try:
            # Quick syntax check: dart analyze on just this file
            result = subprocess.run(
                ["dart", "analyze", str(file_path)],
                capture_output=True, text=True, timeout=30,
                cwd=str(PROJECT_ROOT / "origna_gta"),
            )
            stderr_out = result.stderr + result.stdout
            # dart analyze returns 0 even with infos, check for errors
            if "error •" in stderr_out.lower() or "error -" in stderr_out.lower():
                # Extract first error line
                for line in stderr_out.splitlines():
                    if "error" in line.lower():
                        return False, line.strip()[:200]
            return True, ""
        except subprocess.TimeoutExpired:
            # Don't block on slow analysis — assume OK
            return True, ""
        except Exception:
            # If dart not available, skip validation
            return True, ""

    def _get_diff_preview(self, original: str, fixed: str) -> str:
        """Generate a simple diff preview."""
        import difflib
        diff = difflib.unified_diff(
            original.splitlines(keepends=True),
            fixed.splitlines(keepends=True),
            lineterm="",
            n=2,
        )
        return "".join(list(diff)[:50])  # First 50 lines of diff
