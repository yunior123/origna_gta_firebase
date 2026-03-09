"""
Schema Contract Tests - Enforce consistency between schema and code

These tests ensure:
1. The JSON schema is internally consistent (no conflicting field names)
2. Python code uses field names that exist in the schema
3. Field name constants match the actual schema definitions
4. No magic strings are used where constants should be

Run with: pytest tests/test_schema_contract.py -v
"""

import ast
import json
import re
from pathlib import Path

import pytest

# Paths
PROJECT_ROOT = Path(__file__).parent.parent.parent
SCHEMA_PATH = PROJECT_ROOT / "docs" / "database_schema.json"
FUNCTIONS_DIR = PROJECT_ROOT / "functions"
FLUTTER_DIR = PROJECT_ROOT / "origna_gta" / "lib"


# =============================================================================
# FIXTURES
# =============================================================================


@pytest.fixture(scope="module")
def schema() -> dict:
    """Load the database schema JSON"""
    with open(SCHEMA_PATH) as f:
        return json.load(f)


@pytest.fixture(scope="module")
def all_schema_fields(schema: dict) -> set[str]:
    """Extract all field names from the schema"""
    fields = set()

    def extract_fields(obj, prefix: str = ""):
        """Function extract_fields."""
        if isinstance(obj, dict):
            if "fields" in obj and isinstance(obj["fields"], dict):
                for field_name in obj["fields"]:
                    fields.add(field_name)
            for key, value in obj.items():
                if isinstance(value, dict):
                    extract_fields(value, f"{prefix}.{key}")
                elif isinstance(value, list):
                    for item in value:
                        if isinstance(item, dict):
                            extract_fields(item, prefix)

    # Extract from collections
    if "collections" in schema:
        extract_fields(schema["collections"])

    # Extract from shared schemas
    if "sharedSchemas" in schema:
        extract_fields(schema["sharedSchemas"])

    return fields


@pytest.fixture(scope="module")
def schema_timestamp_fields(schema: dict) -> dict[str, str]:
    """Map collection name to its timestamp field"""
    timestamp_map = {}

    if "collections" in schema:
        for collection_name, collection_def in schema["collections"].items():
            if "fields" in collection_def and "createdAt" in collection_def["fields"]:
                # Check for common timestamp fields
                timestamp_map[collection_name] = "createdAt"

            # Check subcollections
            if "subcollections" in collection_def:
                for sub_name, sub_def in collection_def["subcollections"].items():
                    if "fields" in sub_def and "createdAt" in sub_def["fields"]:
                        timestamp_map[sub_name] = "createdAt"

    return timestamp_map


# =============================================================================
# SCHEMA CONSISTENCY TESTS
# =============================================================================


class TestSchemaConsistency:
    """Tests for internal schema consistency"""

    def test_schema_file_exists(self):
        """Verify schema file exists"""
        assert SCHEMA_PATH.exists(), f"Schema file not found at {SCHEMA_PATH}"

    def test_schema_is_valid_json(self):
        """Verify schema is valid JSON"""
        with open(SCHEMA_PATH) as f:
            schema = json.load(f)
        assert isinstance(schema, dict)
        assert "collections" in schema

    def test_all_collections_have_fields(self, schema: dict):
        """Verify all collections define their fields"""
        for name, definition in schema["collections"].items():
            assert "fields" in definition, f"Collection '{name}' missing 'fields'"

    def test_timestamp_fields_documented(self, schema: dict, schema_timestamp_fields: dict[str, str]):
        """Verify timestamp field naming is consistent and documented"""
        # This test documents the current state (some use createdAt, some createdAt)
        expected_timestamps = {
            "users": "createdAt",
            "products": "createdAt",
            "orders": "createdAt",
            "payouts": "createdAt",
            "cart": "createdAt",
        }

        for collection, expected_field in expected_timestamps.items():
            if collection in schema_timestamp_fields:
                actual = schema_timestamp_fields[collection]
                assert actual == expected_field, (
                    f"Collection '{collection}' uses '{actual}' but expected '{expected_field}'. "
                    f"Update schema or test if intentional."
                )

    def test_money_fields_use_cents_suffix(self, schema: dict):
        """Verify money fields use Cents suffix (not dollars)"""
        money_field_pattern = re.compile(r"(amount|total|fee|cost|price)", re.IGNORECASE)
        cents_suffix_pattern = re.compile(r"Cents$")

        # Fields that are exceptions (prices stored as dollars for display)
        exceptions = {"price"}

        violations = []

        def check_fields(fields: dict, collection: str):
            """Function check_fields."""
            for field_name, field_def in fields.items():
                if field_name in exceptions:
                    continue
                if money_field_pattern.search(field_name):
                    desc = field_def.get("description", "").lower()
                    if "cents" in desc and not cents_suffix_pattern.search(field_name):
                        violations.append(f"{collection}.{field_name} describes cents but doesn't have Cents suffix")

        for coll_name, coll_def in schema["collections"].items():
            if "fields" in coll_def:
                check_fields(coll_def["fields"], coll_name)

        if violations:
            pytest.fail("\n".join(violations))

    def test_required_fields_marked(self, schema: dict):
        """Verify critical fields are marked as required"""
        critical_required = {
            "users": ["uid", "email", "name", "roles", "createdAt"],
            "products": ["name", "price", "description", "imageUrls", "sellerId", "categoryId"],
            "orders": ["userId", "items", "orderStatus", "paymentStatus", "createdAt"],
        }

        for collection, required_fields in critical_required.items():
            if collection in schema["collections"]:
                coll_fields = schema["collections"][collection].get("fields", {})
                for field in required_fields:
                    assert field in coll_fields, f"Missing field '{field}' in {collection}"
                    field_def = coll_fields[field]
                    is_required = field_def.get("required", False)
                    has_default = "default" in field_def
                    assert is_required or has_default, (
                        f"Field '{collection}.{field}' should be required or have a default"
                    )


# =============================================================================
# PYTHON CODE CONTRACT TESTS
# =============================================================================


class TestPythonSchemaContract:
    """Tests that Python code matches the schema"""

    def test_cron_jobs_uses_correct_timestamp_field(self):
        """
        CRITICAL: Verify cron_jobs.py queries 'createdAt' for orders, not 'createdAt'.
        This was a real bug that this test prevents from recurring.

        Accepts both:
        - String literal: .where('createdAt', ...)
        - Constant: .where(Fields.CREATED_AT, ...)
        """
        cron_file = FUNCTIONS_DIR / "handlers" / "cron_jobs.py"
        content = cron_file.read_text()

        # Should use createdAt for orders - either as string literal or via Fields constant
        uses_created_at_literal = ".where('createdAt'" in content or '.where("createdAt"' in content
        uses_created_at_constant = "Fields.CREATED_AT" in content

        assert uses_created_at_literal or uses_created_at_constant, (
            "cron_jobs.py should query 'createdAt' for orders (either as string or Fields.CREATED_AT)"
        )

        # Should NOT use createdAt for orders (either as literal or constant)
        # For orders collection, CREATED_AT should not appear in order queries
        order_section_match = re.search(r"collection\(['\"]orders['\"]\).*?\.stream\(\)", content, re.DOTALL)

        if order_section_match:
            order_section = order_section_match.group(0)
            assert "createdAt" not in order_section.lower() or "CREATED_AT" not in order_section, (
                "cron_jobs.py should NOT query 'createdAt' for orders collection. "
                "Orders use 'createdAt'. Found violations."
            )

    def test_schema_constants_match_schema_fields(self, all_schema_fields: set[str]):
        """Verify schema_constants.py defines fields that exist in schema"""
        constants_file = FUNCTIONS_DIR / "schema_constants.py"
        if not constants_file.exists():
            pytest.skip("schema_constants.py not found")

        content = constants_file.read_text()

        # Extract field values from Fields class
        field_pattern = re.compile(r'(\w+)\s*=\s*["\'](\w+)["\']')
        defined_fields = {match.group(2) for match in field_pattern.finditer(content)}

        # Check that defined constants exist in schema (allowing some extras for flexibility)
        # This is informational - we don't fail on extras
        missing_from_schema = defined_fields - all_schema_fields
        if missing_from_schema:
            print(f"Fields in constants but not in schema: {missing_from_schema}")

    def test_no_magic_timestamp_strings_in_handlers(self):
        """Check for hardcoded timestamp field names in handler files"""
        handlers_dir = FUNCTIONS_DIR / "handlers"

        violations = []
        timestamp_pattern = re.compile(r"['\"](?:createdAt|createdAt|updatedAt)['\"]")

        for py_file in handlers_dir.glob("*.py"):
            content = py_file.read_text()
            lines = content.split("\n")

            for line_num, line in enumerate(lines, 1):
                # Skip comments and imports
                stripped = line.strip()
                if stripped.startswith("#") or stripped.startswith("from ") or stripped.startswith("import "):
                    continue

                matches = timestamp_pattern.findall(line)
                if matches:
                    # This is informational - shows where constants SHOULD be used
                    violations.append(f"{py_file.name}:{line_num}: {matches}")

        if violations:
            print("\nTimestamp strings found (consider using Fields constants):")
            for v in violations[:20]:  # Limit output
                print(f"  {v}")

    def test_pydantic_models_field_names_match_schema(self, schema: dict):
        """Verify Pydantic model field names match schema definitions"""
        models_dir = FUNCTIONS_DIR / "models"

        # Map Pydantic model files to schema collections
        model_to_collection = {
            "product.py": "products",
            "order.py": "orders",
            "user.py": "users",
        }

        for model_file, collection in model_to_collection.items():
            model_path = models_dir / model_file
            if not model_path.exists():
                continue

            content = model_path.read_text()

            # Get expected fields from schema
            if collection not in schema["collections"]:
                continue

            schema_fields = set(schema["collections"][collection]["fields"].keys())

            # Extract Pydantic field names (simplified - looks for field: type patterns)
            pydantic_pattern = re.compile(r"^\s+(\w+):\s+(?:Optional\[)?(?:\w+)", re.MULTILINE)
            model_fields = {m.group(1) for m in pydantic_pattern.finditer(content)}

            # Filter to only real field names (exclude 'model_config', etc.)
            model_fields = {f for f in model_fields if not f.startswith("_") and f != "model_config"}

            # Check for major discrepancies
            # Note: Pydantic may have extra computed fields, so we only check schema fields exist
            missing_in_model = schema_fields - model_fields

            # Only fail on critical missing fields
            critical_fields = {"name", "price", "userId", "orderId", "productId"}
            critical_missing = missing_in_model & critical_fields

            if critical_missing:
                pytest.fail(f"Model {model_file} missing critical fields from schema: {critical_missing}")


# =============================================================================
# DART CODE CONTRACT TESTS
# =============================================================================


class TestDartSchemaContract:
    """Tests that Dart code matches the schema"""

    def test_dart_constants_file_exists(self):
        """Verify Dart schema constants file exists"""
        dart_constants = FLUTTER_DIR / "core" / "schema" / "schema_constants.dart"
        assert dart_constants.exists(), (
            f"Dart schema constants not found at {dart_constants}. Create it to maintain consistency with Python."
        )

    def test_dart_constants_match_python_constants(self):
        """Verify Dart and Python constants define the same fields"""
        python_constants = FUNCTIONS_DIR / "schema_constants.py"
        dart_constants = FLUTTER_DIR / "core" / "schema" / "schema_constants.dart"

        if not python_constants.exists() or not dart_constants.exists():
            pytest.skip("Constants files not found")

        # Extract Python field values
        py_content = python_constants.read_text()
        py_pattern = re.compile(r'(\w+)\s*=\s*["\'](\w+)["\']')
        py_fields = {m.group(2) for m in py_pattern.finditer(py_content) if not m.group(1).startswith("_")}

        # Extract Dart field values
        dart_content = dart_constants.read_text()
        dart_pattern = re.compile(r"static const (\w+)\s*=\s*['\"](\w+)['\"]")
        dart_fields = {m.group(2) for m in dart_pattern.finditer(dart_content)}

        # Compare
        only_in_python = py_fields - dart_fields
        only_in_dart = dart_fields - py_fields

        # Allow some differences but warn
        if only_in_python:
            print(f"\nFields only in Python constants: {only_in_python}")
        if only_in_dart:
            print(f"\nFields only in Dart constants: {only_in_dart}")

        # Critical fields must exist in both
        critical = {"createdAt", "updatedAt", "orderId", "userId", "productId", "sellerId"}
        missing_critical_py = critical - py_fields
        missing_critical_dart = critical - dart_fields

        assert not missing_critical_py, f"Python constants missing critical fields: {missing_critical_py}"
        assert not missing_critical_dart, f"Dart constants missing critical fields: {missing_critical_dart}"

    def test_dart_repositories_use_correct_timestamp(self):
        """Verify Dart repositories use correct timestamp field per collection"""
        repos_dir = FLUTTER_DIR / "core" / "repositories"

        violations = []

        # What each repository should use
        expected = {
            "order_repository.dart": ("orders", "createdAt"),
            "product_repository.dart": ("products", "createdAt"),
        }

        for repo_file, (collection, expected_field) in expected.items():
            repo_path = repos_dir / repo_file
            if not repo_path.exists():
                continue

            content = repo_path.read_text()

            # Check orderBy clauses
            wrong_field = "createdAt" if expected_field == "createdAt" else "createdAt"

            # Look for orderBy with wrong field
            wrong_pattern = re.compile(rf"\.orderBy\(['\"]({wrong_field})['\"]", re.IGNORECASE)

            matches = wrong_pattern.findall(content)
            if matches:
                violations.append(
                    f"{repo_file} uses '{wrong_field}' for {collection} but should use '{expected_field}'"
                )

        if violations:
            pytest.fail("\n".join(violations))


# =============================================================================
# DRIFT DETECTION TESTS
# =============================================================================


class TestSchemaDrift:
    """Tests to detect schema drift over time"""

    def test_schema_version_documented(self, schema: dict):
        """Verify schema has a version number"""
        assert "version" in schema, "Schema should have a version number"
        assert "lastUpdated" in schema, "Schema should have lastUpdated date"

    def test_parallel_field_usage_tracking(self):
        """Track where parallel fields are still used across codebases"""
        tracked_fields = {
            "deliveryStatus": "Parallel field alongside 'status'",
            "createdAt": "Used by products and cart collections",
        }

        # Informational only — tracks usage but does not fail
        print("\nParallel field usage (informational):")

        for field, replacement in tracked_fields.items():
            # Count usage in Python
            py_count = 0
            for py_file in FUNCTIONS_DIR.rglob("*.py"):
                if "test_" in py_file.name or "__pycache__" in str(py_file):
                    continue
                content = py_file.read_text()
                py_count += content.count(f"'{field}'") + content.count(f'"{field}"')

            if py_count > 0:
                print(f"  '{field}': {py_count} usages in Python ({replacement})")

    def test_enum_values_match_schema(self, schema: dict):
        """Verify enum values in code match schema definitions"""
        if "enums" not in schema:
            pytest.skip("Schema has no enums section")

        from schema_constants import (
            DeliveryStatusValues,
            OrderStatusValues,
            PaymentStatusValues,
            PayoutStatusValues,
        )

        # Map our constants to schema enums
        enum_mapping = {
            "OrderStatus": OrderStatusValues.ALL,
            "PaymentStatus": PaymentStatusValues.ALL,
            "DeliveryStatus": DeliveryStatusValues.ALL,
            "PayoutStatus": PayoutStatusValues.ALL,
        }

        for enum_name, code_values in enum_mapping.items():
            if enum_name not in schema["enums"]:
                continue

            schema_values = set(schema["enums"][enum_name].get("values", {}).keys())

            missing_in_code = schema_values - code_values
            extra_in_code = code_values - schema_values

            if missing_in_code:
                pytest.fail(f"{enum_name} missing values in code: {missing_in_code}")

            # Extra values in code might be intentional (future-proofing)
            if extra_in_code:
                print(f"\n{enum_name} has extra values not in schema: {extra_in_code}")


# =============================================================================
# HELPER TESTS FOR CI
# =============================================================================


class TestSchemaCI:
    """Tests specifically for CI pipeline validation"""

    def test_schema_json_is_valid_and_parseable(self):
        """Quick smoke test for CI - schema loads without error"""
        with open(SCHEMA_PATH) as f:
            schema = json.load(f)

        assert "collections" in schema
        assert len(schema["collections"]) > 0

    def test_critical_field_names_are_correct(self, schema: dict):
        """
        Hard-coded test for the most critical field names.
        If these fail, something is seriously wrong.
        """
        # Orders MUST use createdAt
        assert "createdAt" in schema["collections"]["orders"]["fields"]

        # Products use createdAt as their timestamp field
        assert "createdAt" in schema["collections"]["products"]["fields"]

        # Money fields use Cents suffix
        order_fields = schema["collections"]["orders"]["fields"]
        assert "subtotalCents" in order_fields
        assert "taxAmountCents" in order_fields
        assert "totalAmountCents" in order_fields

        # Status fields have correct names
        assert "orderStatus" in order_fields
        assert "paymentStatus" in order_fields


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
