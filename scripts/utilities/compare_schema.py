"""Module compare_schema.py."""
import re
import sys

def parse_py_class(filepath, class_name):
    """Function parse_py_class."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    match = re.search(r'class ' + class_name + r'.*?:(.*?)(?=class \w|\Z)', content, re.DOTALL)
    if not match:
        return {}
    
    class_body = match.group(1)
    # Match UPPER_CASE = "value" or UPPER_CASE = number
    variables = {}
    for line in class_body.split('\n'):
        m = re.match(r'^\s+([A-Z0-9_]+)\s*=\s*(.*?)(?:\s+#.*)?$', line)
        if m:
            key = m.group(1)
            val = m.group(2).strip(' "\'')
            variables[key] = val
    return variables

def parse_dart_class(filepath, class_name):
    """Function parse_dart_class."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    match = re.search(r'abstract (?:final )?class ' + class_name + r'.*?{(.*?)}', content, re.DOTALL)
    if not match:
        return {}
    
    class_body = match.group(1)
    variables = {}
    for line in class_body.split('\n'):
        # match static const varName = "value"; or static const varName = number;
        m = re.match(r'^\s*static\s+const\s+(?:[A-Za-z0-9_<>,\s]*?\s+)?([a-zA-Z0-9_]+)\s*=\s*(.*?);', line)
        if m:
            key = m.group(1)
            val = m.group(2).strip(' "\'')
            variables[key] = val
    return variables

py_file = 'functions/schema_constants.py'
dart_file = 'origna_gta/lib/core/schema/schema_constants.dart'

def to_camel_case(snake_str):
    """Function to_camel_case."""
    components = snake_str.lower().split('_')
    return components[0] + ''.join(x.title() for x in components[1:])

py_collections = parse_py_class(py_file, 'Collections')
dart_collections = parse_dart_class(dart_file, 'Collections')

py_fields = parse_py_class(py_file, 'Fields')
dart_fields = parse_dart_class(dart_file, 'Fields')

py_business = parse_py_class(py_file, 'BusinessRules')
dart_business = parse_dart_class(dart_file, 'BusinessRules')

print("--- COLLECTIONS ---")
for k, v in py_collections.items():
    dart_key = to_camel_case(k)
    if dart_key not in dart_collections:
        print(f"Missing in Dart: {dart_key} (Python: {k} = {v})")
    elif dart_collections[dart_key] != v:
        print(f"Mismatch: {dart_key} -> Py: {v}, Dart: {dart_collections[dart_key]}")

for k, v in dart_collections.items():
    # rudimentary back check
    pass

print("\n--- FIELDS ---")
for k, v in py_fields.items():
    dart_key = to_camel_case(k)
    if k == 'GST_LOWER': dart_key = 'gst'
    if k == 'PST_LOWER': dart_key = 'pst'
    if k == 'HST_LOWER': dart_key = 'hst'
    if k == 'QST_LOWER': dart_key = 'qst'
    if k == 'GST': dart_key = 'GST'
    if k == 'PST': dart_key = 'PST'
    if k == 'HST': dart_key = 'HST'
    if k == 'QST': dart_key = 'QST'

    if dart_key not in dart_fields:
        print(f"Missing in Dart: {dart_key} (Python: {k} = {v})")
    elif dart_fields[dart_key] != v:
        print(f"Mismatch: {dart_key} -> Py: {v}, Dart: {dart_fields[dart_key]}")

print("\n--- BUSINESS RULES ---")
for k, v in py_business.items():
    dart_key = to_camel_case(k)
    if dart_key not in dart_business:
        print(f"Missing in Dart: {dart_key} (Python: {k} = {v})")
    elif str(dart_business[dart_key]) != str(v):
        print(f"Mismatch: {dart_key} -> Py: {v}, Dart: {dart_business[dart_key]}")

