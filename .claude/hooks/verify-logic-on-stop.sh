#!/bin/bash
# Hook: Stop — Verify code quality before Claude finishes a session
# Runs: (a) dart analyze on modified .dart files
#        (b) ruff check on modified .py files
#        (c) associated unit tests for changed files
# Returns JSON with decision:block if critical errors found

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FLUTTER_DIR="$PROJECT_DIR/origna_gta"
FUNCTIONS_DIR="$PROJECT_DIR/functions"

# Collect stdin (Claude hook protocol)
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")

# Don't loop — if we're already in a stop hook, let it finish
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# ─── Detect modified files (staged + unstaged vs HEAD) ───
DART_FILES=()
PY_FILES=()

while IFS= read -r file; do
  case "$file" in
    origna_gta/lib/*.dart) DART_FILES+=("$file") ;;
    functions/*.py)        PY_FILES+=("$file") ;;
  esac
done < <(cd "$PROJECT_DIR" && { git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached HEAD 2>/dev/null; } | sort -u)

# If no files changed, nothing to verify
if [ ${#DART_FILES[@]} -eq 0 ] && [ ${#PY_FILES[@]} -eq 0 ]; then
  exit 0
fi

ERRORS=()
WARNINGS=()

# ═══════════════════════════════════════════════════════════
# (a) Dart Analysis — dart analyze --fatal-infos
# ═══════════════════════════════════════════════════════════
if [ ${#DART_FILES[@]} -gt 0 ]; then
  if command -v dart &>/dev/null; then
    DART_OUTPUT=$(cd "$FLUTTER_DIR" && dart analyze --fatal-infos 2>&1) || true

    # Count errors and warnings
    DART_ERRORS=$(echo "$DART_OUTPUT" | grep -c " error " || true)
    DART_WARNS=$(echo "$DART_OUTPUT" | grep -c " warning " || true)

    if [ "$DART_ERRORS" -gt 0 ]; then
      ERROR_DETAILS=$(echo "$DART_OUTPUT" | grep " error " | head -5)
      ERRORS+=("🎯 Dart: $DART_ERRORS error(s) found. First errors: $ERROR_DETAILS")
    fi

    if [ "$DART_WARNS" -gt 0 ]; then
      WARNINGS+=("⚠️ Dart: $DART_WARNS warning(s) found")
    fi
  else
    WARNINGS+=("⚠️ dart CLI not found — skipping Dart analysis")
  fi
fi

# ═══════════════════════════════════════════════════════════
# (b) Ruff Check — Python linting
# ═══════════════════════════════════════════════════════════
if [ ${#PY_FILES[@]} -gt 0 ]; then
  if command -v ruff &>/dev/null; then
    RUFF_TARGETS=()
    for f in "${PY_FILES[@]}"; do
      RUFF_TARGETS+=("$PROJECT_DIR/$f")
    done

    RUFF_OUTPUT=$(cd "$FUNCTIONS_DIR" && ruff check "${RUFF_TARGETS[@]}" 2>&1) || true
    RUFF_ERRORS=$(echo "$RUFF_OUTPUT" | grep -cE "^[^:]+:[0-9]+:" || true)

    if [ "$RUFF_ERRORS" -gt 0 ]; then
      RUFF_DETAILS=$(echo "$RUFF_OUTPUT" | head -5)
      ERRORS+=("🐍 Python (ruff): $RUFF_ERRORS issue(s). First: $RUFF_DETAILS")
    fi
  else
    WARNINGS+=("⚠️ ruff not installed — skipping Python linting. Install: pip install ruff")
  fi
fi

# ═══════════════════════════════════════════════════════════
# (c) Run associated unit tests for changed files
# ═══════════════════════════════════════════════════════════

# Dart tests
if [ ${#DART_FILES[@]} -gt 0 ] && command -v flutter &>/dev/null; then
  for dart_file in "${DART_FILES[@]}"; do
    test_file=$(echo "$dart_file" | sed 's|origna_gta/lib/|origna_gta/test/|' | sed 's|\.dart$|_test.dart|')
    if [ -f "$PROJECT_DIR/$test_file" ]; then
      TEST_OUT=$(cd "$FLUTTER_DIR" && flutter test "$PROJECT_DIR/$test_file" --no-pub 2>&1) || true
      if echo "$TEST_OUT" | grep -q "Some tests failed"; then
        FAIL_DETAILS=$(echo "$TEST_OUT" | grep -A2 "FAILED" | head -3)
        ERRORS+=("🧪 Dart test failed: $test_file — $FAIL_DETAILS")
      fi
    fi
  done
fi

# Python tests
if [ ${#PY_FILES[@]} -gt 0 ] && command -v pytest &>/dev/null; then
  for py_file in "${PY_FILES[@]}"; do
    basename_noext=$(basename "$py_file" .py)
    test_candidates=(
      "$FUNCTIONS_DIR/tests/test_${basename_noext}.py"
      "$FUNCTIONS_DIR/tests/${basename_noext}_test.py"
    )
    for test_file in "${test_candidates[@]}"; do
      if [ -f "$test_file" ]; then
        TEST_OUT=$(cd "$FUNCTIONS_DIR" && python -m pytest "$test_file" -q --tb=short 2>&1) || true
        if echo "$TEST_OUT" | grep -qE "(FAILED|ERROR)"; then
          FAIL_DETAILS=$(echo "$TEST_OUT" | grep -E "(FAILED|ERROR)" | head -3)
          ERRORS+=("🧪 Python test failed: $(basename "$test_file") — $FAIL_DETAILS")
        fi
        break
      fi
    done
  done
fi

# ═══════════════════════════════════════════════════════════
# Decision: Block or Allow
# ═══════════════════════════════════════════════════════════

TOTAL_ERRORS=${#ERRORS[@]}
TOTAL_WARNINGS=${#WARNINGS[@]}

if [ "$TOTAL_ERRORS" -gt 0 ]; then
  ERROR_MSG=""
  for err in ${ERRORS[@]+"${ERRORS[@]}"}; do
    ERROR_MSG+="$err\n"
  done
  for warn in ${WARNINGS[@]+"${WARNINGS[@]}"}; do
    ERROR_MSG+="$warn\n"
  done

  MODIFIED_SUMMARY="Dart: ${#DART_FILES[@]} files, Python: ${#PY_FILES[@]} files"

  echo "STOP HOOK — Quality Gate FAILED ❌"
  echo ""
  echo "Modified: $MODIFIED_SUMMARY"
  echo ""
  printf "$ERROR_MSG"
  echo ""
  echo "Fix these issues before completing the task."

  cat <<EOF
{"decision": "block", "reason": "Quality gate failed: $TOTAL_ERRORS error(s). $MODIFIED_SUMMARY modified. Fix Dart analysis errors, ruff issues, and failing tests before stopping."}
EOF
  exit 1
fi

# All clear
if [ "$TOTAL_WARNINGS" -gt 0 ]; then
  echo "STOP HOOK — Quality Gate PASSED ✅ (with ${TOTAL_WARNINGS} warning(s))"
  for warn in ${WARNINGS[@]+"${WARNINGS[@]}"}; do
    echo "  $warn"
  done
else
  echo "STOP HOOK — Quality Gate PASSED ✅"
  echo "  Dart files checked: ${#DART_FILES[@]}"
  echo "  Python files checked: ${#PY_FILES[@]}"
fi

exit 0
