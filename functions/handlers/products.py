"""
Product Management Handlers
- Product CRUD operations
- Algolia indexing (Firestore triggers)
- Image upload to Cloudflare R2
- Product deletion with validation
- Rating submission
"""

import base64 as _base64
import contextlib
import html as _html
import logging
import re
import secrets
import uuid
from datetime import UTC, datetime
from typing import Any

import requests
from botocore.config import Config
from firebase_functions import firestore_fn, https_fn
from pydantic import ValidationError

from config import (
    CURRENT_ENV,
    Environment,
    R2Config,
    get_geoapify_api_key,
    get_r2_credentials,
)
from models.product import ProductCreate, ProductUpdate
from schema_constants import (
    COUNTRY_CANADA,
    ApiKeys,
    AppConfig,
    BusinessRules,
    CategoryIds,
    Collections,
    DeliveryTypeValues,
    EmailConfig,
    Fields,
    OrderStatusValues,
    ProductConstraints,
    ProductLifecycleStatusValues,
    RateLimitActions,
    Subcategories,
    SupplierTypeValues,
    UserRoleValues,
    WarehouseTypeValues,
)
from services.algolia_service import delete_product as algolia_delete_product
from services.algolia_service import index_product
from services.algolia_service import partial_update_product as algolia_partial_update
from services.rate_limiter import RateLimiter
from utils.db import get_db, get_firestore, get_server_timestamp
from utils.function_options import DEFAULT_OPTIONS, FIRESTORE_TRIGGER_OPTIONS
from utils.helpers import create_success_response

logger = logging.getLogger(__name__)

# Module-level alias for convenience — single source of truth remains BusinessRules.CDN_BASE_URL
CDN_BASE_URL: str = BusinessRules.CDN_BASE_URL

# Constants
DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100

_r2_creds: dict | None = None  # Module-level cache to avoid repeated Secret Manager hits
_s3_client_cache: dict | None = None  # Module-level S3 client cache — reuse across calls


def _get_cached_r2_credentials() -> dict:
    """Get R2 credentials with module-level caching to avoid Secret Manager on every call."""
    global _r2_creds
    if _r2_creds is None:
        _r2_creds = get_r2_credentials()
    return _r2_creds


def _get_cached_s3_client():
    """Return a module-level boto3 S3 client, creating it on first call.
    boto3 import is deferred to avoid adding it to cold start time for functions that don't use R2.
    """
    import boto3  # Deferred import — reduces cold start for non-R2 functions
    global _s3_client_cache
    if _s3_client_cache is not None:
        return _s3_client_cache
    r2_creds = _get_cached_r2_credentials()
    r2_access_key = r2_creds.get("access_key")
    r2_secret_key = r2_creds.get("secret_key")
    r2_account_id = r2_creds.get("account_id")
    if not all([r2_access_key, r2_secret_key, r2_account_id]):
        raise https_fn.HttpsError("failed-precondition", "R2 credentials not configured")
    _s3_client_cache = boto3.client(
        "s3",
        endpoint_url=f"https://{r2_account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=r2_access_key,
        aws_secret_access_key=r2_secret_key,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )
    return _s3_client_cache


def _generate_product_slug(title: str) -> str:
    """Generate a URL-safe slug: {title-slug}-{8 random hex chars}.
    Collisions checked by caller — retry with new suffix if needed.
    """
    base = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:40]
    suffix = secrets.token_hex(4)  # 8 hex chars
    return f"{base}-{suffix}"


def _is_valid_stock_quantity(stock: Any) -> bool:
    """Return True only for numeric stock quantities that are >= 0."""
    return isinstance(stock, (int, float)) and stock >= 0


# CORS is configured in DEFAULT_OPTIONS via function_options.py


@https_fn.on_call(**DEFAULT_OPTIONS)
def upload_product_images(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Generates presigned URLs for uploading product images to Cloudflare R2.

    Security:
    - Authenticated users only
    - Max 5 images per request
    - 10MB file size limit
    - 1-hour URL expiration

    Request data:
        fileNames: List of file names (e.g., ["image1.jpg", "image2.png"])
        contentTypes: List of MIME types (e.g., ["image/jpeg", "image/png"])

    Returns:
        {
            uploadUrls: [{uploadUrl, publicUrl, fileName}],
            success: True
        }
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # SECURITY: Verify seller onboarding is complete before allowing uploads
    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")
    user_data = user_doc.to_dict()
    if user_data.get(Fields.SUSPENDED, False):
        raise https_fn.HttpsError("permission-denied", "Your account is suspended")
    if UserRoleValues.SELLER not in user_data.get(Fields.ROLES, []) and UserRoleValues.ADMIN not in user_data.get(
        Fields.ROLES, []
    ):
        raise https_fn.HttpsError("permission-denied", "Seller role required")
    if UserRoleValues.ADMIN not in user_data.get(Fields.ROLES, []):
        # SECURITY: Verify onboarding from seller_profiles (authoritative source)
        sp_doc = get_db().collection(Collections.SELLER_PROFILES).document(user_id).get()
        sp_data = sp_doc.to_dict() if sp_doc.exists else {}
        if not sp_data.get(Fields.ONBOARDING_COMPLETED, False):
            raise https_fn.HttpsError("failed-precondition", "Please complete seller onboarding before uploading products")

    # AUDIT FIX: Rate limit image uploads
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.UPLOAD_IMAGES, max_requests=10, window_minutes=1, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    data = req.data
    file_names_raw = data.get("fileNames", [])
    content_types = data.get("contentTypes", [])

    # Import validation functions
    from utils.helpers import sanitize_path

    if not file_names_raw or len(file_names_raw) == 0:
        raise https_fn.HttpsError("invalid-argument", "No files specified")

    if len(file_names_raw) > BusinessRules.MAX_PRODUCT_IMAGES:
        raise https_fn.HttpsError("invalid-argument", f"Maximum {BusinessRules.MAX_PRODUCT_IMAGES} images allowed")

    if len(file_names_raw) != len(content_types):
        raise https_fn.HttpsError("invalid-argument", "File names and content types count mismatch")

    # SECURITY: Validate MIME types against whitelist (prevent non-image uploads to CDN)
    ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
    for ct in content_types:
        if ct not in ALLOWED_MIME_TYPES:
            raise https_fn.HttpsError(
                "invalid-argument", f"Invalid content type '{ct}'. Allowed: {', '.join(sorted(ALLOWED_MIME_TYPES))}"
            )

    # Sanitize file names to prevent path traversal
    file_names = [sanitize_path(fn) for fn in file_names_raw]

    # SECURITY: Validate file extensions against whitelist
    ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp", "gif"}
    for fn in file_names:
        ext = fn.rsplit(".", 1)[-1].lower() if "." in fn else ""
        if ext not in ALLOWED_EXTENSIONS:
            raise https_fn.HttpsError(
                "invalid-argument", f"Invalid file extension '.{ext}'. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}"
            )

    # Get cached S3 client (module-level)
    s3_client = _get_cached_s3_client()
    bucket_name = R2Config.BUCKET_NAME
    upload_urls = []

    try:
        for file_name, content_type in zip(file_names, content_types, strict=False):
            # Generate unique key with environment-aware path
            file_extension = file_name.split(".")[-1]
            unique_key = R2Config.get_image_path("products", f"{uuid.uuid4()}.{file_extension}")

            # Generate presigned URL for upload
            # NOTE: ContentLength removed — it enforces EXACT size, not max.
            # Size limit enforced by Cloudflare R2 bucket-level configuration.
            presigned_url = s3_client.generate_presigned_url(
                "put_object",
                Params={
                    "Bucket": bucket_name,
                    "Key": unique_key,
                    "ContentType": content_type,
                    # SECURITY: Force inline display — prevents download-triggered XSS
                    "ContentDisposition": "inline",
                },
                ExpiresIn=3600,  # 1 hour
            )

            public_url = f"{CDN_BASE_URL}/{unique_key}"

            upload_urls.append(
                {"uploadUrl": presigned_url, "publicUrl": public_url, "fileName": file_name, "key": unique_key}
            )

        return create_success_response({"uploadUrls": upload_urls})

    except Exception as e:
        logger.error(f"ERROR: Failed to generate upload URLs: {e}")
        raise https_fn.HttpsError("internal", "Failed to generate upload URLs. Please try again.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def upload_product_video(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Generates a presigned URL for uploading a single product video to Cloudflare R2.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # SECURITY: Verify seller onboarding is complete before allowing uploads
    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")
    user_data = user_doc.to_dict()
    if user_data.get(Fields.SUSPENDED, False):
        raise https_fn.HttpsError("permission-denied", "Your account is suspended")

    roles = user_data.get(Fields.ROLES, [])
    if UserRoleValues.SELLER not in roles and UserRoleValues.ADMIN not in roles:
        raise https_fn.HttpsError("permission-denied", "Seller role required")

    if UserRoleValues.ADMIN not in roles:
        # SECURITY: Verify onboarding from seller_profiles
        sp_doc = get_db().collection(Collections.SELLER_PROFILES).document(user_id).get()
        sp_data = sp_doc.to_dict() if sp_doc.exists else {}
        if not sp_data.get(Fields.ONBOARDING_COMPLETED, False):
            raise https_fn.HttpsError("failed-precondition", "Please complete seller onboarding before uploading products")

    # Rate limiting
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.UPLOAD_VIDEO, max_requests=3, window_minutes=1, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    data = req.data
    file_name_raw = data.get("fileName")
    content_type = data.get("contentType")

    from utils.helpers import sanitize_path

    if not file_name_raw:
        raise https_fn.HttpsError("invalid-argument", "No file specified")

    # SECURITY: Validate MIME types
    if content_type not in ProductConstraints.ALLOWED_VIDEO_MIME_TYPES:
        raise https_fn.HttpsError(
            "invalid-argument",
            f"Invalid content type '{content_type}'. Allowed: {', '.join(sorted(ProductConstraints.ALLOWED_VIDEO_MIME_TYPES))}"
        )

    # Sanitize file name
    file_name = sanitize_path(file_name_raw)

    # SECURITY: Validate file extensions
    ALLOWED_EXTENSIONS = {"mp4", "mov", "webm"}
    ext = file_name.rsplit(".", 1)[-1].lower() if "." in file_name else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise https_fn.HttpsError(
            "invalid-argument",
            f"Invalid file extension '.{ext}'. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}"
        )

    # Get cached S3 client (module-level)
    s3_client = _get_cached_s3_client()
    bucket_name = R2Config.BUCKET_NAME

    try:
        # Generate unique key
        unique_key = R2Config.get_image_path("products", f"{uuid.uuid4()}.{ext}")

        # Generate presigned URL for upload
        presigned_url = s3_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": bucket_name,
                "Key": unique_key,
                "ContentType": content_type,
                "ContentDisposition": "inline",
            },
            ExpiresIn=3600,  # 1 hour
        )

        public_url = f"{CDN_BASE_URL}/{unique_key}"

        return create_success_response({
            "uploadUrl": presigned_url,
            "publicUrl": public_url,
            "fileName": file_name,
            "key": unique_key
        })

    except Exception as e:
        logger.error(f"ERROR: Failed to generate video upload URL: {e}")
        raise https_fn.HttpsError("internal", "Failed to generate video upload URL. Please try again.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def delete_product_images(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Deletes product images from Cloudflare R2 by their public URLs.
    Used by the Flutter client to clean up orphaned images after a partial
    upload failure in a batch operation.

    Security:
    - Authenticated sellers/admins only
    - URLs must start with CDN_BASE_URL (prevents deleting arbitrary files)
    - Keys must be under the products/ or {env}/products/ path prefix

    Request data:
        publicUrls: List[str] — public CDN URLs to delete (max 10)

    Returns:
        {success: True, deleted: int, failed: int}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data
    public_urls = data.get("publicUrls", [])

    if not isinstance(public_urls, list) or len(public_urls) == 0:
        raise https_fn.HttpsError("invalid-argument", "publicUrls must be a non-empty list")
    if len(public_urls) > 10:
        raise https_fn.HttpsError("invalid-argument", "Maximum 10 images per delete call")

    # Verify seller/admin role
    user_doc = get_db().collection(Collections.USERS).document(user_id).get()
    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")
    user_data = user_doc.to_dict() or {}
    if user_data.get(Fields.SUSPENDED, False):
        raise https_fn.HttpsError("permission-denied", "Account is suspended")
    roles = user_data.get(Fields.ROLES, [])
    if UserRoleValues.SELLER not in roles and UserRoleValues.ADMIN not in roles:
        raise https_fn.HttpsError("permission-denied", "Seller role required")

    # Get cached S3 client (module-level)
    s3_client = _get_cached_s3_client()
    bucket_name = R2Config.BUCKET_NAME
    cdn_prefix = CDN_BASE_URL + "/"

    # Valid key prefixes (environment-scoped to products only — cannot delete user images etc.)
    valid_prefixes = ("products/", "emulator/products/", "dev/products/", "staging/products/")

    deleted = 0
    failed = 0

    for url in public_urls:
        if not isinstance(url, str) or not url.startswith(cdn_prefix):
            logger.warning(f"delete_product_images: skipping invalid URL from user {user_id}: {url[:80]}")
            failed += 1
            continue

        key = url[len(cdn_prefix):]

        # SECURITY: Only allow deletion of product image keys
        if not any(key.startswith(p) for p in valid_prefixes):
            logger.warning(f"delete_product_images: blocked key outside products/ scope: {key[:80]}")
            failed += 1
            continue

        try:
            s3_client.delete_object(Bucket=bucket_name, Key=key)
            deleted += 1
            logger.info(f"delete_product_images: deleted {key} for user {user_id}")
        except Exception as e:
            logger.error(f"delete_product_images: failed to delete {key}: {e}")
            failed += 1

    return create_success_response({"deleted": deleted, "failed": failed})


@https_fn.on_call(**DEFAULT_OPTIONS)
def upload_review_images(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Generates presigned URLs for uploading review images to Cloudflare R2.

    Available to all authenticated users (buyers as well as sellers).
    Max 3 images per request.

    Request data:
        fileNames: List of file names
        contentTypes: List of MIME types

    Returns:
        { uploadUrls: [{uploadUrl, publicUrl, fileName}], success: True }
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # Photo reviews are a premium-only feature
    from utils.premium_check import is_premium_authoritative
    if not is_premium_authoritative(user_id, db=get_db()):
        raise https_fn.HttpsError(
            "permission-denied", "Photo reviews are a premium feature. Upgrade to add photos to your reviews."
        )

    from utils.helpers import sanitize_path

    data = req.data
    file_names_raw = data.get("fileNames", [])
    content_types = data.get("contentTypes", [])

    if not file_names_raw:
        raise https_fn.HttpsError("invalid-argument", "No files specified")
    if len(file_names_raw) > BusinessRules.MAX_REVIEW_IMAGES:
        raise https_fn.HttpsError("invalid-argument", f"Maximum {BusinessRules.MAX_REVIEW_IMAGES} review images allowed")
    if len(file_names_raw) != len(content_types):
        raise https_fn.HttpsError("invalid-argument", "File names and content types count mismatch")

    ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
    for ct in content_types:
        if ct not in ALLOWED_MIME_TYPES:
            raise https_fn.HttpsError("invalid-argument", f"Invalid content type '{ct}'")

    file_names = [sanitize_path(fn) for fn in file_names_raw]
    ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}
    for fn in file_names:
        ext = fn.rsplit(".", 1)[-1].lower() if "." in fn else ""
        if ext not in ALLOWED_EXTENSIONS:
            raise https_fn.HttpsError("invalid-argument", f"Invalid file extension '.{ext}'")

    # Get cached S3 client (module-level)
    s3_client = _get_cached_s3_client()
    bucket_name = R2Config.BUCKET_NAME
    upload_urls = []

    try:
        for file_name, content_type in zip(file_names, content_types, strict=False):
            file_extension = file_name.split(".")[-1]
            unique_key = R2Config.get_image_path("reviews", f"{user_id}/{uuid.uuid4()}.{file_extension}")
            presigned_url = s3_client.generate_presigned_url(
                "put_object",
                Params={
                    "Bucket": bucket_name,
                    "Key": unique_key,
                    "ContentType": content_type,
                    "ContentDisposition": "inline",
                },
                ExpiresIn=3600,
            )
            public_url = f"{CDN_BASE_URL}/{unique_key}"
            upload_urls.append(
                {"uploadUrl": presigned_url, "publicUrl": public_url, "fileName": file_name, "key": unique_key}
            )

        return create_success_response({"uploadUrls": upload_urls})

    except Exception as e:
        logger.error(f"ERROR: Failed to generate review upload URLs: {e}")
        raise https_fn.HttpsError("internal", "Failed to generate upload URLs. Please try again.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def delete_product(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Soft deletes a product (sets lifecycleStatus = archived).

    Security:
    - Only product owner or admin can delete
    - Cannot delete if there are pending orders
    - Product remains in database for order history

    Request data:
        productId: Document ID of product to delete

    Returns:
        {success: True, message: "Product deleted"}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    product_id = req.data.get(Fields.PRODUCT_ID)

    # Validate productId before consuming rate-limit tokens — prevents quota exhaustion via empty calls
    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId required")

    # Rate limit: 10/min — prevent mass-deletion abuse
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.DELETE_PRODUCT, max_requests=10, window_minutes=1, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
    product_doc = product_ref.get()

    if not product_doc.exists:
        raise https_fn.HttpsError("not-found", "Product not found")

    product_data = product_doc.to_dict()

    # Check permissions
    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_data = user_doc.to_dict()
    is_admin = UserRoleValues.ADMIN in user_data.get(Fields.ROLES, [])
    is_owner = product_data[Fields.SELLER_ID] == user_id

    if not (is_admin or is_owner):
        raise https_fn.HttpsError("permission-denied", "Only product owner or admin can delete")

    # Check for pending orders
    # NOTE: Firestore can't filter on nested array map fields with array_contains.
    # Use sellerIds (denormalized on orders) to find related orders for this seller,
    # then check if any contain this productId in items.
    pending_orders_query = (
        get_db()
        .collection(Collections.ORDERS)
        .where(Fields.SELLER_IDS, "array_contains", user_id)
        .where(
            Fields.ORDER_STATUS,
            "in",
            [
                OrderStatusValues.PENDING,
                OrderStatusValues.CONFIRMED,
                OrderStatusValues.PROCESSING,
                OrderStatusValues.SHIPPED,
            ],
        )
        .limit(20)
    )

    pending_orders = []
    for order_doc in pending_orders_query.stream():
        order_data_check = order_doc.to_dict()
        for item in order_data_check.get(Fields.ITEMS, []):
            if item.get(Fields.PRODUCT_ID) == product_id:
                pending_orders.append(order_doc)
                break

    if pending_orders:
        raise https_fn.HttpsError(
            "failed-precondition", "Cannot delete product with pending orders. Please wait for orders to complete."
        )

    # Soft delete
    product_ref.update({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ARCHIVED, Fields.DELETED_AT: get_server_timestamp(), Fields.DELETED_BY: user_id})

    try:
        algolia_delete_product(product_id)
    except Exception as e:
        logger.error(f"Failed to delete from Algolia: {str(e)}")

    # Delete R2 images — soft delete does not trigger on_product_deleted, so cleanup must happen here.
    # Non-fatal: failures are logged but do not block the response.
    try:
        s3 = _get_cached_s3_client()
        bucket = R2Config.BUCKET_NAME
        cdn_prefix = CDN_BASE_URL + "/"
        valid_prefixes = ("products/", "emulator/products/", "dev/products/", "staging/products/")
        for img_url in product_data.get(Fields.IMAGE_URLS) or []:
            if not isinstance(img_url, str) or not img_url.startswith(cdn_prefix):
                continue
            key = img_url[len(cdn_prefix):]
            if not any(key.startswith(p) for p in valid_prefixes):
                continue
            with contextlib.suppress(Exception):
                s3.delete_object(Bucket=bucket, Key=key)
        logger.info(f"delete_product: R2 images cleaned up for product {product_id}")
    except Exception as e:
        logger.error(f"Failed to cleanup R2 images for deleted product {product_id}: {e}")

    # Clean up stock_notification subscriptions for this product (paginated for 200+ watchers)
    try:
        while True:
            subs = list(get_db().collection(Collections.STOCK_NOTIFICATIONS).where(Fields.PRODUCT_ID, "==", product_id).limit(200).stream())
            if not subs:
                break
            batch = get_db().batch()
            for sub in subs:
                batch.delete(sub.reference)
            batch.commit()
    except Exception as e:
        logger.error(f"Failed to cleanup stock_notifications for deleted product {product_id}: {e}")

    # Clean up favorites entries across all users for this product.
    # FIX: Paginate the batch loop — a single .limit(500) batch silently leaves
    # orphans when a popular product has >500 fans. Mirror the paginated pattern
    # already used for stock_notification cleanup above.
    try:
        total_fav_cleaned = 0
        while True:
            fav_refs = list(
                get_db().collection_group(Collections.FAVORITES).where(Fields.PRODUCT_ID, "==", product_id).limit(200).stream()
            )
            if not fav_refs:
                break
            fav_batch = get_db().batch()
            for fav in fav_refs:
                fav_batch.delete(fav.reference)
            fav_batch.commit()
            total_fav_cleaned += len(fav_refs)
            if len(fav_refs) < 200:
                break
        if total_fav_cleaned:
            logger.info(f"Cleaned up {total_fav_cleaned} favorites for deleted product {product_id}")
    except Exception as e:
        logger.error(f"Failed to cleanup favorites for deleted product {product_id}: {e}")

    return create_success_response({"message": "Product deleted successfully"})


@https_fn.on_call(**DEFAULT_OPTIONS)
def submit_product_rating_atomic(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Atomically submits a product rating with images.
    Solves QA-H1: Images are uploaded and document is created in one backend operation.
    If Firestore write fails, uploaded images are rolled back (deleted).
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data

    product_id = data.get(Fields.PRODUCT_ID)
    order_id = data.get(Fields.ORDER_ID)
    rating = data.get(Fields.RATING)
    review_raw = data.get(Fields.REVIEW, "")
    images_raw = data.get(ApiKeys.IMAGES, [])

    if not product_id or not order_id or rating is None:
        raise https_fn.HttpsError("invalid-argument", "productId, orderId, and rating required")

    # 1. Validation (fast checks before R2)
    if not isinstance(rating, (int, float)) or rating < 1 or rating > 5:
        raise https_fn.HttpsError("invalid-argument", "Rating must be between 1 and 5")

    # Premium check for photo reviews
    if images_raw:
        from utils.premium_check import is_premium_authoritative
        if not is_premium_authoritative(user_id, db=get_db()):
            raise https_fn.HttpsError("permission-denied", "Photo reviews are a premium feature.")
        if len(images_raw) > BusinessRules.MAX_REVIEW_IMAGES:
            raise https_fn.HttpsError("invalid-argument", f"Max {BusinessRules.MAX_REVIEW_IMAGES} images.")

    # 2. Verify Purchase (before uploading images to save bandwidth/costs)
    order_ref = get_db().collection(Collections.ORDERS).document(order_id)
    order_doc = order_ref.get()
    if not order_doc.exists:
        raise https_fn.HttpsError("not-found", "Order not found")

    order_data = order_doc.to_dict() or {}
    if order_data.get(Fields.USER_ID) != user_id:
        raise https_fn.HttpsError("permission-denied", "Order ownership mismatch")

    if order_data.get(Fields.ORDER_STATUS) not in {OrderStatusValues.DELIVERED, OrderStatusValues.DISPUTED}:
        raise https_fn.HttpsError("failed-precondition", "Order not in ratable state")

    # Block sellers from rating their own product
    rated_item = next(
        (item for item in order_data.get(Fields.ITEMS, []) if item.get(Fields.PRODUCT_ID) == product_id),
        None,
    )
    if rated_item and rated_item.get(Fields.SELLER_ID) == user_id:
        raise https_fn.HttpsError("permission-denied", "Sellers cannot rate their own products")

    # Ensure the rated product is actually in this order
    if not any(item.get(Fields.PRODUCT_ID) == product_id for item in order_data.get(Fields.ITEMS, [])):
        raise https_fn.HttpsError("invalid-argument", "Product not in this order")

    # 3. Image Upload (R2)
    review_image_urls = []
    uploaded_keys = []
    if images_raw:
        s3_client = _get_cached_s3_client()
        bucket_name = R2Config.BUCKET_NAME

        ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
        MIME_TO_EXT = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}

        try:
            for i, img_item in enumerate(images_raw):
                content_type = img_item.get("contentType", "image/jpeg")
                if content_type not in ALLOWED_MIME_TYPES:
                    continue

                img_bytes = _base64.b64decode(img_item.get("data", ""))
                if not img_bytes:
                    continue

                ext = MIME_TO_EXT[content_type]
                key = R2Config.get_image_path("reviews", f"{uuid.uuid4()}.{ext}")
                s3_client.put_object(
                    Bucket=bucket_name, Key=key, Body=img_bytes,
                    ContentType=content_type, ContentDisposition="inline"
                )
                uploaded_keys.append(key)
                review_image_urls.append(f"{CDN_BASE_URL}/{key}")
        except Exception as e:
            # Cleanup
            for k in uploaded_keys:
                with contextlib.suppress(Exception):
                    s3_client.delete_object(Bucket=bucket_name, Key=k)
            raise https_fn.HttpsError("internal", f"Image upload failed: {e}") from e

    # 4. Atomically write rating and update product avg
    from utils.helpers import sanitized_text
    review = sanitized_text(review_raw)[:1000] if review_raw else ""

    rating_doc = {
        Fields.PRODUCT_ID: product_id,
        Fields.USER_ID: user_id,
        Fields.ORDER_ID: order_id,
        Fields.RATING: rating,
        Fields.REVIEW: review,
        Fields.CREATED_AT: get_server_timestamp(),
        Fields.HELPFUL_COUNT: 0,
        Fields.VERIFIED_PURCHASE: True,
        Fields.REVIEW_IMAGE_URLS: review_image_urls
    }

    product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
    new_rating_ref = get_db().collection(Collections.PRODUCT_RATINGS).document()
    _txn_error = {}

    @get_firestore().transactional
    def update_rating_txn(transaction):
        # Duplicate check by order (prevents double-click)
        """Function update_rating_txn."""
        existing_order = list(get_db().collection(Collections.PRODUCT_RATINGS).where(Fields.ORDER_ID, "==", order_id).limit(1).stream(transaction=transaction))
        if existing_order:
            _txn_error["err"] = https_fn.HttpsError("already-exists", "Already rated")
            return None, None

        # Duplicate check by user+product (one rating per user per product across all orders)
        existing_user_product = list(
            get_db()
            .collection(Collections.PRODUCT_RATINGS)
            .where(Fields.USER_ID, "==", user_id)
            .where(Fields.PRODUCT_ID, "==", product_id)
            .limit(1)
            .stream(transaction=transaction)
        )
        if existing_user_product:
            _txn_error["err"] = https_fn.HttpsError("already-exists", "You have already rated this product")
            return None, None

        p_snap = product_ref.get(transaction=transaction)
        if not p_snap.exists:
            _txn_error["err"] = https_fn.HttpsError("not-found", "Product gone")
            return None, None

        p_data = p_snap.to_dict() or {}
        curr_rating = p_data.get(Fields.RATING, 0.0)
        curr_count = p_data.get(Fields.RATING_COUNT, 0)

        new_count = curr_count + 1
        new_avg = ((curr_rating * curr_count) + rating) / new_count

        transaction.create(new_rating_ref, rating_doc)
        transaction.update(product_ref, {Fields.RATING: new_avg, Fields.RATING_COUNT: new_count})
        return new_avg, new_count

    try:
        new_avg, new_count = update_rating_txn(get_db().transaction())
        if "err" in _txn_error:
            raise _txn_error["err"]
        # Sync updated rating to Algolia so sort-by-rating returns correct results
        if new_avg is not None:
            algolia_partial_update(product_id, {Fields.RATING: new_avg, Fields.RATING_COUNT: new_count})
        return create_success_response({"newRating": new_avg, "ratingCount": new_count})
    except Exception as e:
        # ROLLBACK R2 IMAGES if Firestore fails
        s3_client = _get_cached_s3_client()
        for k in uploaded_keys:
            with contextlib.suppress(Exception):
                s3_client.delete_object(Bucket=R2Config.BUCKET_NAME, Key=k)
        if isinstance(e, https_fn.HttpsError):
            raise
        logger.error(f"submit_product_rating_atomic failed: {e}")
        raise https_fn.HttpsError("internal", str(e)) from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def submit_product_rating(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Submits a product rating after order delivery.

    Security:
    - User must have purchased and received the product
    - One rating per user per product
    - Rating: 1-5 stars

    Request data:
        productId: Product to rate
        orderId: Order ID (for verification)
        rating: 1-5
        review: Optional text review
        reviewImageUrls: Optional list of CDN image URLs (max 3)

    Returns:
        {success: True, newRating: 4.5, ratingCount: 120}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    # AUDIT FIX: Rate limit rating submissions
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=req.auth.uid, action=RateLimitActions.SUBMIT_RATING, max_requests=5, window_minutes=1, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    user_id = req.auth.uid
    data = req.data

    # Import validation functions
    from utils.helpers import sanitized_text

    product_id = data.get(Fields.PRODUCT_ID)
    order_id = data.get(Fields.ORDER_ID)
    rating = data.get(Fields.RATING)
    seller_rating = data.get(Fields.SELLER_RATING) # F-315: Optional seller rating
    review_raw = data.get(Fields.REVIEW, "")
    review_image_urls_raw = data.get(Fields.REVIEW_IMAGE_URLS, [])

    # Sanitize review text to prevent XSS
    review = sanitized_text(review_raw)[:1000] if review_raw else ""  # Max 1000 chars

    # TASK 06: Validate reviewImageUrls — max 3, must be from CDN, premium only
    if review_image_urls_raw:
        if not isinstance(review_image_urls_raw, list):
            raise https_fn.HttpsError("invalid-argument", "reviewImageUrls must be a list")
        if len(review_image_urls_raw) > BusinessRules.MAX_REVIEW_IMAGES:
            raise https_fn.HttpsError("invalid-argument", f"Maximum {BusinessRules.MAX_REVIEW_IMAGES} review images allowed")
        # Photo reviews require premium — verify before accepting URLs
        from utils.premium_check import is_premium_authoritative
        if not is_premium_authoritative(user_id, db=get_db()):
            raise https_fn.HttpsError(
                "permission-denied", "Photo reviews are a premium feature. Upgrade to add photos to your reviews."
            )
        for url in review_image_urls_raw:
            if not isinstance(url, str) or not url.startswith(CDN_BASE_URL):
                raise https_fn.HttpsError("invalid-argument", "Review images must be uploaded to the platform CDN")
    review_image_urls: list[str] = [str(u) for u in review_image_urls_raw] if review_image_urls_raw else []

    if not product_id or not order_id or rating is None:
        raise https_fn.HttpsError("invalid-argument", "productId, orderId, and rating required")

    # Validate rating is numeric and in valid range
    if not isinstance(rating, (int, float)) or rating < 1 or rating > 5:
        raise https_fn.HttpsError("invalid-argument", "Rating must be between 1 and 5")

    # Verify user purchased this product
    order_ref = get_db().collection(Collections.ORDERS).document(order_id)
    order_doc = order_ref.get()

    if not order_doc.exists:
        raise https_fn.HttpsError("not-found", "Order not found")

    order_data = order_doc.to_dict()

    if order_data.get(Fields.USER_ID) != user_id:
        raise https_fn.HttpsError("permission-denied", "This is not your order")

    # Block sellers from rating their own product
    rated_item = next((item for item in order_data.get(Fields.ITEMS, []) if item.get(Fields.PRODUCT_ID) == product_id), None)
    if rated_item and rated_item.get(Fields.SELLER_ID) == user_id:
        raise https_fn.HttpsError("permission-denied", "Sellers cannot rate their own products")

    if order_data[Fields.ORDER_STATUS] not in {OrderStatusValues.DELIVERED, OrderStatusValues.DISPUTED}:
        raise https_fn.HttpsError("failed-precondition", "Can only rate delivered orders")

    # Check if product is in order
    product_in_order = any(item[Fields.PRODUCT_ID] == product_id for item in order_data[Fields.ITEMS])

    if not product_in_order:
        raise https_fn.HttpsError("invalid-argument", "Product not in this order")

    # Build rating doc (pre-assembled — written atomically inside transaction below)
    rating_doc: dict = {
        Fields.PRODUCT_ID: product_id,
        Fields.USER_ID: user_id,
        Fields.ORDER_ID: order_id,
        Fields.RATING: rating,
        Fields.REVIEW: review,
        Fields.CREATED_AT: get_server_timestamp(),
        Fields.HELPFUL_COUNT: 0,
        # Votes are tracked in review_votes/{userId} subcollection (not an array)
        # FIX C-1: Mark as verified purchase (order ownership + delivery already validated above)
        Fields.VERIFIED_PURCHASE: True,
    }

    # F-312: Security - Related Party Gaming Detection
    # If shipping address matches seller address EXACTLY, it's a high-risk gaming attempt (friends/family)
    shipping_addr = order_data.get(Fields.SHIPPING_ADDRESS, {})
    seller_addr = rated_item.get(Fields.SELLER_ADDRESS, {}) if rated_item else {}

    # Comparison keys for "Related Party" detection (approximate for now)
    cmp_keys = ["street", "city", "state", "postalCode"]
    is_related = all(shipping_addr.get(k) == seller_addr.get(k) for k in cmp_keys if shipping_addr.get(k))

    if is_related:
        rating_doc[Fields.IS_RELATED_PARTY] = True
        logger.warning(f"Related party review detected: buyer={user_id} seller={rated_item.get(Fields.SELLER_ID)} product={product_id}")

    if review_image_urls:
        rating_doc[Fields.REVIEW_IMAGE_URLS] = review_image_urls

    # Atomically: check for duplicate, write the rating doc AND update the product average in one transaction.
    # Moving the duplicate check inside the transaction prevents race conditions.
    product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
    new_rating_ref = get_db().collection(Collections.PRODUCT_RATINGS).document()  # Pre-generate doc ref
    _txn_error: dict = {}

    def update_rating_transaction(transaction):
        # FIX C-2: Dual duplicate guard — by order (prevents double-click) AND by user+product
        # (prevents rating inflation when a user buys the same product in multiple orders).
        """Function update_rating_transaction."""
        existing_order = list(
            get_db()
            .collection(Collections.PRODUCT_RATINGS)
            .where(Fields.ORDER_ID, "==", order_id)
            .limit(1)
            .stream(transaction=transaction)
        )
        if existing_order:
            _txn_error["err"] = https_fn.HttpsError("already-exists", "This order has already been rated")
            return None, None

        # FIX C-2: One rating per user per product (across all orders)
        existing_user_product = list(
            get_db()
            .collection(Collections.PRODUCT_RATINGS)
            .where(Fields.USER_ID, "==", user_id)
            .where(Fields.PRODUCT_ID, "==", product_id)
            .limit(1)
            .stream(transaction=transaction)
        )
        if existing_user_product:
            _txn_error["err"] = https_fn.HttpsError("already-exists", "You have already rated this product")
            return None, None

        # Fetch product doc inside transaction for consistent read
        product_doc = product_ref.get(transaction=transaction)
        if not product_doc.exists:
            _txn_error["err"] = https_fn.HttpsError("not-found", "Product not found")
            return None, None
        product_data = product_doc.to_dict()
        current_rating = product_data.get(Fields.RATING, 0)
        rating_count = product_data.get(Fields.RATING_COUNT, 0)
        seller_id = product_data.get(Fields.SELLER_ID)

        # Calculate new average atomically
        total_rating = current_rating * rating_count
        new_rating_count = rating_count + 1
        new_average = (total_rating + rating) / new_rating_count

        transaction.create(new_rating_ref, rating_doc)
        transaction.update(product_ref, {Fields.RATING: new_average, Fields.RATING_COUNT: new_rating_count})

        # F-315: Handle optional seller rating
        if seller_rating is not None and isinstance(seller_rating, (int, float)) and 1 <= seller_rating <= 5 and seller_id:
            seller_ref = get_db().collection(Collections.USERS).document(seller_id)
            seller_doc = seller_ref.get(transaction=transaction)
            if seller_doc.exists:
                seller_data = seller_doc.to_dict() or {}
                s_rating = seller_data.get(Fields.AVG_RATING, 0)
                s_count = seller_data.get(Fields.TOTAL_REVIEWS, 0)

                new_s_count = s_count + 1
                new_s_rating = ((s_rating * s_count) + seller_rating) / new_s_count

                transaction.update(seller_ref, {
                    Fields.AVG_RATING: new_s_rating,
                    Fields.TOTAL_REVIEWS: new_s_count,
                    Fields.UPDATED_AT: get_server_timestamp(),
                })

                # Create separate seller rating entry for audit trail
                seller_rating_ref = get_db().collection(Collections.SELLER_RATINGS).document()
                transaction.create(seller_rating_ref, {
                    Fields.SELLER_ID: seller_id,
                    Fields.BUYER_ID: user_id,
                    Fields.ORDER_ID: order_id,
                    Fields.RATING: seller_rating,
                    Fields.CREATED_AT: get_server_timestamp(),
                })

        return new_average, new_rating_count

    txn_fn = get_firestore().transactional(update_rating_transaction)
    transaction = get_db().transaction()
    new_average, new_rating_count = txn_fn(transaction)

    if "err" in _txn_error:
        raise _txn_error["err"]

    if new_average is not None:
        # Sync updated rating to Algolia so sort-by-rating returns correct results
        algolia_partial_update(product_id, {Fields.RATING: new_average, Fields.RATING_COUNT: new_rating_count})
        return create_success_response({"newRating": new_average, Fields.RATING_COUNT: new_rating_count})

    raise https_fn.HttpsError("not-found", "Product not found")


def validate_image_magic_bytes(image_url: str) -> bool:
    """
    SECURITY FIX #6: Validate uploaded image by checking magic bytes.
    Downloads first 16 bytes and verifies against known image signatures.
    Returns True if valid image, False if malicious/invalid.
    """
    try:
        resp = requests.get(image_url, stream=True, timeout=5)
        if resp.status_code != 200:
            logger.warning(f"⚠️ Image validation failed: HTTP {resp.status_code} for {image_url}")
            return False

        # Read only first 16 bytes for magic byte check
        header_bytes = resp.raw.read(16)
        resp.close()

        if not header_bytes:
            return False

        for magic, _mime in BusinessRules.IMAGE_MAGIC_BYTES.items():
            if header_bytes[: len(magic)] == magic:
                return True

        logger.warning(f"⚠️ SECURITY: Image {image_url} has invalid magic bytes: {header_bytes[:8].hex()}")
        return False
    except Exception as e:
        logger.warning(f"⚠️ Image validation error for {image_url}: {type(e).__name__}")
        # Fail open for CDN timeout issues; rely on MIME type validation
        return True


def _verify_address_with_geoapify(
    product_id: str,
    lat: float,
    lon: float,
    street: str,
    city: str,
    postal_code: str,
    country: str,
) -> tuple[bool, str]:
    """
    SECURITY: Verify seller address coordinates via Geoapify reverse geocoding.

    Returns:
        (is_valid, reason) — bool indicates if address is valid, reason is error message

    Validation rules:
    - Address MUST be verified via Geoapify for non-digital products
    - Coordinates must match declared city/postal/country (fuzzy matching)
    - If unverified or fake address detected → product is REJECTED
    """
    geo_key = get_geoapify_api_key()
    if not geo_key:
        # In production, we MUST have Geoapify key. Fail closed.
        return False, "Address verification service not configured"

    try:
        url = f"https://api.geoapify.com/v1/geocode/reverse?lat={lat}&lon={lon}&apiKey={geo_key}"
        response = requests.get(url, timeout=AppConfig.GEOAPIFY_TIMEOUT_SECONDS)
        if response.status_code != 200:
            return False, f"Address verification failed (HTTP {response.status_code})"

        data = response.json()
        features = data.get("features", [])
        if not features:
            return (False, f"Address verification returned no results — coordinates ({lat}, {lon}) may be invalid")

        props = features[0].get("properties", {})
        geo_city = (props.get("city") or props.get("town") or props.get("village") or "").lower()
        geo_postal = (props.get("postcode") or "").replace(" ", "").replace("-", "").upper()
        geo_country = (props.get("country_code") or "").upper()

        declared_city = city.lower().strip()
        declared_postal = postal_code.replace(" ", "").replace("-", "").upper()
        declared_country = country.upper().strip()

        # Check country match (CA vs CA)
        country_match = geo_country == declared_country[:2].upper() if declared_country else False

        # Check city match (fuzzy — first 3 chars)
        city_match = (
            geo_city[:3] == declared_city[:3]
            if len(geo_city) >= 3 and len(declared_city) >= 3
            else geo_city == declared_city
        )

        # Check postal code match (first 3 chars = Forward Sortation Area)
        postal_match = (
            geo_postal[:3] == declared_postal[:3]
            if len(geo_postal) >= 3 and len(declared_postal) >= 3
            else False  # Strict: postal code must be provided and match
        )

        if not country_match:
            return False, f"Country mismatch: declared {declared_country} vs verified {geo_country}"

        if not city_match:
            return False, f"City mismatch: declared {declared_city} vs verified {geo_city}"

        if not postal_match:
            return False, f"Postal code mismatch: declared {declared_postal} vs verified {geo_postal}"

        logger.info(f"✅ Address verified for product {product_id}: {geo_city}, {geo_postal}")
        return True, ""

    except requests.Timeout:
        return False, "Address verification timeout — please try again"
    except Exception as e:
        return False, f"Address verification error: {type(e).__name__}"


def _geocode_warehouse_address(address: dict) -> dict:
    """Forward-geocode a warehouse address via Geoapify, injecting lat/lon into the dict.
    Fail-open: logs warning, returns original address on failure.
    """
    from utils.helpers import geocode_address
    success, error_msg, geocoded_address = geocode_address(address)
    if not success:
        logger.warning(f"Warehouse geocode failed: {error_msg}")
        return address

    return geocoded_address


def _validate_warehouse_address(address: dict) -> None:
    """
    Validate warehouse address fields.
    FIX H-04: Enforces Canadian postal-code format and province whitelist on server side.
    WH-H2 FIX: International warehouses skip CA-specific validation but still require
    address, city, and country fields to be present.
    Raises https_fn.HttpsError("invalid-argument", ...) on failure.
    """
    if not isinstance(address, dict):
        raise https_fn.HttpsError("invalid-argument", "address must be a map")

    # Required for all warehouses regardless of country
    street = (address.get(Fields.STREET) or "").strip()
    if not street:
        raise https_fn.HttpsError("invalid-argument", "address.street is required")
    city = (address.get(Fields.CITY) or "").strip()
    if not city:
        raise https_fn.HttpsError("invalid-argument", "address.city is required")
    country_raw = (address.get(Fields.COUNTRY) or "").strip()
    if not country_raw:
        raise https_fn.HttpsError("invalid-argument", "address.country is required")

    country = country_raw.lower()
    state = (address.get(Fields.STATE) or "").strip().upper()
    postal = (address.get(Fields.POSTAL_CODE) or "").strip().upper()

    # Canadian-specific validation: province whitelist + postal code format
    if country in ("canada", "ca"):
        if state and state not in BusinessRules.VALID_PROVINCES:
            raise https_fn.HttpsError(
                "invalid-argument",
                f"Invalid province '{state}'. Must be one of: {sorted(BusinessRules.VALID_PROVINCES)}",
            )
        if postal:
            ca_postal_re = re.compile(r"^[A-Z]\d[A-Z][ -]?\d[A-Z]\d$")
            if not ca_postal_re.match(postal):
                raise https_fn.HttpsError(
                    "invalid-argument",
                    f"Invalid Canadian postal code '{postal}'. Expected format: A1A 1A1",
                )
    # International warehouses: no CA-specific checks, required fields already validated above


def _derive_ship_from_fields(seller_id: str, product_data: dict) -> dict:
    """Derive shipFrom* fields from warehouse addresses or seller address.
    Returns dict with shipFromCity, shipFromProvince, shipFromCountry, shipFromCountries,
    and denormalized sellerAddress (from primary warehouse) if warehouses are used.
    """
    if product_data.get(Fields.IS_DIGITAL, False):
        return {}

    warehouse_ids = product_data.get(Fields.WAREHOUSE_IDS) or []
    if not warehouse_ids:
        # Individual seller — use sellerAddress
        addr = product_data.get(Fields.SELLER_ADDRESS) or {}
        result = {}
        if addr.get(Fields.CITY):
            result[Fields.SHIP_FROM_CITY] = addr[Fields.CITY]
        if addr.get(Fields.STATE):
            result[Fields.SHIP_FROM_PROVINCE] = addr[Fields.STATE]
        if addr.get(Fields.COUNTRY):
            result[Fields.SHIP_FROM_COUNTRY] = addr[Fields.COUNTRY]
            result[Fields.SHIP_FROM_COUNTRIES] = [addr[Fields.COUNTRY]]
        return result

    # Warehouse seller — batch-read warehouse docs
    wh_refs = [
        get_db()
        .collection(Collections.USERS)
        .document(seller_id)
        .collection(Collections.WAREHOUSES)
        .document(wh_id)
        for wh_id in warehouse_ids[:20]  # Cap reads
    ]
    wh_docs = get_db().get_all(wh_refs)

    countries = set()
    primary_addr = None
    for doc in wh_docs:
        if not doc.exists:
            continue
        wh_data = doc.to_dict() or {}
        addr = wh_data.get("address") or {}
        country = addr.get(Fields.COUNTRY)
        if country:
            countries.add(country)
        # Use default warehouse as primary, otherwise first
        if wh_data.get("isDefault", False) or primary_addr is None:
            primary_addr = addr

    result = {}
    if primary_addr:
        if primary_addr.get(Fields.CITY):
            result[Fields.SHIP_FROM_CITY] = primary_addr[Fields.CITY]
        if primary_addr.get(Fields.STATE):
            result[Fields.SHIP_FROM_PROVINCE] = primary_addr[Fields.STATE]
        if primary_addr.get(Fields.COUNTRY):
            result[Fields.SHIP_FROM_COUNTRY] = primary_addr[Fields.COUNTRY]

        # M-02: Denormalize sellerAddress from primary warehouse
        # This allows checkout to skip extra Firestore reads for warehouse docs.
        result[Fields.SELLER_ADDRESS] = primary_addr

    if countries:
        result[Fields.SHIP_FROM_COUNTRIES] = sorted(countries)
    return result




@https_fn.on_call(**DEFAULT_OPTIONS)
def create_product_atomic(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Atomically uploads product images to Cloudflare R2 and creates the product
    document in Firestore in a single backend operation.

    Eliminates client-side orchestration — images and product doc are committed
    together. On any R2 or Firestore failure, uploaded images are cleaned up
    automatically.

    Security:
    - Authenticated sellers only
    - Seller onboarding must be complete
    - imageUrls, productId, sellerId, lifecycleStatus, createdAt are always set server-side
    - Max 5 images, each max 10MB, magic-byte validated

    Request data:
        productData: dict  — serialized product fields (imageUrls/productId ignored, set server-side)
        images: list[{data: str (base64), contentType: str}]  — max 5
        testImageUrls: list[str]  — (emulator/dev only) placeholder URLs when images is empty

    Returns:
        { productId: str, imageUrls: list[str], success: True }
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # Seller role + onboarding check
    user_doc = get_db().collection(Collections.USERS).document(user_id).get()
    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")
    user_data = user_doc.to_dict() or {}
    if user_data.get(Fields.SUSPENDED, False):
        raise https_fn.HttpsError("permission-denied", "Your account is suspended")
    roles = user_data.get(Fields.ROLES, [])
    if UserRoleValues.SELLER not in roles and UserRoleValues.ADMIN not in roles:
        raise https_fn.HttpsError("permission-denied", "Seller role required")
    # Read onboarding status from seller_profiles (authoritative source per schema)
    # NOTE: users/{uid}.onboardingCompleted is unreliable — sellers control that doc
    if UserRoleValues.ADMIN not in roles:
        sp_doc = get_db().collection(Collections.SELLER_PROFILES).document(user_id).get()
        sp_data = sp_doc.to_dict() if sp_doc.exists else {}
        if not sp_data.get(Fields.ONBOARDING_COMPLETED, False):
            raise https_fn.HttpsError("failed-precondition", "Please complete seller onboarding before uploading products")

    # Rate limit
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.CREATE_PRODUCT, max_requests=5, window_minutes=1, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    data = req.data
    product_data: dict = dict(data.get(ApiKeys.PRODUCT_DATA) or {})
    images_raw = data.get(ApiKeys.IMAGES, [])
    test_image_urls = data.get(ApiKeys.TEST_IMAGE_URLS, [])

    if not product_data:
        raise https_fn.HttpsError("invalid-argument", f"{ApiKeys.PRODUCT_DATA} is required")
    if not isinstance(images_raw, list):
        raise https_fn.HttpsError("invalid-argument", "images must be a list")
    if len(images_raw) > BusinessRules.MAX_PRODUCT_IMAGES:
        raise https_fn.HttpsError("invalid-argument", f"Maximum {BusinessRules.MAX_PRODUCT_IMAGES} images allowed")

    ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
    MIME_TO_EXT = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif"}

    # Decode and validate all images upfront — fail fast before touching R2
    decoded_images: list[tuple[bytes, str]] = []
    for i, img_item in enumerate(images_raw):
        content_type = img_item.get("contentType", "image/jpeg")
        if content_type not in ALLOWED_MIME_TYPES:
            raise https_fn.HttpsError("invalid-argument", f"Image {i}: invalid content type '{content_type}'")
        try:
            img_bytes = _base64.b64decode(img_item.get("data", ""))
        except Exception as exc:
            raise https_fn.HttpsError("invalid-argument", f"Image {i}: invalid base64 data") from exc
        if not img_bytes:
            raise https_fn.HttpsError("invalid-argument", f"Image {i}: empty data")
        if len(img_bytes) > BusinessRules.MAX_IMAGE_BYTES:
            raise https_fn.HttpsError("invalid-argument", f"Image {i} exceeds 10 MB limit")
        # Magic bytes validation
        if not any(img_bytes[: len(magic)] == magic for magic in BusinessRules.IMAGE_MAGIC_BYTES):
            raise https_fn.HttpsError("invalid-argument", f"Image {i}: not a recognized image format")
        decoded_images.append((img_bytes, content_type))

    # Determine image_urls: real R2 upload or dev/emulator placeholder
    uploaded_keys: list[str] = []
    image_urls: list[str] = []

    if not decoded_images:
        # Accept placeholder URLs only in emulator or dev environments
        is_non_prod = CURRENT_ENV in (Environment.EMULATOR, Environment.DEV)
        if test_image_urls and isinstance(test_image_urls, list) and is_non_prod:
            image_urls = [str(u) for u in test_image_urls[:5]]
        else:
            raise https_fn.HttpsError("invalid-argument", "At least one product image is required")
    else:
        s3_client = _get_cached_s3_client()
        bucket_name = R2Config.BUCKET_NAME

        try:
            for img_bytes, content_type in decoded_images:
                ext = MIME_TO_EXT[content_type]
                key = R2Config.get_image_path("products", f"{uuid.uuid4()}.{ext}")
                s3_client.put_object(
                    Bucket=bucket_name,
                    Key=key,
                    Body=img_bytes,
                    ContentType=content_type,
                    ContentDisposition="inline",
                )
                uploaded_keys.append(key)
                image_urls.append(f"{CDN_BASE_URL}/{key}")
        except Exception as e:
            # Cleanup partial uploads before raising
            import contextlib
            for key in uploaded_keys:
                with contextlib.suppress(Exception):
                    s3_client.delete_object(Bucket=bucket_name, Key=key)
            logger.error(f"create_product_atomic: R2 upload failed for user {user_id}: {e}")
            raise https_fn.HttpsError("internal", "Failed to upload images. Please try again.") from e

    # Override server-controlled fields — NEVER trust client values for these
    product_data[Fields.IMAGE_URLS] = image_urls
    product_data[Fields.SELLER_ID] = user_id
    # Remove client-sent lifecycleStatus — ProductCreate validator requires DRAFT (its default).
    # We re-apply UNDER_REVIEW after Pydantic validation below.
    product_data.pop(Fields.LIFECYCLE_STATUS, None)
    product_data[Fields.CREATED_AT] = get_server_timestamp()
    product_data[Fields.UPDATED_AT] = get_server_timestamp()
    product_data.pop(Fields.PRODUCT_ID, None)  # Generated server-side below
    product_data.pop("rating", None)
    product_data.pop("ratingCount", None)

    # Validate videoUrl
    video_url = product_data.get(Fields.VIDEO_URL)
    if video_url:
        if not str(video_url).startswith(CDN_BASE_URL):
            raise https_fn.HttpsError("invalid-argument", "Invalid video URL origin")

    # International shipping enforcement (T-4)
    if product_data.get(Fields.IS_INTERNATIONAL) is None:
        product_data[Fields.IS_INTERNATIONAL] = False

    if product_data[Fields.IS_INTERNATIONAL] and not product_data.get(Fields.SHIP_FROM_COUNTRY):
        raise https_fn.HttpsError("invalid-argument", "shipFromCountry is required for international products")

    if not product_data[Fields.IS_INTERNATIONAL] and not product_data.get(Fields.SHIP_FROM_COUNTRY):
        product_data[Fields.SHIP_FROM_COUNTRY] = COUNTRY_CANADA

    # N-11: Subcategory validation — must belong to the product's category
    subcategory = product_data.get(Fields.SUBCATEGORY)
    category_id = product_data.get(Fields.CATEGORY_ID)
    if subcategory and category_id is not None:
        cat_id_int = int(category_id)
        allowed = Subcategories.MAP.get(cat_id_int, [])
        if subcategory not in allowed:
            raise https_fn.HttpsError(
                "invalid-argument",
                f"Subcategory '{subcategory}' is not valid for category {cat_id_int}",
            )

    # ADDR-H2: Server-side geocoding for sellerAddress (if no warehouses used)
    # Ensures coordinates are verified and Accurate. Surfaces Geoapify errors.
    warehouse_ids = product_data.get(Fields.WAREHOUSE_IDS) or []
    is_digital = product_data.get(Fields.IS_DIGITAL, False)
    seller_address = product_data.get(Fields.SELLER_ADDRESS)

    if not is_digital and not warehouse_ids and seller_address:
        from utils.helpers import geocode_address
        success, error_msg, geocoded_address = geocode_address(seller_address)
        if not success:
            logger.warning(f"create_product_atomic: sellerAddress geocoding failed: {error_msg}")
            raise https_fn.HttpsError("invalid-argument", f"Seller address error: {error_msg}")

        product_data[Fields.SELLER_ADDRESS] = geocoded_address
        logger.info(f"create_product_atomic: sellerAddress verified for user {user_id}")

    # Normalize apartment: empty string → null (Firestore rules requirement)
    seller_address = product_data.get(Fields.SELLER_ADDRESS)
    if isinstance(seller_address, dict) and seller_address.get("apartment") == "":
        seller_address["apartment"] = None

    # Atomic SKU uniqueness check using a collision doc — prevents concurrent submissions
    # with the same SKU from both passing the non-transactional query above.
    seller_sku = product_data.get(Fields.SELLER_SKU)
    sku_collision_ref = None
    if seller_sku:
        sku_key = f"{user_id}_{seller_sku}"
        sku_collision_ref = get_db().collection(Collections.SELLER_SKUS).document(sku_key)
        try:
            sku_collision_ref.create({
                Fields.SELLER_ID: user_id,
                Fields.SELLER_SKU: seller_sku,
                Fields.CREATED_AT: get_server_timestamp(),
            })
        except Exception as sku_err:
            # Detect Firestore AlreadyExists by exception type first (precise), then
            # fall back to status code / message for SDK variants that wrap the error.
            from google.api_core.exceptions import AlreadyExists as _AlreadyExists
            err_str = str(sku_err).lower()
            is_conflict = (
                isinstance(sku_err, _AlreadyExists)
                or "already-exists" in err_str
                or "already exists" in err_str
                or "conflict" in err_str
                or "409" in err_str
            )
            if is_conflict:
                raise https_fn.HttpsError(
                    "already-exists", f"A product with SKU \"{seller_sku}\" already exists. Use a unique seller SKU."
                ) from sku_err
            # Non-conflict error — log and fall through (SKU check was best-effort)
            logger.warning(f"SKU collision doc creation error (non-fatal): {sku_err}")

    # Warehouse address validation — ensure all warehouse docs exist and have complete addresses
    warehouse_ids = product_data.get(Fields.WAREHOUSE_IDS) or []
    if warehouse_ids:
        # Batch-read all warehouses in one round-trip instead of N sequential .get() calls
        warehouse_refs = [
            get_db().collection(Collections.USERS).document(user_id).collection(Collections.WAREHOUSES).document(wid)
            for wid in warehouse_ids
        ]
        warehouse_docs = {doc.id: doc for doc in get_db().get_all(warehouse_refs)}
        for wid in warehouse_ids:
            w_doc = warehouse_docs.get(wid)
            if w_doc is None or not w_doc.exists:
                raise https_fn.HttpsError("not-found", f"Warehouse '{wid}' not found. Please update your warehouse selection.")

            wh_data = w_doc.to_dict() or {}
            addr = wh_data.get("address", {})
            if not addr.get("city") or not addr.get("country"):
                raise https_fn.HttpsError(
                    "invalid-argument", f"Warehouse '{wid}' has an incomplete address (city and country are required)."
                )

            # F-89: Geocoding Bypass Prevention
            if addr.get(Fields.LATITUDE) is None or addr.get(Fields.LONGITUDE) is None:
                logger.warning(f"Warehouse {wid} (seller={user_id}) is missing geocoding data.")
                raise https_fn.HttpsError(
                    "failed-precondition",
                    f"Warehouse '{wid}' is not geocoded. Please update its address to calculate shipping costs accurately."
                )

    # Warehouse denormalization (reuses existing helper)
    ship_from = _derive_ship_from_fields(user_id, product_data)
    product_data.update(ship_from)

    # Generate product ID server-side and write to Firestore atomically
    product_ref = get_db().collection(Collections.PRODUCTS).document()
    product_id = product_ref.id
    product_data[Fields.PRODUCT_ID] = product_id

    # Validate product data through Pydantic before writing — catches invalid condition,
    # compareAtPrice, digitalType, XSS in name/description, and all field validators.
    try:
        validated = ProductCreate(**product_data)
        # Replace product_data with validated (and coerced) values; re-add server timestamps
        product_data = validated.model_dump(exclude_none=True)
        product_data[Fields.CREATED_AT] = get_server_timestamp()
        product_data[Fields.UPDATED_AT] = get_server_timestamp()
        product_data[Fields.PRODUCT_ID] = product_id
        # Server-enforced: all new products enter UNDER_REVIEW regardless of client value.
        product_data[Fields.LIFECYCLE_STATUS] = ProductLifecycleStatusValues.UNDER_REVIEW
        # SECURITY: Extract supplier data before writing to public product document.
        # Supplier fields (cost, SKU, URL, notes) must NOT be readable by buyers.
        # They live in the `supplier_private` subcollection, protected by Firestore rules.
        supplier_private_data = product_data.pop("supplier", None)
    except ValidationError as e:
        # Surface the first validation error to the client with a clear message
        first_error = e.errors()[0]
        msg = first_error.get("msg", "Invalid product data")
        logger.warning(f"create_product_atomic: Pydantic validation failed for user {user_id}: {msg}")
        if sku_collision_ref is not None:
            import contextlib
            with contextlib.suppress(Exception):
                sku_collision_ref.delete()
        raise https_fn.HttpsError("invalid-argument", msg) from e

    try:
        product_ref.set(product_data)
        # Write supplier fields to protected subcollection (Admin SDK bypasses rules).
        if supplier_private_data:
            product_ref.collection("supplier_private").document(user_id).set(supplier_private_data)
    except Exception as e:
        # Cleanup uploaded images and SKU collision doc before surfacing the error
        import contextlib
        for key in uploaded_keys:
            with contextlib.suppress(Exception):
                s3_client.delete_object(Bucket=bucket_name, Key=key)
        if sku_collision_ref is not None:
            with contextlib.suppress(Exception):
                sku_collision_ref.delete()
        logger.error(f"create_product_atomic: Firestore write failed for user {user_id}: {e}")
        raise https_fn.HttpsError("internal", "Failed to create product. Please try again.") from e

    logger.info(f"create_product_atomic: product {product_id} created by {user_id} with {len(image_urls)} image(s)")
    return create_success_response({Fields.PRODUCT_ID: product_id, "imageUrls": image_urls})


@firestore_fn.on_document_created(document="products/{productId}", **FIRESTORE_TRIGGER_OPTIONS)
def on_product_created(event: firestore_fn.Event) -> None:
    """
    Firestore trigger: Indexes product to Algolia when created.
    Also validates product data consistency and fixes known issues.
    """
    product_id = event.params[Fields.PRODUCT_ID]
    product_data = event.data.to_dict()

    if not product_data:
        logger.info(f"No data for product {product_id}")
        return

    # NOTE: Do NOT skip validation based on lifecycleStatus. All newly created
    # products (draft, under_review, etc.) must pass validation before approval.
    # Algolia indexing only happens after admin approval via admin_approve_product.

    # ── SECURITY: SERVER-SIDE VALIDATION (products written from Flutter) ──
    from utils.helpers import sanitized_text

    product_name = product_data.get(Fields.NAME, "")

    def _deactivate_with_email(reason: str, status: str = ProductLifecycleStatusValues.DRAFT) -> None:
        """Update product status and notify seller via email."""
        update: dict = {
            Fields.LIFECYCLE_STATUS: status,
            Fields.DEACTIVATION_REASON: reason,
        }
        if status == ProductLifecycleStatusValues.REJECTED:
            update[Fields.APPROVAL_REJECTION_REASON] = reason
        get_db().collection(Collections.PRODUCTS).document(product_id).update(update)
        sid = product_data.get(Fields.SELLER_ID)
        seller_email, seller_lang = _get_seller_email_and_lang(sid)
        if seller_email:
            try:
                _send_product_rejection_email(seller_email, product_name, reason, lang=seller_lang)
            except Exception as e:
                logger.error(f"Failed to send deactivation email for {product_id}: {e}")

    # CRITICAL: Check if seller is suspended — deactivate product immediately
    seller_id = product_data.get(Fields.SELLER_ID)
    if seller_id:
        seller_doc = get_db().collection(Collections.USERS).document(seller_id).get()
        if seller_doc.exists:
            seller_data = seller_doc.to_dict()
            if seller_data.get(Fields.SUSPENDED, False):
                logger.info(f"SECURITY: Product {product_id} from suspended seller {seller_id} — deactivating")
                get_db().collection(Collections.PRODUCTS).document(product_id).update(
                    {
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.DRAFT,
                        Fields.DEACTIVATION_REASON: "Seller is suspended",
                    }
                )
                return

    # CRITICAL: Enforce sellerSku uniqueness per seller
    # sellerId + sellerSku must be unique in the products collection
    seller_sku = product_data.get(Fields.SELLER_SKU)
    if seller_sku and seller_id:
        existing = (
            get_db()
            .collection(Collections.PRODUCTS)
            .where(Fields.SELLER_ID, "==", seller_id)
            .where(Fields.SELLER_SKU, "==", seller_sku)
            .where(Fields.LIFECYCLE_STATUS, "!=", ProductLifecycleStatusValues.ARCHIVED)
            .limit(2)
            .get()
        )
        # If more than one document matches (including this new one), it's a duplicate
        duplicate_ids = [doc.id for doc in existing if doc.id != product_id]
        if duplicate_ids:
            logger.warning(
                f"SECURITY: Duplicate sellerSku '{seller_sku}' for seller {seller_id} — "
                f"existing product(s): {duplicate_ids} — deactivating new product {product_id}"
            )
            _deactivate_with_email(f"Duplicate sellerSku: '{seller_sku}' already exists for this seller")
            return

    # CRITICAL: Validate price > 0 and <= 100000 CAD
    price = product_data.get(Fields.PRICE)
    if price is None or not isinstance(price, (int, float)) or price <= 0 or price > 100000:
        logger.info(f"SECURITY: Product {product_id} has invalid price ({price}) — deactivating")
        _deactivate_with_email(f"Invalid price: {price}")
        return

    # SECURITY: compareAtPrice must be at least $0.50 above price (prevents fake discount labels)
    compare_at_price = product_data.get(Fields.COMPARE_AT_PRICE)
    if compare_at_price is not None and isinstance(compare_at_price, (int, float)) and (compare_at_price <= price or (compare_at_price - price) < 0.50):
        logger.info(f"SECURITY: Product {product_id} compareAtPrice gap too small ({compare_at_price} vs {price}) — deactivating")
        _deactivate_with_email(f"compareAtPrice must be at least $0.50 above price (got gap of ${compare_at_price - price:.2f})")
        return

    # SECURITY: hasVariants=true requires at least one variant entry
    has_variants = product_data.get(Fields.HAS_VARIANTS, False)
    if has_variants and not (product_data.get(Fields.VARIANTS) or []):
        logger.info(f"SECURITY: Product {product_id} has hasVariants=true but empty variants list — deactivating")
        _deactivate_with_email("hasVariants is true but no variant entries provided")
        return

    # CRITICAL: Validate stock quantity >= 0
    stock = product_data.get(Fields.STOCK_QUANTITY, 0)
    if not isinstance(stock, (int, float)) or stock < 0:
        logger.info(f"SECURITY: Product {product_id} has invalid stock ({stock}) — deactivating")
        _deactivate_with_email(f"Invalid stock: {stock}")
        return

    # Seller address validation — verify address exists via Geoapify geocoding
    # Skip if product uses warehouse IDs (warehouses are validated at creation time)
    warehouse_ids = product_data.get(Fields.WAREHOUSE_IDS) or []
    seller_address = product_data.get(Fields.SELLER_ADDRESS) or {}
    is_digital = product_data.get(Fields.IS_DIGITAL, False)

    if not is_digital and not warehouse_ids:
        country = seller_address.get(Fields.COUNTRY) or ""
        if not country:
            logger.info(f"SECURITY: Product {product_id} has empty seller country — deactivating")
            _deactivate_with_email("Missing seller country")
            return

        # SECURITY: Validate address coordinates via Geoapify reverse geocoding
        seller_lat = seller_address.get(Fields.LATITUDE)
        seller_lon = seller_address.get(Fields.LONGITUDE)
        seller_street = seller_address.get(Fields.STREET, "")
        seller_city = seller_address.get(Fields.CITY, "")
        seller_postal = seller_address.get(Fields.POSTAL_CODE, "")

        # In dev/emulator, skip lat/lng check to allow rapid product creation without geocoding
        is_non_prod_env = CURRENT_ENV in (Environment.EMULATOR, Environment.DEV)
        if seller_lat is None or seller_lon is None:
            if is_non_prod_env:
                logger.info(f"DEV: Product {product_id} missing lat/lng — skipping Geoapify validation in dev/emulator")
            else:
                logger.info(
                    f"SECURITY: Product {product_id} missing lat/lng — address not verified via Geoapify — REJECTING"
                )
                _deactivate_with_email("Address not verified via Geoapify (missing coordinates)")
                return
        elif not is_non_prod_env:
            is_valid, error_reason = _verify_address_with_geoapify(
                product_id,
                seller_lat,
                seller_lon,
                seller_street,
                seller_city,
                seller_postal,
                country,
            )
            if not is_valid:
                logger.info(f"SECURITY: Product {product_id} failed address verification: {error_reason} — REJECTING")
                _deactivate_with_email(f"Address verification failed: {error_reason}")
                return

    # CRITICAL: Sanitize text fields to prevent stored XSS
    name = product_data.get(Fields.NAME, "")
    description = product_data.get(Fields.DESCRIPTION, "")

    # CRITICAL: Validate categoryId against allowed categories
    category_id = product_data.get(Fields.CATEGORY_ID)
    if category_id is not None and (
        not isinstance(category_id, (int, float))
        or int(category_id) < CategoryIds.MIN
        or int(category_id) > CategoryIds.MAX
    ):
        logger.info(f"SECURITY: Product {product_id} has invalid categoryId ({category_id}) — deactivating")
        _deactivate_with_email(f"Invalid categoryId: {category_id}")
        return
    # Collect all automated fixes/patches to apply in a single write (F-322: No Redundant Writes)
    internal_patches = {}

    sanitized_name = sanitized_text(name)
    sanitized_desc = sanitized_text(description)
    if sanitized_name != name:
        internal_patches[Fields.NAME] = sanitized_name
        logger.info(f"SECURITY: Sanitized XSS in product {product_id} name")
    if sanitized_desc != description:
        internal_patches[Fields.DESCRIPTION] = sanitized_desc
        logger.info(f"SECURITY: Sanitized XSS in product {product_id} description")

    # ── DATA CONSISTENCY VALIDATION ──────────────────────────────────
    # Derive priceCents from price (server-side, authoritative)
    price_val = product_data.get(Fields.PRICE)
    if isinstance(price_val, (int, float)) and price_val > 0:
        internal_patches[Fields.PRICE_CENTS] = round(price_val * 100)

    # Slug generation: assign on creation if missing (unique, URL-safe sharing URL)
    if not product_data.get(Fields.SLUG):
        product_name = product_data.get(Fields.NAME, "product")
        slug_candidate = None
        for _ in range(5):
            candidate = _generate_product_slug(product_name)
            existing = get_db().collection(Collections.PRODUCTS).where(Fields.SLUG, "==", candidate).limit(1).get()
            if not existing:
                slug_candidate = candidate
                break
        if not slug_candidate:
            # Fallback: use doc ID suffix (guaranteed unique)
            slug_candidate = f"product-{product_id[-8:]}"
        internal_patches[Fields.SLUG] = slug_candidate
        logger.info(f"Slug assigned to product {product_id}: {slug_candidate}")

    # Bug #1: Digital products MUST have freeShipping=true
    is_digital = product_data.get(Fields.IS_DIGITAL, False)
    if is_digital and not product_data.get(Fields.FREE_SHIPPING, False):
        internal_patches[Fields.FREE_SHIPPING] = True
        logger.info(f"FIX: Product {product_id} is digital but freeShipping=false → patching to true")

    # Bug #2: Local-only products should have a pickup delivery option
    is_local_only = product_data.get(Fields.IS_LOCAL_DELIVERY_ONLY, False)
    delivery_options = product_data.get(Fields.DELIVERY_OPTIONS, [])
    if is_local_only and not any(
        opt.get(Fields.TYPE) == DeliveryTypeValues.PICKUP for opt in delivery_options if isinstance(opt, dict)
    ):
        pickup_option = {
            Fields.TYPE: DeliveryTypeValues.PICKUP,
            Fields.DESCRIPTION: "Local Pickup",
            Fields.ESTIMATED_DAYS: 0,
            Fields.COST_CENTS: 0,
        }
        internal_patches[Fields.DELIVERY_OPTIONS] = [pickup_option] + delivery_options
        logger.info(f"FIX: Product {product_id} is local-only but missing pickup option → patching")

    # Bug #4: Physical products with no delivery options (and not local-only) → add standard
    if not is_digital and not is_local_only and not delivery_options:
        standard_option = {
            Fields.TYPE: DeliveryTypeValues.STANDARD,
            Fields.DESCRIPTION: "Standard Delivery",
            Fields.ESTIMATED_DAYS: 5,
            Fields.COST_CENTS: 0,
        }
        internal_patches[Fields.DELIVERY_OPTIONS] = [standard_option]
        logger.info(f"FIX: Product {product_id} has no delivery options → adding standard")

    # Derive shipFrom* fields from warehouse addresses or seller address
    seller_id = product_data.get(Fields.SELLER_ID)
    warehouse_ids = product_data.get(Fields.WAREHOUSE_IDS) or []
    # Skip derivation if shipFromCountry already set by create_product_atomic (avoid duplicate reads)
    ship_from_already_set = bool(product_data.get(Fields.SHIP_FROM_COUNTRY))
    if seller_id and not ship_from_already_set and (warehouse_ids or product_data.get(Fields.SELLER_ADDRESS)):
        try:
            ship_from = _derive_ship_from_fields(seller_id, product_data)
            if ship_from:
                internal_patches.update(ship_from)
        except Exception as e:
            logger.error(f"Failed to derive shipFrom fields for {product_id}: {e}")

    # Apply all internal patches in ONE write
    if internal_patches:
        try:
            get_db().collection(Collections.PRODUCTS).document(product_id).update(internal_patches)
            logger.info(f"Applied {len(internal_patches)} internal fixes to product {product_id}")
            # Update local copy for indexing
            product_data.update(internal_patches)
        except Exception as e:
            logger.error(f"WARNING: Failed to apply internal patches to product {product_id}: {str(e)}")

    # FOOD SAFETY: Perishable products should have local delivery or same-day option
    is_perishable = product_data.get(Fields.IS_PERISHABLE, False)

    # SECURITY FIX #6: Validate image magic bytes for uploaded product images
    # Check each image URL to ensure it's a real image (not a malicious file)
    image_urls = product_data.get(Fields.IMAGE_URLS, [])
    for img_url in image_urls:
        if isinstance(img_url, str) and img_url.startswith(BusinessRules.CDN_BASE_URL) and not validate_image_magic_bytes(img_url):
            logger.warning(f"SECURITY: Product {product_id} has invalid image — deactivating: {img_url[:80]}")
            _deactivate_with_email("Image validation failed (invalid file type)")
            return

    if is_perishable:
        delivery_options = product_data.get(Fields.DELIVERY_OPTIONS, [])
        has_local_or_same_day = (
            any(
                opt.get(Fields.TYPE)
                in (
                    DeliveryTypeValues.LOCAL_DELIVERY,
                    DeliveryTypeValues.SAME_DAY,
                    DeliveryTypeValues.PICKUP,
                )
                or opt.get(Fields.ESTIMATED_DAYS, 99) <= 1
                for opt in delivery_options
            )
            if delivery_options
            else product_data.get(Fields.IS_LOCAL_DELIVERY_ONLY, False)
        )

        if not has_local_or_same_day:
            logger.warning(f"Perishable product {product_id} rejected: no local/same-day delivery option")
            _deactivate_with_email(
                "Perishable products require local delivery, same-day delivery, or pickup option "
                "(CFIA compliance — perishables cannot be shipped with standard/express options)"
            )
            return

    # ── DIGITAL URL VALIDATION: HTTPS-only enforcement ──
    if is_digital:
        bad_urls = []
        book_source_url = product_data.get(Fields.BOOK_SOURCE_URL)
        if book_source_url and not book_source_url.startswith("https://"):
            bad_urls.append("bookSourceUrl")
        digital_builds = product_data.get(Fields.DIGITAL_BUILDS) or {}
        for platform, url in digital_builds.items():
            if url and not url.startswith("https://"):
                bad_urls.append(f"digitalBuilds.{platform}")
        if bad_urls:
            logger.warning(f"SECURITY: Product {product_id} has non-HTTPS digital URL(s): {bad_urls} — deactivating")
            reason = f"Digital download URLs must use HTTPS: {', '.join(bad_urls)}"
            _deactivate_with_email(reason, status=ProductLifecycleStatusValues.REJECTED)
            return

    # ── ADMIN APPROVAL GATE ──
    # Products are NOT indexed to Algolia until an admin explicitly approves them.
    # create_product_atomic already sets lifecycleStatus=under_review — only set it here
    # as a safety net for products that somehow arrive in draft state (e.g., older path or direct write).
    current_status = product_data.get(Fields.LIFECYCLE_STATUS)
    if current_status == ProductLifecycleStatusValues.DRAFT:
        try:
            get_db().collection(Collections.PRODUCTS).document(product_id).update(
                {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.UNDER_REVIEW}
            )
            logger.info(f"Product {product_id} advanced draft→under_review — awaiting admin approval")
        except Exception as e:
            logger.error(f"Failed to set approval status for {product_id}: {e}")
    else:
        logger.info(f"Product {product_id} already at {current_status} — no status change needed")

    # ── NOTIFY ALL ADMINS ──
    try:
        _notify_admins_new_product(product_id, product_data)
    except Exception as e:
        logger.error(f"Failed to notify admins of new product {product_id}: {e}")


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────


def _notify_admins_new_product(product_id: str, product_data: dict) -> None:
    """Email all admin users when a product is submitted for review."""

    product_name = product_data.get(Fields.NAME, "Unknown Product")
    seller_id = product_data.get(Fields.SELLER_ID, "unknown")
    is_digital = product_data.get(Fields.IS_DIGITAL, False)
    digital_type = product_data.get(Fields.DIGITAL_TYPE, "")
    price = product_data.get(Fields.PRICE, 0)
    product_type_label = f"Digital ({digital_type})" if is_digital else "Physical"

    # Escape user-controlled values before inserting into HTML to prevent email injection
    safe_product_name = _html.escape(str(product_name))
    safe_seller_id = _html.escape(str(seller_id))

    # Fetch admin users (limit to prevent unbounded reads)
    admin_docs = (
        get_db().collection(Collections.USERS).where(Fields.ROLES, "array_contains", UserRoleValues.ADMIN).limit(50).get()
    )

    subject = f"[Origna] New Product Pending Review: {safe_product_name}"
    for admin_doc in admin_docs:
        admin_data = admin_doc.to_dict() or {}
        admin_email = admin_data.get(Fields.EMAIL)
        if not admin_email:
            continue
        html = f"""
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h2 style="color: #5B30F6;">New Product Pending Review</h2>
  <table style="width:100%; border-collapse:collapse;">
    <tr><td style="padding:6px 0; color:#666; width:140px;">Product Name</td><td style="font-weight:bold;">{safe_product_name}</td></tr>
    <tr><td style="padding:6px 0; color:#666;">Product ID</td><td><code>{_html.escape(product_id)}</code></td></tr>
    <tr><td style="padding:6px 0; color:#666;">Seller ID</td><td><code>{safe_seller_id}</code></td></tr>
    <tr><td style="padding:6px 0; color:#666;">Type</td><td>{_html.escape(product_type_label)}</td></tr>
    <tr><td style="padding:6px 0; color:#666;">Price</td><td>CAD ${price:.2f}</td></tr>
  </table>
  <p style="margin-top:20px;">
    <a href="{CURRENT_ENV.get_base_url()}/admin" style="background:#5B30F6; color:#fff; padding:10px 22px; border-radius:6px; text-decoration:none; font-weight:bold;">
      Review in Admin Panel
    </a>
  </p>
  <p style="color:#999; font-size:12px; margin-top:20px;">Origna Ventures Inc. — {EmailConfig.PHYSICAL_ADDRESS}</p>
</div>"""
        from services.email_task import enqueue_email_task
        enqueue_email_task(
            to_email=admin_email,
            subject=subject,
            html_content=html,
            event_type="admin_new_product_review"
        )
        logger.info(f"Admin notification sent to {admin_email} for product {product_id}")


def _send_product_approval_email(seller_email: str, product_name: str, product_id: str, lang: str = "en") -> None:
    """Notify seller that their product has been approved and is now live. Bilingual (Bill 96)."""

    if lang == "fr":
        subject = f"✅ Votre produit est en ligne\u202f: {product_name}"
        html = f"""
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h2 style="color: #22C55E;">🎉 Votre produit est en ligne\u202f!</h2>
  <p>Bonne nouvelle\u202f! Votre produit <strong>{product_name}</strong> a été examiné et approuvé par notre équipe.</p>
  <p>Il est maintenant visible par les acheteurs sur Origna GTA.</p>
  <table style="width:100%; border-collapse:collapse; margin:16px 0;">
    <tr><td style="padding:6px 0; color:#666; width:140px;">Produit</td><td style="font-weight:bold;">{product_name}</td></tr>
    <tr><td style="padding:6px 0; color:#666;">Statut</td><td style="color:#22C55E; font-weight:bold;">✅ Approuvé et en ligne</td></tr>
  </table>
  <p>Merci de vendre sur Origna GTA\u202f!</p>
  <p style="color:#999; font-size:12px; margin-top:20px;">Origna Ventures Inc. — {EmailConfig.PHYSICAL_ADDRESS}</p>
</div>"""
    else:
        subject = f"✅ Your product is live: {product_name}"
        html = f"""
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h2 style="color: #22C55E;">🎉 Your Product is Live!</h2>
  <p>Good news! Your product <strong>{product_name}</strong> has been reviewed and approved by our team.</p>
  <p>It is now visible to buyers on Origna GTA.</p>
  <table style="width:100%; border-collapse:collapse; margin:16px 0;">
    <tr><td style="padding:6px 0; color:#666; width:140px;">Product</td><td style="font-weight:bold;">{product_name}</td></tr>
    <tr><td style="padding:6px 0; color:#666;">Status</td><td style="color:#22C55E; font-weight:bold;">✅ Approved &amp; Live</td></tr>
  </table>
  <p>Thank you for selling on Origna GTA!</p>
  <p style="color:#999; font-size:12px; margin-top:20px;">Origna Ventures Inc. — {EmailConfig.PHYSICAL_ADDRESS}</p>
</div>"""
    from services.email_task import enqueue_email_task
    enqueue_email_task(
        to_email=seller_email,
        subject=subject,
        html_content=html,
        event_type="product_approved"
    )


def _send_product_rejection_email(seller_email: str, product_name: str, reason: str, lang: str = "en") -> None:
    """Notify seller that their product has been rejected with the reason. Bilingual (Bill 96)."""

    if lang == "fr":
        subject = f"Mise à jour de l'examen de votre produit\u202f: {product_name}"
        html = f"""
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h2 style="color: #EF4444;">Mise à jour de l'examen du produit</h2>
  <p>Malheureusement, votre produit <strong>{product_name}</strong> n'a pas pu être approuvé pour le moment.</p>
  <table style="width:100%; border-collapse:collapse; margin:16px 0;">
    <tr><td style="padding:6px 0; color:#666; width:140px;">Produit</td><td style="font-weight:bold;">{product_name}</td></tr>
    <tr><td style="padding:6px 0; color:#666;">Statut</td><td style="color:#EF4444; font-weight:bold;">❌ Refusé</td></tr>
    <tr><td style="padding:6px 0; color:#666; vertical-align:top;">Raison</td><td>{reason}</td></tr>
  </table>
  <p>Vous pouvez modifier votre produit pour corriger le problème et le soumettre de nouveau.</p>
  <p>Pour toute question, contactez-nous à <a href="mailto:{EmailConfig.SUPPORT_EMAIL}">{EmailConfig.SUPPORT_EMAIL}</a>.</p>
  <p style="color:#999; font-size:12px; margin-top:20px;">Origna Ventures Inc. — {EmailConfig.PHYSICAL_ADDRESS}</p>
</div>"""
    else:
        subject = f"Product review update: {product_name}"
        html = f"""
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h2 style="color: #EF4444;">Product Review Update</h2>
  <p>Unfortunately, your product <strong>{product_name}</strong> could not be approved at this time.</p>
  <table style="width:100%; border-collapse:collapse; margin:16px 0;">
    <tr><td style="padding:6px 0; color:#666; width:140px;">Product</td><td style="font-weight:bold;">{product_name}</td></tr>
    <tr><td style="padding:6px 0; color:#666;">Status</td><td style="color:#EF4444; font-weight:bold;">❌ Rejected</td></tr>
    <tr><td style="padding:6px 0; color:#666; vertical-align:top;">Reason</td><td>{reason}</td></tr>
  </table>
  <p>You can edit your product to address the issue and resubmit it for review.</p>
  <p>If you have questions, contact us at <a href="mailto:{EmailConfig.SUPPORT_EMAIL}">{EmailConfig.SUPPORT_EMAIL}</a>.</p>
  <p style="color:#999; font-size:12px; margin-top:20px;">Origna Ventures Inc. — {EmailConfig.PHYSICAL_ADDRESS}</p>
</div>"""
    from services.email_task import enqueue_email_task
    enqueue_email_task(
        to_email=seller_email,
        subject=subject,
        html_content=html,
        event_type="product_rejected"
    )


def _notify_premium_users_new_product(product_data: dict, product_id: str) -> None:
    """Send FCM push to premium users with notifyNewProducts=True (paginated to handle >500)."""
    product_name = product_data.get(Fields.NAME, "New Product")
    images = product_data.get(Fields.IMAGE_URLS) or []
    image_url = images[0] if images else None

    notification_kwargs: dict = {
        "title": "🛍️ New Product on Origna",
        "body": f"{product_name} just went live!",
    }
    if image_url:
        notification_kwargs["image"] = image_url

    total_success = 0
    last_doc = None

    while True:
        query = (
            get_db()
            .collection(Collections.USERS)
            .where(Fields.IS_PREMIUM, "==", True)
            .where(Fields.NOTIFY_NEW_PRODUCTS, "==", True)
            .limit(500)
        )
        if last_doc:
            query = query.start_after(last_doc)

        docs = list(query.stream())
        if not docs:
            break

        user_ids = [user.id for user in docs]

        from services.push_service import send_push_notifications_batch
        success_count = send_push_notifications_batch(
            user_ids=user_ids,
            title="🛍️ New Product on Origna",
            body=f"{product_name} just went live!",
            image_url=image_url,
            data={"type": "new_product", "productId": product_id, "screen": f"/product/{product_id}"}
        )
        total_success += success_count
        last_doc = docs[-1]

    if total_success > 0:
        logger.info(f"New product FCM sent: {total_success} tokens successfully notified for product {product_id}")


# ─────────────────────────────────────────────────────────────────────────────
# ADMIN CALLABLES
# ─────────────────────────────────────────────────────────────────────────────


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_approve_product(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Admin-only: Approve a product. Sets approvalStatus=approved, isActive=True,
    and indexes it to Algolia so buyers can discover it.

    Request data:
        productId: str

    Returns:
        {success: True, message: "Product approved"}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    user_doc = get_db().collection(Collections.USERS).document(user_id).get()
    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")
    user_data = user_doc.to_dict() or {}
    if UserRoleValues.ADMIN not in user_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    product_id = req.data.get(Fields.PRODUCT_ID)
    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId required")

    product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
    product_doc = product_ref.get()
    if not product_doc.exists:
        raise https_fn.HttpsError("not-found", "Product not found")

    product_data = product_doc.to_dict() or {}

    # Validate digital URLs via HEAD request before approving
    is_digital = product_data.get(Fields.IS_DIGITAL, False)
    if is_digital:
        dead_urls = _check_digital_url_reachability(product_id, product_data)
        if dead_urls:
            seller_email, seller_lang = _get_seller_email_and_lang(product_data.get(Fields.SELLER_ID))
            reason = f"Download URL(s) unreachable: {', '.join(dead_urls)}"
            product_ref.update(
                {
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.REJECTED,
                    Fields.APPROVAL_REJECTION_REASON: reason,
                }
            )
            if seller_email:
                _send_product_rejection_email(seller_email, product_data.get(Fields.NAME, ""), reason, lang=seller_lang)
            return create_success_response(
                {"approved": False, "rejected": True, "reason": reason},
            )

    # Approve — set lifecycleStatus=active atomically
    product_ref.update(
        {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.APPROVAL_REJECTION_REASON: None,
        }
    )

    # Index to Algolia now that it's approved — re-fetch fresh doc to include all trigger patches
    algolia_warning = None
    try:
        fresh_doc = product_ref.get()
        fresh_data = fresh_doc.to_dict() or {} if fresh_doc.exists else product_data
        fresh_data[Fields.LIFECYCLE_STATUS] = ProductLifecycleStatusValues.ACTIVE
        index_product(product_id, fresh_data)
        logger.info(f"Product {product_id} indexed to Algolia after admin approval")
    except Exception as e:
        logger.error(f"Algolia indexing failed after approval for {product_id}: {e}")
        algolia_warning = "Product approved but Algolia indexing failed — product may not appear in search immediately"

    # Email seller
    seller_email, seller_lang = _get_seller_email_and_lang(product_data.get(Fields.SELLER_ID))
    if seller_email:
        try:
            _send_product_approval_email(seller_email, product_data.get(Fields.NAME, ""), product_id, lang=seller_lang)
        except Exception as e:
            logger.error(f"Failed to send approval email for {product_id}: {e}")

    logger.info(f"Admin {user_id} approved product {product_id}")

    # Audit log (non-blocking)
    with contextlib.suppress(Exception):
        get_db().collection(Collections.ADMIN_LOGS).add({
            Fields.ACTION: "product_approved",
            Fields.PRODUCT_ID: product_id,
            Fields.ADMIN_ID: user_id,
            Fields.CREATED_AT: get_server_timestamp(),
        })

    # Notify premium users who opted in for new product alerts
    try:
        _notify_premium_users_new_product(product_data, product_id)
    except Exception as e:
        logger.error(f"Failed to send new product FCM for {product_id}: {e}")

    result = {} if not algolia_warning else {"algoliaWarning": algolia_warning}
    return create_success_response(result)


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_reject_product(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Admin-only: Reject a product with a mandatory reason.
    Sets approvalStatus=rejected, isActive=False, stores reason, emails seller.

    Request data:
        productId: str
        reason: str  — mandatory rejection reason shown to seller

    Returns:
        {success: True, message: "Product rejected"}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    user_doc = get_db().collection(Collections.USERS).document(user_id).get()
    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")
    user_data = user_doc.to_dict() or {}
    if UserRoleValues.ADMIN not in user_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin role required")

    product_id = req.data.get(Fields.PRODUCT_ID)
    reason = (req.data.get("reason") or "").strip()
    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId required")
    if not reason:
        raise https_fn.HttpsError("invalid-argument", "reason required for rejection")
    if len(reason) > 1000:
        raise https_fn.HttpsError("invalid-argument", "reason must be ≤ 1000 characters")

    product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
    product_doc = product_ref.get()
    if not product_doc.exists:
        raise https_fn.HttpsError("not-found", "Product not found")

    product_data = product_doc.to_dict() or {}
    product_name = product_data.get(Fields.NAME, "")

    product_ref.update(
        {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.REJECTED,
            Fields.APPROVAL_REJECTION_REASON: reason,
        }
    )

    # Remove from Algolia if it was previously approved
    import contextlib

    with contextlib.suppress(Exception):
        algolia_delete_product(product_id)

    # Email seller
    seller_email, seller_lang = _get_seller_email_and_lang(product_data.get(Fields.SELLER_ID))
    if seller_email:
        try:
            _send_product_rejection_email(seller_email, product_name, reason, lang=seller_lang)
        except Exception as e:
            logger.error(f"Failed to send rejection email for {product_id}: {e}")

    logger.info(f"Admin {user_id} rejected product {product_id}: {reason}")

    # Audit log (non-blocking)
    with contextlib.suppress(Exception):
        get_db().collection(Collections.ADMIN_LOGS).add({
            Fields.ACTION: "product_rejected",
            Fields.PRODUCT_ID: product_id,
            Fields.ADMIN_ID: user_id,
            Fields.APPROVAL_REJECTION_REASON: reason[:500],
            Fields.CREATED_AT: get_server_timestamp(),
        })
    return create_success_response({})


def _get_seller_email(seller_id: str | None) -> str | None:
    """Fetch seller email from Firestore users collection."""
    if not seller_id:
        return None
    try:
        doc = get_db().collection(Collections.USERS).document(seller_id).get()
        return (doc.to_dict() or {}).get(Fields.EMAIL)
    except Exception:
        return None


def _get_seller_email_and_lang(seller_id: str | None) -> tuple[str | None, str]:
    """Fetch seller email and preferred language from Firestore."""
    if not seller_id:
        return None, "en"
    try:
        doc = get_db().collection(Collections.USERS).document(seller_id).get()
        data = doc.to_dict() or {}
        return data.get(Fields.EMAIL), data.get(Fields.PREFERRED_LANGUAGE, "en")
    except Exception:
        return None, "en"


def _check_digital_url_reachability(product_id: str, product_data: dict) -> list[str]:
    """HEAD-check all digital download URLs. Returns list of unreachable URL labels."""
    dead = []
    urls_to_check: list[tuple[str, str]] = []

    book_url = product_data.get(Fields.BOOK_SOURCE_URL)
    if book_url:
        urls_to_check.append(("bookSourceUrl", book_url))

    builds = product_data.get(Fields.DIGITAL_BUILDS) or {}
    for platform, url in builds.items():
        if url:
            urls_to_check.append((f"digitalBuilds.{platform}", url))

    for label, url in urls_to_check:
        try:
            resp = requests.head(url, timeout=10, allow_redirects=True, headers={"User-Agent": "OrignaBot/1.0"})
            if resp.status_code >= 400:
                logger.warning(f"Digital URL check: {label} returned {resp.status_code} for product {product_id}")
                dead.append(label)
        except requests.exceptions.RequestException as e:
            logger.warning(f"Digital URL check: {label} unreachable for product {product_id}: {e}")
            dead.append(label)

    return dead


@firestore_fn.on_document_updated(document="products/{productId}", **FIRESTORE_TRIGGER_OPTIONS)
def on_product_updated(event: firestore_fn.Event) -> None:
    """
    Firestore trigger: Updates product in Algolia when modified.
    """
    product_id = event.params[Fields.PRODUCT_ID]
    product_data = event.data.after.to_dict()
    before_data = event.data.before.to_dict() if event.data.before else {}

    if not product_data:
        logger.info(f"No data for product {product_id}")
        return

    # If product is not active, delete from index
    if product_data.get(Fields.LIFECYCLE_STATUS) != ProductLifecycleStatusValues.ACTIVE:
        try:
            algolia_delete_product(product_id)
            logger.info(f"Product {product_id} removed from Algolia (inactive)")
        except Exception as e:
            logger.error(f"Failed to delete from Algolia: {str(e)}")
        return

    # ── SKIP RE-VALIDATION FOR NON-SECURITY-RELEVANT UPDATES ──
    # When create_checkout_session or stock-restore updates stockQuantity, or when only
    # metadata fields change, we must NOT re-validate address/geocoding — this would
    # deactivate products that were already validated at creation time.
    _SKIP_VALIDATION_FIELDS = {
        Fields.STOCK_QUANTITY,
        Fields.UPDATED_AT,
        Fields.STOCK_RESTORED,
        Fields.LIFECYCLE_STATUS,
        Fields.DEACTIVATION_REASON,
        Fields.APPROVAL_REJECTION_REASON,
    }
    _address_changed = False
    if before_data:
        changed_fields = {
            key
            for key in set(list(product_data.keys()) + list(before_data.keys()))
            if product_data.get(key) != before_data.get(key)
        }

        # Detect address changes so the Geoapify re-validation block below actually runs.
        _address_changed = Fields.SELLER_ADDRESS in changed_fields

        # ── RESUBMIT: Seller edited a rejected product — reset to under_review ──
        _SELLER_EDITABLE_FIELDS = {
            Fields.NAME,
            Fields.DESCRIPTION,
            Fields.PRICE,
            Fields.IMAGE_URLS,
            Fields.CATEGORY_ID,
            Fields.KEYWORDS,
            Fields.DIGITAL_BUILDS,
            Fields.BOOK_SOURCE_URL,
            Fields.STOCK_QUANTITY,
            Fields.DIGITAL_TYPE,
        }
        before_lifecycle = before_data.get(Fields.LIFECYCLE_STATUS)
        after_lifecycle = product_data.get(Fields.LIFECYCLE_STATUS)
        if (
            before_lifecycle == ProductLifecycleStatusValues.REJECTED
            and after_lifecycle == ProductLifecycleStatusValues.REJECTED
            and changed_fields & _SELLER_EDITABLE_FIELDS
        ):
            logger.info(f"Product {product_id}: rejected product edited by seller — resetting to under_review")
            get_db().collection(Collections.PRODUCTS).document(product_id).update(
                {
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.UNDER_REVIEW,
                    Fields.APPROVAL_REJECTION_REASON: None,
                }
            )
            # Notify admins of the resubmission
            try:
                _notify_admins_new_product(product_id, product_data)
            except Exception as e:
                logger.error(f"Failed to notify admins of resubmission for {product_id}: {e}")
            return

    # If warehouseStockMap changed, re-calculate total stockQuantity
    warehouse_map_after = product_data.get(Fields.WAREHOUSE_STOCK_MAP, {})
    warehouse_map_before = before_data.get(Fields.WAREHOUSE_STOCK_MAP, {})
    if warehouse_map_after != warehouse_map_before:
        calculated_stock = sum(warehouse_map_after.values())
        if calculated_stock != product_data.get(Fields.STOCK_QUANTITY):
            logger.info(f"Product {product_id}: re-calculating stockQuantity from warehouseStockMap: {calculated_stock}")
            get_db().collection(Collections.PRODUCTS).document(product_id).update({
                Fields.STOCK_QUANTITY: calculated_stock,
                Fields.UPDATED_AT: get_server_timestamp()
            })
            # Update local dict for Algolia sync
            product_data[Fields.STOCK_QUANTITY] = calculated_stock

    if changed_fields and changed_fields.issubset(_SKIP_VALIDATION_FIELDS):
        # Guardrail: stock-only updates may come from checkout/restore paths, but
        # we still must reject invalid negative/non-numeric stock values.
        if Fields.STOCK_QUANTITY in changed_fields:
            stock = product_data.get(Fields.STOCK_QUANTITY, 0)
            if not _is_valid_stock_quantity(stock):
                logger.info(
                    f"SECURITY: Product {product_id} updated with invalid stock ({stock}) during stock-only update — deactivating"
                )
                get_db().collection(Collections.PRODUCTS).document(product_id).update(
                    {
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                    }
                )
                return

        # Non-security-relevant update — re-index if active
        is_active = product_data.get(Fields.LIFECYCLE_STATUS) == ProductLifecycleStatusValues.ACTIVE
        if is_active:
            try:
                product_data["id"] = product_id
                # Use partial update for stock/status-only changes to avoid rewriting all fields
                stock_only_fields = {Fields.STOCK_QUANTITY, Fields.LIFECYCLE_STATUS, Fields.UPDATED_AT}
                if changed_fields.issubset(stock_only_fields):
                    partial_fields = {k: product_data[k] for k in changed_fields if k in product_data and k != Fields.UPDATED_AT}
                    if partial_fields:
                        algolia_partial_update(product_id, partial_fields)
                else:
                    index_product(product_id, product_data)
            except Exception as e:
                logger.error(f"Failed to index product {product_id} after metadata update: {str(e)}")

        # TASK 07: Fire back-in-stock notifications when stockQuantity 0→>0
        try:
            _fire_back_in_stock_notifications(product_id, before_data, product_data)
        except Exception as e:
            logger.error(f"Back-in-stock notification error for {product_id}: {e}")

        # N-06: Track price history even on metadata-only updates
        try:
            _track_price_history(product_id, before_data, product_data)
        except Exception as e:
            logger.error(f"Price history tracking error for {product_id}: {e}")

        # F-276: Fire price-drop notifications if price decreased
        try:
            before_price = before_data.get(Fields.PRICE, 0)
            after_price = product_data.get(Fields.PRICE, 0)
            if after_price < before_price:
                _fire_price_drop_notifications(
                    product_id,
                    float(before_price),
                    float(after_price),
                    product_data.get(Fields.NAME, "A product you favorited")
                )
        except Exception as e:
            logger.error(f"Price drop notification error for {product_id}: {e}")

        return

    # ── SERVER-SIDE VALIDATION on update (same as on_product_created) ──
    from utils.helpers import sanitized_text

    # CRITICAL: Check if seller is suspended — deactivate product immediately
    seller_id = product_data.get(Fields.SELLER_ID)
    if seller_id:
        seller_doc = get_db().collection(Collections.USERS).document(seller_id).get()
        if seller_doc.exists:
            seller_data = seller_doc.to_dict()
            if seller_data.get(Fields.SUSPENDED, False):
                logger.info(f"SECURITY: Product {product_id} from suspended seller {seller_id} — deactivating")
                get_db().collection(Collections.PRODUCTS).document(product_id).update(
                    {
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                        Fields.DEACTIVATION_REASON: "Seller is suspended",
                    }
                )
                return

    # Validate price > 0 and <= 100000 CAD
    price = product_data.get(Fields.PRICE)
    if price is not None and (not isinstance(price, (int, float)) or price <= 0 or price > 100000):
        logger.info(f"SECURITY: Product {product_id} updated with invalid price ({price}) — deactivating")
        get_db().collection(Collections.PRODUCTS).document(product_id).update(
            {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
            }
        )
        return

    # Validate compareAtPrice > price AND gap >= $0.50 to prevent fraudulent discount display
    # Must mirror the same rule enforced in on_product_created and ProductModel.validate_compare_at_price.
    compare_at_price = product_data.get(Fields.COMPARE_AT_PRICE)
    if compare_at_price is not None and price is not None and (
        not isinstance(compare_at_price, (int, float))
        or compare_at_price <= price
        or (compare_at_price - price) < 0.50
    ):
        logger.info(
            f"SECURITY: Product {product_id} updated with invalid compareAtPrice ({compare_at_price}) vs price ({price}) — deactivating"
        )
        get_db().collection(Collections.PRODUCTS).document(product_id).update(
            {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
            }
        )
        return

    # Validate stock quantity >= 0
    stock = product_data.get(Fields.STOCK_QUANTITY, 0)
    if not _is_valid_stock_quantity(stock):
        logger.info(f"SECURITY: Product {product_id} updated with invalid stock ({stock}) — deactivating")
        get_db().collection(Collections.PRODUCTS).document(product_id).update(
            {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
            }
        )
        return

    # Seller address validation — skip for warehouse products and digital products
    warehouse_ids = product_data.get(Fields.WAREHOUSE_IDS) or []
    is_digital = product_data.get(Fields.IS_DIGITAL, False)

    if not is_digital and not warehouse_ids:
        seller_address = product_data.get(Fields.SELLER_ADDRESS, {})
        country = seller_address.get(Fields.COUNTRY) or ""
        if not country:
            logger.info(f"SECURITY: Product {product_id} updated with empty seller country — deactivating")
            get_db().collection(Collections.PRODUCTS).document(product_id).update(
                {
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                }
            )
            return

        # SECURITY: Validate address coordinates on updates — only if address actually changed
        if _address_changed:
            seller_lat = seller_address.get(Fields.LATITUDE)
            seller_lon = seller_address.get(Fields.LONGITUDE)
            seller_street = seller_address.get(Fields.STREET, "")
            seller_city = seller_address.get(Fields.CITY, "")
            seller_postal = seller_address.get(Fields.POSTAL_CODE, "")

            if seller_lat is None or seller_lon is None:
                logger.info(f"SECURITY: Product {product_id} updated with missing coordinates — REJECTING")
                get_db().collection(Collections.PRODUCTS).document(product_id).update(
                    {
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                        Fields.DEACTIVATION_REASON: "Address not verified via Geoapify (missing coordinates)",
                    }
                )
                return

            is_valid, error_reason = _verify_address_with_geoapify(
                product_id,
                seller_lat,
                seller_lon,
                seller_street,
                seller_city,
                seller_postal,
                country,
            )
            if not is_valid:
                logger.info(f"SECURITY: Product {product_id} updated with invalid address: {error_reason} — REJECTING")
                get_db().collection(Collections.PRODUCTS).document(product_id).update(
                    {
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                        Fields.DEACTIVATION_REASON: f"Address verification failed: {error_reason}",
                    }
                )
                return

    # Collect all automated fixes/patches to apply in a single write
    internal_patches = {}

    # Sanitize text fields to prevent stored XSS
    name = product_data.get(Fields.NAME, "")
    description = product_data.get(Fields.DESCRIPTION, "")
    sanitized_name = sanitized_text(name)
    sanitized_desc = sanitized_text(description)
    if sanitized_name != name:
        internal_patches[Fields.NAME] = sanitized_name
    if sanitized_desc != description:
        internal_patches[Fields.DESCRIPTION] = sanitized_desc

    # Re-derive shipFrom* fields when warehouseIds changed or shipFromCountry missing (backfill)
    update_wh_ids = product_data.get(Fields.WAREHOUSE_IDS) or []
    update_seller_id = product_data.get(Fields.SELLER_ID)
    ship_from_needed = (
        before_data
        and (
            before_data.get(Fields.WAREHOUSE_IDS) != update_wh_ids
            or not product_data.get(Fields.SHIP_FROM_COUNTRY)
        )
    )
    if ship_from_needed and update_seller_id:
        try:
            ship_from = _derive_ship_from_fields(update_seller_id, product_data)
            if ship_from:
                internal_patches.update(ship_from)
        except Exception as e:
            logger.error(f"Failed to derive shipFrom fields on update for {product_id}: {e}")

    # Apply all internal patches in ONE write
    if internal_patches:
        get_db().collection(Collections.PRODUCTS).document(product_id).update(internal_patches)
        # Update local dict so subsequent logic (notifications, indexing) sees the final data
        product_data.update(internal_patches)
        logger.info(f"Applied {len(internal_patches)} internal patches to product {product_id} in a single write")

    # N-06: Track price history on full-validation path
    try:
        _track_price_history(product_id, before_data, product_data)
    except Exception as e:
        logger.error(f"Price history tracking error for {product_id}: {e}")

    # Fire back-in-stock notifications unconditionally (covers full-validation path too)
    try:
        _fire_back_in_stock_notifications(product_id, before_data, product_data)
    except Exception as e:
        logger.error(f"Back-in-stock notification error for {product_id}: {e}")

    # STOCK-M1 FIX: Delete orphaned stock_notification subscriptions for variants that were
    # removed from the product. Without this, zombie docs accumulate unboundedly.
    try:
        _cleanup_orphaned_variant_subscriptions(product_id, before_data, product_data)
    except Exception as e:
        logger.error(f"Orphaned variant subscription cleanup error for {product_id}: {e}")

    try:
        product_data["id"] = product_id
        # Only index if product is active — prevents bypassing the approval gate
        if product_data.get(Fields.LIFECYCLE_STATUS) == ProductLifecycleStatusValues.ACTIVE:
            index_product(product_id, product_data)
            logger.info(f"Product {product_id} updated in Algolia")
        else:
            logger.info(f"Product {product_id} not indexed — lifecycleStatus={product_data.get(Fields.LIFECYCLE_STATUS)}")
    except Exception as e:
        logger.error(f"Failed to update product {product_id} in Algolia: {str(e)}")


@firestore_fn.on_document_deleted(document="products/{productId}", **FIRESTORE_TRIGGER_OPTIONS)
def on_product_deleted(event: firestore_fn.Event) -> None:
    """
    Firestore trigger: Removes product from Algolia and cleans up stock_notifications when deleted.
    """
    product_id = event.params[Fields.PRODUCT_ID]

    try:
        algolia_delete_product(product_id)
        logger.info(f"Product {product_id} deleted from Algolia")
    except Exception as e:
        logger.error(f"Failed to delete product {product_id} from Algolia: {str(e)}")

    try:
        total_cleaned = 0
        while True:
            subs = list(get_db().collection(Collections.STOCK_NOTIFICATIONS).where(Fields.PRODUCT_ID, "==", product_id).limit(200).stream())
            if not subs:
                break
            batch = get_db().batch()
            for sub in subs:
                batch.delete(sub.reference)
            batch.commit()
            total_cleaned += len(subs)
        logger.info(f"Cleaned up {total_cleaned} stock_notifications for deleted product {product_id}")
    except Exception as e:
        logger.error(f"Failed to cleanup stock_notifications for hard-deleted product {product_id}: {e}")

    # FIX: Paginate the batch loop — a single .limit(500) batch silently leaves
    # orphans when a popular product has >500 fans.
    try:
        total_fav_cleaned = 0
        while True:
            fav_refs = list(
                get_db().collection_group(Collections.FAVORITES).where(Fields.PRODUCT_ID, "==", product_id).limit(200).stream()
            )
            if not fav_refs:
                break
            fav_batch = get_db().batch()
            for fav in fav_refs:
                fav_batch.delete(fav.reference)
            fav_batch.commit()
            total_fav_cleaned += len(fav_refs)
            if len(fav_refs) < 200:
                break
        if total_fav_cleaned:
            logger.info(f"Cleaned up {total_fav_cleaned} favorites for hard-deleted product {product_id}")
    except Exception as e:
        logger.error(f"Failed to cleanup favorites for hard-deleted product {product_id}: {e}")


@https_fn.on_call(**DEFAULT_OPTIONS)
def configure_algolia(req: https_fn.CallableRequest) -> dict:
    """
    One-time setup: Configures Algolia index settings.
    Admin only.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # Check admin role
    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_data = user_doc.to_dict()

    if UserRoleValues.ADMIN not in user_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin only")

    # AUDIT FIX: Rate limit admin endpoint


    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id, action=RateLimitActions.CONFIGURE_ALGOLIA, max_requests=3, window_minutes=60
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    try:
        from services.algolia_service import configure_algolia_index

        configure_algolia_index()
        return create_success_response({"message": "Algolia index configured"})
    except Exception as e:
        logger.error(f"ERROR: Algolia configuration failed: {e}")
        raise https_fn.HttpsError("internal", "Failed to configure Algolia. Please try again.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_products_paginated(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Récupère les produits avec pagination (lazy loading).

    Request data:
        limit: Nombre de produits (défaut: 20, max: 100)
        startAfter: Document ID pour commencer après (cursor)
        category: Filtrer par catégorie (optionnel)
        sellerId: Filtrer par vendeur (optionnel)
        isActive: Filtrer par statut actif (défaut: True)
        orderBy: Champ de tri (défaut: 'createdAt')
        orderDirection: Direction du tri ('asc' ou 'desc', défaut: 'desc')

    Returns:
        {
            products: [...],
            nextCursor: 'doc_id' ou null,
            hasMore: boolean,
            totalFetched: number
        }
    """
    # AUDIT FIX: Rate limit read endpoint to prevent scraping


    _limiter = RateLimiter(get_db())

    if req.auth:
        allowed, msg = _limiter.check_rate_limit(
            identifier=req.auth.uid, action=RateLimitActions.GET_PRODUCTS, max_requests=30, window_minutes=1, fail_closed=False
        )
        if not allowed:
            raise https_fn.HttpsError("resource-exhausted", msg)
    else:
        # IP-based rate limiting for unauthenticated requests (anti-scraping)
        client_ip = (req.raw_request.headers.get("X-Forwarded-For", "") or "").split(",")[0].strip()
        if client_ip:
            allowed, msg = _limiter.check_rate_limit(
                identifier=f"ip:{client_ip}",
                action=RateLimitActions.GET_PRODUCTS,
                max_requests=15,
                window_minutes=1,
                fail_closed=False,
            )
            if not allowed:
                raise https_fn.HttpsError("resource-exhausted", msg)

    data = req.data or {}

    # Paramètres de pagination
    limit = min(data.get("limit", DEFAULT_PAGE_SIZE), MAX_PAGE_SIZE)
    start_after_id = data.get("startAfter")
    category = data.get("category")
    subcategory = data.get(Fields.SUBCATEGORY)
    seller_id = data.get(Fields.SELLER_ID)
    order_by = data.get("orderBy", Fields.CREATED_AT)
    order_direction = data.get("orderDirection", "desc")

    # SECURITY FIX #14: Force lifecycleStatus=active for public API — only admins can list non-active products
    # Prevents client-side bypass where inactive products are exposed
    is_admin = False
    if req.auth:
        user_doc = get_db().collection(Collections.USERS).document(req.auth.uid).get()
        if user_doc.exists:
            roles = user_doc.to_dict().get(Fields.ROLES, [])
            is_admin = UserRoleValues.ADMIN in roles

    # Admins can optionally filter by lifecycleStatus; public always gets active only
    lifecycle_filter = ProductLifecycleStatusValues.ACTIVE
    if is_admin:
        requested = data.get(Fields.LIFECYCLE_STATUS)
        if requested and requested in ProductLifecycleStatusValues.ALL:
            lifecycle_filter = requested

    # Validation
    if order_by not in [Fields.CREATED_AT, Fields.PRICE, Fields.RATING, Fields.RATING_COUNT, Fields.NAME]:
        raise https_fn.HttpsError("invalid-argument", "Invalid orderBy field")

    if order_direction not in ["asc", "desc"]:
        raise https_fn.HttpsError("invalid-argument", "orderDirection must be asc or desc")

    try:
        # Construction de la requête de base
        query = get_db().collection(Collections.PRODUCTS)

        # Filtres
        if lifecycle_filter is not None:
            query = query.where(Fields.LIFECYCLE_STATUS, "==", lifecycle_filter)

        if category:
            query = query.where(Fields.CATEGORY_ID, "==", category)

        if subcategory:
            query = query.where(Fields.SUBCATEGORY, "==", subcategory)

        if seller_id:
            query = query.where(Fields.SELLER_ID, "==", seller_id)

        # Tri
        if order_direction == "desc":
            query = query.order_by(order_by, direction="DESCENDING")
        else:
            query = query.order_by(order_by, direction="ASCENDING")

        # Cursor pour pagination
        if start_after_id:
            start_doc = get_db().collection(Collections.PRODUCTS).document(start_after_id).get()
            if start_doc.exists:
                query = query.start_after(start_doc)

        # Limiter avec +1 pour détecter s'il y a plus de résultats
        query = query.limit(limit + 1)

        # Exécution lazy
        docs = list(query.stream())

        # Vérifier s'il y a plus de résultats
        has_more = len(docs) > limit

        # Limiter au nombre demandé
        if has_more:
            docs = docs[:limit]

        # Formatter les produits
        # SECURITY: Strip supplier private fields — cost, SKU, URL must never reach buyers.
        _SUPPLIER_PRIVATE_KEYS = {"supplier", "supplierSku", "supplierUrl"}
        products = []
        for doc in docs:
            product_data = doc.to_dict()
            product_data["id"] = doc.id
            for _k in _SUPPLIER_PRIVATE_KEYS:
                product_data.pop(_k, None)
            products.append(product_data)

        # Cursor pour la prochaine page
        next_cursor = docs[-1].id if has_more and docs else None

        return create_success_response(
            {"products": products, "nextCursor": next_cursor, "hasMore": has_more, "totalFetched": len(products)}
        )

    except Exception as e:
        logger.error(f"ERROR: Failed to fetch products: {e}")
        raise https_fn.HttpsError("internal", "Failed to fetch products. Please try again.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_seller_products_paginated(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Récupère les produits d'un vendeur avec pagination.
    Authentification requise pour voir ses propres produits.

    Request data:
        sellerId: ID du vendeur (optionnel si connecté)
        limit: Nombre de produits (défaut: 20, max: 100)
        startAfter: Document ID cursor
        includeInactive: Inclure produits inactifs (owner/admin only)

    Returns:
        {
            products: [...],
            nextCursor: 'doc_id' ou null,
            hasMore: boolean,
            totalFetched: number
        }
    """
    # AUDIT FIX: Rate limit read endpoint to prevent scraping
    if req.auth:


        _limiter = RateLimiter(get_db())
        allowed, msg = _limiter.check_rate_limit(
            identifier=req.auth.uid, action=RateLimitActions.GET_SELLER_PRODUCTS, max_requests=30, window_minutes=1, fail_closed=False
        )
        if not allowed:
            raise https_fn.HttpsError("resource-exhausted", msg)

    data = req.data or {}

    seller_id = data.get(Fields.SELLER_ID)
    limit = min(data.get("limit", DEFAULT_PAGE_SIZE), MAX_PAGE_SIZE)
    start_after_id = data.get("startAfter")
    include_inactive = data.get("includeInactive", False)

    # Si pas de sellerId, utiliser l'utilisateur connecté
    if not seller_id:
        if not req.auth:
            raise https_fn.HttpsError("unauthenticated", "User must be authenticated")
        seller_id = req.auth.uid

    # Vérifier les permissions pour includeInactive
    if include_inactive:
        if not req.auth:
            raise https_fn.HttpsError("permission-denied", "Authentication required to view inactive products")

        user_id = req.auth.uid

        # Vérifier que c'est le propriétaire ou un admin
        if user_id != seller_id:
            user_ref = get_db().collection(Collections.USERS).document(user_id)
            user_doc = user_ref.get()

            if not user_doc.exists:
                raise https_fn.HttpsError("not-found", "User not found")

            user_data = user_doc.to_dict()
            if UserRoleValues.ADMIN not in user_data.get(Fields.ROLES, []):
                raise https_fn.HttpsError("permission-denied", "Only owner or admin can view inactive products")

    try:
        # Construction de la requête
        query = get_db().collection(Collections.PRODUCTS).where(Fields.SELLER_ID, "==", seller_id)

        # Filtrer par statut si nécessaire
        if not include_inactive:
            query = query.where(Fields.LIFECYCLE_STATUS, "==", ProductLifecycleStatusValues.ACTIVE)

        # Tri par date de création (plus récent en premier)
        query = query.order_by(Fields.CREATED_AT, direction="DESCENDING")

        # Cursor
        if start_after_id:
            start_doc = get_db().collection(Collections.PRODUCTS).document(start_after_id).get()
            if start_doc.exists:
                query = query.start_after(start_doc)

        # Limite avec +1 pour hasMore
        query = query.limit(limit + 1)

        # Exécution lazy
        docs = list(query.stream())

        has_more = len(docs) > limit
        if has_more:
            docs = docs[:limit]

        # Formatter
        products = []
        for doc in docs:
            product_data = doc.to_dict()
            product_data["id"] = doc.id
            products.append(product_data)

        next_cursor = docs[-1].id if has_more and docs else None

        return create_success_response(
            {"products": products, "nextCursor": next_cursor, "hasMore": has_more, "totalFetched": len(products)}
        )

    except Exception as e:
        logger.error(f"ERROR: Failed to fetch seller products: {e}")
        raise https_fn.HttpsError("internal", "Failed to fetch seller products. Please try again.") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_product_ratings_paginated(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Récupère les ratings d'un produit avec pagination (lazy loading).

    Request data:
        productId: ID du produit (requis)
        limit: Nombre de ratings (défaut: 10, max: 50)
        startAfter: Document ID cursor
        minRating: Filtrer par rating minimum (1-5)

    Returns:
        {
            ratings: [...],
            nextCursor: 'doc_id' ou null,
            hasMore: boolean,
            totalFetched: number
        }
    """
    # AUDIT FIX: Rate limit read endpoint to prevent scraping
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated to read ratings")

    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=req.auth.uid, action=RateLimitActions.GET_PRODUCT_RATINGS, max_requests=30, window_minutes=1, fail_closed=False
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    data = req.data or {}

    product_id = data.get(Fields.PRODUCT_ID)
    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId required")

    limit = min(data.get("limit", 10), 50)
    start_after_id = data.get("startAfter")
    min_rating = data.get("minRating")

    # Validation
    if min_rating is not None and (not isinstance(min_rating, (int, float)) or min_rating < 1 or min_rating > 5):
        raise https_fn.HttpsError("invalid-argument", "minRating must be between 1 and 5")

    try:
        # Construction de la requête
        query = get_db().collection(Collections.PRODUCT_RATINGS).where(Fields.PRODUCT_ID, "==", product_id)

        # Filtrer par rating minimum
        if min_rating is not None:
            query = query.where(Fields.RATING, ">=", min_rating)

        # Tri par date (plus récent en premier)
        query = query.order_by(Fields.CREATED_AT, direction="DESCENDING")

        # Cursor
        if start_after_id:
            start_doc = get_db().collection(Collections.PRODUCT_RATINGS).document(start_after_id).get()
            if start_doc.exists:
                query = query.start_after(start_doc)

        # Limite avec +1
        query = query.limit(limit + 1)

        # Exécution lazy
        docs = list(query.stream())

        has_more = len(docs) > limit
        if has_more:
            docs = docs[:limit]

        # Formatter avec informations utilisateur (batch read pour éviter N+1)
        ratings = []
        rating_data_list = []
        user_ids_to_fetch = set()

        # Préparer les données et collecter les user IDs uniques
        for doc in docs:
            rating_data = doc.to_dict()
            rating_data["id"] = doc.id
            rating_data_list.append(rating_data)

            user_id = rating_data.get(Fields.USER_ID)
            if user_id:
                user_ids_to_fetch.add(user_id)

        # Batch read des utilisateurs (max 10 à la fois pour getAll)
        user_data_map = {}
        if user_ids_to_fetch:
            user_ids_list = list(user_ids_to_fetch)
            # Firestore getAll limite à 10 documents
            for i in range(0, len(user_ids_list), 10):
                batch_user_ids = user_ids_list[i : i + 10]
                user_refs = [get_db().collection(Collections.USERS).document(uid) for uid in batch_user_ids]
                user_docs = get_db().get_all(user_refs)

                for user_doc in user_docs:
                    if user_doc.exists:
                        user_data_map[user_doc.id] = user_doc.to_dict()

        # Enrichir les ratings avec les données utilisateur
        for rating_data in rating_data_list:
            user_id = rating_data.get(Fields.USER_ID)
            if user_id and user_id in user_data_map:
                user_data = user_data_map[user_id]
                rating_data["userName"] = user_data.get(Fields.NAME, "Anonymous").split()[0] if user_data.get(Fields.NAME) else "Anonymous"
                # userAvatar intentionally omitted — privacy: avatars not exposed to other users

            ratings.append(rating_data)

        next_cursor = docs[-1].id if has_more and docs else None

        return create_success_response(
            {Fields.RATINGS: ratings, "nextCursor": next_cursor, "hasMore": has_more, "totalFetched": len(ratings)}
        )

    except Exception as e:
        logger.error(f"ERROR: Failed to fetch ratings: {e}")
        raise https_fn.HttpsError("internal", "Failed to fetch ratings. Please try again.") from e


# =============================================================================
# WAREHOUSE CRUD — Seller shipping location management
# =============================================================================


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_update_warehouse_commission(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Update the commission rate (in Basis Points) for a specific warehouse.
    WH-M1: Provides an audit trail for commission changes. Admin only.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required")

    # Verify admin role — Fields.ROLES is a list, not a scalar string
    user_doc = get_db().collection(Collections.USERS).document(req.auth.uid).get()
    if not user_doc.exists or UserRoleValues.ADMIN not in user_doc.to_dict().get(Fields.ROLES, []):
        raise https_fn.HttpsError("permission-denied", "Admin privileges required")

    data = req.data or {}
    seller_id = data.get(Fields.SELLER_ID)
    warehouse_id = data.get("warehouseId")  # API param key — no Firestore field constant
    new_rate_bps = data.get(Fields.COMMISSION_RATE_BPS)
    reason = data.get(Fields.REASON, "Manual adjustment")

    if not all([seller_id, warehouse_id, new_rate_bps is not None]):
        raise https_fn.HttpsError("invalid-argument", "sellerId, warehouseId, and commissionRateBps required")

    if not isinstance(new_rate_bps, int) or new_rate_bps < 0 or new_rate_bps > 10000:
        raise https_fn.HttpsError("invalid-argument", "commissionRateBps must be an integer between 0 and 10000 (100%)")

    wh_ref = get_db().collection(Collections.USERS).document(seller_id).collection(Collections.WAREHOUSES).document(warehouse_id)
    wh_snap = wh_ref.get()
    if not wh_snap.exists:
        raise https_fn.HttpsError("not-found", "Warehouse not found")

    old_rate = wh_snap.to_dict().get(Fields.COMMISSION_RATE_BPS)

    # Transactional update with audit log
    @get_firestore().transactional
    def update_commission_txn(transaction):
        # Update warehouse doc
        """Function update_commission_txn."""
        transaction.update(wh_ref, {
            Fields.COMMISSION_RATE_BPS: new_rate_bps,
            Fields.UPDATED_AT: get_server_timestamp(),
            Fields.UPDATED_BY: req.auth.uid,
        })

        # Add to audit log subcollection
        audit_ref = wh_ref.collection("commission_audit_log").document()
        transaction.set(audit_ref, {
            "oldRateBps": old_rate,
            "newRateBps": new_rate_bps,
            Fields.REASON: reason,
            "changedBy": req.auth.uid,
            Fields.CREATED_AT: get_server_timestamp(),
        })

    update_commission_txn(get_db().transaction())
    logger.info(f"Admin {req.auth.uid} updated commission for warehouse {warehouse_id} (seller {seller_id}) to {new_rate_bps} bps")

    return create_success_response({"success": True, "oldRateBps": old_rate, "newRateBps": new_rate_bps})


@https_fn.on_call(**DEFAULT_OPTIONS)
def create_warehouse(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Create a warehouse for the authenticated seller.
    Path: users/{sellerId}/warehouses/{warehouseId}
    """
    try:
        if not req.auth:
            raise https_fn.HttpsError("unauthenticated", "Authentication required")

        seller_id = req.auth.uid
        data = req.data or {}

        label = (data.get("label") or "").strip()
        if not label or len(label) > 100:
            raise https_fn.HttpsError("invalid-argument", "label must be 1–100 characters")

        w_type = data.get("type", WarehouseTypeValues.WAREHOUSE)
        if w_type not in WarehouseTypeValues.ALL:
            raise https_fn.HttpsError("invalid-argument", f"type must be one of: {WarehouseTypeValues.ALL}")

        address = data.get("address")
        if not isinstance(address, dict):
            raise https_fn.HttpsError("invalid-argument", "address must be a map")
        # FIX H-04: validate postal code format + province whitelist server-side
        _validate_warehouse_address(address)

        # Geocode warehouse address to get lat/lon
        address = _geocode_warehouse_address(address)

        is_default = bool(data.get("isDefault", False))

        # FIX M-01: Use a Firestore transaction so that clearing the existing default
        # and writing the new warehouse doc are atomic — prevents race conditions that
        # could produce two isDefault:true warehouses.
        from firebase_admin import firestore as _fs_admin

        db = get_db()
        wh_col = db.collection(Collections.USERS).document(seller_id).collection(Collections.WAREHOUSES)
        new_wh_ref = wh_col.document()
        new_wh_doc = {
            "label": label,
            "type": w_type,
            "address": address,
            "isDefault": is_default,
            "createdAt": get_server_timestamp(),
        }

        @_fs_admin.transactional
        def _txn_create(transaction, col_ref, wh_ref, doc, set_as_default):
            if set_as_default:
                existing_defaults = col_ref.where("isDefault", "==", True).stream(transaction=transaction)
                for d in existing_defaults:
                    transaction.update(d.reference, {"isDefault": False})
            transaction.set(wh_ref, doc)

        _txn_create(db.transaction(), wh_col, new_wh_ref, new_wh_doc, is_default)
        warehouse_doc = new_wh_ref

        logger.info(f"Warehouse {warehouse_doc.id} created for seller {seller_id}")
        return create_success_response({"warehouseId": warehouse_doc.id})

    except https_fn.HttpsError:
        raise
    except Exception as e:
        logger.error(f"Failed to create warehouse: {e}")
        raise https_fn.HttpsError("internal", "Failed to create warehouse") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def update_warehouse(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Update a warehouse label, type, address, or default status."""
    try:
        if not req.auth:
            raise https_fn.HttpsError("unauthenticated", "Authentication required")

        seller_id = req.auth.uid
        data = req.data or {}

        warehouse_id = data.get("warehouseId", "").strip()
        if not warehouse_id:
            raise https_fn.HttpsError("invalid-argument", "warehouseId is required")

        # Verify ownership
        wh_col = (
            get_db()
            .collection(Collections.USERS)
            .document(seller_id)
            .collection(Collections.WAREHOUSES)
        )
        wh_ref = wh_col.document(warehouse_id)
        wh_doc = wh_ref.get()
        if not wh_doc.exists:
            raise https_fn.HttpsError("not-found", "Warehouse not found")

        patches: dict = {}
        if "label" in data:
            label = data["label"].strip()
            if not label or len(label) > 100:
                raise https_fn.HttpsError("invalid-argument", "label must be 1–100 characters")
            patches["label"] = label

        if "type" in data:
            if data["type"] not in WarehouseTypeValues.ALL:
                raise https_fn.HttpsError("invalid-argument", f"type must be one of: {WarehouseTypeValues.ALL}")
            patches["type"] = data["type"]

        if "address" in data:
            if not isinstance(data["address"], dict):
                raise https_fn.HttpsError("invalid-argument", "address must be a map")
            # FIX H-04: validate postal code format + province whitelist server-side
            _validate_warehouse_address(data["address"])
            patches["address"] = _geocode_warehouse_address(data["address"])

        if "isDefault" in data:
            patches["isDefault"] = bool(data["isDefault"])

        if not patches:
            raise https_fn.HttpsError("invalid-argument", "No valid fields to update")

        from firebase_admin import firestore as _fs_admin

        @_fs_admin.transactional
        def _txn_update(transaction, wh_ref, patches, wh_col):
            if patches.get("isDefault"):
                # Clear other defaults atomically
                existing_defaults = wh_col.where("isDefault", "==", True).stream(transaction=transaction)
                for d in existing_defaults:
                    if d.id != warehouse_id:
                        transaction.update(d.reference, {"isDefault": False})
            transaction.update(wh_ref, patches)

        _txn_update(get_db().transaction(), wh_ref, patches, wh_col)
        logger.info(f"Warehouse {warehouse_id} updated for seller {seller_id}: {list(patches.keys())}")

        # SYNC FIX: If address or isDefault changed, we must update denormalized shipFrom fields in products
        if "address" in patches or "isDefault" in patches:
            logger.info(f"Syncing shipFrom fields for seller {seller_id} products due to warehouse update")
            # Find all products that might be using this warehouse (or use ANY warehouse if isDefault changed)
            prod_query = get_db().collection(Collections.PRODUCTS).where(Fields.SELLER_ID, "==", seller_id)
            # Only non-digital products that use warehouses
            while True:
                batch_docs = prod_query.where(Fields.IS_DIGITAL, "==", False).limit(200).get()
                if not batch_docs:
                    break

                sync_batch = get_db().batch()
                needs_commit = False
                for pdoc in batch_docs:
                    pdata = pdoc.to_dict() or {}
                    if not pdata.get(Fields.WAREHOUSE_IDS):
                        continue

                    # Re-derive shipFrom fields
                    ship_from = _derive_ship_from_fields(seller_id, pdata)
                    if ship_from:
                        sync_batch.update(pdoc.reference, ship_from)
                        needs_commit = True

                if needs_commit:
                    sync_batch.commit()

                if len(batch_docs) < 200:
                    break

        return create_success_response({"warehouseId": warehouse_id})

    except https_fn.HttpsError:
        raise
    except Exception as e:
        logger.error(f"Failed to update warehouse: {e}")
        raise https_fn.HttpsError("internal", "Failed to update warehouse") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def delete_warehouse(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Delete a warehouse. Blocked if any product still has stock in this warehouse
    or if in-flight orders reference it. Cleans up all associated products with pagination."""
    try:
        if not req.auth:
            raise https_fn.HttpsError("unauthenticated", "Authentication required")

        seller_id = req.auth.uid
        data = req.data or {}

        warehouse_id = data.get("warehouseId", "").strip()
        if not warehouse_id:
            raise https_fn.HttpsError("invalid-argument", "warehouseId is required")

        wh_ref = (
            get_db()
            .collection(Collections.USERS)
            .document(seller_id)
            .collection(Collections.WAREHOUSES)
            .document(warehouse_id)
        )
        wh_doc_snap = wh_ref.get()
        if not wh_doc_snap.exists:
            raise https_fn.HttpsError("not-found", "Warehouse not found")

        # GUARD 1: Block if any product has stock > 0 in this warehouse
        products_query = (
            get_db()
            .collection(Collections.PRODUCTS)
            .where(Fields.SELLER_ID, "==", seller_id)
            .where(Fields.WAREHOUSE_IDS, "array_contains", warehouse_id)
        )

        # Use stream to avoid memory/limit issues during stock check
        for pdoc in products_query.stream():
            pdata = pdoc.to_dict() or {}
            inv_doc = (
                get_db()
                .collection(Collections.PRODUCTS)
                .document(pdoc.id)
                .collection(Collections.INVENTORY_LEVELS)
                .document(warehouse_id)
                .get()
            )
            wh_stock = inv_doc.to_dict().get(Fields.AVAILABLE_QUANTITY, 0) if inv_doc.exists else 0
            flat_stock = int((pdata.get(Fields.WAREHOUSE_STOCK) or {}).get(warehouse_id, 0) or 0)
            effective_stock = max(wh_stock, flat_stock)
            if effective_stock > 0:
                raise https_fn.HttpsError(
                    "failed-precondition",
                    f"Cannot delete warehouse: product '{pdata.get(Fields.NAME, pdoc.id)}' still has {effective_stock} units in stock. Move or sell stock first.",
                )

        # GUARD 2: Block if in-flight orders reference this warehouse
        active_statuses = [
            OrderStatusValues.PENDING,
            OrderStatusValues.CONFIRMED,
            OrderStatusValues.PROCESSING,
            OrderStatusValues.SHIPPED,
        ]
        recent_orders = (
            get_db()
            .collection(Collections.ORDERS)
            .where(Fields.SELLER_IDS, "array_contains", seller_id)
            .where(Fields.ORDER_STATUS, "in", active_statuses)
            .limit(100)
            .get()
        )
        for odoc in recent_orders:
            odata = odoc.to_dict() or {}
            for oitem in odata.get(Fields.ITEMS, []):
                if oitem.get(Fields.FULFILLMENT_WAREHOUSE_ID) == warehouse_id:
                    raise https_fn.HttpsError(
                        "failed-precondition",
                        f"Cannot delete warehouse: order {odoc.id} has an in-flight item fulfilled from this warehouse.",
                    )

        # If deleting the default warehouse, atomically promote another before deleting
        was_default = (wh_doc_snap.to_dict() or {}).get(Fields.IS_DEFAULT, False)
        if was_default:
            other_warehouses = (
                get_db()
                .collection(Collections.USERS)
                .document(seller_id)
                .collection(Collections.WAREHOUSES)
                .where(Fields.IS_DEFAULT, "==", False)
                .limit(1)
                .stream()
            )
            for other_wh in other_warehouses:
                other_wh.reference.update({Fields.IS_DEFAULT: True})
                break  # promote exactly one

        # WH-H1 FIX: Clean up product associations BEFORE deleting the warehouse doc.
        # Deleting first created a window where products still referenced the deleted warehouse,
        # causing checkout failures. Products are updated first, then the warehouse is removed.

        # Cleanup Loop: Remove warehouse from products and subcollections
        from firebase_admin import firestore as _fs_admin_cleanup

        total_cleaned = 0
        while True:
            # Re-fetch batch until query returns empty (products are removed from query as we update WAREHOUSE_IDS)
            batch_docs = products_query.limit(200).get()
            if not batch_docs:
                break

            cleanup_batch = get_db().batch()
            for pdoc in batch_docs:
                p_ref = get_db().collection(Collections.PRODUCTS).document(pdoc.id)
                pdata = pdoc.to_dict() or {}

                # Update product doc
                current_wh_ids = list(pdata.get(Fields.WAREHOUSE_IDS) or [])
                if warehouse_id in current_wh_ids:
                    current_wh_ids.remove(warehouse_id)

                product_patch = {
                    Fields.WAREHOUSE_IDS: current_wh_ids,
                    f"{Fields.WAREHOUSE_STOCK}.{warehouse_id}": _fs_admin_cleanup.DELETE_FIELD,
                }

                # Optimized re-derivation inlined to avoid repeated reads in _derive_ship_from_fields
                # (We don't call the helper here for speed; since the warehouse is gone,
                # any remaining warehouses will be used for shipFrom in subsequent updates or jobs)

                # Re-derive shipFrom fields (warehouse_id is already removed from current_wh_ids above)
                pdata_for_derive = pdata.copy()
                pdata_for_derive[Fields.WAREHOUSE_IDS] = current_wh_ids
                ship_from = _derive_ship_from_fields(seller_id, pdata_for_derive)
                if ship_from:
                    product_patch.update(ship_from)

                cleanup_batch.update(p_ref, product_patch)

                # Delete inventoryLevels subdoc
                inv_ref = p_ref.collection(Collections.INVENTORY_LEVELS).document(warehouse_id)
                cleanup_batch.delete(inv_ref)

                total_cleaned += 1

            cleanup_batch.commit()
            total_cleaned += len(batch_docs)

        # WH-H1 FIX: Delete warehouse doc only after all products have been disassociated.
        wh_ref.delete()

        logger.info(f"Warehouse {warehouse_id} deleted for seller {seller_id} (cleaned {total_cleaned} products)")
        return create_success_response({"warehouseId": warehouse_id})

    except https_fn.HttpsError:
        raise
    except Exception as e:
        logger.error(f"Failed to delete warehouse: {e}")
        raise https_fn.HttpsError("internal", "Failed to delete warehouse") from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_seller_warehouses(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Return all warehouses for the authenticated seller, ordered by default first."""
    try:
        if not req.auth:
            raise https_fn.HttpsError("unauthenticated", "Authentication required")

        seller_id = req.auth.uid
        docs = (
            get_db()
            .collection(Collections.USERS)
            .document(seller_id)
            .collection(Collections.WAREHOUSES)
            .order_by("isDefault", direction="DESCENDING")
            .order_by("createdAt", direction="ASCENDING")
            .get()
        )

        warehouses = []
        for doc in docs:
            d = doc.to_dict() or {}
            d["warehouseId"] = doc.id
            # Serialize timestamps
            created_at = d.get(Fields.CREATED_AT)
            if hasattr(created_at, "isoformat"):
                d[Fields.CREATED_AT] = created_at.isoformat()
            warehouses.append(d)

        return create_success_response({"warehouses": warehouses})

    except https_fn.HttpsError:
        raise
    except Exception as e:
        logger.error(f"Failed to fetch warehouses: {e}")
        raise https_fn.HttpsError("internal", "Failed to fetch warehouses") from e


def _clear_default_warehouse(seller_id: str, exclude_id: str | None = None) -> None:
    """Remove isDefault=True from all warehouses of a seller (except exclude_id)."""
    docs = (
        get_db()
        .collection(Collections.USERS)
        .document(seller_id)
        .collection(Collections.WAREHOUSES)
        .where("isDefault", "==", True)
        .get()
    )
    for doc in docs:
        if exclude_id and doc.id == exclude_id:
            continue
        doc.reference.update({"isDefault": False})


# ================================================================
# STOCK-M1 — ORPHANED VARIANT SUBSCRIPTION CLEANUP
# ================================================================


def _cleanup_orphaned_variant_subscriptions(product_id: str, before_data: dict, after_data: dict) -> None:
    """
    STOCK-M1 FIX: When a seller removes a variant from the variants[] array, delete all
    stock_notification subscriptions for that removed variantKey. Without this, zombie docs
    accumulate unboundedly and buyers receive phantom notifications for non-existent variants.
    """
    before_variants_raw = before_data.get(Fields.VARIANTS) or []
    after_variants_raw = after_data.get(Fields.VARIANTS) or []

    # No variants in before state — nothing could have been removed
    if not before_variants_raw:
        return

    old_variant_keys: set[str] = {
        v.get(Fields.VARIANT_KEY) or v.get(Fields.VARIANT_ID, "")
        for v in before_variants_raw
        if isinstance(v, dict)
    }
    new_variant_keys: set[str] = {
        v.get(Fields.VARIANT_KEY) or v.get(Fields.VARIANT_ID, "")
        for v in after_variants_raw
        if isinstance(v, dict)
    }
    # Discard empty strings to avoid matching product-level (non-variant) subscriptions
    old_variant_keys.discard("")
    new_variant_keys.discard("")

    removed_variant_keys = old_variant_keys - new_variant_keys
    if not removed_variant_keys:
        return

    logger.info(
        f"Product {product_id}: cleaning up subscriptions for removed variants {removed_variant_keys}"
    )
    for vk in removed_variant_keys:
        subs = (
            get_db()
            .collection(Collections.STOCK_NOTIFICATIONS)
            .where(Fields.PRODUCT_ID, "==", product_id)
            .where(Fields.VARIANT_KEY, "==", vk)
            .limit(500)
            .stream()
        )
        cleanup_batch = get_db().batch()
        count = 0
        for sub in subs:
            cleanup_batch.delete(sub.reference)
            count += 1
        if count:
            cleanup_batch.commit()
            logger.info(f"Product {product_id}: deleted {count} orphaned subscriptions for variant '{vk}'")


# ================================================================
# TASK 07 — BACK-IN-STOCK NOTIFICATIONS
# ================================================================


def _fire_back_in_stock_notifications(product_id: str, before_data: dict, after_data: dict) -> None:
    """Send back-in-stock emails to subscribers when stockQuantity transitions 0 → >0."""

    before_stock = before_data.get(Fields.STOCK_QUANTITY, 0)
    after_stock = after_data.get(Fields.STOCK_QUANTITY, 0)
    has_variants = after_data.get(Fields.HAS_VARIANTS, False)

    # For non-variant products: check top-level stock transition.
    # For variant products: we fire per-variant notifications when variants change.
    if not has_variants:
        if before_stock > 0 or after_stock <= 0:
            return
        if after_data.get(Fields.LIFECYCLE_STATUS) != ProductLifecycleStatusValues.ACTIVE:
            return


    product_name = after_data.get(Fields.NAME, "A product you wanted")
    safe_name = _html.escape(product_name)

    if has_variants:
        # variants is a list[dict] — key by variantId for before/after comparison.
        before_variants_raw = before_data.get(Fields.VARIANTS) or []
        after_variants_raw = after_data.get(Fields.VARIANTS) or []
        before_by_id: dict[str, dict] = {
            v.get(Fields.VARIANT_ID, ""): v for v in before_variants_raw if isinstance(v, dict)
        }
        after_by_id: dict[str, dict] = {
            v.get(Fields.VARIANT_ID, ""): v for v in after_variants_raw if isinstance(v, dict)
        }
        restocked_keys: list[str] = [
            vk
            for vk, vdata in after_by_id.items()
            if (before_by_id.get(vk) or {}).get(Fields.STOCK_QUANTITY, 0) == 0
            and (vdata or {}).get(Fields.STOCK_QUANTITY, 0) > 0
            and vk
        ]
        if not restocked_keys:
            return
        if after_data.get(Fields.LIFECYCLE_STATUS) != ProductLifecycleStatusValues.ACTIVE:
            return

        for variant_key in restocked_keys:
            base_query = (
                get_db()
                .collection(Collections.STOCK_NOTIFICATIONS)
                .where(Fields.PRODUCT_ID, "==", product_id)
                .where(Fields.VARIANT_KEY, "==", variant_key)
                .where(Fields.NOTIFIED_AT, "==", None)
            )
            variant_url = f"https://orignagta.ca/products/{product_id}?variant={variant_key}"
            last_doc = None
            while True:
                q = base_query.limit(200)
                if last_doc:
                    q = q.start_after(last_doc)
                batch_docs = list(q.stream())
                if not batch_docs:
                    break
                uids_to_push: list[str] = []
                for sub_doc in batch_docs:
                    sub_data = sub_doc.to_dict() or {}
                    email = sub_data.get(Fields.EMAIL)
                    if not email:
                        continue
                    subject = f"🎉 Back in stock: {safe_name} — Origna"
                    html_body = f"""
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h2 style="color: #5B30F6;">It's back! 🎉</h2>
  <p><strong>{safe_name}</strong> (the variant you wanted) is back in stock on Origna.</p>
  <p style="margin-top:20px;">
    <a href="{variant_url}"
       style="background:#5B30F6; color:#fff; padding:10px 22px; border-radius:6px; text-decoration:none; font-weight:bold;">
      Shop now
    </a>
  </p>
  <p style="color:#999; font-size:12px; margin-top:24px;">
    You requested this notification. If you no longer want back-in-stock emails,
    visit your <a href="https://orignagta.ca/settings/notifications" style="color:#999;">notification settings</a>.<br>
    Origna Ventures Inc.
  </p>
</div>"""
                    try:
                        # Stamp notifiedAt BEFORE sending so Firestore-triggered retries see
                        # notifiedAt != None and skip this subscriber, preventing duplicate
                        # email/push on Cloud Function retry.
                        sub_data_uid = sub_data.get(Fields.USER_ID)
                        sub_doc.reference.update({Fields.NOTIFIED_AT: get_server_timestamp()})
                        from services.email_task import enqueue_email_task
                        enqueue_email_task(
                            to_email=email,
                            subject=subject,
                            html_content=html_body,
                            event_type="back_in_stock_alert"
                        )
                        # COLLECT UIDs for batch push
                        if sub_data_uid:
                            uids_to_push.append(sub_data_uid)

                        # FIX STOCK-C1 (CRITICAL): Delete the subscription doc after successful
                        # notification delivery.
                        sub_doc.reference.delete()
                    except Exception as e:
                        logger.error(f"Failed to send back-in-stock notification for sub {sub_doc.id}: {e}")
                        # Rollback notifiedAt so next run can retry this subscriber
                        try:
                            sub_doc.reference.update({Fields.NOTIFIED_AT: None})
                        except Exception as rollback_err:
                            logger.error(f"Failed to rollback notifiedAt for sub {sub_doc.id}: {rollback_err}")

                # PERFORMANCE: Send push notifications in batch for this page of 200 subscribers
                if uids_to_push:
                    from services.push_service import send_push_notifications_batch as _push_batch
                    _push_batch(
                        uids_to_push,
                        "Back in Stock! 🎉",
                        f"{product_name} (the variant you wanted) is back in stock.",
                        data={"type": "back_in_stock", "productId": product_id, "variantKey": variant_key},
                    )
                last_doc = batch_docs[-1]
        return

    # Non-variant product: fire for subscribers without a variantKey.
    non_variant_query = (
        get_db()
        .collection(Collections.STOCK_NOTIFICATIONS)
        .where(Fields.PRODUCT_ID, "==", product_id)
        .where(Fields.VARIANT_KEY, "==", "")
        .where(Fields.NOTIFIED_AT, "==", None)
    )
    last_doc = None
    while True:
        q = non_variant_query.limit(200)
        if last_doc:
            q = q.start_after(last_doc)
        batch_docs = list(q.stream())
        if not batch_docs:
            break
        uids_to_push: list[str] = []
        for sub_doc in batch_docs:
            sub_data = sub_doc.to_dict() or {}
            email = sub_data.get(Fields.EMAIL)
            if not email:
                continue
            subject = f"🎉 Back in stock: {safe_name} — Origna"
            html_body = f"""
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h2 style="color: #5B30F6;">It's back! 🎉</h2>
  <p><strong>{safe_name}</strong> is back in stock on Origna.</p>
  <p style="margin-top:20px;">
    <a href="https://orignagta.ca/products/{product_id}"
       style="background:#5B30F6; color:#fff; padding:10px 22px; border-radius:6px; text-decoration:none; font-weight:bold;">
      Shop now
    </a>
  </p>
  <p style="color:#999; font-size:12px; margin-top:24px;">
    You requested this notification. If you no longer want back-in-stock emails,
    visit your <a href="https://orignagta.ca/settings/notifications" style="color:#999;">notification settings</a>.<br>
    Origna Ventures Inc.
  </p>
</div>"""
            try:
                # Claim notifiedAt before send to prevent duplicate delivery on retry.
                sub_data_uid = sub_data.get(Fields.USER_ID)
                sub_doc.reference.update({Fields.NOTIFIED_AT: get_server_timestamp()})
                from services.email_task import enqueue_email_task
                enqueue_email_task(
                    to_email=email,
                    subject=subject,
                    html_content=html_body,
                    event_type="back_in_stock_alert"
                )
                # COLLECT UIDs for batch push below
                if sub_data_uid:
                    uids_to_push.append(sub_data_uid)

                # FIX STOCK-C1 (CRITICAL): Delete the subscription doc after successful
                # notification delivery.
                sub_doc.reference.delete()
            except Exception as e:
                logger.error(f"Failed to send back-in-stock notification for sub {sub_doc.id}: {e}")
                # Rollback notifiedAt so next run can retry this subscriber
                try:
                    sub_doc.reference.update({Fields.NOTIFIED_AT: None})
                except Exception as rollback_err:
                    logger.error(f"Failed to rollback notifiedAt for sub {sub_doc.id}: {rollback_err}")

        # PERFORMANCE: Send push notifications in batch for this page of 200 subscribers
        if uids_to_push:
            from services.push_service import send_push_notifications_batch as _push_batch
            _push_batch(
                uids_to_push,
                "Back in Stock! 🎉",
                f"{product_name} is back in stock.",
                data={"type": "back_in_stock", "productId": product_id},
            )
        last_doc = batch_docs[-1]


@https_fn.on_call(**DEFAULT_OPTIONS)
def subscribe_stock_notification(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    TASK 07: Subscribe to back-in-stock notification for a product.

    Request data:
        productId: Product to watch

    Idempotent — re-subscribing after being notified creates a new subscription.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # Rate limit: max 10 subscribe calls per user per minute to prevent Firestore spam
    _sub_limiter = RateLimiter(get_db())
    _sub_allowed, _sub_msg = _sub_limiter.check_rate_limit(
        identifier=user_id,
        action=RateLimitActions.SUBSCRIBE_STOCK_NOTIFICATION,
        max_requests=10,
        window_minutes=1,
        fail_closed=False,
    )
    if not _sub_allowed:
        raise https_fn.HttpsError("resource-exhausted", _sub_msg or "Too many requests. Try again later.")

    data = req.data
    product_id = data.get(Fields.PRODUCT_ID)
    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId required")

    # Reject path-traversal and invalid Firestore ID characters before any DB lookup.
    # Firestore doc IDs cannot contain '/' or be '.' / '..' per SDK rules.
    if not isinstance(product_id, str) or "/" in product_id or product_id in (".", "..") or len(product_id) > 1500:
        raise https_fn.HttpsError("invalid-argument", "Invalid productId format")

    # Validate variantKey length if provided
    variant_key_raw = data.get(Fields.VARIANT_KEY)
    if variant_key_raw and len(str(variant_key_raw)) > 500:
        raise https_fn.HttpsError("invalid-argument", "variantKey too long")

    # Verify product exists and is actually out of stock
    product_doc = get_db().collection(Collections.PRODUCTS).document(product_id).get()
    if not product_doc.exists:
        raise https_fn.HttpsError("not-found", "Product not found")
    product_data = product_doc.to_dict() or {}

    if product_data.get(Fields.SELLER_ID) == user_id:
        raise https_fn.HttpsError("permission-denied", "Sellers cannot subscribe to their own product notifications")

    # When a variantKey is provided, check that specific variant's stock instead
    # of top-level stockQuantity, which would be > 0 if other variants are in stock.
    variant_key = variant_key_raw  # already read and validated above
    has_variants = product_data.get(Fields.HAS_VARIANTS, False)
    if variant_key and has_variants:
        variants_raw = product_data.get(Fields.VARIANTS) or []
        variants_by_key = {v.get(Fields.VARIANT_ID, ""): v for v in variants_raw if isinstance(v, dict)}
        variant_data = variants_by_key.get(variant_key) or {}
        if variant_data.get(Fields.STOCK_QUANTITY, 0) > 0:
            raise https_fn.HttpsError("failed-precondition", "Variant is already in stock")
    elif variant_key and not has_variants:
        # Reject ambiguous subscription that would never fire
        raise https_fn.HttpsError("invalid-argument", "variantKey provided but product has no variants")
    elif has_variants and not variant_key:
        # Product-level sub on a variant product would be orphaned — never notified
        raise https_fn.HttpsError("invalid-argument", "This product has variants. Please specify a variantKey.")
    elif product_data.get(Fields.STOCK_QUANTITY, 0) > 0:
        raise https_fn.HttpsError("failed-precondition", "Product is already in stock")

    # Fetch buyer email
    user_doc = get_db().collection(Collections.USERS).document(user_id).get()
    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")
    user_email = (user_doc.to_dict() or {}).get(Fields.EMAIL)
    if not user_email:
        raise https_fn.HttpsError("failed-precondition", "Account has no email")

    # Idempotency: skip if active subscription already exists for same product+variant.
    # Must filter explicitly for variantKey="" (product-level) to avoid collisions.
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
    if list(existing_query.limit(1).stream()):
        return create_success_response({"subscribed": True})

    doc: dict[str, Any] = {
        Fields.PRODUCT_ID: product_id,
        Fields.USER_ID: user_id,
        Fields.EMAIL: user_email,
        Fields.NAME: product_data.get(Fields.NAME, ""),
        Fields.VARIANT_KEY: variant_key or "",
        Fields.NOTIFIED_AT: None,
        Fields.CREATED_AT: get_server_timestamp(),
    }
    get_db().collection(Collections.STOCK_NOTIFICATIONS).add(doc)
    return create_success_response({"subscribed": True})


@https_fn.on_call(**DEFAULT_OPTIONS)
def unsubscribe_stock_notification(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    TASK 07: Unsubscribe from back-in-stock notification.

    Request data:
        productId: Product to stop watching
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid

    # Rate limit: max 10 unsubscribe calls per user per minute
    _unsub_limiter = RateLimiter(get_db())
    _unsub_allowed, _unsub_msg = _unsub_limiter.check_rate_limit(
        identifier=user_id,
        action=RateLimitActions.UNSUBSCRIBE_STOCK_NOTIFICATION,
        max_requests=10,
        window_minutes=1,
        fail_closed=False,
    )
    if not _unsub_allowed:
        raise https_fn.HttpsError("resource-exhausted", _unsub_msg or "Too many requests. Try again later.")

    data = req.data
    product_id = data.get(Fields.PRODUCT_ID)
    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId required")

    variant_key = data.get(Fields.VARIANT_KEY)
    query = (
        get_db()
        .collection(Collections.STOCK_NOTIFICATIONS)
        .where(Fields.PRODUCT_ID, "==", product_id)
        .where(Fields.USER_ID, "==", user_id)
        .where(Fields.NOTIFIED_AT, "==", None)
    )
    if variant_key:
        query = query.where(Fields.VARIANT_KEY, "==", variant_key)
    else:
        # Explicit empty-string filter: only removes product-level sub, not variant-level ones
        query = query.where(Fields.VARIANT_KEY, "==", "")
    subscriptions = list(query.limit(5).stream())
    for sub in subscriptions:
        sub.reference.delete()

    return create_success_response({"unsubscribed": True})


# ================================================================
# TASK 09 — PRODUCT Q&A
# ================================================================


@https_fn.on_call(**DEFAULT_OPTIONS)
def toggle_favorite(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Atomically toggles a product in the user's favorites list.
    Increments/decrements favoriteCount on the product document.
    SRCH-M2: Provides the data needed for accurate trending scores.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required")

    user_id = req.auth.uid
    product_id = req.data.get(Fields.PRODUCT_ID)

    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId required")

    product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
    fav_ref = get_db().collection(Collections.USERS).document(user_id).collection(Collections.FAVORITES).document(product_id)

    @get_firestore().transactional
    def toggle_fav_txn(transaction):
        """Function toggle_fav_txn."""
        fav_snap = fav_ref.get(transaction=transaction)
        p_snap = product_ref.get(transaction=transaction)

        if not p_snap.exists:
            raise https_fn.HttpsError("not-found", "Product not found")

        is_favorited = fav_snap.exists

        if is_favorited:
            # Unfavorite
            transaction.delete(fav_ref)
            transaction.update(product_ref, {
                Fields.FAVORITE_COUNT: get_firestore().Increment(-1),
                Fields.UPDATED_AT: get_server_timestamp()
            })
            return False
        else:
            # Only allow favoriting active products
            p_data = p_snap.to_dict() or {}
            if p_data.get(Fields.LIFECYCLE_STATUS) != ProductLifecycleStatusValues.ACTIVE:
                raise https_fn.HttpsError("failed-precondition", "Product is not available")
            # Favorite
            transaction.set(fav_ref, {
                Fields.PRODUCT_ID: product_id,
                Fields.DATE_FAVORITED: get_server_timestamp()
            })
            transaction.update(product_ref, {
                Fields.FAVORITE_COUNT: get_firestore().Increment(1),
                Fields.UPDATED_AT: get_server_timestamp()
            })
            return True

    try:
        favorited = toggle_fav_txn(get_db().transaction())
        return create_success_response({
            "favorited": favorited,
            "message": "Product added to favorites" if favorited else "Product removed from favorites"
        })
    except Exception as e:
        if isinstance(e, https_fn.HttpsError):
            raise
        logger.error(f"toggle_favorite failed: {e}")
        raise https_fn.HttpsError("internal", str(e)) from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def ask_product_question(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    TASK 09: Buyer submits a question about a product.

    Request data:
        productId: Product ID
        question: Question text (10-500 chars)
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    # Premium gate must be enforced backend-side (authoritative subscriptions/{uid}).
    from utils.premium_check import is_premium_authoritative

    db = get_db()
    if not is_premium_authoritative(req.auth.uid, db=db):
        raise https_fn.HttpsError(
            "permission-denied",
            "Origna Premium required to ask questions. Upgrade to unlock Q&A, chat with sellers, and more.",
        )

    # S-02 FIX: Rate limit question submissions (max 5/hour per user)


    _limiter = RateLimiter(db)
    allowed, msg = _limiter.check_rate_limit(
        identifier=req.auth.uid,
        action=RateLimitActions.ASK_PRODUCT_QUESTION,
        max_requests=5,
        window_minutes=60,
        fail_closed=False,
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    # M-2 FIX: Removed redundant Firestore-count rate limit — RateLimiter service above
    # already enforces the identical 5/hour cap without an extra Firestore read.

    from utils.helpers import sanitized_text

    user_id = req.auth.uid
    data = req.data
    product_id = data.get(Fields.PRODUCT_ID)
    question_raw = data.get(Fields.QUESTION_TEXT, "")

    if not product_id or not question_raw:
        raise https_fn.HttpsError("invalid-argument", "productId and question required")

    question = sanitized_text(question_raw)[:500]
    if len(question) < 10:
        raise https_fn.HttpsError("invalid-argument", "Question must be at least 10 characters")

    product_doc = db.collection(Collections.PRODUCTS).document(product_id).get()
    if not product_doc.exists:
        raise https_fn.HttpsError("not-found", "Product not found")
    product_data = product_doc.to_dict() or {}
    # S-03 FIX: Always derive sellerId from the actual product document (prevents spoofing)
    seller_id = product_data.get(Fields.SELLER_ID)

    question_ref = db.collection(Collections.PRODUCT_QUESTIONS).document()
    question_ref.set(
        {
            Fields.QUESTION_ID: question_ref.id,
            Fields.PRODUCT_ID: product_id,
            Fields.SELLER_ID: seller_id,
            Fields.ASKER_ID: user_id,
            Fields.QUESTION_TEXT: question,
            Fields.ANSWER_TEXT: None,
            Fields.ANSWERED_AT: None,
            Fields.ANSWERED_BY: None,
            Fields.IS_ANSWERED: False,
            Fields.UPVOTES: 0,
            Fields.CREATED_AT: datetime.now(UTC),
        }
    )

    # Email seller about new question
    try:

        seller_doc = db.collection(Collections.USERS).document(seller_id).get()
        if seller_doc.exists:
            seller_email = (seller_doc.to_dict() or {}).get(Fields.EMAIL)
            if seller_email:
                product_name = product_data.get(Fields.NAME, "your product")
                safe_product_name = _html.escape(product_name)
                safe_product_id = _html.escape(str(product_id))
                subject = f"[Origna] New question on {product_name}"
                html = f"""
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h2 style="color: #5B30F6;">New buyer question</h2>
  <p>A buyer asked a question about <strong>{safe_product_name}</strong>:</p>
  <blockquote style="border-left:3px solid #5B30F6; padding-left:12px; color:#333; margin:16px 0;">
    {question}
  </blockquote>
  <p style="margin-top:20px;">
    <a href="https://orignagta.ca/seller/products/{safe_product_id}/questions"
       style="background:#5B30F6; color:#fff; padding:10px 22px; border-radius:6px; text-decoration:none; font-weight:bold;">
      Answer question
    </a>
  </p>
  <p style="color:#999; font-size:12px; margin-top:24px;">
    Answering buyer questions improves conversions and builds trust.
  </p>
</div>"""
                from services.email_task import enqueue_email_task
                enqueue_email_task(
                    to_email=seller_email,
                    subject=subject,
                    html_content=html,
                    event_type="new_product_question"
                )
    except Exception as e:
        logger.error(f"Failed to email seller about new question for product {product_id}: {e}")

    return create_success_response({Fields.QUESTION_ID: question_ref.id})


@https_fn.on_call(**DEFAULT_OPTIONS)
def answer_product_question(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    TASK 09: Seller (or admin) answers a product question.

    Request data:
        questionId: Question document ID
        answer: Answer text (10-2000 chars)
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    # FIX M-1: Rate limit answer submissions (max 30/hour per user — sellers answer many questions)
    _ans_limiter = RateLimiter(get_db())
    _allowed, _msg = _ans_limiter.check_rate_limit(
        identifier=req.auth.uid,
        action=RateLimitActions.ANSWER_PRODUCT_QUESTION,
        max_requests=30,
        window_minutes=60,
        fail_closed=False,
    )
    if not _allowed:
        raise https_fn.HttpsError("resource-exhausted", _msg)

    from utils.helpers import sanitized_text

    user_id = req.auth.uid
    token = req.auth.token or {}
    is_admin = token.get("admin") is True

    data = req.data
    question_id = data.get(Fields.QUESTION_ID)
    answer_raw = data.get(Fields.ANSWER_TEXT, "")

    if not question_id or not answer_raw:
        raise https_fn.HttpsError("invalid-argument", "questionId and answer required")

    answer = sanitized_text(answer_raw)[:2000]
    if len(answer) < 10:
        raise https_fn.HttpsError("invalid-argument", "Answer must be at least 10 characters")

    question_ref = get_db().collection(Collections.PRODUCT_QUESTIONS).document(question_id)
    question_doc = question_ref.get()
    if not question_doc.exists:
        raise https_fn.HttpsError("not-found", "Question not found")

    question_data = question_doc.to_dict() or {}
    seller_id = question_data.get(Fields.SELLER_ID)

    # Only product's seller or admin can answer
    if not is_admin and user_id != seller_id:
        raise https_fn.HttpsError("permission-denied", "Only the seller or an admin can answer this question")

    now_utc = datetime.now(UTC)
    question_ref.update(
        {
            Fields.ANSWER_TEXT: answer,
            Fields.ANSWERED_AT: now_utc,
            Fields.ANSWERED_BY: user_id,
            Fields.IS_ANSWERED: True,
        }
    )

    # Email asker about the answer
    try:

        asker_id = question_data.get(Fields.ASKER_ID)
        product_id = question_data.get(Fields.PRODUCT_ID)
        if asker_id:
            asker_doc = get_db().collection(Collections.USERS).document(asker_id).get()
            if asker_doc.exists:
                asker_email = (asker_doc.to_dict() or {}).get(Fields.EMAIL)
                product_name = ""
                if product_id:
                    pdoc = get_db().collection(Collections.PRODUCTS).document(product_id).get()
                    if pdoc.exists:
                        product_name = (pdoc.to_dict() or {}).get(Fields.NAME, "")
                if asker_email:
                    safe_pname = _html.escape(product_name) if product_name else ""
                    safe_question_text = _html.escape(question_data.get(Fields.QUESTION_TEXT, ""))
                    safe_pid = _html.escape(str(product_id)) if product_id else ""
                    subject = "[Origna] Your question was answered"
                    html = f"""
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h2 style="color: #5B30F6;">Your question was answered!</h2>
  {"<p>About <strong>" + safe_pname + "</strong>:</p>" if safe_pname else ""}
  <p style="color:#555;"><strong>Your question:</strong></p>
  <blockquote style="border-left:3px solid #5B30F6; padding-left:12px; color:#333; margin:8px 0 16px;">
    {safe_question_text}
  </blockquote>
  <p style="color:#555;"><strong>Answer:</strong></p>
  <blockquote style="border-left:3px solid #38A169; padding-left:12px; color:#333; margin:8px 0 16px;">
    {answer}
  </blockquote>
  {"<p><a href='https://orignagta.ca/products/" + safe_pid + "' style='background:#5B30F6; color:#fff; padding:10px 22px; border-radius:6px; text-decoration:none; font-weight:bold;'>View product</a></p>" if safe_pid else ""}
  <p style="color:#999; font-size:12px; margin-top:24px;">Origna Ventures Inc.</p>
</div>"""
                    from services.email_task import enqueue_email_task
                    enqueue_email_task(
                        to_email=asker_email,
                        subject=subject,
                        html_content=html,
                        event_type="product_question_answered"
                    )
    except Exception as e:
        logger.error(f"Failed to email asker about answer for question {question_id}: {e}")

    return create_success_response({"answered": True})


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_product_questions(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    TASK 09: Get paginated Q&A for a product.

    Request data:
        productId: Product ID
        limit: Max results (default 20, max 50)
        answeredOnly: If true, only return answered questions (default false)
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    data = req.data
    product_id = data.get(Fields.PRODUCT_ID)
    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId required")

    limit = min(int(data.get("limit", 20)), 50)
    answered_only = bool(data.get("answeredOnly", False))

    query = get_db().collection(Collections.PRODUCT_QUESTIONS).where(Fields.PRODUCT_ID, "==", product_id)
    if answered_only:
        query = query.where(Fields.IS_ANSWERED, "==", True)
    query = query.order_by(Fields.CREATED_AT, direction="DESCENDING").limit(limit)

    docs = list(query.stream())
    questions = []
    for doc in docs:
        d = doc.to_dict() or {}
        questions.append(
            {
                Fields.QUESTION_ID: doc.id,
                Fields.QUESTION_TEXT: d.get(Fields.QUESTION_TEXT, ""),
                Fields.ANSWER_TEXT: d.get(Fields.ANSWER_TEXT),
                Fields.ANSWERED_AT: d.get(Fields.ANSWERED_AT),
                Fields.IS_ANSWERED: d.get(Fields.IS_ANSWERED, False),
                Fields.UPVOTES: d.get(Fields.UPVOTES, 0),
                Fields.CREATED_AT: d.get(Fields.CREATED_AT),
            }
        )

    return create_success_response({"questions": questions, "total": len(questions)})


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_delete_product_question(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Moderation: Admin deletes a product question.
    QA-M1: Provides an audit trail for moderation actions.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    # Verify admin role
    is_admin = (req.auth.token or {}).get("admin") is True
    if not is_admin:
        # Fallback check if token is stale — Fields.ROLES is a list, not a scalar string
        user_doc = get_db().collection(Collections.USERS).document(req.auth.uid).get()
        if not user_doc.exists or UserRoleValues.ADMIN not in user_doc.to_dict().get(Fields.ROLES, []):
            raise https_fn.HttpsError("permission-denied", "Admin privileges required")

    data = req.data or {}
    question_id = data.get(Fields.QUESTION_ID)
    reason = data.get("reason", "Inappropriate content")

    if not question_id:
        raise https_fn.HttpsError("invalid-argument", "questionId required")

    question_ref = get_db().collection(Collections.PRODUCT_QUESTIONS).document(question_id)
    question_snap = question_ref.get()
    if not question_snap.exists:
        raise https_fn.HttpsError("not-found", "Question not found")

    question_data = question_snap.to_dict() or {}

    # Atomic delete + audit log
    @get_firestore().transactional
    def delete_question_txn(transaction):
        # 1. Audit log
        """Function delete_question_txn."""
        audit_ref = get_db().collection("admin_audit_log").document()
        transaction.set(audit_ref, {
            "action": "delete_product_question",
            "targetId": question_id,
            "targetData": question_data,
            "reason": reason,
            "adminId": req.auth.uid,
            "timestamp": get_server_timestamp()
        })
        # 2. Delete
        transaction.delete(question_ref)

    delete_question_txn(get_db().transaction())
    logger.info(f"Admin {req.auth.uid} deleted product question {question_id}. Reason: {reason}")

    return create_success_response({"success": True})


@https_fn.on_call(**DEFAULT_OPTIONS)
def admin_delete_product_rating(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Moderation: Admin deletes a product rating/review.
    Recalculates product average rating atomically.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    is_admin = (req.auth.token or {}).get("admin") is True
    if not is_admin:
        # Fallback check — Fields.ROLES is a list, not a scalar string
        user_doc = get_db().collection(Collections.USERS).document(req.auth.uid).get()
        if not user_doc.exists or UserRoleValues.ADMIN not in user_doc.to_dict().get(Fields.ROLES, []):
            raise https_fn.HttpsError("permission-denied", "Admin privileges required")

    data = req.data or {}
    rating_id = data.get("ratingId")
    reason = data.get("reason", "Inappropriate content")

    if not rating_id:
        raise https_fn.HttpsError("invalid-argument", "ratingId required")

    rating_ref = get_db().collection(Collections.PRODUCT_RATINGS).document(rating_id)
    rating_snap = rating_ref.get()
    if not rating_snap.exists:
        raise https_fn.HttpsError("not-found", "Rating not found")

    rating_data = rating_snap.to_dict() or {}
    product_id = rating_data.get(Fields.PRODUCT_ID)
    stars = rating_data.get(Fields.RATING, 0)

    if not product_id:
        raise https_fn.HttpsError("internal", "Incomplete rating data (missing productId)")

    product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)

    @get_firestore().transactional
    def delete_rating_txn(transaction):
        """Function delete_rating_txn."""
        p_snap = product_ref.get(transaction=transaction)
        if not p_snap.exists:
            # Still delete the rating even if product is gone
            pass
        else:
            p_data = p_snap.to_dict() or {}
            curr_rating = p_data.get(Fields.RATING, 0.0)
            curr_count = p_data.get(Fields.RATING_COUNT, 0)

            if curr_count > 1:
                new_count = curr_count - 1
                new_avg = ((curr_rating * curr_count) - stars) / new_count
            else:
                new_count = 0
                new_avg = 0.0

            transaction.update(product_ref, {Fields.RATING: new_avg, Fields.RATING_COUNT: new_count})

        # Audit log
        audit_ref = get_db().collection("admin_audit_log").document()
        transaction.set(audit_ref, {
            "action": "delete_product_rating",
            "targetId": rating_id,
            "targetData": rating_data,
            "reason": reason,
            "adminId": req.auth.uid,
            "timestamp": get_server_timestamp()
        })
        # Delete the rating
        transaction.delete(rating_ref)

    delete_rating_txn(get_db().transaction())
    logger.info(f"Admin {req.auth.uid} deleted product rating {rating_id}. Reason: {reason}")

    return create_success_response({"success": True})


# =============================================================================
# N-03: SELLER REPLY TO REVIEWS
# =============================================================================

@https_fn.on_call(**DEFAULT_OPTIONS)
def answer_review(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    N-03: Seller replies to a product rating.

    Request data:
        ratingId: str — product_ratings document ID
        productId: str — product document ID (used for seller verification)
        reply: str — seller reply text (max 500 chars)

    Rules:
        - Only the seller of the product may reply.
        - Reply cannot be empty.
        - Seller can only reply once (sellerReply must not already exist).
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")


    from utils.helpers import sanitized_text

    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=req.auth.uid, action=RateLimitActions.ANSWER_REVIEW, max_requests=10, window_minutes=60, fail_closed=True
    )
    if not allowed:
        raise https_fn.HttpsError("resource-exhausted", msg)

    user_id = req.auth.uid
    data = req.data
    rating_id = data.get(Fields.RATING_ID)
    product_id = data.get(Fields.PRODUCT_ID)
    reply_raw = data.get(Fields.SELLER_REPLY, "")

    if not rating_id or not product_id:
        raise https_fn.HttpsError("invalid-argument", "ratingId and productId required")
    if not reply_raw or not reply_raw.strip():
        raise https_fn.HttpsError("invalid-argument", "reply cannot be empty")

    reply = sanitized_text(reply_raw.strip())[:500]
    if len(reply) < 1:
        raise https_fn.HttpsError("invalid-argument", "reply cannot be empty after sanitization")
    if len(reply) > 500:
        raise https_fn.HttpsError("invalid-argument", "reply must be at most 500 characters")

    # Verify product exists and caller is its seller
    product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
    product_doc = product_ref.get()
    if not product_doc.exists:
        raise https_fn.HttpsError("not-found", "Product not found")
    product_data = product_doc.to_dict() or {}
    if product_data.get(Fields.SELLER_ID) != user_id:
        raise https_fn.HttpsError("permission-denied", "Only the product seller can reply to reviews")

    # Fetch the rating document
    rating_ref = get_db().collection(Collections.PRODUCT_RATINGS).document(rating_id)
    rating_doc = rating_ref.get()
    if not rating_doc.exists:
        raise https_fn.HttpsError("not-found", "Rating not found")
    rating_data = rating_doc.to_dict() or {}

    # Verify this rating belongs to this product
    if rating_data.get(Fields.PRODUCT_ID) != product_id:
        raise https_fn.HttpsError("invalid-argument", "Rating does not belong to the specified product")

    # Allow update within 24h of original reply; block after that
    existing_reply = rating_data.get(Fields.SELLER_REPLY)
    if existing_reply:
        replied_at = rating_data.get(Fields.SELLER_REPLY_AT)
        if replied_at is None:
            raise https_fn.HttpsError("already-exists", "Seller has already replied to this review")
        reply_age = datetime.now(UTC) - replied_at
        if reply_age.total_seconds() > 86400:  # 24 hours
            raise https_fn.HttpsError("already-exists", "Reply can only be edited within 24 hours")

    rating_ref.update({
        Fields.SELLER_REPLY: reply,
        Fields.SELLER_REPLY_AT: datetime.now(UTC),
    })

    return create_success_response({"replied": True})


# =============================================================================
# N-04: REVIEW HELPFULNESS VOTING
# =============================================================================

@https_fn.on_call(**DEFAULT_OPTIONS)
def vote_review_helpful(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    N-04: Vote a review as helpful (or remove vote).

    Votes are stored in `product_ratings/{ratingId}/review_votes/{userId}` to
    avoid the Firestore 1 MB document limit on an unbounded helpfulVoterIds array.

    Request data:
        ratingId: str — product_ratings document ID
        productId: str — product document ID
        helpful: bool — True = upvote, False = remove vote

    Rules:
        - User cannot vote on their own review.
        - User can only vote once per review.
        - helpful=False removes the vote (decrements helpfulCount).
        - helpfulCount never goes below 0.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data
    rating_id = data.get(Fields.RATING_ID)
    product_id = data.get(Fields.PRODUCT_ID)
    helpful = data.get("helpful")

    if not rating_id or not product_id:
        raise https_fn.HttpsError("invalid-argument", "ratingId and productId required")
    if not isinstance(helpful, bool):
        raise https_fn.HttpsError("invalid-argument", "helpful must be a boolean")

    db = get_db()
    rating_ref = db.collection(Collections.PRODUCT_RATINGS).document(rating_id)
    vote_ref = rating_ref.collection(Collections.REVIEW_VOTES).document(user_id)

    _result: dict = {}
    _error: dict = {}

    def _vote_txn(transaction):
        rating_snap = rating_ref.get(transaction=transaction)
        if not rating_snap.exists:
            _error["err"] = https_fn.HttpsError("not-found", "Rating not found")
            return

        rating_data = rating_snap.to_dict() or {}

        if rating_data.get(Fields.PRODUCT_ID) != product_id:
            _error["err"] = https_fn.HttpsError("invalid-argument", "Rating does not belong to the specified product")
            return

        # Prevent self-voting
        reviewer_uid = rating_data.get(Fields.USER_ID) or rating_data.get("userId")
        if reviewer_uid == user_id:
            _error["err"] = https_fn.HttpsError("permission-denied", "Users cannot vote on their own reviews")
            return

        # Prevent sellers from voting on their own product's reviews
        product_snap = db.collection(Collections.PRODUCTS).document(product_id).get(transaction=transaction)
        if product_snap.exists and product_snap.to_dict().get(Fields.SELLER_ID) == user_id:
            _error["err"] = https_fn.HttpsError("permission-denied", "Sellers cannot vote on reviews for their own products")
            return

        vote_snap = vote_ref.get(transaction=transaction)
        already_voted = vote_snap.exists
        current_count: int = int(rating_data.get(Fields.HELPFUL_COUNT, 0))

        if helpful:
            if already_voted:
                _error["err"] = https_fn.HttpsError("already-exists", "already-voted")
                return
            transaction.set(vote_ref, {
                "isHelpful": True,
                Fields.CREATED_AT: get_server_timestamp(),
            })
            new_count = current_count + 1
        else:
            if not already_voted:
                _error["err"] = https_fn.HttpsError("failed-precondition", "No vote to remove")
                return
            transaction.delete(vote_ref)
            new_count = max(0, current_count - 1)

        transaction.update(rating_ref, {Fields.HELPFUL_COUNT: new_count})
        _result["helpfulCount"] = new_count

    try:
        from firebase_admin import firestore as _fs_admin
        txn = db.transaction()
        _fs_admin.transactional(_vote_txn)(txn)
    except Exception as e:
        logger.error(f"vote_review_helpful transaction failed for {rating_id}: {e}")
        raise https_fn.HttpsError("internal", "Failed to record vote") from e

    if "err" in _error:
        raise _error["err"]

    return create_success_response({"helpfulCount": _result.get("helpfulCount", 0)})


# =============================================================================
# N-06: PRICE HISTORY — INTERNAL HELPER
# =============================================================================

def _track_price_history(product_id: str, before_data: dict, after_data: dict) -> None:
    """
    N-06: Append a price history entry when price or compareAtPrice changes.
    Uses ArrayUnion for the append to avoid read-modify-write race conditions.
    A separate scheduled job or trigger handles trimming to 30 entries.

    NOTE: Uses datetime.now(UTC).isoformat() — NOT get_server_timestamp() —
    because server timestamps CANNOT be nested inside ArrayUnion payloads.
    """
    from firebase_admin.firestore import ArrayUnion

    before_price = before_data.get(Fields.PRICE)
    after_price = after_data.get(Fields.PRICE)
    before_compare = before_data.get(Fields.COMPARE_AT_PRICE)
    after_compare = after_data.get(Fields.COMPARE_AT_PRICE)

    if before_price == after_price and before_compare == after_compare:
        return  # No price change — nothing to record

    new_entry = {
        Fields.PRICE: after_price,
        Fields.COMPARE_AT_PRICE: after_compare,
        "changedAt": datetime.now(UTC).isoformat(),
    }

    prod_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
    # Always use ArrayUnion — avoids race conditions from concurrent updates
    prod_ref.update({Fields.PRICE_HISTORY: ArrayUnion([new_entry])})

    logger.info(f"Price history recorded for product {product_id}: {before_price} -> {after_price}")


# =============================================================================
# N-08: BULK SELLER OPERATIONS
# =============================================================================

@https_fn.on_call(**DEFAULT_OPTIONS)
def bulk_update_products(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    N-08: Bulk update product status for a seller.

    Request data:
        productIds: list[str] — up to 50 product IDs
        action: str — one of "pause", "activate", "archive"

    Returns:
        {updated: N, skipped: M}

    Rules:
        - Caller must own ALL products (ownership verified per-product).
        - Non-owned products are skipped (not an error).
        - "activate" only succeeds if approvalStatus == "approved".
        - Enforces max 50 products per call.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data
    product_ids = data.get("productIds", [])
    action = data.get(Fields.ACTION, "")

    if not isinstance(product_ids, list) or len(product_ids) == 0:
        raise https_fn.HttpsError("invalid-argument", "productIds must be a non-empty list")
    if len(product_ids) > 50:
        raise https_fn.HttpsError("invalid-argument", "Maximum 50 products per bulk operation")

    VALID_ACTIONS = {"pause", "activate", "archive"}
    if action not in VALID_ACTIONS:
        raise https_fn.HttpsError("invalid-argument", f"action must be one of: {sorted(VALID_ACTIONS)}")

    # Deduplicate IDs (prevent duplicate operations in batch)
    product_ids = list(dict.fromkeys(product_ids))

    db = get_db()
    batch = db.batch()
    updated = 0
    skipped = 0
    activated_ids: list[str] = []

    # Fetch all product docs in a single RPC (avoid N+1 sequential gets)
    product_refs = [db.collection(Collections.PRODUCTS).document(pid) for pid in product_ids if isinstance(pid, str) and pid.strip()]
    product_snaps = db.get_all(product_refs) if product_refs else []
    snap_by_id = {snap.id: snap for snap in product_snaps}

    for pid in product_ids:
        if not isinstance(pid, str) or not pid.strip():
            skipped += 1
            continue

        prod_snap = snap_by_id.get(pid)

        if not prod_snap or not prod_snap.exists:
            skipped += 1
            continue

        prod_ref = db.collection(Collections.PRODUCTS).document(pid)
        prod_data = prod_snap.to_dict() or {}

        # Skip products not owned by caller
        if prod_data.get(Fields.SELLER_ID) != user_id:
            skipped += 1
            continue

        if action == "pause":
            batch.update(prod_ref, {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                Fields.UPDATED_AT: datetime.now(UTC),
            })
            updated += 1

        elif action == "activate":
            # Only activate from PAUSED — APPROVED → ACTIVE is admin-only (approval flow)
            current_lifecycle = prod_data.get(Fields.LIFECYCLE_STATUS)
            if current_lifecycle not in {ProductLifecycleStatusValues.PAUSED}:
                skipped += 1
                continue
            batch.update(prod_ref, {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.UPDATED_AT: datetime.now(UTC),
            })
            activated_ids.append(pid)
            updated += 1

        elif action == "archive":
            batch.update(prod_ref, {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ARCHIVED,
                Fields.UPDATED_AT: datetime.now(UTC),
            })
            updated += 1

    if updated > 0:
        batch.commit()
        logger.info(f"bulk_update_products: user={user_id} action={action} updated={updated} skipped={skipped}")

        # FIX: clean up favorites for every archived product so stale bookmark
        # entries don't accumulate. Individual delete_product already does this;
        # bulk archive must mirror it for consistency.
        if action == "archive":
            for pid in product_ids:
                prod_snap = snap_by_id.get(pid)
                if not prod_snap or not prod_snap.exists:
                    continue
                prod_data_check = prod_snap.to_dict() or {}
                if prod_data_check.get(Fields.SELLER_ID) != user_id:
                    continue
                try:
                    total_cleaned = 0
                    while True:
                        fav_refs = list(
                            db.collection_group(Collections.FAVORITES).where(Fields.PRODUCT_ID, "==", pid).limit(200).stream()
                        )
                        if not fav_refs:
                            break
                        fav_batch = db.batch()
                        for fav in fav_refs:
                            fav_batch.delete(fav.reference)
                        fav_batch.commit()
                        total_cleaned += len(fav_refs)
                        if len(fav_refs) < 200:
                            break
                    if total_cleaned:
                        logger.info(f"bulk_update_products: cleaned {total_cleaned} favorites for archived product {pid}")
                except Exception as fav_err:
                    logger.error(f"bulk_update_products: favorites cleanup failed for {pid}: {fav_err}")
        # Re-index activated products in Algolia so they appear in search
        if activated_ids:
            for act_pid in activated_ids:
                try:
                    act_snap = snap_by_id.get(act_pid)
                    if act_snap and act_snap.exists:
                        act_data = act_snap.to_dict() or {}
                        act_data[Fields.LIFECYCLE_STATUS] = ProductLifecycleStatusValues.ACTIVE
                        algolia_partial_update(act_pid, {
                            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                        })
                except Exception as alg_err:
                    logger.error(f"bulk_update_products: Algolia re-index failed for {act_pid}: {alg_err}")

    return create_success_response({"updated": updated, "skipped": skipped})


@https_fn.on_call(**DEFAULT_OPTIONS)
def deactivate_supplier_platform(req: https_fn.CallableRequest) -> dict:
    """Admin-only: bulk-pause all active products from a specific supplier platform.

    Payload: { "supplierType": "<SupplierTypeValues>" }
    Returns: { "updated": N, "skipped": M }
    """
    user_id = req.auth.uid if req.auth else None
    if not user_id:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Authentication required")

    # Admin-only gate
    user_doc = get_db().collection(Collections.USERS).document(user_id).get()
    if not user_doc.exists:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.NOT_FOUND, "User not found")
    user_data = user_doc.to_dict() or {}
    if UserRoleValues.ADMIN not in user_data.get(Fields.ROLES, []):
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.PERMISSION_DENIED, "Admin access required")

    supplier_type = (req.data or {}).get("supplierType", "").strip()
    if not supplier_type:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "supplierType is required")

    # Validate supplier type against the canonical ALL set (not vars() which includes non-string class attrs)
    if supplier_type not in SupplierTypeValues.ALL:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, f"Invalid supplierType: {supplier_type}")

    # Query active products with matching supplier.type (Firestore supports dot notation)
    products_ref = get_db().collection(Collections.PRODUCTS)
    query = (
        products_ref
        .where("supplier.type", "==", supplier_type)
        .where(Fields.LIFECYCLE_STATUS, "==", ProductLifecycleStatusValues.ACTIVE)
        .limit(500)
    )

    updated = 0
    skipped = 0
    cursor = None

    while True:
        docs = list(query.start_after(cursor).stream()) if cursor else list(query.stream())

        if not docs:
            break

        batch = get_db().batch()
        algolia_ids = []
        for doc in docs:
            data = doc.to_dict() or {}
            lifecycle = data.get(Fields.LIFECYCLE_STATUS)
            if lifecycle in {ProductLifecycleStatusValues.ARCHIVED, ProductLifecycleStatusValues.PAUSED}:
                skipped += 1
                continue
            batch.update(doc.reference, {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                Fields.UPDATED_AT: datetime.now(UTC),
            })
            algolia_ids.append(doc.id)
            updated += 1

        if algolia_ids:
            batch.commit()
            # Remove from Algolia search index
            for pid in algolia_ids:
                try:
                    algolia_partial_update(pid, {
                        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                    })
                except Exception as alg_err:
                    logger.error(f"deactivate_supplier_platform: Algolia update failed for {pid}: {alg_err}")

        # Pagination: if we got < 500 docs, we're done
        if len(docs) < 500:
            break
        cursor = docs[-1]

    logger.info(f"deactivate_supplier_platform: admin={user_id} supplier_type={supplier_type} updated={updated} skipped={skipped}")
    return create_success_response({"updated": updated, "skipped": skipped})


@https_fn.on_call(**DEFAULT_OPTIONS)
def update_product(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Update a product with server-side validation.
    
    Security:
    - Ownership check
    - Pydantic schema enforcement
    - XSS sanitization
    - Automatic re-review if digital links change (F-90)
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data
    product_id = data.get(ApiKeys.PRODUCT_ID)
    update_data = data.get(ApiKeys.PRODUCT_DATA)

    if not product_id or not update_data:
        raise https_fn.HttpsError("invalid-argument", "productId and productData are required")

    product_ref = get_db().collection(Collections.PRODUCTS).document(product_id)
    product_snap = product_ref.get()

    if not product_snap.exists:
        raise https_fn.HttpsError("not-found", "Product not found")

    existing_data = product_snap.to_dict() or {}
    if existing_data.get(Fields.SELLER_ID) != user_id:
        # Admin can also edit products? Check roles if needed.
        user_doc = get_db().collection(Collections.USERS).document(user_id).get()
        user_roles = (user_doc.to_dict() or {}).get(Fields.ROLES, [])
        if UserRoleValues.ADMIN not in user_roles:
            raise https_fn.HttpsError("permission-denied", "You do not own this product")

    # Validate update payload
    try:
        # ProductUpdate ensures partial fields are valid
        validated = ProductUpdate(**update_data)
        clean_update = validated.model_dump(exclude_unset=True)
    except ValidationError as e:
        raise https_fn.HttpsError("invalid-argument", f"Validation failed: {e.errors()[0]['msg']}") from e

    # Strip server-managed fields
    PROTECTED_FIELDS = {
        Fields.PRODUCT_ID, Fields.SELLER_ID, Fields.RATING,
        Fields.RATING_COUNT, Fields.CREATED_AT, Fields.UPDATED_AT
    }
    for field in PROTECTED_FIELDS:
        clean_update.pop(field, None)

    # N-11: Subcategory validation — must belong to the product's category
    subcategory = clean_update.get(Fields.SUBCATEGORY)
    if subcategory:
        cat_id = clean_update.get(Fields.CATEGORY_ID) or existing_data.get(Fields.CATEGORY_ID)
        if cat_id is not None:
            cat_id_int = int(cat_id)
            allowed = Subcategories.MAP.get(cat_id_int, [])
            if subcategory not in allowed:
                raise https_fn.HttpsError(
                    "invalid-argument",
                    f"Subcategory '{subcategory}' is not valid for category {cat_id_int}",
                )

    # F-90: Re-trigger UNDER_REVIEW if sensitive digital fields change
    SENSITIVE_FIELDS = {Fields.DIGITAL_BUILDS, Fields.BOOK_SOURCE_URL, Fields.IS_DIGITAL}
    has_sensitive_change = any(field in clean_update for field in SENSITIVE_FIELDS)

    if has_sensitive_change:
        # Logic: if digital links are swapped after approval, product must be re-vetted
        current_status = existing_data.get(Fields.LIFECYCLE_STATUS)
        if current_status in {ProductLifecycleStatusValues.ACTIVE, ProductLifecycleStatusValues.APPROVED}:
            clean_update[Fields.LIFECYCLE_STATUS] = ProductLifecycleStatusValues.UNDER_REVIEW
            logger.info(f"Product {product_id} returned to UNDER_REVIEW due to digital link update")

    # Handle videoUrl replacement/deletion
    if Fields.VIDEO_URL in clean_update:
        new_video_url = clean_update.get(Fields.VIDEO_URL)
        old_video_url = existing_data.get(Fields.VIDEO_URL)

        # Validate new origin if present
        if new_video_url and not str(new_video_url).startswith(CDN_BASE_URL):
            raise https_fn.HttpsError("invalid-argument", "Invalid video URL origin")

        # Delete old video from R2 if changed or removed
        if old_video_url and old_video_url != new_video_url:
            old_key = old_video_url.replace(f"{CDN_BASE_URL}/", "")
            s3_client = _get_cached_s3_client()
            import contextlib
            with contextlib.suppress(Exception):
                s3_client.delete_object(Bucket=R2Config.BUCKET_NAME, Key=old_key)

    clean_update[Fields.UPDATED_AT] = get_server_timestamp()

    # SECURITY: Extract supplier data before updating the public product document.
    # Supplier fields must live in supplier_private subcollection, not the public doc.
    supplier_update = clean_update.pop("supplier", None)

    # Commit to Firestore
    product_ref.update(clean_update)

    # Update supplier private subcollection if seller is updating supplier info.
    if supplier_update:
        product_ref.collection("supplier_private").document(user_id).set(
            supplier_update, merge=True
        )

    return create_success_response({"updated": True})


def _fire_price_drop_notifications(product_id: str, before_price: float, after_price: float, product_name: str) -> None:
    """F-276: Notify users who have favorited a product when its price drops by >= 10%."""
    if before_price <= 0 or after_price >= before_price:
        return

    drop_percent = (before_price - after_price) / before_price
    if drop_percent < 0.10: # Only notify for drops of 10% or more to avoid spam
        return

    logger.info(f"Price drop detected for {product_id} ({product_name}): {before_price} -> {after_price} (-{drop_percent*100:.1f}%)")

    # Find ALL users who have this product in their favorites using cursor pagination.
    # Requires composite index: favorites(productId ASC, dateFavorited ASC) — COLLECTION_GROUP.
    # See firestore.indexes.json for the index definition.
    _PAGE_SIZE = 500
    uids_to_push: list[str] = []
    last_fav_doc = None
    base_query = (
        get_db()
        .collection_group(Collections.FAVORITES)
        .where(Fields.PRODUCT_ID, "==", product_id)
        .order_by(Fields.DATE_FAVORITED)
        .limit(_PAGE_SIZE)
    )
    while True:
        page_query = base_query if last_fav_doc is None else base_query.start_after(last_fav_doc)
        page = list(page_query.stream())
        for fav_doc in page:
            uids_to_push.append(fav_doc.reference.parent.parent.id)
        if len(page) < _PAGE_SIZE:
            break
        last_fav_doc = page[-1]

    if uids_to_push:
        from services.push_service import send_push_notifications_batch
        total_sent = send_push_notifications_batch(
            uids_to_push,
            "Price Drop Alert! 📉",
            f"Great news! '{product_name}' just dropped from ${before_price:.2f} to ${after_price:.2f}.",
            data={"type": "price_drop", "productId": product_id}
        )
        logger.info(f"Sent price drop notifications to {total_sent} users for {product_id}")
