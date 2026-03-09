# Origna GTA — Simplified 35 Flows for Audit

This document defines the 35 core flows of the Origna GTA application, mapped to their respective specialized audit agents.

| # | Flow Name | Primary Agent(s) | Key Files |
|---|-----------|------------------|-----------|
| 1 | Checkout & Payment | payment-auditor, security-auditor | payment_stripe.py, checkout_provider.dart |
| 2 | Order Lifecycle | order-lifecycle-auditor | orders.py, cron_jobs.py, orders_provider.dart |
| 3 | Product Lifecycle | product-lifecycle-auditor | products.py, algolia_service.py |
| 4 | Add Product | add-product-auditor | addproduct_screen.dart, add_product_viewmodel.dart |
| 5 | Auth & Onboarding | auth-onboarding-auditor | auth_provider.dart, login_screen.dart, admin.py |
| 6 | Email Notifications | email-notifications-auditor | email_service.py, email_tasks.py |
| 7 | Cron Jobs | cron-jobs-auditor | cron_jobs.py, orders.py |
| 8 | Search & Discovery | search-discovery-auditor | algolia_service.py, home_viewmodel.dart |
| 9 | Security | security-auditor | firestore.rules, storage.rules, rate_limiter.py |
| 10 | Schema Consistency | schema-sync-checker | database_schema.json, schema_constants.py/dart |
| 11 | Seller Profile & Warehouses | seller-warehouses-auditor | seller_profile.py, warehouses_viewmodel.dart |
| 12 | Subscription & Premium | premium-auditor | subscriptions.py, premium_paywall_widget.dart |
| 13 | Chat & Messaging | chat-messaging-auditor | chat.py, chat_provider.dart |
| 14 | Return Requests | return-requests-auditor | return_request.py, orders.py |
| 15 | Admin Panel | admin-panel-auditor | admin_panel_screen.dart, admin.py |
| 16 | Profile & Address | profile-address-auditor | users.py, address_viewmodel.dart |
| 17 | Notifications | notifications-auditor | notification_service.dart, notification_provider.dart |
| 18 | Digital Products | digital-products-auditor | digital.py, product_models.dart |
| 19 | Coupons & Discounts | coupons-discounts-auditor | coupons.py, cart_provider.dart |
| 20 | Product Q&A & Ratings | product-qa-ratings-auditor | product_rating_viewmodel.dart, qa_provider.dart |
| 21 | Favorites & Seller Products | favorite-auditor | favorites_screen.dart, seller_products_viewmodel.dart |
| 22 | App Bootstrap | app-bootstrap-auditor | main.dart, origna_app.dart, routes.dart |
| 23 | Legal & Compliance | legal-compliance-auditor | privacy_policy_screen.dart, terms_screen.dart |
| 24 | Design System | uiux-expert, design-system-auditor | design_tokens.dart, modern_button.dart |
| 25 | Stock Notifications | stock-notifications-auditor | stock_notification_provider.dart, products.py |
| 26 | Supplier Integration | supplier-integration-auditor | supplier_config.dart, products.py |
| 27 | Logic Audit | logic-auditor | payment_stripe.py, orders.py, checkout_provider.dart |
| 28 | Cross-Stack Audit | cross-stack-auditor | checkout_provider.dart, payment_stripe.py |
| 29 | Frontend Audit | frontend-auditor | checkout_provider.dart, products_provider.dart |
| 30 | Performance Audit | performance-auditor | algolia_service.py, firestore.indexes.json |
| 31 | Refactor Audit | refactor-auditor | admin.py, checkout_provider.dart |
| 32 | Cost Audit | cost-monitor | config.py, algolia_service.py, email_service.py |
| 33 | Code Comments Audit | code-comments-auditor | payment_stripe.py, orders.py, products.py |
| 34 | Legacy Code Audit | legacy-code-audit | addproduct_screen.dart, checkout_screen.dart |
| 35 | Rival Analysis | rival-agent | database_schema.json, home_screen.dart |
