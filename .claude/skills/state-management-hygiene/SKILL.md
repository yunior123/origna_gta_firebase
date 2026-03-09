---
name: state-management-hygiene
description: Best practices and checklist for Flutter state management hygiene. Use when auditing or refactoring providers.
---

# State Management Hygiene Skill

## Checklist
1. **Disposal**: Does every finite-lived state holder get disposed?
2. **Immutability**: Are state objects immutable where appropriate?
3. **Rebuilds**: Is the provider scoped as deeply as possible to avoid rebuilding the whole screen?
4. **Side Effects**: Are side effects (API calls, navigation) handled outside the build method?
