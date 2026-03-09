#!/usr/bin/env python3
"""
Mega Seed Script — Dev Firebase (orignagta-dev)
=================================================
Comprehensive QA seed for admin user yr62813@gmail.com so ALL app views
can be manually tested with realistic data.

Covers:
- 5 sellers (full profiles, warehouses, Stripe-connected)
- 30+ products across all categories + lifecycle states
- 5 digital products (books + software with licenses)
- Orders in EVERY status (pending → delivered, cancelled, disputed)
- Return requests in various states
- Reviews/ratings on products
- Favorites for admin (15 products)
- Cart items for admin (3 products)
- Coupons (percent + fixed)
- Seller metrics

Usage:
  cd /path/to/origna_gta
  source functions/venv/bin/activate
  python scripts/mega_seed_dev.py --project orignagta-dev

Idempotent: safe to re-run. Uses deterministic doc IDs prefixed with "mseed_".
"""

from __future__ import annotations

import argparse
import datetime
import os
import random
import sys

from google.cloud import firestore

_REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(_REPO_ROOT, "functions"))

from schema_constants import (  # noqa: E402
    BusinessRules,
    CategoryIds,
    Collections,
    CouponDiscountTypeValues,
    DeliveryStatusValues,
    DigitalTypeValues,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
    PayoutStatusValues,
    ProductLifecycleStatusValues,
    ReturnStatusValues,
    Subcategories,
    UserRoleValues,
    PaymentProviderValues,
)

# ─────────────────────────────────────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────────────────────────────────────
ADMIN_EMAIL = "yr62813@gmail.com"
ADMIN_UID = "RU9MI8vYFkQCakMrJfG8iGTuc012"
PREFIX = "mseed_"

# Real product images (Picsum)
IMGS = [
    "https://picsum.photos/seed/p1/600/600",
    "https://picsum.photos/seed/p2/600/600",
    "https://picsum.photos/seed/p3/600/600",
    "https://picsum.photos/seed/p4/600/600",
    "https://picsum.photos/seed/p5/600/600",
    "https://picsum.photos/seed/p6/600/600",
    "https://picsum.photos/seed/p7/600/600",
    "https://picsum.photos/seed/p8/600/600",
]


def _now() -> datetime.datetime:
    return datetime.datetime.now(datetime.UTC)


def _ago(days: int = 0, hours: int = 0) -> datetime.datetime:
    return _now() - datetime.timedelta(days=days, hours=hours)


def _get_or_set(ref: firestore.DocumentReference, data: dict, label: str = "") -> bool:
    """Create doc only if it doesn't exist. Returns True if created."""
    if ref.get().exists:
        print(f"  ⏭  exists: {label or ref.id}")
        return False
    ref.set(data)
    print(f"  ✅  created: {label or ref.id}")
    return True


# ─────────────────────────────────────────────────────────────────────────────
# ADDRESSES
# ─────────────────────────────────────────────────────────────────────────────
def _addr(street: str, city: str, province: str, postal: str, phone: str = "4165550100") -> dict:
    return {
        Fields.STREET: street,
        Fields.APARTMENT: "",
        Fields.CITY: city,
        Fields.STATE: province,
        Fields.POSTAL_CODE: postal,
        Fields.COUNTRY: "Canada",
        Fields.PHONE_NUMBER: phone,
        Fields.IS_DEFAULT: True,
        Fields.LABEL: "Home",
        Fields.LATITUDE: 43.6532,
        Fields.LONGITUDE: -79.3832,
    }


TORONTO = _addr("100 King St W", "Toronto", "ON", "M5X 1A4", "4165550001")
MONTREAL = _addr("1000 Rue de la Gauchetière", "Montreal", "QC", "H3B 4W5", "5145550002")
VANCOUVER = _addr("700 W Georgia St", "Vancouver", "BC", "V7Y 1G5", "6045550003")
CALGARY = _addr("400 4 Ave SW", "Calgary", "AB", "T2P 0J4", "4035550004")
OTTAWA = _addr("150 Elgin St", "Ottawa", "ON", "K2P 1L4", "6135550005")


# ─────────────────────────────────────────────────────────────────────────────
# SELLERS
# ─────────────────────────────────────────────────────────────────────────────
SELLERS = [
    {
        "uid": f"{PREFIX}seller_1",
        "email": "seller1@mseed.ca",
        "name": "Alice Chen",
        "address": VANCOUVER,
        "city": "Vancouver",
        "province": "BC",
        "stripe_id": "acct_mseed_seller1",
        "charges": True,
        "payouts": True,
    },
    {
        "uid": f"{PREFIX}seller_2",
        "email": "seller2@mseed.ca",
        "name": "Bob Tremblay",
        "address": MONTREAL,
        "city": "Montreal",
        "province": "QC",
        "stripe_id": "acct_mseed_seller2",
        "charges": True,
        "payouts": True,
    },
    {
        "uid": f"{PREFIX}seller_3",
        "email": "seller3@mseed.ca",
        "name": "Carlos Rivera",
        "address": TORONTO,
        "city": "Toronto",
        "province": "ON",
        "stripe_id": "acct_mseed_seller3",
        "charges": True,
        "payouts": True,
    },
    {
        "uid": f"{PREFIX}seller_4",
        "email": "seller4@mseed.ca",
        "name": "Diana Park",
        "address": CALGARY,
        "city": "Calgary",
        "province": "AB",
        "stripe_id": "acct_mseed_seller4",
        "charges": False,  # onboarding incomplete
        "payouts": False,
    },
    {
        "uid": f"{PREFIX}seller_5",
        "email": "seller5@mseed.ca",
        "name": "Ethan Williams",
        "address": OTTAWA,
        "city": "Ottawa",
        "province": "ON",
        "stripe_id": "acct_mseed_seller5",
        "charges": True,
        "payouts": True,
    },
]


def seed_sellers(db: firestore.Client) -> None:
    """Function seed_sellers."""
    print("\n── Sellers ────────────────────────────────────────────")
    for s in SELLERS:
        uid = s["uid"]
        # users collection
        _get_or_set(
            db.collection(Collections.USERS).document(uid),
            {
                Fields.UID: uid,
                Fields.EMAIL: s["email"],
                Fields.NAME: s["name"],
                Fields.ROLES: [UserRoleValues.BUYER, UserRoleValues.SELLER],
                Fields.ADDRESS: s["address"],
                Fields.CHARGES_ENABLED: s["charges"],
                Fields.PAYOUTS_ENABLED: s["payouts"],
                Fields.ONBOARDING_COMPLETED: s["charges"],
                Fields.STRIPE_ACCOUNT_ID: s["stripe_id"],
                Fields.PAYMENT_PROVIDER: PaymentProviderValues.STRIPE,
                Fields.IS_PREMIUM: False,
                Fields.CREATED_AT: _ago(days=90),
                Fields.UPDATED_AT: _ago(days=1),
                Fields.EMAIL_CONSENT: True,
                Fields.MARKETING_OPT_IN: False,
                Fields.DATA_PROCESSING_CONSENT: True,
            },
            label=f"user/{uid}",
        )
        # seller_profiles collection
        _get_or_set(
            db.collection(Collections.SELLER_PROFILES).document(uid),
            {
                Fields.UID: uid,
                Fields.NAME: s["name"],
                Fields.EMAIL: s["email"],
                Fields.STRIPE_ACCOUNT_ID: s["stripe_id"],
                Fields.CHARGES_ENABLED: s["charges"],
                Fields.PAYOUTS_ENABLED: s["payouts"],
                Fields.ONBOARDING_COMPLETED: s["charges"],
                Fields.BUSINESS_ADDRESS: s["address"],
                Fields.CREATED_AT: _ago(days=90),
                Fields.UPDATED_AT: _ago(days=1),
            },
            label=f"seller_profile/{uid}",
        )
        # Warehouse
        wh_id = f"{PREFIX}wh_{uid.split('_')[-1]}"
        _get_or_set(
            db.collection(Collections.USERS).document(uid).collection(Collections.WAREHOUSES).document(wh_id),
            {
                "warehouseId": wh_id,
                Fields.NAME: f"{s['name']} — {s['city']} Warehouse",
                Fields.ADDRESS: s["address"],
                "isPrimary": True,
                "warehouseType": "warehouse",
                Fields.CREATED_AT: _ago(days=89),
            },
            label=f"warehouse/{wh_id}",
        )


# ─────────────────────────────────────────────────────────────────────────────
# PRODUCTS
# ─────────────────────────────────────────────────────────────────────────────
def _product(
    pid: str,
    name: str,
    description: str,
    price: float,
    category: int,
    seller_uid: str,
    seller_address: dict,
    lifecycle: str = ProductLifecycleStatusValues.ACTIVE,
    stock: int = 50,
    is_digital: bool = False,
    digital_type: str | None = None,
    weight: float = 0.5,
    images: list[str] | None = None,
    rating: float = 0.0,
    rating_count: int = 0,
    free_shipping: bool = False,
    keywords: list[str] | None = None,
    created_days_ago: int = 30,
    subcategory: str | None = None,
) -> dict:
    img = images or [IMGS[hash(pid) % len(IMGS)], IMGS[(hash(pid) + 1) % len(IMGS)]]
    kw = keywords or [name.split()[0].lower(), "canada", "origna"]
    wh_id = f"{PREFIX}wh_{seller_uid.split('_')[-1]}"
    doc: dict = {
        Fields.PRODUCT_ID if hasattr(Fields, "PRODUCT_ID") else "productId": pid,
        Fields.NAME: name,
        Fields.DESCRIPTION: description,
        Fields.PRICE: price,
        Fields.CATEGORY_ID: category,
        Fields.SELLER_ID: seller_uid,
        Fields.SELLER_ADDRESS: seller_address,
        Fields.LIFECYCLE_STATUS: lifecycle,
        Fields.STOCK_QUANTITY: stock,
        Fields.IS_DIGITAL: is_digital,
        Fields.DIGITAL_TYPE: digital_type,
        Fields.WEIGHT_KG: weight,
        Fields.IMAGE_URLS: img,
        Fields.RATING: rating,
        Fields.RATING_COUNT: rating_count,
        Fields.FREE_SHIPPING: free_shipping,
        Fields.KEYWORDS: kw,
        Fields.CREATED_AT: _ago(days=created_days_ago),
        Fields.UPDATED_AT: _ago(days=1),
        Fields.MINIMUM_ORDER_QUANTITY: 1,
        Fields.WAREHOUSE_IDS: [wh_id],
        Fields.PRIMARY_WAREHOUSE_ID: wh_id,
        "isTrending": False,
    }
    if subcategory:
        doc[Fields.SUBCATEGORY] = subcategory
    return doc


PRODUCTS = [
    # ── ACTIVE products (seller_1)
    {
        "pid": f"{PREFIX}prod_electronics_1",
        "name": "Sony WH-1000XM5 Headphones",
        "description": "Industry-leading noise cancelling headphones with Auto NC Optimizer. Up to 30-hour battery. Multipoint connection for 2 devices. Perfect for work-from-home or commuting.",
        "price": 299.99,
        "category": CategoryIds.ELECTRONICS,
        "subcategory": "Audio",
        "seller_idx": 0,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 25,
        "rating": 4.8,
        "rating_count": 142,
        "keywords": ["headphones", "sony", "noise cancelling", "electronics"],
    },
    {
        "pid": f"{PREFIX}prod_electronics_2",
        "name": "Apple AirPods Pro (2nd Gen)",
        "description": "Active Noise Cancellation up to 2x more powerful than previous generation. Adaptive Transparency. Personalized Spatial Audio with dynamic head tracking.",
        "price": 329.00,
        "category": CategoryIds.ELECTRONICS,
        "subcategory": "Audio",
        "seller_idx": 0,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 40,
        "rating": 4.7,
        "rating_count": 89,
        "free_shipping": True,
    },
    {
        "pid": f"{PREFIX}prod_computers_1",
        "name": "Logitech MX Keys Wireless Keyboard",
        "description": "Comfortable and quiet typing. Smart Illumination with proximity sensor. USB-C rechargeable. Multi-device support (up to 3 devices). Cross-computer control with Flow.",
        "price": 159.99,
        "category": CategoryIds.COMPUTERS,
        "subcategory": "Accessories",
        "seller_idx": 0,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 60,
        "rating": 4.6,
        "rating_count": 203,
    },
    # ── ACTIVE products (seller_2 — Montreal)
    {
        "pid": f"{PREFIX}prod_fashion_1",
        "name": "Canada Goose Expedition Parka",
        "description": "The ultimate extreme weather parka. 625 fill power white duck down. Arctic Tech® shell. Rated to -30°C. Made in Canada. Available in multiple colours.",
        "price": 1095.00,
        "category": CategoryIds.FASHION,
        "subcategory": "Outerwear",
        "seller_idx": 1,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 12,
        "rating": 4.9,
        "rating_count": 55,
        "weight": 2.1,
        "keywords": ["canada goose", "parka", "winter jacket", "canada"],
    },
    {
        "pid": f"{PREFIX}prod_fashion_2",
        "name": "Lululemon Align Pant 28",
        "description": "Our best-loved yoga pant. Buttery-soft Nulu™ fabric feels like you're wearing nothing. Full length (28\"). High-rise fit. 4-way stretch.",
        "price": 138.00,
        "category": CategoryIds.FASHION,
        "subcategory": "Women's Clothing",
        "seller_idx": 1,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 80,
        "rating": 4.7,
        "rating_count": 312,
        "free_shipping": True,
    },
    {
        "pid": f"{PREFIX}prod_beauty_1",
        "name": "La Mer Moisturizing Cream 60ml",
        "description": "The iconic moisturizer. Miracle Broth™ fermented sea kelp revitalizes and transforms skin. Restores strength and resilience. For all skin types.",
        "price": 415.00,
        "category": CategoryIds.BEAUTY_PERSONAL_CARE,
        "subcategory": "Skincare",
        "seller_idx": 1,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 20,
        "rating": 4.5,
        "rating_count": 78,
        "weight": 0.2,
    },
    # ── ACTIVE products (seller_3 — Toronto)
    {
        "pid": f"{PREFIX}prod_home_1",
        "name": "Vitamix 5200 Blender",
        "description": "Variable speed motor. Aircraft-grade stainless steel blades. Self-cleaning in 30-60 seconds. 7-year full warranty. Powers through the toughest ingredients.",
        "price": 599.95,
        "category": CategoryIds.HOME_KITCHEN,
        "subcategory": "Kitchen",
        "seller_idx": 2,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 15,
        "rating": 4.8,
        "rating_count": 445,
        "weight": 5.4,
    },
    {
        "pid": f"{PREFIX}prod_home_2",
        "name": "Instant Pot Duo 7-in-1 6qt",
        "description": "7-in-1 multi-use: pressure cooker, slow cooker, rice cooker, steamer, sauté, yogurt maker, warmer. 6-quart size. 13 customizable programs.",
        "price": 99.99,
        "category": CategoryIds.HOME_KITCHEN,
        "subcategory": "Kitchen",
        "seller_idx": 2,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 35,
        "rating": 4.6,
        "rating_count": 891,
        "free_shipping": True,
    },
    {
        "pid": f"{PREFIX}prod_sports_1",
        "name": "Peloton Bike Mat",
        "description": "Thick, durable exercise mat designed specifically for Peloton bikes. Anti-slip bottom keeps mat firmly in place. Protects floors from sweat and impact.",
        "price": 64.00,
        "category": CategoryIds.SPORTS_FITNESS,
        "subcategory": "Fitness",
        "seller_idx": 2,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 100,
        "rating": 4.4,
        "rating_count": 267,
        "weight": 1.8,
    },
    # ── ACTIVE products (seller_5 — Ottawa)
    {
        "pid": f"{PREFIX}prod_gaming_1",
        "name": "PlayStation 5 DualSense Controller",
        "description": "Haptic feedback and adaptive triggers. Integrated microphone. 12-hour battery. USB-C charging. Works with PS5 and PC. Midnight Black edition.",
        "price": 89.99,
        "category": CategoryIds.GAMING,
        "subcategory": "Controllers",
        "seller_idx": 4,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 30,
        "rating": 4.9,
        "rating_count": 1024,
        "free_shipping": True,
    },
    {
        "pid": f"{PREFIX}prod_gaming_2",
        "name": "Nintendo Switch OLED Model",
        "description": "7-inch OLED screen with vivid colors and crisp contrast. Enhanced audio. 64 GB internal storage. Wide adjustable stand. LAN port in dock.",
        "price": 449.99,
        "category": CategoryIds.GAMING,
        "subcategory": "Consoles",
        "seller_idx": 4,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 8,  # Low stock
        "rating": 4.8,
        "rating_count": 567,
        "weight": 0.42,
    },
    {
        "pid": f"{PREFIX}prod_books_1",
        "name": "Atomic Habits by James Clear",
        "description": "The #1 New York Times bestseller. Over 15 million copies sold. Tiny Changes, Remarkable Results. An Easy & Proven Way to Build Good Habits & Break Bad Ones.",
        "price": 21.99,
        "category": CategoryIds.BOOKS,
        "subcategory": "Non-Fiction",
        "seller_idx": 4,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 200,
        "rating": 4.9,
        "rating_count": 4521,
        "weight": 0.35,
        "free_shipping": False,
    },
    {
        "pid": f"{PREFIX}prod_books_2",
        "name": "The Psychology of Money",
        "description": "Timeless lessons on wealth, greed, and happiness. Morgan Housel shares 19 short stories exploring the strange ways people think about money.",
        "price": 18.99,
        "category": CategoryIds.BOOKS,
        "subcategory": "Non-Fiction",
        "seller_idx": 4,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 150,
        "rating": 4.7,
        "rating_count": 2810,
        "weight": 0.3,
    },
    # ── UNDER REVIEW products
    {
        "pid": f"{PREFIX}prod_review_1",
        "name": "Samsung 65-inch 4K QLED TV",
        "description": "Quantum Dot color technology. 120Hz refresh rate. Dolby Atmos. Smart TV with Tizen OS. 4 HDMI ports. Quantum HDR 4K+.",
        "price": 1299.99,
        "category": CategoryIds.ELECTRONICS,
        "subcategory": "Smart Home",
        "seller_idx": 0,
        "lifecycle": ProductLifecycleStatusValues.UNDER_REVIEW,
        "stock": 5,
        "weight": 28.0,
    },
    {
        "pid": f"{PREFIX}prod_review_2",
        "name": "Le Creuset Dutch Oven 5.5qt",
        "description": "Iconic French enameled cast-iron cookware. Even heat distribution. Self-basting lid. Oven safe to 500°F. Comes in Flame Orange.",
        "price": 399.99,
        "category": CategoryIds.HOME_KITCHEN,
        "subcategory": "Kitchen",
        "seller_idx": 1,
        "lifecycle": ProductLifecycleStatusValues.UNDER_REVIEW,
        "stock": 20,
        "weight": 5.5,
    },
    # ── PAUSED products
    {
        "pid": f"{PREFIX}prod_paused_1",
        "name": "Dyson V15 Detect Vacuum",
        "description": "Laser Slim Fluffy cleaner head detects particles invisible to the naked eye. HEPA filtration. Up to 60 minutes run time. LCD screen shows real-time particle counts.",
        "price": 869.99,
        "category": CategoryIds.HOME_KITCHEN,
        "subcategory": "Furniture",
        "seller_idx": 2,
        "lifecycle": ProductLifecycleStatusValues.PAUSED,
        "stock": 7,
        "weight": 3.1,
    },
    # ── DRAFT products
    {
        "pid": f"{PREFIX}prod_draft_1",
        "name": "Weber Spirit II E-310 Gas Grill",
        "description": "3-burner gas grill. 529 sq-in cooking area. Porcelain-enameled cast-iron grates. Grease management system. Side tables. GS4 grilling system.",
        "price": 749.00,
        "category": CategoryIds.HOME_KITCHEN,
        "subcategory": "Garden & Outdoor",
        "seller_idx": 2,
        "lifecycle": ProductLifecycleStatusValues.DRAFT,
        "stock": 3,
        "weight": 55.0,
    },
    # ── REJECTED product
    {
        "pid": f"{PREFIX}prod_rejected_1",
        "name": "Suspicious Miracle Cure Supplement",
        "description": "Cures everything. (Test rejected product — should show rejected state in admin panel.)",
        "price": 49.99,
        "category": CategoryIds.HEALTH_WELLNESS,
        "subcategory": "Vitamins & Supplements",
        "seller_idx": 3,
        "lifecycle": ProductLifecycleStatusValues.REJECTED,
        "stock": 1000,
        "weight": 0.1,
    },
    # ── ARCHIVED product
    {
        "pid": f"{PREFIX}prod_archived_1",
        "name": "2023 Winter Collection Coat",
        "description": "Last season archived item. No longer available. For testing archived product view.",
        "price": 189.00,
        "category": CategoryIds.FASHION,
        "subcategory": "Outerwear",
        "seller_idx": 1,
        "lifecycle": ProductLifecycleStatusValues.ARCHIVED,
        "stock": 0,
        "weight": 1.5,
        "created_days_ago": 400,
    },
    # ── OUT OF STOCK
    {
        "pid": f"{PREFIX}prod_oos_1",
        "name": "Lego Star Wars Millennium Falcon",
        "description": "7,541 pieces. Most detailed LEGO Star Wars model ever created. Minifigures included. Suitable for ages 16+.",
        "price": 949.99,
        "category": CategoryIds.TOYS_GAMES,
        "subcategory": "Building Toys",
        "seller_idx": 4,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 0,
        "weight": 8.5,
        "rating": 4.9,
        "rating_count": 234,
    },
    # ── DIGITAL PRODUCTS (books + software)
    {
        "pid": f"{PREFIX}prod_digital_book_1",
        "name": "Python Crash Course — Digital Edition",
        "description": "A Hands-On, Project-Based Introduction to Programming. Best-selling programming book. Instant download. DRM-free PDF + EPUB. 3rd Edition.",
        "price": 29.99,
        "category": CategoryIds.DIGITAL_PRODUCTS,
        "subcategory": "eBooks",
        "seller_idx": 4,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 9999,
        "is_digital": True,
        "digital_type": DigitalTypeValues.BOOK,
        "weight": 0.0,
        "free_shipping": True,
        "rating": 4.8,
        "rating_count": 1205,
    },
    {
        "pid": f"{PREFIX}prod_digital_book_2",
        "name": "Clean Code — Digital Edition",
        "description": "A Handbook of Agile Software Craftsmanship by Robert C. Martin. Essential reading for every developer. PDF + EPUB formats included.",
        "price": 34.99,
        "category": CategoryIds.DIGITAL_PRODUCTS,
        "subcategory": "eBooks",
        "seller_idx": 4,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 9999,
        "is_digital": True,
        "digital_type": DigitalTypeValues.BOOK,
        "weight": 0.0,
        "free_shipping": True,
        "rating": 4.7,
        "rating_count": 890,
    },
    {
        "pid": f"{PREFIX}prod_digital_sw_1",
        "name": "Origna Photo Editor Pro — License",
        "description": "Professional photo editing software for macOS, Windows & Linux. AI-powered tools. Lifetime license. Free updates for 1 year. Cancel subscription, keep forever.",
        "price": 89.99,
        "category": CategoryIds.DIGITAL_PRODUCTS,
        "subcategory": "Software",
        "seller_idx": 0,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 9999,
        "is_digital": True,
        "digital_type": DigitalTypeValues.SOFTWARE,
        "weight": 0.0,
        "free_shipping": True,
        "rating": 4.3,
        "rating_count": 156,
    },
    {
        "pid": f"{PREFIX}prod_digital_sw_2",
        "name": "VPN Secure — 1-Year Subscription",
        "description": "Military-grade encryption. 60+ countries. Unlimited bandwidth. 10 simultaneous devices. No logs policy. Works on macOS, Windows, Linux, iOS, Android.",
        "price": 79.99,
        "category": CategoryIds.DIGITAL_PRODUCTS,
        "subcategory": "Software",
        "seller_idx": 0,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 9999,
        "is_digital": True,
        "digital_type": DigitalTypeValues.SOFTWARE,
        "weight": 0.0,
        "free_shipping": True,
        "rating": 4.5,
        "rating_count": 432,
    },
    # ── Additional active products for variety
    {
        "pid": f"{PREFIX}prod_pet_1",
        "name": "KONG Classic Dog Toy",
        "description": "The world's best dog toy. Durable natural rubber. Stuff with treats to keep dogs busy. Dishwasher safe. Vet recommended for 50+ years.",
        "price": 19.99,
        "category": CategoryIds.PET_SUPPLIES,
        "subcategory": "Dogs",
        "seller_idx": 2,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 200,
        "weight": 0.25,
        "rating": 4.8,
        "rating_count": 3201,
        "free_shipping": True,
    },
    {
        "pid": f"{PREFIX}prod_office_1",
        "name": "Moleskine Classic Notebook Large",
        "description": "The legendary notebook. 240 pages. Hard cover. Rounded corners. Elastic closure. Inner pocket. Ribbon bookmark. Acid-free paper.",
        "price": 32.95,
        "category": CategoryIds.OFFICE_SUPPLIES,
        "subcategory": "Paper",
        "seller_idx": 1,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 500,
        "weight": 0.3,
        "rating": 4.6,
        "rating_count": 678,
    },
    {
        "pid": f"{PREFIX}prod_health_1",
        "name": "Theragun Prime Massage Gun",
        "description": "Professional percussive therapy device. 4 attachments. 5 built-in speeds (1750-2400 PPM). 120-min battery. Bluetooth + App guided routines.",
        "price": 349.00,
        "category": CategoryIds.HEALTH_WELLNESS,
        "subcategory": "Personal Care",
        "seller_idx": 2,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 18,
        "weight": 1.0,
        "rating": 4.7,
        "rating_count": 543,
    },
    {
        "pid": f"{PREFIX}prod_jewelry_1",
        "name": "Pandora Moments Bracelet + 3 Charms",
        "description": "Sterling silver snake chain bracelet. 19cm. Includes 3 signature Pandora charms. Gift box included. Pandora-certified authentic.",
        "price": 169.00,
        "category": CategoryIds.JEWELRY_WATCHES,
        "subcategory": "Bracelets",
        "seller_idx": 1,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 30,
        "weight": 0.05,
        "rating": 4.8,
        "rating_count": 189,
    },
    {
        "pid": f"{PREFIX}prod_auto_1",
        "name": "Michelin Pilot Sport 4S 245/40R18 (set of 4)",
        "description": "Ultra-high performance summer tire. Optimized for dry and wet grip. Used as OEM on Porsche, BMW, Ferrari. Rated #1 UHP tire.",
        "price": 1399.96,
        "category": CategoryIds.AUTOMOTIVE,
        "subcategory": "Replacement Parts",
        "seller_idx": 3,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 4,
        "weight": 40.0,
        "rating": 4.9,
        "rating_count": 87,
    },
    {
        "pid": f"{PREFIX}prod_baby_1",
        "name": "UPPAbaby Vista V2 Stroller",
        "description": "Grows with your family from infant to toddler. Adjustable toddler seat (forward + parent facing). Compatible with MESA infant car seat. Easy fold.",
        "price": 1199.99,
        "category": CategoryIds.BABY_KIDS,
        "subcategory": "Strollers",
        "seller_idx": 2,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 6,
        "weight": 11.5,
        "rating": 4.7,
        "rating_count": 234,
    },
    # ── MISSING CATEGORIES — Shoes (6), Tools (12), Music (15), Groceries (19), Art (20)
    {
        "pid": f"{PREFIX}prod_shoes_1",
        "name": "Nike Air Max 90 Essential",
        "description": "Iconic sneaker with visible Air cushioning. Leather and textile upper. Rubber Waffle outsole. Max Air unit in the heel. A true streetwear classic.",
        "price": 159.99,
        "category": CategoryIds.SHOES_ACCESSORIES,
        "subcategory": "Sneakers",
        "seller_idx": 1,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 45,
        "weight": 0.8,
        "rating": 4.6,
        "rating_count": 1890,
        "keywords": ["nike", "sneakers", "shoes", "air max"],
    },
    {
        "pid": f"{PREFIX}prod_tools_1",
        "name": "DeWalt 20V MAX Cordless Drill/Driver Kit",
        "description": "High-performance 20V motor. 2-speed transmission (0-450/1,500 rpm). Compact design fits in tight spaces. Includes 2 batteries, charger, and bag.",
        "price": 179.00,
        "category": CategoryIds.TOOLS_HARDWARE,
        "subcategory": "Power Tools",
        "seller_idx": 3,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 22,
        "weight": 2.3,
        "rating": 4.8,
        "rating_count": 3456,
        "keywords": ["dewalt", "drill", "power tools", "cordless"],
    },
    {
        "pid": f"{PREFIX}prod_music_1",
        "name": "Fender Player Stratocaster Electric Guitar",
        "description": "Alder body, maple neck, pau ferro fretboard. 22 medium jumbo frets. 3 Player Series single-coil Strat pickups. Classic tone, modern feel.",
        "price": 999.99,
        "category": CategoryIds.MUSIC_INSTRUMENTS,
        "subcategory": "Guitars",
        "seller_idx": 4,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 8,
        "weight": 3.6,
        "rating": 4.9,
        "rating_count": 567,
        "keywords": ["fender", "guitar", "stratocaster", "electric"],
    },
    {
        "pid": f"{PREFIX}prod_groceries_1",
        "name": "Kirkland Organic Maple Syrup 1L",
        "description": "100% pure Canadian Grade A amber maple syrup. Organic certified. Rich and smooth flavour. Perfect for pancakes, waffles, and baking.",
        "price": 14.99,
        "category": CategoryIds.GROCERIES,
        "subcategory": "Specialty Foods",
        "seller_idx": 2,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 300,
        "weight": 1.3,
        "rating": 4.7,
        "rating_count": 2100,
        "keywords": ["maple syrup", "organic", "canadian", "groceries"],
    },
    {
        "pid": f"{PREFIX}prod_art_1",
        "name": "Winsor & Newton Cotman Watercolour Set — 45 Half Pans",
        "description": "Studio watercolour set with 45 colours. Synthetic hair brush included. Folding palette. Mixing wells built into lid. Ideal for students and hobbyists.",
        "price": 89.99,
        "category": CategoryIds.ART_COLLECTIBLES,
        "subcategory": "Painting",
        "seller_idx": 1,
        "lifecycle": ProductLifecycleStatusValues.ACTIVE,
        "stock": 35,
        "weight": 0.6,
        "rating": 4.5,
        "rating_count": 342,
        "keywords": ["watercolour", "art", "painting", "winsor newton"],
    },
]


def seed_products(db: firestore.Client) -> None:
    """Function seed_products."""
    print("\n── Products ────────────────────────────────────────────")
    for p in PRODUCTS:
        seller = SELLERS[p["seller_idx"]]
        pid = p["pid"]
        data = _product(
            pid=pid,
            name=p["name"],
            description=p["description"],
            price=p["price"],
            category=p["category"],
            seller_uid=seller["uid"],
            seller_address=seller["address"],
            lifecycle=p.get("lifecycle", ProductLifecycleStatusValues.ACTIVE),
            stock=p.get("stock", 50),
            is_digital=p.get("is_digital", False),
            digital_type=p.get("digital_type"),
            weight=p.get("weight", 0.5),
            rating=p.get("rating", 0.0),
            rating_count=p.get("rating_count", 0),
            free_shipping=p.get("free_shipping", False),
            keywords=p.get("keywords"),
            created_days_ago=p.get("created_days_ago", 30),
            subcategory=p.get("subcategory"),
        )
        # Add rejection note for rejected product
        if p.get("lifecycle") == ProductLifecycleStatusValues.REJECTED:
            data["rejectionReason"] = "Product description contains misleading health claims. Please revise."
        _get_or_set(
            db.collection(Collections.PRODUCTS).document(pid),
            data,
            label=f"product/{pid} [{p.get('lifecycle', 'active')}]",
        )
        # Seed digital book access for digital products
        if p.get("is_digital") and p.get("digital_type") == DigitalTypeValues.BOOK:
            data_digital = dict(data)
            data_digital[Fields.BOOK_SOURCE_URL] = f"https://books.orignagta.ca/mseed/{pid}.pdf"
        if p.get("is_digital") and p.get("digital_type") == DigitalTypeValues.SOFTWARE:
            data["digitalBuilds"] = {
                "macos": f"https://downloads.orignagta.ca/mseed/{pid}/macos/installer.dmg",
                "windows": f"https://downloads.orignagta.ca/mseed/{pid}/windows/installer.exe",
                "linux": f"https://downloads.orignagta.ca/mseed/{pid}/linux/installer.tar.gz",
            }


# ─────────────────────────────────────────────────────────────────────────────
# REVIEWS
# ─────────────────────────────────────────────────────────────────────────────
def seed_reviews(db: firestore.Client) -> None:
    """Function seed_reviews."""
    print("\n── Reviews ────────────────────────────────────────────")
    active_pids = [p["pid"] for p in PRODUCTS if p.get("lifecycle") == ProductLifecycleStatusValues.ACTIVE and p.get("rating_count", 0) > 0]
    reviews = [
        {
            "rating": 5,
            "comment": "Absolutely love this product! Worth every penny. Fast shipping to Toronto. Will definitely buy again.",
            "reviewer_uid": ADMIN_UID,
            "reviewer_email": ADMIN_EMAIL,
            "reviewer_name": "Yunior R.",
        },
        {
            "rating": 4,
            "comment": "Great quality. Arrived well packaged. Only minor issue is the instruction manual could be more detailed. Overall very satisfied.",
            "reviewer_uid": f"{PREFIX}seller_1",
            "reviewer_email": "seller1@mseed.ca",
            "reviewer_name": "Alice C.",
        },
        {
            "rating": 5,
            "comment": "Best purchase I've made this year! The quality far exceeds the price. Highly recommend to anyone in Canada.",
            "reviewer_uid": f"{PREFIX}seller_3",
            "reviewer_email": "seller3@mseed.ca",
            "reviewer_name": "Carlos R.",
        },
        {
            "rating": 3,
            "comment": "Decent product. Not quite what I expected based on the photos but functional. Shipping was very fast.",
            "reviewer_uid": f"{PREFIX}seller_2",
            "reviewer_email": "seller2@mseed.ca",
            "reviewer_name": "Bob T.",
        },
    ]
    for i, pid in enumerate(active_pids[:8]):
        for j, rev in enumerate(reviews[:2]):
            rid = f"{PREFIX}rev_{pid.split('_')[-2]}_{j}"
            _get_or_set(
                db.collection(Collections.PRODUCT_RATINGS).document(rid),
                {
                    "ratingId": rid,
                    Fields.PRODUCT_ID: pid,
                    Fields.RATING: rev["rating"],
                    "comment": rev["comment"],
                    Fields.USER_ID: rev["reviewer_uid"],
                    "reviewerEmail": rev["reviewer_email"],
                    "reviewerName": rev["reviewer_name"],
                    "verifiedPurchase": True,
                    Fields.CREATED_AT: _ago(days=random.randint(1, 20)),
                    "helpfulVotes": random.randint(0, 50),
                    "totalVotes": random.randint(0, 60),
                    "imageUrls": [],
                    "isVisible": True,
                    "flagged": False,
                },
                label=f"review/{rid}",
            )


# ─────────────────────────────────────────────────────────────────────────────
# ORDERS  (all statuses)
# ─────────────────────────────────────────────────────────────────────────────
def _order(
    order_id: str,
    buyer_uid: str,
    buyer_email: str,
    seller_uid: str,
    product_pid: str,
    product_name: str,
    price: float,
    qty: int,
    order_status: str,
    payment_status: str,
    delivery_status: str = DeliveryStatusValues.PENDING,
    is_digital: bool = False,
    created_days_ago: int = 10,
) -> dict:
    subtotal_cents = int(price * qty * 100)
    shipping_cents = 0 if is_digital else 1200
    tax_cents = int(subtotal_cents * 0.13)
    total_cents = subtotal_cents + shipping_cents + tax_cents
    platform_fee_cents = int(subtotal_cents * BusinessRules.PLATFORM_FEE_RATIO)

    seller = next((s for s in SELLERS if s["uid"] == seller_uid), SELLERS[0])

    item = {
        Fields.PRODUCT_ID: product_pid,
        Fields.NAME: product_name,
        Fields.DESCRIPTION: "Seeded order item",
        Fields.PRICE: price,
        Fields.QUANTITY: qty,
        Fields.IMAGE_URLS: [IMGS[hash(product_pid) % len(IMGS)]],
        Fields.SELLER_ID: seller_uid,
        Fields.SELLER_ADDRESS: seller["address"],
        Fields.STATUS: delivery_status,
        Fields.FREE_SHIPPING: is_digital,
        Fields.IS_DIGITAL: is_digital,
        "itemId": f"{order_id}_item_1",
    }

    return {
        Fields.ORDER_ID: order_id,
        Fields.USER_ID: buyer_uid,
        Fields.CUSTOMER_ID: buyer_uid,
        Fields.CUSTOMER_EMAIL: buyer_email,
        Fields.ITEMS: [item],
        Fields.SUBTOTAL_CENTS: subtotal_cents,
        Fields.SHIPPING_COST_CENTS: shipping_cents,
        Fields.TAX_AMOUNT_CENTS: tax_cents,
        Fields.TOTAL_AMOUNT_CENTS: total_cents,
        Fields.TAXES: {Fields.GST: 0.0, Fields.HST: tax_cents / 100.0, Fields.PST: 0.0, Fields.QST: 0.0},
        Fields.ORDER_STATUS: order_status,
        Fields.PAYMENT_STATUS: payment_status,
        Fields.SHIPPING_ADDRESS: TORONTO,
        Fields.CREATED_AT: _ago(days=created_days_ago),
        Fields.UPDATED_AT: _ago(days=max(0, created_days_ago - 2)),
        Fields.CURRENCY: BusinessRules.DEFAULT_CURRENCY,
        Fields.SELLER_IDS: [seller_uid],
        Fields.STRIPE_SESSION_ID: f"cs_test_{PREFIX}{order_id[-8:]}",
        Fields.CONFIRMED_BY_CLIENT: order_status in {OrderStatusValues.DELIVERED},
        Fields.CAPTURE_ATTEMPTS: 1 if payment_status == PaymentStatusValues.CAPTURED else 0,
        Fields.PLATFORM_FEE_TOTAL_CENTS: platform_fee_cents,
        Fields.PAYOUT_STATUS: PayoutStatusValues.COMPLETED if payment_status == PaymentStatusValues.CAPTURED else PayoutStatusValues.PENDING,
        "pendingTotalCents": total_cents,
        "actualShippingCents": shipping_cents,
        "refundAmountCents": 0,
    }


ORDER_SPECS = [
    # (order_id_suffix, product_idx, qty, order_status, payment_status, delivery_status, created_days_ago, label)
    ("o_pending",       0,  1, OrderStatusValues.PENDING,     PaymentStatusValues.AUTHORIZED,    DeliveryStatusValues.PENDING,  1,  "pending"),
    ("o_confirmed",     1,  2, OrderStatusValues.CONFIRMED,   PaymentStatusValues.AUTHORIZED,    DeliveryStatusValues.PENDING,  3,  "confirmed"),
    ("o_processing",    2,  1, OrderStatusValues.PROCESSING,  PaymentStatusValues.AUTHORIZED,    DeliveryStatusValues.PENDING,  5,  "processing"),
    ("o_shipped",       3,  1, OrderStatusValues.SHIPPED,     PaymentStatusValues.AUTHORIZED,    DeliveryStatusValues.SHIPPED,  8,  "shipped"),
    ("o_in_transit",    6,  1, OrderStatusValues.IN_TRANSIT,  PaymentStatusValues.AUTHORIZED,    DeliveryStatusValues.SHIPPED,  9,  "in_transit"),
    ("o_delivered_1",   7,  2, OrderStatusValues.DELIVERED,   PaymentStatusValues.CAPTURED,      DeliveryStatusValues.DELIVERED, 15, "delivered (captured)"),
    ("o_delivered_2",   9,  1, OrderStatusValues.DELIVERED,   PaymentStatusValues.CAPTURED,      DeliveryStatusValues.DELIVERED, 20, "delivered #2"),
    ("o_delivered_3",  11,  3, OrderStatusValues.DELIVERED,   PaymentStatusValues.CAPTURED,      DeliveryStatusValues.DELIVERED, 25, "delivered #3"),
    ("o_cancelled",     4,  1, OrderStatusValues.CANCELLED,   PaymentStatusValues.CANCELLED,     DeliveryStatusValues.PENDING,  6,  "cancelled"),
    ("o_failed",        5,  1, OrderStatusValues.FAILED,      PaymentStatusValues.PAYMENT_FAILED,DeliveryStatusValues.PENDING,  4,  "failed"),
    ("o_refunded",      6,  1, OrderStatusValues.DELIVERED,   PaymentStatusValues.REFUNDED,      DeliveryStatusValues.DELIVERED, 30, "refunded"),
    ("o_partial_ref",   7,  2, OrderStatusValues.DELIVERED,   PaymentStatusValues.PARTIALLY_REFUNDED, DeliveryStatusValues.DELIVERED, 35, "partially refunded"),
    ("o_disputed",      8,  1, OrderStatusValues.DISPUTED,    PaymentStatusValues.DISPUTED,      DeliveryStatusValues.DELIVERED, 40, "disputed"),
    ("o_digital_1",    20,  1, OrderStatusValues.DELIVERED,   PaymentStatusValues.CAPTURED,      DeliveryStatusValues.DELIVERED, 12, "digital book delivered"),
    ("o_digital_2",    22,  1, OrderStatusValues.DELIVERED,   PaymentStatusValues.CAPTURED,      DeliveryStatusValues.DELIVERED, 7,  "digital software delivered"),
    ("o_admin_seller", 2,   1, OrderStatusValues.CONFIRMED,   PaymentStatusValues.AUTHORIZED,    DeliveryStatusValues.PENDING,  2,  "admin as seller — buyer is seller_1"),
]


def seed_orders(db: firestore.Client) -> None:
    """Function seed_orders."""
    print("\n── Orders ────────────────────────────────────────────")
    for spec in ORDER_SPECS:
        suffix, prod_idx, qty, o_status, p_status, d_status, days, label = spec
        order_id = f"{PREFIX}{suffix}"
        prod = PRODUCTS[prod_idx]
        seller = SELLERS[prod["seller_idx"]]

        # For the last one: admin is seller, buyer is seller_1
        if suffix == "o_admin_seller":
            buyer_uid = f"{PREFIX}seller_1"
            buyer_email = "seller1@mseed.ca"
            seller_uid = ADMIN_UID
            seller_email = ADMIN_EMAIL
        else:
            buyer_uid = ADMIN_UID
            buyer_email = ADMIN_EMAIL
            seller_uid = seller["uid"]

        data = _order(
            order_id=order_id,
            buyer_uid=buyer_uid,
            buyer_email=buyer_email,
            seller_uid=seller_uid,
            product_pid=prod["pid"],
            product_name=prod["name"],
            price=prod["price"],
            qty=qty,
            order_status=o_status,
            payment_status=p_status,
            delivery_status=d_status,
            is_digital=prod.get("is_digital", False),
            created_days_ago=days,
        )
        _get_or_set(
            db.collection(Collections.ORDERS).document(order_id),
            data,
            label=f"order/{order_id} [{label}]",
        )


# ─────────────────────────────────────────────────────────────────────────────
# RETURN REQUESTS
# ─────────────────────────────────────────────────────────────────────────────
def seed_return_requests(db: firestore.Client) -> None:
    """Function seed_return_requests."""
    print("\n── Return Requests ────────────────────────────────────")
    returns = [
        (f"{PREFIX}return_requested",   f"{PREFIX}o_delivered_1", ReturnStatusValues.REQUESTED, "Item not as described"),
        (f"{PREFIX}return_approved",    f"{PREFIX}o_delivered_2", ReturnStatusValues.APPROVED, "Damaged in transit"),
        (f"{PREFIX}return_refunded",    f"{PREFIX}o_delivered_3", ReturnStatusValues.REFUNDED, "Wrong item received"),
    ]
    for rid, order_id, status, reason in returns:
        prod_idx = 7  # o_delivered_1 → PRODUCTS[7] (Instant Pot)
        prod = PRODUCTS[7]
        seller = SELLERS[prod["seller_idx"]]
        _get_or_set(
            db.collection(Collections.RETURN_REQUESTS).document(rid),
            {
                "returnRequestId": rid,
                Fields.ORDER_ID: order_id,
                Fields.USER_ID: ADMIN_UID,
                Fields.SELLER_ID: seller["uid"],
                Fields.RETURN_STATUS: status,
                Fields.RETURN_REASON: reason,
                Fields.ITEMS: [
                    {
                        Fields.PRODUCT_ID: prod["pid"],
                        Fields.NAME: prod["name"],
                        Fields.QUANTITY: 1,
                        Fields.PRICE: prod["price"],
                    }
                ],
                "refundAmountCents": int(prod["price"] * 100),
                Fields.CREATED_AT: _ago(days=5),
                Fields.UPDATED_AT: _ago(days=1),
            },
            label=f"return/{rid} [{status}]",
        )


# ─────────────────────────────────────────────────────────────────────────────
# FAVORITES & CART (for admin)
# ─────────────────────────────────────────────────────────────────────────────
def seed_favorites_and_cart(db: firestore.Client) -> None:
    """Function seed_favorites_and_cart."""
    print("\n── Favorites & Cart (admin) ───────────────────────────")
    fav_pids = [p["pid"] for p in PRODUCTS if p.get("lifecycle") == ProductLifecycleStatusValues.ACTIVE][:15]
    fav_coll = db.collection(Collections.USERS).document(ADMIN_UID).collection(Collections.FAVORITES)
    for pid in fav_pids:
        _get_or_set(
            fav_coll.document(pid),
            {Fields.PRODUCT_ID: pid, Fields.DATE_FAVORITED: _ago(days=random.randint(1, 30))},
            label=f"fav/{pid}",
        )

    # Cart — 3 physical products
    cart_pids = [p["pid"] for p in PRODUCTS if not p.get("is_digital") and p.get("lifecycle") == ProductLifecycleStatusValues.ACTIVE][:3]
    cart_coll = db.collection(Collections.USERS).document(ADMIN_UID).collection(Collections.CART)
    for pid in cart_pids:
        prod = next(p for p in PRODUCTS if p["pid"] == pid)
        seller = SELLERS[prod["seller_idx"]]
        _get_or_set(
            cart_coll.document(pid),
            {
                Fields.PRODUCT_ID: pid,
                Fields.NAME: prod["name"],
                Fields.PRICE: prod["price"],
                Fields.QUANTITY: 1,
                Fields.IMAGE_URLS: [IMGS[hash(pid) % len(IMGS)]],
                Fields.SELLER_ID: seller["uid"],
                Fields.IS_DIGITAL: False,
                Fields.ADDED_AT if hasattr(Fields, "ADDED_AT") else "addedAt": _ago(hours=2),
            },
            label=f"cart/{pid}",
        )


# ─────────────────────────────────────────────────────────────────────────────
# COUPONS
# ─────────────────────────────────────────────────────────────────────────────
def seed_coupons(db: firestore.Client) -> None:
    """Function seed_coupons."""
    print("\n── Coupons ────────────────────────────────────────────")
    coupons = [
        {
            "id": f"{PREFIX}coupon_percent10",
            Fields.COUPON_CODE: "WELCOME10",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT,
            Fields.DISCOUNT_VALUE: 10.0,
            "minOrderCents": 2000,
            "maxUsesTotal": 1000,
            "maxUsesPerUser": 1,
            "usesCount": 42,
            "active": True,
            "expiresAt": _now() + datetime.timedelta(days=60),
            Fields.CREATED_AT: _ago(days=30),
            "createdBy": ADMIN_UID,
            "description": "10% off your first order (min $20)",
        },
        {
            "id": f"{PREFIX}coupon_fixed5",
            Fields.COUPON_CODE: "SAVE5NOW",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.FIXED_CENTS,
            Fields.DISCOUNT_VALUE: 500.0,
            "minOrderCents": 3000,
            "maxUsesTotal": 500,
            "maxUsesPerUser": 2,
            "usesCount": 128,
            "active": True,
            "expiresAt": _now() + datetime.timedelta(days=30),
            Fields.CREATED_AT: _ago(days=15),
            "createdBy": ADMIN_UID,
            "description": "$5 off orders over $30",
        },
        {
            "id": f"{PREFIX}coupon_expired",
            Fields.COUPON_CODE: "EXPIRED20",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT,
            Fields.DISCOUNT_VALUE: 20.0,
            "minOrderCents": 5000,
            "maxUsesTotal": 100,
            "maxUsesPerUser": 1,
            "usesCount": 100,
            "active": False,
            "expiresAt": _ago(days=10),
            Fields.CREATED_AT: _ago(days=60),
            "createdBy": ADMIN_UID,
            "description": "EXPIRED — 20% off $50+ (for testing expired state)",
        },
    ]
    for c in coupons:
        cid = c.pop("id")
        _get_or_set(db.collection(Collections.COUPONS).document(cid), c, label=f"coupon/{cid}")


# ─────────────────────────────────────────────────────────────────────────────
# SELLER METRICS
# ─────────────────────────────────────────────────────────────────────────────
def seed_seller_metrics(db: firestore.Client) -> None:
    """Function seed_seller_metrics."""
    print("\n── Seller Metrics ─────────────────────────────────────")
    for s in SELLERS[:3]:
        uid = s["uid"]
        mid = f"{PREFIX}metrics_{uid.split('_')[-1]}"
        _get_or_set(
            db.collection(Collections.SELLER_METRICS).document(uid),
            {
                Fields.SELLER_ID: uid,
                "totalOrders": random.randint(50, 500),
                "totalRevenueCents": random.randint(500_000, 5_000_000),
                "averageRating": round(random.uniform(4.0, 5.0), 1),
                "totalReviews": random.randint(20, 300),
                "disputeRate": round(random.uniform(0.0, 0.02), 4),
                "refundRate": round(random.uniform(0.01, 0.05), 4),
                "fulfillmentRate": round(random.uniform(0.95, 1.0), 4),
                "avgShipTimeDays": round(random.uniform(1.0, 3.0), 1),
                "activeProducts": random.randint(5, 50),
                "lastComputedAt": _ago(hours=1),
                Fields.UPDATED_AT: _ago(hours=1),
            },
            label=f"metrics/{uid}",
        )


# ─────────────────────────────────────────────────────────────────────────────
# LICENSES (for digital products already purchased)
# ─────────────────────────────────────────────────────────────────────────────
def seed_licenses(db: firestore.Client) -> None:
    """Function seed_licenses."""
    print("\n── Licenses ───────────────────────────────────────────")
    licenses = [
        {
            "key": "REDACTED_SECRET",
            "productId": f"{PREFIX}prod_digital_sw_1",
            "userId": ADMIN_UID,
            "orderId": f"{PREFIX}o_digital_2",
            "digitalType": DigitalTypeValues.SOFTWARE,
            "status": "active",
            "activatedAt": _ago(days=7),
            "deviceId": "dev_mseed_admin_macbook",
            "platform": "macos",
        },
        {
            "key": "REDACTED_SECRET",
            "productId": f"{PREFIX}prod_digital_book_1",
            "userId": ADMIN_UID,
            "orderId": f"{PREFIX}o_digital_1",
            "digitalType": DigitalTypeValues.BOOK,
            "status": "active",
            "activatedAt": _ago(days=12),
            "deviceId": "dev_mseed_admin_ipad",
            "platform": "macos",
        },
    ]
    for lic in licenses:
        key = lic["key"]
        _get_or_set(
            db.collection(Collections.LICENSES).document(key),
            {
                Fields.LICENSE_KEY: key,
                Fields.PRODUCT_ID: lic["productId"],
                Fields.USER_ID: lic["userId"],
                Fields.ORDER_ID: lic["orderId"],
                Fields.DIGITAL_TYPE: lic["digitalType"],
                "licenseStatus": lic["status"],
                "activatedAt": lic["activatedAt"],
                "deviceId": lic["deviceId"],
                "platform": lic["platform"],
                "digitalBuilds": {
                    "macos": "https://downloads.orignagta.ca/mseed/build/macos.dmg",
                    "windows": "https://downloads.orignagta.ca/mseed/build/windows.exe",
                },
                Fields.CREATED_AT: lic["activatedAt"],
            },
            label=f"license/{key}",
        )


# ─────────────────────────────────────────────────────────────────────────────
# ADMIN USER — ensure doc has all fields
# ─────────────────────────────────────────────────────────────────────────────
def ensure_admin_user(db: firestore.Client) -> None:
    """Function ensure_admin_user."""
    print("\n── Admin User ──────────────────────────────────────────")
    ref = db.collection(Collections.USERS).document(ADMIN_UID)
    doc = ref.get()
    if not doc.exists:
        ref.set({
            Fields.UID: ADMIN_UID,
            Fields.EMAIL: ADMIN_EMAIL,
            Fields.NAME: "Yunior Rodriguez",
            Fields.ROLES: [UserRoleValues.BUYER, UserRoleValues.SELLER, UserRoleValues.ADMIN],
            Fields.CREATED_AT: _ago(days=180),
            Fields.UPDATED_AT: _now(),
            Fields.IS_PREMIUM: True,
            Fields.EMAIL_CONSENT: True,
            Fields.MARKETING_OPT_IN: False,
            Fields.DATA_PROCESSING_CONSENT: True,
        })
        print("  ✅  created admin user doc")
    else:
        # Patch to ensure admin/seller roles and premium
        ref.update({
            Fields.ROLES: [UserRoleValues.BUYER, UserRoleValues.SELLER, UserRoleValues.ADMIN],
            Fields.IS_PREMIUM: True,
            Fields.PAYOUTS_ENABLED: True,
            Fields.CHARGES_ENABLED: True,
            Fields.ONBOARDING_COMPLETED: True,
            Fields.STRIPE_ACCOUNT_ID: "acct_mseed_admin",
        })
        print("  ✅  patched admin user doc (roles + premium)")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
def main() -> int:
    """Function main."""
    parser = argparse.ArgumentParser(description="Mega seed dev Firebase for QA")
    parser.add_argument("--project", default="orignagta-dev")
    parser.add_argument("--allow-prod", action="store_true", help="Allow seeding prod (DANGEROUS)")
    args = parser.parse_args()

    if args.project == "orignagta" and not args.allow_prod:
        print("❌  Refusing to seed prod. Pass --allow-prod if you are 100% sure.")
        return 1

    import firebase_admin
    from firebase_admin import credentials, firestore as fb_firestore

    cred = credentials.ApplicationDefault()
    try:
        app = firebase_admin.get_app()
    except ValueError:
        app = firebase_admin.initialize_app(cred, {"projectId": args.project})

    db: firestore.Client = fb_firestore.client()

    print(f"\n🌱  Mega Seed → {args.project}\n")

    ensure_admin_user(db)
    seed_sellers(db)
    seed_products(db)
    seed_reviews(db)
    seed_orders(db)
    seed_return_requests(db)
    seed_favorites_and_cart(db)
    seed_coupons(db)
    seed_seller_metrics(db)
    seed_licenses(db)

    print(f"""
╔══════════════════════════════════════════════════════════╗
║  ✅  Mega Seed Complete — {args.project}
║
║  Sellers:         {len(SELLERS)} (5 sellers, 1 incomplete onboarding)
║  Products:        {len(PRODUCTS)} (active, under_review, draft, paused, rejected, archived)
║  Orders:          {len(ORDER_SPECS)} (every status: pending→disputed)
║  Return requests: 3 (requested, approved, refunded)
║  Favorites:       15 products for admin
║  Cart:            3 items for admin
║  Coupons:         3 (active %, active $, expired)
║  Seller metrics:  3 sellers
║  Licenses:        2 (software + book)
║
║  Admin login: yr62813@gmail.com
╚══════════════════════════════════════════════════════════╝
""")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
