## LEGAL COMPLIANCE FINDINGS (CASL/PIPEDA/Quebec Law 25/Bill 96)

### HIGH
1. Terms acceptance at checkout does NOT capture version number — no audit trail (checkout_screen.dart:1465)
2. No re-consent flow when policy version changes — users never re-accept updated terms (terms_provider.dart:100)
3. Privacy policy missing required Quebec Law 25 sections (data retention, third-party sharing, cross-border transfers)

### MEDIUM
4. Marketing consent not visually separated from terms on signup — CASL requires clear distinction (login_screen.dart:230)
5. Physical address not visible at point of email consent collection — CASL requirement (signup screen)
6. Unsubscribe HMAC tokens generated but NO validation handler exists (email_service.py:369)
7. Data deletion does NOT remove Stripe customer data — PIPEDA right to erasure gap (admin.py:1559)
8. No cookie consent banner — Quebec Law 25 requires explicit consent for non-essential cookies

### LOW
9. Some email sends use hardcoded "en" instead of user preferredLanguage
10. Terms "Last updated" date hardcoded, not from actual version data
11. Privacy officer contact uses support@ instead of dedicated privacy@ address
12. GST/HST number not displayed in app footer

### VERIFIED COMPLIANT
- Marketing consent is explicit opt-in (not pre-checked)
- French fully supported (Bill 96)
- Unsubscribe links present in marketing emails
- Physical address in email footers
- Data export and deletion functions implemented
