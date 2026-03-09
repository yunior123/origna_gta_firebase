#!/usr/bin/env python3
"""
Validate No Magic Strings
=========================
Detects raw string literals in staged .py and .dart files that should use
schema_constants (Collections, Fields, OrderStatusValues, etc.).

Usage:
    # Pre-commit hook (staged files only):
    python scripts/validate_no_magic_strings.py

    # CI mode (all changed files vs HEAD):
    python scripts/validate_no_magic_strings.py --ci

Exit codes:
    0 = clean
    1 = magic strings found
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass

# ---------------------------------------------------------------------------
# Known collection names (values from schema_constants.py Collections class)
# ---------------------------------------------------------------------------
COLLECTION_NAMES: set[str] = {
    "users", "products", "orders", "payouts", "refunds",
    "webhook_logs", "webhook_events", "security_alerts", "rate_limits",
    "config", "admin_logs", "product_ratings", "seller_ratings",
    "review_votes", "algolia_sync_failures", "_cron_locks",
    "return_requests", "pending_profiles",
    "warehouses", "cart", "favorites", "notifications", "fcm_tokens",
    "licenses", "book_access_tokens", "software_access_tokens",
    "addresses", "stock_notifications", "product_questions",
    "seller_metrics", "coupons", "inventoryLevels",
    "events", "coupon_uses",
    "user_security", "seller_profiles", "seller_skus",
    "_mail_logs", "pending_redemptions",
    "subscriptions", "chats", "messages",
    "platform_debt", "message_reports",
    "payment_providers",
}

# ---------------------------------------------------------------------------
# Status values that should use OrderStatusValues / DeliveryStatusValues / etc.
# Only flag these when they appear in comparisons or assignments to status fields,
# NOT inside class definitions, docstrings, or log messages.
# ---------------------------------------------------------------------------
STATUS_VALUES: set[str] = {
    "pending", "confirmed", "processing", "shipped", "in_transit",
    "delivered", "cancelled", "failed", "expired", "disputed",
    "refunded", "partially_refunded",
}

# ---------------------------------------------------------------------------
# Files and paths to skip
# ---------------------------------------------------------------------------
SKIP_FILENAMES: set[str] = {
    "schema_constants.py",
    "schema_constants.dart",
}

SKIP_PATH_SEGMENTS: tuple[str, ...] = (
    "tests/",
    "test/",
    "test_",
    "conftest",
    "e2e/",
    "scratch/",
    "cli/",           # CLI admin scripts
    "generated/",     # Code-generated files (*.g.dart etc.)
    "seed",           # Seed scripts
    "patrol_test/",   # Patrol integration tests
    ".worktrees/",    # Git worktree copies
    "venv/",          # Python virtual environments
    "node_modules/",  # Node dependencies
    "audit/",         # Audit scripts with their own conventions
)


@dataclass
class Finding:
    """Class Finding."""
    file: str
    line_num: int
    line_text: str
    category: str
    detail: str


def should_skip_file(filepath: str) -> bool:
    """Return True if this file should not be checked."""
    basename = os.path.basename(filepath)
    if basename in SKIP_FILENAMES:
        return True
    # Generated Dart files (e.g., *.g.dart, *.freezed.dart)
    if filepath.endswith(".g.dart") or filepath.endswith(".freezed.dart"):
        return True
    for seg in SKIP_PATH_SEGMENTS:
        if seg in filepath:
            return True
    # Only check .py and .dart
    if not (filepath.endswith(".py") or filepath.endswith(".dart")):
        return True
    return False


def is_excluded_line(line: str, is_python: bool) -> bool:
    """Return True if this line should be excluded from magic string checks."""
    stripped = line.strip()

    # Empty line
    if not stripped:
        return True

    # Comment lines
    if is_python and stripped.startswith("#"):
        return True
    if not is_python and stripped.startswith("//"):
        return True

    # Import statements
    if is_python and (stripped.startswith("import ") or stripped.startswith("from ")):
        return True
    if not is_python and stripped.startswith("import "):
        return True

    # Python constant definitions: UPPER_CASE = "value" or ClassName.UPPER = "value"
    if is_python and re.match(r'^[A-Z_][A-Z_0-9]*\s*=\s*["\']', stripped):
        return True
    # Class-level constant: e.g., USERS = "users"
    if is_python and re.match(r'^\s*[A-Z_][A-Z_0-9]*\s*=\s*["\']', line):
        return True

    # Dart constant definitions: static const fieldName = 'value'
    if not is_python and re.match(r'^\s*(?:static\s+)?const\s+\w+\s*=\s*["\']', stripped):
        return True

    # Docstrings / multiline string markers
    if is_python and (stripped.startswith('"""') or stripped.startswith("'''")):
        return True

    # Decorator lines
    if is_python and stripped.startswith("@"):
        return True

    # Log messages: logger.info/warning/error/debug
    if is_python and re.match(r'^\s*logger\.\w+\(', stripped):
        return True

    # Print calls for debugging
    if stripped.startswith("print("):
        return True

    # Raise with string message (not magic string, just error text)
    if is_python and re.match(r'^\s*raise\s+(ValueError|TypeError|RuntimeError)\(', stripped):
        return True

    return False


# ---- Pattern 1: collection("raw_name") instead of Collections.CONSTANT ----

# Python: .collection("name") or collection('name')
RE_COLLECTION_PY = re.compile(r'\.?collection\(\s*["\']([a-z_]+)["\']\s*\)')
# Dart: .collection('name') or collection("name")
RE_COLLECTION_DART = re.compile(r'\.?collection\(\s*["\']([a-z_]+)["\']\s*\)')


def check_collection_magic(line: str, is_python: bool) -> Finding | None:
    """Detect .collection("raw_string") that should use Collections.X."""
    pattern = RE_COLLECTION_PY if is_python else RE_COLLECTION_DART
    m = pattern.search(line)
    if not m:
        return None
    name = m.group(1)
    if name in COLLECTION_NAMES:
        return Finding(
            file="", line_num=0, line_text=line,
            category="COLLECTION",
            detail=f'Use Collections constant instead of raw "{name}"',
        )
    return None


# ---- Pattern 2: status string comparisons ----
# Matches: == "pending", != "shipped", status: "confirmed", "status": "delivered"
# Does NOT match inside class body constant definitions.

RE_STATUS_COMPARE_PY = re.compile(
    r'(?:==|!=|:\s*)\s*["\'](' + "|".join(STATUS_VALUES) + r')["\']'
)
RE_STATUS_COMPARE_DART = re.compile(
    r'(?:==|!=|:\s*)\s*["\'](' + "|".join(STATUS_VALUES) + r')["\']'
)
# Also catch dict/map literal: {"orderStatus": "pending"}
RE_STATUS_DICT_VALUE = re.compile(
    r'["\'](?:orderStatus|status|deliveryStatus|paymentStatus|itemStatus|newStatus)["\']'
    r'\s*:\s*["\'](' + "|".join(STATUS_VALUES) + r')["\']'
)


def check_status_magic(line: str, is_python: bool) -> Finding | None:
    """Detect raw status string literals in comparisons/assignments."""
    stripped = line.strip()

    # Skip lines that ARE the constant definitions
    if is_python and re.match(r'^\s*[A-Z_]+\s*=\s*["\']', stripped):
        return None
    if not is_python and "static const" in line:
        return None

    # Skip docstrings / comments embedded at end-of-line
    # (the main comment filter already handles full-line comments)

    # Check dict-style status assignment: {"status": "pending"}
    m = RE_STATUS_DICT_VALUE.search(line)
    if m:
        status = m.group(1)
        return Finding(
            file="", line_num=0, line_text=line,
            category="STATUS",
            detail=f'Use status constant instead of raw "{status}"',
        )

    # Check == / != / : comparisons — but only if in a code context
    # Skip if it's inside a docstring-like context (triple quotes)
    pattern = RE_STATUS_COMPARE_PY if is_python else RE_STATUS_COMPARE_DART
    m = pattern.search(line)
    if m:
        status = m.group(1)
        # Exclude lines that are just documenting valid values in comments/docstrings
        # or are part of a mapping dict definition
        if f'"{status}"' in stripped or f"'{status}'" in stripped:
            # Extra check: is this inside a Fields.STATUS: assignment using constants?
            if "Fields." in line or "StatusValues." in line or "OrderStatus" in line:
                return None
            # Skip string interpolation in f-strings and format calls
            if is_python and ("f'" in line or 'f"' in line or ".format(" in line):
                return None
            return Finding(
                file="", line_num=0, line_text=line,
                category="STATUS",
                detail=f'Use status constant instead of raw "{status}"',
            )
    return None


# ---- Pattern 3: .get("fieldName") / ["fieldName"] with known Firestore fields ----
# We only flag the MOST commonly misused fields to avoid false positives.
# These are fields that definitely exist in Fields class and are frequently accessed.

KNOWN_FIELDS: dict[str, str] = {
    # Timestamps
    "createdAt": "Fields.CREATED_AT",
    "updatedAt": "Fields.UPDATED_AT",
    "deletedAt": "Fields.DELETED_AT",
    # IDs
    "userId": "Fields.USER_ID",
    "productId": "Fields.PRODUCT_ID",
    "orderId": "Fields.ORDER_ID",
    "sellerId": "Fields.SELLER_ID",
    "buyerId": "Fields.BUYER_ID",
    # Order fields
    "orderStatus": "Fields.ORDER_STATUS",
    "paymentStatus": "Fields.PAYMENT_STATUS",
    "deliveryStatus": "Fields.DELIVERY_STATUS",
    "totalAmountCents": "Fields.TOTAL_AMOUNT_CENTS",
    "subtotalCents": "Fields.SUBTOTAL_CENTS",
    "taxAmountCents": "Fields.TAX_AMOUNT_CENTS",
    "platformFeeTotalCents": "Fields.PLATFORM_FEE_TOTAL_CENTS",
    # Product fields
    "stockQuantity": "Fields.STOCK_QUANTITY",
    "isActive": "Fields.IS_ACTIVE",
    "isDigital": "Fields.IS_DIGITAL",
    "imageUrls": "Fields.IMAGE_URLS",
    # User fields
    "roles": "Fields.ROLES",
    "stripeAccountId": "Fields.STRIPE_ACCOUNT_ID",
    "payoutsEnabled": "Fields.PAYOUTS_ENABLED",
    "chargesEnabled": "Fields.CHARGES_ENABLED",
    "suspended": "Fields.SUSPENDED",
    # Note: "email" excluded — too many legitimate non-Firestore uses (Auth tokens, request data)
}

RE_FIELD_GET_PY = re.compile(r'\.get\(\s*["\'](\w+)["\']\s*[,)]')
RE_FIELD_BRACKET_PY = re.compile(r'\[\s*["\'](\w+)["\']\s*\]')
RE_FIELD_GET_DART = re.compile(r'\.get\(\s*["\'](\w+)["\']\s*[,)]')
RE_FIELD_BRACKET_DART = re.compile(r'\[\s*["\'](\w+)["\']\s*\]')


def check_field_magic(line: str, is_python: bool) -> Finding | None:
    """Detect .get("knownField") or ["knownField"] that should use Fields.X."""
    stripped = line.strip()

    # Skip constant definitions
    if is_python and re.match(r'^\s*[A-Z_]+\s*=\s*["\']', stripped):
        return None
    if not is_python and "static const" in line:
        return None

    # Skip lines that already use Fields. or ApiKeys.
    if "Fields." in line or "ApiKeys." in line:
        return None

    # Skip string formatting / log lines
    if is_python and ("f'" in line or 'f"' in line):
        return None

    # Skip Firebase Auth token access: token.get("email"), token.get("email_verified")
    # These are Firebase Auth claims, not Firestore fields.
    if is_python and re.search(r'token\.get\(', line):
        return None

    # Skip Firestore trigger params: event.params["orderId"]
    # These are URL route parameters, not document field access.
    if is_python and re.search(r'event\.params\[', line):
        return None

    # Skip req.data.get() — request payload uses ApiKeys, not Fields
    if is_python and re.search(r'req\.data\.get\(', line):
        return None
    if is_python and re.search(r'data\.get\(', line) and "req" in line:
        return None

    # Skip Dart notification/push data access: data['orderId'] from FCM payload
    # These come from push notification payloads, not Firestore docs.
    if not is_python and re.search(r"data\['[a-zA-Z]+'\]", line):
        return None

    # Skip URL query parameters: uri.queryParameters['orderId']
    if "queryParameters" in line or "queryParams" in line:
        return None

    patterns = [
        RE_FIELD_GET_PY if is_python else RE_FIELD_GET_DART,
        RE_FIELD_BRACKET_PY if is_python else RE_FIELD_BRACKET_DART,
    ]

    for pattern in patterns:
        for m in pattern.finditer(line):
            field_name = m.group(1)
            if field_name in KNOWN_FIELDS:
                return Finding(
                    file="", line_num=0, line_text=line,
                    category="FIELD",
                    detail=f'Use {KNOWN_FIELDS[field_name]} instead of raw "{field_name}"',
                )
    return None


def scan_file(filepath: str) -> list[Finding]:
    """Scan a single file for magic strings."""
    findings: list[Finding] = []
    is_python = filepath.endswith(".py")

    try:
        with open(filepath, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except (OSError, IOError):
        return findings

    in_docstring = False
    docstring_char = None

    for i, raw_line in enumerate(lines, start=1):
        line = raw_line.rstrip("\n")

        # Track Python docstrings (triple quotes)
        if is_python:
            stripped = line.strip()
            if not in_docstring:
                if stripped.startswith('"""') or stripped.startswith("'''"):
                    docstring_char = stripped[:3]
                    # Single-line docstring: """..."""
                    if stripped.count(docstring_char) >= 2:
                        continue
                    in_docstring = True
                    continue
            else:
                if docstring_char and docstring_char in stripped:
                    in_docstring = False
                continue

        if in_docstring:
            continue

        if is_excluded_line(line, is_python):
            continue

        # Run all checks
        for checker in (check_collection_magic, check_status_magic, check_field_magic):
            finding = checker(line, is_python)
            if finding:
                finding.file = filepath
                finding.line_num = i
                finding.line_text = line.strip()
                findings.append(finding)
                break  # One finding per line max

    return findings


def get_changed_files(ci_mode: bool) -> list[str]:
    """Get list of files to check."""
    if ci_mode:
        cmd = ["git", "diff", "--name-only", "HEAD"]
    else:
        cmd = ["git", "diff", "--cached", "--name-only"]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        files = [f.strip() for f in result.stdout.strip().split("\n") if f.strip()]
    except subprocess.CalledProcessError:
        # Fallback: check all .py and .dart files
        print("WARNING: git command failed, no files to check.", file=sys.stderr)
        return []

    # Filter to .py and .dart, exclude skipped paths
    return [f for f in files if not should_skip_file(f)]


def main() -> int:
    """Function main."""
    parser = argparse.ArgumentParser(description="Detect magic strings in staged files")
    parser.add_argument("--ci", action="store_true", help="CI mode: check all changed files vs HEAD")
    parser.add_argument("--all", action="store_true", help="Check all .py/.dart files (not just changed)")
    parser.add_argument("files", nargs="*", help="Explicit files to check (overrides git)")
    args = parser.parse_args()

    if args.files:
        files = [f for f in args.files if not should_skip_file(f)]
    elif args.all:
        # Walk the repo for all .py and .dart files
        repo_root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        files = []
        for dirpath, _dirnames, filenames in os.walk(repo_root):
            for fn in filenames:
                fp = os.path.join(dirpath, fn)
                rel = os.path.relpath(fp, repo_root)
                if not should_skip_file(rel):
                    files.append(fp)
    else:
        files = get_changed_files(ci_mode=args.ci)

    if not files:
        return 0

    # Cache repo root once for resolving relative paths
    try:
        repo_root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except subprocess.CalledProcessError:
        repo_root = os.getcwd()

    all_findings: list[Finding] = []
    for filepath in files:
        # Resolve to absolute if relative
        if not os.path.isabs(filepath):
            filepath = os.path.join(repo_root, filepath)
        if os.path.isfile(filepath):
            all_findings.extend(scan_file(filepath))

    if not all_findings:
        print(f"OK: {len(files)} file(s) checked, no magic strings found.")
        return 0

    # Group by category for readability
    by_category: dict[str, list[Finding]] = {}
    for f in all_findings:
        by_category.setdefault(f.category, []).append(f)

    print(f"\nMagic strings detected in {len(files)} file(s):\n")

    category_labels = {
        "COLLECTION": "Collection names (use Collections.X)",
        "STATUS": "Status values (use OrderStatusValues.X / etc.)",
        "FIELD": "Field names (use Fields.X)",
    }

    for cat in ("COLLECTION", "STATUS", "FIELD"):
        findings = by_category.get(cat, [])
        if not findings:
            continue
        label = category_labels.get(cat, cat)
        print(f"--- {label} ({len(findings)} finding(s)) ---")
        for f in findings:
            rel_path = f.file
            if repo_root and f.file.startswith(repo_root):
                rel_path = os.path.relpath(f.file, repo_root)
            print(f"  {rel_path}:{f.line_num}")
            print(f"    {f.line_text}")
            print(f"    -> {f.detail}")
        print()

    total = len(all_findings)
    print(f"TOTAL: {total} magic string(s) found. Fix them to use schema_constants.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
