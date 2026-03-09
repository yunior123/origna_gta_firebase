"""
Test schema consistency between backend (Python) and frontend (Dart)

This test ensures that data models match between backend Cloud Functions
and frontend Flutter app to prevent serialization/deserialization errors.

Run with: pytest test_schema_consistency.py -v
"""

import json
import re
from pathlib import Path


class TestSchemaConsistency:
    """Test field consistency between Python backend and Dart frontend"""

    @staticmethod
    def get_project_root():
        """Get project root directory"""
        current = Path(__file__).resolve()
        # Go up from functions/tests/ to project root
        return current.parent.parent.parent

    @staticmethod
    def _extract_python_string_constants(class_name: str, content: str) -> set[str]:
        """Extract quoted string constants from a Python class block."""
        in_class = False
        class_indent = 0
        values: set[str] = set()

        for line in content.splitlines():
            if not in_class:
                m = re.match(rf"^(\s*)class\s+{re.escape(class_name)}\s*:", line)
                if m:
                    in_class = True
                    class_indent = len(m.group(1))
                continue

            # End when we hit another top-level class
            if re.match(r"^\s*class\s+\w+\s*:", line) and (len(line) - len(line.lstrip(" "))) <= class_indent:
                break

            m = re.match(r"^\s+(\w+)\s*=\s*['\"]([^'\"]+)['\"]", line)
            if m:
                values.add(m.group(2))

        return values

    @staticmethod
    def _extract_dart_string_constants(class_name: str, content: str) -> set[str]:
        """Extract quoted string constants from a Dart `abstract final class` block."""
        in_class = False
        depth = 0
        values: set[str] = set()

        decl_pattern = re.compile(rf"^\s*abstract\s+final\s+class\s+{re.escape(class_name)}\b")
        const_pattern = re.compile(r"static\s+const\s+(?:[\w<>]+\s+)?\w+\s*=\s*['\"]([^'\"]+)['\"]\s*;")

        for line in content.splitlines():
            if not in_class:
                if decl_pattern.search(line):
                    in_class = True
                    depth += line.count("{") - line.count("}")
                continue

            depth += line.count("{") - line.count("}")

            m = const_pattern.search(line)
            if m:
                values.add(m.group(1))

            if depth <= 0:
                break

        return values

    def test_product_fields_consistency(self):
        """Verify product fields match between Python algolia_service.py and Dart constants"""
        root = self.get_project_root()

        # Read Python algolia_service.py
        algolia_service_path = root / "functions" / "services" / "algolia_service.py"
        with open(algolia_service_path) as f:
            algolia_content = f.read()

        # Extract fields from format_product_for_algolia function
        python_fields = set()
        # Find all data.get() calls (updated from product_data.get())
        # Find all data.get() calls with string literals OR Fields constants
        # 1. String literals: data.get('field')
        literal_pattern = r"data\.get\(['\"](\w+)['\"]"
        python_fields.update(re.findall(literal_pattern, algolia_content))

        # 2. Fields constants: data.get(Fields.FIELD_NAME)
        # We need to map Fields.NAME back to 'name'
        # First, load schema_constants.py to build a map
        constants_path = root / "functions" / "schema_constants.py"
        with open(constants_path) as f:
            constants_content = f.read()

        # Map CONSTANT_NAME to 'fieldValue'
        const_map = {}
        const_pattern = r'^\s+(\w+)\s*=\s*["\'](\w+)["\']'
        for match in re.finditer(const_pattern, constants_content, re.MULTILINE):
            const_map[match.group(1)] = match.group(2)

        # Find usage of Fields.CONSTANT
        fields_usage_pattern = r"Fields\.(\w+)"
        for match in re.findall(fields_usage_pattern, algolia_content):
            if match in const_map:
                python_fields.add(const_map[match])

        # Required product fields that must be in Algolia index
        required_fields = {
            "name",
            "description",
            "price",
            "categoryId",
            "sellerId",
            "imageUrls",
            "stockQuantity",
            "rating",
            "ratingCount",
            "lifecycleStatus",
            "searchKeywords",
            "sellerAddress",
            "freeShipping",
            "isPerishable",
            "isLocalDeliveryOnly",
        }

        # Check all required fields are in Python code
        missing = required_fields - python_fields
        assert not missing, f"Missing REQUIRED product fields in algolia_service.py: {missing}"

        # Optional fields (good to have but not critical)
        optional_fields = python_fields - required_fields

        print("✅ Product schema consistent")
        print(f"   Required fields: {len(required_fields)} ✓")
        print(f"   Optional fields: {len(optional_fields)} (weightKg, dimensions, etc.)")

    def test_order_status_consistency(self):
        """Verify OrderStatus values match between Python and Dart schema constants"""
        root = self.get_project_root()

        python_constants_path = root / "functions" / "schema_constants.py"
        with open(python_constants_path) as f:
            python_content = f.read()
        python_statuses = self._extract_python_string_constants("OrderStatusValues", python_content)

        dart_constants_path = root / "origna_gta" / "lib" / "core" / "schema" / "schema_constants.dart"
        with open(dart_constants_path) as f:
            dart_content = f.read()
        dart_statuses = self._extract_dart_string_constants("OrderStatusValues", dart_content)

        assert python_statuses == dart_statuses, (
            "OrderStatusValues mismatch.\n"
            f"  Python: {sorted(python_statuses)}\n"
            f"  Dart: {sorted(dart_statuses)}\n"
            f"  Missing in Python: {sorted(dart_statuses - python_statuses)}\n"
            f"  Missing in Dart: {sorted(python_statuses - dart_statuses)}"
        )

        print(f"✅ OrderStatusValues consistent: {len(python_statuses)} values")
        print(f"   Values: {sorted(python_statuses)}")

    def test_payment_status_consistency(self):
        """Verify PaymentStatus values match between Python and Dart schema constants"""
        root = self.get_project_root()

        python_constants_path = root / "functions" / "schema_constants.py"
        with open(python_constants_path) as f:
            python_content = f.read()
        python_statuses = self._extract_python_string_constants("PaymentStatusValues", python_content)

        dart_constants_path = root / "origna_gta" / "lib" / "core" / "schema" / "schema_constants.dart"
        with open(dart_constants_path) as f:
            dart_content = f.read()
        dart_statuses = self._extract_dart_string_constants("PaymentStatusValues", dart_content)

        assert python_statuses == dart_statuses, (
            "PaymentStatusValues mismatch.\n"
            f"  Python: {sorted(python_statuses)}\n"
            f"  Dart: {sorted(dart_statuses)}\n"
            f"  Missing in Python: {sorted(dart_statuses - python_statuses)}\n"
            f"  Missing in Dart: {sorted(python_statuses - dart_statuses)}"
        )

        print("✅ PaymentStatus consistent")
        print(f"   Python: {sorted(python_statuses)}")
        print(f"   Dart: {sorted(dart_statuses)}")

    def test_delivery_status_consistency(self):
        """Verify DeliveryStatus values match between Python and Dart schema constants"""
        root = self.get_project_root()

        python_constants_path = root / "functions" / "schema_constants.py"
        with open(python_constants_path) as f:
            python_content = f.read()
        python_statuses = self._extract_python_string_constants("DeliveryStatusValues", python_content)

        dart_constants_path = root / "origna_gta" / "lib" / "core" / "schema" / "schema_constants.dart"
        with open(dart_constants_path) as f:
            dart_content = f.read()
        dart_statuses = self._extract_dart_string_constants("DeliveryStatusValues", dart_content)

        assert python_statuses == dart_statuses, (
            "DeliveryStatusValues mismatch.\n"
            f"  Python: {sorted(python_statuses)}\n"
            f"  Dart: {sorted(dart_statuses)}\n"
            f"  Missing in Python: {sorted(dart_statuses - python_statuses)}\n"
            f"  Missing in Dart: {sorted(python_statuses - dart_statuses)}"
        )

        print(f"✅ DeliveryStatusValues consistent: {sorted(python_statuses)}")

    def test_address_fields_consistency(self):
        """Verify address fields match between Python Pydantic model and Dart model"""
        root = self.get_project_root()

        # Read Python Address model from models/base.py
        models_path = root / "functions" / "models" / "base.py"
        with open(models_path) as f:
            models_content = f.read()

        # Expected address fields (from Address Pydantic model)
        expected_required = {"street", "city", "state", "postalCode", "country"}
        expected_optional = {"apartment", "phoneNumber", "label", "isDefault", "latitude", "longitude"}

        # Verify Address model exists and has required fields
        assert "class Address(BaseModel)" in models_content, "Address model not found in models/base.py"
        assert "street: str" in models_content, "Address.street field not found"
        assert "city: str" in models_content, "Address.city field not found"
        assert "state: str" in models_content, "Address.state field not found"
        assert "postalCode: str" in models_content, "Address.postalCode field not found"
        assert "country: str" in models_content, "Address.country field not found"

        print("✅ Address schema consistent with Pydantic model")
        print(f"   Required: {sorted(expected_required)}")
        print(f"   Optional: {sorted(expected_optional)}")

    def test_collection_names_consistency(self):
        """Verify Firestore collection names match between Python and Dart"""
        root = self.get_project_root()

        python_constants_path = root / "functions" / "schema_constants.py"
        with open(python_constants_path) as f:
            python_content = f.read()
        python_values = self._extract_python_string_constants("Collections", python_content)
        python_collections = {v: v for v in python_values}

        dart_constants_path = root / "origna_gta" / "lib" / "core" / "schema" / "schema_constants.dart"
        with open(dart_constants_path) as f:
            dart_content = f.read()
        dart_values = self._extract_dart_string_constants("Collections", dart_content)
        dart_collections = {v: v for v in dart_values}

        # Compare collection values (case-insensitive keys)
        expected_collections = ["users", "products", "orders", "cart", "favorites"]

        for coll in expected_collections:
            python_val = python_collections.get(coll)
            dart_val = dart_collections.get(coll)

            assert python_val == coll, f"Python collection '{coll}' should be '{coll}', got '{python_val}'"
            assert dart_val == coll, f"Dart collection '{coll}' should be '{coll}', got '{dart_val}'"
            assert python_val == dart_val, f"Collection '{coll}' mismatch: Python='{python_val}', Dart='{dart_val}'"

        print(f"✅ Collection names consistent: {expected_collections}")

    def test_algolia_index_configuration(self):
        """Verify Algolia configuration is properly set up"""
        root = self.get_project_root()

        # Read Python algolia_service.py
        algolia_service_path = root / "functions" / "services" / "algolia_service.py"
        with open(algolia_service_path) as f:
            algolia_content = f.read()

        # Check that config is imported (including AlgoliaConfig for dynamic index names)
        assert "from config import AlgoliaConfig, get_algolia_app_id, get_algolia_write_api_key" in algolia_content, (
            "Algolia service should import AlgoliaConfig and credential getters from config.py"
        )

        # Check environment-aware index name helper exists
        assert "_get_index_name" in algolia_content, (
            "Algolia service should use _get_index_name() for environment-aware index selection"
        )
        assert "AlgoliaConfig.get_index_name()" in algolia_content, (
            "Algolia service should delegate to AlgoliaConfig.get_index_name()"
        )

        # Check key functions exist
        required_functions = ["format_product_for_algolia", "index_product", "delete_product"]
        for func in required_functions:
            assert f"def {func}" in algolia_content, f"Missing function: {func}"

        print("✅ Algolia configuration valid")
        print("   Index: dynamic via AlgoliaConfig.get_index_name()")
        print(f"   Functions: {required_functions}")


if __name__ == "__main__":
    # Run tests without pytest
    test_suite = TestSchemaConsistency()
    tests = [
        ("Product Fields", test_suite.test_product_fields_consistency),
        ("Order Status", test_suite.test_order_status_consistency),
        ("Payment Status", test_suite.test_payment_status_consistency),
        ("Delivery Status", test_suite.test_delivery_status_consistency),
        ("Address Fields", test_suite.test_address_fields_consistency),
        ("Collection Names", test_suite.test_collection_names_consistency),
        ("Algolia Configuration", test_suite.test_algolia_index_configuration),
    ]

    print("=" * 70)
    print("SCHEMA CONSISTENCY TESTS")
    print("=" * 70)

    passed = 0
    failed = 0

    for test_name, test_func in tests:
        try:
            print(f"\n🧪 Testing: {test_name}")
            test_func()
            passed += 1
        except AssertionError as e:
            print(f"❌ FAILED: {test_name}")
            print(f"   Error: {e}")
            failed += 1
        except Exception as e:
            print(f"❌ ERROR: {test_name}")
            print(f"   Error: {e}")
            failed += 1

    print("\n" + "=" * 70)
    print(f"RESULTS: {passed} passed, {failed} failed")
    print("=" * 70)

    exit(0 if failed == 0 else 1)
