---
name: firebase-scalability
description: Use when designing Firestore schema, writing security rules, optimizing queries, or reviewing data architecture for scale — NoSQL modeling, indexing, and rules patterns.
---

# Firebase Scalability Skill

## Instructions

1.  **Modeling for Scale (Subcollections vs Arrays)**:
    - If a collection can grow indefinitely (e.g., `comments`, `transactions`), ALWAYS use subcollections (`/users/{uid}/transactions/{id}`).
    - For small, bounded sets (e.g., `user.addresses`, `product.tags`), use arrays (limit to ~50-100 items for performance).
    - Documents have a 1MB limit. A single 1MB document can cost as much to read as 100 10KB documents but is much slower to parse.

2.  **Indexing Best Practices**:
    - Use `firestore.indexes.json` for all composite queries.
    - Avoid over-indexing (200 composite index limit).
    - Favor single-field indexes + `in` queries where possible to reduce index count.

3.  **Security Rules (High Latency Avoidance)**:
    - Use `rules_version = '2';`.
    - Minimize `get()` and `exists()` (max 10 per request).
    - Use Custom Claims (`request.auth.token.role`) for roles (Admin, Seller) to save 1 read per request.
    - Validate every field's type and size (`data.name is string && data.name.size() < 100`).

4.  **Backend Efficiency (Cloud Functions)**:
    - Move heavy imports inside the function body to reduce cold starts.
    - Use `asyncio.gather` (Python) or `Future.wait` (Dart) for parallel data fetching.
    - Enforce idempotency with transaction keys or Stripe idempotency headers.

5.  **Adversarial Logic (Magnus Carlsen)**:
    - Predict price tampering: Backend MUST re-fetch price from Firestore during checkout.
    - Predict race conditions: Use `@firestore.transactional` for all inventory/order status updates.

6.  **Cost Monitoring**:
    - Use `Limit(1)` for checks like `exists`.
    - Denormalize data that is frequently read together to avoid multiple lookups.

## Checklist
- [ ] No potential "Array Bloat" fields (lists > 100 items).
- [ ] Subcollections used for all logs, history, and user-generated content.
- [ ] Composite indexes exist for all multi-field queries.
- [ ] Security rules validate field types and sizes.
- [ ] Cloud Functions are idempotent.
- [ ] Price/stock checked server-side during checkout.
