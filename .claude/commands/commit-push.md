# /commit-push - Commit and push changes with intelligent message

**Usage**: `/commit-push [optional message]`

## What it does:
1. Stages all changes (`git add .`)
2. Generates intelligent commit message based on changes
3. Commits with message
4. Pushes to remote

## Examples:
```
/commit-push
/commit-push "Fix critical security issue in webhooks"
```

## Implementation:
```bash
#!/bin/bash
cd "$(git rev-path --show-toplevel)"

# Stage changes
git add .

# Generate or use provided message
if [ -z "$1" ]; then
  # Auto-generate message from git diff
  MESSAGE=$(git diff --cached --name-only | head -5 | awk '{print "Update " $1}' | paste -sd ", " -)
  MESSAGE="chore: $MESSAGE"
else
  MESSAGE="$1"
fi

# Commit and push
git commit -m "$MESSAGE"
git push origin $(git branch --show-current)

echo "✓ Committed and pushed: $MESSAGE"
```
