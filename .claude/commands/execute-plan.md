# /execute-plan — Execute the current plan phase by phase

Execute the plan saved in STATE.md, one phase at a time.

## What to do:

1. Read `STATE.md` to get the current plan
2. If no plan exists, tell the user: "No plan found. Use `/plan-task [description]` first."
3. Find the first uncompleted phase
4. Execute that phase:
   - For each task in the phase, do the work
   - Mark completed tasks with [x]
   - If a task fails or reveals issues, STOP and report
5. After completing a phase:
   - Update STATE.md with progress
   - Check the Quality Gates for that phase
   - Report: "✅ Phase [N] complete. [summary]. Moving to Phase [N+1]?"
6. Between phases, ask for user confirmation before proceeding
7. At the final phase (Verification):
   - Run all required auditor agents
   - Run full test suite
   - Report final status
8. After all phases complete:
   - Update STATE.md status to "COMPLETED"
   - Summary of all changes made
   - Suggest: "Ready to commit? Use `/commit-push`"
