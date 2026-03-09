---
name: origna-preflight
description: Use when preparing to commit or push origna_gta — runs flutter analyze then flutter test in sequence and reports pass/fail. Both must be green before any push.
disable-model-invocation: true
---

# /origna-preflight Skill

Pre-commit validation gate for `origna_gta`. Runs in sequence — **never in parallel** (8 GB RAM constraint).

## Sequence

### Step 1 — flutter analyze

```bash
cd ~/Documents/GitHub/origna_gta/origna_gta
flutter analyze --no-fatal-infos
```

- Must exit 0.
- If it fails: **STOP**. Show every error with file:line. Do NOT proceed to tests.
- Report: `✅ analyze clean` or `❌ analyze failed (N errors)`.

### Step 2 — flutter test

```bash
cd ~/Documents/GitHub/origna_gta/origna_gta
flutter test
```

- Must exit 0.
- If it fails: **STOP**. Show failed test names and assertion messages.
- Report: `✅ tests passed (N tests)` or `❌ tests failed (N failures)`.

## Final Report

```
Preflight result:
  analyze : ✅ clean   | ❌ N errors
  tests   : ✅ N pass  | ❌ N fail / skipped

→ READY TO PUSH  |  → DO NOT PUSH — fix failures first
```

## Rules

- Run analyze first, always.
- Do NOT push if either step fails.
- Do NOT parallelize — run sequentially.
- Never suppress warnings with `// ignore` to make the gate pass.
