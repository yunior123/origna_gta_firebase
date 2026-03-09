"""Module check_firestore.py."""
import firebase_admin
from firebase_admin import credentials, firestore
import os

key_path = 'functions/serviceAccountKey.json'

if not os.path.exists(key_path):
    print(f"Error: Key file not found at {os.path.abspath(key_path)}")
    exit(1)

try:
    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    print(f"Connected to project: {db.project}")

    print("Listing all collections...")
    collections = [c.id for c in db.collections()]
    print(f"Collections: {collections}")

    # Check 'users' collection
    print("Checking 'users' collection...")
    users = list(db.collection('users').limit(5).stream())
    print(f"Found {len(users)} users.")
    for u in users:
        print(f"User: {u.id} - {u.to_dict().get('email')}")

    # Try to order by desc to get latest created
    print("Fetching ALL products count...")
    all_products = list(db.collection('products').stream()) # Assuming small db
    print(f"Total Products: {len(all_products)}")
    
    for p in all_products:
        data = p.to_dict()
        print(f"Product: {data.get('name')} (ID: {p.id})")
        if data.get('imageUrl') or data.get('imageUrls'):
             print(f"  Images: {data.get('imageUrl') or data.get('imageUrls')}")
            
except Exception as e:
    print(f"An error occurred: {e}")
