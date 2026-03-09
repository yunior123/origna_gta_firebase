# /clear-context — Pre-clear checklist and context hygiene

Before clearing context, perform a safety checklist to avoid losing important work.

## Input
$ARGUMENTS = optional reason for clearing (e.g., "switching to payment work", "context is bloated")

## What to do:

1. **Check context health:**
   - Estimate current context usage (if near 60k tokens or 30% capacity → clearing is recommended)
   - If context is still small and focused → warn "Context is still healthy — consider `/compact` instead"

2. **Save state before clearing:**
   - Run `git diff --name-only` to check for uncommitted changes
   - If there ARE uncommitted changes, run `/pause-work` FIRST to save state to STATE.md
   - If no changes, skip state saving

3. **Summarize what will be lost:**
   - List the key topics discussed in this session
   - List any decisions made that should be persisted
   - If there are important learnings, add them to CLAUDE.md LEARNED section BEFORE clearing

4. **Recommend the right action:**
   - **If context is >60k tokens or >30% capacity** → "✅ Safe to `/clear`. State has been saved."
   - **If context is bloated but has useful info** → "Consider `/compact Focus on [current task]` to preserve key context"
   - **If context is still healthy** → "⚠️ Context is still healthy. No need to clear yet."

5. **Post-clear reminder:**
   - After clearing, the first message should reference `STATE.md` and `CLAUDE.md` to restore context
   - Remind: "After `/clear`, start with: Read STATE.md and CLAUDE.md to restore context"

## Context Hygiene Rules (for reference):
- Clear at **~60k tokens** or **30% context capacity** — whichever comes first
- Never let context rot past 50% — quality degrades significantly
- Prefer **short, focused sessions** over marathon sessions
- Use **subagents for investigation** to keep main context clean
- After 2 failed correction attempts → `/clear` and restart with a better prompt
