#!/usr/bin/env bash
# PreToolUse: blocks edits to secrets/config files that should never be modified by Claude.
# Exit 1 = BLOCKED (Claude sees the message and stops).

set -euo pipefail

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

FILE=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Handle both 'file_path' (Write/Edit) and 'path' fields
    print(d.get('file_path', d.get('path', '')))
except Exception:
    print('')
" 2>/dev/null || echo "")

if [[ -z "$FILE" ]]; then
  exit 0
fi

BASENAME=$(basename "$FILE")

# Define blocked patterns
BLOCKED_PATTERNS=(
  "\.env$"
  "\.env\..*"
  "google-services\.json$"
  "GoogleService-Info\.plist$"
  "firebase_options\.dart$"
  "\.pem$"
  "\.key$"
  "service-account.*\.json$"
)

for PATTERN in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$BASENAME" | grep -qE "$PATTERN"; then
    echo ""
    echo "🚫 BLOCKED: '$FILE' is a secrets/config file."
    echo "   These files must not be edited by Claude to prevent accidental credential exposure."
    echo "   If you genuinely need to edit this file, do it manually in your editor."
    exit 2
  fi
done

exit 0
