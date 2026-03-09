# /pause-work — Save session state for later resume

Save the current work state so it can be resumed in a future session.

## What to do:

1. Create/update the file `STATE.md` in the project root with:

```markdown
# STATE.md — Work in Progress

## Last Updated
[current timestamp]

## Current Task
[Description of what was being worked on]

## Phase
[planning | implementing | testing | reviewing]

## Files Modified (this session)
- [list each file changed and what was changed]

## Files Still To Edit
- [list remaining files that need changes]

## Blockers / Open Questions
- [anything unresolved]

## Context to Restore
- [key decisions made, patterns discovered, important findings]
- [any subagent results worth preserving]

## Next Steps (in order)
1. [first thing to do when resuming]
2. [second thing]
3. [etc.]
```

2. Run `git diff --name-only` to auto-populate the "Files Modified" section
3. Tell the user: "✅ State saved to STATE.md. Use `/resume-work` to continue."
