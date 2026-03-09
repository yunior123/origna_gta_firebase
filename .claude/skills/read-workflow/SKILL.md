---
name: read-workflow
description: Read all files in a workflow group before making changes. Use this BEFORE editing any file to load full context.
context: fork
agent: Explore
---

# Read Workflow Context

Load full context for the **$ARGUMENTS** workflow.

## Steps

1. Read `docs/WORKFLOW_INDEX.md`
2. Find the section for **$ARGUMENTS**
3. Read ALL files listed, in order:
   - Frontend files first (Dart)
   - Backend files (Python)
   - Schema files
   - Test files
4. Summarize:
   - Key data flows
   - Current state of the logic
   - Field mappings between frontend and backend
   - Any inconsistencies spotted
5. Return a concise summary the main conversation can use before editing

## Invocation

```
/read-workflow checkout
/read-workflow orders
/read-workflow products
/read-workflow auth
```
