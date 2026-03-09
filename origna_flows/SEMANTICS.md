# Origna GTA — Flutter Semantics / Key Reference

> Complete map of all `Key()`, `Semantics(label:)`, and `getByRole` selectors for every screen.
> Used by Playwright AI agents to locate elements in the Flutter Web accessibility tree.

---

## Flutter Web Selector Rules (CRITICAL)

```
✅ page.getByRole('button', { name: /text inside button/i })
✅ page.locator('[aria-label="btn-some-label"]')
✅ page.getByRole('textbox', { name: /field label text/i })
✅ page.getByRole('switch', { name: /toggle label/i })
✅ page.getByRole('checkbox', { name: /checkbox-label/i })
✅ page.locator('[aria-label^="product-card-"]').first()

❌ page.getByText('No Platform Fee')       — translated text NOT in DOM
❌ field.fill('value')                      — NEVER works in Flutter Web
❌ page.keyboard.type('value')              — drifts focus, use locator.pressSequentially()
❌ page.locator('button[aria-label=...]')   — buttons use text content, not aria-label
```

---

## HomeScreen (`/`)

| Element | Selector |
|---------|----------|
| Search field | `page.getByRole('textbox', { name: /input-home-search/i })` |
| Clear search | `page.locator('[aria-label="btn-clear-search"]')` |
| Settings/Profile icon | `page.locator('[aria-label="btn-home-settings"]')` |
| Privacy policy link | `page.locator('[aria-label="btn-home-privacy-policy"]')` |
| Terms of service link | `page.locator('[aria-label="btn-home-terms-of-service"]')` |
| Cart icon | `Key('home_cart_button')` |
| Add product FAB | `Key('home_add_product_button')` — visible only if seller/admin |
| Loading more | `aria-label="Loading more products"` |
| Product card | `page.locator('[aria-label^="product-card-"]')` |
| Favorite btn on card | `page.locator('[aria-label^="btn-favorite-"]')` |
| Add to cart on card | `page.locator('[aria-label^="btn-add-to-cart-"]')` |

---

## LoginScreen (`/login`)

| Element | Selector |
|---------|----------|
| Full name field (signup only) | `page.getByRole('textbox', { name: /full.name/i })` or `Key('login_name_field')` |
| Email field | `page.getByRole('textbox', { name: /email/i })` or `Key('login_email_field')` |
| Password field | `page.getByRole('textbox', { name: /password/i })` or `Key('login_password_field')` |
| Terms checkbox (signup) | `page.getByRole('checkbox', { name: /checkbox-accept-terms/i })` |
| Marketing opt-in checkbox | `page.getByRole('checkbox', { name: /checkbox-marketing-opt-in/i })` |
| Submit button | `Key('login_submit_button')` |
| Forgot password | `page.locator('[aria-label="btn-forgot-password"]')` or `Key('login_forgot_password_button')` |
| Google sign-in | `Key('login_google_button')` |
| Toggle login/signup | `page.locator('[aria-label="btn-toggle-auth-mode"]')` or `Key('login_toggle_mode_button')` |
| Forgot cancel btn | `page.locator('[aria-label="btn-forgot-cancel"]')` |
| Forgot send btn | `page.locator('[aria-label="btn-forgot-send"]')` |

**Login flow detection:**
- 2 textboxes visible → login mode
- 3 textboxes visible → signup mode

---

## ProfileScreen (`/profile`)

| Element | Selector |
|---------|----------|
| Sign in button (guest) | `Key('profile_sign_in_button')` |
| My Orders | `Key('profile_my_orders_button')` |
| Seller Orders | `Key('profile_seller_orders_button')` — visible if seller |
| Seller Dashboard | `Key('profile_seller_dashboard_button')` — visible if seller |
| Become Seller | `Key('profile_become_seller_button')` — visible if buyer only |
| Admin Panel | `Key('profile_admin_panel_button')` — visible if admin |
| Favorites | `Key('profile_favorites_button')` |
| Addresses | `Key('profile_address_button')` |
| Terms | `Key('profile_terms_button')` |
| Privacy | `Key('profile_privacy_button')` |
| Contact | `Key('profile_contact_button')` |
| Sign Out | `Key('profile_sign_out_button')` |
| Delete Account | `Key('profile_delete_account_button')` |

---

## ProductDetailsScreen (`/product/:id`)

| Element | Selector |
|---------|----------|
| Back button | `Key('productdetail_back_button')` |
| Product name | `Key('product_detail_name')` |
| Product price | `Key('product_detail_price')` |
| Description | `Key('product_description_section')` |
| Quantity minus | `Key('product_qty_minus')` |
| Quantity value | `Key('product_qty_value')` |
| Quantity plus | `Key('product_qty_plus')` |
| Add to cart | `Key('product_add_to_cart_button')` |
| Own product message | `Key('product_own_product_message')` — shown if seller owns this product |
| Notify me (OOS) | `Key('product_notify_me_button')` — shown if out of stock |
| Notify section | `Key('product_notify_section')` |
| Product images | `aria-label="Product image N of M. Tap to view fullscreen"` |

---

## CartScreen (`/cart`)

| Element | Selector |
|---------|----------|
| Screen title | `Key('cart_screen_title')` |
| Empty message | `Key('cart_empty_message')` |
| Cart item (by productId) | `ValueKey(productId)` → `page.locator('[aria-label="${productId}"]')` |
| Cart qty minus | `Key('cart_qty_minus_${productId}')` |
| Cart qty plus | `Key('cart_qty_plus_${productId}')` |
| Service fee info | `page.locator('[aria-label="btn-info-service-fee"]')` |
| Tax estimate info | `page.locator('[aria-label="btn-info-tax-estimate"]')` |
| Delivery instructions | `page.locator('[aria-label="btn-delivery-instructions"]')` |
| Proceed to checkout | `page.getByRole('button', { name: /proceed.to.checkout/i })` |

---

## CheckoutScreen (`/checkout`)

| Element | Selector |
|---------|----------|
| Root | `Key('checkout_screen_root')` |
| Address section | `Key('checkout_address_section')` |
| Edit address | `page.locator('[aria-label="btn-edit-address"]')` or `Key('checkout_edit_address_button')` |
| Add address | `page.locator('[aria-label="btn-add-address"]')` |
| Delivery speed (standard/express/same_day) | `Key('checkout_delivery_speed_standard')`, `Key('checkout_delivery_speed_express')`, etc. |
| Shipping section | `Key('checkout_shipping_section')` |
| Summary section | `Key('checkout_summary_section')` |
| Apply coupon | `Key('checkout_apply_coupon_button')` |
| Payment section | `Key('checkout_payment_section')` |
| Buyer protection banner | `Key('checkout_buyer_protection_banner')` |
| Buyer protection link | `page.locator('[aria-label="link-buyer-protection"]')` |
| Secure badge | `Key('checkout_secure_badge')` |
| Place order | `page.locator('[aria-label="btn-place-order"]')` or `Key('checkout_place_order_button')` |
| Confirm pay | `page.locator('[aria-label="btn-confirm-pay"]')` or `Key('checkout_confirm_pay_button')` |

---

## OrdersScreen (`/orders`)

| Element | Selector |
|---------|----------|
| Screen title | `Key('orders_screen_title')` |
| Empty message | `Key('orders_empty_message')` |
| Pending approvals | `page.locator('[aria-label="btn-pending-approvals"]')` |
| Action button (Rate, Confirm, etc.) | `Key('order_btn_${label.toLowerCase().replace(' ', '_')}')` |
| Rate button | `page.locator('[aria-label="btn-rate"]')` |
| Confirm receipt | `page.locator('[aria-label="btn-confirm-receipt"]')` |

---

## SellerOrdersScreen (`/seller/orders`)

| Element | Selector |
|---------|----------|
| Screen title | `Key('seller_orders_screen_title')` |
| Mark shipped | `tooltip='seller.mark_shipped'` |
| Confirm ship button | `page.getByRole('button', { name: /confirm shipping/i })` |
| Tracking number input | `page.locator('[aria-label="input-tracking-number"]')` |
| Actual cost input | `page.locator('[aria-label="input-actual-cost"]')` |
| Tracking number update | `page.locator('[aria-label="input-tracking-number-update"]')` |
| Confirm button (dialogs) | `page.getByRole('button', { name: /confirm/i })` |

---

## AddProductScreen (`/seller/add-product`)

| Element | Selector |
|---------|----------|
| Back | `Key('addproduct_back_button')` |
| Screen title | `Key('addproduct_screen_title')` |
| Section: basic | `Key('addproduct_section_basic')` |
| Product name field | `page.getByRole('textbox', { name: /product.name/i })` or `Key('product_name_field')` |
| Description field | `page.getByRole('textbox', { name: /description/i })` or `Key('product_description_field')` |
| Price field | `page.getByRole('textbox', { name: /price.*cad/i })` or `Key('product_price_field')` |
| Stock field | `page.getByRole('textbox', { name: /stock/i })` or `Key('product_stock_field')` |
| Compare at price | `Key('product_compare_at_price_field')` |
| Free shipping toggle | `page.getByRole('switch', { name: /free.shipping/i })` or `Key('addproduct_free_shipping_toggle')` |
| SKU field | `Key('addproduct_seller_sku_field')` |
| Section: images | `Key('addproduct_section_images')` |
| Section: delivery | `Key('addproduct_section_delivery')` |
| Digital toggle | `page.getByRole('switch', { name: /digital.product/i })` or `Key('addproduct_digital_toggle')` |
| Perishable toggle | `page.getByRole('switch', { name: /perishable/i })` or `Key('addproduct_perishable_toggle')` |
| Standard delivery | `Key('addproduct_standard_delivery_card')` |
| Express delivery | `Key('addproduct_express_delivery_card')` |
| Same day delivery | `Key('addproduct_same_day_delivery_card')` |
| Local pickup toggle | `page.getByRole('switch', { name: /local.pickup/i })` or `Key('addproduct_local_pickup_toggle')` |
| Section: package | `Key('addproduct_section_package')` |
| Weight field | `page.getByRole('textbox', { name: /weight/i })` or `Key('addproduct_weight_field')` |
| Length field | `Key('addproduct_length_field')` |
| Width field | `Key('addproduct_width_field')` |
| Height field | `Key('addproduct_height_field')` |
| Digital type: software | `Key('addproduct_digital_type_software')` |
| Digital type: book | `Key('addproduct_digital_type_book')` |
| macOS URL field | `Key('addproduct_macos_url')` |
| Windows URL field | `Key('addproduct_windows_url')` |
| Linux URL field | `Key('addproduct_linux_url')` |
| Book URL field | `Key('addproduct_book_url')` |
| Has variants toggle | `page.getByRole('switch', { name: /has.variants/i })` or `Key('addproduct_has_variants_toggle')` |
| Variants section | `Key('addproduct_section_variants')` |
| Add variant option | `Key('addproduct_add_variant_option_button')` |
| Manage warehouses | `Key('addproduct_manage_warehouses_button')` |
| Street address | `Key('addproduct_street_field')` |
| City | `Key('addproduct_city_field')` |
| Province dropdown | `Key('addproduct_province_dropdown')` |
| Postal code | `Key('addproduct_postal_code_field')` |
| Clear address | `Key('addproduct_clear_address_button')` |
| Category selector | `Key('addproduct_category_selector')` |
| Subcategory | `Key('addproduct_subcategory_${catId}')` |
| Inventory toggle | `Key('addproduct_inventory_toggle')` |
| Section: supplier | `Key('addproduct_section_supplier')` |
| Publish button | `page.locator('[aria-label="btn-publish-product"]')` or `Key('addproduct_submit_button')` |
| Success snackbar | `Key('addproduct_success_snackbar')` |
| Error snackbar | `Key('addproduct_error_snackbar')` |

---

## EditProductScreen (`/seller/edit-product/:id`)

| Element | Selector |
|---------|----------|
| Name field | `Key('product_edit_name_field')` |
| Description | `Key('product_edit_description_field')` |
| Price | `Key('product_edit_price_field')` |
| Stock | `Key('product_edit_stock_field')` |
| Compare at price | `Key('product_edit_compare_at_price_field')` |
| Low stock toggle | `Key('editproduct_low_stock_alert_toggle')` |
| Low stock threshold | `Key('editproduct_low_stock_threshold_field')` |
| Category dropdown | `Key('product_edit_category_dropdown')` |
| Digital section | `Key('editproduct_digital_section')` |
| Digital: software | `Key('editproduct_digital_type_software')` |
| Digital: book | `Key('editproduct_digital_type_book')` |
| macOS URL | `Key('editproduct_macos_url')` |
| Windows URL | `Key('editproduct_windows_url')` |
| Linux URL | `Key('editproduct_linux_url')` |
| Device limit | `Key('editproduct_device_limit')` |
| Book URL | `Key('editproduct_book_url')` |
| Save button | `Key('product_edit_save_button')` |

---

## SubscriptionScreen (`/subscription`)

| Element | Selector |
|---------|----------|
| Subscribe button | `page.locator('[aria-label="btn-subscribe-premium"]')` or `Key('subscribe_button')` |
| Cancel subscription | `page.locator('[aria-label="btn-cancel-subscription"]')` |
| Reactivate | `page.locator('[aria-label="btn-reactivate-subscription"]')` |
| Notify new products | `page.getByRole('switch', { name: /switch-notify-new-products/i })` |
| Notify trending | `page.getByRole('switch', { name: /switch-notify-trending/i })` |
| Keep premium (cancel dialog) | `page.locator('[aria-label="btn-keep-premium"]')` |
| Confirm cancel | `page.locator('[aria-label="btn-confirm-cancel-subscription"]')` |

**Note:** Subscription screen reads `subscriptions/{userId}` (NOT `users/{userId}.isPremium`). For test setup, BOTH must be set:
```typescript
await writeDoc(`users/${uid}`, { isPremium: true });
await writeDoc(`subscriptions/${uid}`, { status: 'active', ... });
```

---

## SellerRegistrationScreen (`/seller/register`)

| Element | Selector |
|---------|----------|
| Terms checkbox | `page.getByRole('checkbox', { name: /chk-seller-terms/i })` or `Key('seller_terms_checkbox')` |
| Action button | `page.locator('[aria-label="btn-seller-action"]')` or `Key('seller_action_button')` |

---

## ChatScreen (`/chat/:chatId`)

| Element | Selector |
|---------|----------|
| Message input | `page.getByRole('textbox')` |
| Send button | `page.locator('[aria-label="btn-send-message"]')` or `Key('chat_send_button')` |
| Message item | `ValueKey(message.id)` |

---

## AddressManagementScreen (`/addresses`)

| Element | Selector |
|---------|----------|
| Add address | `page.locator('[aria-label="btn-add-address"]')` or `Key('btn_add_address')` |

---

## EditAddressScreen

| Element | Selector |
|---------|----------|
| Street field | `Key('address_street_field')` with label `address.street` |
| Autocomplete suggestions | `Key('address_suggestions')` |
| Apartment field | `Key('address_apartment_field')` |
| City field | `Key('address_city_field')` |
| Province dropdown | `ValueKey(state.selectedProvince)` |
| Postal code | `Key('address_postal_code_field')` |
| Phone | `Key('address_phone_field')` |
| Address label chips | `aria-label="chip-address-label-${label.toLowerCase()}"` |
| Save button | `page.locator('[aria-label="btn-save-address"]')` or `Key('btn_save_address')` |

---

## PaymentScreens

| Element | Selector |
|---------|----------|
| View my orders | `page.getByRole('button', { name: /view.my.orders/i })` |
| Back to shopping | `page.locator('[aria-label="btn-back-to-shopping"]')` |

---

## SellerWarehousesScreen (`/seller/warehouses`)

| Element | Selector |
|---------|----------|
| Warehouse type: Warehouse | `page.getByRole('button', { name: /^Warehouse$/i })` — Semantics label |
| Warehouse type: Personal | `page.getByRole('button', { name: /Personal/i })` |
| Location name | `page.getByRole('textbox', { name: /Location Name/i })` |
| Street | `page.getByRole('textbox', { name: /Street Address/i })` |
| City | `page.getByRole('textbox', { name: /^City$/i })` |
| Province | `page.getByRole('textbox', { name: /^Province$/i })` |
| Postal code | `page.getByRole('textbox', { name: /Postal Code/i })` |
| Options menu | `tooltip="Warehouse options"` |

---

## AdminPanelScreen (`/admin`)

| Element | Selector |
|---------|----------|
| Screen title | `Key('admin_screen_title')` |

---

## SubscriptionSuccessScreen

| Element | Selector |
|---------|----------|
| Start shopping | `page.locator('[aria-label="btn-start-shopping"]')` |

---

## Product Lifecycle States (for Admin/Seller testing)

| State | What to expect in UI |
|-------|---------------------|
| `active` | Visible to buyers, purchasable |
| `paused` | Hidden from buyers, seller can re-activate |
| `under_review` | Admin review queue, not purchasable |
| `approved` | Approved but not yet active (intermediate) |
| `rejected` | Shows rejection reason, seller can resubmit |
| `draft` | Saved draft, only visible to seller |
| `archived` | Permanently archived, not purchasable |

---

## Order Status Colors (for visual regression tests)

| Status | Color (DesignTokens) |
|--------|---------------------|
| pending | secondary (amber) |
| confirmed | info (blue) |
| processing | primary (purple) |
| shipped | statusShipped (orange) |
| in_transit | statusInTransit (teal) |
| delivered | success (green) |
| cancelled | error (red) |
| failed | error (red) |
| expired | textSecondary (gray) |
| refunded | warning (yellow) |
| partially_refunded | warning (yellow) |
| disputed | error (red) |
