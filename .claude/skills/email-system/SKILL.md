---
name: email-system
description: Email configuration, templates, and trigger points for Mailjet-based notifications. Use when working on order notifications, auth emails, or email-related logic.
---

# Email System Reference

## Configuration
- **Sender:** support@orignaventures.ca
- **Provider:** Mailjet (real API, real sends)
- **Env var:** `FORCE_REAL_EMAIL=true` in `functions/.env` for real emails in emulator
- **File:** `functions/services/email_service.py` (~733 lines)

## APP_BASE_URL
```python
APP_BASE_URL = 'http://localhost:8888' if IS_EMULATOR else 'https://orignagta.ca'
```

## Email Functions
| Function | Trigger |
|----------|---------|
| `send_email()` | Core Mailjet send |
| `get_order_confirmation_email()` | Buyer order confirmation |
| `get_seller_notification_email()` | Seller new order notification |
| `send_payment_capture_failed_email()` | Capture failure alert |
| `send_3ds_authentication_email()` | 3DS authentication required |
| `send_authorization_expired_email()` | Authorization expired |

## Template Design System
- Gradient hero: #1F235A → #2F3B8F → #764BA2
- ORIGNA brand identity
- Order status tracker with progress bar
- Glassmorphism price summary
- Pill-shaped CTA buttons
- Responsive design
