"""Module promote_user.py."""
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import os

# Use service account
cred_path = os.path.join(os.getcwd(), 'functions/serviceAccountKey.json')
cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred)

db = firestore.client()

user_id = 'ZzHvLrQJ7GbFMMBVBIg9Nfj2rhl2'
print(f"Updating user {user_id} to admin...")
try:
    db.collection('users').document(user_id).update({
        'roles': ['admin', 'seller', 'buyer'],
        'role': 'admin' # Just in case it uses singular
    })
    print("Successfully updated user roles.")
except Exception as e:
    print(f"Error updating user: {e}")
