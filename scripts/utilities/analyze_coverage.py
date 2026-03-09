"""Module analyze_coverage.py."""
import ast
import glob
import re
import os

# Parse __all__ from main.py
with open('functions/main.py', 'r') as f:
    source = f.read()

tree = ast.parse(source)
all_functions = []
for node in ast.walk(tree):
    if isinstance(node, ast.Assign):
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id == '__all__':
                if isinstance(node.value, ast.List):
                    for elt in node.value.elts:
                        if isinstance(elt, ast.Constant):
                            all_functions.append(elt.value)

# Read all test files
test_files = glob.glob('functions/tests/**/*.py', recursive=True)
test_content = ""
for tf in test_files:
    with open(tf, 'r') as f:
        test_content += f.read() + "\n"

# Check which functions are tested
tested = []
untested = []
for func in all_functions:
    # A function is considered tested if there's a test containing its name
    # e.g., test_create_checkout_session or patch('...create_checkout_session')
    # or just the function name being called.
    if func in test_content:
        tested.append(func)
    else:
        untested.append(func)

print(f"Total: {len(all_functions)}")
print(f"Tested: {len(tested)}")
print(f"Untested: {len(untested)}")
print("Untested Functions:")
for f in sorted(untested):
    print(f" - {f}")
