# Runbook: Stock Mismatch Investigation

**Severity**: P1 (Critical)  
**Impact**: Overselling, fulfillment failures, customer complaints  
**Slack Channel**: #incidents

---

## Symptoms

- Product `stockQuantity` shows > 0 but orders failing with "out of stock"
- Negative stock quantities appearing
- Orders cancelled due to insufficient stock but stock not restored
- Discrepancy between reported stock and actual inventory

## Quick Diagnosis

### 1. Check Product Stock

```bash
export PRODUCT_ID="your_product_id"

# Get current stock
firebase firestore:documents:get --collection products --document $PRODUCT_ID

# Check stock transaction history (if audit log enabled)
firebase firestore:documents:query --collection stock_transactions \
  --where "productId==$PRODUCT_ID" \
  --order-by createdAt --direction descending --limit 20
```

### 2. Check Related Orders

```bash
# Find orders affecting this product
firebase firestore:documents:query --collection orders \
  --where "items.productId==$PRODUCT_ID" \
  --where "createdAt>$(date -d '7 days ago' +%s)" \
  --order-by createdAt --direction descending --limit 50
```

### 3. Analyze Stock Movements

```python
# Use Python script for complex analysis
python scripts/admin/analyze_stock.py --product-id $PRODUCT_ID
```

---

## Common Causes & Fixes

### Cause 1: Order Cancelled But Stock Not Restored

**Diagnosis**:
- Order status = `cancelled`
- Order has `stockRestored: false` or field missing
- Product stock unchanged from before order

**Fix**:
```bash
# Restore stock manually
python scripts/admin/adjust_stock.py \
  --product-id $PRODUCT_ID \
  --adjustment +3 \
  --reason "Restoring stock for cancelled order ORDER_ID"

# Mark order as stock restored
python scripts/admin/update_order.py \
  --order-id ORDER_ID \
  --set stockRestored=true
```

### Cause 2: Concurrent Purchase Race Condition

**Diagnosis**:
- Multiple orders created within seconds for same product
- All orders show `paymentStatus: authorized`
- Stock went negative

**Fix**:
1. Cancel excess orders:
   ```bash
   python scripts/admin/cancel_order.py \
     --order-id ORDER_ID \
     --reason "Oversold - refunding customer" \
     --issue-refund
   ```

2. Contact affected customers

3. The atomic transaction in `payment_stripe.py` should prevent this - check for deployment issues

### Cause 3: Manual Stock Adjustment Bypass

**Diagnosis**:
- Stock changed by admin but `updatedAt` doesn't match
- No audit log entry for stock change

**Fix**:
```bash
# Set correct stock level
python scripts/admin/adjust_stock.py \
  --product-id $PRODUCT_ID \
  --set-quantity 10 \
  --reason "Manual correction after inventory count"
```

### Cause 4: Webhook Failure After Payment

**Diagnosis**:
- Order shows `orderStatus: pending`
- `paymentStatus: awaiting_payment` (should be `authorized`)
- Stripe shows payment succeeded

**Fix**:
See [payment-stuck.md](./payment-stuck.md) - same root cause, different symptom

---

## Stock Audit Process

### Full Reconciliation

```bash
# Run complete stock audit
python scripts/admin/stock_audit.py --days 30 --output report.json

# Check specific seller
python scripts/admin/stock_audit.py --seller-id SELLER_ID --days 7
```

### Fix All Mismatches

```bash
# Automated correction (dry run first)
python scripts/admin/stock_audit.py --fix --dry-run

# Apply fixes
python scripts/admin/stock_audit.py --fix --confirm
```

---

## Manual Stock Adjustment

### Emergency Override

```python
# In Cloud Functions shell or admin script
from firebase_admin import firestore

db = firestore.client()
product_ref = db.collection('products').document('PRODUCT_ID')

# Get current
product = product_ref.get().to_dict()
current_stock = product.get('stockQuantity', 0)

# Set new value (use transaction for concurrent safety)
@firestore.transactional
def update_stock(transaction):
    transaction.update(product_ref, {
        'stockQuantity': NEW_VALUE,
        'lastStockAdjustment': firestore.SERVER_TIMESTAMP,
        'stockAdjustmentReason': 'Manual audit correction'
    })

transaction = db.transaction()
update_stock(transaction)
```

---

## Prevention

1. **Daily automated audit**: Run `stock_audit.py` daily, alert on mismatches
2. **Inventory webhooks**: Real-time sync with inventory management system
3. **Low stock alerts**: Notify seller when stock < 5
4. **Stock reservation**: Already implemented - ensure it's not bypassed

---

## Post-Incident

- [ ] Root cause identified (race condition? manual error? webhook failure?)
- [ ] Affected orders documented
- [ ] Customers contacted for any cancelled orders
- [ ] Stock levels corrected
- [ ] Prevention measures implemented
