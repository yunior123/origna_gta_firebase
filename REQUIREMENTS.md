# OrignaGta — Project Requirements & Future-Proof Roadmap

## 🎯 SCOPED FEATURES (v1.0 — March 2026)

### Buyers
- [x] Sign-up/Login with Email & Google (Quebec Law 25 compliant).
- [ ] Sign-up/Login with Apple (App Store compliance).
- [x] Product Discovery: Algolia search, category filtering.
- [x] Cart Management: Multi-seller support, real-time totals.
- [x] Checkout: Stripe Connect, Canadian Tax (GST/HST/QST), Bilingual support.
- [x] Order Tracking: Real-time status, push notifications.
- [x] Returns: Automated requests, seller approval workflow.
- [x] Chat: Direct buyer-seller messaging (plain text).
- [x] Ratings & Reviews: Product feedback, helpful votes.
- [x] Digital Products: Direct download, license key activation.

### Sellers
- [x] Onboarding: Stripe Connect Express.
- [x] Inventory: Multi-warehouse stock tracking, variant support.
- [x] Fulfillment: Order status management, tracking number submission.
- [x] Payments: Automatic payouts on shipment/delivery.
- [x] Dashboard: Sales metrics, active orders, product performance.

### Admins
- [x] Product Approval: Review queue for all new listings.
- [x] Dispute Mediation: Manual intervention for buyer/seller conflicts.
- [x] User Management: Roles (Buyer, Seller, Admin), status (Active, Paused, Suspended).

---

## 🔮 FUTURE-PROOF ROADMAP (v2.0+)

### [F-43] Agentic Commerce (UCP)
Implement machine-readable discovery endpoints (`/.well-known/commerce-agent.json`) for Gemini/Rufus integration.
- **Priority:** P0 (2026 standard).

### [F-45] Biometric Authentication
Integrate Passkeys/WebAuthn for high-value checkouts (>$100 CAD).
- **Priority:** P0 (Fraud prevention).





### [F-35] Machine-Readable Catalog
Ensure all products have `ucpMetadata` for external AI agent scraping and availability checks.
- **Priority:** P1 (Agentic search).

---

## 📐 ARCHITECTURAL QUALITY GATES
1. **Idempotency Verification:** Every financial function MUST have an idempotency test.
2. **Adversarial Audit:** Every new PR must pass an adversarial logic audit (malicious seller/buyer scenarios).
3. **Cross-Stack Sync:** No feature is "done" until Dart, Python, and JSON schemas are in sync.
4. **Bilingual Lock:** UI strings must have EN/FR translations before merging.
5. **Canada-Only:** Geographic boundaries enforced at the infrastructure level for buyers.
