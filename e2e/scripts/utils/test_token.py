#!/usr/bin/env python3
"""Module test_token.py."""
import json
import base64
from urllib.request import Request, urlopen

AUTH = 'http://localhost:9099'

def post(url, data):
    """Function post."""
    req = Request(url, json.dumps(data).encode(), {'Content-Type': 'application/json'})
    return json.loads(urlopen(req).read())

def decode_token(token):
    """Function decode_token."""
    p = token.split('.')[1]
    p += '=' * (4 - len(p) % 4)
    return json.loads(base64.b64decode(p))

# Step 1: Sign in
r1 = post(f'{AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
    {'email': 'yuniorrodriguezo460@gmail.com', 'password': 'REDACTED_TEST_PASSWORD', 'returnSecureToken': True})
token1 = r1['idToken']
j1 = decode_token(token1)
print('Before update - email_verified:', j1.get('email_verified'))

# Step 2: Update emailVerified
r2 = post(f'{AUTH}/identitytoolkit.googleapis.com/v1/accounts:update?key=fake-api-key',
    {'idToken': token1, 'emailVerified': True, 'returnSecureToken': True})
token2 = r2.get('idToken', '')
if token2:
    j2 = decode_token(token2)
    print('After update - email_verified:', j2.get('email_verified'))
else:
    print('No token in update response:', json.dumps(r2)[:200])

# Step 3: Try calling create_checkout_session with updated token
print('\nTesting callable with updated token...')
test_token = token2 or token1
callable_url = 'http://localhost:5001/orignagta/us-central1/create_checkout_session'
payload = {'data': {'userId': r1['localId'], 'items': [], 'subtotal': 0, 'shippingAddress': {}}}
try:
    req = Request(callable_url, json.dumps(payload).encode(), {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {test_token}'
    })
    resp = json.loads(urlopen(req).read())
    print('Callable response:', json.dumps(resp)[:300])
except Exception as e:
    error_body = e.read().decode() if hasattr(e, 'read') else str(e)
    print('Callable error:', error_body[:300])
