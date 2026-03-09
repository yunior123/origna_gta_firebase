"""Module compare_fields.py."""
import json

def to_camel_case(snake_str):
    """Function to_camel_case."""
    components = snake_str.lower().split('_')
    return components[0] + ''.join(x.title() for x in components[1:])

with open('dart_fields.txt', 'r') as f:
    dart_lines = f.readlines()
with open('py_fields.txt', 'r') as f:
    py_lines = f.readlines()

dart_fields = {}
for line in dart_lines:
    if '=' in line:
        k, v = line.strip().split(' = ', 1)
        dart_fields[k] = v

py_fields = {}
for line in py_lines:
    if '=' in line:
        k, v = line.strip().split(' = ', 1)
        py_fields[k] = v

print("=== FIELD NAME DRIFT ===")
for k, v in py_fields.items():
    dart_key = to_camel_case(k)
    # Exceptions
    if k == 'GST_LOWER': dart_key = 'gst'
    if k == 'PST_LOWER': dart_key = 'pst'
    if k == 'HST_LOWER': dart_key = 'hst'
    if k == 'QST_LOWER': dart_key = 'qst'
    if k == 'GST': dart_key = 'GST'
    if k == 'PST': dart_key = 'PST'
    if k == 'HST': dart_key = 'HST'
    if k == 'QST': dart_key = 'QST'
    
    if dart_key not in dart_fields:
        print(f"Missing in Dart: Python.{k} -> {v}")
    elif dart_fields[dart_key] != v:
        print(f"Value mismatch: Python.{k}='{v}' vs Dart.{dart_key}='{dart_fields[dart_key]}'")

for k, v in dart_fields.items():
    # rudimentary reverse check
    found = False
    for pk in py_fields:
        dk = to_camel_case(pk)
        if pk in ['GST_LOWER', 'PST_LOWER', 'HST_LOWER', 'QST_LOWER']:
            dk = pk.split('_')[0].lower()
        if pk in ['GST', 'PST', 'HST', 'QST']:
            dk = pk
        if dk == k:
            found = True
            break
    if not found:
        print(f"Missing in Python: Dart.{k} -> {v}")

with open('dart_values.txt', 'r') as f:
    dart_vals = f.readlines()
with open('py_values.txt', 'r') as f:
    py_vals = f.readlines()

dart_enum = {}
for line in dart_vals:
    if '=' in line:
        k, v = line.strip().split(' = ', 1)
        dart_enum[k] = v

py_enum = {}
for line in py_vals:
    if '=' in line:
        k, v = line.strip().split(' = ', 1)
        py_enum[k] = v

print("\n=== ENUM VALUE DRIFT ===")
# Check OrderStatusValues
for k, v in py_enum.items():
    if k.startswith("OrderStatusValues."):
        dart_key = k
        if dart_key not in dart_enum:
            print(f"Missing in Dart: {k} -> {v}")
        elif dart_enum[dart_key] != v:
            print(f"Mismatch in {k}: Py='{v}', Dart='{dart_enum[dart_key]}'")

for k, v in py_enum.items():
    if k.startswith("ProductLifecycleStatusValues."):
        dart_key = k
        if dart_key not in dart_enum:
            print(f"Missing in Dart: {k} -> {v}")
        elif dart_enum[dart_key] != v:
            print(f"Mismatch in {k}: Py='{v}', Dart='{dart_enum[dart_key]}'")
