"""Module cleanup_db.py."""
import firebase_admin
from firebase_admin import credentials, firestore
import os

key_path = 'functions/serviceAccountKey.json'

if not os.path.exists(key_path):
    print(f"Error: {key_path} not found.")
    exit(1)

try:
    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    # Delete 'Python Created Product'
    # Use ID 'zTVh0K15gMSPzPHeJ5M4' from logs, or search by name.
    
    docs = db.collection('products').where('name', '==', 'Python Created Product').stream()
    for doc in docs:
        print(f"Deleting {doc.id}...")
        doc.reference.delete()
        
    print("Cleanup complete.")

except Exception as e:
    print(f"Error: {e}")
