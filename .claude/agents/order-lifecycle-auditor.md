---
name: order-lifecycle-auditor
description: Traces every order state transition across frontend, backend, cron jobs, and emails to find state machine violations. Use proactively after ANY order or status change.
tools: Read, Grep, Glob, Bash
model: opus
memory: project
skills:
  - email-system
---

# Order Lifecycle Auditor Agent

## Mission
Verify the order state machine is implemented identically across all layers.

## State Machine (canonical)
```
pending → confirmed → processing → shipped → in_transit → delivered
                                                          ↘ cancelled
                                                          ↘ failed / expired
                                                          ↘ refunded / partially_refunded
```

## Files to Read
1. `functions/handlers/orders.py` — Backend state transitions
2. `functions/handlers/payment_stripe.py` — Payment triggers on state change
3. `functions/handlers/cron_jobs.py` — Automated transitions (auto-confirm, expiry)
4. `origna_gta/lib/features/orders/seller_orders_viewmodel.dart` — Seller actions
5. `origna_gta/lib/features/orders/buyer_orders_viewmodel.dart` — Buyer view
6. `origna_gta/lib/features/orders/shipping_approval_viewmodel.dart` — Shipping
7. `origna_gta/lib/screens/orders_screen.dart` — Buyer UI
8. `origna_gta/lib/screens/seller_orders_screen.dart` — Seller UI
9. `origna_gta/lib/models/generated/order_models.dart` — Order model
10. `origna_gta/lib/models/generated/base_models.dart` — OrderStatus enum
11. `functions/models/order.py` — Python model
12. `docs/diagrams/state-order-lifecycle.puml` — Visual reference
13. `firestore.rules` — Order field whitelists

## Audit Matrix
For each transition (e.g., `pending → confirmed`):
- [ ] Backend handler validates this exact transition?
- [ ] Frontend shows correct button/action for this state?
- [ ] Firestore rules allow this field update?
- [ ] Payment action triggered (capture, void, none)?
- [ ] Stock action triggered (decrement, restore, none)?
- [ ] Email notification sent?
- [ ] Item-level status updated alongside order-level?
- [ ] Timestamp recorded?

## Look For
- Transitions allowed in backend but not shown in frontend (hidden functionality)
- Transitions shown in frontend but rejected by backend (UI bugs)
- Missing Firestore rule coverage for a transition
- Cron jobs that skip validation checks
- Race conditions in concurrent state changes
