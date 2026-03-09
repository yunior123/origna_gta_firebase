#!/usr/bin/env python3
"""Send a single test email and track its delivery status."""

import json
import os
import sys
import time

from dotenv import load_dotenv

load_dotenv()
os.environ["FUNCTIONS_EMULATOR"] = "true"
sys.path.insert(0, os.path.dirname(__file__))

from mailjet_rest import Client

from config import get_mailjet_api_key, get_mailjet_secret_key
from schema_constants import EmailConfig

mj_send = Client(auth=(get_mailjet_api_key(), get_mailjet_secret_key()), version="v3.1")
mj_api = Client(auth=(get_mailjet_api_key(), get_mailjet_secret_key()), version="v3")

print("Sending simple test email from support@orignaventures.ca...")

data = {
    "Messages": [
        {
            "From": {"Email": EmailConfig.SUPPORT_EMAIL, "Name": "Origna GTA"},
            "To": [{"Email": "yr628132@gmail.com"}],
            "Subject": "SPF+DKIM Test - Origna (simple)",
            "TextPart": "If you see this in yr628132@gmail.com, SPF+DKIM is working!",
            "HTMLPart": "<h2>SPF + DKIM Test</h2><p>This email was sent from <b>support@orignaventures.ca</b> via Mailjet with SPF and DKIM properly configured.</p><p>If you see this, delivery works!</p>",
        },
        {
            "From": {"Email": EmailConfig.SUPPORT_EMAIL, "Name": "Origna GTA"},
            "To": [{"Email": "yuniorrodriguezo4601@yahoo.com"}],
            "Subject": "SPF+DKIM Test - Origna (simple)",
            "TextPart": "If you see this in yuniorrodriguezo4601@yahoo.com, SPF+DKIM is working!",
            "HTMLPart": "<h2>SPF + DKIM Test</h2><p>This email was sent from <b>support@orignaventures.ca</b> via Mailjet with SPF and DKIM properly configured.</p><p>If you see this, delivery works!</p>",
        },
    ]
}

result = mj_send.send.create(data=data)
resp = result.json()
print(f"Status code: {result.status_code}")

msg_ids = []
for msg in resp.get("Messages", []):
    for to in msg.get("To", []):
        mid = to.get("MessageID")
        email = to.get("Email")
        msg_ids.append((mid, email))
        print(f"  {email} -> MessageID: {mid}")

# Wait and poll status
for wait in [3, 5, 10]:
    print(f"\nWaiting {wait}s then checking status...")
    time.sleep(wait)
    for mid, email in msg_ids:
        r = mj_api.message.get(id=mid)
        if r.status_code == 200:
            d = r.json().get("Data", [{}])[0]
            status = d.get("Status", "?")
            print(f"  {email}: {status}")
        else:
            print(f"  {email}: API error {r.status_code}")

print("\nDone. If status is 'sent' or 'opened', check your inbox!")
print("If 'deferred', there may still be a reputation/throttling issue with Mailjet.")
