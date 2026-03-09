#!/usr/bin/env python3
"""Diagnose why Mailjet emails aren't being delivered."""

import json
import os
import sys

from dotenv import load_dotenv

load_dotenv()

os.environ["FUNCTIONS_EMULATOR"] = "true"
sys.path.insert(0, os.path.dirname(__file__))

from mailjet_rest import Client

from config import MAILJET_API_KEY, MAILJET_SECRET_KEY
from schema_constants import EmailConfig

mailjet = Client(auth=(MAILJET_API_KEY, MAILJET_SECRET_KEY), version="v3")

print("=" * 60)
print("🔍 MAILJET DIAGNOSTICS")
print("=" * 60)

# 1. Check verified senders
print("\n1️⃣  Verified Senders:")
result = mailjet.sender.get()
if result.status_code == 200:
    senders = result.json().get("Data", [])
    for s in senders:
        status = "✅ VERIFIED" if s.get("Status") == "Active" else f"❌ {s.get('Status')}"
        print(f"   {s.get('Email', 'N/A')} — {status} (ID: {s.get('ID')})")
    if not senders:
        print("   ⚠️ NO SENDERS CONFIGURED!")
else:
    print(f"   Error: {result.status_code} — {result.json()}")

# 2. Check sender domains
print("\n2️⃣  Sender Domains (SPF/DKIM):")
result = mailjet.dns.get()
if result.status_code == 200:
    domains = result.json().get("Data", [])
    for d in domains:
        spf = "✅" if d.get("SPFStatus") == "OK" else f"❌ {d.get('SPFStatus')}"
        dkim = "✅" if d.get("DKIMStatus") == "OK" else f"❌ {d.get('DKIMStatus')}"
        print(f"   {d.get('Domain', 'N/A')} — SPF: {spf} | DKIM: {dkim}")
    if not domains:
        print("   ⚠️ NO DOMAINS CONFIGURED!")
else:
    print(f"   Error: {result.status_code} — {result.json()}")

# 3. Check recent message stats
print("\n3️⃣  Recent Messages (last 10):")
mailjet_v3 = Client(auth=(MAILJET_API_KEY, MAILJET_SECRET_KEY), version="v3")
result = mailjet_v3.message.get(filters={"Limit": 10, "Sort": "ArrivedAt+DESC"})
if result.status_code == 200:
    messages = result.json().get("Data", [])
    for m in messages:
        status_map = {
            0: "📤 transactional",
            1: "✉️ sent",
            2: "📬 opened",
            3: "🖱️ clicked",
            4: "🔙 bounced",
            5: "🚫 blocked",
            6: "🗑️ spam",
            7: "⬇️ unsub",
        }
        state = m.get("Status", "unknown")
        msg_id = m.get("ID", "N/A")
        to = m.get(
            "ContactAlt", m.get("Contact", {}).get("Email", "N/A") if isinstance(m.get("Contact"), dict) else "N/A"
        )
        arrived = m.get("ArrivedAt", "N/A")
        print(f"   [{state}] ID:{msg_id} → {to} at {arrived}")
    if not messages:
        print("   No messages found")
else:
    print(f"   Error: {result.status_code} — {result.json()}")

# 4. Try sending a minimal plain test email
print("\n4️⃣  Sending MINIMAL test email...")
print(f"   From: {EmailConfig.SUPPORT_EMAIL}")
print("   To: yr628132@gmail.com, yuniorrodriguezo4601@yahoo.com")

mailjet_send = Client(auth=(MAILJET_API_KEY, MAILJET_SECRET_KEY), version="v3.1")
data = {
    "Messages": [
        {
            "From": {"Email": EmailConfig.SUPPORT_EMAIL, "Name": "Origna GTA"},
            "To": [{"Email": "yr628132@gmail.com", "Name": "Test Gmail"}],
            "Subject": "Mailjet Test — Plain Text",
            "TextPart": "This is a plain text test email from Origna GTA. If you see this, Mailjet delivery works.",
            "HTMLPart": "<html><body><h1>Mailjet Test</h1><p>This is a plain HTML test from Origna GTA.</p><p>If you see this, email delivery works!</p></body></html>",
        },
        {
            "From": {"Email": EmailConfig.SUPPORT_EMAIL, "Name": "Origna GTA"},
            "To": [{"Email": "yuniorrodriguezo4601@yahoo.com", "Name": "Test Yahoo"}],
            "Subject": "Mailjet Test — Plain Text",
            "TextPart": "This is a plain text test email from Origna GTA. If you see this, Mailjet delivery works.",
            "HTMLPart": "<html><body><h1>Mailjet Test</h1><p>This is a plain HTML test from Origna GTA.</p><p>If you see this, email delivery works!</p></body></html>",
        },
    ]
}

result = mailjet_send.send.create(data=data)
print(f"   Status: {result.status_code}")
response = result.json()
print(f"   Full response: {json.dumps(response, indent=2)}")

for msg in response.get("Messages", []):
    status = msg.get("Status")
    to_info = msg.get("To", [{}])[0]
    email = to_info.get("Email", "N/A")
    msg_id = to_info.get("MessageID", "N/A")
    msg_uuid = to_info.get("MessageUUID", "N/A")
    print(f"   → {email}: Status={status}, MessageID={msg_id}, UUID={msg_uuid}")

print("\n" + "=" * 60)
print("💡 If Status=200 but no email received:")
print("   - Check Mailjet Dashboard > Messages for bounce/block status")
print("   - Verify SPF/DKIM DNS records for orignaventures.ca")
print("   - If sender not verified, emails are silently dropped")
print("=" * 60)
