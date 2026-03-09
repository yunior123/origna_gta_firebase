---
name: adversarial-logic-architect
description: Use when designing or reviewing security-critical features, anticipating malicious user behavior, race conditions, or system-wide edge cases in OrignaGTA.
---

# Adversarial Logic Architect Skill

## Instructions

1.  **50+ Adversarial Scenarios**:
    - For every new feature, predict 5+ ways a user or bot could abuse it.
    - Examples: `price_tampering`, `stock_race_condition`, `seller_self_purchase`, `unauthorized_refund`, `mfa_bypass`, `fcm_token_spoofing`.

2.  **Logic-First Architecture (Magnus Carlsen)**:
    - Think 5-10 steps ahead. If the seller does X, and the buyer does Y, and Stripe does Z, what is the final state?
    - Use `@firestore.transactional` for all state-dependent writes.
    - Use idempotency keys for all transactional requests.

3.  **No Trusting the Client**:
    - Assume EVERY value from the Flutter app is malicious or incorrect.
    - Re-fetch `price`, `stock`, `status`, and `uid` from Firestore during Backend processing.

4.  **Security Rules as a Shield**:
    - Use `rules_version = '2';`.
    - Validate every field's type, size, and presence.
    - Prevent changing immutable fields (e.g., `ownerId`, `orderId`) during updates.

5.  **Role-Based Auditing**:
    - Verify that `isAdmin()`, `isSeller()`, and `isOwner()` are checked in BOTH rules and handlers.

6.  **Concurrency Management**:
    - Identify potential race conditions (e.g., two buyers buying the last item simultaneously).
    - Use atomic increments (`firestore.Increment(1)`) for stock/metrics.

## Checklist
- [ ] 5+ adversarial scenarios documented for this feature.
- [ ] No values trusted from the client (re-fetched from DB).
- [ ] All state-dependent writes are inside transactions.
- [ ] Idempotency keys used for all external API calls (Stripe, etc.).
- [ ] Security rules protect immutable fields during updates.
- [ ] Rate limits exist for all user-facing endpoints.

## Rationale
- High-scale systems attract malicious actors.
- "Logic-First" prevents bugs that traditional tests might miss.
- Bulletproof architecture is the only way to reach 100M+ users safely.

---

## Red Team Vulnerability Checklist

Use when doing a security audit pass. Check each class:

### A. AuthN/AuthZ
- [ ] Callable functions missing `if not req.auth:` guard → IDOR
- [ ] Admin endpoints accessible without `UserRoleValues.ADMIN` in `req.auth.token`
- [ ] Seller reading other seller's orders via crafted `sellerId`
- [ ] Buyer impersonating seller via `sellerId` injection in request body
- [ ] MFA bypass: brute-force `mfaBackupCodes`, lockout bypass

### B. Injection & Sanitization
- [ ] Firestore rule gaps — client-supplied IDs not ownership-checked server-side
- [ ] `sanitized_text()` bypass: Unicode homoglyphs, zero-width chars, RLO bidi spoofing
- [ ] Client-supplied `orderId`, `productId`, `userId` not re-verified server-side

### C. Business Logic
- [ ] Self-purchase: `sellerId == userId` check present in checkout
- [ ] Stock race condition: two concurrent buys of `stock=1` both succeed
- [ ] Coupon double-spend: apply same coupon in parallel from two clients
- [ ] Return window bypass: manufactured `deliveredAt` timestamp
- [ ] Platform fee manipulation: crafted `platformFeeRatio` in order metadata

### D. Payment & Financial
- [ ] Stripe webhook signature verified (`stripe.WebhookSignature.verify_header`)
- [ ] Checkout session `metadata` verified server-side before fulfillment
- [ ] Stripe Connect `account_id` not swappable (payout to attacker account)
- [ ] Negative price injection: `priceCents < 0` rejected
- [ ] Zero-balance reversal deadlock: seller has no funds, refund stuck

### E. Rate Limiting & DoS
- [ ] Email flooding via consent endpoints called in loop
- [ ] Review spam: `submit_product_rating` per-user limit enforced
- [ ] Webhook replay: same Stripe `event.id` processed twice
- [ ] Back-in-stock subscription spam (1000 subscriptions/user)

### F. Data Exfiltration
- [ ] `export_my_data` does NOT expose `mfaSecret`, `mfaBackupCodes`
- [ ] Chat messages unreadable by non-participants
- [ ] `_mail_logs` and `user_security` unreadable from client (Firestore rules)
- [ ] Digital license `bookSourceUrl` not in client-readable path

### G. File Upload (R2)
- [ ] MIME type bypass: `.html`/`.js` disguised as image → rejected
- [ ] Path traversal in `object_path` parameter → sanitized
- [ ] SVG with embedded `<script>` rejected as product image

### Reporting Format
```
## [SEVERITY] VULN-###: Short Title
**Attack Vector:** Exact exploit steps
**Affected Code:** path/to/file.py:LineNumber
**Impact:** What attacker gains
**Fix:** Exact code change needed
```
