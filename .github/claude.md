# .github/claude.md — AI Agent Context

> Source of truth: [`CLAUDE.md`](../CLAUDE.md). Read it before any changes.

**OrignaGta** — E-commerce marketplace, Canadian buyers, worldwide sellers.
Flutter/Riverpod + Python Cloud Functions + Firestore + Stripe Connect Express.

## Rules
- MVVM only — no business logic in screens
- Cross-stack sync mandatory (Python ↔ Dart ↔ Schema)
- No new markdown files unless explicitly asked
- Fix all compiler warnings

## Commands
```bash
./start-dev.sh                                    # Emulators + Stripe
cd functions && source venv/bin/activate && pytest # Backend tests
cd e2e && npm test                                 # E2E tests
cd origna_gta && flutter run -d chrome             # Flutter web
```
- `secret-scan.yml` — Scan for leaked secrets