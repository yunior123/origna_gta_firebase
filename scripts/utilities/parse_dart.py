"""Module parse_dart.py."""
import re

with open('origna_gta/lib/core/schema/schema_constants.dart', 'r') as f:
    content = f.read()

# Match abstract class X { ... }
classes = re.findall(r'abstract (?:final )?class ([A-Za-z0-9_]+) \{(.*?)\}', content, re.DOTALL)
dart_data = {}

for class_name, class_body in classes:
    variables = {}
    for line in class_body.split('\n'):
        # Match static const
        m = re.search(r'static\s+const\s+(?:[a-zA-Z0-9_<>,\s]+\s+)?([a-zA-Z0-9_]+)\s*=\s*(.*?);', line)
        if m:
            var_name = m.group(1)
            var_val = m.group(2).strip(' "\'')
            variables[var_name] = var_val
    dart_data[class_name] = variables

# Same for python
with open('functions/schema_constants.py', 'r') as f:
    py_content = f.read()

py_classes = re.findall(r'class ([A-Za-z0-9_]+)(?:\(str, Enum\))?:(.*?)(?=class |\Z)', py_content, re.DOTALL)
py_data = {}

for class_name, class_body in py_classes:
    variables = {}
    for line in class_body.split('\n'):
        m = re.match(r'^\s+([A-Z0-9_]+)\s*=\s*(.*?)(?:\s+#.*)?$', line)
        if m:
            var_name = m.group(1)
            var_val = m.group(2).strip(' "\'')
            variables[var_name] = var_val
    py_data[class_name] = variables

print("DART CLASSES FOUND:", list(dart_data.keys()))
print("PY CLASSES FOUND:", list(py_data.keys()))

with open('dart_fields.txt', 'w') as f:
    for k, v in dart_data.get('Fields', {}).items():
        f.write(f"{k} = {v}\n")
with open('py_fields.txt', 'w') as f:
    for k, v in py_data.get('Fields', {}).items():
        f.write(f"{k} = {v}\n")

with open('dart_values.txt', 'w') as f:
    for k, v in dart_data.items():
        if k not in ['Fields', 'Collections', 'BusinessRules']:
            for name, val in v.items():
                f.write(f"{k}.{name} = {val}\n")
with open('py_values.txt', 'w') as f:
    for k, v in py_data.items():
        if k not in ['Fields', 'Collections', 'BusinessRules']:
            for name, val in v.items():
                f.write(f"{k}.{name} = {val}\n")
