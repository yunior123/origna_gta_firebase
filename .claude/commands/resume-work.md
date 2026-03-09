# /resume-work — Restore session state and continue

Resume work from where the last session left off.

## What to do:

1. Read `STATE.md` from the project root
2. If STATE.md doesn't exist, tell the user "No saved state found. Use `/pause-work` to save state first, or describe what you want to work on."
3. If STATE.md exists:
   a. Read the "Current Task" and "Phase" sections
   b. Read ALL files listed in "Files Modified" to understand what was done
   c. Read the "Context to Restore" section carefully
   d. Read the "Next Steps" section
   e. Present a brief summary:
      ```
      📋 Resuming: [task description]
      📍 Phase: [phase]
      ✅ Done: [what was completed]
      ➡️ Next: [first next step]
      ```
   f. Ask: "Ready to continue with [first next step]?"
4. After resuming, do NOT delete STATE.md — keep it updated as work progresses
