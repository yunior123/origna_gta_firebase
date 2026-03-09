---
name: infra-verification
description: Use when verifying production readiness — checks Firestore rules, indexes, Cloud Functions, Stripe webhooks, and API keys match between project files and live deployed state.
context: fork
agent: infra-verifier
---

# Infrastructure Verification Agent — OrignaGTA

## ⚠️ MISSION

Verify that EVERYTHING in the project matches what's deployed/configured in production APIs.
The app launches March 2026 — zero surprises allowed.

---

## Verification Domains

### 1. Firebase Cloud Functions
**Goal:** Every function in `functions/main.py __all__` is deployed and callable.

**Local source of truth:**
- `functions/main.py` → `__all__` list (54 functions)
- `firebase.json` → functions config

**CLI verification commands:**
```bash
# List deployed functions
gcloud functions list --project=orignagta --format="table(name,status,runtime)"

# Or via Firebase
firebase functions:list --project=orignagta

# Check a specific function
gcloud functions describe create_checkout_session --project=orignagta --region=us-central1
```

**Checks:**
- [ ] Every function in `__all__` is deployed
- [ ] No orphaned functions deployed but not in code
- [ ] Runtime matches `runtime.txt` (python311)
- [ ] Memory/timeout configured appropriately for payment functions
- [ ] Environment variables set (STRIPE_SECRET_KEY, SENTRY_DSN, etc.)
- [ ] Trigger types correct (on_call vs http vs on_document_created)

### 2. Firestore Security Rules
**Goal:** Rules deployed match `firestore.rules` exactly.

**Local source of truth:**
- `firestore.rules` (456 lines)

**CLI verification:**
```bash
# Deploy rules (dry-run)
firebase deploy --only firestore:rules --project=orignagta --dry-run

# Check currently deployed rules
gcloud firestore databases describe --project=orignagta
```

**Checks:**
- [ ] `firestore.rules` deploys without syntax errors
- [ ] All collections have rules (products, orders, users, carts, etc.)
- [ ] Admin-only fields protected (role, stripeAccountId)
- [ ] Canada-only address validation in rules
- [ ] No open rules (`allow read, write: if true`)

### 3. Firestore Indexes
**Goal:** All composite indexes in code match deployed indexes.

**Local source of truth:**
- `firestore.indexes.json` (387 lines, ~20+ composite indexes)

**CLI verification:**
```bash
# List deployed indexes
gcloud firestore indexes composite list --project=orignagta --format=json

# Deploy indexes
firebase deploy --only firestore:indexes --project=orignagta --dry-run

# Check for missing indexes (run queries and check error messages)
```

**Checks:**
- [ ] Every index in `firestore.indexes.json` is deployed and READY
- [ ] No CREATING or ERROR state indexes
- [ ] No orphaned indexes (deployed but not in config)
- [ ] Indexes cover all query patterns in handlers:
  - `products` → isActive + categoryId + createdAt
  - `products` → isActive + keywords + createdAt  
  - `orders` → userId + paymentStatus + createdAt
  - `orders` → sellerId + createdAt
  - `orders` → status + createdAt (for cron jobs)

### 4. Storage Security Rules
**Goal:** `storage.rules` deployed and correct.

**Local source of truth:**
- `storage.rules` (99 lines)

**Checks:**
- [ ] Image upload type restrictions (jpeg, png, gif, webp)
- [ ] 10MB size limit enforced
- [ ] Seller ownership validation for product images
- [ ] Path structure matches: `products/{sellerId}/{productId}/{fileName}`

### 5. Stripe Configuration
**Goal:** All Stripe webhooks, products, and Connect settings match code expectations.

**CLI verification:**
```bash
# List webhook endpoints
stripe webhook_endpoints list --limit=10

# Check specific webhook events registered
stripe webhook_endpoints retrieve we_xxx

# List Connect accounts
stripe accounts list --limit=5

# Check API key validity
stripe config --list

# Verify webhook signing secret matches
stripe listen --print-secret
```

**Checks:**
- [ ] Webhook endpoint URL: `https://us-central1-orignagta.cloudfunctions.net/stripe_webhook`
- [ ] All required events registered:
  - `checkout.session.completed`
  - `checkout.session.expired`
  - `payment_intent.succeeded`
  - `payment_intent.payment_failed`
  - `charge.refunded`
  - `charge.dispute.created`
  - `charge.dispute.updated`
  - `charge.dispute.closed`
  - `charge.dispute.funds_reinstated`
  - `account.updated` (Connect)
  - `transfer.created`
  - `transfer.failed`
- [ ] Webhook signing secret stored in GCP Secret Manager
- [ ] Stripe API version compatible (check `stripe.api_version`)
- [ ] Connect Express onboarding configured
- [ ] Platform fee (2.5%) matches `BusinessRules.PLATFORM_FEE_RATIO`
- [ ] Currency set to CAD
- [ ] Test vs live key distinction

### 6. GCP Secret Manager
**Goal:** All required secrets exist and are accessible.

**CLI verification:**
```bash
# List all secrets
gcloud secrets list --project=orignagta

# Check specific secrets exist
gcloud secrets versions access latest --secret=stripe-secret-key --project=orignagta
gcloud secrets versions access latest --secret=stripe-webhook-secret --project=orignagta
gcloud secrets versions access latest --secret=algolia-api-key --project=orignagta
```

**Required secrets:**
- [ ] `stripe-secret-key` — Stripe API key
- [ ] `stripe-webhook-secret` — Webhook signing secret
- [ ] `algolia-api-key` — Algolia search API key
- [ ] `algolia-app-id` — Algolia app ID
- [ ] `mailjet-api-key` — Mailjet email
- [ ] `mailjet-secret-key` — Mailjet secret
- [ ] `sentry-dsn` — Sentry error tracking
- [ ] `r2-access-key` — Cloudflare R2

### 7. Algolia Search
**Goal:** Algolia index exists, matches schema, and is populated.

**Checks:**
- [ ] Index `products` exists in Algolia dashboard
- [ ] Searchable attributes configured (title, description, keywords, categoryId)
- [ ] Filtering attributes (isActive, categoryId, price, sellerId)
- [ ] Ranking strategy configured
- [ ] Product count matches Firestore active products

### 8. Firebase Hosting
**Goal:** Hosting configuration correct for Flutter web.

**Local source of truth:**
- `firebase.json` → hosting config

**Checks:**
- [ ] Public directory: `origna_gta/build/web`
- [ ] Security headers configured (CSP, HSTS, X-Frame-Options)
- [ ] SPA rewrites for Flutter: `"destination": "/index.html"`
- [ ] Custom domain configured (if applicable)

### 9. CORS & API Configuration
**Checks:**
- [ ] Cloud Functions CORS allows production domain
- [ ] No wildcard CORS in production (`*`)
- [ ] Rate limiting configured per endpoint
- [ ] Sentry DSN active and receiving errors

### 10. Cron Jobs (Cloud Scheduler)
**Local source of truth:** `functions/handlers/cron_jobs.py`

**CLI verification:**
```bash
# List scheduled jobs
gcloud scheduler jobs list --project=orignagta --location=us-central1
```

**Required cron jobs:**
- [ ] `auto_capture_confirmed_receipts` — daily
- [ ] `check_expired_authorizations` — daily
- [ ] `auto_archive_old_orders` — weekly
- [ ] `monitor_algolia_sync` — hourly
- [ ] `cleanup_stale_rate_limits` — daily
- [ ] `cleanup_orphaned_r2_images` — weekly
- [ ] `cleanup_stale_webhook_events` — daily
- [ ] `cleanup_stale_security_alerts` — weekly
- [ ] `retry_failed_algolia_syncs` — every 15 min

---

## Verification Script Usage

```bash
# Run full infra verification
python audit/run_hooks.py --hook infra

# Quick check (no LLM, CLI only)
python audit/run_hooks.py --hook infra --no-llm

# Check specific domain
python audit/scripts/verify_infra.py --domain stripe
python audit/scripts/verify_infra.py --domain firestore
python audit/scripts/verify_infra.py --domain functions
```

---

## Cross-Reference Files

| Domain | Local File | Remote API |
|--------|-----------|------------|
| Functions | `functions/main.py` | `gcloud functions list` |
| Rules | `firestore.rules` | `firebase deploy --dry-run` |
| Indexes | `firestore.indexes.json` | `gcloud firestore indexes composite list` |
| Storage | `storage.rules` | `firebase deploy --dry-run` |
| Webhooks | `functions/handlers/payment_stripe.py` | `stripe webhook_endpoints list` |
| Secrets | `functions/config.py` | `gcloud secrets list` |
| Cron | `functions/handlers/cron_jobs.py` | `gcloud scheduler jobs list` |
| Hosting | `firebase.json` | `firebase hosting:channel:list` |

