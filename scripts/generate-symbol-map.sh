#!/bin/bash
# generate-symbol-map.sh — Extract class/function signatures using ctags + tree-sitter
# Produces docs/SYMBOL_MAP.md structured by domain
# Usage: ./scripts/generate-symbol-map.sh
# Prerequisites: brew install universal-ctags, npm install -g tree-sitter-cli

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_LIB="$PROJECT_DIR/origna_gta/lib"
FUNCTIONS_DIR="$PROJECT_DIR/functions"
OUTPUT_FILE="$PROJECT_DIR/docs/SYMBOL_MAP.md"
TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" EXIT

# ─── Check for ctags ───
if ! command -v ctags &>/dev/null; then
  echo "❌ universal-ctags not found. Install: brew install universal-ctags"
  exit 1
fi

echo "🔍 Generating symbol map..."

# ═══════════════════════════════════════════════════════════
# Phase 1: Extract Dart symbols with grep (ctags lacks Dart support)
# ═══════════════════════════════════════════════════════════
echo "  📱 Scanning Flutter/Dart symbols..."

# Extract classes, abstract classes, mixins, enums, extensions
grep -rn "^\(abstract \)\?class \|^mixin \|^enum \|^extension " "$FLUTTER_LIB" \
  --include="*.dart" \
  --exclude-dir=".dart_tool" \
  2>/dev/null | \
  grep -v ".freezed.dart" | grep -v ".g.dart" | \
  while IFS=: read -r filepath linenum content; do
    # Determine kind
    kind="class"
    if echo "$content" | grep -q "^abstract class"; then kind="abstract_class"; fi
    if echo "$content" | grep -q "^mixin "; then kind="mixin"; fi
    if echo "$content" | grep -q "^enum "; then kind="enum"; fi
    if echo "$content" | grep -q "^extension "; then kind="extension"; fi
    # Extract symbol name (first word after keyword)
    name=$(echo "$content" | sed -E 's/^(abstract )?class |^mixin |^enum |^extension //' | sed -E 's/[ <{(].*//' | tr -d ' ')
    printf "%s\t%s\t%s\t%s\n" "$name" "$kind" "$filepath" "$linenum"
  done > "$TEMP_DIR/dart_symbols.tsv" || true

# Also extract top-level functions from ViewModels and Repositories
grep -rn "  Future<\|  Stream<\|  void \|  static " "$FLUTTER_LIB/features" "$FLUTTER_LIB/core/repositories" \
  --include="*.dart" 2>/dev/null | \
  grep -v ".freezed.dart" | grep -v ".g.dart" | grep -v "\/\/" | grep -v "@" | \
  while IFS=: read -r filepath linenum content; do
    # Extract method name: match word followed by ( 
    name=$(echo "$content" | grep -oE '[a-zA-Z_][a-zA-Z0-9_]*\(' | head -1 | sed 's/($//' || true)
    if [ -n "${name:-}" ] && [ ${#name} -gt 1 ] && [ ${#name} -lt 60 ]; then
      printf "%s\tmethod\t%s\t%s\n" "$name" "$filepath" "$linenum"
    fi
  done >> "$TEMP_DIR/dart_symbols.tsv" || true

# ═══════════════════════════════════════════════════════════
# Phase 2: Extract Python symbols with ctags
# ═══════════════════════════════════════════════════════════
echo "  🐍 Scanning Python backend symbols..."

ctags -R --output-format=json \
  --languages=Python \
  --kinds-Python=cfmCMF \
  --fields=+nKS \
  --extras=-{anonymous} \
  --exclude="__pycache__" \
  --exclude="venv" \
  --exclude=".venv" \
  --exclude="mock_*" \
  --exclude="test_*" \
  --exclude="*_test.py" \
  "$FUNCTIONS_DIR" 2>/dev/null | \
  jq -r 'select(.name != null and (.name | startswith("_") | not)) | [.name, .kind, .path, (.line // 0)] | @tsv' \
  > "$TEMP_DIR/py_symbols.tsv" || true

# ═══════════════════════════════════════════════════════════
# Phase 3: Enhanced extraction with grep for Freezed + decorators
# ═══════════════════════════════════════════════════════════
echo "  🧊 Scanning Freezed models..."

# Freezed factory constructors
grep -rn "factory " "$FLUTTER_LIB/models/generated/" 2>/dev/null | \
  grep -v ".freezed.dart" | grep -v ".g.dart" | \
  sed 's|.*/||' > "$TEMP_DIR/freezed_factories.txt" || true

# Riverpod providers
grep -rn "final.*Provider\|final.*StateNotifierProvider\|final.*FutureProvider\|final.*StreamProvider\|final.*NotifierProvider" \
  "$FLUTTER_LIB" 2>/dev/null | \
  grep -v ".freezed.dart" | grep -v ".g.dart" | \
  sed 's|.*origna_gta/lib/||' > "$TEMP_DIR/providers.txt" || true

# Firebase Cloud Function decorators (@https_fn, @scheduler_fn, @on_document_*)
grep -rn "@https_fn\|@scheduler_fn\|@on_document_\|@https_fn.on_call\|@https_fn.on_request" \
  "$FUNCTIONS_DIR" 2>/dev/null | \
  grep -v "__pycache__" | grep -v "venv" | \
  sed 's|.*functions/||' > "$TEMP_DIR/cloud_functions.txt" || true

# Pydantic models
grep -rn "class.*BaseModel\|class.*BaseSchema" \
  "$FUNCTIONS_DIR/models/" 2>/dev/null | \
  grep -v "__pycache__" | \
  sed 's|.*functions/||' > "$TEMP_DIR/pydantic_models.txt" || true

# ═══════════════════════════════════════════════════════════
# Phase 4: Build the SYMBOL_MAP.md
# ═══════════════════════════════════════════════════════════
echo "  📝 Building SYMBOL_MAP.md..."

cat > "$OUTPUT_FILE" << 'HEADER'
# 🗺️ Symbol Map — OrignaGta

> **Auto-generated** by `scripts/generate-symbol-map.sh` using universal-ctags + grep.
> Regenerate: `./scripts/generate-symbol-map.sh`
> Last updated: TIMESTAMP

This map provides AST-extracted class/function signatures organized by domain.
Use it for navigating the codebase architecture without reading every file.

---

HEADER

# Replace TIMESTAMP
sed -i '' "s|TIMESTAMP|$(date '+%Y-%m-%d %H:%M')|" "$OUTPUT_FILE"

# ─── Helper: extract symbols for a domain by path patterns ───
extract_dart_domain() {
  local domain_name="$1"
  shift
  local patterns=("$@")

  echo "### $domain_name (Dart/Flutter)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "| Symbol | Kind | File | Line |" >> "$OUTPUT_FILE"
  echo "|--------|------|------|------|" >> "$OUTPUT_FILE"

  local found=0
  for pattern in "${patterns[@]}"; do
    while IFS=$'\t' read -r name kind path line; do
      if [[ "$path" == *"$pattern"* ]]; then
        # Relative path from lib/
        rel_path=$(echo "$path" | sed "s|.*/origna_gta/lib/|lib/|")
        echo "| \`$name\` | $kind | $rel_path | L$line |" >> "$OUTPUT_FILE"
        found=1
      fi
    done < "$TEMP_DIR/dart_symbols.tsv"
  done

  if [ "$found" -eq 0 ]; then
    echo "| *(no symbols extracted)* | — | — | — |" >> "$OUTPUT_FILE"
  fi
  echo "" >> "$OUTPUT_FILE"
}

extract_python_domain() {
  local domain_name="$1"
  shift
  local patterns=("$@")

  echo "### $domain_name (Python Backend)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "| Symbol | Kind | File | Line |" >> "$OUTPUT_FILE"
  echo "|--------|------|------|------|" >> "$OUTPUT_FILE"

  local found=0
  for pattern in "${patterns[@]}"; do
    while IFS=$'\t' read -r name kind path line; do
      if [[ "$path" == *"$pattern"* ]]; then
        rel_path=$(echo "$path" | sed "s|.*/functions/|functions/|")
        echo "| \`$name\` | $kind | $rel_path | L$line |" >> "$OUTPUT_FILE"
        found=1
      fi
    done < "$TEMP_DIR/py_symbols.tsv"
  done

  if [ "$found" -eq 0 ]; then
    echo "| *(no symbols extracted)* | — | — | — |" >> "$OUTPUT_FILE"
  fi
  echo "" >> "$OUTPUT_FILE"
}

# ─── Domain: Auth & User ───
echo "## 🔐 Auth & User" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
extract_dart_domain "Auth (Frontend)" "features/auth" "core/repositories/auth"
extract_python_domain "Auth (Backend)" "handlers/admin" "models/user"

# ─── Domain: Products ───
echo "## 📦 Products" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
extract_dart_domain "Products (Frontend)" "features/products" "core/repositories/product" "models/generated/product"
extract_python_domain "Products (Backend)" "handlers/products" "models/product"

# ─── Domain: Orders ───
echo "## 📋 Orders" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
extract_dart_domain "Orders (Frontend)" "features/orders" "core/repositories/order" "models/generated/order"
extract_python_domain "Orders (Backend)" "handlers/orders" "models/order" "handlers/cron"

# ─── Domain: Payments ───
echo "## 💳 Payments" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
extract_dart_domain "Payments (Frontend)" "features/checkout" "features/cart"
extract_python_domain "Payments (Backend)" "handlers/payment" "handlers/payment_stripe" "handlers/payment_airwallex" "handlers/payment_providers"

# ─── Domain: Seller ───
echo "## 🏪 Seller" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
extract_dart_domain "Seller (Frontend)" "features/seller"
extract_python_domain "Seller (Backend)" "handlers/admin"

# ─── Domain: Cart ───
echo "## 🛒 Cart" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
extract_dart_domain "Cart (Frontend)" "features/cart" "core/repositories/cart"

# ─── Domain: Core / Schema ───
echo "## 🏗️ Core & Schema" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
extract_dart_domain "Core (Frontend)" "core/schema" "core/providers" "core/repositories"
extract_python_domain "Schema & Config (Backend)" "schema_constants" "config" "utils"

# ─── Domain: Services ───
echo "## ⚙️ Services" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
extract_dart_domain "Services (Frontend)" "services/"
extract_python_domain "Services (Backend)" "shipping_service" "email_service" "algolia_service" "rate_limiter" "airwallex_service"

# ─── Freezed Models ───
echo "## 🧊 Freezed Models (Generated)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
if [ -s "$TEMP_DIR/freezed_factories.txt" ]; then
  echo '```' >> "$OUTPUT_FILE"
  cat "$TEMP_DIR/freezed_factories.txt" >> "$OUTPUT_FILE"
  echo '```' >> "$OUTPUT_FILE"
else
  echo "*(No Freezed factories extracted)*" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# ─── Pydantic Models ───
echo "## 🐍 Pydantic Models" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
if [ -s "$TEMP_DIR/pydantic_models.txt" ]; then
  echo '```' >> "$OUTPUT_FILE"
  cat "$TEMP_DIR/pydantic_models.txt" >> "$OUTPUT_FILE"
  echo '```' >> "$OUTPUT_FILE"
else
  echo "*(No Pydantic models extracted)*" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# ─── Riverpod Providers ───
echo "## 🔌 Riverpod Providers" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
if [ -s "$TEMP_DIR/providers.txt" ]; then
  echo '```' >> "$OUTPUT_FILE"
  cat "$TEMP_DIR/providers.txt" >> "$OUTPUT_FILE"
  echo '```' >> "$OUTPUT_FILE"
else
  echo "*(No Riverpod providers extracted)*" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# ─── Cloud Functions Endpoints ───
echo "## ☁️ Cloud Functions Endpoints" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
if [ -s "$TEMP_DIR/cloud_functions.txt" ]; then
  echo '```' >> "$OUTPUT_FILE"
  cat "$TEMP_DIR/cloud_functions.txt" >> "$OUTPUT_FILE"
  echo '```' >> "$OUTPUT_FILE"
else
  echo "*(No Cloud Function decorators extracted)*" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# ─── Stats ───
DART_COUNT=$(wc -l < "$TEMP_DIR/dart_symbols.tsv" | tr -d ' ')
PY_COUNT=$(wc -l < "$TEMP_DIR/py_symbols.tsv" | tr -d ' ')
PROVIDER_COUNT=$(wc -l < "$TEMP_DIR/providers.txt" 2>/dev/null | tr -d ' ' || echo "0")

echo "---" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "**Stats:** $DART_COUNT Dart symbols, $PY_COUNT Python symbols, $PROVIDER_COUNT Riverpod providers extracted." >> "$OUTPUT_FILE"

echo ""
echo "✅ Symbol map generated: $OUTPUT_FILE"
echo "   📊 Dart symbols: $DART_COUNT | Python symbols: $PY_COUNT | Providers: $PROVIDER_COUNT"
