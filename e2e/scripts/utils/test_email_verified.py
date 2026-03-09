#!/usr/bin/env python3
"""Test email_verified token flow in Firebase Auth Emulator"""
import json
import base64
from urllib.request import Request, urlopen

AUTH = 'http://localhost:9099'
PROJECT = 'orignagta'

def post_json(url, data, method='POST'):
    """Function post_json."""
    req = Request(url, json.dumps(data).encode(), {'Content-Type': 'application/json'})
    if method != 'POST':
        req.get_method = lambda: method
    return json.loads(urlopen(req).read())

def decode_jwt(token):
    """Function decode_jwt."""
    p = token.split('.')[1]
    p += '=' * (4 - len(p) % 4)
    return json.loads(base64.b64decode(p))

# Step 1: Sign in first to get uid and token
sign_in = post_json(
    f'{AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
    {'email': 'yuniorrodriguezo460@gmail.com', 'password': 'REDACTED_TEST_PASSWORD', 'returnSecureToken': True}
)
uid = sign_in['localId']
claims_before = decode_jwt(sign_in['idToken'])
print(f"Initial token email_verified: {claims_before.get('email_verified')}")

# Step 2: PATCH via emulator admin
try:
    req = Request(
        f'{AUTH}/emulator/v1/projects/{PROJECT}/accounts',
        json.dumps({'localId': uid, 'emailVerified': True}).encode(),
        {'Content-Type': 'application/json'}
    )
    req.get_method = lambda: 'PATCH'
    resp = urlopen(req)
    print(f"PATCH status: {resp.status}")
except Exception as e:
    print(f"PATCH failed: {e}")

# Step 3: Sign in again to get new token after PATCH
sign_in2 = post_json(
    f'{AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
    {'email': 'yuniorrodriguezo460@gmail.com', 'password': 'REDACTED_TEST_PASSWORD', 'returnSecureToken': True}
)
claims_after = decode_jwt(sign_in2['idToken'])
print(f"After PATCH+signIn token email_verified: {claims_after.get('email_verified')}")

# Step 4: Try token exchange to get a fresh token
try:
    exchange = post_json(
        f'{AUTH}/securetoken.googleapis.com/v1/token?key=fake-api-key',
        {'grant_type': 'refresh_token', 'refresh_token': sign_in2['refreshToken']}
    )
    new_token = exchange.get('id_token', exchange.get('access_token', ''))
    if new_token:
        new_claims = decode_jwt(new_token)
        print(f"Refreshed token email_verified: {new_claims.get('email_verified')}")
    else:
        print(f"Token exchange response: {json.dumps(exchange)[:200]}")
except Exception as e:
    error_body = e.read().decode() if hasattr(e, 'read') else str(e)
    print(f"Token exchange failed: {error_body[:200]}")
