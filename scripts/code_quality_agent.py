#!/usr/bin/env python3
"""
🧹 Code Quality Agent — Comments, Refactoring, Organization & Cleanup

Standalone agent that:
  1. Audits and improves comments in Dart and Python files
  2. Flags safe refactoring opportunities (never removes logic)
  3. Checks file/folder organization against best practices
  4. Collects garbage files and moves them to ~/Desktop/trash/

Usage:
  python scripts/code_quality_agent.py                  # Full run (all tasks)
  python scripts/code_quality_agent.py --comments       # Comments audit only
  python scripts/code_quality_agent.py --refactor       # Refactoring scan only
  python scripts/code_quality_agent.py --organize       # Organization check only
  python scripts/code_quality_agent.py --trash          # Trash collection only
  python scripts/code_quality_agent.py --dry-run        # Preview without moving files
"""
from __future__ import annotations

import argparse
import ast
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRASH_DIR = Path.home() / "Desktop" / "OrignaGta_Trash"

# Directories to skip when scanning source files
SKIP_DIRS = {
    ".git", "node_modules", "build", ".dart_tool", "__pycache__",
    "venv", ".venv", "emulator-data", "test-results", "playwright-report",
    ".firebase", ".pub-cache", "Pods", ".symlinks", "ios", "macos",
    "android", "windows", "linux", "web", ".worktrees",
}

# ═══════════════════════════════════════════════════════════════════════════════
# DATA CLASSES
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class Finding:
    """A single code quality finding."""
    category: str       # comments, refactor, organize, trash
    severity: str       # CRITICAL, HIGH, MEDIUM, LOW, INFO
    file: str           # Relative path
    line: int | None    # Line number
    message: str        # Description
    suggestion: str = ""  # Fix suggestion

    def __str__(self) -> str:
        """Function __str__."""
        loc = f"{self.file}:{self.line}" if self.line else self.file
        return f"  [{self.severity}] {loc} — {self.message}"


@dataclass
class AgentReport:
    """Aggregate results from all agent tasks."""
    findings: list[Finding] = field(default_factory=list)
    files_moved: list[tuple[str, str]] = field(default_factory=list)
    comments_added: int = 0
    comments_fixed: int = 0
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())

    def print_summary(self):
        """Function print_summary."""
        by_cat = {}
        for f in self.findings:
            by_cat.setdefault(f.category, []).append(f)

        print(f"\n{'=' * 60}")
        print("🧹 CODE QUALITY AGENT — REPORT")
        print(f"{'=' * 60}")
        print(f"   Timestamp: {self.timestamp}")
        print(f"   Total findings: {len(self.findings)}")

        for cat, items in sorted(by_cat.items()):
            sev_counts = {}
            for i in items:
                sev_counts[i.severity] = sev_counts.get(i.severity, 0) + 1
            sev_str = ", ".join(f"{v} {k}" for k, v in sorted(sev_counts.items()))
            print(f"\n   📋 {cat.upper()} ({len(items)} findings: {sev_str})")
            for item in items[:15]:
                print(f"   {item}")
            if len(items) > 15:
                print(f"      ... and {len(items) - 15} more")

        if self.files_moved:
            print(f"\n   🗑️  Files moved to trash: {len(self.files_moved)}")
            for src, _ in self.files_moved[:20]:
                print(f"      • {src}")
            if len(self.files_moved) > 20:
                print(f"      ... and {len(self.files_moved) - 20} more")

        print(f"\n{'=' * 60}")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. COMMENT AUDITOR
# ═══════════════════════════════════════════════════════════════════════════════

def _iter_source_files(extensions: list[str]) -> list[Path]:
    """Iterate source files in the project, skipping non-relevant dirs."""
    results = []
    for ext in extensions:
        for path in PROJECT_ROOT.rglob(f"*{ext}"):
            # Skip directories we don't care about
            parts = set(path.relative_to(PROJECT_ROOT).parts)
            if parts & SKIP_DIRS:
                continue
            results.append(path)
    return sorted(results)


def _audit_python_comments(filepath: Path) -> list[Finding]:
    """Audit comments and docstrings in a Python file."""
    findings = []
    rel = str(filepath.relative_to(PROJECT_ROOT))
    try:
        source = filepath.read_text(errors="ignore")
    except Exception:
        return findings

    lines = source.splitlines()

    # Check for module-level docstring
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return findings

    if not ast.get_docstring(tree):
        findings.append(Finding(
            category="comments", severity="MEDIUM", file=rel, line=1,
            message="Missing module-level docstring",
            suggestion="Add a brief docstring describing the module's purpose",
        ))

    # Check functions and classes for docstrings
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            # Skip private/test helpers
            if node.name.startswith("_") and not node.name.startswith("__"):
                continue
            if not ast.get_docstring(node):
                findings.append(Finding(
                    category="comments", severity="LOW", file=rel,
                    line=node.lineno,
                    message=f"Function '{node.name}' missing docstring",
                    suggestion="Add docstring: what it does, params, returns",
                ))
        elif isinstance(node, ast.ClassDef):
            if not ast.get_docstring(node):
                findings.append(Finding(
                    category="comments", severity="MEDIUM", file=rel,
                    line=node.lineno,
                    message=f"Class '{node.name}' missing docstring",
                    suggestion="Add docstring describing the class purpose",
                ))

    # Check for legacy/stale comments
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        # Commented-out code (heuristic: line starts with # and contains code patterns)
        if re.match(r"^#\s*(def |class |import |from |if |for |return |print\()", stripped):
            findings.append(Finding(
                category="comments", severity="HIGH", file=rel, line=i,
                message="Commented-out code detected",
                suggestion="Remove commented-out code — use git history instead",
            ))
        # Stale TODO/FIXME/HACK/XXX markers
        if re.search(r"#\s*(TODO|FIXME|HACK|XXX)\b", stripped, re.IGNORECASE):
            findings.append(Finding(
                category="comments", severity="LOW", file=rel, line=i,
                message=f"Stale marker: {stripped[:80]}",
                suggestion="Resolve or create a task for this item",
            ))

    return findings


def _audit_dart_comments(filepath: Path) -> list[Finding]:
    """Audit comments and documentation in a Dart file."""
    findings = []
    rel = str(filepath.relative_to(PROJECT_ROOT))
    try:
        source = filepath.read_text(errors="ignore")
    except Exception:
        return findings

    lines = source.splitlines()

    # Check for public classes/functions without doc comments
    for i, line in enumerate(lines, 1):
        stripped = line.strip()

        # Public class without preceding doc comment
        if re.match(r"^class\s+[A-Z]", stripped):
            has_doc = False
            if i >= 2:
                prev = lines[i - 2].strip()
                if prev.startswith("///") or prev.endswith("*/"):
                    has_doc = True
            if not has_doc:
                class_name = re.match(r"class\s+(\w+)", stripped)
                name = class_name.group(1) if class_name else "unknown"
                findings.append(Finding(
                    category="comments", severity="MEDIUM", file=rel, line=i,
                    message=f"Public class '{name}' missing doc comment",
                    suggestion=f"Add /// doc comment above class '{name}'",
                ))

        # Commented-out code
        if re.match(r"^\s*//\s*(class |Widget |void |Future |final |var |return |import )", line):
            findings.append(Finding(
                category="comments", severity="HIGH", file=rel, line=i,
                message="Commented-out code detected",
                suggestion="Remove commented-out code — use git history instead",
            ))

        # Stale TODO/FIXME/HACK
        if re.search(r"//\s*(TODO|FIXME|HACK|XXX)\b", stripped, re.IGNORECASE):
            findings.append(Finding(
                category="comments", severity="LOW", file=rel, line=i,
                message=f"Stale marker: {stripped[:80]}",
                suggestion="Resolve or create a task for this item",
            ))

    return findings


def audit_comments() -> list[Finding]:
    """Run comment audit across all Dart and Python source files."""
    print("\n📝 Phase 1: Auditing comments...")
    findings = []

    py_files = _iter_source_files([".py"])
    dart_files = _iter_source_files([".dart"])

    for f in py_files:
        findings.extend(_audit_python_comments(f))
    for f in dart_files:
        findings.extend(_audit_dart_comments(f))

    print(f"   Scanned {len(py_files)} Python + {len(dart_files)} Dart files")
    print(f"   Found {len(findings)} comment issues")
    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# 2. REFACTORING SCANNER
# ═══════════════════════════════════════════════════════════════════════════════

def _check_function_complexity(filepath: Path) -> list[Finding]:
    """Check Python functions for high complexity."""
    findings = []
    rel = str(filepath.relative_to(PROJECT_ROOT))
    try:
        source = filepath.read_text(errors="ignore")
        tree = ast.parse(source)
    except Exception:
        return findings

    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            # Count branches as a rough complexity measure
            branches = sum(
                1 for child in ast.walk(node)
                if isinstance(child, (ast.If, ast.For, ast.While, ast.Try, ast.ExceptHandler))
            )
            # Count lines
            end_line = getattr(node, "end_lineno", node.lineno + 20)
            func_lines = end_line - node.lineno

            if branches > 10:
                findings.append(Finding(
                    category="refactor", severity="HIGH", file=rel,
                    line=node.lineno,
                    message=f"Function '{node.name}' has high complexity ({branches} branches, {func_lines} lines)",
                    suggestion="Consider extracting helper functions to reduce complexity",
                ))
            elif func_lines > 80:
                findings.append(Finding(
                    category="refactor", severity="MEDIUM", file=rel,
                    line=node.lineno,
                    message=f"Function '{node.name}' is very long ({func_lines} lines)",
                    suggestion="Consider breaking into smaller functions for readability",
                ))

    return findings


def _check_dart_complexity(filepath: Path) -> list[Finding]:
    """Check Dart files for long functions and deep nesting."""
    findings = []
    rel = str(filepath.relative_to(PROJECT_ROOT))
    try:
        lines = filepath.read_text(errors="ignore").splitlines()
    except Exception:
        return findings

    # Track function lengths by counting braces
    func_start = None
    func_name = ""
    brace_depth = 0

    for i, line in enumerate(lines, 1):
        stripped = line.strip()

        # Detect function/method start
        func_match = re.match(
            r"^\s*(?:static\s+)?(?:Future<[^>]+>|void|Widget|String|int|double|bool|List|Map|dynamic)\s+(\w+)\s*\(",
            line,
        )
        if func_match and func_start is None:
            func_start = i
            func_name = func_match.group(1)
            brace_depth = 0

        # Count braces
        brace_depth += stripped.count("{") - stripped.count("}")

        # Function end
        if func_start and brace_depth <= 0 and i > func_start:
            func_len = i - func_start
            if func_len > 100:
                findings.append(Finding(
                    category="refactor", severity="MEDIUM", file=rel,
                    line=func_start,
                    message=f"Function '{func_name}' is very long ({func_len} lines)",
                    suggestion="Consider extracting sub-widgets or helper methods",
                ))
            func_start = None
            func_name = ""

        # Deep nesting check
        indent = len(line) - len(line.lstrip())
        if indent >= 24 and stripped and not stripped.startswith("//"):
            findings.append(Finding(
                category="refactor", severity="LOW", file=rel, line=i,
                message=f"Deep nesting detected (indent level {indent // 2})",
                suggestion="Consider early returns or extracting to separate methods",
            ))

    return findings


def scan_refactoring() -> list[Finding]:
    """Scan for safe refactoring opportunities."""
    print("\n🔧 Phase 2: Scanning for refactoring opportunities...")
    findings = []

    # Run ruff on Python code (if available)
    ruff_path = PROJECT_ROOT / "functions"
    try:
        result = subprocess.run(
            ["ruff", "check", "--select", "F401,F841,E501", "--format", "text", "."],
            capture_output=True, text=True, cwd=str(ruff_path), timeout=30,
        )
        for line in result.stdout.strip().splitlines():
            if ":" in line:
                findings.append(Finding(
                    category="refactor", severity="LOW",
                    file=f"functions/{line.split(':')[0]}",
                    line=None, message=f"Ruff: {line}",
                ))
    except (FileNotFoundError, subprocess.TimeoutExpired):
        print("   ⚠️  ruff not found — skipping Python lint check")

    # Complexity checks
    for f in _iter_source_files([".py"]):
        # Only check main source, skip tests/generated
        rel = str(f.relative_to(PROJECT_ROOT))
        if "/tests/" in rel or "/test/" in rel or ".g.dart" in rel or ".freezed.dart" in rel:
            continue
        findings.extend(_check_function_complexity(f))

    for f in _iter_source_files([".dart"]):
        rel = str(f.relative_to(PROJECT_ROOT))
        if "/test/" in rel or ".g.dart" in rel or ".freezed.dart" in rel:
            continue
        findings.extend(_check_dart_complexity(f))

    print(f"   Found {len(findings)} refactoring suggestions")
    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# 3. FILE / FOLDER ORGANIZATION CHECKER
# ═══════════════════════════════════════════════════════════════════════════════

# Expected Dart structure under origna_gta/lib/
DART_EXPECTED_DIRS = {
    "screens", "widgets", "providers", "models", "services",
    "utils", "constants", "themes", "l10n",
}

# Expected Python structure under functions/
PYTHON_EXPECTED_DIRS = {
    "handlers", "models", "services", "utils", "tests",
}


def check_organization() -> list[Finding]:
    """Check file and folder organization against best practices."""
    print("\n📁 Phase 3: Checking file/folder organization...")
    findings = []

    # -- Dart structure --
    dart_lib = PROJECT_ROOT / "origna_gta" / "lib"
    if dart_lib.exists():
        actual_dirs = {d.name for d in dart_lib.iterdir() if d.is_dir()}
        missing = DART_EXPECTED_DIRS - actual_dirs
        for d in missing:
            findings.append(Finding(
                category="organize", severity="INFO",
                file=f"origna_gta/lib/{d}/", line=None,
                message=f"Expected directory '{d}/' not found in lib/",
                suggestion=f"Create origna_gta/lib/{d}/ for better organization",
            ))

        # Check for Dart files directly in lib/ (should be in subdirs)
        root_dart_files = [f for f in dart_lib.glob("*.dart") if f.name != "main.dart"]
        for f in root_dart_files:
            findings.append(Finding(
                category="organize", severity="LOW",
                file=str(f.relative_to(PROJECT_ROOT)), line=None,
                message=f"Dart file '{f.name}' at lib/ root — should be in a subdirectory",
                suggestion="Move to appropriate subdirectory (screens/, widgets/, etc.)",
            ))

    # -- Python structure --
    py_root = PROJECT_ROOT / "functions"
    if py_root.exists():
        actual_dirs = {d.name for d in py_root.iterdir() if d.is_dir() and not d.name.startswith(".")}
        missing = PYTHON_EXPECTED_DIRS - actual_dirs
        for d in missing:
            findings.append(Finding(
                category="organize", severity="INFO",
                file=f"functions/{d}/", line=None,
                message=f"Expected directory '{d}/' not found in functions/",
                suggestion=f"Create functions/{d}/ for better organization",
            ))

        # Check for stray Python files at project root
        root_py_files = [
            f for f in PROJECT_ROOT.glob("*.py")
            if f.name not in {"smart_audit.py", "audit_translations.py"}
        ]
        for f in root_py_files:
            findings.append(Finding(
                category="organize", severity="LOW",
                file=str(f.relative_to(PROJECT_ROOT)), line=None,
                message=f"Python file '{f.name}' at project root — consider moving",
                suggestion="Move to scripts/ or appropriate directory",
            ))

    # -- Check for misplaced test files --
    for f in _iter_source_files([".py"]):
        rel = str(f.relative_to(PROJECT_ROOT))
        if f.name.startswith("test_") and "/tests/" not in rel and "/test/" not in rel:
            findings.append(Finding(
                category="organize", severity="MEDIUM",
                file=rel, line=None,
                message=f"Test file '{f.name}' is outside a tests/ directory",
                suggestion="Move to the appropriate tests/ directory",
            ))

    print(f"   Found {len(findings)} organization issues")
    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# 4. TRASH COLLECTOR
# ═══════════════════════════════════════════════════════════════════════════════

def _move_to_trash(src: Path, dry_run: bool = False) -> tuple[str, str] | None:
    """Move a file or directory to ~/Desktop/trash/, preserving relative path."""
    try:
        rel = src.relative_to(PROJECT_ROOT)
    except ValueError:
        rel = Path(src.name)

    dest = TRASH_DIR / rel
    src_str = str(rel)
    dest_str = str(dest)

    if dry_run:
        print(f"   [DRY-RUN] Would move: {src_str} → {dest_str}")
        return (src_str, dest_str)

    dest.parent.mkdir(parents=True, exist_ok=True)

    # Handle name conflicts
    if dest.exists():
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        stem = dest.stem
        suffix = dest.suffix
        dest = dest.with_name(f"{stem}_{ts}{suffix}")

    try:
        shutil.move(str(src), str(dest))
        print(f"   🗑️  {src_str} → {dest}")
        return (src_str, str(dest))
    except Exception as e:
        print(f"   ⚠️  Failed to move {src_str}: {e}")
        return None


def collect_trash(dry_run: bool = False) -> tuple[list[Finding], list[tuple[str, str]]]:
    """Identify and move obsolete files to ~/Desktop/trash/."""
    print("\n🗑️  Phase 4: Collecting trash...")
    findings = []
    moved = []

    if not dry_run:
        TRASH_DIR.mkdir(parents=True, exist_ok=True)
        print(f"   Trash directory: {TRASH_DIR}")

    # 1. _archived/ contents
    archived_dir = PROJECT_ROOT / "_archived"
    if archived_dir.exists():
        for item in archived_dir.iterdir():
            if item.name == ".gitkeep":
                continue
            findings.append(Finding(
                category="trash", severity="INFO",
                file=str(item.relative_to(PROJECT_ROOT)), line=None,
                message=f"Archived content: {item.name}",
            ))
            result = _move_to_trash(item, dry_run)
            if result:
                moved.append(result)

    # 2. Obsolete audit reports (keep only latest, trash timestamped ones)
    hooks_output = PROJECT_ROOT / "audit" / "output" / "hooks"
    if hooks_output.exists():
        timestamped = sorted([
            f for f in hooks_output.iterdir()
            if re.match(r"hooks_report_\d{8}_\d{6}\.", f.name)
        ])
        # Keep the latest 2, trash the rest
        for f in timestamped[:-2]:
            findings.append(Finding(
                category="trash", severity="INFO",
                file=str(f.relative_to(PROJECT_ROOT)), line=None,
                message=f"Obsolete audit report: {f.name}",
            ))
            result = _move_to_trash(f, dry_run)
            if result:
                moved.append(result)

    # 3. firebase-export-* temp directories
    for d in PROJECT_ROOT.glob("firebase-export-*"):
        if d.is_dir():
            findings.append(Finding(
                category="trash", severity="INFO",
                file=str(d.relative_to(PROJECT_ROOT)), line=None,
                message=f"Firebase export temp directory: {d.name}",
            ))
            result = _move_to_trash(d, dry_run)
            if result:
                moved.append(result)

    # 4. Stale cache directories at project root
    for cache_name in ["__pycache__", ".pytest_cache", ".ruff_cache"]:
        cache_dir = PROJECT_ROOT / cache_name
        if cache_dir.exists():
            findings.append(Finding(
                category="trash", severity="INFO",
                file=cache_name, line=None,
                message=f"Stale cache directory: {cache_name}",
            ))
            result = _move_to_trash(cache_dir, dry_run)
            if result:
                moved.append(result)

    # 5. Obsolete/unused docs — check if referenced anywhere
    docs_dir = PROJECT_ROOT / "docs"
    if docs_dir.exists():
        # Read all source files to check references
        all_source = ""
        for ext in [".py", ".dart", ".ts", ".md", ".yaml", ".json", ".sh"]:
            for f in PROJECT_ROOT.rglob(f"*{ext}"):
                parts = set(f.relative_to(PROJECT_ROOT).parts)
                if parts & SKIP_DIRS:
                    continue
                try:
                    all_source += f.read_text(errors="ignore")
                except Exception:
                    pass

        # Check each doc — if stem is never referenced, it might be obsolete
        # Be conservative: only flag specific known-obsolete patterns
        obsolete_patterns = [
            "IMPROVEMENTS_SUMMARY",  # One-time improvement docs
        ]
        for doc in docs_dir.glob("*.md"):
            stem = doc.stem
            if stem in obsolete_patterns:
                findings.append(Finding(
                    category="trash", severity="LOW",
                    file=str(doc.relative_to(PROJECT_ROOT)), line=None,
                    message=f"Potentially obsolete doc: {doc.name}",
                ))
                result = _move_to_trash(doc, dry_run)
                if result:
                    moved.append(result)

    # 6. Log files at project root
    for log_file in PROJECT_ROOT.glob("*.log"):
        findings.append(Finding(
            category="trash", severity="INFO",
            file=str(log_file.relative_to(PROJECT_ROOT)), line=None,
            message=f"Log file: {log_file.name}",
        ))
        result = _move_to_trash(log_file, dry_run)
        if result:
            moved.append(result)

    # 7. Stale ui-debug.log in subdirectories
    for log_file in PROJECT_ROOT.rglob("ui-debug.log"):
        rel = str(log_file.relative_to(PROJECT_ROOT))
        parts = set(log_file.relative_to(PROJECT_ROOT).parts)
        if parts & SKIP_DIRS:
            continue
        findings.append(Finding(
            category="trash", severity="INFO",
            file=rel, line=None,
            message=f"Debug log: {log_file.name}",
        ))
        result = _move_to_trash(log_file, dry_run)
        if result:
            moved.append(result)

    # 8. .DS_Store files
    for ds_store in PROJECT_ROOT.rglob(".DS_Store"):
        rel_parts = set(ds_store.relative_to(PROJECT_ROOT).parts)
        if rel_parts & SKIP_DIRS:
            continue
        result = _move_to_trash(ds_store, dry_run)
        if result:
            moved.append(result)

    print(f"   Found {len(findings)} items to clean up")
    print(f"   {'Would move' if dry_run else 'Moved'} {len(moved)} items to trash")
    return findings, moved


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    """Function main."""
    parser = argparse.ArgumentParser(
        description="🧹 Code Quality Agent — Comments, Refactoring, Organization & Cleanup",
    )
    parser.add_argument("--comments", action="store_true", help="Run comment audit only")
    parser.add_argument("--refactor", action="store_true", help="Run refactoring scan only")
    parser.add_argument("--organize", action="store_true", help="Run organization check only")
    parser.add_argument("--trash", action="store_true", help="Run trash collection only")
    parser.add_argument("--dry-run", action="store_true", help="Preview without moving files")

    args = parser.parse_args()
    run_all = not (args.comments or args.refactor or args.organize or args.trash)

    report = AgentReport()

    print(f"\n{'=' * 60}")
    print("🧹 CODE QUALITY AGENT")
    print(f"{'=' * 60}")
    print(f"   Project: {PROJECT_ROOT}")
    print(f"   Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")

    # Phase 1: Comments
    if run_all or args.comments:
        report.findings.extend(audit_comments())

    # Phase 2: Refactoring
    if run_all or args.refactor:
        report.findings.extend(scan_refactoring())

    # Phase 3: Organization
    if run_all or args.organize:
        report.findings.extend(check_organization())

    # Phase 4: Trash
    if run_all or args.trash:
        trash_findings, moved = collect_trash(dry_run=args.dry_run)
        report.findings.extend(trash_findings)
        report.files_moved = moved

    report.print_summary()

    # Save report
    report_dir = PROJECT_ROOT / "audit" / "output"
    report_dir.mkdir(parents=True, exist_ok=True)
    report_path = report_dir / "code_quality_report.md"

    with open(report_path, "w") as f:
        f.write("# 🧹 Code Quality Agent Report\n\n")
        f.write(f"**Generated:** {report.timestamp}\n\n")
        for cat in ["comments", "refactor", "organize", "trash"]:
            items = [i for i in report.findings if i.category == cat]
            if items:
                f.write(f"\n## {cat.upper()} ({len(items)} findings)\n\n")
                for item in items:
                    f.write(f"- **[{item.severity}]** `{item.file}`")
                    if item.line:
                        f.write(f":{item.line}")
                    f.write(f" — {item.message}\n")
                    if item.suggestion:
                        f.write(f"  - 💡 {item.suggestion}\n")
        if report.files_moved:
            f.write(f"\n## FILES MOVED TO TRASH ({len(report.files_moved)})\n\n")
            for src, dest in report.files_moved:
                f.write(f"- `{src}` → `{dest}`\n")

    print(f"\n📄 Report saved: {report_path.relative_to(PROJECT_ROOT)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
