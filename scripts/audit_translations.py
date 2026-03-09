"""Module audit_translations.py."""
import json
import os
import re

def load_json(path):
    """Function load_json."""
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def get_keys(data, parent_key=''):
    """Function get_keys."""
    keys = set()
    for k, v in data.items():
        current_key = f"{parent_key}.{k}" if parent_key else k
        if isinstance(v, dict):
            keys.update(get_keys(v, current_key))
        else:
            keys.add(current_key)
    return keys

def compare_translations(en_path, fr_path):
    """Function compare_translations."""
    print(f"Loading {en_path}...")
    en_data = load_json(en_path)
    print(f"Loading {fr_path}...")
    fr_data = load_json(fr_path)

    en_keys = get_keys(en_data)
    fr_keys = get_keys(fr_data)

    missing_in_fr = en_keys - fr_keys
    missing_in_en = fr_keys - en_keys

    print(f"\nTotal keys in EN: {len(en_keys)}")
    print(f"Total keys in FR: {len(fr_keys)}")

    if missing_in_fr:
        print("\nMISSING IN FR:")
        for k in sorted(missing_in_fr):
            print(f"  - {k}")
    
    if missing_in_en:
        print("\nMISSING IN EN:")
        for k in sorted(missing_in_en):
            print(f"  - {k}")

    if not missing_in_fr and not missing_in_en:
        print("\nKeys match perfectly.")

def find_hardcoded_strings(root_dir):
    """Function find_hardcoded_strings."""
    print(f"\nScanning {root_dir} for hardcoded strings...")
    # Regex to capture Text('...') or Text("...")
    # This is a simple heuristic.
    # We want to find cases where .tr() is NOT used.
    # Text('string') -> Hardcoded
    # Text('string'.tr()) -> Localized
    # Text(variable) -> Unknown/Ignored for now
    
    text_pattern = re.compile(r"Text\(\s*(['\"])(.*?)\1\s*(?!\.tr)")
    
    # Also look for things like hintText: '...', labelText: '...'
    # hintText: '...'
    property_string_pattern = re.compile(r"(hintText|labelText|title|message|description)\s*:\s*(['\"])(.*?)\2\s*(?!\.tr)")

    hardcoded_count = 0

    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if not filename.endswith('.dart'):
                continue
            
            filepath = os.path.join(dirpath, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            for i, line in enumerate(lines):
                # Skip comments
                if line.strip().startswith('//'):
                    continue

                # Check for Text('...') not followed by .tr
                # Naive check: if 'Text(' in line, check if '.tr' is in line
                # But better to use regex
                
                # We need to be careful. `Text('key'.tr())` matches `Text\(['"]`
                
                # Check for Text('...') matches
                # If we find a match, check if it's followed by .tr()
                
                matches = list(text_pattern.finditer(line))
                for m in matches:
                    content = m.group(2)
                    full_match = m.group(0)
                    # Heuristic: if content represents a key (no spaces, dots usually), might be a key missing .tr()
                    # But if it has spaces, it's definitely a hardcoded string.
                    
                    # Also, look ahead in the line for .tr
                    remaining_line = line[m.end():]
                    if remaining_line.strip().startswith(')'):
                         # likely Text('content'), so no .tr()
                         pass
                    elif '.tr' in remaining_line:
                        continue # assume it's localized
                        
                    # Filter out common false positives or technical strings if needed
                    if content.strip() == '': continue
                    if content == 'Error': continue # maybe hardcoded but generic
                    
                    print(f"{filename}:{i+1} -> Text('{content}')")
                    hardcoded_count += 1

                # Check for property strings
                prop_matches = list(property_string_pattern.finditer(line))
                for m in prop_matches:
                    prop = m.group(1)
                    content = m.group(3)
                    remaining_line = line[m.end():]
                    
                    if '.tr' in remaining_line:
                        continue
                    
                    # If content looks like a key (e.g. 'auth.login'), user might have forgotten .tr()
                    # If content has spaces, it's definitely text.
                    if ' ' in content or len(content) > 20: 
                        print(f"{filename}:{i+1} -> {prop}: '{content}'")
                        hardcoded_count += 1

    print(f"\nFound {hardcoded_count} potential hardcoded strings.")

if __name__ == "__main__":
    en_path = "origna_gta/assets/translations/en.json"
    fr_path = "origna_gta/assets/translations/fr.json"
    lib_path = "origna_gta/lib"
    
    compare_translations(en_path, fr_path)
    find_hardcoded_strings(lib_path)
