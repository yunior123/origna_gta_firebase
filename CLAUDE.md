# CLAUDE.md

## 📥 AUTO-LOADED CONTEXT
@~/.claude/LEARNED.md
@docs/REPO_MAP.md
@docs/AGENT_GUIDE.md
@STATE.md

## 🚀 WORKFLOW LIFECYCLE (GSD FUNNEL)
Operate using a strict **Research → Strategy → Execution → Verification** funnel.

1.  **RESEARCH:** Map the codebase, validate assumptions, identify dependencies, and reproduce issues before proposing fixes.
2.  **STRATEGY:** Formulate a plan, discuss technical decisions (avoid "reasonable defaults"), and define the verification criteria.
3.  **EXECUTION (WAVES):** Implement tasks in atomic units. For complex features, break them into "waves" of parallelizable or sequential sub-tasks.
4.  **VERIFICATION:** Run automated tests, perform cross-stack checks, and verify against requirements.

## 🧠 CONTEXT ENGINEERING
- **Lean Sessions:** Keep the main session context window lean (~30-40% usage). Use `/clear` and resume from `STATE.md` if quality drops.
- **Sub-Agent Orchestration:** Delegate heavy lifting (code analysis, audit, refactoring) to specialized sub-agents in fresh context windows.
- **Source of Truth:** `STATE.md` is the living document for session progress, decisions, and blockers.

## 📝 PLANNING RULES
- **XML Structure:** For complex tasks, create a plan using XML-like tags (`<task>`, `<action>`, `<verify>`) to ensure precision.
- **Atomic Commits:** Every distinct task or fix MUST be proposed as an atomic git commit. One task = one commit.
- **No Deferral:** Forbidden to defer or skip tasks unless explicitly approved by Yunior. No loose ends.

## 📏 ENGINEERING RULES
1. **CHAIN OF VERIFICATION:** First answer the question. Second, list at least 3 ways your answer could be wrong. Third, verify your concern and update your answer. 
2. **NO LEGACY:** Using the word "legacy" is forbidden. No backward compatibility handling—we fix forward. DB is empty, launch is in 10-25 days.
3. **PRODUCTION:** 1.Production website is `www.orignagta.ca` (NOT .com).2. Premium users can have access to chat, phot reviews, only premium users, it would cost too much to have those features for everyone, we are supposed to distinguish premium from non-premium.3. audit reports may contain false positives, so be carefull, the source of truth is ClAUDE.md 4. chat should have limitations to avoid long conversations and abbuse of the system.5. improve pre push hooks all the time to prevent bugs.6.test against emulators are forbidden given that the mac only has 8gb of ram, so test against dev firebase.7. everytime u run tests, u put the info in the STATE.md file.8. if u find an issue and cannot solve it at the end then u can added to state.md as a blocker or as a task to be solved later, any findings should be documented in the STATE.md file.9. no magic strings in the code.10. enforce clean project structure, files inside folders as needed, etc 11. when auditing be honest, dont try to please me.12. tests must cover all flows and the whole repo, as a solo developer I rely only on ai and automated tests to test, ai is the qa team. 13. no post launch tasks, all tasks are for now 14. before running playwright make sure that the cloud services are updated, like firebase, algolia, etc
4. **COMPLIANCE:** All code must comply with Canadian (including Quebec Bill 96/Law 25) and international laws.
5. **AUTOMATION:** Do all work using tools (Stripe CLI, gcloud, firebase, etc.). Avoid asking Yunior for manual setup.
6. **DEPLOYMENT:** Every deploy (indexes, rules, functions) MUST target dev, staging, and prod.
6a. **RAM CONSTRAINT:** Mac has only 8GB RAM — Claude has crashed it 11+ times. Run tasks sequentially, never in parallel. No emulators. No simultaneous heavy processes. Close unused tools before heavy work.
7. **PLAYWRIGHT:** 
    - Tests must be fast. If they take >1h, stop and analyze.
    - Save screenshots to desktop for UI/UX feedback.
    - Profile mode (staging) MUST pass `--dart-define=FORCE_SEMANTICS=true`.
8. **LOGIC FIRST:** 50+ adversarial scenarios (malicious users, race conditions). Think like Magnus Carlsen.
9. **FUTURE PROOF:** Schema must scale to 100M+ users without migrations.
10. **CROSS-STACK:** Python ↔ Dart ↔ Schema synchronization is mandatory.
11. **NO MAGIC STRINGS:** Use constants from `schema_constants`.
12. **SIDE EFFECTS:** Changing one line → update EVERY file impacted (Tests, Rules, Indexes, Schema, Playwright).
13. **TESTING:** Every new feature or bug fix MUST include tests.
15. **SINGLE BRANCH POLICY:** ONLY the `main` branch is allowed in this project. Do not create, use, or merge other branches. Work directly on `main` to avoid parallel history conflicts and complex merge resolutions.

---

## 🏗 PROJECT: OrignaGta
- **Marketplace:** Canadian buyers only, worldwide sellers.
- **Tech Stack:** Flutter/Riverpod + Python Cloud Functions/Pydantic + Firestore + Stripe Connect + Algolia + R2/Cloudflare + Sentry.
- **Architecture:** MVVM w/ Riverpod (Screens = 0 logic). Idempotency for payments. Eventual consistency.

## 🗂 HIERARCHICAL CONTEXT
- **Backend:** `functions/CLAUDE.md`
- **Frontend:** `origna_gta/CLAUDE.md`
- **E2E/Flows:** `e2e/README.md`, `origna_flows/INSTRUCTIONS.md`
- **Deep Context:** `docs/WORKFLOW_INDEX.md`, `docs/REPO_MAP.md`, `docs/AGENT_GUIDE.md`

## 🤖 SPECIALIZED AGENTS
- **Logic Auditor:** Run before 3+ file edits.
- **Payment Auditor:** Run after payment changes.
- **Schema Sync:** Run after `schema_constants` changes.
- **Firebase Architect:** Run after Firestore/Rules changes.
- **Repomix Analyzer:** Run for system-wide drift checks.

## 🌍 ENVIRONMENTS
| Env | Firebase Project | Playwright Config |
|-----|------------------|-------------------|
| dev | `orignagta-dev` | `playwright.config.dev.ts` |
| staging | `orignagta-staging` | `playwright.config.staging.ts` |
| prod | `orignagta` | ❌ never |

