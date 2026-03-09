# Origna GTA Operations Runbooks

> **Quick Reference for Production Incidents**
> 
> When in doubt: **Check logs → Assess impact → Execute playbook → Communicate**

## Runbook Index

| Incident Type | Severity | Runbook | Escalation |
|--------------|----------|---------|------------|
| Payment Stuck in Pending | P1 | [payment-stuck.md](./payment-stuck.md) | @senior-engineer |
| Stock Mismatch Investigation | P1 | [stock-mismatch.md](./stock-mismatch.md) | @senior-engineer |
| Stripe Webhook Failure | P1 | [webhook-failure.md](./webhook-failure.md) | @platform-lead |
| Seller Account Suspension | P2 | [seller-suspension.md](./seller-suspension.md) | @ops-team |
| Refund Manual Process | P2 | [manual-refund.md](./manual-refund.md) | @finance-team |
| Algolia Search Outage | P2 | [search-outage.md](./search-outage.md) | @platform-lead |
| Database Performance | P2 | [db-performance.md](./db-performance.md) | @senior-engineer |
| Circuit Breaker Triggered | P3 | [circuit-breaker.md](./circuit-breaker.md) | @on-call |

## Severity Definitions

- **P1 (Critical)**: Complete service disruption, financial impact, data loss risk
  - Response: Immediate (15 min)
  - Communication: Status page + stakeholder notification
  
- **P2 (High)**: Degraded service, workaround available
  - Response: 1 hour
  - Communication: Internal teams only
  
- **P3 (Medium)**: Minor impact, no immediate action required
  - Response: 4 hours
  - Communication: Ticket only

## Emergency Contacts

| Role | Primary | Secondary |
|------|---------|-----------|
| Platform Lead | platform-lead@origna.ca | +1-XXX-XXX-XXXX |
| Senior Engineer | senior-eng@origna.ca | +1-XXX-XXX-XXXX |
| Finance Team | finance@origna.ca | +1-XXX-XXX-XXXX |
| Stripe Support | support@stripe.com | - |
| Firebase Support | Cloud console | - |

## Useful Commands

```bash
# View recent Cloud Function logs
firebase functions:log --only payment_stripe

# Check Firestore usage
firebase firestore:databases:composite-config list

# View Stripe events
stripe events list --limit 10

# Check circuit breaker status
firebase functions:log --filter "CircuitBreaker"
```

## Infrastructure Access

- **Firebase Console**: https://console.firebase.google.com/project/orignagta
- **Stripe Dashboard**: https://dashboard.stripe.com/connect/accounts
- **Algolia Dashboard**: https://www.algolia.com/apps/[APP_ID]/explorer
- **Cloudflare R2**: https://dash.cloudflare.com/[ACCOUNT_ID]/r2

## Change Log

| Date | Runbook | Change | Author |
|------|---------|--------|--------|
| 2025-02-08 | All | Initial creation | Platform Team |
