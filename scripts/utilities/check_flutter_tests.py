"""Module check_flutter_tests.py."""
import os
import glob

# Find all viewmodels in lib
lib_dir = "origna_gta/lib"
test_dir = "origna_gta/test"

viewmodels = []
for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith("_viewmodel.dart") or "view_model" in f:
            viewmodels.append(os.path.relpath(os.path.join(root, f), lib_dir))

# Find all test files
test_files = []
for root, _, files in os.walk(test_dir):
    for f in files:
        if f.endswith("_test.dart"):
            test_files.append(f)

# See which viewmodels have a corresponding test file
tested_vms = []
untested_vms = []
for vm in viewmodels:
    # Expected test name: same name but ending with _test.dart
    base_name = os.path.basename(vm).replace(".dart", "")
    test_name = base_name + "_test.dart"
    
    # We also check if the base name is somewhere in the test files list
    if test_name in test_files or any(base_name in tf for tf in test_files):
        tested_vms.append(vm)
    else:
        untested_vms.append(vm)

print(f"Total ViewModels: {len(viewmodels)}")
print(f"Tested ViewModels: {len(tested_vms)}")
print(f"Untested ViewModels: {len(untested_vms)}")
print("\nUntested ViewModels List:")
for vm in sorted(untested_vms):
    print(f"- {vm}")
