#!/usr/bin/env python3
"""
Seed Orders — Creates realistic test orders in Firestore emulator.
Creates 8 orders at various statuses for UI testing.

Usage: python3 e2e/scripts/seed/seed-orders.py
"""

import json
import requests
from datetime import datetime, timedelta

FIRESTORE = "http://localhost:8080"
PROJECT = "orignagta"
BASE = f"{FIRESTORE}/v1/projects/{PROJECT}/databases/(default)/documents"

# Load UID map from mega-seed
with open("/Users/yuniorrodriguezosorio/Documents/GitHub/origna_gta/e2e/seed-uid-map.json") as f:
    UID_MAP = json.load(f)

ADMIN_UID = UID_MAP["yr62813@gmail.com"]
SELLER1_UID = UID_MAP["seller1@test.origna.ca"]
SELLER2_UID = UID_MAP["seller2@test.origna.ca"]
SELLER3_UID = UID_MAP["seller3@test.origna.ca"]
SELLER4_UID = UID_MAP["seller4@test.origna.ca"]
BUYER1_UID = UID_MAP["yuniorrodriguezo460@gmail.com"]
BUYER2_UID = UID_MAP["buyer2@test.origna.ca"]
BUYER3_UID = UID_MAP["buyer3@test.origna.ca"]
BUYER4_UID = UID_MAP["buyer4@test.origna.ca"]
BUYER5_UID = UID_MAP["buyer5@test.origna.ca"]

def ts(dt=None):
    """Convert datetime to Firestore timestamp value."""
    if dt is None:
        dt = datetime.utcnow()
    return {"timestampValue": dt.strftime("%Y-%m-%dT%H:%M:%S.000Z")}

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

def mv(fields):
    """Map value."""
    return {"mapValue": {"fields": fields}}

def nv():
    """Null value."""
    return {"nullValue": None}

def make_address(street, city, state, postal, country="Canada", phone="5141234567", lat=45.5, lng=-73.6):
    """Function make_address."""
    return mv({
        "street": sv(street),
        "apartment": sv(""),
        "city": sv(city),
        "state": sv(state),
        "postalCode": sv(postal),
        "country": sv(country),
        "phoneNumber": sv(phone),
        "isDefault": bv(True),
        "label": sv("Home"),
        "latitude": fv(lat),
        "longitude": fv(lng),
    })

def make_item(product_id, name, price, qty, seller_uid, seller_city, seller_province,
              seller_country="Canada", images=None, delivery_status="pending", tracking=None, 
              carrier=None, free_shipping=False, is_digital=False):
    # Use picsum.photos for reliable CORS-friendly images
    """Function make_item."""
    default_images = [f"https://picsum.photos/seed/{product_id}/400/400"]
    fields = {
        "productId": sv(product_id),
        "name": sv(name),
        "description": sv(f"High-quality {name}"),
        "price": fv(price),
        "quantity": iv(qty),
        "imageUrls": av([sv(img) for img in (images or default_images)]),
        "sellerId": sv(seller_uid),
        "sellerAddress": make_address("123 Seller St", seller_city, seller_province, "H3B 1A1", country=seller_country),
        "isDigital": bv(is_digital),
        "status": sv(delivery_status),
        "deliveryStatus": sv(delivery_status),
        "shippingStatus": sv(delivery_status),
        "freeShipping": bv(free_shipping),
        "isLocalDeliveryOnly": bv(False),
        "isPerishable": bv(False),
        "confirmedByBuyer": bv(False),
        "shippingOptions": av([]),
        "weightKg": fv(0.5),
        "minimumOrderQuantity": iv(1),
        "estimatedShipDays": iv(3),
    }
    if tracking:
        fields["trackingNumber"] = sv(tracking)
        fields["carrier"] = sv(carrier or "Canada Post")
    else:
        fields["trackingNumber"] = nv()
        fields["carrier"] = nv()
    return mv(fields)

def make_taxes(province):
    """Calculate taxes for a province."""
    tax_rates = {
        "ON": {"HST": 0.13},
        "QC": {"GST": 0.05, "QST": 0.09975},
        "BC": {"GST": 0.05, "PST": 0.07},
        "AB": {"GST": 0.05},
        "MB": {"GST": 0.05, "PST": 0.07},
        "SK": {"GST": 0.05, "PST": 0.06},
        "NS": {"HST": 0.14},  # Changed from 15% to 14% on April 1, 2025 (CRA)
        "NB": {"HST": 0.15},
        "NL": {"HST": 0.15},
        "PE": {"HST": 0.15},
        "NT": {"GST": 0.05},
        "NU": {"GST": 0.05},
        "YT": {"GST": 0.05},
    }
    return tax_rates.get(province, {"HST": 0.13})

def create_order(order_id, order_data):
    """Create an order document in Firestore (bypass security rules with owner token)."""
    url = f"{BASE}/orders/{order_id}"
    payload = {"fields": order_data}
    headers = {"Authorization": "Bearer owner"}
    r = requests.patch(url, json=payload, headers=headers)
    if r.status_code in (200, 201):
        print(f"  ✅ Order {order_id}: {order_data['orderStatus']['stringValue']}")
    else:
        print(f"  ❌ Order {order_id}: {r.status_code} — {r.text[:200]}")

def build_order(order_id, buyer_uid, buyer_email, buyer_province, items_data,
                status="pending", payment_status="awaiting_payment",
                created_ago_days=0, tracking=None, confirmed=False,
                stripe_pi=None):
    """Build a complete order document."""
    now = datetime.utcnow()
    created = now - timedelta(days=created_ago_days)
    expires = created + timedelta(days=7)

    # Calculate totals
    subtotal_dollars = sum(item["price"] * item["qty"] for item in items_data)
    taxes = make_taxes(buyer_province)
    tax_total_dollars = sum(subtotal_dollars * rate for rate in taxes.values())
    shipping_cents = 1299  # $12.99 flat
    subtotal_cents = int(round(subtotal_dollars * 100))
    tax_cents = int(round(tax_total_dollars * 100))
    total_cents = subtotal_cents + tax_cents + shipping_cents

    # Unique seller IDs
    seller_ids = sorted(set(item["seller_uid"] for item in items_data))

    # Build items
    items = []
    for item in items_data:
        items.append(make_item(
            product_id=item["product_id"],
            name=item["name"],
            price=item["price"],
            qty=item["qty"],
            seller_uid=item["seller_uid"],
            seller_city=item.get("seller_city", "Montreal"),
            seller_province=item.get("seller_province", "QC"),
            seller_country=item.get("seller_country", "Canada"),
            delivery_status=item.get("delivery_status", "pending"),
            tracking=item.get("tracking"),
            carrier=item.get("carrier"),
            free_shipping=item.get("free_shipping", False),
            is_digital=item.get("is_digital", False),
        ))

    # Build taxes map
    tax_fields = {}
    for tax_name, rate in taxes.items():
        tax_fields[tax_name] = fv(round(subtotal_dollars * rate, 2))

    # Build seller payouts
    payouts = []
    for sid in seller_ids:
        seller_items = [i for i in items_data if i["seller_uid"] == sid]
        seller_total = sum(i["price"] * i["qty"] * 100 for i in seller_items)
        platform_fee = int(seller_total * 0.025)
        net = int(seller_total) - platform_fee
        payouts.append(mv({
            "sellerId": sv(sid),
            "stripeAccountId": sv("acct_test_mock"),
            "amountCents": iv(int(seller_total)),
            "platformFeeCents": iv(platform_fee),
            "netAmountCents": iv(net),
            "status": sv("pending"),
            "transferId": nv(),
            "paidAt": nv(),
            "error": nv(),
        }))

    pi = stripe_pi or f"pi_test_{order_id}"

    fields = {
        "orderId": sv(order_id),
        "userId": sv(buyer_uid),
        "customerEmail": sv(buyer_email),
        "customerId": sv(f"cus_test_{buyer_uid[:8]}"),
        "sellerIds": av([sv(sid) for sid in seller_ids]),
        "items": av(items),
        "subtotalCents": iv(subtotal_cents),
        "shippingCostCents": iv(shipping_cents),
        "taxAmountCents": iv(tax_cents),
        "totalAmountCents": iv(total_cents),
        "taxes": mv(tax_fields),
        "currency": sv("cad"),
        "orderStatus": sv(status),
        "paymentStatus": sv(payment_status),
        "shippingAddress": make_address(
            "456 Buyer Rd", "Toronto" if buyer_province == "ON" else "Montreal",
            buyer_province, "M5V 3A8" if buyer_province == "ON" else "H3B 1A1"
        ),
        "stripeSessionId": sv(f"cs_test_{order_id}"),
        "stripePaymentIntentId": sv(pi),
        "paymentProvider": sv("stripe"),
        "createdAt": ts(created),
        "updatedAt": ts(now),
        "expiresAt": ts(expires),
        "capturedAt": nv(),
        "deliveredAt": nv(),
        "captureAttempts": iv(0),
        "confirmedByClient": bv(confirmed),
        "autoConfirmed": bv(False),
        "autoCaptured": bv(False),
        "sellerPayouts": av(payouts),
        "platformFeeTotal": fv(round(subtotal_dollars * 0.025, 2)),
        "payoutStatus": sv("pending"),
        "stockRestored": bv(False),
        "archived": bv(False),
        "shippingApprovalStatus": sv("not_required"),
        "shippingApprovalRequired": bv(False),
        "actualShipping": fv(0.0),
        "pendingTotal": fv(0.0),
    }

    return fields


# ═══════════════════════════════════════════════════════════
# CREATE TEST ORDERS
# ═══════════════════════════════════════════════════════════

print("🛒 Creating test orders...")
print("═" * 50)

# Order 1: PENDING — recently paid, pending confirmation
create_order("order_test_001", build_order(
    "order_test_001",
    buyer_uid=BUYER1_UID,
    buyer_email="yuniorrodriguezo460@gmail.com",
    buyer_province="ON",
    status="pending",
    payment_status="paid",
    created_ago_days=0,
    items_data=[
        {"product_id": "product_001", "name": "Handmade Quebec Scarf", "price": 45.99, "qty": 1,
         "seller_uid": SELLER1_UID, "seller_city": "Montreal", "seller_province": "QC"},
        {"product_id": "product_005", "name": "Pacific Coast Trail Running Shoes", "price": 129.99, "qty": 1,
         "seller_uid": SELLER2_UID, "seller_city": "Vancouver", "seller_province": "BC"},
    ]
))

# Order 2: CONFIRMED — payment authorized, waiting for seller to process
create_order("order_test_002", build_order(
    "order_test_002",
    buyer_uid=BUYER2_UID,
    buyer_email="buyer2@test.origna.ca",
    buyer_province="QC",
    status="confirmed",
    payment_status="authorized",
    created_ago_days=1,
    items_data=[
        {"product_id": "product_002", "name": "Montreal Artisan Leather Bag", "price": 189.99, "qty": 1,
         "seller_uid": SELLER1_UID, "seller_city": "Montreal", "seller_province": "QC"},
        {"product_id": "product_012", "name": "Organic Maple Syrup (1L)", "price": 22.50, "qty": 2,
         "seller_uid": SELLER4_UID, "seller_city": "Ottawa", "seller_province": "ON"},
    ]
))

# Order 3: PROCESSING — seller is preparing the order
create_order("order_test_003", build_order(
    "order_test_003",
    buyer_uid=BUYER3_UID,
    buyer_email="buyer3@test.origna.ca",
    buyer_province="BC",
    status="processing",
    payment_status="authorized",
    created_ago_days=2,
    items_data=[
        {"product_id": "product_007", "name": "Alberta Beef Jerky Gift Box", "price": 34.99, "qty": 3,
         "seller_uid": SELLER3_UID, "seller_city": "Calgary", "seller_province": "AB"},
    ]
))

# Order 4: SHIPPED — items have been shipped with tracking
create_order("order_test_004", build_order(
    "order_test_004",
    buyer_uid=BUYER4_UID,
    buyer_email="buyer4@test.origna.ca",
    buyer_province="ON",
    status="shipped",
    payment_status="captured",
    created_ago_days=3,
    items_data=[
        {"product_id": "product_014", "name": "Bison Leather Wallet", "price": 89.99, "qty": 1,
         "seller_uid": SELLER2_UID, "seller_city": "Vancouver", "seller_province": "BC",
         "delivery_status": "shipped", "tracking": "CP123456789CA", "carrier": "Canada Post"},
        {"product_id": "product_017", "name": "Halifax Lobster Trap Decor", "price": 65.00, "qty": 1,
         "seller_uid": SELLER2_UID, "seller_city": "Vancouver", "seller_province": "BC",
         "delivery_status": "shipped", "tracking": "CP123456789CA", "carrier": "Canada Post"},
    ]
))

# Order 5: IN_TRANSIT — close to delivery
create_order("order_test_005", build_order(
    "order_test_005",
    buyer_uid=BUYER5_UID,
    buyer_email="buyer5@test.origna.ca",
    buyer_province="AB",
    status="in_transit",
    payment_status="captured",
    created_ago_days=5,
    items_data=[
        {"product_id": "product_018", "name": "Nova Scotia Tartan Blanket", "price": 110.00, "qty": 1,
         "seller_uid": SELLER3_UID, "seller_city": "Calgary", "seller_province": "AB",
         "delivery_status": "shipped", "tracking": "FX987654321", "carrier": "FedEx"},
    ]
))

# Order 6: DELIVERED — waiting for buyer confirmation
create_order("order_test_006", build_order(
    "order_test_006",
    buyer_uid=BUYER1_UID,
    buyer_email="yuniorrodriguezo460@gmail.com",
    buyer_province="ON",
    status="delivered",
    payment_status="captured",
    created_ago_days=6,
    items_data=[
        {"product_id": "product_010", "name": "Canadian History eBook Bundle", "price": 14.99, "qty": 1,
         "seller_uid": SELLER4_UID, "seller_city": "Ottawa", "seller_province": "ON",
         "delivery_status": "delivered", "is_digital": True, "free_shipping": True},
    ]
))

# Order 7: CANCELLED — buyer cancelled before shipping
create_order("order_test_007", build_order(
    "order_test_007",
    buyer_uid=BUYER2_UID,
    buyer_email="buyer2@test.origna.ca",
    buyer_province="QC",
    status="cancelled",
    payment_status="awaiting_payment",
    created_ago_days=10,
    items_data=[
        {"product_id": "product_024", "name": "Budget Sticker Pack", "price": 1.99, "qty": 5,
         "seller_uid": SELLER1_UID, "seller_city": "Montreal", "seller_province": "QC"},
    ]
))

# Order 8: Multi-seller CONFIRMED — for the status cycling demo
create_order("order_test_008", build_order(
    "order_test_008",
    buyer_uid=BUYER1_UID,
    buyer_email="yuniorrodriguezo460@gmail.com",
    buyer_province="ON",
    status="confirmed",
    payment_status="authorized",
    created_ago_days=0,
    items_data=[
        {"product_id": "product_001", "name": "Handmade Quebec Scarf", "price": 45.99, "qty": 2,
         "seller_uid": SELLER1_UID, "seller_city": "Montreal", "seller_province": "QC"},
        {"product_id": "product_009", "name": "Wireless Bluetooth Earbuds Pro", "price": 79.99, "qty": 1,
         "seller_uid": SELLER3_UID, "seller_city": "Calgary", "seller_province": "AB"},
        {"product_id": "product_015", "name": "Prairie Sunset Canvas Print", "price": 55.00, "qty": 1,
         "seller_uid": SELLER4_UID, "seller_city": "Ottawa", "seller_province": "ON"},
    ]
))

# Order 9: Multi-country, Multi-seller CONFIRMED
create_order("order_test_009", build_order(
    "order_test_009",
    buyer_uid=BUYER1_UID,
    buyer_email="yuniorrodriguezo460@gmail.com",
    buyer_province="ON",
    status="confirmed",
    payment_status="authorized",
    created_ago_days=0,
    items_data=[
        {"product_id": "product_intl_001", "name": "Global Tech Gadget", "price": 299.99, "qty": 1,
         "seller_uid": SELLER2_UID, "seller_city": "Shenzhen", "seller_province": "GD", "seller_country": "China"},
        {"product_id": "product_001", "name": "Handmade Quebec Scarf", "price": 45.99, "qty": 1,
         "seller_uid": SELLER1_UID, "seller_city": "Montreal", "seller_province": "QC", "seller_country": "Canada"},
    ]
))

print()
print("═" * 50)
print("✅ 9 test orders created!")
print("  📋 order_test_001: pending (2 items, multi-seller)")
print("  📋 order_test_002: confirmed (2 items, multi-seller)")
print("  📋 order_test_003: processing (1 item)")
print("  📋 order_test_004: shipped (2 items, w/ tracking)")
print("  📋 order_test_005: in_transit (1 item, w/ tracking)")
print("  📋 order_test_006: delivered (1 digital item)")
print("  📋 order_test_007: cancelled")
print("  📋 order_test_008: confirmed (3 items, multi-seller — for status cycling)")
print("  📋 order_test_009: confirmed (2 items, multi-country, multi-seller)")
print()
print("🔑 Login as yuniorrodriguezo460@gmail.com (password: REDACTED_TEST_PASSWORD) to see orders")
print("   Orders visible: order_test_001, 006, 008")
print("   Or login as buyer2@test.origna.ca for orders: 002, 007")
