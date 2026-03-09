---
name: repomix-codebase-snapshot
description: Use when needing a full codebase snapshot for bulk AI analysis — generates a Repomix XML bundle of the entire OrignaGTA repo for passing to Gemini or Claude.ai.
---

# Repomix Codebase Snapshot Skill

## Instructions

1.  **Generate the Snapshot**:
    - Ensure `npx` and `node` are available.
    - Run the command: `npx repomix` (uses `REPOMIX.config.json`).
    - The output will be in `repomix-output.txt`.

2.  **Analysis Context**:
    - Use this snapshot when you need to understand the **system as a whole** (e.g., cross-stack drift, architectural alignment).
    - It's much faster to search one large file (`repomix-output.txt`) than hundreds of small files.

3.  **Audit Drift (Frontend vs Backend)**:
    - Compare `lib/core/schema/schema_constants.dart` with `functions/schema_constants.py`.
    - Compare `lib/models/generated/*.dart` with `functions/models/*.py`.
    - Compare `lib/features/` logic with corresponding `functions/handlers/`.

4.  **Audit Testing Parity**:
    - Verify that there's a test for every Cloud Function in `functions/tests/`.
    - Verify that there's a Flutter test for every screen in `origna_gta/test/`.

5.  **Audit Security Consistency**:
    - Check `firestore.rules` against the `models/*.py` field validation.

## Workflow
1.  **Generate**: `npx repomix`.
2.  **Research**: Grep `repomix-output.txt` for specific field names or patterns.
3.  **Verify**: Cross-reference findings with the original files.

## Rationale
- AI agents perform better with dense, localized context.
- `repomix` provides a single source of truth for the entire codebase state at a specific point in time.
- Ideal for identifying "drift" (where one stack is updated but the other is forgotten).
