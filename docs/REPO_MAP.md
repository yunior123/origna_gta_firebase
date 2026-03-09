# Repository Map — OrignaGta

> **Purpose:** Condensed index of every module, file, and its responsibility. Use this to navigate the codebase efficiently without reading every file.

---

## 🔧 Backend — `functions/`

### Entry Point
| File | Exports | Responsibility |
|------|---------|----------------|
| `main.py` | All Cloud Functions | Function registration, Stripe init, validation helpers |

### Handlers — `functions/handlers/` (114 Cloud Functions total)
| File | Key Functions | Responsibility |
|------|---------------|----------------|
| `payment_stripe.py` | `create_checkout_session`, `verify_cart_prices`, `stripe_webhook`, `capture_payment`, `create_connect_account`, `get_connect_account_status`, `create_account_link`, `process_charge_refunded`, `process_dispute_created`, `process_dispute_closed`, `process_dispute_updated`, `process_dispute_funds_reinstated` | Stripe payments: checkout, capture, webhooks, Connect onboarding, dispute handling |
| `payment_providers.py` | `get_payment_providers`, `update_payment_provider`, `get_provider_status` | Admin payment provider management (enable/disable) |
| `orders.py` | `confirm_order_receipt`, `update_order_status`, `update_item_status`, `refund_order_item`, `cancel_order`, `approve_shipping_cost`, `update_shipping_cost`, `on_order_status_changed`, `create_return_request`, `approve_return_request`, `reject_return_request` | Order state machine, item status, refunds, shipping approval, and return requests. |
| `products.py` | `upload_product_images`, `delete_product`, `submit_product_rating`, `configure_algolia`, `get_products_paginated`, `get_seller_products_paginated`, `get_product_ratings_paginated`, `on_product_created`, `on_product_updated`, `on_product_deleted`, `subscribe_stock_notification`, `unsubscribe_stock_notification`, `ask_product_question`, `answer_product_question`, `get_product_questions` | Product management, Algolia sync, ratings, stock notifications, and product Q&A. |
| `chat.py` | `get_or_create_chat`, `send_message`, `mark_messages_read`, `delete_message`, `report_message` | Real-time chat between buyers and sellers (Premium feature). |
| `addresses.py` | `add_buyer_address`, `update_buyer_address`, `delete_buyer_address`, `set_default_buyer_address` | User shipping address management. |
| `digital.py` | `activate_license`, `deactivate_license`, `generate_book_download_session`, `generate_software_download_session`, `verify_license` | Digital products: license management and secure download sessions. |
| `coupons.py` | `validate_coupon`, `apply_coupon_to_order`, `admin_create_coupon` | Platform-wide and seller-specific discount coupons. |
| `subscriptions.py` | `create_premium_subscription`, `cancel_premium_subscription`, `get_subscription_status`, `reactivate_subscription` | Premium membership management for waived fees and advanced features. |
| `admin.py` | `update_user_roles`, `suspend_seller`, `unsuspend_seller`, `admin_update_product_stock`, `admin_mfa_enroll`, `admin_mfa_verify`, `admin_mfa_verify_backup`, `admin_mfa_disable`, `delete_account`, `export_my_data`, `unsubscribe_email` | Role management, seller suspension, MFA, and CASL/PIPEDA compliance. |
| `users.py` | `update_user_profile`, `get_user_profile`, `update_email_consent`, `update_notification_preferences`, `create_user_profile`, `cleanup_fcm_token` | User profile CRUD and email consent management. |
| `cron_jobs.py` | `auto_capture_confirmed_receipts`, `check_expired_authorizations`, `auto_archive_old_orders`, `monitor_algolia_sync`, `cleanup_stale_rate_limits`, `cleanup_orphaned_r2_images`, `cleanup_stale_webhook_events`, `cleanup_stale_security_alerts`, `retry_failed_algolia_syncs`, `check_low_stock_alerts`, `send_abandoned_cart_emails`, `compute_seller_metrics`, `compute_trending_products`, `sync_expired_subscriptions`, `escalate_stale_return_requests` | Scheduled cron jobs for maintenance and automated tasks. |
| `email_tasks.py` | `sendEmailTask` | Asynchronous email tasks triggered by events (via Cloud Tasks). |
| `shipping.py` | `calculate_shipping_cost` | Shipping cost calculation wrapper. |

### Models — `functions/models/`
| File | Classes | Fields of Note |
|------|---------|----------------|
| `base.py` | `OrderStatus`, `PaymentStatus`, enums | Shared enums and base types |
| `order.py` | `Order`, `OrderItem` (Pydantic) | `status`, `items[]`, `totalAmount`, `sellerId`, `buyerId` |
| `product.py` | `Product` (Pydantic) | `price`, `stock`, `sellerId`, `shippingConfig`, `isActive` |
| `user.py` | `User` (Pydantic) | `roles[]`, `stripeAccountId`, `emailVerified`, `suspended` |

### Services
| File | Responsibility |
|------|----------------|
| `schema_constants.py` | All Firestore field names, collection names, enum values (525 lines) |
| `shipping_service.py` | Shipping cost calculation: distance, province, tiers, weight surcharge. Exports `calculate_shipping_cost` Cloud Function |
| `email_service.py` | Mailjet email sending, all HTML templates (~733 lines) |
| `algolia_service.py` | Algolia index sync |
| `rate_limiter.py` | API rate limiting by IP/user |
| `utils.py` | Auth validation, error helpers |
| `config.py` | Environment config |
| `push_service.py` | Firebase Cloud Messaging (FCM) push notifications. |
| `pdf_invoice_service.py` | PDF invoice generation. |
| `email_task.py` | Helper for sending email tasks via Cloud Tasks. |

### Tests — `functions/tests/` (458 tests)
| File | Coverage Area |
|------|---------------|
| `test_critical_flow_scenarios.py` | End-to-end business flows |
| `test_handlers_payment_stripe.py` | Payment handler unit tests |
| `test_handlers_products_orders.py` | Product/order handler tests |
| `test_handlers_admin_cron.py` | Admin + cron job tests |
| `test_payment_security.py` | Payment security edge cases |
| `test_payment_integration.py` | Payment integration flows |
| `test_shipping_service_estimates.py` | Shipping calculation tests |
| `test_shipping_security.py` | Shipping manipulation tests |
| `test_schema_consistency.py` | Python↔JSON schema sync |
| `test_schema_contract.py` | Schema contract validation |
| `test_webhook_security.py` | Webhook HMAC verification |
| `test_edge_cases_advanced.py` | Advanced edge cases |
| `test_pydantic_models.py` | Model validation |
| `test_tax_audit.py` | Tax calculation |
| `test_algolia_indexing.py` | Algolia sync |
| `test_backend_integration.py` | Backend integration |
| `test_adversarial_scenarios.py` | Security scenarios against tampering |
| `test_algolia_simple.py` | Basic Algolia client functionality |
| `test_turnstile.py` | Cloudflare Turnstile token verification (9 tests) |
| `test_checkout_fixes_Feb2026.py` | Recent checkout bug fixes |
| `test_email_service.py` | Email sending service tests |
| `test_handlers_digital.py` | Digital product license handling |
| `test_handlers_users.py` | User profile and address management |
| `test_integration_magnus.py` | Magnus integration tests |
| `test_notifications_flow.py` | Push notification flows |
| `test_rate_limiter_prod.py` | Rate limiter behavior in production |
| `test_r2_simple.py` | R2 storage integration tests |
| `test_schema_sync.py` | Schema synchronization tests |
| `test_security_fixes_2026_02_08.py` | Security fixes from early Feb 2026 |
| `test_security_fixes_2026_02_08_v2.py` | Further security fixes (version 2) |
| `test_security_funcs.py` | General security functions |
| `test_shipping.py` | General shipping logic tests |
| `test_stock_rollback_T7.py` | Stock rollback mechanism tests |

---

## 📱 Frontend — `origna_gta/lib/`

### Core — `lib/core/`
| File | Responsibility |
|------|----------------|
| `providers.dart` | Global Riverpod providers |
| `schema/schema_constants.dart` | Dart mirror of Python schema_constants (465 lines) |
| `repositories/auth_repository.dart` | Firebase Auth operations |
| `repositories/cart_repository.dart` | Cart Firestore CRUD |
| `repositories/order_repository.dart` | Order Firestore queries |
| `repositories/product_repository.dart` | Product Firestore CRUD |
| `repositories/user_repository.dart` | User profile operations |
| `repositories/location_repository.dart` | Geoapify location services |
| `repositories/algolia_product_repository.dart` | Algolia search queries |

### Features — `lib/features/` (MVVM ViewModels + State)
| Feature | Files | Responsibility |
|---------|-------|----------------|
| **auth** | `auth_provider.dart`, `login_viewmodel.dart`, `login_state.dart` | Authentication state, login/register logic |
| **cart** | `cart_provider.dart` | Cart management, add/remove/update items |
| **checkout** | `checkout_provider.dart` | Checkout orchestration: address, shipping, payment |
| **home** | `home_viewmodel.dart`, `home_state.dart` | Home screen: product listing, search, filters |
| **orders** | `buyer_orders_viewmodel.dart`, `seller_orders_viewmodel.dart`, `seller_orders_state.dart`, `orders_provider.dart`, `shipping_approval_viewmodel.dart` | Order management for buyers and sellers |
| **products** | `add_product_viewmodel.dart`, `edit_product_viewmodel.dart`, `product_detail_viewmodel.dart`, `product_actions_viewmodel.dart`, `product_rating_viewmodel.dart`, `products_provider.dart` + states | Product CRUD, rating, detail view |
| **seller** | `seller_registration_view_model.dart`, `seller_registration_state.dart` | Seller onboarding flow |
| **app** | `seller_account_status_viewmodel.dart` | Seller account status monitoring |
| **terms** | `terms_provider.dart` | Terms acceptance tracking |
| **chat** | `chat_viewmodel.dart`, `chat_state.dart` | Chat messaging functionality |
| **subscription** | `subscription_viewmodel.dart`, `subscription_state.dart` | Premium subscription management |

### Screens — `lib/screens/` (35 screens)
| Screen | ViewModel/Provider | Backend Handler |
|--------|-------------------|-----------------|
| `login_screen.dart` | `login_viewmodel` | Firebase Auth (direct) |
| `home_screen.dart` | `home_viewmodel` | Algolia (direct search) |
| `productdetails_screen.dart` | `product_detail_viewmodel` | Firestore (direct read) |
| `addproduct_screen.dart` | `add_product_viewmodel` | Firestore write → `on_product_created` trigger |
| `editproduct_screen.dart` | `edit_product_viewmodel` | Firestore write → `on_product_updated` trigger |
| `cart_screen.dart` | `cart_provider` | — (local Firestore) |
| `checkout_screen.dart` | `checkout_provider` | `payment_stripe.create_checkout_session` |
| `orders_screen.dart` | `buyer_orders_viewmodel` | Firestore query (direct) |
| `seller_orders_screen.dart` | `seller_orders_viewmodel` | `orders.update_shipping_cost`, `orders.capture_payment` |
| `shipping_approval_screen.dart` | `shipping_approval_viewmodel` | `orders.approve_shipping_cost` |
| `ordersuccess_screen.dart` | — | — |
| `seller_registration_screen.dart` | `seller_registration_view_model` | `payment_stripe.create_connect_account` |
| `profile_screen.dart` | — | `users.get_user_profile` |
| `addressmanagement_screen.dart` | — | user_repository (Firestore) |
| `favorites_screen.dart` | — | product_repository (Firestore) |
| `product_card_screen.dart` | `product_detail_viewmodel` | Firestore (direct read) |
| `productaddimages_screen.dart` | `add_product_viewmodel` | Firestore write → `upload_product_images` |
| `chat_screen.dart` | `chat_viewmodel` | `chat.get_or_create_chat`, `chat.send_message` |
| `seller/seller_warehouses_screen.dart` | `seller_warehouses_viewmodel` | Warehouse CRUD functions |
| `productaddvideo_screen.dart` | `add_product_viewmodel` | Firestore write → `upload_product_video` |
| `seller_products_screen.dart` | `seller_products_viewmodel` | Seller product listings |
| `authwrapper_screen.dart` | `auth_provider` | Authentication flow wrapper |
| `cartitem_screen.dart` | `cart_provider` | Individual cart item display |
| `editaddress_screen.dart` | `user_repository` | User address editing |
| `main_screen.dart` | — | Main navigation screen |
| `order_detail_screen.dart` | `order_details_viewmodel` | Individual order details |
| `privacy_policy_screen.dart` | — | Displays privacy policy |
| `reset_password_screen.dart` | `auth_provider` | Password reset functionality |
| `seller_integration_screen.dart` | `seller_integration_viewmodel` | Seller integration setups |
| `seller_setup_screen.dart` | `seller_setup_viewmodel` | Seller initial setup |
| `subscription_cancel_screen.dart` | `subscription_viewmodel` | Subscription cancellation flow |
| `subscription_screen.dart` | `subscription_viewmodel` | Premium subscription display |
| `subscription_success_screen.dart` | `subscription_viewmodel` | Subscription success message |
| `terms_of_service_screen.dart` | `terms_provider` | Displays terms of service |
| `terms_screen.dart` | `terms_provider` | General terms display |

### Models — `lib/models/`
| File | Classes | Note |
|------|---------|------|
| `generated/base_models.dart` | `Address`, `OrderStatus`, enums | Freezed — primary |
| `generated/order_models.dart` | `Order`, `OrderItem` | Freezed — primary |
| `generated/product_models.dart` | `Product`, `ShippingConfig` | Freezed — primary |
| `generated/user_models.dart` | `User`, `SellerProfile` | Freezed — primary |
| `models.dart` | `UserModel`, `CartItemModel`, `ProductModel`, `OrderModel`, `Address` | Manual non-Freezed models |
| `enum_extensions.dart` | Enum helpers | String↔enum conversion |

### Services — `lib/services/`
| File | Responsibility |
|------|----------------|
| `algolia_service.dart` | Algolia client configuration |
| `analytics_service.dart` | Analytics tracking |
| `conf_services.dart` | Service configuration |
| `session_timeout_service.dart` | Session management |
| `notification_service.dart` | Manages local and push notifications. |
| `splash_service.dart` | App splash/loading |
| `turnstile_service.dart` | Cloudflare Turnstile platform dispatcher (web/stub) |
| `turnstile_service_web.dart` | Web implementation via `dart:js_interop` → `window._getTurnstileToken()` |
| `turnstile_service_stub.dart` | Non-web no-op (mobile/desktop — App Check handles attestation) |

### Widgets — `lib/widgets/`
| File | Responsibility |
|------|----------------|
| `modern_button.dart` | Reusable button component |
| `modern_textfield.dart` | Reusable text input |
| `modern_card.dart` | Reusable card |
| `modern_appbar.dart` | App bar |
| `modern_product_card.dart` | Product card |
| `custom_app_bar.dart` | Custom app bar |
| `rating_dialog.dart` | Rating dialog |
| `animations.dart` | Shared animations |
| `legal_screen_body.dart` | Legal content display |

### Utils — `lib/utils/`
| File | Responsibility |
|------|----------------|
| `env_config.dart` | Environment singleton (emulator/production) |
| `design_tokens.dart` | Color tokens, gradients, theme |

---

## 🧪 E2E Tests — `e2e/playwright_ui/` (36 spec files)

| File | Coverage |
|------|----------|
| `stripe-payment.spec.ts` | Stripe hosted checkout |
| `buyer-flow.spec.ts` | Browse → cart → checkout → order |
| `seller-flow.spec.ts` | List product → ship → payout |
| `order-lifecycle.spec.ts` | Full order state machine |
| `order-cancellation-refund.spec.ts` | Cancel + return + refund |
| `shipping-approval.spec.ts` | Shipping cost approval |
| `shipping-calculation.spec.ts` | Province/distance/weight pricing |
| `checkout-validation.spec.ts` | Form validation + coupon codes |
| `payment-edge-cases.spec.ts` | Declined card, 3DS, timeout |
| `multi-seller-orders.spec.ts` | Cross-seller cart + auth checks |
| `add-product-e2e.spec.ts` | Add product + images + warehouse |
| `seller-product-management.spec.ts` | Edit/pause/archive products |
| `seller-registration.spec.ts` | Stripe Connect onboarding |
| `warehouse-multi-location.spec.ts` | Warehouse CRUD + default |
| `digital-product-e2e.spec.ts` | Buy digital + license + download |
| `premium-subscription.spec.ts` | Subscribe + paywall + cancel |
| `favorites.spec.ts` | Toggle + list favorites |
| `profile-management.spec.ts` | Profile + address CRUD |
| `search-products.spec.ts` | Algolia search + filters |
| `trending-products.spec.ts` | Trending section |
| `admin-actions.spec.ts` | Admin product/user actions |
| `admin-panel.spec.ts` | Admin panel tabs |
| `admin-security.spec.ts` | Role enforcement + access control |
| `edge-cases-security.spec.ts` | Self-purchase, price tamper, race |
| `rate-limiting.spec.ts` | Rate limit enforcement |
| `new-coverage-e2e.spec.ts` | Subscription + stock notifications |
| `smoke-home-profile.spec.ts` | App smoke: home + profile |
| `new-notification-features.spec.ts` | New notification features |
| `stock-notif.spec.ts` | Stock notification specific tests |
| `product-video-e2e.spec.ts` | Product video upload and display |
| `password-reset.spec.ts` | Password reset flow |
| `notifications.spec.ts` | General notifications functionality |
| `order-notifications.spec.ts` | Order-specific notifications |
| `return-request.spec.ts` | Return request flow |
| `api-coverage.spec.ts` | Headless API tests — 65+ uncovered Cloud Functions |
| `deep-ui-scenarios.spec.ts` | Deep browser E2E: buyer/seller/admin full journeys |

Shared helpers: `api-helpers.ts`, `flutter-helpers.ts`

Run: `cd e2e && npx playwright test --config=playwright.config.dev.ts --workers=2`  
Screenshots: auto-saved to `~/Desktop/origna-screenshots/dev/`

---

## 🗂️ origna_flows/ — AI Flow Context Bundles

Repo-level docs providing Flutter selector maps and user journey context for AI test generation.

| File | Content |
|------|---------|
| `origna_flows/SEMANTICS.md` | Flutter Key/label/role reference for every screen — use for Playwright selectors |
| `origna_flows/FLOWS.md` | 15 step-by-step user journeys with test assertions and QA checklist |
| `origna_flows/INSTRUCTIONS.md` | AI guide: environments, test accounts, selector rules, coverage gaps, patterns |

**Generate flow bundles for Claude.ai:**
```bash
python3 scripts/collect_flow_files.py
# → ~/Desktop/origna_flows/<flow_name>/  (62 flows)
```

| Flow type | Count | Purpose |
|-----------|-------|---------|
| Audit flows (`checkout_payment`, `security`, …) | 35 | Audit source code for bugs, security, schema sync |
| Test flows (`test_stripe_payment`, …) | 27 | Audit/extend E2E Playwright specs |

---

## 📜 Scripts — `scripts/`

| Script | Purpose |
|--------|---------|
| `collect_flow_files.py` | Bundle source + test files into flow folders for Claude.ai (62 flows, ≤20 files each) |
| `mega_seed_dev.py` | Seed orignagta-dev: 5 sellers, 30 products, 16 orders, returns, coupons, licenses |
| `deploy_with_validation.sh` | Full deploy with pre-checks |
| `deploy_rules.sh` | Deploy Firestore rules only |
| `validate_schema_consistency.sh` | Check Python↔Dart↔JSON schema sync |
| `generate_dart_models.sh` | Run build_runner for Freezed models |
| `run_all_tests.sh` | All test suites |
| `install_git_hooks.sh` | Install pre-push hooks |
| `start-emulators.sh` | Start Firebase emulators |
| `audit_orchestrator.py` | Orchestrates various audit tasks. |
| `audit_translations.py` | Audits translation files for consistency. |
| `audit-stripe-webhooks.sh` | Audits Stripe webhooks configuration. |
| `check_deploy_versions.py` | Checks and validates deployment versions. |
| `code_quality_agent.py` | Tool for enforcing code quality standards. |
| `collect_simplified_flows_35.py` | Collects simplified flow files (35 flows). |
| `create_stripe_webhooks.py` | Creates Stripe webhooks. |
| `delete_dev_products.py` | Deletes development products. |
| `deploy_functions.sh` | Deploys Cloud Functions. |
| `e2e-with-services.sh` | Runs E2E tests with necessary services. |
| `fix_stripe_webhooks.py` | Fixes Stripe webhooks configurations. |
| `fix-all-tests-comprehensive.sh` | Comprehensive script to fix all tests. |
| `fix-all-tests.sh` | Script to fix all tests. |
| `fix-backend-tests.sh` | Script to fix backend tests. |
| `fix-mocking-auto.py` | Automates fixing mocking in tests. |
| `generate_integration_dart_defines.py` | Generates Dart defines for integration tests. |
| `generate-symbol-map.sh` | Generates a symbol map of the codebase. |
| `optimize_secrets.py` | Optimizes secret management. |
| `orchestrate-agents.sh` | Orchestrates agent execution. |
| `post-edit-dart-lint.sh` | Post-edit linting for Dart files. |
| `post-edit-schema-check.sh` | Post-edit schema consistency checks. |
| `pre_push_validation.sh` | Runs validation before git push. |
| `pre_push.sh` | Git pre-push hook. |
| `pre-deploy-checks.sh` | Runs checks before deployment. |
| `quick-test.sh` | Runs a quick test suite. |
| `record_deploy_version.py` | Records the deployment version. |
| `run_flutter_integration_tests_web.sh` | Runs Flutter integration tests for web. |
| `run_flutter_integration_with_timeout.py` | Runs Flutter integration tests with a timeout. |
| `run-e2e-tests.sh` | Runs E2E tests. |
| `run-flutter-emulator.sh` | Runs Flutter emulator. |
| `run-human-tests.sh` | Runs human-assisted tests. |
| `run-integration-db-matrix.sh` | Runs integration tests across database matrix. |
| `run-integration-tests.sh` | Runs integration tests. |
| `run-playwright-e2e.sh` | Runs Playwright E2E tests. |
| `seed_dev_db.py` | Seeds the development database. |
| `seed_dev_firestore_admin_samples.py` | Seeds Firestore with admin samples for development. |
| `setup_algolia.sh` | Sets up Algolia. |
| `setup_secrets.py` | Sets up secrets. |
| `setup_test_seller.py` | Sets up a test seller. |
| `start-all-services.sh` | Starts all services. |
| `start-e2e-services.sh` | Starts services for E2E tests. |
| `start-stripe-webhooks.sh` | Starts Stripe webhooks. |
| `stop-e2e-services.sh` | Stops services for E2E tests. |
| `sync_dev_auth_passwords_from_defines.py` | Syncs development authentication passwords. |
| `sync_emulator_to_algolia.py` | Syncs emulator data to Algolia. |
| `sync_schema.py` | Synchronizes the schema. |
| `test_regression_envs.sh` | Tests regression environments. |
| `update_remote_config.py` | Updates remote configuration. |
| `upload_secrets.py` | Uploads secrets. |
| `validate_algolia_sync.py` | Validates Algolia synchronization. |
| `validate_api_endpoints.py` | Validates API endpoints. |
| `validate_indexes.py` | Validates database indexes. |
| `validate_no_magic_strings.py` | Validates against magic strings. |
| `validate_rules.py` | Validates database rules. |
| `validate_storage_rules.py` | Validates storage rules. |
| `verify_dev_data.py` | Verifies development data. |
| `verify_dev_integration_credentials.py` | Verifies development integration credentials. |
| `verify_functions_sync.py` | Verifies Cloud Functions synchronization. |
| `version_tracker.py` | Tracks repository versions. |
| `write_index_html.py` | Writes the index HTML file. |

### Utilities — `scripts/utilities/`
| Script | Purpose |
|--------|---------|
| `analyze_coverage.py` | Analyzes code coverage output. |
| `check_flutter_tests.py` | Checks Flutter tests validity. |
| `compare_fields.py` / `compare_rules.py` / `compare_schema.py` | Compares schema constants across stacks. |
| `get_collections.py` | Helper for extracting collection names. |
| `parse_dart.py` / `fix_parse.py` | Scripts for parsing/fixing Dart code. |
| `test_extraction.py` | Extracts tests for analysis. |
| `test_uri.dart` | Scratch script for URI testing. |
| `smart_audit.py`, `restore_validation.py`, etc. | Assorted codebase maintenance utilities. |

---

## 🔍 Audit System — `audit/`

| Directory | Contents |
|-----------|----------|
| `audit/hooks/` | Claude-powered composable audit hooks with auto-fix |
| `audit/collect_files.py` | Project file collector with extension/dir filters |
| `audit/doc_crawler.py` | External documentation crawler with disk cache |
| `audit/run_hooks.py` | CLI entrypoint for Claude audit hooks |

---

## 📄 Documentation — `docs/`

| File/Dir | Content |
|----------|---------|
| `database_schema.json` | Complete Firestore schema (1421 lines, v2.0.0) |
| `json_schemas/individual/*.json` | 18 individual collection schemas |
| `diagrams/*.puml` | 7 PlantUML diagrams (architecture, sequences, state) |
| `STRIPE_CONNECT_REFERENCE.md` | Stripe Connect integration guide |
| `SELLER_TERMS_AND_POLICIES.md` | Seller terms of service |
| `setup/*.md` | Setup guides (Algolia, Stripe, CI/CD, Airwallex) |
| `testing/*.md` | Testing documentation |
