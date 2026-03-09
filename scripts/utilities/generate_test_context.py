"""Module generate_test_context.py."""
import os
import glob
import re
from collections import Counter

WORKSPACE = "/Users/yuniorrodriguezosorio/Documents/GitHub/origna_gta"
E2E_DIR = os.path.join(WORKSPACE, "e2e/playwright_ui")
TEST_FILES = [
    "digital-product-e2e.spec.ts",
    "stock-notif.spec.ts",
    "multi-seller-orders.spec.ts",
    "new-coverage-e2e.spec.ts",
    "order-lifecycle.spec.ts",
    "order-notifications.spec.ts",
    "premium-subscription.spec.ts",
    "stripe-payment.spec.ts",
    "order-cancellation-refund.spec.ts",
    "add-product-e2e.spec.ts",
    "digital-products-e2e.spec.ts",
    "new-notification-features.spec.ts",
    "notifications.spec.ts",
    "admin-panel.spec.ts",
    "shipping-approval.spec.ts",
    "shipping-calculation.spec.ts",
    "payment-edge-cases.spec.ts",
    "rate-limiting.spec.ts",
    "return-request.spec.ts",
    "trending-products.spec.ts"
]

STATIC_FILES = [
    "CLAUDE.md",
    "firestore.rules",
    "firestore.indexes.json",
    "functions/schema_constants.py",
    "origna_gta/lib/core/constants/schema_constants.dart",
]

def get_words(text):
    # Extract identifiers (camelCase, snake_case, ClassNames)
    """Function get_words."""
    return set(re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*', text))

def score_file(test_words, filepath):
    """Function score_file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception:
        return 0, ""
    
    file_words = get_words(content)
    # Ignore common short words to improve relevance
    common = {"const", "import", "export", "class", "function", "return", "this", "await", "async", "true", "false", "null", "final", "void", "String", "bool", "int", "def", "self", "None"}
    intersection = (test_words & file_words) - common
    # Score based on number of unique shared identifiers > 4 chars
    score = sum(1 for w in intersection if len(w) > 4)
    return score, content

def generate_contexts():
    """Function generate_contexts."""
    out_dir = os.path.join(os.path.expanduser("~"), "Desktop", "test_contexts")
    os.makedirs(out_dir, exist_ok=True)
    
    # Collect all dart and python files
    dart_files = glob.glob(os.path.join(WORKSPACE, "origna_gta/lib/**/*.dart"), recursive=True)
    py_files = glob.glob(os.path.join(WORKSPACE, "functions/**/*.py"), recursive=True)

    # Exclude schema_constants since we already include them
    dart_files = [f for f in dart_files if "schema_constants.dart" not in f and not f.endswith(".g.dart") and not f.endswith(".freezed.dart")]
    py_files = [f for f in py_files if "schema_constants.py" not in f and "venv" not in f and ".mypy_cache" not in f and "tests" not in f]

    static_content = ""
    for sf in STATIC_FILES:
        sf_path = os.path.join(WORKSPACE, sf)
        if os.path.exists(sf_path):
            with open(sf_path, 'r', encoding='utf-8') as f:
                static_content += f"\n\n--- FILE: {sf} ---\n\n{f.read()}"

    for test_file in set(TEST_FILES):
        test_path = os.path.join(E2E_DIR, test_file)
        if not os.path.exists(test_path):
            print(f"File not found: {test_path}")
            continue
        
        with open(test_path, 'r', encoding='utf-8') as f:
            test_content = f.read()
        
        test_words = get_words(test_content)
        
        # Rank dart files
        dart_scores = []
        for df in dart_files:
            score, content = score_file(test_words, df)
            if score > 0:
                dart_scores.append((score, df, content))
        dart_scores.sort(key=lambda x: x[0], reverse=True)
        top_dart = dart_scores[:4]
        
        # Rank python files
        py_scores = []
        for pf in py_files:
            score, content = score_file(test_words, pf)
            if score > 0:
                py_scores.append((score, pf, content))
        py_scores.sort(key=lambda x: x[0], reverse=True)
        top_py = py_scores[:4]
        
        # Build output
        out_path = os.path.join(out_dir, f"{test_file.replace('.ts', '.txt')}")
        with open(out_path, 'w', encoding='utf-8') as out:
            out.write("====== E2E TEST CONTEXT BUNDLE ======\n")
            out.write(f"TEST FILE: {test_file}\n\n")
            out.write(f"\n\n--- FILE: e2e/playwright_ui/{test_file} ---\n\n{test_content}")
            
            out.write("\n\n====== RELEVANT DART FILES ======\n")
            for score, df, content in top_dart:
                rel_path = os.path.relpath(df, WORKSPACE)
                out.write(f"\n\n--- FILE: {rel_path} (Relevance Score: {score}) ---\n\n{content}")
                
            out.write("\n\n====== RELEVANT PYTHON FILES ======\n")
            for score, pf, content in top_py:
                rel_path = os.path.relpath(pf, WORKSPACE)
                out.write(f"\n\n--- FILE: {rel_path} (Relevance Score: {score}) ---\n\n{content}")
                
            out.write("\n\n====== STATIC CONTEXT (RULES, CONSTANTS, CLAUDE.md) ======\n")
            out.write(static_content)
            
        print(f"Generated context for {test_file} -> {out_path} (Included {len(top_dart)} Dart, {len(top_py)} Py)")

if __name__ == "__main__":
    generate_contexts()
