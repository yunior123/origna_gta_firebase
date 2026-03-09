# Runbook: Payment Stuck in Pending

**Severity**: P1 (Critical)  
**Impact**: Orders not completing, revenue loss  
**Slack Channel**: #incidents

---

## Symptoms

- Orders stuck in `pending` status > 30 minutes
- `paymentStatus` = `awaiting_payment` but Stripe shows payment succeeded
- Customer charged but order not confirmed
- Error logs in `payment_stripe.py`

## Quick Diagnosis (5 minutes)

### 1. Check Order Status

```bash
# Find stuck orders (last 2 hours)
firebase firestore:documents:query --collection orders \
  --where "orderStatus==pending" \
  --where "createdAt>$(date -d '2 hours ago' +%s)"
```

### 2. Check Stripe Events

```bash
# List recent payment events
stripe events list --type payment_intent.created --limit 20

# Check specific order
stripe payment_intents retrieve pi_XXXXXX
```

### 3. Check Webhook Delivery

```bash
# View webhook logs
firebase functions:log --only payment_stripe --filter "webhook" --limit 50
```

### 4. Check Circuit Breaker

Look for logs containing:
- `CircuitBreaker[stripe_checkout]: OPEN`
- `Webhook signature verification failed`
- `Rate limit exceeded`

---

## Common Causes & Fixes

### Cause 1: Webhook Signature Verification Failure

**Diagnosis**:
```
⚠️ Stripe webhook invalid signature from IP: xxx.xxx.xxx.xxx
```

**Fix**:
1. Verify `STRIPE_WEBHOOK_SECRET` is correct in Firebase secrets
2. Check if webhook endpoint URL changed in Stripe dashboard
3. Re-register webhook if needed:
   ```bash
   stripe webhook_endpoints create \
     --url https://us-central1-orignagta.cloudfunctions.net/stripe_webhook \
     --enabled-events checkout.session.completed \
     --enabled-events payment_intent.succeeded
   ```

### Cause 2: Circuit Breaker Open

**Diagnosis**:
```
❌ CircuitBreaker[stripe_checkout]: OPEN (3 failures)
```

**Fix**:
1. Wait 30 seconds for auto-reset (half-open)
2. If persistent, check Stripe API status: https://status.stripe.com/
3. Manual reset (emergency only):
   ```python
   # In Cloud Functions shell
   from utils.circuit_breaker import CircuitBreakerRegistry
   CircuitBreakerRegistry.get('stripe_checkout').reset()
   ```

### Cause 3: Webhook Processing Error

**Diagnosis**:
```
❌ Error processing Stripe webhook: OrderNotFound for event_type: checkout.session.completed
```

**Fix**:
1. Find order in Firestore by `stripeSessionId`
2. If order missing, create manually:
   ```bash
   # Use admin script to recreate order from Stripe data
   python scripts/admin/recreate_order.py --session-id cs_test_XXX
   ```

### Cause 4: Idempotency Key Collision

**Diagnosis**:
```
⚠️ Stripe webhook already processed: checkout.session.completed
```

**Fix**:
1. Check if order actually confirmed (query by `stripeSessionId`)
2. If confirmed but status wrong, manually update:
   ```bash
   python scripts/admin/update_order_status.py \
     --order-id ORDER_ID \
     --status confirmed \
     --reason "Manual fix: webhook processed but status not updated"
   ```

---

## Manual Recovery Process

If automated recovery fails:

### Step 1: Get Order Details

```bash
export ORDER_ID="your_order_id"
firebase firestore:documents:get --collection orders --document $ORDER_ID
```

### Step 2: Verify Stripe Payment

```bash
export SESSION_ID="cs_test_XXX"  # From order.stripeSessionId
stripe checkout sessions list --limit=1
stripe payment_intents retrieve pi_XXX  # From session
```

### Step 3: Manual Status Update (Emergency)

```bash
python scripts/admin/update_order_status.py \
  --order-id $ORDER_ID \
  --status confirmed \
  --payment-status authorized \
  --stripe-payment-intent-id pi_XXX \
  --reason "Manual recovery: payment confirmed in Stripe"
```

### Step 4: Notify Customer

```bash
python scripts/admin/send_order_confirmation.py --order-id $ORDER_ID
```

---

## Prevention

1. **Monitor webhook delivery rate**: Alert if < 99% in 1 hour
2. **Circuit breaker metrics**: Alert after 3 failures in 5 minutes
3. **Order confirmation lag**: Alert if orders stuck > 10 minutes
4. **Stripe API status**: Subscribe to status page notifications

---

## Post-Incident Checklist

- [ ] Root cause documented in incident ticket
- [ ] Affected customers identified and notified
- [ ] Refunds issued if needed (coordinate with finance)
- [ ] Fix deployed to prevent recurrence
- [ ] Runbook updated if new scenario discovered
