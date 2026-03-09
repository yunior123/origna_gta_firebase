"""Module smart_audit.py."""

import json
import os
import re
import difflib

def load_json(path):
    """Function load_json."""
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def flatten_json(data, parent_key=''):
    """Function flatten_json."""
    items = {}
    for k, v in data.items():
        current_key = f"{parent_key}.{k}" if parent_key else k
        if isinstance(v, dict):
            items.update(flatten_json(v, current_key))
        else:
            items[current_key] = v
    return items

def find_best_match(text, translation_map):
    """Function find_best_match."""
    text_lower = text.lower().strip().rstrip(':')
    
    # Exact match
    for key, val in translation_map.items():
        if val.lower() == text_lower:
            return key, 1.0
            
    # Substring match (e.g. "Add to Cart" vs "add_to_cart")
    # Fuzzy match
    matches = difflib.get_close_matches(text_lower, [v.lower() for v in translation_map.values()], n=1, cutoff=0.8)
    if matches:
        # Find key for this value
        for key, val in translation_map.items():
            if val.lower() == matches[0]:
                return key, 0.8
                
    return None, 0.0

def scan_file(filepath, translation_map):
    """Function scan_file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # improved patterns for multi-line
    # Text('string') or Text("string")
    # We want to match `Text(\s*['"]content['"]`
    # and also named args like `label: 'content'`
    
    patterns = [
        # Match Text('...') or Text("...")
        (r"Text\s*\(\s*(['\"])(.*?)\1", 2),
        # Match label: '...'
        (r"label\s*:\s*(['\"])(.*?)\1", 2),
        # Match tooltip: '...'
        (r"tooltip\s*:\s*(['\"])(.*?)\1", 2),
        # Match description: '...'
        (r"description\s*:\s*(['\"])(.*?)\1", 2),
         # Match title: '...'
        (r"title\s*:\s*(['\"])(.*?)\1", 2),
    ]
    
    findings = []
    
    # Remove comments to avoid false positives? 
    # Comments are hard to remove reliably with regex, but let's try a simple block removal
    # remove // comments
    content_no_comments = re.sub(r'//.*', '', content)
    # remove /* */ comments
    content_no_comments = re.sub(r'/\*.*?\*/', '', content_no_comments, flags=re.DOTALL)

    for pat, group_idx in patterns:
        for m in re.finditer(pat, content_no_comments, flags=re.DOTALL):
            text = m.group(group_idx)
            start = m.start()
            
            # check if .tr() follows
            # look ahead a bit
            post_match = content_no_comments[m.end():m.end()+100]
            if re.match(r"\s*\.tr", post_match):
                continue
                
            if len(text) < 2: continue
            if '$' in text and '{' in text: continue # heavy interpolation ignore for now unless simple
            
             # Ignore keys (e.g. 'product.title') - heuristic: no spaces, contains dot
            if ' ' not in text and '.' in text and not text.endswith('.'):
                continue
            
            best_key, score = find_best_match(text, translation_map)
            
            # Get line number
            line_num = content.count('\n', 0, start) + 1
            
            findings.append({
                'line': line_num,
                'content': text.replace('\n', '\\n'),
                'match_key': best_key,
                'score': score
            })

    # Deduplicate by line+content
    unique_findings = {}
    for f in findings:
        k = f"{f['line']}:{f['content']}"
        if k not in unique_findings:
            unique_findings[k] = f
            
    return sorted(unique_findings.values(), key=lambda x: x['line'])

def main():
    """Function main."""
    en_path = 'origna_gta/assets/translations/en.json'
    lib_dir = 'origna_gta/lib'
    
    print(f"Loading translations from {en_path}...")
    translations = flatten_json(load_json(en_path))
    
    print(f"Scanning {lib_dir}...")
    
    all_findings = []
    
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                findings = scan_file(filepath, translations)
                if findings:
                    all_findings.extend([{**f, 'file': filepath} for f in findings])

    print(f"\nFound {len(all_findings)} potential hardcoded strings across {len(set(f['file'] for f in all_findings))} files.\n")
    
    # Group by file
    findings_by_file = {}
    for f in all_findings:
        if f['file'] not in findings_by_file:
            findings_by_file[f['file']] = []
        findings_by_file[f['file']].append(f)
        
    for filepath, findings in sorted(findings_by_file.items()):
        print(f"\nExample File: {filepath} ({len(findings)} strings)")
        # Show top 5 examples per file to keep output manageable
        for r in findings[:5]:
             match_info = ""
             if r['match_key']:
                 match_info = f" [Reuse: {r['match_key']}]"
             print(f"  L{r['line']}: \"{r['content'][:50]}...\"{match_info}")
        if len(findings) > 5:
            print(f"  ... and {len(findings)-5} more")

if __name__ == "__main__":
    main()
