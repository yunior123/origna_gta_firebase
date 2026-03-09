---
name: shipping-costs
description: Distance-based and province-based shipping cost tables, surcharges, and multipliers for the e-commerce marketplace serving Canadian buyers (sellers worldwide). Use when working on checkout, shipping, or pricing logic.
---

# Shipping Cost Reference

## Distance-Based Pricing
| Distance | Cost |
|----------|------|
| ≤15km | $1.99 |
| ≤50km | $4.99 |
| ≤150km | $9.99 |
| ≤500km | $14.99 |
| ≤1200km | $18.99 |
| ≤2500km | $22.99 |
| >2500km | $26.99 |

## Province-Based Fallback
| Scenario | Cost |
|----------|------|
| `freeShipping=true` | $0.00 |
| Same province | $12.99 |
| Adjacent province | $18.99 |
| Same region | $22.99 |
| Cross-country | $26.99 |

## Surcharges & Multipliers
| Rule | Value |
|------|-------|
| Local-only cross-province | +$50.00 penalty |
| Local-only >100km | $75.00 flat |
| Express (≤15km) | ×4.0 multiplier |
| Same-day (≤15km) | ×4.5 multiplier |
| Weight >2kg | +$1.50/kg × qty |
| Default weight | 0.5kg |
| Default dimensions | 10×10×10cm |

## Implementation Files
- Backend: `functions/services/shipping_service.py`
- Frontend preview: `origna_gta/lib/features/checkout/checkout_provider.dart`
- Tests: `functions/tests/test_shipping_service_estimates.py`, `functions/tests/test_shipping_security.py`
