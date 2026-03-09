# Order Lifecycle Auditor Memory

## State Machine (Backend Source of Truth)
- Defined in `functions/schema_constants.py` class `OrderStatusValues.VALID_TRANSITIONS`
- Enforced by `functions/utils/helpers.py::is_valid_order_status_transition()`
- Firestore rules duplicate in `firestore.rules::isValidOrderStateTransition()`
- Frontend enum in `origna_gta/lib/models/generated/base_models.dart::OrderStatus`

## Key Architecture Facts
- Auto-capture mode: Payment captured at Stripe Checkout (not manual capture)
- Seller payouts via `stripe.Transfer.create()` after delivery confirmation
- Item-level statuses use `DeliveryItemStatusTransitions` (pending->shipped->delivered->refunded)
- Order-level status aggregated from item statuses
- Webhook `checkout.session.completed` transitions pending->confirmed
- Cron `auto_capture_confirmed_receipts` transitions shipped->delivered after AUTO_CONFIRM_DAYS

## Webhook Events Collection
- Collection: `webhook_events` (Collections.WEBHOOK_EVENTS)
- Timestamp field: `Fields.TIMESTAMP` ("timestamp") -- NOT `Fields.CREATED_AT`
- Written by: payment_stripe.py (line 1225), payment_airwallex.py (line 483)
- Cleaned up by: cron_jobs.py `cleanup_stale_webhook_events` using `Fields.TIMESTAMP`
- Confirmed matching on 2026-02-18 audit

## Known Informational Items (Not Bugs)
- `process_session_expired` and `process_payment_intent_failed` bypass state machine validation
  (acceptable for webhook-driven transitions, guarded by idempotency flags)
- `process_payment_intent_failed` uses batch (not transaction) for stock restore + order cancel
  (guarded by `STOCK_RESTORED` flag for idempotency)
- `approve_shipping_cost` rejection sets CANCELLED without calling `is_valid_order_status_transition()`
  (acceptable: pre-validated to be in confirmed/processing state by upstream logic)

## Email Triggers
- confirmed: Handled in `process_checkout_session_completed()` (payment_stripe.py)
- processing/shipped/in_transit/delivered/cancelled/refunded/partially_refunded: `on_order_status_changed` trigger
- NO email for `expired` or `failed` status changes

## File Locations
- Backend handlers: `functions/handlers/orders.py`, `functions/handlers/payment_stripe.py`
- Cron jobs: `functions/handlers/cron_jobs.py`
- Email service: `functions/services/email_service.py`
- State machine: `functions/schema_constants.py`
- Frontend viewmodels: `origna_gta/lib/features/orders/`
- Frontend screens: `origna_gta/lib/screens/orders_screen.dart`, `seller_orders_screen.dart`
