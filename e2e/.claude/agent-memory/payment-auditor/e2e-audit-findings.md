# E2E Payment Test Audit Findings (2026-02-18, Round 2)

## CRITICAL-1: Country Code Mismatch -- FIXED
- api-helpers.ts lines 269, 315: fallback now `'Canada'` (was `'CA'`)
- payment_stripe.py line 558: `if country.lower() != "canada"`
- Status: Test-side fix applied. Backend still has latent bug (ignores ALLOWED_SHIPPING_COUNTRIES).

## CRITICAL-2: update_item_status called with invalid status 'processing'
- multi-seller-orders.spec.ts line 76: `newStatus: 'processing'`
- Backend DeliveryStatusValues only allows: pending, shipped, delivered, refunded
- Will return invalid-argument error, test will fail

## HIGH-3: shipping-approval.spec.ts sends wrong parameter names + wrong units
- Line 45: sends `shippingCostCents: 1500` but backend expects `newShippingCost` (in dollars)
- Lines 46-47: sends `carrier`, `estimatedDays` which backend ignores (not in API contract)
- Backend will reject with "newShippingCost must be a non-negative number"

## HIGH-4: update_shipping_cost requires paymentStatus='authorized' but auto-capture sets 'captured'
- orders.py line 1303: `if order_data.get(Fields.PAYMENT_STATUS) != PaymentStatusValues.AUTHORIZED`
- checkout.session.completed webhook sets paymentStatus to 'captured' (line 1414)
- ALL shipping-approval tests will fail with "Payment must be in authorized state"
- This is a backend design gap -- update_shipping_cost is unreachable in auto-capture mode

## MEDIUM-5: order-cancellation-refund 'Cannot cancel shipped order' fragile for multi-seller
- Lines 49-58: calls `update_order_status` with `newStatus: 'processing'` then 'shipped'
- If product discovered happens to be from a multi-seller order, backend blocks update_order_status
- Currently safe because getTestProduct returns single-seller products, but fragile

## MEDIUM-6: Stock restoration uses polling -- ALREADY NOTED (previous audit)
- order-cancellation-refund.spec.ts lines 80-85: proper polling loop now implemented

## LOW-7: multi-seller-orders.spec.ts line 107 weak assertion
- `expect(error).toBeTruthy()` -- always passes even if callExpectError returns unexpected-success
- Should be `expect(error.code).not.toBe('unexpected-success')`

## LOW-8: Dev credentials in version control -- ALREADY NOTED
- api-helpers.ts lines 15, 26, 39-44
