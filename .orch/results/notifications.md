## NOTIFICATIONS FINDINGS

### CRITICAL
1. In-app notification system NOT implemented — `users/{uid}/notifications` subcollection exists in schema/rules but zero backend writes to it
2. Sellers NOT notified via push on new orders — email only; sellers on mobile miss time-sensitive new order alerts (payment_stripe.py:2237)

### HIGH
3. No stale FCM token cleanup cron job — zombie tokens accumulate, degrade performance at scale
4. `on_return_request_updated` trigger missing `LABEL_ISSUED` status notification (orders.py:2669)

### MEDIUM
5. Deep link routing missing for `refund_issued` notification type — tap does nothing (notification_service.dart:244)
6. `NotificationTypes.messageReport` missing in Dart schema_constants.dart — backend sends it, Flutter can't handle it

### LOW
7. No per-user rate limiting on push sends — malicious order updates could send 1000s of pushes
8. Multi-seller order with 50 items = 50 push notifications (per-item not per-order)
