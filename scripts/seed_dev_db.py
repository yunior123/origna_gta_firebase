"""Module seed_dev_db.py."""

import firebase_admin
from firebase_admin import credentials, firestore, auth
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

PROJECT_ID = "orignagta-dev"

import subprocess
import google.auth.transport.requests
import google.oauth2.credentials

def get_access_token():
    """Function get_access_token."""
    try:
        token = subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode("utf-8").strip()
        return token
    except Exception as e:
        print(f"Error getting access token: {e}")
        return None

def initialize_firebase():
    """Function initialize_firebase."""
    access_token = get_access_token()
    if access_token:
        cred = google.oauth2.credentials.Credentials(access_token)
        try:
            app = firebase_admin.get_app()
        except ValueError:
            app = firebase_admin.initialize_app(cred, {
                'projectId': PROJECT_ID,
            })
        return firestore.client()
    else:
        print("Falling back to default credentials (likely to fail without ADC)...")
        try:
            app = firebase_admin.get_app()
        except ValueError:
            cred = credentials.ApplicationDefault()
            app = firebase_admin.initialize_app(cred, {
                'projectId': PROJECT_ID,
            })
        return firestore.client()

def create_test_users(db):
    """Function create_test_users."""
    print("Creating test users...")
    users = [
        {"email": "seller@test.com", "password": "password123", "role": "seller", "name": "Test Seller", "start_uid": "test-seller-uid"},
        {"email": "buyer@test.com", "password": "password123", "role": "buyer", "name": "Test Buyer", "start_uid": "test-buyer-uid"},
        {"email": "admin@test.com", "password": "password123", "role": "admin", "name": "Test Admin", "start_uid": "test-admin-uid"},
    ]
    
    created_uids = {}
    
    for user_data in users:
        # Deterministic UID for testing
        uid = user_data.get("start_uid")
        
        try:
            # Try to create in Auth (might fail with quota error)
            # Wrap entire Auth block to ensure we proceed to Firestore even if Auth fails completely
            try:
                try:
                    user = auth.get_user(uid)
                    print(f"User {user_data['email']} (Auth) already exists: {user.uid}")
                except auth.UserNotFoundError:
                    user = auth.create_user(
                        uid=uid,
                        email=user_data["email"],
                        password=user_data["password"],
                        display_name=user_data["name"]
                    )
                    print(f"Created user {user_data['email']} (Auth): {user.uid}")
            except Exception as auth_e:
                 print(f"⚠️ Auth interaction failed for {user_data['email']} (likely quota project error). interacting with Firestore only using fake UID: {uid}. Auth Error: {auth_e}")
            
            created_uids[user_data["role"]] = uid

            # Create in Firestore (should work with valid access token)
            roles = [user_data["role"]]
            if user_data["role"] == "seller":
                roles = ["seller", "buyer"] # Sellers are also buyers
            if user_data["role"] == "admin":
                roles = ["admin", "buyer", "seller"]
            
            print(f"Creating Firestore doc for {uid}...")
            db.collection("users").document(uid).set({
                "email": user_data["email"],
                "name": user_data["name"],
                "roles": roles,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "onboardingCompleted": True,
                "suspended": False,
                "profilePictureUrl": f"https://ui-avatars.com/api/?name={user_data['name']}"
            }, merge=True)
            print(f"✅ Created Firestore user: {uid}")
            
        except Exception as e:
            print(f"Error processing user {user_data['email']}: {e}")
            
    return created_uids

def create_test_products(db, seller_uid):
    """Function create_test_products."""
    print("Creating test products...")
    products = [
        {
            "name": "Test Physical Product",
            "keywords": ["test", "physical", "product"],
            "description": "A wonderful physical product for testing.",
            "price": 29.99,
            "stockQuantity": 100,
            "isActive": True,
            "sellerId": seller_uid,
            "categoryId": 1,
            "imageUrls": ["https://picsum.photos/400/400"],
            "deliveryOptions": [{"type": "standard", "cost": 5.0, "estimatedDays": 3, "description": "Standard"}],
            "isDigital": False,
            "sellerAddress": {"street": "123 Test St", "city": "Toronto", "state": "ON", "postalCode": "M5V 2H1", "country": "CA"}
        },
        {
            "name": "Test Digital Product",
            "description": "A downloadable digital product.",
            "price": 9.99,
            "stockQuantity": 999,
            "isActive": True,
            "sellerId": seller_uid,
            "categoryId": 2,
            "imageUrls": ["https://picsum.photos/400/400"],
             "deliveryOptions": [],
            "isDigital": True,
            "freeShipping": True,
            "sellerAddress": {"street": "456 Digital Ave", "city": "Montreal", "state": "QC", "postalCode": "H3Z 2Y7", "country": "CA"}
        },
         {
            "name": "Test Local Product",
            "description": "Only available for local pickup.",
            "price": 50.00,
            "stockQuantity": 10,
            "isActive": True,
            "sellerId": seller_uid,
            "categoryId": 3,
            "imageUrls": ["https://picsum.photos/400/400"],
            "deliveryOptions": [{"type": "pickup", "cost": 0.0, "estimatedDays": 0, "description": "Pickup"}],
            "isLocalDeliveryOnly": True,
            "isDigital": False,
             "sellerAddress": {"street": "789 Local Ln", "city": "Vancouver", "state": "BC", "postalCode": "V6B 3P8", "country": "CA"}
        }
    ]
    
    for p in products:
        # Add required meta
        p["createdAt"] = firestore.SERVER_TIMESTAMP
        p["updatedAt"] = firestore.SERVER_TIMESTAMP
        p["rating"] = 0
        p["ratingCount"] = 0
        p["keywords"] = p["name"].lower().split()
        
        print(f"DEBUG PAYLOAD: {p}")
        db.collection("products").add(p)
        print(f"Created product: {p['name']}")

if __name__ == "__main__":
    print(f"🌱 Seeding {PROJECT_ID}...")
    db = initialize_firebase()
    uids = create_test_users(db)
    if "seller" in uids:
        create_test_products(db, uids["seller"])
    print("✅ Seeding complete!")
