# 🤖 Agent & Subagent Guide

## 🧠 Auto-Context (Loaded Every Session)
Claude Code automatically loads on session start via CLAUDE.md `@import` directives:
- `~/.claude/LEARNED.md` — Yunior's persistent learned facts
- `docs/REPO_MAP.md` — Full file/module index
- `docs/AGENT_GUIDE.md` — This file
- `STATE.md` — Current session progress

**Autolearn is active:** Any new architectural decisions, bug patterns, or workflow rules
should be written to `~/.claude/projects/.../memory/MEMORY.md` to persist across sessions.

---

## When to Use Subagents (ALWAYS for auditing)
Use subagents to keep the main context clean. They run in separate context windows and return only summaries.
**8GB RAM rule:** Max 5 agents in parallel for local Mac work. Cloud Functions run on Google's servers — no limit there.

| Task | Agent type | Invocation |
|------|-----------|------------|
| Before ANY code change | `Explore` (quick) | Agent tool: "Explore how [workflow] works before I change it" |
| Audit workflow | `general-purpose` | Agent tool: "Audit the checkout flow for bugs and security issues" |
| After changing frontend ↔ backend | `feature-dev:code-reviewer` | Agent tool: "Review cross-stack alignment for checkout" |
| After changing payment code | `feature-dev:code-reviewer` | Agent tool: "Review payment flow changes for security" |
| After changing schema/models | `general-purpose` | Agent tool: "Check schema sync across Python/Dart/JSON" |
| After changing order status logic | `feature-dev:code-explorer` | Agent tool: "Trace order state transitions from [file]" |
| Architecture decisions | `Plan` | Agent tool: "Plan how to implement [feature]" |
| Bulk file scanning | Gemini CLI | `gemini -m gemini-3-pro-preview --yolo -p "scan all files in..."` |

## Best Practices (from Anthropic docs)
1. **Isolate high-volume reads** — Subagents read 10-15 files without cluttering main context
2. **Chain agents** — First explore with `Explore`, then fix, then verify with `feature-dev:code-reviewer`
3. **Parallel research (max 5 agents)** — "Use subagents to investigate auth, payments, and orders in parallel"
4. **Foreground vs background** — Use foreground when you need results before proceeding; background (run_in_background=true) for audits while continuing work
5. **Resume subagents** — Pass agent ID from previous invocation to resume with full context
6. **Delegate investigation** — "Use a subagent to investigate how [feature] works" (preserves main context)
7. **Gemini for bulk work** — Large codebase scans, translation drafts, boilerplate. Always review before applying.
8. **Always verify agent fixes** — After agents complete, run `pytest` (backend) or `flutter analyze` (frontend). Trust but verify.

## Mandatory Agent Usage Rules
- **RULE: Before editing 3+ files → run `Explore` agent on that workflow FIRST**
- **RULE: After editing payment files → run `feature-dev:code-reviewer` IMMEDIATELY**
- **RULE: After editing schema_constants → run schema sync check agent IMMEDIATELY**
- **RULE: After editing order handler → run `feature-dev:code-explorer` to trace state IMMEDIATELY**
- **RULE: Audit results with 0 CRITICAL findings → proceed. Any CRITICAL → fix before committing**
- **RULE: After any agent completes → run verification (flutter analyze / pytest) before accepting fixes**

## Slash Commands for Auditing
- `/audit-workflow [name]` — Run full logic audit on a workflow
- `/check-schema-sync` — Verify all 6 schema layers are in sync
- `/cross-stack-check` — Compare all frontend ↔ backend file pairs

---

## 🤖 AI Delegation System (Token Saving)

Use the `delegate` shell command to offload tasks to external AI tools.
All run under Yunior's existing subscriptions — **zero extra cost**.

```bash
delegate gemini      "explain this service architecture..."
delegate grok        "what's the best approach for real-time inventory..."
delegate copilot     "how do I fix this Dart null-safety error..."
delegate antigravity "review this payment handler for bugs..."

# From file (for long prompts)
delegate gemini --file /tmp/task.txt

# From stdin
cat functions/handlers/orders.py | delegate gemini "find all race conditions"
```

| Model | When to Use | Speed |
|-------|------------|-------|
| **codex** | OpenAI Codex (gpt-5.3-codex), code tasks, reasoning | ~5-15s |
| **copilot** | Git/code suggestions, shell commands, quick answers | ~5-10s |
| **gemini** | Bulk analysis, doc gen, translation drafts, boilerplate | ~30-60s |
| **grok** | Latest AI reasoning, real-time info, second opinion | ~30-60s |
| **antigravity** | Code review, Gemini 3.1 + Sonnet 4.6, IDE context | ~30-60s |

### Setup Status
- ✅ **Codex** — ready (gpt-5.3-codex, yuniorrodriguezo460@gmail.com)
- ✅ **Copilot** — ready (`gh copilot` v0.0.418)
- ✅ **Gemini** — ready (19 cookies from viral-video-pipeline)
- ✅ **Antigravity** — ready (CASCADE agent + file-based I/O via AppleScript)
- ⚠️ **Grok** — needs one-time setup: `bash ~/.claude/ai_delegates/setup_grok_cookies.sh`

### Files
```
~/.claude/ai_delegates/
  ai_chat.py            — main hub (gemini/grok/copilot/antigravity)
  delegate              — shell wrapper (in PATH)
  antigravity_chat.py   — Antigravity HTTP + AppleScript
  setup_cookies.py      — cookie extractor
  setup_grok_cookies.sh — Grok interactive login (run once)
  cookies/
    gemini_cookies.json — 19 session cookies
    grok_cookies.json   — empty until setup_grok_cookies.sh run
```

### Rules
- **Use for bulk/secondary tasks** — don't delegate security-critical decisions
- **Always review Gemini/Grok output** — treat as junior dev, not ground truth
- **Copilot is synchronous** — blocks the Bash call until complete; fine for quick queries
- **Antigravity requires the app to be running** — check it's open before delegating

---

## 🗂️ AI Flow Bundles — `origna_flows/` + `scripts/collect_flow_files.py`

Use flow bundles to upload to Claude.ai for deep per-flow auditing without token waste.

### Generate bundles
```bash
python3 scripts/collect_flow_files.py
# → ~/Desktop/origna_flows/<flow_name>/  (62 flows, ≤20 files, ≤700 KB each)
```

### Two bundle types

| Type | Example | Drop into Claude.ai and ask |
|------|---------|-----------------------------|
| **Audit flow** | `checkout_payment/` | "Audit this flow. Find all bugs, security issues, race conditions." |
| **Test flow** | `test_stripe_payment/` | "Read the spec. Find gaps. Write new tests covering [scenario]." |

### Every bundle contains
1. `CLAUDE.md` — project-wide rules and anti-patterns
2. `INSTRUCTIONS.md` — per-flow audit checklist (auto-generated)
3. For **test flows**: spec file + `api-helpers.ts` + `flutter-helpers.ts` (highest priority)
4. `origna_flows/SEMANTICS.md` — Flutter Key/label/role map → use for Playwright `getByRole` / `[aria-label]`
5. `origna_flows/FLOWS.md` — 15 user journeys with test assertions
6. Relevant source files (screens, viewmodels, handlers, schema)

### 27 test-centered flows (one per spec)
`test_add_product` · `test_admin_actions` · `test_admin_panel` · `test_admin_security` ·
`test_buyer_flow` · `test_checkout_validation` · `test_digital_products` · `test_edge_cases_security` ·
`test_favorites` · `test_multi_seller_orders` · `test_new_coverage` · `test_order_cancellation` ·
`test_order_lifecycle` · `test_payment_edge_cases` · `test_premium_subscription` · `test_profile_management` ·
`test_rate_limiting` · `test_search_products` · `test_seller_flow` · `test_seller_product_management` ·
`test_seller_registration` · `test_shipping_approval` · `test_shipping_calculation` · `test_smoke_home_profile` ·
`test_stripe_payment` · `test_trending_products` · `test_warehouse_multi_location`

### Flutter selector rules (critical for test flows)
- ✅ `getByRole('button', { name: /Add to Cart/i })` — buttons use text as label
- ✅ `page.locator('[aria-label^="product-card-"]')` — containers use `aria-label` attribute
- ✅ `page.locator('[aria-label="key-name"]')` — Semantics(label:) → aria-label attribute
- ❌ NEVER search by display text like `getByText('No Platform Fee')` — not in Flutter's DOM
- ❌ `fill()` never works in Flutter Web — always use `pressSequentially()`

---

## 📚 Workflow-Indexed File Reading (RAG Chunking)

**CRITICAL: Never edit a file in isolation. Always read the FULL file group for that workflow first.**

### Step 1: Identify the Workflow
Consult `docs/WORKFLOW_INDEX.md` to find which workflow the change belongs to.

### Step 2: Read ALL Files in the Group (Chunked)
Read files in this order — frontend first, then backend, then schema, then tests:

**Example: Checkout workflow → read these 12 files BEFORE making any change:**
```
CHUNK 1 (Frontend): checkout_screen.dart, checkout_provider.dart, cart_provider.dart
CHUNK 2 (Backend): payment_stripe.py, orders.py, shipping_service.py
CHUNK 3 (Schema): schema_constants.py, schema_constants.dart, database_schema.json
CHUNK 4 (Tests): test_payment_stripe.py, test_shipping_service.py, checkout e2e
```

### Step 3: Cross-Reference Before Editing
- Compare Dart field names with Python field names
- Compare Dart enums with Python enums
- Compare request payloads with handler expectations
- Compare error handling (what frontend expects vs what backend returns)

### Step 4: After Editing, Re-Read Impacted Files
If you changed `payment_stripe.py`, re-read `checkout_provider.dart` to verify the interface still matches.

### Workflow Quick-Index
| Workflow | Key Files to Read Together |
|----------|--------------------------|
| Checkout | `checkout_provider.dart`, `payment_stripe.py`, `shipping_service.py`, `schema_constants.*` |
| Orders | `seller_orders_viewmodel.dart`, `buyer_orders_viewmodel.dart`, `orders.py`, `cron_jobs.py`, `order_models.*` |
| Products | `add_product_viewmodel.dart`, `products.py`, `product_models.*`, `schema_constants.*` |
| Auth | `auth_provider.dart`, `admin.py`, `user_models.*`, `firestore.rules` |
| Payments | `checkout_provider.dart`, `payment_stripe.py`, `orders.py`, `cron_jobs.py` |
| Schema | ALL `schema_constants.*`, ALL `models/*`, `database_schema.json`, `firestore.rules` |

---

## 🔄 Session Management (Context Hygiene)

- `/clear` between unrelated tasks — don't pollute context
- `/compact Focus on [current workflow]` when context is getting full
- `/rewind` if Claude goes off track — cheaper than correcting
- After 2 failed corrections → `/clear` and start fresh with a better prompt
- Context fills fast with file reads. Delegate investigation to subagents to preserve main context
- Use `--continue` to resume sessions across terminal restarts
- Use `/pause-work` before ending a session to save state
- Use `/resume-work` to pick up where you left off

---

## 🧹 Daily Workflow Hygiene

### Plan Mode is Mandatory
- **For ANY non-trivial task**, always ask for a plan first: "Plan how to implement [feature]"
- Review and refine the plan before giving the green light to write code
- Use `/plan-task [description]` to formalize the planning step
- Never allow direct implementation of complex features without an approved plan

### Aggressive Context Clearing
- **Clear at ~60k tokens or 30% context capacity** — whichever comes first
- Context rot degrades response quality — Claude loses focus and starts hallucinating
- Use `/clear-context` before clearing to run the safety checklist
- Use `/compact Focus on [current task]` when context is bloated but has useful info
- After **2 failed correction attempts** → `/clear` and start fresh with a better prompt
- After `/clear`, always start with: `Read STATE.md and CLAUDE.md to restore context`

### Visual Context for UI Work
- **Drag and drop screenshots** of mocks or current bugs directly into the chat
- Claude compares visual inputs to code — this produces significantly better UI matches
- For UI bugs: screenshot the bug + screenshot the expected behavior = fastest fix
- For new screens: provide a Figma screenshot or hand-drawn wireframe before coding

### Session Rotation Best Practices
- Prefer **short, focused sessions** (1 workflow per session) over marathon multi-topic sessions
- **Delegate investigation** to subagents — preserve main context for action
- Use **background agents** (Ctrl+B) for audits while you continue working
- Each session should have a clear goal stated upfront: "This session: fix checkout flow"
- End every session with `/pause-work` to save state for the next session

### Context Budget Guidelines
| Context Usage | Action |
|--------------|--------|
| 0-30% | ✅ Healthy — continue working |
| 30-50% | ⚠️ Consider `/compact` to trim noise |
| 50-70% | 🔶 Use `/clear-context` checklist, save state |
| 70%+ | 🔴 Mandatory `/clear` — quality is degrading |
