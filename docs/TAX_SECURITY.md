# Tax System Security Documentation

## Overview
This document describes the security measures and potential vulnerabilities in the OrignaGTA tax system.

## Security Measures Implemented

### 1. Server-Side Tax Calculation
- **Status**: ✅ SECURE
- Tax is calculated server-side in `create_checkout_session()`
- Client cannot manipulate tax amounts
- All prices validated against Firestore before tax calculation

### 2. Stripe Tax Integration
- **Status**: ✅ SECURE
- Uses Stripe Tax API for automatic tax calculation
- Stripe validates GST/HST numbers with CRA (Canada Revenue Agency)
- B2B reverse charge only applied when Stripe confirms validity

### 3. Tax Code Assignment
- **Status**: ✅ SECURE
- Tax codes mapped from product `categoryId` (server-side)
- `CATEGORY_TAX_CODE_MAP` in `config.py`
- Client cannot manipulate tax codes

### 4. Rate Limiting
- **Status**: ✅ SECURE
- Checkout: 5 requests per minute per user
- GST number updates: 3 per day per user
- Prevents brute force attacks

### 5. Refund Tax Handling
- **Status**: ✅ SECURE
- Partial refunds include proportional tax refund
- `refund_order_item()` calculates tax proportion correctly

### 6. Fallback Security (FIXED)
- **Status**: ✅ SECURE (after fix)
- When Stripe Tax API fails, falls back to manual calculation
- **CRITICAL**: B2B exemption (GST-based) is DISABLED in fallback mode
- Cannot exploit API failures to bypass GST validation

## Known Limitations

### 1. Shipping Address Verification
- **Status**: ⚠️ ACCEPTED RISK
- Tax rate determined by shipping address province
- No verification that shipping address matches billing address
- **Risk**: User could use lower-tax province address
- **Mitigation**: 
  - This is standard e-commerce practice (Amazon, Shopify, etc.)
  - Address fraud is a legal issue, not technical
  - Can implement address verification service if needed

### 2. GST Number Format Validation
- **Status**: ⚠️ ACCEPTED
- Basic format validation only (9 digits + 2 letters + 4 digits)
- Full CRA validation done by Stripe Tax
- If Stripe Tax disabled, no B2B exemption allowed

## Tax Calculation Flow

```
1. Client sends checkout request
   ↓
2. Server validates all prices from Firestore
   ↓
3. Server calculates shipping cost
   ↓
4. Tax Calculation:
   a. If STRIPE_TAX_ENABLED=true:
      - Call Stripe Tax API with GST number
      - Stripe validates GST and calculates tax
      - Returns tax amount + reverse_charge flag
   
   b. If Stripe Tax fails or disabled:
      - Manual calculation per item
      - NO B2B exemption applied (GST ignored)
      - Category-based exemptions still apply
   ↓
5. Create order with calculated tax
   ↓
6. Create Stripe checkout session
   ↓
7. Webhook confirms payment (no tax recalculation)
```

## Category-Based Tax Exemptions

| Category | Tax Code | Exempt Provinces |
|----------|----------|------------------|
| Children's Clothing | txcd_20030002 | ON, BC, MB, SK |
| Basic Groceries | txcd_30060005 | ALL provinces |
| General Goods | txcd_99999999 | None |

## B2B Tax Exemption

### How It Works
1. User adds GST number in profile
2. At checkout, GST number passed to Stripe Tax
3. Stripe validates with CRA
4. If valid B2B, Stripe applies reverse charge (0% tax)
5. Order marked with `taxExempt: true`

### Security
- Stripe handles all GST validation
- We trust Stripe's response
- No custom GST validation logic
- GST number stored for audit trail

## Refund Tax Handling

### Partial Refunds
```python
# Calculate proportional refund
proportion = item_subtotal / order_subtotal
proportional_tax = order_tax * proportion
refund_amount = item_subtotal + proportional_tax + proportional_shipping
```

### Full Refunds
- Full tax amount refunded
- Stripe handles refund calculation

## Testing

Run tax security tests:
```bash
cd functions
python -m pytest tests/test_tax_audit.py -v
```

## Recommendations

1. **Enable Stripe Tax in production** for automatic tax calculation
2. **Monitor fallback usage** - if frequent, investigate Stripe API issues
3. **Consider address verification service** if address fraud becomes issue
4. **Regular audits** of tax calculation logs

## Contact

For tax system security questions, contact the development team.
