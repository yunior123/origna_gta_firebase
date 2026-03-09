# 🇨🇦 Canadian Law Compliance Audit — OrignaGTA

**Date:** February 10, 2026  
**Platform:** E-commerce marketplace (Web + future Android/iOS)  
**Target market:** Canadian buyers, worldwide sellers  
**Governing law:** Ontario, Canada (per Terms of Service)

---

## Executive Summary

OrignaGTA has **strong foundations** in tax calculation, payment security, and basic privacy. However, **10 critical gaps** and **12 moderate gaps** were identified across 8 areas of Canadian law. This audit covers federal and provincial requirements.

| Area | Status | Critical | Moderate | Low |
|------|--------|----------|----------|-----|
| 1. Tax (GST/HST/PST) | ✅ Mostly compliant | 1 | 2 | 1 |
| 2. Privacy (PIPEDA) | ⚠️ Gaps | 2 | 3 | 1 |
| 3. Quebec Privacy (Law 25) | 🔴 Non-compliant | 2 | 1 | 0 |
| 4. Anti-Spam (CASL) | ⚠️ Gaps | 2 | 2 | 0 |
| 5. Consumer Protection (CPA/Competition Act) | ⚠️ Gaps | 1 | 2 | 1 |
| 6. Accessibility (ACA/AODA) | ⚠️ Partial | 1 | 1 | 1 |
| 7. French Language (OLA/Charter) | 🔴 Non-compliant | 1 | 1 | 0 |
| 8. Mobile App (PIPEDA + App Store) | ⚠️ Pre-launch | 0 | 0 | 3 |
| **TOTAL** | | **10** | **12** | **7** |

---

## 1. TAX COMPLIANCE (GST/HST/PST/QST)

### ✅ What's Already Compliant

- **Server-side tax calculation** — Taxes calculated in `create_checkout_session()`, not client-manipulable
- **Accurate provincial rates** — All 13 provinces/territories correctly configured in `schema_constants.py`
  - Nova Scotia updated to 14% HST ✅
  - Quebec GST 5% + QST 9.975% ✅
- **Category-based exemptions** — Children's clothing (ON, BC, MB, SK), Basic groceries (all provinces)
- **Stripe Tax integration** — B2B reverse charge via CRA-validated GST numbers
- **Tax on shipping** — Correctly taxes shipping costs per ARC requirements
- **Fallback security** — B2B exemption disabled when Stripe Tax API unavailable

### 🔴 CRITICAL — GST/HST Registration Number Missing

**Law:** Excise Tax Act, s. 223(1) — All GST/HST registrants MUST display their registration number on invoices/receipts.

**Current state:** No GST/HST registration number displayed anywhere — not on checkout, not in order confirmation emails, not in receipts.

**Fix required:**
- Add `GST/HST Registration Number: XXXXX XXXX RT0001` to:
  - Checkout screen order summary
  - Order confirmation emails (buyer + seller)
  - All receipt/invoice documents
- Store in `config.py` as `PLATFORM_GST_HST_NUMBER`

### ⚠️ MODERATE — "Plus applicable taxes" indication

**Law:** Competition Act (Bill C-56, June 2024) — While government taxes are exempt from the drip pricing ban, CRA and Competition Bureau **recommend** clear disclosure.

**Current state:** Product cards and detail pages show `$XX.XX` with zero indication that taxes apply.

**Fix recommended:**
- Add `"+ applicable taxes"` or `"avant taxes"` label beneath prices on product cards, product detail screen, and cart screen
- Alt: Show estimated tax range based on visitor's province (if known)

### ⚠️ MODERATE — Email receipts missing tax breakdown

**Current state:** Order confirmation emails (`email_service.py`) should be verified to include full tax breakdown with province, rate, and registration number.

### ℹ️ LOW — Consider showing tax estimate in cart

Currently taxes only appear at checkout. Showing an estimate earlier improves trust and reduces cart abandonment.

---

## 2. PRIVACY (PIPEDA — Federal)

**Law:** Personal Information Protection and Electronic Documents Act (PIPEDA)

### ✅ What's Already Compliant

- **Privacy Policy exists** — Detailed 16-section policy in `privacy_policy_screen.dart`
- **Consent at checkout** — Terms acceptance checkbox required before purchase
- **Data minimization** — Only necessary data collected
- **Google API compliance** — Limited Use requirements followed
- **Data security** — TLS, Firebase Security Rules, no full card storage
- **Right to access** stated in policy
- **Right to deletion** — `delete_account` endpoint exists, E2E tested
- **Data retention** — 7-year order retention documented (tax law compliance)
- **Children's privacy** — Under 16 statement in policy
- **Third-party disclosures** — All data processors listed (Stripe, Firebase, Algolia, Mailjet)

### 🔴 CRITICAL — No Data Breach Notification Process

**Law:** PIPEDA Part 1, Division 1.1 (mandatory since Nov 2018) — Organizations MUST:
1. Report breaches of security safeguards to the Privacy Commissioner
2. Notify affected individuals
3. Keep records of all breaches for 24 months

**Current state:** No breach notification process, no incident response plan for privacy breaches, no breach record-keeping system.

**Fix required:**
- Create a Data Breach Response Plan document
- Implement breach logging in Firestore (`privacy_breaches` collection)
- Create template notification letters (to Commissioner + affected users)
- Add breach assessment criteria (real risk of significant harm test)
- Set up 72-hour notification timeline procedure

### 🔴 CRITICAL — No Privacy Impact Assessment (PIA)

**Law:** PIPEDA Principle 1 (Accountability) + OPC Guidance — PIAs recommended for new systems handling personal information at scale.

**Current state:** No documented PIA exists.

**Fix required:**
- Conduct and document a PIA before launch covering:
  - Data flows (buyer → platform → seller → payment)
  - Cross-border data transfers (Firebase US servers, Stripe, Algolia)
  - Third-party processor agreements
  - Risk assessment and mitigations

### ⚠️ MODERATE — Account Deletion Timeline

**Current state:** Privacy policy promises deletion "within 30 days." The `delete_account` endpoint exists but:
- No automated 30-day deadline enforcement
- No confirmation email sent after deletion
- No audit trail of deletion requests

### ⚠️ MODERATE — Data Portability Not Implemented

**Current state:** Privacy policy promises "Data portability — request a copy of your data in a portable format" but no endpoint or mechanism exists to export user data.

**Fix required:**
- Create `export_my_data` endpoint returning JSON with user profile, orders, addresses
- Add "Download My Data" button in settings/account screen

### ⚠️ MODERATE — Cross-Border Data Transfer Disclosure

**Current state:** Data is stored on Firebase (Google Cloud — US servers), processed by Stripe (US), searched by Algolia (US/EU). Privacy policy doesn't explicitly disclose that data leaves Canada.

**Fix required:**
- Add section to privacy policy: "Your data may be stored and processed in the United States and other countries. By using our platform, you consent to the transfer of your information to countries outside Canada."

### ℹ️ LOW — Cookie Policy Specificity

Privacy policy section 13 mentions cookies but doesn't specify which cookies are used, their purpose, or duration. Consider expanding.

---

## 3. QUEBEC PRIVACY (Law 25 / Loi 25)

**Law:** An Act respecting the protection of personal information in the private sector (as amended by Bill 64/Law 25) — Fully in force since September 2024.

**Applies:** To ANY business collecting personal information of Quebec residents, regardless of where the business is based.

### 🔴 CRITICAL — No Privacy Officer Designated

**Law 25 Requirement (effective Sept 2022):** Every organization must designate a person responsible for the protection of personal information and publish their title and contact information on the website.

**Current state:** No privacy officer designated or published on the website.

**Fix required:**
- Designate a privacy officer (can be the founder)
- Publish name, title, contact info on the privacy policy page
- File with the Commission d'accès à l'information (CAI) if required

### 🔴 CRITICAL — No Consent Management for Quebec Users

**Law 25 Requirements (effective Sept 2023-2024):**
1. **Granular consent** — Must obtain separate consent for each purpose of data collection
2. **Privacy policy must state:**
   - Types of personal information collected
   - Purposes of collection ✅ (already done)
   - Rights of individuals ✅ (already done)
   - **Name and contact of privacy officer** ❌
   - **Whether data is transferred outside Quebec** ❌
   - **Right to withdraw consent** — must be as easy as giving it ❌
3. **Consent withdrawal mechanism** — Must be clearly available
4. **Anonymization/de-identification** — Must be used when purpose is fulfilled

**Fix required:**
- Add privacy officer info to privacy policy
- Add explicit consent granularity (separate toggles for: account management, order processing, analytics, communications)
- Add "Where your data is stored" section disclosing US/international transfers
- Implement easy consent withdrawal mechanism in settings

### ⚠️ MODERATE — No Privacy Impact Assessment (Évaluation des facteurs relatifs à la vie privée)

**Law 25 (effective Sept 2023):** Mandatory PIA for any project involving personal information. Overlaps with PIPEDA PIA requirement above.

---

## 4. ANTI-SPAM (CASL — Canada's Anti-Spam Legislation)

**Law:** An Act to promote the efficiency and adaptability of the Canadian economy (S.C. 2010, c. 23)

### ✅ What's Already Compliant

- **All current emails are transactional** — Order confirmations, shipping updates, payment alerts are CASL-exempt
- **No marketing emails sent currently** — No CEMs (Commercial Electronic Messages) being sent

### 🔴 CRITICAL — Missing Physical Address in Emails

**CASL s. 6(2)(b):** Every CEM must include the sender's name, mailing address, and either telephone, email, or web address. Even transactional emails should include this as best practice.

**Current state:** Email templates in `email_service.py` contain no physical mailing address of OrignaGTA.

**Fix required:**
- Add to every email footer:
  ```
  OrignaGTA / Origna Ventures
  [Physical address]
  [City, Province, Postal Code]
  support@orignaventures.ca | orignaventures.ca
  ```

### 🔴 CRITICAL — No Unsubscribe Mechanism

**CASL s. 6(2)(c):** Every CEM must contain a functional unsubscribe mechanism. Unsubscribe requests must be processed within 10 business days.

**Current state:** No unsubscribe link in any email. No backend endpoint for unsubscribe. No user preference management.

**CASL fine:** Up to $10M per violation (organization).

**Fix required (before any marketing emails are sent):**
- Add `List-Unsubscribe` header to all Mailjet API calls
- Add unsubscribe link in email footer
- Create `POST /unsubscribe` endpoint
- Create email preferences screen in Flutter app
- Track consent timestamps in user document

### ⚠️ MODERATE — No Consent Tracking Infrastructure

**CASL s. 10(1):** The person alleging consent has the burden of proving it. You must keep records of: when consent was given, how, and what was consented to.

**Current state:** No `emailConsent`, `consentTimestamp`, or `consentMethod` fields in user schema.

**Fix required:**
- Add to `schema_constants.py` and `schema_constants.dart`:
  ```python
  EMAIL_CONSENT = "emailConsent"
  CONSENT_TIMESTAMP = "consentTimestamp"
  CONSENT_METHOD = "consentMethod"  # "registration", "checkout", "settings"
  MARKETING_OPT_IN = "marketingOptIn"
  ```

### ⚠️ MODERATE — Privacy Policy Promises Opt-Out Without Implementation

**Current state:** Section 10 of privacy policy states users can "Opt out of marketing communications at any time" but no mechanism exists.

---

## 5. CONSUMER PROTECTION

### Ontario Consumer Protection Act (CPA, 2002)

### ✅ What's Already Compliant

- **Clear pricing in CAD** ✅
- **Return policy** — 14-day return window stated in Terms of Service ✅
- **Delivery timeline** — Estimated delivery dates shown ✅
- **Contract disclosure** — Terms accepted before purchase ✅
- **Refund processing** — 3-5 business days stated ✅

### 🔴 CRITICAL — Ontario Internet Agreement Requirements

**CPA Part III, s. 38-40 (Internet Agreements):** For remote/internet purchases over $50:
1. Must provide **contract** with: supplier name, description of goods, itemized price, delivery date, cancellation rights
2. Must provide a **copy of the agreement** (emailed or downloadable)
3. Buyer has right to cancel within **7 days** if no proper copy received
4. Buyer can cancel if delivery not made within **30 days of promised date**

**Current state:**
- Order confirmation emails exist ✅
- But: No formal "copy of agreement" with all CPA-required elements
- No explicit reference to 30-day delivery cancellation right

**Fix required:**
- Ensure order confirmation email includes ALL CPA-required elements:
  - Full legal name of OrignaGTA / Origna Ventures
  - Complete description of purchased items
  - Itemized price breakdown (subtotal, tax, shipping)
  - Expected delivery date or range
  - Cancellation and return rights
  - Contact information for customer service
- Add cancellation right notice: "If your order is not delivered within 30 days of the estimated delivery date, you may cancel and receive a full refund."

### ⚠️ MODERATE — Competition Act (Drip Pricing)

**Bill C-56 (June 2024):** Prohibits non-optional charges being added at checkout that weren't in the advertised price. Government taxes are **exempted**, but all platform fees must be included.

**Current state:** Platform fee (2.5%) is charged to sellers, not buyers ✅. However, shipping costs are only revealed at checkout for some delivery options.

**Recommendation:** Indicate shipping cost ranges on product pages: "Shipping from $1.99"

### ⚠️ MODERATE — Product Safety / Prohibited Products

**Canada Consumer Product Safety Act (CCPSA):** Marketplace must not facilitate sale of recalled or banned products.

**Current state:** No integration with Health Canada recall database. Relies solely on seller honesty and prohibited items list in Terms.

**Recommendation:**
- Add product category restrictions for regulated goods
- Consider Health Canada recall API integration (future)
- Add "Report unsafe product" button on product pages

### ℹ️ LOW — Price History for Sales

**Competition Act s. 74.01:** "Regular price" claims require the product to have been sold at that price for a substantial period. No "original price / sale price" comparison feature currently exists, but if added, must comply.

---

## 6. ACCESSIBILITY

### Accessible Canada Act (ACA, 2019) + AODA (Ontario)

### ✅ What's Already Compliant

- **Semantic tree enabled** — `SemanticsBinding.instance.ensureSemantics()` in `main.dart` ✅
- **Semantics widgets** — Used in key components (product cards, buttons, appbar, etc.) ✅
- **WCAG awareness** — Documented in `.claude/skills/accessibility-matrix/SKILL.md` and `.claude/agents/uiux-expert.md`

### 🔴 CRITICAL — No WCAG 2.1 AA Audit Completed

**ACA (federal):** Requires organizations to identify, remove, and prevent barriers for people with disabilities.
**AODA (Ontario):** By 2025, all public-facing websites must meet WCAG 2.1 Level AA.

**Current state:** Semantic widgets are used but no formal WCAG audit has been performed. Missing:
- Contrast ratio verification across all screens
- Keyboard navigation testing
- Screen reader testing (VoiceOver/TalkBack)
- Focus order validation
- Alt text for all images
- Error identification for form fields

**Fix required:**
- Run `flutter test --accessibility` or manual audit
- Test with VoiceOver (iOS/macOS) and TalkBack (Android)
- Verify contrast ratios against WCAG 2.1 AA (4.5:1 text, 3:1 large text)
- Add `Semantics(label: ...)` to ALL interactive elements without text labels
- Ensure all form errors are announced to screen readers

### ⚠️ MODERATE — Mobile App Accessibility

**AODA IASR s. 14:** All new internet websites and web content must conform to WCAG 2.0 Level AA (since 2021). Mobile apps should also comply as best practice.

**Recommendation:** Include accessibility testing in the CI/CD pipeline.

### ℹ️ LOW — Accessibility Statement Missing

**Best practice:** Have a public accessibility statement page describing commitment, known limitations, and contact for accessibility issues.

---

## 7. FRENCH LANGUAGE REQUIREMENTS

### Official Languages Act + Quebec Charter of the French Language

### 🔴 CRITICAL — No French Language Support

**Quebec Charter of the French Language (as amended by Bill 96, June 2022):**
- Consumer products and services offered to Quebec residents MUST be available in French
- Websites selling to Quebec consumers must have French content available
- Terms of use, product descriptions, receipts — all must be in French for Quebec users
- **Fines: $3,000–$30,000 per violation**

**Federal Official Languages Act:**
- Federally regulated businesses must provide services in both official languages
- While a marketplace may not be federally regulated, serving Quebec buyers triggers Charter obligations

**Current state:** 
- Entire app/website is English-only
- No French translations for: Privacy Policy, Terms of Service, product categories, checkout flow, emails
- Cart locale is hardcoded to `en_CA`

**Fix required (before serving Quebec customers):**
- Implement Flutter internationalization (`flutter_localizations` + `intl`)
- Translate all legal pages (Terms, Privacy, Return Policy)
- Provide French email templates
- Allow sellers to provide French product descriptions (or auto-translate)
- Add language switcher (EN/FR)
- At minimum: all legally required documents in French

### ⚠️ MODERATE — Quebec-Specific Consumer Protection

**Quebec Consumer Protection Act (Loi sur la protection du consommateur):**
- Specific rules about merchant obligations
- 10-day cooling off for door-to-door and certain online agreements
- Contract in French must be offered if requested

---

## 8. MOBILE APP SPECIFICS (Future iOS/Android)

### ℹ️ LOW — App Store Privacy Labels

**Apple App Store / Google Play:** Require privacy "nutrition labels" disclosing data collection.

**Action:** Prepare App Store Privacy details:
- Data collected: Name, email, address, payment info, purchase history, usage data
- Data linked to identity: Yes (account required for purchasing)
- Data used for tracking: No (no ad tracking)

### ℹ️ LOW — App Tracking Transparency (iOS)

**Apple ATT Framework:** Must request permission before tracking. Since OrignaGTA doesn't use advertising trackers, this is likely not required. But verify that Firebase Analytics SDK doesn't trigger ATT requirement.

### ℹ️ LOW — Push Notification Consent

**CASL + App Store requirements:** Users must opt in to push notifications. iOS handles this natively, but ensure marketing pushes are separate from transactional.

---

## PRIORITY ACTION PLAN

### 🔴 Phase 1 — CRITICAL (Before Launch, March 2026)

| # | Action | Law | Effort | Impact |
|---|--------|-----|--------|--------|
| 1 | Add GST/HST registration number to checkout + emails | Excise Tax Act | Low | Legal requirement |
| 2 | Add physical address to all email templates | CASL | Low | $10M fine risk |
| 3 | Add unsubscribe mechanism + List-Unsubscribe header | CASL | Medium | $10M fine risk |
| 4 | Create Data Breach Notification Plan | PIPEDA | Medium | Mandatory since 2018 |
| 5 | Designate Privacy Officer + publish on website | Quebec Law 25 | Low | Mandatory since 2022 |
| 6 | Add cross-border data transfer disclosure to privacy policy | PIPEDA + Law 25 | Low | Legal requirement |
| 7 | Implement consent tracking schema fields | CASL + Law 25 | Medium | Burden of proof |
| 8 | French language support for legal pages | Quebec Charter / Bill 96 | High | $3K-$30K fine/violation |
| 9 | CPA-compliant order confirmation emails | Ontario CPA | Medium | Cancellation right |
| 10 | WCAG 2.1 AA accessibility audit | ACA + AODA | High | Legal requirement |

### ⚠️ Phase 2 — MODERATE (Within 3 months post-launch)

| # | Action | Law | Effort |
|---|--------|-----|--------|
| 11 | Conduct Privacy Impact Assessment | PIPEDA + Law 25 | Medium |
| 12 | Implement data portability (export user data) | PIPEDA | Medium |
| 13 | Add "plus applicable taxes" to product prices | Competition Bureau guidance | Low |
| 14 | Add email preferences screen in app | CASL | Medium |
| 15 | Add account deletion confirmation + audit trail | PIPEDA | Low |
| 16 | Add tax breakdown to order confirmation emails | Excise Tax Act | Medium |
| 17 | Add product safety reporting mechanism | CCPSA | Low |
| 18 | Add 30-day delivery cancellation right notice | Ontario CPA | Low |
| 19 | Quebec-specific consumer protection compliance | QC CPA | Medium |
| 20 | Cookie policy expansion with specifics | PIPEDA | Low |
| 21 | Accessibility statement page | ACA/AODA best practice | Low |
| 22 | Full French localization of app | Quebec Charter | High |

### ℹ️ Phase 3 — LOW (Before mobile app launch)

| # | Action | Law |
|---|--------|-----|
| 23 | Prepare App Store privacy nutrition labels | Apple/Google policy |
| 24 | Verify ATT framework not required | Apple policy |
| 25 | Separate transactional vs marketing push notifications | CASL |
| 26 | Show shipping estimates on product pages | Competition Bureau |
| 27 | Add tax estimate in cart screen | UX best practice |
| 28 | Health Canada recall database integration | CCPSA |
| 29 | Price history tracking for "sale" claims | Competition Act |

---

## REFERENCE: Canadian Laws Applicable

| Law | Jurisdiction | Regulator | Status |
|-----|-------------|-----------|--------|
| PIPEDA | Federal | Privacy Commissioner (OPC) | Active |
| Quebec Law 25 (Loi 25) | Quebec | Commission d'accès à l'information (CAI) | Fully in force Sept 2024 |
| CASL | Federal | CRTC + Competition Bureau + OPC | Active since 2014 |
| Competition Act | Federal | Competition Bureau | Amended June 2024 (Bill C-56) |
| Excise Tax Act (GST/HST) | Federal | CRA | Active |
| Consumer Protection Act | Ontario | Ministry of Public and Business Service | Active |
| Quebec CPA | Quebec | Office de la protection du consommateur | Active |
| Accessible Canada Act | Federal | Standards Canada | Active since 2019 |
| AODA | Ontario | AODA compliance office | Active since 2005 |
| Charter of the French Language | Quebec | OQLF | Amended by Bill 96, 2022 |
| Official Languages Act | Federal | Commissioner of Official Languages | Active |
| CCPSA (Product Safety) | Federal | Health Canada | Active |

---

*This audit is for informational purposes. Consult a Canadian e-commerce lawyer before launch to validate all findings. Recommend legal review by a firm specializing in Canadian privacy law (e.g., any firm listed on the OPC's website).*

*Last updated: February 10, 2026*
