#!/usr/bin/env python3
"""
Script to update all @https_fn decorators to use global options
This ensures all Cloud Functions have proper timeout and memory settings
"""

import re
from pathlib import Path

# Define the replacements
REPLACEMENTS = [
    # on_call without parameters -> use DEFAULT_OPTIONS
    (r"@https_fn\.on_call\(\)", "@https_fn.on_call(**DEFAULT_OPTIONS._asdict())"),
    # on_call with only cors -> use DEFAULT_OPTIONS + cors
    (r"@https_fn\.on_call\(cors=cors_config\)", "@https_fn.on_call(**DEFAULT_OPTIONS._asdict(), cors=CORS_CONFIG)"),
    # on_request without parameters -> use DEFAULT_OPTIONS
    (r"@https_fn\.on_request\(\)", "@https_fn.on_request(**DEFAULT_OPTIONS._asdict())"),
]

# Import statement to add
IMPORT_LINE = "from utils.function_options import DEFAULT_OPTIONS, WEBHOOK_OPTIONS, CORS_CONFIG, CRON_OPTIONS\n"


def update_file(filepath: Path):
    """Update a single Python file with new decorator patterns"""
    with open(filepath, encoding="utf-8") as f:
        content = f.read()

    original_content = content

    # Add import if not present and file has https_fn decorators
    if "@https_fn." in content and "from utils.function_options import" not in content:
        # Find where to insert (after other imports)
        if "from firebase_functions import" in content:
            content = content.replace(
                "from firebase_functions import", IMPORT_LINE + "from firebase_functions import", 1
            )
        elif "import firebase_functions" in content:
            content = content.replace("import firebase_functions", "import firebase_functions\n" + IMPORT_LINE, 1)

    # Apply replacements
    for pattern, replacement in REPLACEMENTS:
        content = re.sub(pattern, replacement, content)

    # Write back if changed
    if content != original_content:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"✓ Updated: {filepath}")
        return True
    return False


def main():
    """Update all handler files"""
    handlers_dir = Path(__file__).parent / "handlers"

    updated_count = 0
    for py_file in handlers_dir.glob("*.py"):
        if py_file.name == "__init__.py":
            continue
        if update_file(py_file):
            updated_count += 1

    print(f"\n✓ Updated {updated_count} files")


if __name__ == "__main__":
    main()
