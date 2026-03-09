"""Module get_collections.py."""
import re

# Dart
with open('origna_gta/lib/core/schema/schema_constants.dart', 'r') as f:
    dart_content = f.read()
dart_collections = re.search(r'abstract final class Collections \{(.*?)\}', dart_content, re.DOTALL).group(1)
dart_colls = re.findall(r"static const [a-zA-Z0-9_]+\s*=\s*'([^']+)';", dart_collections)

# Python
with open('functions/schema_constants.py', 'r') as f:
    py_content = f.read()
py_collections = re.search(r'class Collections:(.*?)(?=class \w|\Z)', py_content, re.DOTALL).group(1)
py_colls = re.findall(r'^[ \t]+[A-Z0-9_]+\s*=\s*"([^"]+)"', py_collections, re.MULTILINE)

dart_set = set(dart_colls)
py_set = set(py_colls)

print("In Python but not Dart:")
for c in py_set - dart_set:
    print(c)

print("In Dart but not Python:")
for c in dart_set - py_set:
    print(c)
