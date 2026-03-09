#!/usr/bin/env python3
"""
Seed Mockup Products — Creates 20 realistic Canadian marketplace products
in the Firestore emulator for UI testing.

Usage: python3 e2e/scripts/seed/seed_mockup_products.py

Requires: requests (pip install requests)
Emulator must be running on localhost:8080 (Firestore) and localhost:9099 (Auth).
"""

import requests
import uuid
from datetime import datetime, timedelta
import random

# =============================================================================
# EMULATOR CONFIG
# =============================================================================
FIRESTORE_PORT = 8080
AUTH_PORT = 9099
PROJECT = "orignagta"

FIRESTORE_BASE = f"http://localhost:{FIRESTORE_PORT}/v1/projects/{PROJECT}/databases/(default)/documents"
AUTH_BASE = f"http://localhost:{AUTH_PORT}"

TARGET_EMAIL = "yr62813@gmail.com"

# =============================================================================
# FIRESTORE REST API HELPERS (same pattern as seed-orders.py)
# =============================================================================

def sv(val):
    """String value."""
    return {"stringValue": str(val)}

def iv(val):
    """Integer value."""
    return {"integerValue": str(int(val))}

def fv(val):
    """Double/float value."""
    return {"doubleValue": float(val)}

def bv(val):
    """Boolean value."""
    return {"booleanValue": bool(val)}

def av(items):
    """Array value."""
    return {"arrayValue": {"values": items}}

def ts(dt=None):
    """Timestamp value."""
    if dt is None:
        dt = datetime.utcnow()
    return {"timestampValue": dt.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"}

def mv(fields):
    """Map value."""
    return {"mapValue": {"fields": fields}}

def nv():
    """Null value."""
    return {"nullValue": None}


# =============================================================================
# LOOKUP USER UID FROM AUTH EMULATOR
# =============================================================================

def get_uid_for_email(email: str) -> str | None:
    """Look up a user's UID from the Auth emulator by email."""
    url = f"{AUTH_BASE}/identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:lookup"
    # Try the emulator's list endpoint
    accounts_url = f"{AUTH_BASE}/identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts"
    try:
        # Method 1: Query by email via sign-in lookup
        r = requests.post(
            f"{AUTH_BASE}/identitytoolkit.googleapis.com/v1/accounts:lookup",
            json={"email": [email]},
            params={"key": "fake-api-key"},
        )
        if r.status_code == 200:
            data = r.json()
            if "users" in data:
                for user in data["users"]:
                    if user.get("email") == email:
                        return user["localId"]
    except Exception:
        pass

    # Method 2: List all users and filter
    try:
        r = requests.get(
            f"{AUTH_BASE}/emulator/v1/projects/{PROJECT}/accounts",
            params={"pageSize": 1000},
        )
        if r.status_code == 200:
            data = r.json()
            for user in data.get("userInfo", []):
                if user.get("email") == email:
                    return user["localId"]
    except Exception:
        pass

    return None


# =============================================================================
# CREATE PRODUCT DOCUMENT VIA FIRESTORE REST API
# =============================================================================

def create_product(doc_id: str, fields: dict):
    """Write a product document to the emulator Firestore."""
    url = f"{FIRESTORE_BASE}/products/{doc_id}"
    payload = {"fields": fields}
    headers = {"Authorization": "Bearer owner"}
    r = requests.patch(url, json=payload, headers=headers)
    if r.status_code in (200, 201):
        return True
    else:
        print(f"  ❌ Failed {doc_id}: {r.status_code} — {r.text[:300]}")
        return False


# =============================================================================
# ALSO ENSURE THE USER DOC EXISTS (seller role needed)
# =============================================================================

def ensure_user_is_seller(uid: str, email: str):
    """Make sure the user document in Firestore has seller role."""
    url = f"{FIRESTORE_BASE}/users/{uid}"
    headers = {"Authorization": "Bearer owner"}
    # Check if user doc exists
    r = requests.get(url, headers=headers)
    if r.status_code == 200:
        existing = r.json()
        fields = existing.get("fields", {})
        roles = fields.get("roles", {}).get("arrayValue", {}).get("values", [])
        role_strings = [v.get("stringValue", "") for v in roles]
        if "seller" not in role_strings:
            role_strings.append("seller")
            fields["roles"] = av([sv(role) for role in role_strings])
            requests.patch(url, json={"fields": fields}, headers=headers)
            print(f"  🔧 Added 'seller' role to {email}")
        else:
            print(f"  ✅ User {email} already has seller role")
    else:
        # Create user doc with seller+buyer roles
        fields = {
            "uid": sv(uid),
            "email": sv(email),
            "name": sv("Test Seller"),
            "roles": av([sv("buyer"), sv("seller")]),
            "createdAt": ts(),
            "suspended": bv(False),
            "onboardingCompleted": bv(True),
            "payoutsEnabled": bv(True),
            "chargesEnabled": bv(True),
            "stripeAccountId": sv("acct_test_mock_seller"),
            "commissionRate": fv(0.025),
        }
        r2 = requests.patch(url, json={"fields": fields}, headers=headers)
        if r2.status_code in (200, 201):
            print(f"  ✅ Created user doc for {email} with seller role")
        else:
            print(f"  ❌ Failed to create user doc: {r2.status_code}")


# =============================================================================
# PRODUCT DATA — 20 diverse Canadian marketplace products
# =============================================================================

def build_address(street, city, province, postal_code, lat, lng):
    """Build a Firestore address map."""
    return mv({
        "street": sv(street),
        "apartment": sv(""),
        "city": sv(city),
        "state": sv(province),
        "postalCode": sv(postal_code),
        "country": sv("Canada"),
        "phoneNumber": sv("6135551234"),
        "isDefault": bv(True),
        "label": sv("Business"),
        "latitude": fv(lat),
        "longitude": fv(lng),
    })

def build_delivery_options(free_shipping=False):
    """Build standard delivery options array."""
    opts = [
        mv({
            "type": sv("standard"),
            "description": sv("Standard Shipping (5-7 business days)"),
            "cost": fv(0.0 if free_shipping else 9.99),
            "estimatedDays": iv(7),
            "quantityDiscounts": av([]),
            "maxItemsPerShipment": iv(0),
            "additionalItemCost": fv(0),
            "availableInternational": bv(False),
        }),
        mv({
            "type": sv("express"),
            "description": sv("Express Shipping (2-3 business days)"),
            "cost": fv(4.99 if free_shipping else 19.99),
            "estimatedDays": iv(3),
            "quantityDiscounts": av([]),
            "maxItemsPerShipment": iv(0),
            "additionalItemCost": fv(0),
            "availableInternational": bv(False),
        }),
    ]
    return av(opts)


PRODUCTS = [
    # === ELECTRONICS (categoryId: 1) ===
    {
        "name": "Samsung Galaxy Buds3 Pro — Wireless ANC Earbuds",
        "price": 329.99,
        "description": "Premium wireless earbuds with adaptive noise cancellation, 360 Audio, and up to 30 hours of battery life with the charging case. IPX7 water resistant. Perfect for commuting on the TTC or working from home. Includes USB-C charging cable and extra ear tips.",
        "categoryId": 1,
        "stockQuantity": 45,
        "keywords": ["samsung", "galaxy buds", "earbuds", "wireless", "anc", "noise cancelling", "bluetooth", "audio"],
        "city": "Toronto", "province": "ON", "postalCode": "M5V 3A8",
        "street": "220 Yonge St", "lat": 43.6532, "lng": -79.3832,
        "weightKg": 0.15, "freeShipping": False,
        "images": [
            "https://picsum.photos/seed/galaxybuds/600/600",
            "https://picsum.photos/seed/galaxybuds2/600/600",
        ],
    },
    {
        "name": "Apple AirPods Max — Over-Ear Headphones (Midnight)",
        "price": 779.00,
        "description": "High-fidelity audio with Apple's custom-designed driver delivers immersive sound. Active Noise Cancellation, Transparency mode, spatial audio with dynamic head tracking. The breathable knit mesh canopy and memory foam ear cushions ensure premium comfort for long listening sessions.",
        "categoryId": 1,
        "stockQuantity": 12,
        "keywords": ["apple", "airpods max", "headphones", "over-ear", "anc", "spatial audio", "premium"],
        "city": "Vancouver", "province": "BC", "postalCode": "V6B 1A1",
        "street": "701 W Georgia St", "lat": 49.2827, "lng": -123.1207,
        "weightKg": 0.385, "freeShipping": True,
        "images": [
            "https://picsum.photos/seed/airpodsmax/600/600",
            "https://picsum.photos/seed/airpodsmax2/600/600",
        ],
    },
    # === COMPUTERS (categoryId: 2) ===
    {
        "name": "ASUS ROG Strix 16\" Gaming Laptop — RTX 4070, 32GB RAM",
        "price": 2499.99,
        "description": "Powerful gaming laptop featuring Intel i9-13980HX, NVIDIA RTX 4070 8GB, 32GB DDR5, 1TB NVMe SSD. 16\" QHD 240Hz display. Per-key RGB keyboard. ROG Intelligent Cooling with liquid metal. Perfect for gaming and content creation.",
        "categoryId": 2,
        "stockQuantity": 8,
        "keywords": ["asus", "rog", "gaming laptop", "rtx 4070", "laptop", "computer", "i9"],
        "city": "Montreal", "province": "QC", "postalCode": "H3B 1A1",
        "street": "1001 Rue Sainte-Catherine O", "lat": 45.5017, "lng": -73.5673,
        "weightKg": 2.5, "freeShipping": True,
        "images": [
            "https://picsum.photos/seed/roglaptop/600/600",
            "https://picsum.photos/seed/roglaptop2/600/600",
            "https://picsum.photos/seed/roglaptop3/600/600",
        ],
    },
    # === GAMING (categoryId: 3) ===
    {
        "name": "PlayStation 5 Slim — Digital Edition Bundle",
        "price": 579.99,
        "description": "The PS5 Slim Digital Edition with an extra DualSense controller and 12-month PS Plus subscription. Experience lightning-fast loading with the custom SSD, adaptive triggers, and haptic feedback. 1TB storage. Includes vertical stand.",
        "categoryId": 3,
        "stockQuantity": 20,
        "keywords": ["ps5", "playstation", "sony", "gaming", "console", "dualsense", "digital"],
        "city": "Calgary", "province": "AB", "postalCode": "T2P 1H7",
        "street": "317 7 Ave SW", "lat": 51.0447, "lng": -114.0719,
        "weightKg": 3.2, "freeShipping": False,
        "images": [
            "https://picsum.photos/seed/ps5slim/600/600",
            "https://picsum.photos/seed/ps5slim2/600/600",
        ],
    },
    # === HOME & KITCHEN (categoryId: 4) ===
    {
        "name": "Breville Barista Express Espresso Machine",
        "price": 899.99,
        "description": "Professional-grade espresso at home. Built-in conical burr grinder, precise digital temperature control, 15-bar Italian pump. Includes steam wand for microfoam milk texturing. Stainless steel housing. Makes café-quality lattes and cappuccinos. Perfect for Canada's cold mornings!",
        "categoryId": 4,
        "stockQuantity": 15,
        "keywords": ["breville", "espresso", "coffee", "barista", "machine", "grinder", "kitchen"],
        "city": "Ottawa", "province": "ON", "postalCode": "K1P 1J1",
        "street": "50 Rideau St", "lat": 45.4215, "lng": -75.6972,
        "weightKg": 10.5, "freeShipping": True,
        "images": [
            "https://picsum.photos/seed/breville/600/600",
            "https://picsum.photos/seed/breville2/600/600",
        ],
    },
    {
        "name": "Le Creuset Dutch Oven 5.3L — Flame Orange",
        "price": 449.00,
        "description": "Iconic Le Creuset enameled cast iron Dutch oven in signature Flame orange. 5.3-litre capacity perfect for soups, stews, and braised dishes. Even heat distribution and superior heat retention. Oven safe to 260°C. Lifetime warranty. Made in France.",
        "categoryId": 4,
        "stockQuantity": 22,
        "keywords": ["le creuset", "dutch oven", "cast iron", "cookware", "kitchen", "pot", "cooking"],
        "city": "Winnipeg", "province": "MB", "postalCode": "R3C 0V8",
        "street": "201 Portage Ave", "lat": 49.8951, "lng": -97.1384,
        "weightKg": 5.2, "freeShipping": False,
        "images": [
            "https://picsum.photos/seed/lecreuset/600/600",
        ],
    },
    # === FASHION (categoryId: 5) ===
    {
        "name": "Canada Goose Expedition Parka — Black Label",
        "price": 1549.99,
        "description": "The ultimate Canadian winter parka. Rated for -30°C and colder. Features 625-fill power duck down, removable coyote fur ruff, fleece-lined chin guard, and multiple interior pockets. TEI 5 — Extreme cold weather. Iconic Canadian-made outerwear.",
        "categoryId": 5,
        "stockQuantity": 10,
        "keywords": ["canada goose", "parka", "winter", "jacket", "coat", "expedition", "down", "warm"],
        "city": "Toronto", "province": "ON", "postalCode": "M5H 2N2",
        "street": "100 Queen St W", "lat": 43.6529, "lng": -79.3849,
        "weightKg": 2.1, "freeShipping": True,
        "images": [
            "https://picsum.photos/seed/canadagoose/600/600",
            "https://picsum.photos/seed/canadagoose2/600/600",
        ],
    },
    {
        "name": "Lululemon Align High-Rise Leggings 25\" — Dark Olive",
        "price": 128.00,
        "description": "Buttery soft Nulu™ fabric feels weightless for low-impact workouts and everyday wear. Four-way stretch, sweat-wicking, and incredibly comfortable. High-rise waistband lies flat against your skin. Hidden waistband pocket. Made for yoga, pilates, and casual wear.",
        "categoryId": 5,
        "stockQuantity": 60,
        "keywords": ["lululemon", "leggings", "align", "yoga", "workout", "athleisure", "women"],
        "city": "Vancouver", "province": "BC", "postalCode": "V6E 1B2",
        "street": "2113 W 4th Ave", "lat": 49.2672, "lng": -123.1586,
        "weightKg": 0.22, "freeShipping": False,
        "images": [
            "https://picsum.photos/seed/lululemon/600/600",
            "https://picsum.photos/seed/lululemon2/600/600",
        ],
    },
    # === SHOES & ACCESSORIES (categoryId: 6) ===
    {
        "name": "Nike Air Max 90 — University Red / White",
        "price": 179.99,
        "description": "The iconic Nike Air Max 90 with visible Max Air unit in the heel. Premium leather and mesh upper. Rubber Waffle outsole for excellent traction. University Red colourway. A true classic since 1990. Men's sizing.",
        "categoryId": 6,
        "stockQuantity": 35,
        "keywords": ["nike", "air max", "shoes", "sneakers", "running", "red", "men"],
        "city": "Edmonton", "province": "AB", "postalCode": "T5J 2R7",
        "street": "10180 101 St NW", "lat": 53.5461, "lng": -113.4938,
        "weightKg": 0.8, "freeShipping": False,
        "images": [
            "https://picsum.photos/seed/nikeam90/600/600",
            "https://picsum.photos/seed/nikeam902/600/600",
        ],
    },
    # === BEAUTY & PERSONAL CARE (categoryId: 8) ===
    {
        "name": "Dyson Airwrap Complete Long — Nickel/Copper",
        "price": 699.99,
        "description": "The Dyson Airwrap multi-styler for long hair. Uses the Coanda effect to curl, wave, smooth, and dry — with no extreme heat damage. Includes 6 attachments: barrels, brushes, and dryer. Intelligent heat control up to 150°C. Flight-ready storage case included.",
        "categoryId": 8,
        "stockQuantity": 18,
        "keywords": ["dyson", "airwrap", "hair styler", "curler", "dryer", "beauty", "styling"],
        "city": "Montreal", "province": "QC", "postalCode": "H2X 1L4",
        "street": "900 Rue Sherbrooke O", "lat": 45.5088, "lng": -73.5748,
        "weightKg": 0.67, "freeShipping": True,
        "images": [
            "https://picsum.photos/seed/dysonairwrap/600/600",
            "https://picsum.photos/seed/dysonairwrap2/600/600",
        ],
    },
    # === SPORTS & FITNESS (categoryId: 10) ===
    {
        "name": "Peloton Bike+ with 24\" Rotating HD Touchscreen",
        "price": 3295.00,
        "description": "The premium at-home cycling experience. 24\" rotating HD touchscreen lets you take classes on and off the bike. Auto-follow resistance technology, Apple GymKit integration, and 4-channel audio. Stream thousands of live and on-demand classes. Includes cycling shoes and weights.",
        "categoryId": 10,
        "stockQuantity": 5,
        "keywords": ["peloton", "bike", "cycling", "fitness", "exercise", "home gym", "spin"],
        "city": "Toronto", "province": "ON", "postalCode": "M4W 1A8",
        "street": "2300 Yonge St", "lat": 43.7084, "lng": -79.3985,
        "weightKg": 63.5, "freeShipping": True,
        "images": [
            "https://picsum.photos/seed/peloton/600/600",
            "https://picsum.photos/seed/peloton2/600/600",
        ],
    },
    {
        "name": "Bauer Vapor Hyperlite2 Ice Hockey Skates — Senior",
        "price": 1099.99,
        "description": "Top-of-the-line hockey skates. AEROFOAM+ memory foam liner for custom fit. Carbon CURV composite boot for lightweight strength. PULSE TI steel runners. LS Pulse edge holder. Designed for elite-level performance on Canadian ice. Senior size 9D.",
        "categoryId": 10,
        "stockQuantity": 14,
        "keywords": ["bauer", "hockey", "skates", "vapor", "ice hockey", "senior", "sports", "winter"],
        "city": "Quebec City", "province": "QC", "postalCode": "G1R 4P5",
        "street": "250 Boul Wilfrid-Hamel", "lat": 46.8139, "lng": -71.2080,
        "weightKg": 1.8, "freeShipping": False,
        "images": [
            "https://picsum.photos/seed/bauerskates/600/600",
            "https://picsum.photos/seed/bauerskates2/600/600",
        ],
    },
    # === TOOLS & HARDWARE (categoryId: 12) ===
    {
        "name": "DeWalt 20V MAX Drill/Driver Combo Kit (5-Tool)",
        "price": 549.99,
        "description": "Complete 5-tool cordless combo kit: drill/driver, impact driver, reciprocating saw, circular saw, and LED work light. Two 20V MAX 2.0Ah lithium-ion batteries, charger, and contractor bag included. Compact and lightweight design for tight spaces.",
        "categoryId": 12,
        "stockQuantity": 25,
        "keywords": ["dewalt", "drill", "tools", "power tools", "combo kit", "cordless", "hardware"],
        "city": "Hamilton", "province": "ON", "postalCode": "L8P 4S6",
        "street": "100 King St W", "lat": 43.2557, "lng": -79.8711,
        "weightKg": 8.5, "freeShipping": False,
        "images": [
            "https://picsum.photos/seed/dewalt/600/600",
            "https://picsum.photos/seed/dewalt2/600/600",
        ],
    },
    # === BOOKS (categoryId: 14) ===
    {
        "name": "The Handmaid's Tale — Margaret Atwood (Hardcover)",
        "price": 29.99,
        "description": "The classic Canadian dystopian novel by Margaret Atwood. Set in the near future, the Republic of Gilead offers Offred only one function: to breed. Beautifully bound hardcover special edition with new introduction by the author. A must-read work of Canadian literature.",
        "categoryId": 14,
        "stockQuantity": 100,
        "keywords": ["book", "margaret atwood", "handmaids tale", "canadian", "fiction", "dystopian", "novel"],
        "city": "Victoria", "province": "BC", "postalCode": "V8W 1N3",
        "street": "1105 Government St", "lat": 48.4284, "lng": -123.3656,
        "weightKg": 0.45, "freeShipping": False,
        "images": [
            "https://picsum.photos/seed/handmaidstale/600/600",
        ],
    },
    # === TOYS & GAMES (categoryId: 16) ===
    {
        "name": "LEGO Technic McLaren P1 — 3893 Pieces",
        "price": 579.99,
        "description": "Build the iconic McLaren P1 hypercar in stunning detail. 3,893 pieces with working V8 engine, dihedral doors, and active rear wing. 1:8 scale. Over 59cm long. A challenging build for adult LEGO enthusiasts. Includes display stand and collector's booklet.",
        "categoryId": 16,
        "stockQuantity": 7,
        "keywords": ["lego", "technic", "mclaren", "car", "building", "model", "toy", "adult"],
        "city": "Mississauga", "province": "ON", "postalCode": "L5B 1M2",
        "street": "100 City Centre Dr", "lat": 43.5890, "lng": -79.6441,
        "weightKg": 4.1, "freeShipping": True,
        "images": [
            "https://picsum.photos/seed/legomclaren/600/600",
            "https://picsum.photos/seed/legomclaren2/600/600",
        ],
    },
    # === PET SUPPLIES (categoryId: 18) ===
    {
        "name": "PetSafe ScoopFree Ultra Self-Cleaning Litter Box",
        "price": 229.99,
        "description": "Say goodbye to scooping! The ScoopFree Ultra automatically rakes waste 5, 10, or 20 minutes after your cat uses it. Crystal litter absorbs urine and dries solid waste. Disposable trays for easy cleanup. Privacy hood included. Covers odours 5x better than clumping clay.",
        "categoryId": 18,
        "stockQuantity": 30,
        "keywords": ["pet", "cat", "litter box", "self-cleaning", "automatic", "petsafe"],
        "city": "Saskatoon", "province": "SK", "postalCode": "S7K 1J5",
        "street": "201 1 Ave S", "lat": 52.1332, "lng": -106.6700,
        "weightKg": 5.5, "freeShipping": False,
        "images": [
            "https://picsum.photos/seed/litterbox/600/600",
        ],
    },
    # === HEALTH & WELLNESS (categoryId: 9) ===
    {
        "name": "Theragun PRO Plus — Smart Percussive Therapy Device",
        "price": 599.99,
        "description": "The most advanced Theragun ever. Features a brushless motor with QuietForce Technology™, Bluetooth app connectivity, customizable speed range (1750-2400 PPM), OLED screen, and ergonomic multi-grip design. 6 attachments included. 300-minute battery life. Perfect for Canadian athletes.",
        "categoryId": 9,
        "stockQuantity": 20,
        "keywords": ["theragun", "massage", "percussive", "therapy", "recovery", "muscle", "fitness", "health"],
        "city": "Halifax", "province": "NS", "postalCode": "B3J 1T9",
        "street": "5670 Spring Garden Rd", "lat": 44.6488, "lng": -63.5752,
        "weightKg": 1.3, "freeShipping": True,
        "images": [
            "https://picsum.photos/seed/theragun/600/600",
            "https://picsum.photos/seed/theragun2/600/600",
        ],
    },
    # === JEWELRY & WATCHES (categoryId: 7) ===
    {
        "name": "Tissot PRX Powermatic 80 — Ice Blue Dial",
        "price": 495.00,
        "description": "Swiss-made automatic watch with the iconic integrated bracelet design. 40mm stainless steel case, ice blue dial, sapphire crystal, and 80-hour power reserve. Water resistant to 100m. The perfect blend of 1970s design and modern Swiss watchmaking.",
        "categoryId": 7,
        "stockQuantity": 9,
        "keywords": ["tissot", "watch", "prx", "automatic", "swiss", "jewelry", "luxury", "blue"],
        "city": "Laval", "province": "QC", "postalCode": "H7T 1C8",
        "street": "3035 Boul Le Carrefour", "lat": 45.5616, "lng": -73.7532,
        "weightKg": 0.15, "freeShipping": True,
        "images": [
            "https://picsum.photos/seed/tissotprx/600/600",
            "https://picsum.photos/seed/tissotprx2/600/600",
        ],
    },
    # === DIGITAL PRODUCTS (categoryId: 21) ===
    {
        "name": "Adobe Creative Cloud — 1 Year Subscription (All Apps)",
        "price": 779.88,
        "description": "Full access to 20+ creative desktop and mobile apps including Photoshop, Illustrator, InDesign, Premiere Pro, After Effects, and more. 100GB cloud storage. Adobe Fonts and Adobe Portfolio included. Digital delivery — instant activation code via email.",
        "categoryId": 21,
        "stockQuantity": 999,
        "keywords": ["adobe", "creative cloud", "photoshop", "illustrator", "software", "digital", "subscription"],
        "city": "Ottawa", "province": "ON", "postalCode": "K2P 1L4",
        "street": "150 Elgin St", "lat": 45.4201, "lng": -75.6910,
        "weightKg": None, "freeShipping": True, "isDigital": True,
        "images": [
            "https://picsum.photos/seed/adobecc/600/600",
        ],
    },
    # === ART & COLLECTIBLES (categoryId: 20) ===
    {
        "name": "2024 Silver Maple Leaf 1 oz — Royal Canadian Mint",
        "price": 54.99,
        "description": "Official 1 oz .9999 fine silver bullion coin from the Royal Canadian Mint. Iconic maple leaf design with Queen Elizabeth II obverse. $5 CAD face value. Micro-engraved radial lines as a security feature. Comes in individual protective capsule. A classic Canadian collectible.",
        "categoryId": 20,
        "stockQuantity": 50,
        "keywords": ["silver", "coin", "maple leaf", "bullion", "rcm", "royal canadian mint", "collectible", "investment"],
        "city": "Charlottetown", "province": "PE", "postalCode": "C1A 1M8",
        "street": "134 Kent St", "lat": 46.2382, "lng": -63.1311,
        "weightKg": 0.04, "freeShipping": False,
        "images": [
            "https://picsum.photos/seed/silvercoin/600/600",
            "https://picsum.photos/seed/silvercoin2/600/600",
        ],
    },
]

# =============================================================================
# MAIN — SEED PRODUCTS
# =============================================================================

def main():
    """Function main."""
    print("=" * 60)
    print("🍁 OrignaGTA — Seed 20 Mockup Products")
    print("=" * 60)

    # Step 1: Verify emulator is running
    print("\n📡 Checking Firestore emulator...")
    try:
        r = requests.get(f"http://localhost:{FIRESTORE_PORT}/")
        if r.status_code != 200:
            print(f"  ⚠️  Firestore responded with status {r.status_code} (may still work)")
    except requests.ConnectionError:
        print(f"  ❌ Cannot connect to Firestore emulator on port {FIRESTORE_PORT}")
        print("     Run the emulator first: firebase emulators:start")
        return
    print(f"  ✅ Firestore emulator is running on port {FIRESTORE_PORT}")

    # Step 2: Look up UID for target email
    print(f"\n🔍 Looking up UID for {TARGET_EMAIL}...")
    seller_uid = get_uid_for_email(TARGET_EMAIL)
    if not seller_uid:
        print(f"  ❌ Could not find user with email {TARGET_EMAIL} in Auth emulator")
        print("     Creating a fallback UID...")
        seller_uid = "seed_seller_" + uuid.uuid4().hex[:12]
        print(f"  🆔 Using generated UID: {seller_uid}")
    else:
        print(f"  ✅ Found UID: {seller_uid}")

    # Step 3: Ensure user has seller role
    print("\n👤 Ensuring user has seller role...")
    ensure_user_is_seller(seller_uid, TARGET_EMAIL)

    # Step 4: Create 20 products
    print(f"\n📦 Creating {len(PRODUCTS)} products...\n")
    success_count = 0
    for i, p in enumerate(PRODUCTS, 1):
        doc_id = f"seed_product_{uuid.uuid4().hex[:12]}"

        # Randomize creation date: spread over last 30 days
        days_ago = random.randint(0, 30)
        hours_ago = random.randint(0, 23)
        created_dt = datetime.utcnow() - timedelta(days=days_ago, hours=hours_ago)

        is_digital = p.get("isDigital", False)

        fields = {
            "name": sv(p["name"]),
            "price": fv(p["price"]),
            "description": sv(p["description"]),
            "imageUrls": av([sv(url) for url in p["images"]]),
            "sellerId": sv(seller_uid),
            "sellerAddress": build_address(
                p["street"], p["city"], p["province"], p["postalCode"],
                p["lat"], p["lng"]
            ),
            "categoryId": iv(p["categoryId"]),
            "stockQuantity": iv(p["stockQuantity"]),
            "rating": fv(round(random.uniform(3.5, 5.0), 1)),
            "ratingCount": iv(random.randint(0, 150)),
            "keywords": av([sv(kw) for kw in p["keywords"]]),
            "isActive": bv(True),
            "createdAt": ts(created_dt),
            "isDigital": bv(is_digital),
            "isLocalDeliveryOnly": bv(False),
            "isPerishable": bv(False),
            "estimatedShipDays": iv(3 if not is_digital else 0),
            "deliveryOptions": build_delivery_options(p.get("freeShipping", False)),
            "minimumOrderQuantity": iv(1),
            "freeShipping": bv(p.get("freeShipping", False)),
            "status": sv("active"),
        }

        # Add weight only for physical products
        if p.get("weightKg") is not None:
            fields["weightKg"] = fv(p["weightKg"])

        ok = create_product(doc_id, fields)
        if ok:
            success_count += 1
            cat_name = get_category_name(p["categoryId"])
            print(f"  ✅ [{i:2d}/20] {p['name'][:50]}... — ${p['price']:.2f} CAD ({cat_name}, {p['city']})")
        else:
            print(f"  ❌ [{i:2d}/20] FAILED: {p['name'][:50]}")

    # Summary
    print(f"\n{'=' * 60}")
    print(f"🏁 Done! {success_count}/{len(PRODUCTS)} products created successfully.")
    print(f"   Seller UID: {seller_uid}")
    print(f"   Seller Email: {TARGET_EMAIL}")
    print("\n   🔗 View in Emulator UI: http://localhost:4000/firestore/data/products")
    print(f"{'=' * 60}")


def get_category_name(cat_id: int) -> str:
    """Map category ID to name."""
    categories = {
        1: "Electronics", 2: "Computers", 3: "Gaming",
        4: "Home & Kitchen", 5: "Fashion", 6: "Shoes & Accessories",
        7: "Jewelry & Watches", 8: "Beauty & Personal Care",
        9: "Health & Wellness", 10: "Sports & Fitness",
        11: "Automotive", 12: "Tools & Hardware",
        13: "Office Supplies", 14: "Books",
        15: "Music & Instruments", 16: "Toys & Games",
        17: "Baby & Kids", 18: "Pet Supplies",
        19: "Groceries", 20: "Art & Collectibles",
        21: "Digital Products",
    }
    return categories.get(cat_id, f"Category {cat_id}")


if __name__ == "__main__":
    main()
