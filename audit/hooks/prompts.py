"""
Shared prompt fragments for structured output.
All hooks append this to get machine-parseable findings.
"""

STRUCTURED_OUTPUT_INSTRUCTION = """

## OUTPUT FORMAT

After your detailed analysis, you MUST output a structured findings block in this EXACT format:

```json
[
  {
    "severity": "CRITICAL|HIGH|MEDIUM|LOW",
    "title": "Short title (max 80 chars)",
    "description": "Detailed explanation of the issue and why it matters",
    "file": "relative/path/to/file.py",
    "line": 42,
    "fix_suggestion": "Exact code change or clear instruction to fix this",
    "category": "security|logic|performance|consistency|maintainability|payment|auth"
  }
]
```

Rules for the JSON block:
- Include ALL findings, not just critical ones
- The `file` field must be a relative path from the project root
- The `line` field can be null if not applicable
- The `fix_suggestion` should be specific enough that a developer can implement it immediately
- Sort by severity (CRITICAL first, then HIGH, MEDIUM, LOW)
- Be precise — no vague suggestions
"""

PROJECT_CONTEXT = """
## Project Context
- **OrignaGta**: E-commerce marketplace serving Canadian buyers, with sellers worldwide (Flutter + Firebase + Stripe Connect)
- **Scale**: 100M+ users/year target
- **Architecture**: MVVM — Screens (UI only) → ViewModels → Repositories → Providers (Riverpod)
- **Backend**: Python 3.11 Cloud Functions (Flask + firebase-functions)
- **Payments**: Stripe Connect Express (direct charges, manual capture, 2.5% platform fee)
- **Database**: Cloud Firestore
- **Models**: Freezed + json_serializable (Dart) / Pydantic v2 (Python)
- **Schema sync**: schema_constants.py ↔ schema_constants.dart ↔ database_schema.json
- **Single developer project** — maintainability is critical
"""
