# /audit-security - Run comprehensive security audit

**Usage**: `/audit-security [--fix]`

## What it does:
1. Scans for exposed secrets/API keys
2. Checks authentication/authorization
3. Validates input sanitization
4. Reviews webhook signatures
5. Checks for SQL injection (if applicable)
6. Validates CORS settings
7. Reviews rate limiting
8. Checks for XSS vulnerabilities

## Examples:
```
/audit-security
/audit-security --fix
```

## Security Checklist:
```yaml
critical:
  - Webhook signature verification (Stripe, Airwallex)
  - Environment variables not exposed
  - SQL injection prevention
  - XSS prevention (HTML sanitization)
  - CSRF protection
  
important:
  - Rate limiting on all endpoints
  - Input validation
  - Error message sanitization
  - Secure session management
  
nice_to_have:
  - Security headers (CSP, HSTS)
  - Dependency vulnerability scan
  - Penetration testing
```

## Auto-fixes (with --fix flag):
- ✅ Add missing signature verifications
- ✅ Sanitize user inputs
- ✅ Add rate limiting decorators
- ✅ Fix exposed secrets → environment variables
- ✅ Add CORS restrictions
