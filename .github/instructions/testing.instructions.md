---
applyTo: "e2e/**/*.ts,e2e/**/*.spec.ts,functions/tests/**/*.py,origna_gta/test/**/*.dart"
---

# Testing Context

## Test Suites
| Suite | Location | Count | Command |
|-------|----------|-------|---------|
| Backend unit | `functions/tests/` | 288+ | `cd functions && source venv/bin/activate && pytest` |
| Flutter unit | `origna_gta/test/` | — | `cd origna_gta && flutter test` |
| E2E Playwright | `e2e/*.spec.ts` | 161+ | `cd e2e && npx playwright test` |
| Dart analysis | — | — | `cd origna_gta && flutter analyze` |
| Python lint | — | — | `ruff check functions/` |

## Backend Test Files
| File | Coverage |
|------|----------|
| `test_critical_flow_scenarios.py` | End-to-end business flows |
| `test_handlers_payment_stripe.py` | Payment handler unit tests |
| `test_handlers_products_orders.py` | Product/order handler tests |
| `test_schema_consistency.py` | Python↔JSON schema sync |
| `test_webhook_security.py` | Webhook HMAC verification |

## E2E Key Specs
| File | Tests |
|------|-------|
| `fullstack-e2e.spec.ts` | 37 — Core marketplace |
| `payment-workflow-e2e.spec.ts` | 54 — Payment edge cases |
| `regression-e2e.spec.ts` | 38 — Status/schema/formula |
| `logic-failures-e2e.spec.ts` | 29 — Financial/state/permission attacks |

## Cross-Stack: When test fails, check both sides
- Dart model ↔ Python model field names match?
- Frontend request payload ↔ backend handler expected format?
- Schema constants (Dart) ↔ schema constants (Python) in sync?
