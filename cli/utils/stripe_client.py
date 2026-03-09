"""Stripe client — picks test vs live key based on environment."""
import os
import stripe
from dotenv import load_dotenv


def get_stripe(env: str) -> stripe.StripeClient:
    """Function get_stripe."""
    env_file = os.path.join(os.path.dirname(__file__), f"../.env.{env}")
    if os.path.exists(env_file):
        load_dotenv(env_file, override=True)
    key = os.environ.get("STRIPE_SECRET_KEY")
    if not key:
        raise RuntimeError(
            f"STRIPE_SECRET_KEY not found. Set it in cli/.env.{env}"
        )
    if env == "prod" and key.startswith("sk_test_"):
        raise RuntimeError("PROD env is using a test Stripe key — aborting.")
    return stripe.StripeClient(key)
