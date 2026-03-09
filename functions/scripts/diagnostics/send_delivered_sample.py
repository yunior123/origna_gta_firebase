#!/usr/bin/env python3
"""Send delivered email sample using verified Gmail sender."""

import os
import sys

from dotenv import load_dotenv

load_dotenv()

os.environ["FUNCTIONS_EMULATOR"] = "true"
os.environ["FORCE_REAL_EMAIL"] = "true"
sys.path.insert(0, os.path.dirname(__file__))

from mailjet_rest import Client

from config import MAILJET_API_KEY, MAILJET_SECRET_KEY
from services.email_service import get_order_delivered_email

# Use the verified Gmail sender (the only one that works without SPF/DKIM)
VERIFIED_SENDER = "yuniorrodriguezo460@gmail.com"

RECIPIENTS = [
    "yr628132@gmail.com",
    "yuniorrodriguezo4601@yahoo.com",
]

MOCK_ORDER_DATA = {
    "orderId": "ORD7f3a9c2e4b1d6e8f",
    "customerEmail": "yr628132@gmail.com",
    "items": [
        {"name": "Sony WH-1000XM5 Wireless Headphones", "quantity": 1, "price": 449.99},
        {"name": "Apple AirTag (4 Pack)", "quantity": 2, "price": 129.00},
        {"name": "Anker USB-C Fast Charger 65W", "quantity": 1, "price": 45.99},
    ],
    "subtotalCents": 75398,
    "shippingCostCents": 1299,
    "taxes": {"GST (5%)": 37.70, "PST (8%)": 60.32},
    "totalAmountCents": 86429,
    "shippingAddress": {
        "street": "456 King Street West",
        "apartment": "Unit 1204",
        "city": "Toronto",
        "state": "ON",
        "postalCode": "M5V 1K4",
        "country": "Canada",
        "phoneNumber": "+1 (416) 555-0192",
    },
}

MOCK_ORDER_ID = "ORD7f3a9c2e4b1d6e8f"

print("=" * 60)
print("📧 Sending Order Delivered email (via verified Gmail sender)")
print(f"   From: {VERIFIED_SENDER}")
print(f"   To: {', '.join(RECIPIENTS)}")
print("=" * 60)

# Generate the delivered email HTML
delivered_html = get_order_delivered_email(MOCK_ORDER_DATA, MOCK_ORDER_ID)

mailjet = Client(auth=(MAILJET_API_KEY, MAILJET_SECRET_KEY), version="v3.1")

for recipient in RECIPIENTS:
    data = {
        "Messages": [
            {
                "From": {"Email": VERIFIED_SENDER, "Name": "Origna GTA"},
                "To": [{"Email": recipient}],
                "Subject": f"[SAMPLE] Your Order Has Been Delivered — #{MOCK_ORDER_ID[:8]}",
                "HTMLPart": delivered_html,
            }
        ]
    }
    result = mailjet.send.create(data=data)
    resp = result.json()
    status = resp.get("Messages", [{}])[0].get("Status", "unknown")
    if status == "success":
        msg_id = resp["Messages"][0]["To"][0]["MessageID"]
        print(f"  ✅ {recipient} — MessageID: {msg_id}")
    else:
        print(f"  ❌ {recipient} — {resp}")

print("\n✅ Done! Check your inboxes.")
