"""Module create_stripe_webhooks.py."""

import os
import subprocess
import sys
import stripe
from dotenv import load_dotenv

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../functions/.env'))

STRIPE_SECRET_KEY = os.environ.get("STRIPE_SECRET_KEY")

if not STRIPE_SECRET_KEY:
    print("❌ STRIPE_SECRET_KEY not found in functions/.env")
    sys.exit(1)

stripe.api_key = STRIPE_SECRET_KEY

# Configuration
WEBHOOK_EVENTS = [
    "payment_intent.succeeded",
    "payment_intent.payment_failed",
    "charge.refunded",
    "charge.succeeded"  # Useful for debugging/receipts
]

PROJECTS = {
    # "orignagta-dev": "https://us-central1-orignagta-dev.cloudfunctions.net/stripe_webhook", # Already configured
    "orignagta-staging": "https://us-central1-orignagta-staging.cloudfunctions.net/stripe_webhook"
}

def upload_secret(project_id, secret_name, secret_value):
    """Function upload_secret."""
    print(f"   Uploading {secret_name} to {project_id}...")
    try:
        # Enable Secret Manager API (idempotent)
        subprocess.run(
            ["gcloud", "services", "enable", "secretmanager.googleapis.com", "--project", project_id],
            capture_output=True
        )

        # Create secret (if not exists)
        subprocess.run(
            ["gcloud", "secrets", "create", secret_name, "--project", project_id, "--replication-policy", "automatic"],
            capture_output=True
        )
        
        # Add secret version
        process = subprocess.Popen(
            ["gcloud", "secrets", "versions", "add", secret_name, "--project", project_id, "--data-file=-"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = process.communicate(input=secret_value)
        
        if process.returncode == 0:
            print(f"   ✅ Successfully set {secret_name}")
        else:
            print(f"   ❌ Failed to set {secret_name}: {stderr}")
            
    except Exception as e:
        print(f"   ❌ Exception setting {secret_name}: {e}")

def main():
    """Function main."""
    print("🚀 Starting Stripe Webhook Setup...")
    
    # helper to find existing webhook
    existing_webhooks = stripe.WebhookEndpoint.list(limit=100)
    
    for project_id, url in PROJECTS.items():
        print(f"\n--- Processing {project_id} ---")
        print(f"Target URL: {url}")
        
        # Check if exists
        details = None
        for wh in existing_webhooks.data:
            if wh.url == url:
                details = wh
                break
        
        if details:
            print(f"⚠️  Webhook already exists (ID: {details.id})")
            print("   Re-creating to ensure we have the signing secret...")
            stripe.WebhookEndpoint.delete(details.id)
            
        print("   Creating new webhook endpoint...")
        try:
            new_wh = stripe.WebhookEndpoint.create(
                url=url,
                enabled_events=WEBHOOK_EVENTS,
                description=f"Webhook for {project_id}"
            )
            signing_secret = new_wh.secret
            print(f"   ✅ Created Webhook ID: {new_wh.id}")
            
            # Upload secret
            upload_secret(project_id, "STRIPE_WEBHOOK_SECRET", signing_secret)
            
        except Exception as e:
            print(f"   ❌ Failed to create webhook: {e}")

if __name__ == "__main__":
    main()
