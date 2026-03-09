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

mailjet = Client(auth=(MAILJET_API_KEY, MAILJET_SECRET_KEY), version="v3")

# Get last 30 messages
result = mailjet.message.get(filters={"Limit": 30, "Sort": "ArrivedAt+DESC"})
if result.status_code == 200:
    msgs = result.json().get("Data", [])
    print(f"{'Status':<12} {'MessageID':<22} {'Subject snippet':<45} {'ArrivedAt'}")
    print("-" * 110)
    for m in msgs:
        mid = m.get("ID", "")
        status = m.get("Status", "?")
        arrived = m.get("ArrivedAt", "?")
        # Get message info for subject
        detail = mailjet.messagesentstatistics.get(id=mid)
        subj = ""
        if detail.status_code == 200:
            d = detail.json().get("Data", [{}])
            if d:
                subj = d[0].get("Subject", "")[:44]

        emoji = {"sent": "✅", "opened": "📬", "deferred": "⏳", "bounced": "🔙", "blocked": "🚫"}.get(status, "❓")
        print(f"{emoji} {status:<10} {mid:<22} {subj:<45} {arrived}")
else:
    print(f"Error: {result.status_code}")
