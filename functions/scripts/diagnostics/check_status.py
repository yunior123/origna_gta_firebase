#!/usr/bin/env python3
"""Check delivery status of recent Mailjet messages."""

import os
import sys

from dotenv import load_dotenv

load_dotenv()
os.environ["FUNCTIONS_EMULATOR"] = "true"
sys.path.insert(0, os.path.dirname(__file__))

from mailjet_rest import Client

from config import MAILJET_API_KEY, MAILJET_SECRET_KEY

mj = Client(auth=(MAILJET_API_KEY, MAILJET_SECRET_KEY), version="v3")

result = mj.message.get(filters={"Limit": 16, "Sort": "ArrivedAt+DESC"})
if result.status_code == 200:
    msgs = result.json().get("Data", [])
    for m in msgs:
        mid = m.get("ID")
        status = m.get("Status", "?")
        arrived = m.get("ArrivedAt", "?")
        sender_id = m.get("SenderID", "")

        # Resolve recipient email
        recipient = "?"
        contact_id = m.get("ContactID")
        if contact_id:
            c = mj.contact.get(id=contact_id)
            if c.status_code == 200:
                cd = c.json().get("Data", [])
                if cd:
                    recipient = cd[0].get("Email", "?")

        emoji = {
            "sent": "SENT",
            "opened": "OPENED",
            "deferred": "DEFERRED",
            "bounced": "BOUNCED",
            "blocked": "BLOCKED",
            "clicked": "CLICKED",
            "queued": "QUEUED",
            "spam": "SPAM",
        }.get(status, status)

        print(f"{emoji:<10} -> {recipient:<36} SenderID:{sender_id}  at {arrived}")
else:
    print(f"Error: {result.status_code}")
