---
name: tax-system
description: Canadian tax compliance (GST/HST/PST/QST), Stripe Tax integration, tax codes, exemptions, and full audit checklist. Load before editing ANY tax-related file.
---

# Canadian Tax System — OrignaGTA

## ⚠️ LEGAL COMPLIANCE — READ FIRST

OrignaGTA is an **e-commerce marketplace serving Canadian buyers (sellers can be worldwide)**. Tax compliance is **mandatory by law**.
Source of truth: [CRA GST/HST rates](https://www.canada.ca/en/revenue-agency/services/tax/businesses/topics/gst-hst-businesses/charge-collect-which-rate/calculator.html)

**Last verified with CRA: February 2026**

---

## Current Canadian Tax Rates (as of April 1, 2025)

| Province/Territory | Code | Tax Type | Rate | Combined |
|--------------------|------|----------|------|----------|
| Alberta | AB | GST | 5% | 5% |
| British Columbia | BC | GST + PST | 5% + 7% | 12% |
| Manitoba | MB | GST + PST | 5% + 7% | 12% |
| New Brunswick | NB | HST | 15% | 15% |
| Newfoundland & Labrador | NL | HST | 15% | 15% |
| **Nova Scotia** | **NS** | **HST** | **14%** | **14%** |
| Northwest Territories | NT | GST | 5% | 5% |
| Nunavut | NU | GST | 5% | 5% |
| Ontario | ON | HST | 13% | 13% |
| Prince Edward Island | PE | HST | 15% | 15% |
| Quebec | QC | GST + QST | 5% + 9.975% | 14.975% |
| Saskatchewan | SK | GST + PST | 5% + 6% | 11% |
| Yukon | YT | GST | 5% | 5% |

### Recent Changes
- **April 1, 2025**: Nova Scotia HST decreased from 15% → **14%**
- Always check CRA website before launch for any new changes

---

## Architecture — Tax Files Map

### Backend (Single Source of Truth)
| File | What | Lines |
|------|------|-------|
| `functions/schema_constants.py` | `BusinessRules.TAX_RATES` (percentages) | ~L815-830 |
| `functions/schema_constants.py` | `BusinessRules.CHILDRENS_CLOTHING_EXEMPT_PROVINCES` | ~L852 |
| `functions/schema_constants.py` | `BusinessRules.TAX_CODE_*` constants | ~L843-850 |
| `functions/handlers/payment_stripe.py` | `_PROVINCE_TAX_BREAKDOWN` (derived from TAX_RATES) | ~L69-77 |
| `functions/handlers/payment_stripe.py` | `get_item_tax_rate()` | ~L313-325 |
| `functions/handlers/payment_stripe.py` | `calculate_tax_with_stripe()` | ~L328-410 |
| `functions/handlers/payment_stripe.py` | Tax calculation in `create_checkout_session()` | ~L715-780 |
| `functions/services/shipping_service.py` | `_TAX_RATES_CACHE` (combined decimals) | ~L15-19 |
| `functions/config.py` | `CATEGORY_TAX_CODE_MAP` (21 categories) | ~L285-307 |
| `functions/config.py` | `STRIPE_TAX_ENABLED` feature flag | ~L282 |
| `functions/config.py` | Stripe Tax constants | ~L309-316 |
| `functions/models/order.py` | `Taxes` Pydantic model | ~L106-115 |

### Frontend
| File | What | Lines |
|------|------|-------|
| `origna_gta/lib/core/schema/schema_constants.dart` | `BusinessRules.taxRates` (percentages) | ~L594-610 |
| `origna_gta/lib/utils/utils.dart` | `provinceTaxRates` (decimals) | ~L28-42 |
| `origna_gta/lib/utils/utils.dart` | `getTaxRate()`, `calculateDetailedTaxes()`, `isValidTaxCode()` | ~L216, L436, L454 |
| `origna_gta/lib/features/checkout/checkout_provider.dart` | `checkoutTaxRateProvider`, `calculateTaxes()` | ~L33-37, L140 |
| `origna_gta/lib/features/checkout/checkout_state.dart` | `taxBreakdown`, `taxAmount` | ~L46, L80 |
| `origna_gta/lib/screens/checkout_screen.dart` | Tax display + `_buildTaxBreakdown()` | ~L640-710 |
| `origna_gta/lib/screens/cart_screen.dart` | Tax info tooltip text | ~L334-363 |
| `origna_gta/lib/screens/addproduct_screen.dart` | Tax code validation in form | ~L334 |

### Schema & Docs
| File | What |
|------|------|
| `docs/database_schema.json` | `taxes`, `taxAmountCents`, `taxExempt`, `taxExemption`, `itemTaxes` |
| `docs/TAX_SECURITY.md` | Security documentation |
| `docs/json_schemas/individual/Taxes.json` | JSON schema for Taxes model |

### Tests
| File | What |
|------|------|
| `functions/tests/test_tax_audit.py` | Tax code mapping tests |
| `functions/tests/test_critical_flow_scenarios.py` | Province rates + fallback tests |
| `functions/tests/test_handlers_payment_stripe.py` | Checkout flow tax tests |
| `origna_gta/test/unit/business_logic_test.dart` | Frontend tax calculation tests |
| `e2e/scripts/seed/seed-orders.py` | `make_taxes()` seeder function |

---

## Cross-Stack Sync Rules

When changing ANY tax rate or tax logic:

1. **`functions/schema_constants.py`** → Update `BusinessRules.TAX_RATES` (percentages)
2. **`origna_gta/lib/core/schema/schema_constants.dart`** → Mirror `BusinessRules.taxRates`
3. **`origna_gta/lib/utils/utils.dart`** → Update `provinceTaxRates` (decimal conversion)
4. **`functions/services/shipping_service.py`** → Update `_TAX_RATES_CACHE` (combined decimal)
5. **`functions/handlers/payment_stripe.py`** → `_PROVINCE_TAX_BREAKDOWN` is auto-derived ✅
6. **`docs/database_schema.json`** → Update tax rates in business rules section
7. **`e2e/scripts/seed/seed-orders.py`** → Update `make_taxes()` function
8. **ALL tests** → Update expected values

**`_PROVINCE_TAX_BREAKDOWN` in payment_stripe.py** is auto-derived from `BusinessRules.TAX_RATES` — no manual update needed.

---

## Tax Calculation Flow

```
Frontend (estimate only)          Backend (authoritative)
┌──────────────────────┐         ┌──────────────────────────┐
│ provinceTaxRates     │         │ BusinessRules.TAX_RATES   │
│ getTaxRate(province) │         │                            │
│ calculateDetailedTaxes│        │ STRIPE_TAX_ENABLED?        │
│                      │         │   YES → Stripe Tax API     │
│                      │         │     - GST number validation│
│                      │         │     - B2B reverse charge   │
│                      │         │     - Category exemptions  │
│                      │         │   NO/FAIL → Manual calc    │
│                      │         │     - Per-item tax rates   │
│                      │         │     - Category exemptions  │
│                      │         │     - NO B2B exemption     │
└──────────────────────┘         └──────────────────────────┘
```

---

## Stripe Tax Integration

### Feature Flag
- `STRIPE_TAX_ENABLED` in `functions/config.py` (env var)
- Default: `false` — manual calculation used
- When enabled: Stripe Tax API calculates exact amounts

### Tax Code Mapping (CATEGORY_TAX_CODE_MAP)
| Category ID | Name | Stripe Tax Code | Notes |
|------------|------|-----------------|-------|
| 1 | Electronics | txcd_99999999 | General Tangible Goods |
| 3 | Gaming | txcd_10201000 | Video Games |
| 14 | Books | txcd_10302000 | Digital Books |
| 17 | Baby & Kids | txcd_20030002 | Children's Clothing (exempt ON, BC, MB, SK) |
| 19 | Groceries | txcd_30060005 | Basic Groceries (exempt ALL) |
| 21 | Digital Products | txcd_10000000 | Digital Services |
| Others | — | txcd_99999999 | General Tangible Goods |

### B2B Exemption (GST Number)
- Format: `^\d{9}[A-Z]{2}\d{4}$` (e.g., `123456789RT0001`)
- Rate limited: 3 updates/day
- Only validated by Stripe Tax API (not in manual fallback)
- Reverse charge applied when Stripe confirms validity

---

## Canadian Tax Law Requirements for Marketplaces

### GST/HST Registration
- **Required** if annual taxable supplies exceed $30,000
- OrignaGTA is a "distribution platform operator" under ETA amendments (July 1, 2021)
- Must register under **normal GST/HST** regime (not simplified)

### Place of Supply Rules
- Tax rate based on **delivery address** province (not seller's province)
- Standard e-commerce practice, confirmed by CRA

### What's Taxable
- **Taxable** (standard rate): Most tangible goods, services, shipping
- **Zero-rated** (0%): Basic groceries, prescription drugs, medical devices
- **Exempt**: Some children's clothing in specific provinces
- **Shipping**: GST/HST applies to shipping charges in Canada

### Receipts/Invoices Must Show
- GST/HST registration number
- Tax amounts charged (broken down by type)
- Total before and after tax

### Digital Platform Operator Rules (ETA 2021 amendments)
- Platform operators facilitating supplies of qualifying goods in Canada
- Must collect and remit GST/HST on behalf of unregistered sellers
- Must maintain records for 6 years

---

## Known Issues & Gotchas

### 1. Shipping Tax Base Inconsistency (Frontend)
- `_buildTaxBreakdown()` uses `subtotal + shippingCost` as tax base ✅
- `Estimated Total` line uses `getTaxRate(state) * subtotal` only ❌
- These show different numbers to the customer in the same screen

### 2. Manual Calculation Doesn't Tax Shipping
- When `STRIPE_TAX_ENABLED=false`, backend only taxes item subtotals
- Shipping cost is NOT included in taxation base
- Stripe Tax API correctly includes shipping

### 3. Rate Duplication
- Tax rates exist in 6+ locations
- `_PROVINCE_TAX_BREAKDOWN` is auto-derived (good)
- `_TAX_RATES_CACHE` in shipping_service.py is manually maintained (risk)

### 4. Fallback Defaults
- `getTaxRate()` defaults to 0.13 (Ontario HST) for unknown provinces
- `checkoutTaxRateProvider` defaults to 0.13
- `_buildTaxBreakdown()` defaults to `{'HST': 0.13}`
- Consistent, but should these be blocked instead of defaulted?

---

## Audit Checklist

When auditing the tax system, verify:

- [ ] All 13 provinces/territories present in every tax rate map
- [ ] Rates match current CRA published rates
- [ ] NS is 14% HST (changed April 2025)
- [ ] QC QST is 9.975% (not 10%)
- [ ] Frontend `provinceTaxRates` matches backend `BusinessRules.TAX_RATES` (decimal vs %)
- [ ] `_TAX_RATES_CACHE` combined rates match individual rate sums
- [ ] `_PROVINCE_TAX_BREAKDOWN` derived from TAX_RATES (not hardcoded)
- [ ] Tax on shipping included in backend calculation
- [ ] B2B exemption ONLY works with Stripe Tax API
- [ ] Children's clothing exempt in ON, BC, MB, SK only
- [ ] Basic groceries exempt in ALL provinces
- [ ] Estimated Total in checkout includes tax on shipping
- [ ] `_buildTaxBreakdown` and `Estimated Total` use same tax base
- [ ] GST number format validation: `^\d{9}[A-Z]{2}\d{4}$`
- [ ] Rate limiting on GST number updates (3/day)
- [ ] Refund includes proportional tax refund
- [ ] `database_schema.json` rates match code
- [ ] `e2e/scripts/seed/seed-orders.py` covers all 13 provinces/territories
- [ ] Cart screen info text shows correct rate ranges
- [ ] Tests cover all provinces and edge cases

---

## Interaction Matrix

| Change | Files to Update |
|--------|----------------|
| Tax rate change | schema_constants.py → schema_constants.dart → utils.dart → shipping_service.py → database_schema.json → seed-orders.py → ALL tests |
| New tax code | config.py (CATEGORY_TAX_CODE_MAP) → schema_constants.py (TAX_CODE_*) → tests |
| New exemption | payment_stripe.py (get_item_tax_rate) → Stripe Tax config → tests |
| New province/territory | ALL 6+ tax rate locations + VALID_PROVINCES + tests |
| Stripe Tax toggle | config.py env var only (feature flag) |
| B2B logic change | payment_stripe.py + users.py + Stripe dashboard |
