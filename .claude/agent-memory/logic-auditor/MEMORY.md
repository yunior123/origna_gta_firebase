# Logic Auditor Memory

## Confirmed Bug Patterns

### 1. Stock restore inconsistency (3-field rule violations)
The codebase has TWO canonical stock restore functions in `payment_stripe.py`:
- `_add_stock_restore_to_batch()` (line ~2555) -- for batch writes
- `_add_stock_restore_to_transaction()` (line ~2578) -- for transactions

Both correctly restore all 3 stock fields: `stockQuantity`, `warehouseStock.{wh}`, `inventoryLevels/{wh}`.
BUT there are at least 2 places that do inline stock restore and miss fields:
- `cron_jobs.py:705-710` (expired order cleanup) -- only restores `stockQuantity`
- `orders.py:2052-2055` (`mark_received` return) -- only restores `stockQuantity`

**Always grep for `Increment(.*QUANTITY` or `STOCK_QUANTITY.*Increment` to find inline stock restores.**

### 2. FSM mismatch between Dart and Python
The `VALID_TRANSITIONS` dict in `schema_constants.py` and `schema_constants.dart` can drift.
Key file locations:
- Dart: `schema_constants.dart` ~line 1202 (`OrderStatusValues.validTransitions`)
- Python: `schema_constants.py` ~line 785 (`OrderStatusValues.VALID_TRANSITIONS`)

Found: `disputed → [refunded, partially_refunded]` in Dart but `disputed → []` in Python.

### 3. Unbounded cron queries
Many cron jobs removed `.limit()` -- always check for pagination in:
- `cleanup_stale_rate_limits`, `cleanup_stale_webhook_events`, `cleanup_stale_security_alerts`
- `cleanup_orphaned_r2_images`, `revalidate_digital_product_urls`, `check_low_stock_alerts`
- `compute_seller_health_metrics` (worst: O(sellers * orders))
- `send_abandoned_cart_reminders`

### 4. Digital item skipping
Any stock operation must check `item.get(Fields.IS_DIGITAL, False)` before modifying stock.
The cron expired order stock restore misses this check.

## Cross-Stack File Mappings
| Dart File | Python File | Sync Area |
|-----------|-------------|-----------|
| `schema_constants.dart` | `schema_constants.py` | Enums, field names, FSM |
| `checkout_provider.dart` | `payment_stripe.py` | Checkout flow, prices |
| `orders_screen.dart` | `orders.py` | Order status updates |
| `auth_repository.dart` | `admin.py` | User profile creation |

## Architecture Notes
- Auto-capture: Payment is CAPTURED at checkout.session.completed. No manual capture step.
- All post-checkout functions that check `PaymentStatusValues.AUTHORIZED` are legacy paths (manual capture migration).
- `update_shipping_cost` can never update totals in practice because payment is always CAPTURED.
- Apple Sign-In: name is provided only on first authorization; must be persisted immediately.
