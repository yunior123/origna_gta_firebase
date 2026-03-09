"""Review management — list, delete, flag."""
import click
from cli.utils.output import header, success, error, console, make_table, confirm_prod
from cli.utils.firebase_client import get_firestore


@click.group()
def reviews():
    """Manage product reviews."""
    pass


@reviews.command(name="list")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--product", default=None, help="Filter by product ID")
@click.option("--user", default=None, help="Filter by user ID")
@click.option("--has-photos", is_flag=True, default=False, help="Only reviews with photos")
@click.option("--flagged", is_flag=True, default=False, help="Only flagged reviews")
@click.option("--limit", default=30)
def list_reviews(env: str, product: str | None, user: str | None, has_photos: bool, flagged: bool, limit: int):
    """List product reviews with optional filters."""
    header("Reviews", env)
    db = get_firestore(env)
    query = db.collection("product_ratings").limit(limit)
    if product:
        query = query.where("productId", "==", product)
    if user:
        query = query.where("userId", "==", user)
    if flagged:
        query = query.where("isFlagged", "==", True)
    docs = list(query.stream())

    if has_photos:
        docs = [d for d in docs if d.to_dict().get("reviewImageUrls")]

    t = make_table(
        f"Reviews ({env}) — {len(docs)}",
        ["ID", "Product", "User", "Rating", "Review", "Photos", "Flagged", "Created"],
    )
    for doc in docs:
        d = doc.to_dict()
        photos = d.get("reviewImageUrls", [])
        t.add_row(
            doc.id[:16],
            d.get("productId", "—")[:16],
            d.get("userId", "—")[:16],
            str(d.get("rating", "—")),
            str(d.get("review", "—"))[:40],
            str(len(photos)),
            "✓" if d.get("isFlagged") else "—",
            str(d.get("createdAt", "—"))[:19],
        )
    console.print(t)


@reviews.command()
@click.argument("review_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.confirmation_option(prompt="Permanently delete this review?")
def delete(review_id: str, env: str):
    """Delete a review by ID."""
    header(f"Delete review {review_id[:12]}...", env)
    if env == "prod" and not confirm_prod(f"delete review {review_id}"):
        return
    db = get_firestore(env)
    ref = db.collection("product_ratings").document(review_id)
    doc = ref.get()
    if not doc.exists:
        error(f"Review {review_id} not found")
        return
    ref.delete()
    success(f"Review {review_id} deleted")


@reviews.command()
@click.argument("review_id")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--unflag", is_flag=True, default=False, help="Unflag instead of flagging")
def flag(review_id: str, env: str, unflag: bool):
    """Flag or unflag a review for manual moderation."""
    action = "Unflag" if unflag else "Flag"
    header(f"{action} review {review_id[:12]}...", env)
    db = get_firestore(env)
    ref = db.collection("product_ratings").document(review_id)
    doc = ref.get()
    if not doc.exists:
        error(f"Review {review_id} not found")
        return
    ref.update({"isFlagged": not unflag})
    success(f"Review {review_id} {'unflagged' if unflag else 'flagged'}")
