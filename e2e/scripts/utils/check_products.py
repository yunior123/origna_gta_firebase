#!/usr/bin/env python3
"""Quick check: verify products exist and are queryable in the Firestore emulator."""
import requests

FIRESTORE = "http://localhost:8080/v1/projects/orignagta/databases/(default)/documents"
HEADERS = {"Authorization": "Bearer owner", "Content-Type": "application/json"}

def rest_to_native(v):
    """Function rest_to_native."""
    if "stringValue" in v: return v["stringValue"]
    if "integerValue" in v: return int(v["integerValue"])
    if "doubleValue" in v: return float(v["doubleValue"])
    if "booleanValue" in v: return v["booleanValue"]
    if "timestampValue" in v: return v["timestampValue"]
    if "nullValue" in v: return None
    if "arrayValue" in v:
        return [rest_to_native(i) for i in v.get("arrayValue", {}).get("values", [])]
    if "mapValue" in v:
        return {k: rest_to_native(val) for k, val in v.get("mapValue", {}).get("fields", {}).items()}
    return v

# 1. Count all products
print("=" * 60)
print("1. ALL PRODUCTS IN COLLECTION")
r = requests.get(f"{FIRESTORE}/products?pageSize=100", headers=HEADERS)
docs = r.json().get("documents", [])
print(f"   Total: {len(docs)} documents")

# 2. Run the same query the Flutter app uses
print("\n2. FLUTTER APP QUERY: isActive==true, orderBy createdAt desc")
query = {
    "structuredQuery": {
        "from": [{"collectionId": "products"}],
        "where": {
            "fieldFilter": {
                "field": {"fieldPath": "isActive"},
                "op": "EQUAL",
                "value": {"booleanValue": True}
            }
        },
        "orderBy": [{"field": {"fieldPath": "createdAt"}, "direction": "DESCENDING"}],
        "limit": 20
    }
}
r2 = requests.post(f"{FIRESTORE}:runQuery", json=query, headers=HEADERS)
results = r2.json()
# Filter out empty results
results = [item for item in results if "document" in item]
print(f"   Results: {len(results)} products")

for i, item in enumerate(results[:5]):
    doc = item["document"]
    fields = doc.get("fields", {})
    name = fields.get("name", {}).get("stringValue", "?")
    price = fields.get("price", {}).get("doubleValue", 0)
    dc = fields.get("createdAt", {})
    dc_type = list(dc.keys())[0] if dc else "MISSING"
    print(f"   [{i+1}] {name} | ${price} | createdAt type: {dc_type}")

# 3. Check first product deserialization
if results:
    print("\n3. FIRST PRODUCT - FULL DESERIALIZATION CHECK")
    doc = results[0]["document"]
    fields = doc.get("fields", {})
    native = {k: rest_to_native(v) for k, v in fields.items()}
    native["productId"] = doc["name"].split("/")[-1]
    
    required = ["productId", "name", "price", "description", "imageUrls", "sellerId", "sellerAddress", "categoryId", "stockQuantity", "createdAt"]
    missing = [f for f in required if f not in native]
    print(f"   Missing required fields: {missing if missing else 'NONE ✅'}")
    
    addr = native.get("sellerAddress", {})
    if isinstance(addr, dict):
        addr_required = ["street", "city", "state", "postalCode"]
        addr_missing = [f for f in addr_required if f not in addr]
        print(f"   Missing address fields: {addr_missing if addr_missing else 'NONE ✅'}")
    else:
        print(f"   ⚠️ sellerAddress is not a map: {type(addr)}")
    
    print(f"   createdAt = {native.get('createdAt')}")
    print(f"   categoryId type = {type(native.get('categoryId')).__name__} = {native.get('categoryId')}")

# 4. Check for products without createdAt (would break orderBy)
print("\n4. PRODUCTS WITHOUT createdAt FIELD")
bad_count = 0
for doc_data in docs:
    fields = doc_data.get("fields", {})
    if "createdAt" not in fields:
        name = fields.get("name", {}).get("stringValue", "?")
        print(f"   ⚠️ MISSING createdAt: {name}")
        bad_count += 1
print(f"   {bad_count} products missing createdAt" if bad_count else "   All products have createdAt ✅")

# 5. Check createdAt types (mixed types would break ordering)
print("\n5. createdAt TYPE CHECK")
types = {}
for doc_data in docs:
    fields = doc_data.get("fields", {})
    dc = fields.get("createdAt", {})
    t = list(dc.keys())[0] if dc else "MISSING"
    types[t] = types.get(t, 0) + 1
for t, count in types.items():
    print(f"   {t}: {count} products")
if len(types) > 1:
    print("   ⚠️ MIXED TYPES - This can break Firestore orderBy!")

print("\n" + "=" * 60)
