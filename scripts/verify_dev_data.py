"""Module verify_dev_data.py."""

import firebase_admin
from firebase_admin import firestore
import subprocess
import google.oauth2.credentials
from dotenv import load_dotenv

load_dotenv("functions/.env")

PROJECT_ID = "orignagta-dev"

def get_access_token():
    """Function get_access_token."""
    try:
        return subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode("utf-8").strip()
    except Exception as e:
        print(f"Error getting token: {e}")
        return None

def verify_data():
    """Function verify_data."""
    print(f"🔍 Verifying data in {PROJECT_ID}...")
    token = get_access_token()
    if not token:
        return

    cred = google.oauth2.credentials.Credentials(token)
    try:
        app = firebase_admin.get_app()
    except ValueError:
        app = firebase_admin.initialize_app(cred, {'projectId': PROJECT_ID})

    db = firestore.client()
    
    # Check Products
    docs = list(db.collection("products").stream())
    print(f"📦 Found {len(docs)} products:")
    for doc in docs:
        data = doc.to_dict()
        print(f" - {doc.id}: {data.get('name')} (Active: {data.get('isActive')}, CreatedAt: {data.get('createdAt')})")

    # Check Users
    users = list(db.collection("users").stream())
    print(f"👤 Found {len(users)} users:")
    for user in users:
        print(f" - {user.id}: {user.to_dict().get('email')}")

if __name__ == "__main__":
    verify_data()
