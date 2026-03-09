# Product Sourcing Agent — Design Document
**Date:** 2026-03-04
**Author:** Claude Code (approved by Yunior Rodriguez Osorio)
**Status:** Approved → Implementation Pending

---

## Problem

OrignaGTA launches in 10–25 days with an empty product catalog. Seller account `yr62813@gmail.com` (UID: `RU9MI8vYFkQCakMrJfG8iGTuc012`) needs a realistic, well-priced, localized (EN + FR) product catalog across multiple categories to give buyers a good first experience.

---

## Solution: Automated Product Sourcing Agent (Approach A)

A Python script (`scripts/product_sourcing_agent.py`) orchestrated by a Claude Code skill (`/source-products`) that:
1. Researches trending products via CJDropshipping free browse API + WebSearch
2. Generates localized product images using nanobanana `/edit` on supplier images (removes Chinese text, Canadian-market quality)
3. Sets smart CAD pricing with ≥10% profit margin
4. Generates EN+FR translations via Gemini CLI
5. Validates all fields against existing Pydantic schema
6. Writes to Firestore as seller yr62813 via Admin SDK

---

## Architecture

```
/source-products (Claude Code skill)
         │
         ▼
scripts/product_sourcing_agent.py
         │
    Phase 1: RESEARCH
    ├── CJDropshipping free browse API (no auth for catalog)
    ├── WebSearch: "best selling [category] Canada 2026"
    └── Output: raw product candidates (name, cost_usd, supplier_url, image_url, shipping_days)
         │
    Phase 2: PRICE CALCULATION (per product)
    ├── cost_usd × live_usd_cad_rate (open.er-api.com, fallback 1.38)
    ├── + estimated_shipping_cad (from CJDropshipping shipping estimate)
    ├── + 13% HST buffer
    ├── + 2.5% platform fee buffer
    └── price = cost_cad × smart_markup (2.5x–3x, ensures ≥10% net margin)
         │
    Phase 3: IMAGE GENERATION (per product)
    ├── Download supplier image to /tmp/product_images/raw/
    ├── nanobanana /edit: "Remove all Chinese/Asian text, make product
    │   photo clean white background, professional Canadian e-commerce style,
    │   keep product identical"
    ├── Save to /tmp/product_images/edited/
    ├── Upload to R2 via upload_r2_helper.py (env prefix: products/dev/)
    └── Fallback: use supplier URL directly if nanobanana or R2 fails
         │
    Phase 4: TRANSLATION (per product)
    ├── gemini -m gemini-3-pro-preview --yolo
    ├── Prompt: "Translate to Canadian French (Quebec). Name: [name].
    │   Description: [desc]. Return JSON {nameF, descriptionF}"
    └── Validate: both fields non-empty, reasonable length
         │
    Phase 5: SCHEMA VALIDATION (per product)
    ├── Pydantic ProductCreate model (same as Cloud Functions)
    ├── Required: name, price, description, imageUrls, sellerId, categoryId, stockQuantity
    ├── Price range: $0.99–$100,000 CAD
    ├── categoryId: 1–21
    ├── description: 10–4000 chars
    └── On failure: skip product, log to /tmp/product_sourcing_errors.json
         │
    Phase 6: FIRESTORE WRITE (per product)
    ├── Admin SDK (credentials.ApplicationDefault())
    ├── sellerId = RU9MI8vYFkQCakMrJfG8iGTuc012
    ├── lifecycleStatus = active (admin bypass, no review needed)
    ├── doc ID prefix = "psrc_" + uuid4() (idempotent re-runs)
    ├── supplier sub-object stored (type, supplierUrl, cost, currency, shippingDays)
    └── Rate limit: 1 product per 2 seconds
```

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Product data source | CJDropshipping free browse + WebSearch | CJDropshipping has free catalog endpoint; good Canadian shipping times (7–15 days); no API key required for browsing |
| Image approach | nanobanana `/edit` on supplier image | **Critical for accuracy**: edited version of actual product = no customer claims. Not generic AI generation. |
| Image edit prompt | Remove text only, keep product identical | Safety — customer gets what they see |
| Translations | Gemini CLI (gemini-3-pro-preview) | Already available, high quality, Quebec French |
| Firestore auth | Admin SDK ApplicationDefault | Same pattern as mega_seed_dev.py; no credentials in code |
| lifecycleStatus | `active` (skip review) | yr62813 is the platform owner/admin |
| Doc ID prefix | `psrc_` | Distinguishes sourced products from seeded ones; safe to re-run |
| Exchange rate | Live fetch with 1.38 fallback | Accurate CAD pricing |
| Profit floor | ≥10% after shipping + HST + platform fee | Explicit minimum margin check per product |

---

## Pricing Formula

```python
cost_cad = supplier_cost_usd * usd_cad_rate
shipping_cad = estimated_shipping_usd * usd_cad_rate  # from CJDropshipping

# Total cost basis
total_cost = cost_cad + shipping_cad

# Smart markup: start at 2.5x, go up to 3x if needed for margin
for markup in [2.5, 2.75, 3.0]:
    selling_price = total_cost * markup
    platform_fee = selling_price * 0.025  # 2.5% OrignaGTA fee
    hst = selling_price * 0.13  # Ontario HST (buyer pays, but affects competitiveness)
    net_margin = (selling_price - total_cost - platform_fee) / selling_price
    if net_margin >= 0.10:
        break

# Round to .99 pricing (psychology)
price_cad = math.floor(selling_price) + 0.99
compare_at_price = round(price_cad * 1.3, 2)  # "original price" for visual discount
```

---

## Categories & Target Counts (initial run)

| Category | ID | Target Products | Rationale |
|----------|----|-----------------|-----------|
| Electronics | 1 | 8 | Highest search volume |
| Computers | 2 | 5 | Accessories/peripherals |
| Gaming | 3 | 6 | Strong CA market |
| Home & Kitchen | 4 | 8 | Amazon.ca top category |
| Fashion | 5 | 6 | High dropshipping volume |
| Shoes & Accessories | 6 | 5 | Easy sourcing |
| Jewelry & Watches | 7 | 4 | High margin |
| Beauty & Personal Care | 8 | 6 | Top dropshipping niche |
| Health & Wellness | 9 | 5 | Post-COVID demand |
| Sports & Fitness | 10 | 6 | Strong CA market |
| Automotive | 11 | 4 | Accessories only |
| Tools & Hardware | 12 | 4 | Home improvement |
| **Total** | | **~67 products** | |

---

## Error Handling

| Failure | Action |
|---------|--------|
| CJDropshipping API down | Fall back to WebSearch-only product research |
| nanobanana edit fails | Use supplier image URL directly (log warning) |
| R2 upload fails | Use supplier image URL directly (log warning) |
| Gemini translation fails | Leave `nameF`/`descriptionF` empty (optional fields) |
| Pydantic validation fails | Skip product, append to errors JSON, continue |
| Firestore write fails | Retry once after 5s, then skip and log |
| Exchange rate API down | Use fallback rate 1.38 |

---

## Files

```
NEW:  scripts/product_sourcing_agent.py      # Main orchestrator
NEW:  scripts/upload_r2_helper.py            # R2 upload utility (reuses env config)
NEW:  ~/.claude/skills/source-products.md    # /source-products Claude Code skill
MOD:  STATE.md                               # Updated after each run with results
```

---

## Skill Interface

```bash
/source-products                          # Run all categories, default count
/source-products --category=electronics   # Single category
/source-products --count=5                # Limit per category
/source-products --dry-run                # Validate only, no writes
```

---

## Safety & Legal

- **No scraped copyrighted text**: product descriptions rewritten by Gemini, not copied
- **No supplier brand names**: generic product names only (e.g., "Wireless Noise-Cancelling Headphones", not "AirPods clone")
- **Images edited, not copied**: nanobanana edits remove Chinese text but keep product fidelity — this is transformative use
- **Supplier info stored privately**: `supplier` sub-object stored in Firestore but excluded from buyer-facing Algolia index and public reads (existing protection)
- **Canadian compliance**: all prices in CAD, FR translations meet Quebec Bill 96

---

## Success Criteria

- [ ] ≥50 products written to Firestore with `lifecycleStatus = active`
- [ ] All products visible in OrignaGTA dev app
- [ ] EN + FR names and descriptions for every product
- [ ] Every product has ≥2 images on R2 CDN (or supplier URL fallback)
- [ ] Net margin ≥10% for every product
- [ ] Zero Pydantic validation errors on written products
- [ ] Script completes in <30 minutes (sequential, 8GB safe)
