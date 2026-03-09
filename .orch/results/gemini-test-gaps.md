## GEMINI: TEST COVERAGE GAPS (Top 20)

### CRITICAL E2E Gaps
1. Dispute Resolution E2E — buyer/seller/admin arbitration flow
2. Seller Payouts/Withdrawals E2E — earnings, bank account management
3. 2FA E2E — setup, login, recovery

### HIGH E2E Gaps
4. Chat Functionality E2E — buyer-seller messaging, read receipts
5. Product Reviews/Ratings E2E — submit, view, seller respond
6. Coupon Application E2E — percentage/fixed, expired/invalid codes
7. Address Management E2E — add/edit/delete/default address
8. Subscription Upgrade/Downgrade/Cancel E2E — beyond purchase flow

### CRITICAL Backend Test Gaps
9. Dispute Resolution backend logic — financial adjustments, refunds
10. Seller Payout security/fraud — unauthorized withdrawal prevention
11. User Data Deletion/Privacy — PIPEDA compliance, cross-service cleanup
12. Subscription recurring billing/proration — recurring events, plan changes
13. Real-time Inventory Management — concurrent purchase over-sell prevention

### HIGH Backend Test Gaps
14. Chat API security — message tampering, unauthorized chat access
15. Coupon abuse prevention — race conditions, double-spending
16. Cron Job idempotency/failure recovery
17. Admin RBAC enforcement — all admin endpoints tested
18. Admin Config propagation — config changes affect UI correctly
