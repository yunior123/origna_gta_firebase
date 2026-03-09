"""Product management — list, approve, reject, delete, add."""
import uuid
from datetime import UTC, datetime

import click
from cli.utils.output import header, success, error, console, make_table, confirm_prod
from cli.utils.firebase_client import get_firestore


@click.group()
def products():
    """Manage marketplace products."""
    pass


@products.command(name="list")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--pending-approval", is_flag=True, default=False)
@click.option("--seller", default=None, help="Filter by seller UID")
@click.option("--limit", default=20)
def list_products(env: str, pending_approval: bool, seller: str | None, limit: int):
    """List products with optional filters."""
    header("Products", env)
    db = get_firestore(env)
    query = db.collection("products").limit(limit)
    if pending_approval:
        query = query.where("approvalStatus", "==", "pending")
    if seller:
        query = query.where("sellerId", "==", seller)
    docs = list(query.stream())
    t = make_table(f"Products ({env}) — {len(docs)}", ["ID", "Title", "Seller", "Price", "Stock", "Approval"])
    for doc in docs:
        d = doc.to_dict()
        price = d.get("priceCents", 0)
        t.add_row(
            doc.id[:16],
            str(d.get("title", "—"))[:30],
            d.get("sellerId", "—")[:16],
            f"${price/100:.2f}",
            str(d.get("stockQuantity", 0)),
            d.get("approvalStatus", "approved"),
        )
    console.print(t)


@products.command()
@click.argument("product_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def approve(product_id: str, env: str):
    """Approve a product for listing."""
    header(f"Approve {product_id[:12]}...", env)
    db = get_firestore(env)
    db.collection("products").document(product_id).update({"approvalStatus": "approved"})
    success(f"Product {product_id} approved")


@products.command()
@click.argument("product_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--reason", required=True)
def reject(product_id: str, env: str, reason: str):
    """Reject a product with a reason."""
    header(f"Reject {product_id[:12]}...", env)
    db = get_firestore(env)
    db.collection("products").document(product_id).update({
        "approvalStatus": "rejected",
        "rejectionReason": reason,
    })
    success(f"Product {product_id} rejected: {reason}")


@products.command()
@click.argument("product_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.confirmation_option(prompt="Permanently delete this product?")
def delete(product_id: str, env: str):
    """Permanently delete a product."""
    header(f"Delete {product_id[:12]}...", env)
    if env == "prod" and not confirm_prod(f"delete product {product_id}"):
        return
    db = get_firestore(env)
    db.collection("products").document(product_id).delete()
    success(f"Product {product_id} deleted")


@products.command(name="add")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--seller-uid", required=True, help="UID of the seller (must have an active Stripe Connect account)")
@click.option("--title", required=True, help="Product title")
@click.option("--description", required=True, help="Product description")
@click.option("--price", required=True, type=float, help="Price in CAD dollars (e.g. 29.99)")
@click.option("--category", required=True, type=int, help="Category ID (1-21). 1=Electronics, 5=Fashion, 14=Books, 21=Digital, etc.")
@click.option("--stock", required=True, type=int, help="Initial stock quantity")
@click.option("--image-url", "image_urls", required=True, multiple=True, help="Image URL(s) — repeat flag for multiple (max 5)")
@click.option("--digital", is_flag=True, default=False, help="Mark as a digital product (no shipping)")
@click.option("--product-id", default=None, help="Custom product ID (auto-generated if omitted)")
def add_product(
    env: str,
    seller_uid: str,
    title: str,
    description: str,
    price: float,
    category: int,
    stock: int,
    image_urls: tuple[str, ...],
    digital: bool,
    product_id: str | None,
) -> None:
    """Add a product to the marketplace as an admin.

    The seller must have an active Stripe Connect account (payoutsEnabled=true).
    The product is auto-approved and goes live immediately.

    Examples:\b
      ./admin products add --env=dev \\
        --seller-uid=eVxwL5SfEATPnw1zhWYaUdGx8MD2 \\
        --title="Vintage Camera" --description="35mm film camera, excellent condition" \\
        --price=89.99 --category=1 --stock=3 \\
        --image-url=https://example.com/camera.jpg

      ./admin products add --env=dev \\
        --seller-uid=RU9MI8vYFkQCakMrJfG8iGTuc012 \\
        --title="Python E-book" --description="Complete Python guide PDF" \\
        --price=14.99 --category=21 --stock=9999 --digital \\
        --image-url=https://example.com/book-cover.jpg
    """
    header("Add Product", env)

    if not 1 <= category <= 21:
        error(f"Category ID must be between 1 and 21 (got {category})")
        raise SystemExit(1)
    if len(image_urls) > 5:
        error("Maximum 5 image URLs allowed")
        raise SystemExit(1)
    if stock < 0:
        error("Stock quantity cannot be negative")
        raise SystemExit(1)
    if price <= 0:
        error("Price must be greater than 0")
        raise SystemExit(1)

    db = get_firestore(env)

    # Validate seller exists and has a Stripe Connect account
    seller_doc = db.collection("users").document(seller_uid).get()
    if not seller_doc.exists:
        error(f"Seller {seller_uid} not found in Firestore")
        raise SystemExit(1)

    seller_data = seller_doc.to_dict() or {}
    stripe_account_id = seller_data.get("stripeAccountId")
    if not stripe_account_id:
        error(
            f"Seller {seller_uid} has no Stripe Connect account (stripeAccountId is missing). "
            "The seller must complete Stripe onboarding before products can be listed."
        )
        raise SystemExit(1)

    payouts_enabled = seller_data.get("payoutsEnabled", False)
    if not payouts_enabled:
        console.print(
            f"[yellow]⚠ Warning:[/yellow] Seller {seller_uid} has stripeAccountId={stripe_account_id} "
            "but payoutsEnabled=false. Product will be created but payouts may fail."
        )
        if not click.confirm("Continue anyway?", default=False):
            raise SystemExit(0)

    price_cents = round(price * 100)
    product_id = product_id or str(uuid.uuid4()).replace("-", "")[:20]
    now = datetime.now(UTC)

    product_data = {
        "title": title,
        "description": description,
        "priceCents": price_cents,
        "categoryId": category,
        "stockQuantity": stock,
        "imageUrls": list(image_urls),
        "sellerId": seller_uid,
        "sellerStripeAccountId": stripe_account_id,
        "status": "active",
        "isActive": True,
        "approvalStatus": "approved",
        "isDigital": digital,
        "rating": 0.0,
        "ratingCount": 0,
        "dateCreated": now,
        "updatedAt": now,
        "archived": False,
    }

    if env == "prod" and not confirm_prod(f"add product '{title}' for seller {seller_uid}"):
        raise SystemExit(0)

    db.collection("products").document(product_id).set(product_data)

    console.print("\n[bold green]✓ Product created[/bold green]")
    t = make_table("New Product", ["Field", "Value"])
    t.add_row("ID", product_id)
    t.add_row("Title", title)
    t.add_row("Seller UID", seller_uid)
    t.add_row("Stripe Account", stripe_account_id)
    t.add_row("Price", f"CAD ${price:.2f} ({price_cents} cents)")
    t.add_row("Category", str(category))
    t.add_row("Stock", str(stock))
    t.add_row("Digital", str(digital))
    t.add_row("Status", "active / approved")
    console.print(t)
    success(f"Product {product_id} is live on {env}")
