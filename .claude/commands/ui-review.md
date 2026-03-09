```markdown
---
description: >
  Run a comprehensive UI/UX audit on a specific screen or widget. 
  Grades visual quality, motion design, responsiveness, accessibility, and performance.
  Produces actionable improvement recommendations ranked by impact.
---

# UI/UX Design Review

Run the `uiux-expert` agent on the target screen(s).

## Steps

1. **Identify Target** — Determine which screen/widget to audit from the user's request.
   If no specific screen is mentioned, audit ALL screens in `origna_gta/lib/screens/`.

2. **Read Context** — Read these files first:
   - `origna_gta/lib/utils/design_tokens.dart` (current tokens)
   - `origna_gta/lib/utils/glassmorphism.dart` (glass components)
   - `origna_gta/lib/utils/responsive_layout.dart` (responsive system)
   - The target screen file(s)
   - Any related widgets in `origna_gta/lib/widgets/`

3. **Audit** — For each screen, evaluate against all 5 dimensions:
   - **Visual Quality** — Design token usage, spacing, typography, consistency
   - **Motion Design** — Entrance animations, interactions, transitions
   - **Responsive** — All 4 breakpoints, touch targets, overflow
   - **Accessibility** — Semantics, contrast, focus order, screen reader
   - **Performance** — const constructors, builders, RepaintBoundary

4. **Grade** — Assign A/B/C/D/F grade per dimension and overall.

5. **Recommend** — Produce ranked improvement list with:
   - Impact level (HIGH/MEDIUM/LOW)
   - Exact file and line number
   - Specific code change
   - Before/after visualization if possible

6. **Implement** — If the user requests it, implement the top improvements.

```
