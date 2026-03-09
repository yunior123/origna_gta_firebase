---
paths:
  - "firestore.rules"
  - "**/auth*"
  - "**/admin*"
  - "**/rate_limiter*"
  - "**/security*"
---

# Security Rules

- Assume attackers. Server-side validation for everything. Never trust frontend.
- Self-purchase blocked, role-gated ops, MFA for role changes, rate limiting.
- Webhook HMAC verification. Idempotency keys. Atomic stock transactions.
- Firestore rules = defense-in-depth (backend validates first).
