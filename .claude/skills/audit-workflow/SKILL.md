---
name: audit-workflow
description: Use when auditing any workflow (checkout, orders, auth, payment, schema) by reading all related files as indexed chunks. Run before editing 3+ files in a workflow.
context: fork
agent: logic-auditor
disable-model-invocation: true
---

# Workflow Audit Skill

Audit the **$ARGUMENTS** workflow by reading ALL related files in indexed chunks.

## Process

1. Read `docs/WORKFLOW_INDEX.md` and find the section for **$ARGUMENTS**
2. Read ALL files listed in that workflow section, in chunks:
   - **Chunk 1 (Frontend)**: Read all Dart screen + viewmodel + provider files
   - **Chunk 2 (Backend)**: Read all Python handler + service files
   - **Chunk 3 (Schema)**: Read schema_constants (both Dart + Python), models, database_schema.json
   - **Chunk 4 (Tests)**: Read test files for this workflow
3. Cross-reference frontend ↔ backend for:
   - Field name mismatches (camelCase vs snake_case)
   - Request/response format mismatches
   - Error handling gaps
   - Enum value mismatches
   - Authorization checks present on backend but not enforced (or vice versa)
4. Check all Logic Checkpoints listed in WORKFLOW_INDEX.md
5. Report findings in the standard BUG format

## Invocation

```
/audit-workflow checkout
/audit-workflow orders
/audit-workflow products
/audit-workflow auth
/audit-workflow payments
/audit-workflow schema
```
