#!/usr/bin/env python3
"""Seed DEV Firestore with admin sample data (idempotent).

Creates (if missing):
- Sample products
- Admin favorites (users/{adminUid}/favorites)
- Sample orders for the admin user (orders/* with paymentStatus=captured)

This script uses Google Cloud / Firebase Admin privileges via ADC (Application Default Credentials),
so it bypasses Firestore security rules.

Run (recommended):
  cd /path/to/origna_gta
  source functions/venv/bin/activate
  python scripts/seed_dev_firestore_admin_samples.py --project orignagta-dev

Prereq:
  - You must have access to the Firebase/GCP project.
  - ADC must be configured (e.g. `gcloud auth application-default login`).

NOTE: This script intentionally targets DEV by default. It refuses to run against prod unless
      you pass --allow-prod.
"""

from __future__ import annotations

import argparse
import os
import sys

from google.cloud import firestore


def _repo_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def _import_schema_constants() -> tuple:
    functions_dir = os.path.join(_repo_root(), "functions")
    sys.path.insert(0, functions_dir)

    from schema_constants import (  # type: ignore
        Collections,
        Fields,
        DeliveryStatusValues,
        OrderStatusValues,
        PaymentStatusValues,
        PaymentProviderValues,
        PayoutStatusValues,
        ProductStatusValues,
        UserRoleValues,
        BusinessRules,
    )

    return (
        Collections,
        Fields,
        DeliveryStatusValues,
        OrderStatusValues,
        PaymentStatusValues,
        PaymentProviderValues,
        PayoutStatusValues,
        ProductStatusValues,
        UserRoleValues,
        BusinessRules,
    )


def _require_not_prod(project_id: str, allow_prod: bool) -> None:
    if allow_prod:
        return
    if project_id == "orignagta":
        raise SystemExit(
            "Refusing to seed prod project 'orignagta'. Re-run with --allow-prod if you are 100% sure."
        )


def _get_user_doc_by_email(db: firestore.Client, users_coll: str, email_field: str, email: str):
    docs = list(db.collection(users_coll).where(email_field, "==", email).limit(1).stream())
    return docs[0] if docs else None


def main() -> int:
    """Function main."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default="orignagta-dev", help="Firebase/GCP project id")
    parser.add_argument("--admin-email", default="yr62813@gmail.com", help="Admin test account email")
    parser.add_argument("--min-favorites", type=int, default=1, help="Ensure at least N favorites")
    parser.add_argument("--min-orders", type=int, default=1, help="Ensure at least N captured orders")
    parser.add_argument("--allow-prod", action="store_true", help="Allow seeding prod project (DANGEROUS)")
    args = parser.parse_args()

    _require_not_prod(args.project, args.allow_prod)

    (
        Collections,
        Fields,
        DeliveryStatusValues,
        OrderStatusValues,
        PaymentStatusValues,
        PaymentProviderValues,
        PayoutStatusValues,
        ProductStatusValues,
        UserRoleValues,
        BusinessRules,
    ) = (
        _import_schema_constants()
    )

    db = firestore.Client(project=args.project)

    admin_doc = _get_user_doc_by_email(
        db,
        users_coll=Collections.USERS,
        email_field=Fields.EMAIL,
        email=args.admin_email,
    )
    if admin_doc is None:
        print(
            f"❌ Admin user doc not found in {args.project}: users where {Fields.EMAIL} == {args.admin_email}\n"
            "Create it once by signing in with that account in DEV, then re-run this seeder.",
            file=sys.stderr,
        )
        return 2

    admin_uid = admin_doc.id
    print(f"✅ Admin user found: uid={admin_uid}")

    # Pick (or create) a seller uid different from admin.
    seller_uid = None
    seller_query = (
        db.collection(Collections.USERS)
        .where(Fields.ROLES, "array_contains", UserRoleValues.SELLER)
        .limit(25)
        .stream()
    )
    for doc in seller_query:
        if doc.id != admin_uid:
            seller_uid = doc.id
            break

    if seller_uid is None:
        seller_uid = f"seed_seller_{args.project}"
        seller_ref = db.collection(Collections.USERS).document(seller_uid)
        if not seller_ref.get().exists:
            seller_ref.set(
                {
                    Fields.UID: seller_uid,
                    Fields.EMAIL: f"seed-seller@{args.project}.local",
                    Fields.NAME: "Seed Seller",
                    Fields.ROLES: [UserRoleValues.BUYER, UserRoleValues.SELLER],
                    Fields.CREATED_AT: firestore.SERVER_TIMESTAMP,
                    Fields.PAYOUTS_ENABLED: True,
                    Fields.CHARGES_ENABLED: True,
                    Fields.ONBOARDING_COMPLETED: True,
                    Fields.SUSPENDED: False,
                    Fields.PAYMENT_PROVIDER: PaymentProviderValues.STRIPE,
                }
            )
        print(f"ℹ️  Created seed seller user doc: uid={seller_uid}")
    else:
        print(f"✅ Using existing seller uid: {seller_uid}")

    # --- Seed products ---
    # Deterministic IDs make this script idempotent.
    product_ids = [
        f"seed_{args.project}_product_1",
        f"seed_{args.project}_product_2",
    ]

    sample_seller_address = {
        Fields.STREET: "123 Seed St",
        Fields.APARTMENT: "",
        Fields.CITY: "Montreal",
        Fields.STATE: "QC",
        Fields.POSTAL_CODE: "H2X 1A1",
        Fields.COUNTRY: "Canada",
        Fields.PHONE_NUMBER: "5145550000",
        Fields.IS_DEFAULT: False,
        Fields.LABEL: "",
    }

    for idx, product_id in enumerate(product_ids, start=1):
        ref = db.collection(Collections.PRODUCTS).document(product_id)
        if ref.get().exists:
            continue

        ref.set(
            {
                Fields.NAME: f"Seed Product {idx} ({args.project})",
                Fields.PRICE: 19.99 + (idx * 5),
                Fields.DESCRIPTION: "Seeded sample product for integration tests",
                Fields.IMAGE_URLS: ["https://via.placeholder.com/300"],
                Fields.SELLER_ID: seller_uid,
                Fields.SELLER_ADDRESS: sample_seller_address,
                Fields.CATEGORY_ID: 1,
                Fields.STOCK_QUANTITY: 50,
                Fields.KEYWORDS: ["seed", "integration", "test"],
                Fields.CREATED_AT: firestore.SERVER_TIMESTAMP,
                Fields.RATING: 0.0,
                Fields.RATING_COUNT: 0,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.FREE_SHIPPING: False,
                Fields.IS_DIGITAL: False,
                Fields.WEIGHT_KG: 0.5,
                Fields.MINIMUM_ORDER_QUANTITY: 1,
            }
        )
        print(f"✅ Created product: {product_id}")

    # --- Seed favorites for admin ---
    fav_coll = (
        db.collection(Collections.USERS)
        .document(admin_uid)
        .collection(Collections.FAVORITES)
    )

    existing_favs = list(fav_coll.limit(10).stream())
    if len(existing_favs) < args.min_favorites:
        for product_id in product_ids[: args.min_favorites]:
            fav_ref = fav_coll.document(product_id)
            if fav_ref.get().exists:
                continue
            fav_ref.set(
                {
                    Fields.PRODUCT_ID: product_id,
                    Fields.DATE_FAVORITED: firestore.SERVER_TIMESTAMP,
                }
            )
            print(f"✅ Added admin favorite: {product_id}")
    else:
        print(f"✅ Admin already has favorites: count>={len(existing_favs)}")

    # --- Seed captured orders for admin ---
    orders_coll = db.collection(Collections.ORDERS)

    captured_orders = list(
        orders_coll.where(Fields.USER_ID, "==", admin_uid)
        .where(Fields.PAYMENT_STATUS, "==", PaymentStatusValues.CAPTURED)
        .limit(10)
        .stream()
    )

    if len(captured_orders) >= args.min_orders:
        print(f"✅ Admin already has captured orders: count>={len(captured_orders)}")
        return 0

    # Create deterministic order IDs so reruns stay idempotent.
    # Firestore server timestamp is enough for UI purposes.
    order_ids = [
        f"seed_{args.project}_admin_order_1",
        f"seed_{args.project}_admin_order_2",
    ]

    shipping_address = {
        Fields.STREET: "456 Buyer Ave",
        Fields.APARTMENT: "Unit 2",
        Fields.CITY: "Toronto",
        Fields.STATE: "ON",
        Fields.POSTAL_CODE: "M5V 1A1",
        Fields.COUNTRY: "Canada",
        Fields.PHONE_NUMBER: "4165550000",
        Fields.IS_DEFAULT: True,
        Fields.LABEL: "Home",
    }

    taxes = {Fields.GST: 0.0, Fields.PST: 0.0, Fields.HST: 0.0, Fields.QST: 0.0}

    for i, order_id in enumerate(order_ids, start=1):
        ref = orders_coll.document(order_id)
        if ref.get().exists:
            continue

        subtotal_cents = 2500 + (i * 500)
        shipping_cents = 500
        tax_cents = 0
        total_cents = subtotal_cents + shipping_cents + tax_cents

        item = {
            Fields.PRODUCT_ID: product_ids[(i - 1) % len(product_ids)],
            Fields.NAME: f"Seed Order Item {i}",
            Fields.DESCRIPTION: "Seeded order item for integration tests",
            Fields.PRICE: subtotal_cents / 100.0,
            Fields.QUANTITY: 1,
            Fields.IMAGE_URLS: ["https://via.placeholder.com/300"],
            Fields.SELLER_ID: seller_uid,
            Fields.SELLER_ADDRESS: sample_seller_address,
            Fields.STATUS: DeliveryStatusValues.PENDING,
            Fields.DELIVERY_STATUS: DeliveryStatusValues.PENDING,
            Fields.FREE_SHIPPING: False,
            Fields.IS_DIGITAL: False,
        }

        ref.set(
            {
                Fields.ORDER_ID: order_id,
                Fields.USER_ID: admin_uid,
                Fields.CUSTOMER_ID: admin_uid,
                Fields.CUSTOMER_EMAIL: args.admin_email,
                Fields.ITEMS: [item],
                Fields.SUBTOTAL_CENTS: subtotal_cents,
                Fields.SHIPPING_COST_CENTS: shipping_cents,
                Fields.TAX_AMOUNT_CENTS: tax_cents,
                Fields.TOTAL_AMOUNT_CENTS: total_cents,
                Fields.TAXES: taxes,
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.SHIPPING_ADDRESS: shipping_address,
                Fields.CREATED_AT: firestore.SERVER_TIMESTAMP,
                Fields.UPDATED_AT: firestore.SERVER_TIMESTAMP,
                Fields.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
                Fields.SELLER_IDS: [seller_uid],
                Fields.STRIPE_SESSION_ID: f"cs_test_seed_{args.project}_{i}",
                Fields.CONFIRMED_BY_CLIENT: False,
                Fields.CAPTURE_ATTEMPTS: 0,
                Fields.PLATFORM_FEE_TOTAL_CENTS: 0,
                Fields.PAYOUT_STATUS: PayoutStatusValues.PENDING,
            }
        )
        print(f"✅ Created admin order: {order_id}")

    # Re-check count
    captured_orders = list(
        orders_coll.where(Fields.USER_ID, "==", admin_uid)
        .where(Fields.PAYMENT_STATUS, "==", PaymentStatusValues.CAPTURED)
        .limit(10)
        .stream()
    )
    print(f"✅ Captured admin orders now: {len(captured_orders)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
