## SELLER WAREHOUSES FINDINGS

### CRITICAL
1. `delete_warehouse` does NOT reassign default when default warehouse deleted → seller can end up with ZERO defaults (products.py:3191)

### HIGH
2. Warehouse deletion: race condition — warehouse deleted first, then products updated → checkout fails between line 3191-3230
3. International warehouse province NOT validated (only Canadian) — allows garbage state codes (products.py:1034)
4. International warehouse postal code NOT validated — geocoding fails silently

### MEDIUM
5. No admin callable to update `commissionRateBps` — requires manual Firebase Console edit (no audit trail)

### LOW
6. Country field not required in warehouse address — can create warehouse with empty country
7. Dead `onSave` callback in seller_warehouses_screen.dart (assert always fails)
