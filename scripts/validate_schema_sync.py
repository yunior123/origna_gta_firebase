#!/usr/bin/env python3
"""
Cross-stack schema synchronization validator.

Parses Python (functions/schema_constants.py) and Dart
(origna_gta/lib/core/schema/schema_constants.dart) to extract string constant
VALUES and cross-references critical classes that MUST stay in sync.

Exit code 0 = all good, 1 = sync issues found.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NamedTuple

# ---------------------------------------------------------------------------
# Paths (relative to repo root)
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent
PYTHON_FILE = REPO_ROOT / "functions" / "schema_constants.py"
DART_FILE = REPO_ROOT / "origna_gta" / "lib" / "core" / "schema" / "schema_constants.dart"

# ---------------------------------------------------------------------------
# Critical class pairs: (Python class name, Dart class name)
# These MUST have identical string VALUES on both sides.
# ---------------------------------------------------------------------------
CRITICAL_PAIRS: list[tuple[str, str]] = [
    ("Collections", "Collections"),
    ("Fields", "Fields"),
    ("OrderStatusValues", "OrderStatusValues"),
    ("PaymentStatusValues", "PaymentStatusValues"),
    ("DeliveryStatusValues", "DeliveryStatusValues"),
    ("ApiKeys", "ApiKeys"),
    ("PayoutStatusValues", "PayoutStatusValues"),
    ("UserRoleValues", "UserRoleValues"),
    ("ProductLifecycleStatusValues", "ProductLifecycleStatusValues"),
    ("ReturnStatusValues", "ReturnStatusValues"),
    ("ShippingApprovalStatusValues", "ShippingApprovalStatusValues"),
    ("DeliveryTypeValues", "DeliveryTypeValues"),
    ("SecurityAlertTypes", "SecurityAlertTypes"),
    ("SeverityLevels", "SeverityLevels"),
    ("CarrierValues", "CarrierValues"),
    ("SupplierTypeValues", "SupplierTypeValues"),
    ("ConsentMethodValues", "ConsentMethodValues"),
    ("LanguageValues", "LanguageValues"),
    ("SupplierCurrencyValues", "SupplierCurrencyValues"),
    ("CouponDiscountTypeValues", "CouponDiscountTypeValues"),
    ("DiscountTypeValues", "DiscountTypeValues"),
    ("WarehouseTypeValues", "WarehouseTypeValues"),
    ("WebhookStatusValues", "WebhookStatusValues"),
    ("NotificationTypes", "NotificationTypes"),
    ("OrderEventTypes", "OrderEventTypes"),
    ("StripeConstants", "StripeConstants"),
    ("StripeEventTypes", "StripeEventTypes"),
    ("PlaceholderAddressValues", "PlaceholderAddressValues"),
    ("DigitalTypeValues", "DigitalTypeValues"),
    ("DigitalPlatformValues", "DigitalPlatformValues"),
    ("LicenseStatusValues", "LicenseStatusValues"),
    ("SubscriptionStatusValues", "SubscriptionStatusValues"),
    ("ProductConditionValues", "ProductConditionValues"),
    ("CronLockStatusValues", "CronLockStatusValues"),
    ("AlgoliaActionValues", "AlgoliaActionValues"),
    ("WebhookResponseStatus", "WebhookResponseStatus"),
    ("RateLimitActions", "RateLimitActions"),
    ("Documents", "Documents"),
    ("CategoryIds", "CategoryIds"),
    ("ErrorCodeValues", "ErrorCodeValues"),
    ("CartVerificationReasonValues", "CartVerificationReasonValues"),
    ("PaymentProviderValues", "PaymentProviderValues"),
    ("PolicyVersionValues", "PolicyVersionValues"),
    ("ShippingSourceValues", "ShippingSourceValues"),
]


class ConstantEntry(NamedTuple):
    """Class ConstantEntry."""
    name: str  # UPPER_SNAKE or camelCase constant name
    value: str  # The string literal value


# ---------------------------------------------------------------------------
# Python parser
# ---------------------------------------------------------------------------

# Match: CONST_NAME = "value"  or  CONST_NAME = 'value'
# Also handles constants with type annotations like ALL: frozenset[str] = ...
_PY_CLASS_RE = re.compile(r"^class\s+(\w+)")
_PY_CONST_RE = re.compile(
    r'^\s+([A-Z][A-Z0-9_]*)\s*(?::\s*[^=]+)?\s*=\s*["\']([^"\']*)["\']'
)
# Also catch integer constants like ELECTRONICS = 1
_PY_INT_CONST_RE = re.compile(
    r"^\s+([A-Z][A-Z0-9_]*)\s*=\s*(\d+)\s*(?:#.*)?$"
)


def parse_python(path: Path) -> dict[str, list[ConstantEntry]]:
    """Parse Python file, returning {class_name: [ConstantEntry, ...]}."""
    classes: dict[str, list[ConstantEntry]] = {}
    current_class: str | None = None
    indent_depth = 0

    with open(path, encoding="utf-8") as f:
        for line in f:
            # Detect class definition
            m_cls = _PY_CLASS_RE.match(line)
            if m_cls:
                current_class = m_cls.group(1)
                classes.setdefault(current_class, [])
                indent_depth = 0
                continue

            # Reset class context on module-level non-empty, non-comment lines
            if current_class and line.strip() and not line[0].isspace() and not line.startswith("#"):
                # New top-level definition that is not a class
                if not _PY_CLASS_RE.match(line):
                    current_class = None
                continue

            if not current_class:
                continue

            # Try string constant
            m_const = _PY_CONST_RE.match(line)
            if m_const:
                name, value = m_const.group(1), m_const.group(2)
                # Skip aggregate constants like ALL, VALID_TRANSITIONS, etc.
                if name in ("ALL", "VALID_TRANSITIONS", "TERMINAL_STATES", "BUYER_VISIBLE",
                            "REQUIRED_FIELDS", "TIMESTAMP_FIELD", "PREMIUM_ACTIVE"):
                    continue
                classes[current_class].append(ConstantEntry(name, value))
                continue

            # Try integer constant (for CategoryIds etc.)
            m_int = _PY_INT_CONST_RE.match(line)
            if m_int:
                name, value = m_int.group(1), m_int.group(2)
                if name in ("ALL", "MIN", "MAX"):
                    continue
                classes[current_class].append(ConstantEntry(name, value))

    return classes


# ---------------------------------------------------------------------------
# Dart parser
# ---------------------------------------------------------------------------

# Match: static const name = 'value';  or  static const String name = 'value';
_DART_CLASS_RE = re.compile(r"^\s*(?:abstract\s+)?(?:final\s+)?class\s+(\w+)")
_DART_CONST_RE = re.compile(
    r"^\s+static\s+const\s+(?:String\s+)?(\w+)\s*=\s*'([^']*)'\s*;"
)
# Integer constants: static const electronics = 1;
_DART_INT_CONST_RE = re.compile(
    r"^\s+static\s+const\s+(\w+)\s*=\s*(\d+)\s*;"
)
# Double constants: static const platformFeePercent = 2.5;
_DART_DOUBLE_CONST_RE = re.compile(
    r"^\s+static\s+const\s+(\w+)\s*=\s*(\d+\.\d+)\s*;"
)


def parse_dart(path: Path) -> dict[str, list[ConstantEntry]]:
    """Parse Dart file, returning {class_name: [ConstantEntry, ...]}."""
    classes: dict[str, list[ConstantEntry]] = {}
    current_class: str | None = None
    brace_depth = 0

    with open(path, encoding="utf-8") as f:
        for line in f:
            # Detect class definition
            m_cls = _DART_CLASS_RE.match(line)
            if m_cls:
                current_class = m_cls.group(1)
                classes.setdefault(current_class, [])
                # Count opening braces in this line
                brace_depth = line.count("{") - line.count("}")
                continue

            if current_class is not None:
                brace_depth += line.count("{") - line.count("}")
                if brace_depth <= 0:
                    current_class = None
                    brace_depth = 0
                    continue

            if not current_class:
                continue

            # Try string constant
            m_const = _DART_CONST_RE.match(line)
            if m_const:
                name, value = m_const.group(1), m_const.group(2)
                # Skip aggregates
                if name in ("all", "validTransitions", "terminalStates", "buyerVisible",
                            "premiumActive", "timestampField"):
                    continue
                classes[current_class].append(ConstantEntry(name, value))
                continue

            # Try integer constant (for CategoryIds etc.)
            m_int = _DART_INT_CONST_RE.match(line)
            if m_int:
                name, value = m_int.group(1), m_int.group(2)
                if name in ("all", "min", "max"):
                    continue
                classes[current_class].append(ConstantEntry(name, value))

    return classes


# ---------------------------------------------------------------------------
# Comparison logic
# ---------------------------------------------------------------------------

def get_values(entries: list[ConstantEntry]) -> set[str]:
    """Extract the set of unique string/int values from constant entries."""
    return {e.value for e in entries}


def get_value_to_names(entries: list[ConstantEntry]) -> dict[str, list[str]]:
    """Map value -> list of constant names that produce it."""
    mapping: dict[str, list[str]] = {}
    for e in entries:
        mapping.setdefault(e.value, []).append(e.name)
    return mapping


def compare_class_pair(
    py_class: str,
    dart_class: str,
    py_entries: list[ConstantEntry],
    dart_entries: list[ConstantEntry],
) -> list[str]:
    """Compare two classes and return list of issue strings (empty = OK)."""
    issues: list[str] = []

    py_values = get_values(py_entries)
    dart_values = get_values(dart_entries)

    py_only = sorted(py_values - dart_values)
    dart_only = sorted(dart_values - py_values)

    if py_only:
        py_map = get_value_to_names(py_entries)
        for val in py_only:
            names = py_map.get(val, ["?"])
            issues.append(
                f"  PYTHON ONLY: '{val}' (constant(s): {', '.join(names)}) "
                f"-- missing in Dart {dart_class}"
            )

    if dart_only:
        dart_map = get_value_to_names(dart_entries)
        for val in dart_only:
            names = dart_map.get(val, ["?"])
            issues.append(
                f"  DART ONLY:   '{val}' (constant(s): {', '.join(names)}) "
                f"-- missing in Python {py_class}"
            )

    return issues


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    """Validate schema sync between Python and Dart schema_constants files.

    Returns 0 on success, 1 if any sync issues are found.
    """
    # Verify files exist
    if not PYTHON_FILE.exists():
        print(f"ERROR: Python file not found: {PYTHON_FILE}")
        return 1
    if not DART_FILE.exists():
        print(f"ERROR: Dart file not found: {DART_FILE}")
        return 1

    print("=" * 72)
    print("  Schema Sync Validator: Python <-> Dart")
    print("=" * 72)
    print(f"  Python: {PYTHON_FILE.relative_to(REPO_ROOT)}")
    print(f"  Dart:   {DART_FILE.relative_to(REPO_ROOT)}")
    print("=" * 72)
    print()

    py_classes = parse_python(PYTHON_FILE)
    dart_classes = parse_dart(DART_FILE)

    total_issues = 0
    total_ok = 0
    missing_classes: list[str] = []

    for py_name, dart_name in CRITICAL_PAIRS:
        py_entries = py_classes.get(py_name)
        dart_entries = dart_classes.get(dart_name)

        # Handle missing classes
        if py_entries is None and dart_entries is None:
            missing_classes.append(f"  {py_name}/{dart_name}: NOT FOUND in either file")
            continue
        if py_entries is None:
            missing_classes.append(f"  {py_name}: NOT FOUND in Python (Dart has {len(dart_entries or [])} constants)")
            total_issues += 1
            continue
        if dart_entries is None:
            missing_classes.append(f"  {dart_name}: NOT FOUND in Dart (Python has {len(py_entries)} constants)")
            total_issues += 1
            continue

        issues = compare_class_pair(py_name, dart_name, py_entries, dart_entries)

        if issues:
            total_issues += len(issues)
            print(f"MISMATCH  {py_name} ({len(py_entries)} py) <-> {dart_name} ({len(dart_entries)} dart)")
            for issue in issues:
                print(issue)
            print()
        else:
            total_ok += 1
            py_vals = get_values(py_entries)
            print(f"OK        {py_name} <-> {dart_name} ({len(py_vals)} values in sync)")

    # Report missing classes
    if missing_classes:
        print()
        print("MISSING CLASSES:")
        for msg in missing_classes:
            print(msg)

    # Summary
    print()
    print("=" * 72)
    print(f"  SUMMARY: {total_ok} pairs OK, {total_issues} issues found")
    if missing_classes:
        print(f"           {len(missing_classes)} class(es) missing from one or both files")
    print("=" * 72)

    # Also report classes found in files but NOT in critical pairs (informational)
    all_py_checked = {p for p, _ in CRITICAL_PAIRS}
    all_dart_checked = {d for _, d in CRITICAL_PAIRS}
    py_unchecked = sorted(set(py_classes.keys()) - all_py_checked)
    dart_unchecked = sorted(set(dart_classes.keys()) - all_dart_checked)

    if py_unchecked or dart_unchecked:
        print()
        print("INFO: Classes NOT in critical pairs (unchecked):")
        if py_unchecked:
            print(f"  Python only: {', '.join(py_unchecked)}")
        if dart_unchecked:
            print(f"  Dart only:   {', '.join(dart_unchecked)}")

    if total_issues > 0:
        print()
        print("RESULT: FAIL -- schema sync issues detected")
        return 1

    print()
    print("RESULT: PASS -- all critical classes are in sync")
    return 0


if __name__ == "__main__":
    sys.exit(main())
