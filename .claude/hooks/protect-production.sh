#!/bin/bash
# Hook: PreToolUse — Protect production-critical files from accidental edits
# Warns when editing deployment configs, production secrets, or firebase config

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Production-critical file patterns
BLOCKED=false
REASON=""

# Direct production config files
case "$FILE_PATH" in
  *serviceAccountKey*)
    BLOCKED=true
    REASON="🔒 SERVICE ACCOUNT KEY — This is a production secret. Are you sure you need to edit it?"
    ;;
  *firebase.json)
    REASON="⚠️ FIREBASE CONFIG — Changes here affect ALL environments (emulator + production)."
    ;;
  *firestore.rules)
    REASON="⚠️ FIRESTORE RULES — Changes affect data security for ALL users. Run schema-sync-checker after editing."
    ;;
  *storage.rules)
    REASON="⚠️ STORAGE RULES — Changes affect file access security."
    ;;
  *.env.production*|*prod.env*)
    BLOCKED=true
    REASON="🔒 PRODUCTION ENV — Cannot edit production environment variables directly."
    ;;
esac

if [ "$BLOCKED" = true ]; then
  echo "{\"decision\":\"block\",\"reason\":\"$REASON\"}"
  exit 0
fi

if [ -n "$REASON" ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"$REASON\"}}"
fi

exit 0
