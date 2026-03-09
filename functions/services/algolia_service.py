"""
Algolia indexing service for products
Handles syncing Firestore products to Algolia search index
"""

import logging

from algoliasearch.search.client import SearchClientSync
from pydantic import ValidationError

from config import AlgoliaConfig, get_algolia_app_id, get_algolia_write_api_key
from models.product import Product
from schema_constants import AppConfig, Collections, Fields, ProductLifecycleStatusValues

logger = logging.getLogger(__name__)


# Algolia client — NO GLOBAL STATE to avoid "Event loop is closed" errors in Cloud Function container reuse
# Each function now initializes and closes its own client via context manager.


def _get_algolia_client() -> SearchClientSync:
    """Initialize a fresh Algolia client. Raises RuntimeError if credentials are missing."""
    app_id = get_algolia_app_id()
    api_key = get_algolia_write_api_key()
    if not app_id or not api_key:
        raise RuntimeError("Algolia credentials not configured — app_id or api_key is missing")

    # Use SearchClientSync for synchronous Cloud Functions.
    # We must use it as a context manager to ensure the internal transport is closed.
    return SearchClientSync(app_id, api_key)


def _get_index_name() -> str:
    """Get the correct Algolia index name based on environment (emulator vs production)."""
    return AlgoliaConfig.get_index_name()


def format_product_for_algolia(product_id: str, product_data: dict | Product) -> dict:
    """
    Format product document for Algolia indexing.

    Args:
        product_id: Firestore document ID
        product_data: Product document data (dict) or Product Pydantic model

    Returns:
        Formatted object for Algolia with objectID
    """
    # Convert Product model to dict if needed
    if isinstance(product_data, Product):
        # Use Pydantic model_dump for clean serialization
        data = product_data.model_dump(exclude_none=True)
    else:
        # Dict input support
        try:
            # Attempt to validate as Product for consistency
            product = Product(**product_data)
            data = product.model_dump(exclude_none=True)
        except ValidationError as e:
            # SECURITY: Don't index unvalidated data — skip and log to DLQ
            logger.error(f"❌ Product {product_id} failed Pydantic validation, skipping Algolia index: {e}")
            _log_sync_failure(product_id, "index", f"ValidationError: {e}", 0)
            return {}

    # Algolia requires objectID field
    # Derive priceCents for Algolia numeric range filters (numericAttributesForFiltering).
    # Backend derives this authoritatively; fall back to computing from price if absent.
    price_val = data.get(Fields.PRICE, 0.0) or 0.0
    price_cents_val = data.get(Fields.PRICE_CENTS)
    if price_cents_val is None and price_val:
        price_cents_val = round(price_val * 100)

    algolia_object = {
        "objectID": product_id,
        Fields.NAME: data.get(Fields.NAME, ""),
        Fields.DESCRIPTION: data.get(Fields.DESCRIPTION, ""),
        Fields.PRICE: price_val,
        # SRCH-NUM1: priceCents enables numericAttributesForFiltering on the Algolia index.
        # Frontend uses `priceCents>=X` numeric filters — must be indexed as an integer.
        Fields.PRICE_CENTS: price_cents_val or 0,
        Fields.CATEGORY_ID: data.get(Fields.CATEGORY_ID, 0),
        Fields.SELLER_ID: data.get(Fields.SELLER_ID, ""),
        Fields.IMAGE_URLS: data.get(Fields.IMAGE_URLS, []),
        Fields.STOCK_QUANTITY: data.get(Fields.STOCK_QUANTITY, 0),
        Fields.RATING: data.get(Fields.RATING, 0.0),
        Fields.RATING_COUNT: data.get(Fields.RATING_COUNT, 0),
        Fields.LIFECYCLE_STATUS: data.get(Fields.LIFECYCLE_STATUS, ProductLifecycleStatusValues.DRAFT),
        Fields.KEYWORDS: data.get(Fields.KEYWORDS, []) or data.get(Fields.SEARCH_KEYWORDS, []),
        Fields.FREE_SHIPPING: data.get(Fields.FREE_SHIPPING, False),
        Fields.IS_PERISHABLE: data.get(Fields.IS_PERISHABLE, False),
        Fields.IS_LOCAL_DELIVERY_ONLY: data.get(Fields.IS_LOCAL_DELIVERY_ONLY, False),
    }

    # SRCH-H1: Compute availableInCanada — filters out international sellers with
    # local-delivery-only products that can never ship to any Canadian buyer.
    # Canadian-seller local-delivery products remain available (buyer/seller in same province).
    # DEPLOY NOTE: 'availableInCanada' must be added as an "Attribute for Faceting"
    # in Algolia index settings for Filter.facet() to work on this field.
    is_local_only = data.get(Fields.IS_LOCAL_DELIVERY_ONLY, False)
    seller_addr = data.get(Fields.SELLER_ADDRESS) or {}
    if hasattr(seller_addr, "model_dump"):
        seller_addr = seller_addr.model_dump(exclude_none=True)
    seller_country = (seller_addr.get(Fields.COUNTRY) or "").strip().upper()
    is_canadian_seller = seller_country in ("CA", "CANADA")
    # availableInCanada = True when: ships nationally OR is local-only but seller is Canadian
    algolia_object["availableInCanada"] = (not is_local_only) or is_canadian_seller

    # Seller address - handle both dict and Address object
    seller_address = data.get(Fields.SELLER_ADDRESS)
    if seller_address:
        # Convert Address model to dict if needed
        if hasattr(seller_address, "model_dump"):
            algolia_object[Fields.SELLER_ADDRESS] = seller_address.model_dump(exclude_none=True)
        else:
            algolia_object[Fields.SELLER_ADDRESS] = seller_address

    # shipFrom* fields for warehouse products
    for field in [Fields.SHIP_FROM_CITY, Fields.SHIP_FROM_PROVINCE, Fields.SHIP_FROM_COUNTRY]:
        val = data.get(field)
        if val:
            algolia_object[field] = val
    countries = data.get(Fields.SHIP_FROM_COUNTRIES)
    if countries:
        algolia_object[Fields.SHIP_FROM_COUNTRIES] = countries

    # Optional fields
    optional_fields = [
        Fields.WEIGHT_KG,
        Fields.LENGTH_CM,
        Fields.WIDTH_CM,
        Fields.HEIGHT_CM,
        Fields.TAX_CODE,
        Fields.DELIVERY_OPTIONS,
        Fields.ESTIMATED_SHIP_DAYS,
        Fields.MINIMUM_ORDER_QUANTITY,
        # N-11: Subcategory for faceted search
        Fields.SUBCATEGORY,
        # N-09: Variant metadata (for display, not stock)
        Fields.HAS_VARIANTS,
        Fields.VARIANT_OPTIONS,
        # Buyer-facing fields: condition facet, price anchoring, trending sort, digital flag
        Fields.CONDITION,
        Fields.COMPARE_AT_PRICE,
        Fields.IS_DIGITAL,
        Fields.TRENDING_SCORE,
        Fields.IS_TRENDING,
    ]
    # SECURITY: fields intentionally excluded from Algolia (NEVER add these):
    # bookSourceUrl, digitalBuilds, cost, supplierUrl, sellerSku — internal/sensitive only
    for field in optional_fields:
        if field in data:
            algolia_object[field] = data[field]

    # Add timestamp for sorting (convert Firestore timestamp to Unix timestamp)
    if Fields.CREATED_AT in data and data[Fields.CREATED_AT]:
        algolia_object[Fields.CREATED_AT] = (
            data[Fields.CREATED_AT].timestamp() if hasattr(data[Fields.CREATED_AT], "timestamp") else 0
        )

    return algolia_object


def _log_sync_failure(product_id: str, action: str, error: str, retries: int):
    """Log failed Algolia sync to Firestore dead letter queue for later retry."""
    try:
        from firebase_admin import firestore as fs

        db = fs.client()
        db.collection(Collections.ALGOLIA_SYNC_FAILURES).add(
            {
                Fields.PRODUCT_ID: product_id,
                Fields.ACTION: action,
                Fields.ERROR: error,
                Fields.CREATED_AT: fs.SERVER_TIMESTAMP,
                Fields.RETRIES: retries,
                Fields.RESOLVED: False,
            }
        )
        logger.info(f"  📝 Logged sync failure for {product_id} to dead letter queue")
    except Exception as dlq_err:
        logger.error(f"  ❌ Failed to log to dead letter queue: {dlq_err}")


def index_product(product_id: str, product_data: dict, max_retries: int = AppConfig.ALGOLIA_MAX_RETRIES) -> bool:
    """
    Index a single product to Algolia with retry + exponential backoff.
    On final failure, logs to algolia_sync_failures collection for later reconciliation.

    Args:
        product_id: Firestore document ID
        product_data: Product document data
        max_retries: Number of retry attempts (default 3)

    Returns:
        True if successful, False otherwise
    """
    # Only index active products; skip delete for non-active that were never indexed (e.g. draft)
    if product_data.get(Fields.LIFECYCLE_STATUS) != ProductLifecycleStatusValues.ACTIVE:
        prev_status = product_data.get("_previousLifecycleStatus")
        if prev_status == ProductLifecycleStatusValues.ACTIVE:
            logger.info(f"  ⏭️  Product {product_id} deactivated - removing from index")
            delete_product(product_id)
        else:
            logger.info(f"  ⏭️  Product {product_id} is not active and was never active - skipping delete")
        return True

    algolia_object = format_product_for_algolia(product_id, product_data)
    last_error = None

    for attempt in range(max_retries):
        try:
            with _get_algolia_client() as client:
                client.save_object(index_name=_get_index_name(), body=algolia_object)
            logger.info(f"  ✅ Indexed product {product_id} to Algolia (index={_get_index_name()})")
            return True
        except RuntimeError as e:
            logger.warning(f"⚠️  Algolia not configured - skipping indexing: {e}")
            return False
        except Exception as e:
            last_error = e
            logger.warning(f"  ⚠️  Algolia index attempt {attempt + 1}/{max_retries} failed for {product_id}: {e}")

    # All retries exhausted — log to dead letter queue
    _log_sync_failure(product_id, "index", str(last_error), max_retries)
    return False


def partial_update_product(product_id: str, fields: dict, max_retries: int = AppConfig.ALGOLIA_MAX_RETRIES) -> bool:
    """
    Partially update specific fields in Algolia without replacing the full record.
    Use for stock/status-only changes to avoid sending all 20+ fields.

    Args:
        product_id: Firestore document ID (used as objectID in Algolia)
        fields: Dict of field names to new values (e.g., {"stockQuantity": 5})
        max_retries: Number of retry attempts

    Returns:
        True if successful, False otherwise
    """
    body = {"objectID": product_id, **fields}
    last_error = None

    for attempt in range(max_retries):
        try:
            with _get_algolia_client() as client:
                client.partial_update_object(
                    index_name=_get_index_name(),
                    object_id=product_id,
                    attributes_to_update=body,
                )
            logger.info(f"  ✅ Partially updated product {product_id} in Algolia: {list(fields.keys())}")
            return True
        except RuntimeError as e:
            logger.warning(f"⚠️  Algolia not configured - skipping partial update: {e}")
            return False
        except Exception as e:
            last_error = e
            logger.warning(f"  ⚠️  Algolia partial update attempt {attempt + 1}/{max_retries} failed for {product_id}: {e}")

    _log_sync_failure(product_id, "partial_update", str(last_error), max_retries)
    return False


def batch_partial_update_products(product_ids: list[str], fields: dict, max_retries: int = AppConfig.ALGOLIA_MAX_RETRIES) -> bool:
    """
    Batch partial-update the same fields on multiple Algolia records in a single HTTP request.
    Use instead of looping partial_update_product for suspend/unsuspend operations.

    Args:
        product_ids: List of Firestore product IDs (objectIDs in Algolia)
        fields: Dict of field names/values to set on every record (e.g., {"lifecycleStatus": "paused"})
        max_retries: Number of retry attempts

    Returns:
        True if all records updated, False on final failure
    """
    if not product_ids:
        return True

    objects = [{"objectID": pid, **fields} for pid in product_ids]
    last_error = None

    for attempt in range(max_retries):
        try:
            from algoliasearch.search.models.action import Action
            from algoliasearch.search.models.batch_request import BatchRequest
            from algoliasearch.search.models.batch_write_params import BatchWriteParams

            requests = [BatchRequest(action=Action.PARTIAL_UPDATE_OBJECT, body=obj) for obj in objects]
            with _get_algolia_client() as client:
                client.batch(
                    index_name=_get_index_name(),
                    batch_write_params=BatchWriteParams(requests=requests),
                )
            logger.info(f"  ✅ Batch partial-updated {len(product_ids)} products in Algolia: {list(fields.keys())}")
            return True
        except RuntimeError as e:
            logger.warning(f"⚠️  Algolia not configured - skipping batch partial update: {e}")
            return False
        except Exception as e:
            last_error = e
            logger.warning(f"  ⚠️  Algolia batch partial update attempt {attempt + 1}/{max_retries} failed: {e}")

    _log_sync_failure("batch", "batch_partial_update", str(last_error), max_retries)
    return False


def delete_product(product_id: str, max_retries: int = AppConfig.ALGOLIA_MAX_RETRIES) -> bool:
    """
    Delete a product from Algolia index with retry + exponential backoff.
    On final failure, logs to algolia_sync_failures collection.

    Args:
        product_id: Firestore document ID
        max_retries: Number of retry attempts (default 3)

    Returns:
        True if successful, False otherwise
    """
    last_error = None

    for attempt in range(max_retries):
        try:
            with _get_algolia_client() as client:
                client.delete_object(index_name=_get_index_name(), object_id=product_id)
            logger.info(f"  ✅ Deleted product {product_id} from Algolia (index={_get_index_name()})")
            return True
        except RuntimeError as e:
            logger.warning(f"⚠️  Algolia not configured - skipping deletion: {e}")
            return False
        except Exception as e:
            last_error = e
            logger.warning(f"  ⚠️  Algolia delete attempt {attempt + 1}/{max_retries} failed for {product_id}: {e}")

    # All retries exhausted — log to dead letter queue
    _log_sync_failure(product_id, "delete", str(last_error), max_retries)
    return False


def get_index_stats() -> int:
    """
    Get the number of records in the Algolia index.
    Used by monitor_algolia_sync cron job to detect Firestore↔Algolia drift.

    Returns:
        Number of records in the index, or 0 if unavailable.
    """
    try:
        with _get_algolia_client() as client:
            index_name = _get_index_name()
            # Use search with empty query and hitsPerPage=0 to get nbHits
            search_result = client.search_single_index(
                index_name=index_name,
                search_params={"query": "", "hitsPerPage": 0}
            )
            return search_result.nb_hits or 0
    except RuntimeError as e:
        logger.warning(f"⚠️  Algolia not configured - cannot get index stats: {e}")
        return 0
    except Exception as e:
        # "Event loop is closed" happens on container reuse — non-fatal, log as warning
        # to avoid Sentry noise. The cron caller treats 0 as "unknown" and skips alerting.
        logger.warning(f"⚠️  Failed to get Algolia index stats (non-fatal): {str(e)}")
        return 0


def batch_index_products(products: list) -> tuple:
    """
    Index multiple products in batch

    Args:
        products: List of tuples (product_id, product_data)

    Returns:
        Tuple of (success_count, failure_count)
    """
    success_count = 0
    failure_count = 0
    skipped_count = 0
    algolia_objects = []
    id_map: list[str] = []  # parallel list of product_ids for per-item DLQ logging

    for product_id, product_data in products:
        if product_data.get(Fields.LIFECYCLE_STATUS) == ProductLifecycleStatusValues.ACTIVE:
            algolia_objects.append(format_product_for_algolia(product_id, product_data))
            id_map.append(product_id)
        else:
            # Inactive/draft products are intentionally excluded — not failures.
            skipped_count += 1

    if not algolia_objects:
        return (0, failure_count)

    try:
        with _get_algolia_client() as client:
            client.save_objects(index_name=_get_index_name(), objects=algolia_objects)
        logger.info(f"  ✅ Batch indexed {len(algolia_objects)} products to Algolia (index={_get_index_name()})")
        success_count = len(algolia_objects)
    except RuntimeError as e:
        logger.warning(f"⚠️  Algolia not configured - skipping batch indexing: {e}")
        return (0, len(products))
    except Exception as e:
        logger.error(f"  ❌ Failed to batch index products: {str(e)}")
        # Log each item to DLQ so they can be retried individually
        for pid in id_map:
            _log_sync_failure(pid, "batch_index", str(e), 1)
        failure_count += len(algolia_objects)

    return (success_count, failure_count)


def configure_algolia_index():
    """
    Configure Algolia index settings and replicas
    Should be run once during setup or when index configuration changes
    """
    try:
        with _get_algolia_client() as client:
            index_name = _get_index_name()
            logger.info(f"  🔧 Configuring Algolia index: {index_name}")
            # Set searchable attributes with priority
            client.set_settings(
                index_name=index_name,
                index_settings={
                    "searchableAttributes": [
                        Fields.NAME,  # Highest priority
                        Fields.DESCRIPTION,
                        Fields.KEYWORDS,
                    ],
                    "attributesForFaceting": [
                        Fields.CATEGORY_ID,
                        Fields.SUBCATEGORY,
                        Fields.SELLER_ID,
                        Fields.LIFECYCLE_STATUS,
                        Fields.FREE_SHIPPING,
                        Fields.IS_PERISHABLE,
                        f"filterOnly({Fields.SHIP_FROM_PROVINCE})",  # SRCH-PROV: province-level buyer filtering
                        f"filterOnly({Fields.SHIP_FROM_COUNTRY})",
                        f"filterOnly({Fields.SHIP_FROM_COUNTRIES})",
                        "filterOnly(availableInCanada)",  # SRCH-H1: Canada buyer filtering
                    ],
                    "numericAttributesForFiltering": [
                        Fields.PRICE_CENTS,  # SRCH-NUM1: enables priceCents>=X / priceCents<=X numeric filters
                    ],
                    "customRanking": [
                        f"desc({Fields.RATING})",  # Sort by rating first
                        f"desc({Fields.RATING_COUNT})",  # Then by number of ratings
                        f"desc({Fields.CREATED_AT})",  # Then by newest
                    ],
                    "attributesToRetrieve": [
                        "objectID",
                        Fields.NAME,
                        Fields.DESCRIPTION,
                        Fields.PRICE,
                        Fields.PRICE_CENTS,  # SRCH-NUM1: needed for numeric filter round-trip
                        Fields.CATEGORY_ID,
                        Fields.SUBCATEGORY,
                        Fields.SELLER_ID,
                        Fields.IMAGE_URLS,
                        Fields.STOCK_QUANTITY,
                        Fields.RATING,
                        Fields.RATING_COUNT,
                        Fields.LIFECYCLE_STATUS,
                        Fields.KEYWORDS,
                        Fields.SELLER_ADDRESS,
                        Fields.WEIGHT_KG,
                        Fields.LENGTH_CM,
                        Fields.WIDTH_CM,
                        Fields.HEIGHT_CM,
                        Fields.IS_LOCAL_DELIVERY_ONLY,
                        Fields.ESTIMATED_SHIP_DAYS,
                        Fields.TAX_CODE,
                        Fields.DELIVERY_OPTIONS,
                        Fields.IS_PERISHABLE,
                        Fields.MINIMUM_ORDER_QUANTITY,
                        Fields.FREE_SHIPPING,
                        Fields.SHIP_FROM_CITY,
                        Fields.SHIP_FROM_PROVINCE,
                        Fields.SHIP_FROM_COUNTRY,
                        Fields.SHIP_FROM_COUNTRIES,
                        "availableInCanada",  # SRCH-H1
                    ],
                    "highlightPreTag": "<mark>",
                    "highlightPostTag": "</mark>",
                    "hitsPerPage": AppConfig.ALGOLIA_HITS_PER_PAGE,
                },
            )
            logger.info(f"  ✅ Configured Algolia index settings for '{index_name}'")
            return True
    except RuntimeError as e:
        logger.warning(f"⚠️  Algolia not configured - skipping index configuration: {e}")
        return False
    except Exception as e:
        logger.error(f"  ❌ Failed to configure Algolia index '{_get_index_name()}': {str(e)}")
        return False


def delete_products_from_algolia(product_ids: list[str]) -> int:
    """
    Batch delete multiple products from Algolia (GDPR account deletion).

    Args:
        product_ids: List of Firestore document IDs to remove

    Returns:
        Number of successfully deleted products
    """
    if not product_ids:
        return 0
    try:
        with _get_algolia_client() as client:
            client.delete_objects(index_name=_get_index_name(), object_ids=product_ids)
        logger.info(f"  ✅ Batch deleted {len(product_ids)} products from Algolia (index={_get_index_name()})")
        return len(product_ids)
    except RuntimeError as e:
        logger.warning(f"⚠️  Algolia not configured - skipping batch deletion: {e}")
        return 0
    except Exception as e:
        logger.error(f"  ❌ Algolia batch delete failed: {e}")
        for pid in product_ids:
            _log_sync_failure(pid, "delete", str(e), 1)
        return 0
