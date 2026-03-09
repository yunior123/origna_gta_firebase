---
name: ux-info-buttons
description: Helper patterns for info tooltips and explanation buttons in the add product screen. Use when modifying add product UI or adding new info tooltips.
---

# UX Info Buttons Pattern (Add Product Screen)

## 3 Helper Patterns in `addproduct_screen.dart`

| Pattern | Widget | Trigger | Visual |
|---------|--------|---------|--------|
| `_showInfoSheet(title, body)` | Modal bottom sheet | Tap ℹ️ | 💡 icon, title bold, body text |
| `_buildTappableInfoHint(short, title, body)` | Inline row → opens sheet | Tap row | `(i) text >` |
| `_buildInfoBanner(text, icon, color)` | Static colored banner | Always visible | Colored bg + icon + text |

## 16 Info Points

| # | Location | Type | Title |
|---|----------|------|-------|
| 1 | Free Shipping toggle | ℹ️→sheet | "Free Shipping" |
| 2 | Tax Code field | hint→sheet | "Stripe Tax Codes" |
| 3 | Digital Product toggle | ℹ️→sheet | "Digital Products" |
| 4 | Perishable Item toggle | ℹ️→sheet | "Perishable Items" |
| 5 | Standard Delivery tier | ℹ️→sheet | "Standard Delivery" |
| 6 | Express Delivery tier | ℹ️→sheet | "Express Delivery" |
| 7 | Same-Day Delivery tier | ℹ️→sheet | "Same-Day Delivery" |
| 8 | Local Pickup Only toggle | ℹ️→sheet | "Local Pickup Only" |
| 9 | Weight & Dimensions | hint→sheet | "Package Weight & Dimensions" |
| 10 | Bulk Discounts header | ℹ️→sheet | "Bulk Shipping Discounts" |
| 11 | 10+ Free Shipping toggle | ℹ️→sheet | "Bulk Free Shipping" |
| 12 | Multi-item fields | hint→sheet | "Multi-Item Shipping" |
| 13 | Has Tracking toggle | ℹ️→sheet | "Supplier Tracking" |
| 14 | Manage Inventory toggle | ℹ️→sheet | "Inventory Management" |
| 15 | Track Quantity toggle | ℹ️→sheet | "Track Quantity" |
| 16 | Allow Backorders toggle | ℹ️→sheet | "Allow Backorders" |
