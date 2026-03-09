# Cloud Functions Architecture Recommendations

> **Status**: RFC (Request for Comments)  
> **Impact**: Medium-High (Deployment & Operational)  
> **Effort**: 2-3 weeks  

## Current State

Currently, all handlers are deployed as a single Cloud Functions deployment unit:

```
functions/
├── handlers/
│   ├── payment_stripe.py      # ~2,300 lines
│   ├── orders.py              # ~450 lines
│   ├── products.py            # ~330 lines
│   ├── admin.py               # ~250 lines
│   ├── cron_jobs.py           # ~650 lines
│   └── ...
```

**Deployment Unit**: Single monolith  
**Cold Start**: ~2-3 seconds (all handlers loaded)  
**Memory**: 1GB shared across all handlers

## Proposed Architecture

Split into domain-specific micro-functions for better isolation and scaling:

```
functions/
├── payment/                   # Payment processing domain
│   ├── stripe_webhook/        # Webhook handler only
│   ├── stripe_checkout/       # Checkout session creation
│   ├── stripe_capture/        # Payment capture
│   └── stripe_refund/         # Refund processing
├── orders/                    # Order lifecycle domain
│   ├── order_create/          # Order creation
│   ├── order_update/          # Status updates
│   ├── order_cancel/          # Cancellation
│   └── order_triggers/        # Firestore triggers
├── products/                  # Product management domain
│   ├── product_crud/          # Create/update/delete
│   ├── product_search/        # Algolia integration
│   └── product_triggers/      # Firestore triggers
├── admin/                     # Administrative domain
│   ├── admin_users/           # User management
│   ├── admin_sellers/         # Seller operations
│   └── admin_security/        # Security alerts
└── shared/                    # Shared components
    ├── lib/                   # Common utilities
    └── config/                # Configuration
```

## Benefits

| Benefit | Current | Proposed | Impact |
|---------|---------|----------|--------|
| **Cold Start** | 2-3s (all handlers) | 0.5-1s (relevant only) | 60% faster |
| **Memory Usage** | 1GB shared | 256MB-512MB per function | 50% reduction |
| **Deployment Risk** | High (one bug affects all) | Low (isolated failures) | Critical |
| **Scaling Granularity** | All functions scale together | Per-function scaling | Cost savings |
| **Team Ownership** | Single owner | Domain ownership | Parallel development |

## Implementation Phases

### Phase 1: Extract Shared Library (Week 1)

Create shared components used by all functions:

```python
# functions/shared/lib/config.py
# functions/shared/lib/firestore.py
# functions/shared/lib/rate_limiter.py
# functions/shared/lib/schema.py
```

### Phase 2: Extract Payment Functions (Week 2)

**Priority**: Highest (most critical, most complex)

```python
# functions/payment/stripe_webhook/main.py
# functions/payment/stripe_checkout/main.py
# functions/payment/stripe_capture/main.py
```

**Deployment**:
```bash
firebase deploy --only functions:stripe_webhook
firebase deploy --only functions:stripe_checkout
firebase deploy --only functions:stripe_capture
```

### Phase 3: Extract Order Functions (Week 3)

```python
# functions/orders/order_create/main.py
# functions/orders/order_update/main.py
# functions/orders/order_triggers/main.py
```

### Phase 4: Remaining Functions (Week 4)

```python
# functions/products/product_crud/main.py
# functions/admin/admin_users/main.py
# functions/cron/cleanup_jobs/main.py
```

## Configuration Changes

### Current (monolithic)

```python
# functions/main.py
from handlers.payment_stripe import stripe_webhook, create_checkout_session
from handlers.orders import update_order_status
from handlers.products import upload_product_images

# All registered in single file
```

### Proposed (micro-functions)

```python
# functions/payment/stripe_webhook/main.py
from firebase_functions import https_fn
from shared.lib import config, firestore

@https_fn.on_call(
    memory=options.MemoryOption.MB_256,
    timeout_sec=30,
)
def stripe_webhook(req):
    ...
```

## Inter-Service Communication

Use Firestore for async communication between services:

```
Order Service                    Payment Service
     |                                |
     |-- create order document -------->|
     |                                |
     |<-- order.status = "confirmed" ---|
     |    (trigger webhook)           |
     |                                |
```

Or use Pub/Sub for event-driven architecture:

```python
# Order service publishes event
from google.cloud import pubsub_v1
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(project_id, "payment-events")
publisher.publish(topic_path, b"order.created", order_id=order_id)

# Payment service subscribes
@pubsub_fn.on_message_published(topic="payment-events")
def handle_payment_event(event):
    ...
```

## Migration Strategy

### Option 1: Blue/Green Deployment

1. Deploy new micro-functions alongside existing monolith
2. Update Flutter to call new endpoints gradually
3. Monitor error rates
4. Decommission monolith after 100% traffic migration

### Option 2: Strangler Fig Pattern

1. Extract one function at a time
2. Route traffic to new function via internal proxy
3. Gradually migrate all functions
4. Remove old code paths

**Recommended**: Option 2 (lower risk, gradual migration)

## Cost Analysis

### Current Costs (Estimated Monthly)

- Invocations: 1M/month
- Memory: 1GB
- Compute: $0.40/GB-hour
- **Total**: ~$150/month

### Proposed Costs

| Function | Memory | Invocations | Cost |
|----------|--------|-------------|------|
| stripe_webhook | 256MB | 100K | $8 |
| stripe_checkout | 512MB | 50K | $10 |
| stripe_capture | 256MB | 50K | $4 |
| order_create | 256MB | 50K | $4 |
| order_update | 256MB | 200K | $16 |
| product_crud | 256MB | 300K | $24 |
| admin | 256MB | 10K | $1 |
| **Total** | - | - | **~$67/month** |

**Savings**: ~$83/month (55% reduction)

## Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Increased complexity | Medium | Medium | Shared library, good documentation |
| Cold start in new services | High | Low | Minimize dependencies, use lazy loading |
| Data inconsistency | Low | High | Use transactions, idempotency keys |
| Deployment errors | Medium | Medium | CI/CD automation, canary deployments |
| Debugging difficulty | Medium | Medium | Centralized logging (Cloud Trace) |

## Decision Matrix

| Criteria | Keep Monolith | Micro-Functions | Winner |
|----------|---------------|-----------------|--------|
| Development speed | ✅ Fast | ⚠️ Slower setup | Monolith |
| Operational isolation | ❌ All or nothing | ✅ Per-function | Micro |
| Debugging simplicity | ✅ Single codebase | ⚠️ Distributed | Monolith |
| Team scaling | ❌ Bottleneck | ✅ Parallel teams | Micro |
| Cost efficiency | ❌ Over-provisioned | ✅ Right-sized | Micro |
| Cold start | ❌ Slower | ✅ Faster | Micro |
| Risk of bugs | ❌ Wide blast radius | ✅ Isolated | Micro |

**Verdict**: Proceed with micro-function architecture (3 out of 7 criteria favor monolith for development phase, but micro-functions win on operational concerns which matter more at scale).

## Recommended Next Steps

1. **Week 1**: Create RFC document, get team buy-in
2. **Week 2**: Implement shared library, extract payment webhooks
3. **Week 3**: Deploy to staging, test extensively
4. **Week 4**: Gradual production rollout (1% → 10% → 50% → 100%)
5. **Week 5**: Monitor, optimize, document learnings

## Appendix: Code Examples

### Shared Library Structure

```python
# functions/shared/lib/firestore.py
from firebase_admin import firestore

_db = None

def get_db():
    global _db
    if _db is None:
        _db = firestore.client()
    return _db

def transactional(fn):
    """Decorator for Firestore transactions."""
    def wrapper(*args, **kwargs):
        transaction = get_db().transaction()
        return fn(transaction, *args, **kwargs)
    return wrapper
```

### Micro-Function Example

```python
# functions/payment/stripe_capture/main.py
import os
from firebase_functions import https_fn, options

# Shared library import
from shared.lib.config import Collections, PaymentStatus
from shared.lib.firestore import get_db
from shared.lib.rate_limiter import RateLimiter

# Initialize only what's needed
_db = get_db()
_rate_limiter = RateLimiter(_db)

@https_fn.on_call(
    memory=options.MemoryOption.MB_256,
    timeout_sec=60,
    max_instances=100,
)
def capture_payment(req: https_fn.CallableRequest):
    """Capture payment for delivered order."""
    # Rate limiting
    allowed, msg = _rate_limiter.check_rate_limit(
        identifier=req.auth.uid,
        action='capture_payment',
        max_requests=10,
        window_minutes=1,
    )
    if not allowed:
        raise https_fn.HttpsError('resource-exhausted', msg)
    
    # ... capture logic (same as current)
    
# Local testing
if __name__ == '__main__':
    # Can run this function in isolation
    pass
```

---

**Document Owner**: Platform Team  
**Last Updated**: 2025-02-08  
**Next Review**: 2025-03-08
