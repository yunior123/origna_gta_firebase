#!/bin/bash
# Hook: PostToolUse — After editing schema-related files, warn Claude about schema sync
# Reads the tool input from stdin and checks if the edited file is schema-related

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Check if the edited file is schema-related
SCHEMA_PATTERNS=(
  "schema_constants"
  "database_schema"
  "models/order"
  "models/product"
  "models/user"
  "models/base"
  "order_models"
  "product_models"
  "user_models"
  "base_models"
  "firestore.rules"
)

IS_SCHEMA=false
for pattern in "${SCHEMA_PATTERNS[@]}"; do
  if echo "$FILE_PATH" | grep -q "$pattern"; then
    IS_SCHEMA=true
    break
  fi
done

if [ "$IS_SCHEMA" = true ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"⚠️ SCHEMA FILE EDITED: $FILE_PATH — You MUST run the schema-sync-checker agent to verify all 6 schema layers are still in sync. Use: 'Use the schema-sync-checker to verify schema sync after editing $FILE_PATH'\"}}"
fi

exit 0
