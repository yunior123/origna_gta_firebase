#!/usr/bin/env bash
# Post-edit hook: Validates schema consistency after schema-related files are edited.
# Used by Claude Code hooks to auto-check after edits.

set -euo pipefail

CHANGED_FILE="${1:-}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Only run for schema-related files
case "$CHANGED_FILE" in
  *schema_constants* | *database_schema* | *firestore.rules | *models/base* | *models/order* | *models/product* | *models/user* | *base_models* | *order_models* | *product_models* | *user_models*)
    echo "🔍 Schema-related file changed: $CHANGED_FILE"
    echo "   Checking schema consistency..."
    
    # Quick check: compare field counts between Python and Dart constants
    PY_FIELDS=$(grep -c "= '" "$PROJECT_ROOT/functions/schema_constants.py" 2>/dev/null || echo "0")
    DART_FIELDS=$(grep -c "= '" "$PROJECT_ROOT/origna_gta/lib/core/schema/schema_constants.dart" 2>/dev/null || echo "0")
    
    if [ "$PY_FIELDS" != "$DART_FIELDS" ]; then
      echo "⚠️  WARNING: schema_constants field count mismatch!"
      echo "   Python: $PY_FIELDS fields"
      echo "   Dart:   $DART_FIELDS fields"
      echo "   Run: ./scripts/validate_schema_consistency.sh"
    else
      echo "✅ Schema constants field counts match ($PY_FIELDS fields)"
    fi
    ;;
  *)
    # Not a schema file — no check needed
    ;;
esac
