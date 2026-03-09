---
name: full-stack-audit
description: Use when checking frontend-backend consistency — Dart field names vs Python fields, enum mismatches, payload vs handler expectations, or cross-stack schema drift.
context: fork
agent: cross-stack-auditor
disable-model-invocation: true
---

# Full Stack Audit

Run a comprehensive audit of ALL cross-stack interfaces in the project.

## File Pairs to Compare (read each pair together)

### 1. Checkout Flow
- `origna_gta/lib/features/checkout/checkout_provider.dart` ↔ `functions/handlers/payment_stripe.py`

### 2. Order Operations
- `origna_gta/lib/features/orders/seller_orders_viewmodel.dart` ↔ `functions/handlers/orders.py`
- `origna_gta/lib/features/orders/buyer_orders_viewmodel.dart` ↔ `functions/handlers/orders.py`

### 3. Product CRUD
- `origna_gta/lib/features/products/add_product_viewmodel.dart` ↔ `functions/handlers/products.py`

### 4. Auth & Admin
- `origna_gta/lib/features/auth/auth_provider.dart` ↔ `functions/handlers/admin.py`

### 5. Schema Constants (MUST be identical)
- `origna_gta/lib/core/schema/schema_constants.dart` ↔ `functions/schema_constants.py`

### 6. Models (field-by-field comparison)
- `origna_gta/lib/models/generated/order_models.dart` ↔ `functions/models/order.py`
- `origna_gta/lib/models/generated/product_models.dart` ↔ `functions/models/product.py`
- `origna_gta/lib/models/generated/user_models.dart` ↔ `functions/models/user.py`

### 7. Shipping
- `origna_gta/lib/features/checkout/checkout_provider.dart` ↔ `functions/services/shipping_service.py`

### 8. Digital Products
- `origna_gta/lib/features/products/add_product_viewmodel.dart` ↔ `functions/handlers/digital.py`

### 9. Subscriptions / Premium
- `origna_gta/lib/features/subscription/subscription_provider.dart` ↔ `functions/handlers/subscriptions.py`

### 10. Returns
- `origna_gta/lib/models/generated/return_request_models.dart` ↔ `functions/handlers/orders.py` (return_request handler)

### 11. Notifications
- `origna_gta/lib/features/notifications/notification_provider.dart` ↔ `functions/handlers/users.py` (FCM token mgmt)

## For Each Pair
1. Read both files completely
2. Compare: field names, types, enums, error handling, response format
3. Report mismatches in the standard MISMATCH format

## Invocation
```
/full-stack-audit
```
