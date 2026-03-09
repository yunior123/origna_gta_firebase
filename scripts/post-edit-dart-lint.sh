#!/usr/bin/env bash
# Post-edit hook: Runs dart analyze on changed Flutter files.
# Used by Claude Code hooks to auto-lint after edits.

set -euo pipefail

CHANGED_FILE="${1:-}"

# Only run for Dart files
case "$CHANGED_FILE" in
  *.dart)
    echo "🔍 Dart file changed: $CHANGED_FILE"
    cd "$(dirname "$0")/../origna_gta"
    
    # Run dart analyze on the specific file
    if dart analyze "$CHANGED_FILE" 2>/dev/null; then
      echo "✅ No analysis issues"
    else
      echo "⚠️  Dart analysis found issues — check above"
    fi
    ;;
  *)
    # Not a Dart file — skip
    ;;
esac
