"""Stripe webhook management per environment."""
import click
from cli.utils.output import header, success, error, console, make_table
from cli.utils.stripe_client import get_stripe


ENV_TO_URL = {
    "dev": "https://us-central1-orignagta-dev.cloudfunctions.net/stripe_webhook",
    "staging": "https://us-central1-orignagta-staging.cloudfunctions.net/stripe_webhook",
    "prod": "https://us-central1-orignagta.cloudfunctions.net/stripe_webhook",
}

REQUIRED_EVENTS = [
    "checkout.session.completed",
    "checkout.session.expired",
    "payment_intent.succeeded",
    "payment_intent.payment_failed",
    "payment_intent.canceled",
    "charge.dispute.created",
    "charge.dispute.funds_reinstated",
    "charge.dispute.funds_withdrawn",
    "charge.dispute.closed",
]


@click.group()
def webhooks():
    """Manage Stripe webhooks per environment."""
    pass


@webhooks.command(name="list")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def list_webhooks(env: str):
    """List all Stripe webhook endpoints."""
    header("Stripe Webhooks", env)
    stripe = get_stripe(env)
    endpoints = stripe.webhook_endpoints.list()
    t = make_table("Webhook Endpoints", ["ID", "URL", "Status", "Events"])
    for ep in endpoints.data:
        t.add_row(ep.id, ep.url[:60], ep.status, str(len(ep.enabled_events)))
    console.print(t)


@webhooks.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def verify(env: str):
    """Verify all required events are registered."""
    header("Verify Webhooks", env)
    stripe_client = get_stripe(env)
    expected_url = ENV_TO_URL[env]
    endpoints = stripe_client.webhook_endpoints.list()
    match = next((ep for ep in endpoints.data if ep.url == expected_url), None)
    if not match:
        error(f"No webhook found for URL: {expected_url}")
        return
    missing = set(REQUIRED_EVENTS) - set(match.enabled_events)
    if missing:
        error(f"Missing events: {missing}")
    else:
        success(f"All {len(REQUIRED_EVENTS)} required events registered on {match.id}")


@webhooks.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def sync(env: str):
    """Create or update webhook endpoint with all required events."""
    header("Sync Webhooks", env)
    stripe_client = get_stripe(env)
    expected_url = ENV_TO_URL[env]
    endpoints = stripe_client.webhook_endpoints.list()
    existing = next((ep for ep in endpoints.data if ep.url == expected_url), None)
    if existing:
        stripe_client.webhook_endpoints.update(existing.id, {"enabled_events": REQUIRED_EVENTS})
        success(f"Updated existing webhook {existing.id}")
    else:
        ep = stripe_client.webhook_endpoints.create(params={
            "url": expected_url,
            "enabled_events": REQUIRED_EVENTS,
        })
        success(f"Created webhook {ep.id} for {expected_url}")
