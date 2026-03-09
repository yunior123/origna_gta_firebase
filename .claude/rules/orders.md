---
paths:
  - "**/order*"
  - "**/orders*"
  - "functions/handlers/orders.py"
  - "functions/handlers/cron_jobs.py"
  - "origna_gta/lib/features/orders/**"
---

# Order Lifecycle Rules

States: `pending → confirmed → processing → shipped → in_transit → delivered` (+ cancelled/failed/expired/refunded)

- One-way transitions only. Terminal states are final.
- Sellers CANNOT mark delivered (admin/cron only). Multi-seller → use `update_item_status`.
- Cancel: restore stock + refund/void. Double-cancel idempotent via `STOCK_RESTORED`.
- `deliveryStatus` DEPRECATED → use `status` on items.
- Cross-check: `orders.py` ↔ `payment_stripe.py` ↔ `cron_jobs.py` ↔ `orders/*.dart` ↔ `order_models.dart`
