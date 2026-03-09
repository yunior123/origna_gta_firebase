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

## Known Issue: Firestore Rules Field Whitelist
The Firestore rules whitelist does NOT include many fields the backend writes:
`items`, `payoutStatus`, `confirmedByClient`, `confirmedAt`, `autoConfirmed`,
`archived`, `archivedAt`, `shippingApproval`, `shippingApprovalStatus`, etc.
Backend bypasses rules via Admin SDK (expected), but if admin client-side updates
are ever attempted, they will fail on these fields.

## Email Triggers
- confirmed: Handled in `process_checkout_session_completed()` (payment_stripe.py), NOT in `on_order_status_changed`
- processing/shipped/in_transit/delivered/cancelled/refunded/partially_refunded: `on_order_status_changed` trigger
- NO email for `expired` or `failed` status changes
- NO dedicated `get_order_confirmed_email` function (uses `get_order_confirmation_email` in webhook)

## File Locations
- Backend handlers: `functions/handlers/orders.py`, `functions/handlers/payment_stripe.py`
- Cron jobs: `functions/handlers/cron_jobs.py`
- Email service: `functions/services/email_service.py`
- State machine: `functions/schema_constants.py`
- Frontend viewmodels: `origna_gta/lib/features/orders/`
- Frontend screens: `origna_gta/lib/screens/orders_screen.dart`, `seller_orders_screen.dart`
