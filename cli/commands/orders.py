"""Order management — list, view, refund, force-status, cancel."""
import click
from cli.utils.output import header, success, error, console, make_table, confirm_prod
from cli.utils.firebase_client import get_firestore
from cli.utils.stripe_client import get_stripe


@click.group()
def orders():
    """Manage marketplace orders."""
    pass


@orders.command(name="list")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--status", default=None)
@click.option("--limit", default=20)
@click.option("--buyer", default=None, help="Filter by buyer UID")
def list_orders(env: str, status: str | None, limit: int, buyer: str | None):
    """List orders with optional filters."""
    header("Orders", env)
    db = get_firestore(env)
    query = db.collection("orders").limit(limit)
    if status:
        query = query.where("status", "==", status)
    if buyer:
        query = query.where("buyerId", "==", buyer)
    docs = list(query.stream())
    t = make_table(f"Orders ({env}) — {len(docs)} results", ["Order ID", "Buyer", "Status", "Total", "Created"])
    for doc in docs:
        d = doc.to_dict()
        total = d.get("totalAmountCents", 0)
        t.add_row(
            doc.id[:20],
            d.get("buyerId", "—")[:16],
            d.get("status", "—"),
            f"${total/100:.2f} CAD",
            str(d.get("createdAt", "—"))[:19],
        )
    console.print(t)


@orders.command()
@click.argument("order_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def view(order_id: str, env: str):
    """View full order details."""
    header(f"Order {order_id[:12]}...", env)
    db = get_firestore(env)
    doc = db.collection("orders").document(order_id).get()
    if not doc.exists:
        error(f"Order {order_id} not found")
        return
    from rich.pretty import pprint
    pprint(doc.to_dict())


@orders.command()
@click.argument("order_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--amount", required=True, type=int, help="Refund amount in cents")
@click.option("--reason", default="requested_by_customer",
              type=click.Choice(["duplicate", "fraudulent", "requested_by_customer"]))
def refund(order_id: str, env: str, amount: int, reason: str):
    """Issue a Stripe refund for an order."""
    header(f"Refund Order {order_id[:12]}...", env)
    if env == "prod" and not confirm_prod(f"refund ${amount/100:.2f} on order {order_id}"):
        return
    db = get_firestore(env)
    doc = db.collection("orders").document(order_id).get()
    if not doc.exists:
        error(f"Order {order_id} not found")
        return
    d = doc.to_dict()
    pi_id = d.get("stripePaymentIntentId")
    if not pi_id:
        error("Order has no stripePaymentIntentId")
        return
    stripe = get_stripe(env)
    pi = stripe.payment_intents.retrieve(pi_id)
    charge_id = pi.latest_charge
    if not charge_id:
        error("No charge found on PaymentIntent")
        return
    rf = stripe.refunds.create(params={"charge": charge_id, "amount": amount, "reason": reason})
    db.collection("orders").document(order_id).update({
        "refundStatus": "refunded",
        "refundAmountCents": amount,
        "stripeRefundId": rf.id,
    })
    success(f"Refund {rf.id} issued: ${amount/100:.2f}")


@orders.command(name="force-status")
@click.argument("order_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--status", required=True,
              type=click.Choice(["pending", "processing", "shipped", "delivered", "cancelled", "disputed"]))
def force_status(order_id: str, env: str, status: str):
    """Force an order's status (admin override)."""
    header(f"Force Status {order_id[:12]}...", env)
    if env == "prod" and not confirm_prod(f"force status={status} on order {order_id}"):
        return
    db = get_firestore(env)
    db.collection("orders").document(order_id).update({"status": status})
    success(f"Order {order_id} status forced to '{status}'")


@orders.command()
@click.argument("order_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--reason", required=True)
def cancel(order_id: str, env: str, reason: str):
    """Cancel an order and update status."""
    header(f"Cancel Order {order_id[:12]}...", env)
    if env == "prod" and not confirm_prod(f"cancel order {order_id}"):
        return
    db = get_firestore(env)
    db.collection("orders").document(order_id).update({
        "status": "cancelled",
        "cancellationReason": reason,
    })
    success(f"Order {order_id} cancelled: {reason}")
