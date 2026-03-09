"""Seed minimal DEV data for integration tests.

Ensures the admin user has:
- at least one favorite (users/{uid}/favorites/{productId})
- at least one order (orders/{orderId})

Idempotent: safe to run multiple times.

This script is intended for the DEV Firebase project used by Flutter web
integration tests (no emulators).

Credentials:
- Uses GOOGLE_APPLICATION_CREDENTIALS if set
- Otherwise looks for ../serviceAccountKey.json relative to this file
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import UTC, datetime
from pathlib import Path

_FUNCTIONS_DIR = Path(__file__).resolve().parent.parent
if str(_FUNCTIONS_DIR) not in sys.path:
    sys.path.insert(0, str(_FUNCTIONS_DIR))

import firebase_admin  # noqa: E402
from firebase_admin import auth, credentials, firestore  # noqa: E402

from schema_constants import (  # noqa: E402
    BusinessRules,
    CategoryIds,
    Collections,
    DeliveryStatusValues,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
    ProductLifecycleStatusValues,
    UserRoleValues,
)


def _ensure_firebase_initialized() -> None:
    if firebase_admin._apps:
        return

    expected_project_id = os.environ.get("ORIGNA_SEED_PROJECT_ID", "orignagta-dev").strip()

    # Prefer explicit credential path if provided; otherwise try repo-local key.
    cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not cred_path:
        candidate = (Path(__file__).resolve().parent.parent / "serviceAccountKey.json").resolve()
        if candidate.exists():
            cred_path = str(candidate)
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = cred_path

    if cred_path and Path(cred_path).exists():
        with open(cred_path) as f:
            raw = f.read()
        try:
            project_id = json.loads(raw).get("project_id")
        except Exception:
            project_id = None

        if project_id and project_id != expected_project_id:
            raise SystemExit(
                f"Refusing to seed: service account project_id={project_id!r} "
                f"does not match expected {expected_project_id!r}. "
                "Set GOOGLE_APPLICATION_CREDENTIALS to a DEV key or override ORIGNA_SEED_PROJECT_ID explicitly."
            )

        firebase_admin.initialize_app(credentials.Certificate(cred_path))
        return

    # Fall back to application default credentials (may work on CI/GCP).
    firebase_admin.initialize_app()


def _now_utc() -> datetime:
    return datetime.now(UTC)


def _seed_user_profile(db: firestore.Client, *, user_uid: str, user_email: str) -> None:
    """Ensure user profile exists with admin AND seller roles for testing."""
    user_ref = db.collection(Collections.USERS).document(user_uid)

    # Check if profile already exists
    existing = user_ref.get()

    if existing.exists:
        # User exists - ensure they have admin AND seller roles
        user_data = existing.to_dict() or {}
        current_roles = user_data.get(Fields.ROLES, [])

        # Add missing roles
        updated_roles = list(set(current_roles + [UserRoleValues.ADMIN, UserRoleValues.SELLER]))

        if set(updated_roles) != set(current_roles):
            user_ref.update({Fields.ROLES: updated_roles})
            print(f"✅ Updated roles for {user_email}: {updated_roles}")
    else:
        # User doesn't exist - create with admin AND seller roles
        user_data = {
            Fields.UID: user_uid,
            Fields.EMAIL: user_email,
            Fields.NAME: "Test Admin User",
            Fields.ROLES: [UserRoleValues.ADMIN, UserRoleValues.SELLER],
            Fields.CREATED_AT: _now_utc(),
            Fields.STRIPE_ACCOUNT_ID: f"test_acct_{user_uid[:12]}",
            Fields.CHARGES_ENABLED: True,
            Fields.PAYOUTS_ENABLED: True,
        }
        user_ref.set(user_data)
        print(f"✅ Created user profile for {user_email} with admin + seller roles")


def _seed_product(db: firestore.Client, *, seller_uid: str) -> str:
    # Keep deterministic IDs for idempotency.
    product_id = f"seed_admin_{seller_uid[:12]}_product"
    product_ref = db.collection(Collections.PRODUCTS).document(product_id)

    # If it already exists, still ensure required fields are present (merge).
    # This keeps the seed idempotent while allowing schema evolution.

    address = {
        Fields.STREET: "136 Shaver Ave N",
        Fields.CITY: "Toronto",
        Fields.STATE: "ON",
        Fields.POSTAL_CODE: "M9B 4N8",
        Fields.COUNTRY: "Canada",
    }

    product_doc = {
        Fields.NAME: "Seed Product (Admin)",
        Fields.PRICE: 19.99,
        Fields.DESCRIPTION: "Seeded product for DEV integration tests.",
        Fields.IMAGE_URLS: ["https://example.com/seed-product.jpg"],
        Fields.SELLER_ID: seller_uid,
        Fields.SELLER_ADDRESS: address,
        Fields.CATEGORY_ID: CategoryIds.ELECTRONICS,
        Fields.STOCK_QUANTITY: 25,
        Fields.RATING: 0.0,
        Fields.RATING_COUNT: 0,
        Fields.CREATED_AT: _now_utc(),
        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
    }

    product_ref.set(product_doc, merge=True)
    return product_id


def _seed_favorite(db: firestore.Client, *, user_uid: str, product_id: str) -> None:
    fav_ref = db.collection(Collections.USERS).document(user_uid).collection(Collections.FAVORITES).document(product_id)

    fav_ref.set(
        {
            Fields.PRODUCT_ID: product_id,
            Fields.DATE_FAVORITED: _now_utc(),
        },
        merge=True,
    )


def _seed_order(db: firestore.Client, *, user_uid: str, user_email: str, product_id: str) -> str:
    order_id = f"seed_admin_{user_uid[:12]}_order"
    order_ref = db.collection(Collections.ORDERS).document(order_id)

    # If it already exists, still ensure required fields are present (merge).

    product_snap = db.collection(Collections.PRODUCTS).document(product_id).get()
    product = product_snap.to_dict() if product_snap.exists else {}

    seller_address = product.get(Fields.SELLER_ADDRESS) or {
        Fields.STREET: "136 Shaver Ave N",
        Fields.CITY: "Toronto",
        Fields.STATE: "ON",
        Fields.POSTAL_CODE: "M9B 4N8",
        Fields.COUNTRY: "Canada",
    }

    item_price = float(product.get(Fields.PRICE) or 19.99)
    quantity = 1
    subtotal_cents = int(round(item_price * 100)) * quantity

    order_item = {
        Fields.PRODUCT_ID: product_id,
        Fields.NAME: product.get(Fields.NAME) or "Seed Product (Admin)",
        Fields.DESCRIPTION: product.get(Fields.DESCRIPTION) or "Seeded product for DEV integration tests.",
        Fields.PRICE: item_price,
        Fields.QUANTITY: quantity,
        Fields.IMAGE_URLS: product.get(Fields.IMAGE_URLS) or ["https://example.com/seed-product.jpg"],
        Fields.SELLER_ID: product.get(Fields.SELLER_ID) or user_uid,
        Fields.SELLER_ADDRESS: seller_address,
        Fields.STATUS: DeliveryStatusValues.PENDING,
    }

    shipping_address = {
        Fields.STREET: "136 Shaver Ave N",
        Fields.CITY: "Toronto",
        Fields.STATE: "ON",
        Fields.POSTAL_CODE: "M9B 4N8",
        Fields.COUNTRY: "Canada",
    }

    seller_id = order_item[Fields.SELLER_ID]

    order_doc = {
        Fields.ORDER_ID: order_id,
        Fields.USER_ID: user_uid,
        Fields.CUSTOMER_ID: f"seed_customer_{user_uid[:12]}",
        Fields.CUSTOMER_EMAIL: user_email,
        Fields.ITEMS: [order_item],
        Fields.SELLER_IDS: [seller_id],
        Fields.SUBTOTAL_CENTS: subtotal_cents,
        Fields.SHIPPING_COST_CENTS: 0,
        Fields.TAX_AMOUNT_CENTS: 0,
        Fields.TOTAL_AMOUNT_CENTS: subtotal_cents,
        Fields.TAXES: {"GST": 0.0, "PST": 0.0, "HST": 0.0, "QST": 0.0},
        Fields.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
        Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
        Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
        Fields.STRIPE_SESSION_ID: f"seed_session_{order_id}",
        Fields.CAPTURED_AT: _now_utc(),
        Fields.AUTO_CAPTURED: True,
        Fields.CONFIRMED_BY_CLIENT: True,
        Fields.CONFIRMED_AT: _now_utc(),
        Fields.SHIPPING_ADDRESS: shipping_address,
        Fields.CREATED_AT: _now_utc(),
    }

    order_ref.set(order_doc, merge=True)
    return order_id


def main() -> int:
    """Function main."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--admin-email",
        default=os.environ.get("TEST_ADMIN_EMAIL", ""),
        help="Admin email to lookup (defaults to TEST_ADMIN_EMAIL env var)",
    )
    args = parser.parse_args()

    admin_email = (args.admin_email or "").strip()
    if not admin_email:
        raise SystemExit("Missing --admin-email (or TEST_ADMIN_EMAIL env var).")

    _ensure_firebase_initialized()
    db = firestore.client()

    user = auth.get_user_by_email(admin_email)
    admin_uid = user.uid

    # Seed user profile with admin + seller roles
    _seed_user_profile(db, user_uid=admin_uid, user_email=admin_email)

    product_id = _seed_product(db, seller_uid=admin_uid)
    _seed_favorite(db, user_uid=admin_uid, product_id=product_id)
    _seed_order(db, user_uid=admin_uid, user_email=admin_email, product_id=product_id)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
