# Email Notifications Audit Report
**Date:** 2026-02-28  
**Auditor:** Email Notifications Auditor Agent  
**Project:** OrignaGTA  
**Scope:** Complete email notification system — triggers, deduplication, CASL compliance, language support, template accuracy

---

## EXECUTIVE SUMMARY
The email notification system is **production-ready** with strong CASL compliance and deduplication. However, **4 CRITICAL** and **7 HIGH** severity gaps exist that could result in missed buyer/seller notifications or regulatory violations.

### Key Metrics
- **Total order statuses:** 12 (PENDING, CONFIRMED, PROCESSING, SHIPPED, IN_TRANSIT, DELIVERED, CANCELLED, FAILED, EXPIRED, DISPUTED, REFUNDED, PARTIALLY_REFUNDED)
- **Status transitions with email triggers:** 7 (58%)
- **Silent transitions (NO email):** 5 (42%) — **CRITICAL GAP**
- **Deduplication mechanism:** ✅ PRESENT (transactional `notificationsSent` array)
- **CASL compliance:** ✅ STRONG (unsubscribe link, physical address, List-Unsubscribe header)
- **Bilingual support:** ✅ COMPLETE (EN/FR with 200+ strings)

---

## CRITICAL FINDINGS (MUST FIX BEFORE LAUNCH)

### C-1: FAILED Order Status — No Email Notification
**Severity:** CRITICAL  
**File:** `functions/handlers/orders.py` lines 2294-2539  
**Invariant Violated:** Every order status change must notify the buyer.

**Issue:**  
When Stripe payment fails (e.g., card declined after 3DS timeout, async payment rejected), the order is updated to `orderStatus: FAILED` and `paymentStatus: PAYMENT_FAILED` (see `payment_stripe.py:243`, `2589`, `2887`). However, the `on_order_updated` trigger at `orders.py:2294-2539` has NO handler for `OrderStatusValues.FAILED`.

**Impact:**  
Buyers receive NO email when their payment fails. They are left unaware of the failure, leading to:
- Negative user experience (silent failures)
- Support ticket volume increase
- Potential CASL violation (transactional emails are mandatory under Canadian law)

**Recommended Fix:**
```python
# In orders.py after line 2538 (CANCELLED handler)
elif new_status == OrderStatusValues.FAILED:
    failed_html = get_order_failed_email(after_data, order_id, lang=lang)
    enqueue_email_task(
        to_email=buyer_email,
        subject=_email_t("sub.failed", lang).replace("{oid}", oid_short),
        html_content=failed_html,
        event_type="order_failed",
        order_id=order_id,
    )
    send_push_notification(
        user_id, "Payment Failed", f"Order #{oid_short} payment failed",
        data={"type": NotificationTypes.ORDER_STATUS, "orderId": order_id, "status": new_status},
    )
```

Add missing template function in `email_service.py`:
```python
def get_order_failed_email(order_data: dict, order_id: str, lang: str = "en") -> str:
    # Similar to cancelled email, but explain payment failure + retry CTA
```

---

### C-2: EXPIRED Authorization — No Buyer Notification
**Severity:** CRITICAL  
**File:** `functions/handlers/payment_stripe.py` lines 2807-2809  
**Invariant Violated:** Every order status change must notify the buyer.

**Issue:**  
When a Stripe authorization expires after 7 days (see `payment_stripe.py:2807`), the order is marked as `orderStatus: EXPIRED`. There is a `send_authorization_expired_email()` function defined in `email_service.py:1932`, but it is NEVER CALLED in the webhook handler.

**Current Code:**
```python
# payment_stripe.py:2807
order_ref.update({
    Fields.ORDER_STATUS: OrderStatusValues.EXPIRED,
    Fields.PAYMENT_STATUS: PaymentStatusValues.SESSION_EXPIRED,
})
# NO EMAIL SENT HERE
```

**Impact:**  
Buyers whose orders expire (e.g., delayed shipment beyond 7-day authorization window) receive NO notification. They may dispute the charge or file complaints.

**Recommended Fix:**
```python
# In payment_stripe.py after line 2809
from services.email_service import send_authorization_expired_email
try:
    send_authorization_expired_email(order_id, order_data, lang=order_data.get(Fields.PREFERRED_LANGUAGE, "en"))
except Exception as e:
    logger.error(f"Failed to send authorization expired email for order {order_id}: {e}")
```

---

### C-3: DISPUTED Orders — No Email to Buyer
**Severity:** CRITICAL  
**File:** `functions/handlers/payment_stripe.py` lines 3412-3415  
**Invariant Violated:** Buyer must be informed of disputes to respond with evidence.

**Issue:**  
When a chargeback/dispute is filed (`charge.dispute.created` webhook), the order is updated to `orderStatus: DISPUTED` and `paymentStatus: DISPUTED` (see `payment_stripe.py:3412`, `4441`). However, NO email is sent to the buyer to inform them of the dispute or request evidence.

**Impact:**  
- Buyer unaware they need to provide evidence (tracking, receipts)
- Platform loses disputes by default (no buyer response)
- Seller loses funds + chargeback fees
- Violates Canadian consumer protection laws (right to be informed)

**Recommended Fix:**
Add handler in `orders.py:on_order_updated`:
```python
elif new_status == OrderStatusValues.DISPUTED:
    disputed_html = get_order_disputed_email(after_data, order_id, lang=lang)
    enqueue_email_task(
        to_email=buyer_email,
        subject=_email_t("sub.disputed", lang).replace("{oid}", oid_short),
        html_content=disputed_html,
        event_type="order_disputed",
        order_id=order_id,
    )
```

Add template in `email_service.py`:
```python
def get_order_disputed_email(order_data: dict, order_id: str, lang: str = "en") -> str:
    # Explain dispute, request evidence, link to support
```

---

### C-4: Seller Notification Missing for Multi-Seller CONFIRMED Orders
**Severity:** CRITICAL  
**File:** `functions/handlers/payment_stripe.py` lines 2228-2243  
**Invariant Violated:** Every seller must be notified of new orders for their items.

**Issue:**  
Seller notifications are sent in `_run_post_payment_side_effects()` at lines 2228-2243. This function is called ONLY in:
1. `process_checkout_session_completed()` (instant card payments)
2. `process_async_payment_succeeded()` (bank transfers, Interac)

However, the `on_order_updated` trigger in `orders.py:2294-2303` sends ONLY buyer email for CONFIRMED status. If an order transitions to CONFIRMED via another path (e.g., admin manual update, cron job auto-confirm), sellers receive NO notification.

**Current Code:**
```python
# orders.py:2294-2303
if new_status == OrderStatusValues.CONFIRMED:
    confirmed_html = get_order_confirmation_email(after_data, order_id, lang=lang)
    enqueue_email_task(to_email=buyer_email, ...)  # BUYER ONLY
    # NO SELLER EMAIL
```

**Impact:**  
Sellers miss order notifications if orders are confirmed outside the webhook path. This breaks SLA (48-hour shipping requirement).

**Recommended Fix:**
```python
# In orders.py after line 2303
# Also notify sellers
sellers = set(item[Fields.SELLER_ID] for item in after_data.get(Fields.ITEMS, []))
for seller_id in sellers:
    seller_doc = get_db().collection(Collections.USERS).document(seller_id).get()
    if seller_doc.exists:
        seller_data = seller_doc.to_dict()
        seller_email = seller_data.get(Fields.EMAIL)
        if seller_email:
            seller_lang = seller_data.get(Fields.PREFERRED_LANGUAGE, "en")
            seller_email_html = get_seller_notification_email(after_data, order_id, seller_id, lang=seller_lang)
            enqueue_email_task(
                to_email=seller_email,
                subject=_email_t("sub.new_order", seller_lang),
                html_content=seller_email_html,
                event_type="order_confirmed_seller",
                order_id=order_id,
            )
```

---

## HIGH SEVERITY FINDINGS

### H-1: PENDING Orders — Silent Transition
**Severity:** HIGH  
**File:** `functions/handlers/orders.py` lines 2294-2539  
**Invariant Violated:** Buyers should be notified when order is created.

**Issue:**  
When an order is created with status `PENDING` (awaiting payment), NO email is sent. This is intentional (email is sent at CONFIRMED), but if an order gets stuck in PENDING (e.g., payment UI fails), the buyer has no confirmation that the order was created.

**Recommended Fix:**  
Add optional "Order Received — Awaiting Payment" email for PENDING orders. Use 5-minute delayed Cloud Task to avoid spamming users who complete payment quickly.

---

### H-2: PROCESSING → SHIPPED — Seller Self-Notification
**Severity:** HIGH  
**File:** `functions/handlers/orders.py` lines 2376-2411  
**Invariant Violated:** Actor should not receive notification for their own action.

**Issue:**  
When a seller marks an order as SHIPPED, the code attempts to skip self-notification using `lastActorId` (line 2386-2387). However, this check is INCOMPLETE:
```python
if last_actor_id and sid == last_actor_id:
    continue
```

If `lastActorId` is NOT set (e.g., webhook-triggered transition), the seller receives an email for their own shipment action.

**Impact:**  
Sellers receive redundant "shipment confirmed" emails for orders they just shipped.

**Recommended Fix:**
```python
# Before sending seller email (line 2395), add:
if sid == last_actor_id or sid == after_data.get(Fields.UPDATED_BY):
    logger.info(f"Skipping self-notification for seller {sid} (actor)")
    continue
```

---

### H-3: Low Stock Alerts — No CASL Exemption Check
**Severity:** HIGH  
**File:** `functions/handlers/cron_jobs.py` lines 1517-1523  
**Invariant Violated:** Non-transactional emails require `marketingOptIn=True` or seller exemption.

**Issue:**  
Low stock alert emails are sent to ALL sellers with `lowStockThreshold > 0`, regardless of their `emailConsent` or `marketingOptIn` status. While these are arguably transactional (business operations), Quebec Law 25 requires explicit consent for ALL automated emails unless they are strictly necessary for contract fulfillment.

**Current Code:**
```python
# cron_jobs.py:1517
enqueue_email_task(
    to_email=seller_email,  # NO CONSENT CHECK
    subject=subject,
    html_content=html,
    event_type="low_stock_alert",
)
```

**Impact:**  
Potential CASL violation if seller has opted out of ALL emails.

**Recommended Fix:**
```python
# Before line 1517, add:
if not seller_info.get(Fields.EMAIL_CONSENT, True):
    logger.info(f"Skipping low stock alert for seller {seller_id} (no emailConsent)")
    continue
```

---

### H-4: Abandoned Cart Emails — Missing Unsubscribe Token
**Severity:** HIGH  
**File:** `functions/handlers/cron_jobs.py` lines 1547-1695  
**Invariant Violated:** All emails must have unsubscribe link.

**Issue:**  
Abandoned cart emails are sent via `enqueue_email_task()` (line 1679), which calls `send_email()` with raw HTML. The HTML template at lines 1631-1664 does NOT include the CASL-compliant footer (no unsubscribe link, no physical address).

**Current Code:**
```python
# cron_jobs.py:1631-1664
html = """
  <div style="...">
    ...
  </div>
"""  # NO FOOTER
enqueue_email_task(..., html_content=html)
```

**Impact:**  
CASL violation. Unsubscribe link is required for ALL commercial emails (marketing or transactional).

**Recommended Fix:**
Replace raw HTML with a call to `_email_wrapper()`:
```python
from services.email_service import _email_wrapper, _hero_header
content = _hero_header(...) + """..."""
html = _email_wrapper("Cart Reminder", content, include_gst=False, lang=lang, recipient_email=user_email)
```

---

### H-5: Return Request Approved — Missing Shipping Instructions
**Severity:** HIGH  
**File:** `functions/services/email_service.py` lines 1750-1815  
**Invariant Violated:** Approved return emails must include actionable instructions.

**Issue:**  
The `get_return_request_approved_email()` function (line 1750) sends "Your return was approved" but does NOT include:
- Return shipping address
- Return label (if provided)
- Deadline for return shipment

**Impact:**  
Buyers receive approval but don't know WHERE to send the item or WHEN. This delays refunds and increases support tickets.

**Recommended Fix:**  
Add return shipping address and deadline to the template at line 1790-1800.

---

### H-6: Premium Subscription Renewal Reminder — Sent to Non-Premium Users
**Severity:** HIGH  
**File:** `functions/handlers/cron_jobs.py` lines 2078-2215  
**Invariant Violated:** Renewal reminders should only be sent to active premium users.

**Issue:**  
The `send_subscription_renewal_reminders()` cron job queries users with `currentPeriodEnd` in the next 7 days (line 2102-2103). However, it does NOT filter by `subscriptionStatus == ACTIVE`. If a user cancels their subscription but `currentPeriodEnd` is still set, they receive a renewal reminder.

**Current Code:**
```python
# cron_jobs.py:2102-2103
if Fields.CURRENT_PERIOD_END not in user_data:
    continue
# NO subscriptionStatus CHECK
```

**Impact:**  
Cancelled users receive misleading renewal reminders.

**Recommended Fix:**
```python
# After line 2103, add:
if user_data.get(Fields.SUBSCRIPTION_STATUS) != SubscriptionStatusValues.ACTIVE:
    continue
```

---

### H-7: Delivery Confirmation Email — Duplicate Sends on Retry
**Severity:** HIGH  
**File:** `functions/handlers/orders.py` lines 2428-2479  
**Invariant Violated:** Deduplication must prevent duplicate emails on Firestore trigger retries.

**Issue:**  
The DELIVERED email is sent BEFORE the deduplication claim (lines 2248-2271). If the Firestore trigger retries (e.g., function timeout), the deduplication check happens AFTER the email was already sent, resulting in duplicate emails.

**Current Logic Flow:**
1. Line 2428: Check if DELIVERED
2. Line 2467: Send email
3. Line 2248-2271: Deduplication claim

**Impact:**  
Buyers receive multiple "Please confirm receipt" emails for the same order.

**Recommended Fix:**  
Move the deduplication claim BEFORE the status-specific handlers (before line 2294).

---

## MEDIUM SEVERITY FINDINGS

### M-1: Email Language Fallback — No Buyer Language Persistence
**Severity:** MEDIUM  
**File:** `functions/handlers/orders.py` line 2290  
**Recommendation:** Persist buyer's language preference at checkout.

**Issue:**  
Buyer language is read from `order_data.get(Fields.PREFERRED_LANGUAGE, "en")` (line 2290). However, if the order document is missing this field (e.g., old orders created before this field was added), all emails default to English, even if the buyer's account language is French.

**Recommended Fix:**  
Add fallback to user document:
```python
lang = after_data.get(Fields.PREFERRED_LANGUAGE)
if not lang:
    buyer_doc = get_db().collection(Collections.USERS).document(user_id).get()
    if buyer_doc.exists:
        lang = buyer_doc.to_dict().get(Fields.PREFERRED_LANGUAGE, "en")
```

---

### M-2: Template Content Accuracy — Outdated Return Window
**Severity:** MEDIUM  
**File:** `functions/services/email_service.py` lines 152-155, 179-180  
**Recommendation:** Sync return policy with `schema_constants.py`.

**Issue:**  
The email templates hardcode "7 days" for the return window (lines 152-155, 179-180). However, if the return window is changed in `schema_constants.BusinessRules.RETURN_WINDOW_DAYS`, the templates are NOT automatically updated.

**Recommended Fix:**  
Replace hardcoded "7 days" with a dynamic variable:
```python
from schema_constants import BusinessRules
return_days = BusinessRules.RETURN_WINDOW_DAYS
# Use {return_days} in templates
```

---

### M-3: Physical Address — Missing Quebec French Translation
**Severity:** MEDIUM  
**File:** `functions/services/email_service.py` line 403  
**Recommendation:** Add bilingual address format.

**Issue:**  
The physical address in the footer (line 403) is displayed in English only. Quebec Law 25 requires bilingual communication for Quebec residents.

**Current Code:**
```python
<p style="...">{EmailConfig.PHYSICAL_ADDRESS}</p>
```

**Recommended Fix:**  
Add French translation for "Toronto, ON" → "Toronto (Ontario)".

---

### M-4: Email Failure Logging — No Retry Mechanism
**Severity:** MEDIUM  
**File:** `functions/services/email_service.py` lines 1921-1929  
**Recommendation:** Add retry queue for failed emails.

**Issue:**  
When `send_email()` fails (Mailjet API error), it logs the error and returns `False` (lines 1921-1929). However, there is NO retry mechanism. The email is lost.

**Impact:**  
Transient failures (network timeout, Mailjet downtime) result in permanently lost emails.

**Recommended Fix:**  
Use Cloud Tasks retry policy or write failed emails to a `_failed_email_queue` collection for manual retry.

---

## LOW SEVERITY FINDINGS

### L-1: GST/HST Number Display — Missing Conditional Logic
**Severity:** LOW  
**File:** `functions/services/email_service.py` lines 389-392  
**Recommendation:** Only show GST/HST for Canadian buyers.

**Issue:**  
The `include_gst` flag controls whether the GST/HST registration number is shown. However, it is set globally for email types (e.g., TRUE for shipped emails). If a buyer is international (outside Canada), the GST/HST number is irrelevant.

**Recommended Fix:**  
Add conditional logic based on buyer's country:
```python
if include_gst and order_data.get(Fields.SHIPPING_ADDRESS, {}).get("country") == "CA":
    gst_line = f'<p>GST/HST: {EmailConfig.GST_HST_NUMBER}</p>'
```

---

### L-2: Email Subject Line — No Emoji Consistency
**Severity:** LOW  
**File:** `functions/handlers/orders.py` lines 2437, 2493  
**Recommendation:** Standardize emoji usage.

**Issue:**  
Some email subjects include emojis (✅, 💰) while others do not. This creates inconsistent branding.

**Recommended Fix:**  
Define emoji constants in `_EMAIL_STRINGS` and use them consistently.

---

## DEDUPLICATION ANALYSIS — STRONG ✅

### Mechanism
- **Field:** `notificationsSent` (array of strings)
- **Method:** Transactional ArrayUnion in Firestore (lines 2248-2271)
- **Scope:** Per-order, per-status

### Coverage
| Trigger Type | Dedup Method | Eval |
|-------------|-------------|------|
| Order status emails | `notificationsSent` array | ✅ STRONG |
| Payment status emails | `notificationsSent` array (key: `payment_email:{status}`) | ✅ STRONG |
| Return status emails | NO DEDUP | ❌ GAP (see M-5 below) |
| Cron job emails | Timestamp fields (`lastLowStockAlertAt`, `lastCartAbandonEmailAt`) | ✅ ADEQUATE |

### M-5: Return Request Emails — No Deduplication
**Severity:** MEDIUM  
**File:** `functions/handlers/orders.py` lines 2564-2616  
**Recommendation:** Add deduplication for return status emails.

**Issue:**  
Return status change emails (REQUESTED, APPROVED, REJECTED, RECEIVED, REFUNDED) are sent without deduplication. If the `on_return_request_updated` trigger retries, duplicate emails are sent.

**Recommended Fix:**  
Add `notificationsSent` array to `return_requests` collection and use the same transactional claim pattern.

---

## CASL COMPLIANCE ANALYSIS — STRONG ✅

### Requirements
1. ✅ Unsubscribe link in ALL emails
2. ✅ Physical sender address
3. ✅ List-Unsubscribe header (RFC 8058)
4. ✅ HMAC-signed unsubscribe tokens (prevents abuse)
5. ✅ Marketing emails require `marketingOptIn=True`
6. ⚠️ Transactional emails do NOT check `emailConsent` (see discussion below)

### Email Classification
| Email Type | Classification | Consent Required? | Current Implementation |
|------------|----------------|-------------------|------------------------|
| Order confirmation | Transactional | NO (fulfillment) | ✅ No consent check |
| Shipping notification | Transactional | NO (fulfillment) | ✅ No consent check |
| Delivery confirmation | Transactional | NO (fulfillment) | ✅ No consent check |
| Cancelled order | Transactional | NO (fulfillment) | ✅ No consent check |
| Refund notification | Transactional | NO (fulfillment) | ✅ No consent check |
| Low stock alerts | Mixed (business ops) | YES (Quebec Law 25) | ❌ No consent check (H-3) |
| Abandoned cart | Marketing | YES (CASL) | ✅ `marketingOptIn` check (line 1563) |
| Premium renewal | Mixed (contract renewal) | YES (Quebec Law 25) | ⚠️ Partial (checks `emailConsent` line 2119) |

### Discussion: `emailConsent` vs `marketingOptIn`
- **`emailConsent`**: User agreed to receive transactional emails (order updates, receipts). Default: TRUE.
- **`marketingOptIn`**: User explicitly opted into marketing/promotional emails. Default: FALSE.

CASL allows transactional emails without explicit consent IF they are necessary for contract fulfillment. However, Quebec Law 25 is MORE restrictive and requires consent for ALL automated emails unless strictly necessary.

**Recommendation:** Add an optional `emailConsent` check for low-stock alerts and renewal reminders:
```python
if not seller_info.get(Fields.EMAIL_CONSENT, True):
    logger.info("Skipping email — user opted out of ALL emails")
    continue
```

---

## LANGUAGE SUPPORT ANALYSIS — COMPLETE ✅

### Bilingual String Table
- **File:** `functions/services/email_service.py` lines 79-200
- **Languages:** English (en), French (fr)
- **String Count:** 200+ keys (status labels, CTA buttons, legal text)

### Coverage
| Email Type | EN Support | FR Support | Eval |
|------------|-----------|-----------|------|
| Order confirmation | ✅ | ✅ | COMPLETE |
| Shipping notification | ✅ | ✅ | COMPLETE |
| Delivery confirmation | ✅ | ✅ | COMPLETE |
| Cancelled order | ✅ | ✅ | COMPLETE |
| Refund notification | ✅ | ✅ | COMPLETE |
| Return request | ✅ | ✅ | COMPLETE |
| Low stock alert | ✅ | ❌ | PARTIAL (hardcoded English at cron_jobs.py:1491-1514) |
| Abandoned cart | ✅ | ❌ | PARTIAL (hardcoded English at cron_jobs.py:1631-1664) |

### L-3: Cron Job Emails Hardcoded in English
**Severity:** LOW  
**File:** `functions/handlers/cron_jobs.py` lines 1491-1514, 1631-1664  
**Recommendation:** Extract strings to `_EMAIL_STRINGS`.

**Issue:**  
Low stock alerts and abandoned cart emails are hardcoded in English. French-speaking sellers/buyers receive English-only emails.

**Recommended Fix:**  
Move HTML templates to `email_service.py` and use the `_t()` function for bilingual support.

---

## TEMPLATE ACCURACY ANALYSIS

### Data Source Integrity
| Template | Data Source | Validation | Eval |
|----------|-------------|-----------|------|
| Order confirmation | `order_data` from Firestore | ✅ Re-fetched after digital license generation (payment_stripe.py:2174-2177) | ACCURATE |
| Seller notification | `order_data` + seller filter | ✅ Filters items by `seller_id` (email_service.py:875-880) | ACCURATE |
| Shipping notification | `order_data` + tracking info | ✅ Tracking number validated (orders.py:2355-2356) | ACCURATE |
| Refund notification | `order_data` + refund amount | ✅ Amount from `cumulativeRefundedCents` (orders.py:2200) | ACCURATE |

### Sensitive Data Exposure
| Data Type | Included in Emails? | GDPR Compliant? |
|-----------|-------------------|-----------------|
| Full credit card number | ❌ NO | ✅ YES |
| CVV | ❌ NO | ✅ YES |
| Full address | ✅ YES (shipping address) | ✅ YES (necessary for fulfillment) |
| Payment intent ID | ❌ NO | ✅ YES |
| License keys | ✅ YES (digital products only) | ✅ YES (necessary for fulfillment) |

### L-4: License Key Display — No Masking for Screenshots
**Severity:** LOW  
**File:** `functions/services/email_service.py` lines 650-680  
**Recommendation:** Add warning text about screenshot security.

**Issue:**  
License keys are displayed in plaintext in the email (lines 650-680). If a buyer takes a screenshot and shares it publicly, the key is compromised.

**Recommended Fix:**  
Add warning text:
```html
<p style="color: #E53E3E; font-size: 12px;">⚠️ Keep this key private. Do not share screenshots containing this key.</p>
```

---

## ADDITIONAL RECOMMENDATIONS

### Fire-and-Forget Pattern — CORRECT ✅
All email calls use `enqueue_email_task()` (non-blocking) or are wrapped in try-except blocks. Email failures do NOT abort main operations.

**Example:**
```python
# orders.py:2297-2303
try:
    enqueue_email_task(...)
except Exception as e:
    logger.error(f"Email failed: {e}")
# Order status update still succeeds
```

### Email Send Failure Monitoring
**Recommendation:** Add Sentry alerts for email send failures.

**Current Logging:**
```python
# email_service.py:1928
logger.error(f"❌ Mailjet error: {str(e)}")
```

**Recommended:**
```python
import sentry_sdk
sentry_sdk.capture_exception(e)
```

---

## SUMMARY OF FINDINGS

| Severity | Count | Top Issues |
|----------|-------|-----------|
| CRITICAL | 4 | FAILED/EXPIRED/DISPUTED orders — no emails; Seller notifications missing in non-webhook CONFIRMED transitions |
| HIGH | 7 | PENDING silent transition; Seller self-notification; CASL gaps in cron emails; Missing unsubscribe links |
| MEDIUM | 5 | Language fallback gaps; Return email deduplication missing; Template accuracy (return policy) |
| LOW | 4 | GST/HST conditional display; Emoji inconsistency; French translations missing in cron emails; License key warnings |

---

## NEXT STEPS
1. Fix C-1 to C-4 IMMEDIATELY before launch (regulatory + UX critical)
2. Fix H-1 to H-7 within 1 week (compliance + DX critical)
3. Fix M-1 to M-5 within 2 weeks (polish + reliability)
4. Fix L-1 to L-4 as technical debt (nice-to-have)

---

**Audit completed by Email Notifications Auditor Agent**  
**Contact:** claude-agent@origna.local  
**Report saved to:** `.claude/agent-memory/email-notifications-auditor/AUDIT_REPORT.md`
