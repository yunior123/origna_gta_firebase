"""Module compare_rules.py."""
import re

def parse_py_class(filepath, class_name):
    """Function parse_py_class."""
    with open(filepath, 'r') as f:
        content = f.read()
    match = re.search(r'class ' + class_name + r'.*?:(.*?)(?=class \w|\Z)', content, re.DOTALL)
    if not match: return {}
    class_body = match.group(1)
    variables = {}
    for line in class_body.split('\n'):
        m = re.match(r'^\s+([A-Z0-9_]+)\s*=\s*(.*?)(?:\s+#.*)?$', line)
        if m:
            variables[m.group(1)] = m.group(2).strip(' "\'')
    return variables

py_collections = parse_py_class('functions/schema_constants.py', 'Collections')

with open('firestore.rules', 'r') as f:
    rules = f.read()

rule_matches = re.findall(r'match /([a-zA-Z0-9_]+)/', rules)

print("--- RULES COVERAGE ---")
covered = set(rule_matches)
for k, v in py_collections.items():
    if v not in covered:
        print(f"Missing in firestore.rules: {v}")

