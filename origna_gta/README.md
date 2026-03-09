#+#+#+#+ origna_gta (Flutter app)

E-commerce marketplace serving Canadian buyers (Web, Android, iOS) using Firebase + Stripe Connect Express. Sellers can be worldwide.

## Architecture (MVVM)
- UI → ViewModels → Repositories → Firebase/Stripe services
- No business logic in widgets
- Idempotent payments + defensive validation
- Product ratings submitted via Cloud Function (server-validated)

## App flow diagram
```mermaid
sequenceDiagram
	participant U as User
	participant A as App
	participant F as Firebase Functions
	participant S as Stripe
	participant DB as Firestore

	U->>A: Checkout
	A->>F: create_checkout_session (idempotencyKey)
	F->>DB: Validate stock, reserve, create order
	F->>S: Create Checkout Session (manual capture, tax)
	S-->>A: Hosted checkout URL
	S-->>F: Webhook events (session completed, PI status)
	F->>DB: Update order totals/taxes/status
	A->>F: confirm_order_receipt (buyer)
	F->>S: Capture payment
	S-->>F: transfer events
```

## Database diagram (Firestore)
```mermaid
erDiagram
	USERS ||--o{ USERS_CART : has
	USERS ||--o{ USERS_FAVORITES : has
	USERS ||--o{ ORDERS : places
	USERS ||--o{ PRODUCTS : sells
	PRODUCTS ||--o{ USERS_CART : in_cart
	PRODUCTS ||--o{ USERS_FAVORITES : favorited
	ORDERS ||--o{ ORDER_ITEMS : contains
	ORDERS ||--o{ SELLER_PAYOUTS : splits
	ORDERS ||--o{ WEBHOOK_LOGS : audited_by
	WEBHOOK_EVENTS ||--o{ WEBHOOK_LOGS : logged_as

	USERS {
		string uid
		string email
		string name
		string[] roles
		Address address
		timestamp createdAt
		string customerId
		string lastCheckoutSession
		string lastOrderId
		timestamp lastCheckoutTimestamp
		string stripeAccountId
		boolean payoutsEnabled
		boolean chargesEnabled
		boolean onboardingCompleted
		boolean suspended
		timestamp suspendedAt
		timestamp updatedAt
	}

	USERS_CART {
		string productId
		number quantity
		timestamp createdAt
	}

	USERS_FAVORITES {
		string productId
		timestamp dateFavorited
	}

	PRODUCTS {
		string name
		number price
		string description
		string[] imageUrls
		string sellerId
		Address sellerAddress
		number categoryId
		number stockQuantity
		number rating
		number ratingCount
		string[] searchKeywords
		boolean isActive
		timestamp deletedAt
		timestamp createdAt
	}

	ORDERS {
		string userId
		string customerEmail
		string customerId
		OrderItem[] items
		string[] sellerIds
		number subtotal
		map taxes
		number shippingCost
		number total
		number amount
		string currency
		string status
		string paymentStatus
		Address deliveryInfo
		string stripeSessionId
		string stripePaymentIntentId
		timestamp createdAt
		timestamp updatedAt
		boolean confirmedByClient
		timestamp confirmedAt
		boolean autoConfirmed
		SellerPayout[] sellerPayouts
		number platformFeeTotal
		string payoutStatus
		map ratings
		number refundAmount
		timestamp refundedAt
	}

	ORDER_ITEMS {
		string productId
		string name
		string description
		number price
		number quantity
		string[] imageUrls
		string sellerId
		Address sellerAddress
		string deliveryStatus
		string trackingNumber
		boolean confirmedByBuyer
		timestamp createdAt
	}

	SELLER_PAYOUTS {
		string sellerId
		string stripeAccountId
		number gross
		number platformFee
		number net
		boolean paid
		string transferId
		timestamp paidAt
		string error
	}

	WEBHOOK_LOGS {
		string eventId
		string eventType
		number payloadSize
		boolean signatureVerified
		string processingStatus
		string orderId
		string errorMessage
		timestamp receivedAt
	}

	WEBHOOK_EVENTS {
		string eventId
		string eventType
		timestamp receivedAt
		boolean processed
		timestamp processedAt
		string processingStatus
		string orderId
		string errorMessage
		boolean livemode
	}

	Address {
		string street
		string apartment
		string city
		string state
		string postalCode
		string country
		string phoneNumber
		boolean isDefault
		string label
		number latitude
		number longitude
	}
```

Source complet des champs : docs/database_schema.json

## Setup
1. Flutter: `flutter pub get`
2. Run app: `flutter run`
3. Tests: `../scripts/run_all_tests.sh`
4. Firestore indexes: `firebase deploy --only firestore:indexes`

## Testing
- Fast local unit/widget path:
  - `flutter test`
- Dedicated unit coverage target:
  - `flutter test test/coverage_gate_test.dart --coverage --coverage-path=coverage_unit.info`
- Dedicated integration coverage target:
  - `flutter test integration_test/coverage_gate_integration_test.dart`
- Full strict gate:
  - `../scripts/run_quality_gate.sh`
- Heavy Flutter integration coverage is enforced remotely by:
  - GitHub Actions `Strict Quality Audit` on Linux desktop
  - Codemagic `quality-gate-remote` on macOS
- Local heavy gates are opt-in via:
  - `../scripts/run_quality_gate.sh --allow-local-heavy --backend-gate-mode strict`

## Stripe Connect (direct charges)
- Manual capture authorization
- Capture after shipment/receipt confirmation
- Platform fee: 2.5%

## Stripe test cards
- 4242 4242 4242 4242 (success)
- 4000 0000 0000 9995 (insufficient funds)
- 4000 0000 0000 0002 (generic decline)
- 4000 0025 0000 3155 (3DS required)

Use any future expiry, any CVC, any postal code.

## Current hardening focus
- Keep checkout/order/payment flows green in the remote strict audit.
- Expand integration/device tests around user-visible flows instead of adding logic to widgets.
- Expand threat-model tests for cart/checkout abuse.



