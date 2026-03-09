#!/usr/bin/env python3
"""Force emailVerified=true for admin and yahoo accounts in the Auth emulator."""
import requests

AUTH = "http://localhost:9099"
KEY = "fake-api-key"

accounts = [
    ("yr62813@gmail.com", "REDACTED_TEST_PASSWORD"),
    ("yuniorrodriguezo4601@yahoo.com", "TestYahoo123!"),
]

for email, pwd in accounts:
    r = requests.post(
        f"{AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={KEY}",
        json={"email": email, "password": pwd, "returnSecureToken": True},
    )
    data = r.json()
    if "idToken" not in data:
        print(f"❌ {email}: {data.get('error', {}).get('message', 'unknown error')}")
        continue

    r2 = requests.post(
        f"{AUTH}/identitytoolkit.googleapis.com/v1/accounts:update?key={KEY}",
        json={"idToken": data["idToken"], "emailVerified": True, "returnSecureToken": True},
    )
    verified = r2.json().get("emailVerified", False)
    print(f"✅ {email} → emailVerified = {verified}")
