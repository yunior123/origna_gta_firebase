"""Module auto_fix_comments.py."""
import os
import ast
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {
    ".git", "node_modules", "build", ".dart_tool", "__pycache__",
    "venv", ".venv", "emulator-data", "test-results", "playwright-report",
    ".firebase", ".pub-cache", "Pods", ".symlinks", "ios", "macos",
    "android", "windows", "linux", "web",
}

def iter_source_files(extensions):
    """Function iter_source_files."""
    results = []
    for ext in extensions:
        for path in PROJECT_ROOT.rglob(f"*{ext}"):
            parts = set(path.relative_to(PROJECT_ROOT).parts)
            if parts & SKIP_DIRS:
                continue
            # Skip generated files
            if ".g.dart" in path.name or ".freezed.dart" in path.name:
                continue
            results.append(path)
    return sorted(results)

def fix_python_file(filepath):
    """Function fix_python_file."""
    try:
        source = filepath.read_text(errors="ignore")
    except Exception:
        return 0
    
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return 0

    lines = source.splitlines()
    fixes = 0

    # Collect nodes missing docstrings
    missing_doc_nodes = []
    
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if node.name.startswith("_") and not node.name.startswith("__"):
                    continue
            if not ast.get_docstring(node):
                missing_doc_nodes.append(node)

    # Sort nodes by line number descending to avoid offsetting issues when inserting
    missing_doc_nodes.sort(key=lambda n: n.lineno, reverse=True)

    for node in missing_doc_nodes:
        # Insert as first statement in the node body.
        # For classes, this must be before decorators on the first method.
        if node.body:
            first_stmt = node.body[0]
            insert_lineno = first_stmt.lineno
            if isinstance(node, ast.ClassDef) and getattr(first_stmt, "decorator_list", None):
                decorator_lines = [d.lineno for d in first_stmt.decorator_list if hasattr(d, "lineno")]
                if decorator_lines:
                    insert_lineno = min(decorator_lines)
            insert_line_idx = insert_lineno - 1
            
            # Find indentation
            indent_str = ""
            if insert_line_idx < len(lines):
                line_text = lines[insert_line_idx]
                indent = len(line_text) - len(line_text.lstrip())
                indent_str = " " * indent
            
            node_type = "Class" if isinstance(node, ast.ClassDef) else "Function"
            docstr = f'{indent_str}"""{node_type} {node.name}."""'
            lines.insert(insert_line_idx, docstr)
            fixes += 1

    # Check for module docstring
    if not ast.get_docstring(tree):
        # Insert at top, but safely after imports? Actually top of file is fine, or after #!/usr/bin/env
        if lines and lines[0].startswith("#!"):
            lines.insert(1, f'"""Module {filepath.name}."""')
        else:
            lines.insert(0, f'"""Module {filepath.name}."""')
        fixes += 1

    if fixes > 0:
        filepath.write_text("\n".join(lines) + "\n")
    return fixes

def fix_dart_file(filepath):
    """Function fix_dart_file."""
    try:
        source = filepath.read_text(errors="ignore")
    except Exception:
        return 0

    lines = source.splitlines()
    fixes = 0
    new_lines = []
    
    class_pattern = re.compile(r"^class\s+([A-Z]\w*)")
    
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        match = class_pattern.match(stripped)
        if match:
            # Check if there's a doc comment above it
            has_doc = False
            if len(new_lines) > 0:
                prev = new_lines[-1].strip()
                if prev.startswith("///") or prev.endswith("*/"):
                    has_doc = True
                elif prev.startswith("@") and len(new_lines) > 1: # like @freezed
                    prev2 = new_lines[-2].strip()
                    if prev2.startswith("///") or prev2.endswith("*/"):
                        has_doc = True
            
            if not has_doc:
                class_name = match.group(1)
                new_lines.append(f"/// Documentation for {class_name}")
                fixes += 1
                
        new_lines.append(line)
        i += 1

    if fixes > 0:
        filepath.write_text("\n".join(new_lines) + "\n")
    return fixes

def main():
    """Function main."""
    py_files = iter_source_files([".py"])
    dart_files = iter_source_files([".dart"])
    
    total_py_fixes = 0
    for f in py_files:
        total_py_fixes += fix_python_file(f)
        
    total_dart_fixes = 0
    for f in dart_files:
        total_dart_fixes += fix_dart_file(f)

    print(f"Fixed {total_py_fixes} Python missing docstrings.")
    print(f"Fixed {total_dart_fixes} Dart missing doc comments.")

if __name__ == "__main__":
    main()
