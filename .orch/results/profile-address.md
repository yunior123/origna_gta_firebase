## PROFILE & ADDRESS FINDINGS

### CRITICAL
1. `delete_buyer_address` has no explicit ownership check — attacker could delete other user's address with guessed ID (users.py:491)

### HIGH
2. No check for active orders using address before deletion — buyer could lose shipping reference (users.py:491)
3. Geoapify error not surfaced with context — user stuck if API down with generic "select from suggestions" error (address_viewmodel.dart:43)

### MEDIUM
4. Default address swap not in transaction — concurrent update race could result in two defaults (users.py:466)
5. Province code not validated client-side before backend call — bad Geoapify result causes cryptic error
6. Postal code regex validation missing on frontend — waits for backend round-trip

### LOW
7. 10-address limit not enforced client-side — user fills entire form before seeing error
