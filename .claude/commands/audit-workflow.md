Run a deep logic audit on a specific workflow. Usage: /audit-workflow [checkout|orders|products|auth|payments|all]

Read docs/WORKFLOW_INDEX.md first to identify all files in the target workflow.
Then read EVERY file listed for that workflow — both frontend and backend.
Trace the complete data flow: UI → ViewModel → Repository → Cloud Function → Firestore → Response → UI
Check every "Logic checkpoint" listed in the workflow index.

For each bug found, report:
- Severity: CRITICAL / HIGH / MEDIUM / LOW
- Location: file:line → file:line (cross-stack)
- Description: What's wrong
- Trace: The code path that leads to the bug
- Fix: Specific change needed

Focus on logic errors, not style. Think like an adversarial user trying to break the system.
Use ultrathink for maximum reasoning depth.
