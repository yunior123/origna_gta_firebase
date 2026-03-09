---
name: orchestrator
description: Multi-model AI orchestration protocol. Use this skill before coordinating Gemini CLI, Claude subagents, or parallel AI tasks. Defines routing rules, Gemini CLI command patterns, filesystem-as-state, and synthesis patterns.
---

# Multi-Model Orchestration Skill

## Overview

This skill governs how Claude Code orchestrates multiple AI models for complex tasks:
- **Gemini CLI** (`gemini`) — 1M-token context, built-in Google Search, large codebase dumps, web research
- **Claude Subagents** — domain specialists (`logic-auditor`, `payment-auditor`, etc.), code generation
- **Bash tools** — direct execution, file I/O, CLI tools (Stripe, Firebase, gcloud)

---

## Routing Decision Matrix

| Task Type | Route To | Reason |
|-----------|----------|--------|
| Large codebase analysis (>50 files) | Gemini CLI | 1M token context |
| Web research + synthesis | Gemini CLI | Native Google Search |
| Competitive intelligence | Gemini CLI | Web access + large context |
| Security/logic audit | Claude subagent (`logic-auditor`) | Deep reasoning, domain memory |
| Payment/schema changes | Claude subagent (`payment-auditor`) | Specialized domain knowledge |
| Cross-stack drift check | Claude subagent (`cross-stack-auditor`) | Knows both stacks |
| Repomix snapshot analysis | Claude subagent (`repomix-analyzer-agent`) | Handles full codebase XML |
| Single-file analysis | Direct Read + reasoning | No overhead needed |
| CLI operations (gcloud/firebase/stripe) | Bash tool | Direct execution |
| Parallel independent tasks | Multiple Task calls in one message | Max parallelism |

---

## Gemini CLI Command Patterns

### Basic Headless Call
```bash
gemini -p "YOUR PROMPT" --yolo
```

### With Model Selection (ALWAYS use highest available model)
```bash
# DEFAULT: Always use gemini-3.1-pro-preview (or higher if available)
gemini -m gemini-3.1-pro-preview -p "PROMPT" --yolo

# NEVER use gemini-2.5-flash, gemini-2.5-pro, or any 2.x model — they sabotage output quality
```

### With Specific Directory Context
```bash
gemini --include-directories /path/to/dir -p "PROMPT" --yolo
```

### With File Piped as Context
```bash
cat /path/to/file.txt | gemini -p "Analyze this: PROMPT" --yolo
```

### JSON Output for Structured Data
```bash
gemini -p "Return JSON only: PROMPT" --output-format json --yolo
```

### Save Output to Filesystem-as-State
```bash
gemini -p "PROMPT" --yolo > .orch/results/gemini-task-name.txt 2>&1
```

---

## Model Selection Rules

```
ALL Gemini tasks → gemini-3.1-pro-preview (or highest model in /model list)
NEVER use gemini-2.5-flash or gemini-2.5-pro — always prefer top model
Domain audits (payment, security, schema, orders) → Claude subagent
Parallel independent work → multiple Task tool calls simultaneously
```

---

## Filesystem-as-State Pattern

For multi-step orchestration, use `.orch/` as shared state:

```
.orch/
  tasks/          # JSON task queue
  results/        # Raw output from each agent/model
  synthesis/      # Final synthesized output
```

**Create a task file:**
```bash
mkdir -p .orch/tasks .orch/results .orch/synthesis
echo '{"id":"t1","type":"gemini","model":"gemini-3.1-pro-preview","prompt":"..."}' > .orch/tasks/t1.json
```

**Execute and store result:**
```bash
gemini -p "$(cat .orch/tasks/t1.json | jq -r .prompt)" --yolo > .orch/results/t1.txt 2>&1
```

**Synthesize:**
Read all result files, synthesize in Claude's context, write to `.orch/synthesis/final.md`.

---

## Parallel Execution Protocol

When you have N independent tasks:

1. **Identify dependencies** — only parallelize tasks with no shared state dependency
2. **Assign routing** — apply the routing matrix for each task
3. **Launch simultaneously** — for Claude subagents, call multiple `Task` tool uses in ONE message
4. **For Gemini tasks** — use Bash `run_in_background: true` for each
5. **Collect** — wait for all to complete, then synthesize

```
PARALLEL:
  Task A: gemini -p "..." > .orch/results/a.txt [background]
  Task B: Claude subagent [background]
  Task C: gemini -p "..." > .orch/results/c.txt [background]
THEN: Synthesize a.txt + b result + c.txt
```

---

## Quality Gate

Before marking orchestration complete:
- [ ] All launched tasks completed (no pending background tasks)
- [ ] Results are non-empty and coherent
- [ ] Cross-model conflicts surfaced explicitly (don't silently pick one)
- [ ] Synthesis cites which model produced which finding
- [ ] Filesystem state cleaned up if ephemeral (`.orch/` removed if not needed)

---

## Example Invocations

### Codebase Architecture Analysis via Gemini
```bash
find . -name "*.py" -not -path "*/node_modules/*" | head -100 | xargs cat | \
  gemini -m gemini-3.1-pro-preview -p "Analyze this Python backend codebase. Identify: 1) architecture patterns, 2) potential bugs, 3) missing features. Be specific with file:line references." \
  --yolo
```

### Competitive Research
```bash
gemini -m gemini-3.1-pro-preview -p "Search the web for: how do top e-commerce apps handle multi-seller cart splitting? Compare Medusa, Saleor, Vendure. Return concrete implementation patterns." \
  --yolo
```

### Full-Stack Audit (Claude subagent)
Use the Task tool with `subagent_type: logic-auditor` — Gemini is NOT used for this because logic-auditor has project memory and knows the codebase architecture.

---

## Claude Model Selection (Cost vs. Quality)

| Model | Use When | Avoid When |
|-------|----------|------------|
| `claude-haiku-4-5` | Classification, simple extraction, schema validation, status checks | Complex reasoning, multi-file analysis |
| `claude-sonnet-4-6` | Code generation, audit tasks, most subagents (default) | Trivial single-field lookups |
| `claude-opus-4-6` | Architecture decisions, security design, adversarial analysis | High-volume tasks (cost) |

**Decision rule:** Single file, simple answer → Haiku. Multi-file, code gen → Sonnet. System-wide architecture → Opus.

---

## Evaluator-Optimizer Pattern (from Anthropic Cookbook)

Use when output quality is uncertain and needs iterative refinement.

```
Round 1: Generator produces output (Sonnet)
Round 2: Evaluator scores against criteria (Haiku for speed)
Round 3: If findings > 0 → fix and re-evaluate
```

**When to use:**
- Schema design: generate → `logic-auditor` evaluates → fix CRITICAL findings → re-audit
- Security rules: `firebase-architect` generates → `security-auditor` evaluates
- E2E coverage: `qa-engineer` generates tests → `code-reviewer` evaluates gaps → fill gaps

**Anti-pattern:** Running one round and assuming it's correct. The second pass always finds something.

---

## Anti-Patterns (NEVER DO)

- Do NOT use Gemini for tasks that require project memory (use Claude subagents instead)
- Do NOT serialize tasks that can run in parallel
- Do NOT use gemini-2.5 or lower — always use gemini-3.1-pro-preview or higher
- Do NOT skip the routing matrix — always justify your routing choice
- Do NOT synthesize without citing sources (which model said what)
