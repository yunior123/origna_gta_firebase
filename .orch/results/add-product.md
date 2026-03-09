## ADD PRODUCT FINDINGS

### CRITICAL
1. State NOT reset on navigation away — stale form data on re-entry (addproduct_screen.dart:793)
2. Warehouse fallback missing — seller with warehouses can bypass by entering address manually (add_product_viewmodel.dart:126)
3. lifecycleStatus sent as `draft` from Dart — backend overrides to UNDER_REVIEW but violates schema contract (add_product_viewmodel.dart:340)
4. No loading state during video upload — UI shows no feedback, user can double-submit (add_product_viewmodel.dart:384)
5. No CAD-only currency hint on price field — international sellers may enter wrong currency

### HIGH
6. No drag-to-reorder UI for images — seller can't set primary image without deleting others
7. Address validation logic duplicated in addProduct() and edit flow — DRY violation
8. SKU uniqueness error shown as SnackBar not inline field error — poor UX

### MEDIUM
9. No info tooltip for warehouse stock allocation section
10. Video duration validation allows zero-duration (corrupted video) — add minimum check

### VERIFIED OK
- Images uploaded to R2 before product doc (atomic with rollback)
- Backend SKU uniqueness via atomic collision doc
- Digital product address skip logic correct
