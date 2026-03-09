# Stripe Webhook Listener Setup for Firebase Emulator

## Overview
This guide shows how to use `stripe listen --forward` to properly handle Stripe webhooks during local development and testing with the Firebase emulator.

## Prerequisites
- Stripe CLI installed (`brew install stripe/stripe-cli/stripe` on macOS)
- Stripe account with test keys
- Firebase Emulator running locally

## Setup Steps

### 1. Install Stripe CLI
```bash
# macOS
brew install stripe/stripe-cli/stripe

# Verify installation
stripe version
```

### 2. Login to Stripe
```bash
stripe login

# This will open a browser window - authorize and get a restricted API key
# Copy the restricted key for use in the emulator
```

### 3. Configure Environment Variables
Create `.env` with Stripe webhook secrets:
```bash
# .env (do not commit to repo)
STRIPE_WEBHOOK_SECRET=whsec_test_xxxxxxxxxxxx
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxx
```

### 4. Start Webhook Listener
```bash
# Listen on local port 3000 (or your function port)
stripe listen --forward-to localhost:3000/webhook

# Output:
# Ready! Your webhook signing secret is whsec_test_xxxx
# Forwarding to http://localhost:3000/webhook
# Events ready for testing...
```

### 5. Configure Firebase Function Handler
Update your webhook handler to accept Stripe events:

```python
# handlers/payment_stripe.py

import stripe
from firebase_functions import https_fn

STRIPE_WEBHOOK_SECRET = os.getenv('STRIPE_WEBHOOK_SECRET')

@https_fn.on_request()
def stripe_webhook_handler(req: https_fn.Request) -> https_fn.Response:
    """Handle Stripe webhook events"""
    
    # Get signature from header
    sig_header = req.headers.get('Stripe-Signature')
    event = None
    
    try:
        # Verify webhook signature
        event = stripe.Webhook.construct_event(
            req.data, sig_header, STRIPE_WEBHOOK_SECRET
        )
    except ValueError:
        return https_fn.Response("Invalid payload", status_code=400)
    except stripe.error.SignatureVerificationError:
        return https_fn.Response("Invalid signature", status_code=400)
    
    # Handle event types
    event_type = event['type']
    
    if event_type == 'charge.captured':
        handle_charge_captured(event['data']['object'])
    elif event_type == 'charge.refunded':
        handle_charge_refunded(event['data']['object'])
    elif event_type == 'payment_intent.succeeded':
        handle_payment_intent_succeeded(event['data']['object'])
    elif event_type == 'charge.dispute.created':
        handle_dispute_created(event['data']['object'])
    
    return https_fn.Response(json.dumps({'success': True}))
```

### 6. Test Webhook Events During Development

#### Test Payment Succeeded Event
```bash
stripe trigger charge.succeeded --forward-to localhost:3000/webhook
```

#### Test Charge Captured Event
```bash
stripe trigger charge.captured --forward-to localhost:3000/webhook
```

#### Test Refund Event
```bash
stripe trigger charge.refunded --forward-to localhost:3000/webhook
```

#### Test Dispute Created Event
```bash
stripe trigger charge.dispute.created --forward-to localhost:3000/webhook
```

### 7. Full Development Workflow

```bash
# Terminal 1: Start Firebase Emulator
cd /Users/yuniorrodriguezosorio/Documents/GitHub/origna_gta
firebase emulators:start --only functions,firestore

# Terminal 2: Start Stripe Webhook Listener
stripe listen --forward-to localhost:5001/webhook

# Terminal 3: Run tests
cd /Users/yuniorrodriguezosorio/Documents/GitHub/origna_gta/functions
python3 -m pytest tests/test_handlers_payment_stripe.py -v

# Terminal 4: Manually trigger events
stripe trigger charge.captured --forward-to localhost:5001/webhook
```

## Configuration for Different Environments

### Local Development
```bash
FUNCTIONS_EMULATOR=true
STRIPE_WEBHOOK_ENDPOINT=http://localhost:5001/webhook
STRIPE_WEBHOOK_SECRET=whsec_test_local_xxxxxxxx
```

### Testing (Emulator)
```bash
TESTING=true
FUNCTIONS_EMULATOR=true
STRIPE_WEBHOOK_SECRET=whsec_test_emulator_xxxxxxxx
```

### Staging
```bash
STRIPE_WEBHOOK_SECRET=$(gcloud secrets versions access latest --secret="stripe_webhook_secret_staging")
STRIPE_WEBHOOK_ENDPOINT=https://staging.origna.ca/webhook
```

### Production
```bash
STRIPE_WEBHOOK_SECRET=$(gcloud secrets versions access latest --secret="stripe_webhook_secret_prod")
STRIPE_WEBHOOK_ENDPOINT=https://origna.ca/webhook
```

## Webhook Events in Test Suite

### Mocking Webhook Events in Tests
```python
# tests/test_handlers_payment_stripe.py

@patch('handlers.payment_stripe.stripe.Webhook.construct_event')
def test_webhook_charge_captured(self, mock_construct_event):
    """Test charge.captured webhook event"""
    from handlers.payment_stripe import stripe_webhook_handler
    
    # Mock the webhook event
    mock_construct_event.return_value = {
        'type': 'charge.captured',
        'data': {
            'object': {
                'id': 'ch_test_123',
                'amount': 5000,
                'currency': 'cad',
                'metadata': {'orderId': 'order_123'}
            }
        }
    }
    
    # Create mock request
    mock_request = Mock()
    mock_request.headers = {'Stripe-Signature': 'test_signature'}
    mock_request.data = json.dumps({'event': 'charge.captured'})
    
    result = stripe_webhook_handler(mock_request)
    
    assert result.status_code == 200
```

## Troubleshooting

### Webhook Not Forwarding
```bash
# Check listener status
stripe status

# Restart listener with verbose output
stripe listen --forward-to localhost:5001/webhook --print-json
```

### Signature Verification Failed
```bash
# Get current webhook secret from Stripe dashboard:
# Settings > Webhooks > Endpoints > Select endpoint > Signing secret

# Export to .env
echo "STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxx" >> .env
```

### Events Not Triggering
```bash
# List available event types
stripe trigger --list

# Trigger specific event with custom data
stripe trigger charge.succeeded \
  --override amount=2000 \
  --override currency=cad \
  --forward-to localhost:5001/webhook
```

## Best Practices

1. **Always verify signatures** - Never trust webhook data without verification
2. **Idempotency** - Handle duplicate events gracefully
3. **Error handling** - Return 200 quickly, process async
4. **Logging** - Log all webhook events for debugging
5. **Testing** - Test webhook handling in CI/CD with mocks
6. **Security** - Never commit webhook secrets to git
7. **Monitoring** - Monitor webhook delivery in Stripe dashboard

## Quick Reference Commands

```bash
# Start listening and forwarding
stripe listen --forward-to localhost:5001/webhook

# Trigger test events
stripe trigger payment_intent.succeeded
stripe trigger charge.captured
stripe trigger charge.refunded
stripe trigger charge.dispute.created
stripe trigger customer.created

# Monitor webhook deliveries
stripe logs tail

# Check webhook endpoint configuration
stripe webhook_endpoints list
stripe webhook_endpoints retrieve [id]
```

## Integration with CI/CD

For automated testing in GitHub Actions:

```yaml
# .github/workflows/test.yml

- name: Test with Stripe Mock
  env:
    TESTING: 'true'
    FUNCTIONS_EMULATOR: 'true'
    STRIPE_WEBHOOK_SECRET: ${{ secrets.STRIPE_WEBHOOK_SECRET_TEST }}
  run: |
    cd functions
    python3 -m pytest tests/test_handlers_payment_stripe.py -v
```

## References
- [Stripe CLI Documentation](https://stripe.com/docs/stripe-cli)
- [Stripe Webhooks Guide](https://stripe.com/docs/webhooks)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
