## SCHEMA SYNC FINDINGS

### CRITICAL
1. `ORDER_REFUND_CENTS` constant missing in Python schema_constants.py — Dart has it at line 748
2. `PaymentStatusEnum.DISPUTED` missing in Python models/base.py (Dart line 127)
3. `PaymentStatusEnum.PARTIALLY_REFUNDED` missing in Python models/base.py (Dart line 135)
4. `OrderStatusEnum.PARTIALLY_REFUNDED` missing in Python models/base.py (Dart line 102)

### MEDIUM
5. Firestore rules should validate new payment/order status values

### VERIFIED SYNCED
- pushEnabled, madeInCountry, compareAtPrice, UserRole, ShippingApprovalStatus, DeliveryStatus, Address model, REFUND_AMOUNT_CENTS
