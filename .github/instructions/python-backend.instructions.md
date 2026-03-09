---
applyTo: "functions/**/*.py"
---

# Python Backend Context

## Architecture
- Entry: `functions/main.py` — all Cloud Functions registered here
- Handlers: `functions/handlers/` — HTTP endpoints, business logic
- Models: `functions/models/` — Pydantic v2 models
- Schema: `functions/schema_constants.py` — source of truth for field names/enums

## Critical Safety Rules
- **Idempotency** required for all payment/transfer operations (event_id dedup)
- **Validate ALL inputs server-side** — never trust frontend
- **Re-fetch prices from Firestore** — never use client-sent amounts
- **Atomic Firestore transactions** for stock operations
- **Webhook signature verification** via `stripe.Webhook.construct_event()`
- **Rate limiting** on auth endpoints (`rate_limiter.py`)
- **Canada-only buyers** — backend validates postal code + province

## Cross-Stack Sync (when changing Python models)
Update ALL: `schema_constants.py` → `schema_constants.dart` → `database_schema.json` → Pydantic models → Freezed models → tests

## Key Handlers
| Handler | Responsibility |
|---------|---------------|
| `payment_stripe.py` | Stripe checkout, capture, refund, webhooks, Connect |
| `orders.py` | Order CRUD, state transitions, stock management |
| `products.py` | Product CRUD, Algolia sync, images |
| `admin.py` | User mgmt, roles, MFA, GDPR, seller onboarding |
| `cron_jobs.py` | Auto-confirm, expired auth, archive, rate limiter cleanup |

## Testing
```bash
cd functions && source venv/bin/activate && pytest tests/ -v --tb=short
ruff check functions/
```
