# Workflow Index — OrignaGta

> **Purpose:** When Claude examines or edits ANY file, consult this index first to know ALL files that participate in that workflow. This prevents logic bugs from cross-stack inconsistencies.

**Full system architecture:** See [`docs/ARCHITECTURE.md`](./ARCHITECTURE.md) — Mermaid diagrams for all flows, complete Cloud Functions catalog, DB schema, security layers, and Canadian compliance summary.

---

## 🧪 E2E TEST CONTEXT

For writing or auditing Playwright tests, always load the relevant **test flow bundle**:

```bash
python3 scripts/collect_flow_files.py
# → ~/Desktop/origna_flows/test_<name>/
```

**Flutter selector rules** (non-negotiable):
- `getByRole('button', { name: /label/i })` — buttons
- `[aria-label="key-name"]` — Semantics containers, form fields
- `pressSequentially()` always — `fill()` never works in Flutter Web
- NEVER search by translated display text — it's not in the DOM

**Playwright test files:** `e2e/playwright_ui/*.spec.ts`  
**Shared helpers:** `e2e/playwright_ui/api-helpers.ts`, `flutter-helpers.ts`  
**Selector map:** `origna_flows/SEMANTICS.md`  
**User journeys:** `origna_flows/FLOWS.md`
**Strict gate:** `.github/workflows/strict-quality-audit.yml` → `scripts/run_quality_gate.sh`

---

## 🛒 CHECKOUT & PAYMENT WORKFLOW

**Summary:** Buyer adds items to cart → proceeds to checkout → enters address → payment intent created (Stripe) → authorization hold → order created → seller ships → payment captured.

### Files to read together (Frontend → Backend → Schema):
```
FRONTEND:
  origna_gta/lib/features/cart/cart_provider.dart          # Cart state management
  origna_gta/lib/features/checkout/checkout_provider.dart   # Checkout orchestration
  origna_gta/lib/screens/cart_screen.dart                   # Cart UI
  origna_gta/lib/screens/checkout_screen.dart               # Checkout UI
  origna_gta/lib/core/repositories/cart_repository.dart     # Cart Firestore ops
  origna_gta/lib/core/repositories/order_repository.dart    # Order Firestore ops
  origna_gta/lib/screens/ordersuccess_screen.dart           # Success UI

BACKEND:
  functions/handlers/payment_stripe.py                      # create_checkout, capture, refund, webhooks
  functions/handlers/orders.py                              # create_order, update_order_status
  functions/services/shipping_service.py                    # Shipping cost calculation
  functions/schema_constants.py                             # Field names, enums, status values

SCHEMA/RULES:
  docs/database_schema.json                                 # Source of truth
  firestore.rules                                           # Security rules for orders/payments
  docs/json_schemas/individual/Order.json                   # Order structure
  origna_gta/lib/core/schema/schema_constants.dart          # Frontend mirror of constants
```

### Logic checkpoints:
- [ ] Cart items → order items: field mapping correct?
- [ ] Price sent from frontend → price verified from Firestore in backend?
- [ ] Shipping cost calculated identically in frontend preview and backend?
- [ ] Stock reservation atomic in Firestore transaction?
- [ ] PaymentIntent amount matches order total exactly?
- [ ] Authorization → capture flow handles expiry (7 day)?
- [ ] Self-purchase blocked (seller ≠ buyer)?
- [ ] Multi-seller cart splits into separate orders per seller?

---

## 📦 ORDER LIFECYCLE WORKFLOW

**Summary:** Order created → seller confirms → processing → shipped (tracking) → in_transit → delivered → (optional) rating. Cancellation/refund possible at certain states.

### State machine:
```
pending → confirmed → processing → shipped → in_transit → delivered
                                                          ↘ cancelled
                                                          ↘ failed / expired
                                                          ↘ refunded / partially_refunded
```

### Files to read together:
```
FRONTEND:
  origna_gta/lib/features/orders/seller_orders_viewmodel.dart    # Seller order actions
  origna_gta/lib/features/orders/seller_orders_state.dart        # Seller order state
  origna_gta/lib/features/orders/buyer_orders_viewmodel.dart     # Buyer order view
  origna_gta/lib/features/orders/orders_provider.dart            # Order providers
  origna_gta/lib/features/orders/shipping_approval_viewmodel.dart # Shipping approval
  origna_gta/lib/screens/orders_screen.dart                      # Buyer orders UI
  origna_gta/lib/screens/seller_orders_screen.dart               # Seller orders UI
  origna_gta/lib/screens/shipping_approval_screen.dart           # Shipping approval UI

BACKEND:
  functions/handlers/orders.py                                   # update_order_status, state transitions
  functions/handlers/payment_stripe.py                           # capture on ship, refund on cancel
  functions/handlers/cron_jobs.py                                # auto_confirm_delivery, check_expired_authorizations
  functions/services/email_service.py                            # Order status notification emails

MODELS:
  origna_gta/lib/models/generated/order_models.dart              # Order, OrderItem Freezed models
  origna_gta/lib/models/generated/base_models.dart               # OrderStatus enum, Address
  functions/models/order.py                                      # Python Order model
  functions/models/base.py                                       # Python base enums

SCHEMA:
  docs/database_schema.json                                      # orders collection schema
  docs/diagrams/state-order-lifecycle.puml                       # Visual state machine
  docs/json_schemas/individual/Order.json                        # Order JSON schema
  firestore.rules                                                # Order security rules
```

### Logic checkpoints:
- [ ] State transitions match the state machine exactly?
- [ ] Item-level status tracks independently from order-level?
- [ ] `deliveryStatus` (DEPRECATED) vs `status` string — no conflicts?
- [ ] Cron: auto-confirm after 7 days works with correct timestamp comparison?
- [ ] Cron: expired authorizations checked within 7-day Stripe window?
- [ ] Cancel triggers stock restoration AND payment refund?
- [ ] Double-cancel is idempotent?
- [ ] Emails sent for each status transition?

---

## 🏪 PRODUCT LIFECYCLE WORKFLOW

**Summary:** Seller creates product → images uploaded to R2 → Algolia indexed → buyer searches → buyer views detail → adds to cart.

### Files to read together:
```
FRONTEND:
  origna_gta/lib/features/products/add_product_viewmodel.dart    # Create product
  origna_gta/lib/features/products/add_product_state.dart        # Create state
  origna_gta/lib/features/products/edit_product_viewmodel.dart   # Edit product
  origna_gta/lib/features/products/edit_product_state.dart       # Edit state
  origna_gta/lib/features/products/product_detail_viewmodel.dart # Product detail
  origna_gta/lib/features/products/product_actions_viewmodel.dart # Actions (delete, toggle)
  origna_gta/lib/features/products/products_provider.dart        # Product providers
  origna_gta/lib/features/products/product_rating_viewmodel.dart # Rating
  origna_gta/lib/screens/addproduct_screen.dart                  # Add product UI
  origna_gta/lib/screens/editproduct_screen.dart                 # Edit product UI
  origna_gta/lib/screens/productdetails_screen.dart              # Detail UI
  origna_gta/lib/screens/product_card_screen.dart                # Card widget
  origna_gta/lib/screens/productaddimages_screen.dart            # Image upload UI
  origna_gta/lib/core/repositories/product_repository.dart       # Product Firestore ops

BACKEND:
  functions/handlers/products.py                                 # CRUD, Algolia sync, image management
  functions/services/algolia_service.py                           # Algolia indexing
  functions/models/product.py                                    # Python Product model

SCHEMA:
  docs/database_schema.json                                      # products collection
  docs/json_schemas/individual/Product.json                      # Product JSON schema
  origna_gta/lib/models/generated/product_models.dart            # Freezed Product model
```

### Logic checkpoints:
- [ ] Product fields: frontend form → Firestore doc → Algolia index all consistent?
- [ ] Stock management: creation, purchase decrement, cancel restore?
- [ ] Price: stored as cents or dollars? Consistent across stack?
- [ ] Shipping config: all delivery tiers stored and read correctly?
- [ ] Image URLs: R2 upload → Firestore URL → frontend display chain intact?
- [ ] Seller can only edit/delete own products?
- [ ] Deactivated products hidden from search AND blocked at checkout?
- [ ] Rating formula correct (average, count, weighted)?

---

## 👤 AUTH & SELLER ONBOARDING WORKFLOW

**Summary:** User registers → email verified → can buy. Seller registers → Stripe Connect onboarding → KYC → can sell.

### Files to read together:
```
FRONTEND:
  origna_gta/lib/features/auth/auth_provider.dart                # Auth state
  origna_gta/lib/features/auth/login_viewmodel.dart              # Login logic
  origna_gta/lib/features/auth/login_state.dart                  # Login state
  origna_gta/lib/features/seller/seller_registration_view_model.dart  # Seller registration
  origna_gta/lib/features/seller/seller_registration_state.dart  # Seller reg state
  origna_gta/lib/features/app/seller_account_status_viewmodel.dart # Account status
  origna_gta/lib/screens/login_screen.dart                       # Login UI
  origna_gta/lib/screens/seller_registration_screen.dart         # Seller reg UI
  origna_gta/lib/screens/seller_setup_screen.dart                # Seller setup UI
  origna_gta/lib/screens/authwrapper_screen.dart                 # Auth wrapper routing
  origna_gta/lib/core/repositories/auth_repository.dart          # Auth Firestore ops
  origna_gta/lib/core/repositories/user_repository.dart          # User Firestore ops

BACKEND:
  functions/handlers/admin.py                                    # register, roles, MFA, GDPR, seller onboarding
  functions/handlers/payment_stripe.py                           # create_stripe_connect_account
  functions/models/user.py                                       # Python User model
  functions/services/rate_limiter.py                              # Rate limiting

SCHEMA:
  docs/database_schema.json                                      # users, sellers collections
  docs/json_schemas/individual/User.json                         # User JSON schema
  firestore.rules                                                # User/seller security rules
```

### Logic checkpoints:
- [ ] Email verification required before checkout?
- [ ] Role assignment: buyer default, seller on onboarding, admin manual?
- [ ] Stripe Connect account created with seller's actual country (sellers can be worldwide)?
- [ ] Onboarding return URL handles success AND failure?
- [ ] Suspended seller → products deactivated cascade?
- [ ] Rate limiting on login and registration?
- [ ] MFA-gated admin role changes?

---

## 📧 EMAIL NOTIFICATION WORKFLOW

### Files to read together:
```
BACKEND:
  functions/services/email_service.py                            # All email templates + sending
  functions/handlers/orders.py                                   # Triggers email on status change
  functions/handlers/payment_stripe.py                           # Payment failure emails
  functions/handlers/cron_jobs.py                                # Expiry notification emails
```

### Logic checkpoints:
- [ ] Every order status transition sends appropriate email?
- [ ] Email links use correct APP_BASE_URL (emulator vs production)?
- [ ] 3DS authentication email sent when required?
- [ ] Authorization expired email sent on cron detection?

---

## 🔄 CRON JOBS WORKFLOW

### Files to read together:
```
BACKEND:
  functions/handlers/cron_jobs.py                                # All scheduled tasks
  functions/handlers/orders.py                                   # Order status updates called by cron
  functions/handlers/payment_stripe.py                           # Capture/expire called by cron
  functions/check_expired_authorizations.py                      # Standalone auth expiry check
```

### Logic checkpoints:
- [ ] Auto-confirm delivery: 7 days after shipped, correct timestamp math?
- [ ] Expired authorization: 7-day Stripe window, captures or cancels?
- [ ] Archive old orders: 30 days, correct query?
- [ ] Rate limiter cleanup: removes stale entries?
- [ ] Idempotent: running cron twice doesn't double-process?

---

## 🔍 SEARCH & DISCOVERY WORKFLOW

### Files to read together:
```
FRONTEND:
  origna_gta/lib/features/home/home_viewmodel.dart               # Home search
  origna_gta/lib/features/home/home_state.dart                   # Home state
  origna_gta/lib/screens/home_screen.dart                        # Home UI with search
  origna_gta/lib/core/repositories/algolia_product_repository.dart # Algolia queries
  origna_gta/lib/services/algolia_service.dart                   # Algolia client

BACKEND:
  functions/services/algolia_service.py                           # Index sync
  functions/handlers/products.py                                 # Product indexing on create/update/delete
```

---

## 🛡️ SECURITY CROSS-CUT

### Files that must stay in sync for security:
```
firestore.rules                                                  # Database security rules
functions/services/rate_limiter.py                                # API rate limiting
functions/utils/helpers.py                                       # Auth validation helpers
functions/handlers/admin.py                                      # Role management
origna_gta/lib/core/repositories/auth_repository.dart            # Frontend auth
origna_gta/lib/features/auth/auth_provider.dart                  # Auth state
```

---

## 📐 SCHEMA CONSISTENCY CROSS-CUT

### Files that MUST stay in perfect sync:
```
docs/database_schema.json          ← SOURCE OF TRUTH
functions/schema_constants.py      ← Python mirror (field names, enums, collections)
origna_gta/lib/core/schema/schema_constants.dart  ← Dart mirror
functions/models/*.py              ← Python data models
origna_gta/lib/models/generated/*.dart             ← Dart Freezed models
docs/json_schemas/individual/*.json                ← Individual JSON schemas
```

### Validation:
```bash
./scripts/validate_schema_consistency.sh    # Automated check
```
