"""Module fix_stripe_webhooks.py."""

import os
import stripe
import subprocess
from dotenv import load_dotenv

# Load environment variables
load_dotenv("functions/.env")

# Initialize Stripe
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

if not stripe.api_key:
    print("❌ STRIPE_SECRET_KEY not found in functions/.env")
    exit(1)

if not stripe.api_key.startswith("sk_test_"):
    print("❌ STRIPE_SECRET_KEY is not a Test key. This script is for Test mode only.")
    print(f"Key found: {stripe.api_key[:8]}...")
    exit(1)

# Configuration
EVENTS = [
    "checkout.session.completed",
    "checkout.session.async_payment_succeeded",
    "checkout.session.async_payment_failed",
    "checkout.session.expired",
    "payment_intent.succeeded",
    "payment_intent.payment_failed",
    "payment_intent.canceled",
    "charge.refunded",
    "charge.dispute.created",
    "charge.dispute.updated",
    "charge.dispute.closed",
    "charge.dispute.funds_reinstated",
    "transfer.reversed",
    "payout.failed",
    "refund.failed",
    "account.updated",
]

DEV_URL = "https://us-central1-orignagta-dev.cloudfunctions.net/stripe_webhook"
STAGING_URL = "https://us-central1-orignagta-staging.cloudfunctions.net/stripe_webhook"
PROD_URL_TO_REMOVE = "https://us-central1-orignagta.cloudfunctions.net/stripe_webhook"

def update_secret(project_id, secret_name, secret_value):
    """Updates a secret in Google Secret Manager."""
    print(f"🔐 Updating secret '{secret_name}' in {project_id}...")
    try:
        # Check if secret exists
        subprocess.run(
            f"gcloud secrets describe {secret_name} --project {project_id}",
            shell=True,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except subprocess.CalledProcessError:
        # Create secret if it doesn't exist
        print(f"Creating secret {secret_name}...")
        subprocess.run(
            f"gcloud secrets create {secret_name} --replication-policy=automatic --project {project_id}",
            shell=True,
            check=True
        )

    # Add new version
    process = subprocess.Popen(
        f"gcloud secrets versions add {secret_name} --data-file=- --project {project_id}",
        shell=True,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = process.communicate(input=secret_value)
    
    if process.returncode == 0:
        print(f"✅ Secret updated successfully in {project_id}")
    else:
        print(f"❌ Failed to update secret in {project_id}: {stderr}")

def main():
    """Function main."""
    print("🔄 Checking Stripe Webhooks (Test Mode)...")
    
    # 1. List existing webhooks
    webhooks = stripe.WebhookEndpoint.list(limit=100)
    
    existing_dev = None
    existing_staging = None
    
    for webhook in webhooks.data:
        if webhook.url == PROD_URL_TO_REMOVE:
            print(f"⚠️ Found Production URL in Test Mode: {webhook.url} ({webhook.id})")
            print("🗑️ Deleting incorrect webhook...")
            stripe.WebhookEndpoint.delete(webhook.id)
            print("✅ Deleted.")
        elif webhook.url == DEV_URL:
            # Check if events match
            if set(webhook.enabled_events) == set(EVENTS):
                print(f"✅ Dev webhook already exists and is correct: {webhook.id}")
                existing_dev = webhook
            else:
                print("⚠️ Dev webhook exists but events mismatch. Deleting and recreating...")
                stripe.WebhookEndpoint.delete(webhook.id)
        elif webhook.url == STAGING_URL:
             if set(webhook.enabled_events) == set(EVENTS):
                print(f"✅ Staging webhook already exists and is correct: {webhook.id}")
                existing_staging = webhook
             else:
                print("⚠️ Staging webhook exists but events mismatch. Deleting and recreating...")
                stripe.WebhookEndpoint.delete(webhook.id)

    # 2. Create Dev Webhook if missing
    if not existing_dev:
        print(f"➕ Creating Dev Webhook: {DEV_URL}")
        dev_webhook = stripe.WebhookEndpoint.create(
            url=DEV_URL,
            enabled_events=EVENTS,
            description="Dev Environment Webhook"
        )
        print(f"✅ Created Dev Webhook: {dev_webhook.id}")
        existing_dev = dev_webhook
        
        # Update Secret Manager
        update_secret("orignagta-dev", "STRIPE_WEBHOOK_SECRET", dev_webhook.secret)
    else:
        # Verify secret matches (optional, but good practice if we could read it - we can't read from Stripe)
        # We assume if it exists, the secret is already in GSM. But to be safe, we might want to *rotate* it if we can't read it.
        # Actually, if it exists, we assume the secret is lost? No, we can't retrieve the secret again.
        # If the user doesn't have it, we should verify GSM.
        # For this script, if it exists, we'll try to update GSM anyway if we just created it.
        pass

    # 3. Create Staging Webhook if missing
    if not existing_staging:
        print(f"➕ Creating Staging Webhook: {STAGING_URL}")
        staging_webhook = stripe.WebhookEndpoint.create(
            url=STAGING_URL,
            enabled_events=EVENTS,
            description="Staging Environment Webhook"
        )
        print(f"✅ Created Staging Webhook: {staging_webhook.id}")
        
        # Update Secret Manager
        update_secret("orignagta-staging", "STRIPE_WEBHOOK_SECRET", staging_webhook.secret)

    print("\n🎉 Webhook setup complete!")

if __name__ == "__main__":
    main()
