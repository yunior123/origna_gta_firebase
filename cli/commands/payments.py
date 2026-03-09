"""Payment management — disputes, payouts, capture."""
import click
from cli.utils.output import header, success, error, console, make_table, confirm_prod
from cli.utils.firebase_client import get_firestore
from cli.utils.stripe_client import get_stripe


@click.group()
def payments():
    """Manage payments, disputes, and payouts."""
    pass


@payments.command(name="dispute")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--status", default=None, type=click.Choice(["needs_response", "under_review", "won", "lost"]))
def list_disputes(env: str, status: str | None):
    """List Stripe disputes."""
    header("Disputes", env)
    stripe = get_stripe(env)
    params: dict = {"limit": 20}
    if status:
        params["status"] = status
    disputes = stripe.disputes.list(params=params)
    t = make_table(f"Disputes ({env})", ["Dispute ID", "Amount", "Status", "Reason", "Order"])
    for d in disputes.data:
        order_id = d.metadata.get("orderId", "—") if d.metadata else "—"
        t.add_row(d.id, f"${d.amount/100:.2f}", d.status, d.reason, order_id)
    console.print(t)


@payments.command(name="dispute-resolve")
@click.argument("dispute_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--action", required=True, type=click.Choice(["accept", "submit_evidence"]))
def resolve_dispute(dispute_id: str, env: str, action: str):
    """Accept or submit evidence for a dispute."""
    header(f"Resolve Dispute {dispute_id[:16]}...", env)
    if env == "prod" and not confirm_prod(f"{action} dispute {dispute_id}"):
        return
    stripe = get_stripe(env)
    if action == "accept":
        stripe.disputes.close(dispute_id)
        success(f"Dispute {dispute_id} accepted (closed)")
    else:
        error("Evidence submission requires uploading files — use the Stripe dashboard.")


@payments.command(name="trigger-payouts")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--dry-run", is_flag=True, default=False)
def trigger_payouts(env: str, dry_run: bool):
    """Trigger payout processing for delivered orders."""
    header("Trigger Payouts", env)
    if env == "prod" and not confirm_prod("trigger payouts in PRODUCTION"):
        return
    if dry_run:
        console.print("[yellow]DRY RUN — no payouts will be created[/yellow]")
        return
    db = get_firestore(env)
    delivered = (
        db.collection("orders")
        .where("status", "==", "delivered")
        .where("payoutStatus", "==", "pending")
        .stream()
    )
    count = sum(1 for _ in delivered)
    success(f"Found {count} orders eligible for payout. Run cron_jobs.process_pending_payouts to execute.")


@payments.command()
@click.argument("order_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def capture(order_id: str, env: str):
    """Manually capture payment for an order (if not auto-captured)."""
    header(f"Capture {order_id[:12]}...", env)
    if env == "prod" and not confirm_prod(f"capture payment for order {order_id}"):
        return
    db = get_firestore(env)
    doc = db.collection("orders").document(order_id).get()
    if not doc.exists:
        error(f"Order {order_id} not found")
        return
    pi_id = doc.to_dict().get("stripePaymentIntentId")
    stripe = get_stripe(env)
    stripe.payment_intents.capture(pi_id)
    success(f"Payment captured for order {order_id}")
