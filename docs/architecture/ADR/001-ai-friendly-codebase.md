# ADR 001: AI-Friendly Codebase Optimization

## Status
Accepted (Feb 26, 2026)

## Context
As the project scales and the solo founder (Yunior) relies heavily on AI agents (Gemini, Claude Code, Copilot) for development, the codebase must be optimized for "Agent Legibility." Traditional project structures often lead to context window exhaustion or "file-hopping" confusion.

## Decision
We will implement an "LLM-native" codebase structure to maximize AI productivity and accuracy.

### Key Changes
1.  **Context Locality:** Organize code by feature (Vertical Slice Architecture).
2.  **Explicit Metadata:** Use `llms.txt` and `llms-full.txt` at the root as a "dense map."
3.  **Hierarchical Rules:** Use nested `CLAUDE.md` and `GEMINI.md` for local rules.
4.  **Verification Chains:** All code changes MUST include a verification command in the local `CLAUDE.md`.
5.  **No Legacy Handling:** Explicitly forbidden to maintain backward compatibility in the pre-launch phase.

## Consequences
- **Positive:** Improved AI accuracy, faster onboarding for new agents, reduced token costs.
- **Negative:** Slightly more overhead for documentation and maintaining metadata files.
- **Ongoing:** All agents must update `llms.txt` when adding new features or modules.
