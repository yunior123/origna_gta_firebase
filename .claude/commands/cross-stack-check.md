Find all bugs at the frontend↔backend boundary.

Read these file PAIRS together and compare:

PAIR 1 — Schema Constants:
  functions/schema_constants.py ↔ origna_gta/lib/core/schema/schema_constants.dart

PAIR 2 — Checkout:
  origna_gta/lib/features/checkout/checkout_provider.dart ↔ functions/handlers/payment_stripe.py

PAIR 3 — Orders:
  origna_gta/lib/features/orders/seller_orders_viewmodel.dart ↔ functions/handlers/orders.py

PAIR 4 — Products:
  origna_gta/lib/features/products/add_product_viewmodel.dart ↔ functions/handlers/products.py

PAIR 5 — Auth:
  origna_gta/lib/features/auth/auth_provider.dart ↔ functions/handlers/admin.py

PAIR 6 — Models:
  origna_gta/lib/models/generated/*.dart ↔ functions/models/*.py

For each pair, check:
- Field names match (camelCase consistency)
- Request/response formats agree
- Error handling covers all backend error codes
- Enum values exist on both sides
- Types are compatible
- Null/optional handling matches

Report mismatches with file:line references. Use ultrathink.
