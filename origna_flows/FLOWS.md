# Origna GTA — User Flows

> Step-by-step user journeys used for E2E test design and manual QA.
> Each flow includes preconditions, steps, expected outcomes, and test hints.

---

## Flow 1: Guest Browse → Add to Cart → Checkout

**Preconditions:** Not logged in. Active products exist.

1. Open `/` — home screen loads with product grid
2. Search for "headphones" → Algolia results appear
3. Click product card → navigate to `/product/:id`
4. View images (swipe), read description, check price
5. Tap "Add to Cart" → login prompt appears (guest cannot cart)
6. Login with `yr62813@gmail.com / REDACTED_TEST_PASSWORD`
7. Product added to cart → cart badge updates
8. Navigate to `/cart`
9. See product, price, shipping estimate, taxes
10. Tap "Proceed to Checkout"
11. Select/confirm shipping address (Toronto, ON)
12. Choose delivery speed (standard)
13. Apply coupon `WELCOME10` → 10% discount applied
14. Review order summary
15. Tap "Place Order" → Stripe checkout opens
16. Fill card `4242 4242 4242 4242`, exp `12/26`, cvv `123`
17. Submit → redirect to `/payment-success`
18. Order appears in `/orders` with status `pending` → `confirmed`

**Test assertions:**
- Cart badge shows count
- Coupon discount visible in summary
- Order created in Firestore with correct total
- Payment status = `authorized`

---

## Flow 2: Seller — Add Product (Physical)

**Preconditions:** Logged in as seller (yr62813@gmail.com with seller role).

1. Navigate to `/seller/add-product` (via profile → Add Product FAB)
2. Fill: Product Name, Description, Price (CAD), Stock Quantity
3. Upload 2+ images
4. Select Category: Electronics
5. Configure delivery: enable Standard (3-5 days), Express (1-2 days)
6. Set dimensions and weight
7. Select province: ON, city: Toronto, postal code: M5V 3A8
8. Tap "Publish Product"
9. Product created with `lifecycleStatus: under_review`
10. Admin gets notification to review

**Test assertions:**
- All required fields validated (empty name → error)
- Price must be > 0
- At least 1 image required
- Product in Firestore with `lifecycleStatus: 'under_review'`
- SKU uniqueness enforced

---

## Flow 3: Admin — Approve/Reject Product

**Preconditions:** Admin logged in. Product in `under_review` state.

1. Navigate to `/admin`
2. Find product queue (under review tab)
3. View product: `mseed_prod_review_1` (Samsung 65" TV)
4. Click "Approve" → product moves to `approved` → `active`
5. Product now visible on home screen
6. Find product: `mseed_prod_rejected_1`
7. Click "Reject" → enter rejection reason
8. Product moves to `rejected`
9. Seller notified via email

**Test assertions:**
- Admin-only route (non-admin cannot access)
- Product lifecycle transitions correct
- Rejection reason stored in Firestore

---

## Flow 4: Seller — Ship Order

**Preconditions:** Seller logged in. Order with status `confirmed` exists.

1. Navigate to `/seller/orders`
2. Find order with `confirmed` status
3. Tap "Mark as Shipped"
4. Enter tracking number: `1Z999AA10123456784`
5. Confirm → order status becomes `shipped`
6. Buyer receives shipping notification
7. Enter actual shipping cost (if different from quoted)
8. Approve shipping cost → buyer notified

**Test assertions:**
- Only seller of the order can mark shipped
- Tracking number stored in order
- Order status transitions: confirmed → shipped

---

## Flow 5: Buyer — Confirm Receipt

**Preconditions:** Buyer logged in. Order with status `delivered`.

1. Navigate to `/orders`
2. Find delivered order
3. Tap "Confirm Receipt"
4. Payment captured (authorized → captured)
5. Seller paid out
6. Option to "Rate" order appears

**Test assertions:**
- Only buyer of the order can confirm
- Payment status: authorized → captured
- Payout triggered to seller Stripe account

---

## Flow 6: Return Request Flow

**Preconditions:** Buyer. Order in `delivered` status.

1. Navigate to `/orders` → find delivered order
2. Tap "Request Return"
3. Select reason: "Item not as described"
4. Submit return request
5. Status: `requested`
6. Seller receives notification, reviews
7. Seller approves → status: `approved`
8. Shipping label issued → status: `label_issued`
9. Item received → status: `received`
10. Refund issued → status: `refunded`

**Test assertions:**
- Return window enforced (e.g., 30 days)
- Only delivered orders can have returns
- Refund amount matches order total

---

## Flow 7: Premium Subscription

**Preconditions:** Non-premium buyer logged in.

1. Navigate to `/subscription` (via profile)
2. View premium features list
3. Tap "Subscribe" → Stripe checkout opens
4. Fill card: `4242 4242 4242 4242`
5. Submit → redirect to subscription success
6. `users/{uid}.isPremium = true`
7. `subscriptions/{uid}.status = 'active'`
8. Chat feature unlocked
9. Navigate to `/subscription` → cancel dialog
10. Tap "Cancel Subscription" → confirm
11. `subscriptions/{uid}.status = 'canceled'`
12. Premium features revoked at period end

**Test assertions:**
- Non-premium cannot access chat
- Subscription state in both `users` and `subscriptions` collections
- Notification toggles work after premium

---

## Flow 8: Digital Product — Buy & Download

**Preconditions:** Buyer logged in. Digital book product exists.

1. Find `mseed_prod_digital_book_1` (Python Crash Course)
2. Add to cart → checkout
3. No shipping address needed (digital)
4. No shipping cost
5. Complete payment
6. License key generated: format `XXXX-XXXX-XXXX-XXXX`
7. Order appears in `/orders` with digital badge
8. Download link available immediately
9. Test book redirect URL works

**Test assertions:**
- No shipping required for digital
- License created in `licenses` collection
- Download URL accessible
- Re-download works (license stays active)

---

## Flow 9: Coupon Application

**Preconditions:** Buyer with items in cart.

1. Navigate to `/checkout`
2. Find coupon code input
3. Enter `WELCOME10` → 10% discount applied
4. Total updates in summary
5. Enter `EXPIRED20` → error: "Coupon expired"
6. Enter `INVALID` → error: "Invalid coupon code"
7. Remove coupon → total reverts
8. Enter `SAVE5NOW` → $5 off (min $30 order)

**Test assertions:**
- Discount applied correctly (% and fixed)
- Expired coupon rejected
- Per-user usage limit enforced
- Minimum order enforced

---

## Flow 10: Seller Warehouse Management

**Preconditions:** Seller logged in.

1. Navigate to `/seller/warehouses`
2. View existing warehouses
3. Add new warehouse:
   - Type: Warehouse
   - Name: "Toronto Hub"
   - Address: 100 King St W, Toronto, ON, M5X 1A4
4. Set as primary warehouse
5. Navigate to add product → select this warehouse
6. Per-warehouse stock configured
7. Delete old warehouse (if not used)

**Test assertions:**
- At least 1 warehouse required to add products
- Primary warehouse enforced
- Address validation (Canada only)

---

## Flow 11: Admin User Management

**Preconditions:** Admin logged in.

1. Navigate to `/admin`
2. Search for seller: `seller1@mseed.ca`
3. View seller profile + Stripe account status
4. Suspend seller → seller cannot list products
5. Unsuspend seller → restored
6. View security alerts
7. Manually refund order
8. View product ratings, flag/delete suspicious review

**Test assertions:**
- Non-admin cannot access admin routes
- Suspended seller products hidden from buyers
- Audit log entry created for admin actions

---

## Flow 12: Back-in-Stock Notification

**Preconditions:** Buyer. Out-of-stock product: `mseed_prod_oos_1`.

1. View `mseed_prod_oos_1` product detail
2. "Notify Me" button shown (stock = 0)
3. Tap "Notify Me" → subscribed
4. Admin adds stock → product back to `active` with stock > 0
5. Buyer receives push notification
6. Notification links to product page

**Test assertions:**
- Notify Me button only on OOS products
- Duplicate subscriptions prevented
- Notification sent when stock restored

---

## Flow 13: Chat Flow (Premium)

**Preconditions:** Premium buyer. Active seller product.

1. View product detail
2. Tap "Chat with Seller" → navigate to `/chat/:chatId`
3. Send message: "Hi, do you ship to Quebec?"
4. Message appears in chat list
5. Seller logs in → sees unread badge
6. Seller replies
7. Buyer sees reply in real-time
8. Non-premium buyer taps chat → paywall shown

**Test assertions:**
- Chat only accessible to premium buyers
- Messages ordered by timestamp
- Read receipts work
- Non-premium see subscription prompt

---

## Flow 14: Multi-Seller Cart

**Preconditions:** Buyer with products from 2 different sellers in cart.

1. Add `mseed_prod_electronics_1` (seller_1) to cart
2. Add `mseed_prod_fashion_1` (seller_2) to cart
3. Navigate to `/cart`
4. See items grouped by seller
5. Checkout → separate shipping per seller
6. One Stripe session, multiple order items
7. Each seller gets separate payout
8. Platform fee deducted from each seller

**Test assertions:**
- Cart groups by seller
- Shipping calculated per seller address
- Platform fee = 2.5% per seller subtotal
- Both sellers can see their portion of the order

---

## Flow 15: Security — Self-Purchase Blocked

**Preconditions:** Admin (also seller) logged in.

1. Navigate to product owned by admin
2. Product detail shows "Your Product" message
3. Add to Cart button hidden
4. Cannot proceed to checkout with own product
5. Backend verifies `sellerId != buyerId`

**Test assertions:**
- UI hides add-to-cart for own products
- Backend rejects self-purchase attempts
- `product_own_product_message` key visible

---

## QA Checklist for Manual Testing (Admin Login)

Use these screens with the mega-seeded dev data:

| Screen | Test Data Available | What to Verify |
|--------|---------------------|----------------|
| Home | 30 products (20 active) | Search, filter, categories, product cards |
| Product Detail | All lifecycle states | Images, pricing, add to cart, OOS state |
| Cart | 3 items pre-loaded | Quantities, totals, coupon, checkout |
| Orders | 16 orders all statuses | Status badges, action buttons, order details |
| Seller Orders | 1 confirmed order | Mark shipped, tracking |
| Admin Panel | All users + products | Approve/reject, user management |
| Favorites | 15 favorited products | Toggle favorite, view favorites screen |
| Subscription | Not premium by default | Subscribe flow, feature gates |
| Digital Products | 2 active digital products | Buy, download, activate license |
| Warehouses | 1 warehouse seeded | Add warehouse, edit |
| Addresses | Admin has 1 address | Add/edit/delete address |
| Return Requests | 3 returns seeded | View return status |
