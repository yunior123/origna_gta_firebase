---
name: canadian-law-compliance
description: Use when editing legal pages, email templates, checkout flows, or consent mechanisms — covers PIPEDA, CASL, Bill 96, Law 25, CDSA, and provincial compliance for OrignaGTA.
---

# Skill: Canadian Law Compliance

## Description
Complete Canadian law compliance reference for OrignaGTA e-commerce marketplace. Covers 12 federal and provincial laws. Load before editing any legal page, email template, checkout flow, privacy policy, or consent mechanism.

## When to Load
- Editing privacy policy or terms of service
- Working on email templates (CASL compliance)
- Modifying checkout or payment flows (tax display)
- Adding consent mechanisms or user preferences
- Working on French localization
- Modifying account deletion or data export
- Adding new data collection points
- Preparing for mobile app launch

---

## Quick Reference: 12 Applicable Laws

| Law | Area | Regulator | Key Requirement |
|-----|------|-----------|-----------------|
| PIPEDA | Privacy (federal) | OPC | 10 principles, breach notification, PIAs |
| Quebec Law 25 | Privacy (QC) | CAI | Privacy officer, granular consent, PIA mandatory |
| CASL | Anti-spam | CRTC | Consent + unsubscribe + physical address in all CEMs |
| Competition Act | Fair pricing | Competition Bureau | No drip pricing (taxes exempt) |
| Excise Tax Act | GST/HST | CRA | Registration number on all receipts |
| Ontario CPA | Consumer protection | MPBSD | Internet agreement requirements, 30-day delivery right |
| Quebec CPA | Consumer protection | OPC-QC | French language, 10-day cooling off |
| ACA | Accessibility (federal) | Standards Canada | Remove and prevent barriers |
| AODA | Accessibility (ON) | AODA Office | WCAG 2.1 AA for web |
| Charter of French Language | Language (QC) | OQLF | All consumer content in French |
| Official Languages Act | Language (federal) | Commissioner | Bilingual services |
| CCPSA | Product safety | Health Canada | No recalled/banned products |

---

## Critical Compliance Gaps (As of Feb 2026)

### 🔴 10 CRITICAL Issues

1. **GST/HST registration number missing** — Must display on checkout + emails + receipts
   - Files: `functions/services/email_service.py`, `origna_gta/lib/screens/checkout_screen.dart`
   - Add: `PLATFORM_GST_HST_NUMBER` in `functions/config.py`

2. **No physical address in emails** — CASL requires sender mailing address
   - Files: `functions/services/email_service.py` (all email templates)

3. **No unsubscribe mechanism** — CASL requires functional unsubscribe in all CEMs
   - Need: `List-Unsubscribe` header in Mailjet calls + unsubscribe link in templates
   - Need: `POST /unsubscribe` endpoint + email preferences screen

4. **No data breach notification plan** — PIPEDA mandatory since Nov 2018
   - Need: breach response plan doc, breach logging, notification templates

5. **No privacy officer designated** — Quebec Law 25 mandatory since Sept 2022
   - Need: publish name/title/contact on privacy policy page

6. **No cross-border data transfer disclosure** — Data goes to US (Firebase, Stripe, Algolia)
   - Fix: Add section to privacy policy about international transfers

7. **No consent tracking infrastructure** — CASL burden of proof
   - Schema fields needed: `emailConsent`, `consentTimestamp`, `consentMethod`, `marketingOptIn`
   - Files: `schema_constants.py`, `schema_constants.dart`, `database_schema.json`

8. **No French language support** — Quebec Charter + Bill 96
   - Need: Flutter i18n, French legal pages, French email templates
   - Fines: $3,000-$30,000 per violation

9. **Order confirmation emails not CPA-compliant** — Ontario Internet Agreement rules
   - Must include: supplier full name, itemized price, delivery date, cancellation rights

10. **No WCAG 2.1 AA audit** — ACA + AODA requirement
    - Semantics widgets exist but no formal audit done
    - Need: contrast check, keyboard nav, screen reader testing

---

## Tax Rates (Verified Correct — Feb 2026)

| Province | Tax Type | Rate | Status |
|----------|----------|------|--------|
| AB | GST | 5% | ✅ |
| BC | GST+PST | 5%+7% = 12% | ✅ |
| MB | GST+PST | 5%+7% = 12% | ✅ |
| NB | HST | 15% | ✅ |
| NL | HST | 15% | ✅ |
| NS | HST | 14% | ✅ (updated 2025) |
| NT | GST | 5% | ✅ |
| NU | GST | 5% | ✅ |
| ON | HST | 13% | ✅ |
| PE | HST | 15% | ✅ |
| QC | GST+QST | 5%+9.975% = 14.975% | ✅ |
| SK | GST+PST | 5%+6% = 11% | ✅ |
| YT | GST | 5% | ✅ |

Source: `functions/schema_constants.py` lines 824-838

---

## CASL Email Compliance Checklist

Every commercial electronic message (CEM) MUST have:
- [ ] Sender identification (OrignaGTA / Origna Ventures)
- [ ] Physical mailing address
- [ ] Contact info (email, phone, or web)
- [ ] Functional unsubscribe mechanism
- [ ] `List-Unsubscribe` header in Mailjet API call
- [ ] Consent obtained before sending (express or implied)
- [ ] Consent timestamp recorded

Transactional emails (order confirmations, shipping updates) are exempt but should still include address as best practice.

---

## Schema Fields to Add (Consent Tracking)

```python
# schema_constants.py
EMAIL_CONSENT = "emailConsent"
CONSENT_TIMESTAMP = "consentTimestamp"
CONSENT_METHOD = "consentMethod"      # "registration", "checkout", "settings"
MARKETING_OPT_IN = "marketingOptIn"   # boolean, default false
PRIVACY_OFFICER_NAME = "Yunior Rodriguez Osorio"
PRIVACY_OFFICER_EMAIL = "support@orignaventures.ca"  # Using support@ until dedicated privacy@ mailbox is provisioned
```

---

## Full Audit Document
See `docs/CANADIAN_LAW_COMPLIANCE_AUDIT.md` for the complete 29-item action plan with priorities and effort estimates.
