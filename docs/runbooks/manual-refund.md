# Runbook: Manual Refund Process

**Severity**: P2 (High)  
**Impact**: Customer satisfaction, financial accuracy  
**Slack Channel**: #finance-ops

---

## When to Use This Runbook

- Automated refund failed but customer entitled to refund
- Partial refund needed (system only supports full)
- Refund needed after payout already sent to seller
- Dispute resolution requires refund

## Prerequisites

- [ ] Order ID
- [ ] Reason for refund
- [ ] Refund amount (full or partial)
- [ ] Approval from finance team (if > $500)

---

## Quick Reference

| Scenario | Command | Notes |
|----------|---------|-------|
| Full refund, before capture | Void authorization | No fees |
| Full refund, after capture | Stripe refund + reverse transfer | 2.5% fee retained |
| Partial refund | Stripe partial refund + manual transfer adjustment | Complex |
| After seller payout | Refund from platform + recover from seller | Requires seller consent or suspension |

---

## Step-by-Step Process

### Step 1: Verify Order Details

```bash
export ORDER_ID="your_order_id"

# Get order info
python scripts/admin/get_order.py --order-id $ORDER_ID

# Check payment status in Stripe
stripe payment_intents retrieve pi_XXXXXX --expand charges.data.refunds
```

### Step 2: Determine Refund Type

#### Option A: Order Not Yet Captured

If `paymentStatus` = `authorized`:

```bash
# Simply cancel the order - no refund needed
python scripts/admin/cancel_order.py \
  --order-id $ORDER_ID \
  --reason "Customer requested cancellation"
```

#### Option B: Full Refund (Standard)

```bash
# Automated full refund
python scripts/admin/refund_order.py \
  --order-id $ORDER_ID \
  --full \
  --reason "Customer request" \
  --notify-customer
```

#### Option C: Partial Refund (Manual)

```bash
# Issue partial refund via Stripe
stripe refunds create \
  --payment-intent=pi_XXXXXX \
  --amount=5000 \  # Amount in cents
  --reason="requested_by_customer"

# Record in Firestore
python scripts/admin/record_partial_refund.py \
  --order-id $ORDER_ID \
  --amount-cents 5000 \
  --reason "Partial refund: item damaged"
```

#### Option D: After Seller Payout

**⚠️ WARNING: Complex - requires finance approval**

```bash
# 1. Find the payout
python scripts/admin/find_payout.py --order-id $ORDER_ID

# 2. Reverse the transfer (if still reversible)
stripe transfer_reversals create tr_XXXXXX \
  --amount=5000

# 3. Issue refund to customer
stripe refunds create --payment-intent=pi_XXXXXX --amount=5000

# 4. Record everything
python scripts/admin/record_post_payout_refund.py \
  --order-id $ORDER_ID \
  --transfer-reversal-id trr_XXXXXX \
  --refund-id re_XXXXXX
```

### Step 3: Verify Refund

```bash
# Check Stripe
stripe charges list --payment-intent=pi_XXXXXX

# Check Firestore
python scripts/admin/get_order.py --order-id $ORDER_ID | jq '.refundStatus'
```

### Step 4: Notify Customer

```bash
# Send refund confirmation email
python scripts/admin/send_refund_confirmation.py \
  --order-id $ORDER_ID \
  --refund-amount 50.00 \
  --refund-method "original_payment_method"
```

---

## Special Scenarios

### Multi-Seller Order Refund

For orders with items from multiple sellers:

```bash
# Refund specific items only
python scripts/admin/refund_order_items.py \
  --order-id $ORDER_ID \
  --items item_1,item_2 \
  --reason "Items out of stock"
```

### Dispute-Related Refund

If refund is due to dispute:

```bash
# Mark as dispute-related
python scripts/admin/refund_order.py \
  --order-id $ORDER_ID \
  --dispute-id dp_XXXXXX \
  --reason "Dispute resolution: customer favored"

# Create security alert for tracking
python scripts/admin/create_security_alert.py \
  --type "dispute_refund" \
  --order-id $ORDER_ID \
  --severity high
```

### Seller Cannot Cover Refund

If seller has insufficient balance for reversal:

1. Platform covers refund initially
2. Seller account flagged
3. Future payouts held until recovered
4. Manual recovery process:

```bash
# Suspend seller until resolved
python scripts/admin/suspend_seller.py \
  --seller-id SELLER_ID \
  --reason "Insufficient funds for refund reversal" \
  --auto-resolve-on-payment

# Create receivable
python scripts/admin/create_seller_receivable.py \
  --seller-id SELLER_ID \
  --amount 50.00 \
  --description "Refund recovery for order ORDER_ID"
```

---

## Financial Reporting

### Generate Refund Report

```bash
# Daily refund report
python scripts/reports/daily_refunds.py --date 2025-02-08

# Monthly summary
python scripts/reports/monthly_refunds.py --month 2025-01
```

### Reconciliation

```bash
# Match Stripe refunds to Firestore
python scripts/reports/reconcile_refunds.py --start-date 2025-02-01 --end-date 2025-02-08
```

---

## Prevention

1. **Clear refund policy**: Document in terms of service
2. **Automated refunds**: Most refunds should be self-service
3. **Dispute early warning**: Monitor dispute rate by seller
4. **Seller reserve**: Hold 5% of payouts for 7 days to cover refunds

---

## Post-Refund Checklist

- [ ] Customer refunded (verified in Stripe)
- [ ] Order status updated to `refunded` or `partially_refunded`
- [ ] Seller notified (if applicable)
- [ ] Transfer reversed (if payout occurred)
- [ ] Security alert created (for pattern detection)
- [ ] Financial records updated
- [ ] Customer confirmation email sent
