# Stock Notifications Audit Report
**Date:** 2026-02-28
**Auditor:** Stock Notifications Auditor Agent
**Scope:** Back-in-stock notification system (TASK 07)

---

## Executive Summary

The stock notification system is **mostly well-implemented** with strong variant scoping and duplicate prevention. However, **CRITICAL** and **HIGH** severity issues exist around notification cleanup, email delivery failures, and partial lifecycle gaps.

**Critical Findings:** 1
**High Findings:** 2
**Medium Findings:** 3
**Low Findings:** 1

---

## Findings

### 1. CRITICAL: Notifications Not Deleted After Email Sent
**Severity:** CRITICAL
**File:** `/functions/handlers/products.py`
**Lines:** 3389-3410 (variant flow), 3455-3473 (non-variant flow)

**Invariant Violated:**
Notification docs should be **deleted** after successful email send to prevent permanent accumulation and potential re-notification bugs.

**Current Behavior:**
```python
# Line 3393: Only stamps notifiedAt, NEVER deletes the doc
sub_doc.reference.update({Fields.NOTIFIED_AT: get_server_timestamp()})
enqueue_email_task(...)
```

After `notifiedAt` is stamped, the doc remains in Firestore **forever**. The schema shows `notifiedAt` is nullable, implying "not yet notified" when `None`. But there's no cleanup job to purge notified records.

**Impact:**
- `stock_notifications` collection grows unbounded over time (1 doc per subscription per restock)
- Query performance degrades as collection scales to 100K+ docs
- Re-subscription after being notified creates a NEW doc (idempotency is correct), but old notified docs remain as "zombie" records
- Admin dashboard queries for "pending notifications" must filter `notifiedAt == None`, adding query complexity

**Recommended Fix:**
```python
# After successful email send:
try:
    enqueue_email_task(...)
    # DELETE the doc after email queued (not just stamp notifiedAt)
    sub_doc.reference.delete()
except Exception as e:
    # On email failure, leave doc unmodified so retry can occur
    logger.error(f"Failed to send back-in-stock notification for sub {sub_doc.id}: {e}")
```

**Alternative (if historical tracking is needed):**
Move notified docs to a separate `stock_notifications_history` collection via batch operation.

---

### 2. HIGH: No Cleanup of Notifications When Buyer Cancels Their Own Subscription Pre-Restock
**Severity:** HIGH
**File:** `/functions/handlers/orders.py`
**Lines:** 2323-2352

**Invariant Violated:**
Notifications should be cleaned up when a buyer **purchases** the product, but also when the buyer **manually unsubscribes** BEFORE the product restocks.

**Current Behavior:**
- `unsubscribe_stock_notification` (lines 3574-3607 in `products.py`) correctly deletes the subscription doc
- `on_order_updated` trigger (lines 2323-2352 in `orders.py`) correctly deletes subscriptions when order status is `CONFIRMED` or `PROCESSING`

**BUT:**
The unsubscribe flow at lines 3603-3605 only deletes docs where `notifiedAt == None`. This is **correct** (prevents deleting historical records if we keep them).

**However, the CRITICAL issue from Finding #1 means:**
- If buyer subscribes, gets notified (doc stamped with `notifiedAt`), then product goes out of stock again, buyer cannot "reset" their subscription because the old doc still exists.
- Frontend `init()` in `stock_notification_provider.dart` (line 51) filters `notifiedAt == None` when checking existing subscription, so UI **correctly** shows "not subscribed" after notification. But the notified doc remains as database clutter.

**Impact:**
- Clutters Firestore with permanent notification records
- No mechanism to purge old notifications (no cron job exists)
- Over 12 months, a popular product with 10K watchers could accumulate 10K * 12 = 120K orphan docs

**Recommended Fix:**
Implement a daily cron job to delete `stock_notifications` docs where `notifiedAt < NOW - 30 days`.

---

### 3. HIGH: Email Send Failure Does Not Block Stock Restoration (No Transactional Rollback)
**Severity:** HIGH
**File:** `/functions/handlers/products.py`
**Lines:** 3308-3477 (`_fire_back_in_stock_notifications`)

**Invariant Violated:**
"Email send failure on stock notification does not block the stock restoration operation."

**Current Behavior:**
```python
# Line 3278-3280 in on_product_updated trigger
try:
    _fire_back_in_stock_notifications(product_id, before_data, product_data)
except Exception as e:
    logger.error(f"Back-in-stock notification error for {product_id}: {e}")
```

Email failures are **caught and logged**, but do NOT prevent the product update from succeeding. This is **correct behavior** per the audit checklist requirement.

**HOWEVER:**
When `enqueue_email_task` fails (line 3395 or 3459), the `notifiedAt` timestamp has **already been stamped** (line 3393 or 3457), meaning:
1. The subscriber is marked as "notified"
2. But no email was actually sent
3. On Cloud Function retry (Firestore trigger), the doc now has `notifiedAt != None`, so the subscriber is **skipped** (query filters `notifiedAt == None` at line 3551)

**Impact:**
- Subscriber loses their notification permanently if email task enqueueing fails
- No retry mechanism for failed email sends after `notifiedAt` is stamped
- Silent failure mode: buyer never knows the product restocked

**Recommended Fix:**
```python
# Option 1: Optimistic stamp (current pattern) but with cleanup on email failure
try:
    sub_doc.reference.update({Fields.NOTIFIED_AT: get_server_timestamp()})
    enqueue_email_task(...)
    sub_doc.reference.delete()  # Clean up after success
except Exception as e:
    # ROLLBACK the notifiedAt stamp on email failure
    sub_doc.reference.update({Fields.NOTIFIED_AT: None})
    logger.error(f"Failed notification for sub {sub_doc.id}: {e}")

# Option 2: Pessimistic stamp (safer)
try:
    enqueue_email_task(...)
    # Only stamp notifiedAt AFTER email task successfully queued
    sub_doc.reference.update({Fields.NOTIFIED_AT: get_server_timestamp()})
    sub_doc.reference.delete()
except Exception as e:
    logger.error(f"Failed notification for sub {sub_doc.id}: {e}")
```

**Note:** Option 2 risks duplicate emails on Cloud Function retry if email succeeds but the function crashes before stamping `notifiedAt`. Use idempotency keys in email service to mitigate.

---

### 4. MEDIUM: Variant Scoping Correct, But Missing Edge Case for Deleted Variants
**Severity:** MEDIUM
**File:** `/functions/handlers/products.py`
**Lines:** 3337-3360 (variant restock detection)

**Invariant Verified (PASS):**
Restocking size M does NOT notify users waiting for size L. The logic at lines 3337-3360 correctly compares `before_by_id` vs `after_by_id` dicts keyed by `variantId`, and only notifies for variants where `before_stock <= 0` and `after_stock > 0`.

**Edge Case Gap:**
What if a seller **deletes** a variant (removes it from the `variants` array entirely) while subscribers are waiting for it?

**Current Behavior:**
- `subscribe_stock_notification` (line 3522-3526) validates that the variant exists in `product_data.get(Fields.VARIANTS)` at subscription time
- But if the seller later removes that variant (e.g., discontinues size XXL), the notification doc remains in Firestore with an orphaned `variantKey`
- When the product is updated, `_fire_back_in_stock_notifications` will NOT find that `variantKey` in the new `after_by_id` dict (line 3335), so no notification fires (correct)
- But the orphaned subscription doc is never cleaned up

**Impact:**
- Orphaned subscriptions accumulate when sellers discontinue variants
- Buyer may still see "subscribed" UI state in frontend if they revisit the product (though the variant picker would no longer show the discontinued option)

**Recommended Fix:**
Add cleanup logic in `on_product_updated` trigger:
```python
# After line 2242 (warehouse stock recalculation)
if has_variants:
    current_variant_ids = {v.get(Fields.VARIANT_ID) for v in product_data.get(Fields.VARIANTS, []) if isinstance(v, dict)}
    # Clean up subscriptions for deleted variants
    orphaned_subs = (
        get_db()
        .collection(Collections.STOCK_NOTIFICATIONS)
        .where(Fields.PRODUCT_ID, "==", product_id)
        .where(Fields.NOTIFIED_AT, "==", None)
        .stream()
    )
    batch = get_db().batch()
    for sub in orphaned_subs:
        sub_data = sub.to_dict()
        variant_key = sub_data.get(Fields.VARIANT_KEY, "")
        if variant_key and variant_key not in current_variant_ids:
            batch.delete(sub.reference)
    batch.commit()
```

---

### 5. MEDIUM: No Admin Dashboard to View All Pending Stock Notifications for a Product
**Severity:** MEDIUM
**File:** N/A (feature gap)

**Invariant Violated:**
"Admin can view all pending stock notifications for a product."

**Current Behavior:**
- Firestore rules (line 495-502 in `firestore.rules`) allow admins to read `stock_notifications` docs
- But no admin endpoint exists in `/functions/handlers/admin.py` to query and return all pending notifications for a given product

**Impact:**
- Admins cannot see how many users are waiting for a product to restock
- No visibility into which products have high demand but low stock
- No way to debug notification issues (e.g., "Why didn't user X get notified?")

**Recommended Fix:**
Add a callable function in `admin.py`:
```python
@https_fn.on_call(**DEFAULT_OPTIONS)
def get_pending_stock_notifications(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Admin-only: Fetch all pending stock notifications for a product.

    Request data:
        productId: Product to query

    Returns:
        { notifications: [{ userId, email, variantKey, createdAt }] }
    """
    if not req.auth or not _is_admin(req.auth.uid):
        raise https_fn.HttpsError("permission-denied", "Admin only")

    product_id = req.data.get(Fields.PRODUCT_ID)
    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId required")

    subs = (
        get_db()
        .collection(Collections.STOCK_NOTIFICATIONS)
        .where(Fields.PRODUCT_ID, "==", product_id)
        .where(Fields.NOTIFIED_AT, "==", None)
        .limit(500)
        .stream()
    )

    results = []
    for sub in subs:
        data = sub.to_dict()
        results.append({
            Fields.USER_ID: data.get(Fields.USER_ID),
            Fields.EMAIL: data.get(Fields.EMAIL),
            Fields.VARIANT_KEY: data.get(Fields.VARIANT_KEY, ""),
            Fields.CREATED_AT: data.get(Fields.CREATED_AT),
        })

    return create_success_response({"notifications": results})
```

---

### 6. MEDIUM: Firestore Rules Allow Backend-Only Creates, But Comment Says "Backend Handles Via Specific Endpoint"
**Severity:** MEDIUM
**File:** `/firestore.rules`
**Lines:** 495-502

**Current Behavior:**
```javascript
match /stock_notifications/{notifId} {
  allow read: if isAuthenticated() &&
    (resource.data.userId == request.auth.uid || isAdmin());
  // Backend only handles creates via specific `subscribe_stock_notification` endpoint to ensure consistency
  allow create, update: if false;
  // Deletes are also backend-only to ensure server-side logging and auditability
  allow delete: if false;
}
```

**Analysis:**
Rules are **correct**: all writes are blocked at Firestore rules level, forcing clients to use the `subscribe_stock_notification` callable function (which uses Admin SDK and bypasses rules).

**Edge Case:**
The comment mentions "specific endpoint" but doesn't reference the callable function name. This is a documentation gap, not a security issue.

**Recommended Fix:**
Update comment to reference the exact function:
```javascript
// Backend-only: all creates/updates/deletes go through subscribe_stock_notification
// and unsubscribe_stock_notification callable functions (Admin SDK bypasses rules).
allow create, update, delete: if false;
```

---

### 7. LOW: Duplicate Subscription Prevention Works, But Query Could Be More Efficient
**Severity:** LOW
**File:** `/functions/handlers/products.py`
**Lines:** 3544-3558

**Invariant Verified (PASS):**
Duplicate subscription is correctly prevented via the query at lines 3546-3557:
```python
existing_query = (
    get_db()
    .collection(Collections.STOCK_NOTIFICATIONS)
    .where(Fields.PRODUCT_ID, "==", product_id)
    .where(Fields.USER_ID, "==", user_id)
    .where(Fields.NOTIFIED_AT, "==", None)
)
if variant_key:
    existing_query = existing_query.where(Fields.VARIANT_KEY, "==", variant_key)
else:
    existing_query = existing_query.where(Fields.VARIANT_KEY, "==", "")
```

**Observation:**
The query uses `.limit(1).stream()` and checks `if list(...):` to determine existence. This is correct.

**Minor Optimization:**
Use `.get()` instead of `.stream()` for single-doc existence checks:
```python
if existing_query.limit(1).get().docs:
    return create_success_response({"subscribed": True})
```

**Impact:**
Negligible performance difference, but `.get()` is more idiomatic for non-streaming queries.

---

## Additional Verification: Eligibility Check

**Requirement:** "Notify-me only available when product/variant is genuinely out of stock (`stockQuantity == 0`)?"

**File:** `/origna_gta/lib/screens/productdetails_screen.dart`
**Lines:** 462-489

**Verified (PASS):**
```dart
if (widget.stockQuantity <= 0) {
  final notifState = ref.watch(stockNotificationNotifierProvider(...));
  // Show "Notify Me" button
}
```

Frontend correctly shows notify button only when `stockQuantity <= 0`.

**Backend validation:**
`subscribe_stock_notification` (line 3508-3534 in `products.py`) enforces:
- For non-variant products: `product_data.get(Fields.STOCK_QUANTITY, 0) > 0` rejects subscription
- For variant products: checks specific variant's `stockQuantity` via `variant_data.get(Fields.STOCK_QUANTITY, 0) > 0`

**Verdict:** PASS

---

## Additional Verification: Notification Scoped to Correct Variant

**Requirement:** "Restocking size M does not notify users waiting for size L?"

**File:** `/functions/handlers/products.py`
**Lines:** 3327-3360

**Verified (PASS):**
```python
# Line 3337-3360: Per-variant restock detection
restocked_keys: list[str] = [
    vk
    for vk, after_var in after_by_id.items()
    if before_by_id.get(vk, {}).get(Fields.STOCK_QUANTITY, 0) <= 0
    and after_var.get(Fields.STOCK_QUANTITY, 0) > 0
]

for variant_key in restocked_keys:
    # Query filters by exact variantKey (line 3373)
    query = query.where(Fields.VARIANT_KEY, "==", variant_key)
```

**Verdict:** PASS — Notifications are correctly scoped by `variantKey`.

---

## Additional Verification: Cleanup on Product Deletion

**Requirement:** "Notification cleaned up when product is deleted or permanently deactivated?"

**File:** `/functions/handlers/products.py`
**Lines:** 604-615 (soft delete), 2485-2498 (hard delete trigger)

**Verified (PASS):**
```python
# delete_product callable (line 604-615)
while True:
    subs = list(get_db().collection(Collections.STOCK_NOTIFICATIONS).where(Fields.PRODUCT_ID, "==", product_id).limit(200).stream())
    if not subs:
        break
    batch = get_db().batch()
    for sub in subs:
        batch.delete(sub.reference)
    batch.commit()

# on_product_deleted trigger (line 2485-2498)
# Same paginated cleanup logic
```

**Verdict:** PASS — Both soft delete (lifecycle=archived) and hard delete (Firestore trigger) clean up notifications.

---

## Summary of Audit Checklist

| Requirement | Status | Severity if Failed | Notes |
|-------------|--------|-------------------|-------|
| Notify-me only when genuinely out of stock | ✅ PASS | N/A | Frontend + backend validation correct |
| Duplicate subscription prevented | ✅ PASS | N/A | Query filters by userId + productId + variantKey + notifiedAt==None |
| Notification scoped to correct variant | ✅ PASS | N/A | Per-variant restock detection is accurate |
| Notification sent when stock restored above 0 | ✅ PASS | N/A | Checks `before_stock <= 0` and `after_stock > 0` |
| **Notification doc cleaned up after email sent** | ❌ FAIL | **CRITICAL** | Only stamps `notifiedAt`, never deletes (Finding #1) |
| Notification cleaned up when buyer purchases | ✅ PASS | N/A | `on_order_updated` deletes subs on CONFIRMED/PROCESSING |
| Notification cleaned up when product deleted | ✅ PASS | N/A | Both soft and hard delete paths paginate cleanup |
| Firestore rules: only authenticated user can register | ✅ PASS | N/A | Rules block all client writes; callable enforces auth |
| **Admin can view all pending notifications** | ❌ FAIL | **MEDIUM** | No admin endpoint exists (Finding #5) |
| **Email send failure does not block stock restoration** | ⚠️ PARTIAL | **HIGH** | Errors are caught, but `notifiedAt` stamp before email causes lost notifications (Finding #3) |

---

## Recommendations Summary

1. **CRITICAL (Finding #1):** Delete notification docs after successful email send, OR implement a cron job to purge `notifiedAt < NOW - 30 days`.

2. **HIGH (Finding #3):** Stamp `notifiedAt` AFTER email task is successfully queued, not before. Add rollback logic if email fails.

3. **MEDIUM (Finding #4):** Add cleanup for orphaned variant subscriptions when seller deletes a variant.

4. **MEDIUM (Finding #5):** Implement `get_pending_stock_notifications` admin callable to view waitlist for a product.

5. **LOW (Finding #7):** Use `.get()` instead of `.stream()` for single-doc existence checks (minor optimization).

---

## Conclusion

The stock notification system demonstrates **strong variant scoping, duplicate prevention, and purchase-based cleanup**. However, the **lack of post-notification cleanup** (Finding #1) will cause unbounded collection growth, and the **email failure handling** (Finding #3) risks silent notification loss.

**Priority:** Fix Finding #1 and Finding #3 before launch. Finding #5 can be deferred to post-launch admin tooling iteration.

---

**Audit Completed:** 2026-02-28
**Agent:** stock-notifications-auditor
**Next Review:** After fixes are merged, re-audit with E2E tests for notification delivery + cleanup.
