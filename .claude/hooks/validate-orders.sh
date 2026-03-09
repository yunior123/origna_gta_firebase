#!/bin/bash
# Hook: PostToolUse — After editing order-related files, remind Claude to audit state machine
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

ORDER_PATTERNS=(
  "orders.py"
  "order_models"
  "orders_viewmodel"
  "orders_screen"
  "cron_jobs"
  "shipping_approval"
  "order_lifecycle"
)

IS_ORDER=false
for pattern in "${ORDER_PATTERNS[@]}"; do
  if echo "$FILE_PATH" | grep -qi "$pattern"; then
    IS_ORDER=true
    break
  fi
done

if [ "$IS_ORDER" = true ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"📦 ORDER FILE EDITED: $FILE_PATH — You MUST run the order-lifecycle-auditor to verify state machine consistency. Use: 'Use the order-lifecycle-auditor to trace state transitions after editing $FILE_PATH'\"}}"
fi

exit 0
