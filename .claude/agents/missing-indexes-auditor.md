---
name: missing-indexes-auditor
description: Audits missing Firestore composite indexes — finds queries in Flutter providers, Python handlers, and Firestore rules that require composite indexes not present in firestore.indexes.json. Use after any Firestore query change or when experiencing "requires an index" errors in production.
tools: Read, Grep, Glob, Bash
model: sonnet
memory: project
---

# Missing Indexes Auditor

## Mission
Find every Firestore composite query in the codebase that requires an index, then verify each index exists in `firestore.indexes.json`. Report any missing index with the exact JSON to add.

## Firestore Index Rules (when an index IS required)

Firestore requires a composite index whenever a query:
1. Has **2+ `where()` clauses** on different fields
2. Has a **`where()` + `orderBy()`** on different fields
3. Has an **`orderBy()` on field A** + **`orderBy()` on field B**
4. Has **`array_contains` / `array_contains_any`** combined with ANY other filter or orderBy

Single-field queries with a single `orderBy()` on the SAME field do NOT require composite indexes.

## Audit Steps

### Step 1: Read the current indexes
Read `/firestore.indexes.json` completely. Build a mental map of:
```
collection → [(field, direction/arrayConfig), ...] pairs
```

### Step 2: Scan Flutter providers for composite queries
Search these files for `.where(` + `.orderBy(` patterns:
- `origna_gta/lib/features/**/*.dart`
- `origna_gta/lib/core/repositories/*.dart`
- `origna_gta/lib/screens/*.dart`

For each query found, extract:
- Collection name (from `collection('...')`)
- All `.where()` clauses (field + operator)
- All `.orderBy()` clauses (field + direction)
- `.limit()` if present (informational)

### Step 3: Scan Python handlers for composite queries
Search these files for composite Firestore queries:
- `functions/handlers/*.py`
- `functions/services/*.py`

Look for patterns:
```python
.where(field, op, value).where(field2, op2, value2)
.where(field, op, value).order_by(field2)
.where(field, ...).where(...).stream()
.where(field, ...).where(...).get()
```

### Step 4: Cross-reference with existing indexes

For each composite query found:
1. Identify the collection name
2. List the fields + order required
3. Check if an equivalent index exists in `firestore.indexes.json`
4. Mark as **MISSING** if not found

### Step 5: Known high-risk areas (always check)

Based on STATE.md findings, verify these specific indexes exist:

| Collection | Fields Required | Reason |
|-----------|-----------------|---------|
| `product_questions` | `productId ASC` + `isAnswered ASC` + `createdAt DESC` | F-293: Q&A sort "Answered First" |
| `orders` | `userId ASC` + `createdAt DESC` | Buyer order history |
| `orders` | `sellerIds ARRAY_CONTAINS` + `createdAt DESC` | Seller order list |
| `orders` | `sellerIds ARRAY_CONTAINS` + `orderStatus ASC` + `createdAt DESC` | Seller filtered orders |
| `stock_notifications` | `productId ASC` + `userId ASC` | Back-in-stock dedup |
| `return_requests` | `orderId ASC` + `returnStatus ASC` | Return list filter |
| `coupons` | `sellerId ASC` + `isActive ASC` | Seller coupon list |
| `products` | `lifecycleStatus ASC` + `sellerId ASC` + `createdAt DESC` | Seller product list |
| `rate_limits` | `lastRequest ASC` (single-field, no composite needed) | Cleanup cron |
| `webhook_events` | `timestamp ASC` | Cleanup cron |
| `platform_debt` | `status ASC` + `createdAt DESC` | A-05: Debt recovery audit |
| `_mail_logs` | `eventType ASC` + `createdAt DESC` | Email dedup audit |

### Step 6: Check cron job queries
Cron jobs in `functions/handlers/cron_jobs.py` often run unbounded queries. Verify:
- `auto_archive_old_orders`: what fields does it filter on?
- `check_expired_authorizations`: createdAt + paymentStatus + orderStatus?
- `compute_seller_metrics`: sellerIds + createdAt composite?
- `check_low_stock_alerts`: lifecycleStatus + what else?

### Step 7: Format missing indexes

For each missing index, output the exact JSON to add to `firestore.indexes.json`:

```json
{
  "collectionGroup": "<collection>",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "<field1>", "order": "ASCENDING"},
    {"fieldPath": "<field2>", "order": "DESCENDING"},
    {"fieldPath": "<arrayField>", "arrayConfig": "CONTAINS"}
  ],
  "comment": "<reason — which query needs this>"
}
```

## Output Format

```
## Missing Index Audit Report

### CRITICAL: Missing Indexes (will cause runtime errors in production)

1. **collection: `product_questions`**
   - Query: productId == X AND isAnswered == True ORDER BY createdAt DESC
   - File: functions/handlers/products.py:234
   - Fix: [JSON block]

2. ...

### LOW: Indexes Present but Possibly Stale
List any indexes in firestore.indexes.json that appear to have NO corresponding query
in the codebase anymore (potential dead weight).

### Summary
- Total composite queries found: N
- Indexes already present: N
- Indexes MISSING: N
- Stale indexes: N
```

## Final Action

After reporting:
1. If missing indexes found: ADD them directly to `firestore.indexes.json` in the `"indexes": [...]` array
2. If stale indexes found: Flag for manual review (do NOT delete automatically — could be used by console queries)
3. Update the comment in STATE.md F-293 if the Q&A index was added
