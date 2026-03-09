#!/usr/bin/env python3
"""Clean Firestore products and re-seed with proper Timestamp types."""
import requests
import uuid
import random
from datetime import datetime, timedelta

FIRESTORE = "http://localhost:8080/v1/projects/orignagta/databases/(default)/documents"
HEADERS = {"Authorization": "Bearer owner"}

def delete_all_products():
    """Delete ALL products from the emulator."""
    print("🗑️  Deleting all existing products...")
    r = requests.get(f"{FIRESTORE}/products?pageSize=200", headers=HEADERS)
    docs = r.json().get("documents", [])
    count = 0
    for doc in docs:
        doc_path = doc["name"]
        # Extract just the relative path
        rel_path = doc_path.split("/databases/(default)/documents/")[-1]
        requests.delete(f"{FIRESTORE}/{rel_path}", headers=HEADERS)
        count += 1
    print(f"   Deleted {count} products")

def sv(val):
    """Function sv."""
    return {"stringValue": str(val)}
def iv(val):
    """Function iv."""
    return {"integerValue": str(int(val))}
def fv(val):
    """Function fv."""
    return {"doubleValue": float(val)}
def bv(val):
    """Function bv."""
    return {"booleanValue": bool(val)}
def av(items):
    """Function av."""
    return {"arrayValue": {"values": items}}
def nv():
    """Function nv."""
    return {"nullValue": None}
def mv(fields):
    """Function mv."""
    return {"mapValue": {"fields": fields}}

def ts(dt=None):
    """Timestamp value — MUST use timestampValue for proper Firestore ordering."""
    if dt is None:
        dt = datetime.utcnow()
    return {"timestampValue": dt.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"}

def build_address(street, city, province, postal_code, lat, lng):
    """Function build_address."""
    return mv({
        "street": sv(street),
        "apartment": sv(""),
        "city": sv(city),
        "state": sv(province),
        "postalCode": sv(postal_code),
        "country": sv("Canada"),
        "phoneNumber": sv("+16135551234"),
        "isDefault": bv(True),
        "label": sv("Business"),
        "latitude": fv(lat),
        "longitude": fv(lng),
    })

def build_delivery_options(free_shipping=False):
    """Function build_delivery_options."""
    return av([
        mv({
            "type": sv("standard"),
            "description": sv("Standard Shipping (5-7 business days)"),
            "cost": fv(0.0 if free_shipping else 9.99),
            "estimatedDays": iv(7),
        }),
        mv({
            "type": sv("express"),
            "description": sv("Express Shipping (2-3 business days)"),
            "cost": fv(4.99 if free_shipping else 19.99),
            "estimatedDays": iv(3),
        }),
    ])

PRODUCTS = [
    # ── Electronics (1) — 3 products ──
    {"name": "Samsung Galaxy Buds3 Pro — Wireless ANC Earbuds", "price": 329.99, "description": "Premium wireless earbuds with adaptive noise cancellation, 360 Audio, and up to 30 hours of battery life. IPX7 water resistant.", "categoryId": 1, "stock": 45, "keywords": ["samsung", "galaxy buds", "earbuds", "wireless", "anc"], "city": "Toronto", "prov": "ON", "pc": "M5V 3A8", "street": "220 Yonge St", "lat": 43.6532, "lng": -79.3832, "wkg": 0.15, "free": False, "imgs": ["https://picsum.photos/seed/buds3/600/600", "https://picsum.photos/seed/buds3b/600/600"]},
    {"name": "Apple AirPods Max — Over-Ear Headphones", "price": 779.00, "description": "High-fidelity audio with custom driver, Active Noise Cancellation, Transparency mode, spatial audio with dynamic head tracking.", "categoryId": 1, "stock": 12, "keywords": ["apple", "airpods", "headphones", "anc", "premium"], "city": "Vancouver", "prov": "BC", "pc": "V6B 1A1", "street": "701 W Georgia St", "lat": 49.2827, "lng": -123.1207, "wkg": 0.385, "free": True, "imgs": ["https://picsum.photos/seed/airmax1/600/600", "https://picsum.photos/seed/airmax2/600/600"]},
    {"name": "Sony WH-1000XM5 — Noise Cancelling Headphones", "price": 499.99, "description": "Industry-leading ANC with 30-hour battery, multipoint connection, speak-to-chat, and LDAC Hi-Res Audio.", "categoryId": 1, "stock": 30, "keywords": ["sony", "headphones", "anc", "wireless", "bluetooth"], "city": "Calgary", "prov": "AB", "pc": "T2P 3M9", "street": "317 7th Ave SW", "lat": 51.0460, "lng": -114.0708, "wkg": 0.25, "free": False, "imgs": ["https://picsum.photos/seed/sonyxm5/600/600", "https://picsum.photos/seed/sonyxm5b/600/600"]},

    # ── Computers (2) — 3 products ──
    {"name": "ASUS ROG Strix 16\" Gaming Laptop — RTX 4070", "price": 2499.99, "description": "16-inch 240Hz display, Intel i9-13980HX, 32GB DDR5 RAM, 1TB NVMe SSD, NVIDIA RTX 4070 8GB.", "categoryId": 2, "stock": 8, "keywords": ["asus", "rog", "laptop", "gaming", "rtx 4070"], "city": "Montreal", "prov": "QC", "pc": "H3B 1A2", "street": "1000 Rue de la Gauchetière", "lat": 45.5017, "lng": -73.5673, "wkg": 2.5, "free": True, "imgs": ["https://picsum.photos/seed/rogstrix/600/600", "https://picsum.photos/seed/rogstrix2/600/600"]},
    {"name": "MacBook Pro 14\" M3 Pro — Space Black", "price": 2799.00, "description": "Apple M3 Pro chip, 18GB unified memory, 512GB SSD, Liquid Retina XDR display, 17-hour battery life.", "categoryId": 2, "stock": 15, "keywords": ["apple", "macbook", "laptop", "m3", "pro"], "city": "Toronto", "prov": "ON", "pc": "M5H 2N2", "street": "1 Dundas St W", "lat": 43.6562, "lng": -79.3809, "wkg": 1.6, "free": True, "imgs": ["https://picsum.photos/seed/macbook14/600/600", "https://picsum.photos/seed/macbook14b/600/600"]},
    {"name": "Dell UltraSharp 27\" 4K USB-C Monitor — U2723QE", "price": 729.99, "description": "27-inch 4K IPS Black panel, USB-C 90W charging, 100% sRGB, VESA DisplayHDR 400, KVM switch built-in.", "categoryId": 2, "stock": 20, "keywords": ["dell", "monitor", "4k", "usb-c", "ultrasharp"], "city": "Ottawa", "prov": "ON", "pc": "K1P 5G3", "street": "111 Sussex Dr", "lat": 45.4215, "lng": -75.6972, "wkg": 6.6, "free": False, "imgs": ["https://picsum.photos/seed/dellu27/600/600", "https://picsum.photos/seed/dellu27b/600/600"]},

    # ── Gaming (3) — 3 products ──
    {"name": "PlayStation 5 Slim — Digital Edition Bundle", "price": 579.99, "description": "PS5 Slim Digital Edition with DualSense controller, 1TB SSD storage, 4K HDR gaming, and two included games.", "categoryId": 3, "stock": 25, "keywords": ["ps5", "playstation", "gaming", "console", "sony"], "city": "Calgary", "prov": "AB", "pc": "T2P 1J9", "street": "200 Barclay Parade SW", "lat": 51.0447, "lng": -114.0719, "wkg": 3.9, "free": False, "imgs": ["https://picsum.photos/seed/ps5slim/600/600", "https://picsum.photos/seed/ps5slim2/600/600"]},
    {"name": "Nintendo Switch OLED — White Joy-Con Bundle", "price": 449.99, "description": "7-inch vibrant OLED screen, 64GB internal storage, enhanced audio, wide adjustable stand. Tabletop & TV modes.", "categoryId": 3, "stock": 40, "keywords": ["nintendo", "switch", "oled", "gaming", "portable"], "city": "Winnipeg", "prov": "MB", "pc": "R3C 0V8", "street": "1 Forks Market Rd", "lat": 49.8880, "lng": -97.1300, "wkg": 0.9, "free": False, "imgs": ["https://picsum.photos/seed/switcholed/600/600", "https://picsum.photos/seed/switcholed2/600/600"]},
    {"name": "Xbox Elite Wireless Controller Series 2 — Core", "price": 179.99, "description": "Adjustable-tension thumbsticks, wrap-around rubberized grip, shorter hair trigger locks, 40-hour rechargeable battery.", "categoryId": 3, "stock": 35, "keywords": ["xbox", "controller", "elite", "gaming", "wireless"], "city": "Edmonton", "prov": "AB", "pc": "T5J 0K1", "street": "10220 103 Ave NW", "lat": 53.5461, "lng": -113.4938, "wkg": 0.35, "free": False, "imgs": ["https://picsum.photos/seed/xboxelite/600/600", "https://picsum.photos/seed/xboxelite2/600/600"]},

    # ── Home & Kitchen (4) — 3 products ──
    {"name": "Breville Barista Express Espresso Machine", "price": 899.99, "description": "Built-in conical burr grinder, dose control, steam wand for micro-foam milk. Italian-designed 15 bar pump.", "categoryId": 4, "stock": 15, "keywords": ["breville", "espresso", "coffee", "barista", "kitchen"], "city": "Ottawa", "prov": "ON", "pc": "K1P 5G3", "street": "111 Sussex Dr", "lat": 45.4215, "lng": -75.6972, "wkg": 10.5, "free": True, "imgs": ["https://picsum.photos/seed/breville/600/600", "https://picsum.photos/seed/breville2/600/600"]},
    {"name": "Le Creuset Dutch Oven 5.3L — Flame Orange", "price": 449.00, "description": "Iconic French enameled cast iron Dutch oven. Superior heat distribution and retention for slow cooking, braising, baking.", "categoryId": 4, "stock": 20, "keywords": ["le creuset", "dutch oven", "cast iron", "cooking", "kitchen"], "city": "Winnipeg", "prov": "MB", "pc": "R3C 0V8", "street": "1 Forks Market Rd", "lat": 49.8880, "lng": -97.1300, "wkg": 5.9, "free": False, "imgs": ["https://picsum.photos/seed/lecreuset/600/600", "https://picsum.photos/seed/lecreuset2/600/600"]},
    {"name": "Dyson V15 Detect Absolute Vacuum", "price": 949.99, "description": "Laser illumination reveals microscopic dust. Piezo sensor counts and sizes particles. LCD shows real-time data.", "categoryId": 4, "stock": 18, "keywords": ["dyson", "vacuum", "cordless", "home", "cleaning"], "city": "Toronto", "prov": "ON", "pc": "M4W 3R8", "street": "1 Bloor St E", "lat": 43.6702, "lng": -79.3860, "wkg": 3.1, "free": True, "imgs": ["https://picsum.photos/seed/dysonv15/600/600", "https://picsum.photos/seed/dysonv15b/600/600"]},

    # ── Fashion (5) — 3 products ──
    {"name": "Canada Goose Expedition Parka — Black Label", "price": 1549.99, "description": "Extreme weather parka rated to -30°C. Premium duck down, coyote fur ruff hood, TEI 5 rating.", "categoryId": 5, "stock": 10, "keywords": ["canada goose", "parka", "winter", "jacket", "fashion"], "city": "Toronto", "prov": "ON", "pc": "M5H 2N2", "street": "100 Queen St W", "lat": 43.6529, "lng": -79.3849, "wkg": 2.1, "free": True, "imgs": ["https://picsum.photos/seed/goose/600/600", "https://picsum.photos/seed/goose2/600/600"]},
    {"name": "Lululemon Align High-Rise Leggings 25\"", "price": 128.00, "description": "Buttery-soft Nulu fabric, high-rise waistband, 4-way stretch. Perfect for yoga, Pilates, and casual wear.", "categoryId": 5, "stock": 60, "keywords": ["lululemon", "leggings", "yoga", "activewear", "fashion"], "city": "Vancouver", "prov": "BC", "pc": "V6Z 2L2", "street": "2113 Main St", "lat": 49.2668, "lng": -123.1008, "wkg": 0.2, "free": False, "imgs": ["https://picsum.photos/seed/lulu/600/600", "https://picsum.photos/seed/lulu2/600/600"]},
    {"name": "Aritzia Super Puff — Matte Pearl", "price": 348.00, "description": "Iconic vegan puffer jacket with responsibly-sourced goose down. Water-repellent, oversized silhouette, recycled lining.", "categoryId": 5, "stock": 25, "keywords": ["aritzia", "puffer", "jacket", "winter", "fashion"], "city": "Vancouver", "prov": "BC", "pc": "V6B 1A1", "street": "701 W Georgia St", "lat": 49.2827, "lng": -123.1207, "wkg": 0.8, "free": False, "imgs": ["https://picsum.photos/seed/aritzia/600/600", "https://picsum.photos/seed/aritzia2/600/600"]},

    # ── Shoes & Accessories (6) — 3 products ──
    {"name": "Nike Air Max 90 — University Red / White", "price": 179.99, "description": "Classic silhouette with Nike Air cushioning, rubber waffle outsole, and premium leather upper.", "categoryId": 6, "stock": 30, "keywords": ["nike", "air max", "sneakers", "shoes", "running"], "city": "Edmonton", "prov": "AB", "pc": "T5J 0K1", "street": "10220 103 Ave NW", "lat": 53.5461, "lng": -113.4938, "wkg": 0.8, "free": False, "imgs": ["https://picsum.photos/seed/airmax90/600/600", "https://picsum.photos/seed/airmax902/600/600"]},
    {"name": "New Balance 550 — White / Green", "price": 159.99, "description": "Retro basketball-inspired sneaker with premium leather upper, ENCAP midsole cushioning, and rubber outsole.", "categoryId": 6, "stock": 42, "keywords": ["new balance", "550", "sneakers", "shoes", "retro"], "city": "Montreal", "prov": "QC", "pc": "H2Y 1C6", "street": "500 Rue Saint-Catherine O", "lat": 45.5048, "lng": -73.5719, "wkg": 0.75, "free": False, "imgs": ["https://picsum.photos/seed/nb550/600/600", "https://picsum.photos/seed/nb550b/600/600"]},
    {"name": "Blundstone Classic 550 — Walnut Brown", "price": 249.95, "description": "Iconic Chelsea boot with XRD® shock protection, SPS Max Comfort System, water-resistant premium leather.", "categoryId": 6, "stock": 20, "keywords": ["blundstone", "boots", "chelsea", "shoes", "leather"], "city": "Halifax", "prov": "NS", "pc": "B3J 1P3", "street": "1969 Upper Water St", "lat": 44.6488, "lng": -63.5752, "wkg": 1.1, "free": False, "imgs": ["https://picsum.photos/seed/blundstone/600/600", "https://picsum.photos/seed/blundstone2/600/600"]},

    # ── Jewelry & Watches (7) — 2 products ──
    {"name": "Tissot PRX Powermatic 80 — Ice Blue Dial", "price": 495.00, "description": "Swiss automatic movement with 80-hour power reserve. 40mm stainless steel case, integrated bracelet.", "categoryId": 7, "stock": 6, "keywords": ["tissot", "watch", "automatic", "swiss", "prx"], "city": "Laval", "prov": "QC", "pc": "H7T 1C8", "street": "3035 Boulevard le Carrefour", "lat": 45.5698, "lng": -73.7508, "wkg": 0.3, "free": False, "imgs": ["https://picsum.photos/seed/tissot/600/600", "https://picsum.photos/seed/tissot2/600/600"]},
    {"name": "Mejuri Bold Chain Necklace — 14K Gold Vermeil", "price": 128.00, "description": "Handcrafted chunky chain necklace in 14K gold vermeil over sterling silver. Sustainable luxury jewelry.", "categoryId": 7, "stock": 50, "keywords": ["mejuri", "necklace", "gold", "jewelry", "chain"], "city": "Toronto", "prov": "ON", "pc": "M5V 3A8", "street": "220 Yonge St", "lat": 43.6532, "lng": -79.3832, "wkg": 0.05, "free": False, "imgs": ["https://picsum.photos/seed/mejuri/600/600", "https://picsum.photos/seed/mejuri2/600/600"]},

    # ── Beauty & Personal Care (8) — 2 products ──
    {"name": "Dyson Airwrap Complete Long — Nickel/Copper", "price": 699.99, "description": "Multi-styler with Coanda airflow technology. Curl, wave, smooth, and dry with no extreme heat.", "categoryId": 8, "stock": 18, "keywords": ["dyson", "airwrap", "hair", "styler", "beauty"], "city": "Montreal", "prov": "QC", "pc": "H2Y 1C6", "street": "500 Rue Saint-Catherine O", "lat": 45.5048, "lng": -73.5719, "wkg": 1.5, "free": True, "imgs": ["https://picsum.photos/seed/dysonwrap/600/600", "https://picsum.photos/seed/dysonwrap2/600/600"]},
    {"name": "The Ordinary AHA 30% + BHA 2% Peeling Solution", "price": 12.90, "description": "10-minute chemical exfoliant with glycolic, lactic, tartaric, citric acid blend. Targets uneven texture and dullness.", "categoryId": 8, "stock": 200, "keywords": ["the ordinary", "skincare", "peeling", "exfoliant", "beauty"], "city": "Toronto", "prov": "ON", "pc": "M5H 2N2", "street": "100 Queen St W", "lat": 43.6529, "lng": -79.3849, "wkg": 0.1, "free": False, "imgs": ["https://picsum.photos/seed/ordinary/600/600", "https://picsum.photos/seed/ordinary2/600/600"]},

    # ── Health & Wellness (9) — 2 products ──
    {"name": "Theragun PRO Plus — Percussive Therapy Device", "price": 599.99, "description": "Smart percussive therapy with OLED screen, Bluetooth, and QuietForce Technology. 6 attachments, 300-min battery.", "categoryId": 9, "stock": 20, "keywords": ["theragun", "massage", "therapy", "recovery", "wellness"], "city": "Halifax", "prov": "NS", "pc": "B3J 1P3", "street": "1969 Upper Water St", "lat": 44.6488, "lng": -63.5752, "wkg": 1.3, "free": True, "imgs": ["https://picsum.photos/seed/theragun/600/600", "https://picsum.photos/seed/theragun2/600/600"]},
    {"name": "Vitamix A3500 Ascent Series Blender — Graphite", "price": 849.95, "description": "Built-in wireless connectivity, 5 program settings, touchscreen controls, self-detect container technology.", "categoryId": 9, "stock": 10, "keywords": ["vitamix", "blender", "health", "smoothie", "wellness"], "city": "Vancouver", "prov": "BC", "pc": "V6Z 2L2", "street": "2113 Main St", "lat": 49.2668, "lng": -123.1008, "wkg": 5.5, "free": True, "imgs": ["https://picsum.photos/seed/vitamix/600/600", "https://picsum.photos/seed/vitamix2/600/600"]},

    # ── Sports & Fitness (10) — 3 products ──
    {"name": "Peloton Bike+ — 24\" Rotating HD Touchscreen", "price": 3295.00, "description": "Premium indoor cycling with live and on-demand classes. 24-inch rotating HD touchscreen, auto-follow resistance.", "categoryId": 10, "stock": 5, "keywords": ["peloton", "bike", "fitness", "cycling", "cardio"], "city": "Toronto", "prov": "ON", "pc": "M4W 3R8", "street": "1 Bloor St E", "lat": 43.6702, "lng": -79.3860, "wkg": 63.0, "free": True, "imgs": ["https://picsum.photos/seed/peloton/600/600", "https://picsum.photos/seed/peloton2/600/600"]},
    {"name": "Bauer Vapor Hyperlite2 Ice Hockey Skates", "price": 1099.99, "description": "Senior fit, carbon composite boot, SPEED PLATE 2.0, LS PULSE TI runners. Engineered for elite performance.", "categoryId": 10, "stock": 7, "keywords": ["bauer", "hockey", "skates", "ice", "sports"], "city": "Quebec City", "prov": "QC", "pc": "G1R 4P5", "street": "250 Boulevard Wilfrid-Hamel", "lat": 46.8139, "lng": -71.2080, "wkg": 2.0, "free": False, "imgs": ["https://picsum.photos/seed/bauer/600/600", "https://picsum.photos/seed/bauer2/600/600"]},
    {"name": "Yeti Hopper M20 Soft Cooler — Charcoal", "price": 450.00, "description": "Rugged soft-sided cooler with MagShield Access, DryHide Shell, ColdCell insulation. Holds 36 cans.", "categoryId": 10, "stock": 15, "keywords": ["yeti", "cooler", "outdoor", "camping", "sports"], "city": "Kelowna", "prov": "BC", "pc": "V1Y 6H2", "street": "1352 Water St", "lat": 49.8863, "lng": -119.4960, "wkg": 2.3, "free": False, "imgs": ["https://picsum.photos/seed/yeti/600/600", "https://picsum.photos/seed/yeti2/600/600"]},

    # ── Tools & Hardware (12) — 2 products ──
    {"name": "DeWalt 20V MAX 5-Tool Combo Kit", "price": 549.99, "description": "Includes drill/driver, impact driver, circular saw, reciprocating saw, and LED work light. Two 20V batteries included.", "categoryId": 12, "stock": 22, "keywords": ["dewalt", "drill", "tools", "power tools", "combo kit"], "city": "Hamilton", "prov": "ON", "pc": "L8P 1A1", "street": "77 James St N", "lat": 43.2557, "lng": -79.8711, "wkg": 8.5, "free": False, "imgs": ["https://picsum.photos/seed/dewalt/600/600", "https://picsum.photos/seed/dewalt2/600/600"]},
    {"name": "Milwaukee M18 FUEL Hammer Drill/Driver Kit", "price": 399.00, "description": "Brushless motor, 1,400 in-lbs torque, REDLINK PLUS intelligence, all-metal ratcheting chuck. Two M18 batteries.", "categoryId": 12, "stock": 18, "keywords": ["milwaukee", "drill", "hammer", "tools", "power tools"], "city": "Brampton", "prov": "ON", "pc": "L6T 3R5", "street": "25 Peel Centre Dr", "lat": 43.7315, "lng": -79.7624, "wkg": 4.2, "free": False, "imgs": ["https://picsum.photos/seed/milwaukee/600/600", "https://picsum.photos/seed/milwaukee2/600/600"]},

    # ── Books (14) — 2 products ──
    {"name": "The Handmaid's Tale — Margaret Atwood (Hardcover)", "price": 29.99, "description": "The classic dystopian novel by Canada's celebrated author. Hardcover collector's edition with introduction by the author.", "categoryId": 14, "stock": 100, "keywords": ["book", "atwood", "handmaids tale", "fiction", "canadian"], "city": "Victoria", "prov": "BC", "pc": "V8W 1N3", "street": "735 Broughton St", "lat": 48.4284, "lng": -123.3656, "wkg": 0.5, "free": False, "imgs": ["https://picsum.photos/seed/atwood/600/600", "https://picsum.photos/seed/atwood2/600/600"]},
    {"name": "Atomic Habits — James Clear (Paperback)", "price": 24.99, "description": "An easy & proven way to build good habits & break bad ones. #1 New York Times bestseller with 15 million copies sold.", "categoryId": 14, "stock": 150, "keywords": ["book", "atomic habits", "self help", "james clear", "bestseller"], "city": "Toronto", "prov": "ON", "pc": "M5V 3A8", "street": "220 Yonge St", "lat": 43.6532, "lng": -79.3832, "wkg": 0.3, "free": False, "imgs": ["https://picsum.photos/seed/atomichabits/600/600", "https://picsum.photos/seed/atomichabits2/600/600"]},

    # ── Toys & Games (16) — 2 products ──
    {"name": "LEGO Technic McLaren P1 — 3893 Pieces", "price": 579.99, "description": "Highly detailed 1:8 scale model with working V8 engine, active rear spoiler, and opening doors.", "categoryId": 16, "stock": 14, "keywords": ["lego", "technic", "mclaren", "model", "building"], "city": "Mississauga", "prov": "ON", "pc": "L5B 1M2", "street": "100 City Centre Dr", "lat": 43.5890, "lng": -79.6441, "wkg": 4.2, "free": True, "imgs": ["https://picsum.photos/seed/legop1/600/600", "https://picsum.photos/seed/legop12/600/600"]},
    {"name": "Ravensburger Disney Villains 2000-Piece Puzzle", "price": 39.99, "description": "Premium 2000-piece jigsaw puzzle featuring iconic Disney villains. SoftClick technology for perfect fit.", "categoryId": 16, "stock": 60, "keywords": ["ravensburger", "puzzle", "disney", "jigsaw", "toys"], "city": "Ottawa", "prov": "ON", "pc": "K1P 5G3", "street": "111 Sussex Dr", "lat": 45.4215, "lng": -75.6972, "wkg": 1.0, "free": False, "imgs": ["https://picsum.photos/seed/ravpuzzle/600/600", "https://picsum.photos/seed/ravpuzzle2/600/600"]},

    # ── Pet Supplies (18) — 2 products ──
    {"name": "PetSafe ScoopFree Self-Cleaning Litter Box", "price": 229.99, "description": "Automatic self-cleaning litter box with disposable crystal trays. No scooping for weeks. Health counter tracks usage.", "categoryId": 18, "stock": 35, "keywords": ["petsafe", "litter box", "cat", "pet", "automatic"], "city": "Saskatoon", "prov": "SK", "pc": "S7K 0J5", "street": "21 St E & 2nd Ave", "lat": 52.1332, "lng": -106.6700, "wkg": 5.0, "free": False, "imgs": ["https://picsum.photos/seed/petsafe/600/600", "https://picsum.photos/seed/petsafe2/600/600"]},
    {"name": "Kong Classic Dog Toy — Large Red", "price": 18.99, "description": "Ultra-durable natural rubber chew toy for aggressive chewers. Stuff with treats for enrichment. Vet recommended.", "categoryId": 18, "stock": 200, "keywords": ["kong", "dog", "toy", "chew", "pet"], "city": "Calgary", "prov": "AB", "pc": "T2P 1J9", "street": "200 Barclay Parade SW", "lat": 51.0447, "lng": -114.0719, "wkg": 0.3, "free": False, "imgs": ["https://picsum.photos/seed/kong/600/600", "https://picsum.photos/seed/kong2/600/600"]},

    # ── Art & Collectibles (20) — 2 products ──
    {"name": "2024 Silver Maple Leaf 1 oz — Royal Canadian Mint", "price": 54.99, "description": "1 oz .9999 fine silver bullion coin. Iconic maple leaf design with enhanced security features. RCM certified.", "categoryId": 20, "stock": 50, "keywords": ["silver", "maple leaf", "coin", "rcm", "bullion", "collectible"], "city": "Charlottetown", "prov": "PE", "pc": "C1A 1M3", "street": "123 Queen St", "lat": 46.2352, "lng": -63.1311, "wkg": 0.031, "free": False, "imgs": ["https://picsum.photos/seed/silver/600/600", "https://picsum.photos/seed/silver2/600/600"]},
    {"name": "Pokémon 25th Anniversary Golden Box — Sealed", "price": 899.99, "description": "Ultra-premium collector's set featuring gold-stamped cards, exclusive promos, and display case. Factory sealed.", "categoryId": 20, "stock": 3, "keywords": ["pokemon", "cards", "collectible", "sealed", "anniversary"], "city": "Toronto", "prov": "ON", "pc": "M5V 3A8", "street": "220 Yonge St", "lat": 43.6532, "lng": -79.3832, "wkg": 1.5, "free": True, "imgs": ["https://picsum.photos/seed/pokemonbox/600/600", "https://picsum.photos/seed/pokemonbox2/600/600"]},

    # ── Digital Products (21) — 2 products ──
    {"name": "Adobe Creative Cloud — 1 Year Subscription", "price": 779.88, "description": "Full access to 20+ creative apps including Photoshop, Illustrator, Premiere Pro, After Effects. Digital delivery.", "categoryId": 21, "stock": 999, "keywords": ["adobe", "creative cloud", "photoshop", "software", "digital"], "city": "Ottawa", "prov": "ON", "pc": "K2P 1L4", "street": "99 Bank St", "lat": 45.4200, "lng": -75.6900, "wkg": None, "free": True, "imgs": ["https://picsum.photos/seed/adobe/600/600"], "digital": True},
    {"name": "Microsoft 365 Family — 1 Year (6 Users)", "price": 129.99, "description": "Premium Office apps, 1TB OneDrive per person, advanced security for 6 users. Includes Word, Excel, PowerPoint, Outlook.", "categoryId": 21, "stock": 999, "keywords": ["microsoft", "office", "365", "software", "digital"], "city": "Toronto", "prov": "ON", "pc": "M5H 2N2", "street": "100 Queen St W", "lat": 43.6529, "lng": -79.3849, "wkg": None, "free": True, "imgs": ["https://picsum.photos/seed/ms365/600/600"], "digital": True},
]

def create_product(doc_id, fields):
    """Function create_product."""
    url = f"{FIRESTORE}/products/{doc_id}"
    r = requests.patch(url, json={"fields": fields}, headers=HEADERS)
    return r.status_code in (200, 201)

def ensure_seller(uid, email):
    """Function ensure_seller."""
    url = f"{FIRESTORE}/users/{uid}"
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
    requests.patch(url, json={"fields": fields}, headers=HEADERS)

def main():
    """Function main."""
    total = len(PRODUCTS)
    print("=" * 60)
    print(f"🧹 CLEAN SEED — Delete all & re-seed {total} products")
    print("=" * 60)

    # Step 1: Delete all existing products
    delete_all_products()

    # Step 2: Set up seller
    seller_uid = "seed_seller_001"
    print(f"\n👤 Setting up seller: yr62813@gmail.com → {seller_uid}")
    ensure_seller(seller_uid, "yr62813@gmail.com")

    # Step 3: Create 20 products with PROPER timestampValue
    print(f"\n📦 Creating {total} products with timestampValue...\n")
    ok = 0
    for i, p in enumerate(PRODUCTS, 1):
        doc_id = f"prod_{uuid.uuid4().hex[:10]}"
        days_ago = random.randint(0, 30)
        hours_ago = random.randint(0, 23)
        created = datetime.utcnow() - timedelta(days=days_ago, hours=hours_ago)

        fields = {
            "name": sv(p["name"]),
            "price": fv(p["price"]),
            "description": sv(p["description"]),
            "imageUrls": av([sv(u) for u in p["imgs"]]),
            "sellerId": sv(seller_uid),
            "sellerAddress": build_address(p["street"], p["city"], p["prov"], p["pc"], p["lat"], p["lng"]),
            "categoryId": iv(p["categoryId"]),
            "stockQuantity": iv(p["stock"]),
            "rating": fv(round(random.uniform(3.5, 5.0), 1)),
            "ratingCount": iv(random.randint(5, 200)),
            "keywords": av([sv(kw) for kw in p["keywords"]]),
            "isActive": bv(True),
            "createdAt": ts(created),  # ← PROPER timestampValue
            "isDigital": bv(p.get("digital", False)),
            "isLocalDeliveryOnly": bv(False),
            "isPerishable": bv(False),
            "estimatedShipDays": iv(0 if p.get("digital") else 3),
            "deliveryOptions": build_delivery_options(p["free"]),
            "minimumOrderQuantity": iv(1),
            "freeShipping": bv(p["free"]),
            "status": sv("active"),
        }
        if p["wkg"] is not None:
            fields["weightKg"] = fv(p["wkg"])

        if create_product(doc_id, fields):
            ok += 1
            print(f"  ✅ [{i:2d}/{total}] {p['name'][:55]} — ${p['price']:.2f}")
        else:
            print(f"  ❌ [{i:2d}/{total}] FAILED: {p['name']}")

    # Verify
    print(f"\n{'=' * 60}")
    print(f"🏁 Done! {ok}/{total} products created.")
    print("\n🔍 Verifying createdAt types...")
    r = requests.get(f"{FIRESTORE}/products?pageSize=25", headers=HEADERS)
    docs = r.json().get("documents", [])
    types = {}
    for d in docs:
        dc = d.get("fields", {}).get("createdAt", {})
        t = list(dc.keys())[0] if dc else "MISSING"
        types[t] = types.get(t, 0) + 1
    for t, c in types.items():
        emoji = "✅" if t == "timestampValue" else "⚠️"
        print(f"   {emoji} {t}: {c} products")
    
    print("\n🔗 Refresh browser: http://localhost:3000")
    print("🔗 Emulator UI: http://localhost:4000/firestore/data/products")
    print("=" * 60)

if __name__ == "__main__":
    main()
