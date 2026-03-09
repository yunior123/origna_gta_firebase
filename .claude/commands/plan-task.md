# /plan-task — Break a complex task into executable phases

Plan a multi-step task with verification gates before executing.

## Input
$ARGUMENTS = description of the task to plan

## What to do:

1. Analyze the task described in "$ARGUMENTS"
2. Consult `docs/WORKFLOW_INDEX.md` to identify all impacted files
3. Create a structured plan:

```markdown
# PLAN: [task title]

## Scope
- Files to read: [list]
- Files to modify: [list]
- Files to create: [list]
- Tests to update: [list]

## Phases

### Phase 1: Research & Context
- [ ] Read all relevant files (use subagent if >5 files)
- [ ] Identify cross-stack impacts
- [ ] Note current state of each file

### Phase 2: Implementation
- [ ] [specific change 1]
- [ ] [specific change 2]
- [ ] [etc.]

### Phase 3: Cross-Stack Sync
- [ ] Update schema_constants.py ↔ schema_constants.dart
- [ ] Update models if needed
- [ ] Update firestore.rules if needed

### Phase 4: Testing
- [ ] Run existing tests to verify no regressions
- [ ] Add/update tests for new behavior
- [ ] Run full test suite

### Phase 5: Verification
- [ ] Run logic-auditor on the workflow
- [ ] Run schema-sync-checker if schema changed
- [ ] Run payment-auditor if payment changed
- [ ] 50+ adversarial scenario check

## Quality Gates (MUST pass before commit)
- [ ] Logic audit: 0 CRITICAL findings
- [ ] All tests pass
- [ ] Cross-stack sync verified
- [ ] No regressions in related workflows
```

4. Save the plan to `STATE.md`
5. Ask: "Plan ready. Execute with `/execute-plan` or adjust?"
