"""
🛡️ Security Audit Hook — Firestore rules, input validation, API security.
"""
from .base import BaseHook, register_hook
from .prompts import STRUCTURED_OUTPUT_INSTRUCTION, PROJECT_CONTEXT


@register_hook
class SecurityHook(BaseHook):
    """Class SecurityHook."""
    hook_name = "security"
    description = "API security: Firestore rules, input validation, injection, data exposure"
    emoji = "🛡️"

    watch_patterns = [
        "firestore.rules",
        "storage.rules",
        "functions/handlers/*.py",
        "functions/utils/helpers.py",
        "functions/services/rate_limiter.py",
        "functions/config.py",
    ]

    # Optimized: security-critical files, ~97K budget
    target_files = [
        "firestore.rules",                          # 19K — THE access control
        "functions/handlers/payment_stripe.py",     # 94K — payment security
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are a senior application security engineer performing a DEEP security audit.

{PROJECT_CONTEXT}

## Focus Areas

1. **FIRESTORE RULES** — Every collection: who can read? who can write? which fields? Can unauthenticated users access anything? Can user A access user B's data? Are admin-only fields protected?
2. **STORAGE RULES** — Upload restrictions (type, size)? Can users access others' files? Path traversal?
3. **INPUT VALIDATION** — All user inputs validated server-side? Max lengths? Type checking? NoSQL injection via dict keys? Unicode abuse? Script injection in product descriptions?
4. **API ENDPOINTS** — All handlers check auth? Rate limited? CORS configured? HTTP methods restricted?
5. **SECRETS** — API keys exposed to frontend? Stripe secret key in client code? Environment variable handling?
6. **DATA EXPOSURE** — Are Stripe account IDs, internal IDs, or PII leaked in API responses? Verbose error messages?
7. **IDOR (Insecure Direct Object Reference)** — Can user manipulate IDs to access other users' orders, products, profiles?
8. **CSRF/REPLAY** — Webhook replay protection? Idempotency keys? Token reuse?

## Rules
- Check EVERY Firestore rule for EVERY collection
- Assume a sophisticated attacker with a valid account
- Create at least 25 security attack scenarios
- Every finding must reference specific files and line numbers

{STRUCTURED_OUTPUT_INSTRUCTION}

Project files:
"""


@register_hook
class PerformanceHook(BaseHook):
    """Class PerformanceHook."""
    hook_name = "performance"
    description = "Performance: N+1 queries, missing indexes, unnecessary reads, scaling"
    emoji = "⚡"

    watch_patterns = [
        "functions/handlers/*.py",
        "functions/services/algolia_service.py",
        "functions/services/shipping_service.py",
        "functions/handlers/cron_jobs.py",
        "firestore.indexes.json",
        "origna_gta/lib/features/**/*.dart",
        "origna_gta/lib/core/repositories/*.dart",
    ]

    # Optimized: hot-path backend files, ~95K budget
    target_files = [
        "functions/handlers/products.py",            # 29K — product queries
        "functions/handlers/orders.py",              # 43K — order queries
        "functions/handlers/cron_jobs.py",            # 22K — batch jobs
        "functions/services/algolia_service.py",      # 12K — search indexing
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are a senior performance engineer auditing a Firebase-based marketplace at scale.

{PROJECT_CONTEXT}

## Focus Areas (target: 100M+ users/year)

1. **FIRESTORE READS** — N+1 query patterns? Unbounded collection reads? Missing pagination? Unnecessary document reads?
2. **FIRESTORE WRITES** — Batched writes used where appropriate? Transaction overuse? Contention on hot documents?
3. **INDEXES** — Missing composite indexes for queries? Unused indexes?
4. **CLOUD FUNCTIONS** — Cold start optimization? Function size? Timeout handling? Memory limits?
5. **CRON JOBS** — Thundering herd on Stripe/Firestore? Batch processing? Rate limiting against external APIs?
6. **ALGOLIA** — Batch indexing? Index size management? Query optimization?
7. **FRONTEND** — Widget rebuilds? Unnecessary state invalidations? Image loading optimization? Lazy loading?
8. **CACHING** — What should be cached (products, categories)? Cache invalidation strategy?

## Rules
- Focus on what will break at 100M users/year
- Every finding must reference specific files
- Quantify impact where possible (e.g., "This query reads N documents per request")

{STRUCTURED_OUTPUT_INSTRUCTION}

Project files:
"""


@register_hook
class StateMgmtHook(BaseHook):
    """Class StateMgmtHook."""
    hook_name = "state-mgmt"
    description = "State management: Riverpod providers, state consistency, race conditions"
    emoji = "🧠"

    watch_patterns = [
        "origna_gta/lib/features/**/*.dart",
        "origna_gta/lib/core/repositories/*.dart",
        "origna_gta/lib/services/*.dart",
    ]

    # Optimized: Riverpod state files only, ~72K budget
    target_files = [
        "origna_gta/lib/core/repositories/auth_repository.dart",   # 12K
        "origna_gta/lib/features/checkout/checkout_provider.dart", # 11K
        "origna_gta/lib/features/cart/cart_provider.dart",         # 10K
        "origna_gta/lib/features/products/add_product_viewmodel.dart", # 11K
        "origna_gta/lib/core/repositories/order_repository.dart", # 5K
        "origna_gta/lib/features/products/products_provider.dart", # 4K
        "origna_gta/lib/features/orders/seller_orders_viewmodel.dart", # 1.5K
        "origna_gta/lib/features/orders/buyer_orders_viewmodel.dart", # 1.3K
        "origna_gta/lib/features/auth/auth_provider.dart",        # 0.6K
        "origna_gta/lib/features/checkout/checkout_state.dart",   # 3.8K
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are a senior Flutter/Riverpod expert auditing state management.

{PROJECT_CONTEXT}

## Focus Areas

1. **PROVIDER ARCHITECTURE** — Proper use of StateNotifierProvider, FutureProvider, StreamProvider? Circular dependencies?
2. **STATE CONSISTENCY** — Can state become stale after failed operations? Optimistic updates without rollback? Race conditions between providers?
3. **ERROR HANDLING** — Are all async operations wrapped in try-catch? Do providers expose error states? Is the user notified of failures?
4. **MEMORY LEAKS** — Providers not disposed? Stream listeners not cancelled? Controllers not disposed?
5. **AUTH STATE** — Does auth state change propagate to all dependent providers? Can user access stale data after logout?
6. **CHECKOUT STATE** — Can checkout state become inconsistent with backend? Double-submit protection? State machine validation?
7. **CART-CHECKOUT SYNC** — Is cart invalidated after checkout? Can stale cart items cause issues?

## Anti-patterns to flag
- ❌ Provider or Bloc usage (should be Riverpod ONLY)
- ❌ Business logic in screens
- ❌ withOpacity() on colors
- ❌ Hardcoded colors instead of DesignTokens
- ❌ MaterialPageRoute instead of named routes

{STRUCTURED_OUTPUT_INSTRUCTION}

Project files:
"""


@register_hook
class OrdersHook(BaseHook):
    """Class OrdersHook."""
    hook_name = "orders"
    description = "Order lifecycle: creation, status transitions, shipping, delivery, disputes"
    emoji = "📋"

    watch_patterns = [
        "functions/handlers/orders.py",
        "functions/handlers/payment_stripe.py",
        "functions/handlers/cron_jobs.py",
        "functions/models/order.py",
        "functions/services/shipping_service.py",
        "origna_gta/lib/features/orders/*",
    ]

    # Optimized: order lifecycle logic only, ~95K budget
    target_files = [
        "functions/handlers/orders.py",              # 43K — order state machine
        "functions/handlers/cron_jobs.py",            # 22K — auto-capture, cleanup
        "functions/services/shipping_service.py",     # 17K — shipping flow
        "functions/schema_constants.py",             # 16K — status constants
        "functions/models/order.py",                 # 8K  — order model
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are auditing the ORDER LIFECYCLE of an e-commerce marketplace.

{PROJECT_CONTEXT}

## Focus Areas

1. **ORDER STATE MACHINE** — Valid transitions only? Can an order go from "cancelled" to "shipped"? Are transitions enforced server-side?
2. **SHIPPING FLOW** — Tracking number validation? Can seller mark as shipped without tracking? Delivery confirmation integrity?
3. **CANCELLATION** — Can buyer cancel after shipment? Can seller cancel after payment captured? Is refund triggered automatically?
4. **MULTI-SELLER ORDERS** — Are sub-orders independent? Can one seller's failure affect another's order?
5. **STATUS UPDATES** — Are buyer and seller notified? Email triggers correct? Push notification on status change?
6. **ORDER DATA** — Can buyer modify order after creation? Can seller see buyer's personal info they shouldn't?
7. **CRON CLEANUP** — Stale orders cleaned up? Expired authorizations handled?

## Rules
- Create at least 20 order manipulation scenarios
- Every finding must reference specific files

{STRUCTURED_OUTPUT_INSTRUCTION}

Project files:
"""


@register_hook
class ErrorHandlingHook(BaseHook):
    """Class ErrorHandlingHook."""
    hook_name = "errors"
    description = "Error handling: network errors, retries, graceful degradation, Sentry"
    emoji = "🛡️"

    watch_patterns = [
        "functions/handlers/*.py",
        "functions/*.py",
        "origna_gta/lib/features/**/*.dart",
        "origna_gta/lib/core/repositories/*.dart",
    ]

    # Optimized: backend error paths, ~97K budget
    target_files = [
        "functions/handlers/payment_stripe.py",     # 94K — payment errors critical
        "functions/utils/helpers.py",               # 12K — error helpers
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are auditing ERROR HANDLING across the entire stack of an e-commerce marketplace.

{PROJECT_CONTEXT}

## Focus Areas

1. **BACKEND ERROR HANDLING** — Are all external API calls (Stripe, Algolia, Mailjet, R2) wrapped in try-except? Specific exception types caught? Fallback behavior?
2. **NETWORK FAILURES** — What happens when Stripe is down? When Algolia is down? When Firestore is temporarily unavailable?
3. **RETRY LOGIC** — Is there retry with exponential backoff for transient failures? Are retries idempotent?
4. **ERROR RESPONSES** — Are errors returned with proper HTTP status codes? Are internal details (stack traces, Stripe IDs) leaked to clients?
5. **FRONTEND ERROR HANDLING** — Does the UI show meaningful error messages? Are errors caught in all async operations?
6. **PARTIAL FAILURES** — What happens when Firestore write succeeds but Stripe call fails? Compensation/rollback logic?
7. **TIMEOUT HANDLING** — Cloud Function timeout (60s default)? Stripe API timeout? Frontend request timeout?
8. **SENTRY INTEGRATION** — Are errors properly reported? Is PII scrubbed? Are breadcrumbs useful?

{STRUCTURED_OUTPUT_INSTRUCTION}

Project files:
"""


@register_hook
class SellerHook(BaseHook):
    """Class SellerHook."""
    hook_name = "seller"
    description = "Seller onboarding: Stripe Connect, capabilities, payout, terms"
    emoji = "🏪"

    watch_patterns = [
        "functions/handlers/admin.py",
        "functions/handlers/payment_stripe.py",
        "origna_gta/lib/features/seller/*",
        "origna_gta/lib/screens/seller_*.dart",
    ]

    # Optimized: seller onboarding logic, ~93K budget
    target_files = [
        "functions/handlers/admin.py",               # 21K — seller management
        "functions/handlers/payment_stripe.py",     # 94K — Connect onboarding
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are auditing SELLER ONBOARDING & MANAGEMENT in an e-commerce marketplace.

{PROJECT_CONTEXT}

## Focus Areas

1. **STRIPE CONNECT ONBOARDING** — Express account creation flow? Required capabilities checked? Account verification status?
2. **SELLER VERIFICATION** — Can an unverified seller list products? Can they receive payouts without complete verification?
3. **TERMS ACCEPTANCE** — Is terms acceptance recorded with timestamp? Can seller operate without accepting terms?
4. **PRODUCT MANAGEMENT** — Can seller edit/delete products with active orders? Can seller set negative prices?
5. **PAYOUT MANAGEMENT** — Minimum payout threshold? Payout schedule? Can seller manipulate payout amount?
6. **SELLER SUSPENSION** — Can admin suspend seller? Are active orders handled on suspension? Are products delisted?
7. **DATA ACCESS** — Can seller see other sellers' sales data? Can seller see buyer PII beyond shipping address?

{STRUCTURED_OUTPUT_INSTRUCTION}

Project files:
"""
