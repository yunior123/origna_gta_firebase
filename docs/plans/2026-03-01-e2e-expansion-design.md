# E2E Test Expansion Design — 2026-03-01

## Problem
34% callable API coverage (33/98 functions). Solo developer relies entirely on automated tests as QA team. No gaps allowed.

## Solution
1. **api-coverage.spec.ts** — 58+ headless API tests covering all 65 uncovered Cloud Functions
2. **deep-ui-scenarios.spec.ts** — 14+ browser E2E tests for critical user journeys
3. **Audit pass** — Deepen all 34 existing spec files (verify DB state, not just HTTP 200)
4. **Docs** — Update REPO_MAP.md, create e2e/README.md

## Principles
- Every mutation test MUST verify Firestore state after the call (readDoc + assert)
- Every permission test MUST verify unauthorized callers get rejected
- Tests run against dev Firebase (never emulators — 8GB RAM constraint)
- Use existing api-helpers.ts utilities — never duplicate

## API Coverage Suites (api-coverage.spec.ts)
| Suite | Functions | Tests |
|-------|-----------|-------|
| A. User Profile | get/update/create_user_profile, update_email_consent | 5 |
| B. Address CRUD | add/update/delete/set_default_buyer_address | 6 |
| C. Product Queries | get_products_paginated, get_seller_products_paginated, get_product_ratings_paginated | 4 |
| D. Product Q&A | ask/answer/get_product_questions | 5 |
| E. Reviews | answer_review, vote_review_helpful, admin_delete_review, admin_flag_review | 5 |
| F. Admin Ops | update_user_roles, suspend/unsuspend_seller, admin_approve/reject_product | 6 |
| G. Admin MFA | admin_mfa_verify, admin_mfa_verify_backup, admin_mfa_disable | 3 |
| H. Coupons | apply_coupon, admin_create_coupon | 4 |
| I. Warehouse Ops | update_warehouse, delete_warehouse | 3 |
| J. Payment | verify_cart_prices, capture_payment, get_payment_providers | 4 |
| K. Chat | mark_messages_read, delete_message | 3 |
| L. GDPR/Account | delete_account, export_my_data, unsubscribe_email | 4 |
| M. Shipping | calculate_shipping_cost | 3 |
| N. Digital Licenses | verify_license, e2e_seed_license | 3 |

## Browser E2E Suites (deep-ui-scenarios.spec.ts)
| Suite | Scenario | Tests |
|-------|----------|-------|
| A. Full buyer journey | Browse → search → cart → checkout → tracking | 3 |
| B. Seller lifecycle | Create → edit → deactivate → reactivate | 3 |
| C. Multi-address | Add addresses → select non-default → checkout | 2 |
| D. Coupon flow | Apply → verify discount → checkout | 2 |
| E. Q&A UI | Ask → seller answers → verify display | 2 |
| F. Return request | Delivered → request return → admin approves | 2 |

## Existing Test Improvements
- add-product-e2e: verify product actually in Firestore after creation
- admin-actions: add refund_order_item, admin_refund_order coverage
- admin-security: role escalation attempts
- order-cancellation-refund: reject_return_request
- warehouse: update_warehouse, delete_warehouse
