# Copilot Skills — OrignaGta

> Learned patterns & gotchas. Full history: `.claude/LEARNED.md`

---

## Search Routing

| Condition | Route |
|---|---|
| Text + Algolia available | Algolia (5s timeout → Firestore fallback) |
| Text + no Algolia | Firestore `arrayContains(keywords.first)` |
| Category only | Firestore `where(categoryId)` |
| Browse | Firestore `orderBy(createdAt)` |

Key files: `algolia_service.dart`, `algolia_product_repository.dart`, `home_viewmodel.dart`

### Emulator vs Production
Algolia NOT emulated (isAvailable=false → Firestore only). Stripe uses test keys. R2 uses `emulator/` prefix.

---

## Home Screen Pagination

- `HomeState.copyWith` uses Sentinel to distinguish "not passed" from "set to null"
- Infinite scroll guards: `isLoading || isLoadingMore` + `!isFirstLoad && !hasMore`
- Category switch resets: products, lastDocument, hasMore, isLoading
- `favoritesProvider` uses `ref.keepAlive()` to prevent blink on rebuild

---

## Payment Pipeline

```
checkout_provider → createCheckoutSession → payment_stripe.py
→ Stripe Checkout (hosted) → checkout.session.completed webhook
→ order CONFIRMED/CAPTURED → seller ships → confirm_order_receipt
→ _capture_payment_impl (idempotent) → stripe.Transfer.create()
```

- **Auto-capture** — `paymentStatus` always `'captured'`, never `'authorized'`
- 2.5% platform fee, CAD only, idempotency keys required
- `_capture_payment_impl` (undecorated) for internal calls, NOT `capture_payment`
- `source_transaction` = charge ID (`ch_xxx`), NOT PaymentIntent (`pi_xxx`)
- Refund failures → SECURITY_ALERTS + `requires_manual_review`

---

## Order Lifecycle

```
pending → confirmed → processing → shipped → in_transit → delivered
```
- Sellers CANNOT mark delivered (admin/cron only)
- Multi-seller orders: use `update_item_status`, NOT `update_order_status`
- `update_item_status` auto-promotes: all shipped → SHIPPED, all delivered → DELIVERED
- Cancel: restore stock + refund/void. Double-cancel idempotent via `STOCK_RESTORED` flag.

---

## Cross-Stack Sync

Change a field → update ALL 6 layers: `schema_constants.py` → `schema_constants.dart` → `database_schema.json` → Pydantic models → Freezed models → tests

---

## Flutter Web Semantics (Playwright E2E)

- CanvasKit renders `<canvas>` → use `<flt-semantics>` DOM tree
- Semantics force-enabled in `main.dart`
- `flutter-helpers.ts` — canonical selectors: `flutterButton()`, `flutterInput()`, etc.
- ModernButton auto-labels via `Semantics(button: true, label:)`
- ModernTextField: label is separate Text widget, field uses hintText
- Convention: `btn-*`, `input-*`, `chk-*`, `product-card-*`

---

## Key Gotchas

1. `get_server_timestamp()` CANNOT nest in arrays/ArrayUnion → use `datetime.now(timezone.utc)`
2. `signIn()` returns `{idToken, localId}` NOT `{token}`
3. Stock field: `stockQuantity` not `stock`
4. Project ID: `orignagta` (no hyphen)
5. Product needs BOTH `isActive: true` AND `status: 'active'`
6. Firestore REST PATCH needs `updateMask.fieldPaths` or replaces entire doc
7. Auth Emulator starts with 0 users — MUST seed via `mega-seed.ts`
8. Rate limiter: 100x bypass when `FUNCTIONS_EMULATOR=true`
9. `on_order_status_changed` trigger `KeyError: 'authtype'` — known Firebase SDK bug, ignore
10. Cron functions not deployed — `auto_confirm`, `expire_pending`, `archive`, `cleanup_rate_limits`

---

## File Groups (Read Together)

| Workflow | Key Files |
|---|---|
| Search | `algolia_service`, `algolia_product_repository`, `home_viewmodel`, `home_screen` |
| Checkout | `checkout_provider`, `checkout_screen`, `payment_stripe.py`, `shipping_service.py` |
| Orders | `order_repository`, `orders_viewmodel`, `orders_screen`, `handlers/orders.py` |
| Auth | `auth_repository`, `auth_viewmodel`, `login_screen`, `handlers/admin.py` |
| E2E | `api-helpers.ts` (40+ exports), `flutter-helpers.ts` (semantics selectors) |

---

## E2E Testing

- 259 tests across 11 Playwright spec files + 288 backend pytest
- **6 workers locally, 4 in CI** — configured in `e2e/playwright.config.ts`
- Override with `E2E_WORKERS=8 npx playwright test`
- Flutter UI tests use **serial mode + shared page** (load Flutter ONCE, not per-test)
- `api-helpers.ts` = canonical module. NEVER duplicate helpers.
- `flutter-helpers.ts` exports `waitForFlutter()` — NEVER duplicate locally
- `mega-seed.ts` seeds 76 users, 30 products, 8 orders
- Startup: emulators → seed → (optional) stripe listen → test
- `page.locator('canvas')` does NOT pierce Flutter Shadow DOM → use `page.evaluate()`
- Firestore trigger decorators: use `FIRESTORE_TRIGGER_OPTIONS` (no CORS), NOT `DEFAULT_OPTIONS`
- Firebase SDK bug: `firestore_fn.py` line 137 `KeyError: 'authtype'` — patched with `.get()` in venv

### Version Alignment
- **Python**: venv 3.13 = `functions/runtime.txt` (`python313`) = CI (`3.13`)
- Always keep all three in sync when upgrading

---

## Specialized AI Agents

### 🏗️ Infra Verification Agent
Validates production readiness — compares project files vs live APIs.
```bash
# Full verification (CLI + LLM)
python audit/run_hooks.py --hook infra

# Quick CLI-only check (free, no LLM cost)
python audit/scripts/verify_infra.py
python audit/scripts/verify_infra.py --domain stripe
python audit/scripts/verify_infra.py --domain firestore
python audit/scripts/verify_infra.py --domain functions
python audit/scripts/verify_infra.py --domain secrets
```
**Checks:** Cloud Functions deployed, Firestore rules/indexes, Stripe webhooks, GCP secrets, storage rules, hosting config.

### 🧪 QA Engineer Agent
AI QA specialist — coverage analysis, gap detection, framework recommendations.
```bash
# Full QA analysis (local scan + LLM)
python audit/run_hooks.py --hook qa

# Quick local scan (free, no LLM cost)
python audit/scripts/qa_scanner.py
python audit/scripts/qa_scanner.py --run-tests
python audit/scripts/qa_scanner.py --generate-plan
```
**Covers:** Test coverage metrics, untested handlers, missing critical flows, framework gaps (Patrol, Maestro, golden tests), cross-browser, accessibility.

---

*Last updated: 2026-02-11*
