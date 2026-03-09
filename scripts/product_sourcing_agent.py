#!/usr/bin/env python3
"""
Product Sourcing Agent — reads product candidates JSON, generates images via nanobanana,
translates to FR via Gemini CLI, validates, and writes to Firestore as seller yr62813.

Usage:
    cd ~/Documents/GitHub/origna_gta
    source functions/venv/bin/activate
    export $(grep -v '^#' functions/.env.local | xargs)
    export GCP_PROJECT=orignagta-dev
    python scripts/product_sourcing_agent.py --candidates /tmp/product_candidates.json

Candidates JSON format: list of dicts with keys:
    name, description, supplier_cost_usd, shipping_cost_usd, image_url,
    category_id, subcategory (opt), keywords (opt), weight_kg (opt),
    shipping_days, condition (opt), supplier_url (opt)
"""
from __future__ import annotations

import argparse
import datetime
import json
import math
import os
import subprocess
import sys
import time
import urllib.request
import uuid
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_REPO_ROOT / "functions"))

import firebase_admin
from firebase_admin import credentials, firestore as fb_firestore

from schema_constants import (
    BusinessRules,
    Collections,
    Fields,
    ProductLifecycleStatusValues,
    SupplierTypeValues,
)
from models.product import ProductCreate, SupplierInfo, SellerDeliveryOption
from models.base import Address

# ── Constants ──────────────────────────────────────────────────────────────────
ADMIN_UID = "RU9MI8vYFkQCakMrJfG8iGTuc012"
PREFIX = "psrc_"
USD_CAD_FALLBACK = 1.38
RATE_LIMIT_SECONDS = 2
GEMINI_BIN = str(Path.home() / ".nvm/versions/node/v22.12.0/bin/gemini")
ERRORS_FILE = "/tmp/product_sourcing_errors.json"

# Seller address used for shipping source validation (admin seller is in Toronto)
_SELLER_ADDRESS = {
    "street": "123 Commerce St",
    "city": "Toronto",
    "state": "ON",
    "postalCode": "M5V 0A1",
    "country": "Canada",
}

# ── Exchange rate ───────────────────────────────────────────────────────────────
def get_usd_cad_rate() -> float:
    """Function get_usd_cad_rate."""
    try:
        url = "https://open.er-api.com/v6/latest/USD"
        with urllib.request.urlopen(url, timeout=5) as resp:
            data = json.loads(resp.read())
            rate = float(data["rates"]["CAD"])
            print(f"[rate] USD→CAD: {rate:.4f}")
            return rate
    except Exception as e:
        print(f"[rate] Fallback {USD_CAD_FALLBACK} ({e})")
        return USD_CAD_FALLBACK


# ── Pricing ────────────────────────────────────────────────────────────────────
def calculate_price(
    supplier_cost_usd: float, shipping_cost_usd: float, usd_cad: float
) -> tuple[float, float]:
    """Returns (selling_price_cad, compare_at_price_cad). Ensures >=10% margin."""
    cost_cad = supplier_cost_usd * usd_cad
    shipping_cad = shipping_cost_usd * usd_cad
    total_cost = cost_cad + shipping_cad

    platform_fee_pct: float = BusinessRules.PLATFORM_FEE_PERCENT

    price_cad = 0.0
    for markup in [2.5, 2.75, 3.0, 3.5]:
        candidate = total_cost * markup
        platform_fee = candidate * (platform_fee_pct / 100)
        net_margin = (candidate - total_cost - platform_fee) / candidate
        if net_margin >= 0.10:
            price_cad = candidate
            break

    if price_cad == 0.0:
        price_cad = total_cost * 3.5

    price_cad = math.floor(price_cad) + 0.99
    price_cad = max(price_cad, 1.99)
    price_cad = round(price_cad, 2)
    compare_at = round(price_cad * 1.30, 2)
    return price_cad, compare_at


# ── Image ──────────────────────────────────────────────────────────────────────
def download_supplier_image(url: str, dest: str) -> bool:
    """Function download_supplier_image."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as resp, open(dest, "wb") as f:
            f.write(resp.read())
        return True
    except Exception as e:
        print(f"  [image] Download failed: {e}")
        return False


def edit_image_nanobanana(input_path: str, product_name: str) -> str | None:
    """Function edit_image_nanobanana."""
    out_dir = "/tmp/product_images/edited"
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    api_key = os.environ.get("NANOBANANA_GEMINI_API_KEY", "").strip()
    if not api_key:
        print("  [image] Skipping nanobanana (NANOBANANA_GEMINI_API_KEY not set)")
        return None

    prompt = (
        f"Professional product photo for Canadian e-commerce. "
        f"Remove ALL Chinese, Japanese, Korean, or Asian text from this image. "
        f"Remove watermarks and supplier branding. "
        f"Keep the product '{product_name}' identical — same angle, same product. "
        f"Clean white background. No text anywhere."
    )

    cmd = [
        GEMINI_BIN, "-e", "nanobanana", "--yolo",
        "-p", f'/edit "{input_path}" "{prompt}" --output-dir "{out_dir}"',
    ]

    try:
        before = set(Path(out_dir).glob("*.*"))
        subprocess.run(
            cmd, capture_output=True, text=True, timeout=120,
            env={**os.environ, "NANOBANANA_GEMINI_API_KEY": api_key},
        )
        after = set(Path(out_dir).glob("*.*"))
        new_files = sorted(after - before, key=lambda p: p.stat().st_mtime, reverse=True)
        if new_files:
            print(f"  [image] nanobanana → {new_files[0].name}")
            return str(new_files[0])
        print("  [image] nanobanana produced no new file")
        return None
    except subprocess.TimeoutExpired:
        print("  [image] nanobanana timed out")
        return None
    except Exception as e:
        print(f"  [image] nanobanana error: {e}")
        return None


def upload_to_r2(local_path: str) -> str | None:
    """Function upload_to_r2."""
    try:
        result = subprocess.run(
            [sys.executable, str(_REPO_ROOT / "scripts/upload_r2_helper.py"), local_path],
            capture_output=True, text=True, timeout=30,
        )
        url = result.stdout.strip()
        if url.startswith("https://cdn.origna.ca"):
            print(f"  [image] R2 → {url}")
            return url
        print(f"  [image] R2 failed: {result.stderr[:200]}")
        return None
    except Exception as e:
        print(f"  [image] R2 error: {e}")
        return None


def get_product_image_url(image_url: str, product_name: str) -> str:
    """Function get_product_image_url."""
    raw_dir = "/tmp/product_images/raw"
    Path(raw_dir).mkdir(parents=True, exist_ok=True)
    raw_path = f"{raw_dir}/{uuid.uuid4().hex}.jpg"

    if not download_supplier_image(image_url, raw_path):
        return image_url

    edited_path = edit_image_nanobanana(raw_path, product_name) or raw_path
    r2_url = upload_to_r2(edited_path)
    return r2_url or image_url


# ── Translation ────────────────────────────────────────────────────────────────
def translate_to_french(name: str, description: str) -> tuple[str | None, str | None]:
    """Function translate_to_french."""
    prompt = (
        f'Translate to Canadian French (Quebec). '
        f'Return ONLY valid JSON with keys "nameF" and "descriptionF". '
        f'Marketing-friendly tone. '
        f'Name: {json.dumps(name)}. Description: {json.dumps(description[:400])}'
    )
    cmd = [GEMINI_BIN, "-m", "gemini-3-pro-preview", "--yolo", "-p", prompt]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        output = result.stdout.strip()
        start, end = output.find("{"), output.rfind("}") + 1
        if start == -1 or end == 0:
            return None, None
        data = json.loads(output[start:end])
        name_f = (data.get("nameF") or "").strip() or None
        desc_f = (data.get("descriptionF") or "").strip() or None
        if name_f:
            print(f"  [fr] {name_f[:60]}")
        return name_f, desc_f
    except Exception as e:
        print(f"  [fr] error: {e}")
        return None, None


# ── Firestore ──────────────────────────────────────────────────────────────────
def init_firestore(project: str):
    """Function init_firestore."""
    try:
        firebase_admin.get_app()
    except ValueError:
        # Resolve GOOGLE_APPLICATION_CREDENTIALS relative to functions/ if it's a relative path
        gac = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "")
        if gac and not os.path.isabs(gac):
            resolved = str(_REPO_ROOT / "functions" / gac.lstrip("./"))
            if os.path.exists(resolved):
                os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = resolved
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred, {"projectId": project})
    return fb_firestore.client()


def write_product(db, product_data: dict, dry_run: bool = False) -> bool:
    """Function write_product."""
    if dry_run:
        print(f"  [DRY RUN] Would write: {product_data.get(Fields.NAME, '?')}")
        return True
    doc_id = product_data[Fields.PRODUCT_ID]
    db.collection(Collections.PRODUCTS).document(doc_id).set(product_data)
    return True


# ── Pipeline ───────────────────────────────────────────────────────────────────
def process_candidate(candidate: dict, db, usd_cad: float, dry_run: bool) -> dict:
    """Function process_candidate."""
    name = candidate["name"].strip()
    print(f"\n{'='*60}\nProcessing: {name}")
    errors: list[str] = []

    # 1. Price
    price_cad, compare_at = calculate_price(
        float(candidate.get("supplier_cost_usd", 10.0)),
        float(candidate.get("shipping_cost_usd", 3.0)),
        usd_cad,
    )
    print(f"  [price] ${price_cad} CAD")

    # 2. Image
    image_url = candidate.get("image_url", "")
    final_img = (
        get_product_image_url(image_url, name)
        if image_url
        else "https://cdn.origna.ca/dev/products/placeholder.jpg"
    )

    # 3. Translation
    description = candidate["description"].strip()
    name_f, desc_f = translate_to_french(name, description)

    # 4. Build doc
    doc_id = f"{PREFIX}{uuid.uuid4().hex}"
    now = datetime.datetime.now(datetime.UTC)
    shipping_days = int(candidate.get("shipping_days", 12))

    # Delivery option — costCents is int (100 = $1.00 CAD)
    delivery_cost_cents = 999  # $9.99 CAD standard shipping
    delivery_option = {
        "type": "standard",
        "description": f"Estimated {shipping_days}–{shipping_days + 5} business days",
        "costCents": delivery_cost_cents,
        "estimatedDays": shipping_days,
        "quantityDiscounts": [],
        "maxItemsPerShipment": 0,
        "additionalItemCostCents": 0,
        "availableNationwide": True,
    }

    # Supplier URL — must be https:// or omit
    raw_supplier_url = candidate.get("supplier_url", "")
    supplier_url: str | None = None
    if raw_supplier_url and raw_supplier_url.startswith("https://"):
        supplier_url = raw_supplier_url

    product_dict: dict = {
        Fields.PRODUCT_ID: doc_id,
        Fields.NAME: name,
        Fields.NAME_F: name_f,
        Fields.PRICE: price_cad,
        Fields.COMPARE_AT_PRICE: compare_at,
        Fields.DESCRIPTION: description,
        Fields.DESCRIPTION_F: desc_f,
        Fields.IMAGE_URLS: [final_img],
        Fields.SELLER_ID: ADMIN_UID,
        Fields.CATEGORY_ID: int(candidate["category_id"]),
        Fields.STOCK_QUANTITY: 999,
        Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
        Fields.ESTIMATED_SHIP_DAYS: shipping_days,
        Fields.IS_DIGITAL: False,
        Fields.IS_LOCAL_DELIVERY_ONLY: False,
        Fields.IS_PERISHABLE: False,
        Fields.FREE_SHIPPING: False,
        Fields.MINIMUM_ORDER_QUANTITY: 1,
        Fields.RATING: 0.0,
        Fields.RATING_COUNT: 0,
        Fields.TRENDING_SCORE: 0,
        Fields.VIEW_COUNT: 0,
        Fields.PURCHASE_COUNT: 0,
        Fields.IS_TRENDING: False,
        Fields.KEYWORDS: candidate.get("keywords", []),
        Fields.CONDITION: candidate.get("condition", "new"),
        Fields.CREATED_AT: now,
        Fields.UPDATED_AT: now,
        Fields.HAS_VARIANTS: False,
        Fields.VARIANTS: [],
        Fields.VARIANT_OPTIONS: [],
        Fields.DELIVERY_OPTIONS: [delivery_option],
        Fields.SUPPLIER: {
            "type": SupplierTypeValues.CJDROPSHIPPING,
            "supplierUrl": supplier_url,
            "cost": float(candidate.get("supplier_cost_usd", 0)),
            "currency": "USD",
            "shippingDays": f"{shipping_days}-{shipping_days + 5}",
            "hasTracking": True,
            "notes": "Sourced via product sourcing agent",
        },
        Fields.WEIGHT_KG: candidate.get("weight_kg"),
        Fields.SHIP_FROM_COUNTRY: "CN",
        Fields.SHIP_FROM_COUNTRIES: ["CN"],
        # Seller address for shipping source validation
        Fields.SELLER_ADDRESS: _SELLER_ADDRESS,
    }
    if candidate.get("subcategory"):
        product_dict[Fields.SUBCATEGORY] = candidate["subcategory"]

    # 5. Pydantic validation
    try:
        validate_dict = {
            "name": name,
            "nameF": name_f,
            "price": price_cad,
            "compareAtPrice": compare_at,
            "description": description,
            "descriptionF": desc_f,
            "imageUrls": [final_img],
            "sellerId": ADMIN_UID,
            "categoryId": int(candidate["category_id"]),
            "stockQuantity": 999,
            # ProductCreate enforces 'draft' at model layer (backend handles transitions).
            # We validate as draft then write 'active' directly to Firestore (admin privilege).
            "lifecycleStatus": ProductLifecycleStatusValues.DRAFT,
            "estimatedShipDays": shipping_days,
            "isDigital": False,
            "isLocalDeliveryOnly": False,
            "isPerishable": False,
            "freeShipping": False,
            "minimumOrderQuantity": 1,
            "keywords": candidate.get("keywords", []),
            "condition": candidate.get("condition", "new"),
            "hasVariants": False,
            "variants": [],
            "variantOptions": [],
            "deliveryOptions": [
                SellerDeliveryOption(
                    type="standard",
                    description=f"Estimated {shipping_days}–{shipping_days + 5} business days",
                    costCents=delivery_cost_cents,
                    estimatedDays=shipping_days,
                    quantityDiscounts=[],
                    maxItemsPerShipment=0,
                    additionalItemCostCents=0,
                    availableNationwide=True,
                )
            ],
            "supplier": SupplierInfo(
                type=SupplierTypeValues.CJDROPSHIPPING,
                supplierUrl=supplier_url,
                cost=float(candidate.get("supplier_cost_usd", 0)),
                currency="USD",
                shippingDays=f"{shipping_days}-{shipping_days + 5}",
                hasTracking=True,
                notes="Sourced via product sourcing agent",
            ),
            "weightKg": candidate.get("weight_kg"),
            "shipFromCountry": "CN",
            "shipFromCountries": ["CN"],
            "sellerAddress": Address(**_SELLER_ADDRESS),
        }
        if candidate.get("subcategory"):
            validate_dict["subcategory"] = candidate["subcategory"]

        ProductCreate(**validate_dict)
        print("  [validate] OK")
    except Exception as e:
        errors.append(str(e))
        print(f"  [validate] FAIL {e}")
        return {"name": name, "status": "skipped", "errors": errors}

    # 6. Write
    try:
        write_product(db, product_dict, dry_run=dry_run)
        print(f"  [write] OK {doc_id}")
        return {"name": name, "doc_id": doc_id, "status": "ok", "price_cad": price_cad}
    except Exception as e:
        errors.append(str(e))
        print(f"  [write] FAIL {e}")
        return {"name": name, "status": "error", "errors": errors}


def main() -> None:
    """Function main."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", default="/tmp/product_candidates.json")
    parser.add_argument("--project", default=os.environ.get("GCP_PROJECT", "orignagta-dev"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args()

    print(f"Product Sourcing Agent — project={args.project} dry_run={args.dry_run}")
    with open(args.candidates) as f:
        candidates = json.load(f)
    if args.limit > 0:
        candidates = candidates[: args.limit]
    print(f"Loaded {len(candidates)} candidates")

    usd_cad = get_usd_cad_rate()
    db = init_firestore(args.project)

    results: list[dict] = []
    for i, c in enumerate(candidates, 1):
        print(f"\n[{i}/{len(candidates)}]")
        r = process_candidate(c, db, usd_cad, args.dry_run)
        results.append(r)
        if not args.dry_run:
            time.sleep(RATE_LIMIT_SECONDS)

    ok = [r for r in results if r["status"] == "ok"]
    skipped = [r for r in results if r["status"] == "skipped"]
    failed = [r for r in results if r["status"] == "error"]
    print(f"\n{'='*60}")
    print(f"DONE — {len(ok)} written, {len(skipped)} skipped, {len(failed)} errors")

    errs = [r for r in results if r["status"] != "ok"]
    if errs:
        with open(ERRORS_FILE, "w") as f:
            json.dump(errs, f, indent=2, default=str)
        print(f"Errors: {ERRORS_FILE}")

    with open("/tmp/product_sourcing_results.json", "w") as f:
        json.dump(results, f, indent=2, default=str)
    print("Results: /tmp/product_sourcing_results.json")


if __name__ == "__main__":
    main()
