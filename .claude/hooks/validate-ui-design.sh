#!/bin/bash
# Validates UI changes follow design system rules
# Triggered on PostToolUse for edits to Flutter UI files

CHANGED_FILE="$CLAUDE_FILE_PATH"

# Only check Flutter UI files
if [[ "$CHANGED_FILE" != *"origna_gta/lib/screens/"* ]] && \
   [[ "$CHANGED_FILE" != *"origna_gta/lib/widgets/"* ]] && \
   [[ "$CHANGED_FILE" != *"origna_gta/lib/utils/"* ]]; then
  exit 0
fi

ISSUES=""

# Check for hardcoded colors (common anti-pattern)
HARDCODED_COLORS=$(grep -n "Color(0x" "$CHANGED_FILE" 2>/dev/null | grep -v "DesignTokens" | grep -v "//" | head -5)
if [ -n "$HARDCODED_COLORS" ]; then
  ISSUES="${ISSUES}\n⚠️ HARDCODED COLORS found (use DesignTokens instead):\n${HARDCODED_COLORS}\n"
fi

# Check for withOpacity (deprecated)
DEPRECATED_OPACITY=$(grep -n "\.withOpacity(" "$CHANGED_FILE" 2>/dev/null | head -3)
if [ -n "$DEPRECATED_OPACITY" ]; then
  ISSUES="${ISSUES}\n⚠️ DEPRECATED withOpacity() found (use withValues(alpha:) instead):\n${DEPRECATED_OPACITY}\n"
fi

# Check for MaterialPageRoute (should use SlidePageRoute)
MATERIAL_ROUTE=$(grep -n "MaterialPageRoute" "$CHANGED_FILE" 2>/dev/null | head -3)
if [ -n "$MATERIAL_ROUTE" ]; then
  ISSUES="${ISSUES}\n⚠️ MaterialPageRoute found (use SlidePageRoute / context.pushAnimated instead):\n${MATERIAL_ROUTE}\n"
fi

# Check for CircularProgressIndicator (should use ShimmerLoading)
SPINNER=$(grep -n "CircularProgressIndicator" "$CHANGED_FILE" 2>/dev/null | head -3)
if [ -n "$SPINNER" ]; then
  ISSUES="${ISSUES}\n⚠️ CircularProgressIndicator found (consider ShimmerLoading for better UX):\n${SPINNER}\n"
fi

# Check for IconButton without tooltip
ICON_NO_TOOLTIP=$(grep -n "IconButton(" "$CHANGED_FILE" 2>/dev/null | while read line; do
  LINE_NUM=$(echo "$line" | cut -d: -f1)
  # Check next 5 lines for tooltip
  HAS_TOOLTIP=$(sed -n "${LINE_NUM},$((LINE_NUM+5))p" "$CHANGED_FILE" 2>/dev/null | grep "tooltip")
  if [ -z "$HAS_TOOLTIP" ]; then
    echo "$line"
  fi
done | head -3)
if [ -n "$ICON_NO_TOOLTIP" ]; then
  ISSUES="${ISSUES}\n♿ IconButton without tooltip (accessibility issue):\n${ICON_NO_TOOLTIP}\n"
fi

if [ -n "$ISSUES" ]; then
  echo -e "🎨 UI Design System Check:${ISSUES}"
  echo ""
  echo "Reference: .claude/skills/design-system-bible/SKILL.md"
fi

exit 0
