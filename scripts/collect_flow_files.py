#!/usr/bin/env python3
"""
collect_flow_files.py — Copies relevant source files for each workflow
into Desktop/origna_flows/<flow_name>/ for AI review.

Rules:
  - CLAUDE.md + any learned.md/LEARNED.md variants are prepended for AI context.
  - Max 8 primary files per flow folder (+ INSTRUCTIONS.md + optional _overflow.md = 10 total).
  - Extra files are concatenated into _overflow.md.
  - Total combined content is capped at MAX_TOTAL_BYTES to respect Claude.ai's context limit.

Usage:
    python scripts/collect_flow_files.py
"""

import json
import os
import shutil
from dataclasses import asdict, dataclass
from pathlib import Path
from time import perf_counter

REPO_ROOT = Path(__file__).resolve().parent.parent
DESKTOP = Path.home() / "Desktop" / "origna_flows"
MAX_FILES_PER_FLOW = 8  # includes CLAUDE.md; +INSTRUCTIONS.md +_overflow.md = 10 total max
MAX_TOTAL_FILES_PER_FLOW = 10
# Tuned up to avoid flow truncation in high-complexity bundles; can be overridden for tighter caps.
MAX_TOTAL_BYTES = int(os.getenv("ORIGNA_FLOW_MAX_BYTES", "1500000"))

# CLAUDE.md is auto-injected into every flow as the first file
_CLAUDE = "CLAUDE.md"
_LEARNED_CANDIDATES = (
    "learned.md",
    "LEARNED.md",
    ".claude/learned.md",
    ".claude/LEARNED.md",
)


def _resolve_learned_files() -> list[str]:
    resolved_files: list[str] = []
    seen_file_ids: set[tuple[int, int]] = set()
    for rel in _LEARNED_CANDIDATES:
        src = REPO_ROOT / rel
        if not src.exists():
            continue
        # De-duplicate aliases (e.g., case-variant paths) that map to the same file.
        stat = src.stat()
        file_id = (stat.st_dev, stat.st_ino)
        if file_id in seen_file_ids:
            continue
        seen_file_ids.add(file_id)
        resolved_files.append(rel)
    return resolved_files

_COMMON_FOOTER = """
---

## 📋 Required Output Format

**Be maximally concise. Every word must save the engineer tokens, not cost them. **

For each finding, output exactly this block — nothing more:

```
[SEVERITY] file/path.ext:LINE_NUMBER
PROBLEM: one sentence — what is wrong and why it matters, backed by strong evidence.
FIX: few sentences — exact change needed (field name, method, value, logic) +  section for code snippet demonstrating the fix, propose a few approches as per claude.md.
```

Severity levels: `[CRITICAL]` · `[HIGH]` · `[MEDIUM]` · `[LOW]` · `[BONUS]`

**Rules for your response:**
- No prose intros, no summaries, no "Overall the code looks good…" filler.
- No restating the audit checklist back.
- One block per finding. Stack multiple findings with a blank line between them.
- If a finding spans multiple files, list the primary file first, then add `ALSO: file2.ext:LINE`.
- If no issues found for a checklist item, skip it entirely — do NOT write "✅ No issues".
- Use `[BONUS]` for findings outside the checklist scope.
- Line numbers are mandatory. If uncertain, give the nearest anchor (function name + offset).
- Ultrathink, make sure the proposed fixes do not contradict themselves, provide code snippets with the proposed solutions, verify that the proposed fixes are real.

**Example output:**
```
[CRITICAL] functions/handlers/payment_stripe.py:312
PROBLEM: uses client-sent `amount` instead of re-fetching price from Firestore.
FIX: replace `amount = request.data["amount"]` with Firestore lookup `product_doc.get("priceCents")`.

[HIGH] origna_gta/lib/features/checkout/checkout_provider.dart:87
PROBLEM: sellerId == buyerId check only on frontend; backend handler missing the guard.
FIX: add `if order.seller_id == order.buyer_id: raise HttpsError(...)` in create_order handler.
```

---

## 🎁 Bonus Fixes — Report ALL of Them
Spot issues beyond the checklist? Report **every single one** with `[BONUS]` — no cap, no filtering.
Do NOT stop at a handful. If you see 20 bonus issues, output all 20. Same format, same conciseness.
Examples: architectural smells, race conditions, missing indexes, N+1 queries, scalability gaps, missing null checks, anti-patterns, hardcoded values, missing error handling, inconsistent naming, performance issues, accessibility gaps, security edge cases.

---

## 📌 Project Context
- **Stack**: Flutter/Riverpod · Python Cloud Functions/Pydantic · Firestore · Stripe Connect Express · Algolia
- **Buyers**: Canada-only (backend-enforced). **Sellers**: worldwide. **Currency**: CAD only.
- **Scale**: 100M+ users/year. No migrations — schema must be correct at launch (March 2026).
- **No legacy code.** MVVM: screens = zero logic. Riverpod StateNotifier only.
- See `CLAUDE.md` for full rules and anti-patterns.

---

## 🤖 Specialized Agent Playbooks, when taking decision and verifying that the issues and bonus features or issues are correct, spawn them all to verify that the answer is correct so that all is well orchestrated.

> These are the exact patterns our specialized audit agents use. Apply ALL of them to the files in this flow.

### 🔐 Security Auditor Patterns
1. **Unauthenticated calls** — Every `@on_call` function must check `context.auth`; unauthenticated = raise `HttpsError('unauthenticated')`.
2. **Firestore rules vs handler auth** — Rules are defense-in-depth; the handler must also validate auth. A rule `allow write: if request.auth != null` is NOT enough if the handler skips UID checks.
3. **Self-purchase bypass** — `buyer_uid != seller_uid` enforced in the backend handler, NOT just frontend.
4. **Price tampering** — Backend re-fetches `priceCents` from Firestore; client-sent price NEVER trusted. Tolerance ±$0.01.
5. **Webhook HMAC** — `stripe.Webhook.construct_event()` called with raw body; webhook secret from Secret Manager, not env var.
6. **Role escalation** — Users cannot write `isAdmin=true`, `isSeller=true` to their own doc. Rules AND handler must block this.
7. **Collection-specific rules** — Verify these collections have tight rules: `stock_notifications` (owner-only), `product_questions` (seller-answer-only), `seller_metrics` (no client writes), `addresses` (owner CRUD only), `user_security` (backend-only, `allow read: if false`).
8. **Input sanitization** — User text stored in Firestore must be length-limited; no raw HTML rendered (no `HtmlWidget`, `InAppWebView` rendering user content).
9. **Session timeout** — `SessionTimeoutService` 15-minute inactivity; verify it fires on the correct user interaction events.
10. **Circuit breaker** — `CircuitBreakerConfig` thresholds; open circuit doesn't silently swallow errors visible to user.

### 💳 Payment Auditor Patterns
1. **Auto-capture** — `paymentStatus` is always `'captured'` immediately at checkout. There is NO manual capture step. Flag any code that assumes authorization-only flow.
2. **Platform fee** — Exactly 2.5% (`BusinessRules.PLATFORM_FEE_RATIO`). Verify the formula: `fee = round(total * 0.025)`. Applied to post-discount amount.
3. **`source_transaction`** — Must be charge ID (`ch_xxx`), NEVER PaymentIntent ID (`pi_xxx`). Wrong ID causes transfer failures.
4. **Idempotency keys** — Every Stripe API call (charge, refund, transfer) uses an idempotency key derived from order/event IDs.
5. **Webhook dedup** — `webhook_events` collection stores `event_id`; handler returns early if already processed.
6. **Dispute auto-reversal** — `handle_dispute_created()` must reverse all associated transfers immediately.
7. **Refund failures** — On Stripe refund failure: create `SECURITY_ALERTS` doc + set `requires_manual_review=true` on order. Never silently swallow.
8. **3DS** — `requires_action` state triggers email to buyer with payment link; order stays `pending`.
9. **CAD-only** — All Stripe amounts in CAD cents (`currency='cad'`). No other currency allowed.
10. **Stripe Connect** — `transfer_data.destination` = seller's Stripe account ID from `seller_profiles/{uid}.stripeAccountId`.

### 🔄 Cross-Stack Auditor Patterns
1. **camelCase ↔ snake_case** — Dart sends `camelCase` JSON keys; Python expects `snake_case`. Mismatch = silent `None` in Python, `null` in Dart.
2. **Error response parsing** — Frontend must handle ALL backend error codes, not just success. If backend returns `{'error': 'out_of_stock'}`, frontend must surface it.
3. **Enum parity** — Every `OrderStatus`, `ProductCondition`, `ShippingType`, etc. value must exist in BOTH `schema_constants.py` AND `schema_constants.dart` with identical string values.
4. **Money format** — All money stored as `int` cents in Firestore and Python. Dart model has `int` cents fields + computed dollar getters. Never store dollar floats.
5. **Timestamp handling** — Firestore `Timestamp` → Python `datetime` → Dart `DateTime`. Verify `.toDate()` / `.fromDate()` conversions are not lost.
6. **Optional vs required** — A field `Optional[str]` in Python must map to `String?` in Dart. Mismatches cause runtime null errors.
7. **Response format** — If backend returns `{'success': true, 'orderId': '...'}`, the Dart code must parse exactly those keys. Check for key name drift.

### 🧠 Logic Auditor Patterns
1. **Race conditions** — Two users buying the last unit simultaneously: stock decrement must use Firestore transaction (`@firestore.transaction`), not a read-then-write.
2. **State machine violations** — One-way only. Terminal states (`delivered`, `refunded`, `cancelled`) cannot transition. Check every `update_order_status` call site.
3. **Double-processing** — Cron jobs and webhooks running concurrently on the same order: idempotency check at the START of every handler.
4. **Missing null guards** — Any `doc.get('field')` in Python without a default, or `.field!` in Dart without a null check, is a crash waiting to happen.
5. **Firestore read cost** — N+1 queries (reading a doc per list item) at scale = expensive. Look for loops that call `db.collection().document().get()`.
6. **Auth state race** — `BuildContext` captured before `await`; check `mounted` after every async call before using context.
7. **Stale provider state** — `ref.read()` in build = stale data. `ref.watch()` in event handler = extra rebuilds. Both are bugs.

### 🖼️ Frontend Auditor Patterns
1. **Async provider handling** — Every `ref.watch(asyncProvider)` must use `.when(data:, loading:, error:)`. Using `.value!` crashes on null.
2. **`ref.watch` in callbacks** — `onPressed: () { ref.watch(...) }` is wrong → use `ref.read(...)` in callbacks. `ref.watch` only in `build`.
3. **Premium gate consistency** — ALL premium-gated features use the same provider. Direct `user.isPremium` checks (not the subscription stream) can be stale.
4. **`withOpacity()` DEPRECATED** — Use `Color.withValues(alpha: x)` instead. Every `withOpacity()` call is a lint warning.
5. **`EnvConfig()` not `EnvConfig.instance`** — The singleton is accessed via constructor. Wrong access pattern = null or default values.
6. **`BuildContext` after async** — Resolve `context` before `await`. After `await`, check `if (!mounted) return;`.
7. **`MaterialPageRoute` banned** — Use named routes only. Direct `MaterialPageRoute` push breaks deep links and back navigation.
8. **`CircularProgressIndicator` banned** — Use `ModernLoadingIndicator`. Raw progress indicators break the design system.
9. **`IconButton` without tooltip** — Every `IconButton` needs a `tooltip:` parameter for accessibility.
10. **Hardcoded colors** — All colors from `DesignTokens`. No `Color(0xFF...)`, no `Colors.*`.

### 📐 Schema Sync Checker Patterns
1. **6-layer sync** — `database_schema.json` → `schema_constants.py` → `schema_constants.dart` → Pydantic models → Freezed models → `firestore.rules`. All 6 must agree.
2. **No magic strings** — Field names referenced in handlers must use `SchemaConstants.fieldName`, not `'field_name'` string literals.
3. **`createdAt`/`updatedAt`** — Every Firestore document must have both timestamps. Check model definitions.
4. **Money as cents** — Any field ending in `Cents`, `Amount`, `Price`, `Fee`, `Total` must be `int` in both Python and Dart.
5. **Seller-specific fields** — Fields like `stripeAccountId`, `commissionRateBps`, `businessName` live in `seller_profiles/{uid}`, NOT in `users/{uid}`.
6. **MFA secrets** — `mfaSecret`, `mfaBackupCodes` live in `user_security/{uid}` (backend-only). `users` doc only has `mfaEnabled` bool.

### 📦 Order Lifecycle Auditor Patterns
State machine: `pending → confirmed → processing → shipped → in_transit → delivered` (+ `cancelled`, `failed`, `expired`, `refunded`, `partially_refunded`)
1. **One-way transitions** — No backward transitions. Terminal states are final.
2. **Per-transition checklist** — For each transition verify: ① handler validates it ② Firestore rules allow it ③ correct payment action fires ④ stock action fires ⑤ email sent ⑥ timestamp recorded.
3. **Sellers cannot mark delivered** — Only cron (`auto_confirm_delivery`) or admin can set `delivered`. Flag any seller-accessible path to `delivered`.
4. **Cancel = stock restore + refund/void** — Both must happen atomically. If stock restored but refund fails, order data is corrupted.
5. **`deliveryStatus` DEPRECATED** — Use `status` only. Any remaining `deliveryStatus` references are bugs.
6. **Item-level status** — `orderItem.status` must be updated alongside `order.status` for multi-item orders.

### 🔄 Order Lifecycle Auditor Patterns (cron-specific)
- **Auto-confirm** — 7 days after `shippedAt` timestamp; uses Firestore server timestamp comparison.
- **Expired authorizations** — Within 7-day Stripe window; cancels order + voids auth + restores stock.
- **Idempotency** — Cron re-run on same batch: each record checks state before acting; no double-processing.

### 💰 Premium Auditor Patterns
1. **Webhook → isPremium sync** — `checkout.session.completed` must atomically update BOTH subscription doc AND `user.isPremium`. If webhook fails mid-way, isPremium can be stale.
2. **Frontend uses stream, not cache** — `PremiumPaywallWidget` must watch `subscriptionStreamProvider` (real-time), not `user.isPremium` alone (stale cache).
3. **Client-side bypass impossible** — Backend endpoints that serve premium features must re-validate subscription status server-side; never trust `user.isPremium` from a client-sent payload.
4. **Webhook idempotency** — Duplicate `customer.subscription.updated` events must not double-flip isPremium. Check `webhook_events` dedup.
5. **Cancellation timing** — Cancellation should set `cancelAtPeriodEnd=true`; isPremium stays true until period ends, then cron flips it. Immediate revocation is a UX bug.
6. **Reactivation flow** — Reactivation must update subscription doc status → isPremium = true in the SAME transaction. A reactivated user seeing a paywall is a revenue loss.
7. **Expiry race condition** — If subscription expires exactly at checkout time, order must fail gracefully, not proceed at premium price.

### 💸 Cost Monitor Patterns
1. **Secret Manager per-invocation** — Secrets (`get_secret_*()`) must be cached in module-level globals. Re-fetching per request = $0.03/10k calls at scale.
2. **Algolia over-indexing** — Only reindex when searchable fields change (name, description, price, category). Stock-only updates must use `partial_update_object`, never full `save_object`.
3. **Stripe Tax caching** — `calculate_tax_with_stripe()` costs $0.50/call. Cache results per province + tax_code combo for the session; tax rates don't change hourly.
4. **Firestore N+1** — Any loop calling `db.collection().document().get()` per item is an N+1. Use `get_all()` batch reads.
5. **Geoapify caching** — Geocoding results must be cached on the address doc (`latitude`/`longitude` fields). Same address = same coordinates; never re-geocode.
6. **Mailjet volume** — Free tier = 200/day. Combine order confirmation + receipt into 1 email. Seller notifications should batch (daily digest) not per-event.
7. **R2 orphan cleanup** — Deleted/archived product images must be removed from Cloudflare R2. Orphaned images accumulate storage cost silently.
8. **Cloud Function memory** — Default 256MB is wasteful for lightweight handlers. Audit each function's actual peak memory and right-size.
9. **Cron job batching** — Cron handlers should process records in batches (e.g. 100 orders at a time), not one-by-one. Look for loops that call Firestore updates inside them.

### 🏆 Rival Agent Patterns
1. **Standard checkout features** — Amazon/Shopify baseline: save-for-later, quantity limits with stock validation, address autocomplete, free-shipping threshold display. Flag missing items.
2. **Order tracking UX** — Competitors show a timeline (placed → confirmed → shipped → delivered). Our order detail must have equivalent visual status timeline.
3. **Seller trust signals** — eBay/Etsy: verified seller badge, response rate, avg ship time, positive feedback %. Flag if seller profile page lacks these.
4. **Abandoned cart** — Shopify/Amazon send reminder after 1h + 24h. Check if we have any abandoned cart recovery (email or push).
5. **Product discovery** — Competitors show "Customers also bought" / "Similar items". Flag if product detail page lacks recommendations.
6. **Review system completeness** — Amazon standard: star histogram, photo reviews, verified purchase badge, sort by helpful/recent. Flag missing components.
7. **Buyer protection visibility** — AliExpress/eBay prominently show buyer protection policy at checkout. Flag if we don't surface our dispute/refund policy before payment.
8. **Mobile-first friction** — Temu/Shein optimize for <3 taps to checkout. Count taps from product detail → order confirmed; flag if >5.
9. **Price anchoring** — Compare-at price (strikethrough) shown on product card/detail. Flag if `comparePriceCents` field exists but isn't displayed.
10. **Wishlist / Save for later** — Every major platform has this. Flag if missing or incomplete.

### 🎨 UI/UX Expert Patterns
1. **DesignTokens only** — No `Color(0xFF...)`, no `Colors.*`, no `withOpacity()`. Every visual property from `DesignTokens`. `withOpacity()` → `Color.withValues(alpha:)`.
2. **Loading = shimmer** — `CircularProgressIndicator` banned. Use `ShimmerLoading` for async content. `ModernLoadingIndicator` for page-level loads.
3. **8pt spacing grid** — All padding/margin must be multiples of 4 (preferably 8). Misaligned spacing breaks visual rhythm.
4. **Staggered list entrance** — Lists loaded async must use `StaggeredList` or `AnimatedListItem`. Content appearing instantly without animation feels cheap.
5. **Empty states designed** — Every list/collection that can be empty must have: icon + message + CTA (e.g. "No orders yet → Start Shopping"). Raw empty list = unfinished.
6. **`MaterialPageRoute` banned** — Use `SlidePageRoute` / named routes. Raw `MaterialPageRoute` breaks deep links and looks dated.
7. **`IconButton` needs tooltip** — Every `IconButton` must have `tooltip:` for accessibility AND to appear in screen reader audits.
8. **Responsive at 4 breakpoints** — 320px / 480px / 768px / 1024px+. Use `ResponsiveLayout` widget. Fixed-width containers that overflow on mobile are CRITICAL.
9. **Glass effects placement** — `GlassAppBar`, `GlassCard` for nav/floating elements only. Never wrap body text or list items in glass — it kills readability.
10. **Semantic labels on images** — Every `Image` must be wrapped in `Semantics(label: '...')`. Decorative images use `ExcludeSemantics`.
"""

# ── Per-flow audit instructions ─────────────────────────────────────────────
FLOW_INSTRUCTIONS: dict[str, str] = {
    "checkout_payment": """\
# Audit: Checkout & Payment Flow

## What to Audit
1. **Price integrity** — backend must re-fetch prices from Firestore; never trust client-sent amounts (±$0.01 tolerance).
2. **Idempotency** — every payment/capture/transfer operation must be idempotent (check event_id dedup, Stripe idempotency keys).
3. **Self-purchase prevention** — `sellerId != buyerId` enforced server-side, not just frontend.
4. **Stripe Connect** — verify `source_transaction` uses charge ID (`ch_xxx`), NOT PaymentIntent (`pi_xxx`).
5. **Authorization → Capture window** — 7-day window respected; expired authorizations handled.
6. **Platform fee** — 2.5% fee calculation (`BusinessRules.PLATFORM_FEE_RATIO`) applied correctly.
7. **Canada-only buyers** — postal code + province validated server-side at checkout.
8. **Race conditions** — concurrent checkout for same product/stock; stock decrement atomicity.
9. **Error paths** — payment failure, partial capture failure, Stripe webhook delivery failure.
10. **Cart → Order transition** — cart cleared atomically after order creation; no double-orders.
""",

    "order_lifecycle": """\
# Audit: Order Lifecycle & State Machine

## What to Audit
1. **State machine completeness** — all valid transitions covered; invalid transitions rejected.
2. **Cron timing** — auto-confirm window correct; expired authorizations voided on schedule.
3. **Idempotency** — status update handlers safe to replay (webhook retries, duplicate events).
4. **Shipping approval** — seller approval step cannot be bypassed; buyer cannot mark shipped.
5. **Capture timing** — capture only triggered after seller marks shipped + approval window.
6. **Refund correctness** — full/partial refund amounts, platform fee reversal, seller payout reversal.
7. **Email triggers** — correct email sent at each status transition; no duplicate sends.
8. **Stock restoration** — stock returned to correct warehouse on cancellation/return.
9. **Cross-stack sync** — OrderStatus enums identical in Dart, Python, and schema_constants.
10. **Dispute handling** — `handle_dispute_created()` reverses transfers correctly.
""",

    "product_lifecycle": """\
# Audit: Product Lifecycle (CRUD + Algolia)

## What to Audit
1. **SKU deduplication** — `sellerId + sellerSku` uniqueness enforced at repo layer AND via trigger.
2. **Algolia sync** — product indexed/updated/deleted in Algolia atomically with Firestore write.
3. **Stock management** — `stockQuantity` = sum of all warehouse quantities; atomic decrement.
4. **Warehouse assignment** — products require either `sellerAddress` OR `warehouseIds`; both/neither = invalid.
5. **Image upload** — R2 upload permissions, orphan image cleanup on product delete.
6. **`isActive` flag** — correctly toggled; inactive products excluded from search results.
7. **Seller authorization** — seller can only edit/delete their own products.
8. **`shipFromCity/Province/Country`** — correctly denormalized from primary warehouse at write time.
9. **Cross-stack field names** — Product model fields identical across Dart/Python/JSON schema.
10. **Price validation** — price bounds, currency (CAD only), no negative values.
""",

    "add_product": """\
# Audit: Add Product Flow

## What to Audit
1. **Warehouse vs. address logic** — if `selectedWarehouseIds` non-empty → `useWarehouses=true`, `sellerAddress=null`, `stockQuantity=sum(warehouseStockMap)`.
2. **Form validation** — required fields enforced before submission; no silent failures.
3. **SKU uniqueness check** — pre-write query throws before Firestore write; trigger as safety net.
4. **Image upload sequencing** — images uploaded before product doc written; partial upload handled.
5. **Algolia indexing** — product indexed immediately after creation with correct fields.
6. **State management** — `AddProductState` reset correctly on success/cancel; no stale state.
7. **Backend validation** — all frontend validation duplicated server-side.
8. **`shipFromCity/Province/Country`** — denormalized correctly from primary warehouse.
9. **Error UX** — all error states surfaced to user; no silent swallowed exceptions.
10. **Category/condition enums** — only valid schema constant values accepted.
""",

    "auth_seller_onboarding": """\
# Audit: Auth & Seller Onboarding

## What to Audit
1. **Rate limiting** — login/signup endpoints rate-limited; `RELAXED_RATE_LIMITS` only for dev/emulator.
2. **User doc creation** — only via `create_user_profile` CF (idempotent); no direct client Firestore writes.
3. **Stripe Connect Express** — onboarding URL generated correctly; account status polled safely.
4. **Seller role assignment** — `isSeller` flag set only after Stripe onboarding complete; not self-assignable.
5. **MFA** — secrets stored in `user_security/{uid}` (backend-only); `users` doc has only `mfaEnabled` flag.
6. **Consent capture** — `ConsentMethodValues` stored at signup; CASL/PIPEDA compliance.
7. **Auth state** — `AuthWrapper` correctly redirects based on auth + onboarding state.
8. **Admin role** — cannot be self-assigned; only assigned by existing admin.
9. **Session timeout** — expired sessions handled gracefully.
10. **Seller profile isolation** — seller fields in `seller_profiles/{uid}`, not `users` doc.
""",

    "email_notifications": """\
# Audit: Email Notifications

## What to Audit
1. **Trigger correctness** — every order status transition triggers the right email to the right recipient.
2. **Duplicate send prevention** — emails not sent twice on webhook retry or cron re-run.
3. **Template accuracy** — order totals, shipping info, and links in email templates are correct.
4. **Seller vs. buyer routing** — correct email address used for each; no cross-user leakage.
5. **CASL compliance** — transactional emails compliant; no marketing emails without consent.
6. **Failure handling** — Mailjet failure logged; order not rolled back due to email failure.
7. **Language support** — email language respects user `language` preference (`en`/`fr`).
8. **Refund/dispute emails** — triggered correctly with accurate amounts.
9. **Cron-triggered emails** — auto-confirm and expiry emails sent exactly once.
10. **No PII leakage** — emails do not expose sensitive data (payment details, raw IDs).
""",

    "cron_jobs": """\
# Audit: Cron Jobs

## What to Audit
1. **Idempotency** — every cron handler safe to run multiple times without side effects.
2. **Auto-confirm timing** — confirmation window correct; no premature or missed confirmations.
3. **Expired authorization voiding** — Stripe auth cancellation triggered within 7-day window.
4. **Rate limiter cleanup** — stale rate limit records purged without affecting active limits.
5. **Archive logic** — old orders archived at correct age; no active orders archived.
6. **Error isolation** — one failing record does not abort the entire cron batch.
7. **Concurrency** — cron does not conflict with real-time order updates (Firestore transactions).
8. **Logging** — each cron run logged with count of affected records.
9. **Backfill safety** — cron re-run after downtime does not double-process records.
10. **Stock restoration** — expired/cancelled orders restore stock to correct warehouse.
""",

    "search_discovery": """\
# Audit: Search & Discovery

## What to Audit
1. **Algolia index freshness** — product updates reflected in index within acceptable latency.
2. **Inactive product filtering** — `isActive=false` products excluded from all search results.
3. **Canada buyer filtering** — products not shippable to Canada hidden from buyer search.
4. **Relevance config** — searchable attributes, ranking, and facets correctly configured per environment.
5. **Index environment isolation** — emulator/dev/staging/prod use separate Algolia indices.
6. **Algolia API key scoping** — search key has no write permissions; write key server-side only.
7. **Product card data** — `shipFromCity/Province/Country` + smart multi-location label displayed correctly.
8. **Pagination** — infinite scroll / pagination handles empty pages and end-of-results correctly.
9. **Race condition** — product deleted from Firestore but still in Algolia index = handled gracefully.
10. **Search on product delete** — Algolia record deleted synchronously when product removed.
""",

    "security": """\
# Audit: Security

## What to Audit
1. **Firestore rules** — every collection has correct read/write rules; no wildcards granting unintended access.
2. **Unauthenticated access** — no authenticated data accessible without valid Firebase token.
3. **Rate limiting** — all sensitive endpoints protected; limits per IP + UID.
4. **Input sanitization** — all user input sanitized server-side; no XSS/injection vectors.
5. **Self-purchase bypass** — `sellerId != buyerId` enforced; cannot be bypassed via API.
6. **Price tampering** — client-sent price ignored; backend re-fetches from Firestore.
7. **Role escalation** — users cannot self-assign `admin` or `seller` roles.
8. **Webhook HMAC** — Stripe webhook signature verified before processing; raw body used.
9. **Storage rules** — R2/Cloud Storage rules restrict access to owner only.
10. **Admin collection access** — `user_security`, `webhook_events`, `rate_limits` inaccessible to clients.
""",

    "schema_consistency": """\
# Audit: Schema Consistency (6-Layer Sync)

## What to Audit
1. **Field name parity** — every field in `schema_constants.py` has exact match in `schema_constants.dart`.
2. **Enum value parity** — all enum values identical across Python, Dart, and JSON schemas.
3. **Collection name parity** — `Collections.*` constants identical across Python and Dart.
4. **Pydantic ↔ Freezed parity** — every Pydantic model field has corresponding Freezed field with same name/type.
5. **JSON schema completeness** — `docs/json_schemas/individual/` schemas cover all fields in models.
6. **`database_schema.json`** — top-level schema matches actual Firestore structure.
7. **Money fields** — all money stored as cents (`int`); no dollar floats in any model or schema.
8. **Timestamp fields** — `createdAt`/`updatedAt` present on all documents; correct Firestore Timestamp type.
9. **Optional vs required** — nullable fields consistent across Dart (`?`) and Python (`Optional`).
10. **No magic strings** — no hardcoded field names in handlers; all reference schema constants.
""",

    "seller_profile_warehouses": """\
# Audit: Seller Profile & Warehouses

## What to Audit
1. **Seller profile isolation** — seller-specific fields in `seller_profiles/{uid}`; `users` doc has only `isSeller` flag.
2. **Warehouse sub-collection** — warehouses at `users/{sellerId}/warehouses/{warehouseId}`; correct access rules.
3. **Default warehouse** — exactly one warehouse can be `isDefault=true` per seller; enforced atomically.
4. **Commission basis points** — `commissionRateBps` stored correctly (250 = 2.50%); never stored as float.
5. **Stripe Connect status** — `payoutsEnabled` flag synced from Stripe account status.
6. **Seller cannot sell without onboarding** — products cannot be listed until Stripe onboarding complete.
7. **Warehouse deletion** — cannot delete warehouse assigned to active products; reassignment required.
8. **`shipFromCountries`** — deduped list of countries across all warehouse IDs updated on warehouse change.
9. **Address validation** — warehouse address must be valid; country/province fields required.
10. **Firestore rules** — sellers can only read/write their own `seller_profiles` and `warehouses`.
""",

    "subscription_premium": """\
# Audit: Subscription & Premium Features

## What to Audit
1. **`isPremium` cache consistency** — Firestore `isPremium` flag synced from Stripe subscription status webhook.
2. **Paywall bypass prevention** — premium features gated server-side, not just frontend `isPremium` check.
3. **Subscription expiry** — expired subscriptions downgrade access correctly; no grace period exploit.
4. **Reactivation flow** — cancelled → reactivated subscription restores access atomically.
5. **Stripe webhook dedup** — `customer.subscription.*` events deduplicated via `webhook_events` collection.
6. **Cancel at period end** — cancellation defers until end of billing period; access not immediately revoked.
7. **Cron cleanup** — expired subscriptions identified and flagged by cron; no stale `isPremium=true`.
8. **Seller vs buyer premium** — correct premium tier applied per user role.
9. **Paywall widget** — `PremiumPaywallWidget` correctly shown/hidden based on subscription state.
10. **No double charge** — resubscription flow does not charge twice for overlapping periods.
""",

    "chat_messaging": """\
# Audit: Chat & Messaging

## What to Audit
1. **Access control** — only the buyer and seller of an order can access their chat thread; no cross-user read.
2. **Firestore rules** — chat documents unreadable by third parties including admins (unless flagged).
3. **Message ordering** — messages ordered by server timestamp, not client timestamp (prevents reordering).
4. **Spam prevention** — rate limiting on message sends; no flood attacks.
5. **File/image attachments** — if supported, attachment URLs scoped to chat participants only.
6. **Notification trigger** — new message triggers push/in-app notification to recipient only.
7. **Thread creation** — chat thread created only after order exists; no orphan threads.
8. **Message persistence** — messages not deletable by sender after delivery (dispute evidence).
9. **Blocked users** — if blocking supported, messages from blocked users not delivered.
10. **PII in messages** — no sensitive data (payment info, addresses) exposed via chat API.
""",

    "return_requests": """\
# Audit: Return Requests

## What to Audit
1. **Return state machine** — all valid transitions; invalid transitions (e.g., approve already-rejected) blocked.
2. **Return window** — return request only allowed within policy window after delivery confirmation.
3. **Refund calculation** — refund amount correct (order total minus platform fee); no under/over-refund.
4. **Stock restoration** — stock restored to correct warehouse only after return physically confirmed.
5. **Seller authorization** — only the seller of the order can approve/reject the return.
6. **Buyer authorization** — only the buyer can initiate a return for their own order.
7. **Stripe refund idempotency** — refund not issued twice on webhook retry.
8. **Email triggers** — buyer notified on approval/rejection; seller notified on new return request.
9. **Cross-stack model parity** — `ReturnRequest` fields identical in Dart and Python models.
10. **Dispute escalation** — unresolved returns escalate correctly; admin intervention path exists.
""",

    "admin_panel": """\
# Audit: Admin Panel

## What to Audit
1. **Role enforcement** — every admin endpoint validates `admin` role server-side; not just UI gating.
2. **Audit logging** — all admin actions (ban, refund, role change) logged with actor UID + timestamp.
3. **User ban** — banned user cannot authenticate; active sessions invalidated.
4. **Product moderation** — admin can deactivate any product; seller notified.
5. **Order intervention** — admin can force-cancel/refund orders; idempotency maintained.
6. **Seller verification** — seller approval flow cannot be self-bypassed.
7. **Payment provider management** — `payment_providers` collection write-protected; admin-only.
8. **Security tab** — security alerts surfaced correctly; `requires_manual_review` flag actionable.
9. **Data export / GDPR** — GDPR delete request handled correctly; all user data purged.
10. **Admin self-protection** — admin cannot demote themselves or delete their own account via panel.
""",

    "profile_address": """\
# Audit: Profile & Address Management

## What to Audit
1. **Canada-only validation** — buyer shipping addresses must be in Canada; non-CA addresses rejected server-side.
2. **Address format** — postal code format validated (A1A 1A1); province code in allowed list.
3. **Default address** — exactly one address can be default; setting new default atomically clears old one.
4. **Address deletion** — cannot delete address used in an active/pending order.
5. **Profile update authorization** — users can only update their own profile.
6. **Sensitive field protection** — email/UID not updatable via profile update endpoint.
7. **`users` doc vs `seller_profiles`** — profile update does not accidentally overwrite seller-only fields.
8. **Consent update** — language preference and marketing consent updates stored with `consentMethod`.
9. **Cross-stack field names** — `Address` model fields identical in Dart and Python; no collision with legacy `models.dart`.
10. **Geoapify integration** — address autocomplete does not expose API key client-side.
""",

    "notifications": """\
# Audit: Notifications

## What to Audit
1. **Notification deduplication** — same event does not trigger duplicate notifications.
2. **Recipient targeting** — notification sent to correct user (buyer vs seller) for each event type.
3. **Push token management** — stale/invalid FCM tokens removed; no errors on send to invalid token.
4. **In-app notification state** — read/unread state persisted correctly per user.
5. **Permission gating** — notifications only sent to users who granted permission.
6. **Order event coverage** — all order status transitions trigger appropriate notification.
7. **Rate limiting** — notification floods prevented; per-user notification throttling.
8. **Firestore rules** — users can only read their own notifications; cannot write notification docs directly.
9. **Notification on admin action** — seller notified when product deactivated by admin.
10. **Silent data messages vs display messages** — correct notification type used for background vs foreground.
""",

    "digital_products": """\
# Audit: Digital Products

## What to Audit
1. **Download access control** — download URL only accessible after payment captured; not at authorization.
2. **URL expiry** — signed download URLs expire; cannot be shared after expiry.
3. **Delivery trigger** — digital delivery triggered by correct order status (captured, not just authorized).
4. **No physical shipping** — digital products must not trigger shipping flow or shipping cost calculation.
5. **Stock management** — digital products: unlimited stock (or no stock decrement); no warehouse assignment.
6. **Refund policy** — digital product refund rules enforced (e.g., no refund after download).
7. **File storage security** — digital files in R2 with access restricted to buyer post-purchase only.
8. **Order model** — `isDigital` flag correctly set and used in order handling across stack.
9. **Algolia indexing** — digital products correctly tagged; filterable by type in search.
10. **Cross-stack parity** — digital product fields consistent in Dart/Python/schema.
""",

    "coupons_discounts": """\
# Audit: Coupons & Discounts

## What to Audit
1. **Server-side validation** — coupon code validated backend; client-computed discount never trusted.
2. **Usage limits** — per-coupon and per-user usage limits enforced atomically (no race condition double-use).
3. **Expiry enforcement** — expired coupons rejected server-side; not just UI check.
4. **Discount calculation** — percentage vs fixed discount applied correctly; floor at $0 (no negative totals).
5. **Stacking prevention** — multiple coupons cannot be stacked unless explicitly allowed.
6. **Seller-scoped coupons** — coupon only valid for the seller's products if scoped; not cross-seller.
7. **Cart update on removal** — removing coupon from cart recalculates totals atomically.
8. **Stripe integration** — discount reflected correctly in Stripe PaymentIntent amount.
9. **Audit trail** — coupon usage recorded per order for fraud detection.
10. **Platform fee on discounted price** — platform fee calculated on post-discount amount, not original price.
""",

    "product_qa_ratings": """\
# Audit: Product Q&A & Ratings

## What to Audit
1. **Rating eligibility** — only buyers who completed a purchase (order captured) can rate a product.
2. **One rating per order** — buyer cannot submit multiple ratings for the same order/product.
3. **Rating manipulation** — seller cannot rate their own product; admin cannot inflate ratings.
4. **Average recalculation** — product average rating updated atomically on new rating submission.
5. **Q&A authorization** — anyone can ask; only the seller of that product can officially answer.
6. **Moderation** — admin can remove abusive Q&A entries; seller cannot delete buyer questions.
7. **Firestore rules** — ratings/Q&A documents writable only by eligible users.
8. **Cross-stack parity** — `Ratings` model fields identical in Dart/Python/JSON schema.
9. **Algolia sync** — average rating indexed in Algolia for sort-by-rating feature.
10. **Review content safety** — no PII or payment info in review text; length limits enforced.
""",

    "favorites_seller_products": """\
# Audit: Favorites & Seller Product Listing

## What to Audit
1. **Favorites ownership** — users can only read/write their own favorites; no cross-user access.
2. **Deleted product in favorites** — favorited product deleted by seller handled gracefully (no crash, stale entry cleaned).
3. **Inactive product filtering** — inactive/suspended products excluded from seller product listing and favorites.
4. **Seller product authorization** — seller can only see/manage their own products in seller panel.
5. **Favorites count** — if favorites count stored on product, updated atomically; not trusted from client.
6. **Pagination** — both favorites and seller product list paginate correctly; no N+1 queries.
7. **Algolia vs Firestore** — seller product list reads from Firestore (authoritative); search uses Algolia.
8. **Firestore rules** — `favorites` sub-collection restricted to owner; no public read.
9. **Product card data** — all required fields present for card rendering; no null crashes.
10. **Remove from favorites on product delete** — orphan favorites cleaned up on product deletion.
""",

    "app_bootstrap": """\
# Audit: App Bootstrap & Configuration

## What to Audit
1. **Environment detection** — correct Firebase project, Algolia index, and R2 prefix per environment (emulator/dev/staging/prod).
2. **Route guards** — `authwrapper_screen` correctly routes unauthenticated, unverified, and authenticated users.
3. **Provider initialization** — Riverpod providers initialized in correct order; no uninitialized access at startup.
4. **Session timeout** — 15-minute inactivity timeout fires correctly; auth state cleaned up on sign-out.
5. **Analytics** — events logged without PII; analytics disabled in emulator/dev.
6. **Cloud Function registration** — all handlers registered in `main.py`; no orphan functions.
7. **Config secrets** — no API keys or secrets hardcoded in frontend; all from `--dart-define` or CF environment.
8. **Function options** — memory/timeout/region set correctly per handler sensitivity; payment handlers have higher timeout.
9. **Deferred widgets** — deferred loading does not block critical path screens.
10. **CORS** — backend CORS config includes all hosting domains; no missing origin.
""",

    "legal_compliance": """\
# Audit: Legal & Compliance (PIPEDA, CASL, Quebec Law 25, Bill 96)

## What to Audit
1. **CASL consent** — marketing emails require explicit opt-in; `consentMethod` stored at signup.
2. **PIPEDA / Quebec Law 25** — privacy policy accessible; granular consent collected; user data deletion path exists.
3. **Bill 96 (Quebec)** — French language available for all consumer-facing content; `language` preference respected.
4. **Terms acceptance** — terms/privacy acceptance recorded with version + timestamp before checkout.
5. **Physical address on emails** — all outbound emails include sender's physical address + unsubscribe link.
6. **Terms screen accuracy** — displayed terms text matches actual stored version; no stale cached content.
7. **Unsubscribe flow** — `unsubscribe` link in email leads to functional opt-out; preference persisted in Firestore.
8. **Language selector** — language switch updates `language` field in user doc and email preferences.
9. **Privacy policy screen** — loads current policy; version displayed; no hardcoded old text.
10. **Minor protection** — no mechanism for minors to register; age confirmation at signup if required.
""",

    "design_system": """\
# Audit: Design System & UI Components

## What to Audit
1. **No hardcoded colors** — zero `Color(0x...)` or named colors outside `DesignTokens`; no `withOpacity()` usage.
2. **Modern widget consistency** — all buttons use `ModernButton`, all inputs use `ModernTextField`; no raw `ElevatedButton`/`TextField`.
3. **Loading states** — all async operations use `ModernLoadingIndicator`; no raw `CircularProgressIndicator`.
4. **Glassmorphism correctness** — blur, opacity, and border values from `glassmorphism.dart` constants; not hardcoded.
5. **Responsive layout** — `ResponsiveLayout` breakpoints used for all multi-column layouts; no magic pixel values.
6. **Animation performance** — animations use `RepaintBoundary`; no janky rebuild-heavy animations.
7. **Accessibility** — all interactive widgets have `tooltip` or `Semantics` label; contrast ratios meet WCAG AA.
8. **AppBar consistency** — `ModernAppBar`/`CustomAppBar` used everywhere; no raw `AppBar`.
9. **Mascot integration** — mascot provider correctly scoped; no memory leaks from animation controllers.
10. **Deferred widget** — deferred loading fallback shown correctly; no blank flash or null errors.
""",

    "stock_notifications": """\
# Audit: Stock Notifications & Product Variants

## What to Audit
1. **Notify-me eligibility** — stock notification only registered when product is genuinely out of stock; no false triggers.
2. **Duplicate registration prevention** — user cannot register the same product twice for stock alerts.
3. **Notification send timing** — alert sent when stock restored to > 0; not on partial restock below threshold.
4. **Variant stock isolation** — notifications scoped to correct variant (size/color); not fired for unrelated variants.
5. **Firestore rules** — `stock_notifications` collection writable only by authenticated buyer; readable only by owner + admin.
6. **Cleanup on purchase** — stock notification entry removed after buyer purchases the notified product.
7. **Cleanup on product delete** — orphan notifications cleaned up when product deleted.
8. **Variant model parity** — `variant_models.dart` fields consistent with Python product model variant structure.
9. **Stock decrement atomicity** — variant stock decremented atomically on purchase; no race condition oversell.
10. **Email trigger** — stock notification email template includes correct product/variant info and direct link.
""",

    "supplier_integration": """\
# Audit: Supplier Integration & Platform Config

## What to Audit
1. **CAD-only selling price** — supplier cost currencies are internal only; all listed prices forced to CAD.
2. **Supplier config extensibility** — new supplier can be added to `supplierPlatforms` map without code changes.
3. **No supplier API keys in frontend** — all external supplier API calls go through backend; keys not in Dart code.
4. **Product import flow** — imported supplier product data mapped correctly to `Product` model fields.
5. **Delivery day estimates** — `minDeliveryDays`/`maxDeliveryDays` from supplier config propagate to shipping display.
6. **Supplier deactivation** — deactivating a supplier platform hides its products from search gracefully.
7. **Cross-stack supplier field names** — supplier fields consistent in Dart config, Python model, and Firestore schema.
8. **Image import** — supplier product images imported to R2 with correct env prefix; original URLs not stored publicly.
9. **SKU collision prevention** — imported products use `sellerSku = supplierSku`; dedup enforced across imports.
10. **Seller authorization** — seller can only import products for their own account; no cross-seller imports.
""",

    "logic_audit": """\
# Audit: Logic & Business Rules (Full Stack)

## What to Audit
1. **Race conditions** — concurrent stock reservation, coupon redemption, and payment capture all use atomic Firestore transactions.
2. **State machine violations** — order and payment status transitions follow valid paths; no skipped states.
3. **Idempotency** — all payment and transfer operations are idempotent; duplicate events don't double-process.
4. **Authorization checks** — every handler validates the caller is the correct role (buyer, seller, admin) for the operation.
5. **Price integrity** — backend re-fetches product price from Firestore; never trusts client-sent amounts.
6. **Self-purchase prevention** — `sellerId != buyerId` enforced in all purchase paths.
7. **Stock consistency** — `stockQuantity` at product level equals sum of all warehouse inventory levels.
8. **Cross-stack field parity** — Dart models and Python models have identical field names and types.
9. **Cron job isolation** — one failing record in a batch does not abort the rest; errors logged per record.
10. **Error propagation** — errors returned to caller with correct HTTP status; no silent failures that leave data in inconsistent state.
""",

    "cross_stack_audit": """\
# Audit: Cross-Stack Frontend ↔ Backend Boundary

## What to Audit
1. **Request payload format** — frontend sends exactly the fields the backend handler expects; no extra or missing fields.
2. **Field name consistency** — every field name in Dart models matches its Python model counterpart (camelCase vs snake_case mapping correct).
3. **Enum value consistency** — all enum values in `schema_constants.dart` exactly match `schema_constants.py`; no stale values.
4. **Response parsing** — Dart `fromJson`/`fromFirestore` factories handle all fields the backend writes; no unhandled nulls.
5. **Error contract** — backend error response shape matches what frontend error handlers expect.
6. **Auth token forwarding** — frontend sends Firebase ID token; backend verifies it before any operation.
7. **Timestamp handling** — Firestore `Timestamp` correctly converted on both sides; no epoch/millisecond mismatches.
8. **Collection path constants** — Dart `CollectionPaths` and Python collection name strings match exactly.
9. **Model version drift** — no field added to Python model but missing from Dart model or vice versa.
10. **Null safety** — optional fields marked as nullable on both sides; no forced non-null on potentially missing fields.
""",

    "frontend_audit": """\
# Audit: Frontend Riverpod Providers & ViewModels

## What to Audit
1. **ref.watch vs ref.read** — `ref.watch` used in build methods; `ref.read` used in callbacks and event handlers only.
2. **Error state coverage** — every async provider exposes error state; screens show meaningful error UI, not blank or crash.
3. **Loading state coverage** — every async operation shows loading indicator; no silent pending states.
4. **Premium gate consistency** — all premium features guarded by `isPremium` check before display AND before action.
5. **BuildContext async safety** — no `BuildContext` passed to async methods; context resolved before any `await`.
6. **Provider disposal** — providers that allocate resources (streams, timers) implement `onDispose` or `AutoDispose`.
7. **State reset** — viewmodel state reset when navigating away from forms; no stale data on re-entry.
8. **Deferred UI readiness** — deferred features check backend readiness flag before enabling UI; no premature access.
9. **Navigation guard** — unauthenticated users redirected before accessing protected screens; no flash of protected content.
10. **No business logic in screens** — screens delegate all logic to viewmodels; no direct Firestore/API calls from screen widgets.
""",

    "performance_audit": """\
# Audit: Performance & Query Efficiency

## What to Audit
1. **N+1 Firestore reads** — list screens batch-fetch documents; no per-item individual reads in loops.
2. **Unbounded queries** — all Firestore queries have `.limit()` applied; no collection scans.
3. **Missing indexes** — `firestore.indexes.json` covers all compound queries used in handlers; no missing composite index.
4. **Algolia call frequency** — Algolia sync calls batched on product update; no per-field individual updates.
5. **Cloud Function cold start** — heavy imports moved to module level; no top-level I/O blocking initialization.
6. **Flutter widget rebuilds** — widgets consuming providers are narrowly scoped; no full-tree rebuilds on partial state changes.
7. **ListView optimization** — all long lists use `ListView.builder`; no `ListView(children:)` with large arrays.
8. **Image caching** — product images use `cached_network_image` with `cacheWidth`/`cacheHeight`; no full-res decode.
9. **Provider over-watching** — `select()` used when only a subset of provider state is needed by a widget.
10. **Firestore pagination** — cursor-based pagination (`startAfterDocument`) used for all list endpoints; no offset pagination.
""",

    "refactor_audit": """\
# Audit: Code Quality & Refactoring Opportunities

## What to Audit
1. **Code duplication** — logic repeated across handlers or viewmodels should be extracted to shared utilities or base classes.
2. **Dead code** — unused functions, commented-out blocks, and unreachable branches should be removed.
3. **Oversized functions** — functions exceeding 80 lines should be decomposed into smaller, named helpers.
4. **Magic strings** — hardcoded field names, collection names, or status values should reference `schema_constants`.
5. **Wrong abstraction layer** — business logic in screens, UI logic in viewmodels, or data access in handlers are architectural violations.
6. **Inconsistent error handling** — mix of try/catch and uncaught exceptions; error handling should follow a consistent pattern.
7. **Coupling** — tight coupling between unrelated modules; introduce interfaces or repository patterns where needed.
8. **Test coverage gaps** — critical paths (payment, order state transitions) without corresponding test coverage.
9. **Naming inconsistency** — function/variable names that don't follow project conventions (camelCase Dart, snake_case Python).
10. **TODOs and FIXMEs** — outstanding TODO comments that represent known bugs or deferred work should be triaged.
""",

    "cost_audit": """\
# Audit: API & Infrastructure Cost Efficiency

## What to Audit
1. **Algolia search calls** — search called only on user interaction (debounced); no polling or on-every-keystroke calls.
2. **Algolia index writes** — product sync batched; no per-field individual index updates; inactive products deleted from index not just filtered.
3. **Email send rate** — email service not called redundantly; order status change emails deduplicated via event_id.
4. **Firestore read efficiency** — projections used where full documents are not needed; `select()` on large documents.
5. **Cloud Function invocations** — cron jobs check for work before doing heavy processing; early exit on empty batches.
6. **Stripe API calls** — no redundant PaymentIntent retrievals; cached where safe within a single request.
7. **R2/Cloudflare storage** — temporary images cleaned up on product deletion; no orphaned blobs.
8. **Memory allocation** — Cloud Functions memory allocation matches actual peak usage; no over-provisioned functions.
9. **Shipping service calls** — shipping cost calculation cached per session; not recalculated on every page load.
10. **Subscription polling** — premium status checked from cached Firestore field; no Stripe API call on every auth check.
""",

    "code_comments_audit": """\
# Audit: Code Comments & Documentation Quality

## What to Audit
1. **Stale TODO comments** — TODOs referencing known fixes that have since been implemented should be removed.
2. **Missing docstrings** — public functions, classes, and methods in both Python and Dart lack docstrings; add them.
3. **Misleading comments** — comments that describe what the code does (not why) or that contradict the actual logic.
4. **Complex logic explanation** — non-obvious algorithms (fee calculation, state machine transitions, retry logic) need inline explanation.
5. **Magic number explanation** — numeric constants without context (timeouts, limits, ratios) should have comments explaining their origin.
6. **Deprecated code markers** — code paths kept for backward compatibility should be marked with deprecation notice and removal plan.
7. **Security-sensitive sections** — auth checks, signature verification, and idempotency logic should have comments explaining the security invariant.
8. **Cross-stack coupling notes** — where Dart and Python models must stay in sync, add a comment referencing the counterpart file.
9. **Cron job documentation** — each cron job should have a header comment explaining its trigger frequency and purpose.
10. **Error handling rationale** — non-obvious error handling choices (swallowing exceptions, retry logic) should explain why.
""",

    "legacy_code_audit": """\
# Audit: Legacy, Deprecated & Dead Code

## What to Audit
1. **Banned Flutter APIs** — `withOpacity()`, `MaterialPageRoute`, `CircularProgressIndicator`, raw `ElevatedButton`/`TextField`/`AppBar`.
2. **Old state management** — any `Provider`, `ChangeNotifier`, `BlocProvider`, or `GetX` usage; Riverpod ONLY.
3. **Business logic in screens** — direct Firestore/Firebase calls in `screens/`; all logic must be in ViewModels.
4. **Deprecated Python idioms** — Pydantic v1 `.dict()`, `@validator`, bare `except:`, `print()` for logging.
5. **Dead/commented-out code** — commented-out code blocks, unreachable branches, unused functions.
6. **The word "legacy"** — forbidden in the entire codebase; flag every occurrence.
7. **`@deprecated`/`@Deprecated` markers** — code that was deprecated must be removed, not just marked.
8. **Magic strings** — hardcoded Firestore field names and collection names outside `schema_constants`.
9. **Removed schema fields** — `warehouseStock`, `deliveryStatus`, or any field removed from the schema still referenced in code.
10. **TODOs/FIXMEs without issue reference** — untracked deferred work must be resolved or tracked with `TODO(#issue)`.
""",

    "rival_audit": """\
# Audit: Competitive Intelligence & Feature Gap Analysis

## What to Audit
1. **Checkout UX** — compare OrignaGTA checkout flow to Amazon/Shopify; identify friction points and missing trust signals.
2. **Product discovery** — compare search, filter, and recommendation UX to AliExpress/Etsy; identify missing discovery features.
3. **Seller onboarding** — compare seller registration and product listing flow to Shopify/eBay; identify unnecessary friction.
4. **Order management** — compare buyer and seller order tracking UX to Amazon/Walmart; identify missing status visibility.
5. **Trust signals** — compare review system, seller ratings, and return policy display to established marketplaces.
6. **Mobile UX** — compare mobile responsiveness and touch interactions to top e-commerce apps.
7. **Premium feature value** — compare subscription tier value proposition to similar SaaS marketplace platforms.
8. **Shipping transparency** — compare shipping cost and delivery estimate display to Amazon Prime / Shopify markets.
9. **Cart and wishlist** — compare cart abandonment recovery and wishlist features to top platforms.
10. **Canadian market fit** — features specific to Canadian buyers (French, CAD, local shipping) vs. global competitors.
""",

    # ── TEST-FLOW INSTRUCTIONS ────────────────────────────────────────────────
    # For test-centered flows the instructions tell the AI HOW to work with the test file.

    "test_add_product": """\
# Test Flow: Add Product (E2E)

## Context
This flow contains the Playwright spec + all supporting source files for the Add Product screen.
The `api-helpers.ts` and `flutter-helpers.ts` are the shared test utilities.
`SEMANTICS.md` maps every Flutter Key/label used for selectors.

## What to Do
1. **Read** the spec file first to understand current test coverage.
2. **Identify gaps** — what scenarios are NOT tested? (validation errors, image upload, warehouse selection, SKU conflict, digital toggle, etc.)
3. **Write new tests** or extend existing ones directly in the spec file format.
4. **Use Flutter selectors** from SEMANTICS.md — never search by display text.
5. **Use helpers** — `getProductData()`, `createTestProduct()`, `loginAs()` from api-helpers.ts.
6. Output full test blocks ready to paste into the spec file.
""",

    "test_admin_actions": """\
# Test Flow: Admin Actions (E2E)

## Context
Admin-only operations: product approval/rejection, user banning, order intervention, seller verification.

## What to Do
1. Read the spec to understand current admin action coverage.
2. Identify missing scenarios: audit log entries, admin self-protection, payment provider config.
3. Extend tests — every admin action must verify backend state change (Firestore), not just UI.
4. Use `loginAsAdmin()` helper. Non-admin access attempts must be tested with `loginAsSeller()`.
5. Output full test blocks ready to paste.
""",

    "test_admin_panel": """\
# Test Flow: Admin Panel (E2E)

## Context
Admin panel tabs: products queue, users, orders, sellers, security alerts.

## What to Do
1. Read the spec — identify which tabs have coverage and which are missing.
2. Add tests for: product approve/reject lifecycle, user ban + session invalidation, security alert resolution.
3. All assertions must check both UI state AND Firestore document state.
4. Output full test blocks ready to paste.
""",

    "test_admin_security": """\
# Test Flow: Admin Security (E2E)

## Context
Security tests: unauthenticated access, role escalation, Firestore rule enforcement.

## What to Do
1. Read the spec — identify untested attack vectors.
2. Add tests for: non-admin accessing admin routes (403), self-role-escalation, cross-user data access.
3. Each test should make the forbidden call directly (via api-helpers fetch) and assert rejection.
4. Output full test blocks ready to paste.
""",

    "test_buyer_flow": """\
# Test Flow: Buyer Flow (E2E)

## Context
Full buyer journey: browse → product detail → cart → checkout → order tracking.

## What to Do
1. Read the spec — trace the full happy path and identify edge cases not covered.
2. Add tests for: out-of-stock handling, address validation, multiple addresses, coupon at checkout.
3. Use `SEMANTICS.md` for all selectors — cart badge, checkout button, order status label keys.
4. Output full test blocks ready to paste.
""",

    "test_checkout_validation": """\
# Test Flow: Checkout Validation (E2E)

## Context
Form validation at checkout: address, coupon codes, stock availability, price changes.

## What to Do
1. Read the spec — identify all validation paths currently tested.
2. Add tests for: expired coupon, min-order coupon, invalid postal code, out-of-stock during checkout.
3. Each validation error must assert the correct error message is displayed (use Semantics label keys).
4. Output full test blocks ready to paste.
""",

    "test_digital_products": """\
# Test Flow: Digital Products (E2E)

## Context
Digital product purchase: no shipping, license generation, download access.

## What to Do
1. Read the spec — identify what's tested vs missing.
2. Add tests for: license key displayed after purchase, re-download works, no shipping address required.
3. Verify order shows digital badge in orders list.
4. Output full test blocks ready to paste.
""",

    "test_edge_cases_security": """\
# Test Flow: Edge Cases & Security (E2E)

## Context
Adversarial scenarios: self-purchase, price tampering, race conditions, auth bypass.

## What to Do
1. Read the spec — identify which attack vectors are tested.
2. Add tests for any missing: concurrent checkout (stock race), coupon double-use, self-purchase API call.
3. Each security test must call the backend directly (api-helpers) to bypass frontend guards.
4. Output full test blocks ready to paste.
""",

    "test_favorites": """\
# Test Flow: Favorites (E2E)

## Context
Favorites: toggle, count badge, view favorites screen, handle deleted product.

## What to Do
1. Read the spec — what's covered?
2. Add tests for: favorite from product detail, unfavorite, favorites list shows correct items.
3. Edge case: favorite a product that gets deleted — assert graceful handling, no crash.
4. Output full test blocks ready to paste.
""",

    "test_multi_seller_orders": """\
# Test Flow: Multi-Seller Orders (E2E)

## Context
Cart with products from multiple sellers: separate shipping, separate payouts, cross-seller auth.

## What to Do
1. Read the spec — what multi-seller scenarios are covered?
2. Add tests for: seller A cannot see/modify seller B's order, separate shipping per seller, platform fee per seller.
3. Use SEMANTICS.md for order grouping selectors.
4. Output full test blocks ready to paste.
""",

    "test_new_coverage": """\
# Test Flow: New Coverage (E2E)

## Context
Tests for features added after initial E2E suite: subscription, stock notifications, advanced profile features.

## What to Do
1. Read the spec — understand what "new coverage" currently includes.
2. Identify the biggest gaps vs FLOWS.md and INSTRUCTIONS.md coverage gaps section.
3. Add complete new test blocks for uncovered areas.
4. Output full test blocks ready to paste.
""",

    "test_order_cancellation": """\
# Test Flow: Order Cancellation & Refund (E2E)

## Context
Cancellation and return flows: buyer cancels, seller approves return, refund issued.

## What to Do
1. Read the spec — trace cancellation and return paths tested.
2. Add tests for: cancel within window vs outside window, return approval/rejection, partial refund.
3. Assert Firestore order status AND Stripe refund (via api-helpers Stripe call).
4. Output full test blocks ready to paste.
""",

    "test_order_lifecycle": """\
# Test Flow: Order Lifecycle (E2E)

## Context
Full order state machine: pending → confirmed → shipped → delivered, plus failure paths.

## What to Do
1. Read the spec — identify which state transitions are tested.
2. Add tests for missing transitions: auto-confirm (mock cron), expired authorization, dispute.
3. Each transition test must verify: UI state change + Firestore document + email trigger (if applicable).
4. Output full test blocks ready to paste.
""",

    "test_payment_edge_cases": """\
# Test Flow: Payment Edge Cases (E2E)

## Context
Payment failure scenarios: declined card, 3DS, network timeout, refund failure.

## What to Do
1. Read the spec — which payment failure paths are tested?
2. Add tests for: card declined (4000 0000 0000 9995), 3DS required (4000 0025 0000 3155), Stripe test clock scenarios.
3. Each failure must assert correct user-facing error message and order not created.
4. Output full test blocks ready to paste.
""",

    "test_premium_subscription": """\
# Test Flow: Premium Subscription (E2E)

## Context
Subscription lifecycle: subscribe, use premium features, cancel, reactivate.

## What to Do
1. Read the spec — what subscription scenarios are tested?
2. Add tests for: paywall shown to non-premium, premium features unlocked after subscribe, cancellation flow, chat access gate.
3. Must verify BOTH `subscriptions/{uid}.status` AND `users/{uid}.isPremium` in Firestore.
4. Output full test blocks ready to paste.
""",

    "test_profile_management": """\
# Test Flow: Profile Management (E2E)

## Context
Profile: display name, language, addresses (CRUD), default address.

## What to Do
1. Read the spec — what profile actions are tested?
2. Add tests for: add Canadian address, set default, delete non-default, non-CA address rejected.
3. Language preference change must persist to Firestore user doc.
4. Output full test blocks ready to paste.
""",

    "test_rate_limiting": """\
# Test Flow: Rate Limiting (E2E)

## Context
Rate limit enforcement on sensitive endpoints: login, signup, checkout.

## What to Do
1. Read the spec — which endpoints are rate-limit tested?
2. Add tests: exceed login rate limit → 429 response, rate limit resets after window.
3. Note: dev environment uses `RELAXED_RATE_LIMITS=true` (100x multiplier) — tests must hit that higher limit.
4. Output full test blocks ready to paste.
""",

    "test_search_products": """\
# Test Flow: Search Products (E2E)

## Context
Algolia-powered search: text search, category filter, price range, sort by.

## What to Do
1. Read the spec — what search scenarios are covered?
2. Add tests for: search with no results (empty state), category filter, inactive product excluded from results.
3. Use SEMANTICS.md for search input key and product card selectors.
4. Output full test blocks ready to paste.
""",

    "test_seller_flow": """\
# Test Flow: Seller Flow (E2E)

## Context
Seller journey: list product, view orders, mark shipped, receive payout.

## What to Do
1. Read the spec — what seller actions are tested?
2. Add tests for: seller cannot see other sellers' orders, mark shipped with tracking number, shipping approval workflow.
3. Use SEMANTICS.md for seller order screen selectors.
4. Output full test blocks ready to paste.
""",

    "test_seller_product_management": """\
# Test Flow: Seller Product Management (E2E)

## Context
Product CRUD for sellers: create, edit, pause, archive, delete.

## What to Do
1. Read the spec — what product management actions are tested?
2. Add tests for: pause/unpause product, archive, edit price, edit stock, SKU conflict on edit.
3. Every change must be verified in Firestore AND Algolia index (via api-helpers).
4. Output full test blocks ready to paste.
""",

    "test_seller_registration": """\
# Test Flow: Seller Registration (E2E)

## Context
Seller onboarding: form, Stripe Connect Express, role assignment.

## What to Do
1. Read the spec — what registration steps are tested?
2. Add tests for: incomplete form → error, Stripe Connect redirect, seller role assigned after completion.
3. Verify `seller_profiles/{uid}` created in Firestore, `isSeller=true` on user doc.
4. Output full test blocks ready to paste.
""",

    "test_shipping_approval": """\
# Test Flow: Shipping Approval (E2E)

## Context
Shipping cost approval workflow: seller submits actual cost, buyer approves/rejects.

## What to Do
1. Read the spec — what approval scenarios are tested?
2. Add tests for: buyer approves → order proceeds to capture; buyer rejects → order cancelled and refunded.
3. Verify payment status transitions in Firestore.
4. Output full test blocks ready to paste.
""",

    "test_shipping_calculation": """\
# Test Flow: Shipping Calculation (E2E)

## Context
Dynamic shipping cost calculation based on seller location, buyer address, and product weight.

## What to Do
1. Read the spec — what calculation scenarios are tested?
2. Add tests for: different provinces (ON vs BC vs QC), express vs standard, free shipping threshold.
3. Assert the calculated amount matches expected formula from shipping_service.py rules.
4. Output full test blocks ready to paste.
""",

    "test_smoke_home_profile": """\
# Test Flow: Smoke — Home & Profile (E2E)

## Context
Smoke tests: app loads, home screen shows products, profile accessible after login.

## What to Do
1. Read the spec — what smoke checks are in place?
2. Add critical smoke assertions missing: search bar present, cart icon present, bottom nav items, profile data loaded.
3. These tests should be FAST (< 30s) — no checkout, no payment.
4. Output full test blocks ready to paste.
""",

    "test_stripe_payment": """\
# Test Flow: Stripe Payment (E2E)

## Context
Full Stripe payment flow via Stripe hosted checkout: card entry, 3DS, success redirect.

## What to Do
1. Read the spec — what payment scenarios go through Stripe's UI?
2. Add tests for: successful payment with 4242 card, failure with 4000...9995 card, order created correctly.
3. Use `fillStripeCheckout()` helper from api-helpers.ts — do NOT re-implement Stripe form filling.
4. Output full test blocks ready to paste.
""",

    "test_trending_products": """\
# Test Flow: Trending Products (E2E)

## Context
Trending/featured products section on home screen powered by Algolia.

## What to Do
1. Read the spec — what trending product scenarios are tested?
2. Add tests for: trending section visible, clicking a trending product navigates to detail, empty state handled.
3. Use SEMANTICS.md for trending section container key.
4. Output full test blocks ready to paste.
""",

    "test_warehouse_multi_location": """\
# Test Flow: Warehouse Multi-Location (E2E)

## Context
Seller warehouse management: add warehouse, set default, assign product stock per warehouse.

## What to Do
1. Read the spec — what warehouse scenarios are tested?
2. Add tests for: add warehouse → shows in list, set as default, per-warehouse stock on product creation.
3. Verify `users/{uid}/warehouses/{warehouseId}` Firestore path and `seller_profiles` update.
4. Output full test blocks ready to paste.
""",
}

# ── Workflow → files map ────────────────────────────────────────────────────
# Do NOT include CLAUDE.md here — it is injected automatically.
FLOWS: dict[str, list[str]] = {
    "checkout_payment": [
        # Frontend
        "origna_gta/lib/features/cart/cart_provider.dart",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/features/checkout/checkout_state.dart",
        "origna_gta/lib/screens/cart_screen.dart",
        "origna_gta/lib/screens/cartitem_screen.dart",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/screens/payment_screens.dart",
        "origna_gta/lib/core/repositories/cart_repository.dart",
        "origna_gta/lib/core/repositories/order_repository.dart",
        "origna_gta/lib/screens/ordersuccess_screen.dart",
        # Backend
        "functions/handlers/payment_stripe.py",
        "functions/handlers/orders.py",
        "functions/services/shipping_service.py",
        "functions/schema_constants.py",
        # Schema / Rules
        "docs/database_schema.json",
        "firestore.rules",
        "docs/json_schemas/individual/Order.json",
        "docs/json_schemas/individual/OrderCreate.json",
        "docs/json_schemas/individual/OrderItem.json",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "order_lifecycle": [
        # Frontend
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "origna_gta/lib/features/orders/seller_orders_state.dart",
        "origna_gta/lib/features/orders/buyer_orders_viewmodel.dart",
        "origna_gta/lib/features/orders/orders_provider.dart",
        "origna_gta/lib/features/orders/shipping_approval_viewmodel.dart",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/screens/seller_orders_screen.dart",
        "origna_gta/lib/screens/shipping_approval_screen.dart",
        # Backend
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        "functions/handlers/cron_jobs.py",
        "functions/services/email_service.py",
        # Models
        "origna_gta/lib/models/generated/order_models.dart",
        "origna_gta/lib/models/generated/base_models.dart",
        "functions/models/order.py",
        "functions/models/order_event.py",
        "functions/models/base.py",
        # Schema
        "docs/database_schema.json",
        "docs/json_schemas/individual/Order.json",
        "docs/json_schemas/individual/OrderItem.json",
        "docs/json_schemas/individual/OrderStatusEnum.json",
        "docs/json_schemas/individual/PaymentStatusEnum.json",
        "docs/json_schemas/individual/ShippingApprovalStatusEnum.json",
        "firestore.rules",
    ],

    "product_lifecycle": [
        # Frontend
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/features/products/add_product_state.dart",
        "origna_gta/lib/features/products/edit_product_viewmodel.dart",
        "origna_gta/lib/features/products/edit_product_state.dart",
        "origna_gta/lib/features/products/product_detail_viewmodel.dart",
        "origna_gta/lib/features/products/product_actions_viewmodel.dart",
        "origna_gta/lib/features/products/products_provider.dart",
        "origna_gta/lib/features/products/product_rating_viewmodel.dart",
        "origna_gta/lib/screens/addproduct_screen.dart",
        "origna_gta/lib/screens/editproduct_screen.dart",
        "origna_gta/lib/screens/productdetails_screen.dart",
        "origna_gta/lib/screens/product_card_screen.dart",
        "origna_gta/lib/screens/productaddimages_screen.dart",
        "origna_gta/lib/core/repositories/product_repository.dart",
        # Backend
        "functions/handlers/products.py",
        "functions/services/algolia_service.py",
        "functions/models/product.py",
        # Schema
        "docs/database_schema.json",
        "docs/json_schemas/individual/Product.json",
        "origna_gta/lib/models/generated/product_models.dart",
    ],

    "add_product": [
        # Core UI + ViewModel
        "origna_gta/lib/screens/addproduct_screen.dart",
        "origna_gta/lib/screens/productaddimages_screen.dart",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/features/products/add_product_state.dart",
        # Warehouse support
        "origna_gta/lib/features/seller/warehouses_viewmodel.dart",
        # Repository + providers
        "origna_gta/lib/core/repositories/product_repository.dart",
        "origna_gta/lib/features/products/products_provider.dart",
        # Backend
        "functions/handlers/products.py",
        "functions/services/algolia_service.py",
        "functions/services/shipping_service.py",
        "functions/models/product.py",
        # Constants + schema
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "origna_gta/lib/models/generated/product_models.dart",
        "docs/json_schemas/individual/Product.json",
    ],

    "auth_seller_onboarding": [
        # Frontend
        "origna_gta/lib/features/auth/auth_provider.dart",
        "origna_gta/lib/features/auth/login_viewmodel.dart",
        "origna_gta/lib/features/auth/login_state.dart",
        "origna_gta/lib/features/seller/seller_registration_view_model.dart",
        "origna_gta/lib/features/seller/seller_registration_state.dart",
        "origna_gta/lib/features/seller/seller_account_status_viewmodel.dart",
        "origna_gta/lib/screens/login_screen.dart",
        "origna_gta/lib/screens/seller_registration_screen.dart",
        "origna_gta/lib/screens/seller_setup_screen.dart",
        "origna_gta/lib/screens/authwrapper_screen.dart",
        "origna_gta/lib/core/repositories/auth_repository.dart",
        "origna_gta/lib/core/repositories/user_repository.dart",
        # Backend
        "functions/handlers/admin.py",
        "functions/handlers/payment_stripe.py",
        "functions/models/user.py",
        "functions/services/rate_limiter.py",
        # Schema
        "docs/database_schema.json",
        "docs/json_schemas/individual/User.json",
        "firestore.rules",
    ],

    "email_notifications": [
        "functions/services/email_service.py",
        "functions/services/email_task.py",
        "functions/handlers/email_tasks.py",
        "functions/services/pdf_invoice_service.py",
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        "functions/handlers/cron_jobs.py",
        "functions/schema_constants.py",
    ],

    "cron_jobs": [
        "functions/handlers/cron_jobs.py",
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        "functions/schema_constants.py",
        "docs/database_schema.json",
    ],

    "search_discovery": [
        # Frontend
        "origna_gta/lib/features/home/home_viewmodel.dart",
        "origna_gta/lib/features/home/home_state.dart",
        "origna_gta/lib/screens/home_screen.dart",
        "origna_gta/lib/core/repositories/algolia_product_repository.dart",
        "origna_gta/lib/services/algolia_service.dart",
        "origna_gta/lib/widgets/modern_product_card.dart",
        # Backend
        "functions/services/algolia_service.py",
        "functions/handlers/products.py",
        "functions/schema_constants.py",
        "functions/configure_algolia_indices.py",
    ],

    "security": [
        "firestore.rules",
        "storage.rules",
        "functions/services/rate_limiter.py",
        "functions/utils/helpers.py",
        "functions/utils/crypto_utils.py",
        "functions/utils/function_options.py",
        "functions/handlers/admin.py",
        "origna_gta/lib/core/repositories/auth_repository.dart",
        "origna_gta/lib/features/auth/auth_provider.dart",
        "origna_gta/lib/services/session_timeout_service.dart",
        "origna_gta/lib/utils/circuit_breaker.dart",
        "functions/schema_constants.py",
        "docs/database_schema.json",
    ],

    "schema_consistency": [
        "docs/database_schema.json",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "functions/models/base.py",
        "functions/models/order.py",
        "functions/models/product.py",
        "functions/models/user.py",
        "functions/models/seller_profile.py",
        "origna_gta/lib/models/generated/base_models.dart",
        "origna_gta/lib/models/generated/order_models.dart",
        "origna_gta/lib/models/generated/product_models.dart",
        "origna_gta/lib/models/generated/user_models.dart",
        "origna_gta/lib/models/generated/seller_profile_models.dart",
        "origna_gta/lib/models/generated/models.dart",
        "origna_gta/lib/models/models.dart",
        "origna_gta/lib/models/enum_extensions.dart",
        "origna_gta/lib/utils/constants.dart",
        # Individual JSON schemas
        "docs/json_schemas/individual/Order.json",
        "docs/json_schemas/individual/OrderCreate.json",
        "docs/json_schemas/individual/OrderItem.json",
        "docs/json_schemas/individual/OrderStatusEnum.json",
        "docs/json_schemas/individual/PaymentStatusEnum.json",
        "docs/json_schemas/individual/Product.json",
        "docs/json_schemas/individual/ProductCreate.json",
        "docs/json_schemas/individual/Ratings.json",
        "docs/json_schemas/individual/Taxes.json",
        "docs/json_schemas/individual/User.json",
        "docs/json_schemas/individual/UserCreate.json",
        "docs/json_schemas/individual/UserRole.json",
        "docs/json_schemas/individual/Address.json",
        "docs/json_schemas/individual/AddressDetails.json",
        "docs/json_schemas/individual/SellerDeliveryOption.json",
        "docs/json_schemas/individual/SellerPayout.json",
        "docs/json_schemas/individual/ShippingApprovalStatusEnum.json",
        "docs/json_schemas/individual/DeliveryStatusEnum.json",
        "firestore.rules",
    ],

    # ── NEW FLOWS ─────────────────────────────────────────────────────────────

    "seller_profile_warehouses": [
        # Seller profile
        "origna_gta/lib/features/seller/seller_registration_view_model.dart",
        "origna_gta/lib/features/seller/seller_registration_state.dart",
        "origna_gta/lib/features/seller/seller_account_status_viewmodel.dart",
        "origna_gta/lib/features/seller/warehouses_viewmodel.dart",
        "origna_gta/lib/screens/seller_registration_screen.dart",
        "origna_gta/lib/screens/seller_setup_screen.dart",
        "origna_gta/lib/screens/seller/seller_warehouses_screen.dart",
        "origna_gta/lib/screens/seller_integration_screen.dart",
        "origna_gta/lib/models/generated/seller_profile_models.dart",
        # Backend
        "functions/models/seller_profile.py",
        "functions/handlers/admin.py",
        "functions/handlers/payment_stripe.py",
        # Schema
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "firestore.rules",
    ],

    "subscription_premium": [
        # Frontend
        "origna_gta/lib/features/subscription/subscription_provider.dart",
        "origna_gta/lib/features/subscription/subscription_state.dart",
        "origna_gta/lib/screens/subscription_screen.dart",
        "origna_gta/lib/screens/subscription_cancel_screen.dart",
        "origna_gta/lib/screens/subscription_success_screen.dart",
        "origna_gta/lib/widgets/premium_paywall_widget.dart",
        # Backend
        "functions/handlers/subscriptions.py",
        "functions/handlers/payment_stripe.py",
        "functions/handlers/cron_jobs.py",
        "functions/utils/premium_check.py",
        # Schema / Rules
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "firestore.rules",
    ],

    "chat_messaging": [
        # Frontend
        "origna_gta/lib/features/chat/chat_provider.dart",
        "origna_gta/lib/features/chat/chat_repository.dart",
        "origna_gta/lib/screens/chat_screen.dart",
        # Backend
        "functions/handlers/chat.py",
        # Schema / Rules
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "firestore.rules",
    ],

    "return_requests": [
        # Frontend
        "origna_gta/lib/models/generated/return_request_models.dart",
        "origna_gta/lib/features/orders/buyer_orders_viewmodel.dart",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/screens/seller_orders_screen.dart",
        # Backend
        "functions/models/return_request.py",
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        "functions/services/email_service.py",
        # Schema / Rules
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "firestore.rules",
    ],

    "admin_panel": [
        # Frontend screens
        "origna_gta/lib/features/admin/admin_panel_screen.dart",
        "origna_gta/lib/features/admin/admin_actions_viewmodel.dart",
        "origna_gta/lib/features/admin/admin_providers.dart",
        "origna_gta/lib/features/admin/admin_repository.dart",
        "origna_gta/lib/features/admin/tabs/admin_orders_tab.dart",
        "origna_gta/lib/features/admin/tabs/admin_products_tab.dart",
        "origna_gta/lib/features/admin/tabs/admin_sellers_tab.dart",
        "origna_gta/lib/features/admin/tabs/admin_users_tab.dart",
        "origna_gta/lib/features/admin/tabs/admin_reviews_tab.dart",
        "origna_gta/lib/features/admin/tabs/admin_security_tab.dart",
        "origna_gta/lib/features/admin/tabs/admin_payment_providers_tab.dart",
        # Backend
        "functions/handlers/admin.py",
        "functions/handlers/payment_providers.py",
        # Schema / Rules
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "firestore.rules",
    ],

    "profile_address": [
        # Frontend
        "origna_gta/lib/features/profile/profile_viewmodel.dart",
        "origna_gta/lib/features/profile/profile_state.dart",
        "origna_gta/lib/features/profile/profile_provider.dart",
        "origna_gta/lib/features/profile/address_viewmodel.dart",
        "origna_gta/lib/features/profile/address_state.dart",
        "origna_gta/lib/features/profile/address_management_viewmodel.dart",
        "origna_gta/lib/screens/profile_screen.dart",
        "origna_gta/lib/screens/addressmanagement_screen.dart",
        "origna_gta/lib/screens/editaddress_screen.dart",
        "origna_gta/lib/core/repositories/user_repository.dart",
        "origna_gta/lib/core/repositories/location_repository.dart",
        # Backend
        "functions/handlers/users.py",
        "functions/handlers/addresses.py",
        "functions/models/user.py",
        # Schema / Rules
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "origna_gta/lib/models/generated/user_models.dart",
        "docs/json_schemas/individual/User.json",
        "docs/json_schemas/individual/Address.json",
        "docs/json_schemas/individual/AddressDetails.json",
        "firestore.rules",
    ],

    "notifications": [
        # Frontend
        "origna_gta/lib/features/notifications/notification_provider.dart",
        "origna_gta/lib/services/notification_service.dart",
        # Backend
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        "functions/services/email_service.py",
        # Schema / Rules
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "firestore.rules",
    ],

    "digital_products": [
        # Backend
        "functions/handlers/digital.py",
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        "functions/models/product.py",
        "functions/models/order.py",
        # Frontend
        "origna_gta/lib/models/generated/product_models.dart",
        "origna_gta/lib/models/generated/order_models.dart",
        "origna_gta/lib/screens/productdetails_screen.dart",
        # Schema / Rules
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/json_schemas/individual/Product.json",
        "docs/json_schemas/individual/Order.json",
        "firestore.rules",
    ],

    "coupons_discounts": [
        # Backend
        "functions/handlers/coupons.py",
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        # Frontend
        "origna_gta/lib/features/cart/cart_provider.dart",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/screens/cart_screen.dart",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/core/repositories/cart_repository.dart",
        # Schema / Rules
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "firestore.rules",
    ],

    "product_qa_ratings": [
        # Q&A
        "origna_gta/lib/features/qa/qa_provider.dart",
        "origna_gta/lib/features/qa/qa_repository.dart",
        "origna_gta/lib/models/qa_model.dart",
        # Ratings
        "origna_gta/lib/features/products/product_rating_viewmodel.dart",
        "origna_gta/lib/widgets/rating_dialog.dart",
        "origna_gta/lib/widgets/rating_histogram.dart",
        "origna_gta/lib/screens/productdetails_screen.dart",
        # Backend
        "functions/handlers/products.py",
        "functions/handlers/orders.py",
        # Schema / Rules
        "docs/json_schemas/individual/Ratings.json",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "firestore.rules",
    ],

    "favorites_seller_products": [
        # Frontend
        "origna_gta/lib/screens/favorites_screen.dart",
        "origna_gta/lib/features/seller/seller_products_viewmodel.dart",
        "origna_gta/lib/screens/seller_products_screen.dart",
        "origna_gta/lib/core/repositories/product_repository.dart",
        "origna_gta/lib/widgets/modern_product_card.dart",
        # Backend
        "functions/handlers/products.py",
        # Schema / Rules
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "firestore.rules",
    ],

    # ── NEW FLOWS ─────────────────────────────────────────────────────────────

    "app_bootstrap": [
        # App entry & routing
        "origna_gta/lib/main.dart",
        "origna_gta/lib/origna_app.dart",
        "origna_gta/lib/core/routes.dart",
        "origna_gta/lib/screens/main_screen.dart",
        "origna_gta/lib/screens/common_screens.dart",
        "origna_gta/lib/screens/authwrapper_screen.dart",
        # Config & providers
        "origna_gta/lib/utils/env_config.dart",
        "origna_gta/lib/core/providers.dart",
        "origna_gta/lib/services/conf_services.dart",
        "origna_gta/lib/services/analytics_service.dart",
        "origna_gta/lib/services/session_timeout_service.dart",
        "origna_gta/lib/utils/utils.dart",
        # Backend entry
        "functions/main.py",
        "functions/config.py",
        "functions/utils/function_options.py",
    ],

    "legal_compliance": [
        # Screens
        "origna_gta/lib/screens/privacy_policy_screen.dart",
        "origna_gta/lib/screens/terms_screen.dart",
        "origna_gta/lib/screens/terms_of_service_screen.dart",
        "origna_gta/lib/features/terms/terms_provider.dart",
        "origna_gta/lib/widgets/legal_screen_body.dart",
        "origna_gta/lib/widgets/language_selector.dart",
        # Auth (consent capture)
        "origna_gta/lib/screens/login_screen.dart",
        "functions/handlers/users.py",
        "functions/services/email_service.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
    ],

    "design_system": [
        # Tokens & utilities
        "origna_gta/lib/utils/design_tokens.dart",
        "origna_gta/lib/utils/glassmorphism.dart",
        "origna_gta/lib/utils/responsive_layout.dart",
        "origna_gta/lib/utils/animations.dart",
        "origna_gta/lib/utils/deferred_widget.dart",
        # Modern widget library
        "origna_gta/lib/widgets/modern_button.dart",
        "origna_gta/lib/widgets/modern_card.dart",
        "origna_gta/lib/widgets/modern_textfield.dart",
        "origna_gta/lib/widgets/modern_loading_indicator.dart",
        "origna_gta/lib/widgets/modern_appbar.dart",
        "origna_gta/lib/widgets/custom_app_bar.dart",
        "origna_gta/lib/widgets/animations.dart",
        # Mascot
        "origna_gta/lib/widgets/mascot/canadian_moose.dart",
        "origna_gta/lib/widgets/mascot/mascot_provider.dart",
        "origna_gta/lib/widgets/mascot/moose_provider.dart",
        "origna_gta/lib/widgets/mascot/shop_mascot.dart",
        "origna_gta/lib/widgets/mascot/mascot_preview.dart",
    ],

    "stock_notifications": [
        # Frontend
        "origna_gta/lib/features/products/stock_notification_provider.dart",
        "origna_gta/lib/features/products/variant_models.dart",
        "origna_gta/lib/features/products/products_provider.dart",
        "origna_gta/lib/screens/productdetails_screen.dart",
        "origna_gta/lib/core/repositories/product_repository.dart",
        # Backend
        "functions/handlers/products.py",
        "functions/handlers/orders.py",
        "functions/services/email_service.py",
        # Schema / Rules
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "docs/json_schemas/individual/Product.json",
        "firestore.rules",
    ],

    "supplier_integration": [
        # Supplier config
        "origna_gta/lib/core/config/supplier_config.dart",
        # Product flow (supplier products imported as listings)
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/features/products/add_product_state.dart",
        "origna_gta/lib/screens/addproduct_screen.dart",
        "origna_gta/lib/core/repositories/product_repository.dart",
        "functions/handlers/products.py",
        "functions/models/product.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/json_schemas/individual/Product.json",
    ],

    # ── CROSS-CUTTING AUDIT FLOWS ─────────────────────────────────────────────

    "logic_audit": [
        "functions/handlers/payment_stripe.py",
        "functions/handlers/orders.py",
        "functions/handlers/cron_jobs.py",
        "functions/handlers/products.py",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "origna_gta/lib/features/orders/buyer_orders_viewmodel.dart",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/models/generated/order_models.dart",
        "origna_gta/lib/models/generated/product_models.dart",
        "functions/models/order.py",
        "functions/models/product.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
        "firestore.rules",
    ],

    "cross_stack_audit": [
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "functions/handlers/payment_stripe.py",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "functions/handlers/orders.py",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "functions/handlers/products.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "functions/schema_constants.py",
        "origna_gta/lib/models/generated/order_models.dart",
        "functions/models/order.py",
        "origna_gta/lib/models/generated/product_models.dart",
        "functions/models/product.py",
        "origna_gta/lib/models/generated/user_models.dart",
        "functions/models/user.py",
        "origna_gta/lib/models/generated/base_models.dart",
        "functions/models/base.py",
    ],

    "frontend_audit": [
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "origna_gta/lib/features/orders/buyer_orders_viewmodel.dart",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/features/products/edit_product_viewmodel.dart",
        "origna_gta/lib/features/auth/auth_provider.dart",
        "origna_gta/lib/features/subscription/subscription_provider.dart",
        "origna_gta/lib/core/providers.dart",
        "origna_gta/lib/screens/home_screen.dart",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/screens/productdetails_screen.dart",
        "origna_gta/lib/widgets/premium_paywall_widget.dart",
        "origna_gta/lib/widgets/modern_product_card.dart",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
    ],

    "performance_audit": [
        "functions/handlers/payment_stripe.py",
        "functions/handlers/orders.py",
        "functions/handlers/products.py",
        "functions/services/algolia_service.py",
        "functions/config.py",
        "functions/schema_constants.py",
        "firestore.indexes.json",
        "origna_gta/lib/features/home/home_viewmodel.dart",
        "origna_gta/lib/core/repositories/algolia_product_repository.dart",
        "origna_gta/lib/core/repositories/product_repository.dart",
        "origna_gta/lib/core/repositories/order_repository.dart",
        "origna_gta/lib/core/providers.dart",
        "origna_gta/lib/screens/home_screen.dart",
        "origna_gta/lib/widgets/modern_product_card.dart",
        "docs/database_schema.json",
    ],

    "refactor_audit": [
        "functions/handlers/payment_stripe.py",
        "functions/handlers/orders.py",
        "functions/handlers/products.py",
        "functions/handlers/admin.py",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/screens/addproduct_screen.dart",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/utils/design_tokens.dart",
        "origna_gta/lib/core/providers.dart",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
    ],

    "cost_audit": [
        "functions/config.py",
        "functions/handlers/payment_stripe.py",
        "functions/services/algolia_service.py",
        "functions/services/email_service.py",
        "functions/services/shipping_service.py",
        "functions/handlers/products.py",
        "functions/handlers/cron_jobs.py",
        "functions/handlers/subscriptions.py",
        "functions/main.py",
        "origna_gta/lib/core/repositories/algolia_product_repository.dart",
        "origna_gta/lib/services/algolia_service.dart",
        "origna_gta/lib/core/providers.dart",
        "firestore.indexes.json",
        "docs/database_schema.json",
    ],

    "code_comments_audit": [
        "functions/handlers/payment_stripe.py",
        "functions/handlers/orders.py",
        "functions/handlers/products.py",
        "functions/handlers/admin.py",
        "functions/handlers/cron_jobs.py",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/core/repositories/product_repository.dart",
        "origna_gta/lib/core/repositories/order_repository.dart",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "functions/models/order.py",
        "functions/models/product.py",
    ],

    "legacy_code_audit": [
        # Key screens (most likely to accumulate banned patterns)
        "origna_gta/lib/screens/addproduct_screen.dart",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/screens/home_screen.dart",
        "origna_gta/lib/screens/productdetails_screen.dart",
        "origna_gta/lib/screens/login_screen.dart",
        "origna_gta/lib/screens/profile_screen.dart",
        # ViewModels & providers
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "origna_gta/lib/features/orders/buyer_orders_viewmodel.dart",
        "origna_gta/lib/features/auth/auth_provider.dart",
        "origna_gta/lib/core/providers.dart",
        # Models (check for removed/renamed fields)
        "origna_gta/lib/models/generated/order_models.dart",
        "origna_gta/lib/models/generated/product_models.dart",
        "origna_gta/lib/models/generated/user_models.dart",
        # Backend handlers
        "functions/handlers/orders.py",
        "functions/handlers/products.py",
        "functions/handlers/admin.py",
        # Schema constants (source of truth for removed fields)
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "docs/database_schema.json",
    ],

    "rival_audit": [
        "docs/database_schema.json",
        "origna_gta/lib/screens/home_screen.dart",
        "origna_gta/lib/screens/productdetails_screen.dart",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/widgets/modern_product_card.dart",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/screens/seller_orders_screen.dart",
        "origna_gta/lib/screens/profile_screen.dart",
        "origna_gta/lib/features/subscription/subscription_provider.dart",
        "functions/schema_constants.py",
        "STATE.md",
    ],

    # ── TEST-CENTERED FLOWS — one per Playwright spec file ───────────────────
    # Each flow has the spec + helpers as the PRIMARY files, supporting source
    # files second, and origna_flows docs for Flutter selector context.
    # Purpose: drop into Claude.ai and ask it to audit, extend, or fix the test.

    "test_add_product": [
        "e2e/playwright_ui/add-product-e2e.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/addproduct_screen.dart",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/features/products/add_product_state.dart",
        "origna_gta/lib/features/seller/warehouses_viewmodel.dart",
        "origna_gta/lib/core/repositories/product_repository.dart",
        "functions/handlers/products.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_admin_actions": [
        "e2e/playwright_ui/admin-actions.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/features/admin/admin_actions_viewmodel.dart",
        "origna_gta/lib/features/admin/admin_panel_screen.dart",
        "origna_gta/lib/features/admin/admin_providers.dart",
        "functions/handlers/admin.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "firestore.rules",
    ],

    "test_admin_panel": [
        "e2e/playwright_ui/admin-panel.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/features/admin/admin_panel_screen.dart",
        "origna_gta/lib/features/admin/admin_providers.dart",
        "origna_gta/lib/features/admin/tabs/admin_products_tab.dart",
        "origna_gta/lib/features/admin/tabs/admin_users_tab.dart",
        "origna_gta/lib/features/admin/tabs/admin_orders_tab.dart",
        "functions/handlers/admin.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "firestore.rules",
    ],

    "test_admin_security": [
        "e2e/playwright_ui/admin-security.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "firestore.rules",
        "functions/handlers/admin.py",
        "functions/services/rate_limiter.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "origna_gta/lib/features/auth/auth_provider.dart",
    ],

    "test_buyer_flow": [
        "e2e/playwright_ui/buyer-flow.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/home_screen.dart",
        "origna_gta/lib/screens/productdetails_screen.dart",
        "origna_gta/lib/screens/cart_screen.dart",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "functions/handlers/payment_stripe.py",
        "functions/handlers/orders.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_checkout_validation": [
        "e2e/playwright_ui/checkout-validation.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/screens/cart_screen.dart",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/features/checkout/checkout_state.dart",
        "functions/handlers/payment_stripe.py",
        "functions/handlers/coupons.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_digital_products": [
        "e2e/playwright_ui/digital-products-e2e.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/productdetails_screen.dart",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/models/generated/product_models.dart",
        "origna_gta/lib/models/generated/order_models.dart",
        "functions/handlers/digital.py",
        "functions/handlers/orders.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_edge_cases_security": [
        "e2e/playwright_ui/edge-cases-security.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "firestore.rules",
        "functions/handlers/payment_stripe.py",
        "functions/handlers/orders.py",
        "functions/services/rate_limiter.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_favorites": [
        "e2e/playwright_ui/favorites.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/favorites_screen.dart",
        "origna_gta/lib/screens/productdetails_screen.dart",
        "origna_gta/lib/core/repositories/product_repository.dart",
        "functions/handlers/products.py",
        "firestore.rules",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_multi_seller_orders": [
        "e2e/playwright_ui/multi-seller-orders.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/screens/seller_orders_screen.dart",
        "origna_gta/lib/features/orders/buyer_orders_viewmodel.dart",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_new_coverage": [
        "e2e/playwright_ui/new-coverage-e2e.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/subscription_screen.dart",
        "origna_gta/lib/screens/profile_screen.dart",
        "origna_gta/lib/screens/home_screen.dart",
        "origna_gta/lib/features/subscription/subscription_provider.dart",
        "functions/handlers/subscriptions.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_order_cancellation": [
        "e2e/playwright_ui/order-cancellation-refund.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/features/orders/buyer_orders_viewmodel.dart",
        "origna_gta/lib/models/generated/order_models.dart",
        "origna_gta/lib/models/generated/return_request_models.dart",
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_order_lifecycle": [
        "e2e/playwright_ui/order-lifecycle.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/orders_screen.dart",
        "origna_gta/lib/screens/seller_orders_screen.dart",
        "origna_gta/lib/features/orders/buyer_orders_viewmodel.dart",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "origna_gta/lib/models/generated/order_models.dart",
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_payment_edge_cases": [
        "e2e/playwright_ui/payment-edge-cases.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/features/checkout/checkout_state.dart",
        "functions/handlers/payment_stripe.py",
        "functions/handlers/orders.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_premium_subscription": [
        "e2e/playwright_ui/premium-subscription.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/subscription_screen.dart",
        "origna_gta/lib/screens/subscription_cancel_screen.dart",
        "origna_gta/lib/screens/subscription_success_screen.dart",
        "origna_gta/lib/features/subscription/subscription_provider.dart",
        "origna_gta/lib/widgets/premium_paywall_widget.dart",
        "functions/handlers/subscriptions.py",
        "functions/handlers/payment_stripe.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_profile_management": [
        "e2e/playwright_ui/profile-management.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/profile_screen.dart",
        "origna_gta/lib/screens/addressmanagement_screen.dart",
        "origna_gta/lib/screens/editaddress_screen.dart",
        "origna_gta/lib/features/profile/profile_viewmodel.dart",
        "origna_gta/lib/features/profile/address_viewmodel.dart",
        "functions/handlers/users.py",
        "functions/handlers/addresses.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_rate_limiting": [
        "e2e/playwright_ui/rate-limiting.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "functions/services/rate_limiter.py",
        "functions/handlers/admin.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "firestore.rules",
    ],

    "test_search_products": [
        "e2e/playwright_ui/search-products.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/home_screen.dart",
        "origna_gta/lib/features/home/home_viewmodel.dart",
        "origna_gta/lib/features/home/home_state.dart",
        "origna_gta/lib/core/repositories/algolia_product_repository.dart",
        "origna_gta/lib/widgets/modern_product_card.dart",
        "functions/services/algolia_service.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_seller_flow": [
        "e2e/playwright_ui/seller-flow.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/seller_orders_screen.dart",
        "origna_gta/lib/screens/addproduct_screen.dart",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "functions/handlers/orders.py",
        "functions/handlers/products.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_seller_product_management": [
        "e2e/playwright_ui/seller-product-management.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/addproduct_screen.dart",
        "origna_gta/lib/screens/editproduct_screen.dart",
        "origna_gta/lib/screens/seller_products_screen.dart",
        "origna_gta/lib/features/products/add_product_viewmodel.dart",
        "origna_gta/lib/features/products/edit_product_viewmodel.dart",
        "origna_gta/lib/features/seller/seller_products_viewmodel.dart",
        "functions/handlers/products.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_seller_registration": [
        "e2e/playwright_ui/seller-registration.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/seller_registration_screen.dart",
        "origna_gta/lib/screens/seller_setup_screen.dart",
        "origna_gta/lib/features/seller/seller_registration_view_model.dart",
        "origna_gta/lib/features/seller/seller_registration_state.dart",
        "functions/handlers/admin.py",
        "functions/handlers/payment_stripe.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_shipping_approval": [
        "e2e/playwright_ui/shipping-approval.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/shipping_approval_screen.dart",
        "origna_gta/lib/screens/seller_orders_screen.dart",
        "origna_gta/lib/features/orders/shipping_approval_viewmodel.dart",
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart",
        "functions/handlers/orders.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "origna_gta/lib/models/generated/order_models.dart",
    ],

    "test_shipping_calculation": [
        "e2e/playwright_ui/shipping-calculation.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "functions/services/shipping_service.py",
        "functions/handlers/payment_stripe.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_smoke_home_profile": [
        "e2e/playwright_ui/smoke-home-profile.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/home_screen.dart",
        "origna_gta/lib/screens/profile_screen.dart",
        "origna_gta/lib/screens/main_screen.dart",
        "origna_gta/lib/features/home/home_viewmodel.dart",
        "origna_gta/lib/features/profile/profile_viewmodel.dart",
        "origna_gta/lib/features/auth/auth_provider.dart",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_stripe_payment": [
        "e2e/playwright_ui/stripe-payment.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/screens/payment_screens.dart",
        "origna_gta/lib/screens/ordersuccess_screen.dart",
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "functions/handlers/payment_stripe.py",
        "functions/handlers/orders.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_trending_products": [
        "e2e/playwright_ui/trending-products.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/home_screen.dart",
        "origna_gta/lib/features/home/home_viewmodel.dart",
        "origna_gta/lib/core/repositories/algolia_product_repository.dart",
        "origna_gta/lib/widgets/modern_product_card.dart",
        "functions/services/algolia_service.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
    ],

    "test_warehouse_multi_location": [
        "e2e/playwright_ui/warehouse-multi-location.spec.ts",
        "e2e/playwright_ui/api-helpers.ts",
        "e2e/playwright_ui/flutter-helpers.ts",
        "origna_flows/SEMANTICS.md",
        "origna_flows/FLOWS.md",
        "origna_flows/INSTRUCTIONS.md",
        "origna_gta/lib/screens/seller/seller_warehouses_screen.dart",
        "origna_gta/lib/features/seller/warehouses_viewmodel.dart",
        "origna_gta/lib/models/generated/seller_profile_models.dart",
        "functions/models/seller_profile.py",
        "functions/handlers/admin.py",
        "functions/schema_constants.py",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "firestore.rules",
    ],
}

# ── origna_flows docs always appended to every flow (E2E test context) ───────
# These files live in the repo and provide Flutter semantics, user flows,
# and Playwright testing instructions for the AI reviewing each flow.
_ORIGNA_FLOWS_DOCS = [
    "origna_flows/SEMANTICS.md",   # Flutter Key/label/role map for every screen
    "origna_flows/FLOWS.md",       # 15 step-by-step user journeys with test assertions
    "origna_flows/INSTRUCTIONS.md",  # AI agent guide: selectors, environments, patterns
]

# ── Per-flow E2E test spec files ──────────────────────────────────────────────
# Maps each flow to the Playwright spec(s) that cover it.
# These are appended AFTER the primary source files, before overflow.
FLOW_SPECS: dict[str, list[str]] = {
    "checkout_payment": [
        "e2e/playwright_ui/stripe-payment.spec.ts",
        "e2e/playwright_ui/checkout-validation.spec.ts",
        "e2e/playwright_ui/payment-edge-cases.spec.ts",
        "e2e/playwright_ui/shipping-calculation.spec.ts",
        "e2e/playwright_ui/buyer-flow.spec.ts",
    ],
    "order_lifecycle": [
        "e2e/playwright_ui/order-lifecycle.spec.ts",
        "e2e/playwright_ui/multi-seller-orders.spec.ts",
        "e2e/playwright_ui/shipping-approval.spec.ts",
        "e2e/playwright_ui/buyer-flow.spec.ts",
        "e2e/playwright_ui/seller-flow.spec.ts",
    ],
    "product_lifecycle": [
        "e2e/playwright_ui/seller-product-management.spec.ts",
        "e2e/playwright_ui/seller-flow.spec.ts",
    ],
    "add_product": [
        "e2e/playwright_ui/add-product-e2e.spec.ts",
    ],
    "auth_seller_onboarding": [
        "e2e/playwright_ui/seller-registration.spec.ts",
    ],
    "email_notifications": [
        "e2e/playwright_ui/new-coverage-e2e.spec.ts",
    ],
    "search_discovery": [
        "e2e/playwright_ui/search-products.spec.ts",
        "e2e/playwright_ui/trending-products.spec.ts",
    ],
    "security": [
        "e2e/playwright_ui/admin-security.spec.ts",
        "e2e/playwright_ui/edge-cases-security.spec.ts",
        "e2e/playwright_ui/rate-limiting.spec.ts",
    ],
    "seller_profile_warehouses": [
        "e2e/playwright_ui/warehouse-multi-location.spec.ts",
        "e2e/playwright_ui/seller-registration.spec.ts",
    ],
    "subscription_premium": [
        "e2e/playwright_ui/premium-subscription.spec.ts",
    ],
    "return_requests": [
        "e2e/playwright_ui/order-cancellation-refund.spec.ts",
    ],
    "admin_panel": [
        "e2e/playwright_ui/admin-actions.spec.ts",
        "e2e/playwright_ui/admin-panel.spec.ts",
        "e2e/playwright_ui/admin-security.spec.ts",
    ],
    "profile_address": [
        "e2e/playwright_ui/profile-management.spec.ts",
        "e2e/playwright_ui/smoke-home-profile.spec.ts",
    ],
    "digital_products": [
        "e2e/playwright_ui/digital-products-e2e.spec.ts",
    ],
    "coupons_discounts": [
        "e2e/playwright_ui/checkout-validation.spec.ts",
    ],
    "favorites_seller_products": [
        "e2e/playwright_ui/favorites.spec.ts",
    ],
    "app_bootstrap": [
        "e2e/playwright_ui/smoke-home-profile.spec.ts",
    ],
    "logic_audit": [
        "e2e/playwright_ui/buyer-flow.spec.ts",
        "e2e/playwright_ui/seller-flow.spec.ts",
        "e2e/playwright_ui/edge-cases-security.spec.ts",
    ],
    "cross_stack_audit": [
        "e2e/playwright_ui/buyer-flow.spec.ts",
        "e2e/playwright_ui/seller-flow.spec.ts",
        "e2e/playwright_ui/multi-seller-orders.spec.ts",
    ],
    "frontend_audit": [
        "e2e/playwright_ui/smoke-home-profile.spec.ts",
        "e2e/playwright_ui/new-coverage-e2e.spec.ts",
    ],
    "performance_audit": [
        "e2e/playwright_ui/search-products.spec.ts",
        "e2e/playwright_ui/buyer-flow.spec.ts",
    ],
    "legacy_code_audit": [
        "e2e/playwright_ui/new-coverage-e2e.spec.ts",
        "e2e/playwright_ui/smoke-home-profile.spec.ts",
    ],
    "stock_notifications": [
        "e2e/playwright_ui/new-coverage-e2e.spec.ts",
    ],
}


@dataclass
class FlowCopyResult:
    """Class FlowCopyResult."""
    flow_name: str
    copied_files: int
    missing_count: int
    missing_files: list[str]
    total_bytes: int
    folder_file_count: int
    overflow_entries_written: int
    deferred_primary_count: int
    truncated_overflow: bool
    omitted_due_size_count: int


def copy_flow(flow_name: str, file_paths: list[str]) -> FlowCopyResult:
    """Copy files for a flow into Desktop/origna_flows/<flow_name>/.

    - Writes INSTRUCTIONS.md (does NOT count toward MAX_FILES_PER_FLOW).
    - CLAUDE.md + any learned.md/LEARNED.md variants (if present) are prepended first.
    - E2E spec files from FLOW_SPECS + origna_flows docs appended after primary source files.
    - If total files exceed MAX_FILES_PER_FLOW, excess files are concatenated into _overflow.md.
    - Total content is capped at MAX_TOTAL_BYTES to respect Claude.ai's context limit.
    - Folder will have at most 10 files: 8 primary + INSTRUCTIONS.md + _overflow.md.
    """
    dest_root = DESKTOP / flow_name
    if dest_root.exists():
        shutil.rmtree(dest_root)
    dest_root.mkdir(parents=True)

    # Write INSTRUCTIONS.md (not counted in file limit)
    instructions_body = FLOW_INSTRUCTIONS.get(flow_name, "")
    instructions_text = instructions_body + _COMMON_FOOTER
    (dest_root / "INSTRUCTIONS.md").write_text(instructions_text, encoding="utf-8")

    total_bytes = len(instructions_text.encode("utf-8"))

    # Build file list: CLAUDE.md (+ learned files if present) → E2E specs → source files → origna_flows docs
    # Spec files get HIGH priority (right after injected context files) so they're never bumped to overflow.
    spec_files = FLOW_SPECS.get(flow_name, [])
    learned_files = _resolve_learned_files()
    injected_files = [_CLAUDE] + learned_files
    origna_docs = [f for f in _ORIGNA_FLOWS_DOCS if f not in file_paths]
    seen: set[str] = set()
    all_files: list[str] = []
    for f in injected_files + spec_files + list(file_paths) + origna_docs:
        if f not in seen:
            seen.add(f)
            all_files.append(f)

    # Split into normal (first MAX_FILES_PER_FLOW) and overflow
    primary = all_files[:MAX_FILES_PER_FLOW]
    overflow = list(all_files[MAX_FILES_PER_FLOW:])

    copied = 0
    missing = 0
    missing_files: list[str] = []
    deferred: list[str] = []  # primary files bumped to overflow due to size limit
    always_include = set(injected_files)

    for rel in primary:
        src = REPO_ROOT / rel
        if not src.exists():
            print(f"  ⚠️  MISSING: {rel}")
            missing += 1
            missing_files.append(rel)
            continue
        file_bytes = src.stat().st_size
        # Always include injected context files; defer others if size cap would be exceeded
        if rel not in always_include and total_bytes + file_bytes > MAX_TOTAL_BYTES:
            deferred.append(rel)
            continue
        dest = dest_root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        total_bytes += file_bytes
        copied += 1

    # Concatenate overflow + deferred files into _overflow.md
    all_overflow = deferred + overflow
    overflow_entries_written = 0
    truncated_overflow = False
    omitted_due_size_count = 0
    if all_overflow:
        overflow_parts: list[str] = []
        for idx, rel in enumerate(all_overflow):
            src = REPO_ROOT / rel
            if not src.exists():
                print(f"  ⚠️  MISSING (overflow): {rel}")
                missing += 1
                missing_files.append(rel)
                continue
            try:
                content = src.read_text(encoding="utf-8", errors="replace")
            except Exception as e:
                content = f"[Error reading file: {e}]"
            header = f"## FILE: {rel}\n\n```\n"
            footer = "\n```\n"
            chunk_bytes = len((header + content + footer).encode("utf-8"))
            if total_bytes + chunk_bytes > MAX_TOTAL_BYTES:
                truncated_overflow = True
                # Truncate content to fit within remaining budget
                header_b = header.encode("utf-8")
                trunc_footer = b"\n[TRUNCATED -- size limit reached]\n```\n"
                remaining = MAX_TOTAL_BYTES - total_bytes - len(header_b) - len(trunc_footer)
                if remaining < 20:
                    omitted_due_size_count = len(all_overflow) - idx
                    break  # no room left — stop adding overflow files
                truncated = content.encode("utf-8")[:remaining].decode("utf-8", errors="ignore")
                part = header + truncated + "\n[TRUNCATED — size limit reached]\n```\n"
                overflow_parts.append(part)
                total_bytes += len(part.encode("utf-8"))
                copied += 1
                overflow_entries_written += 1
                omitted_due_size_count = len(all_overflow) - idx - 1
                break  # stop after truncated entry
            overflow_parts.append(f"## FILE: {rel}\n\n```\n{content}\n```\n")
            total_bytes += chunk_bytes
            copied += 1
            overflow_entries_written += 1

        if overflow_parts:
            overflow_md = dest_root / "_overflow.md"
            overflow_md.write_text(
                f"# Overflow files for flow: {flow_name}\n\n"
                + "\n---\n\n".join(overflow_parts),
                encoding="utf-8",
            )

    folder_files = sum(1 for f in dest_root.rglob("*") if f.is_file())  # actual files to upload to Claude.ai
    return FlowCopyResult(
        flow_name=flow_name,
        copied_files=copied,
        missing_count=missing,
        missing_files=missing_files,
        total_bytes=total_bytes,
        folder_file_count=folder_files,
        overflow_entries_written=overflow_entries_written,
        deferred_primary_count=len(deferred),
        truncated_overflow=truncated_overflow,
        omitted_due_size_count=omitted_due_size_count,
    )


def write_manifest(results: list[FlowCopyResult], elapsed_seconds: float) -> None:
    """Write structured run metadata for downstream audits."""
    total_copied = sum(r.copied_files for r in results)
    total_missing = sum(r.missing_count for r in results)
    truncated_flows = sum(1 for r in results if r.truncated_overflow)
    near_limit_flows = sum(1 for r in results if r.total_bytes > MAX_TOTAL_BYTES * 0.95)
    payload = {
        "summary": {
            "flow_count": len(results),
            "total_copied_files": total_copied,
            "total_missing_files": total_missing,
            "truncated_flows": truncated_flows,
            "near_limit_flows": near_limit_flows,
            "max_primary_files_per_flow": MAX_FILES_PER_FLOW,
            "max_total_bytes_per_flow": MAX_TOTAL_BYTES,
            "elapsed_seconds": round(elapsed_seconds, 3),
        },
        "flows": [asdict(r) for r in results],
    }
    manifest_path = DESKTOP / "_manifest.json"
    manifest_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main() -> None:
    """Function main."""
    started = perf_counter()
    # Wipe the entire output folder first so renamed/deleted flows don't linger
    if DESKTOP.exists():
        shutil.rmtree(DESKTOP)
        print(f"🗑️  Removed old: {DESKTOP}")
    DESKTOP.mkdir(parents=True)
    print(f"📂 Output: {DESKTOP}\n")
    results: list[FlowCopyResult] = []

    for flow, files in FLOWS.items():
        result = copy_flow(flow, files)
        results.append(result)
        status = "✅" if result.missing_count == 0 else "⚠️"
        size_kb = result.total_bytes / 1024
        near_limit = "  ⚠️ NEAR LIMIT" if result.total_bytes > MAX_TOTAL_BYTES * 0.95 else ""
        trunc_note = "  ✂️ TRUNCATED" if result.truncated_overflow else ""
        print(
            f"{status} {flow:<35}  {result.folder_file_count}/{MAX_TOTAL_FILES_PER_FLOW} files  "
            f"({result.missing_count} missing)  📦 {size_kb:.0f} KB"
            f"{near_limit}{trunc_note}"
        )

    elapsed = perf_counter() - started
    total_copied = sum(r.copied_files for r in results)
    total_missing = sum(r.missing_count for r in results)
    write_manifest(results, elapsed)

    print(f"\nDone — {total_copied} files copied, {total_missing} missing across {len(FLOWS)} flows.")
    print(f"📁 Open: {DESKTOP}")
    print(
        f"ℹ️  Size cap: {MAX_TOTAL_BYTES // 1024} KB per flow  |  "
        f"Max files: {MAX_FILES_PER_FLOW} primary + INSTRUCTIONS.md + _overflow.md = {MAX_TOTAL_FILES_PER_FLOW} total"
    )
    print(f"🧾 Manifest: {DESKTOP / '_manifest.json'}")


def create_complete_flows() -> None:
    """Backward-compatible alias used by older automation prompts."""
    main()


if __name__ == "__main__":
    create_complete_flows()
