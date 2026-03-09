# Symbol Map — OrignaGta

> **Auto-generated** by `scripts/generate-symbol-map.sh` — Regenerate: `./scripts/generate-symbol-map.sh`
> Last updated: 2026-02-18

Classes, functions, and key methods organized by domain. Implementation-only (no abstract duplicates).

---

## Auth & User

### Auth (Frontend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `LoginViewModel` | class | lib/features/auth/login_viewmodel.dart | L11 |
| `LoginState` | class | lib/features/auth/login_state.dart | L1 |
| `handleAuth` | method | lib/features/auth/login_viewmodel.dart | L16 |
| `handleGoogleSignIn` | method | lib/features/auth/login_viewmodel.dart | L111 |
| `resetPassword` | method | lib/features/auth/login_viewmodel.dart | L130 |
| `FirebaseAuthRepository` | class | lib/core/repositories/auth_repository.dart | L34 |
| `deleteAccount` | method | lib/core/repositories/auth_repository.dart | L42 |
| `ensureUserDocumentExists` | method | lib/core/repositories/auth_repository.dart | L53 |
| `registerWithEmail` | method | lib/core/repositories/auth_repository.dart | L103 |
| `signInWithEmail` | method | lib/core/repositories/auth_repository.dart | L233 |
| `signInWithGoogle` | method | lib/core/repositories/auth_repository.dart | L264 |
| `signOut` | method | lib/core/repositories/auth_repository.dart | L281 |
| `validateCurrentUser` | method | lib/core/repositories/auth_repository.dart | L286 |
| `watchProfile` | method | lib/core/repositories/auth_repository.dart | L342 |

### Auth & Admin (Backend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `update_user_roles` | function | functions/handlers/admin.py | L86 |
| `suspend_seller` | function | functions/handlers/admin.py | L195 |
| `restore_stock_batch` | function | functions/handlers/admin.py | L346 |
| `admin_mfa_enroll` | function | functions/handlers/admin.py | L382 |
| `admin_mfa_verify` | function | functions/handlers/admin.py | L434 |
| `admin_mfa_disable` | function | functions/handlers/admin.py | L489 |
| `delete_account` | function | functions/handlers/admin.py | L538 |
| `User` | class | functions/models/user.py | L12 |
| `UserCreate` | class | functions/models/user.py | L173 |

## Products

### Products (Frontend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `AddProductViewModel` | class | lib/features/products/add_product_viewmodel.dart | L17 |
| `AddProductState` | class | lib/features/products/add_product_state.dart | L3 |
| `EditProductViewModel` | class | lib/features/products/edit_product_viewmodel.dart | L15 |
| `EditProductState` | class | lib/features/products/edit_product_state.dart | L3 |
| `ProductActionsViewModel` | class | lib/features/products/product_actions_viewmodel.dart | L20 |
| `ProductDetailViewModel` | class | lib/features/products/product_detail_viewmodel.dart | L28 |
| `ProductRatingViewModel` | class | lib/features/products/product_rating_viewmodel.dart | L20 |
| `FavoritesController` | class | lib/features/products/products_provider.dart | L70 |
| `ProductQuery` | class | lib/features/products/products_provider.dart | L93 |
| `FirebaseProductRepository` | class | lib/core/repositories/product_repository.dart | L11 |
| `addProduct` | method | lib/core/repositories/product_repository.dart | L18 |
| `deleteProduct` | method | lib/core/repositories/product_repository.dart | L58 |
| `fetchProducts` | method | lib/core/repositories/product_repository.dart | L73 |
| `uploadImages` | method | lib/core/repositories/product_repository.dart | L155 |
| `AlgoliaProductRepository` | class | lib/core/repositories/algolia_product_repository.dart | L12 |
| `DeliveryInfo` | class | lib/models/generated/product_models.dart | L42 |
| `InventoryConfig` | class | lib/models/generated/product_models.dart | L65 |
| `Product` | class | lib/models/generated/product_models.dart | L91 |
| `ProductCreate` | class | lib/models/generated/product_models.dart | L159 |
| `SellerDeliveryOption` | class | lib/models/generated/product_models.dart | L202 |
| `ShippingQuantityDiscount` | class | lib/models/generated/product_models.dart | L230 |
| `SupplierInfo` | class | lib/models/generated/product_models.dart | L253 |

### Products (Backend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `upload_product_images` | function | functions/handlers/products.py | L63 |
| `delete_product` | function | functions/handlers/products.py | L160 |
| `submit_product_rating` | function | functions/handlers/products.py | L237 |
| `update_rating_transaction` | function | functions/handlers/products.py | L325 |
| `on_product_created` | function | functions/handlers/products.py | L358 |
| `on_product_updated` | function | functions/handlers/products.py | L431 |
| `on_product_deleted` | function | functions/handlers/products.py | L460 |
| `configure_algolia` | function | functions/handlers/products.py | L474 |
| `get_products_paginated` | function | functions/handlers/products.py | L505 |
| `get_seller_products_paginated` | function | functions/handlers/products.py | L605 |
| `get_product_ratings_paginated` | function | functions/handlers/products.py | L705 |
| `Product` | class | functions/models/product.py | L248 |
| `ProductCreate` | class | functions/models/product.py | L458 |
| `SellerDeliveryOption` | class | functions/models/product.py | L58 |
| `SupplierInfo` | class | functions/models/product.py | L131 |
| `InventoryConfig` | class | functions/models/product.py | L208 |

## Orders

### Orders (Frontend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `BuyerOrdersViewModel` | class | lib/features/orders/buyer_orders_viewmodel.dart | L20 |
| `SellerOrdersViewModel` | class | lib/features/orders/seller_orders_viewmodel.dart | L9 |
| `ShippingApprovalViewModel` | class | lib/features/orders/shipping_approval_viewmodel.dart | L20 |
| `FirebaseOrderRepository` | class | lib/core/repositories/order_repository.dart | L7 |
| `approveShippingCost` | method | lib/core/repositories/order_repository.dart | L14 |
| `capturePayment` | method | lib/core/repositories/order_repository.dart | L19 |
| `confirmReceipt` | method | lib/core/repositories/order_repository.dart | L24 |
| `createCheckoutSession` | method | lib/core/repositories/order_repository.dart | L29 |
| `updateItemStatus` | method | lib/core/repositories/order_repository.dart | L43 |
| `watchBuyerOrders` | method | lib/core/repositories/order_repository.dart | L68 |
| `watchSellerOrders` | method | lib/core/repositories/order_repository.dart | L93 |
| `Order` | class | lib/models/generated/order_models.dart | L162 |
| `OrderCreate` | class | lib/models/generated/order_models.dart | L348 |
| `OrderItem` | class | lib/models/generated/order_models.dart | L368 |
| `SellerPayout` | class | lib/models/generated/order_models.dart | L428 |
| `Taxes` | class | lib/models/generated/order_models.dart | L474 |

### Orders (Backend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `confirm_order_receipt` | function | functions/handlers/orders.py | L61 |
| `update_order_status` | function | functions/handlers/orders.py | L85 |
| `update_item_status` | function | functions/handlers/orders.py | L253 |
| `cancel_order` | function | functions/handlers/orders.py | L397 |
| `refund_order_item` | function | functions/handlers/orders.py | L518 |
| `approve_shipping_cost` | function | functions/handlers/orders.py | L728 |
| `on_order_status_changed` | function | functions/handlers/orders.py | L852 |
| `Order` | class | functions/models/order.py | L122 |
| `OrderCreate` | class | functions/models/order.py | L209 |
| `OrderItem` | class | functions/models/order.py | L14 |
| `SellerPayout` | class | functions/models/order.py | L88 |
| `Taxes` | class | functions/models/order.py | L68 |

### Cron Jobs

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `auto_capture_confirmed_receipts` | function | functions/handlers/cron_jobs.py | L57 |
| `check_expired_authorizations` | function | functions/handlers/cron_jobs.py | L237 |
| `auto_archive_old_orders` | function | functions/handlers/cron_jobs.py | L308 |
| `monitor_algolia_sync` | function | functions/handlers/cron_jobs.py | L360 |
| `cleanup_stale_rate_limits` | function | functions/handlers/cron_jobs.py | L415 |

## Payments

### Payments (Frontend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `CheckoutNotifier` | class | lib/features/checkout/checkout_provider.dart | L49 |
| `CheckoutState` | class | lib/features/checkout/checkout_provider.dart | L337 |
| `calculateShipping` | method | lib/features/checkout/checkout_provider.dart | L59 |
| `calculateTaxes` | method | lib/features/checkout/checkout_provider.dart | L122 |
| `startCheckout` | method | lib/features/checkout/checkout_provider.dart | L163 |
| `updateAddress` | method | lib/features/checkout/checkout_provider.dart | L267 |
| `CartController` | class | lib/features/cart/cart_provider.dart | L179 |
| `addToCart` | method | lib/features/cart/cart_provider.dart | L205 |
| `removeFromCart` | method | lib/features/cart/cart_provider.dart | L239 |
| `updateQuantity` | method | lib/features/cart/cart_provider.dart | L245 |
| `FirebaseCartRepository` | class | lib/core/repositories/cart_repository.dart | L13 |

### Payments — Stripe (Backend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `create_checkout_session` | function | functions/handlers/payment_stripe.py | L144 |
| `reserve_stock_transaction` | function | functions/handlers/payment_stripe.py | L425 |
| `get_tax_code_for_category` | function | functions/handlers/payment_stripe.py | L534 |
| `rollback_stock` | function | functions/handlers/payment_stripe.py | L628 |
| `stripe_webhook` | function | functions/handlers/payment_stripe.py | L655 |
| `process_checkout_session_completed` | function | functions/handlers/payment_stripe.py | L825 |
| `process_async_payment_succeeded` | function | functions/handlers/payment_stripe.py | L906 |
| `process_session_expired` | function | functions/handlers/payment_stripe.py | L962 |
| `process_payment_intent_succeeded` | function | functions/handlers/payment_stripe.py | L985 |
| `process_charge_refunded` | function | functions/handlers/payment_stripe.py | L1017 |
| `process_dispute_created` | function | functions/handlers/payment_stripe.py | L1058 |
| `process_transfer_reversed` | function | functions/handlers/payment_stripe.py | L1167 |
| `process_account_updated` | function | functions/handlers/payment_stripe.py | L1218 |
| `create_connect_account` | function | functions/handlers/payment_stripe.py | L1280 |
| `create_account_link` | function | functions/handlers/payment_stripe.py | L1364 |
| `get_connect_account_status` | function | functions/handlers/payment_stripe.py | L1408 |
| `capture_payment` | function | functions/handlers/payment_stripe.py | L1462 |
| `lock_for_capture` | function | functions/handlers/payment_stripe.py | L1569 |
| `sanitize_metadata` | function | functions/handlers/payment_stripe.py | L1784 |

### Payments — Airwallex (Backend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `airwallex_create_seller_account` | function | functions/handlers/payment_airwallex.py | L73 |
| `airwallex_process_payment` | function | functions/handlers/payment_airwallex.py | L116 |
| `airwallex_capture_payment` | function | functions/handlers/payment_airwallex.py | L195 |
| `airwallex_webhook` | function | functions/handlers/payment_airwallex.py | L249 |

### Payment Providers (Backend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `PaymentProvider` | class | functions/handlers/payment_providers.py | L80 |
| `is_provider_enabled` | function | functions/handlers/payment_providers.py | L113 |
| `get_enabled_providers` | function | functions/handlers/payment_providers.py | L151 |
| `get_payment_providers` | function | functions/handlers/payment_providers.py | L242 |
| `update_payment_provider` | function | functions/handlers/payment_providers.py | L293 |
| `get_provider_status` | function | functions/handlers/payment_providers.py | L406 |

## Seller

### Seller (Frontend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `SellerRegistrationViewModel` | class | lib/features/seller/seller_registration_view_model.dart | L15 |
| `SellerRegistrationState` | class | lib/features/seller/seller_registration_state.dart | L2 |
| `continueOnboarding` | method | lib/features/seller/seller_registration_view_model.dart | L58 |
| `refreshAccountStatus` | method | lib/features/seller/seller_registration_view_model.dart | L83 |
| `startRegistration` | method | lib/features/seller/seller_registration_view_model.dart | L110 |

## Schema & Config

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `Collections` | class | functions/schema_constants.py | L35 |
| `Fields` | class | functions/schema_constants.py | L59 |
| `OrderStatusValues` | class | functions/schema_constants.py | L275 |
| `PaymentStatusValues` | class | functions/schema_constants.py | L295 |
| `DeliveryStatusValues` | class | functions/schema_constants.py | L315 |
| `PayoutStatusValues` | class | functions/schema_constants.py | L325 |
| `UserRoleValues` | class | functions/schema_constants.py | L340 |
| `ProductStatusValues` | class | functions/schema_constants.py | L349 |
| `ShippingApprovalStatusValues` | class | functions/schema_constants.py | L360 |
| `SchemaRegistry` | class | functions/schema_constants.py | L383 |
| `BusinessRules` | class | functions/schema_constants.py | L437 |
| `ApiKeys` | class | functions/schema_constants.py | L496 |
| `Environment` | class | functions/config.py | L37 |
| `OrderStatus` | class | functions/config.py | L58 |
| `PaymentStatus` | class | functions/config.py | L71 |
| `DeliveryStatus` | class | functions/config.py | L83 |
| `R2Config` | class | functions/config.py | L143 |
| `AlgoliaConfig` | class | functions/config.py | L185 |
| `StripeConfig` | class | functions/config.py | L225 |

### Utils (Backend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `create_success_response` | function | functions/utils/helpers.py | L17 |
| `create_error_response` | function | functions/utils/helpers.py | L21 |
| `sanitize_email` | function | functions/utils/helpers.py | L127 |
| `validate_address_map` | function | functions/utils/helpers.py | L171 |
| `validate_order_data` | function | functions/utils/helpers.py | L206 |
| `log_webhook_to_database` | function | functions/utils/helpers.py | L253 |
| `is_valid_order_status_transition` | function | functions/utils/helpers.py | L286 |

## Services

### Services (Frontend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `AlgoliaService` | class | lib/services/algolia_service.dart | L7 |
| `ConfigService` | class | lib/services/conf_services.dart | L3 |
| `SessionTimeoutService` | class | lib/services/session_timeout_service.dart | L11 |
| `SplashService` | class | lib/services/splash_service.dart | L4 |

### Services (Backend)

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `calculate_shipping_cost` | function | functions/services/shipping_service.py | L373 |
| `estimate_delivery_date_range` | function | functions/services/shipping_service.py | L133 |
| `get_tax_rate` | function | functions/services/shipping_service.py | L94 |
| `get_order_confirmation_email` | function | functions/services/email_service.py | L13 |
| `get_seller_notification_email` | function | functions/services/email_service.py | L228 |
| `send_email` | function | functions/services/email_service.py | L451 |
| `index_product` | function | functions/services/algolia_service.py | L107 |
| `delete_product` | function | functions/services/algolia_service.py | L152 |
| `batch_index_products` | function | functions/services/algolia_service.py | L189 |
| `configure_algolia_index` | function | functions/services/algolia_service.py | L221 |
| `RateLimiter` | class | functions/services/rate_limiter.py | L9 |
| `AirwallexService` | class | functions/services/airwallex_service.py | L22 |

## Additional Repositories

| Symbol | Kind | File | Line |
|--------|------|------|------|
| `FirebaseUserRepository` | class | lib/core/repositories/user_repository.dart | L5 |
| `SellerAccountStatus` | class | lib/core/repositories/user_repository.dart | L52 |
| `GeoapifyLocationRepository` | class | lib/core/repositories/location_repository.dart | L9 |

## Pydantic Models

| Model | File | Line |
|-------|------|------|
| `User` | functions/models/user.py | L12 |
| `UserCreate` | functions/models/user.py | L173 |
| `OrderItem` | functions/models/order.py | L14 |
| `Taxes` | functions/models/order.py | L68 |
| `Ratings` | functions/models/order.py | L80 |
| `SellerPayout` | functions/models/order.py | L88 |
| `Order` | functions/models/order.py | L122 |
| `OrderCreate` | functions/models/order.py | L209 |
| `ShippingQuantityDiscount` | functions/models/product.py | L16 |
| `SellerDeliveryOption` | functions/models/product.py | L58 |
| `SupplierInfo` | functions/models/product.py | L131 |
| `InventoryConfig` | functions/models/product.py | L208 |
| `Product` | functions/models/product.py | L248 |
| `ProductCreate` | functions/models/product.py | L458 |
| `Address` | functions/models/base.py | L73 |
| `AddressDetails` | functions/models/base.py | L210 |

## Freezed Models (Dart)

| Model | File | Line |
|-------|------|------|
| `Address` | lib/models/generated/base_models.dart | L16 |
| `AddressDetails` | lib/models/generated/base_models.dart | L49 |
| `User` | lib/models/generated/user_models.dart | L28 |
| `UserCreate` | lib/models/generated/user_models.dart | L99 |
| `Product` | lib/models/generated/product_models.dart | L92 |
| `ProductCreate` | lib/models/generated/product_models.dart | L160 |
| `InventoryConfig` | lib/models/generated/product_models.dart | L66 |
| `SellerDeliveryOption` | lib/models/generated/product_models.dart | L203 |
| `SupplierInfo` | lib/models/generated/product_models.dart | L254 |
| `Order` | lib/models/generated/order_models.dart | L163 |
| `OrderCreate` | lib/models/generated/order_models.dart | L349 |
| `OrderItem` | lib/models/generated/order_models.dart | L369 |
| `SellerPayout` | lib/models/generated/order_models.dart | L429 |
| `Taxes` | lib/models/generated/order_models.dart | L475 |

## Riverpod Providers (declarations only)

### Core Providers (`lib/core/providers.dart`)
- `algoliaProductRepositoryProvider` — `Provider<ProductRepository>`
- `algoliaServiceProvider` — `Provider<AlgoliaService>`
- `authRepositoryProvider` — `Provider<AuthRepository>`
- `authStateProvider` — `StreamProvider<User?>`
- `cartRepositoryProvider` — `Provider<CartRepository>`
- `currentUserProvider` — `Provider<User?>`
- `firebaseAuthProvider` — `Provider<FirebaseAuth>`
- `firebaseFunctionsProvider` — `Provider<FirebaseFunctions>`
- `firestoreProvider` — `Provider<FirebaseFirestore>`
- `locationRepositoryProvider` — `Provider<LocationRepository>`
- `orderRepositoryProvider` — `Provider<OrderRepository>`
- `productRepositoryProvider` — `Provider<ProductRepository>`
- `userIdProvider` — `Provider<String?>`
- `userRepositoryProvider` — `Provider<UserRepository>`

### Feature Providers
- `loginViewModelProvider` — `StateNotifierProvider<LoginViewModel, LoginState>` (auth)
- `userProfileProvider` — `StreamProvider<UserModel?>` (auth)
- `homeViewModelProvider` — `StateNotifierProvider<HomeViewModel, HomeState>` (home)
- `addProductViewModelProvider` — `StateNotifierProvider<AddProductViewModel, AddProductState>` (products)
- `editProductViewModelProvider` — `StateNotifierProvider.family<..., Product>` (products)
- `productActionsViewModelProvider` — `StateNotifierProvider<ProductActionsViewModel, ...>` (products)
- `productDetailViewModelProvider` — `StateNotifierProvider` (products)
- `productRatingViewModelProvider` — `StateNotifierProvider<ProductRatingViewModel, ...>` (products)
- `productsProvider` — `FutureProvider.family<List<Product>, ProductQuery>` (products)
- `productByIdProvider` — `FutureProvider.family<Product?, String>` (products)
- `favoritesProvider` — `StreamProvider<Set<String>>` (products)
- `favoritedProductsProvider` — `FutureProvider<List<Product>>` (products)
- `favoritesControllerProvider` — `Provider<FavoritesController>` (products)
- `searchQueryProvider` — `StateProvider<String>` (products)
- `selectedCategoryProvider` — `StateProvider<int?>` (products)
- `filteredProductsProvider` — `FutureProvider<List<Product>>` (products)
- `checkoutStateProvider` — `StateNotifierProvider<CheckoutNotifier, CheckoutState>` (checkout)
- `checkoutTaxRateProvider` — `Provider<double>` (checkout)
- `checkoutTotalProvider` — `Provider<double>` (checkout)
- `cartControllerProvider` — `Provider<CartController>` (cart)
- `cartItemsProvider` — `StreamProvider<List<CartItemModel>>` (cart)
- `cartItemCountProvider` — `Provider<int>` (cart)
- `cartSubtotalProvider` — `Provider<double>` (cart)
- `cartWithDetailsProvider` — `FutureProvider<List<CartItemDetailModel>>` (cart)
- `cartItemDetailProvider` — `FutureProvider.family<CartItemDetailModel?, String>` (cart)
- `cartItemQuantityProvider` — `StreamProvider.family<int, String>` (cart)
- `buyerOrdersProvider` — `StreamProvider<List<Order>>` (orders)
- `sellerOrdersProvider` — `StreamProvider<List<Order>>` (orders)
- `orderByIdProvider` — `FutureProvider.family<Order?, String>` (orders)
- `paidOrderBySessionProvider` — `StreamProvider.family<Order?, String>` (orders)
- `pendingApprovalsCountProvider` — `Provider<int>` (orders)
- `pendingShippingApprovalsProvider` — `Provider<AsyncValue<List<Order>>>` (orders)
- `buyerOrdersViewModelProvider` — `StateNotifierProvider<BuyerOrdersViewModel, ...>` (orders)
- `sellerOrdersViewModelProvider` — `StateNotifierProvider<SellerOrdersViewModel, ...>` (orders)
- `shippingApprovalViewModelProvider` — `StateNotifierProvider<ShippingApprovalViewModel, ...>` (orders)
- `sellerRegistrationViewModelProvider` — `StateNotifierProvider<SellerRegistrationViewModel, ...>` (seller)
- `sellerAccountStatusProvider` — `StreamProvider<SellerAccountStatus>` (app)
- `refreshSellerStatusProvider` — `FutureProvider.family<SellerAccountStatus, void>` (app)
- `profileViewModelProvider` — `StateNotifierProvider<ProfileViewModel, ProfileState>` (profile)
- `addressViewModelProvider` — `StateNotifierProvider<AddressViewModel, AddressState>` (profile)
- `termsProvider` — `FutureProvider<String>` (terms)
- `adminActionsViewModelProvider` — `StateNotifierProvider<AdminActionsViewModel, ...>` (admin)
- `adminOrdersProvider` — `StreamProvider.family<List<Order>, String>` (admin)
- `adminProductsProvider` — `StreamProvider.family<List<Product>, String?>` (admin)
- `adminRepositoryProvider` — `Provider<AdminRepository>` (admin)
- `adminSellersProvider` — `StreamProvider<List<UserModel>>` (admin)
- `adminUsersProvider` — `StreamProvider<List<UserModel>>` (admin)

## Cloud Functions Endpoints

### HTTP Callable (`@https_fn.on_call`)
| Function | File | Line |
|----------|------|------|
| `create_checkout_session` | handlers/payment_stripe.py | L143 |
| `create_connect_account` | handlers/payment_stripe.py | L1279 |
| `create_account_link` | handlers/payment_stripe.py | L1363 |
| `get_connect_account_status` | handlers/payment_stripe.py | L1407 |
| `capture_payment` | handlers/payment_stripe.py | L1461 |
| `upload_product_images` | handlers/products.py | L62 |
| `delete_product` | handlers/products.py | L159 |
| `submit_product_rating` | handlers/products.py | L236 |
| `configure_algolia` | handlers/products.py | L473 |
| `get_products_paginated` | handlers/products.py | L504 |
| `get_seller_products_paginated` | handlers/products.py | L604 |
| `get_product_ratings_paginated` | handlers/products.py | L704 |
| `confirm_order_receipt` | handlers/orders.py | L60 |
| `update_order_status` | handlers/orders.py | L84 |
| `update_item_status` | handlers/orders.py | L252 |
| `cancel_order` | handlers/orders.py | L396 |
| `refund_order_item` | handlers/orders.py | L517 |
| `approve_shipping_cost` | handlers/orders.py | L727 |
| `get_payment_providers` | handlers/payment_providers.py | L241 |
| `update_payment_provider` | handlers/payment_providers.py | L292 |
| `get_provider_status` | handlers/payment_providers.py | L405 |
| `update_user_roles` | handlers/admin.py | L85 |
| `suspend_seller` | handlers/admin.py | L194 |
| `admin_mfa_enroll` | handlers/admin.py | L381 |
| `admin_mfa_verify` | handlers/admin.py | L433 |
| `admin_mfa_disable` | handlers/admin.py | L488 |
| `delete_account` | handlers/admin.py | L537 |
| `airwallex_create_seller_account` | handlers/payment_airwallex.py | L72 |
| `airwallex_process_payment` | handlers/payment_airwallex.py | L115 |
| `airwallex_capture_payment` | handlers/payment_airwallex.py | L194 |

### Webhooks (`@https_fn.on_request`)
| Function | File | Line |
|----------|------|------|
| `stripe_webhook` | handlers/payment_stripe.py | L654 |
| `airwallex_webhook` | handlers/payment_airwallex.py | L248 |

### Scheduled (`@scheduler_fn.on_schedule`)
| Function | Schedule | File | Line |
|----------|----------|------|------|
| `auto_capture_confirmed_receipts` | every 24 hours | handlers/cron_jobs.py | L56 |
| `check_expired_authorizations` | every 24 hours | handlers/cron_jobs.py | L236 |
| `auto_archive_old_orders` | every 12 hours | handlers/cron_jobs.py | L307 |
| `monitor_algolia_sync` | every 15 minutes | handlers/cron_jobs.py | L359 |
| `cleanup_stale_rate_limits` | every 30 minutes | handlers/cron_jobs.py | L414 |
| `check_expired_authorizations_scheduled` | 0 2 * * * | handlers/cron_jobs.py | L454 |
