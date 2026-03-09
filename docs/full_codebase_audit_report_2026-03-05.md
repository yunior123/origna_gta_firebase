# Full Codebase Audit Report (Monorepo)

Date: 2026-03-05  
Scope: `origna_gta/` (Flutter), `functions/` (Cloud Functions), shared schema/rules/docs

## Executive Summary

The payment/order stack has strong controls in several critical places (Stripe webhook signature verification, webhook idempotency, backend authoritative price checks), but there are still high-risk lifecycle inconsistencies around line-item identity and schema drift.

Top risks:
1. Item-level mutations still key by `productId` in multiple flows while backend triggers treat `cartItemId` as canonical unique identity.
2. Captured-order shipping adjustment path references undefined schema constants (`SHIPPING_DIFF_CENTS`, `TAX_DIFF_CENTS`) and can fail at runtime.
3. `cartItemId` is now operationally required in backend order triggers, but not represented in OrderItem models/schema contracts.

## Skills and Agent Coverage

### Applied skill set (audit-relevant)

| Skill | Coverage |
|---|---|
| `review-stripe-payment-flow` | Applied |
| `review-stripe-ecommerce-architecture` | Applied |
| `review-order-lifecycle-logic` | Applied |
| `review-product-lifecycle-logic` | Applied |
| `review-ecommerce-app-architecture` | Applied |
| `review-schema-design-architecture` | Applied |
| `review-firestore-model-schema-consistency` | Applied |
| `review-cloud-functions-api-contracts` | Applied |
| `review-checkout-cart-integrity` | Applied |
| `review-seller-stripe-connect-lifecycle` | Applied |
| `security-best-practices` | Applied (static secure-default checks) |
| `security-threat-model` | Applied (repo-grounded snapshot) |

### Specialized agent lenses applied

Used as checklist lenses from `.claude/agents`:
- `logic-auditor`
- `payment-auditor`
- `order-lifecycle-auditor`
- `product-lifecycle-auditor`
- `cross-stack-auditor`
- `schema-sync-checker`
- `orchestrator-agent`

### Available-but-not-executed skills

- `sentry`: blocked (`SENTRY_AUTH_TOKEN` unset)
- `speech`, `transcribe`: blocked/not relevant (`OPENAI_API_KEY` unset)
- `cloudflare-deploy`: not relevant for audit (`wrangler` missing)
- `playwright`, `screenshot`: not required for static logic/schema audit

## Quality Gates

- `flutter analyze --no-fatal-infos` (frontend): **PASS**
- `flutter test` (frontend): **FAIL** (`+170 -263`), failing on missing golden files (`goldens/*.png`)
- `pytest -q` (backend): **PASS** (`524 passed, 1 warning`)
- `python3 -m mypy main.py handlers services models` (backend): **FAIL** (`479 errors in 31 files`)

## Findings (Prioritized)

### F-001 (P1) Non-unique line-item identity across order lifecycle

**Invariant broken:** Item-level operations must target a unique order line item, not first-match by `productId`.

**Evidence**
- Backend item updates by `productId` first match:
  - `functions/handlers/orders.py:130`
  - `functions/handlers/orders.py:562`
  - `functions/handlers/orders.py:598`
  - `functions/handlers/orders.py:1921`
  - `functions/handlers/orders.py:2033`
  - `functions/handlers/orders.py:2092`
- Frontend sends `productId` for item operations:
  - `origna_gta/lib/core/repositories/order_repository.dart:32`
  - `origna_gta/lib/core/repositories/order_repository.dart:60`
  - `origna_gta/lib/features/orders/buyer_orders_viewmodel.dart:37`
  - `origna_gta/lib/screens/seller_orders_screen.dart:732`
  - `origna_gta/lib/widgets/order_widgets.dart:1499`
- But backend triggers/dedup logic treats `cartItemId` as unique:
  - `functions/handlers/orders.py:3312`
  - `functions/handlers/orders.py:3440`

**Failure mode**
- Orders with two lines of the same `productId` (variant/split scenarios) can update/refund/confirm the wrong line item.

**Recommended fix**
- Promote `cartItemId` (or explicit `orderItemId`) to canonical API identity for item-level mutations.
- Keep `"all"` sentinel for bulk seller updates, but remove productId-first-match behavior for single-item actions.

**Tests to add**
- Multi-line same `productId` order: independent ship/confirm/refund/return behavior per line.

---

### F-002 (P1) Captured shipping-adjustment path uses undefined schema constants

**Invariant broken:** Runtime write fields must exist in `Fields` constants.

**Evidence**
- Undefined constant usage:
  - `functions/handlers/orders.py:1799`
  - `functions/handlers/orders.py:1800`
- Constants missing in `Fields`:
  - `functions/schema_constants.py:666`
  - `functions/schema_constants.py:680`
- Static check confirms:
  - `handlers/orders.py:1799` and `handlers/orders.py:1800` reported by mypy (`attr-defined`)

**Failure mode**
- On captured-order shipping delta branch, code can throw `AttributeError` before discrepancy fields are recorded.

**Recommended fix**
- Add `SHIPPING_DIFF_CENTS` and `TAX_DIFF_CENTS` to `functions/schema_constants.py` and Dart mirror.
- Add these fields to schema docs and parsing layers where needed.

**Tests to add**
- `update_shipping_cost` on captured order with non-zero delta should complete and persist diff fields.

---

### F-003 (P1) Schema/model drift: `cartItemId` is operationally required but missing from OrderItem contracts

**Invariant broken:** Canonical order item identity used by runtime logic must exist in schema/model contracts.

**Evidence**
- Runtime writes and depends on `cartItemId`:
  - `functions/handlers/payment_stripe.py:895`
  - `functions/handlers/orders.py:3313`
  - `functions/handlers/orders.py:3441`
- Field constant exists:
  - `functions/schema_constants.py:669`
  - `origna_gta/lib/core/schema/schema_constants.dart:914`
- Order item models omit `cartItemId`:
  - `functions/models/order.py:49`
  - `origna_gta/lib/models/generated/order_models.dart:30`
  - `origna_gta/lib/models/generated/order_models.dart:474`
- Schema reference for `OrderItem` does not define `cartItemId`:
  - `docs/database_schema.json:989`
  - `docs/database_schema.json:3120`

**Failure mode**
- Cross-stack contracts cannot reliably reason about unique line IDs; future API changes remain brittle.

**Recommended fix**
- Add `cartItemId` (or `orderItemId`) to Python model, Dart model, and `database_schema.json` `OrderItem`.
- Migrate frontend item actions to use this identity end-to-end.

**Tests to add**
- Contract tests for serialize/deserialize preserving `cartItemId` across backend and client models.

---

### F-004 (P2) Cart quantity and row identity still keyed by `productId`, not `cartItemId`

**Evidence**
- Quantity provider aggregates by `productId`:
  - `origna_gta/lib/features/cart/cart_provider.dart:96`
  - `origna_gta/lib/features/cart/cart_provider.dart:99`
- UI watches quantity by `productId`:
  - `origna_gta/lib/screens/cartitem_screen.dart:108`
  - `origna_gta/lib/screens/cartitem_screen.dart:123`
  - `origna_gta/lib/screens/cartitem_screen.dart:143`
- Dismissible keyed by `productId`:
  - `origna_gta/lib/screens/cartitem_screen.dart:29`

**Failure mode**
- Variant rows can display combined quantities and unstable row identity behavior.

**Recommended fix**
- Key quantity state and list keys by `cartItemId`.

**Tests to add**
- Same product with 2 variants in cart: independent quantity control and row dismissal.

---

### F-005 (P2) Shipping fallback parser converts dollars->cents incorrectly (operator precedence)

**Evidence**
- `origna_gta/lib/utils/constants.dart:402`

**Failure mode**
- Non-null `price` may skip `*100` conversion in alternate schema path.

**Recommended fix**
- Change to `(((map['price'] as num?)?.toDouble() ?? 0.0) * 100).round()`.

**Tests to add**
- Alternate shipping map with `price: 12.34` yields `1234` cents.

---

### F-006 (P2) Cloud Function endpoint contract centralization drift in user repository

**Evidence**
- Hardcoded callable names and response keys in repository:
  - `origna_gta/lib/core/repositories/user_repository.dart:16`
  - `origna_gta/lib/core/repositories/user_repository.dart:27`
  - `origna_gta/lib/core/repositories/user_repository.dart:51`
  - `origna_gta/lib/core/repositories/user_repository.dart:61`
  - `origna_gta/lib/core/repositories/user_repository.dart:88`
  - `origna_gta/lib/core/repositories/user_repository.dart:101`
  - `origna_gta/lib/core/repositories/user_repository.dart:19`
  - `origna_gta/lib/core/repositories/user_repository.dart:30`
- Central endpoint class exists but does not carry these address/profile endpoints:
  - `origna_gta/lib/core/schema/schema_constants.dart:263`
  - `origna_gta/lib/core/schema/schema_constants.dart:343`

**Failure mode**
- Rename/drift risk is higher because contract is partly centralized, partly literal.

**Recommended fix**
- Move all callable endpoint names and common response keys into shared constants and typed DTO parsing.

---

### F-007 (P3) `verify_cart_prices` is deployed but not used by frontend pre-checkout flow

**Evidence**
- Function exported/deployed:
  - `functions/main.py:198`
  - `functions/main.py:292`
  - `functions/handlers/payment_stripe.py:288`
- Frontend constant exists:
  - `origna_gta/lib/core/schema/schema_constants.dart:327`
- No frontend call site found for `verify_cart_prices` in `origna_gta/lib/`.

**Failure mode**
- Users only discover stale price/availability at checkout creation time instead of a deterministic pre-check step.

**Recommended fix**
- Call `verify_cart_prices` immediately before `create_checkout_session` and surface item-level diffs.

---

### F-008 (P2) Type-safety gate is red and includes real contract/runtime hazards

**Evidence**
- `python3 -m mypy main.py handlers services models` -> `479 errors in 31 files`
- Includes high-signal hazards (example):
  - `handlers/orders.py:1799` (`Fields.SHIPPING_DIFF_CENTS` missing)
  - `handlers/orders.py:1800` (`Fields.TAX_DIFF_CENTS` missing)

**Failure mode**
- Static contract drift can slip into runtime behavior and production defects.

**Recommended fix**
- Triage by domain: payment/order/schema first, then gradual strictness for remaining modules.

---

### F-009 (P3) Frontend golden regression suite is blocked by missing baseline assets

**Evidence**
- `flutter test` ended with `+170 -263` and repeated missing golden files under `goldens/*.png`.

**Failure mode**
- UI regression detection is ineffective in CI/local verification.

**Recommended fix**
- Restore/commit deterministic golden baselines or split golden suite behind explicit opt-in target.

## Positive Controls Verified

- Stripe webhook signature verification before processing:
  - `functions/handlers/payment_stripe.py:1503`
- Stripe webhook idempotency claim via create-once event doc:
  - `functions/handlers/payment_stripe.py:1532`
  - `functions/handlers/payment_stripe.py:1538`
- Server-authoritative price validation in checkout:
  - `functions/handlers/payment_stripe.py:868`
  - `functions/handlers/payment_stripe.py:912`

## Remediation Order

1. Fix `productId`-based item mutation APIs to unique item identity (`cartItemId`/`orderItemId`) across frontend+backend.
2. Add missing `SHIPPING_DIFF_CENTS`/`TAX_DIFF_CENTS` constants and tests; update schema contracts.
3. Add `cartItemId` to OrderItem schema/models and migrate client parsing/action keys.
4. Fix cart quantity keying and shipping fallback precedence bug.
5. Re-enable golden baseline workflow and reduce mypy error budget in critical domains.

## Notes

- This report supersedes frontend-only audit framing and includes backend (`functions/`) and shared schema architecture.
