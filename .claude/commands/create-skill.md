# /create-skill — Capture a workflow approach as a reusable skill

Save the current approach/pattern as a reusable skill for future sessions.

## Input
$ARGUMENTS = name of the skill (kebab-case, e.g., "api-migration" or "bulk-refactor")

## What to do:

1. Ask the user (or infer from context): "What approach/pattern should this skill capture?"
2. Create the skill file at `.claude/skills/$ARGUMENTS/SKILL.md` with this structure:

```markdown
---
name: $ARGUMENTS
description: [one-line description of what this skill does]
context: fork
---

# [Skill Title]

## When to Use
[Describe the situation where this skill is useful]

## Process
1. [Step 1]
2. [Step 2]
3. [etc.]

## Files Typically Involved
- [list common files this pattern touches]

## Verification
- [How to verify the skill was applied correctly]

## Examples
[Brief example of input → output]
```

3. Confirm: "✅ Skill `$ARGUMENTS` created at `.claude/skills/$ARGUMENTS/SKILL.md`"
4. The skill will be available in future sessions via the skills system
