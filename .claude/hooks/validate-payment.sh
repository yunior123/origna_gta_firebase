#!/bin/bash
# Hook: PostToolUse — After editing payment-related files, remind Claude to audit
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

PAYMENT_PATTERNS=(
  "payment_stripe"
  "checkout_provider"
  "checkout_screen"
  "stripe"
  "payment"
  "capture"
  "refund"
)

IS_PAYMENT=false
for pattern in "${PAYMENT_PATTERNS[@]}"; do
  if echo "$FILE_PATH" | grep -qi "$pattern"; then
    IS_PAYMENT=true
    break
  fi
done

if [ "$IS_PAYMENT" = true ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"💰 PAYMENT FILE EDITED: $FILE_PATH — You MUST run the payment-auditor agent to verify financial correctness. Use: 'Use the payment-auditor to audit the payment pipeline after editing $FILE_PATH'\"}}"
fi

exit 0
