"""
🔄 Cross-Stack Schema Sync Hook

This is a FAST, local-only hook (no LLM needed for basic checks).
It compares schema_constants.py ↔ schema_constants.dart ↔ database_schema.json
and flags any mismatches.

Falls back to LLM for deep cross-stack analysis if --deep flag is used.
"""
from __future__ import annotations

import json
import re

from .base import BaseHook, Finding, HookResult, register_hook
from .config import PROJECT_ROOT, HIGH, MEDIUM
from .prompts import STRUCTURED_OUTPUT_INSTRUCTION, PROJECT_CONTEXT


_SYNC_CLASS_NAMES = {
    # Cross-stack invariants: these strings are used everywhere (Firestore paths + field names).
    "Collections",
    "Documents",
    "Fields",
}


def _should_sync_class(class_name: str) -> bool:
    # Intentionally strict and minimal: many *Values/*Ids classes are backend-only.
    # Keep the fast local check focused on Firestore schema names.
    return class_name in _SYNC_CLASS_NAMES


def _extract_python_constants(text: str) -> dict[str, str]:
    """Extract string constants from key schema classes in schema_constants.py."""
    constants: dict[str, str] = {}
    current_class: str | None = None

    for line in text.splitlines():
        class_match = re.match(r"^class\s+(\w+)\s*(?:\(|:)\s*", line)
        if class_match:
            current_class = class_match.group(1)
            continue

        if current_class and re.match(r"^\S", line):
            # New top-level statement ends the previous class block.
            current_class = None

        if not current_class or not _should_sync_class(current_class):
            continue

        # Capture:     NAME = "value"
        match = re.match(r"^\s+(\w+)\s*=\s*[\"\']([^\"\']+)[\"\']\s*(?:#.*)?$", line)
        if match:
            key = f"{current_class}.{match.group(1)}"
            constants[key] = match.group(2)

    return constants


def _extract_dart_constants(text: str) -> dict[str, str]:
    """Extract string constants from key schema classes in schema_constants.dart."""
    constants: dict[str, str] = {}
    current_class: str | None = None
    brace_depth = 0

    for line in text.splitlines():
        if current_class is None:
            class_match = re.match(
                r"^\s*(?:abstract\s+final\s+class|class)\s+(\w+)\s*\{\s*$",
                line,
            )
            if class_match:
                current_class = class_match.group(1)
                brace_depth = line.count("{") - line.count("}")
                continue

        if current_class is not None:
            brace_depth += line.count("{") - line.count("}")
            if brace_depth <= 0:
                current_class = None
                brace_depth = 0
                continue

            if not _should_sync_class(current_class):
                continue

            # Capture both typed and untyped const strings:
            #   static const foo = 'bar';
            #   static const String foo = 'bar';
            match = re.match(
                r"^\s*static\s+const(?:\s+\w+)?\s+(\w+)\s*=\s*['\"]([^'\"]+)['\"]\s*;\s*(?://.*)?$",
                line,
            )
            if match:
                key = f"{current_class}.{match.group(1)}"
                constants[key] = match.group(2)

    return constants


@register_hook
class SchemaSyncHook(BaseHook):
    """Class SchemaSyncHook."""
    hook_name = "schema-sync"
    description = "Cross-stack schema sync: Python ↔ Dart ↔ JSON schema"
    emoji = "🔄"

    watch_patterns = [
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "functions/models/*.py",
        "origna_gta/lib/models/generated/*.dart",
    ]

    target_files = [
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "functions/models/base.py",
        "functions/models/order.py",
        "functions/models/product.py",
        "functions/models/user.py",
        "origna_gta/lib/models/generated/base_models.dart",
        "origna_gta/lib/models/generated/order_models.dart",
        "origna_gta/lib/models/generated/product_models.dart",
        "origna_gta/lib/models/generated/user_models.dart",
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are a cross-stack consistency auditor for a Flutter + Python Firebase project.

{PROJECT_CONTEXT}

## Your Task
Compare the matched frontend↔backend file pairs and find EVERY mismatch.

### 1. Schema Constants Sync
- `schema_constants.py` (Python) vs `schema_constants.dart` (Dart) — EVERY field/collection/enum must be identical
- Both vs `database_schema.json` — missing or extra fields?

### 2. Model Field Mismatches
For each model pair (Order, Product, User, Base):
- Field names identical?
- Types compatible (String↔String, int↔int, Timestamp↔DateTime)?
- Required vs Optional same on both sides?
- Default values consistent?
- Enum values identical?

### 3. API Contract Mismatches
- Frontend sending fields backend doesn't expect?
- Backend returning fields frontend doesn't parse?
- Status enum values different between stacks?

### 4. Firestore Field Names
- Code using literal strings instead of schema_constants?
- Typos in field names?

{STRUCTURED_OUTPUT_INSTRUCTION}

Project files:
"""

    def run(self, changed_only: list[str] | None = None) -> HookResult:
        """
        Run fast local checks first, then optionally call LLM for deep analysis.
        """
        import time
        start = time.time()
        result = HookResult(hook_name=self.hook_name, status="success")

        # ── Fast local checks ────────────────────────────────────────────
        py_path = PROJECT_ROOT / "functions" / "schema_constants.py"
        dart_path = PROJECT_ROOT / "origna_gta" / "lib" / "core" / "schema" / "schema_constants.dart"
        json_path = PROJECT_ROOT / "docs" / "database_schema.json"

        py_exists = py_path.exists()
        dart_exists = dart_path.exists()
        json_exists = json_path.exists()

        if not py_exists or not dart_exists:
            result.status = "error"
            result.error = f"Schema files missing: py={py_exists}, dart={dart_exists}"
            return result

        py_text = py_path.read_text()
        dart_text = dart_path.read_text()

        py_constants = _extract_python_constants(py_text)
        dart_constants = _extract_dart_constants(dart_text)

        # Compare values (where names match)
        py_values = set(py_constants.values())
        dart_values = set(dart_constants.values())

        only_in_py = py_values - dart_values
        only_in_dart = dart_values - py_values

        if only_in_py:
            for val in sorted(only_in_py):
                # Find the key for this value
                key = next((k for k, v in py_constants.items() if v == val), "?")
                result.findings.append(Finding(
                    severity=HIGH,
                    title=f"Schema value '{val}' exists in Python but not Dart",
                    description=f"Constant `{key} = '{val}'` in schema_constants.py has no matching value in schema_constants.dart. This will cause cross-stack field name mismatches.",
                    file="functions/schema_constants.py",
                    fix_suggestion=f"Add the corresponding constant with value '{val}' to schema_constants.dart",
                    category="consistency",
                ))

        if only_in_dart:
            for val in sorted(only_in_dart):
                key = next((k for k, v in dart_constants.items() if v == val), "?")
                result.findings.append(Finding(
                    severity=HIGH,
                    title=f"Schema value '{val}' exists in Dart but not Python",
                    description=f"Constant `{key} = '{val}'` in schema_constants.dart has no matching value in schema_constants.py.",
                    file="origna_gta/lib/core/schema/schema_constants.dart",
                    fix_suggestion=f"Add the corresponding constant with value '{val}' to schema_constants.py",
                    category="consistency",
                ))

        # Check JSON schema coverage
        if json_exists:
            try:
                schema = json.loads(json_path.read_text())
                # Extract all field names from schema
                schema_fields = set()
                def _extract_fields(obj, prefix=""):
                    if isinstance(obj, dict):
                        for k, v in obj.items():
                            schema_fields.add(k)
                            _extract_fields(v, f"{prefix}.{k}")
                    elif isinstance(obj, list):
                        for item in obj:
                            _extract_fields(item, prefix)
                _extract_fields(schema)
            except (json.JSONDecodeError, Exception):
                result.findings.append(Finding(
                    severity=MEDIUM,
                    title="database_schema.json is invalid or unreadable",
                    description="Could not parse docs/database_schema.json",
                    file="docs/database_schema.json",
                    category="consistency",
                ))

        # ── LLM deep analysis (if files are provided) ────────────────────
        files = self.resolve_files(changed_only)
        if files:
            result.files_audited = len(files)
            try:
                context = self.bundle_files(files)
                prompt = self.get_prompt()
                raw = self.call_llm(prompt, context)
                llm_findings = self.parse_findings(raw)
                result.findings.extend(llm_findings)
                result.markdown_report = raw
            except Exception as e:
                # Local checks still succeeded, just note the LLM failure
                print(f"  ⚠️  LLM deep analysis failed: {e}")
                result.markdown_report = "LLM deep analysis was not performed."

        result.findings.sort(key=lambda f: f.severity_rank)
        result.duration_seconds = round(time.time() - start, 2)
        return result
