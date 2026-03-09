"""
🧹 Code Quality Audit Hook

Integrates the standalone `scripts/code_quality_agent.py` into the
audit hooks ecosystem. Uses Anthropic API for deeper refactoring analysis
after running the local static checks.
"""
from __future__ import annotations

import subprocess
import sys
import time

from .base import BaseHook, Finding, HookResult, register_hook
from .config import PROJECT_ROOT
from .prompts import STRUCTURED_OUTPUT_INSTRUCTION, PROJECT_CONTEXT


@register_hook
class CodeQualityHook(BaseHook):
    """
    Code Quality hook that checks comments, refactoring opportunities,
    file organization, and obsolete files.
    """
    hook_name = "code-quality"
    description = "Code Quality: Comments, Refactoring, Organization & Cleanup"
    emoji = "🧹"

    watch_patterns = [
        "*.py",
        "*.dart",
    ]

    # Target key files for LLM deep refactoring scan
    target_files = [
        "functions/models/order.py",
        "functions/handlers/orders.py",
        "scripts/code_quality_agent.py",
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are a SENIOR STAFF ENGINEER focusing on Code Quality, Refactoring, and Maintainability.

{PROJECT_CONTEXT}

## Your Mission
1. **Comment Audit**: Review the code for missing, legacy (TODO/FIXME), or vague comments. Suggest concise, self-documenting code alternatives or exact `///` (Dart) and `\"\"\"` (Python) docstrings.
2. **Refactoring**: Identify duplicated logic, overly complex functions, or deep nesting.
   - **CRITICAL RULE**: NEVER suggest removing or altering business logic. Only suggest structural improvements (e.g. extracting helpers).
3. **Organization**: Check if files are in the right place according to the architecture.

## Deliverables
Provide a structured list of findings with specific, actionable fix suggestions.

{STRUCTURED_OUTPUT_INSTRUCTION}

Focus on HIGH/MEDIUM severity items that impact long-term maintainability.
"""

    def run(self, changed_only: list[str] | None = None) -> HookResult:
        """Run local checks via script, then LLM deep scan."""
        start = time.time()
        result = HookResult(hook_name=self.hook_name, status="success")

        print(f"\n{self.emoji} {self.hook_name}: Running Code Quality analysis...")

        # ── Phase 1: Local Analysis ──
        print("  📋 Phase 1: Running local code_quality_agent.py...")
        script_path = PROJECT_ROOT / "scripts" / "code_quality_agent.py"
        
        if script_path.exists():
            try:
                # Run the script in dry-run mode to just get findings, not move files
                res = subprocess.run(
                    [sys.executable, str(script_path), "--dry-run"],
                    capture_output=True, text=True, cwd=str(PROJECT_ROOT)
                )
                
                # Parse stdout for findings (basic parsing)
                # The script outputs in format: `  [SEVERITY] file:line — message`
                lines = res.stdout.splitlines()
                for line in lines:
                    line = line.strip()
                    if line.startswith("[CRITICAL]") or line.startswith("[HIGH]") or \
                       line.startswith("[MEDIUM]") or line.startswith("[LOW]") or \
                       line.startswith("[INFO]"):
                        
                        parts = line.split("]", 1)
                        if len(parts) == 2:
                            sev = parts[0][1:].strip()
                            rest = parts[1].strip()
                            
                            file_msg = rest.split(" — ", 1)
                            if len(file_msg) == 2:
                                file_line = file_msg[0].strip()
                                msg = file_msg[1].strip()
                                
                                # parse file:line
                                file_parts = file_line.split(":")
                                file_path = file_parts[0]
                                ln = int(file_parts[1]) if len(file_parts) > 1 and file_parts[1].isdigit() else None
                                
                                result.findings.append(Finding(
                                    category="local-qa", severity=sev, file=file_path,
                                    line=ln, title=msg[:80], description=msg
                                ))
                
                print(f"  ✅ Local phase found {len(result.findings)} issues")
                
            except Exception as e:
                print(f"  ⚠️  Failed to run local agent: {e}")

        # ── Phase 2: LLM Deep Analysis ──
        
        files = self.resolve_files(changed_only)
        if files:
            result.files_audited = len(files)
            print(f"  🤖 Phase 2: LLM deep analysis of {len(files)} files...")

            try:
                context = self.bundle_files(files)
                prompt = self.get_prompt()
                
                raw_response = self.call_llm(prompt, context)
                llm_findings = self.parse_findings(raw_response)
                
                result.findings.extend(llm_findings)
                result.markdown_report = raw_response
            except Exception as e:
                print(f"  ⚠️  LLM analysis skipped: {e}")
                if not result.markdown_report:
                    result.markdown_report = "LLM analysis failed."

        # Sort combined findings
        result.findings.sort(key=lambda f: f.severity_rank)
        result.duration_seconds = round(time.time() - start, 2)
        return result
