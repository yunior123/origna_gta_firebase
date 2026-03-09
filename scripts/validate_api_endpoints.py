#!/usr/bin/env python3
"""
validate_api_endpoints.py - Cross-reference Cloud Function endpoints between
backend (main.py) and frontend (Dart), then health-check deployed functions.

Usage:
    python scripts/validate_api_endpoints.py [--env dev|staging] [--skip-http] [--verbose]

Exits with code 1 if any CRITICAL mismatches are found (frontend calls a
function that does not exist in the backend).
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

# ---------------------------------------------------------------------------
# Paths (relative to repo root)
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN_PY = REPO_ROOT / "functions" / "main.py"
HANDLERS_DIR = REPO_ROOT / "functions" / "handlers"
DART_LIB = REPO_ROOT / "origna_gta" / "lib"
SCHEMA_DART = DART_LIB / "core" / "schema" / "schema_constants.dart"

# ---------------------------------------------------------------------------
# Environment config
# ---------------------------------------------------------------------------
ENV_CONFIG = {
    "dev": {
        "project": "orignagta-dev",
        "region": "northamerica-northeast1",
    },
    "staging": {
        "project": "orignagta-staging",
        "region": "northamerica-northeast1",
    },
}

# ---------------------------------------------------------------------------
# Function type classification
# ---------------------------------------------------------------------------
# Decorators that indicate a function type:
#   on_call       -> callable (client can invoke via httpsCallable)
#   on_request    -> HTTP endpoint (raw HTTP, e.g. webhooks, redirects)
#   on_document_* -> Firestore trigger (cannot be called via HTTP)
#   on_schedule   -> Cron job (Cloud Scheduler invokes it)
#   on_task_dispatched -> Cloud Tasks queue handler
DECORATOR_TYPES = {
    "on_call": "callable",
    "on_request": "http",
    "on_document_created": "firestore_trigger",
    "on_document_written": "firestore_trigger",
    "on_document_updated": "firestore_trigger",
    "on_document_deleted": "firestore_trigger",
    "on_schedule": "cron",
    "on_task_dispatched": "task_queue",
}

# Regex to match decorator + def lines in handler files
# Captures: decorator name and function name
DECORATOR_RE = re.compile(
    r"@(?:\w+_fn\.)?(on_call|on_request|on_document_\w+|on_schedule|on_task_dispatched)"
    r"\b.*?\ndef\s+(\w+)\s*\(",
    re.DOTALL,
)


def parse_backend_functions() -> dict[str, dict]:
    """Parse __all__ from main.py and classify each function by its decorator type."""
    # Step 1: Extract __all__ list from main.py
    main_src = MAIN_PY.read_text(encoding="utf-8")
    all_match = re.search(r"__all__\s*=\s*\[(.*?)\]", main_src, re.DOTALL)
    if not all_match:
        print("ERROR: Could not parse __all__ from main.py")
        sys.exit(2)

    all_names: list[str] = re.findall(r'"(\w+)"', all_match.group(1))

    # Step 2: Scan handler files to determine decorator type for each function
    func_types: dict[str, str] = {}
    for handler_file in sorted(HANDLERS_DIR.glob("*.py")):
        if handler_file.name == "__init__.py":
            continue
        src = handler_file.read_text(encoding="utf-8")
        for m in DECORATOR_RE.finditer(src):
            decorator_name = m.group(1)
            func_name = m.group(2)
            func_type = DECORATOR_TYPES.get(decorator_name, "unknown")
            func_types[func_name] = func_type

    # Step 3: Build result dict for every function in __all__
    results: dict[str, dict] = {}
    for name in all_names:
        ftype = func_types.get(name, "unknown")
        results[name] = {
            "name": name,
            "type": ftype,
            "in_all": True,
        }

    # Step 4: Also capture functions imported but NOT in __all__ (potential drift)
    import_re = re.compile(r"from\s+handlers\.\w+\s+import\s*\((.*?)\)", re.DOTALL)
    # Words that appear in import blocks but are NOT function names (e.g. "# noqa: E402")
    IMPORT_NOISE = {"noqa", "E402", "type", "ignore"}
    imported_names: set[str] = set()
    for m in import_re.finditer(main_src):
        for name in re.findall(r"(\w+)", m.group(1)):
            if name not in IMPORT_NOISE:
                imported_names.add(name)

    for name in imported_names - set(all_names):
        ftype = func_types.get(name, "unknown")
        results[name] = {
            "name": name,
            "type": ftype,
            "in_all": False,
        }

    return results


def parse_dart_endpoints() -> dict[str, list[str]]:
    """
    Extract all Cloud Function endpoint names referenced in Dart code.
    Returns {endpoint_name: [list of source files]}.
    """
    endpoints: dict[str, list[str]] = {}

    # Pattern 1: CloudFunctionEndpoints constants -> extract string values
    constants_map: dict[str, str] = {}
    if SCHEMA_DART.exists():
        src = SCHEMA_DART.read_text(encoding="utf-8")
        # Match: static const someVar = 'some_function_name';
        for m in re.finditer(
            r"static\s+const\s+(\w+)\s*=\s*'(\w+)'", src
        ):
            constants_map[m.group(1)] = m.group(2)

    # Pattern 2: Scan all Dart files for httpsCallable(...) calls
    # Matches both:
    #   httpsCallable(CloudFunctionEndpoints.someName)
    #   httpsCallable('some_name')
    callable_const_re = re.compile(
        r"httpsCallable\(CloudFunctionEndpoints\.(\w+)\)"
    )
    callable_string_re = re.compile(r"httpsCallable\('(\w+)'\)")

    for dart_file in sorted(DART_LIB.rglob("*.dart")):
        rel_path = str(dart_file.relative_to(REPO_ROOT))
        src = dart_file.read_text(encoding="utf-8")

        # Constant references
        for m in callable_const_re.finditer(src):
            const_name = m.group(1)
            endpoint = constants_map.get(const_name, f"UNRESOLVED:{const_name}")
            endpoints.setdefault(endpoint, []).append(rel_path)

        # Direct string references
        for m in callable_string_re.finditer(src):
            endpoint = m.group(1)
            endpoints.setdefault(endpoint, []).append(rel_path)

    # Deduplicate source file lists
    for k in endpoints:
        endpoints[k] = sorted(set(endpoints[k]))

    return endpoints


def health_check_function(base_url: str, func_name: str, timeout: float = 10.0) -> dict:
    """
    Perform a lightweight HTTP GET to check if a Cloud Function is deployed.
    Returns {name, status_code, deployed, latency_ms, error}.
    """
    url = f"{base_url}/{func_name}"
    start = time.monotonic()
    result = {
        "name": func_name,
        "url": url,
        "status_code": None,
        "deployed": False,
        "latency_ms": 0,
        "error": None,
    }
    try:
        req = Request(url, method="GET")
        req.add_header("User-Agent", "OrignaGTA-EndpointValidator/1.0")
        with urlopen(req, timeout=timeout) as resp:
            result["status_code"] = resp.status
            result["deployed"] = True
    except HTTPError as e:
        result["status_code"] = e.code
        # 401, 403, 400, 405 all mean the function EXISTS but rejected our unauthenticated GET
        result["deployed"] = e.code != 404
        if e.code == 404:
            result["error"] = "NOT DEPLOYED (404)"
    except URLError as e:
        result["error"] = f"URL error: {e.reason}"
    except Exception as e:
        result["error"] = str(e)

    result["latency_ms"] = round((time.monotonic() - start) * 1000)
    return result


def print_section(title: str) -> None:
    """Function print_section."""
    print(f"\n{'=' * 70}")
    print(f"  {title}")
    print(f"{'=' * 70}")


def main() -> int:
    """Function main."""
    parser = argparse.ArgumentParser(description="Validate OrignaGTA API endpoints")
    parser.add_argument(
        "--env",
        choices=["dev", "staging"],
        default="dev",
        help="Target environment for HTTP health checks (default: dev)",
    )
    parser.add_argument(
        "--skip-http",
        action="store_true",
        help="Skip HTTP health checks (only do static analysis)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show detailed output for all functions",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=10.0,
        help="HTTP request timeout in seconds (default: 10)",
    )
    args = parser.parse_args()

    exit_code = 0

    # -----------------------------------------------------------------------
    # 1. Parse backend
    # -----------------------------------------------------------------------
    print_section("BACKEND: Cloud Functions from main.py")
    backend = parse_backend_functions()

    type_counts: dict[str, int] = {}
    for f in backend.values():
        t = f["type"]
        type_counts[t] = type_counts.get(t, 0) + 1

    in_all_count = sum(1 for f in backend.values() if f["in_all"])
    imported_only = sum(1 for f in backend.values() if not f["in_all"])

    print(f"\nTotal functions in __all__: {in_all_count}")
    print(f"Imported but NOT in __all__: {imported_only}")
    print(f"\nBy type:")
    for t in sorted(type_counts):
        print(f"  {t:20s} {type_counts[t]:3d}")

    # List imported-but-not-exported
    not_exported = [f for f in backend.values() if not f["in_all"]]
    if not_exported:
        print(f"\nWARNING: {len(not_exported)} function(s) imported but NOT in __all__:")
        for f in sorted(not_exported, key=lambda x: x["name"]):
            print(f"  - {f['name']} ({f['type']})")

    # -----------------------------------------------------------------------
    # 2. Parse frontend
    # -----------------------------------------------------------------------
    print_section("FRONTEND: Dart httpsCallable references")
    dart_endpoints = parse_dart_endpoints()

    print(f"\nTotal unique endpoints called by Dart: {len(dart_endpoints)}")
    if args.verbose:
        for ep in sorted(dart_endpoints):
            files = dart_endpoints[ep]
            print(f"  {ep}")
            for f in files:
                print(f"    -> {f}")

    # -----------------------------------------------------------------------
    # 3. Cross-reference
    # -----------------------------------------------------------------------
    print_section("CROSS-REFERENCE: Frontend vs Backend")

    backend_names = set(backend.keys())
    backend_all_names = {n for n, f in backend.items() if f["in_all"]}
    frontend_names = set(dart_endpoints.keys())

    # CRITICAL: Frontend calls something that doesn't exist in backend at all
    frontend_only = frontend_names - backend_names
    # WARNING: Backend defines something never called by frontend (may be triggers/crons/admin)
    backend_only = backend_all_names - frontend_names

    # Separate backend-only by type
    backend_only_callable = []
    backend_only_other = []
    for name in sorted(backend_only):
        ftype = backend.get(name, {}).get("type", "unknown")
        if ftype in ("callable", "http"):
            backend_only_callable.append((name, ftype))
        else:
            backend_only_other.append((name, ftype))

    # CRITICAL mismatches
    if frontend_only:
        print(f"\n*** CRITICAL: {len(frontend_only)} endpoint(s) called by frontend but NOT defined in backend ***")
        for ep in sorted(frontend_only):
            files = dart_endpoints[ep]
            print(f"  [CRITICAL] {ep}")
            for f in files:
                print(f"             called from: {f}")
        exit_code = 1
    else:
        print("\n[OK] All frontend-referenced endpoints exist in the backend.")

    # Callable/HTTP backend functions not called by frontend
    if backend_only_callable:
        print(f"\n[INFO] {len(backend_only_callable)} callable/HTTP endpoint(s) in backend not called by Dart frontend:")
        print("       (These may be used by admin panels, E2E tests, external integrations, etc.)")
        for name, ftype in backend_only_callable:
            print(f"  - {name} ({ftype})")

    # Non-callable (triggers, crons, tasks) are expected to not be called by frontend
    if backend_only_other and args.verbose:
        print(f"\n[OK] {len(backend_only_other)} trigger/cron/task functions (not callable from frontend):")
        for name, ftype in backend_only_other:
            print(f"  - {name} ({ftype})")

    # Matched endpoints
    matched = frontend_names & backend_all_names
    print(f"\n[OK] {len(matched)} endpoint(s) matched between frontend and backend.")

    # -----------------------------------------------------------------------
    # 4. HTTP health checks
    # -----------------------------------------------------------------------
    if not args.skip_http:
        env_cfg = ENV_CONFIG[args.env]
        base_url = f"https://{env_cfg['region']}-{env_cfg['project']}.cloudfunctions.net"

        # Only health-check callable and HTTP functions (not triggers/crons/tasks)
        checkable = [
            name
            for name, info in backend.items()
            if info["in_all"] and info["type"] in ("callable", "http")
        ]
        checkable.sort()

        print_section(f"HTTP HEALTH CHECK: {args.env} ({len(checkable)} endpoints)")
        print(f"Base URL: {base_url}")
        print(f"Timeout: {args.timeout}s per request")
        print(f"Checking {len(checkable)} callable/HTTP functions...\n")

        results: list[dict] = []
        with ThreadPoolExecutor(max_workers=10) as pool:
            futures = {
                pool.submit(health_check_function, base_url, name, args.timeout): name
                for name in checkable
            }
            for future in as_completed(futures):
                r = future.result()
                results.append(r)

        # Sort by name for consistent output
        results.sort(key=lambda x: x["name"])

        deployed_count = 0
        not_deployed: list[dict] = []
        errors: list[dict] = []

        for r in results:
            if r["deployed"]:
                deployed_count += 1
                status_str = f"HTTP {r['status_code']}"
                if args.verbose:
                    print(f"  [DEPLOYED]     {r['name']:45s} {status_str:>10s}  {r['latency_ms']:>5d}ms")
            elif r["error"] and "404" not in str(r["error"]):
                errors.append(r)
                print(f"  [ERROR]        {r['name']:45s} {r['error']}")
            else:
                not_deployed.append(r)
                print(f"  [NOT DEPLOYED] {r['name']:45s} 404  {r['latency_ms']:>5d}ms")

        print(f"\nSummary:")
        print(f"  Deployed:     {deployed_count}/{len(checkable)}")
        print(f"  Not deployed: {len(not_deployed)}/{len(checkable)}")
        print(f"  Errors:       {len(errors)}/{len(checkable)}")

        if not_deployed:
            print(f"\n*** WARNING: {len(not_deployed)} function(s) not deployed to {args.env} ***")
            for r in not_deployed:
                in_frontend = r["name"] in frontend_names
                severity = "CRITICAL" if in_frontend else "WARNING"
                label = " (called by frontend!)" if in_frontend else ""
                print(f"  [{severity}] {r['name']}{label}")
                if in_frontend:
                    exit_code = 1

    # -----------------------------------------------------------------------
    # 5. Final summary
    # -----------------------------------------------------------------------
    print_section("FINAL RESULT")
    if exit_code == 0:
        print("\n[PASS] No critical mismatches found.")
    else:
        print("\n[FAIL] Critical issues detected. See above for details.")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
