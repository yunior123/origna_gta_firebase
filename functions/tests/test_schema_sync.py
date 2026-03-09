"""
Tests for Schema Synchronization Script

Tests the Python-to-Dart schema generation to ensure consistency
across the Flutter frontend and Python backend.
"""

# Import the sync script functions
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))
from sync_schema import (
    CLASS_MAPPING,
    compare_values,
    extract_business_rules,
    extract_python_class_constants,
    generate_business_rules_class,
    generate_enum_class,
    to_dart_camel_case,
    update_class_in_dart,
)


class TestExtractPythonConstants:
    """Tests for extracting constants from Python source files."""

    def test_extract_order_status(self, tmp_path):
        """Should extract OrderStatus class constants."""
        python_file = tmp_path / "config.py"
        python_file.write_text("""
class OrderStatus:
    PENDING = 'pending'
    CONFIRMED = 'confirmed'
    PROCESSING = 'processing'
    SHIPPED = 'shipped'
    DELIVERED = 'delivered'
    CANCELLED = 'cancelled'
""")

        result = extract_python_class_constants(python_file, "OrderStatus")

        assert result["PENDING"] == "pending"
        assert result["CONFIRMED"] == "confirmed"
        assert result["SHIPPED"] == "shipped"
        assert len(result) == 6

    def test_extract_payment_status(self, tmp_path):
        """Should extract PaymentStatus class constants."""
        python_file = tmp_path / "config.py"
        python_file.write_text("""
class PaymentStatus:
    AWAITING_PAYMENT = 'awaiting_payment'
    AUTHORIZED = 'authorized'
    CAPTURED = 'captured'
    REFUNDED = 'refunded'
""")

        result = extract_python_class_constants(python_file, "PaymentStatus")

        assert result["AWAITING_PAYMENT"] == "awaiting_payment"
        assert result["AUTHORIZED"] == "authorized"
        assert result["CAPTURED"] == "captured"

    def test_extract_user_roles(self, tmp_path):
        """Should extract UserRoles class constants."""
        python_file = tmp_path / "config.py"
        python_file.write_text("""
class UserRoles:
    ADMIN = 'admin'
    SELLER = 'seller'
    BUYER = 'buyer'
""")

        result = extract_python_class_constants(python_file, "UserRoles")

        assert result["ADMIN"] == "admin"
        assert result["SELLER"] == "seller"
        assert result["BUYER"] == "buyer"

    def test_empty_class(self, tmp_path):
        """Should return empty dict for non-existent class."""
        python_file = tmp_path / "config.py"
        python_file.write_text("""
class ExistingClass:
    VALUE = 'test'
""")

        result = extract_python_class_constants(python_file, "NonExistentClass")
        assert result == {}


class TestExtractBusinessRules:
    """Tests for extracting business rule constants."""

    def test_extract_platform_fee(self, tmp_path):
        """Should extract PLATFORM_FEE_PERCENT."""
        python_file = tmp_path / "config.py"
        python_file.write_text("""
PLATFORM_FEE_PERCENT = 2.5  # 2.5%
AUTO_CONFIRM_DAYS = 5
AUTHORIZATION_EXPIRY_DAYS = 6
""")

        result = extract_business_rules(python_file)

        assert result["platformFeePercent"] == 2.5
        assert result["autoConfirmDays"] == 5
        assert result["authorizationExpiryDays"] == 6

    def test_missing_values(self, tmp_path):
        """Should handle missing values gracefully."""
        python_file = tmp_path / "config.py"
        python_file.write_text("""
# No business rules defined
SOME_OTHER_CONSTANT = 'value'
""")

        result = extract_business_rules(python_file)

        assert result == {}


class TestNameConversion:
    """Tests for name conversion functions."""

    def test_to_dart_camel_case(self):
        """Should convert UPPER_SNAKE_CASE to lowerCamelCase."""
        assert to_dart_camel_case("PENDING") == "pending"
        assert to_dart_camel_case("PARTIALLY_REFUNDED") == "partiallyRefunded"
        assert to_dart_camel_case("IN_TRANSIT") == "inTransit"
        assert to_dart_camel_case("AWAITING_PAYMENT") == "awaitingPayment"


class TestGenerateEnumClass:
    """Tests for Dart enum class generation."""

    def test_generates_valid_dart_code(self):
        """Should generate syntactically valid Dart code."""
        values = {
            "PENDING": "pending",
            "CONFIRMED": "confirmed",
        }

        dart_code = generate_enum_class("OrderStatusValues", values)

        assert "abstract final class OrderStatusValues" in dart_code
        assert "static const pending = 'pending';" in dart_code
        assert "static const confirmed = 'confirmed';" in dart_code
        assert "static const all = {" in dart_code

    def test_creates_all_set(self):
        """Should create 'all' set with all values."""
        values = {
            "PENDING": "pending",
            "SHIPPED": "shipped",
        }

        dart_code = generate_enum_class("DeliveryStatusValues", values)

        assert "static const all = {" in dart_code
        assert "pending," in dart_code
        assert "shipped," in dart_code

    def test_sorts_alphabetically(self):
        """Should sort values alphabetically."""
        values = {
            "ZEBRA": "zebra",
            "ALPHA": "alpha",
            "BETA": "beta",
        }

        dart_code = generate_enum_class("TestValues", values)

        # alpha should come before beta and zebra
        alpha_pos = dart_code.find("alpha")
        beta_pos = dart_code.find("beta")
        zebra_pos = dart_code.find("zebra")
        assert alpha_pos < beta_pos < zebra_pos


class TestGenerateBusinessRulesClass:
    """Tests for BusinessRules class generation."""

    def test_generates_class(self):
        """Should generate BusinessRules class."""
        rules = {
            "platformFeePercent": 2.5,
            "autoConfirmDays": 5,
        }

        dart_code = generate_business_rules_class(rules)

        assert "abstract final class BusinessRules" in dart_code
        assert "static const platformFeePercent = 2.5;" in dart_code
        assert "static const autoConfirmDays = 5;" in dart_code

    def test_formats_integers(self):
        """Should format integer values correctly."""
        rules = {
            "autoConfirmDays": 5,
        }

        dart_code = generate_business_rules_class(rules)

        assert "static const autoConfirmDays = 5;" in dart_code


class TestUpdateClassInDart:
    """Tests for updating classes in Dart content."""

    def test_updates_existing_class(self):
        """Should update existing class in Dart content."""
        dart_content = """
/// Valid values for orderStatus field
abstract final class OrderStatusValues {
  static const pending = 'pending';
  static const all = {pending};
}
"""
        new_class = """
/// Valid values for orderStatus field
abstract final class OrderStatusValues {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const all = {pending, confirmed};
}
"""
        result = update_class_in_dart(dart_content, "OrderStatusValues", new_class)

        assert "static const confirmed = " in result
        assert "static const pending = " in result

    def test_preserves_other_classes(self):
        """Should not modify other classes."""
        dart_content = """
abstract final class OrderStatusValues {
  static const pending = 'pending';
}

abstract final class PaymentStatusValues {
  static const authorized = 'authorized';
}
"""
        new_class = """
abstract final class OrderStatusValues {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
}
"""
        result = update_class_in_dart(dart_content, "OrderStatusValues", new_class)

        assert "PaymentStatusValues" in result
        assert "authorized" in result


class TestCompareValues:
    """Tests for value comparison."""

    def test_equal_values(self):
        """Should return True for matching values."""
        python_values = {
            "PENDING": "pending",
            "CONFIRMED": "confirmed",
        }
        dart_values = {
            "pending": "pending",
            "confirmed": "confirmed",
        }

        assert compare_values(python_values, dart_values) is True

    def test_different_values(self):
        """Should return False for different values."""
        python_values = {
            "PENDING": "pending",
            "CONFIRMED": "confirmed",
        }
        dart_values = {
            "pending": "pending",
        }

        assert compare_values(python_values, dart_values) is False

    def test_different_content(self):
        """Should return False for same keys but different values."""
        python_values = {
            "PENDING": "pending",
        }
        dart_values = {
            "pending": "old_pending",
        }

        assert compare_values(python_values, dart_values) is False


class TestClassMapping:
    """Tests for the class mapping configuration."""

    def test_mapping_exists(self):
        """Should have mappings for all expected classes."""
        expected_mappings = {
            "OrderStatus": "OrderStatusValues",
            "PaymentStatus": "PaymentStatusValues",
            "DeliveryStatus": "DeliveryStatusValues",
            "UserRoles": "UserRoleValues",
        }

        for py_class, dart_class in expected_mappings.items():
            assert py_class in CLASS_MAPPING
            assert CLASS_MAPPING[py_class] == dart_class


class TestEndToEnd:
    """End-to-end tests for the sync process."""

    def test_full_sync_process(self, tmp_path):
        """Test the complete sync process from Python to Dart."""
        # Create Python source
        python_source = tmp_path / "config.py"
        python_source.write_text("""
class OrderStatus:
    PENDING = 'pending'
    CONFIRMED = 'confirmed'

    class PaymentStatus:
        AUTHORIZED = 'authorized'
        CAPTURED = 'captured'

    PLATFORM_FEE_PERCENT = 2.5
    AUTO_CONFIRM_DAYS = 5
    """)
        # Create initial Dart content
        dart_file = tmp_path / "schema.dart"
        dart_file.write_text("""
// Schema Constants

abstract final class OrderStatusValues {
  static const pending = 'pending';
  static const all = {pending};
}

abstract final class PaymentStatusValues {
  static const authorized = 'authorized';
  static const all = {authorized};
}

abstract final class BusinessRules {
  static const platformFeePercent = 2.0;
}
""")

        # Extract from Python
        business_rules = extract_business_rules(python_source)

        # Read Dart content
        dart_content = dart_file.read_text()

        # Update BusinessRules (simplest case - single class to update)
        new_rules_class = generate_business_rules_class(business_rules)
        updated_content = update_class_in_dart(dart_content, "BusinessRules", new_rules_class)

        # Verify BusinessRules was updated
        assert "static const platformFeePercent = 2.5;" in updated_content

        # Verify other classes are preserved
        assert "OrderStatusValues" in updated_content
        assert "PaymentStatusValues" in updated_content

        # Write and verify file
        dart_file.write_text(updated_content)
        assert dart_file.exists()
        final_content = dart_file.read_text()
        assert "BusinessRules" in final_content
        assert "platformFeePercent = 2.5" in final_content


if __name__ == "__main__":
    pytest.main([__file__, "-v"])


def test_digital_product_constants_exist():
    """Function test_digital_product_constants_exist."""
    from schema_constants import Collections, Fields

    assert hasattr(Fields, "DIGITAL_TYPE")
    assert hasattr(Fields, "SLUG")
    assert hasattr(Fields, "DIGITAL_BUILDS")
    assert hasattr(Fields, "BOOK_SOURCE_URL")
    assert hasattr(Fields, "DEVICE_LIMIT")
    assert hasattr(Fields, "LICENSE_KEY")
    assert hasattr(Fields, "DIGITAL_UNLOCKED")
    assert hasattr(Fields, "SUPPORTED_PLATFORMS")
    assert hasattr(Fields, "ACTIVATIONS")
    assert hasattr(Fields, "DEVICE_ID")
    assert hasattr(Fields, "LAST_VERIFIED_AT")
    assert hasattr(Fields, "ACCESS_TOKEN")
    assert hasattr(Fields, "BOOK_ACCESS_TOKEN")
    assert hasattr(Collections, "LICENSES")
    assert hasattr(Collections, "BOOK_ACCESS_TOKENS")


def test_digital_type_values_exist():
    """Function test_digital_type_values_exist."""
    from schema_constants import DigitalPlatformValues, DigitalTypeValues

    assert DigitalTypeValues.SOFTWARE == "software"
    assert DigitalTypeValues.BOOK == "book"
    assert "macos" in DigitalPlatformValues.ALL
    assert "windows" in DigitalPlatformValues.ALL
    assert "linux" in DigitalPlatformValues.ALL
    assert DigitalPlatformValues.MACOS == "macos"
    assert DigitalPlatformValues.WINDOWS == "windows"
    assert DigitalPlatformValues.LINUX == "linux"
