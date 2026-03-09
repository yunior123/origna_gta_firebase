"""Module fix_parse.py."""
import re

with open('origna_gta/lib/core/schema/schema_constants.dart', 'r') as f:
    content = f.read()

classes = re.findall(r'abstract (?:final )?class ([A-Za-z0-9_]+) \{(.*?)\}', content, re.DOTALL)
dart_fields = {}
dart_enum = {}

for class_name, class_body in classes:
    for line in class_body.split('\n'):
        line = line.strip()
        if not line.startswith('static const'): continue
        
        # remove 'static const '
        line = line[len('static const '):]
        # split by '='
        if '=' not in line: continue
        parts = line.split('=', 1)
        left = parts[0].strip()
        right = parts[1].strip().strip(';').strip(' "\'')
        
        # get var name
        var_name = left.split(' ')[-1]
        
        if class_name == 'Fields':
            dart_fields[var_name] = right
        elif class_name not in ['Collections', 'BusinessRules']:
            dart_enum[f"{class_name}.{var_name}"] = right

with open('functions/schema_constants.py', 'r') as f:
    py_content = f.read()

py_classes = re.findall(r'class ([A-Za-z0-9_]+)(?:\(str, Enum\))?:(.*?)(?=class |\Z)', py_content, re.DOTALL)
py_fields = {}
py_enum = {}

for class_name, class_body in py_classes:
    for line in class_body.split('\n'):
        line = line.strip()
        m = re.match(r'^([A-Z0-9_]+)\s*=\s*(.*?)(?:\s+#.*)?$', line)
        if m:
            var_name = m.group(1)
            var_val = m.group(2).strip(' "\'')
            if class_name == 'Fields':
                py_fields[var_name] = var_val
            elif class_name not in ['Collections', 'BusinessRules']:
                py_enum[f"{class_name}.{var_name}"] = var_val

def to_camel_case(snake_str):
    """Function to_camel_case."""
    components = snake_str.lower().split('_')
    return components[0] + ''.join(x.title() for x in components[1:])

print("=== FIELDS ===")
for k, v in py_fields.items():
    dart_key = to_camel_case(k)
    if k in ['GST_LOWER', 'PST_LOWER', 'HST_LOWER', 'QST_LOWER']: dart_key = k.split('_')[0].lower()
    elif k in ['GST', 'PST', 'HST', 'QST']: dart_key = k

    if dart_key not in dart_fields:
        print(f"Missing in Dart: {k} -> {v}")
    elif dart_fields[dart_key] != v:
        print(f"Mismatch: {k}='{v}' vs Dart.{dart_key}='{dart_fields[dart_key]}'")

print("\n=== ENUMS ===")
for k, v in py_enum.items():
    if "OrderStatusValues" in k or "ProductLifecycleStatusValues" in k:
        # Check if python value is in dart
        # Since dart enums keys might differ, let's just check if the VALUE exists in dart enum
        dart_vals = [val for key, val in dart_enum.items() if key.startswith(k.split('.')[0])]
        if v not in dart_vals:
            print(f"Missing in Dart ENUM {k.split('.')[0]}: {v}")

