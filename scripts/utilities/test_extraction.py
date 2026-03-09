"""Module test_extraction.py."""
import re

with open('origna_gta/lib/core/schema/schema_constants.dart', 'r') as f:
    dart_content = f.read()

# find all static const ... = '...';
matches = re.findall(r"static\s+const\s+(?:String\s+)?([a-zA-Z0-9_]+)\s*=\s*['\"](.*?)['\"];", dart_content)
dart_fields = {m[0]: m[1] for m in matches}
print(f"Dart total constants extracted: {len(dart_fields)}")

with open('functions/schema_constants.py', 'r') as f:
    py_content = f.read()

# match X_Y = "..."
py_matches = re.findall(r"^    ([A-Z0-9_]+)\s*=\s*['\"](.*?)['\"]", py_content, re.MULTILINE)
py_fields = {m[0]: m[1] for m in py_matches}
print(f"Python total constants extracted: {len(py_fields)}")

# Now find fields actually missing
missing_in_dart = []
missing_in_py = []

dart_values_set = set(dart_fields.values())
py_values_set = set(py_fields.values())

for py_val in py_values_set:
    if py_val not in dart_values_set:
        missing_in_dart.append(py_val)

for dart_val in dart_values_set:
    if dart_val not in py_values_set:
        missing_in_py.append(dart_val)

print("Values in Py but not in Dart:", missing_in_dart)
print("Values in Dart but not in Py:", missing_in_py)

