---
name: add-product-flow
description: Deep knowledge of the Add Product flow — files, patterns, bugs found, interaction matrix, and gotchas. Load this before editing any add-product file.
context: fork
---

# Add Product Flow — Deep Knowledge

## Files
| File | Role | Lines |
|------|------|-------|
| `lib/features/products/add_product_state.dart` | Immutable state (sentinel `copyWith`) | ~90 |
| `lib/features/products/add_product_viewmodel.dart` | Validation, image compress, create product | ~276 |
| `lib/screens/productaddimages_screen.dart` | Image picker widget (local state + callback) | ~240 |
| `lib/screens/addproduct_screen.dart` | Main UI — 5 sections, submit button | ~1600 |

## Sentinel `copyWith` Pattern
Dart `copyWith` with nullable fields silently clears values. Fix:
```dart
const _sentinel = Object();
AddProductState copyWith({ Object? errorMessage = _sentinel, ... }) {
  return AddProductState(
    errorMessage: errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
  );
}
```
Applied to: `errorMessage`, `latitude`, `longitude`.

## Image Sync (Bug #1 — was CRITICAL)
`ProductAddImages` is `StatefulWidget` with local `_imageModels`. It MUST call `onImagesChanged` callback after pick/remove, otherwise ViewModel's `state.imageModels` stays empty → validation error. Always use `Image.memory(imageModel.bytes)` (non-nullable `Uint8List`), never `Image.network` for local picker images.

## Free Shipping Cascade
Backend `shipping_service.py` makes ALL tiers $0 when `freeShipping=true` (excludes from `chargeable_items`). So:
- `toggleFreeShipping(true)` → disable `expressEnabled`, `sameDayEnabled`, `freeShippingAt10Plus`
- UI hides Express/Same-Day tier cards + bulk discounts section + shows info banner
- Digital products force `freeShipping=true` — guard prevents un-checking

## Interaction Matrix
| Action | standard | express | sameDay | freeShipping | freeShipping10+ |
|--------|:--------:|:-------:|:-------:|:------------:|:---------------:|
| `toggleDigital(true)` | ❌ | ❌ | ❌ | ✅ forced | — |
| `toggleFreeShipping(true)` | — | ❌ | ❌ | ✅ | ❌ |
| `setLocalDeliveryOnly(true)` | ❌ | ❌ | ❌ | — | — |

## Key Gotchas
1. **`double.parse` crash** → Always `double.tryParse(...) ?? 0` in submit
2. **Postal code** → Normalize `replaceAll(' ', '')` before regex `^[A-Z]\d[A-Z]\d[A-Z]\d$`
3. **Stale coordinates** → Call `clearCoordinates()` on manual edit of street/city/postalCode
4. **Same-day delivery** → Must include `quantityDiscounts`, `additionalItemCost`, `maxItemsPerShipment`
5. **Double-submit** → Guard with `if (state.isLoading) return;` at top of `addProduct()`
6. **Discount validation** → 0-100% range on shipping discount tier fields

## Known Remaining TODOs (Low Priority)
- `_inventoryManaged`, `_trackQuantity`, `_allowBackorder` are local state — disconnected from ViewModel
- `_apartmentController` declared but no UI field rendered
- Discount tiers should validate 5+ ≥ 3+ ordering
- Free Shipping toggle visible for digital (cosmetic — forced true anyway)
