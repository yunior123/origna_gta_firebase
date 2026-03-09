import json
import os
import re

def load_json(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def get_keys(data, parent_key=''):
    keys = set()
    if isinstance(data, dict):
        for k, v in data.items():
            current_key = f"{parent_key}.{k}" if parent_key else k
            if isinstance(v, dict):
                keys.update(get_keys(v, current_key))
            else:
                keys.add(current_key)
    return keys

def find_tr_keys(root_dir):
    # This regex looks for string literals followed by .tr(
    # It allows alphanumeric, dots, underscores, and hyphens in keys.
    tr_pattern = re.compile(r"(['\"])([a-zA-Z0-9._-]+)\1\.tr\(")
    used_keys = set()
    
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if not filename.endswith('.dart'):
                continue
            
            filepath = os.path.join(dirpath, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                matches = tr_pattern.findall(content)
                for m in matches:
                    used_keys.add(m[1])
    return used_keys

if __name__ == "__main__":
    en_path = "origna_gta/assets/translations/en.json"
    lib_path = "origna_gta/lib"
    
    en_data = load_json(en_path)
    en_keys = get_keys(en_data)
    
    used_keys = find_tr_keys(lib_path)
    
    missing_in_json = used_keys - en_keys
    unused_in_json = en_keys - used_keys
    
    print(f"Total keys in JSON: {len(en_keys)}")
    print(f"Total .tr() keys found in code: {len(used_keys)}")
    
    if missing_in_json:
        print(f"\n{len(missing_in_json)} KEYS USED IN CODE BUT MISSING IN JSON:")
        for k in sorted(missing_in_json):
            print(f"  - {k}")
    else:
        print("\nAll keys used in code are present in JSON.")
        
    if unused_in_json:
        print(f"\n{len(unused_in_json)} KEYS IN JSON BUT NOT FOUND IN CODE (POTENTIALLY UNUSED):")
        # Too many to print probably, just show count
        # for k in sorted(unused_in_json):
        #     print(f"  - {k}")
