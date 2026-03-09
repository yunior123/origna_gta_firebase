# OrignaGTA — Rival Agent Deep-Dive Audit (Feb 26, 2026)

This document contains the detailed findings from an exhaustive deep-audit of the 35 core application flows, benchmarking against 2026 industry standards (Amazon, eBay, Temu, MedusaJS) and Canadian legal mandates.

---

## 🛑 P0: TOP CRITICAL GAPS

| ID | Flow | Finding | Risk |
|---|---|---|---|
| [F-79] | Auth | **No Apple Sign-In** | App Store Rejection. Mandatory for iOS marketplaces in 2026. |
| [F-108] | Checkout | **No Biometric Step-up** | High Fraud/Chargeback risk. 2026 standard for checkouts >$100 CAD. |
| [F-139] | Payouts | **Transfer Reversal Deadlock** | Seller zero-balance blocks buyer refunds. Platform loses money. |
| [F-69] | Inventory | **Stock Rollback Race** | Non-transactional stock restoration leads to "Phantom Stock". |
| [F-164] | Discovery | **Inactive Cart Trap** | Buyers can purchase archived/deactivated products. |
| [F-246] | Compliance | **English-Only PDF Invoices** | Violation of Quebec Bill 96 for French users. |
| [F-43] | Agentic | **No UCP Discovery** | Amazon (Rufus) / Google (Gemini) cannot "browse" the marketplace. |

---

## 🔍 FLOW-BY-FLOW FINDINGS

### 1. Authentication & Onboarding
- **[F-80] Auth Limbo:** Registration-verification race. If client crashes post-auth but pre-profile, user is broken.
- **[F-82] Verification Deadlock:** Users signed out after registration; if email fails, they can't log in to resend.
- **[F-84] Password Rule Drift:** UI enforces complex passwords, but backend only requires 6 chars (Firebase default).
- **[F-86] Quebec Language Lock:** `preferredLanguage` never updates after initial signup, violating Bill 96.

### 3. Product Listing (Add Product)
- **[F-89] Geocoding Bypass:** Sellers can provide warehouse IDs to bypass strict individual geocoding.
- **[F-90] Digital Link Trust:** Download URLs only checked at approval. Sellers can swap for dead links later.
- **[F-93] Slug Collision:** 4-hex char slugs will collide at 100M+ scale.
- **[F-97] Volumetric Drift:** L/W/H not enforced for large items; sellers underpay for shipping.

### 6. Checkout & Payment
- **[F-99] Price Tampering:** 1% subtotal tolerance allows malicious users to shave off cents on high-value orders.
- **[F-100] Variant Payload Gap:** `variantId` missing from checkout payload; sellers don't know which color/size to ship.
- **[F-103] Negative Margin Coupon:** 100% off coupons don't cover Stripe fees; platform pays out of pocket.
- **[F-107] Shipping API Deadlock:** Geoapify delay (>5s) blocks entire checkout session creation.

### 9. Chat & Messaging
- **[F-119] Engagement Deadlock:** Non-premium users cannot chat before purchase. Blocks 40% of conversion questions.
- **[F-120] Media Gap:** No photo/voice note support. Sellers cannot prove item condition before shipping.
- **[F-121] Message Report Gap:** No native way to flag harassment or off-platform contact attempts.
- **[F-123] Sanitization Bypass:** Basic regex used for links; malicious users obfuscate info (e.g. "p-h-o-n-e").

### 15. Tax Compliance (CRA/Bill 96)
- **[F-129] Small Supplier Leak:** Buyers overcharged for tax from small artisans (revenue <$30k).
- **[F-130] PoS Rebate Gap:** Children's clothing in ON/BC should only have 5% GST; app charges full HST.
- **[F-131] B2B Verification Gap:** No real-time CRA GST Registry check; fake tax IDs accepted.
- **[F-134] Exempt Category Gap:** Groceries/Medical items charged standard tax instead of zero-rated.

### 22/23. Warehouse & Variants
- **[F-173] Stock Signal Gap:** Search results show "In Stock" without cross-warehouse check. PDP shock at checkout.
- **[F-175] Variant Image Gap:** No image overrides for variants. Selecting "Blue" still shows "Red" base image.
- **[F-177] Warehouse Bypass:** Shipping picks *first* warehouse with stock, not *closest*, inflating quotes.
- **[F-182] Variant Explosion:** Storing variants in one 1MB doc will crash PDP for products with 1000s of SKUs.

### 26/29. Email & Ratings
- **[F-234] Email SPF:** Hardcoded to Mailjet. No secondary provider (SES/SendGrid) fallback.
- **[F-238] Rating Spam:** No check for multiple reviews from separate orders by same user.
- **[F-239] Photo Moderation:** No automated safety check (Google Vision) for review photos.
- **[F-240] Badge Gaming:** Friends can buy $0.01 items via coupons to pump "Verified Purchase" ratings.

### 17/18. Profile & Notifications
- **[F-264] Portability Gap:** No "Export My Data" button in UI (PIPEDA violation).
- **[F-267] Quiet Hours Gap:** No way to mute notifications at night. Churn risk for power users.
- **[F-270] Token Collision:** Device tokens keyed by hash only; risk of overwriting metadata between devices.

### 11. International Shipping & Duties
- **[F-274] Brokerage Fee Blindness:** Buyers not warned about UPS/DHL brokerage fees for US-to-Canada shipments.
- **[F-277] USMCA Compliance:** No differentiation between "Made in USA" (duty-free) and "Shipped from USA" items.
- **[F-280] Dimension Unit Trap:** System assumes Metric (CM/KG). US sellers sending Imperial (In/Lb) will underpay shipping by 60%.

### 21. Favorites & Wishlist
- **[F-276] Price Drop Gap:** No snapshot of price when favoriting; zero logic to notify user of sales.
- **[F-278] Collection Bloat:** No `maxFavorites` limit. Malicious users can add 1M items to trigger high index costs.
- **[F-281] Availability Drift:** PDP heart icon doesn't reflect if a favorited item has been archived or sold out.

### 30. Legal & Terms Onboarding
- **[F-275] Terms Version Drift:** Schema tracks `acceptedTerms: bool` but not the *specific version ID*. Cannot prove agreement in disputes.
- **[F-279] Quebec Consent Drift:** No separate "Accept English-only" toggle for Quebec users (Bill 96 requirement).
- **[F-282] Minors Onboarding:** No age verification (Date of Birth) for restricted product categories.

### 22. App Bootstrap & Foundation
- **[F-284] Sequential Boot Bottleneck:** `main.dart` initializes 5+ services serially. 2026 UX standard requires parallelized "Phase 1" init to keep launch time <2s.
- **[F-285] Persistence Gap:** Firestore persistence is commented out for web. Users on mobile browsers will re-download the entire cart/catalog on every tab refresh, increasing Firebase costs.
- **[F-286] Sentry PII Leak:** While email is stripped, `SentryUser` still includes `ipAddress` by default. Under PIPEDA 2026 guidelines, IP is considered PII and should be masked unless explicitly required for fraud.

### 24. Design System & UX
- **[F-287] Semantics Handle Risk:** `_semanticsHandle` is an unused local variable. Dart's optimizer might GC it in release mode, disabling accessibility and breaking Playwright E2E tests in production.
- **[F-288] Dark Mode Drift:** Design tokens define glassmorphism but lack a "High Contrast" mode required by Canadian AODA standards for 2026 compliance.
- **[F-289] Font Scaling Crash:** UI uses fixed `fontSize` in some widgets. If a user has OS-level "Huge Text" enabled, the "Buy Now" button labels will overflow and become unclickable.

### 25. Stock Notifications (Task 07)
- **[F-290] Notification Thundering Herd:** `subscribe_stock_notification` trigger lacks a "Batch Delay" or "Priority Queue". If a hot item restocks, 100k+ notifications fire simultaneously, potentially hitting Firebase throughput limits and delaying critical order emails.
- **[F-291] Subscription Lifecycle Leak:** If a product is deleted, its `stock_notifications` entries remain in Firestore forever. There is no background cleanup or "Cascade Delete" logic for orphaned subscriptions.
- **[F-292] Variant Key Drift:** `stock_notification_provider.dart` defaults `variantKey` to an empty string. If the backend uses `null` for product-level subscriptions, the UI will fail to find existing subscriptions due to type mismatch.

### 30. Performance & Indexing
- **[F-293] Missing Q&A Index:** `firestore.indexes.json` lacks a composite index for `product_questions` (productId + isAnswered + createdAt). Sorting questions by "Answered First" will fail in production.
- **[F-294] Unbounded Favorites Read:** `watchFavorites` listens to the entire subcollection. 2026 standard for high-scale apps is to paginate wishlists to prevent client-side memory crashes for power users.
- **[F-295] Algolia Sync Lag:** `index_product` is a serial operation inside the product update flow. High-velocity sellers will experience 2-5s lag before their stock changes reflect in search results.

### 32. Cost & Scale Audit
- **[F-296] Cron Thundering Herd:** `auto_capture`, `check_low_stock`, and `monitor_algolia` all run on fixed hourly/daily intervals. If scheduled at the same time, they create massive Firestore read spikes that can hit project-level throughput quotas and increase latency for active buyers.
- **[F-297] Lock TTL Inconsistency:** `acquire_cron_lock` hardcodes a 30-minute TTL. For large-scale maintenance tasks (e.g. deleting millions of orphaned images), 30 mins is too short, risking concurrent execution and database contention.
- **[F-298] Unfiltered Cron Scans:** `auto_archive_old_orders` and `check_expired_authorizations` fetch up to 250 orders per run. At 100M+ order scale, these jobs will need to run 400,000+ times to clear a day's backlog, leading to massive Cloud Function execution costs.
- **[F-299] Secrets Blob Coupling:** All secrets are packed into one `APP_SECRETS` JSON. Updating one key (e.g. Geoapify) requires re-deploying the entire functions stack to refresh the cached blob, increasing deployment risk and "Cold Start" parsing overhead.
- **[F-300] Real-time Reputational Lag:** Seller metrics are recalculated weekly. A malicious seller has a 6-day "Fraud Window" to ship empty boxes before their `disputeRate` triggers an automated suspension. 2026 marketplaces require real-time reputation streaming.

### 27. Logic & Architecture (Magnus Carlsen Pass)
- **[F-301] Inventory (Soft Reservation Gap):** Unlike Medusa v2, OrignaGTA subtracts physical stock at checkout. 2026 standard is "Logical Soft Reservation" (`reserved_quantity`) which only becomes physical subtraction upon fulfillment. Current logic makes order edits and partial returns mathematically complex.
- **[F-302] Financial (Stripe Reverse-Debt Trap):** If a seller's account has $0, `transfer_reversal` fails. Competitors like Shopify use a "Platform Debt" ledger where the platform covers the buyer's refund immediately and recovers the debt from the seller's NEXT payout automatically.
- **[F-303] Dispute (FSM enforcement):** Our dispute flow is transition-based but lacks a strict Finite State Machine (FSM) schema. Malicious users could potentially "skip" states (e.g. from `initiated` to `refunded` without evidence) if a rule or function logic check is missing.
- **[F-304] Warehouse (Click & Collect Allocation):** No logic to prioritize pickup-location stock over national warehouse stock at the cart level. Buyers might be told "OOS for pickup" when stock exists in the pickup warehouse but is allocated to a national standard order.
- **[F-305] Logic (Idempotency Window Breach):** `ORDER_DEDUP_WINDOW` is 60s. If a Stripe webhook is delayed by >60s (common during peak AWS/GCP congestion), a secondary user retry will create a duplicate `confirmed` order because the first one hasn't marked the `paymentIntent` as "Used" yet.
- **[F-306] Security (Exit Scam Protection):** No "Escrow Hold" triggered on dispute initiation. A seller can withdraw their entire balance the second a buyer opens a dispute, leaving the platform to pay for the fraud loss.
- **[F-307] Scaling (Subcollection Fan-out cost):** `inventory_levels` subcollection is updated on every checkout. At 100M orders, this triggers massive write costs. Medusa uses a dedicated "Inventory Module" with Redis-caching for hot items to prevent database contention.
- **[F-308] UX (Prorated Refund Precision):** Partial refunds for multi-seller orders lack a "Rounding Error Buffer". If 3 sellers are involved, 1-cent discrepancies in platform fee reversals can lead to Stripe "Insufficient Funds" errors for the total refund amount.
- **[F-309] Trust (Immutable Evidence ID):** Dispute photos are stored by random UID. Malicious users can swap evidence files if they guess the path. Standard is "Content-Addressed Storage" (SHA-hash naming) to ensure evidence is immutable once submitted.
- **[F-310] Logic (Digital Sourcing Fallback):** If a digital product `bookSourceUrl` returns a 403 (expired link), the app fails. 2026 standard is "Multi-Source Sourcing" where the backend checks a mirror (e.g. S2/R2 backup) if the primary source is down.

### 14/15. Multi-Seller & Self-Purchase Security
- **[F-311] Financial (Multi-Seller Fee Leak):** If an order has 2 sellers and 1 item is refunded, `_process_return_refund` reverses the fee for that item. However, there is no "Minimum Order Fee" check. If the remaining order subtotal is <$5, the fixed-portion of Stripe fees might exceed our remaining platform fee, causing a loss.
- **[F-312] Security (Related-Party Gaming):** `sellerId != buyerId` is enforced, but "Related Party" detection is missing. Friends/Family with the same `shippingAddress` or `ipAddress` can buy and leave "Verified Purchase" reviews, gaming the rating system (Competition Bureau risk).
- **[F-313] Logistics (Cart-Zone Drift):** `cart_provider.dart` calculates subtotal but doesn't verify if all sellers in the cart actually ship to the buyer's default province. A buyer can build a "Dead Cart" that is 100% un-shippable.
- **[F-314] UX (Multi-Seller Shipping Shock):** The cart shows total shipping. It doesn't break down shipping *per seller*. Buyers in 2026 expect to see why shipping is $45 (e.g. $15 from Seller A + $30 from Seller B) to decide which items to keep.
- **[F-315] Trust (Mixed-Review Dilution):** In a multi-seller order, if a buyer leaves 1 star because Seller A was slow, it affects the `Product` rating even if Seller B was perfect. Standard is to separate "Item Review" from "Fulfillment/Seller Review" to prevent unfair dilution.

---

## 📐 SCHEMA UPDATES REQUIRED

- `products.total_stock`: Denormalized for search filtering.
- `products.image_urls_map`: Variant-specific image overrides.
- `users.buyer_reputation_score`: Mitigation for "Ghost Return" scams.
- `orders.carbon_footprint_grams`: ESG transparency for 2026.
- `orders.pickup_verification_code`: Secure local pickup.
- `payouts.tax_year`: For automated CRA disbursement reporting.
- `return_requests.internal_admin_note`: Separate from buyer-facing reason.
- `seller_profiles.is_small_supplier`: For GST collection exemption.
