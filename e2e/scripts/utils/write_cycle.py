#!/usr/bin/env python3
"""Helper: writes the cycle-order.py script to /tmp."""
script = r'''#!/usr/bin/env python3
import requests, time

FIRESTORE = "http://localhost:8080"
PROJECT = "orignagta"
ORDER_ID = "order_test_008"
URL = f"{FIRESTORE}/v1/projects/{PROJECT}/databases/(default)/documents/orders/{ORDER_ID}"
HEADERS = {"Authorization": "Bearer owner"}

TRANSITIONS = [
    ("confirmed", "processing", None, "processing"),
    ("processing", "shipped", "CP123456789CA", "shipped"),
    ("shipped", "in_transit", None, "in_transit"),
    ("in_transit", "delivered", None, "delivered"),
]

def update_order(order_status, tracking=None, item_status=None):
    r = requests.get(URL, headers=HEADERS)
    if r.status_code != 200:
        print(f"   Failed to fetch: {r.status_code}")
        return False
    doc = r.json()
    fields = dict(doc["fields"])
    fields["orderStatus"] = {"stringValue": order_status}
    ts = time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime())
    fields["updatedAt"] = {"timestampValue": ts}
    if order_status == "delivered":
        fields["deliveredAt"] = {"timestampValue": ts}
    if "items" in fields and "arrayValue" in fields["items"]:
        items = fields["items"]["arrayValue"].get("values", [])
        for item in items:
            mf = item.get("mapValue", {}).get("fields", {})
            mf["status"] = {"stringValue": item_status or order_status}
            if order_status in ("shipped", "delivered"):
                mf["deliveryStatus"] = {"stringValue": order_status}
            if tracking:
                mf["trackingNumber"] = {"stringValue": tracking}
                mf["carrier"] = {"stringValue": "Canada Post"}
            if order_status == "shipped":
                mf["shippedAt"] = {"timestampValue": ts}
            if order_status == "delivered":
                mf["deliveredAt"] = {"timestampValue": ts}
    payload = {"fields": fields}
    r2 = requests.patch(URL, json=payload, headers=HEADERS)
    return r2.status_code in (200, 201)

print("Cycling order_test_008 (10s intervals)")
for i, (f_s, t_s, trk, its) in enumerate(TRANSITIONS):
    print(f"\n[{i+1}/4] {f_s} -> {t_s}")
    if update_order(t_s, trk, its):
        print(f"   OK -> {t_s} (items -> {its})")
    else:
        print("   FAIL")
    if i < len(TRANSITIONS) - 1:
        print("   Waiting 10s...")
        time.sleep(10)
print("\nDone! order_test_008 is now DELIVERED")
'''

with open("/tmp/cycle-order.py", "w") as f:
    f.write(script)
print("Cycle script written to /tmp/cycle-order.py")
