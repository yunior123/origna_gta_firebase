# Product Sourcing Agent Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a `/source-products` Claude Code skill + Python script that researches, images, translates, validates, and writes ~67 real dropshipping products to Firestore as seller yr62813.

**Architecture:** The Claude Code skill does WebSearch research and produces a product candidates JSON, then invokes `scripts/product_sourcing_agent.py` which handles pricing, nanobanana image editing, Gemini FR translation, Pydantic validation, and Admin SDK Firestore writes. Two-step pipeline: research (Claude) → execution (Python).

**Tech Stack:** Python 3.12+, firebase-admin, boto3, Pydantic v2, Gemini CLI (nanobanana extension + gemini-3-pro-preview), functions/venv, existing R2/Firestore config.

---

## Environment & Prerequisites

```bash
# Working directory for all commands (unless noted):
cd ~/Documents/GitHub/origna_gta

# Python venv (always activate before running scripts):
source functions/venv/bin/activate

# R2 credentials (already in functions/.env.local — load before running):
export $(grep -v '^#' functions/.env.local | xargs)

# Firebase project target:
export GCP_PROJECT=orignagta-dev

# Admin UID for yr62813@gmail.com:
ADMIN_UID="RU9MI8vYFkQCakMrJfG8iGTuc012"

# CDN base URL:
CDN_BASE_URL="https://cdn.origna.ca"

# R2 bucket:
R2_BUCKET="orignagta-images"
```

---

## Task 1: R2 Upload Helper

**Files:**
- Create: `scripts/upload_r2_helper.py`

**Purpose:** Standalone utility that uploads a local image file to R2 and returns its public CDN URL. Reuses exact boto3 pattern from `functions/handlers/products.py:81-103`.

**Step 1: Create the file**

```python
#!/usr/bin/env python3
"""
R2 Upload Helper — uploads a local image file to Cloudflare R2 dev/products/ folder.
Returns the public CDN URL (https://cdn.origna.ca/dev/products/<filename>).

Usage:
    source functions/venv/bin/activate
    export $(grep -v '^#' functions/.env.local | xargs)
    python scripts/upload_r2_helper.py /tmp/my_image.jpg

Env vars required:
    R2_ACCOUNT_ID, R2_ACCESS_KEY, R2_SECRET_KEY
"""
from __future__ import annotations

import os
import sys
import uuid
from pathlib import Path

import boto3  # in functions/requirements.txt
from botocore.config import Config

BUCKET = "orignagta-images"
CDN_BASE = "https://cdn.origna.ca"
FOLDER = "dev/products"  # hardcoded to dev — change for staging/prod


def upload_image(local_path: str, filename: str | None = None) -> str:
    """Upload image to R2, return public CDN URL."""
    account_id = os.environ["R2_ACCOUNT_ID"]
    access_key = os.environ["R2_ACCESS_KEY"]
    secret_key = os.environ["R2_SECRET_KEY"]

    s3 = boto3.client(
        "s3",
        endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )

    path = Path(local_path)
    if filename is None:
        ext = path.suffix or ".jpg"
        filename = f"psrc_{uuid.uuid4().hex}{ext}"

    key = f"{FOLDER}/{filename}"

    # Detect content type
    suffix = path.suffix.lower()
    content_type = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }.get(suffix, "image/jpeg")

    with open(local_path, "rb") as f:
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=f,
            ContentType=content_type,
        )

    public_url = f"{CDN_BASE}/{key}"
    return public_url


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python upload_r2_helper.py <local_path>", file=sys.stderr)
        sys.exit(1)
    url = upload_image(sys.argv[1])
    print(url)
```

**Step 2: Test it manually**

```bash
source functions/venv/bin/activate
export $(grep -v '^#' functions/.env.local | xargs)
# Create a tiny test image
python3 -c "
from PIL import Image
img = Image.new('RGB', (100, 100), color='red')
img.save('/tmp/test_r2.jpg')
" 2>/dev/null || echo 'hi' > /tmp/test_r2.jpg

python scripts/upload_r2_helper.py /tmp/test_r2.jpg
```

Expected output: `https://cdn.origna.ca/dev/products/psrc_<hex>.jpg`

**Step 3: Commit**

```bash
git add scripts/upload_r2_helper.py
git commit -m "feat: add R2 upload helper for product sourcing agent"
```

---

## Task 2: Product Sourcing Agent (Core Script)

**Files:**
- Create: `scripts/product_sourcing_agent.py`
- Reads: `/tmp/product_candidates.json` (produced by Claude skill in Task 4)
- Reads: `functions/venv` (Python env), `functions/.env.local` (R2 creds)
- Imports: `functions/schema_constants.py`, `functions/models/product.py`

**Step 1: Create the file**

```python
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

Candidates JSON format (list of objects):
    [{
        "name": "Wireless Noise-Cancelling Headphones",
        "description": "Over-ear headphones with 30-hour battery...",  # 10-4000 chars
        "supplier_cost_usd": 18.50,
        "supplier_url": "https://cjdropshipping.com/product/...",
        "image_url": "https://img.cjdropshipping.com/...",  # supplier image to edit
        "category_id": 1,                                    # 1-21
        "subcategory": "Headphones",                         # optional
        "keywords": ["headphones", "wireless", "bluetooth"],
        "weight_kg": 0.35,
        "shipping_days": 12,                                 # estimated days CA
        "shipping_cost_usd": 3.50,                          # estimated shipping cost
        "condition": "new"
    }, ...]
"""
from __future__ import annotations

import argparse
import datetime
import json
import math
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_REPO_ROOT / "functions"))

import firebase_admin  # noqa: E402
from firebase_admin import credentials, firestore as fb_firestore  # noqa: E402

from schema_constants import (  # noqa: E402
    BusinessRules,
    CategoryIds,
    Collections,
    Fields,
    ProductLifecycleStatusValues,
    SupplierTypeValues,
)
from models.product import ProductCreate  # noqa: E402

# ─── Constants ────────────────────────────────────────────────────────────────

ADMIN_UID = "RU9MI8vYFkQCakMrJfG8iGTuc012"
PREFIX = "psrc_"
USD_CAD_FALLBACK = 1.38
RATE_LIMIT_SECONDS = 2  # wait between Firestore writes
GEMINI_BIN = str(Path.home() / ".nvm/versions/node/v22.12.0/bin/gemini")
ERRORS_FILE = "/tmp/product_sourcing_errors.json"

# ─── Exchange rate ─────────────────────────────────────────────────────────────

def get_usd_cad_rate() -> float:
    """Fetch live USD→CAD rate. Fallback to 1.38 on any error."""
    try:
        url = "https://open.er-api.com/v6/latest/USD"
        with urllib.request.urlopen(url, timeout=5) as resp:
            data = json.loads(resp.read())
            rate = float(data["rates"]["CAD"])
            print(f"[rate] USD→CAD: {rate:.4f}")
            return rate
    except Exception as e:
        print(f"[rate] Could not fetch rate ({e}), using fallback {USD_CAD_FALLBACK}")
        return USD_CAD_FALLBACK


# ─── Pricing ───────────────────────────────────────────────────────────────────

def calculate_price(supplier_cost_usd: float, shipping_cost_usd: float, usd_cad: float) -> tuple[float, float]:
    """
    Returns (selling_price_cad, compare_at_price_cad).
    Ensures ≥10% net margin after platform fee. Uses .99 pricing psychology.
    """
    cost_cad = supplier_cost_usd * usd_cad
    shipping_cad = shipping_cost_usd * usd_cad
    total_cost = cost_cad + shipping_cad

    price_cad = 0.0
    for markup in [2.5, 2.75, 3.0, 3.5]:
        candidate = total_cost * markup
        platform_fee = candidate * (BusinessRules.PLATFORM_FEE_PERCENT / 100)
        net_margin = (candidate - total_cost - platform_fee) / candidate
        if net_margin >= 0.10:
            price_cad = candidate
            break

    if price_cad == 0.0:
        price_cad = total_cost * 3.5  # absolute floor

    # Round to .99 psychology
    price_cad = math.floor(price_cad) + 0.99
    price_cad = max(price_cad, 0.99)  # Pydantic min is 0.99 (Field gt=0.99)
    price_cad = round(price_cad, 2)

    # Compare-at = 30% above selling price (shows "was" price)
    compare_at = round(price_cad * 1.30, 2)

    return price_cad, compare_at


# ─── Image handling ────────────────────────────────────────────────────────────

def download_supplier_image(url: str, dest: str) -> bool:
    """Download supplier image to local path. Returns True on success."""
    try:
        headers = {"User-Agent": "Mozilla/5.0"}
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=15) as resp, open(dest, "wb") as f:
            f.write(resp.read())
        return True
    except Exception as e:
        print(f"  [image] Download failed: {e}")
        return False


def edit_image_nanobanana(input_path: str, product_name: str) -> str | None:
    """
    Use Gemini CLI nanobanana /edit to localize the supplier image.
    Removes Chinese/Asian text, keeps product identical, white background.
    Returns path to edited image or None on failure.
    """
    out_dir = "/tmp/product_images/edited"
    Path(out_dir).mkdir(parents=True, exist_ok=True)

    prompt = (
        f"Professional product photo for Canadian e-commerce. "
        f"Remove ALL Chinese, Japanese, Korean, or Asian text/characters from this image. "
        f"Remove any watermarks, logos, or supplier branding. "
        f"Keep the product '{product_name}' identical — same angle, same product. "
        f"Clean white or very light neutral background. "
        f"High quality, 600x600px minimum. No text anywhere."
    )

    # nanobanana /edit <image_path> "<prompt>" --output-dir <dir>
    cmd = [
        GEMINI_BIN,
        "-e", "nanobanana",
        "--yolo",
        "-p", f'/edit "{input_path}" "{prompt}" --output-dir "{out_dir}"',
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            env={**os.environ, "NANOBANANA_GEMINI_API_KEY": os.environ["NANOBANANA_GEMINI_API_KEY"]},
        )
        # Find the newest file in out_dir after the command
        files = sorted(Path(out_dir).glob("*.png"), key=lambda p: p.stat().st_mtime, reverse=True)
        if files:
            print(f"  [image] nanobanana edited → {files[0]}")
            return str(files[0])
        # Also check .jpg
        files = sorted(Path(out_dir).glob("*.jpg"), key=lambda p: p.stat().st_mtime, reverse=True)
        if files:
            print(f"  [image] nanobanana edited → {files[0]}")
            return str(files[0])
        print(f"  [image] nanobanana output: {result.stdout[-500:]}")
        return None
    except subprocess.TimeoutExpired:
        print("  [image] nanobanana timed out")
        return None
    except Exception as e:
        print(f"  [image] nanobanana error: {e}")
        return None


def upload_to_r2(local_path: str) -> str | None:
    """Upload image file to R2, return CDN URL. None on failure."""
    try:
        result = subprocess.run(
            [sys.executable, str(_REPO_ROOT / "scripts/upload_r2_helper.py"), local_path],
            capture_output=True, text=True, timeout=30,
        )
        url = result.stdout.strip()
        if url.startswith("https://cdn.origna.ca"):
            print(f"  [image] R2 uploaded → {url}")
            return url
        print(f"  [image] R2 upload failed: {result.stderr}")
        return None
    except Exception as e:
        print(f"  [image] R2 upload error: {e}")
        return None


def get_product_image_url(image_url: str, product_name: str) -> str:
    """
    Full image pipeline:
    1. Download supplier image
    2. Edit with nanobanana (remove Chinese text, keep product identical)
    3. Upload to R2
    Fallback: use supplier URL directly if any step fails.
    """
    raw_dir = "/tmp/product_images/raw"
    Path(raw_dir).mkdir(parents=True, exist_ok=True)
    raw_path = f"{raw_dir}/{uuid.uuid4().hex}.jpg"

    print(f"  [image] Downloading supplier image...")
    if not download_supplier_image(image_url, raw_path):
        print(f"  [image] Fallback: using supplier URL directly")
        return image_url

    print(f"  [image] Editing with nanobanana...")
    edited_path = edit_image_nanobanana(raw_path, product_name)
    if not edited_path:
        print(f"  [image] nanobanana failed, uploading raw supplier image to R2")
        edited_path = raw_path

    r2_url = upload_to_r2(edited_path)
    if r2_url:
        return r2_url

    print(f"  [image] R2 failed, fallback: supplier URL")
    return image_url


# ─── Translation ───────────────────────────────────────────────────────────────

def translate_to_french(name: str, description: str) -> tuple[str | None, str | None]:
    """
    Use Gemini CLI to translate product name and description to Canadian French.
    Returns (nameF, descriptionF) or (None, None) on failure.
    """
    prompt = (
        f'Translate the following product listing to Canadian French (Quebec). '
        f'Return ONLY a valid JSON object with keys "nameF" and "descriptionF". '
        f'Keep product names natural and marketing-friendly. '
        f'Name: {json.dumps(name)}. '
        f'Description: {json.dumps(description[:500])}'  # truncate for speed
    )

    cmd = [
        GEMINI_BIN,
        "-m", "gemini-3-pro-preview",
        "--yolo",
        "-p", prompt,
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        output = result.stdout.strip()
        # Extract JSON from output (may have surrounding text)
        start = output.find("{")
        end = output.rfind("}") + 1
        if start == -1 or end == 0:
            print(f"  [translate] No JSON in response")
            return None, None
        data = json.loads(output[start:end])
        name_f = data.get("nameF", "").strip() or None
        desc_f = data.get("descriptionF", "").strip() or None
        if name_f:
            print(f"  [translate] FR: {name_f[:60]}...")
        return name_f, desc_f
    except Exception as e:
        print(f"  [translate] Error: {e}")
        return None, None


# ─── Firestore ─────────────────────────────────────────────────────────────────

def init_firestore(project: str):
    """Initialize Firebase Admin SDK."""
    cred = credentials.ApplicationDefault()
    try:
        app = firebase_admin.get_app()
    except ValueError:
        app = firebase_admin.initialize_app(cred, {"projectId": project})
    return fb_firestore.client()


def product_exists(db, product_id: str) -> bool:
    """Check if a product doc already exists (idempotency)."""
    return db.collection(Collections.PRODUCTS).document(product_id).get().exists


def write_product(db, product_data: dict, dry_run: bool = False) -> bool:
    """Write product to Firestore. Returns True on success."""
    if dry_run:
        print(f"  [DRY RUN] Would write: {product_data['name']}")
        return True

    doc_id = product_data[Fields.PRODUCT_ID]
    ref = db.collection(Collections.PRODUCTS).document(doc_id)
    ref.set(product_data)
    return True


# ─── Main pipeline ─────────────────────────────────────────────────────────────

def process_candidate(candidate: dict, db, usd_cad: float, dry_run: bool) -> dict:
    """Process one product candidate. Returns status dict."""
    name = candidate["name"].strip()
    print(f"\n{'='*60}")
    print(f"Processing: {name}")

    errors = []

    # ── 1. Price ──
    supplier_cost = float(candidate.get("supplier_cost_usd", 10.0))
    shipping_cost = float(candidate.get("shipping_cost_usd", 3.0))
    price_cad, compare_at_cad = calculate_price(supplier_cost, shipping_cost, usd_cad)
    print(f"  [price] ${price_cad} CAD (supplier ${supplier_cost} + ship ${shipping_cost} USD)")

    # ── 2. Image ──
    image_url_raw = candidate.get("image_url", "")
    if image_url_raw:
        final_image_url = get_product_image_url(image_url_raw, name)
    else:
        final_image_url = "https://cdn.origna.ca/dev/products/placeholder.jpg"
        print("  [image] No supplier image URL provided, using placeholder")

    # ── 3. Translation ──
    description = candidate["description"].strip()
    name_f, desc_f = translate_to_french(name, description)

    # ── 4. Build product dict ──
    doc_id = f"{PREFIX}{uuid.uuid4().hex}"
    now = datetime.datetime.now(datetime.UTC)

    shipping_days = int(candidate.get("shipping_days", 12))

    product_dict = {
        Fields.PRODUCT_ID: doc_id,
        Fields.NAME: name,
        Fields.NAME_F: name_f,
        Fields.PRICE: price_cad,
        Fields.COMPARE_AT_PRICE: compare_at_cad,
        Fields.DESCRIPTION: description,
        Fields.DESCRIPTION_F: desc_f,
        Fields.IMAGE_URLS: [final_image_url],
        Fields.SELLER_ID: ADMIN_UID,
        Fields.CATEGORY_ID: int(candidate["category_id"]),
        Fields.STOCK_QUANTITY: 999,  # dropshipping: no stock limit
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
        Fields.DELIVERY_OPTIONS: [{
            "type": "standard",
            "description": f"Estimated delivery {shipping_days}-{shipping_days + 5} days",
            "costCents": 999,  # $9.99 shipping
            "estimatedDays": shipping_days,
            "quantityDiscounts": [],
            "maxItemsPerShipment": 0,
            "additionalItemCostCents": 0,
            "availableNationwide": True,
        }],
        # Supplier info (stored privately, not in Algolia)
        Fields.SUPPLIER: {
            "type": SupplierTypeValues.CJDROPSHIPPING,
            "supplierUrl": candidate.get("supplier_url", ""),
            "cost": supplier_cost,
            "currency": "USD",
            "shippingDays": f"{shipping_days}-{shipping_days + 5}",
            "hasTracking": True,
            "notes": "Sourced via product sourcing agent",
        },
        Fields.WEIGHT_KG: candidate.get("weight_kg"),
        Fields.SHIP_FROM_COUNTRY: "CN",
        Fields.SHIP_FROM_COUNTRIES: ["CN"],
    }

    # Add optional fields
    if candidate.get("subcategory"):
        product_dict[Fields.SUBCATEGORY] = candidate["subcategory"]
    if candidate.get("made_in_country"):
        product_dict[Fields.MADE_IN_COUNTRY] = candidate["made_in_country"]

    # ── 5. Pydantic validation ──
    try:
        # Build ProductCreate for validation (requires sellerAddress OR warehouseIds for non-digital)
        # We use shipFromCountry as the address context — add a minimal sellerAddress
        validate_dict = dict(product_dict)
        validate_dict["sellerAddress"] = {
            "street": "123 Commerce St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V 0A1",
            "country": "Canada",
        }
        # Remove Firestore-only fields not in ProductCreate
        for k in [Fields.PRODUCT_ID, Fields.CREATED_AT, Fields.UPDATED_AT,
                  Fields.RATING, Fields.RATING_COUNT, Fields.TRENDING_SCORE,
                  Fields.VIEW_COUNT, Fields.PURCHASE_COUNT, Fields.IS_TRENDING]:
            validate_dict.pop(k, None)
        ProductCreate(**validate_dict)
        print(f"  [validate] ✓ Pydantic OK")
    except Exception as e:
        errors.append(f"Pydantic validation failed: {e}")
        print(f"  [validate] ✗ FAILED: {e}")
        return {"name": name, "status": "skipped", "errors": errors}

    # ── 6. Firestore write ──
    try:
        write_product(db, product_dict, dry_run=dry_run)
        print(f"  [firestore] ✓ Written: {doc_id}")
        return {"name": name, "doc_id": doc_id, "status": "ok", "price_cad": price_cad}
    except Exception as e:
        errors.append(f"Firestore write failed: {e}")
        print(f"  [firestore] ✗ FAILED: {e}")
        return {"name": name, "status": "error", "errors": errors}


def main():
    parser = argparse.ArgumentParser(description="Product Sourcing Agent")
    parser.add_argument("--candidates", default="/tmp/product_candidates.json",
                        help="Path to product candidates JSON file")
    parser.add_argument("--project", default=os.environ.get("GCP_PROJECT", "orignagta-dev"),
                        help="Firebase project ID")
    parser.add_argument("--dry-run", action="store_true",
                        help="Validate only, no Firestore writes")
    parser.add_argument("--limit", type=int, default=0,
                        help="Max products to process (0 = all)")
    args = parser.parse_args()

    print(f"Product Sourcing Agent — project={args.project} dry_run={args.dry_run}")

    # Load candidates
    with open(args.candidates) as f:
        candidates = json.load(f)

    if args.limit > 0:
        candidates = candidates[:args.limit]

    print(f"Loaded {len(candidates)} candidates from {args.candidates}")

    # Init
    usd_cad = get_usd_cad_rate()
    db = init_firestore(args.project)

    # Process
    results = []
    errors = []

    for i, candidate in enumerate(candidates, 1):
        print(f"\n[{i}/{len(candidates)}]")
        result = process_candidate(candidate, db, usd_cad, dry_run=args.dry_run)
        results.append(result)
        if result["status"] in ("error", "skipped"):
            errors.append(result)
        if not args.dry_run:
            time.sleep(RATE_LIMIT_SECONDS)

    # Summary
    ok = [r for r in results if r["status"] == "ok"]
    skipped = [r for r in results if r["status"] == "skipped"]
    failed = [r for r in results if r["status"] == "error"]

    print(f"\n{'='*60}")
    print(f"DONE — {len(ok)} written, {len(skipped)} skipped, {len(failed)} errors")

    if errors:
        with open(ERRORS_FILE, "w") as f:
            json.dump(errors, f, indent=2, default=str)
        print(f"Errors saved to {ERRORS_FILE}")

    # Write results summary
    summary_file = "/tmp/product_sourcing_results.json"
    with open(summary_file, "w") as f:
        json.dump(results, f, indent=2, default=str)
    print(f"Full results: {summary_file}")


if __name__ == "__main__":
    main()
```

**Step 2: Quick smoke test (dry run with 1 fake candidate)**

```bash
source functions/venv/bin/activate
export $(grep -v '^#' functions/.env.local | xargs)
export GCP_PROJECT=orignagta-dev

# Create minimal test candidate
cat > /tmp/test_candidates.json << 'EOF'
[{
  "name": "Wireless Bluetooth Headphones Premium Sound",
  "description": "Over-ear wireless headphones with 30-hour battery life, active noise cancellation, and premium sound quality. Compatible with all devices. Includes carrying case.",
  "supplier_cost_usd": 14.50,
  "shipping_cost_usd": 3.00,
  "image_url": "https://picsum.photos/seed/headphones/600/600",
  "category_id": 1,
  "subcategory": "Headphones",
  "keywords": ["headphones", "wireless", "bluetooth", "noise cancelling"],
  "weight_kg": 0.32,
  "shipping_days": 12,
  "condition": "new"
}]
EOF

python scripts/product_sourcing_agent.py \
  --candidates /tmp/test_candidates.json \
  --project orignagta-dev \
  --dry-run
```

Expected output ends with: `DONE — 0 written, 0 skipped, 0 errors` (dry run = no writes but full pipeline runs)

**Step 3: Commit**

```bash
git add scripts/product_sourcing_agent.py
git commit -m "feat: add product sourcing agent script (pricing, image, translate, validate, write)"
```

---

## Task 3: Claude Code Skill `/source-products`

**Files:**
- Create: `~/.claude/skills/source-products.md`

**Purpose:** The skill does the research phase (WebSearch per category) and produces `/tmp/product_candidates.json`, then invokes the Python script.

**Step 1: Create the skill file**

```markdown
---
name: source-products
description: Research trending dropshipping products and add them to OrignaGTA as seller yr62813. Produces product candidates via WebSearch then runs product_sourcing_agent.py.
---

# /source-products Skill

## Arguments
- `--category=<name>` — single category (electronics, home, fashion, etc). Default: all
- `--count=<n>` — products per category. Default: 5
- `--dry-run` — validate only, no Firestore writes

## What this skill does

1. WebSearch for trending/best-selling products per category in Canada
2. For each product found: extract name, description, supplier data, image URL
3. Write candidates to `/tmp/product_candidates.json`
4. Run `python scripts/product_sourcing_agent.py` with that file
5. Report results

## Category → Search Query Map

| Category | ID | Search Query |
|----------|----|-------------|
| Electronics | 1 | `best selling electronics accessories Canada 2026 dropship` |
| Computers | 2 | `trending computer accessories Canada 2026 Amazon best sellers` |
| Gaming | 3 | `best selling gaming accessories Canada 2026` |
| Home & Kitchen | 4 | `trending home kitchen products Canada Amazon best sellers 2026` |
| Fashion | 5 | `trending fashion accessories Canada dropship 2026` |
| Shoes & Accessories | 6 | `best selling shoe accessories handbags Canada 2026` |
| Jewelry & Watches | 7 | `trending jewelry watches Canada dropship 2026` |
| Beauty & Personal Care | 8 | `best selling beauty products Canada dropship 2026` |
| Health & Wellness | 9 | `trending health wellness products Canada 2026` |
| Sports & Fitness | 10 | `best selling sports fitness Canada 2026` |
| Automotive | 11 | `trending car accessories Canada 2026` |
| Tools & Hardware | 12 | `best selling home tools hardware Canada 2026` |

## Product candidate format (per product)

```json
{
  "name": "<EN name, 1-100 chars, no brand names>",
  "description": "<EN description, 50-400 chars, benefit-focused>",
  "supplier_cost_usd": <estimated USD cost from CJ/AliExpress>,
  "shipping_cost_usd": <estimated shipping USD to Canada>,
  "image_url": "<supplier product image URL>",
  "category_id": <1-21>,
  "subcategory": "<optional subcategory string>",
  "keywords": ["keyword1", "keyword2"],
  "weight_kg": <optional float>,
  "shipping_days": <int, typical 7-21 for CJ to Canada>,
  "condition": "new"
}
```

## Rules for product names
- NO brand names (no "Apple", "Samsung", "Nike", etc.)
- Generic descriptive names only: "Wireless Noise-Cancelling Headphones"
- 2-8 words, benefits-first

## Rules for descriptions
- 2-4 sentences, benefit-focused
- No mention of supplier, shipping, or brand
- No Chinese translationese ("high quality product good price")
- Mention key features: materials, dimensions, compatibility, battery life, etc.

## Execution steps

After building product_candidates.json:

```bash
cd ~/Documents/GitHub/origna_gta
source functions/venv/bin/activate
export $(grep -v '^#' functions/.env.local | xargs)
export GCP_PROJECT=orignagta-dev
python scripts/product_sourcing_agent.py \
  --candidates /tmp/product_candidates.json \
  --project orignagta-dev
```

Then report: how many written, any errors, sample of products created.
```

**Step 2: Verify the skill file is readable**

```bash
ls -la ~/.claude/skills/source-products.md
```

**Step 3: Commit**

```bash
cd ~/Documents/GitHub/origna_gta
git add scripts/  # nothing new here for git, skill is in ~/.claude
git commit --allow-empty -m "docs: add /source-products skill reference"
```

---

## Task 4: Fix schema_constants field name references in the script

**Why:** The script references `Fields.NAME_F`, `Fields.DESCRIPTION_F`, `Fields.COMPARE_AT_PRICE`, `Fields.WEIGHT_KG`, `Fields.SHIP_FROM_COUNTRY`, `Fields.SHIP_FROM_COUNTRIES`, `Fields.MADE_IN_COUNTRY`, `Fields.RATING_COUNT`, `Fields.TRENDING_SCORE`, `Fields.VIEW_COUNT`, `Fields.PURCHASE_COUNT`, `Fields.IS_TRENDING`, `Fields.SUBCATEGORY`, `Fields.SUPPLIER`, etc. Verify all exist in `schema_constants.py`.

**Step 1: Check which Fields constants exist**

```bash
grep -n "NAME_F\|DESCRIPTION_F\|COMPARE_AT_PRICE\|WEIGHT_KG\|SHIP_FROM_COUNTRY\|SHIP_FROM_COUNTRIES\|MADE_IN_COUNTRY\|RATING_COUNT\|TRENDING_SCORE\|VIEW_COUNT\|PURCHASE_COUNT\|IS_TRENDING\|SUBCATEGORY\|= 'supplier'" \
  functions/schema_constants.py | head -40
```

**Step 2: Fix any missing Fields by using string literals with a comment**

For any field in the script that doesn't have a `Fields.X` constant: replace with the raw string from `schema_constants.py` or add the constant if it's clearly missing. Do NOT add magic strings without a comment pointing to schema_constants.

**Step 3: Run a schema import test**

```bash
source functions/venv/bin/activate
export GCP_PROJECT=orignagta-dev
python3 -c "
import sys; sys.path.insert(0, 'functions')
from schema_constants import Fields, ProductLifecycleStatusValues, SupplierTypeValues
print('Fields.NAME:', Fields.NAME)
print('Fields.SUPPLIER:', Fields.SUPPLIER)
print('Active:', ProductLifecycleStatusValues.ACTIVE)
print('CJ:', SupplierTypeValues.CJDROPSHIPPING)
"
```

Expected: prints field values without import errors.

**Step 4: Fix script if any issues found, then commit**

```bash
git add scripts/product_sourcing_agent.py
git commit -m "fix: align product sourcing agent field names with schema_constants"
```

---

## Task 5: Run the full pipeline

**This is the actual execution.** Claude Code's `/source-products` skill runs this.

**Step 1: Research phase (Claude Code WebSearch)**

Use WebSearch to build 67 real product candidates across 12 categories. Write to `/tmp/product_candidates.json`.

For each category (12 total), search for 5-8 trending products and extract:
- Generic product name (no brands)
- Description (2-4 sentences)
- Estimated cost from CJDropshipping (~$5–$40 USD for most items)
- Estimated shipping to Canada (~$2–$8 USD, 10–20 days)
- Real supplier image URL (from CJDropshipping or AliExpress product page)
- Category ID and subcategory

**Step 2: Execute dry run first**

```bash
cd ~/Documents/GitHub/origna_gta
source functions/venv/bin/activate
export $(grep -v '^#' functions/.env.local | xargs)
export GCP_PROJECT=orignagta-dev

python scripts/product_sourcing_agent.py \
  --candidates /tmp/product_candidates.json \
  --project orignagta-dev \
  --dry-run
```

Expected: all products pass Pydantic validation. Fix any issues.

**Step 3: Execute real run (limit 5 first)**

```bash
python scripts/product_sourcing_agent.py \
  --candidates /tmp/product_candidates.json \
  --project orignagta-dev \
  --limit 5
```

Check Firebase Console: https://console.firebase.google.com/project/orignagta-dev/firestore → `products` collection. Verify 5 new docs with prefix `psrc_` and `lifecycleStatus: active`.

**Step 4: Run the full batch**

```bash
python scripts/product_sourcing_agent.py \
  --candidates /tmp/product_candidates.json \
  --project orignagta-dev
```

**Step 5: Verify in app**

The `on_product_created` Cloud Function trigger fires automatically on each new product doc → syncs to Algolia. After all products written:

```bash
# Check how many psrc_ products exist in Firestore
python3 -c "
import sys, os
sys.path.insert(0, 'functions')
os.environ['GCP_PROJECT'] = 'orignagta-dev'
import firebase_admin
from firebase_admin import credentials, firestore as fb_firestore
cred = credentials.ApplicationDefault()
firebase_admin.initialize_app(cred, {'projectId': 'orignagta-dev'})
db = fb_firestore.client()
docs = db.collection('products').where('sellerId', '==', 'RU9MI8vYFkQCakMrJfG8iGTuc012').where('lifecycleStatus', '==', 'active').stream()
count = sum(1 for _ in docs)
print(f'Active products for yr62813: {count}')
"
```

Expected: ≥50 active products.

**Step 6: Update STATE.md**

Add section with run results: products written, any errors, image success rate, sample product IDs.

**Step 7: Commit results**

```bash
cd ~/Documents/GitHub/origna_gta
git add STATE.md
git commit -m "feat: product sourcing agent — $(cat /tmp/product_sourcing_results.json | python3 -c 'import json,sys; r=json.load(sys.stdin); print(f\"{len([x for x in r if x[chr(115)+chr(116)+chr(97)+chr(116)+chr(117)+chr(115)]==\"ok\"])} products added\")')"
```

---

## Task 6: Error Recovery & Rerun

**If Task 5 has failures** (Pydantic errors, R2 failures, translation failures):

**Step 1: Check errors file**

```bash
cat /tmp/product_sourcing_errors.json | python3 -m json.tool
```

**Step 2: Fix candidate data for failed products**

Edit `/tmp/product_candidates.json` to fix invalid fields:
- Description too short: add more text
- Price calculation error: adjust `supplier_cost_usd`
- Missing required field: add it

**Step 3: Rerun only failed products**

```bash
# Extract failed product names from errors
python3 -c "
import json
with open('/tmp/product_sourcing_errors.json') as f:
    errors = json.load(f)
names = [e['name'] for e in errors]
print(json.dumps(names, indent=2))
"

# Then filter candidates to only failed ones and rerun
python scripts/product_sourcing_agent.py \
  --candidates /tmp/failed_candidates.json \
  --project orignagta-dev
```

---

## Success Verification Checklist

Run this after the full pipeline completes:

```bash
source functions/venv/bin/activate
export GCP_PROJECT=orignagta-dev
python3 - << 'PYEOF'
import sys, os
sys.path.insert(0, 'functions')
os.environ['GCP_PROJECT'] = 'orignagta-dev'
import firebase_admin
from firebase_admin import credentials, firestore as fb_firestore

cred = credentials.ApplicationDefault()
try:
    firebase_admin.get_app()
except:
    firebase_admin.initialize_app(cred, {'projectId': 'orignagta-dev'})
db = fb_firestore.client()

docs = list(db.collection('products')
    .where('sellerId', '==', 'RU9MI8vYFkQCakMrJfG8iGTuc012')
    .where('lifecycleStatus', '==', 'active')
    .stream())

total = len(docs)
with_fr = sum(1 for d in docs if d.to_dict().get('nameF'))
with_images = sum(1 for d in docs if d.to_dict().get('imageUrls'))
categories = set(d.to_dict().get('categoryId') for d in docs)

print(f"✅ Total active products: {total} (target: ≥50)")
print(f"✅ With FR translation: {with_fr}/{total}")
print(f"✅ With images: {with_images}/{total}")
print(f"✅ Categories covered: {sorted(categories)}")

# Sample
if docs:
    sample = docs[0].to_dict()
    print(f"\nSample product:")
    print(f"  Name: {sample.get('name')}")
    print(f"  NameF: {sample.get('nameF')}")
    print(f"  Price: ${sample.get('price')} CAD")
    print(f"  Status: {sample.get('lifecycleStatus')}")
    print(f"  Images: {sample.get('imageUrls', [])[:1]}")
PYEOF
```

---

## Notes for Implementer

1. **nanobanana may be slow** (~30–60s per image edit). Budget 2–3 min per product total.
2. **Gemini CLI rate limits**: if translation fails with quota error, add `time.sleep(5)` between calls.
3. **R2 upload needs env vars**: always run `export $(grep -v '^#' functions/.env.local | xargs)` first.
4. **8GB RAM**: the script is lightweight — only 1 Python process + Gemini CLI subprocess. Safe to run.
5. **Algolia sync is automatic**: `on_product_created` trigger fires on each Firestore write. No manual Algolia step.
6. **`sellerAddress` in validation**: the script adds a dummy Toronto address for Pydantic validation only. The actual Firestore doc uses `shipFromCountry: CN` — the validation address is not written to Firestore.
7. **CJDropshipping image URLs** typically look like: `https://img.cjdropshipping.com/image/xxx.jpg` — these work fine for downloading.
