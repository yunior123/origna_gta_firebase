#!/usr/bin/env python3
"""
Schema Synchronization Script
=============================

Synchronizes schema constants between Python backend and Dart frontend.
This script only updates enum value classes that have corresponding Python sources:
- OrderStatusValues (from Python schema_constants.OrderStatusValues)
- PaymentStatusValues (from Python schema_constants.PaymentStatusValues)
- DeliveryStatusValues (from Python schema_constants.DeliveryStatusValues)
- UserRoleValues (from Python schema_constants.UserRoleValues)
- BusinessRules (from Python schema_constants.BusinessRules)

All other classes in the Dart file are preserved as-is.

Usage:
    python scripts/sync_schema.py [--check]

Options:
    --check    Verify schemas match without writing files (CI mode)
"""

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

# Configuration
PROJECT_ROOT = Path(__file__).parent.parent
PYTHON_SCHEMA_SOURCE = PROJECT_ROOT / "functions" / "schema_constants.py"
DART_SCHEMA_FILE = PROJECT_ROOT / "origna_gta" / "lib" / "core" / "schema" / "schema_constants.dart"


# Mapping of Python class names to Dart class names
CLASS_MAPPING = {
    'OrderStatus': 'OrderStatusValues',
    'PaymentStatus': 'PaymentStatusValues',
    'DeliveryStatus': 'DeliveryStatusValues',
    'UserRoles': 'UserRoleValues',
}

PYTHON_CLASS_FALLBACKS = {
    "OrderStatus": "OrderStatusValues",
    "PaymentStatus": "PaymentStatusValues",
    "DeliveryStatus": "DeliveryStatusValues",
    "UserRoles": "UserRoleValues",
}


def extract_python_class_constants(file_path: Path, class_name: str) -> dict[str, str]:
    """Extract string constant values from a Python class."""
    content = file_path.read_text()
    
    # Find class definition (handle both "class Name:" and "class Name(object):")
    class_pattern = rf"class {class_name}(?:\([^)]*\))?:\n(.*?)(?:\nclass|\Z)"
    class_match = re.search(class_pattern, content, re.DOTALL)
    
    if not class_match:
        return {}
    
    class_body = class_match.group(1)
    if not class_body:
        return {}
    
    constants = {}
    
    # Extract NAME = 'value' patterns
    for match in re.finditer(r"([A-Z_]+)\s*=\s*['\"]([^'\"]+)['\"]", class_body):
        name = match.group(1)
        value = match.group(2)
        constants[name] = value
    
    return constants


def extract_business_rules(file_path: Path) -> dict[str, Any]:
    """Extract business rule constants from schema constants."""
    content = file_path.read_text()
    class_pattern = r"class BusinessRules(?:\([^)]*\))?:\n(.*?)(?:\nclass|\Z)"
    class_match = re.search(class_pattern, content, re.DOTALL)
    search_body = class_match.group(1) if class_match else content
    if not search_body:
        return {}
    rules = {}

    # PLATFORM_FEE_PERCENT:
    # schema_constants.BusinessRules uses percent (2.5)
    match = re.search(r"PLATFORM_FEE_PERCENT\s*=\s*(\d+\.?\d*)", search_body)
    if match:
        rules["platformFeePercent"] = float(match.group(1))

    match = re.search(r"AUTO_CONFIRM_DAYS\s*=\s*(\d+)", search_body)
    if match:
        rules["autoConfirmDays"] = int(match.group(1))

    match = re.search(r"AUTHORIZATION_EXPIRY_DAYS\s*=\s*(\d+)", search_body)
    if match:
        rules["authorizationExpiryDays"] = int(match.group(1))

    return rules


def to_dart_camel_case(snake_case: str) -> str:
    """Convert UPPER_SNAKE_CASE to lowerCamelCase."""
    parts = snake_case.lower().split('_')
    return parts[0] + ''.join(word.capitalize() for word in parts[1:])


def generate_enum_class(name: str, values: dict[str, str]) -> str:
    """Generate a Dart enum values class."""
    lines = []
    
    # Add doc comment based on class name
    if name == 'OrderStatusValues':
        lines.append("/// Valid values for orderStatus field")
    elif name == 'PaymentStatusValues':
        lines.append("/// Valid values for paymentStatus field")
    elif name == 'DeliveryStatusValues':
        lines.append("/// Valid values for deliveryStatus/status field on order items")
    elif name == 'UserRoleValues':
        lines.append("/// Valid values for roles array")
    else:
        lines.append(f"/// Valid values for {name.replace('Values', '').lower()} field")
    
    lines.append(f"abstract final class {name} {{")
    
    # Add individual values
    for const_name, value in sorted(values.items()):
        dart_name = to_dart_camel_case(const_name)
        lines.append(f"  static const {dart_name} = '{value}';")
    
    # Add 'all' set
    lines.append("")
    lines.append("  static const all = {")
    dart_names = [to_dart_camel_case(name) for name in sorted(values.keys())]
    for dart_name in dart_names:
        lines.append(f"    {dart_name},")
    lines.append("  };")
    lines.append("}")
    
    return "\n".join(lines)


def generate_business_rules_class(rules: dict[str, Any]) -> str:
    """Generate the BusinessRules Dart class."""
    lines = [
        "/// Business rule constants",
        "abstract final class BusinessRules {"
    ]
    
    for name, value in sorted(rules.items()):
        if isinstance(value, float):
            # Format floats nicely
            if value == int(value):
                lines.append(f"  static const {name} = {int(value)};")
            else:
                lines.append(f"  static const {name} = {value};")
        else:
            lines.append(f"  static const {name} = {value};")
    
    lines.append("}")
    return "\n".join(lines)


def update_class_in_dart(dart_content: str, class_name: str, new_class_content: str) -> str:
    """Update a specific class in the Dart content while preserving everything else."""
    # Pattern to match the class definition
    # Matches from "/// Valid values..." comment through the closing "}"
    pattern = rf"(/// Valid values.*?\n)?abstract final class {class_name} \{{.*?^\}}"
    
    # Use MULTILINE and DOTALL flags
    if re.search(pattern, dart_content, re.MULTILINE | re.DOTALL):
        # Replace existing class
        return re.sub(pattern, new_class_content, dart_content, flags=re.MULTILINE | re.DOTALL)
    else:
        print(f"   ⚠️  Class {class_name} not found in Dart file, skipping")
        return dart_content


def update_timestamp(dart_content: str) -> str:
    """Update the generation timestamp in the Dart file."""
    timestamp = datetime.now().isoformat()
    
    # Check if there's already a Generated: line
    if '// Generated:' in dart_content:
        return re.sub(r'// Generated: .+', f'// Generated: {timestamp}', dart_content)
    else:
        # Add after the WARNING line
        return dart_content.replace(
            '// WARNING: THIS FILE IS AUTO-GENERATED',
            f'// WARNING: THIS FILE IS AUTO-GENERATED\n//\n// Source: functions/schema_constants.py\n// Generated: {timestamp}'
        )


def get_current_dart_values(dart_content: str, class_name: str) -> dict[str, str]:
    """Extract current values from a Dart enum class."""
    pattern = rf"abstract final class {class_name} \{{(.*?)\n\}}"
    match = re.search(pattern, dart_content, re.DOTALL)
    
    if not match:
        return {}
    
    class_body = match.group(1)
    values = {}
    
    # Extract static const declarations
    for line in class_body.split('\n'):
        match = re.search(r"static const (\w+) = ['\"]([^'\"]+)['\"];", line)
        if match and match.group(1) != 'all':
            dart_name = match.group(1)
            value = match.group(2)
            values[dart_name] = value
    
    return values


def compare_values(python_values: dict[str, str], dart_values: dict[str, str]) -> bool:
    """Compare Python and Dart values (considering name conversion)."""
    # Convert Python names to Dart names for comparison
    python_as_dart = {to_dart_camel_case(k): v for k, v in python_values.items()}
    return python_as_dart == dart_values


def main():
    """Function main."""
    parser = argparse.ArgumentParser(description='Sync schema between Python and Dart')
    parser.add_argument('--check', action='store_true', 
                       help='Check if schemas match without writing')
    args = parser.parse_args()
    
    print("🔍 Schema Sync Tool")
    print("=" * 60)
    
    # Check files exist
    if not PYTHON_SCHEMA_SOURCE.exists():
        print(f"❌ Error: {PYTHON_SCHEMA_SOURCE} not found")
        sys.exit(1)
    
    if not DART_SCHEMA_FILE.exists():
        print(f"❌ Error: {DART_SCHEMA_FILE} not found")
        sys.exit(1)
    
    print(f"📁 Python source: {PYTHON_SCHEMA_SOURCE}")
    print(f"📁 Dart file: {DART_SCHEMA_FILE}")
    print()
    
    # Read current Dart content
    dart_content = DART_SCHEMA_FILE.read_text()
    
    # Extract Python constants for each mapped class
    print("🔄 Extracting Python constants...")
    python_data = {}
    
    for py_class, dart_class in CLASS_MAPPING.items():
        values = extract_python_class_constants(PYTHON_SCHEMA_SOURCE, py_class)
        if not values and py_class in PYTHON_CLASS_FALLBACKS:
            values = extract_python_class_constants(PYTHON_SCHEMA_SOURCE, PYTHON_CLASS_FALLBACKS[py_class])
        python_data[dart_class] = values
        print(f"   ✓ {py_class} → {dart_class}: {len(values)} values")
    
    # Extract business rules
    business_rules = extract_business_rules(PYTHON_SCHEMA_SOURCE)
    print(f"   ✓ BusinessRules: {len(business_rules)} values")
    print()
    
    # Check mode
    if args.check:
        print("🔍 Checking schema consistency...")
        
        mismatches = []
        
        for py_class, dart_class in CLASS_MAPPING.items():
            python_values = python_data[dart_class]
            dart_values = get_current_dart_values(dart_content, dart_class)
            
            if not compare_values(python_values, dart_values):
                mismatches.append(
                    f"{dart_class}: Python has {len(python_values)}, "
                    f"Dart has {len(dart_values)} values"
                )
        
        if mismatches:
            print("❌ Schema mismatches found:")
            for m in mismatches:
                print(f"   - {m}")
            print("\nRun `python scripts/sync_schema.py` to update.")
            sys.exit(1)
        else:
            print("✅ Schema is consistent!")
            sys.exit(0)
    
    # Update mode
    print("📝 Updating Dart file...")
    updated_content = dart_content
    changes = []
    
    # Update each class
    for py_class, dart_class in CLASS_MAPPING.items():
        python_values = python_data[dart_class]
        dart_values = get_current_dart_values(updated_content, dart_class)
        
        if not compare_values(python_values, dart_values):
            new_class = generate_enum_class(dart_class, python_values)
            updated_content = update_class_in_dart(updated_content, dart_class, new_class)
            changes.append(
                f"{dart_class}: {len(dart_values)} → {len(python_values)} values"
            )
        else:
            print(f"   ✓ {dart_class} already up-to-date")
    
    # Update BusinessRules
    # Note: BusinessRules is a special case - we just check if it exists
    # and update it if the values changed
    if 'abstract final class BusinessRules' in updated_content:
        # Extract current values for comparison (simplified)
        current_rules = {}
        for rule_name in ['platformFeePercent', 'autoConfirmDays', 'authorizationExpiryDays']:
            pattern = rf"static const {rule_name} = ([\d.]+);"
            match = re.search(pattern, updated_content)
            if match:
                current_rules[rule_name] = float(match.group(1))
        
        # Check if any values changed
        rules_changed = False
        for name, value in business_rules.items():
            if name not in current_rules or abs(current_rules[name] - value) > 0.001:
                rules_changed = True
                break
        
        if rules_changed:
            new_rules_class = generate_business_rules_class(business_rules)
            updated_content = update_class_in_dart(updated_content, 'BusinessRules', new_rules_class)
            changes.append("BusinessRules: values updated")
        else:
            print("   ✓ BusinessRules already up-to-date")
    else:
        print("   ⚠️  BusinessRules not found in Dart file, skipping")
    
    # Update timestamp
    updated_content = update_timestamp(updated_content)
    
    # Write if changed
    if changes:
        DART_SCHEMA_FILE.write_text(updated_content)
        print(f"\n✅ Updated {DART_SCHEMA_FILE}")
        print("\n📊 Changes made:")
        for change in changes:
            print(f"   - {change}")
    else:
        # Still update timestamp to show the file was checked
        DART_SCHEMA_FILE.write_text(updated_content)
        print("\n✅ No value changes needed (timestamp updated)")
    
    print("\n📋 Next steps:")
    print("   1. Run `flutter analyze` to verify")
    print("   2. Run tests to ensure nothing broke")
    print("   3. Commit changes with message: 'chore: sync schema constants'")


if __name__ == '__main__':
    main()
