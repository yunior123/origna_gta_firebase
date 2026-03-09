#!/usr/bin/env python3
"""Check Mailjet account status, limits, and quota."""

import os
import sys

from dotenv import load_dotenv

load_dotenv()
os.environ["FUNCTIONS_EMULATOR"] = "true"
sys.path.insert(0, os.path.dirname(__file__))

from mailjet_rest import Client

from config import MAILJET_API_KEY, MAILJET_SECRET_KEY

mj = Client(auth=(MAILJET_API_KEY, MAILJET_SECRET_KEY), version="v3")

# 1. Account info
print("=== ACCOUNT INFO ===")
r = mj.myprofile.get()
if r.status_code == 200:
    d = r.json().get("Data", [{}])[0]
    for k in ["Email", "Firstname", "Lastname", "CompanyName", "JobTitle"]:
        print(f"  {k}: {d.get(k, 'N/A')}")

# 2. API Key info
print("\n=== API KEY INFO ===")
r = mj.apikey.get()
if r.status_code == 200:
    for key in r.json().get("Data", []):
        print(f"  Name: {key.get('Name')}")
        print(f"  IsActive: {key.get('IsActive')}")
        print(f"  IsMaster: {key.get('IsMaster')}")
        print(f"  QuarantineValue: {key.get('QuarantineValue')}")
        print(f"  Runlevel: {key.get('Runlevel')}")
        print(f"  CreatedAt: {key.get('CreatedAt')}")

# 3. Message stats (today)
print("\n=== TODAY'S STATS ===")
r = mj.statcounters.get(
    filters={
        "CounterSource": "APIKey",
        "CounterTiming": "Message",
        "CounterResolution": "Day",
        "Limit": 1,
        "Sort": "Timeslice+DESC",
    }
)
if r.status_code == 200:
    data = r.json().get("Data", [])
    if data:
        d = data[0]
        print(f"  Messages sent: {d.get('MessageSentCount', 0)}")
        print(f"  Opened: {d.get('MessageOpenedCount', 0)}")
        print(f"  Clicked: {d.get('MessageClickedCount', 0)}")
        print(f"  Bounced: {d.get('MessageHardBouncedCount', 0) + d.get('MessageSoftBouncedCount', 0)}")
        print(f"  Spam: {d.get('MessageSpamCount', 0)}")
        print(f"  Blocked: {d.get('MessageBlockedCount', 0)}")
        print(f"  Deferred: {d.get('MessageDeferredCount', 0)}")
    else:
        print("  No stats for today")
else:
    print(f"  Stats error: {r.status_code}")

# 4. Check user info / restrictions
print("\n=== USER/RESTRICTIONS ===")
r = mj.user.get()
if r.status_code == 200:
    d = r.json().get("Data", [{}])[0]
    print(f"  MaxAllowedAPIKeys: {d.get('MaxAllowedAPIKeys')}")
    print(f"  NewContactsPerRequest: {d.get('NewContactsPerRequest')}")
    print(f"  WarnedRateLimit: {d.get('WarnedRateLimit')}")
    # Print all fields
    for k, v in sorted(d.items()):
        if v and v != 0 and v != "":
            print(f"  {k}: {v}")
else:
    print(f"  Error: {r.status_code}")

# 5. Sender status
print("\n=== SENDER STATUS ===")
r = mj.sender.get()
if r.status_code == 200:
    for s in r.json().get("Data", []):
        print(f"  {s.get('Email')}: Status={s.get('Status')}, IsDefaultSender={s.get('IsDefaultSender')}")
