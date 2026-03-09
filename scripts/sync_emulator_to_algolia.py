#!/usr/bin/env python3
"""
Sync emulator Firestore products to Algolia 'products_emulator' index.

Prerequisites:
  - Firebase emulators must be running (firebase emulators:start)
  - Algolia credentials must be in functions/.env

Usage:
    cd /path/to/origna_gta
    source functions/venv/bin/activate
    FUNCTIONS_EMULATOR=true python scripts/sync_emulator_to_algolia.py
"""
import os
import sys

# Force emulator mode so AlgoliaConfig.get_index_name() returns 'products_emulator'
os.environ['FUNCTIONS_EMULATOR'] = 'true'
os.environ['FIRESTORE_EMULATOR_HOST'] = 'localhost:8080'

# Add functions/ to path for project imports
FUNCTIONS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'functions')
sys.path.insert(0, FUNCTIONS_DIR)

# Load .env for Algolia credentials
from dotenv import load_dotenv
load_dotenv(os.path.join(FUNCTIONS_DIR, '.env'))

# Now import project modules (after env is set)
from algoliasearch.search.client import SearchClient
from config import AlgoliaConfig
from schema_constants import Fields

# Validate credentials
ALGOLIA_APP_ID = os.environ.get('ALGOLIA_APP_ID', '')
ALGOLIA_WRITE_API_KEY = os.environ.get('ALGOLIA_WRITE_API_KEY', '')

if not ALGOLIA_APP_ID or not ALGOLIA_WRITE_API_KEY:
    print("❌ ALGOLIA_APP_ID and ALGOLIA_WRITE_API_KEY required in functions/.env")
    sys.exit(1)

INDEX_NAME = AlgoliaConfig.get_index_name()
print(f"🎯 Target Algolia index: {INDEX_NAME}")
print(f"📡 Firestore emulator: {os.environ.get('FIRESTORE_EMULATOR_HOST')}")

# Connect to Firestore emulator
import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    # For emulator, use serviceAccountKey if available, else dummy init
    sa_path = os.path.join(FUNCTIONS_DIR, 'serviceAccountKey.json')
    if os.path.exists(sa_path):
        cred = credentials.Certificate(sa_path)
        firebase_admin.initialize_app(cred)
    else:
        os.environ.setdefault('GCLOUD_PROJECT', 'orignagta')
        firebase_admin.initialize_app(options={'projectId': 'orignagta'})

db = firestore.client()

# Fetch all active products from emulator Firestore
print("\n📦 Fetching products from emulator Firestore...")
products_ref = db.collection('products').where(filter=firestore.FieldFilter('isActive', '==', True))
docs = list(products_ref.stream())
print(f"   Found {len(docs)} active products")

if not docs:
    # Also try without the isActive filter (some seed data may not have it)
    print("   Trying without isActive filter...")
    all_docs = list(db.collection('products').stream())
    print(f"   Found {len(all_docs)} total products (including inactive)")
    if not all_docs:
        print("\n⚠️  No products found in emulator Firestore.")
        print("   Make sure emulators are running and products are seeded.")
        print("   To seed: cd e2e && npx ts-node seed-emulator.ts")
        sys.exit(0)
    docs = all_docs

# Format products for Algolia
algolia_objects = []
for doc in docs:
    data = doc.to_dict()
    obj = {
        'objectID': doc.id,
        Fields.NAME: data.get(Fields.NAME, ''),
        Fields.DESCRIPTION: data.get(Fields.DESCRIPTION, ''),
        Fields.PRICE: data.get(Fields.PRICE, 0.0),
        Fields.CATEGORY_ID: data.get(Fields.CATEGORY_ID, 0),
        Fields.SELLER_ID: data.get(Fields.SELLER_ID, ''),
        Fields.IMAGE_URLS: data.get(Fields.IMAGE_URLS, []),
        Fields.STOCK_QUANTITY: data.get(Fields.STOCK_QUANTITY, 0),
        Fields.RATING: data.get(Fields.RATING, 0.0),
        Fields.RATING_COUNT: data.get(Fields.RATING_COUNT, 0),
        Fields.LIFECYCLE_STATUS: data.get(Fields.LIFECYCLE_STATUS, ProductLifecycleStatusValues.ACTIVE),
        Fields.KEYWORDS: data.get(Fields.KEYWORDS, []) or data.get(Fields.SEARCH_KEYWORDS, []),
        Fields.FREE_SHIPPING: data.get(Fields.FREE_SHIPPING, False),
        Fields.IS_PERISHABLE: data.get(Fields.IS_PERISHABLE, False),
        Fields.IS_LOCAL_DELIVERY_ONLY: data.get(Fields.IS_LOCAL_DELIVERY_ONLY, False),
    }

    # Seller address
    addr = data.get(Fields.SELLER_ADDRESS)
    if addr:
        obj[Fields.SELLER_ADDRESS] = addr

    # Optional fields
    for field in [Fields.WEIGHT_KG, Fields.LENGTH_CM, Fields.WIDTH_CM, Fields.HEIGHT_CM,
                  Fields.TAX_CODE, Fields.DELIVERY_OPTIONS, Fields.ESTIMATED_SHIP_DAYS,
                  Fields.MINIMUM_ORDER_QUANTITY]:
        if field in data and data[field] is not None:
            obj[field] = data[field]

    # Convert Firestore timestamp to unix timestamp for sorting
    dc = data.get(Fields.CREATED_AT)
    if dc:
        if hasattr(dc, 'timestamp'):
            obj[Fields.CREATED_AT] = int(dc.timestamp())
        elif isinstance(dc, (int, float)):
            obj[Fields.CREATED_AT] = int(dc)

    algolia_objects.append(obj)
    name = data.get(Fields.NAME, '???')
    print(f"   ✅ {doc.id[:12]}...: {name}")

# Push to Algolia using asyncio (v4 client is async)
import asyncio

print(f"\n🚀 Pushing {len(algolia_objects)} products to Algolia index '{INDEX_NAME}'...")
client = SearchClient(ALGOLIA_APP_ID, ALGOLIA_WRITE_API_KEY)

async def push_and_verify():
    """Function push_and_verify."""
    try:
        resp = await client.save_objects(index_name=INDEX_NAME, objects=algolia_objects)
        print("✅ Upload complete!")
    except Exception as e:
        print(f"❌ Failed to push to Algolia: {e}")
        await client.close()
        sys.exit(1)

    # Wait for indexing and verify
    print("\n⏳ Waiting for Algolia to index...")
    await asyncio.sleep(3)

    try:
        from algoliasearch.search.models.search_params_object import SearchParamsObject
        results = await client.search_single_index(
            index_name=INDEX_NAME,
            search_params=SearchParamsObject(query='', hits_per_page=0),
        )
        print(f"📊 Index '{INDEX_NAME}' now has {results.nb_hits} total records")
    except Exception as e:
        print(f"⚠️  Could not verify (non-critical): {e}")

    await client.close()

asyncio.run(push_and_verify())

print(f"\n🎉 Done! {len(algolia_objects)} products synced to '{INDEX_NAME}'")
print(f"   Test with: algolia search {INDEX_NAME} -p origna -q \"test\"")
