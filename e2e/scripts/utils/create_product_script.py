"""Module create_product_script.py."""
import firebase_admin
from firebase_admin import credentials, firestore
import os
import datetime

key_path = 'functions/serviceAccountKey.json'

if not os.path.exists(key_path):
    print(f"Error: {key_path} not found.")
    exit(1)

try:
    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    # Create product
    doc_ref = db.collection('products').document()
    doc_ref.set({
        'name': 'Python Created Product',
        'description': 'Created via python script for verification',
        'price': 10.0,
        'stock': 100,
        'createdAt': datetime.datetime.now(datetime.timezone.utc),
        'isActive': True
    })
    
    print(f"Created product with ID: {doc_ref.id}")

    # Verify it exists
    doc = db.collection('products').document(doc_ref.id).get()
    if doc.exists:
        print("Verified existence in Firestore.")
    else:
        print("Failed to verify existence.")

except Exception as e:
    print(f"Error: {e}")
