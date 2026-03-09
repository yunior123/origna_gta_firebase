# Skills, Agents & Legacy Sweep — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove all outdated/dead content, fix stale skill data, upgrade skills with Claude cookbook patterns, and validate with a full 10-agent audit.

**Architecture:** Four-wave approach — dead removal first, legacy code scan second, skill rewrites third, full audit fourth. Each wave is independently committable.

**Tech Stack:** Claude Code skills (SKILL.md), Markdown docs, Python Cloud Functions, Flutter/Dart, Playwright E2E (TypeScript)

---

## HONEST FINDINGS (pre-plan audit)

These are confirmed problems found BEFORE implementation begins:

| Issue | Severity | Evidence |
|-------|----------|----------|
| `e2e-test-suites` skill lists 9 spec files | CRITICAL | 34 actual .spec.ts files exist |
| Duplicate E2E spec: `digital-product-e2e.spec.ts` AND `digital-products-e2e.spec.ts` | HIGH | Both files exist in `e2e/playwright_ui/` |
| `e2e-test-suites` skill test count "279 E2E" is stale (Feb 10 2026) | HIGH | Many new specs added since |
| 4 overlapping testing docs in `docs/testing/` (870 lines total, mostly stale) | MEDIUM | COMPREHENSIVE, E2E_TESTS_README, TESTING_GUIDE, E2E_TESTING_GUIDE |
| `docs/plans/2026-02-27-orchestrator-design.md` — design doc for feature already shipped | LOW | orchestrator skill exists |
| `docs/agents/ethical_hacker_agent.md` — orphaned, no associated skill | LOW | Single file, no skill pointer |
| Orchestrator skill uses `gemini-2.0-flash` and `gemini-1.5-pro` — both old | MEDIUM | Gemini 2.5 Flash/Pro are current |
| Skills have no Claude cookbook patterns (evaluator-optimizer, prompt caching) | MEDIUM | Missing patterns from Anthropic cookbook |
| `GEMINI.md` duplicates CLAUDE.md, CLAUDE.md is source of truth | LOW | GEMINI.md defers to CLAUDE.md anyway |
| `payment-system` skill doesn't reflect staging webhook failure (3,655 retries) | HIGH | STATE.md shows active Stripe incident |

---

## Wave 1: Dead Content Removal

### Task 1: Remove duplicate E2E spec file

**Files:**
- Delete: `e2e/playwright_ui/digital-product-e2e.spec.ts` (older singular form)
- Keep: `e2e/playwright_ui/digital-products-e2e.spec.ts` (newer plural form)

**Step 1: Confirm which is newer and which to keep**

```bash
wc -l e2e/playwright_ui/digital-product-e2e.spec.ts e2e/playwright_ui/digital-products-e2e.spec.ts
diff e2e/playwright_ui/digital-product-e2e.spec.ts e2e/playwright_ui/digital-products-e2e.spec.ts | head -40
```

Expected: One is a subset or near-copy of the other. Keep the longer/newer one.

**Step 2: Check for imports in any other file**

```bash
grep -r "digital-product-e2e" e2e/ --include="*.ts"
```

Expected: No imports (spec files are standalone).

**Step 3: Delete the older singular-named file**

```bash
git rm e2e/playwright_ui/digital-product-e2e.spec.ts
```

**Step 4: Commit**

```bash
git add -u
git commit -m "fix: remove duplicate digital-product e2e spec (singular vs plural)"
```

---

### Task 2: Remove stale testing docs

**Files:**
- Delete: `docs/testing/COMPREHENSIVE_TESTS_DOCUMENTATION.md`
- Delete: `docs/testing/E2E_TESTS_README.md`
- Delete: `docs/testing/E2E_TESTING_GUIDE.md`
- Keep and update: `docs/testing/TESTING_GUIDE.md` (43 lines — minimal, worth keeping as pointer)

**Rationale:** The `e2e-test-suites` skill is the authoritative source. These docs are French/English mixed, reference old file structures, and duplicate skill content with stale counts.

**Step 1: Read TESTING_GUIDE.md to verify it's worth keeping**

```bash
cat docs/testing/TESTING_GUIDE.md
```

**Step 2: Remove the three stale docs**

```bash
git rm docs/testing/COMPREHENSIVE_TESTS_DOCUMENTATION.md
git rm docs/testing/E2E_TESTS_README.md
git rm docs/testing/E2E_TESTING_GUIDE.md
```

**Step 3: Update TESTING_GUIDE.md to point to the skill**

Replace content with:
```markdown
# Testing Guide

> Source of truth: `.claude/skills/e2e-test-suites/SKILL.md` (34 specs, updated continuously)

## Quick Reference
- **E2E config:** `e2e/playwright.config.dev.ts`
- **Specs:** `e2e/playwright_ui/*.spec.ts` (34 files)
- **Helpers:** `e2e/playwright_ui/api-helpers.ts`, `flutter-helpers.ts`
- **Base URL:** `https://orignagta-dev.web.app`
- **Run:** `npx playwright test --config=e2e/playwright.config.dev.ts`

## Rules (non-negotiable)
- Never use `fill()` — always `pressSequentially()`
- Never `page.goto()` after login — use `page.goBack()`
- No dynamic product creation in `beforeAll` — use stable product IDs
- Tests against dev Firebase only — emulators forbidden (8GB RAM constraint)
```

**Step 4: Commit**

```bash
git add -u docs/testing/
git commit -m "fix: consolidate stale testing docs → e2e-test-suites skill is source of truth"
```

---

### Task 3: Remove GEMINI.md

**Files:**
- Delete: `GEMINI.md`

**Rationale:** GEMINI.md defers to CLAUDE.md as source of truth (its own words: "CLAUDE.md is the absolute source of truth"). It duplicates the project vision/stack. It references Gemini CLI which is now covered by the `orchestrator` skill. Removing it eliminates confusion about which file to trust.

**Step 1: Check if anything imports or references GEMINI.md**

```bash
grep -r "GEMINI.md" . --include="*.md" --include="*.ts" --include="*.py" --include="*.dart" | grep -v ".git"
```

Expected: Only STATE.md references it as "source of truth" (which should be fixed to point to CLAUDE.md only).

**Step 2: Remove STATE.md reference to GEMINI.md**

In `STATE.md`, find and remove or replace the line:
```
> **Source of Truth:** [CLAUDE.md](./CLAUDE.md), [GEMINI.md](./GEMINI.md), [LEARNED.md](./.claude/LEARNED.md).
```
Change to:
```
> **Source of Truth:** [CLAUDE.md](./CLAUDE.md) — single source of truth.
```

**Step 3: Delete GEMINI.md**

```bash
git rm GEMINI.md
```

**Step 4: Commit**

```bash
git add STATE.md
git commit -m "fix: remove GEMINI.md (CLAUDE.md is sole source of truth, no duplication)"
```

---

### Task 4: Remove orphaned plans doc

**Files:**
- Delete: `docs/plans/2026-02-27-orchestrator-design.md`
- Keep: New plan files (this file, etc.)

**Rationale:** The orchestrator was designed and shipped. Design docs for completed features only waste AI context and mislead future readers.

**Step 1: Verify orchestrator was shipped**

```bash
cat .claude/skills/orchestrator/SKILL.md | head -5
```

Expected: Skill exists and is active.

**Step 2: Delete the shipped design doc**

```bash
git rm docs/plans/2026-02-27-orchestrator-design.md
```

**Step 3: Commit**

```bash
git commit -m "fix: remove implemented orchestrator design doc (skill is live)"
```

---

### Task 5: Remove/inline orphaned ethical hacker agent doc

**Files:**
- Evaluate: `docs/agents/ethical_hacker_agent.md`

**Step 1: Read the file**

```bash
cat docs/agents/ethical_hacker_agent.md
```

**Step 2: Decision**
- If it contains unique adversarial testing patterns → merge the key parts into `adversarial-logic-architect` skill
- If it's generic → delete entirely

```bash
# If deleting:
git rm docs/agents/ethical_hacker_agent.md

# If merging key parts into skill:
# Edit .claude/skills/adversarial-logic-architect/SKILL.md
# Then: git rm docs/agents/ethical_hacker_agent.md
```

**Step 3: Commit**

```bash
git commit -m "fix: remove orphaned ethical-hacker agent doc (merged into adversarial-logic-architect skill)"
```

---

## Wave 2: Legacy Code Audit (Agent-Driven)

### Task 6: Run legacy-code-auditor on full codebase

**Step 1: Launch legacy-code-auditor agent**

In Claude Code, run:
```
Use the legacy-code-auditor agent on the full codebase. Focus on:
1. Flutter: deprecated APIs, old Riverpod patterns (StateNotifier instead of Notifier, etc.), commented-out code, stale TODO comments
2. Python: deprecated Cloud Functions v1 patterns, old firebase-admin idioms, unused imports, commented code
3. E2E: deprecated Playwright APIs, old selector patterns
Report findings in a structured list with file:line references.
```

**Step 2: Review findings**

The agent will return a list. For each finding:
- **Deprecated API / pattern** → fix immediately (see Task 7)
- **Commented-out code** → delete immediately
- **Stale TODO** → either fix or delete the comment
- **False positive** → skip (CLAUDE.md warns about false positives in audits)

**Step 3: Apply fixes**

Batch similar fixes (all commented-out code in one commit, all deprecated API replacements in one commit).

**Step 4: Commit**

```bash
git commit -m "fix: remove all commented-out code and stale TODOs found by legacy audit"
git commit -m "fix: update deprecated Flutter/Python patterns to current idioms"
```

---

### Task 7: Fix specific known legacy patterns

**Flutter (check these files specifically):**

```bash
# Riverpod: find any StateNotifier usage (old pattern)
grep -r "StateNotifier\|StateNotifierProvider\|ChangeNotifier" origna_gta/lib/ --include="*.dart"

# Check for deprecated flutter_riverpod patterns
grep -r "ref.read.*provider.*notifier\|ProviderContainer" origna_gta/lib/ --include="*.dart"

# Commented out blocks
grep -rn "\/\/ TODO\|\/\/ FIXME\|\/\/ HACK\|\/\/ XXX\|\/\/.*disabled\|\/\/.*old\|\/\/.*remove" origna_gta/lib/ --include="*.dart" | head -30
```

**Python (check these files):**

```bash
# Old firebase-functions v1 patterns
grep -rn "functions\.https\.on_call\|@https_fn\." functions/ --include="*.py" | head -20

# Commented out blocks
grep -rn "# TODO\|# FIXME\|# HACK\|# OLD\|# REMOVE" functions/ --include="*.py" | head -30

# Unused imports
python3 -m py_compile functions/main.py 2>&1 | head -20
```

**E2E specs:**

```bash
# Old Playwright API patterns (page.waitForNavigation deprecated)
grep -rn "waitForNavigation\|waitForSelector\b" e2e/playwright_ui/ --include="*.ts"

# fill() usage (forbidden per CLAUDE.md — always use pressSequentially)
grep -rn "\.fill(" e2e/playwright_ui/ --include="*.spec.ts"
```

Fix each finding inline. No backward-compatibility shims — fix forward.

**Commit:**

```bash
git commit -m "fix: replace deprecated API calls — fill→pressSequentially, waitForNavigation→waitForURL"
```

---

## Wave 3: Skill Rewrites

### Task 8: Rewrite e2e-test-suites skill (CRITICAL — most stale skill)

**File:** `.claude/skills/e2e-test-suites/SKILL.md`

**What's wrong:**
- Says "9 files" → actually 34 files
- Says "279 E2E (9 files) + 288 Backend" → completely outdated
- Missing: 25 new spec files added after Feb 10 2026
- Root cause fixes section locked to Feb 2026 context

**Step 1: Count actual test cases in all specs**

```bash
grep -c "^  test(" e2e/playwright_ui/*.spec.ts 2>/dev/null || \
grep -c "test\(" e2e/playwright_ui/*.spec.ts | sort -t: -k2 -rn | head -40
```

**Step 2: Count backend tests**

```bash
find functions/tests -name "test_*.py" -o -name "*_test.py" | xargs grep -c "def test_" 2>/dev/null | awk -F: '{sum+=$2} END{print "Backend total:", sum}'
```

**Step 3: Rewrite the skill with accurate data**

The rewritten skill must include:
- Accurate file list (all 34 specs)
- Accurate test counts per file
- All api-helpers.ts exports (keep this section — it's accurate)
- Remove the "Run Progression" history table (stale, not useful for future sessions)
- Add the 7 new spec groups added after Feb 10 2026

**Template for new file list section:**
```markdown
## Test Suite (34 E2E Spec Files)

| File | Focus |
|------|-------|
| add-product-e2e.spec.ts | Product creation flow |
| admin-actions.spec.ts | Admin-only operations |
| admin-panel.spec.ts | Admin dashboard |
| admin-security.spec.ts | Admin access controls |
| buyer-flow.spec.ts | Full buyer journey |
| checkout-validation.spec.ts | Cart/checkout guards |
| digital-products-e2e.spec.ts | Digital product delivery |
| edge-cases-security.spec.ts | Adversarial scenarios |
| favorites.spec.ts | Wishlist operations |
| multi-seller-orders.spec.ts | Split-order handling |
| new-coverage-e2e.spec.ts | Gap coverage |
| new-notification-features.spec.ts | Push/in-app notifications |
| notifications.spec.ts | Notification flows |
| order-cancellation-refund.spec.ts | Cancel/refund lifecycle |
| order-lifecycle.spec.ts | Full order state machine |
| order-notifications.spec.ts | Order status emails |
| password-reset.spec.ts | Auth recovery |
| payment-edge-cases.spec.ts | Stripe edge cases |
| premium-subscription.spec.ts | Subscription lifecycle |
| profile-management.spec.ts | User profile CRUD |
| rate-limiting.spec.ts | Rate limit enforcement |
| return-request.spec.ts | Return/refund requests |
| search-products.spec.ts | Algolia search |
| seller-flow.spec.ts | Seller journey |
| seller-product-management.spec.ts | Seller CRUD |
| seller-registration.spec.ts | Stripe Connect onboarding |
| shipping-approval.spec.ts | Shipping workflow |
| shipping-calculation.spec.ts | Cost calculation |
| smoke-home-profile.spec.ts | Smoke tests |
| stock-notif.spec.ts | Back-in-stock alerts |
| stripe-payment.spec.ts | Payment pipeline |
| trending-products.spec.ts | Trending algorithm |
| warehouse-multi-location.spec.ts | Multi-warehouse ops |
| [34th spec] | [Focus] |
```

**Commit:**

```bash
git add .claude/skills/e2e-test-suites/SKILL.md
git commit -m "fix(skills): rewrite e2e-test-suites — 34 specs, remove stale Feb 2026 data"
```

---

### Task 9: Upgrade orchestrator skill with Claude cookbook patterns

**File:** `.claude/skills/orchestrator/SKILL.md`

**What to add (from Claude cookbook):**

**1. Evaluator-Optimizer Pattern**

```markdown
## Evaluator-Optimizer Pattern

Use when output quality is uncertain and needs iterative refinement.

### Structure
- **Generator agent**: Produces initial output
- **Evaluator agent**: Scores against criteria (correctness, completeness, security)
- **Loop**: If score < threshold → regenerate with evaluator feedback

### When to use
- Schema design (generate → logic-auditor evaluates → regenerate if CRITICAL findings)
- E2E test coverage (qa-engineer generates → code-reviewer evaluates → fill gaps)
- Security rules (firebase-architect generates → security-auditor evaluates)

### Command pattern
```bash
# Round 1: Generate
# Round 2: Evaluate with auditor
# Round 3: If findings > 0 → fix and re-evaluate
```
```

**2. Prompt Caching (for large reads)**

```markdown
## Prompt Caching — Cost Reduction

When reading large static files repeatedly (schema_constants, WORKFLOW_INDEX),
mark them as cacheable context to reduce token costs.

### Files worth caching across a session
- `docs/WORKFLOW_INDEX.md` — read once, reference multiple times
- `functions/schema_constants.py` + `origna_gta/lib/core/schema/schema_constants.dart`
- `docs/database_schema.json`

### Pattern: Read files once at session start, reference by name later
```

**3. Update Gemini model versions**

Replace all instances of:
- `gemini-2.0-flash` → `gemini-2.5-flash` (or latest)
- `gemini-1.5-pro` → `gemini-2.5-pro` (or latest)

Verify current Gemini model names before replacing.

**Commit:**

```bash
git add .claude/skills/orchestrator/SKILL.md
git commit -m "fix(skills): add evaluator-optimizer pattern, prompt caching, update Gemini model names"
```

---

### Task 10: Update payment-system skill with staging webhook failure

**File:** `.claude/skills/payment-system/SKILL.md`

**Add to Known Issues section:**

```markdown
## Active Incidents (check before debugging)

### Staging Webhook Failure (2026-02-24 onwards)
- **URL:** `https://northamerica-northeast1-orignagta-staging.cloudfunctions.net/stripe_webhook`
- **Symptom:** 3,655+ failed webhook retries, Stripe will stop retrying 2026-03-05
- **Impact:** Subscription invoices delayed ≤3 days; checkout.session.completed may not process
- **Action:** Fix staging deployment or disable this webhook endpoint in Stripe dashboard
- **Diagnostic:** Check Cloud Functions logs for staging webhook function errors

### Webhook OOM Fix (deployed)
- Default 256 MiB insufficient for stripe_webhook (processes orders + payouts + digital licenses)
- Fixed: `WEBHOOK_OPTIONS` uses `memory: options.MemoryOption.MB_512`
```

**Commit:**

```bash
git add .claude/skills/payment-system/SKILL.md
git commit -m "fix(skills): add staging webhook failure incident + OOM fix to payment-system skill"
```

---

### Task 11: Update qa-engineer skill with adversarial patterns

**File:** `.claude/skills/qa-engineer/SKILL.md`

**Add section: Adversarial Test Patterns (from Claude cookbook)**

```markdown
## Adversarial Test Patterns

### The 50+ Scenario Rule (from CLAUDE.md)
Every feature requires 50+ adversarial scenarios considered. Minimum checklist:

**Authentication Attacks**
- Expired token accepted
- Token from wrong environment (dev token on staging)
- Seller token used for buyer-only operation
- Admin token replayed after logout

**Payment Manipulation**
- Price tampered in checkout payload (backend must re-read from Firestore)
- Double-click checkout (idempotency key must deduplicate)
- Webhook replay (idempotency must block duplicate order creation)
- Self-purchase (seller cannot buy own product)

**Race Conditions**
- Two buyers purchase last item simultaneously (stock must go to ≥0)
- Order cancel + payment capture race (atomic check required)
- Concurrent coupon redemption (atomic limit enforcement)

**Data Isolation**
- Seller A reads Seller B's orders
- Buyer reads another buyer's private data
- Admin endpoint called without admin role

**Input Boundary**
- Empty strings, null, undefined in all required fields
- Max-length strings (test 1000+ char product names)
- Negative prices, zero stock, past expiry dates
```

**Commit:**

```bash
git add .claude/skills/qa-engineer/SKILL.md
git commit -m "fix(skills): add adversarial test pattern checklist to qa-engineer skill"
```

---

### Task 12: Update full-stack-audit skill with missing file pairs

**File:** `.claude/skills/full-stack-audit/SKILL.md`

**Add missing pairs:**

```markdown
### 8. Digital Products
- `origna_gta/lib/features/products/digital_product_provider.dart` ↔ `functions/handlers/digital.py`

### 9. Premium Subscription
- `origna_gta/lib/features/premium/premium_provider.dart` ↔ `functions/handlers/subscriptions.py`

### 10. Returns
- `origna_gta/lib/features/orders/return_provider.dart` ↔ `functions/handlers/returns.py`

### 11. Notifications
- `origna_gta/lib/features/notifications/notifications_provider.dart` ↔ `functions/handlers/notifications.py`
```

First verify these files actually exist:

```bash
find origna_gta/lib -name "*digital*" -o -name "*premium*" -o -name "*return*" -o -name "*notif*" | grep -v ".dart_tool" | head -20
find functions/handlers -name "*.py" | sort
```

Only add pairs for files that exist.

**Commit:**

```bash
git add .claude/skills/full-stack-audit/SKILL.md
git commit -m "fix(skills): add digital, premium, returns, notifications pairs to full-stack-audit"
```

---

### Task 13: Add model-selection guidance to orchestrator skill

**File:** `.claude/skills/orchestrator/SKILL.md`

**Add section: Claude Model Selection**

```markdown
## Claude Model Selection (Cost vs. Quality)

| Model | Use When | Avoid When |
|-------|----------|------------|
| `claude-haiku-4-5` | Classification, simple extraction, schema validation, status checks | Complex reasoning, multi-file analysis |
| `claude-sonnet-4-6` | Code generation, audit tasks, most subagents | Trivial single-field lookups |
| `claude-opus-4-6` | Architecture decisions, security design, adversarial analysis | High-volume tasks (cost) |

### Decision Rule
- **Single file, simple answer** → Haiku
- **Multi-file analysis, code generation** → Sonnet (default)
- **System-wide architecture, adversarial design** → Opus

### Cost Optimization
- Always prefer Haiku for the "evaluator" role in evaluator-optimizer loops
- Use Sonnet for the "generator" role
- Reserve Opus for final synthesis only
```

**Commit:**

```bash
git add .claude/skills/orchestrator/SKILL.md
git commit -m "fix(skills): add Claude model selection matrix to orchestrator skill"
```

---

## Wave 4: Full Codebase Audit

### Task 14: Run 10 specialized agents in parallel

**This is the honest verdict. No cherry-picking results.**

Launch all agents simultaneously from a single Claude Code message:

```
Run these 10 agents in parallel. Each should audit its domain fully and report ALL findings — do not filter. Be honest:

1. legacy-code-auditor — full codebase sweep
2. security-auditor — Firestore rules + backend auth + input validation
3. payment-auditor — checkout → payment → capture → refund pipeline
4. order-lifecycle-auditor — every order state transition
5. cross-stack-auditor — ALL frontend↔backend interfaces
6. schema-sync-checker — ALL 6 schema layers in sync
7. frontend-auditor — Riverpod providers, error/loading states, premium gates
8. auth-onboarding-auditor — rate limiting, Stripe Connect, MFA, role assignment
9. performance-auditor — N+1 reads, unbounded queries, cold starts
10. cron-jobs-auditor — idempotency, auto-confirm timing, error isolation
```

**Step 2: Triage findings**

For each finding:
- **CRITICAL**: Fix before any deploy
- **HIGH**: Fix in current sprint
- **MEDIUM**: Log in TODOS.md
- **LOW**: Log in TODOS.md, defer
- **FALSE POSITIVE**: Mark as such with evidence

**Step 3: Create follow-up tasks for CRITICAL/HIGH findings**

Each CRITICAL finding becomes a new task in the current session or a new plan.

**Step 4: Commit audit results**

```bash
git add TODOS.md
git commit -m "chore: triage full 10-agent audit — CRITICAL/HIGH findings logged"
```

---

## Wave 5: Verification

### Task 15: Verify skills are loadable and accurate

```bash
# Check all skill files are valid markdown
for f in .claude/skills/*/SKILL.md; do
  echo "Checking: $f"
  head -3 "$f"
  echo "---"
done
```

### Task 16: Run one E2E smoke test to confirm spec changes didn't break anything

```bash
npx playwright test e2e/playwright_ui/smoke-home-profile.spec.ts \
  --config=e2e/playwright.config.dev.ts \
  --reporter=line
```

Expected: All smoke tests pass.

### Task 17: Final commit

```bash
git add -A
git status  # should be clean after all waves
git log --oneline -10  # verify all wave commits
```

---

## Summary of Changes

| Wave | Files Changed | Commits |
|------|--------------|---------|
| 1: Dead removal | 6 files deleted, 2 updated | 5 commits |
| 2: Legacy code | Various Flutter/Python/E2E | 2+ commits |
| 3: Skill rewrites | 5 skill SKILL.md files | 5 commits |
| 4: Audit | TODOS.md + fixes | 1+ commits |
| 5: Verify | — | 0 |

**Total: ~13+ commits, all atomic, all reversible**
