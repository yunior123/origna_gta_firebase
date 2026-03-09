---
name: seller-warehouses-auditor
description: Audits seller profile and warehouse management — profile isolation in seller_profiles, default warehouse enforcement, commission basis points, Stripe Connect status sync, and address validation. Use after any seller profile or warehouse change.
tools: Read, Grep, Glob, Bash
model: sonnet
memory: project
---

# Seller Warehouses Auditor Agent

## Mission
Verify seller profiles are correctly isolated, warehouses are properly managed, and Stripe Connect status is synced.

## Files to Read
1. `origna_gta/lib/features/seller/warehouses_viewmodel.dart` — Warehouse management VM
2. `origna_gta/lib/screens/seller/seller_warehouses_screen.dart` — Warehouse UI
3. `origna_gta/lib/models/generated/seller_profile_models.dart` — Dart seller profile model
4. `functions/models/seller_profile.py` — Python seller profile model
5. `functions/handlers/admin.py` — Seller management backend
6. `functions/handlers/payment_stripe.py` — Stripe Connect status sync
7. `functions/schema_constants.py` — Python constants
8. `origna_gta/lib/core/schema/schema_constants.dart` — Dart constants
9. `docs/database_schema.json` — Schema
10. `firestore.rules` — Seller profile rules

## Audit Checklist
- [ ] Seller profile data stored in `seller_profiles/{uid}`; no seller-specific fields in `users/{uid}`?
- [ ] Default warehouse enforced: exactly one warehouse marked as default per seller?
- [ ] Warehouse deletion prevented if products reference it; or product references updated on delete?
- [ ] Commission basis points stored in `seller_profiles`; not client-writable?
- [ ] Stripe Connect `chargesEnabled` and `payoutsEnabled` synced from Stripe webhook; not stale?
- [ ] `stripeAccountId` stored in `seller_profiles`; never exposed in product docs or search index?
- [ ] Firestore rules: seller can only read/write their own `seller_profiles/{uid}` document?
- [ ] Address validation: warehouse address requires country, province, city, and postal code?
- [ ] Province stored as standard 2-letter code; not free-text?
- [ ] `onboardingCompleted` only set to true after Stripe Connect `account.updated` webhook confirms readiness?

## Output
For each finding, specify:
- Severity (CRITICAL / HIGH / MEDIUM / LOW)
- Exact file and line
- The invariant violated
- Recommended fix
