#!/usr/bin/env bash
# PostToolUse: runs flutter analyze on the edited Dart file.
# Exits with error if issues are found so Claude sees them immediately.

set -euo pipefail

TOOL_OUTPUT="${CLAUDE_TOOL_OUTPUT:-}"

FILE=$(echo "$TOOL_OUTPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# Only proceed for .dart files inside origna_gta
if [[ "$FILE" != *".dart" ]]; then
  exit 0
fi

PROJECT_DIR="$CLAUDE_PROJECT_DIR/origna_gta"
if [[ ! -d "$PROJECT_DIR" ]]; then
  exit 0
fi

echo "🔍 flutter analyze: $FILE"
OUTPUT=$(cd "$PROJECT_DIR" && flutter analyze --no-fatal-infos "$FILE" 2>&1 | tail -20)
echo "$OUTPUT"

# Fail loudly if any error/warning lines found
if echo "$OUTPUT" | grep -qE "^(error|warning) •"; then
  echo ""
  echo "❌ flutter analyze found issues in $FILE — fix before proceeding."
  exit 1
fi

echo "✅ flutter analyze clean."
exit 0
