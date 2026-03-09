# Search & Discovery Auditor Memory

## Architecture (verified 2026-03-03)
- Backend index name: `AlgoliaConfig.get_index_name()` in `functions/config.py` lines 214-222
  - emulator → `products_emulator`, dev → `products_dev`, staging → `products_staging`, prod → `products`
- Frontend index name: `EnvConfig().algoliaIndexName` in `origna_gta/lib/utils/env_config.dart` lines 113-118 — identical mapping
- Backend write key: `get_algolia_write_api_key()` from APP_SECRETS Secret Manager (`algolia.write_api_key`)
- Frontend search key: Firebase Remote Config key `algolia_search_api_key` (read-only, safe)
- No admin/write key ever sent to frontend — confirmed clean

## availableInCanada (SRCH-H1)
- Computed in `format_product_for_algolia()`: `(not is_local_only) or is_canadian_seller`
- Country comparison: `seller_country in ("CA", "CANADA")` — uppercased — ok
- Listed as `filterOnly(availableInCanada)` in `attributesForFaceting` — filters only, not searchable
- Listed in `attributesToRetrieve` — available to client
- Frontend applies `Filter.facet('availableInCanada', true)` in Algolia search path (`algolia_service.dart` line 60)
- NOT applied on Firestore fallback path — known acceptable gap (Firestore fallback has no `availableInCanada` index)
  → The `canadaOnly` toggle on home screen does client-side post-filter on `shipFromCountry == 'CA'` as compensating control

## Inactive Product Filtering
- Backend `index_product()`: only indexes `lifecycleStatus == ACTIVE`; deactivated products trigger delete
- `on_product_updated`: non-active status → `algolia_delete_product()` immediately
- `on_product_deleted`: always calls `algolia_delete_product()`
- Frontend Algolia path: `Filter.facet(Fields.lifecycleStatus, ProductLifecycleStatusValues.active)` — double-enforced
- Frontend Firestore fallback: `where(Fields.lifecycleStatus, isEqualTo: active)` — correctly filtered

## Fixes Applied (2026-03-03)
1. **FIXED (HIGH)**: Dead code removed — `_address_changed` assignment after `return` at line ~2435 in `on_product_updated` in `functions/handlers/products.py`
2. **FIXED (HIGH)**: `priceCents` now indexed in `format_product_for_algolia()` — derived from `Fields.PRICE_CENTS` or computed from `price * 100`
3. **FIXED (HIGH)**: `numericAttributesForFiltering` added to `configure_algolia_index()` with `Fields.PRICE_CENTS` — frontend numeric filters now work
4. **FIXED (MEDIUM)**: `shipFromProvince` added to `attributesForFaceting` in `configure_algolia_index()`
5. **FIXED (MEDIUM)**: `batch_index_products` — inactive/skipped products no longer miscounted as failures
6. **FIXED (LOW)**: `priceCents` added to `attributesToRetrieve` in `configure_algolia_index()`

## Remaining Known Issues
- `_previousLifecycleStatus` key in `index_product()` is a magic string not in `Fields` constants — harmless (path is defensive-delete only), but should be added to `schema_constants.py` when convenient
- Firestore fallback path has no `availableInCanada` enforcement — acceptable because: (a) Algolia is the primary path for text search, (b) client-side `canadaOnly` toggle compensates, (c) Firestore fallback is non-text browse only

## Sync Triggers (confirmed complete)
- Create: `on_product_created` — does NOT index; approval flow only indexes via `admin_approve_product` (correct by design)
- Update: `on_product_updated` — indexes or deletes based on lifecycleStatus
- Delete: `on_product_deleted` — always deletes from Algolia
- Approval: `admin_approve_product` — indexes fresh doc after admin approval
- Suspension: `deactivate_supplier_platform` — batch partial update with paused status
- Monitoring: `monitor_algolia_sync` cron every 15 min — alerts on >5% mismatch

## Environment Isolation
- Both backend and frontend use identical index-name mapping per environment
- Isolation is compile-time (dart-define / IS_EMULATOR env var) — correct

## IMPORTANT: After deploying algolia_service.py changes
Run `configure_algolia` callable (or `python configure_algolia_indices.py`) against dev, staging, prod
to push the new `numericAttributesForFiltering` and updated `attributesForFaceting` to each Algolia index.
