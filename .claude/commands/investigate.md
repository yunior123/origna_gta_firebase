# /investigate — Delegate research to a subagent

Investigate a topic using a subagent to preserve main context.

## Input
$ARGUMENTS = topic or question to investigate

## What to do:

1. Launch a subagent with this prompt:

```
Investigate: $ARGUMENTS

Context: This is the OrignaGta project — an e-commerce marketplace serving Canadian buyers, with sellers worldwide, built with Flutter + Firebase + Stripe Connect.

Your task:
1. Read docs/WORKFLOW_INDEX.md to understand the project structure
2. Search for all files related to "$ARGUMENTS"
3. Read the relevant files thoroughly
4. Analyze:
   - How does this feature/system currently work?
   - What files are involved?
   - What are the key data flows?
   - Are there any potential issues or inconsistencies?
   - What tests cover this area?

Return a concise summary with:
- **How it works**: [2-3 sentence explanation]
- **Key files**: [list with one-line description of each]
- **Data flow**: [step by step]
- **Potential issues**: [any bugs, gaps, or inconsistencies found]
- **Test coverage**: [what's tested, what's not]
```

2. Wait for the subagent's response
3. Present the summary to the user in the main conversation
4. The main context stays clean — no file reads polluting it
