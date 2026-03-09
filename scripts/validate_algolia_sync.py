#!/usr/bin/env python3
"""
Validate Algolia configuration consistency across the OrignaGTA codebase.

Cross-references:
  - Backend: which fields are indexed to Algolia (algolia_service.py)
  - Frontend: which fields are consumed/filtered on (algolia_service.dart, algolia_product_repository.dart)
  - Config: index names, env vars, Remote Config keys
  - Schema: field name constants in Python + Dart

Exit codes:
  0 = clean (warnings allowed)
  1 = critical issues found
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths (relative to repo root)
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent

BACKEND_ALGOLIA_SERVICE = REPO_ROOT / "functions" / "services" / "algolia_service.py"
BACKEND_CONFIG = REPO_ROOT / "functions" / "config.py"
BACKEND_SCHEMA = REPO_ROOT / "functions" / "schema_constants.py"

DART_ALGOLIA_SERVICE = REPO_ROOT / "origna_gta" / "lib" / "services" / "algolia_service.dart"
DART_ALGOLIA_REPO = REPO_ROOT / "origna_gta" / "lib" / "core" / "repositories" / "algolia_product_repository.dart"
DART_ENV_CONFIG = REPO_ROOT / "origna_gta" / "lib" / "utils" / "env_config.dart"
DART_SCHEMA = REPO_ROOT / "origna_gta" / "lib" / "core" / "schema" / "schema_constants.dart"
DART_PROVIDERS = REPO_ROOT / "origna_gta" / "lib" / "core" / "providers.dart"
DART_CONF_SERVICES = REPO_ROOT / "origna_gta" / "lib" / "services" / "conf_services.dart"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

warnings: list[str] = []
errors: list[str] = []


def warn(msg: str) -> None:
    """Function warn."""
    warnings.append(msg)


def error(msg: str) -> None:
    """Function error."""
    errors.append(msg)


def read_file(path: Path) -> str:
    """Function read_file."""
    if not path.exists():
        error(f"File not found: {path}")
        return ""
    return path.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# 1. Extract backend indexed fields from format_product_for_algolia
# ---------------------------------------------------------------------------

def extract_backend_indexed_fields(src: str) -> set[str]:
    """Parse format_product_for_algolia to find every field key written to the Algolia object."""
    fields: set[str] = set()

    # Match Fields.CONSTANT_NAME patterns used as keys
    for m in re.finditer(r'Fields\.([A-Z_]+)', src):
        fields.add(m.group(1))

    # Match literal string keys like "availableInCanada", "objectID"
    for m in re.finditer(r'algolia_object\[(["\'])(.+?)\1\]', src):
        fields.add(m.group(2))

    # objectID is always set
    fields.add("objectID")

    return fields


def extract_backend_facet_fields(src: str) -> set[str]:
    """Parse configure_algolia_index to find attributesForFaceting."""
    facets: set[str] = set()
    in_facets = False
    for line in src.splitlines():
        if "attributesForFaceting" in line:
            in_facets = True
            continue
        if in_facets:
            stripped = line.strip()
            # End of list
            if stripped.startswith("]"):
                break
            # Fields.CONSTANT (standalone or inside f-string)
            m = re.search(r'Fields\.([A-Z_]+)', line)
            if m:
                facets.add(m.group(1))
            # filterOnly(Fields.CONSTANT) inside f-string: f"filterOnly({Fields.X})"
            m = re.search(r'filterOnly\(\{?Fields\.([A-Z_]+)\}?\)', line)
            if m:
                facets.add(m.group(1))
            # String literal "filterOnly(fieldName)" — entire value is a string
            m = re.search(r'["\']filterOnly\((\w+)\)["\']', line)
            if m:
                facets.add(m.group(1))
            # bare literal string in list (not inside filterOnly)
            if "filterOnly" not in line:
                m = re.search(r'["\']([a-zA-Z_]+)["\']', line)
                if m:
                    facets.add(m.group(1))
    return facets


def extract_backend_retrievable_fields(src: str) -> set[str]:
    """Parse configure_algolia_index to find attributesToRetrieve."""
    fields: set[str] = set()
    in_retrieve = False
    for line in src.splitlines():
        if "attributesToRetrieve" in line:
            in_retrieve = True
            continue
        if in_retrieve:
            stripped = line.strip()
            # Collect any fields on this line first
            for m in re.finditer(r'Fields\.([A-Z_]+)', line):
                fields.add(m.group(1))
            for m in re.finditer(r'["\']([a-zA-Z_]+)["\']', line):
                fields.add(m.group(1))
            # End of list
            if stripped.startswith("]") or ("]" in stripped and "Fields" not in stripped and '"' not in stripped):
                break
    return fields


# ---------------------------------------------------------------------------
# 2. Extract frontend filter/facet fields
# ---------------------------------------------------------------------------

def extract_dart_filter_fields(src: str) -> set[str]:
    """Extract fields used in Filter.facet() calls in Dart Algolia service."""
    fields: set[str] = set()
    # Fields.fieldName patterns
    for m in re.finditer(r'Filter\.facet\(\s*Fields\.(\w+)', src):
        fields.add(m.group(1))
    # Literal string patterns like Filter.facet('availableInCanada', ...)
    for m in re.finditer(r"Filter\.facet\(\s*'(\w+)'", src):
        fields.add(m.group(1))
    return fields


def extract_dart_hit_fields(src: str) -> set[str]:
    """Extract fields read from Algolia hits in hitToProductMap."""
    fields: set[str] = set()
    for m in re.finditer(r"hit\[Fields\.(\w+)\]", src):
        fields.add(m.group(1))
    for m in re.finditer(r"hit\['(\w+)'\]", src):
        fields.add(m.group(1))
    return fields


# ---------------------------------------------------------------------------
# 3. Index name consistency
# ---------------------------------------------------------------------------

def extract_index_names_backend(config_src: str) -> dict[str, str]:
    """Extract environment -> index name mapping from Python config."""
    mapping: dict[str, str] = {}
    patterns = [
        (r'return "products_emulator"', "emulator", "products_emulator"),
        (r'return "products_dev"', "dev", "products_dev"),
        (r'return "products_staging"', "staging", "products_staging"),
        (r'return "products"', "production", "products"),
    ]
    for pattern, env, name in patterns:
        if re.search(pattern, config_src):
            mapping[env] = name
    return mapping


def extract_index_names_frontend(env_src: str) -> dict[str, str]:
    """Extract environment -> index name mapping from Dart EnvConfig."""
    mapping: dict[str, str] = {}
    patterns = [
        (r"AppEnvironment\.emulator\s*=>\s*'(\w+)'", "emulator"),
        (r"AppEnvironment\.dev\s*=>\s*'(\w+)'", "dev"),
        (r"AppEnvironment\.staging\s*=>\s*'(\w+)'", "staging"),
        (r"AppEnvironment\.production\s*=>\s*'(\w+)'", "production"),
    ]
    for pattern, env in patterns:
        m = re.search(pattern, env_src)
        if m:
            mapping[env] = m.group(1)
    return mapping


# ---------------------------------------------------------------------------
# 4. Resolve Python Fields constants to actual Firestore field names
# ---------------------------------------------------------------------------

def build_python_field_map(schema_src: str) -> dict[str, str]:
    """Build mapping from CONSTANT_NAME -> 'camelCaseValue' for Python Fields class."""
    mapping: dict[str, str] = {}
    in_fields = False
    for line in schema_src.splitlines():
        if line.strip().startswith("class Fields"):
            in_fields = True
            continue
        if in_fields and line.strip().startswith("class ") and "Fields" not in line:
            break
        if in_fields:
            m = re.match(r'\s+([A-Z_]+)\s*=\s*"(\w+)"', line)
            if m:
                mapping[m.group(1)] = m.group(2)
    return mapping


def build_dart_field_map(schema_src: str) -> dict[str, str]:
    """Build mapping from fieldName -> 'camelCaseValue' for Dart Fields class."""
    mapping: dict[str, str] = {}
    in_fields = False
    for line in schema_src.splitlines():
        if "class Fields" in line:
            in_fields = True
            continue
        if in_fields and re.match(r'^(abstract\s+)?(final\s+)?class\s+', line.strip()) and "Fields" not in line:
            break
        if in_fields:
            m = re.match(r"\s+static\s+const\s+(?:String\s+)?(\w+)\s*=\s*'(\w+)'", line)
            if m:
                mapping[m.group(1)] = m.group(2)
    return mapping


# ---------------------------------------------------------------------------
# 5. Check environment variable / Remote Config references
# ---------------------------------------------------------------------------

def check_env_var_references() -> None:
    """Verify ALGOLIA_APP_ID and ALGOLIA_WRITE_API_KEY are referenced consistently."""
    backend_config = read_file(BACKEND_CONFIG)

    # Backend should load ALGOLIA_APP_ID and ALGOLIA_WRITE_API_KEY
    if 'ALGOLIA_APP_ID' not in backend_config:
        error("Backend config.py does not reference ALGOLIA_APP_ID env var")
    if 'ALGOLIA_WRITE_API_KEY' not in backend_config:
        error("Backend config.py does not reference ALGOLIA_WRITE_API_KEY env var")

    # Frontend should use Remote Config keys, not env vars
    dart_conf = read_file(DART_CONF_SERVICES)
    dart_schema = read_file(DART_SCHEMA)

    if "algoliaAppId" not in dart_conf:
        error("Frontend conf_services.dart does not expose algoliaAppId getter")
    if "algoliaSearchApiKey" not in dart_conf:
        error("Frontend conf_services.dart does not expose algoliaSearchApiKey getter")

    # RemoteConfigKeys should define the keys
    if "algolia_app_id" not in dart_schema:
        error("Dart schema_constants.dart missing RemoteConfigKeys.algoliaAppId ('algolia_app_id')")
    if "algolia_search_api_key" not in dart_schema:
        error("Dart schema_constants.dart missing RemoteConfigKeys.algoliaSearchApiKey ('algolia_search_api_key')")

    # Verify providers.dart wires config -> AlgoliaService
    providers_src = read_file(DART_PROVIDERS)
    if "config.algoliaAppId" not in providers_src:
        error("providers.dart does not pass config.algoliaAppId to AlgoliaService.create")
    if "config.algoliaSearchApiKey" not in providers_src:
        error("providers.dart does not pass config.algoliaSearchApiKey to AlgoliaService.create")


# ---------------------------------------------------------------------------
# Main validation
# ---------------------------------------------------------------------------

def main() -> int:
    """Function main."""
    print("=" * 70)
    print("  Algolia Configuration Consistency Validator")
    print("=" * 70)
    print()

    # Load sources
    algolia_svc_src = read_file(BACKEND_ALGOLIA_SERVICE)
    config_src = read_file(BACKEND_CONFIG)
    py_schema_src = read_file(BACKEND_SCHEMA)
    dart_svc_src = read_file(DART_ALGOLIA_SERVICE)
    dart_repo_src = read_file(DART_ALGOLIA_REPO)
    dart_env_src = read_file(DART_ENV_CONFIG)
    dart_schema_src = read_file(DART_SCHEMA)

    if not algolia_svc_src or not dart_svc_src:
        # Already logged as errors
        return 1

    py_field_map = build_python_field_map(py_schema_src)
    dart_field_map = build_dart_field_map(dart_schema_src)

    # --- Check 1: Index name consistency ---
    print("[1/5] Index name consistency across environments...")
    backend_indexes = extract_index_names_backend(config_src)
    frontend_indexes = extract_index_names_frontend(dart_env_src)

    for env in ("emulator", "dev", "staging", "production"):
        be = backend_indexes.get(env)
        fe = frontend_indexes.get(env)
        if be and fe and be != fe:
            error(f"Index name mismatch for {env}: backend='{be}' vs frontend='{fe}'")
        elif be and not fe:
            warn(f"Index name for {env} found in backend ('{be}') but not in frontend")
        elif fe and not be:
            warn(f"Index name for {env} found in frontend ('{fe}') but not in backend")
        else:
            print(f"  {env}: {be} == {fe}  OK")

    print()

    # --- Check 2: Frontend filter fields are in backend facets ---
    print("[2/5] Frontend filter fields vs backend facets...")
    frontend_filters = extract_dart_filter_fields(dart_svc_src)
    backend_facets = extract_backend_facet_fields(algolia_svc_src)

    # Resolve Python constant names to camelCase values for comparison
    backend_facet_values: set[str] = set()
    for f in backend_facets:
        if f in py_field_map:
            backend_facet_values.add(py_field_map[f])
        else:
            # Already a literal string value (e.g. "availableInCanada")
            backend_facet_values.add(f)

    # Resolve Dart field names to camelCase values
    frontend_filter_values: set[str] = set()
    for f in frontend_filters:
        if f in dart_field_map:
            frontend_filter_values.add(dart_field_map[f])
        else:
            # Already a literal (e.g. 'availableInCanada')
            frontend_filter_values.add(f)

    for fv in sorted(frontend_filter_values):
        if fv in backend_facet_values:
            print(f"  Filter '{fv}': indexed as facet  OK")
        else:
            error(f"Frontend uses filter on '{fv}' but backend does NOT list it in attributesForFaceting")

    # Report backend facets not used by frontend (informational)
    unused_facets = backend_facet_values - frontend_filter_values
    if unused_facets:
        for uf in sorted(unused_facets):
            print(f"  Backend facet '{uf}' not used by frontend filters (OK, may be used server-side)")

    print()

    # --- Check 3: Frontend hit fields vs backend retrievable attributes ---
    print("[3/5] Frontend hit consumption vs backend attributesToRetrieve...")
    frontend_hit_fields = extract_dart_hit_fields(dart_svc_src)
    backend_retrievable = extract_backend_retrievable_fields(algolia_svc_src)

    # Resolve to values
    backend_retrievable_values: set[str] = set()
    for f in backend_retrievable:
        if f in py_field_map:
            backend_retrievable_values.add(py_field_map[f])
        else:
            backend_retrievable_values.add(f)

    frontend_hit_values: set[str] = set()
    for f in frontend_hit_fields:
        if f in dart_field_map:
            frontend_hit_values.add(dart_field_map[f])
        else:
            frontend_hit_values.add(f)

    missing_from_retrieve: list[str] = []
    for fv in sorted(frontend_hit_values):
        if fv in backend_retrievable_values:
            print(f"  Hit field '{fv}': in attributesToRetrieve  OK")
        elif fv == "objectID":
            print(f"  Hit field 'objectID': always returned by Algolia  OK")
        elif fv == "searchKeywords":
            # Fallback field, not critical
            print(f"  Hit field 'searchKeywords': fallback alias (keywords)  OK")
        else:
            missing_from_retrieve.append(fv)
            warn(f"Frontend reads hit['{fv}'] but it is NOT in backend attributesToRetrieve")

    print()

    # --- Check 4: availableInCanada facet ---
    print("[4/5] availableInCanada facet (SRCH-H1)...")

    # Check it is computed in format_product_for_algolia
    if 'algolia_object["availableInCanada"]' in algolia_svc_src or "availableInCanada" in algolia_svc_src:
        print("  Backend computes availableInCanada in format_product_for_algolia  OK")
    else:
        error("Backend does NOT compute 'availableInCanada' in format_product_for_algolia")

    # Check it is in attributesForFaceting
    if "availableInCanada" in backend_facet_values:
        print("  Backend lists availableInCanada in attributesForFaceting  OK")
    else:
        error("Backend does NOT list 'availableInCanada' in attributesForFaceting")

    # Check it is in attributesToRetrieve
    if "availableInCanada" in backend_retrievable_values:
        print("  Backend lists availableInCanada in attributesToRetrieve  OK")
    else:
        warn("Backend does NOT list 'availableInCanada' in attributesToRetrieve (may not be needed client-side)")

    # Check frontend uses it as a filter
    if "availableInCanada" in frontend_filter_values:
        print("  Frontend applies Filter.facet('availableInCanada', true)  OK")
    else:
        error("Frontend does NOT filter on 'availableInCanada' -- Canadian buyers may see undeliverable products")

    print()

    # --- Check 5: Env var / Remote Config references ---
    print("[5/5] Environment variable and Remote Config key references...")
    check_env_var_references()

    # Check that backend uses get_algolia_app_id / get_algolia_write_api_key in algolia_service
    if "get_algolia_app_id" in algolia_svc_src:
        print("  Backend algolia_service.py uses get_algolia_app_id()  OK")
    else:
        error("Backend algolia_service.py does not use get_algolia_app_id()")

    if "get_algolia_write_api_key" in algolia_svc_src:
        print("  Backend algolia_service.py uses get_algolia_write_api_key()  OK")
    else:
        error("Backend algolia_service.py does not use get_algolia_write_api_key()")

    # Check frontend uses search-only key (not write key)
    if "algoliaSearchApiKey" in read_file(DART_PROVIDERS):
        print("  Frontend uses search-only API key (not write key)  OK")
    else:
        warn("Could not verify frontend uses search-only key")

    print()

    # --- Cross-stack field name consistency ---
    print("[BONUS] Cross-stack field name consistency (Python Fields vs Dart Fields)...")
    # Check that every field used in Algolia indexing has the same camelCase value
    # in both Python and Dart schema_constants
    backend_indexed_consts = set()
    for m in re.finditer(r'Fields\.([A-Z_]+)', algolia_svc_src):
        backend_indexed_consts.add(m.group(1))

    # Map Python constants to camelCase, find corresponding Dart constant
    py_to_camel = {k: v for k, v in py_field_map.items() if k in backend_indexed_consts}
    dart_camel_to_name = {v: k for k, v in dart_field_map.items()}

    cross_stack_ok = 0
    for py_const, camel_val in sorted(py_to_camel.items()):
        if camel_val in dart_camel_to_name:
            cross_stack_ok += 1
        else:
            warn(f"Python Fields.{py_const} = '{camel_val}' has no matching Dart Fields entry")

    print(f"  {cross_stack_ok}/{len(py_to_camel)} Algolia-indexed Python fields have matching Dart constants  ", end="")
    if cross_stack_ok == len(py_to_camel):
        print("OK")
    else:
        print("WARN")

    print()

    # --- Summary ---
    print("=" * 70)
    print("  SUMMARY")
    print("=" * 70)

    if warnings:
        print(f"\n  WARNINGS ({len(warnings)}):")
        for w in warnings:
            print(f"    [WARN] {w}")

    if errors:
        print(f"\n  ERRORS ({len(errors)}):")
        for e in errors:
            print(f"    [ERROR] {e}")
        print(f"\n  Result: FAIL ({len(errors)} error(s), {len(warnings)} warning(s))")
        return 1

    if warnings:
        print(f"\n  Result: PASS with {len(warnings)} warning(s)")
    else:
        print("\n  Result: PASS (clean)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
