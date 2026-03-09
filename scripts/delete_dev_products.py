"""Module delete_dev_products.py."""
import firebase_admin
from firebase_admin import firestore
import subprocess

PROJECT_ID = "orignagta-dev"

def get_access_token():
    """Get Access Token from gcloud."""
    try:
        token = subprocess.check_output(
            ["gcloud", "auth", "print-access-token"],
            text=True
        ).strip()
        return token
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to get access token: {e}")
        return None

def delete_all_products():
    """Function delete_all_products."""
    print(f"xx Deleting all products in {PROJECT_ID}...")
    token = get_access_token()
    if not token:
        return

    import google.oauth2.credentials
    cred = google.oauth2.credentials.Credentials(token)
    try:
        app = firebase_admin.get_app()
    except ValueError:
        app = firebase_admin.initialize_app(cred, {'projectId': PROJECT_ID})

    db = firestore.client()
    
    docs = list(db.collection("products").list_documents())
    print(f"📦 Found {len(docs)} products to delete.")
    
    batch = db.batch()
    count = 0
    for doc in docs:
        batch.delete(doc)
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
            print(f"Deleted {count}...")
            
    if count % 400 != 0:
        batch.commit()
        
    print(f"✅ Deleted {count} products.")

if __name__ == "__main__":
    delete_all_products()
