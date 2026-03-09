#!/bin/bash
# Hook: PostToolUse — After editing premium/subscription files, remind to run premium-auditor
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

PREMIUM_PATTERNS=(
  "subscription"
  "premium"
  "isPremium"
  "premium_paywall"
  "PremiumPaywall"
  "subscriptionStream"
)

IS_PREMIUM=false
for pattern in "${PREMIUM_PATTERNS[@]}"; do
  if echo "$FILE_PATH" | grep -qi "$pattern"; then
    IS_PREMIUM=true
    break
  fi
done

if [ "$IS_PREMIUM" = true ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"👑 PREMIUM FILE EDITED: $FILE_PATH — You MUST run the premium-auditor agent to verify the premium lifecycle. Use: 'Use the premium-auditor to audit the premium subscription pipeline after editing $FILE_PATH'\"}}"
fi

exit 0
